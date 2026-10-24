# StackCard — комплект Android release

Подготовка релиза отложена пользователем2026-10-24; Phase20 заменена на
[полный аудит](../product/product-spec.md#phase-20--полный-аудит-проекта).
Этот guide сохраняет уже подготовленную процедуру для будущего отдельного
поручения. AAB не принят: последняя попытка остановилась на stripping native
debug symbols. Наличие конфигурации и материалов не означает готовую сборку или
публикацию в Google Play. История проверок —
[release preparation](../product/evidence/release-preparation-2026-10-24/checks.json).

## Подпись и сборка

Утверждённый Android ID — `dev.snownumb.stackcard`; Firebase app —
`1:713694392116:android:50154e562d3b3b7d233f61`. Новый API key ограничен этим
package, release/debug SHA-1 и11 Firebase API; AI/Gemini исключены. Legacy
`com.example.app_stackcard` и его key сохранены. Это отдельная установка: local
guest data старого ID автоматически не мигрируют; приложение не удалять.

После официального FlutterFire configure сверять native/Dart public key.
В этой среде CLI вернул legacy shared key и для нового appId. Для отдельного
нового key используется воспроизводимый generator; `--key-file` — ответ
Google API Keys `getKeyString` для нового ограниченного key, не OAuth token:

```zsh
# Согласовать generated Android options с новым key, не меняя legacy/iOS
python3 tools/release/configure_android_firebase.py \
  --package dev.snownumb.stackcard \
  --app-id 1:713694392116:android:50154e562d3b3b7d233f61 \
  --key-file /absolute/private/path/public-android-key.json
```

Команда выполняется из корня monorepo и отказывает при чужом appId/неверной форме
ключа до изменения файлов. После неё — Dart format, analyze и native build.
Не расширять старый key и не убирать API/application restrictions ради генерации.

Android release использует отдельный upload keystore. `android/key.properties`
либо файл из `STACKCARD_ANDROID_KEY_PROPERTIES` содержит поля из
[образца](../../apps/mobile/android/key.properties.example). Реальный файл,
пароли и keystore хранятся вне Git с правами0600, каталог —0700.
Пароли не передавать аргументами команд и не печатать в логах. Не заменять
существующий ключ: следующий APK должен иметь ту же подпись. Независимую
защищённую резервную копию ключа и паролей хранит владелец; копия на том же
диске не защищает от потери компьютера.

Команды из `apps/mobile`, macOS zsh/bash. `STACKCARD_ANDROID_KEY_PROPERTIES`
указывает на существующий приватный файл; значение — путь, не пароль.

```zsh
# Проверить точные зависимости и исходники перед выпуском
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub

# Собрать AAB с Dart obfuscation и отдельными символами
flutter build appbundle --release --obfuscate \
  --split-debug-info=build/release-symbols/aab

# Собрать APK для прямой проверки на Android с той же signing configuration
flutter build apk --release --obfuscate \
  --split-debug-info=build/release-symbols/apk
```

Результаты — `build/app/outputs/bundle/release/app-release.aab` и
`build/app/outputs/flutter-apk/app-release.apk`. Каждый набор symbols относится
к своей точной сборке/ABI. Сохранить также R8 mapping из
`build/app/outputs/mapping/release`, SHA256 artifacts, versionName/versionCode,
application ID и fingerprint сертификата. Хранить binaries/symbols отдельно от
keystore; symbols и mapping не включать в публичный релиз или GitHub CI artifacts.
Obfuscation скрывает имена; она не защищает секреты внутри приложения.

Первый release после integration/debug tests запускать со штатным pub step:
Flutter3.47 исключает dev plugins из release Gradle graph, и устаревший
`GeneratedPluginRegistrant.java` иначе может ссылаться на integration_test.
Не исправлять generated Java вручную. После переключения обратно к native
integration tests также разрешить Flutter обновить registrant для debug.

Проверить подпись настоящего APK через Android SDK `apksigner verify --verbose
--print-certs`, AAB — JDK `jarsigner -verify`. Проверить отсутствие debuggable,
application ID, версию и permissions через `aapt2 dump badging/permissions`.
AAB не устанавливается напрямую. Для проверки его точных split APK использовать
официальный bundletool либо Play internal testing; APK companion — отдельная
проверенная сборка, а не доказательство установки AAB.

Release без credentials должен завершаться ошибкой `validateReleaseCredentials`;
debug/CI не требуют release secrets. Предыдущий debug APK нельзя обновить
release-подписью того же ID: не удалять приложение с пользовательскими данными
ради установки. Использовать отдельное тестовое устройство/профиль.

## Материалы на русском

**Название:** StackCard

**Краткое описание:** Портфолио разработчика: проекты, редактор и PDF в одном приложении.

**Полное описание:**

StackCard помогает собрать портфолио разработчика из профиля, навыков,
реализованных проектов, опыта и образования.

- Одно основное портфолио и три раздела: «Главная», «Проекты», «Редактор».
- Главная показывает сохранённую версию; изменения редактора сохраняются явно.
- Библиотека проектов с технологиями и ссылками на репозиторий и продукт.
- Просмотр публичных GitHub-репозиториев и явный выбор проектов для добавления.
- Ручной ввод города и страны, фото профиля из камеры или галереи.
- PDF из сохранённого портфолио с поддержкой русского текста.
- Гостевой черновик на устройстве; сохранённые данные аккаунта синхронизируются.
- Светлый русский интерфейс. Первичное заполнение можно пропустить.

Публичная ссылка, Developer Card/QR, обращения и push требуют подключённого
сервиса. В текущем локальном комплекте постоянный сервер публикации и обращений
не подключён: эти действия показывают недоступность. Сохранение не публикует
портфолио автоматически. Приложение не запрашивает геопозицию.

Отчёты Firebase Crashlytics выключены по умолчанию и включаются отдельно в
настройках. Analytics не подключён. Политика и ограничения отзыва копий доступны
в помощи приложения; web-источник — `/help#privacy` текущего сайта. До публичного
store-выпуска владелец должен предоставить действующий публичный HTTPS URL этой
политики и контакт поддержки; localhost и GitHub Actions URL их не заменяют.

**Что нового в первом комплекте:** одно основное портфолио, библиотека проектов,
явный Save, PDF, ручной город и приватная opt-in диагностика.

Screenshots брать из фактически проверенного приложения с синтетическими данными:
сохранённая Главная, библиотека проектов, редактор и настройки приватности.
Не использовать старые dark/GPS/multiple-document экраны или изображение
публичной ссылки как обещание работающего сервера. Снимки Simulator/emulator
подписывать как такие; они не доказывают проверку физического телефона.

## Перед store-размещением

Владелец отдельно подтверждает developer account, application ID, release
версию, support contact, публичную privacy policy и допустимый канал.
Play App Signing разделяет upload key и ключ, которым Google подписывает
установки. Зарегистрировать fingerprint фактической app-signing подписи в
Firebase/OAuth/API key restrictions; upload certificate не заменяет её.
Не ослаблять ограничения ключей ради входа Google или Firebase.

Data safety заполнить по фактическому runtime и SDK: account email/UID,
выбранные поля портфолио/контакты/фото, crash/device/installation metadata при
opt-in и обращения при подключённом сервисе. Город — текст пользователя,
доступа к GPS нет. Отсутствие Analytics не означает отсутствие сбора данных.
Не заявлять, что приложение полностью анонимно. Account deletion и её
recovery зависят от trusted API; его отсутствие — блокер обещания полного
удаления данных в публичном store-выпуске.

Internal track/Google Play/App Distribution не создаются автоматически.
Публичные download links добавляются только после проверенной публикации;
до неё `/download` сохраняет честное состояние без ссылки на установку.

## iOS

iOS — самостоятельная проверка: Xcode/SPM build, system PDF picker
(сохранение/отмена), Share/Open, реальные permissions и APNs на устройстве.
Simulator build не доказывает APNs, подпись или App Store готовность.
Для App Store нужны Apple developer team, сертификат/provisioning profile,
Bundle ID, App Store Connect metadata/privacy labels и разрешение владельца
на загрузку. Новые аккаунты, платная подписка и принятие соглашений не входят
в автоматическую подготовку комплекта.

Источники процедуры: [Flutter Android release](https://docs.flutter.dev/deployment/android),
[Dart obfuscation](https://docs.flutter.dev/deployment/obfuscate) и
[Android app signing](https://developer.android.com/studio/publish/app-signing).
