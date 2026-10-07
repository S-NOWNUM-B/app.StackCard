<div align="center">

# StackCard Mobile

**Flutter-клиент для Android и iOS с мобильным редактором общего портфолио**

![Mobile Android + iOS](https://raster.shields.io/badge/Mobile-Android_%2B_iOS-09090B?style=for-the-badge)
![Stage Phase 11 in progress](https://raster.shields.io/badge/Stage-Phase_11_in_progress-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Назначение](#назначение)
- [Что хранится здесь](#что-хранится-здесь)
- [Типовые сценарии](#типовые-сценарии)
- [Локальная разработка](#локальная-разработка)
- [Правила](#правила)

---

## Назначение

Phase 11 добавляет приватные avatar/project images: camera/gallery, validation,
resize/compression, upload progress/retry и отображение по Storage path.
Guest остаётся local-only; Apply и Save отдельны. Контракт —
[ADR 0003](../../docs/decisions/0003-private-portfolio-media.md), setup и проверка —
[CONTRIBUTING](../../CONTRIBUTING.md#media-storage-и-native-acceptance);
фактическая приёмка — в product spec.

Мобильное приложение StackCard — самостоятельный редактор портфолио, который
будет использовать тот же аккаунт, draft и правила публикации, что и web.
Offline draft/cache и нативные функции относятся к мобильному клиенту.

GitHub Import загружает публичный профиль и repositories через Dio.
Hive сохраняет response cache с offline fallback и отдельный portfolio draft;
SharedPreferences — настройки приложения, UI переведён на ru/en.
Локальный Builder позволяет собрать профиль, ручные проекты и разделы,
выбрать порядок, видимость и тему блоков и посмотреть рабочий результат.
Home, Portfolio, Projects и Settings читают проекции этого draft; до начала
Builder показываются demo-данные. Общий app shell и Material 3 light/dark сохранены.
Phase 7 добавила Firebase Auth, защищённые именованные routes и изоляцию draft
по guest/UID. Native entry настраивает настоящий account adapter; локальный guest
доступ выбирается явно. Google flow, полный password reset и iOS приёмка остаются
открытыми. Отдельно разрешённая Phase 8 завершена: Firestore sync поверх local
Hive draft с durable outbox и pending/synced/error/retry. Publication repository
подготовлен для отдельного явного действия; public UI/web ещё не созданы.
Phase 9 завершена: явные Add/Review/Ignore для GitHub repositories проверены;
source metadata и ручные overrides сохраняются раздельно в том же draft.
Phase 10 завершена: read-only подсказки объясняют новый repository, обновления,
недостающие description/demo и кандидатов для featured. Владелец открывает
Preview или редактор и применяет изменения отдельно.
Последующие функции развиваются по roadmap;
статус и результаты проверок — в
[product spec](../../docs/product/product-spec.md#phase-10--portfolio-suggestions).
ThemeMode/Locale/preferences управляются Provider; product state, repository
loading и DI — Riverpod. Их границы и
учебная эволюция описаны в
[state management guide](../../docs/learning/state-management.md).
Сайт развивается отдельно в [apps/web](../web/README.md)
на Next.js; desktop и Flutter web targets в mobile не входят.

---

## Что хранится здесь

<div align="center">

| **Материал** | **Назначение** |
|:---|:---|
| [lib/main.dart](lib/main.dart) | Bootstrap, восстановление runtime до `StackCardApp`, ProviderScope и lifecycle GoRouter |
| [lib/app](lib/app/) | LocalRuntime composition, GoRouter и адаптивный app shell |
| [lib/core/state](lib/core/state/) | Нейтральные settings contracts и AppearanceController для ThemeMode/Locale/preferences через Provider |
| [lib/core/storage/local_storage.dart](lib/core/storage/local_storage.dart) | Hive boxes в Application Support, изоляция cache/draft и сохранность повреждённых файлов |
| [lib/core/localization](lib/core/localization/) | Согласованные UI-каталоги ru/en и Localizations delegate |
| [lib/core/theme](lib/core/theme/) | Утверждённая палитра, Material 3, typography, spacing/radius |
| [lib/shared/widgets](lib/shared/widgets/) | Используемые общие widgets, loading/error/retry и async view |
| [lib/features](lib/features/) | Auth/profile/projects/github_import/portfolio_draft: presentation/domain/data и public APIs; portfolio read model, Home и Settings |
| [lib/features/github_import/github_import.dart](lib/features/github_import/github_import.dart) | Публичный API GitHub Import; DI связывает repository, clock и response cache, native bootstrap подставляет Hive adapter |
| [lib/features/auth/auth.dart](lib/features/auth/auth.dart) | Account repository/user/typed failures, Firebase adapter, session/actions/explicit guest access; legacy demo API для preview/tests |
| [lib/features/portfolio_draft/portfolio_draft.dart](lib/features/portfolio_draft/portfolio_draft.dart) | Portfolio domain, validation/completion, repository, единый session controller, Builder/preview и private notes |
| [lib/features/portfolio_draft/data/local_draft_accounts.dart](lib/features/portfolio_draft/data/local_draft_accounts.dart) | Guest/UID namespaces, явный transfer, journal/generation и recovery |
| [lib/features/portfolio_draft/domain/portfolio_sync.dart](lib/features/portfolio_draft/domain/portfolio_sync.dart), [data/synced_portfolio_draft_repository.dart](lib/features/portfolio_draft/data/synced_portfolio_draft_repository.dart) | Pure sync contract и local-first wrapper: durable outbox, ACK, retry и remote hydration |
| [lib/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart](lib/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart), [data/hive_portfolio_sync_metadata_store.dart](lib/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart) | UID-bound SDK adapter и persistent sync metadata рядом с draft envelope |
| [lib/features/portfolio_draft/data/firestore_portfolio_publication_repository.dart](lib/features/portfolio_draft/data/firestore_portfolio_publication_repository.dart), [data/portfolio_public_content_codec.dart](lib/features/portfolio_draft/data/portfolio_public_content_codec.dart) | Prepared online publish/unpublish и public projection без hidden data/private notes |
| [lib/features/settings/data/shared_preferences_settings_repository.dart](lib/features/settings/data/shared_preferences_settings_repository.dart) | Один versioned snapshot настроек через SharedPreferencesAsync |
| [lib/features/portfolio_draft/domain/portfolio_suggestions.dart](lib/features/portfolio_draft/domain/portfolio_suggestions.dart), [presentation/portfolio_suggestion_list.dart](lib/features/portfolio_draft/presentation/portfolio_suggestion_list.dart) | Pure deterministic rules, единые пороги и локализованные объяснения без автоматической записи |
| [assets/fonts](assets/fonts/) | Локальные DM Sans, Noto Sans fallback и SIL OFL лицензии |
| [test/widget_test.dart](test/widget_test.dart), [test/responsive_test.dart](test/responsive_test.dart) | UI-сценарии, навигация, темы и адаптивность |
| [test/auth_di_test.dart](test/auth_di_test.dart), [test/profile_di_test.dart](test/profile_di_test.dart), [test/projects_di_test.dart](test/projects_di_test.dart) | Подмена repositories в реальных экранах и async states |
| [test/auth_repository_test.dart](test/auth_repository_test.dart), [test/profile_repository_test.dart](test/profile_repository_test.dart), [test/projects_repository_test.dart](test/projects_repository_test.dart) | Domain rules, demo/mock content и immutable collections |
| [test/appearance_controller_test.dart](test/appearance_controller_test.dart), [test/project_filters_test.dart](test/project_filters_test.dart), [test/state_management_test.dart](test/state_management_test.dart) | Владельцы состояния, действия, навигация и новая session |
| [test/github_data_test.dart](test/github_data_test.dart), [test/github_import_controller_test.dart](test/github_import_controller_test.dart), [test/github_import_widget_test.dart](test/github_import_widget_test.dart) | DTO/HTTP/ETag, запросы и lifecycle controller, локальные фильтры и экран GitHub Import |
| [test/github_persistence_test.dart](test/github_persistence_test.dart), [test/local_storage_test.dart](test/local_storage_test.dart) | Реальный Hive reopen, TTL/fallback/304, ошибки записи, изоляция boxes и повреждённые файлы |
| [test/settings_persistence_test.dart](test/settings_persistence_test.dart), [test/localization_test.dart](test/localization_test.dart) | Restore/сохранение настроек, write retry и переведённый UI |
| [test/portfolio_draft_repository_test.dart](test/portfolio_draft_repository_test.dart), [test/portfolio_draft_controller_test.dart](test/portfolio_draft_controller_test.dart), [test/portfolio_draft_widget_test.dart](test/portfolio_draft_widget_test.dart) | Persistence, revisions, unknown schema, input retention, асинхронные действия и private notes |
| [test/account_navigation_test.dart](test/account_navigation_test.dart), [test/account_draft_transfer_widget_test.dart](test/account_draft_transfer_widget_test.dart), [test/local_draft_accounts_test.dart](test/local_draft_accounts_test.dart) | Auth guards/named/nested routes, account boundaries, explicit transfer и real Hive reopen/recovery |
| [integration_test/account_runtime_test.dart](integration_test/account_runtime_test.dart) | Отдельная opt-in native проверка email account lifecycle с disposable dev account |
| [integration_test/firestore_runtime_test.dart](integration_test/firestore_runtime_test.dart) | Opt-in native sync/owner checks и отдельная seed/check restart pair с изолированным storage |
| [lib/firebase_options.dart](lib/firebase_options.dart), [firebase.json](firebase.json), [android/app/google-services.json](android/app/google-services.json), [ios/Runner/GoogleService-Info.plist](ios/Runner/GoogleService-Info.plist) | Generated Android/iOS Firebase configuration; runtime initialization остаётся в LocalRuntime |
| [pubspec.yaml](pubspec.yaml), [pubspec.lock](pubspec.lock) | SDK constraint, dependencies и разрешённые версии |
| [analysis_options.yaml](analysis_options.yaml) | Dart analyzer и lint rules |
| `android/`, `ios/` | Native scaffolds и платформенные настройки |

</div>

Экраны используют общие tokens/widgets и публичные feature APIs. Domain хранит
pure Dart модели, правила и repository contracts; data содержит demo/mock
источники, Dio-реализацию GitHub repository, Firebase Auth/Firestore и storage adapters. DI связывается у корня
feature, `StackCardApp.providerOverrides`
передаётся внутреннему ProviderScope для замены источника. `PortfolioContent`
принадлежит единому draft; profile/projects остаются read model проекциями,
`PortfolioOverview` объединяет их для Home и demo Portfolio. Builder preview
читает рабочий content и не показывает private notes. Подробные границы — в
[architecture](../../docs/architecture/architecture.md#mobile-modules--при-реальных-сценариях). Brand originals находятся в
[assets/branding](../../assets/branding/); `StackCardBrand` отрисовывает
оригинальные mark paths через `CustomPainter` без SVG package.

---

## Типовые сценарии

### Войти или открыть локальный guest-редактор

Запусти приложение на Android-устройстве/эмуляторе или iOS-устройстве/симуляторе.
Native Sign In использует Firebase email/password, registration/password reset
и Google adapter; session stream определяет текущего владельца.
В dev project включён Email/Password; Google provider ещё требует завершения
Console configuration и live проверки. Можно явно открыть local guest-режим
без account. Ошибка configuration/restoring/session не открывает чужой draft.
Legacy demo-email/`openDemo` остаётся только preview/test harness `StackCardApp`
без native account configuration; обычный запуск этот путь не использует.
Через app shell доступны Portfolio, Projects и Settings; переходы поддерживают
возврат назад. Projects позволяет искать и фильтровать ручные проекты Builder
либо demo-данные до его начала, открывать карточку с подробностями.
Loading/error/retry работают с текущими repository
states; подмена источника не требует правки widgets. Settings получает профиль
из того же profile provider, переключает dark/light/system и показывает
loading/empty/error с retry. Dark — тема по умолчанию; выбранная тема сохраняется
после перезапуска. Query/filter state остаётся в app session до смены владельца.

Settings позволяет явно перенести сохранённый guest draft в account с пустым
local/cloud draft; начало переноса требует сети. Server read и create-if-absent
transaction защищают данные другого устройства, даже если local cache пустой.
Занятый/повреждённый target не заменяется. Сбой переноса сохраняет recoverable
source/journal и требует повторного transfer для того же UID. После sign out
guest не видит draft аккаунта; при несохранённых правках выход требует
подтверждения их отбрасывания. Settings/public GitHub cache остаются на устройстве.

### Прочитать публичные данные GitHub

На Projects нажми «GitHub Import»: откроется `/github-import`. Введи username
и отправь форму; неверный формат не вызывает HTTP-запрос. Успешная загрузка
показывает профиль и первую страницу repositories. Username не отправляется
на сервер при каждом нажатии клавиши.

Поиск и фильтры работают по загруженному списку. Query применяется после
300 ms без ввода; сетевой поиск не выполняется. «Загрузить ещё» читает URL из
Link, включая canonical путь с numeric user ID; результаты объединяются по
repository ID. Потяни список для refresh: текущие карточки остаются видимыми
при обновлении и при его ошибке. Ошибка следующей страницы показывается отдельно.

Loading, empty и ошибки сети, timeout, отсутствующего пользователя, ответа API
и rate limit имеют отдельные состояния. Retry выполняется явно; при rate limit
новые HTTP-запросы блокируются до deadline. Новый username сбрасывает поиск и
фильтры; refresh сохраняет их. Уход с экрана освобождает controller, отменяет
запросы и debounce; поздний ответ не меняет новое состояние.

Native bootstrap подключает Hive response cache: request URI индексирует schema 1
envelope с body, ETag, Link и UTC `validatedAt`. Каждый запрос сначала проверяет
сеть; `200`/`304` обновляют дату. При network/timeout/server failure разрешена
сохранённая копия младше 7 дней. Возраст от 7 дней, повреждение или неизвестная
schema исключают запись из fallback. Rate limit, not found, forbidden, неверный
ответ и отмена не подменяются cache.

Экран показывает «Сохранённая копия GitHub» и дату последней проверки; смешанные
страницы сохраняют предупреждение и самую раннюю дату. Ошибка локальной записи
не скрывает успешный HTTP-ответ, но показывает недоступность offline copy.
Preview показывает source, Add добавляет repository в рабочий draft.
Повторный импорт сопоставляет repository ID и не создаёт второй проект.
Review changes показывает source до/после и защищённые ручные значения; Accept
меняет только поля без override. Ignore запоминает конкретную source версию;
следующая отличающаяся версия снова требует review. Импортированные проекты
редактируются тем же Project editor; live URL, featured и visibility принадлежат
владельцу. Отдельный Save сохраняет Add/Accept/Ignore; Preview/Cancel ничего не
записывают. Cached source сохраняет известную дату проверки.
Public browsing доступен без аккаунта; draft actions требуют account либо явный
guest access. Изменение UID или проекта после открытия review отклоняет устаревшее
действие. GitHub profile не заменяет профиль владельца, source чтение и draft sync
не публикуют данные. Подробности — в [ADR 0002](../../docs/decisions/0002-github-import-and-review.md).

### Сохранить настройки и локальные заметки

В Settings выбери dark/light/system, Русский/English и показ описаний источника.
UI, navigation и сообщения переведены; исходные названия и тексты контента
сохраняются. Один version 1 snapshot записывается в `stackcard.settings.v1`
через SharedPreferencesAsync. Ошибка сохранения видна с retry; выбор сразу
применяется к UI. Bootstrap восстанавливает настройки и открывает Hive boxes
до первого экрана `StackCardApp`; ошибка открытия показывает повторный запуск.

Из Portfolio открой «Локальные заметки». `/portfolio-draft` редактирует private
notes в том же draft, отдельно от показываемого в preview content.
Явный Save сохраняет рабочий draft в `portfolio_draft` box, увеличивает revision,
записывает UTC `updatedAt` и `pendingSync`. Saved draft переживает перезапуск;
несохранённый ввод сохраняется при навигации в текущей session. Ошибка Save
оставляет ввод доступным. Повреждённая запись или неизвестная schema сохраняются
с блокировкой перезаписи. В account-режиме pending означает durable outbox,
synced — подтверждение сервера конкретной записи; error сохраняет draft и даёт
retry. Guest остаётся local-only. Cache recovery не изменяет portfolio draft.

### Редактировать портфолио

Из Portfolio открой Builder (`/portfolio/builder`). Начало создаёт пустое
портфолио без копирования demo/GitHub source. Заполни профиль, добавь навыки,
опыт, образование, ссылки и Resume; Resume — обычный текст с переносами строк.
Форма применяет изменения целиком, отмена оставляет прежние значения.
Ручной проект можно создать из Builder или Projects, изменить или удалить,
выбрать featured и видимость.

В Builder перемещай десять блоков вверх/вниз и включай нужные разделы.
Пустые блоки пропускаются; Featured Projects показывает видимые проекты с отметкой
featured, а Builder/Projects сохраняют все ручные записи для редактирования.
Тема портфолио dark/light применяется к отображению Portfolio/preview отдельно
от темы приложения.
Полнота вычисляется по профилю, About, навыкам, видимому проекту и ссылкам;
опциональные разделы не обязательны, скрытие блока не увеличивает процент.
Preview (`/portfolio/preview`) показывает рабочие изменения до Save и их статус.

Явный Save сохраняет весь draft. Ошибка оставляет ввод доступным; новые правки
во время записи остаются несохранёнными. Сохранённое портфолио открывается
после перезапуска и без сети. Прежний draft заметок v1 читается без перезаписи;
первая явная запись v3 сохраняет backup исходной записи. V2 читается без eager
migration, явный Save/ACK пишет v3. Неизвестный или
повреждённый формат блокирует перезапись. Conflict revision разрешается явным
действием перечитать сохранённую версию, которое отбрасывает несохранённые правки.

Account Save завершается в Hive до cloud send. Pending outbox переживает restart;
reconnect подтверждает отправку, а server update не отбрасывает unsaved ввод.
Whole-document LWW выбирает поздний server commit: offline Save или retry может
заменить draft другого устройства целиком, изменения не сливаются. Local revision
не определяет порядок между устройствами. Последствия — в
[ADR 0001](../../docs/decisions/0001-firestore-sync-and-publication.md).

Sync не меняет public snapshot. Prepared publication repository использует
отдельную online transaction и public projection; скрытые проекты/поля блоков
и private notes/source metadata не раскрываются public payload. GitHub import
явно меняет curated draft на Phase 9; Publish UI и web вводятся по
[roadmap](../../docs/product/product-spec.md#roadmap).

### Использовать общий backend и функции устройства

Firebase Auth определяет account session; Firestore sync относится к Phase 8,
web-редактор появится на Phase 13. Нативные camera,
location и sharing вводятся под конкретный сценарий и платформу; Kotlin и
MethodChannel относятся к Android. Клиент не публикует draft автоматически.

---

## Локальная разработка

Открывай эту директорию как Flutter-проект в Android Studio/VS Code.
Flutter/Dart-команды выполняются здесь, Git — из корня monorepo.
Предусловия и запуск описаны в [быстром старте](../../CONTRIBUTING.md#быстрый-старт),
проверки — в [CONTRIBUTING](../../CONTRIBUTING.md#проверки).
Firebase CLI generation, provider setup и optional Auth/Firestore Emulator defines — в
[configuration guide](../../CONTRIBUTING.md#firebase-configuration-и-окружение),
отдельный native acceptance — в
[разделе проверок](../../CONTRIBUTING.md#native-firebase-auth-acceptance).
Rules Emulator Suite и native sync/restart pair — в
[Firestore checks](../../CONTRIBUTING.md#firestore-rules-и-native-sync-acceptance).
Rules/indexes/config и отдельный npm suite находятся в [firebase](../../firebase/),
не смешиваются с Flutter manifest или generated Firebase configuration.

Для Android нужны SDK, JDK и устройство/эмулятор; для iOS — macOS и Xcode.
Фактические проблемы toolchain показывает `flutter doctor -v`; наличие scaffold
не подтверждает готовность нативной сборки на конкретном компьютере.
В текущей среде Xcode неполный и CocoaPods отсутствует: generated iOS config
есть, но iOS build/приёмка не выполнены. Native acceptance использует отдельный
opt-in запуск; обычный suite сохраняет legacy unconfigured preview для UI tests.

---

## Правила

- перед изменением прочитай [AI router](../../docs/AI/README.md),
  [общие правила](../../docs/AI/AGENTS.md) и [mobile scope](../../docs/AI/scopes/mobile.md);
- для Firestore schema/Rules следуй [Firebase scope](../../docs/AI/scopes/firebase.md)
  и [ADR 0001](../../docs/decisions/0001-firestore-sync-and-publication.md);
- добавляй dependencies при реальном использовании, сохраняй lockfile приложения;
- generated-файлы и `.metadata` не редактируй вручную;
- feature placement и границы данных согласуй с [архитектурой](../../docs/architecture/architecture.md);
- сохраняй принятый [визуальный язык](../../docs/design/design-system.md), не добавляй параллельные tokens;
- обновляй ссылки и документы при изменении команд, путей или контрактов.
