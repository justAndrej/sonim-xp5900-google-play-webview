#!/bin/bash
# Builds a minimal Magisk RRO module to allow Play-installed Google WebView as
# an alternate provider on stock Sonim XP5900 / Android 11.
# Requires Android SDK Build Tools, adb, Java keytool, Python 3.
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
OUT="$ROOT/out"
TMP="$OUT/work"
mkdir -p "$TMP"

for tool in adb python3 keytool; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: $tool not found in PATH" >&2
    exit 1
  fi
done

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
if [[ ! -d "$SDK/build-tools" ]]; then
  echo "ERROR: Android SDK Build Tools not found in $SDK/build-tools" >&2
  echo 'Set ANDROID_HOME (e.g., $HOME/Library/Android/sdk).' >&2
  exit 1
fi
BT="$(find "$SDK/build-tools" -type f -name aapt2 | sort -r | head -1 | sed 's|/aapt2$||')"
if [[ -z "$BT" ]]; then
  echo 'ERROR: aapt2 missing. Install Android SDK Build Tools in Android Studio.' >&2
  exit 1
fi
for t in aapt2 apksigner zipalign; do
  if [[ ! -x "$BT/$t" ]]; then
    echo "ERROR: $BT/$t is missing" >&2
    exit 1
  fi
done

echo 'Checking attached Sonim...'
ANDROID_API="$(adb shell getprop ro.build.version.sdk | tr -d '\r')"
[[ "$ANDROID_API" == '30' ]] || { echo "ERROR: Expected Android 11 (API 30), got $ANDROID_API" >&2; exit 1; }
MODEL="$(adb shell getprop ro.product.model | tr -d '\r')"
[[ "$MODEL" == 'XP5900' ]] || { echo "ERROR: Expected Sonim XP5900, got $MODEL" >&2; exit 1; }

if [[ "${1:-}" == '--resume' ]]; then
  echo 'Reusing existing WebView and framework-res.apk copies for this run...'
  for apk in google-webview.apk framework-res.apk; do
    [[ -s "$TMP/$apk" ]] || {
      echo "ERROR: $TMP/$apk missing or empty; rerun without --resume" >&2
      exit 1
    }
  done
else
  echo 'Pulling installed Google WebView APK...'
  WEBVIEW_REMOTE="$(adb shell pm path com.google.android.webview | tr -d '\r' | sed -n 's/^package:\(.*\/base\.apk\)$/\1/p' | head -1)"
  [[ -n "$WEBVIEW_REMOTE" ]] || { echo 'ERROR: Google WebView base.apk not found' >&2; exit 1; }
  if ! adb pull "$WEBVIEW_REMOTE" "$TMP/google-webview.apk"; then
    echo 'ADB pull failed; retrying through root...'
    adb exec-out su -c "cat '$WEBVIEW_REMOTE'" > "$TMP/google-webview.apk"
  fi

  # Collect framework-res.apk from exact phone firmware to avoid SDK framework skew.
  echo 'Pulling Sonim framework-res.apk...'
  if ! adb pull /system/framework/framework-res.apk "$TMP/framework-res.apk"; then
    adb exec-out su -c 'cat /system/framework/framework-res.apk' > "$TMP/framework-res.apk"
  fi
fi

echo 'Verifying Google WebView APK signature...'
"$BT/apksigner" verify --min-sdk-version 30 --max-sdk-version 30 --print-certs-pem \
  "$TMP/google-webview.apk" > "$TMP/webview-certs.txt"
python3 "$ROOT/extract_signer_cert.py" "$TMP/webview-certs.txt" "$TMP/google-cert.b64"
# extract_signer_cert.py already verifies that the full DER certificate's
# SHA-256 matches apksigner's signing-certificate fingerprint for API 30.
# Do not parse a hard-coded "Signer #1" line here: apksigner also emits
# "V3.0 Signer:" and "Signer (minSdkVersion=..., maxSdkVersion=...)" labels.
# Do not confuse "Source Stamp Signer" with the APK signing certificate.

mkdir -p "$TMP/res/xml" "$TMP/module/system/product/overlay"
CERT="$(tr -d '\n\r' < "$TMP/google-cert.b64")"
cat > "$TMP/res/xml/config_webview_packages.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<webviewproviders>
  <webviewprovider packageName="com.android.webview"
      description="Sonim AOSP WebView (safe fallback)" availableByDefault="true" />
  <webviewprovider packageName="com.google.android.webview"
      description="Google WebView from Play" availableByDefault="true">
    <signature>${CERT}</signature>
  </webviewprovider>
</webviewproviders>
EOF
cat > "$TMP/AndroidManifest.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="org.sonim.webview.provider.overlay"
    android:versionCode="1" android:versionName="1.0">
    <uses-sdk android:minSdkVersion="29" android:targetSdkVersion="30" />
    <overlay android:targetPackage="android" android:isStatic="true"
        android:priority="10" />
    <application android:hasCode="false" android:label="Sonim Google WebView Provider" />
</manifest>
EOF

echo 'Compiling signed static RRO...'
"$BT/aapt2" compile --dir "$TMP/res" -o "$TMP/compiled.zip"
"$BT/aapt2" link -I "$TMP/framework-res.apk" --manifest "$TMP/AndroidManifest.xml" \
    --min-sdk-version 29 --target-sdk-version 30 \
    -o "$TMP/unsigned.apk" "$TMP/compiled.zip"
"$BT/zipalign" -f -p 4 "$TMP/unsigned.apk" "$TMP/aligned.apk"
# Persist the overlay signing key across re-runs (not related to Google's key).
if [[ ! -f "$OUT/sonim-overlay-signing.jks" ]]; then
  keytool -genkeypair -keystore "$OUT/sonim-overlay-signing.jks" \
    -alias sonimrro -keyalg RSA -keysize 2048 -validity 3650 \
    -storepass changeit -keypass changeit \
    -dname 'CN=Sonim Local RRO, OU=Personal, O=Local, L=Local, ST=Local, C=US' >/dev/null
fi
"$BT/apksigner" sign --ks "$OUT/sonim-overlay-signing.jks" \
    --ks-pass pass:changeit --key-pass pass:changeit \
    --ks-key-alias sonimrro --min-sdk-version 29 \
    --out "$TMP/module/system/product/overlay/SonimWebViewConfigOverlay.apk" "$TMP/aligned.apk"
"$BT/apksigner" verify --min-sdk-version 29 "$TMP/module/system/product/overlay/SonimWebViewConfigOverlay.apk"
cat > "$TMP/module/module.prop" <<'EOF'
id=sonimwebviewrro
name=Sonim Google WebView Provider (RRO)
version=1.3
versionCode=4
author=Locally built for Sonim XP5900
description=Allows Play-installed Google WebView as optional provider; leaves stock AOSP WebView intact.
EOF

# Package only the module files. No app, system property or installer scripts.
python3 - "$TMP/module" "$OUT/sonim-google-webview-rro-magisk.zip" <<'PY'
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root, dest = map(Path, sys.argv[1:])
with ZipFile(dest, 'w', ZIP_DEFLATED) as zf:
    for file in sorted(root.rglob('*')):
        if file.is_file():
            zf.write(file, file.relative_to(root))
print('Built:', dest)
PY

echo
echo 'Installation: Magisk -> Modules -> Install from storage -> select ZIP -> reboot.'
echo 'Then verify: adb shell dumpsys webviewupdate'
echo 'To select: adb shell cmd webviewupdate set-webview-implementation com.google.android.webview'
echo 'Do NOT disable com.android.webview until successful switching and testing.'
