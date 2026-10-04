<div align="center">

# StackCard Design v2 — аудит

**Текущие экраны, данные, интеграции и расхождения с требованиями редизайна**

![Phase R0 audit](https://raster.shields.io/badge/Phase-R0_audit-C7FF1A?style=for-the-badge)
![Scope read only](https://raster.shields.io/badge/Scope-source_and_Figma-14161B?style=for-the-badge)

</div>

---

## Содержание

- [Область и доказательства](#область-и-доказательства)
- [Исходное состояние и roadmap](#исходное-состояние-и-roadmap)
- [Инвентаризация источников](#инвентаризация-источников)
- [Текущие экраны и маршруты](#текущие-экраны-и-маршруты)
- [Работающие контракты и целевая модель](#работающие-контракты-и-целевая-модель)
- [Figma и расхождения](#figma-и-расхождения)
- [Сохранить и изменить](#сохранить-и-изменить)
- [Продуктовые пробелы](#продуктовые-пробелы)
- [Публикация и приватность](#публикация-и-приватность)
- [Проверки и ограничения](#проверки-и-ограничения)

---

## Область и доказательства

Срез — 2026-10-05. В R0 выполнено чтение репозитория, действующих contracts,
документов, Figma metadata и выбранных renders. Этот документ имеет статус
`awaiting_review`; он не разрешает R1 и не устанавливает DESIGN_READY.
Продуктовый код, данные, Figma и зависимости этим аудитом не изменены.

| **Вид результата** | **Что он подтверждает** |
|:---|:---|
| Текущий source/config | Наличие конкретного контракта или реализации; это статическое чтение, не новый запуск приложения |
| Сохранённая приёмка roadmap | Результаты предыдущих запусков в их исходном scope; tests/live backend в R0 не повторялись |
| MCP metadata | Реальные страницы, nodes, имена и структура Figma; наличие frame не означает полноту flow |
| Просмотренный render | Видимый экран и его расхождения; не работающий backend и не полная проверка prototype |
| Требование Design v2 | Целевое поведение из последнего задания; реализация и приёмка ещё впереди |

Новая версия требований — [requirements.md](requirements.md), карта переходов —
[screens.md](screens.md), порядок дальнейшей работы — [plan.md](plan.md).
Старые документы и макеты сохраняются как история. Последний запрос пользователя
имеет приоритет над противоречащими ему прежними решениями.

---

## Исходное состояние и roadmap

На начало аудита рабочая ветка — `redesign/full-app`. До R0 уже существовали
незакоммиченные изменения в следующих файлах; они сохранены:

- `docs/AI/AGENTS.md`;
- `docs/AI/README.md`;
- `docs/AI/scopes/mobile.md`;
- `docs/design/design-contract.md`;
- `docs/design/design-system.md`;
- `docs/design/implementation-handoff.md`;
- `docs/product/product-spec.md`;
- `docs/design/redesign-plan.md` — исходно untracked.

Canonical основного roadmap —
[product-spec.md](../product/product-spec.md#план-разработки).
По сохранённой приёмке Phase 0–6 и 8–10 завершены. Последняя функциональная
фаза — Phase 10 Portfolio Suggestions; следующая запланированная — Phase 11 Media.
Phase 11–20 не реализуются в рамках R0.

Phase 7 остаётся открытой: Google provider/OAuth configuration, native Google flow,
фактическое получение reset-письма и смена пароля, iOS. Это указано в
[Phase 7](../product/product-spec.md#phase-7--firebase-authentication). Исторические Android sync checks не закрывают эти сценарии.

Основная разработка новых функций приостановлена. Сохраняем точку возвращения
«перед Phase 11» вместе с незавершённой приёмкой Phase 7. Предложить возврат можно
после принятой R9 и REDESIGN_DONE; переход требует отдельного поручения.

Предыдущая Figma-first итерация описана в
[product spec](../product/product-spec.md#новый-figma-first-target-2026-10-04). Её макеты не меняли runtime/schema/Rules. Это не завершённый
Design v2 и не основание считать multiple documents реализованными.

---

## Инвентаризация источников

| **Источник** | **Что прочитано и кем владеет** |
|:---|:---|
| [pubspec.yaml](../../apps/mobile/pubspec.yaml), [pubspec.lock](../../apps/mobile/pubspec.lock), [analysis_options.yaml](../../apps/mobile/analysis_options.yaml) | Flutter dependencies и анализ; Material 3, Provider/Riverpod, GoRouter, Hive, Dio, Firebase Auth/Firestore; media/FCM dependencies не введены |
| [main.dart](../../apps/mobile/lib/main.dart), [LocalRuntime](../../apps/mobile/lib/app/local_runtime.dart) | Native bootstrap, settings/storage/Firebase composition; configuration error не включает demo fallback |
| [Router](../../apps/mobile/lib/app/app_router.dart), [Shell](../../apps/mobile/lib/app/app_shell.dart) | Реальные auth/private/nested paths, старая root navigation и tablet sidebar |
| [Colors](../../apps/mobile/lib/core/theme/stackcard_colors.dart), [Theme](../../apps/mobile/lib/core/theme/stackcard_theme.dart), [Tokens](../../apps/mobile/lib/core/theme/stackcard_tokens.dart) | Текущие runtime colors/Material 3/type/spacing; не автоматически migrated Design v2 tokens |
| [AsyncView](../../apps/mobile/lib/shared/widgets/stackcard_async_view.dart), [States](../../apps/mobile/lib/shared/widgets/stackcard_states.dart), [Button](../../apps/mobile/lib/shared/widgets/stackcard_button.dart), [Input](../../apps/mobile/lib/shared/widgets/stackcard_input.dart), [Poster](../../apps/mobile/lib/shared/widgets/stackcard_poster.dart) | Shared UI, loading/error/retry, controls и прежний artwork |
| [PortfolioContent](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_content.dart), [PortfolioProfile](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_profile.dart), [PortfolioProject](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_project.dart), [Sections](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_sections.dart) | Pure Dart singleton model, profile/projects/skills/experience/education/links/plain Resume |
| [Draft controller](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_draft_controller.dart), [Hive repository](../../apps/mobile/lib/features/portfolio_draft/data/hive_portfolio_draft_repository.dart), [Local accounts](../../apps/mobile/lib/features/portfolio_draft/data/local_draft_accounts.dart) | Working/durable separation, revision/backup, UID namespace и explicit guest transfer |
| [Sync API](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_sync.dart), [Local-first repository](../../apps/mobile/lib/features/portfolio_draft/data/synced_portfolio_draft_repository.dart), [Firestore draft adapter](../../apps/mobile/lib/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart) | Durable outbox, server ACK, pending/error/retry и whole-document sync |
| [GitHub rules](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_github_sync.dart), [GitHub bridge](../../apps/mobile/lib/features/github_import/github_portfolio_providers.dart), [Suggestions](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_suggestions.dart) | Explicit import/review/Ignore, overrides, dedup и read-only рекомендации |
| [Auth contract](../../apps/mobile/lib/features/auth/domain/account_auth_repository.dart), [Auth user](../../apps/mobile/lib/features/auth/domain/auth_user.dart), [Firebase Auth adapter](../../apps/mobile/lib/features/auth/data/firebase_account_auth_repository.dart) | Session, email sign-in/register/reset, Google credential sign-in, sign out |
| [Publication contract](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_publication.dart), [Publication adapter](../../apps/mobile/lib/features/portfolio_draft/data/firestore_portfolio_publication_repository.dart), [Public codec](../../apps/mobile/lib/features/portfolio_draft/data/portfolio_public_content_codec.dart) | Prepared explicit transaction и безопасная client projection; пользовательского public flow ещё нет |
| [Rules](../../firebase/firestore.rules), [Firebase config](../../firebase/firebase.json), [Rules package](../../firebase/package.json), [Indexes](../../firebase/firestore.indexes.json) | Private/public access, linked transitions и отдельный emulator test contract |
| [Web README](../../apps/web/README.md) | Только scope будущего Next.js-приложения; web code/config/routes отсутствуют |
| [Product spec](../product/product-spec.md), [Architecture](../architecture/architecture.md), [ADR 0001](../decisions/0001-firestore-sync-and-publication.md), [ADR 0002](../decisions/0002-github-import-and-review.md) | Roadmap, текущие data boundaries, sync/publication и GitHub contracts |
| [Design system](../design/design-system.md), [Design contract](../design/design-contract.md), [Handoff](../design/implementation-handoff.md), [Прежний redesign plan](../design/redesign-plan.md) | Старый runtime и прежний Figma target; спорные решения больше не определяют Design v2 |

Original branding в `assets/branding` и зарегистрированные локальные DM Sans/Noto
Sans с OFL licenses сохраняются. Выбор шрифтов Design v2 и их визуальная проверка
принадлежат R2–R3; наличие font assets не подтверждает читаемость всех макетов.

---

## Текущие экраны и маршруты

Полный перечень существующих nested paths и target screen IDs находится в
[screens.md](screens.md#текущие-маршруты). Ниже — фактическая роль экранов и
главные расхождения; новые path names в R0 не назначаются.

| **Маршрут и source** | **Текущее поведение и проблема** |
|:---|:---|
| `/home` — [Home](../../apps/mobile/lib/features/home/home_screen.dart) | Dashboard с greeting, profile poster, readiness percentage, counters, Featured и большими Projects/GitHub кнопками; строки 62–135, 205–242. Нет нужной библиотеки Все/Резюме/Проекты |
| `/portfolio` — [Portfolio](../../apps/mobile/lib/features/portfolio/presentation/portfolio_screen.dart) | Demo либо preview единственного working content; это не список нескольких Portfolio |
| `/projects` — [Projects](../../apps/mobile/lib/features/projects/presentation/projects_screen.dart) | Import/create/search/list и редактирование работают через draft; большой poster и category filters перед списком, строки 89–206, противоречат новому порядку |
| `/settings` — [Settings](../../apps/mobile/lib/features/settings/settings_screen.dart) | Theme/language/source descriptions, profile summary, account/guest transfer, demo state previews. Нет полного DeveloperProfile/account/privacy управления; poster и settings root принадлежат прежнему UI |
| `/sign-in`, `/register`, `/reset-password` — [Auth forms](../../apps/mobile/lib/features/auth/presentation/sign_in_screen.dart) | Account forms/session states и explicit guest; сохраняются вместе с guards и typed errors |
| `/github-import` — [Import](../../apps/mobile/lib/features/github_import/presentation/github_import_screen.dart) | Публичное source чтение, selection/pagination/cache/retry; private import actions guarded. Source просмотр не публикует данные |
| `/portfolio-draft` — [Notes](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_draft_screen.dart) | Private notes общего draft; сохраняются вне public content |
| `/portfolio/builder` и дочерние editors — [Builder](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_builder_screen.dart) | Profile/skills/experience/education/links/resume, блоки/order/visibility/theme; один content. Resume editor — одно multiline поле |
| `/projects/new`, `/projects/:id/edit` — [Project editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_project_editor_screen.dart) | Ручной CRUD и curated source поля; нет attachment entity к нескольким outputs |
| `/portfolio/preview` — [Preview](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_preview_screen.dart) | Working preview; не опубликованная страница и не настоящий public URL |
| `apps/web` | Только README; `/u/[username]` — план, не работающий route. Landing, workspace, public Resume/Portfolio ещё не реализованы |

[AppShell](../../apps/mobile/lib/app/app_shell.dart), строки 11–16, использует
Home/Portfolio/Projects/Settings. При ширине от 700 переключается на sidebar
(32–92), mobile labels видны только у выбранного пункта или скрываются при
крупном тексте (149–157). Header содержит STACKCARD/DEMO и logout icon (97–138).
Это реальные source расхождения с REQ-NAV-01..05 и tablet требованиями.

Back у nested editors и существующие auth redirects необходимо сохранить.
Root tab change и возвращение из Settings проектируются заново в R1;
автоматическое удаление Back из всех экранов недопустимо.

В [Projects cards](../../apps/mobile/lib/features/projects/presentation/projects_screen.dart),
строки 308–318 и 332–337, используются крупный `project.symbol` и slash technologies.
Это source основания для cover/placeholder и TechnologyBadge, а не подтверждение
реализованного media lifecycle. [GitHubSourceLink](../../apps/mobile/lib/features/github_import/presentation/github_source_cards.dart),
365–395, уже копирует URL GitHub source с подтверждением; это не публичная ссылка
документа Resume/Portfolio.

[Builder](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_builder_screen.dart),
110–148, показывает sections/projects/blocks/theme в одном содержимом, а 184–225 —
readiness poster. [Editor scaffold](../../apps/mobile/lib/features/portfolio_draft/presentation/builder_editor_widgets.dart),
227–260, размещает Apply после прокручиваемой формы. Доступное сохранение и
разделение content/appearance/preview/publication требуют новой UX-композиции;
buffered input и явные Apply/Cancel необходимо сохранить.

Текущий [runtime Colors](../../apps/mobile/lib/core/theme/stackcard_colors.dart),
19–61, содержит другую neutral palette, acid/cyan/pink и красный `accent`.
Его значения не соответствуют сохранённой палитре Design v2.
[Brand painter](../../apps/mobile/lib/shared/widgets/stackcard_brand.dart), 49–85,
повторяет геометрию старого S. Изменение color roles и внедрение нового знака
принадлежат R8 после согласования дизайна; исходные assets сохраняются.

---

## Работающие контракты и целевая модель

Здесь «есть в коде» означает прочитанную implementation. Runtime приёмка этих
функций зафиксирована ранее в основном roadmap, а не повторена в R0.

| **Область** | **Текущее состояние и отличие от target** |
|:---|:---|
| Общая база | `PortfolioProfile` имеет name/username/headline/bio/locationText/avatarUrl. Остальные данные принадлежат одному `PortfolioContent`; самостоятельного DeveloperProfile store нет |
| Resume/Portfolio | [Content](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_content.dart), строки 12–46, содержит одну строку `resumeText` и один набор content; multiple document IDs/status/date/duplicate отсутствуют |
| Project relations | [Project](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_project.dart), строки 14–29: featured/visible глобальны. [Удаление в Builder](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_builder_panels.dart), 203–206, удаляет сам проект. Target требует separate attachment с order/featured/visibility |
| Изменение профиля | [Profile projection](../../apps/mobile/lib/features/profile/presentation/portfolio_profile_projection.dart) читает working content. Нет independent documents, per-output overrides и review обновления base data |
| Фото | Profile хранит avatarUrl, [editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_profile_editor_screen.dart), 63–68, предлагает текстовый URL. [Renderer](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_content_view.dart), 97–117, показывает artwork, не выбранную фотографию |
| Контакты и ссылки | [SocialLink](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_sections.dart), 114–146, имеет label/url/kind; CRUD [link editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_links_editor_screen.dart) работает. Нет public email/phone, per-link privacy, reorder и selection/override для outputs |
| URL validation | [Validation](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_validation.dart), 31–48, принимает http/https; mailto/tel не поддерживаются этим link contract. Контакты нельзя незаметно свести к прежним URL-полям |
| GitHub | [Add](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_github_sync.dart), 211–239, dedup по repository ID; Accept, 243–279, сохраняет user overrides и отклоняет stale review. Add/Accept/Ignore меняют working content, Save отдельный |
| Working и Save | [Controller](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_draft_controller.dart), 215–240, сохраняет captured snapshot и оставляет новый ввод unsaved; 274–291 удерживает ввод при remote hydration |
| Sync | [Sync state](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_sync.dart), 5–31, разделяет localOnly/loading/pending/synced/error. [Adapter](../../apps/mobile/lib/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart), 16, привязан к `accounts/{uid}/drafts/current`; whole-document LWW определяется server commits |
| Storage | [Hive](../../apps/mobile/lib/features/portfolio_draft/data/hive_portfolio_draft_repository.dart), 22–24, 42–72, 123–140: v3/revision/pending/legacy backup; UID namespaces, guest generation и explicit transfer сохраняются |
| Publication | Prepared repository сверяет переданный content с актуальным cloud draft, атомарно обновляет account/username/snapshot; UI, public reader и Resume publication отсутствуют |
| Username | Validation lowercase 3–30; draft profile editing не резервирует имя. [Publication adapter](../../apps/mobile/lib/features/portfolio_draft/data/firestore_portfolio_publication_repository.dart), 62–72, защищает занятое имя и при rename удаляет старый snapshot/claim; redirects не реализованы |
| Account | [Auth API](../../apps/mobile/lib/features/auth/domain/account_auth_repository.dart), 3–9: email sign-in/register/reset, Google sign-in, sign out. Нет provider linking/unlinking, login email/password change, reauth и account deletion |
| App preferences | [AppSettings](../../apps/mobile/lib/core/state/app_settings.dart), 5–24: theme/language/source descriptions. Notifications/reduced motion отсутствуют |
| Technologies | Технологии — доступные строки, но [renderer](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_content_view.dart), 122–126 и 163–169, склеивает их через `/`. TechnologyBadge icon+text — новый UI-компонент, не причина строить отдельный backend |

В существующих документах [relation target](../design/redesign-plan.md#целевая-domain-relation)
уже отделён от текущей schema. Его прежнее «live inheritance/snapshot уточнить»
заменяется последним явным правилом: новым документам предлагать базу;
существующим показывать изменения и применять их явно. Это не требует сложной
системы версионирования, но требует согласованного storage contract до переноса.

---

## Figma и расхождения

Доступ к Figma через MCP в R0 работал. Проверены metadata девяти страниц:
`0:1`, `2:98`, `2:99`, `2:100`, `2:101`, `2:102`, `2:103`, `2:104`, `2:105`.
Отдельно просмотрены renders перечисленных ниже экранов. Экспорт или screenshots
от пользователя для этой части аудита не требуются.

| **Проверенный material** | **Наблюдение и действие Design v2** |
|:---|:---|
| [Home 38:3901](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3901), render | «Добрый вечер, Станислав.» и quick access Все проекты/Мои резюме/GitHub; убрать greeting и заменить на точный Home-filter Все/Резюме/Проекты — REQ-HOME-01..03, REQ-NAV-03 |
| [Projects 38:3903](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3903), render | Фильтры Все/GitHub/Вручную, slash technologies, отсутствие cover; нужны установленный порядок экрана, no category panel, cover/placeholder и badges — REQ-PROJECT-01..03, REQ-TECH-01 |
| [Settings 38:3905](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3905), render | Есть группы настроек, но это список входов; actual inner profile/contact/security/privacy flows не подтверждены — REQ-SETTINGS-01..04 |
| [Landing 9:2](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=9-2), render | One-portfolio promise и artwork; изменить сообщение на общую профессиональную базу и разные Resume/Portfolio, показать настоящий product preview |
| [Public Portfolio 9:535](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=9-535), render | Lime poster с абстракцией вместо selected photo, slash technologies и буквенные project placeholders; композиция должна строиться вокруг человека/работ — REQ-PORTFOLIO-02, REQ-PROJECT-03, REQ-TECH-01 |
| [Resume 38:3902](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3902), [Portfolios 38:3904](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3904) | IDs и metadata проверены; renders этой пары в R0 не просмотрены, полная визуальная приёмка не заявляется |
| [Light Home 44:474](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=44-474), [Resumes 44:584](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=44-584), [Projects 44:661](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=44-661), [Portfolios 44:741](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=44-741), [Settings 44:852](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=44-852) | Metadata-only; не подтверждает dark/light parity, contrast и увеличенный текст |
| [Tablet 2:102](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-102) | Восемь legacy frames; новый tablet сохраняет нижнюю navigation и centered content. Старую sidebar переносить нельзя |
| [Desktop web 2:103](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-103), [Mobile web 2:104](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-104) | Legacy concept pages в вариантах тем; это макеты, не web runtime или backend |

Metadata и выбранные renders не подтверждают полный prototype walkthrough,
внутренние редакторы, фото/permissions, публичный Resume, сохранение, OAuth или
server publication. Эти сценарии требуют отдельных frames и проверки R1–R7.
Прежние keyframes не имеют статуса DESIGN_READY.

В старых [design contract](../design/design-contract.md),
[design system](../design/design-system.md) и [redesign plan](../design/redesign-plan.md)
встречаются greeting/quick access rail, Projects filters, recolor старого S,
180–300 мс и большие root headings. Последний запрос заменяет их на отсутствие
greeting, фиксированные Home-filter и Projects structure, новый спроектированный
знак, обычные transitions 180–280 мс и компактный root header.
Логотип, переменные и old frames не удаляются; новые согласованные assets
создаются отдельно. Figma selection outlines не являются визуальным приёмом.

---

## Сохранить и изменить

| **Решение** | **Предмет и причина** |
|:---|:---|
| Keep | Material 3, dark/light, ru/en, SafeArea, nested Back, guards, Repository/Riverpod boundaries и существующие интеграции |
| Keep | Working/durable/outbox/server ACK, UID isolation, explicit guest transfer, recoverable legacy formats и private notes |
| Keep | GitHub cache/pagination/retry/dedup, manual overrides, explicit Add/Accept/Ignore/Save; deterministic read-only suggestions |
| Replace | Home dashboard → mixed library, четыре roots с постоянными labels, contextual gear → настоящие nested Settings |
| Replace | Один Portfolio preview → список outputs; plain Resume → структурированный документ/wizard; Global featured/visible → attachment свойства |
| Replace | Slash tech → icon+text badges; abstract profile poster → выбранное фото или нормальный no-photo вариант; letters → аккуратные no-cover states |
| Remove from UI | Root logout/DEMO/greeting/readiness/counters, большие Projects/GitHub shortcuts на Home, Projects category panel, tablet sidebar, oversized decorative settings hero |
| Add to design | Полные profile/contacts/account/privacy screens, focused editors, link access after publication, update review, document settings и responsive/motion/state set |
| Separate product work | Multiple-output migration, media/Storage, account lifecycle, public privacy hardening, web implementation и Inbox/FCM; не fake-success actions в R8 |

Удаление отменённых элементов из UI не означает удаления бизнес-логики,
зависимостей, assets, тестов или integrations. Existing shared UI/theme механизмы
адаптируются при R8; новые визуальные components допустимы там, где legacy мешает,
без второй параллельной runtime design system.

[StackCardButton](../../apps/mobile/lib/shared/widgets/stackcard_button.dart),
40–47 и 111–114, уже задаёт минимум 48×48 и loading semantics. Порядок/видимость
блоков имеют альтернативные Up/Down controls в
[builder panels](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_builder_panels.dart),
210–328. Эти работающие механизмы нужно адаптировать, а не заново заменять
необязательным drag-and-drop.

---

## Продуктовые пробелы

Эти IDs — реестр отсутствующих или неполных product contracts. Это не новые
разрешённые задачи основного roadmap. Они не блокируют UX/design R1–R7;
перед R8 нужно отдельно согласовать предпосылки либо честно ограничить перенос.

| **Gap ID** | **Пробел, зависимость и проверяемый будущий результат** |
|:---|:---|
| GAP-DATA-01 | Singleton → DeveloperProfile/Projects Library/multiple Resume/Portfolio; отдельное согласование модели и migration. Сохранить notes, resumeText, curated projects, source metadata и UID data; миграцию проверить reopen/compatibility tests |
| GAP-DATA-02 | Attachment order/featured/visibility, create+attach/remove-only-relation. Проверить reuse одного Project в нескольких outputs и сохранность library/других links при remove |
| GAP-DATA-03 | Предложение profile data новым outputs и explicit review обновлений существующих; selections/local overrides. Проверить, что base edit не меняет старый документ или published snapshot незаметно |
| GAP-MEDIA-01 | Gallery/camera/photo replacement/removal, upload/retry, MIME/size, cleanup и Storage Rules — основная Phase 11. Проверить permissions, no-photo, preview и owner/public access |
| GAP-PUB-01 | Public Resume и несколько Portfolio snapshots; explicit publish/unpublish UI, постоянные Copy/Open/Share и dirty-published state. Основа transaction есть; новое document addressing и public readers отсутствуют |
| GAP-PUB-02 | Глубокая server validation/public projection для нового data contract; см. раздел ниже. Проверить direct SDK writes, hidden/private fields и отсутствие утечки через nested arrays |
| GAP-URL-01 | Username/output URL policy, multiple slugs и rename последствия. Сейчас old URL удаляется, redirects нет; пользователь должен согласовать сохранение или прекращение старых адресов до реализации |
| GAP-AUTH-01 | Открытая Phase 7: Google provider/config/native flow, полный reset и iOS. Подтверждать реальным SDK/native evidence, не наличием кнопки или mocked tests |
| GAP-ACCOUNT-01 | Login email verification/change, password change/reauth, provider inventory/link/unlink/last-provider protection, account/data deletion. Существующий API делает sign-in, не управление провайдерами |
| GAP-CONTACT-01 | Public email/optional phone, link reorder/selection/overrides и privacy; отдельные поля от login email. Обращения/anti-spam/Inbox/FCM и уведомления — основная Phase 14; browser push не добавляется автоматически |
| GAP-WEB-01 | Next.js landing/download/auth/workspace/public readers и mobile↔web acceptance — основная Phase 13a→13b→13c. В R6 готовится дизайн всех поверхностей; implementation отсутствует |
| GAP-PREF-01 | Reduced motion preference/static variants и notification settings. Theme/locale сохраняются сейчас; новые settings нельзя показывать как уже persisted/connected |

Native Android sharing/QR пока относятся к Phase 15. «Скопировать ссылку» и
«Поделиться» должны обозначать реальные поддерживаемые действия; макет share
sheet не подтверждает Kotlin MethodChannel или iOS sharing.

Предыдущий roadmap Phase 13 описывает одно портфолио. Перед продуктовой реализацией
multiple outputs потребуется согласованный scope update его условий приёмки.
R0 сохраняет roadmap и историю, не переписывает эти фазы автоматически.

---

## Публикация и приватность

Текущий [publication adapter](../../apps/mobile/lib/features/portfolio_draft/data/firestore_portfolio_publication_repository.dart)
подготовлен для explicit online action. Строки 41–61 читают актуальный private
draft и отклоняют отсутствующий/несохранённый/stale content. Строки 67–88 меняют
account pointer, username reservation и public snapshot одной transaction.
Unpublish (97–111) удаляет snapshot/claim, сохраняя private draft.
Sync и GitHub refresh не вызывают публикацию.

Это одна публикация на username, а не multiple Resume/Portfolio contract.
Rename (69–72) удаляет прежний public snapshot и reservation; старый username
может занять другой владелец. Нельзя обещать постоянную доступность прежнего URL
или redirects. Draft username editing не выполняет cloud reservation.

[Public codec](../../apps/mobile/lib/features/portfolio_draft/data/portfolio_public_content_codec.dart),
строки 5–57 и 60–78, физически исключает hidden blocks/projects, GitHub accepted
source/override/ignore metadata. Private notes находятся вне content.
Публичный renderer должен читать snapshot, а не private owner draft.

[Firestore Rules](../../firebase/firestore.rules), строки 119–168, ограничивают
private draft UID владельца; 172–221 связывают account/claim/snapshot через
post-write state и защищают имя от захвата. Public anonymous `get` разрешён,
collection `list` запрещён (190–192).

Статическое ограничение: Rules проверяют skills/projects/experience/education/
links/blocks только как `list` (38–49); allowlist public fields относится к
верхнему уровню (52–57). `sourceMutationId` связывается с private draft
(208–211), но равенство public content безопасной client projection сервером
не доказывается. Полная validation элементов списков сейчас принадлежит codec.
Проверка официального клиента не равна защите от произвольной owner SDK-записи.

Это зафиксированный GAP-PUB-02, а не проверенный exploit. В R0 не меняются Rules
и backend. До публичного rollout новой schema нужна отдельная реализация и
Rules/projection acceptance; требования REQ-SHARE-01 и privacy нельзя подтвердить
только отсутствием полей на screenshot.

---

## Проверки и ограничения

Реальные тестовые источники, которые нужно сохранить и учитывать при переносе:

- [widget_test.dart](../../apps/mobile/test/widget_test.dart) и [responsive_test.dart](../../apps/mobile/test/responsive_test.dart) — UI/navigation/responsive;
- [account_navigation_test.dart](../../apps/mobile/test/account_navigation_test.dart), [account_auth_ui_test.dart](../../apps/mobile/test/account_auth_ui_test.dart), [firebase_auth_google_test.dart](../../apps/mobile/test/firebase_auth_google_test.dart) — auth/session/UI contracts;
- [local_draft_accounts_test.dart](../../apps/mobile/test/local_draft_accounts_test.dart), [cloud_guest_transfer_journal_test.dart](../../apps/mobile/test/cloud_guest_transfer_journal_test.dart) — UID/guest/recovery;
- [portfolio_domain_test.dart](../../apps/mobile/test/portfolio_domain_test.dart), [portfolio_builder_forms_test.dart](../../apps/mobile/test/portfolio_builder_forms_test.dart), [portfolio_draft_controller_test.dart](../../apps/mobile/test/portfolio_draft_controller_test.dart) — validation, CRUD, input/Save;
- [portfolio_draft_schema_migration_test.dart](../../apps/mobile/test/portfolio_draft_schema_migration_test.dart), [portfolio_sync_repository_test.dart](../../apps/mobile/test/portfolio_sync_repository_test.dart) — legacy formats, outbox/ACK/reopen;
- [portfolio_github_sync_test.dart](../../apps/mobile/test/portfolio_github_sync_test.dart), [github_smart_sync_widget_test.dart](../../apps/mobile/test/github_smart_sync_widget_test.dart), [github_persistence_test.dart](../../apps/mobile/test/github_persistence_test.dart) — explicit review, overrides, cache;
- [portfolio_public_content_test.dart](../../apps/mobile/test/portfolio_public_content_test.dart), [firestore_publication_adapter_test.dart](../../apps/mobile/test/firestore_publication_adapter_test.dart), [firestore_rules.test.mjs](../../firebase/test/firestore_rules.test.mjs) — projection, transaction и реальные Rules;
- [account_runtime_test.dart](../../apps/mobile/integration_test/account_runtime_test.dart), [firestore_runtime_test.dart](../../apps/mobile/integration_test/firestore_runtime_test.dart) — отдельная opt-in native acceptance, не обычный static аудит.

Часть тестов закрепляет отменённый UI:
[widget_test.dart](../../apps/mobile/test/widget_test.dart), строки 32, 52 и
155, ожидает STACKCARD/DEMO или greeting; 53–61 — прежние destination icons и
Appearance. В R8 эти assertions заменяются проверками новых требований,
сохраняя navigation/state сценарии. Старые goldens и успешный прошлый run не
являются критериями готовности Design v2.

Команды и preconditions принадлежат [CONTRIBUTING](../../CONTRIBUTING.md#проверки).
В R0 Flutter analyze/tests, native launch, Firebase live/emulator suites и deploy
не запускались. Наличие test файла не подтверждает его прохождение.
Записанные прежде 822 Flutter tests и Android launch в Phase 10, а также Rules
и native sync acceptance Phase 8–9 остаются историческим evidence своего scope.

Выполненная проверка документов охватывает реальные пути, Markdown anchors,
TOC и согласованность утверждений со source. Она не закрывает визуальную
приёмку, контраст, tap targets, keyboard/text scaling или backend безопасность.
Полный R0 registry и результаты document checks фиксирует ведущий в plan.

Доступ к Figma не является блокером. Не проверены полный walkthrough старого
prototype, все internal flows, финальные dark/light/responsive/motion variants
и публичный Resume. Они остаются задачами дизайна, а не поводом придумывать
node IDs или объявлять готовность.

Нерешённые продуктовые вопросы: политика URL при rename/multiple outputs,
границы отдельной migration и account lifecycle implementation перед R8.
Зафиксированные palette/navigation/Home/settings решения повторно не обсуждаются.
После R0 работа останавливается для согласования плана; следующая допустимая
задача — R1.1 из [plan.md](plan.md).
