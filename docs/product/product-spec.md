<div align="center">

# StackCard Product

**Мобильный и web-конструктор developer-портфолио с контролируемой публикацией**

![Stage Phase 1](https://raster.shields.io/badge/Stage-Phase_1-111111?style=for-the-badge)
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
- [План разработки](#план-разработки)
- [Учебные требования и сдача](#учебные-требования-и-сдача)

---

## Статус и границы текущей работы

**Phase 0: Product foundation завершена.** Проверки кода и документов пройдены;
debug APK собран и запущен на Android-эмуляторе, изменение счётчика подтверждено.
По прямому поручению пользователя выполнена **Phase 1: UI foundation**:
пять экранов на mock data, Material 3 темы, общие компоненты и GoRouter.
Этот документ отделяет реализованный интерфейс от целевых функций.
Flutter-приложение находится в `apps/mobile`; в `apps/web`
сейчас только README. Remote `origin` уже подключён; `main` отслеживает `origin/main`.
Для дальнейшей разработки выбрана ветка `dev`, отслеживающая `origin/dev`.
Commit и push выполняются только по запросу пользователя.

План фаз 0–20 документирован; обязательный порядок дальнейшей разработки
закреплён в [общих AI-правилах](../AI/AGENTS.md#разработка-по-плану),
корневом/mobile AGENTS, router и CONTRIBUTING.

Phase 1 использует демонстрационные данные: Firebase, GitHub API, Riverpod,
web, сохранение, редактирование и публикация ещё не подключены. Тема меняется
через `setState` и действует до закрытия приложения. Дальнейшая работа ведётся
в `dev`; переход к Phase 2 требует отдельного поручения пользователя.

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

<a id="roadmap"></a>

## План разработки

План объединяет исходное описание StackCard, требования учебного задания
`individual_project_flutter_ru.docx` и актуальный scope выше: mobile, полноценный
web-редактор и публичные портфолио. Этот раздел владеет roadmap; технические решения
подробно фиксируются в architecture и ADR, команды — в CONTRIBUTING.

**Phase 0 и Phase 1 завершены:** основа и UI foundation проверены;
результаты и ограничения записаны в соответствующих разделах ниже.
Текущее поручение ограничено Phase 1. Фазы 2–20 остаются планом;
дальнейшая разработка ведётся в `dev` после отдельного поручения пользователя.

Чекбокс `- [x]` означает подтверждённый результат, `- [ ]` — оставшуюся задачу
или непроверенный сценарий. При отметке проверки рядом фиксируются результат
и ограничения среды. Фаза завершена только после приёмки обязательных сценариев.

<div align="center">

| **Фаза** | **Статус** |
|:---|:---|
| Phase 0 — Product foundation | Завершена; код, документы и нативный запуск на Android проверены |
| Phase 1 — UI foundation | Завершена; UI, темы, навигация и mock-сценарии проверены |
| Phase 2 — Basic state management | Запланирована |
| Phase 3 — Architecture | Запланирована |
| Phase 4 — GitHub API | Запланирована |
| Phase 5 — Local persistence / offline | Запланирована |
| Phase 6 — Portfolio domain и локальный Builder | Запланирована |
| Phase 7 — Firebase authentication | Запланирована |
| Phase 8 — Firestore synchronization | Запланирована |
| Phase 9 — Living Portfolio / Smart GitHub Sync | Запланирована |
| Phase 10 — Portfolio Suggestions | Запланирована |
| Phase 11 — Media | Запланирована |
| Phase 12 — Location | Запланирована |
| Phase 13a — Public shell | Запланирована |
| Phase 13b — Auth и редактор | Запланирована |
| Phase 13c — Public portfolio | Запланирована |
| Phase 14 — Contact / Inbox / FCM | Запланирована |
| Phase 15 — Developer Card и native sharing | Запланирована |
| Phase 16 — Performance | Запланирована |
| Phase 17 — Testing | Запланирована |
| Phase 18 — CI/CD | Запланирована |
| Phase 19 — Production hardening | Запланирована |
| Phase 20 — Release | Запланирована |

</div>

### Как выполнять план

- Выполнять одну фазу за раз. Сначала завершить её задачи и проверки, затем
  показать результат. Переходить дальше по уже полученному разрешению пользователя;
  если следующая фаза не разрешена, получить подтверждение перед её началом.
- Внутри фазы двигаться небольшими изменениями с проверяемым пользовательским
  сценарием. После каждого шага приложение должно запускаться.
- Добавлять зависимости и слои вместе с реальным использованием. До соответствующей
  фазы не создавать Firebase, Next.js, пустые features или универсальные abstractions.
- Добавлять значимые tests по мере появления поведения. Phase 17 доводит покрытие;
  security rules проверяются при подключении сервиса, а не только перед релизом.
- При приёмке фиксировать: выполненные задачи, результат запуска, проверки,
  ограничения и решения. Не отмечать фазу готовой по одному списку файлов.
- В этом документе обновлять фактический прогресс и результаты проверок фазы.
  После подтверждённого перехода обновлять текущую фазу в разделе статуса
  и связанные описания; правила работы по плану закреплены в
  [общих инструкциях](../AI/AGENTS.md#разработка-по-плану).
- Commit, push, подключение remote и публикация выполняются по отдельному запросу.
  План не задаёт календарные сроки; темы курса сопоставлены в следующем разделе.

### Phase 0 — Product foundation

**Задачи**

- [x] Проверить существующий monorepo и сохранить Flutter-приложение в `apps/mobile`
  с Android/iOS targets; повторно генерировать scaffold не нужно.
- [x] Зафиксировать scope, MVP, экраны, архитектурное направление и дизайн в текущих
  README и guides. Сохранить `.gitignore`, lockfile, ADR и branding originals.
- [x] Выполнить доступные проверки окружения, зависимостей, format, analyze, widget test
  и попытку запуска по [CONTRIBUTING](../../CONTRIBUTING.md#проверки);
  ограничения нативной проверки записаны ниже.
- [x] Подготовить отчёт о фундаменте и ограничениях среды. Commit возможен
  только по запросу пользователя.

**Проверки и приёмка**

- [x] Подтверждены структура monorepo, Android/iOS targets, lockfile, ignore rules,
  ADR и сохранность оригиналов branding.
- [x] Окружение и зависимости проверены; format, analyze и widget test выполнены
  по CONTRIBUTING, результаты и ограничения записаны.
- [x] Минимальное приложение запущено на Android-эмуляторе `main_phone`;
  экран StackCard и изменение счётчика `0 → 1` подтверждены. iOS не проверен;
  причина указана ниже.
- [x] Документы согласованы с существующей основой; отчёт о фазе подготовлен.

**Результаты проверки — 3 октября 2026**

- `flutter --version`: Flutter 3.47.4 stable, Dart 3.13.3; SDK constraint выполнен.
- `flutter pub get`: успешно; manifest и lockfile не изменились.
- `dart format --output=none --set-exit-if-changed lib test`: успешно,
  оба файла уже отформатированы.
- `flutter analyze`: `No issues found`.
- `flutter test`: 1/1 widget test прошёл, включая обновление счётчика.
- Проверка документации: 12 файлов без ошибок оформления и локальных ссылок;
  `project_context.py` и `git diff --check` прошли.
- Mobile содержит только Android/iOS targets; builds, caches и `local.properties`
  исключены из Git. Все шесть SVG совпадают с embedded originals brand kit.
- Android debug APK успешно собран: Gradle 9.3.1, `assembleDebug`,
  `build/app/outputs/flutter-apk/app-debug.apk`. Первая загрузка Gradle завершена;
  исходники и отслеживаемые configs не менялись.
- APK установлен и запущен на `main_phone` (Android 17 / API 37, arm64).
  После завершения оконного эмулятора проверка выполнена в режиме `-no-window`:
  `adb install` завершился успешно, `MainActivity` открылась. Android UI hierarchy
  и снимки экрана подтвердили StackCard, начальный счётчик `0` и значение `1`
  после нажатия кнопки. Физическое устройство не проверялось.
- `flutter doctor -v`: для Android отсутствуют cmdline-tools, статус лицензий
  неизвестен; это не помешало проверенной Android-сборке. Xcode установлен
  неполностью, CocoaPods отсутствует; iOS-запуск не проверялся.
- Локальная ветка `dev` создана от текущего `main` и выбрана для дальнейшей работы;
  незакоммиченные изменения сохранены. В этой задаче commit/push не выполнялись.

**Готово, когда:** минимальное приложение запускается, документы согласованы,
проверки выполнены или их ограничения явно указаны. Firebase, GitHub API,
продуктовые features и Next.js на этой фазе не вводятся.

### Phase 1 — UI foundation

**Задачи**

- [x] Перенести tokens из [design system](../design/design-system.md) в Material 3
  theme: light/dark, typography, spacing, radius и правила Signal Red.
- [x] Создать используемые общие buttons, cards, inputs и состояния loading/error/empty.
- [x] Добавить app shell и GoRouter; показать Sign In, Home, Portfolio, Projects,
  Settings на mock data. Inbox подключается со своим сценарием позднее.
- [x] Подготовить эскизы и проверить пять экранов на телефоне и планшете,
  в portrait/landscape; проверить читаемость, контраст и работу с клавиатурой.

**Проверки и приёмка**

- [x] Sign In, Home, Portfolio, Projects и Settings доступны через app shell;
  переходы и возврат работают на mock data.
- [x] Light/dark темы, typography, spacing, radius и применение Signal Red
  соответствуют design system; общие компоненты используются на экранах.
- [x] Экраны сверены с эскизами на телефоне и планшете в обеих ориентациях;
  читаемость, контраст, keyboard navigation и отсутствие overflow проверены.
- [x] Loading/error/empty состояния проверены; format, analyze и значимые
  UI tests проходят, результаты запуска и ограничения записаны.

**Результаты проверки — 3 октября 2026**

- Палитра из нового поручения перенесена полностью: 15 ролей каждой темы,
  dark по умолчанию. Типографика — локальные DM Sans и Noto Sans для кириллицы,
  лицензии SIL OFL поставляются вместе со шрифтами. Логотип отрисован по оригинальным
  vector paths; исходники branding сохранены.
- Работают вход в демо с локальной валидацией email, переходы/возврат,
  поиск и фильтры проектов, сброс пустого результата, предпросмотр проекта/портфолио,
  dark/light/system, состояния loading/empty/error и retry. Авторизации нет;
  email не сохраняется. Учебная эволюция управления состоянием остаётся Phase 2.
- `flutter pub get`, `flutter analyze` и проверка `dart format` прошли;
  анализ — `No issues found`. `flutter test`: **105/105** tests прошли.
  Пять tests проверяют пользовательские сценарии, включая Tab, отправку формы
  и активацию навигации Enter. Ещё 100 проверяют пять экранов в двух темах,
  text scale 1×/2× и размерах 390×844, 844×390, 768×1024, 1024×768, 320×640.
- При обычном масштабе автоматические проверки контраста текста проходят
  в начале и конце страницы; Android touch target guideline проходит на начальном
  viewport. Это не полный accessibility audit и не подтверждение всех платформ.
- [Эскизы](../design/design-system.md#эскизы-экранов-mobile) согласованы с реализованной
  компоновкой. 40 Flutter PNG в `docs/design/previews` просмотрены для всех пяти
  экранов, двух тем, phone/tablet и обеих ориентаций. Overflow при обычном и
  удвоенном тексте не обнаружен; красный используется локально в CTA и индикаторах.
- Android debug APK собран и установлен на `main_phone` (Android 17 / API 37,
  arm64). Все пять экранов открыты; native UI hierarchy и снимки подтвердили
  переходы, светлую тему и Android Back. Физические phone/tablet и iOS не проверены;
  tablet/landscape проверялись рендерингом Flutter, а не отдельными устройствами.
- Текущий `flutter doctor -v` подтверждает неполную установку Xcode и отсутствие
  CocoaPods, поэтому iOS-запуск недоступен. В Android SDK отсутствуют cmdline-tools
  и неизвестен статус лицензий; Android debug сборка и запуск при этом прошли.
- Документы и ссылки проверены; `git diff --check` чистый. Commit/push не выполнялись.

**Готово, когда:** навигация и обе темы работают, основные экраны соответствуют
эскизам и сохраняют компоновку на разных размерах. Backend не требуется.

### Phase 2 — Basic state management

**Задачи**

- [ ] Выполнить обязательную для курса эволюцию одного простого сценария, например
  переключения темы: `setState → InheritedWidget → Provider`.
- [ ] Сохранить сравнение подходов и этапов рефакторинга; в рабочем коде оставить
  одну итоговую реализацию сценария.
- [ ] Ограничить Provider базовыми ThemeMode/Locale; ввести Riverpod для первого
  реального состояния продукта и обосновать выбор в документации.

**Проверки и приёмка**

- [ ] Один сценарий продемонстрирован последовательно через setState,
  InheritedWidget и Provider; итоговое состояние обновляет нужные widgets.
- [ ] Сравнение и обоснование Provider/Riverpod сохранены; в рабочем коде
  осталась одна итоговая реализация сценария.
- [ ] Поведение состояния проверено; разработчик может объяснить различия
  подходов. Persistence не заявлена до Phase 5.

**Готово, когда:** базовое состояние доступно нужным widgets, обновляется
предсказуемо, а разработчик может объяснить различия трёх подходов. Сохранение
настроек между запусками добавляется на Phase 5.

### Phase 3 — Architecture

**Задачи**

- [ ] Разделить существующие auth/profile/projects сценарии на features с
  `presentation/domain/data`, Repository pattern и Riverpod dependency injection.
- [ ] Убрать бизнес-правила из widgets; domain не связывать с Flutter, Dio, Hive
  или Firebase. Mock-реализации пока остаются источником данных.
- [ ] Создавать UseCase/DataSource только под содержательную логику или источник.
  Обновить architecture и обоснование Provider/Riverpod в документации.

**Проверки и приёмка**

- [ ] UI получает данные через Repository и Riverpod DI; смена mock-источника
  не требует переписывать widgets.
- [ ] Domain не зависит от Flutter, Dio, Hive или Firebase; бизнес-правила
  вынесены из widgets, пустые слои не созданы.
- [ ] Существующие сценарии и значимые tests проходят; architecture и
  обоснование state management согласованы с кодом.

**Готово, когда:** UI получает данные через согласованные границы, источник можно
заменить без переписывания widgets, существующие сценарии продолжают работать.

### Phase 4 — GitHub API

**Задачи**

- [ ] Реализовать отдельный GitHub Import: ввод username, публичный профиль и repositories
  через Dio, модели и JSON serialization.
- [ ] Добавить pagination, timeout, retry, pull-to-refresh и поиск/filter с debounce,
  где он нужен сценарию. Проверить актуальные rate limits и поведение API перед кодом.
- [ ] Показать loading/success/empty/error; отделить сетевой источник от UI и подготовить
  используемый контракт кэша. Протестировать parsing и обработку сетевых сбоев.

**Проверки и приёмка**

- [ ] Публичный профиль и repositories загружаются; pagination, refresh
  и используемый поиск/filter с debounce работают.
- [ ] Loading/success/empty/error, timeout и retry проверены; пустой профиль
  и сетевой сбой не ломают экран.
- [ ] Parsing и обработка сбоев покрыты tests; rate limits и поведение API
  сверены с актуальной документацией. Импорт в portfolio ещё не выполняется.

**Готово, когда:** repositories загружаются и листаются, ошибку можно повторить,
пустой профиль не ломает экран. Импорт в портфолио и Firebase ещё не выполняется.

### Phase 5 — Local persistence / offline

**Задачи**

- [ ] Сохранять theme, locale и простые настройки в SharedPreferences.
- [ ] Использовать Hive для GitHub cache и local portfolio draft; альтернативу
  обосновать в ADR до реализации.
- [ ] Определить cache lifetime, хранение несинхронизированных изменений и версию
  локальной модели; показывать доступные сохранённые данные без сети.
- [ ] Проверить перезапуск, отсутствие сети, пустой/повреждённый кэш и восстановление
  соединения без потери draft.

**Проверки и приёмка**

- [ ] Theme, locale и простые настройки сохраняются после перезапуска.
- [ ] Ранее загруженные repositories и local draft доступны без сети;
  несинхронизированные изменения не теряются.
- [ ] Пустой/повреждённый кэш и reconnect проверены; cache lifetime,
  версия модели и решение о локальном хранилище зафиксированы.

**Готово, когда:** настройки переживают перезапуск, ранее загруженные repositories
доступны offline, локальные изменения сохраняются. Remote sync появится на Phase 8.

### Phase 6 — Portfolio domain и локальный Builder

**Задачи**

- [ ] Ввести Profile, Skill, Project, Experience, Education, SocialLink, PortfolioBlock
  и PortfolioTheme по реальным формам, без окончательной Firestore schema заранее.
- [ ] Реализовать ручные проекты и редактирование профиля, skills, links, experience,
  education и содержимого Resume; формат resume определить перед реализацией.
- [ ] Добавить add/edit/delete, featured, block reorder, show/hide, validation и preview.
  Сохранять изменения в локальный draft.
- [ ] Рассчитать portfolio completion и покрыть правила/validation unit tests,
  основной сценарий editor — widget tests.

**Проверки и приёмка**

- [ ] Ручные проекты и данные профиля можно добавить, изменить и удалить;
  featured, порядок и видимость блоков отражаются в preview.
- [ ] Draft сохраняется, открывается после перезапуска и просматривается offline.
- [ ] Validation и completion покрыты unit tests, основной путь editor —
  widget tests; формат Resume определён. Public publication ещё не доступна.

**Готово, когда:** портфолио можно собрать, сохранить, открыть после перезапуска
и просмотреть offline. Публичной публикации пока нет.

### Phase 7 — Firebase authentication

**Задачи**

- [ ] Подключить Firebase для Android/iOS; описать configuration и environment handling.
- [ ] Реализовать email/password и Google sign-in, регистрацию, восстановление пароля,
  auth state и sign out.
- [ ] Добавить именованные routes, параметры, вложенную навигацию и auth redirects
  в GoRouter; проверить переходы, восстановление сессии и выход.
- [ ] Привязать local draft к Firebase uid, определить перенос гостевого draft
  и изоляцию данных при смене аккаунта.

**Проверки и приёмка**

- [ ] Email/password, Google sign-in, регистрация, восстановление пароля,
  восстановление сессии и sign out проверены.
- [ ] Auth redirects, именованные routes, параметры и вложенная навигация
  корректно открывают защищённые экраны владельцу.
- [ ] Гостевой draft переносится по выбранному правилу; sign out и смена
  аккаунта не раскрывают чужие локальные данные.

**Готово, когда:** оба способа входа работают, защищённые экраны доступны владельцу,
sign out и смена пользователя не раскрывают чужой локальный draft.

### Phase 8 — Firestore synchronization

**Задачи**

- [ ] До remote writes спроектировать private account/draft, public snapshot,
  username uniqueness и проверяемую атомарность publish/unpublish. Зафиксировать ADR.
- [ ] Ввести remote repository поверх local cache; выбрать conflict strategy для
  нескольких устройств и будущего web-клиента, описать последствия.
- [ ] Реализовать `pending/synced/error`, повтор синхронизации и обработку потери сети.
- [ ] Создать Firestore Rules и проверки owner access, отказа чужому пользователю
  и анонимного доступа только к опубликованным данным.

**Проверки и приёмка**

- [ ] Offline-правки синхронизируются после reconnect; pending/synced/error
  и повтор после сбоя отражают фактическое состояние.
- [ ] Конфликт нескольких клиентов обработан по выбранной стратегии;
  private/public schema, username uniqueness и атомарность публикации описаны в ADR.
- [ ] Firestore Rules tests подтверждают owner access, отказ чужому пользователю
  и анонимное чтение только published данных; private draft остаётся private.

**Готово, когда:** offline-правки доходят до облака после восстановления сети,
конфликт обрабатывается по выбранной стратегии, private данные остаются private.
Механизм явной публикации подготовлен; public web появится на Phase 13.

### Phase 9 — Living Portfolio / Smart GitHub Sync

**Задачи**

- [ ] Добавить импорт repository → Project с `source = manual | github`,
  `githubRepositoryId`, `lastGitHubSyncAt` и sync status.
- [ ] Разделить source metadata и пользовательские overrides; повторный импорт
  одного repository не должен создавать дубликаты.
- [ ] Обнаруживать новые/изменённые repositories и показывать Ignore, Preview,
  Add to portfolio и Review changes.
- [ ] Проверить повторную синхронизацию, сохранение ручных правок и отсутствие
  автоматического изменения published snapshot.

**Проверки и приёмка**

- [ ] Выбранный repository импортируется в Project; повторный импорт
  не создаёт дубликат, source metadata и overrides сохраняются раздельно.
- [ ] Новые и изменённые repositories предлагают Ignore, Preview,
  Add to portfolio и Review changes; владелец выбирает действие.
- [ ] Повторный sync сохраняет ручные правки и не меняет published snapshot
  без явной публикации; сценарии проверены.

**Готово, когда:** владелец импортирует и принимает выбранные изменения,
а обновление GitHub не перезаписывает curated данные и публичную версию молча.

### Phase 10 — Portfolio Suggestions

**Задачи**

- [ ] Реализовать deterministic rules: новый repository, активность, отсутствующие
  description/preview и кандидаты для featured.
- [ ] Если нужен внутренний ProjectScore, определить факторы и пороги в одном месте;
  UI показывает причину и полезное действие.
- [ ] Проверить правила unit tests независимо от UI и внешних сервисов.

**Проверки и приёмка**

- [ ] Одинаковые входные данные дают одинаковые suggestions;
  новый repository, активность и отсутствие description/preview проверены.
- [ ] Каждая suggestion объясняет причину и предлагает действие владельцу;
  факторы и пороги ProjectScore определены в одном месте, если он используется.
- [ ] Unit tests правил проходят без UI и внешних сервисов; AI и
  автоматическая публикация не введены.

**Готово, когда:** одинаковые входные данные дают объяснимые suggestions,
владелец выбирает действие; AI и автоматическая публикация не используются.

### Phase 11 — Media

**Задачи**

- [ ] Подключить Firebase Storage для avatar и project images, camera/gallery.
  При выбранном файловом формате resume добавить его загрузку здесь.
- [ ] Ввести MIME/size validation, compression/resize, upload progress, retry
  и image caching через cached_network_image; обработать отказ в permissions
  и отмену выбора.
- [ ] Создать Storage Rules, проверку ownership и public/private доступа,
  определить очистку заменённых файлов.

**Проверки и приёмка**

- [ ] Avatar и project images выбираются через camera/gallery,
  проходят MIME/size validation, compression/resize и отображаются после upload.
- [ ] Progress, retry, caching, отказ в permissions и отмена выбора проверены
  на устройстве; выбранный файловый Resume обрабатывается, если он предусмотрен.
- [ ] Storage Rules tests подтверждают ownership и public/private доступ;
  чужие/private файлы недоступны, очистка заменённых файлов определена.

**Готово, когда:** изображения загружаются и отображаются, сбой даёт повтор,
чужие/private файлы недоступны. Нативный сценарий проверен на устройстве.

### Phase 12 — Location

**Задачи**

- [ ] Подключить geolocator и Google Maps к Profile Location Picker.
- [ ] Получить геопозицию по действию пользователя, показать marker и дать
  подтвердить местоположение на карте.
- [ ] Обработать denied, permanently denied и service disabled; в публичное
  представление передавать только выбранный город/страну без точных coordinates.

**Проверки и приёмка**

- [ ] Геопозиция запрашивается по действию пользователя; marker показан,
  выбранное местоположение подтверждается и сохраняется.
- [ ] Denied, permanently denied и service disabled проверены;
  отказ не блокирует editor.
- [ ] Public представление содержит только выбранный город/страну;
  точные GPS coordinates не раскрываются.

**Готово, когда:** location выбирается и сохраняется, отказ не блокирует editor,
публичное портфолио не раскрывает точную геопозицию.

### Phase 13 — Website и web editor

Только здесь создать Next.js-приложение в подготовленном `apps/web`, выбрать
зависимости и реальные format/lint/typecheck/test/build команды. Выполнять
подэтапы **13a → 13b → 13c**, сохраняя единые data contracts с mobile.

#### 13a — Public shell

**Задачи**

- [ ] Создать Next.js-приложение в `apps/web`; выбрать используемые зависимости
  и реальные format/lint/typecheck/test/build команды.
- [ ] Реализовать responsive layout, главную и `/download` в принятом
  визуальном стиле.
- [ ] Показать CTA и download links по фактической доступности;
  до релиза не показывать фиктивные ссылки на магазин.

**Проверки и приёмка**

- [ ] Главная и `/download` читаемы и доступны на телефоне, планшете и desktop;
  layout соответствует принятому стилю.
- [ ] CTA ведут к доступным действиям; фиктивных store/download links нет.
- [ ] Выбранные web checks и build проходят по реальным configs;
  результаты и ограничения записаны.

#### 13b — Auth и редактор

**Задачи**

- [ ] Реализовать вход и защищённый `/app` для владельца.
- [ ] Добавить профиль, проекты, блоки и GitHub import общего private draft.
- [ ] Показать saving/saved/error/retry; web v1 оставить online-first.
- [ ] Проверить owner access и обмен правками mobile ↔ web.

**Проверки и приёмка**

- [ ] Auth guards закрывают private редактор от анонимного и чужого пользователя.
- [ ] Владелец редактирует одно портфолио из обоих клиентов;
  правки передаются mobile ↔ web по общей модели и conflict strategy.
- [ ] Saving/saved/error/retry отражают реальное состояние;
  сбой online-сохранения даёт понятный повтор, проверки редактора проходят.

#### 13c — Public portfolio

**Задачи**

- [ ] Реализовать preview и явные publish/unpublish в обоих редакторах.
- [ ] Создать `/u/[username]`, metadata, SEO/OpenGraph.
- [ ] Публичному клиенту разрешить чтение только published snapshot;
  корректно обработать неизвестный/unpublished username.

**Проверки и приёмка**

- [ ] Посетитель видит только опубликованную версию;
  изменение draft не меняет public page до Publish.
- [ ] Publish обновляет публичную версию, Unpublish прекращает доступ;
  неизвестный и unpublished username обработаны корректно.
- [ ] Metadata и SEO/OpenGraph проверены; private данные не раскрываются,
  publication tests и общий сценарий mobile ↔ web проходят.

**Проверки и приёмка Phase 13**

- [ ] Подэтапы 13a → 13b → 13c приняты последовательно;
  общие data contracts согласованы с mobile, web checks проходят.
- [ ] Сценарий редактирование → preview → publish → правка draft → unpublish
  подтверждён в обоих клиентах и на public page.

**Готово, когда:** владелец редактирует одно портфолио из двух клиентов, посетитель
видит только опубликованную версию, новая правка draft не меняет public page
до Publish, Unpublish прекращает доступ. Contact form подключается на Phase 14.

### Phase 14 — Contact / Inbox / FCM

**Задачи**

- [ ] Добавить web Contact me с name/email/message и validation; определить
  anti-spam/rate limiting до публичного открытия формы.
- [ ] Создать ContactRequest и Inbox в mobile/web; обращения читает только владелец.
- [ ] Настроить mobile FCM: device tokens, permissions и переход из уведомления
  к обращению. Отправку выполнять с доверенной стороны, с Functions при необходимости.
- [ ] Проверить доставку на устройстве, отказ в уведомлениях и смену аккаунта;
  Inbox остаётся источником обращения при недоставленном push.

**Проверки и приёмка**

- [ ] Валидное обращение с public page появляется в mobile/web Inbox;
  validation, anti-spam и rate limiting проверены до публичного открытия формы.
- [ ] Обращение читает только владелец; отказ постороннему подтверждён
  проверками доступа.
- [ ] FCM доставлен на устройство, переход открывает обращение;
  отказ в notifications и смена аккаунта проверены, без push обращение остаётся в Inbox.

**Готово, когда:** обращение с public page появляется в обоих кабинетах,
владелец получает mobile notification, посторонний не читает Inbox. Это не чат;
browser push автоматически в scope не добавляется.

### Phase 15 — Developer Card и native sharing

**Задачи**

- [ ] Создать карточку с avatar, name, role, technologies, username, logo и public URL.
- [ ] Добавить QR-код; обработать состояние портфолио, которое ещё не опубликовано.
- [ ] Реализовать собственный MethodChannel → Android/Kotlin → `Intent.ACTION_SEND`.
  Поведение sharing для iOS определить и проверить отдельно.

**Проверки и приёмка**

- [ ] Developer Card содержит avatar, name, role, technologies, username,
  logo и корректный public URL; unpublished состояние обработано.
- [ ] QR открывает опубликованное portfolio.
- [ ] Собственный Kotlin MethodChannel и Android share sheet передают ссылку
  на реальном устройстве; результат проверки iOS sharing указан отдельно.

**Готово, когда:** QR открывает public portfolio, native Android share sheet
передаёт корректную ссылку, Platform Channel работает на реальном устройстве.

### Phase 16 — Performance

**Задачи**

- [ ] Проверить большие списки, pagination, изображения, rebuilds, memory и frames
  в Flutter DevTools; ListView.builder и image caching вводить уже при появлении сценариев.
- [ ] Сохранить исходные измерения и screenshots, исправить обнаруженные проблемы
  и повторить тот же сценарий на том же устройстве.
- [ ] Проверить public web/editor после появления реальных данных и изображений.

**Проверки и приёмка**

- [ ] Большие списки, pagination, изображения, rebuilds, memory и frames
  измерены в Flutter DevTools на указанном устройстве.
- [ ] Сохранены сопоставимые measurements/screenshots до и после;
  один сценарий повторён на том же устройстве, каждая оптимизация объяснена.
- [ ] Public web/editor проверены с реальными данными и изображениями;
  ненужные микрооптимизации не добавлены.

**Готово, когда:** есть сопоставимые результаты до/после и объяснение каждой
оптимизации. Микрооптимизация без измеренной проблемы не требуется.

### Phase 17 — Testing

**Задачи**

- [ ] Довести unit tests repositories, validation, completion, sync и suggestions;
  widget tests auth, project card, builder и loading/error/empty states.
- [ ] Добавить минимум один integration test: sign in → create/edit project →
  preview → publish. Проверить offline/reconnect и private/public границу.
- [ ] Получить `flutter test --coverage` с coverage **более 40%**, clean analyze
  и отчёт о покрытии. Проверить web auth guards, публикацию и обмен draft с mobile.

**Проверки и приёмка**

- [ ] Unit и widget tests для repositories, validation, completion, sync,
  suggestions, auth, project card, builder и UI states проходят.
- [ ] Integration test sign in → create/edit project → preview → publish
  проходит; offline/reconnect и private/public граница подтверждены.
- [ ] Coverage по flutter test --coverage превышает 40%, analyze чистый;
  отчёт сохранён, web auth guards, publication и обмен draft с mobile проверены.

**Готово, когда:** tests проходят, coverage превышает учебный порог, сквозной
сценарий подтверждён. Tests предыдущих фаз сохраняются и дополняются.

### Phase 18 — CI/CD

**Задачи**

- [ ] Добавить GitHub Actions для каждого push/PR: dependency resolution, format check,
  analyze, tests с coverage, APK build и сохранение artifact.
- [ ] Настроить проверку порога coverage, воспроизводимое окружение и отдельные
  проверки web по его реальным configs.
- [ ] Проверить, что ошибка проверки делает pipeline неуспешным; signing secrets
  не хранить в коде. Release AAB подключить на фазе выпуска.

**Проверки и приёмка**

- [ ] Pipeline запускается на push/PR, проходит dependency resolution,
  format, analyze, tests, coverage и APK build; artifact доступен.
- [ ] Ошибка format/analyze/tests или недостаточное coverage делает
  pipeline неуспешным; негативный сценарий проверен.
- [ ] Окружение воспроизводимо, web checks соответствуют реальным configs;
  signing secrets отсутствуют в коде, release AAB остаётся задачей выпуска.

**Готово, когда:** pipeline проходит на рабочей версии, APK artifact доступен,
нарушение format/analyze/tests/coverage блокирует успешный результат.

### Phase 19 — Production hardening

**Задачи**

- [ ] Подключить Crashlytics и подтвердить доставку тестового отчёта; настроить
  безопасное error logging без private данных.
- [ ] Провести audit Firestore/Storage Rules и public/private границ, проверить
  validation, permission descriptions, account deletion и обработку сбоев.
- [ ] Завершить onboarding, loading/error/empty UX, app icon, splash, versioning
  и privacy policy; проверить оба мобильных targets и responsive web.

**Проверки и приёмка**

- [ ] Тестовый Crashlytics report доставлен; error logging не содержит
  private данных.
- [ ] Firestore/Storage Rules, validation, account deletion, permission
  descriptions и обработка сбоев проверены; значимые дефекты устранены.
- [ ] Onboarding, loading/error/empty UX, icon, splash, versioning и privacy
  policy готовы; Android, iOS и responsive web проверены.

**Готово, когда:** диагностический отчёт доставлен, значимые security/UX дефекты
устранены, разрешения и работа с данными объяснены пользователю.

### Phase 20 — Release

**Задачи**

- [ ] Утвердить application IDs и signing configuration, создать и безопасно хранить
  Android keystore; собрать подписанный release AAB с obfuscation и сохранить symbols.
- [ ] Проверить release на устройстве, подготовить screenshots, описание и privacy policy.
- [ ] Подготовить Google Play internal testing; при отсутствии developer account —
  подписанный AAB и пакет материалов, раздачу через Firebase App Distribution.
- [ ] Опубликовать реальные download links после появления релиза; отдельно описать
  шаги iOS/App Store и подготовить демонстрацию проекта.

**Проверки и приёмка**

- [ ] Подписанный Android release AAB с obfuscation собран и проверен
  на устройстве; signing configuration, keystore и symbols хранятся безопасно.
- [ ] Screenshots, описание, privacy policy и демонстрация готовы;
  Google Play internal testing либо пакет AAB/App Distribution подготовлен.
- [ ] Выполнен только разрешённый пользователем способ распространения;
  download links ведут к реальному release.
- [ ] Шаги iOS/App Store описаны отдельно; Android release не выдаётся
  за выполненную iOS-публикацию.

**Готово, когда:** подписанный Android release проверен, материалы для магазина
готовы, выполнен разрешённый способ распространения. Загрузка в Google Play,
App Distribution или deploy web требует запроса пользователя; iOS-публикация
не заявляется выполненной по одному Android release.

**Phase 0 и Phase 1 завершены. Дальнейшая разработка — в `dev`;
Phase 2 требует отдельного поручения пользователя.**

---

## Учебные требования и сдача

Учебное задание задаёт **16 недель**, продуктовый план — **21 фазу (0–20)**.
Это разные единицы: таблица сопоставляет темы и результаты, не назначает
фазе длительность в одну неделю. Все обязательные компоненты курса включены
в задачи выше; готовность подтверждается работой приложения и проверками.

<div align="center">

| **Неделя курса** | **Фазы и подтверждение результата** |
|:---|:---|
| 1 — Flutter/Dart | Phase 0: окружение и Hello World; Dart-задачи на null safety, classes, collections, async/await; постановка задачи, аудитория, список экранов и сравнение 2–3 аналогов. |
| 2 — Widgets/UI | Phase 1: эскизы и статические экраны, Stateless/Stateful widgets, Material 3. |
| 3 — Basic state | Phase 2: один сценарий setState → InheritedWidget → Provider и сравнительная заметка. |
| 4 — Advanced state/architecture | Phases 2–3: Riverpod, presentation/domain/data, Repository, DI и обоснование выбора. |
| 5 — REST/JSON | Phase 4: GitHub API, serialization, states, timeout/retry, refresh и debounce. |
| 6 — Persistence | Phase 5: настройки, кэш и доступ без сети; локальный Builder развивается на Phase 6. |
| 7 — Navigation/adaptive UI | Phases 1 и 7: routes/parameters/nested navigation, auth redirect после подключения auth, телефон/планшет и обе ориентации. |
| 8 — Firebase/РК1 | Phases 7–8 и 14: email/Google, Firestore, Rules, FCM на устройстве; материалы текущих заданий недель 1–7. |
| 9 — Maps/location | Phase 12: карта, marker, геопозиция и отказ в permissions; use-case Profile Location. |
| 10 — Performance | Phase 16 и предыдущие API/media фазы: lazy lists, pagination, image cache, DevTools screenshots до/после. |
| 11 — Native | Phases 11 и 15: camera/gallery и собственный Kotlin MethodChannel на устройстве. |
| 12 — CI/CD | Phase 18: зелёный pipeline, build/analyze/tests на push и APK artifact. |
| 13 — Tests | Phase 17: unit/widget/integration tests, coverage >40%, отчёт и запуск в CI. |
| 14 — Publication | Phases 19–20: Crashlytics, signed AAB, store materials/internal testing либо App Distribution; описание iOS-публикации. |
| 15 — Presentation/РК2 | Демонстрация 7–10 минут: сценарий, архитектура, tests и profiling; материалы заданий недель 8–15. |
| 16 — Exam | Индивидуальная защита: работа приложения, разбор кода/архитектуры и способность объяснить и воспроизвести выбранный фрагмент. |

</div>

**Календарное расхождение:** курс требует FCM уже на неделе 8, карты — на 9,
CI — на 12; текущий продуктовый roadmap вводит их на Phases 14, 12 и 18.
Web-редактор добавляет работу сверх обязательного учебного объёма. Если недельные сроки обязательны,
до начала следующих фаз нужен отдельно согласованный учебный график: он должен
перенести учебные milestones раньше и выделить дополнительные функции продукта.
Следование текущей последовательности само по себе не гарантирует сдачу по неделям.

Для учебной подготовки дополнительно:

- Подтвердить у преподавателя закрепление темы Developer Portfolio; менять тему
  только по согласованию. Текущая документация не подтверждает административное согласование.
- Подготовить Dart-упражнения и сравнение 2–3 аналогов. В публичном README
  оставить краткое обоснование state management со ссылкой на подробное решение;
  требования/MVP и план остаются в product spec по правилам проекта.
- Сохранять доказательства по мере работы: эскизы, результаты запусков, отчёт
  coverage, DevTools до/после, CI artifact, Crashlytics report и release materials.
- После разрешённых commits использовать историю изменений для объяснения этапов.
  На защите уметь самостоятельно объяснить код, ограничения и принятые решения.
