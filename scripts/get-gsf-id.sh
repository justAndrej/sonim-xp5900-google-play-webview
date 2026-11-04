#!/usr/bin/env bash
# Read the Google Services Framework android_id from its database.
# Works around READ_GSERVICES permission denied to ADB shell.
# Copies GSF database/WAL into a private TEMP directory on the Mac and deletes
# them on exit. Requires rooted phone and Python 3. Do NOT publish the ID.
set -euo pipefail
command -v adb >/dev/null || { echo 'ERROR: adb missing.' >&2; exit 1; }
command -v python3 >/dev/null || { echo 'ERROR: python3 missing.' >&2; exit 1; }
BASE='/data/user/0/com.google.android.gsf/databases/gservices.db'
if [[ "$(adb shell su -c 'id -u' | tr -d '\r')" != 0 ]]; then
  echo 'ERROR: ADB Shell has no root permissions in Magisk.' >&2
  exit 1
fi
if ! adb shell su -c "test -f '$BASE'"; then
  echo "ERROR: $BASE not found. Is com.google.android.gsf installed?" >&2
  exit 1
fi
TMP="$(mktemp -d)"
chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT
for suffix in '' '-wal'; do
  REMOTE="$BASE$suffix"
  if adb shell su -c "test -f '$REMOTE'"; then
    adb exec-out su -c "cat '$REMOTE'" > "$TMP/gservices.db$suffix"
  fi
done
python3 - "$TMP/gservices.db" <<'PY'
import sqlite3
import sys
from pathlib import Path
p = Path(sys.argv[1])
if not p.exists() or p.stat().st_size == 0:
    raise SystemExit('ERROR: Could not copy the GSF database')
try:
    conn = sqlite3.connect(f'file:{p.as_posix()}?mode=ro', uri=True)
    try:
        row = conn.execute("SELECT value FROM main WHERE name='android_id'").fetchone()
    finally:
        conn.close()
except sqlite3.DatabaseError as e:
    raise SystemExit(f'ERROR: GSF DB could not be read: {e}; check WAL consistency')
if row is None or not str(row[0]).strip():
    raise SystemExit('ERROR: android_id is absent from GSF database')
raw = str(row[0]).strip()
try:
    # Some databases may represent a 64-bit ID as a signed integer.
    value = int(raw, 10) & ((1 << 64) - 1)
except ValueError:
    raise SystemExit('ERROR: android_id is not a decimal integer')
print('GSF ID (hex, private):', f'{value:016x}')
print('Register at https://www.google.com/android/uncertified/')
print('Use the same Google account as on Sonim (observed working in our test).')
print('This does not grant official Play Protect device certification.')
PY
