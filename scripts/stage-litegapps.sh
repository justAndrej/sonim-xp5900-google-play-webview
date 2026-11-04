#!/usr/bin/env bash
# Upload a vetted LiteGapps ZIP to the Sonim for manual install via Magisk app.
# Does not flash anything, grant root, or reboot the device.
set -euo pipefail
if [[ $# -ne 1 ]]; then
  echo 'Usage: bash scripts/stage-litegapps.sh <LiteGapps-arm64-11.0-....zip>' >&2
  exit 2
fi
ZIP="$1"
[[ -f "$ZIP" && -s "$ZIP" ]] || { echo 'ERROR: missing/empty ZIP.' >&2; exit 1; }
[[ "$(adb shell getprop ro.product.model | tr -d '\r')" == 'XP5900' ]] || { echo 'ERROR: expected XP5900.' >&2; exit 1; }
[[ "$(adb shell getprop ro.build.version.sdk | tr -d '\r')" == '30' ]] || { echo 'ERROR: expected Android 11, API 30.' >&2; exit 1; }
[[ "$(adb shell getprop ro.product.cpu.abi | tr -d '\r')" == 'arm64-v8a' ]] || { echo 'ERROR: expected arm64.' >&2; exit 1; }
case "${ZIP##*/}" in
  *arm64*11.0*.zip) ;;
  *) echo 'ERROR: ZIP filename should indicate arm64 and Android 11. Check source/build before proceeding.' >&2; exit 1 ;;
esac
if command -v unzip >/dev/null; then unzip -tq "$ZIP" >/dev/null; fi
NAME="${ZIP##*/}"
REMOTE="/sdcard/Download/$NAME"
echo "Copying locally verified ZIP to $REMOTE"
adb push "$ZIP" "$REMOTE"
cat <<EOF2
Staged: $REMOTE
On Sonim: Magisk -> Modules -> Install from storage -> $NAME -> reboot.
This script DID NOT install the module. Review its publisher and SHA-256 first.
EOF2
