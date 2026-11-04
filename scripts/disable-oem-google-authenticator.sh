#!/usr/bin/env bash
# The Sonim OEM component was observed to intercept type=com.google accounts.
# Never disable the whole com.android.synccontact package.
set -euo pipefail
COMPONENT='com.android.synccontact/com.android.synccontact.service.GoogleAccountAuthenticator'
usage() {
  cat <<'USAGE'
Usage: bash scripts/disable-oem-google-authenticator.sh [--status|--apply|--undo]
  --status  Read-only check (default)
  --apply   Disable only the OEM authenticator component for user 0 (root required)
  --undo    Re-enable the same component (root required)
Check the component name on your own firmware before applying.
USAGE
}
case "${1:---status}" in
  --status)
    echo 'OEM Google authenticator status (check component entry below):'
    adb shell dumpsys package com.android.synccontact | tr -d '\r' | grep -i -C 3 'GoogleAccountAuthenticator' || {
      echo 'Component not found. Do not apply this fix without investigating the OEM package.' >&2
      exit 1
    }
    ;;
  --apply|--undo)
    command -v adb >/dev/null || { echo 'adb missing' >&2; exit 1; }
    if ! adb shell pm path com.android.synccontact | grep -q '^package:'; then
      echo 'ERROR: com.android.synccontact not installed. Nothing changed.' >&2
      exit 1
    fi
    if ! adb shell dumpsys package com.android.synccontact | grep -q 'GoogleAccountAuthenticator'; then
      echo 'ERROR: expected component not found. Nothing changed.' >&2
      exit 1
    fi
    if [[ "$(adb shell su -c 'id -u' | tr -d '\r')" != 0 ]]; then
      echo 'ERROR: Magisk root permission not granted to ADB Shell.' >&2
      exit 1
    fi
    if [[ "$1" == '--apply' ]]; then
      echo "Disabling only: $COMPONENT"
      adb shell su -c "pm disable --user 0 '$COMPONENT'"
    else
      echo "Enabling: $COMPONENT"
      adb shell su -c "pm enable --user 0 '$COMPONENT'"
    fi
    ;;
  -h|--help) usage ;;
  *) usage >&2; exit 2 ;;
esac
