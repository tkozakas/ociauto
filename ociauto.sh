#!/usr/bin/env bash
#
# ociauto.sh — Retry-launch an OCI compute instance with exponential backoff + jitter
# and a live countdown until next retry

set -uo pipefail
# (we omit `-e` so we can handle errors ourselves)

# === Load .env Variables ===
if [[ -f .env ]]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo "ERROR: .env file not found" >&2
  exit 1
fi

# === Back-off parameters (from .env, with defaults) ===
interval=${BASE_INTERVAL:-60}
max_interval=${MAX_INTERVAL:-300}
factor=${BACKOFF_FACTOR:-2}
jitter_percent=${JITTER_PERCENT:-10}

# === Paths & Logs ===
FLAG_FILE="${HOME}/.oci/instance_launched"
SUCCESS_LOG="${HOME}/.oci/instance_launch_success.log"
ERROR_LOG="${HOME}/.oci/instance_launch_error.log"
MAX_ERROR_LOG_SIZE=$((10 * 1024 * 1024))

rotate_error_log() {
  if [[ -f "$ERROR_LOG" && $(stat -c%s "$ERROR_LOG") -ge $MAX_ERROR_LOG_SIZE ]]; then
    mv "$ERROR_LOG" "${ERROR_LOG}.old"
  fi
}

log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$1"
}

# === Skip if already launched ===
if [[ -f "$FLAG_FILE" ]]; then
  echo "Instance already launched; exiting."
  log_message "$SUCCESS_LOG" "Instance already launched; exiting."
  exit 0
fi

# === Retry Loop ===
while true; do
  rotate_error_log
  echo "[$(date '+%H:%M:%S')] Launch attempt…"
  log_message "$SUCCESS_LOG" "Attempting to launch instance…"

  # Run the OCI CLI command and capture output + exit code
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
    echo "✅ Instance launched!"
    log_message "$SUCCESS_LOG" "✅ Instance launched successfully."
    mkdir -p "$(dirname "$FLAG_FILE")"
    touch "$FLAG_FILE"
    break
  else
    echo "❌ Launch failed (exit code $exitcode); will retry shortly."
    log_message "$ERROR_LOG" "❌ Launch failed (exit $exitcode); output follows."
    echo "$output" >> "$ERROR_LOG"

    # === Compute jittered sleep time ===
    # jitter range = ±jitter_percent% of interval
    jitter_range=$(( interval * jitter_percent * 2 / 100 ))
    jitter_offset=$(( interval * jitter_percent / 100 ))
    jitter_amt=$(( RANDOM % (jitter_range + 1) - jitter_offset ))
    sleep_time=$(( interval + jitter_amt ))

    # === Countdown until next retry ===
    for ((remaining=sleep_time; remaining>0; remaining--)); do
      printf "\rRetrying in %3d seconds... " "$remaining"
      sleep 1
    done
    printf "\rRetrying now!                    \n"

    # === Apply exponential backoff ===
    interval=$(( interval * factor ))
    if [[ $interval -gt $max_interval ]]; then
      interval=$max_interval
    fi
  fi
done
