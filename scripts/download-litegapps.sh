#!/usr/bin/env bash
# Optional download of an UPSTREAM released LiteGapps build for arm64 / Android 11.
# Pinned example (2026-07-09), NOT necessarily the exact build used in the case study.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="${1:-$ROOT/out/downloads}"
NAME='LiteGapps-arm64-11.0-20260709-official.zip'
SHA256='3b6266bb9cc8972555ed16d3396e96e6ced5f7e0cf13c86cb982ab83712c1299'
URL="https://github.com/litegapps/litegapps/releases/download/lite-build-20260709-3/$NAME"
mkdir -p "$DEST"
FILE="$DEST/$NAME"
PART="$FILE.part"
command -v curl >/dev/null || { echo 'ERROR: curl missing' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'ERROR: python3 missing' >&2; exit 1; }
if [[ ! -f "$FILE" ]]; then
  echo "Downloading upstream LiteGapps ARM64 Android 11 to $FILE"
  curl -fL --retry 3 -o "$PART" "$URL"
  mv "$PART" "$FILE"
fi
python3 - "$FILE" "$SHA256" <<'PY'
from pathlib import Path
import hashlib
import sys
path, expected = Path(sys.argv[1]), sys.argv[2]
h = hashlib.sha256()
with path.open('rb') as f:
    for block in iter(lambda: f.read(1024 * 1024), b''):
        h.update(block)
actual = h.hexdigest()
if actual != expected:
    raise SystemExit(f'ERROR: SHA-256 mismatch! Got {actual}; expected {expected}')
print('Verified SHA-256:', actual)
PY
# Check archive integrity if unzip is available.
if command -v unzip >/dev/null; then
  unzip -tq "$FILE" >/dev/null
  echo 'ZIP integrity: OK'
fi
printf 'Ready: %s\n' "$FILE"
printf '%s\n' 'Install this ZIP in Magisk manually after backing up your device.'
