#!/usr/bin/env bash
# Reinstall previously backed-up, device-sourced Google Play Store split APKs.
# Explicit --apply required to modify the connected device.
set -euo pipefail
if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo 'Usage: bash scripts/reinstall-playstore-splits.sh <backup-dir> [--apply]' >&2
  exit 2
fi
DIR="$1"
if [[ $# -eq 2 && "$2" != "--apply" ]]; then
  echo "ERROR: unknown option $2 (expected --apply)" >&2
  exit 2
fi
[[ -d "$DIR" ]] || { echo "ERROR: $DIR is not a directory" >&2; exit 1; }
shopt -s nullglob
APKS=("$DIR"/*.apk)
(( ${#APKS[@]} > 0 )) || { echo "ERROR: no *.apk in $DIR" >&2; exit 1; }
[[ -f "$DIR/base.apk" ]] || { echo 'ERROR: base.apk is missing. Incomplete backup.' >&2; exit 1; }

echo "Play Store backup: ${#APKS[@]} APK file(s)"
printf '  %s\n' "${APKS[@]}"
if [[ "${2:-}" != '--apply' ]]; then
  echo 'DRY RUN. To reinstall, add --apply. Existing Play Store data will NOT be cleared.'
  exit 0
fi
[[ "$(adb shell getprop ro.product.model | tr -d '\r')" == 'XP5900' ]] || {
  echo 'ERROR: connected device is not XP5900. No changes made.' >&2
  exit 1
}
echo 'Reinstalling the complete split set with --force-queryable...'
adb install-multiple -r --force-queryable "${APKS[@]}"
echo 'Done. Reboot/reopen apps; do not clear data of Google services.'
