#!/usr/bin/env bash
# Read-only diagnostics. Designed for Sonim XP5900 (ROW) with Android 11.
set -euo pipefail
command -v adb >/dev/null || { echo 'ERROR: adb not found (Android Platform Tools).' >&2; exit 1; }
getprop() { adb shell getprop "$1" | tr -d '\r'; }

echo '=== Device ==='
printf 'Manufacturer: %s\n' "$(getprop ro.product.manufacturer)"
printf 'Model:        %s\n' "$(getprop ro.product.model)"
printf 'Android API:  %s\n' "$(getprop ro.build.version.sdk)"
printf 'ABIs:         %s\n' "$(getprop ro.product.cpu.abilist)"
printf 'RAM profile:  %s\n' "$(getprop ro.config.low_ram)"
printf 'Boot state:   %s\n' "$(getprop ro.boot.verifiedbootstate)"

echo
echo '=== Display and declared features ==='
adb shell am get-config | tr -d '\r' | head -n 3 || true
adb shell pm list features | tr -d '\r' | grep -E 'feature:android.hardware.(touchscreen|faketouch)' || true

echo
echo '=== Google components ==='
for p in com.google.android.gms com.google.android.gsf com.android.vending com.google.android.webview; do
  if adb shell pm path "$p" | grep -q '^package:'; then
    echo "INSTALLED: $p"
    adb shell dumpsys package "$p" | grep -m1 -E 'versionName=' || true
  else
    echo "ABSENT:    $p"
  fi
done

echo
echo '=== Active WebView ==='
adb shell dumpsys webviewupdate | tr -d '\r' | grep -E 'Current WebView package|Valid package|Invalid package' || true

echo
echo 'No settings were changed.'
