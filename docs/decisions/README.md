# Архитектурные решения

Короткие ADR фиксируют решение, контекст, альтернативы и последствия, когда выбор
влияет на несколько частей продукта. Отдельный ADR для каждого widget не нужен.

## Принято для Phase 0

| Решение | Причина и последствия |
| --- | --- |
| Один monorepo, Flutter в `apps/mobile`, будущий сайт в `apps/web` | Mobile и web-редактор/публичные страницы — один продукт; каталог `apps/web` подготовлен с README, приложение ещё не создано |
| Перенос существующего scaffold, mobile только Android/iOS | Сохраняет Android/iOS native configs и настройки; desktop и Flutter web targets удалены, повторный `flutter create` не нужен |
| Минимальный запуск без будущих packages | Счётчик и widget test проверяют фундамент без premature architecture |
| Firebase вместо своего backend в v1 | Единый аккаунт и данные для mobile/web, меньше компонентов; сервисы пока не настроены |
| Next.js для сайта и web-редактора на Phase 13 | Главная, скачивание mobile, защищённый кабинет и public portfolio с SEO/metadata/OpenGraph; отдельное приложение `apps/web` |
| Два редактора одного портфолио | Mobile и web работают с общим private draft и правилами публикации; согласованные data contracts реализуются отдельно в Dart/TypeScript |
| Mobile offline, web v1 online-first | Mobile хранит локальный draft/cache; web показывает статус сохранения/sync и требует сети для удалённых действий |
| GitHub source отдельно от curated/published данных | Пользователь контролирует редактуру и публикацию, sync предлагает изменения |
| Logo originals в `assets/branding` | Имена совпадают с brand kit, SVG bytes сохранены, runtime integration отложена |
| Lockfile mobile отслеживается | Воспроизводимое разрешение зависимостей приложения |
| Общий AI-контекст в `docs/AI/` | Router, общие и scope rules хранятся вместе; root/nested AGENTS остаются точками входа, runtime configs — рядом с кодом |

Реализованная UI foundation и целевые решения описаны в
[architecture](../architecture/architecture.md) и
[design system](../design/design-system.md).
Общий порядок работы и sources описаны в [AI router](../AI/README.md).

## Принято для Phase 2

| Решение | Причина и последствия |
| --- | --- |
| Provider для ThemeMode, Riverpod для Projects query/filter state | Выполняет учебную эволюцию простого app-level состояния; immutable состояние продукта и производный список проверяются независимо от widget tree |
| Один runtime-владелец каждого состояния | AppearanceController владеет темой, ProjectFiltersNotifier — поиском/фильтрами; router не передаёт theme callbacks, TextEditingController остаётся UI-ресурсом |
| Locale после появления переводов | Разрешённая граница Provider ThemeMode/Locale не требует пустой реализации Locale при русскоязычном UI |
| State только в app session | Фильтры сохраняются при навигации, перезапуск сбрасывает выбор; persistence относится к Phase 5 |
| Промежуточные учебные версии вне `lib` | Независимые patches восстанавливают варианты темы во временной копии; рабочий код содержит итоговый Provider |

Сравнение подходов, переходы и воспроизведение находятся в
[state management guide](../learning/state-management.md).

## Принято для Phase 3

| Решение | Причина и последствия |
| --- | --- |
| `presentation/domain/data` в auth/profile/projects | Реальные demo-сценарии получают pure Dart модели/правила и repository contracts; data хранит mock content, widgets рендерят состояния |
| Repository contracts + Riverpod DI у корня feature | Concrete реализации заменяются provider override без переписывания экранов; FutureProvider/AsyncNotifier обслуживают загрузку и действия, Provider остаётся владельцем темы |
| Public feature barrels для межмодульных зависимостей | `auth.dart`, `profile.dart`, `projects.dart`, `portfolio.dart` раскрывают намеренный API; внутренние файлы другой feature не становятся общим контрактом |
| Immutable models и domain selection | `ProjectSource` отделяет происхождение от UI-подписи; query/filter и featured-отбор работают без Flutter/Riverpod; коллекции защищены от внешней мутации |
| `PortfolioOverview` как presentation read model | Объединяет profile/projects; полный featured-список не зависит от поиска на Projects. На Phase 3 Builder/domain ещё отсутствовал; Phase 6 вводит его отдельно от read models |
| `ProfileReadiness` как demo-snapshot | На Phase 3 валидация счётчиков и расчёт доли не задавали алгоритм полноты Builder; Phase 6 сохраняет read model и подставляет вычисленный результат |
| Без дополнительных UseCase/DataSource | Текущие mock repositories и простые правила не требуют пустого промежуточного слоя; network/persistence вводятся на соответствующих фазах |
| Явный retry для asynchronous repository state | Loading/error отображаются shared widgets; пользовательский retry повторяет запрос, сохранённые query/filter остаются в app session |

