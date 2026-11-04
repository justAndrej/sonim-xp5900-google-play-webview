# Sonim XP5900 (XP5plus) — Google Play & modern WebView

[Русский](README.md) · **Community guide, not an official Sonim/Google product**

Инструменты и воспроизводимая инструкция для **Sonim XP5900 ROW, Android 11 (API 30), arm64, Magisk/root**: установка LiteGapps, устранение проблем входа в Google, нормальная установка приложений из Play Маркета и переход с WebView 83 на Google WebView 156+. Тестировалось на одном XP5900. На XP5700/XP5800, других прошивках и Android-версиях не проверялось.

## Требования

- Рабочая загрузка Android, Magisk/root, резервная копия важных данных и возможность восстановить телефон.
- Mac/Linux (или адаптация команд под Windows), ADB из Android Platform Tools, Python 3. При необходимости сборки WebView — Android SDK Build Tools и Java `keytool`.
- **Не очищайте данные** `com.android.vending`, `com.google.android.gms`, `com.google.android.gsf` без продуманного плана восстановления. На исследованном Sonim очистка данных Play Маркета привела к ошибкам авторизации и баннеру о несертифицированном устройстве.

## Короткая инструкция

1. **LiteGapps:** скачайте **arm64 + Android 11** с [сайта проекта](https://litegapps.github.io/download) и установите ZIP через **Magisk → Модули → Установить из хранилища**, перезагрузитесь. Для воспроизводимости есть **пример фиксированной официальной Lite-сборки**: `bash scripts/download-litegapps.sh` (сверяет SHA-256 с релизом разработчика; это *не обязательно та же версия*, которая применялась в исходном эксперименте). ZIP третьей стороны не распространяется в этом репозитории. Для переноса проверенного ZIP в папку Downloads телефона можно вызвать `bash scripts/stage-litegapps.sh out/downloads/LiteGapps-arm64-11.0-20260709-official.zip` (скрипт НЕ устанавливает модуль).
2. Проверка: `bash scripts/check-device.sh`. Должны существовать `com.google.android.gms`, `com.google.android.gsf`, `com.android.vending`.
3. **Google-аккаунт не добавляется?** На исследованной прошивке сторонний OEM-аутентификатор `com.android.synccontact` перехватывал `type=com.google`. Посмотрите `bash scripts/disable-oem-google-authenticator.sh --status`; если компонент совпадает, запустите `bash scripts/disable-oem-google-authenticator.sh --apply`, затем повторите добавление Google-аккаунта. Команда отключает *только компонент*, не весь пакет. Отмена: `--undo`.
4. **Google Chat пишет `requires the Google Play Store, but it is missing` / `SERVICE_INVALID (9)`?** При наличии установленного Play Маркета сохраните все его APK/split APK: `bash scripts/backup-playstore-splits.sh`; затем `bash scripts/reinstall-playstore-splits.sh out/playstore-backup --apply`. Перестановка **полного набора APK с `--force-queryable`** помогла на исследованном устройстве. Не используйте APK из случайных источников и не выкладывайте бэкап в GitHub.
5. **Play Маркет скрывает приложения из-за `notouch`?** Создайте модуль: `bash scripts/build-touchscreen-module.sh`. Установите `out/sonim-xp5900-touchscreen-magisk.zip` в Magisk и перезагрузите. Он объявляет `android.hardware.touchscreen` и `android.hardware.faketouch`; **настоящий сенсорный экран не появляется**. Один только `faketouch` в нашем опыте не помог. Проверка: `adb shell pm list features | grep -E 'touchscreen|faketouch'`.
6. **Несертифицированное устройство:** получаем собственный GSF ID командой `bash scripts/get-gsf-id.sh`, затем регистрируем его на [официальной странице Google](https://www.google.com/android/uncertified/) **в аккаунте, который настроен на Sonim**. В нашем опыте регистрация под другим аккаунтом не помогла, а под тем же — восстановила функции Play Маркета. Это не делает телефон официально сертифицированным. Перезагрузитесь, проверьте установку Google Chat, Telegram, WhatsApp.
7. **Современный WebView для Via:** установите `com.google.android.webview` из Google Play. Если `adb shell dumpsys webviewupdate` по-прежнему показывает `com.android.webview, 83.x`, соберите Magisk RRO через `bash webview/build-on-mac.sh` (нужны SDK Build Tools + Java). Установите `webview/out/sonim-google-webview-rro-magisk.zip`, перезагрузите, убедитесь, что Google WebView отображается как `Valid package`, затем переключите его:

   ```bash
   adb shell cmd webviewupdate set-webview-implementation com.google.android.webview
   adb shell dumpsys webviewupdate
   adb shell am force-stop mark.via.gp
   ```

   На исследованном устройстве заработал Google WebView **156.0.8078.47**. **Не удаляйте заводской `com.android.webview`** — он нужен для отката. Сборщик сохраняет проверку настоящего APK-сертификата (для Android API 30) и не принимает `Source Stamp Signer` за подпись WebView.

## Каталог

```text
scripts/check-device.sh                    Read-only диагностика
scripts/download-litegapps.sh             Пример скачивания LiteGapps + SHA-256
scripts/stage-litegapps.sh                Передача ZIP в Download (без установки)
scripts/disable-oem-google-authenticator.sh  Изолированное исправление входа
scripts/backup-playstore-splits.sh        Backup APK/splits из телефона
scripts/reinstall-playstore-splits.sh     Повторная установка, требует --apply
scripts/get-gsf-id.sh                     Приватное чтение GSF ID для регистрации
scripts/build-touchscreen-module.sh       ZIP Magisk с feature-флагами
modules/touchscreen/                       Исходники touchscreen-модуля
webview/                                   Рабочий RRO builder v4
scripts/                                    Скрипты для Mac/Linux (Bash)
docs/4pda-post.bbcode                      Текст для 4PDA
tests/                                      Локальные тесты сборщика
```

## Проверка и откат

```bash
adb shell dumpsys webviewupdate
adb shell pm list features | grep -E 'touchscreen|faketouch'
# Вернуть старый WebView при проблемах:
adb shell cmd webviewupdate set-webview-implementation com.android.webview
# Отключить WebView RRO (после перезагрузки):
adb shell su -c 'touch /data/adb/modules/sonimwebviewrro/disable'
# Отключить декларацию сенсорного экрана:
adb shell su -c 'touch /data/adb/modules/sonim_touchscreen_test/disable'
adb reboot
```

Откат OEM-аутентификатора: `bash scripts/disable-oem-google-authenticator.sh --undo`. Не удаляйте работающий Play Маркет, Google Services Framework, Google Play Services и старый WebView при диагностике.

## Ограничения и источники

- Root, разблокированный загрузчик и старые исправления безопасности повышают риски безопасности. Успешная работа сервисов Google **не равна** Play Protect certification или прохождению Play Integrity.
- Проект содержит только свои скрипты, исходники overlay и XML feature declarations; **не содержит** APK Google, ключей подписи WebView, базы GSF, персональных данных или образов прошивки. MIT относится только к коду этого проекта.
- В WebView-архив сборщика входит **локально создаваемый** сертификат подписи RRO, а сертификат Google извлекается и проверяется во время сборки.
- Официальные источники: [LiteGapps installation](https://litegapps.github.io/doc/installation.html), [LiteGapps releases](https://github.com/litegapps/litegapps/releases), [Google uncertified devices](https://www.google.com/android/uncertified/), [Chromium WebView providers](https://chromium.googlesource.com/chromium/src/+/main/android_webview/docs/webview-providers.md), [AOSP overlays](https://source.android.com/docs/core/runtime/rros).

## Контрибьюции и проверка

```bash
for f in scripts/*.sh webview/build-on-mac.sh; do bash -n "$f"; done
python3 -m unittest discover -s tests -v
```

Скрипты проверены статически и unit-тестами без Sonim; **сквозная установка с нуля** на втором устройстве пока не тестировалась. Ранее успешный WebView builder v4 перенесён без изменения алгоритма подписи.
