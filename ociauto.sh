#!/bin/bash
#
# ociauto.sh — Retry-launch an OCI compute instance using .env config

# Don’t abort on error; we’ll inspect exit codes ourselves
set -uo pipefail

# === Load .env Variables ===
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo "ERROR: .env file not found" >&2
  exit 1
fi

FLAG_FILE="${HOME}/.oci/instance_launched"
SUCCESS_LOG="${HOME}/.oci/instance_launch_success.log"
ERROR_LOG="${HOME}/.oci/instance_launch_error.log"
MAX_ERROR_LOG_SIZE=$((10 * 1024 * 1024))

rotate_error_log() {
  if [[ -f "$ERROR_LOG" && $(stat -c%s "$ERROR_LOG") -ge $MAX_ERROR_LOG_SIZE ]]; then
    mv "$ERROR_LOG" "$ERROR_LOG".old
  fi
}

log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$1"
}

# If it’s already been launched, nothing to do
if [[ -f "$FLAG_FILE" ]]; then
  echo "Already launched; exiting."
  log_message "$SUCCESS_LOG" "Instance already launched; exiting."
  exit 0
fi

while true; do
  rotate_error_log
  echo "[$(date '+%H:%M:%S')] Launch attempt…"
  log_message "$SUCCESS_LOG" "Attempting to launch instance…"

  # run OCI CLI and capture both output and exit code
  output=$(oci compute instance launch \
    --compartment-id       "${COMPARTMENT_OCID}" \
    --availability-domain  "${AVAILABILITY_DOMAIN}" \
    --shape                "${SHAPE}" \
    --shape-config         "{\"ocpus\":${OCPUS},\"memoryInGBs\":${MEMORY_GB}}" \
    --image-id             "${IMAGE_OCID}" \
    --subnet-id            "${SUBNET_OCID}" \
    --assign-public-ip     true \
    --metadata             ssh_authorized_keys="${SSH_KEY}" \
    --display-name         "${DISPLAY_NAME}" 2>&1)
  exitcode=$?

  if [[ $exitcode -eq 0 ]]; then
    echo "✅ Launched!"
    log_message "$SUCCESS_LOG" "✅ Instance launched successfully."
    mkdir -p "$(dirname "$FLAG_FILE")"
    touch "$FLAG_FILE"
    break
  else
    echo "❌ Failed (exit $exitcode), retrying in ${RETRY_INTERVAL}s…"
    log_message "$ERROR_LOG" "❌ Launch failed (exit $exitcode); output follows."
    echo "$output" >> "$ERROR_LOG"
    sleep "$RETRY_INTERVAL"
  fi
done
