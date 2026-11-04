#!/usr/bin/env bash
# Back up all installed Play Store splits from the CONNECTED user's device.
# These are proprietary Google APKs: keep locally; do NOT commit/publish.
set -euo pipefail
DEST="${1:-out/playstore-backup}"
[[ "$DEST" != '/' && -n "$DEST" ]] || { echo 'ERROR: choose a normal destination directory' >&2; exit 2; }
mkdir -p "$DEST"
chmod 700 "$DEST" 2>/dev/null || true
if find "$DEST" -maxdepth 1 -type f -name '*.apk' | grep -q .; then
  echo "ERROR: $DEST already contains APKs. Use a new/empty directory to avoid mixing different split versions." >&2
  exit 1
fi

PM_PATHS="$(adb shell pm path com.android.vending | tr -d '\r')"
if ! grep -q '^package:' <<< "$PM_PATHS"; then
  echo 'ERROR: Play Store (com.android.vending) is missing or inaccessible.' >&2
  exit 1
fi
count=0
while IFS= read -r line; do
  case "$line" in
    package:*)
      remote="${line#package:}"
      name="${remote##*/}"
      [[ "$name" == *.apk ]] || { echo "Unexpected APK filename: $name" >&2; exit 1; }
      target="$DEST/$name"
      echo "Saving $name"
      if ! adb pull "$remote" "$target"; then
        echo "ADB pull failed; trying root cat for $name" >&2
        adb exec-out su -c "cat '$remote'" > "$target"
      fi
      [[ -s "$target" ]] || { echo "Empty file: $target" >&2; exit 1; }
      count=$((count + 1))
      ;;
  esac
done <<< "$PM_PATHS"
(( count > 0 )) || { echo 'ERROR: no APK files were backed up' >&2; exit 1; }
printf '%s\n' "Backed up $count APK file(s) in $DEST" 'IMPORTANT: do not publish this directory; it contains Google APKs.'
