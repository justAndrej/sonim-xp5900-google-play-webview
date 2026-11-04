# Sonim XP5900 WebView RRO builder — v4

**Fix:** `apksigner` on the user's Mac reports `V3.0 Signer: certificate SHA-256 digest: ...`, plus a **different** `Source Stamp Signer` digest. v4 recognizes the real APK signer, ignores the source stamp, and validates the entire DER certificate against the application signer SHA-256 before constructing the overlay.

**No root or device changes occur during build.** The RRO mechanism is still unverified on this firmware. Keep the stock AOSP WebView intact.

## New run (pull APKs from device)

```sh
bash build-on-mac.sh
```

## Resume without downloading 243 MB again

If a previous version's `out/work` already contains `google-webview.apk` and `framework-res.apk`, copy them:

```sh
mkdir -p out/work
cp ../sonim-rro-kit-v3/out/work/{google-webview.apk,framework-res.apk} out/work/
bash build-on-mac.sh --resume
```

The relative `cp` command assumes the v3 and v4 folders are siblings. Otherwise, supply their actual paths. `--resume` still runs `apksigner verify` with Android API 30 and validates the certificate; it only skips re-downloading the files.

Build output: `out/sonim-google-webview-rro-magisk.zip`.

After a successful build, install through Magisk and reboot. Inspect first:

```sh
adb shell cmd overlay list | grep -Ei 'sonim|webview'
adb shell dumpsys webviewupdate
```

Proceed to select Google WebView **only if** it appears as a Valid package in `dumpsys webviewupdate`:

```sh
adb shell cmd webviewupdate set-webview-implementation com.google.android.webview
```

No guarantee of compatibility on stock Sonim firmware: Android 11 enforces RRO rules, so an installed overlay may be rejected. If rejected, collect `cmd overlay list`, `dumpsys overlay`, and WebView diagnostics rather than disabling the stock provider.

To disable module if necessary (requires ADB root):

```sh
adb shell su -c 'touch /data/adb/modules/sonimwebviewrro/disable'
adb reboot
```
