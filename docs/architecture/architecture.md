<div align="center">

# StackCard Architecture

**Текущая Flutter-основа и целевые границы mobile, web и общего backend**

![Architecture guide](https://raster.shields.io/badge/Architecture-guide-09090B?style=for-the-badge)
![Stage Phase 12 in progress](https://raster.shields.io/badge/Stage-Phase_12_in_progress-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Текущее состояние — Phase 12](#текущее-состояние--phase-12)
- [Схема системы](#схема-системы)
- [Зоны ответственности](#зоны-ответственности)
- [Целевые границы — ещё не реализованы](#целевые-границы--ещё-не-реализованы)
- [Web и общие контракты](#web-и-общие-контракты)
- [Mobile modules — при реальных сценариях](#mobile-modules--при-реальных-сценариях)
- [Authentication и изоляция локального draft](#authentication-и-изоляция-локального-draft)
- [GitHub Import: HTTP и persistent-кэш](#github-import-http-и-persistent-кэш)
- [Smart GitHub Sync и ручные overrides](#smart-github-sync-и-ручные-overrides)
- [Portfolio Suggestions](#portfolio-suggestions)
- [Локальные настройки и draft на Phase 5](#локальные-настройки-и-draft-на-phase-5)
- [Portfolio domain и локальный Builder](#portfolio-domain-и-локальный-builder)
- [Приватные изображения — Phase 11](#приватные-изображения--phase-11)
- [Source, draft и публикация](#source-draft-и-публикация)
- [Ключевые потоки](#ключевые-потоки)
- [Выбор города и страны — Phase 12](#выбор-города-и-страны--phase-12)
- [Границы расширения](#границы-расширения)
- [Нефункциональные требования](#нефункциональные-требования)
- [Завершение Phase 0](#завершение-phase-0)

---

## Текущее состояние — Phase 12

Phase 10 завершена. На 2026-10-07 реализована Phase 11 Media с открытой приёмкой;
контракт и ограничения описаны в [media](#приватные-изображения--phase-11),
приёмка — в [product spec](../product/product-spec.md#phase-11--media).
По следующему поручению развивается Phase 12: ручной город/страна и
опциональное определение города без карты. Контракт — [ниже](#выбор-города-и-страны--phase-12).

В monorepo есть одно Flutter-приложение в `apps/mobile`. Код Architecture
Phase 3 реализован поверх UI foundation и basic state management;
Phase 4 добавила отдельный GitHub Import с публичным HTTP-источником.
Phase 5 сохраняет настройки, GitHub cache и локальные заметки к портфолио.
Phase 6 расширила тот же draft до локального Builder с ручными формами,
порядком и видимостью блоков, вычисляемой полнотой и preview.
Phase 7 добавила Firebase authentication, защищённую навигацию и локальную
изоляцию guest/UID draft. Android email lifecycle проверен; Google flow,
полный password reset и iOS приёмка остаются открытыми. Отдельно разрешённая
Phase 8 завершена: local-first Firestore sync проверен на Android;
механизм явной публикации подготовлен и проверен в adapter/Rules tests.
Phase 9 завершена: явные GitHub import/review/ignore сохраняют overrides;
private metadata проверены при offline Save, Android restart и cloud ACK.
Phase 10 завершена: read-only подсказки вычисляются pure rules по текущему
content и известным GitHub snapshots; UI предлагает явные Preview/editor actions.
Непроверенные сценарии Phase 7 остаются открытыми.
Приёмка и фактические результаты проверок ведутся в
[product spec](../product/product-spec.md#phase-10--portfolio-suggestions).
Sign In, Home, Portfolio, Projects и Settings сохраняют общий app shell,
Material 3 light/dark. До начала Builder они показывают демонстрационный контент;
после начала — проекции единого рабочего draft через Riverpod. Данные сохраняются
через Repository contracts. Firebase Auth работает через отдельный account API;
Firestore adapter синхронизирует account draft поверх Hive. Publish/unpublish
подготовлены отдельным transaction repository, без публичного экрана или web.
Контракт и последствия LWW зафиксированы до remote writes в
[ADR 0001](../decisions/0001-firestore-sync-and-publication.md).

Текущие используемые области:

```text
apps/mobile/
├── assets/fonts/             # локальные шрифты и лицензии
├── lib/
│   ├── main.dart             # ProviderScope, overrides и GoRouter lifecycle
│   ├── app/                  # router, shell, composition local_runtime.dart
│   ├── core/state/           # neutral AppSettings/repository, AppearanceController
│   ├── core/localization/    # ru/en UI catalogue и delegates
│   ├── core/storage/         # lifecycle отдельных Hive boxes
│   ├── core/theme/           # цвета, Material 3, spacing/radius
│   ├── shared/widgets/       # card, button, input, states, async view, brand
│   └── features/
│       ├── auth/             # public API, DI, presentation/domain/data
│       ├── profile/          # public API, DI, presentation/domain/data
│       ├── projects/         # public API, DI, presentation/domain/data
│       ├── github_import/    # public GitHub source, DTO, Dio, Hive response cache
│       ├── portfolio/        # public API и presentation read model
│       ├── portfolio_draft/  # Builder, Hive/Firestore sync, publication и controller
│       ├── media/            # picker/preprocessing, private Storage, UID-scoped DI
│       ├── location/         # ручной город/страна, optional native geolocation
│       ├── home/             # экран на PortfolioOverview
│       └── settings/         # настройки, SharedPreferences adapter и preview состояний
└── test/                     # contracts, DI, состояние, UI и responsive
```

Маршруты заданы в
[`app_router.dart`](../../apps/mobile/lib/app/app_router.dart): `/sign-in`,
`/register`, `/reset-password`,
`/home`, `/portfolio`, `/projects`, `/settings`, `/github-import`, `/portfolio-draft`,
`/portfolio/builder`, `/portfolio/preview`, `/projects/new` и `/projects/:id/edit`.
Формы Builder используют дочерние пути `profile`, `skills`, `experience`,
`education`, `links`, `resume`. `/` перенаправляет на `/home`. Четыре основных
экрана используют app shell; формы, preview, Sign In, GitHub Import и локальные
заметки открываются отдельно. Маршруты именованы, формы Builder вложены в
`portfolioBuilder`, `editProject` получает параметр `id`. Private routes требуют
активного account либо явно выбранного локального guest-режима;
GitHub Import и auth forms публичны. `from` возвращает к разрешённому локальному
пути после входа. `DemoSession` остаётся preview-механизмом и не авторизует аккаунт.

Dark — режим по умолчанию. Выбор dark/light/system принадлежит
[`AppearanceController`](../../apps/mobile/lib/core/state/appearance_controller.dart),
созданному `ChangeNotifierProvider`. `Selector` подключает его к `MaterialApp`,
Settings читает выбранный mode через `select` и меняет его через `read`.
Router не передаёт theme callbacks и сохраняет экземпляр при смене темы.

[`project_filters.dart`](../../apps/mobile/lib/features/projects/presentation/project_filters.dart)
владеет query/filter state через Riverpod `Notifier`; чистый
[`ProjectFilters`](../../apps/mobile/lib/features/projects/domain/project_filters.dart)
отбирает проекты. `projectsProvider` читает проекцию рабочего Builder content,
а при его отсутствии загружает demo-список из repository;
`visibleProjectsProvider` вычисляет `AsyncValue` с результатами поиска,
`featuredProjectsProvider` отбирает featured независимо от поиска.
Providers без `autoDispose` сохраняют состояние в app session; смена UID или
режима доступа сбрасывает private widget state и фильтры. ThemeMode, ru/en locale и настройка
описаний GitHub cards сохраняются одним versioned snapshot в SharedPreferences;
UI переведён, пользовательский и source content сохраняет исходный язык.

[`StackCardApp`](../../apps/mobile/lib/main.dart) принимает `providerOverrides`
и передаёт их своему `ProviderScope`. Замена repository в DI изменяет данные
реальных экранов без правки widgets. Эволюция темы и границы двух механизмов
объяснены в [state management guide](../learning/state-management.md).

Canonical sources: [`pubspec.yaml`](../../apps/mobile/pubspec.yaml),
[`pubspec.lock`](../../apps/mobile/pubspec.lock),
[`analysis_options.yaml`](../../apps/mobile/analysis_options.yaml).
SDK constraint и разрешённые версии берём из них, native settings — из platform
directories приложения. `.metadata` и generated-файлы вручную не меняем.

Mobile scope — Android и iOS; их native scaffolds сохранены, Android — первый
release target. Desktop и Flutter web targets в `apps/mobile` отсутствуют.
Сайт с публичными страницами и защищённым редактором планируется отдельно
на Phase 13. В [apps/web](../../apps/web/README.md) сейчас только README;
Next.js-приложение, его зависимости и команды запуска ещё не созданы.

Цветовая система и эскизы описаны в [design guide](../design/design-system.md).
Local DM Sans и Noto Sans fallback зарегистрированы в pubspec. Знак в
`StackCardBrand` повторяет paths оригинальных SVG через `CustomPainter`;
logo originals в `assets/branding` сохранены без изменения.

---

## Схема системы

**Целевая архитектура, ещё не реализованная целиком.** UI и локальные
Repository/DI границы — текущая основа mobile. Остальные узлы и связи вводятся на своих фазах.
Схема описывает ответственность компонентов; Firestore schema и атомарная
публикация определены в [ADR 0001](../decisions/0001-firestore-sync-and-publication.md).
Web, Storage и последующие интеграции по-прежнему целевые.

### Общий обзор

![Целевая архитектура StackCard: mobile, web, Firebase и GitHub](../diagrams/architecture-overview.png)

[Mermaid-исходник обзора](../diagrams/architecture-overview.mmd).

### Редактирование и публикация

![Схема StackCard: редакторы, private draft, явная публикация и public snapshot](../diagrams/architecture-system.png)

[Mermaid-исходник схемы](../diagrams/architecture-system.mmd).

Публичная страница не читает private draft. GitHub поставляет предложения для
редактора; только отдельное действие владельца обновляет published snapshot.
Логический узел публикации реализуется client transaction с проверкой связанных
документов в Firestore Rules. Firebase Function или отдельный endpoint для
этого сценария не нужны; пользовательский экран вводится на своей фазе.

---

## Зоны ответственности

### apps/mobile

Исполняемый Flutter-клиент для Android и iOS. Сейчас владеет app shell,
основными экранами, GitHub Import, локальным Builder и приватными заметками,
Repository/DI, общей темой/widgets и tests. GitHub cache и явно сохранённый
portfolio draft доступны offline в своём guest/UID namespace. Firebase Auth
отвечает за account session; восстановление сессии блокирует private routes.
Account Save остаётся локальным awaited write; отдельный sync adapter отправляет
durable outbox и получает server updates. Guest не отправляет данные в Firestore.
Другие native integrations вводятся по фазам.
Mobile не владеет реализацией сайта или доверенными серверными операциями.

### apps/web

Отдельный будущий Next.js-клиент: marketing pages, защищённый редактор и
public portfolio. Пока содержит только README. Общие data contracts связывают
клиенты без импорта Flutter/Dart runtime в React/TypeScript.

### firebase

[Каталог Firebase](../../firebase/) содержит Firestore Rules, indexes, Emulator
Suite configuration и отдельные Rules tests с npm manifest/lockfile.
Generated mobile configuration принадлежит `apps/mobile`; service-account
credentials здесь не хранятся. Rules закрывают private account/draft и проверяют
атомарность publication records. Deployment имеет явный project target и
выполняется в рамках разрешённой настройки окружения.

### assets/branding

Оригинальные SVG и brand kit. Mobile mark уже отрисовывается в shared widget;
launcher icons вводятся на Phase 19. Сохранённый оригинал не заменяется
промежуточным экспортом.

### docs и docs/AI

Product spec владеет сценариями и roadmap, architecture — границами системы,
design guide — визуальными правилами, ADR — существенными решениями.
Общие AI-инструкции, router и scope rules хранятся в [docs/AI](../AI/README.md).
Root/nested AGENTS — точки входа к этому контексту, без копий общих правил.
Runtime configs остаются рядом с кодом и сохраняют владение своими значениями.

---

## Целевые границы — ещё не реализованы

<div align="center">

| **Часть** | **Ответственность и срок введения** |
|:---|:---|
| `apps/mobile` | Android/iOS-редактор, offline draft и sync; функции по roadmap |
| `apps/web` | Главная, download, кабинет и public portfolio; Phase 13–14 |
| `firebase` | Firestore Rules, indexes и emulator tests введены на Phase 8; Storage/FCM — будущие фазы |
| `.github/workflows` — ещё не создан | Проверки и APK artifact; Phase 18 |

</div>

Это один продукт, поэтому один monorepo. Firebase project уже создан для mobile
authentication; web подключится на своей фазе. Отдельный NestJS/PostgreSQL
backend в v1 не нужен. Mobile не импортирует
web-код. Публичные страницы читают только опубликованное представление; редактор
в защищённом web-кабинете работает с private draft своего владельца.
Firebase Functions добавляются только при реальной необходимости доверенных
операций. Будущая CI проверит format/analyze/tests/coverage и сохранит APK artifact.

---

## Web и общие контракты

Next.js — целевой стек сайта, пока без созданного приложения и установленных
web-зависимостей. Один Firebase backend и один аккаунт связывают mobile и web.
Клиенты разделяют правила модели, ownership, validation, sync и явной публикации;
Dart и TypeScript реализуют их независимо в своих стеках. Общие data contracts
не означают общий runtime-код или перенос Flutter widgets в React.

Планируемые группы маршрутов, **не существующая конфигурация routing**:

<div align="center">

| **Группа** | **Ответственность и доступ** |
|:---|:---|
| `/`, `/download` | Публичная информация о проекте и мобильных релизах. |
| `/sign-in`, `/sign-up` | Authentication. |
| `/app` и вложенные страницы | Защищённые профиль/проекты/блоки, preview, publish/unpublish, Inbox и настройки своего аккаунта. |
| `/u/[username]` | Только published portfolio, SEO/metadata/OpenGraph; Contact me на Phase 14. |

</div>

Защита маршрута помогает UX, но не заменяет ownership checks в Firebase Rules
и на доверенной стороне. Владелец читает/изменяет свой draft из обоих клиентов;
анонимный посетитель не получает account data, черновики или Inbox.

Mobile сохраняет offline draft и cache. Web v1 планируется online-first с явными
состояниями несохранённых изменений, сохранения, sync error и retry.
Phase 8 выбирает whole-document LWW по порядку server commits и отдельные
private/public документы; контракт — в [ADR 0001](../decisions/0001-firestore-sync-and-publication.md).
Перед Phase 13 проверить совместимость
web-редактора с этой моделью; не создавать вторую независимую модель портфолио.

Phase 13 развивается по шагам: **13a** — public shell, главная и скачивание mobile;
**13b** — auth/защищённый кабинет и редактор общего draft; **13c** — published
портфолио, preview и publish/unpublish. Детали — в [roadmap](../product/product-spec.md#roadmap).
Это план после мобильных фундаментальных фаз; Phase 1 реализует только mobile UI.

---

## Mobile modules — при реальных сценариях

На Phase 3 `auth`, `profile` и `projects` разделены на используемые слои:

```text
features/<feature>/
├── <feature>.dart            # намеренный публичный API
├── *_providers.dart          # либо *_dependencies.dart: DI feature
├── presentation/             # widgets, controllers/notifiers, AsyncValue
├── domain/                   # pure Dart модели, правила и repository contracts
└── data/                     # concrete repositories: demo, HTTP, Hive, Firebase SDK
```

<div align="center">

| **Область** | **Ответственность и публичная граница** |
|:---|:---|
| [auth](../../apps/mobile/lib/features/auth/auth.dart) | Pure Dart `AccountAuthRepository`, `AuthUser`, typed `AuthFailure`; Firebase adapter и Riverpod account session/actions. Legacy `AuthRepository`/`DemoSession` сохранены для preview без native configuration |
| [profile](../../apps/mobile/lib/features/profile/profile.dart) | Immutable read models `Profile`, `ProfileHighlight`, `ProfileReadiness`; `profileProvider` читает проекцию Builder, при отсутствии content — заменяемый demo repository |
| [projects](../../apps/mobile/lib/features/projects/projects.dart) | Read model `Project`, typed `ProjectSource`, `ProjectsRepository`, pure query/filter и featured-отбор; проекция ручных проектов Builder либо demo repository через Riverpod |
| [github_import](../../apps/mobile/lib/features/github_import/github_import.dart) | Public source models и `GitHubImportRepository`; Dio/DTO/cache в data, отдельный Riverpod controller и экран. Не меняет profile/projects/portfolio repositories |
| [portfolio](../../apps/mobile/lib/features/portfolio/portfolio.dart) | `PortfolioOverview` объединяет публичные profile/projects states для Home и demo Portfolio; это presentation read model |
| [portfolio_draft](../../apps/mobile/lib/features/portfolio_draft/portfolio_draft.dart) | Pure Dart portfolio content, validation/completion/suggestions, draft/sync/publication contracts; working controller, Builder/preview, Hive cache/outbox и UID-bound Firestore adapters |
| [media](../../apps/mobile/lib/features/media/media.dart) | Pure picker/repository contracts, MIME/resize preprocessing, UID-bound Storage adapter; editor/image widgets используют публичный API |
| [location](../../apps/mobile/lib/features/location/location.dart) | Pure `PortfolioPlace` и repository; geolocator/native geocoding в data, picker подтверждает только город/страну, без карты |
| Home и Settings | Рендерят данные публичных feature APIs; Home использует overview, Settings — profile state и AppSettings через Provider |

</div>

Зависимости: presentation → domain, data → domain. Корневые DI-файлы feature
связывают repository contract с реализацией. Widgets не импортируют concrete
repositories или mock content. Между features используются публичные
`auth.dart`, `profile.dart`, `projects.dart`, `portfolio.dart`, `github_import.dart`,
`portfolio_draft.dart`;
внутренние файлы другой feature не импортируются.

Domain использует только Dart и не зависит от Flutter, Riverpod, Dio, Hive или
Firebase. Model collections защищены от внешнего изменения. UI auth/profile/projects
получает `AsyncValue`; GitHub Import использует `GitHubImportState` для списка,
refresh и pagination. Loading/error и явный retry показываются общими widgets,
empty обрабатывается соответствующим экраном. Repository отвечает за источник,
controller/notifier — за действие или состояние; pure domain — за правила.
UseCase/DataSource не созданы: mock repositories и GitHub HTTP-adapter
достаточны для текущих сценариев, без дополнительного промежуточного слоя.

`ProfileReadiness` предоставляет счётчики и долю/процент для read model:
demo repository задаёт их в snapshot, проекция Builder получает результат pure
`calculatePortfolioCompletion`. `PortfolioOverview` не является draft, опубликованной версией или
контрактом синхронизации.

Provider владеет ThemeMode, Locale и простой настройкой отображения описаний.
Их neutral immutable contract — `core/state/AppSettings`, persistence adapter —
`features/settings/data`; core не импортирует settings feature. Riverpod управляет product state,
асинхронными repository данными и DI. Эволюция `setState → InheritedWidget → Provider`
сохранена в [учебном guide](../learning/state-management.md), в `lib` осталась
одна итоговая реализация темы. GoRouter владеет маршрутизацией; Dio и JSON DTO
используются GitHub Import. Auth redirects читают account/guest access gate;
router не владеет auth session или draft.

---

## Authentication и изоляция локального draft

[`AccountAuthRepository`](../../apps/mobile/lib/features/auth/domain/account_auth_repository.dart)
определяет email/password sign-in, registration, password reset, Google sign-in,
sign out и stream с nullable [`AuthUser`](../../apps/mobile/lib/features/auth/domain/auth_user.dart).
Domain не импортирует Firebase. [`FirebaseAccountAuthRepository`](../../apps/mobile/lib/features/auth/data/firebase_account_auth_repository.dart)
преобразует SDK user и ошибки в pure Dart user/typed failure; reset UI не раскрывает
существование email. Google credential получается через native Google Sign-In
и передаётся Firebase Auth. Session persistence принадлежит SDK; приложение
не записывает password, OAuth credential или auth token в Hive/preferences.

[`auth_providers.dart`](../../apps/mobile/lib/features/auth/auth_providers.dart)
разделяет session stream, async actions и явно выбранный `guestAccessProvider`.
Session stream не делает автоматический retry; UI показывает restoring/error
и предлагает явный повтор подписки.
Legacy demo API доступен в `StackCardApp` без account adapter для UI preview/tests;
native entry всегда выполняет Firebase configuration. Ошибка configuration
показывается bootstrap error/retry и не включает demo-вход вместо аккаунта.
Restoring/error/signedOut без явного guest access блокируют private repository
и routes; нельзя читать guest или последнего пользователя как fallback.

[`LocalRuntime`](../../apps/mobile/lib/app/local_runtime.dart) и
[`main.dart`](../../apps/mobile/lib/main.dart) связывают Firebase adapter и
`portfolioDraftRepositoryFactoryProvider` с локальным storage. Firebase project
и Android/iOS apps зарегистрированы; canonical configuration находится в
[`firebase_options.dart`](../../apps/mobile/lib/firebase_options.dart),
[`firebase.json`](../../apps/mobile/firebase.json),
[`google-services.json`](../../apps/mobile/android/app/google-services.json) и
[`GoogleService-Info.plist`](../../apps/mobile/ios/Runner/GoogleService-Info.plist).
FlutterFire-generated sources обновляются генератором, runtime initialization
остаётся обычным code в `LocalRuntime`. Dev Auth Emulator выбирается через
`FIREBASE_AUTH_EMULATOR_HOST` и `FIREBASE_AUTH_EMULATOR_PORT`; этот режим не
заменяет проверку реального Google flow и native session restore.

[`LocalDraftAccounts`](../../apps/mobile/lib/features/portfolio_draft/data/local_draft_accounts.dart)
сохраняет guest в прежних keys `draft`/`draft.v1.backup`, а каждый account — в
namespace по base64url UTF-8 UID со своим v1 backup. Notes, content, revision и
metadata сохраняются в прежнем envelope; app settings и public GitHub cache
не зависят от UID и сохраняются после sign out. Shared serial queue Box
исключает гонки между repository instances и transfer. In-flight save всегда
пишет в namespace своего repository, даже при смене активного UID.

Перенос guest выполняется только явным действием из Settings. В configured
runtime начало требует сети и пустого target как в local namespace, так и в
Firestore; пустой offline cache не доказывает, что cloud draft отсутствует.
[`LocalRuntime.transferGuestToUser`](../../apps/mobile/lib/app/local_runtime.dart)
проверяет server-only read перед новым переносом; при своём pending journal
продолжает recovery. Corrupt/unsupported source, target или sync metadata
блокируют перенос без перезаписи. V1 читается без migration; при явном переносе
raw envelope/backup сохраняются, последующая ACK migration может создать v4.

Durable owner journal записывается до online cloud claim. Transaction создаёт
private current draft только при отсутствии записи; повтор разрешён только для
того же transfer mutation ID, notes и content. Занятый cloud draft не заменяется,
creation race закрывается transaction. Подтверждённый occupied-cloud conflict
освобождает незавершённый journal, пока local destination отсутствует и перенос
не committed, включая recovery после потерянного ACK. Удаляется только validated
sync metadata той же transfer mutation; guest и новая cloud версия сохраняются.
Неоднозначный сетевой сбой оставляет source reserved за тем же UID.
Remote ACK metadata сохраняется до local destination/cleanup, затем durable
`syncPrepared` отмечает этап: recovery после него не повторяет cloud claim и не
перезаписывает более новые remote правки. После destination/backup write
фиксируется committed claim, меняется guest generation, удаляются guest records
и journal. Flush завершает каждый этап. Обычный draft sync по-прежнему использует LWW;
online compare-and-set относится только к явному guest transfer.
Журнал Phase 7 без syncPrepared с уже записанной destination завершает прежний
локальный перенос через durable legacyLocalCommit. Сохранённая тогда pending
версия участвует в обычном LWW; это не новый cloud claim или server ACK.
При неоднозначном сбое исходные данные и journal сохраняются; guest и целевой account
блокируются до явного retry transfer тем же UID. Второй UID не может получить
reserved source. Persistent generation запрещает старому guest repository,
включая queued save, воскресить уже переданный draft; новый guest getter
получает новое пустое поколение. Availability reserved transfer учитывает активный
UID и предлагает retry только владельцу journal. После transfer controller
перечитывает target, только если нет новых working edits или выполняемого Save;
иначе сохраняет рабочий ввод и сообщает о завершённом переносе. Это изоляция
приложения, не шифрование Box.

UID/access transitions заменяют draft repository/controller и его projections,
сбрасывают фильтры и private form widget state. Sign out при unsaved changes
требует подтверждения их отбрасывания; durable account draft остаётся на устройстве.
Firestore sync использует тот же UID boundary; его storage/status/publication
контракт описан [ниже](#source-draft-и-публикация).
Обязательная live auth и iOS приёмка отражается только по результатам проверки
в [Phase 7](../product/product-spec.md#phase-7--firebase-authentication).

---

## GitHub Import: HTTP и persistent-кэш

`Projects → GitHub Import → username → profile + repositories` — отдельный
просмотр источника. `GitHubProfile` и `GitHubRepository` не являются `Profile`
или curated `Project`; Phase 9 связывает repository с draft только явными actions.

[`GitHubImportController`](../../apps/mobile/lib/features/github_import/presentation/github_import_controller.dart)
управляет загрузкой, refresh, pagination и локальным поиском. Первые profile/page
публикуются как один успешный snapshot. При неудачном refresh или запросе следующей
страницы прежний список остаётся виден вместе с ошибкой и retry. Новый username
заменяет результат; controller отменяет старые запросы и проверяет generation,
чтобы запоздалый ответ не заменил новый профиль. Закрытие экрана освобождает
autoDispose scope и debounce timer.
HTTP repository остаётся в app session: повторное открытие экрана не сбрасывает
rate deadline. Controller отменяет активные requests при dispose; Dio закрывается
при завершении app scope.

[`DioGitHubImportRepository`](../../apps/mobile/lib/features/github_import/data/dio_github_import_repository.dart)
владеет HTTP, строгим parsing DTO, отменой и преобразованием сетевых ошибок в
pure Dart `GitHubFailure`. Feature-root DI создаёт Dio с ограниченными timeout;
widgets не знают о transport. JSON `fromJson/toJson` написаны вручную для двух
небольших DTO: codegen dependencies не нужны. Ответы с null/пустыми optional
полями допустимы, некорректные обязательные поля дают `invalidResponse`.

Pagination следует `Link` с `rel="next"`, включая numeric `/user/{id}/repos`,
который реально возвращает GitHub. Принимаются только HTTPS-ссылки
`api.github.com` на repositories загруженного профиля. Кнопка «Загрузить ещё»
запрашивает следующую страницу; результаты объединяются по стабильному ID.
Поиск по названию/описанию/языку имеет debounce 300 ms, фильтры работают локально
на загруженных страницах; GitHub Search API не используется.

[`GitHubResponseCache`](../../apps/mobile/lib/features/github_import/data/github_response_cache.dart)
— используемый async contract data-слоя. Bootstrap подставляет
[`HiveGitHubResponseCache`](../../apps/mobile/lib/features/github_import/data/hive_github_response_cache.dart);
memory default сохраняет изоляцию tests. JSON envelope v1 содержит body,
ETag, Link и UTC last-validation timestamp, key — request URI. Срок доступности
копии — 7 дней с последнего успешного `200/304`; будущая дата, неизвестная schema,
повреждённый ответ и истёкшая запись считаются cache miss и удаляются только из cache box.

GET сначала проверяет GitHub; `If-None-Match` посылается при сохранённом ETag,
`304` восстанавливает проверенные body/Link и обновляет срок. Только network,
timeout и server failures допускают fallback к валидной сохранённой копии.
Not found, forbidden, invalid response, rate limits и отмена не маскируются кэшем.
`GitHubReadMetadata` сообщает source provenance/date и storage failures;
смешанный снимок остаётся отмеченным как cached до успешного full refresh.
Ошибка записи не скрывает успешный HTTP, но UI предупреждает об отсутствии
надёжной device copy. Cancellation проверяется на всех cache awaits.

На 3 октября 2026 проверены официальные
[users](https://docs.github.com/en/rest/users/users#get-a-user),
[repositories](https://docs.github.com/en/rest/repos/repos#list-repositories-for-a-user),
[pagination](https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api),
[API versions](https://docs.github.com/en/rest/about-the-rest-api/api-versions) и
[rate limits](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api).
API version явно закреплена в adapter/DI. Публичный доступ без токена имеет
60 запросов в час на исходящий IP. Retry выполняется явно; `403/429` с признаками
rate limit показывают срок из `Retry-After`/`X-RateLimit-Reset` или безопасную
паузу, до которого новые запросы блокируются. Unauthenticated `304` не заявляется
как обход rate limit: освобождение от primary quota требует корректной
авторизации по [GitHub best practices](https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api).

Парсинг, HTTP/cache/сбои, controller races и реальные widgets проверяются
`github_data_test.dart`, `github_import_controller_test.dart` и
`github_import_widget_test.dart`. Persistent cache, TTL и reconnect покрыты
`github_persistence_test.dart`; актуальные результаты и native limitations — в
[приёмке Phase 5](../product/product-spec.md#phase-5--local-persistence--offline).

---

## Smart GitHub Sync и ручные overrides

[`GitHub bridge`](../../apps/mobile/lib/features/github_import/github_portfolio_providers.dart)
связывает source metadata с публичным draft API. Public browsing не открывает
private repository до account/explicit guest access. Load/refresh/pagination
не меняют working content. Add/Accept/Ignore вызывают существующий
`PortfolioDraftController`; Save сохраняет captured working snapshot отдельно.

[`Pure sync rules`](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_github_sync.dart)
сопоставляют проекты по repository ID и вычисляют new/synced/changed/ignored.
`PortfolioProject.githubMetadata` хранит accepted source, известный UTC validatedAt
и override fields; curated строки остаются прежними полями проекта.
Editor отмечает ручные title/description/technologies/repositoryUrl через
`withUserEdits`. Accept обновляет только поля без override и source baseline;
liveUrl/featured/visible всегда сохраняются. Stale review отклоняется при изменении
проекта; captured repository identity предотвращает применение к новому UID.

Ignore registry в private content хранит ID/fingerprint конкретной версии.
Он сохраняется вместе с draft и переживает restart; новый source snapshot снова
даёт предложение. Cached source не получает свежий lastGitHubSyncAt;
незавершённая pagination и отсутствие repository не удаляют curated проект.
Prepared publication repository не вызывается этим путём.
На Phase 9 были введены Hive v3/private Firestore 2; на Phase 11 writers
обновлены до v4/3 (ADR 0003). Защита от downgrade и public projection
зафиксированы в [ADR 0002](../decisions/0002-github-import-and-review.md).
Результаты приёмки — в [Phase 9](../product/product-spec.md#phase-9--living-portfolio--smart-github-sync).

---

## Portfolio Suggestions

[Pure rules](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_suggestions.dart)
принадлежат существующему draft domain. `buildPortfolioSuggestions` получает
content, необязательные source snapshots и явно заданное `now`; результат
immutable, имеет stable IDs и порядок. Domain не читает часы, сеть или SDK,
не меняет content и не вызывает Save/publication.

`PortfolioSuggestionThresholds` — единственное место числовых порогов;
UI берёт их для объяснений из того же API. `ProjectScore` не вводится:
для текущих правил достаточно конкретного условия и полезного действия.

| Правило | Условие и действие |
| --- | --- |
| Новый repository | Загруженный source ещё не импортирован, не fork/archived и не ignored для этой версии; Preview ведёт к прежнему явному Add |
| Недавнее обновление | Imported repository обновлён не более 30 дней назад; future date исключена, редактор позволяет актуализировать описание |
| Длительный простой | Последнее известное обновление imported repository было не менее 180 дней назад; владелец проверяет актуальность в редакторе |
| Нет description/demo | У visible curated проекта пустое описание или `liveUrl`; редактор позволяет заполнить соответствующее поле |
| Кандидат для featured | Visible, ещё не featured, заполнены описание и технологии; manual имеет demo, GitHub не fork/archived и имеет ссылку плюс недавнее обновление или не менее 5 stars; владелец решает в редакторе |

В Projects правила используют working curated content и accepted source, поэтому
работают offline. В GitHub Import используется явно загруженный source текущего
repository. При нескольких snapshots одного ID выбирается более поздний
`updatedAt`, затем fingerprint для стабильного tie break. Invalid source пропускается.
Source `updatedAt` означает обновление repository, не подтверждённый commit или
полную историю активности. Ignore конкретной версии подавляет source advice,
но не подсказки о незаполненных curated полях; новая версия снова рассматривается.
Hidden проекты исключаются из рекомендаций. Изображения и screenshots принадлежат
Phase 11; preview текущего правила означает demo-ссылку, без новой storage schema.

[Provider](../../apps/mobile/lib/features/portfolio_draft/portfolio_draft_providers.dart)
проверяет account/explicit guest до private read и не предлагает demo advice при
отсутствии content, loading или повреждённом draft. Working edits немедленно
пересчитывают результат, смена UID убирает подсказки прежнего владельца.
[Общий UI](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_suggestion_list.dart)
показывает причины ru/en в Projects и GitHub source cards; действия открывают
Preview или прежний project editor. Подсказки не применяют featured автоматически,
не сохраняются отдельным списком и не требуют cloud/Rules migration.
Приёмка — в [Phase 10](../product/product-spec.md#phase-10--portfolio-suggestions).

---

## Локальные настройки и draft на Phase 5

[`LocalRuntime`](../../apps/mobile/lib/app/local_runtime.dart) — composition root:
читает `SettingsRepository`, открывает [`LocalStorage`](../../apps/mobile/lib/core/storage/local_storage.dart)
в Application Support и передаёт Hive adapters/initial settings в `StackCardApp`.
Production запускает `StackCardBootstrap`; app появляется после restoration.
Неудачный startup показывает безопасный retry, без внутренних diagnostics.
При disposal, включая завершившуюся после disposal загрузку, boxes закрываются.

SharedPreferencesAsync хранит один JSON snapshot v1: theme, ru/en language и
showSourceDescriptions. AppearanceController применяет выбор в app session,
последовательно сохраняет последнее состояние и показывает failure/retry.
Corrupt preferences дают безопасные defaults; locale не пересоздаёт router.

[`portfolio_draft`](../../apps/mobile/lib/features/portfolio_draft/portfolio_draft.dart)
на Phase 5 сохранял предварительные заметки в envelope v1: notes, revision,
UTC updatedAt, pendingSync. Phase 6 сохраняет полный portfolio draft в той же
отдельной Hive box; совместимый переход к v4 описан ниже. Успешная запись увеличивает
revision; на Phase 5–7 pendingSync обозначал локальные изменения без remote sync.
На Phase 8 account repository связывает этот draft с durable outbox и реальным
server ACK; guest остаётся local-only.
Неизвестная версия или повреждённый draft блокируют перезапись исходной записи.

Cache и draft находятся в разных boxes. Нечитаемый cache file сохраняется как
backup и создаётся новый; draft file не обрезается автоматически. Ни GitHub
refresh, ни очистка cache не изменяют draft. Hive 2.2.3 требует наблюдения двух
Future при ошибке открытия; public openBox wrapper покрыт regression tests.
Решения — в [ADR](../decisions/README.md#принято-для-phase-5), результаты —
в [product spec](../product/product-spec.md#phase-5--local-persistence--offline).

---

## Portfolio domain и локальный Builder

[`PortfolioDraft`](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_draft.dart)
содержит private notes, nullable `PortfolioContent`, revision, UTC updatedAt и
pendingSync. `content == null` означает прежние заметки или ещё не начатый
Builder; demo-данные тогда доступны для знакомства с UI. Начало Builder создаёт
пустой content и не копирует demo-профиль или GitHub source. Приватные заметки
остаются вне content и не попадают в preview.

[`PortfolioContent`](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_content.dart)
владеет `PortfolioProfile`, skills, ручными `PortfolioProject`, experience,
education, social links, plain text Resume, блоками и `PortfolioTheme`.
Коллекции immutable, элементы имеют стабильные ID, equality учитывает значения
и порядок. Pure Dart domain не зависит от Firestore; cloud envelope и доступ
определяет [ADR 0001](../decisions/0001-firestore-sync-and-publication.md).
Десять уникальных блоков — Profile, About, Skills, Featured Projects, Experience,
Education, GitHub, Links, Resume, Location — имеют порядок и видимость.
Тема портфолио dark/light применяется существующей `StackCardTheme` к отображению
content на Portfolio и в preview, не меняя ThemeMode приложения. Resume сохраняет переносы строк;
Markdown, файловые вложения и обработка media в этой фазе не вводятся.

[`PortfolioDraftController`](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_draft_controller.dart)
— единственный mutable владелец рабочего notes/content и последнего durable
draft в app session. Формы применяют валидный результат целиком; отмена не меняет
content. Home, Portfolio, Projects и Settings читают проекции публичного
`portfolioWorkingContentProvider`, без отдельного write store.
После `ensureLoaded()` read models подписываются на readiness/content, чтобы
завершение первого чтения не повторяло demo-запрос. Demo допускается только
при успешном чтении с content null; read failure показывает ошибку с явным retry.
Shell и readiness-подписи отражают текущий локальный профиль, включая initials.
Preview показывает текущие рабочие значения, порядок и видимость блоков, включая ещё не сохранённые
правки; статус сохранения не скрывается. Чтение GitHub не изменяет content;
явные import/review/ignore actions используют тот же controller и отдельный Save.
Пустые блоки пропускаются; Featured Projects показывает только видимые featured
проекты. Builder и Projects сохраняют доступ ко всем ручным проектам для редактора.

Явный Save захватывает notes/content и ожидаемую revision. Успех обновляет durable
snapshot, увеличивает revision один раз и ставит pendingSync; более новые правки
во время записи остаются unsaved. Ошибка сохраняет ввод для retry. Repository
последовательно проверяет revision и пишет: stale revision даёт conflict без
перезаписи. Повторное чтение сохранённой версии выполняется явным действием,
поскольку отбрасывает несохранённые правки. `saveNotes` изменяет только notes,
сохраняя остальной content.

Hive envelope v4 допускает nullable content, private GitHub metadata и media paths.
Чтение v1/v2/v3 не мигрирует запись; v2 projects становятся manual;
legacy content получает пустые media поля. Версии до v4 отвергают media keys.
Чтение v1 сохраняет точные notes
и metadata, возвращая content null, и само не переписывает запись. Первая явная
запись сохраняет raw v1 backup в той же box перед заменой. Ошибка backup или записи
оставляет прежний durable draft. Повреждённый и unknown-version формат блокирует
перезапись; draft не имеет TTL и не удаляется при cache eviction.

Pure domain validation проверяет поля, URL, ID коллекций и набор блоков; неполный
профиль можно сохранить как draft. Полнота вычисляется из пяти необходимых
шагов: профиль, About, навыки, хотя бы один видимый проект и ссылки. Experience,
Education, GitHub, Resume и Location опциональны; скрытие блока не повышает
процент. Число полноты не хранится отдельным mutable полем.
Приёмка и ограничения — в [Phase 6](../product/product-spec.md#phase-6--portfolio-domain-и-локальный-builder).

---

## Приватные изображения — Phase 11

[Media API](../../apps/mobile/lib/features/media/media.dart) разделяет picker,
preprocessing, Repository и Riverpod session state. Profile/project forms
сохраняют upload result в локальной форме до Apply; Save остаётся прежним явным
действием. Storage SDK работает по owner-only path, без `getDownloadURL`.
Guest не имеет media repository; UID transition отменяет uploads и исключает
late results. Private bytes cache живёт только в provider memory, внешние public
avatars используют `cached_network_image`.

`avatarPath`/`imagePaths` принадлежат private draft и не попадают в public codec.
Original MIME/size, decode bounds, JPEG resize/compression и EXIF cleanup
проверяются до upload. Storage Rules ограничивают owner read/create/delete,
JPEG size и immutable path, запрещают list/public namespace. Firebase bearer
tokens при намеренном раскрытии владельцем обходят Rules; приложение их не
получает и не сохраняет.

Прежние сохранённые files не удаляются при замене: offline/LWW клиент может
ссылаться на них. Отмена новых unapplied uploads делает best-effort cleanup;
server garbage collection отсутствует. Полный контракт и причины — в
[ADR 0003](../decisions/0003-private-portfolio-media.md), команды — в
[CONTRIBUTING](../../CONTRIBUTING.md#media-storage-и-native-acceptance), фактическая
приёмка — в [Phase 11](../product/product-spec.md#phase-11--media).

## Source, draft и публикация

1. **GitHub source:** публичный профиль и repository metadata для импорта/сравнения.
   В v1 не нужен private repository access.
2. **Curated draft:** пользовательские описания, выбранные проекты, screenshots,
   технологии, links, featured/visibility/order и настройки блоков.
3. **Published representation:** явно опубликованные данные публичной страницы.
   Изменения draft и GitHub sync не становятся публичными сами по себе.

GitHub не является абсолютным source of truth. `PortfolioProject` хранит typed
происхождение `manual`/`github`, стабильный repository ID, accepted source snapshot
и известный UTC `lastGitHubSyncAt`. Статус source comparison вычисляется отдельно
от отправки draft в Firestore.
Пользовательские overrides отличаются от импортированных полей. Новые/изменённые
repositories дают предложения, которые пользователь просматривает.

Mobile offline: локальный cache и редактируемый draft, затем Firestore synchronization;
состояния `pending`, `synced`, `error`. Preferences — простые настройки, Hive
предпочтителен по учебному заданию для draft/cache. Альтернатива требует причины и ADR.

### Local-first sync и конфликты

[`SyncedPortfolioDraftRepository`](../../apps/mobile/lib/features/portfolio_draft/data/synced_portfolio_draft_repository.dart)
оборачивает local repository, UID-bound remote adapter и
[`HivePortfolioSyncMetadataStore`](../../apps/mobile/lib/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart).
[`PortfolioSyncState`](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_sync.dart)
отделяет local-only/loading от pending/synced/error. Save сначала завершает
запись Hive, затем сохраняет outbox snapshot с mutation ID и local revision.
После restart pending draft восстанавливает outbox, включая разрыв между Save
и metadata write. ACK старой mutation не снимает pending с нового Save.
Неподтверждённые SDK cache/pending snapshots не считаются server ACK.

[`FirestorePortfolioDraftRepository`](../../apps/mobile/lib/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart)
использует server timestamp и snapshots с metadata. Firestore persistence
дополняет Hive; working state редактора принадлежит controller. Server update
обновляет durable cache, но не отбрасывает несохранённый ввод. Ошибка отправки
сохраняет local draft/outbox; explicit retry повторяет синхронизацию. При потере
сети pending запись остаётся до reconnect и подтверждения сервера. UID transition
закрывает subscriptions/retry прежнего repository, guest не имеет remote adapter.

Conflict strategy — whole-document last-write-wins по порядку server commits.
Local revisions защищают только записи одного устройства; device clock и
revision другого клиента не определяют победителя. Одновременные изменения не
сливаются: поздний commit, в том числе offline Save после reconnect или повтор
после потерянного ACK, заменяет draft целиком. Mutation ID связывает local ACK,
но не гарантирует global exactly-once. Будущий online-first web использует тот
же envelope и последствия; сохранение обеих конкурирующих версий не обещается.

### Private/public schema и явная публикация

| Путь | Данные и доступ |
| --- | --- |
| `accounts/{uid}/drafts/current` | Owner-only envelope: notes/content, mutation ID, local revision и server updatedAt |
| `accounts/{uid}` | Owner-only pointer текущей публикации и монотонная publication version |
| `usernames/{username}` | Уникальная reservation; authenticated get, list запрещён |
| `publicPortfolios/{username}` | Только snapshot явной публикации; anonymous get, list запрещён |

Username использует существующую lowercase validation 3–30 символов.
[`FirestorePortfolioPublicationRepository`](../../apps/mobile/lib/features/portfolio_draft/data/firestore_portfolio_publication_repository.dart)
подготовлен для online publish/unpublish. Transaction читает актуальный private
draft и проверяет, что content совпадает с явно переданным сохранённым snapshot;
затем меняет account pointer, reservation и public snapshot вместе. Publish
новой версии увеличивает publication version; rename удаляет старую ссылку.
Unpublish удаляет snapshot/reservation и обнуляет pointer, сохраняя private draft.
Освобождённый username сможет занять другой владелец; прежняя ссылка не резервируется.
Автоматическая синхронизация этот repository не вызывает; public UI/web не созданы.

[`Public projection`](../../apps/mobile/lib/features/portfolio_draft/data/portfolio_public_content_codec.dart)
исключает hidden projects и очищает поля скрытых блоков перед записью snapshot.
Accepted source/override fields и ignore registry удаляются из public payload.
Private writer schema 3 читает 1/2/3, Rules запрещают downgrade; public schema 1
сохраняет прежний curated contract и физически исключает private media keys. Миграция — в [ADR 0002](../decisions/0002-github-import-and-review.md).
Private notes не входят в content и не отправляются в public collection.
[`Firestore Rules`](../../firebase/firestore.rules) проверяют owner, field allowlists
и связанные post-write records через `getAfter`/`existsAfter`: частичный
publish/rename/unpublish и захват чужого username запрещены. Полная validation
элементов списков остаётся в codec; Rules не обещают произвольного обхода массивов.
Детальный контракт и альтернативы — в [ADR 0001](../decisions/0001-firestore-sync-and-publication.md),
команды Rules/native checks — в [CONTRIBUTING](../../CONTRIBUTING.md#firestore-rules-и-native-sync-acceptance).

Suggestions вычисляются pure deterministic rules, описанными в
[Portfolio Suggestions](#portfolio-suggestions); UI объясняет условие и действие.

---

## Ключевые потоки

### Запуск и навигация текущего UI

1. Flutter вызывает `main` в `apps/mobile/lib/main.dart`.
2. `StackCardBootstrap` восстанавливает settings, открывает Hive boxes и
   инициализирует Firebase через `LocalRuntime`; `StackCardApp` создаёт
   `MaterialApp.router` с выбранной темой, locale и GoRouter.
3. Account session stream восстанавливает владельца; email/password либо
   Google sign-in открывает разрешённый private route. Явный guest mode
   разрешает локальный редактор без аккаунта. Восстановление/ошибка session
   блокируют private routes. Legacy `AuthRepository.openDemo` относится только
   к preview/tests без native account configuration.
4. Profile и Projects читают рабочий content через проекции либо загружаются
   из заменяемых demo repositories через Riverpod. `PortfolioOverview` объединяет
   их для Home и demo Portfolio; поиск Projects не меняет полный список
   или featured на других экранах.
5. Settings меняет AppearanceController и сохраняет цельный snapshot preferences,
   читает profile provider и держит preview loading/empty/error в session.
   Account controls выполняют sign out и явный guest transfer; смена владельца
   очищает private session state, durable draft остаётся в своём namespace.
   Portfolio открывает Builder, preview и приватные notes; формы и ручные проекты
   изменяют один рабочий draft, явный Save сохраняет его локально; account outbox
   синхронизируется отдельно с честным pending/synced/error.
   Projects открывает GitHub Import с HTTP/cache и явным refresh. Tests проверяют contracts,
   замену источника, асинхронные состояния, навигацию и layouts.

Demo profile/projects остаются локальными и не копируются в Builder. Settings
и сохранённый portfolio draft используют device storage, отдельный GitHub Import
читает HTTP с offline fallback. Firebase Auth определяет account; draft sync
принадлежит отдельному Firestore adapter и не вызывает публикацию.

### Импорт, редактура и публикация — целевой поток

1. GitHub integration получает публичные metadata и предлагает проекты для импорта.
2. Пользователь выбирает данные и дополняет curated draft в mobile или web.
3. Mobile сохраняет локальную правку и синхронизирует её через общий backend;
   web v1 сохраняет удалённо с явным статусом действия.
4. Preview показывает редактируемый результат владельцу.
5. Явное publish обновляет published representation; публичная страница читает её.

Detection изменений GitHub и синхронизация draft не выполняют шаг публикации.
Контактное обращение и notifications подключаются отдельным сценарием Phase 14.

---

## Выбор города и страны — Phase 12

Пользователь вручную вводит город и страну в Profile Location Picker или
нажимает «Определить мой город». Открытие picker не запрашивает разрешения.
`PortfolioLocationRepository.currentPlace()` возвращает только `PortfolioPlace`;
geolocator и native reverse geocoding принадлежат `features/location/data`.
В adapter одно определение с ограниченным временем ожидания; Android запрашивает
только approximate/coarse location, iOS — When In Use, без background updates.
Из placemark используются только locality и country, без улицы, дома или адреса.

Полученный город/страна — предложение: пользователь может исправить его и явно
подтвердить. Picker возвращает только текстовый результат; Profile меняет свой
form controller, Apply обновляет working draft, Save отдельно сохраняет его.
Cancel, поздний ответ после ручного ввода и смена UID/repository не изменяют draft.
Denied/permanently denied/service disabled/timeout и ошибка reverse geocoding
оставляют ручной ввод доступным; переход в настройки и повтор выполняются явно.

Координаты остаются временными локальными переменными adapter и не передаются
presentation, Hive, Firestore, логам или public snapshot. Существующее поле
`PortfolioProfile.locationText` хранит выбранный город/страну; schema не меняется,
прежние ручные значения сохраняются. Public projection удаляет скрытый Location.
Google Maps SDK, карта и marker исключены по решению пользователя 2026-10-07.
Ключ Maps API, billing и новая web-интеграция этому сценарию не нужны.
Проверки и фактическая приёмка — в [Phase 12](../product/product-spec.md#phase-12--location).

## Границы расширения

<div align="center">

| **Вопрос** | **Правило размещения или изменения** |
|:---|:---|
| Где добавить мобильный сценарий? | В используемую feature внутри `apps/mobile/lib`, начиная с реального владельца |
| Где добавить страницу сайта? | В `apps/web` после создания Next.js-приложения на подтверждённой фазе |
| Когда выделять общий механизм? | Когда есть реальные потребители и одинаковая ответственность |
| Как менять data contract? | Согласовать mobile/web, private/public границы и затронутые проверки |
| Где хранить AI-правило? | В `docs/AI/AGENTS.md` или relevant scope, обновив router и adapters |
| Где хранить runtime config? | В canonical source соответствующего приложения или инструмента |
| Что документировать вместе с изменением? | Затронутый contract у его владельца, links и существенное решение в ADR |

</div>

Общая модель не требует общей runtime-библиотеки между Dart и TypeScript.
Package, UseCase или DataSource выделяется под существующий сценарий,
а не ради заранее заполненного дерева каталогов.

---

## Нефункциональные требования

Требования ниже целевые; конкретные механизмы и проверки вводятся вместе
с соответствующими интеграциями, без заявления об уже готовом backend.

<div align="center">

| **Требование** | **Подход** |
|:---|:---|
| Контроль публикации | Отделить source, draft и published representation; публиковать явно |
| Приватность | Проверять ownership на доверенной стороне и границы public snapshot |
| Работа при сбоях | Mobile cache/draft; явные sync states, error и retry в обоих редакторах |
| Поддерживаемость | Одному контракту — один владелец; features добавляются по необходимости |
| Воспроизводимость | Canonical manifests/lockfile и проверки по затронутому поведению |
| Доступность | Согласованные UI states и проверки контраста из design guide |

</div>

### Errors, privacy и интеграции — будущие требования

- Widget получает Loading/Success/Empty/Error; ошибки timeout/network/auth/parsing/
  validation/cache преобразуются на границах, без разбросанного `try/catch` в UI.
- GitHub Import поддерживает pagination, retry, pull-to-refresh и ETag и persistent cache;
  Hive offline cache сохраняется отдельно от portfolio draft.
- Private writes ограничены owner; посторонние читают только опубликованные данные.
  Firestore/Storage Rules тестируются при интеграции. Secrets и signing data не в Git.
- Location публикуется как город/страна, без GPS/адреса; ручной ввод и
  опциональное определение города описаны в [Phase 12](#выбор-города-и-страны--phase-12).
- Media проходит MIME/size validation, compression и cleanup по спроектированным
  правилам; camera/gallery включаются по реальному сценарию.
- Web использует подходящий browser UX для файлов, location и sharing. Camera,
  location permissions проверяются по каждой платформе; одинаковая data model
  не обещает полного равенства нативных возможностей.
- Contact form требует validation и spam/rate-limit strategy; FCM отправляется на
  доверенной стороне, server credentials не помещаются в клиент.
- Native sharing Android: MethodChannel → Kotlin → `Intent.ACTION_SEND`.
  Developer Card и QR — Phase 15.

---

## Завершение Phase 0

Phase 0 подготовила структуру, документы, ignore rules и logo originals.
Её проверка включала разрешение зависимостей, format/analyze/widget test
и запуск scaffold на Android. Исторические результаты сохранены в
[product spec](../product/product-spec.md#phase-0--product-foundation).

Дальнейшие проверки, ограничения среды и переходы фиксируются там же.
Commit и синхронизация с remote выполняются по отдельному запросу.
Полный [roadmap](../product/product-spec.md) и
[решения](../decisions/README.md) дополняют этот guide.
