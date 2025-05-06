#!/bin/bash
#
# ociauto-env.sh — Retry-launch an OCI compute instance using .env config

# === Load .env Variables ===
if [ -f .env ]; then
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport
fi

# === Logging & Flag Files ===
FLAG_FILE="${HOME}/.oci/instance_launched"
SUCCESS_LOG="${HOME}/.oci/instance_launch_success.log"
ERROR_LOG="${HOME}/.oci/instance_launch_error.log"
MAX_ERROR_LOG_SIZE=$((10 * 1024 * 1024))

rotate_error_log() {
  if [ -f "${ERROR_LOG}" ] && [ "$(stat -c%s "${ERROR_LOG}")" -ge "${MAX_ERROR_LOG_SIZE}" ]; then
    mv "${ERROR_LOG}" "${ERROR_LOG}.old"
  fi
}

log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$1"
}

# Skip if already launched
if [ -f "${FLAG_FILE}" ]; then
  log_message "${SUCCESS_LOG}" "Instance already launched; exiting."
  exit 0
fi

# === Retry Loop ===
while true; do
  rotate_error_log
  log_message "${SUCCESS_LOG}" "Attempting to launch instance..."

  output=$(oci compute instance launch \
    --compartment-id "${COMPARTMENT_OCID}" \
    --availability-domain "${AVAILABILITY_DOMAIN}" \
    --shape "${SHAPE}" \
    --shape-config "{\"ocpus\": ${OCPUS}, \"memoryInGBs\": ${MEMORY_GB}}" \
    --image-id "${IMAGE_OCID}" \
    --subnet-id "${SUBNET_OCID}" \
    --assign-public-ip true \
    --metadata "{\"ssh_authorized_keys\":\"${SSH_KEY}\"}" \
    --display-name "${DISPLAY_NAME}" 2>&1)

  if echo "${output}" | jq -e . >/dev/null 2>&1; then
    log_message "${SUCCESS_LOG}" "✅ Instance launched successfully."
    mkdir -p "$(dirname "${FLAG_FILE}")"
    touch "${FLAG_FILE}"
    break
  else
    log_message "${ERROR_LOG}" "❌ Launch failed; sleeping ${RETRY_INTERVAL}s. Output:"
    echo "${output}" >> "${ERROR_LOG}"
    sleep "${RETRY_INTERVAL}"
  fi
done
