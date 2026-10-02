<div align="center">

# StackCard Product

**Мобильный и web-конструктор developer-портфолио с контролируемой публикацией**

![Stage Phase 0](https://raster.shields.io/badge/Stage-Phase_0-111111?style=for-the-badge)
![Mobile + Web planned](https://raster.shields.io/badge/Mobile_%2B_Web-planned-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Статус и границы текущей работы](#статус-и-границы-текущей-работы)
- [Концепция и аудитория](#концепция-и-аудитория)
- [Living Portfolio: данные и контроль пользователя](#living-portfolio-данные-и-контроль-пользователя)
- [Portfolio Suggestions](#portfolio-suggestions)
- [Пользовательский путь и экраны](#пользовательский-путь-и-экраны)
- [Portfolio Builder и Developer Card](#portfolio-builder-и-developer-card)
- [MVP и полный scope v1](#mvp-и-полный-scope-v1)
- [Offline, приватность и безопасность](#offline-приватность-и-безопасность)
- [Техническое направление и качество](#техническое-направление-и-качество)
- [Non-goals v1](#non-goals-v1)
- [Roadmap](#roadmap)

---

## Статус и границы текущей работы

Текущий этап — **Phase 0: Product foundation**. Этот документ фиксирует
целевой продукт, а не реализованные возможности. В локальной основе подготовлены
документация и минимальное Flutter-приложение в `apps/mobile`; в `apps/web`
сейчас только README. Подключение удалённого репозитория и дальнейшая разработка —
последующие действия. Commit и push выполняются только по запросу пользователя.

Phase 0 не включает подключение Firebase, GitHub API, Riverpod, реализацию web,
бизнес-функции и новые зависимости на будущее. После неё работа останавливается;
переход к Phase 1 требует подтверждения пользователя.

---

## Концепция и аудитория

**StackCard** — конструктор developer-портфолио для мобильного приложения и сайта
с синхронизацией публичных данных GitHub и публикацией web-визитки. Flutter-приложение
и web-кабинет — два редактора одного портфолио. Сайт также объясняет проект на
главной странице, предлагает скачать мобильное приложение и показывает
опубликованные портфолио с контактной формой и metadata для распространения ссылки.

Платформы продукта — Android, iOS и web. Mobile реализуется на Flutter в
`apps/mobile`, сайт — отдельно на Next.js в `apps/web`. Каталог сайта уже подготовлен
с README; приложение появится на Phase 13. Desktop-приложения
и Flutter web не входят в scope. Android выпускается первым; iOS остаётся
целевой мобильной платформой.

Целевая аудитория — разработчики, особенно студенты и начинающие специалисты,
которым нужно представить проекты работодателю или заказчику. GitHub содержит
полезные технические данные, но сам по себе не даёт отобранного рассказа о навыках
и результатах работы. StackCard помогает выбрать проекты, дополнить их понятным
описанием, изображениями и demo, а затем поделиться одной ссылкой.

Пример адреса: `stackcard.dev/u/snownumb`. **Домен — иллюстрация, не заявка на
регистрацию и не выбранный production host.** Планируемый путь публичного профиля:
`/u/[username]`.

---

## Living Portfolio: данные и контроль пользователя

Главная функция — **Living Portfolio / Smart GitHub Sync**. GitHub поставляет
публичные профиль, avatar, bio, repositories, descriptions, repository URLs,
languages, topics, stars, forks и сведения об активности. Это источник данных,
но не абсолютный source of truth для публичного портфолио.

Нужно сохранять три смысловых состояния; это продуктовый контракт, а не готовая
Firestore schema:

<div align="center">

| **Состояние** | **Назначение и управление** |
|:---|:---|
| GitHub source data | Полученные metadata и их кэш. Обновление источника не означает одобрение публикации. |
| Curated portfolio / draft | Данные, отобранные и отредактированные владельцем. Включают ручные проекты и дополнения к импортированным. |
| Published portfolio | Одобренная пользователем публичная версия. Публичные страницы сайта читают только её; черновик доступен владельцу в mobile и защищённом web-кабинете. |

</div>

При импорте пользователь выбирает репозиторий и может изменить описание и
технологии, добавить screenshot и live/demo URL, назначить featured, скрыть проект
или удалить его из портфолио. Проект имеет происхождение `manual | github`;
для импортированного проекта нужны связь с GitHub repository и сведения о sync.
Конкретную модель и правила сопоставления полей предстоит спроектировать.

Smart Sync обнаруживает новый репозиторий или изменения существующего и предлагает
действия: **Ignore**, **Preview / Review changes**, **Add to portfolio**.
Пользователь видит изменения до их принятия. Ручные правки сохраняют смысл и не
должны молча заменяться новыми данными GitHub.

**Ни обновление GitHub, ни синхронизация локального draft с облаком не могут без
подтверждения владельца переписать опубликованное портфолио.** Изменения черновика
попадают в публичную версию только через явное действие публикации. Unpublish
убирает доступ к опубликованной странице, сохраняя редактируемые данные владельца.
Физическое хранение версий и процедура публикации определяются на соответствующей
фазе, с сохранением этого контракта.

---

## Portfolio Suggestions

Рекомендации v1 используют понятные deterministic rules, без AI. Примеры:
новый репозиторий, недавняя активность или длительный простой, отсутствующие
description или screenshot, новые технологии, проект, который стоит выделить.

Внутренний `ProjectScore` допустим. Его возможные факторы: README, description,
activity, дата обновления, topics, stars/forks, technologies, homepage/demo и
ручной priority. Формула и пороги пока не выбраны. В UI показываются полезное
объяснение и действие, например «Recommended for your portfolio», а не обязательно
число. Правила должны проверяться отдельно от UI и не публиковать изменения сами.

---

## Пользовательский путь и экраны

### Мобильное приложение

Целевой первый запуск:

`Splash → Onboarding → Sign In / Sign Up → Create Profile → Choose username →
GitHub import → Select projects → Complete profile → Preview → Publish → Share`.

Ручное создание проектов также поддерживается: GitHub не является единственным
способом наполнения портфолио. До появления auth и облака промежуточные учебные
фазы работают с mock data и локальным draft.

<div align="center">

| **Раздел** | **Содержимое** |
|:---|:---|
| Authentication | Splash, Onboarding, Sign In, Sign Up, Forgot Password. |
| Home | Приветствие, portfolio completion, public status и URL, quick actions, recent sync, suggestions, recent contact requests. |
| Portfolio | Профиль, about, skills, experience, education, links, location, resume, blocks, theme, preview, publish/unpublish. |
| Projects | Ручные и импортированные проекты, GitHub repositories, featured projects, editor и sync state. |
| Inbox | Контактные обращения с публичной страницы. |
| Settings | Account, appearance, light/dark/system, language, GitHub, privacy, notifications, logout/delete account. |

</div>

Основная навигация после авторизации: **Home, Portfolio, Projects, Inbox, Settings**.
Дополнительные экраны: Portfolio Preview, GitHub Import, Project Editor,
Profile Editor, Location Picker, Resume Editor, Developer Card, Sync Suggestions.

### Сайт и web-редактор

Сайт предлагает полный путь: знакомство с проектом → регистрация или вход →
создание и редактирование портфолио → preview → явная публикация → публичная ссылка.
Мобильное приложение можно скачать отдельно; оно использует тот же аккаунт и draft.

Предлагаемая карта страниц — **план Phase 13, не реализованные маршруты или
окончательный API-контракт**:

<div align="center">

| **Путь** | **Доступ и назначение** |
|:---|:---|
| `/` | Публичная главная: назначение, преимущества, сценарий работы и переходы к web-редактору или скачиванию приложения. |
| `/download` | Информация о мобильной версии, поддерживаемых release targets и реальные способы скачивания после появления релизов. |
| `/sign-in`, `/sign-up` | Вход и создание аккаунта для одного Firebase backend. |
| `/app` | Защищённый кабинет: обзор состояния портфолио и переходы к редактированию. |
| `/app/portfolio`, `/app/projects` | Планируемые разделы редактора: профиль, блоки и проекты, GitHub import, preview и publish/unpublish. |
| `/app/inbox`, `/app/settings` | Планируемые обращения и настройки аккаунта; точные вложенные пути определить при реализации. |
| `/u/[username]` | Публичное опубликованное портфолио, SEO/OpenGraph и контактная форма. |

</div>

Редакторы разделяют модель портфолио и правила сохранения/публикации. Изменение
в одном клиенте должно появляться в другом после синхронизации, с понятным статусом
и выбранной conflict strategy. Web v1 планируется online-first; обязательная
поддержка локального offline draft остаётся задачей mobile.

---

## Portfolio Builder и Developer Card

Builder v1 состоит из блоков: Profile, About, Skills, Featured Projects,
Experience, Education, GitHub, Links, Resume, Location. Пользователь редактирует
содержимое, меняет порядок и включает/выключает блоки. Локальный builder позволяет
добавлять, редактировать и удалять данные с preview. Варианты отображения блоков
возможны позднее. Свободный canvas, двумерный resize и редактор уровня Figma/Webflow
не входят в v1.

**Shareable Developer Card** — компактная цифровая визитка с avatar, name, role,
основными technologies, username, portfolio URL, QR-кодом на публичное портфолио
и логотипом StackCard. Её можно показать и отправить. Android sharing планируется
через собственный MethodChannel, Kotlin и native share sheet.

---

## MVP и полный scope v1

MVP — целевой результат нескольких фаз, а не задача Phase 0:

<div align="center">

| **Область** | **Обязательный результат MVP** |
|:---|:---|
| Authentication | Email/password и Google. |
| Profile | Avatar, name, username, headline, bio, skills, links, location. |
| Projects | Manual project, GitHub import, featured, screenshot, technologies, repository URL, live URL. |
| Living Portfolio | Repositories, import, sync и простые suggestions. |
| Portfolio | Редактирование в mobile и web, block ordering, hide/show, preview, publish/unpublish одного портфолио. |
| Website | Главная о проекте, страница скачивания mobile, auth и защищённый редактор, public portfolio и contact form. |
| Inbox / Notifications | Contact requests в обоих кабинетах и mobile FCM notification о новом обращении. |
| Offline | Mobile: кэш ранее загруженных данных и portfolio draft. Web: online-first с явным статусом сохранения/синхронизации. |
| Другие сценарии | Light/dark theme; mobile location, camera, native share и QR Developer Card по возможностям платформы. |

</div>

Полное направление v1 также предусматривает experience, education, resume,
system theme и языковые настройки. Их детализация, как и username policy,
форматы resume и ограничения полей, выполняется перед соответствующей реализацией.

Публичная страница показывает только одобренные profile data, проекты и включённые
блоки. Посетитель может отправить **Contact me** с name, email и message.
Создаётся ContactRequest; владелец получает FCM notification и читает обращение
в mobile или web Inbox. Это контактная форма, а не чат. Поддержка browser push
не следует автоматически из требования mobile FCM и требует отдельного решения.

---

## Offline, приватность и безопасность

- В mobile без сети доступны ранее загруженные profile и projects, GitHub cache и
  редактирование локального draft. После восстановления сети изменения
  синхронизируются с облаком; состояния: `pending`, `synced`, `error`.
- Web v1 требует сети для auth, удалённого сохранения и публикации. UI явно
  показывает несохранённые изменения, сохранение, sync error и повтор действия;
  не сообщает об успешном сохранении до подтверждения. Поведение при потере сети
  не должно создавать ложное ожидание mobile offline-возможностей.
- Conflict strategy для mobile, web и нескольких устройств должна быть явной
  и документированной. Simple last-write-wins допустим на раннем этапе после
  отдельного решения; это не разрешение на
  автоматическую перезапись публичной версии.
- GitHub v1 использует публичные repositories и endpoints. Private repository
  access не требуется; private token нельзя хранить в Firestore открытым текстом.
- Владелец может изменять только свои private данные; чужое опубликованное
  портфолио доступно только для чтения. Firestore и Storage Rules должны проверять
  ownership; draft, account data, contact requests и device tokens не становятся
  публичными вместе с портфолио.
- Location выбирается с подтверждением пользователя. Карта и permission имеют
  конкретную цель: указать местоположение профиля. Публично сохраняется безопасное
  представление города/страны, например «Almaty, Kazakhstan», без точных GPS
  coordinates. Нужно обработать denied, permanently denied и service disabled.
- Camera/gallery используются для avatar и project images. До upload нужны
  validation, compression/resize; для Storage — ограничения размера, разрешённые
  MIME types, access rules и стратегия очистки старых файлов.
- Camera, maps, permissions и sharing реализуются с учётом конкретной платформы.
  Web поддержит загрузку файлов и подходящий browser UX; MethodChannel и Kotlin
  относятся к Android. Полное равенство нативных возможностей клиентов не обещается.
- Входящие данные, URL и contact form требуют validation. Защита от contact spam
  и rate limiting проектируется до публичного запуска соответствующего сценария.
- Secrets не входят в репозиторий. Environment contract и handling Firebase
  config описываются при подключении сервисов. Privacy policy, объяснения
  permissions и account deletion входят в подготовку production-версии.
- Сетевые сценарии требуют loading, success, empty, error, timeout, retry,
  pagination, pull-to-refresh и caching. Ошибки должны давать понятное действие,
  не ломая доступ к сохранённым данным.

---

## Техническое направление и качество

Целевые стек, границы приложения и развитие слоёв описаны в
[architecture.md](../architecture/architecture.md). Они вводятся по фазам,
без enterprise framework и лишнего backend. Web планируется на Next.js для
главной, скачивания mobile, защищённого редактора и публичных страниц с SEO/OpenGraph.
Mobile и web используют один Firebase project и согласованные data contracts,
когда сервисы будут подключены. Dart- и TypeScript-клиенты реализуют эти контракты
в своих стеках; общей runtime-библиотеки между ними сейчас нет.

Визуальный язык **Obsidian + Signal Red**, редкое применение красного,
палитры и правила компонентов закреплены в
[design-system.md](../design/design-system.md). Решения и нерешённые вопросы
фиксируются в [ADR](../decisions/README.md).

Приоритеты: correctness → simplicity → maintainability → user experience →
architecture purity → fancy features. Не создавать abstraction без реального
сценария. Производительность проверяется профилированием, затем исправляются
найденные проблемы; результаты до/после сохраняются.

Целевая проверка продукта: unit tests для repositories, suggestions, completion,
sync и validation; widget tests для auth, project card, editor и UI states;
integration test пути sign in → edit project → preview → publish. Учебная цель —
coverage **более 40%**, `flutter analyze` без ошибок. Проверки поведения добавляются
по мере реализации; Phase 17 доводит покрытие, а не запрещает тесты раньше.
Перед реализацией web определить его format/lint/typecheck/test команды по реальным
configs. Проверить auth guards, owner access, draft → publish и чтение public snapshot
в browser, а также синхронизацию изменений между клиентами.

---

## Non-goals v1

Не входят: social network, likes/comments/followers, recruiter platform, jobs
marketplace, messaging/chat, custom domains, template marketplace, complex
analytics, AI portfolio generation / recruiter / CV scoring, multi-user teams,
paid subscriptions, full GitHub client, private GitHub repositories,
сложный drag/resize canvas.

---

## Roadmap

Фазы выполняются последовательно. После каждой фазы приложение должно оставаться
запускаемым; выполнение следующей не начинается автоматически. Phase 0 завершается
подготовкой локальной основы и отчётом; первый commit — только после отдельного
запроса. Текущий запрос не включает подключение remote.

<div align="center">

| **Фаза** | **Проверяемый результат** |
|:---|:---|
| **0 — Product foundation** | Локальный репозиторий, README, product/architecture/design docs и ADR, `.gitignore`, минимальный Flutter app в `apps/mobile`, доступные doctor/pub get/analyze и проверка запуска. Без Firebase, GitHub API, web и сложной архитектуры. |
| 1 — UI foundation | Material 3, light/dark theme, tokens, common widgets, app shell и GoRouter; статические Sign In, Home, Portfolio, Projects, Settings на mock data. |
| 2 — Basic state management | Учебная эволюция setState → InheritedWidget → Provider для одного простого сценария при необходимости; Provider для ThemeMode/Locale, Riverpod для основного состояния; решение документируется. |
| 3 — Architecture | Feature modules с presentation/domain/data, Repository pattern и Riverpod DI для первых реальных auth/profile/projects features. |
| 4 — GitHub API | Независимый GitHub Import по username: Dio, user/repositories, serialization, pagination, loading/empty/error/retry, cache abstraction; без импорта в Firebase. |
| 5 — Local persistence / offline | SharedPreferences, Hive, GitHub cache и local portfolio draft; ранее загруженное доступно без сети. |
| 6 — Portfolio domain | Profile, Skill, Project, Experience, Education, SocialLink, PortfolioBlock, PortfolioTheme; локальный builder с add/edit/delete/reorder/show/hide/preview. |
| 7 — Firebase authentication | Email/password, Google, auth state, route guards, sign out и привязка local user к Firebase uid. |
| 8 — Firestore synchronization | Local cache + remote через Repository; явная conflict strategy и состояния synced/pending/error. |
| 9 — Living Portfolio | Import repository → Project, manual/github source, repository identity, last sync и detection изменений. |
| 10 — Portfolio Suggestions | Deterministic rules с независимой от UI проверкой. |
| 11 — Media | Firebase Storage, avatar/project images, camera/gallery, compression, cache и Storage Rules. |
| 12 — Location | Geolocator, Google Maps, Location Picker, permissions и approximate public location. |
| 13 — Website и web editor | Создание Next.js-приложения в `apps/web`: главная, скачивание mobile, auth/кабинет, редактор общего draft и public portfolio с SEO/metadata/OpenGraph. Последовательность — 13a → 13b → 13c ниже. |
| 14 — Contact / Inbox / FCM | ContactRequest из web form, mobile/web Inbox и mobile уведомление владельцу. |
| 15 — Developer Card | Визуальная визитка, QR и Android sharing через MethodChannel + Kotlin. |
| 16 — Performance | Профилирование списков, images, rebuilds, memory и frame rendering; исправление измеренных проблем с результатами до/после. |
| 17 — Testing | Unit/widget/integration, coverage >40%, clean analyze. |
| 18 — CI/CD | GitHub Actions: dependency resolution, format, analyze, tests/coverage, APK build и сохранение artifact; AAB позднее. |
| 19 — Production hardening | Crashlytics, audit rules, error logging, loading/error/empty UX, privacy policy, permissions descriptions, app icon, splash, versioning. |
| 20 — Release | Android keystore, signed release/AAB, obfuscation, internal testing или Firebase App Distribution, screenshots и store description. |

</div>

Phase 13 расширена до полноценного сайта и выполняется последовательно:

1. **13a — Public shell:** Next.js foundation, responsive layout, главная о проекте
   и `/download`. CTA и ссылки отражают реально доступные возможности/релизы.
2. **13b — Auth и редактор:** вход, защищённый `/app`, профиль/проекты/блоки,
   общий private draft, состояния сохранения и sync. Включает проверку совместимости
   data contracts и conflict strategy с mobile.
3. **13c — Public portfolio и публикация:** preview, явные publish/unpublish,
   `/u/[username]` с чтением только published snapshot, SEO/metadata/OpenGraph.
   Contact form и Inbox подключаются на Phase 14.

В Phase 0 подготовлен каталог `apps/web` с README. Создание Next.js-приложения
и реализация сайта остаются задачами Phase 13.

**После Phase 0 остановиться; Phase 1 — только с подтверждением пользователя.**
