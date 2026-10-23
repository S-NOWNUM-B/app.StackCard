# AI router StackCard

Начало: [общие правила](AGENTS.md). Общие правила хранятся в репозитории;
отдельные копии для разных AI-клиентов не требуются.

Phase18 CI/CD завершена2026-10-23: GitHub green/red runs и artifacts проверены.
Переход к Phase19 требует отдельного поручения.
Source/local и Android Phase 17 проверены; отложенный iOS и незакрытые
проверки Phase 15–16 отдельно сохраняются в product spec.
Native Share переиспользует существующий канал; новые root-вкладки не добавляются.

Действующий продуктовый контракт 2026-10-12 — [одно основное портфолио](../decisions/0005-single-main-portfolio.md):
3 roots, durable Home/PDF/Share, Library+Editor, optional4step onboarding,
Firestore avatar и ручной город. Оно заменяет D048 UI и Phase12 GPS, сохраняя
старые данные/URL. Исторические scopes ниже не возвращают старый интерфейс.

Перед любой задачей по разработке продукта обязательно прочитай
[план разработки](../product/product-spec.md#план-разработки),
[текущий статус](../product/product-spec.md#статус-и-границы-текущей-работы)
и действующий scope. С 2026-10-07 очередь фаз поставлена на паузу прямым
поручением пользователя: mobile capabilities по Figma/концепции разрешены
в границах product status. Исторические задачи и открытые проверки сохраняются.
Актуальная [последовательность capabilities](../product/product-spec.md#актуальная-последовательность-2026-10-21)
обновлена 2026-10-08 под multiple documents/Figma. D048: ответ «Также реализовать
web и публикацию» разрешает mobile/web/publication перенос без повторного phase
approval. Minimal public reader не зависит от полного owner web editor;
старый singleton roadmap не выполнять. Последующий ответ «Да, выполнить
визуальную проверку web/mobile» разрешает D048 preview/browser/native checks;
deploy/billing/Git сохраняют отдельные ограничения.
Прямой переход пользователя 2026-10-09 разрешает Phase 14 Contact/Inbox/FCM;
контракт — [ADR 0004](../decisions/0004-contact-inbox-notifications.md).
Открытые проверки прошлых фаз и следующий переход остаются в product spec.
Порядок задают [общие правила выполнения плана](AGENTS.md#разработка-по-плану).

| Задача | Читать | Canonical source |
| --- | --- | --- |
| Commit, pull, rebase, push и исправление истории | [Git workflow](GIT_WORKFLOW.md) | [шаблон commit-msg](../../tools/git/commit-msg), [validator](../../tools/git/validate_commit_message.py), реальные status/diff, сохранённые commit objects/body, upstream и актуальные remote refs |
| CI/CD, checks, APK и coverage artifacts | [CI scope](scopes/ci.md), [Phase 18](../product/product-spec.md#phase-18--cicd), [команды](../../CONTRIBUTING.md#cicd--phase-18) | `.github/workflows/ci.yml`, `.fvmrc`, `.node-version`, `.java-version`, actual manifests/lockfiles, `tools/redesign/check_imports.py`, `tools/testing/check_coverage.py` |
| Testing / coverage / journeys | [Phase 17](../product/product-spec.md#phase-17--testing), [команды](../../CONTRIBUTING.md#testing--phase-17) | `tools/testing/check_coverage.py`, `tools/testing/native_journey.py`, mobile `main_portfolio_journey_test.dart` и `integration_test/main_portfolio_runtime_test.dart`, web `main-portfolio-journey.bridge.mjs`, `tool/testing/emulator-journey.cjs`, actual backend/Rules suites; evidence в `docs/product/evidence/phase17` |
| Performance / measurements | [Phase 16](../product/product-spec.md#phase-16--performance), [команды](../../CONTRIBUTING.md#performance--phase-16), mobile/web scope | `apps/mobile/tool/performance`, `apps/web/tool/performance`; raw evidence в `docs/product/evidence/phase16`; native DevTools отдельно от host diagnostics |
| Developer Card / QR / Share | [Phase 15](../product/product-spec.md#phase-15--developer-card-и-native-sharing), [architecture](../architecture/architecture.md#developer-card-и-qr--phase-15), mobile scope | `portfolio_draft/domain/developer_card.dart`, public codec/Firestore adapter, UID-bound providers и card screen; existing `stackcard/document_links` channel |
| Contact form, private Inbox и native FCM | [ADR 0004](../decisions/0004-contact-inbox-notifications.md), [Contact contract](../architecture/architecture.md#contact-inbox-и-уведомления--phase-14), web/mobile/firebase scopes | `firebase/functions/src/server.mjs` (Spark Node runtime), shared `contact-*.mjs`, Rules/indexes; web contact contract/repository/form/Inbox; mobile `features/inbox`, `features/notifications`, LocalRuntime/router |
| Разработка продукта: scope, capabilities, история фаз и сценарии | [План разработки](../product/product-spec.md#план-разработки), [Product spec](../product/product-spec.md), [правила фаз](AGENTS.md#разработка-по-плану) | Действующий scope и открытые критерии в product spec, последнее поручение пользователя и фактическая реализация |
| Структура/зависимости mobile | [Mobile rules](scopes/mobile.md), [architecture](../architecture/architecture.md), [решения](../decisions/README.md) | `apps/mobile/pubspec.yaml`, `apps/mobile/pubspec.lock`, `apps/mobile/lib`, platform configs |
| Структура и scope web | [Web scope](scopes/web.md), [Web README](../../apps/web/README.md), [architecture](../architecture/architecture.md#web-и-общие-контракты) | `apps/web/src`, `package.json`/lockfile, `next.config.ts`, `tsconfig.json`, `.env.example`; Next.js runtime |
| Публикация отдельных документов, постоянный URL, trusted projection/media/delete | [Publication contract](../architecture/architecture.md#privatepublic-schema-и-явная-публикация), [Firebase scope](scopes/firebase.md), [Web scope](scopes/web.md), [prerequisites](../redesign/prerequisites.md#publication-url-delete--отдельный-продуктовый-пакет) | `firebase/functions`, `firebase/firestore.rules`, `firebase/storage.rules`, mobile document-publication API, web owner/public clients; подробные paths и текущая проверка — в architecture/product spec |
| Repository, DI и feature boundaries | [Architecture](../architecture/architecture.md#mobile-modules--при-реальных-сценариях), [Mobile rules](scopes/mobile.md), [решения](../decisions/README.md) | Public feature APIs, domain contracts, feature-root providers/dependencies, data implementations |
| Firebase Auth, session, route guards и guest/UID isolation | [Auth/local accounts contract](../architecture/architecture.md#authentication-и-изоляция-локального-draft), [Mobile rules](scopes/mobile.md), [решения Phase 7](../decisions/README.md#принято-для-phase-7) | [auth API](../../apps/mobile/lib/features/auth/auth.dart), [LocalRuntime](../../apps/mobile/lib/app/local_runtime.dart), [router](../../apps/mobile/lib/app/app_router.dart), [draft DI](../../apps/mobile/lib/features/portfolio_draft/portfolio_draft_providers.dart), [LocalDraftAccounts](../../apps/mobile/lib/features/portfolio_draft/data/local_draft_accounts.dart), generated [Firebase options](../../apps/mobile/lib/firebase_options.dart) и native configs |
| Firestore sync, private/public schema, Rules и Emulator Suite | [Sync/publication contract](../architecture/architecture.md#source-draft-и-публикация), [ADR 0001](../decisions/0001-firestore-sync-and-publication.md), [Firebase rules](scopes/firebase.md), [Mobile rules](scopes/mobile.md) | [sync API](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_sync.dart), [local-first repository](../../apps/mobile/lib/features/portfolio_draft/data/synced_portfolio_draft_repository.dart), [Rules](../../firebase/firestore.rules), [Firebase config](../../firebase/firebase.json), [test scripts](../../firebase/package.json); setup/acceptance в [CONTRIBUTING](../../CONTRIBUTING.md#firestore-rules-и-native-sync-acceptance) |
| GitHub HTTP, pagination, retry и offline cache | [GitHub Import contract](../architecture/architecture.md#github-import-http-и-persistent-кэш), [Mobile rules](scopes/mobile.md), [решения](../decisions/README.md#принято-для-phase-5) | `apps/mobile/lib/features/github_import`: pure Dart metadata, DTO, repository/cache и controller; Dio settings в DI, Hive adapter из LocalRuntime |
| Smart GitHub import/review, overrides и Ignore | [Smart Sync contract](../architecture/architecture.md#smart-github-sync-и-ручные-overrides), [ADR 0002](../decisions/0002-github-import-and-review.md), [Mobile rules](scopes/mobile.md) | [pure sync rules](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_github_sync.dart), [bridge](../../apps/mobile/lib/features/github_import/github_portfolio_providers.dart), public draft controller/codec; сохранение остаётся через прежний repository |
| Portfolio Suggestions, пороги и объяснения | [Suggestions contract](../architecture/architecture.md#portfolio-suggestions), [Mobile rules](scopes/mobile.md) | [pure rules](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_suggestions.dart), public draft providers и общий suggestions UI; явно заданное время, без отдельного storage/HTTP |
| Avatar/project images, camera/gallery и Storage | [Media contract](../architecture/architecture.md#приватные-изображения--phase-11), [ADR 0003](../decisions/0003-private-portfolio-media.md), [mobile](scopes/mobile.md), [Firebase](scopes/firebase.md) | `features/media`, private media paths в draft, `firebase/storage.rules`; setup/проверки в CONTRIBUTING |
| Основное портфолио, migration/onboarding/PDF/avatar/manual city | [ADR 0005](../decisions/0005-single-main-portfolio.md), [современная architecture](../architecture/architecture.md#одно-основное-портфолио), mobile/web/firebase scopes | Existing workspace/main helpers/codecs/controllers, main editor/Home/PDF; `features/media` Firestore adapter; `locationText` без GPS |
| Bootstrap, local storage и portfolio Builder | [Local persistence contract](../architecture/architecture.md#локальные-настройки-и-draft-на-phase-5), [Builder contract](../architecture/architecture.md#portfolio-domain-и-локальный-builder), [Mobile rules](scopes/mobile.md), [решения Phase 6](../decisions/README.md#принято-для-phase-6) | [LocalRuntime](../../apps/mobile/lib/app/local_runtime.dart), [LocalStorage](../../apps/mobile/lib/core/storage/local_storage.dart) и public [portfolio_draft.dart](../../apps/mobile/lib/features/portfolio_draft/portfolio_draft.dart) |
| AppSettings compatibility, light-only/ru runtime | [Mobile rules](scopes/mobile.md), [Local persistence contract](../architecture/architecture.md#локальные-настройки-и-draft-на-phase-5), [Design system](../design/design-system.md) | [core/state](../../apps/mobile/lib/core/state/), [core/localization](../../apps/mobile/lib/core/localization/) и [SharedPreferences adapter](../../apps/mobile/lib/features/settings/data/shared_preferences_settings_repository.dart) |
| UI и branding | [Design system](../design/design-system.md#монохромный-бренд) | `assets/branding/stackcard-v2-brand-kit.json`, pinned original Design v2 SVG и source manifest; существующие widgets. Link/Accent — история |
| StackCard Design v2: аудит, дизайн и перенос UI | Сначала [Redesign README](../redesign/README.md) и [план R0–R9](../redesign/plan.md), затем [требования](../redesign/requirements.md), [аудит](../redesign/audit.md), [экраны](../redesign/screens.md), [референсы](../redesign/references.md) | Последние решения пользователя, активная согласованная R-задача и проверенные source/Figma IDs; прежние docs/design сохраняются как история; R7/DESIGN_READY acceptance остаётся открытой; mobile capability scope разрешён 2026-10-07 |
| Запуск, lint, tests | [CONTRIBUTING](../../CONTRIBUTING.md#быстрый-старт), [Mobile README](../../apps/mobile/README.md) | `apps/mobile/analysis_options.yaml`, `test`, Flutter SDK |
| State management и учебные этапы | [Mobile rules](scopes/mobile.md), [state management](../learning/state-management.md) | AppearanceController для AppSettings; публичные feature APIs и Riverpod DI; учебные patches вне runtime |
| Публичное описание проекта | [Root README](../../README.md), [Product spec](../product/product-spec.md) | Назначение, подтверждённые сценарии и фактическая доступность продукта |

Порядок: инструкции → актуальные sources и аналог → непосредственно применимые
skills из доступного каталога → минимальные изменения → проверки и diff.
Если skill недоступен, продолжить по project rules без его установки.

`project-documentation` — единый skill для текста, визуального оформления и
синхронизации docs с реализацией; `project-context-bootstrapper` — для
устойчивых placement/check rules; `codex-subagent-orchestrator` — для независимых
частей при разрешённой делегации. Skill не меняет действующий scope и не добавляет
неиспользуемые зависимости. Новые guides создаются только при реальной необходимости.

Корневой README — публичный обзор StackCard: назначение, аудитория, возможности,
пользовательский путь и принцип работы. Он не содержит дерево
репозитория, roadmap, фазы, команды разработки или внутренние AI-правила.
Принятую редакцию README сохранять: статус реализации раскрывается в product spec,
служебная отметка статуса и отдельный раздел контроля публикации в README не нужны.
Пользовательский путь уже объясняет явную публикацию; готовый релиз не заявляется.
Product spec владеет требованиями и roadmap; architecture — устройством системы
и техническими схемами; CONTRIBUTING — локальным запуском, командами и проверками.

Проектные docs используют центрированную шапку с названием, кратким описанием,
читаемыми badges `for-the-badge` и содержанием. Таблицы добавляются для сопоставлений.
Технологические карточки используют SVG `https://img.shields.io/badge/`,
`style=for-the-badge`, название, подтверждённую версию, `logo` и `logoColor`.
Левая часть остаётся стандартной серой, правая — фирменного цвета технологии.
PNG `raster.shields.io` не использовать по умолчанию: он размывается при увеличении.
Alt содержит название и версию; не растягивать badges через width/height.
Логотип документа — существующий Brand A с paper/ink для тёмного/светлого viewer.
В шапке указывать основные технологии без вложенных языков и tooling:
Next.js без React/TypeScript, самостоятельный React без TypeScript/Vite,
Flutter без Dart; тот же принцип действует для остальных frameworks.
Независимые сервисы и базы показывать отдельно. Детали зависимостей оставлять
в manifests и профильных технических разделах, когда они нужны читателю. Badge отражает факт или явно помеченный план. CONTRIBUTING и
module README используют тот же визуальный профиль. AGENTS, AI router, ADR и
standalone runbook сохраняют рабочий формат. Источники фактов — code/configs;
оформление не требует переписывать все документы под публичную аудиторию.

В architecture Mermaid-схемы объясняют связи компонентов и границы данных.
Исходники хранятся в `docs/diagrams/*.mmd`; PNG с теми же узлами и связями
позволяет читать их в viewer без поддержки Mermaid. При изменении схемы
обновлять исходник и изображение вместе, проверять отображение. Целевые узлы
и интеграции помечаются планом. Папки проекта сохраняют принятые имена.

AI-контекст и optional registry размещаются в `docs/AI/`; scope rules —
в `docs/AI/scopes/`. Корневой и вложенные AGENTS направляют к ним. Runtime configs и secrets в эту
директорию не переносятся; product/architecture/design guides остаются в `docs/`.
