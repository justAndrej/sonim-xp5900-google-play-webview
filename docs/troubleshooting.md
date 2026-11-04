# Частые ошибки и что уже пробовали

| Симптом | Проверенное действие / причина |
|---|---|
| Выбор Google-аккаунта сразу закрывается; `AuthenticatorException: null bundle returned` | В исследованной прошивке OEM-аутентификатор из `com.android.synccontact` перехватывал `type=com.google`; отключили **только компонент** с root. |
| FCM работает, но Google Chat показывает `SERVICE_INVALID (9)` и «Play Store is missing» | Переустановили все split APK **уже установленного** Play Store через `adb install-multiple -r --force-queryable ...`. |
| Telegram/WhatsApp не видны в Play Маркете, `am get-config` показывает `notouch` | Отдельный `faketouch` не помог. Добавили одновременно `android.hardware.touchscreen` и `android.hardware.faketouch`; реального сенсорного ввода это не даёт. |
| В поиске Play Маркета «устройство не сертифицировано», «не авторизован», «Something went wrong» | Регистрация **GSF ID** на официальном сайте Google, в **том же аккаунте**, который используется на устройстве, помогла в нашем случае. Сертификация Play Protect при этом не предоставляется. |
| `content query` для GSF сообщает `Permission Denial: READ_GSERVICES` | Нормально для ADB shell. Скрипт `get-gsf-id.sh` читает `gservices.db` с root и SQLite на Mac, с удалением локальных временных файлов. |
| `sqlite3: inaccessible or not found` внутри Sonim | Ожидаемо: Android shell не содержит `sqlite3`; используется встроенный модуль sqlite3 в Python 3 на Mac. |
| `wm size`/`wm density` не меняют список доступных приложений | Эти команды не создают PackageManager feature-флаги. |
| Google WebView установлен, но активен AOSP 83 | OEM разрешал только `com.android.webview`. Сборщик из `webview/` создаёт RRO для добавления Google WebView как второго провайдера. |
| Сборщик сертификата v1–v3 отвергал Google WebView | На Mac `apksigner` печатал `V3.0 Signer:` и отдельно `Source Stamp Signer:`. Используем проверенный на этом устройстве парсер **v4**. |

**Не повторять без причины:** `adb shell pm clear com.android.vending`, `pm clear com.google.android.gms`, `pm clear com.google.android.gsf`; это может нарушить работающее состояние несертифицированной конфигурации. Не удалять старый AOSP WebView.

**Варианты отката:** см. [README](../README.md). Если вы ещё не загрузились после установки RRO, отключите модуль в Magisk. Для недоступного UI при работающем root ADB модуль можно отключить созданием файла `disable` в `/data/adb/modules/<id>/` и перезагрузкой.
