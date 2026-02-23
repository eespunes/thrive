#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/app"
DEFAULT_AVD="Medium_Phone_API_36.0"
AVD_NAME="${1:-$DEFAULT_AVD}"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: command '$cmd' not found in PATH."
    exit 1
  fi
}

require_cmd flutter
require_cmd emulator
require_cmd adb

if ! emulator -list-avds | grep -Fxq "$AVD_NAME"; then
  echo "Error: AVD '$AVD_NAME' not found."
  echo "Available emulators:"
  emulator -list-avds
  exit 1
fi

get_running_emulator() {
  adb devices | awk 'NR>1 && $2=="device" && $1 ~ /^emulator-/ {print $1; exit}'
}

DEVICE_ID="$(get_running_emulator || true)"

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "Starting Android emulator: $AVD_NAME"
  nohup emulator -avd "$AVD_NAME" -no-snapshot-save >/tmp/thrive-emulator.log 2>&1 &

  echo "Waiting for emulator to be ready..."
  for _ in {1..90}; do
    DEVICE_ID="$(get_running_emulator || true)"
    if [[ -n "${DEVICE_ID:-}" ]]; then
      BOOT_READY="$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
      if [[ "$BOOT_READY" == "1" ]]; then
        break
      fi
    fi
    sleep 2
  done
fi

if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "Error: emulator started but no online emulator device was detected."
  exit 1
fi

BOOT_READY="$(adb -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
if [[ "$BOOT_READY" != "1" ]]; then
  echo "Error: emulator '$DEVICE_ID' is online but boot is not completed."
  exit 1
fi

echo "Using emulator device: $DEVICE_ID"
echo "Launching Thrive app..."

cd "$APP_DIR"
flutter pub get
flutter run -d "$DEVICE_ID" --target lib/main.dart