Подробные границы и текущие источники — в
[architecture](../architecture/architecture.md#mobile-modules--при-реальных-сценариях),
сравнение state mechanisms — в [учебном guide](../learning/state-management.md).
Результаты приёмки и ограничения фиксируются в
[product spec](../product/product-spec.md#phase-3--architecture).

## Принято для Phase 4

| Решение | Рассмотренная альтернатива | Причина и последствия |
| --- | --- | --- |
| Отдельный GitHub Import и public `github_import.dart` | Сразу заменить curated Projects ответами API | Публичные GitHub metadata читаются на `/github-import`; demo-портфолио и будущие curated/draft/published модели сохраняют собственные contracts |
| Dio и DTO в data, pure Dart repository/models/failures в domain | HTTP и raw JSON внутри widgets | Data проверяет ответы и преобразует их в immutable модели; feature-root DI подменяет repository, clock и response cache, widgets читают presentation state |
| Controller через `NotifierProvider.autoDispose` | Хранить запросы и таймеры в widget или бессрочной app session | Controller владеет атомарной initial load, refresh и pagination; уход с экрана отменяет запросы и debounce, generation guards и `ref.mounted` отсекают поздние ответы |
| Pagination по `Link` с проверкой origin и user path | Угадывать следующий номер страницы | Поддерживаются username и canonical numeric-ID paths GitHub; объединение по repository ID сохраняет порядок и исключает дубли |
| Локальные фильтры и query debounce 300 ms | Новый API search на каждый ввод | Поиск применяется только к загруженным repositories; новый username сбрасывает filters, refresh сохраняет их |
| Typed failures и явный retry с rate-limit deadline | Автоматические повторы без учёта API headers | Initial error, refresh error и page error различаются; успешный список сохраняется при ошибке refresh/more, повторный HTTP блокируется до разрешённого времени. Repository живёт в app session, чтобы закрытие экрана не сбрасывало deadline |
| ETag conditional requests с serialized response cache в памяти | Сразу добавить Hive и offline fallback | Cache индексируется request URI и переживает закрытие экрана в app session; `304` повторно использует проверенный ответ. Disk persistence, TTL и versioned schema остаются Phase 5 |

Границы реализации — в
[architecture](../architecture/architecture.md#mobile-modules--при-реальных-сценариях),
использование экрана — в [mobile guide](../../apps/mobile/README.md#прочитать-публичные-данные-github),
состояния и lifecycle — в [state management guide](../learning/state-management.md#github-import-на-phase-4).
Результаты приёмки фиксируются в
[product spec](../product/product-spec.md#phase-4--github-api).

## Принято для Phase 5

Решения ниже введены на Phase 5; notes-only schema расширена решением Phase 6 ниже.
Приёмка и её доказательства находятся в
[product spec](../product/product-spec.md#phase-5--local-persistence--offline).

| Решение | Рассмотренная альтернатива | Причина и последствия |
| --- | --- | --- |
| Original Hive 2.2.3, JSON envelopes без generator | Prerelease Hive, fork или SQL database | Stable версия выполняет план и текущие key/value сценарии; schema проверяется в data, pure Dart domain не зависит от Hive. Версии фиксирует mobile lockfile |
| `path_provider` Application Support и отдельные boxes | Общий box или temporary directory | `LocalStorage` открывает `stackcard/github_responses` и `stackcard/portfolio_draft`. Cache воспроизводим; пользовательские notes имеют независимый lifecycle и не удаляются вместе с cache |
| Network-first cache, schema 1 и hard TTL 7 дней | Бессрочный offline cache или cache-first без проверки | URI key хранит body, ETag, Link и UTC `validatedAt`; только успешные `200`/`304` продлевают срок. Возраст от 7 дней исключает fallback; отмена проверяется после storage awaits |
| Offline fallback только для network/timeout/server | Подменять cache любой HTTP failure | Not found, forbidden, rate limit, invalid response и cancellation сохраняют смысл ошибки. Проверенный cached DTO/Link используется только в допустимом возрасте, offline-чтение не продлевает TTL |
| Метаданные чтения и явное предупреждение UI | Выдать cached ответы за свежие данные | `GitHubReadMetadata` передаёт источник, дату и storage failures; aggregate объединяет профиль/страницы с самой ранней датой. Успешный HTTP остаётся доступным при ошибке cache write, UI сообщает, что offline copy не гарантирована |
| Отдельный notes draft, schema 1, revision и `pendingSync` | Сразу реализовать весь Builder или cloud sync | На Phase 5 `portfolio_draft` сохранял notes, revision, UTC `updatedAt` и pendingSync одним awaited write; очередь исключает конкурирующие revisions. Schema 2 и Builder вводятся на Phase 6, remote sync — своей фазой |
| Cache evict, draft preserve при повреждении/unknown schema | Автоматически сбросить оба хранилища | Некорректная, expired или future-schema cache row удаляется. Draft repository сохраняет исходную запись и блокирует перезапись до совместимого формата; неизвестные версии не мигрируются догадкой |
| Backup нечитаемого cache-файла; `crashRecovery: false` для boxes | Автоматическая обрезка повреждённого Hive-файла | `LocalStorage` переименовывает cache в `.hive.unreadable-<UTC stamp>` и пробует открыть новый. Повреждённый draft не обрезается: bootstrap показывает ошибку/retry, файл сохраняется, уже открытый cache закрывается |
| Два публичных `openBox` в одном `Future.wait` | Наблюдать только первый Future | Shim для Hive 2.2.3 обрабатывает оба Future, завершающиеся ошибкой при неудачном открытии; оба вызова получают один box. Поведение и сохранность файлов проверяются real-file tests |
| Нейтральные settings contracts и SharedPreferencesAsync | Theme/locale внутри widgets или настройки в draft box | `core/state` владеет AppSettings/SettingsRepository и Provider controller. Один version 1 snapshot в `stackcard.settings.v1` объединяет theme/language/source descriptions; последовательные записи и retry не требуют feature imports в core |
| Restore до `StackCardApp`, реальные ru/en UI-каталоги | Применить настройки после первого экрана или хранить Locale без переводов | Bootstrap читает settings и открывает boxes, затем подставляет persistent adapters. ThemeMode/Locale применяются сразу; source content сохраняет исходный язык |

Sources: [manifest](../../apps/mobile/pubspec.yaml) и
[lockfile](../../apps/mobile/pubspec.lock), stable
[Hive 2.2.3](https://pub.dev/packages/hive/versions/2.2.3),
[Application Support API](https://pub.dev/documentation/path_provider/latest/path_provider/getApplicationSupportDirectory.html).
[SharedPreferencesAsync 2.5.5](https://pub.dev/packages/shared_preferences/versions/2.5.5)
обращается к platform storage без собственного cache. Snapshot записывается
одним ключом; это не гарантия crash-safe disk commit от плагина, поэтому
пользовательский draft хранится отдельно в Hive.

Runtime composition — [LocalRuntime](../../apps/mobile/lib/app/local_runtime.dart)
и [LocalStorage](../../apps/mobile/lib/core/storage/local_storage.dart).
Проверка границ — [GitHub persistence](../../apps/mobile/test/github_persistence_test.dart),
[storage files](../../apps/mobile/test/local_storage_test.dart),
[settings](../../apps/mobile/test/settings_persistence_test.dart),
[localization](../../apps/mobile/test/localization_test.dart) и
[draft repository](../../apps/mobile/test/portfolio_draft_repository_test.dart).

## Принято для Phase 6

| Решение | Рассмотренная альтернатива | Причина и последствия |
| --- | --- | --- |
| Единый `PortfolioContent` в `portfolio_draft`, `Profile`/`Project` — read models | Отдельный write store для каждого экрана | Формы изменяют один domain content; Home/Portfolio/Projects/Settings читают проекции через публичные feature APIs. Existing demo Repository/DI остаётся fallback до начала Builder |
| Nullable content для legacy draft и пустой content при начале Builder | Скопировать demo/GitHub data в пользовательский draft | Notes-only v1 не выдаётся за заполненное портфолио; null отличается от начатого пустого Builder. GitHub Import остаётся отдельным source и не меняет curated content |
| Private notes вне `PortfolioContent` | Включить notes в рендеримый content | `/portfolio-draft` использует тот же controller/repository, но preview получает только content; заметки не становятся частью портфолио |
| Envelope v2 с raw v1 backup перед явной записью | Переписать v1 при чтении или обнулить неподдерживаемый draft | Чтение сохраняет точные notes/metadata без write. Backup/write failure оставляет прежний durable draft; corrupted/unknown schema блокирует перезапись, cache eviction не затрагивает draft |
| Последовательный Save с `expectedRevision` | Перезаписывать без проверки durable revision | Stale revision даёт conflict без потери более свежей записи. UI сохраняет рабочий ввод; явный reload требует решения отбросить несохранённые изменения. Это локальная защита, remote multi-device strategy ещё не выбрана |
| Рабочий content и durable snapshot в одном session controller | Preview только последней записи или второй mutable preview store | Preview показывает applied изменения до Save с честным unsaved status. Save захватывает snapshot, более новые правки остаются unsaved; failure сохраняет ввод, duplicate Save блокируется |
| Pure validation и пять шагов полноты | Сохранять процент либо считать только видимые блоки | Профиль, About, навыки, видимый проект и ссылки дают полноту; optional разделы не обязательны, скрытие блока не повышает процент. Неполный draft допустим, некорректные значения не сохраняются |
| `PortfolioTheme` отдельно от app ThemeMode | Менять тему приложения при выборе оформления портфолио | Dark/light хранится в content и использует существующую StackCardTheme для отображения Portfolio/preview; AppearanceController продолжает владеть настройками приложения |
| Resume — plain text, без новых dependencies | Markdown renderer или файловое resume на этой фазе | Реальная multiline форма сохраняет переносы строк; файлы, media и экспорт вводятся по отдельным сценариям roadmap |

Sources: публичный [portfolio draft API](../../apps/mobile/lib/features/portfolio_draft/portfolio_draft.dart),
[PortfolioContent](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_content.dart),
[validation](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_validation.dart),
[completion](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_completion.dart),
[controller](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_draft_controller.dart) и
[Hive repository](../../apps/mobile/lib/features/portfolio_draft/data/hive_portfolio_draft_repository.dart).
Подробный contract — в [architecture](../architecture/architecture.md#portfolio-domain-и-локальный-builder),
приёмка и ограничения — в [Phase 6](../product/product-spec.md#phase-6--portfolio-domain-и-локальный-builder).

## Решить перед соответствующими фазами

- Sync conflict strategy и поведение при нескольких устройствах, включая правки
  из mobile и web; согласование и проверка совместимости data contracts.
- Firestore schema, private draft/public snapshot, username uniqueness,
  атомарность publish/unpublish.
- Перед изменением storage schema определить явную migration пользовательского
  draft и совместимость revisions; cache можно воспроизвести из source API.
- Contact spam/rate limiting и доверенная отправка notifications.
- Application IDs, signing и release configuration до публикации.
- Точные web routes, зависимости, способы auth/session и проверки определить
  перед Phase 13 по реальному Next.js/Firebase стеку. Browser push и равенство
  нативных функций не включаются автоматически в mobile-требования.

## Формат ADR

Файл: `NNNN-short-title.md`. Поля: дата, статус (`proposed`, `accepted`, `superseded`),
контекст, решение, альтернативы, последствия и способ проверки.
Пересмотренное решение сохраняется со ссылкой на заменяющий ADR.
