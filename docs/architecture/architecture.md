<div align="center">

# StackCard Architecture

**Текущая Flutter-основа и целевые границы mobile, web и общего backend**

![Architecture guide](https://raster.shields.io/badge/Architecture-guide-09090B?style=for-the-badge)
![Stage Phase 6 Builder](https://raster.shields.io/badge/Stage-Phase_6_Builder-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Текущее состояние — Phase 6](#текущее-состояние--phase-6)
- [Схема системы](#схема-системы)
- [Зоны ответственности](#зоны-ответственности)
- [Целевые границы — ещё не реализованы](#целевые-границы--ещё-не-реализованы)
- [Web и общие контракты](#web-и-общие-контракты)
- [Mobile modules — при реальных сценариях](#mobile-modules--при-реальных-сценариях)
- [GitHub Import: HTTP и persistent-кэш](#github-import-http-и-persistent-кэш)
- [Локальные настройки и draft на Phase 5](#локальные-настройки-и-draft-на-phase-5)
- [Portfolio domain и локальный Builder](#portfolio-domain-и-локальный-builder)
- [Source, draft и публикация](#source-draft-и-публикация)
- [Ключевые потоки](#ключевые-потоки)
- [Границы расширения](#границы-расширения)
- [Нефункциональные требования](#нефункциональные-требования)
- [Завершение Phase 0](#завершение-phase-0)

---

## Текущее состояние — Phase 6

В monorepo есть одно Flutter-приложение в `apps/mobile`. Код Architecture
Phase 3 реализован поверх UI foundation и basic state management;
Phase 4 добавила отдельный GitHub Import с публичным HTTP-источником.
Phase 5 сохраняет настройки, GitHub cache и локальные заметки к портфолио.
Phase 6 расширяет тот же draft до локального Builder с ручными формами,
порядком и видимостью блоков, вычисляемой полнотой и preview.
Окончательная приёмка и фактические результаты проверок ведутся в
[product spec](../product/product-spec.md#phase-6--portfolio-domain-и-локальный-builder).
Sign In, Home, Portfolio, Projects и Settings сохраняют общий app shell,
Material 3 light/dark. До начала Builder они показывают демонстрационный контент;
после начала — проекции единого рабочего draft через Riverpod. Данные сохраняются
через Repository contracts. Реальная авторизация, remote sync и публикация
вводятся по roadmap.

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
│       ├── portfolio_draft/  # portfolio domain, Builder, preview, Hive и controller
│       ├── home/             # экран на PortfolioOverview
│       └── settings/         # настройки, SharedPreferences adapter и preview состояний
└── test/                     # contracts, DI, состояние, UI и responsive
```

Маршруты заданы в
[`app_router.dart`](../../apps/mobile/lib/app/app_router.dart): `/sign-in`,
`/home`, `/portfolio`, `/projects`, `/settings`, `/github-import`, `/portfolio-draft`,
`/portfolio/builder`, `/portfolio/preview`, `/projects/new` и `/projects/:id/edit`.
Формы Builder используют дочерние пути `profile`, `skills`, `experience`,
`education`, `links`, `resume`. `/` перенаправляет на `/home`. Четыре основных
экрана используют app shell; формы, preview, Sign In, GitHub Import и локальные
заметки открываются отдельно. Auth guards пока отсутствуют: `DemoSession` отражает demo-вход,
но не авторизует аккаунт.

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
Providers без `autoDispose` сохраняют состояние в app session. Demo-session и
фильтры сбрасываются при новом запуске. ThemeMode, ru/en locale и настройка
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
Схема описывает ответственность компонентов; точная Firestore schema и
механизм публикации определяются перед интеграцией backend.

### Общий обзор

![Целевая архитектура StackCard: mobile, web, Firebase и GitHub](../diagrams/architecture-overview.png)

[Mermaid-исходник обзора](../diagrams/architecture-overview.mmd).

### Редактирование и публикация

![Схема StackCard: редакторы, private draft, явная публикация и public snapshot](../diagrams/architecture-system.png)

[Mermaid-исходник схемы](../diagrams/architecture-system.mmd).

Публичная страница не читает private draft. GitHub поставляет предложения для
редактора; только отдельное действие владельца обновляет published snapshot.
Логический узел публикации не означает заранее выбранную Firebase Function
или созданный endpoint: доверенная проверка и атомарность будут спроектированы
на Phase 8.

---

## Зоны ответственности

### apps/mobile

Исполняемый Flutter-клиент для Android и iOS. Сейчас владеет app shell,
основными экранами, GitHub Import, локальным Builder и приватными заметками,
Repository/DI, общей темой/widgets и tests. GitHub cache и явно сохранённый
portfolio draft доступны offline. Другие native integrations вводятся по фазам.
Mobile не владеет реализацией сайта или доверенными серверными операциями.

### apps/web

Отдельный будущий Next.js-клиент: marketing pages, защищённый редактор и
public portfolio. Пока содержит только README. Общие data contracts связывают
клиенты без импорта Flutter/Dart runtime в React/TypeScript.

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
| `firebase` — каталог ещё не создан | Auth, Firestore, Storage, Rules и FCM; Phase 7–14 |
| `.github/workflows` — ещё не создан | Проверки и APK artifact; Phase 18 |

</div>

Это один продукт, поэтому один monorepo. Общий Firebase project будет обслуживать
mobile и web; отдельный NestJS/PostgreSQL backend в v1 не нужен. Mobile не импортирует
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
состояниями несохранённых изменений, сохранения, sync error и retry. Перед Phase 8
нужно выбрать strategy конфликтов между устройствами и клиентами, согласовать
data contracts и private/public границу. Перед Phase 13 проверить совместимость
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
└── data/                     # demo/mock реализации repositories
```

<div align="center">

| **Область** | **Ответственность и публичная граница** |
|:---|:---|
| [auth](../../apps/mobile/lib/features/auth/auth.dart) | `AuthRepository`, нормализация `DemoSession`, проверка demo-email; `AuthController` выполняет асинхронное действие через DI, `DemoAuthRepository` остаётся локальным источником |
| [profile](../../apps/mobile/lib/features/profile/profile.dart) | Immutable read models `Profile`, `ProfileHighlight`, `ProfileReadiness`; `profileProvider` читает проекцию Builder, при отсутствии content — заменяемый demo repository |
| [projects](../../apps/mobile/lib/features/projects/projects.dart) | Read model `Project`, typed `ProjectSource`, `ProjectsRepository`, pure query/filter и featured-отбор; проекция ручных проектов Builder либо demo repository через Riverpod |
| [github_import](../../apps/mobile/lib/features/github_import/github_import.dart) | Public source models и `GitHubImportRepository`; Dio/DTO/cache в data, отдельный Riverpod controller и экран. Не меняет profile/projects/portfolio repositories |
| [portfolio](../../apps/mobile/lib/features/portfolio/portfolio.dart) | `PortfolioOverview` объединяет публичные profile/projects states для Home и demo Portfolio; это presentation read model |
| [portfolio_draft](../../apps/mobile/lib/features/portfolio_draft/portfolio_draft.dart) | Pure Dart portfolio content, validation/completion и repository; единый session controller, формы Builder и ordered preview, Hive persistence и private notes |
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
используются GitHub Import, auth guards вводятся вместе с настоящей авторизацией.

---

## GitHub Import: HTTP и persistent-кэш

`Projects → GitHub Import → username → profile + repositories` — отдельный
просмотр источника. `GitHubProfile` и `GitHubRepository` не являются `Profile`
или curated `Project`; преобразование для импорта появится на Phase 9.

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
отдельной Hive box; контракт перехода к v2 описан ниже. Успешная запись увеличивает
revision; pendingSync обозначает локальные изменения, но не выполняет remote sync.
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
и порядок. Это локальный domain; окончательная Firestore schema не задаётся.
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
правки; статус сохранения не скрывается. GitHub Import не изменяет этот content.
Пустые блоки пропускаются; Featured Projects показывает только видимые featured
проекты. Builder и Projects сохраняют доступ ко всем ручным проектам для редактора.

Явный Save захватывает notes/content и ожидаемую revision. Успех обновляет durable
snapshot, увеличивает revision один раз и ставит pendingSync; более новые правки
во время записи остаются unsaved. Ошибка сохраняет ввод для retry. Repository
последовательно проверяет revision и пишет: stale revision даёт conflict без
перезаписи. Повторное чтение сохранённой версии выполняется явным действием,
поскольку отбрасывает несохранённые правки. `saveNotes` изменяет только notes,
сохраняя остальной content.

Hive envelope v2 допускает nullable content. Чтение v1 сохраняет точные notes
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

## Source, draft и публикация

1. **GitHub source:** публичный профиль и repository metadata для импорта/сравнения.
   В v1 не нужен private repository access.
2. **Curated draft:** пользовательские описания, выбранные проекты, screenshots,
   технологии, links, featured/visibility/order и настройки блоков.
3. **Published representation:** явно опубликованные данные публичной страницы.
   Изменения draft и GitHub sync не становятся публичными сами по себе.

GitHub не является абсолютным source of truth. Текущий `Project` хранит typed
происхождение `manual`/`github`. Связь с repository через стабильный ID и
время/состояние sync будут введены вместе с импортом и синхронизацией.
Пользовательские overrides отличаются от импортированных полей. Новые/изменённые
repositories дают предложения, которые пользователь просматривает.

Mobile offline: локальный cache и редактируемый draft, затем Firestore synchronization;
состояния `pending`, `synced`, `error`. Preferences — простые настройки, Hive
предпочтителен по учебному заданию для draft/cache. Альтернатива требует причины и ADR.
Conflict strategy ещё не выбрана; простая last-write-wins допустима после фиксации
последствий, включая несколько устройств и правки из mobile/web. Изменение draft
в одном клиенте должно стать доступным другому после успешной синхронизации.

Firestore schema из ТЗ — направление, не контракт. Перед Phase 8 спроектировать
private account/draft и public snapshot, уникальность username, атомарность
publish/unpublish и rules. Один `published`-флаг при смешивании private/public полей
не решает границу доступа; её нужно проверять явно.

Suggestions сначала deterministic, тестируются независимо от UI. Числовой
ProjectScore необязательно показывать; UI объясняет полезное действие.

---

## Ключевые потоки

### Запуск и навигация текущего UI

1. Flutter вызывает `main` в `apps/mobile/lib/main.dart`.
2. `StackCardBootstrap` восстанавливает settings и открывает Hive boxes через
   `LocalRuntime`; `StackCardApp` создаёт `MaterialApp.router` с выбранной темой,
   locale и GoRouter.
3. Sign In использует pure demo-email validation и `AuthController`;
   успешный `AuthRepository.openDemo` открывает Home. App shell позволяет
   переходить на Portfolio, Projects и Settings, возвращаться назад.
4. Profile и Projects читают рабочий content через проекции либо загружаются
   из заменяемых demo repositories через Riverpod. `PortfolioOverview` объединяет
   их для Home и demo Portfolio; поиск Projects не меняет полный список
   или featured на других экранах.
5. Settings меняет AppearanceController и сохраняет цельный snapshot preferences,
   читает profile provider и держит preview loading/empty/error в session.
   Portfolio открывает Builder, preview и приватные notes; формы и ручные проекты
   изменяют один рабочий draft, явный Save сохраняет его локально.
   Projects открывает GitHub Import с HTTP/cache и явным refresh. Tests проверяют contracts,
   замену источника, асинхронные состояния, навигацию и layouts.

Demo profile/projects остаются локальными и не копируются в Builder. Settings
и сохранённый portfolio draft используют device storage, отдельный GitHub Import
читает HTTP с offline fallback; Firebase не подключён.

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
- Location публикуется как город/страна, без точных GPS; denied/permanently denied/
  service disabled обрабатываются отдельно.
- Media проходит MIME/size validation, compression и cleanup по спроектированным
  правилам; camera/gallery включаются по реальному сценарию.
- Web использует подходящий browser UX для файлов, location и sharing. Camera,
  maps и permissions проверяются по каждой платформе; одинаковая data model
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
