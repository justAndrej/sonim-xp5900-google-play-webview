#!/usr/bin/env bash
# Create a Magisk ZIP declaring fake touchscreen support for Play Store filtering.
# DOES NOT add real hardware gestures or change Configuration.touchscreen.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/modules/touchscreen"
TARGET="${1:-$ROOT/out/sonim-xp5900-touchscreen-magisk.zip}"
mkdir -p "$(dirname "$TARGET")"
python3 - "$SOURCE" "$TARGET" <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import sys
root, dest = map(Path, sys.argv[1:])
assert (root / 'module.prop').is_file()
assert (root / 'system/etc/permissions/sonim-touchscreen-test.xml').is_file()
with ZipFile(dest, 'w', ZIP_DEFLATED) as z:
    for f in sorted(root.rglob('*')):
        if f.is_file():
            z.write(f, f.relative_to(root))
print('Built:', dest)
PY
printf '%s\n' 'Install ZIP manually via Magisk -> Modules, then reboot.'
