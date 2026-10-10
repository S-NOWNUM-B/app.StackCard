<div align="center">

# Разработка StackCard

**Процесс работы, проверки и правила внесения согласованных изменений**

![Contributing guide](https://raster.shields.io/badge/Contributing-guide-09090B?style=for-the-badge)
![Scope mobile web publication](https://raster.shields.io/badge/Scope-mobile_web_publication-C7FF1A?style=for-the-badge)

</div>

---

## Содержание

- [Что вносить](#что-вносить)
- [Процесс работы](#процесс-работы)
- [Требования к изменениям](#требования-к-изменениям)
- [Быстрый старт](#быстрый-старт)
- [Firebase configuration и окружение](#firebase-configuration-и-окружение)
- [Web и document publication](#web-и-document-publication)
- [Основные команды](#основные-команды)
- [Проверки](#проверки)
- [Коммиты](#коммиты)
- [Pull Requests](#pull-requests)

---

## Что вносить

Phase 0–6 завершены; отдельно разрешённая Phase 8 — Firestore sync — завершена.
Account session/actions, auth guards и UID isolation введены на Phase 7;
Google flow, полный password reset и iOS приёмка остаются открытыми.
Phase 8 добавила local-first sync и подготовила atomic publication repository;
Phase 9 завершена: явный GitHub import/review/ignore сохраняет ручные overrides;
Phase 10 завершена: детерминированные подсказки объясняют причины и явные действия;
Phase 11 реализована с открытой device/live приёмкой; Phase 12 разрешена без карты,
с ручным городом/страной и optional geolocation.
статус и результаты проверок находятся в
[product spec](docs/product/product-spec.md#статус-и-границы-текущей-работы).
С 2026-10-07 пользователь поставил последовательную очередь фаз на паузу и
разрешил функциональную mobile работу по Figma/концепции общей базы и документов.
[План](docs/product/product-spec.md#план-разработки) сохраняет историю и acceptance;
действующий scope — в product status и
[исключении общих правил](docs/AI/AGENTS.md#разработка-по-плану).
D048 (2026-10-08) явно разрешает mobile/web/document publication перенос.
Deploy/billing/commit/push не выполняются автоматически. Последующий явный
ответ «Да, выполнить визуальную проверку web/mobile» разрешает D048 browser/
native/preview checks; headless checks не доказывают live/Figma acceptance.

<div align="center">

| **Направление** | **Допустимые изменения сейчас** |
|:---|:---|
| Документация | Уточнение сценариев, границ, источников и способов работы |
| Mobile UI и storage | Builder/preview, ручные и импортированные проекты, private notes, GitHub Import/review/ignore с offline copy и app settings |
| Mobile authentication | Firebase email/password, registration/reset, Google sign-in, session restoration/sign out; именованные защищённые routes и явный guest/UID draft transfer |
| Sync и publication | Hive7/cloud6, durable outbox/exact ACK/LWW; trusted document publication с permanent ID, privacy/media/delete lifecycle и deny client public writes |
| Web | Next.js landing/download/Auth/UID owner editors и anonymous /d/[publicId], совместимый cloud6 model; online-first Save/CAS и publication API |
| Mobile state и architecture | Provider для ThemeMode/Locale/preferences; Riverpod для repository loading/actions, DI и filters; pure Dart contracts и data adapters, учебные patches вне runtime |
| Структура | Согласование путей, ignore rules и общего AI-контекста |
| Brand assets | Сохранение оригиналов и описания их применения |

</div>

В `apps/mobile` реализованы UI foundation и Repository/DI границы
для Android/iOS с GoRouter: до создания Builder core-портфолио использует demo/mock sources,
GitHub Import читает public API через Dio и сохраняет ответы с ETag/Link в Hive.
Cache имеет hard TTL 7 дней и проверяется сетью при каждом чтении; fallback
доступен при network/timeout/server failure с явной датой последней проверки.
Отдельный draft хранит PortfolioContent и приватные заметки. Home/document libraries/Projects/Settings
читают working aggregate. Независимые Resume/Portfolio хранят snapshots секций
и Library relations; plain `resumeText` остаётся legacy-compatible. Scoped Save
сохраняет документ/проект/базу без соседнего unsaved ввода;
прочитанные данные не добавляются автоматически в curated-портфолио.
В `apps/web` находится отдельный Next.js runtime; manifests/lockfile/env принадлежат
этому приложению. `firebase/functions` владеет trusted publication HTTP handler.
Firebase Auth остаётся account boundary; Firestore sync не вызывает Publish.
Legacy username adapter сохранён, но новые Rules закрывают его client writes.
Document actions используют только confirmed inventory/permanent URL.

---

## Процесс работы

### 1. Определить область изменения

Начни с [README](README.md), [общих правил](docs/AI/AGENTS.md) и
[AI router](docs/AI/README.md). Для mobile прочитай
[scope rules](docs/AI/scopes/mobile.md), для Rules/emulators —
[Firebase scope](docs/AI/scopes/firebase.md). Затем прочитай
[план разработки](docs/product/product-spec.md#план-разработки) и действующий
capability scope. Соотнеси задачу с её критериями готовности, установи статус,
владельца контракта и конкретный проверяемый результат.

### 2. Изучить источники и сделать локальное изменение

Перед реализацией открой затронутые code/config и ближайший аналог.
Версии и зависимости проверяй в manifests/lockfiles. Разделяй работу на
небольшие самостоятельные шаги; сначала используй существующий механизм.

Auth/profile/projects/github_import/portfolio_draft используют `presentation/domain/data`; DI связывается у
корня feature. Domain остаётся pure Dart; concrete repositories не импортируются
widgets. Между features используй публичные barrels. `PortfolioOverview` —
presentation read model обзора. Чистый Builder domain принадлежит `portfolio_draft`;
этот feature владеет единственным записываемым repository и app-session controller.
В GitHub Import data слой владеет Dio, DTO mapping, Link pagination и ETag
validators и versioned cache; controller — загрузкой, refresh, локальным debounce
и обработкой typed failures. Settings contracts и app-level состояние находятся
в нейтральном `core/state`; data adapter пишет один version 1 snapshot через
SharedPreferencesAsync. Bootstrap восстанавливает настройки, открывает отдельные
Hive boxes и настраивает Firebase Auth/Firestore до создания `StackCardApp`.
Account SDK изолирован в data; guest/UID draft factory выбирается через DI.
Account adapter сохраняет локально и отправляет durable outbox отдельно;
whole-document LWW и private/public схема описаны в
[ADR 0001](docs/decisions/0001-firestore-sync-and-publication.md).
Storage, network failures и rate-limit
deadline проверяются через подменяемые repositories, cache и clock.
Подробное направление зависимостей — в
[architecture](docs/architecture/architecture.md#mobile-modules--при-реальных-сценариях).

Flutter/Dart-команды выполняются в `apps/mobile`; Git — из корня monorepo.
Нативные платформы mobile — Android и iOS, для iOS-разработки нужен macOS host.
Установку и запуск описывает [быстрый старт](#быстрый-старт).

### 3. Обновить документы и проверить результат

Изменение пути, команды, контракта или устойчивого правила сопровождается
обновлением затронутых links и guides в той же задаче. AI-контекст хранится
в `docs/AI/`, рабочие configs остаются рядом с кодом. Решение с последствиями
для нескольких областей фиксируй в [ADR](docs/decisions/README.md).

Выполни проверки по затронутому поведению и просмотри фактический diff.
Сообщи выполненные проверки и ограничения среды; наличие файла или успешный
link check не доказывают правильность его содержания.

Обнови фактический прогресс и результаты проверок в product spec. Перед завершением
фазы сверь все её критерии готовности; оставшиеся задачи и непроверенные сценарии
укажи явно. Следующую фазу начинай после завершения текущей и подтверждения
пользователя; прямое поручение на неё считается подтверждением.

---

## Требования к изменениям

- одна задача и понятный scope без unrelated правок;
- существующие архитектура, naming и визуальный стиль сохраняются;
- новые зависимости добавляются только при использовании в текущей фазе;
- native configs Android/iOS и generated-file ownership сохраняются;
- документы отделяют готовое поведение от целевых решений и планов;
- локальные caches, builds, SDK paths, signing keys и secrets не попадают в Git;
- чужие изменения не удаляются и не включаются в свой commit автоматически.

---

## Быстрый старт

Установи Flutter stable с Dart, удовлетворяющим `environment.sdk` в pubspec.
Для Android нужны Android SDK, JDK и эмулятор/устройство; для iOS — macOS и Xcode.
Точные проблемы окружения покажет `flutter doctor -v`.

macOS — zsh/bash, из корня репозитория:

```sh
cd apps/mobile
flutter --version
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <device-id>
```

`<device-id>` замени ID Android-устройства/эмулятора или iOS-устройства/симулятора
из `flutter devices`. Android — первый release target; iOS также входит в scope.
Открывай `apps/mobile`, если IDE не обнаруживает Flutter-проект в корне monorepo.

Native запуск открывает auth screen: email/password, registration, reset,
Google sign-in либо явно выбранный локальный guest-режим.
Configuration и готовность способов входа описаны [ниже](#firebase-configuration-и-окружение).
Private routes доступны account или local guest; до начала Builder core-портфолио
использует демонстрационные данные. Legacy «Открыть демо» сохранён только в
preview/tests `StackCardApp` без native account configuration.
Кнопка «GitHub Import» на Projects открывает
`/github-import`: отправка username загружает публичный профиль и repositories.
Поиск работает по уже загруженным данным с debounce 300 ms; «Загрузить ещё»
читает следующую страницу из Link. Ошибки повторяются только по действию
пользователя; rate-limit deadline блокирует сетевой retry до разрешённого времени.
В Настройках сохраняются dark/light/system, Русский/English и показ source
descriptions. Переведены UI и сообщения; пользовательские и GitHub тексты
остаются исходными. В Портфолио «Локальные заметки» открывают `/portfolio-draft`:
явное сохранение переживает перезапуск, несохранённый ввод — только навигацию
текущей session. «Открыть Builder» позволяет заполнить профиль, списки и Resume,
добавить ручной проект, изменить featured/видимость и порядок блоков. Preview читает
рабочий ввод; Save сохраняет всё портфолио и notes в namespace текущего владельца.
Settings позволяет явно перенести сохранённый guest draft в account при наличии
сети и пустом local/cloud draft. Cloud claim проверяется transaction; при сбое
source сохраняется для повтора тем же UID, существующие remote данные не заменяются.
Sign out с несохранёнными правками требует подтверждения; durable draft остаётся
у своего UID, settings/cache сохраняются. Account draft синхронизируется через
Firestore с pending/synced/error и retry; guest остаётся local-only. Remote update
не отбрасывает unsaved ввод. Поздний server commit может заменить draft другого
устройства целиком; sync не публикует портфолио. Web-редактор вводится на своей фазе.

---

## Firebase configuration и окружение

Native composition находится в
[LocalRuntime](apps/mobile/lib/app/local_runtime.dart), запуск с account adapter —
в [main.dart](apps/mobile/lib/main.dart). По умолчанию используется generated dev
configuration: `projectId` и app identifiers берутся из
[firebase_options.dart](apps/mobile/lib/firebase_options.dart) и
[firebase.json](apps/mobile/firebase.json), Android — из
[google-services.json](apps/mobile/android/app/google-services.json), iOS — из
[GoogleService-Info.plist](apps/mobile/ios/Runner/GoogleService-Info.plist).
Android/iOS apps зарегистрированы; эти файлы обновляются FlutterFire CLI,
а runtime initialization остаётся обычным кодом. Generated identifiers не являются
service-account secrets; credentials, signing keys и SDK paths в Git не добавляются.
Порядок генерации описан в [официальном Flutter setup](https://firebase.google.com/docs/flutter/setup).

Для обновления configuration нужны Firebase CLI с доступом к выбранному dev
project и FlutterFire CLI. На macOS для iOS generation используется Ruby
`xcodeproj`; установленный generator не заменяет Xcode/CocoaPods для сборки.
Если FlutterFire CLI отсутствует, установи его через `dart pub global activate flutterfire_cli`.
macOS — zsh/bash, из `apps/mobile`; `<project-id>` замени значением canonical
`projectId` и выбирай существующие Android/iOS apps:

```sh
firebase login
dart pub global run flutterfire_cli:flutterfire configure --project="<project-id>" --platforms=android,ios
```

Команда меняет generated/native configuration; после неё проверь diff и совпадение
application ID/bundle ID с существующими приложениями. Packages Auth уже есть
в pubspec; повторно добавлять зависимости ради генерации не нужно.

В dev Firebase Console включён Email/Password. Для нового окружения включи его
в Authentication → Sign-in method по
[password-auth guide](https://firebase.google.com/docs/auth/flutter/password-auth).
Google provider подготовлен, но сохранение provider в Console требует выбранного
project support email; live Google flow пока не подтверждён.
Для Android зарегистрирован debug SHA-1. На другой машине или для другого
signing certificate получи fingerprint и добавь его к соответствующему Firebase
app; Google provider должен быть включён, а config после этого обновлён.
Требования — в [Google authentication guide](https://firebase.google.com/docs/auth/flutter/federated-auth#google).
macOS — zsh/bash, из `apps/mobile`:

```sh
./android/gradlew -p android signingReport
```

Для отдельно запущенного Auth Emulator runtime принимает необязательные
`FIREBASE_AUTH_EMULATOR_HOST` и `FIREBASE_AUTH_EMULATOR_PORT` через `--dart-define`.
Host задаётся без протокола и port; port по умолчанию — 9099. Для Android
emulator, обращающегося к сервису на host machine, используется `10.0.2.2`.
Настройка самого сервиса — в [Auth Emulator guide](https://firebase.google.com/docs/emulator-suite/connect_auth).
macOS — zsh/bash, из `apps/mobile`, после запуска emulator service:

```sh
flutter run -d "<android-id>" --dart-define=FIREBASE_AUTH_EMULATOR_HOST=10.0.2.2 --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9099
```

Без host define app использует Firebase project из generated options. Emulator
проверки не подтверждают настоящий Google consent/account picker.
Приложение не сохраняет password/token в Hive или preferences; восстановление
account session выполняет Firebase SDK. App settings/public GitHub cache
не зависят от UID, а draft изолирован в guest/UID namespaces.

Firestore Rules/indexes и Emulator Suite configuration находятся отдельно в
[firebase](firebase/); [ADR 0001](docs/decisions/0001-firestore-sync-and-publication.md)
задаёт private account/draft, public snapshot и LWW. Native runtime принимает
`FIRESTORE_EMULATOR_HOST` и `FIRESTORE_EMULATOR_PORT` через `--dart-define`;
host задаётся без протокола/port. Явно передавай port из
[firebase/firebase.json](firebase/firebase.json): default SDK define может
отличаться от project emulator port. Это отдельный сервис от Auth Emulator.

Для отдельной local development session запусти сервис с generated project ID;
это emulator namespace, не deployment. macOS — zsh/bash, из корня репозитория:

```sh
cd firebase
firebase emulators:start --only firestore --project stackcard-dev-snownumb
```

macOS — zsh/bash, в другом терминале из `apps/mobile`, после запуска Firestore Emulator Suite;
пример использует текущий port из canonical config:

```sh
flutter run -d "<android-id>" --dart-define=FIRESTORE_EMULATOR_HOST=10.0.2.2 --dart-define=FIRESTORE_EMULATOR_PORT=8085
```

Auth Emulator defines можно добавить к этой команде, если отдельно запущен и
настроен Auth Emulator. Без Firestore host define SDK использует dev database
generated project. Firebase billing upgrade не нужен для текущего dev setup
и автоматически не выполняется. Rules и native команды — в
[разделе проверок](#firestore-rules-и-native-sync-acceptance).

Android — доступный target текущей среды. iOS configuration сгенерирована, но
native iOS build/приёмка недоступны при неполном Xcode и отсутствии CocoaPods;
проверяй фактический toolchain через `flutter doctor -v`.

---

## Contact/Inbox/FCM — Phase 14

Data/privacy contract — [ADR 0004](docs/decisions/0004-contact-inbox-notifications.md).
Новые collections не меняют draft schema; account deletion удаляет Inbox/device
subcollections и UID-owned global token bindings.

Web [.env.example](apps/web/.env.example): `NEXT_PUBLIC_CONTACT_INBOX_API_URL`
для `contactInbox` и `NEXT_PUBLIC_APP_CHECK_SITE_KEY` для зарегистрированного
reCAPTCHA Enterprise Essentials App Check web provider (бесплатный Spark).
Backend [.env.example](firebase/functions/.env.example):
exact `PUBLIC_WEB_ORIGIN` и intended `CONTACT_APP_CHECK_APP_ID` того же web app.
`CONTACT_RATE_HMAC_KEY` (≥32 символа) — private server env, не public env/репозиторий.
Live дополнительно требует App Check token-consumption Token Verifier IAM
permissions и отдельно развёрнутых Rules/indexes, Node API и Next.js web.
`roles/firebaseappcheck.tokenVerifier` требуется именно runtime principal ADC;
обычная `roles/owner` не заменяет это право. Временный grant личному owner для
live-теста снимается после проверки. Постоянный backend требует своего
согласованного runtime principal с этим правом; без него submit закрывается.
Cloud Functions/App Hosting/Storage/Firestore TTL live запрещены Spark-only правилом.
`src/index.mjs` остаётся demo Functions adapter; живой сервер — `src/server.mjs`.
С private standard ADC (`GOOGLE_APPLICATION_CREDENTIALS`, не Git), explicit
`GCLOUD_PROJECT`, `BACKEND_PORT`, origin/appId/HMAC из `.env.example`,
macOS zsh/bash, cwd `firebase/functions`: `npm start`. Сервер слушает loopback;
HTTPS обеспечивает собственный reverse proxy или временный tunnel. `/health`
проверяет запуск; API paths — `/contactInbox` и `/documentPublication`.
Не создавайте service account keys для теста, когда есть стандартные user ADC.
Без bucket доступен text-only Publish; media операции и account delete
отклоняются до irreversible writes. Quick Tunnel — только dev acceptance,
его случайный URL нужно зарегистрировать в App Check и web/native env,
после остановки он не обеспечивает live availability.
[Firebase replay protection](https://firebase.google.com/docs/app-check/custom-resource-backend#replay_protection_beta)
описывает consumed limited-use проверку; обычный reusable token не заменяет её.
Отсутствующая конфигурация закрывает submit. Demo bypass ограничен actual Functions
emulator + demo project, не произвольным client flag или production project.

Canonical indexes включают collection-group `publications.publicId` для private
lookup и отключённое индексирование visitor PII/FCM tokens.
`contactRateLimits.expiresAt` не включает платную TTL policy; фиксированные windows
определяет server clock. Истёкшие rate docs остаются до отдельной доверенной
maintenance очистки; контролируйте бесплатную Firestore storage quota.

Mobile получает `CONTACT_INBOX_API_URL` через Dart define; adapter принимает HTTPS,
demo HTTP только при demo Firebase app+Auth emulator configuration. Firebase Messaging
native auto-init выключен до явного разрешения владельца. Settings показывает
реальные permission/registration/cleanup states; permission denied не скрывает Inbox.
Pending backend revoke сохраняется в памяти controller до ACK; успешный SDK
deleteToken не стирает его. После смены аккаунта retry может требовать вход в
прежний account. Только failure local SDK/consent cleanup блокирует новый enable;
неподтверждённый backend revoke остаётся видимым и после явного enable нового UID.
FCM live setup требует действующего Firebase Android app и устройства с Google Play
services; для iOS — Xcode signing, Push Notifications capability/aps entitlement,
APNs key в Firebase и физического устройства. Наличие manifest/entitlement не
подтверждает delivery. [Firebase Flutter receive](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages)
задаёт permission, foreground, background/terminated tap scenarios.

macOS zsh/bash, cwd `firebase/functions`: `npm run check` и `npm test`.
macOS zsh/bash, cwd `firebase`: `npm run test:all-rules` запускает actual SDK Rules/
service tests; focused `npm run test:contact` использует только Firestore emulator.
Не запускайте эти тесты поверх browser fixtures: они очищают demo Firestore.
Для локального browser сценария, macOS zsh/bash, cwd `firebase`:

```zsh
PUBLIC_WEB_ORIGIN=http://127.0.0.1:3000 firebase emulators:start --only auth,firestore,storage,functions --project demo-stackcard-test
```

Web запускается с отдельной demo config из `.env.example`, обоими HTTP endpoint
URLs, emulator flag и local origin. Secret/real App Check/FCM transport для demo
не требуются; notification trigger в demo не отправляет live FCM. Web проверки —
`typecheck`, `test`, `format:check`, `build` из `apps/web` (macOS zsh/bash).
Mobile проверки — format/analyze/tests из `apps/mobile` по существующему gate.
Live submit вызывает sender после durable commit без облачного trigger; matching
retry не дублирует transport с receipt, ошибка push сохраняет Inbox.
Live acceptance проверяет валидное обращение в обоих Inbox, чужой UID, отказ/
revocation permissions, token refresh, delivery/tap из background и terminated,
смену UID во время enable/cleanup и сохранение Inbox при transport failure.
Emulator и fake messaging tests не заменяют этот gate; deploy в разрешённом scope,
billing upgrade запрещён.

Opt-in native Inbox acceptance использует только именованные SDK apps с `demo-`
project и localhost/Android host, не default/live session. Подготовьте temporary
define JSON вне Git: `RUN_INBOX_EMULATOR_ACCEPTANCE=true`, `INBOX_EMULATOR_PROJECT`,
`INBOX_EMULATOR_HOST`, `INBOX_AUTH_EMULATOR_PORT`, `INBOX_FIRESTORE_EMULATOR_PORT`,
`INBOX_OWNER_EMAIL/PASSWORD` из disposable demo account и `INBOX_REQUEST_ID`
обращения, принятого trusted HTTP. Для обязательной проверки двух страниц нужны
минимум 51 exact-contract records в этом demo Inbox; тестовые extras создаются
только emulator Admin fixture. Эти параметры не являются live credentials.
macOS zsh/bash, cwd `apps/mobile`, при запущенных demo эмуляторах и Android:

```zsh
flutter test integration_test/inbox_runtime_test.dart -d "<android-id>" --no-pub --no-uninstall --dart-define-from-file="<temporary-demo-defines.json>"
```

Тест проверяет actual Dart SDK server reads/cursor/readAt, foreign/anonymous
denial и UID guards. `--no-uninstall` сохраняет данные приложения; после тестового
APK восстановите обычный debug APK через build и `adb install -r`, не uninstall.

Отдельный opt-in [native permission test](apps/mobile/integration_test/notification_permission_runtime_test.dart)
проверяет mapping настоящего Android `POST_NOTIFICATIONS` через Firebase SDK.
Он не запрашивает permission, не получает/удаляет FCM token, не читает Auth/draft
и требует выключенный auto-init. Используйте только dev Android 13+; перед
изменением разрешения сохраните его granted/flags из `adb shell dumpsys package`
и после проверки восстановите исходное состояние. Для локального эмулятора с
исходным `granted=false`, без `user-set/user-fixed` и прежних SDK permission requests,
macOS zsh/bash, cwd `apps/mobile`:

```zsh
flutter test integration_test/notification_permission_runtime_test.dart -d "<android-id>" --no-pub --no-uninstall --dart-define=RUN_NOTIFICATION_PERMISSION_ACCEPTANCE=true --dart-define=NOTIFICATION_EXPECTED_PERMISSION=notDetermined
adb -s "<android-id>" shell pm grant com.example.app_stackcard android.permission.POST_NOTIFICATIONS
flutter test integration_test/notification_permission_runtime_test.dart -d "<android-id>" --no-pub --no-uninstall --dart-define=RUN_NOTIFICATION_PERMISSION_ACCEPTANCE=true --dart-define=NOTIFICATION_EXPECTED_PERMISSION=authorized
adb -s "<android-id>" shell pm revoke com.example.app_stackcard android.permission.POST_NOTIFICATIONS
adb -s "<android-id>" shell pm set-permission-flags com.example.app_stackcard android.permission.POST_NOTIFICATIONS user-set
flutter test integration_test/notification_permission_runtime_test.dart -d "<android-id>" --no-pub --no-uninstall --dart-define=RUN_NOTIFICATION_PERMISSION_ACCEPTANCE=true --dart-define=NOTIFICATION_EXPECTED_PERMISSION=denied
adb -s "<android-id>" shell pm clear-permission-flags com.example.app_stackcard android.permission.POST_NOTIFICATIONS user-set user-fixed
flutter build apk --debug --no-pub
adb -s "<android-id>" install -r build/app/outputs/flutter-apk/app-debug.apk
```

Если любой шаг неуспешен, всё равно восстановите permission и обычный APK.
Эта проверка не заменяет ручной отказ в системном prompt, live delivery/tap или
controller resume/UID scenarios; последние отдельно проверяются regression tests.

Opt-in [live FCM test](apps/mobile/integration_test/notifications_live_runtime_test.dart)
использует default Messaging SDK, отдельные named Auth/Firestore apps и disposable
accounts. Если есть прежний default push consent, тест останавливается до изменений.
`RUN_NOTIFICATION_LIVE_ACCEPTANCE=true`, `NOTIFICATION_LIVE_RUN_ID` (32 hex),
`NOTIFICATION_LIVE_STAGE` (`foreground`, `background`, `terminated`, `foreign`,
`denied`; `revoked` отдельно), `NOTIFICATION_LIVE_MESSAGE`, `CONTACT_INBOX_API_URL`
и `STACKCARD_PUBLICATION_API_URL` передаются временным define JSON вне Git.
macOS zsh/bash, cwd `apps/mobile`: `flutter build apk --debug --no-pub --target
integration_test/notifications_live_runtime_test.dart --dart-define-from-file="<temporary-live-defines.json>"`.
Установка только `adb install -r -t`, без uninstall/clear и автоматического `-g`.

Private cache `stackcard-phase14-live-<runId>/<stage>.json` содержит только metadata.
Host после `owner-created` создаёт исключительно проверенному новому test UID
active root generation0 и canonical schema6 saved text-only document по указанным
`documentId`/`sourceMutationId`, затем пишет `<stage>.command=fixture-ready`.
Test сам выполняет authenticated Publish с RAM-only ID token. После `ready/armed`
выполнить настоящую отправку public формы; её actual requestId по owner/exact message
записать в `<stage>.request-id` (32 hex), не подменять browser-generated ID.
Для `denied` дополнительно command `inbox-submitted`; для `foreign` — `switch-owner`,
проверенный disposable B fixture и `foreign-fixture-ready`.

Принять только `status=passed` с confirmed actual SDK event, exact server message,
`sdkTokenDeleted`, отсутствием `backendCleanupPending`, `isolatedSessionsClosed`,
`defaultSessionPreserved` и `defaultConsentPreserved`. Background tap нажимает
настоящее tray notification; cold проверка требует Home → `am kill` (не force-stop)
→ FCM → настоящее нажатие, новый processId и `getInitialMessage`. Compiled standalone
APK выбран для process recreation; killed Flutter runner не выдаётся за PASS.
После теста удалить только собственные disposable cloud fixtures/bindings, вернуть
обычный APK/исходные permission flags; временные URLs не доказывают stable hosting.

## Web и document publication

D048 связывает [web](apps/web/README.md),
[trusted functions](firebase/functions/package.json) и mobile тем же Firebase
проектом. Runtime values хранятся в env/config; private content не передаётся
SSR/public props. Подробный data/lifecycle contract - в
[architecture](docs/architecture/architecture.md#privatepublic-schema-и-явная-публикация).

Для установки и headless checks нужен Node, совместимый с обоими manifests;
Functions используют Node22. macOS zsh/bash, cwd `apps/web`:

```zsh
npm ci
npm run format:check
npm run typecheck
npm test
npm run build
```

Для server handler, macOS zsh/bash, cwd `firebase/functions`:

```zsh
npm ci
npm run check
npm test
```

`check` проверяет синтаксис server modules; `test` проверяет actual contract/
security fixtures. Tests, требующие Emulator Suite, запускаются только по
предусловиям actual scripts; unit/fake tests не доказывают production deployment.
Полный emulator gate: macOS zsh/bash, cwd `firebase`, `npm run test:all-rules`
запускает Auth/Firestore/Storage и весь test glob, включая Rules и Admin-SDK
publication service integration. Для focused service: `npm run test:service`;
Rules-only: `npm run test:rules` (Firestore), `npm run test:storage` (Storage).
`next build` не запускает browser/device и не подтверждает visual parity.

Web setup: скопировать [.env.example](apps/web/.env.example) в локальный
`.env.local` и заполнить public Firebase web app configuration того же проекта,
`NEXT_PUBLIC_PUBLICATION_API_URL` и настоящий `NEXT_PUBLIC_WEB_ORIGIN`.
Public config не является service-account credential; tokens/passwords не
записываются приложением. Для demo emulators включить
`NEXT_PUBLIC_USE_EMULATORS=true`, адреса/порты согласовать с
[firebase.json](firebase/firebase.json). Live и emulator services не смешивать.
Неполная конфигурация показывает unavailable/configuration state, не fake data.

Functions [.env.example](firebase/functions/.env.example) задаёт
`PUBLIC_WEB_ORIGIN`: exact origin без trailing slash/path, например настоящий
origin настроенного web. Browser CORS разрешает только его. Live требует HTTPS;
локальный HTTP принимается только emulator mode. URL endpoint получается от
отдельно настроенного handler, production domain здесь не выдумывается.

Mobile использует Dart define `STACKCARD_PUBLICATION_API_URL` при разрешённом
build/run. `LocalRuntime` фиксирует UID и перепроверяет Auth session после
асинхронного получения ID token. Missing endpoint отключает publication adapter;
guest сохраняет local-only доступ. Durable request journal сохраняется отдельно
по UID до POST; unknown/pending/reopen разрешаются через тот же operation ID.
`SharedPreferencesDocumentPublicationOperationStore` и account deletion journal
не содержат password/token/public draft copy. Save/sync остаются отдельными.
`SharedPreferencesAccountDeletionJournal` также сохраняет случайный 256-bit
recovery key до подтверждённого результата. После утраты Auth ограниченный
`deletionStatus` продолжает только прежнюю operation; server хранит hash key.
Local journal очищается после подтверждения captured UID.

`npm run dev`/`npm start` находятся в web manifest для обычной локальной работы;
D048 browser/native/preview checks разрешены последующим явным ответом
пользователя; результаты запуска фиксируются в product spec. Историческое
no-preview/run не переопределяет это разрешение.
Deploy Functions/Rules/web и billing требуют отдельного поручения. Generated
native AppIcon assets не доказывают выполненный build/device acceptance.

Для воспроизводимой проверки pinned native AppIcons после `npm ci` в
`firebase/functions`, macOS zsh/bash, cwd корень monorepo:

```zsh
SHARP_MODULE_ROOT="$PWD/firebase/functions/node_modules" node tools/redesign/export_native_icons.mjs --check
```

`--check` ничего не переписывает: сверяет source hash, existing Android/iOS PNG,
размеры/alpha и [ledger](docs/redesign/source/native-app-icons.json). Без `--check`
script заменяет только существующие AppIcon exports и ledger; original SVG и
splash не меняются. iOS output opaque RGB, фон исходный #070708.

---

## Основные команды

macOS — zsh/bash, команды выполняются из `apps/mobile`:

<div align="center">

| **Команда** | **Назначение** |
|:---|:---|
| `flutter pub get` | Разрешить зависимости приложения |
| `flutter doctor -v` | Проверить Flutter и нативные toolchains |
| `flutter devices` | Получить доступные target IDs |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | Проверить форматирование |
| `flutter analyze` | Статический анализ Dart |
| `flutter test` | Проверить состояние, UI-сценарии, адаптивность, контраст и touch targets |

</div>

Проверки запускай по затронутому поведению. Порядок и ограничения описаны в
[разделе проверок](#проверки).

Секреты, service-account keys, signing keys и локальные SDK paths в Git не попадают.
Firebase/env contract описан в [разделе configuration](#firebase-configuration-и-окружение).

---

## Проверки

Перед полным Flutter suite установите зависимости web через `npm ci` в
`apps/web` и обеспечьте Node из его manifest. Cross-client test
`web_workspace_contract_test.dart` запускает actual TypeScript helpers через
установленный `tsx`, затем Dart cloud codec и обратный web parser. Новых сервисов,
эмуляторов или production credentials для этого contract test не требуется.

Для изменения Flutter UI сначала разреши зависимости, затем проверь
формат, анализ и значимое поведение. macOS — zsh/bash; Windows — WSL/Ubuntu.
Рабочая директория — `apps/mobile`:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

Ожидаются успешный exit code, отсутствие ошибок анализа и прошедшие tests.
`test/widget_test.dart` проверяет legacy preview-вход без native configuration,
переходы и возврат, поиск проектов,
предпросмотр, смену темы, UI states и клавиатуру. `test/responsive_test.dart`
проверяет шесть экранов в двух темах на размерах телефона и планшета, portrait/landscape,
включая узкий экран и удвоенный текст. При обычном масштабе проверяются контраст
текста и touch targets; это автоматические проверки, не полный accessibility audit.
`test/appearance_controller_test.dart` проверяет начальную тему и уведомления,
`test/project_filters_test.dart` — правила поиска, сочетания фильтров и срок жизни.
`test/state_management_test.dart` проверяет общую тему, system brightness,
сохранение query/filter при навигации, синхронизацию поля и новую app session.
`test/auth_repository_test.dart`, `test/profile_repository_test.dart` и
`test/projects_repository_test.dart` проверяют contracts, чистые правила и
immutable данные. Соответствующие `auth_di_test.dart`, `profile_di_test.dart`,
`projects_di_test.dart` подменяют источник в Settings, DeveloperProfile и проекциях
рабочей базы через
`StackCardApp.providerOverrides`, проверяют loading/error/empty и явный retry.
`test/github_data_test.dart` проверяет DTO, HTTP failures, Link pagination и
условные ETag-запросы; `test/github_import_controller_test.dart` — debounce,
retry deadline, отмену, конкурирующие запросы и сохранение результатов.
`test/github_import_widget_test.dart` проверяет GitHub Import на реальном экране
с подменяемым источником, включая refresh, pagination и UI states.
`test/github_persistence_test.dart` проверяет реальный Hive reopen, hard TTL,
schema/corruption, offline fallback, reconnect/304, ошибки storage и отмену.
`test/local_storage_test.dart` проверяет раздельные boxes, backup повреждённого
cache-файла, сохранность повреждённого draft и закрытие draft при cache close failure.
`test/local_runtime_widget_test.dart` проверяет runtime reopen, безопасный startup
retry, source notice и reconnect UI.
`test/settings_persistence_test.dart` и `test/localization_test.dart` проверяют
snapshot restore, очередь записей/retry, ru/en UI и увеличенный текст.
`test/portfolio_draft_repository_test.dart`, `test/portfolio_draft_controller_test.dart`
и `test/portfolio_draft_widget_test.dart` проверяют saved notes, revisions,
сохранность ввода при ошибках, unknown schema и экран локального draft.
Builder domain/repository tests проверяют validation/completion, schema v1–v6→v7
и сохранность private notes/documents; controller/forms/preview/integration tests проверяют
CRUD, рабочее состояние, сохранение и единые проекции. Визуальные проверки
Builder находятся в `test/portfolio_builder_visual_test.dart`.
`test/portfolio_suggestions_test.dart` проверяет pure rules с заданным временем,
границы активности, ignore, stable IDs и отсутствие мутаций.
`test/portfolio_suggestions_provider_test.dart` проверяет working edits и
account/guest/UID boundaries без записи; `test/portfolio_suggestions_widget_test.dart`
проверяет объяснения ru/en, Preview/editor actions и responsive UI.
Account tests находятся в `test/firebase_auth_repository_test.dart`,
`test/firebase_auth_controller_test.dart`, `test/firebase_auth_google_test.dart`,
`test/account_auth_ui_test.dart`, `test/account_navigation_test.dart`,
`test/account_draft_transfer_widget_test.dart` и `test/local_draft_accounts_test.dart`.
Они проверяют SDK mapping/typed failures, session/guest access, именованные
guarded/nested routes, UID transitions, explicit transfer и real Hive recovery.
Заменяемые SDK sources и widget tests не доказывают live auth или iOS readiness.

### Native Firebase Auth acceptance

[integration_test/account_runtime_test.dart](apps/mobile/integration_test/account_runtime_test.dart)
запускается отдельно и только с opt-in define и `--no-uninstall`, чтобы runner
не удалял приложение и локальные данные после проверки. Он обращается к generated dev
Firebase project, требует уже signed-out development device, создаёт один
synthetic `.invalid` account и удаляет его в cleanup. Password генерируется
в памяти, credentials не пишутся в файлы и не выводятся. Проверяются registration,
email sign-in, rejection неверного password, session stream и sign out;
затем native bootstrap открывает реальную форму account auth, а явный guest
переход открывает локальную app shell.
Reset проверяет принятие запроса SDK/backend; `.invalid` address не позволяет
проверить доставку письма. Это не Google flow; restart restoration запускается отдельно двумя шагами ниже.
macOS — zsh/bash, из `apps/mobile`, после `flutter devices`:

```sh
flutter test integration_test/account_runtime_test.dart -d "<android-id>" --no-uninstall --dart-define=RUN_FIREBASE_AUTH_ACCEPTANCE=true
```

Ожидаются успешный результат и удаление disposable account. При аварийном
прерывании проверь его cleanup в dev Console. Обычный `flutter test` запускает
`test/`; opt-in native suite не включается автоматически. Результаты запуска,
Google flow, фактического restart восстановления и iOS проверок фиксируются
отдельно в product spec; наличие теста не считается пройденной приёмкой.

Для native SDK session restore используй два последовательных запуска на том же
signed-out dev device, без удаления app data между ними. `seed` создаёт disposable
account и намеренно оставляет его session; `check` в новом процессе проверяет
восстановленный user до любого sign-in и удаляет только account из тестового
namespace. Обязательно завершай пару запусков; password/token не передаются между
процессами. Seed даёт SDK две секунды на асинхронную запись до forced-stop
тестового runner; это ожидание относится только к тесту. macOS — zsh/bash,
из `apps/mobile`:

```sh
flutter test integration_test/account_runtime_test.dart -d "<android-id>" --no-uninstall --dart-define=RUN_FIREBASE_AUTH_ACCEPTANCE=true --dart-define=FIREBASE_AUTH_RESTORE_PHASE=seed
flutter test integration_test/account_runtime_test.dart -d "<android-id>" --no-uninstall --dart-define=RUN_FIREBASE_AUTH_ACCEPTANCE=true --dart-define=FIREBASE_AUTH_RESTORE_PHASE=check
```

При прерывании пары disposable account остаётся в dev project; завершай `check`
на том же устройстве. Проверка не читает и не очищает пользовательский Hive draft.

### Firestore Rules и native sync acceptance

Rules tests имеют отдельный npm manifest/lockfile в [firebase](firebase/).
Нужны Node, удовлетворяющий `engines` в [package.json](firebase/package.json),
Firebase CLI и Java для Firestore Emulator. Launcher использует demo project
и canonical emulator config, не подключается к live database. macOS — zsh/bash,
из корня репозитория:

```sh
cd firebase
npm ci
npm run test:rules
```

`test:rules` запускает Firestore Emulator, затем `npm run test:firestore` с client SDK Rules
contexts и завершает сервис. Отдельный `npm test` требует уже запущенный emulator
и корректный `FIRESTORE_EMULATOR_HOST`. Проверяются owner access, foreign/anonymous
denial, public exact get/list denial, direct client public write denial,
no-downgrade, deleted-document tombstones и account deletion lock. Trusted
projection/CAS/media/operation handler проверяется отдельной functions suite. Результаты запуска фиксируются в product spec;
наличие tests не подтверждает успешную приёмку.

Для разрешённого dev deployment сначала выполни Rules tests, проверь project
и diff Rules/indexes. Команда ниже — процедура deployment, не часть обычных
проверок документации; выполнять только при авторизованной настройке окружения.
macOS — zsh/bash, из `firebase`, target указан явно:

```sh
firebase deploy --only firestore:rules,firestore:indexes --project stackcard-dev-snownumb
```

Opt-in [native sync suite](apps/mobile/integration_test/firestore_runtime_test.dart)
проверяет настоящий Android Firebase SDK на dev database после deployment Rules.
Unique named Firebase apps и отдельный временный Hive storage сохраняют ordinary
app session/draft. Suite создаёт disposable `phase8.*@example.invalid` accounts;
cleanup удаляет только их UID draft/auth records и test directory. Проверяются
offline local Save/reopen, reconnect/server ACK, более поздний commit второго
клиента и owner/foreign/anonymous private access. Public snapshot suite не создаёт.
Phase 9 дополнительно проверяет stable GitHub ID, source metadata/overrides,
повторный импорт и явный review после offline/reopen/server ACK.
macOS — zsh/bash, из `apps/mobile`, на development emulator:

```sh
flutter test integration_test/firestore_runtime_test.dart -d emulator-5554 --no-uninstall --dart-define=RUN_FIRESTORE_SYNC_ACCEPTANCE=true
```

`--no-uninstall` обязателен: integration runner по умолчанию удаляет приложение
и его локальные данные после tests. Для другого dev device замени ID после
`flutter devices`. Guard допускает только dev project; credentials генерируются
в памяти, не выводятся и не сохраняются приложением.

Полный process restart проверяется двумя последовательными запусками.
`seed` сохраняет pending draft без сети и disposable session; `check` в новом
процессе восстанавливает SDK session/outbox до sign-in, подтверждает sync и
выполняет cleanup. Pair использует отдельный persistent test storage; ordinary
app storage не очищается. Заверши оба запуска на одном устройстве без удаления
app data. macOS — zsh/bash, из `apps/mobile`:

```sh
flutter test integration_test/firestore_runtime_test.dart -d emulator-5554 --no-uninstall --dart-define=RUN_FIRESTORE_SYNC_ACCEPTANCE=true --dart-define=FIRESTORE_RESTORE_PHASE=seed
flutter test integration_test/firestore_runtime_test.dart -d emulator-5554 --no-uninstall --dart-define=RUN_FIRESTORE_SYNC_ACCEPTANCE=true --dart-define=FIRESTORE_RESTORE_PHASE=check
```

Если пара прервана, disposable account/test storage остаются до завершения
`check` на том же устройстве. Emulator Rules, mocked Dart SDK, live Android и
iOS acceptance — разные проверки; результаты не заменяют друг друга.
Legacy prepared publication repository не определяет D048 public API и новые
Rules не разрешают его writes. Document UI/handler source не означает deployment
или выполненную production публикацию пользователя.

### Location и native acceptance

Phase 12 использует ручной город/страну и optional geolocator/native geocoding,
без карты, Maps API keys и Maps billing. Контракт — в
[architecture](docs/architecture/architecture.md#выбор-города-и-страны--phase-12).
Android manifest запрашивает только `ACCESS_COARSE_LOCATION`, iOS Info.plist —
`NSLocationWhenInUseUsageDescription`; background updates не включаются.
При отказе, timeout, отсутствии locality/country или сбое native geocoder
работает ручной ввод. Native geocoding может требовать сеть; это не поиск
по каталогу городов, не гарантированный offline resolver и не отдельный HTTP API.

macOS — zsh/bash, cwd `apps/mobile`, focused checks:

```zsh
flutter test --no-pub test/location
```

Opt-in [location_runtime_test.dart](apps/mobile/integration_test/location_runtime_test.dart)
проверяет настоящий SDK и, для granted, отдельный Hive test storage после reopen
и city-only public projection. Обычные account/draft не очищаются;
`--no-uninstall` сохраняет данные приложения. До запуска подготовить состояние
permissions/location services на dev device. `granted` требует разрешение,
location services, доступный fix и native geocoder; `serviceDisabled` — выключенные
services; `denied` — отказ в появившемся системном dialog; `permanentlyDenied` —
запрет в OS. Не подменять отсутствующий native fix mocked координатами.

```zsh
flutter test --no-pub integration_test/location_runtime_test.dart -d emulator-5554 --no-uninstall --dart-define=RUN_LOCATION_ACCEPTANCE=true --dart-define=LOCATION_SCENARIO=manual
flutter test --no-pub integration_test/location_runtime_test.dart -d emulator-5554 --no-uninstall --dart-define=RUN_LOCATION_ACCEPTANCE=true --dart-define=LOCATION_SCENARIO=granted
flutter test --no-pub integration_test/location_runtime_test.dart -d emulator-5554 --no-uninstall --dart-define=RUN_LOCATION_ACCEPTANCE=true --dart-define=LOCATION_SCENARIO=serviceDisabled
```

После проверки восстановить прежние OS settings. SDK test не подтверждает
системный permission dialog, работу всего picker или process restart;
widget/unit checks и Android/iOS device acceptance фиксируются отдельно в product spec.
`manual` проверяет настоящий picker без вызова геолокации, подтверждение и
city-only Hive/public payload. После integration runner вернуть обычный entrypoint
через `flutter run --no-pub -d emulator-5554 --no-resident`, без uninstall.

### Media Storage и native acceptance

Phase 11 использует `features/media`, Storage paths в private draft и
[Storage Rules](firebase/storage.rules). Контракт/cleanup —
[ADR 0003](docs/decisions/0003-private-portfolio-media.md). Live Cloud Storage
требует Blaze и созданный bucket; generated Firebase options содержит имя
bucket, но это само по себе не доказывает его существование. Billing upgrade
и deployment не выполняются автоматически. Перед live запуском после отдельного
разрешения должны быть deployed и Storage Rules, и обновлённые Firestore Rules
(private schema 6). Старые writers после нового schema update получат отказ.

macOS — zsh/bash, cwd `firebase`, для локальной проверки без billing:

```sh
npm run test:all-rules
```

`test:storage` проверяет Storage отдельно; `test:rules` — прежние Firestore tests.
Для native SDK acceptance сначала запустить demo Auth/Storage emulators.
macOS — zsh/bash, cwd `firebase`:

```sh
firebase emulators:start --only auth,storage --project demo-stackcard-test
```

macOS — zsh/bash, второй терминал, cwd `apps/mobile`, Android emulator:

```sh
flutter test integration_test/media_runtime_test.dart -d emulator-5554 --no-uninstall --dart-define=RUN_MEDIA_ACCEPTANCE=true
```

Named Firebase apps используют только demo namespace и не меняют обычный
app session/draft. Этот тест проверяет native upload/read/progress и отказ
foreign/unauthenticated SDK; он не открывает camera/gallery системный UI.
Android debug network config допускает HTTP только к `10.0.2.2`, `127.0.0.1`
и `localhost`; release не получает это исключение.
В native app composition Storage emulator включается через
`STORAGE_EMULATOR_HOST` и `STORAGE_EMULATOR_PORT`; Android host `10.0.2.2`,
port — из [firebase.json](firebase/firebase.json). Auth/Firestore defines
настраиваются отдельно; не смешивать emulator и live services случайно.

Обязательная ручная приёмка: avatar и project image через camera/gallery,
cancel без потери формы, отказ permissions, progress/retry после network
failure, Apply → Save → restart → отображение и UID change во время upload.
iOS требует проверки camera/photo permissions из Info.plist на доступном
нативном устройстве. JPEG/PNG/WebP supported; HEIC выдаёт validation failure.
Private image cache memory-only, public внешние avatars кешируются пакетом
cached_network_image. Потерянный picker result после process death не
применяется автоматически: выбор повторить. Новые отменённые uploads очищаются
best effort; прежние saved paths сохраняются для offline/LWW, server GC нет.

### Остальные focused и visual проверки

Для review общей базы, macOS zsh/bash, cwd `apps/mobile`:

```zsh
flutter test --no-pub test/portfolio_document_base_review_test.dart test/portfolio_document_base_review_widget_test.dart test/portfolio_document_editor_test.dart test/portfolio_documents_persistence_test.dart
```

Проверяются сохранение local overrides и порядка, Apply/Cancel/Save/reopen,
legacy без baseline, raw backups, UID transition и stale captured base. Rules
проверяются отдельной командой `npm run test:rules` из `firebase`, включая все
20 документов с baseline. Headless результаты не доказывают visual/native или
live sync нового payload. D048 visual/browser/native checks разрешены
последующим явным ответом пользователя; результаты и ограничения среды отдельно.

Для сфокусированной проверки storage и настроек из той же директории:

```sh
flutter test test/github_persistence_test.dart test/local_storage_test.dart test/local_runtime_widget_test.dart test/settings_persistence_test.dart test/localization_test.dart test/portfolio_draft_repository_test.dart test/portfolio_draft_controller_test.dart test/portfolio_draft_widget_test.dart
```

Сравнение подходов и проверка сохранённых учебных вариантов — в
[state management guide](docs/learning/state-management.md).
Учебные patches применяются независимо к временным копиям текущего проекта;
они сохраняют Repository/DI и меняют только механизм темы. Цель coverage
из roadmap относится к Phase 17.

Снимки для визуальной сверки сохраняются в `docs/design/previews`; это результаты
рендеринга Flutter. Чтобы обновить их после согласованного изменения UI,
из той же директории в zsh/bash:

```sh
flutter test test/responsive_test.dart --dart-define=UPDATE_UI_PREVIEWS=true --update-goldens
```

Для сравнения с существующими PNG без их обновления убери `--update-goldens`.

Перед приёмкой просмотреть снимки всех пяти экранов в обеих темах и ориентациях;
обновление PNG само по себе не подтверждает качество дизайна. Нативный запуск
проверяется отдельно на доступном Android/iOS target.

Для применения форматирования, тот же терминал и директория:

```sh
dart format lib test integration_test
```

Для правки только документации проверь local links, anchors, соответствие TOC
заголовкам и отображение Markdown. Flutter tests без изменения кода не требуются.
При изменении архитектурной схемы обнови Mermaid-исходник в `docs/diagrams/`
и его PNG вместе. Изображение должно сохранять узлы, направления и подписи связей
исходника; проверь читаемость схемы и badges в используемом preview.
Actual web/functions commands и env описаны в
[Web и document publication](#web-и-document-publication).

---

## Коммиты

Commit и push выполняются только по запросу пользователя. До staging проверь
status и diff; добавляй явные пути текущей задачи и повторно просмотри staged diff.

Действующий формат — `type(scope): description`: type/scope на английском,
lowercase; описание на русском, lowercase, без точки, с глаголом в прошедшем
времени и объяснением изменения. Body обязателен: отдельный пункт для каждого
созданного, изменённого, удалённого или переименованного файла.

После clone включи нативный [commit-msg hook](.githooks/commit-msg), чтобы Git
проверял body и пути даже при коммите из Desktop/IDE. Требуется Python 3 в PATH.
macOS zsh/bash или Windows Git Bash, cwd корень monorepo:

```sh
git config --local core.hooksPath .githooks
```

Для `amend` используй `STACKCARD_COMMIT_MODE=amend` только перед этой командой;
полный пример, правила и тесты — в [Git workflow](docs/AI/GIT_WORKFLOW.md#нативный-commit-msg-hook).

При подключённом remote синхронизируй через rebase/autostash. После конфликтов
проверь сохранность локальных изменений и повтори релевантные проверки.
Не обходи hooks ради завершения операции.

---

## Pull Requests

При работе через PR описание должно объяснять проблему,
получившееся поведение, выполненные проверки и существенные ограничения.
Сохраняй размер одной задачи; актуальный diff должен позволять проверить выводы.
CI ещё не настроен: его проверки вводятся на соответствующей фазе.
