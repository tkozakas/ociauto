#!/usr/bin/env bash
#
# ociauto.sh — Retry-launch an OCI compute instance with exponential backoff + jitter,
# live countdown and on-screen error only, with periodic session-token refresh

set -uo pipefail   # strict mode, but no -e so we handle failures manually

# === Load .env Variables ===
if [[ -f .env ]]; then
  set -o allexport; source .env; set +o allexport
else
  echo "ERROR: .env file not found" >&2
  exit 1
fi

# === Backoff params ===
interval=${BASE_INTERVAL:-60}
max_interval=${MAX_INTERVAL:-300}
factor=${BACKOFF_FACTOR:-2}
jitter_percent=${JITTER_PERCENT:-10}

# === Logs & Flag ===
FLAG_FILE="${HOME}/.oci/instance_launched"
SUCCESS_LOG="${HOME}/.oci/instance_launch_success.log"
ERROR_LOG="${HOME}/.oci/instance_launch_error.log"
MAX_ERROR_LOG_SIZE=$((10 * 1024 * 1024))

rotate_error_log() {
  if [[ -f $ERROR_LOG && $(stat -c%s "$ERROR_LOG") -ge $MAX_ERROR_LOG_SIZE ]]; then
    mv "$ERROR_LOG" "${ERROR_LOG}.old"
  fi
}
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$1"
}

# === Exit if already done ===
if [[ -f "$FLAG_FILE" ]]; then
  echo "Instance already launched; exiting."
  log_message "$SUCCESS_LOG" "Instance already launched; exiting."
  exit 0
fi

# === Retry Loop ===
while true; do
  rotate_error_log

  # Refresh session token if using security_token auth
  if [[ "${OCI_CLI_AUTH:-}" == "security_token" ]]; then
    oci session refresh --profile "${OCI_CLI_PROFILE}" >/dev/null 2>&1 || {
      echo "WARNING: failed to refresh OCI session—authentication may expire."
    }
  fi

  echo "[$(date '+%H:%M:%S')] Launch attempt…"
  log_message "$SUCCESS_LOG" "Attempting to launch instance…"

  output=$(oci compute instance launch \
    --compartment-id            "${COMPARTMENT_OCID}" \
    --availability-domain       "${AVAILABILITY_DOMAIN}" \
    --shape                     "${SHAPE}" \
    --shape-config              "{\"ocpus\":${OCPUS},\"memoryInGBs\":${MEMORY_GB}}" \
    --image-id                  "${IMAGE_OCID}" \
    --subnet-id                 "${SUBNET_OCID}" \
    --assign-public-ip          true \
    --ssh-authorized-keys-file  "${SSH_KEYS_FILE}" \
    --display-name              "${DISPLAY_NAME}" 2>&1)
  exitcode=$?

  if [[ $exitcode -eq 0 ]]; then
    echo "✅ Instance launched!"
    log_message "$SUCCESS_LOG" "✅ Instance launched successfully."
    mkdir -p "$(dirname "$FLAG_FILE")" && touch "$FLAG_FILE"
    break
  fi

  # on failure: show only the CLI error
  echo
  echo "❌ Launch failed (exit code $exitcode). Error:"
  echo "────────────────────────────────────────────────"
  echo "$output"
  echo "────────────────────────────────────────────────"
  log_message "$ERROR_LOG" "❌ Launch failed (exit $exitcode); output follows."
  echo "$output" >> "$ERROR_LOG"

  # backoff with jitter + countdown
  jitter_range=$(( interval * jitter_percent * 2 / 100 ))
  jitter_offset=$(( interval * jitter_percent / 100 ))
  jitter_amt=$(( RANDOM % (jitter_range + 1) - jitter_offset ))
  sleep_time=$(( interval + jitter_amt ))

  for ((n=sleep_time; n>0; n--)); do
    printf "\rRetrying in %3d seconds... " "$n"
    sleep 1
  done
  printf "\rRetrying now!                    \n"

  interval=$(( interval * factor ))
  (( interval > max_interval )) && interval=$max_interval
done

exit 0

