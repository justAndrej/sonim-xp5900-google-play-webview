# Публичные источники

- Официальная установка LiteGapps через Magisk: https://litegapps.github.io/doc/installation.html
- LiteGapps download: https://litegapps.github.io/download
- Фиксированный LiteGapps arm64 Android 11 (2026-07-09) — исходный SHA256: https://github.com/litegapps/litegapps/releases/tag/lite-build-20260709-3
- Официальная регистрация несертифицированного Android / custom ROM: https://www.google.com/android/uncertified/
- Chromium WebView providers, требования Android к пакетам и подписям: https://chromium.googlesource.com/chromium/src/+/main/android_webview/docs/webview-providers.md
- AOSP Runtime Resource Overlays: https://source.android.com/docs/core/runtime/rros

**Статус:** установка WebView через RRO builder v4, OEM-аутентификатор, split APK и флаги touchscreen — отчёт об успешной работе на **одном** Sonim XP5900 с Android 11, а не независимые испытания на других устройствах. При выпуске обновления Google WebView могут измениться требования/подписи, поэтому builder читает актуальный установленный APK при каждой сборке.
