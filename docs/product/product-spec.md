<div align="center">

# StackCard Product

**Мобильный и web-конструктор developer-портфолио с контролируемой публикацией**

![Stage Phase 10 complete](https://raster.shields.io/badge/Stage-Phase_10_complete-111111?style=for-the-badge)
![Mobile + Web planned](https://raster.shields.io/badge/Mobile_%2B_Web-planned-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Статус и границы текущей работы](#статус-и-границы-текущей-работы)
- [Редизайн мобильного интерфейса](#редизайн-мобильного-интерфейса)
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
По следующему поручению выполнена **Phase 2: Basic state management**:
эволюция темы `setState → InheritedWidget → Provider`, Riverpod для поиска/фильтров
Projects и воспроизводимые учебные этапы вне рабочего кода.
По следующему поручению завершена **Phase 3: Architecture**: features
auth/profile/projects разделены на `presentation/domain/data`, Repository
contracts и Riverpod DI позволяют заменять демонстрационные источники.
По следующему поручению завершена **Phase 4: GitHub API**: отдельный GitHub Import
загружает публичный профиль и repositories через Dio, поддерживает pagination,
refresh, локальный поиск/filter и повтор запроса после ошибки.
Результаты проверок и Android-запуска зафиксированы в
[разделе Phase 4](#phase-4--github-api).
По предыдущему поручению завершена **Phase 5: Local persistence / offline**:
theme, ru/en locale и настройка описаний источника сохраняются в SharedPreferences;
Hive хранит GitHub cache и отдельные локальные заметки с revision/pendingSync.
Перезапуск, offline и reconnect проверены на Android;
подробности — в [приёмке Phase 5](#phase-5--local-persistence--offline).
По предыдущему поручению завершена **Phase 6: Portfolio domain и локальный Builder**:
единый draft, ручные формы и preview без публикации. Resume выбран обычным
текстом с сохранением переносов строк; файловые вложения в этой фазе не вводятся.
По предыдущему поручению реализована **Phase 7: Firebase authentication**: account
session, защищённые routes и UID isolation. Обязательная Google/reset/iOS приёмка
остаётся открытой в [Phase 7](#phase-7--firebase-authentication). По явному следующему
поручению пользователя завершена **Phase 8: Firestore synchronization**: private draft,
состояния синхронизации и правила доступа; схема зафиксирована в
[ADR](../decisions/0001-firestore-sync-and-publication.md).
По следующему прямому поручению завершена **Phase 9: Living Portfolio / Smart GitHub Sync**:
явный импорт repositories, review изменений и сохранение ручных overrides.
По следующему прямому поручению завершена **Phase 10: Portfolio Suggestions**:
детерминированные подсказки с объяснением и явным действием владельца.
Этот документ отделяет реализованный интерфейс от целевых функций.
Flutter-приложение находится в `apps/mobile`; в `apps/web`
сейчас только README. Remote `origin` уже подключён; `main` отслеживает `origin/main`.
Для дальнейшей разработки выбрана ветка `dev`, отслеживающая `origin/dev`.
Commit и push выполняются только по запросу пользователя.

План фаз 0–20 документирован; обязательный порядок дальнейшей разработки
закреплён в [общих AI-правилах](../AI/AGENTS.md#разработка-по-плану),
корневом/mobile AGENTS, router и CONTRIBUTING.

После успешного чтения пустого/legacy draft основные экраны используют demo;
после начала Builder — единый working PortfolioContent. Home, Projects и Settings
читают проекции этого content; Portfolio и preview отображают видимые блоки
в заданном порядке и теме. Ошибка чтения draft показывает failure/retry, без demo fallback.
GitHub Import отдельно читает публичный GitHub API с persistent cache и offline fallback.
Firebase Auth и Firestore sync подключены в native bootstrap.
Web и пользовательская публикация остаются следующими фазами. App settings принадлежат AppearanceController через
Provider; account session/actions, Builder и filters — Riverpod.
Settings, GitHub response cache, явно сохранённые content и notes переживают перезапуск;
Firebase session восстанавливается SDK; явный guest access, query/filter и ещё
не сохранённый ввод остаются в app session. Account draft хранится отдельно по UID;
guest draft переносится только явно из Settings в пустой account namespace.
Чтение и refresh GitHub не меняют curated portfolio. Явные Add/Accept/Ignore
меняют working draft; Save сохраняет его отдельно, публикация остаётся отдельным действием.
Пользователь явно разрешил переход к Phase 8 при открытой приёмке Phase 7;
это не означает завершения оставшихся auth сценариев. Phase 9 завершена;
Phase 10 завершена; Phase 11 и последующие этапы требуют отдельного поручения.

---

## Редизайн мобильного интерфейса

**Результат (2026-10-04):** по прямому поручению пользователя в существующей
ветке `redesign/full-app` переработан UI возможностей Phase 0–10. Палитра
Obsidian/Signal Red расширена acid/cyan/pink; UI адаптирует композицию
прикреплённого референса и короткие controls/sections из 21st.dev.
Общий визуальный контракт для mobile и будущего web находится в
[design system](../design/design-system.md).

**Задачи и приёмка**

- [x] Обновить canonical theme/shared widgets, навигацию и Home.
- [x] Переработать auth, Portfolio, Projects, Settings, GitHub Import/review,
  Builder, формы, notes и preview; убрать вложенные cards, повторные подписи
  и декоративные badges. Metadata/revision/date доступны через раскрытие.
- [x] Сохранить critical states и явные actions; auth/guest/transfer, CRUD,
  Save/reload, sync, Add/Accept/Ignore, visibility/order и private preview
  проверены existing tests. Domain/data/controllers/providers, Rules/schema,
  dependencies и оригинальные branding assets не изменены.
- [x] `dart format lib test integration_test` — **181 files, 0 changed**;
  `flutter analyze` — **No issues found**; полный `flutter test` — **822 passed**.
  UI expectations адаптированы к коротким действиям и раскрытию metadata.
  Contrast/touch-target проверки измеряют целиком отрисованный контент при
  исходной ширине; пороги WCAG/Android не снижались, overflow/goldens остаются
  на исходных viewports.
- [x] Обновлены **56** Flutter previews для основных экранов и Builder в
  light/dark, portrait/landscape phone/tablet. Выборочно просмотрены Home,
  Sign In, Portfolio, Projects, Settings, Builder hub и light preview,
  включая phone и tablet layouts.
  Responsive checks включают 320 px и text scale 2, Builder/review — ru/en
  и клавиатуру. Ordinary `main.dart` собран и запущен на `emulator-5554`,
  native Sign In и Home после guest access просмотрены; checksum существующего
  `portfolio_draft.hive` совпал до/после запуска.
- [ ] Native iOS запуск не проверен; прежняя открытая приёмка Phase 7 сохраняется.

**Уточнение входа (2026-10-04):** по обратной связи пользователя удалён весь
розовый декоративный poster со слоганом. Вход, регистрация и сброс пароля
используют центрированный по обеим осям блок шириной до 400 px и отдельно
центрированный brand; текст формы остаётся слева. По следующему уточнению
введены нейтральные ссылки и матовые поля/кнопки с radius 12;
recovery, submit/Google, переход режима и guest образуют последовательные группы.
Прошли 52 auth/navigation/widget/localization tests, включая 6 новых проверок
геометрии центрирования, контраста, targets и доступности submit с клавиатурой
на phone/tablet для всех трёх режимов и обеих тем. Дополнительно прошли 20
responsive checks демо-входа, включая 320 px и text scale 2; обновлены 8 demo
previews и созданы 6 account previews. `flutter analyze` — **No issues found**.
Все три account формы собраны и просмотрены на `emulator-5554`;
checksum локального draft до/после совпал.

**Единые основные кнопки (2026-10-04):** по последнему уточнению пользователя
auth наследует красный CTA всего приложения с белыми текстом и иконками.
`ColorScheme.primary/onPrimary` используют существующий `#E60010` и `#FFFFFF`
с контрастом 4.80:1; исходный brand остаётся Signal Red `#FF0012`.
Проверены все 10 primary-вызовов: auth/demo, Portfolio, Builder/редакторы/notes,
GitHub import/review. Loading сохраняет красный фон и белый spinner,
disabled без loading получает нейтральные фон и читаемый текст.
Приёмка: `dart format` — **182 files, 0 changed**; `flutter analyze` —
**No issues found**; полный `flutter test` — **832 passed** после восстановления
отсутствовавшего RU `account.guestNote`. Четыре новых button regression cases
проверяют реальные цвета текста/иконки/spinner, contrast, hover/press/focus,
loading/disabled и secondary в обеих темах, включая auth.
Перегенерированы все **62** previews; выборочно просмотрены auth, Portfolio
и Builder в light/dark. На Android просмотрены Sign In и Portfolio с белыми
надписями на красном; checksum сохранённого draft совпал.

Редизайн не начинает Phase 11 или web implementation. Commit/push не выполнялись.

### Новый Figma-first target (2026-10-04)

По следующему прямому запросу принят новый UX/UI target: DeveloperProfile и
глобальная Projects Library дают несколько структурированных Resumes и Portfolios;
featured/visible/order относятся к связи Project с Portfolio. Root navigation —
Home / Resumes / Projects / Portfolios с постоянными labels; Settings открывается
через contextual gear, nested Back сохраняется. Target brand заменяет Signal Red
на acid lime с neutral foundation и cyan/pink artwork; 390 px — основной размер,
большие экраны сохраняют ту же IA.

Первый scope — repository и
[Figma audit](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard), IA,
target design system и пять key screens. Через MCP изучены 9 Figma pages,
31 COMPONENT/COMPONENT_SET узел на components page и color/metrics collections.
Первая итерация выполнена: по пять ключевых экранов в dark/light на 390×844,
обновлённые shared masters/variables и root prototype с 19 переходами в каждой
теме. Структура через MCP и все десять renders просмотрены; это не закрывает
полные flows, responsive и accessibility QA.
Экранная карта, relations и pending acceptance — в
[redesign plan](../design/redesign-plan.md); canonical visual target — в
[design system](../design/design-system.md).

Текущий Flutter сохраняет red primary, одиночный PortfolioContent, plain
resumeText и прежнюю навигацию. Runtime/schema/Rules, dependencies и original
branding assets этой Figma-first задачей не изменены. Исторические checks выше
сохраняют свой scope и не подтверждают target. Core flows, state/responsive set,
web design, multiple-output migration и Flutter/web implementation остаются
следующими шагами. Node links и фактическая приёмка — в redesign plan.

---

## Концепция и аудитория

**StackCard** — приложение для управления developer identity: базовый профиль,
глобальная библиотека проектов, несколько резюме и портфолио под разные роли.
Flutter-приложение и будущий web-кабинет используют общие данные владельца и
явную публикацию outputs; текущий runtime пока хранит один draft. Сайт объясняет проект на
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
Модель и правила сопоставления Phase 9 зафиксированы в
[ADR 0002](../decisions/0002-github-import-and-review.md).

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

Рекомендации Phase 10 используют понятные deterministic rules, без AI:
новый репозиторий, недавнее известное обновление или длительный простой,
отсутствующие description/demo и кандидат для featured. UI объясняет причину
и открывает Preview или редактор; владелец выбирает и сохраняет изменения сам.
Screenshot относится к Media Phase 11; новые технологии и другие сигналы могут
расширить правила позже при отдельном scope.

`ProjectScore` не вводится: для текущих действий достаточно конкретных условий.
Пороги активности и stars определены в одном pure API; подробный контракт — в
[architecture](../architecture/architecture.md#portfolio-suggestions).
Правила проверяются отдельно от UI и не публикуют изменения сами.

---

## Пользовательский путь и экраны

### Мобильное приложение

Принятый target экранов и переходов — в
[Figma-first плане](../design/redesign-plan.md#navigation-map). Ниже сохранён
прежний single-portfolio scope для связи с учебными фазами и current runtime;
completion, global Featured и пять tabs не являются новым target.

Прежний целевой первый запуск:

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

Ниже сохранён прежний MVP по фазам, а не задача Phase 0. Его single Portfolio и
global Featured заменены новым [target model](../design/redesign-plan.md#целевая-domain-relation):
multiple Resumes/Portfolios и featured в PortfolioProject. Историческая приёмка
фаз сохраняется; будущая migration определяется до implementation.

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

Визуальный язык **Obsidian / Signal Red / Electric**: цельные цветные поверхности,
крупная типографика и открытые секции без вложенных карточек;
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

**Phase 0–6 завершены:** основа, UI, состояние, архитектура, GitHub Import, offline и Builder проверены;
результаты и ограничения записаны в соответствующих разделах ниже.
**С 2026-10-05 основная разработка новых функций приостановлена:** активна только
R5 инициативы [StackCard Design v2](../redesign/README.md), весь пакет
R5.1a–R5.4c ожидает общей приёмки D037, в сохранённом full-phase/parallel/no-preview режиме D036. Прямое поручение
использовать [план R0–R9](../redesign/plan.md) и начать первую фазу приняло R0
и разрешило R1.1. Поручение «переходи к следующей фазе» приняло
[три схемы IA](../redesign/screens.md#r11--информационная-архитектура)
и разрешило следующую задачу R1.2. Поручение исправить кнопки/поиск и затем
продолжить приняло [24 low-fi экрана R1.2](../redesign/screens.md#r12--low-fi-основных-сценариев)
после проверенных правок: последовательные кнопки горизонтально, поиск с лупой
без заголовка. Приняты поручением «переходи к следующему этапу» ещё
[24 low-fi экрана R1.3](../redesign/screens.md#r13--low-fi-resume-wizard-и-редактора):
пять шагов Resume, optional skip, фото/no-photo, focused sections и отдельный Save.
Созданы и визуально проверены
[40 low-fi экранов R1.4](../redesign/screens.md#r14--low-fi-projects-portfolio-и-публикации):
Project create/import/review, Portfolio attachments/preview, отдельный Publish,
errors/unsaved/public access. Ответом пользователя принята политика постоянных
адресов документов, сохраняемых при смене названия/никнейма (D019).
Поручение добавить цветовые акценты и затем продолжить выполнено (D020):
основные действия и выбранные состояния выделены lime, опасные — красным;
размеры и горизонтальные ряды сохранены. **R1 — done; R2.1 — done D022**:
[шесть пилотов](../redesign/screens.md#r21--два-визуальных-направления) сравнивают
два направления на одинаковых Home, public Resume без фото и Настройках.
Сравнение принято поручением продолжить. **R2.2/R2.3/R2 — done D024**:
[brand specimens](../redesign/screens.md#r22--знак-написание-и-иконка-приложения)
обоих вариантов содержат знак/написание/иконку, dark/light/mono, проверку
16–48 px и восьми UI-шапок. Пользователь выбрал бренд A и поручил продолжить;
связанные пилоты A / Cyber Editorial служат основой R3. B сохранён как история.
**R3.1 — done D028**: после сравнения Noto Sans / Manrope / Golos Text
пользователь поручил перейти к следующему этапу. Закреплена рекомендация Manrope;
[Dark/Light foundations](../redesign/screens.md#закреплённая-типографика-manrope-d028)
обновлены, исходная палитра/Wordmark A сохранены. Это Figma UI, bundled fonts
пока прежние. **R3.2 — done D030**:
[Navigation/cards/TechnologyBadge](../redesign/screens.md#r32--навигация-карточки-и-technologybadge)
содержат9 sets/44variants,4 root labels,3 Home filters, gear/back, отдельное Copy
и badges icon+text/+N/full wrap. Итоговые410 texts contrast/bounds PASS;
**R3.3 — done D032**:
[формы, stepper, фото и секции](../redesign/screens.md#r33--формы-stepper-фото-и-секции)
содержат10 sets/67 variants, PhotoSourceSheet и6 SVG icons; четыре Dark/Light
boards показывают keyboard и static ×2 reflow.513 texts/103 strokes, bounds,
references и touch audit PASS. Фотография — обозначенный generated_demo,
не пользовательский upload. Поручение D032 приняло R3.3 и разрешило R3.4,
работу нескольких агентов и ускорение.
**R3.4 и полная R3 — done D034**:
[states/motion/adaptive](../redesign/screens.md#r34--состояния-motion-и-адаптивность)
содержат2sets/18variants и10Dark/Light fixtures320/390/430/768/844landscape.
Local Save, server ACK иPublish разделены; unknown publication result честно
обозначен. Save/Отмена закреплены над bottom tabs; motion180/240/280ms и0ms
reduced — статические specs.393texts/786mode samples,342strokes/96targets,
geometry/bindings/references/scopes PASS. Native keyboard/media/OS scaling/
routing/clipboard/icon exports иplayable prototype ещё pending.
**R4 — done D036**: пользователь принял полную R3 и разрешил
все девять задач R4.1–R4.7c одним пакетом D034. Собраны четыре root-библиотеки
и Settings/Profile/Contacts/Account/Privacy/App: [61state/122Dark-Light frames,
9boards](../redesign/screens.md#r4--основные-экраны-и-настройки).
Metadata/contrast: 2074actual-mode text samples ≥4.739:1,
1446strokes ≥4.364:1,840targets≥48;17failure categories0.
70fixed-brand vector fills сохраняют original Flutter/Dart assets; scope
onPrimary расширен STROKE_COLOR без смены palette values.
Добавлены три scoped families/6input-composition variants и один pinned Search SVG;
98variables/50styles сохранены без drift. Визуальный просмотр, preview и запуск
приложения не выполнялись по прямому запросу D034. Полный пакет принят
следующим поручением продолжить, D036. Это Figma target; новые screens/routes/
backend этим пакетом не реализованы.
**R5 — awaiting_review D037**: поручение «переходи к следующему этапу
разработки» приняло всю R4 и продолжило следующую R5 в сохранённом режиме
фаза целиком/параллельно/без preview и запуска. Это интерпретация прежних
предпочтений; пользователь не называл весь набор R5 буквально.
Все 13 задач собраны: [83 состояния / 166 Dark/Light frames / 13 boards](../redesign/screens.md#r5--создание-редактирование-и-публикация).
Resume wizard/edit/structured preview, manual/GitHub Projects/review,
Portfolio content/associations/appearance и Publish/Share/Unpublish/delete
сохраняют отдельные local Save, sync ACK и explicit Publish. Unknown outcome
не объявляется success. Structural QA:3474actual-mode text samples
min4.832909811:1,1280strokes min4.364564811:1,966targets≥48;18failure categories0.
Wizard1–5/16preview/84forms/152fixedfooter и48actual identity checks PASS.
98variable values/50style IDs сохранены точно;274originalFlutter/Dart fills
retained targeted source exemption,14existing demo imagefills80×80. DS дополнили
DocumentIdentity(photo/no-photo), ChangeComparison и ProjectAssociationRow.
Visual inspection/preview/run пропущены по сохранённому запросу. Это статический
Figma target, без native input/media/SDK/OAuth/schema/backend/cloud evidence.
После приёмки R5 и поручения продолжить следующая полная фаза — R6 Web;
сейчас R6+ и R8 не начаты, основная разработка функций сохраняет freeze.

Новая URL route scheme и миграция adapter остаются предпосылкой R8.
Runtime/schema не изменены. Проверки и ограничения — в
[результатах R3.4](../redesign/plan.md#фактический-результат-r34-d032d033);
предыдущие цветовые правки и результаты R2 сохранены отдельно.
Точка остановки функционального roadmap —
после Phase 10, перед Phase 11 Media; Google/reset/iOS приёмка Phase 7 остаётся
открытой. Возврат к roadmap предлагается после пользовательской приёмки
REDESIGN_DONE и требует отдельного поручения. Новые model/migration/media/account/
publication/web возможности перечислены как [продуктовые пробелы](../redesign/audit.md#продуктовые-пробелы)
и [предпосылки R8](../redesign/plan.md#зависимости-реализации); их реализация сейчас
не разрешена. Последние требования Design v2 имеют приоритет над прежними макетами.

Phase 10 завершена. Предыдущее прямое поручение — Figma-first refactor:
audit, IA, design system и ключевые экраны по [redesign plan](../design/redesign-plan.md).
Первый этап Figma выполнен; core flows/states и перенос Flutter/web остаются
отдельными последующими шагами. История runtime-redesign выше сохраняется.
Открытые Google/reset/iOS проверки Phase 7 сохранены; Phase 11–20 остаются планом и
требуют отдельного поручения пользователя.

Чекбокс `- [x]` означает подтверждённый результат, `- [ ]` — оставшуюся задачу
или непроверенный сценарий. При отметке проверки рядом фиксируются результат
и ограничения среды. Фаза завершена только после приёмки обязательных сценариев.

<div align="center">

| **Фаза** | **Статус** |
|:---|:---|
| Phase 0 — Product foundation | Завершена; код, документы и нативный запуск на Android проверены |
| Phase 1 — UI foundation | Завершена; UI, темы, навигация и mock-сценарии проверены |
| Phase 2 — Basic state management | Завершена; три этапа темы, итоговый Provider и Riverpod state проверены |
| Phase 3 — Architecture | Завершена; Repository/DI, чистый domain, UI и Android-запуск проверены |
| Phase 4 — GitHub API | Завершена; HTTP, pagination, refresh, состояния и Android-запуск проверены |
| Phase 5 — Local persistence / offline | Завершена; settings, Hive cache/draft, offline/reconnect и Android restart проверены |
| Phase 6 — Portfolio domain и локальный Builder | Завершена; CRUD, validation/completion, preview, migration и Android offline restart проверены |
| Phase 7 — Firebase authentication | В работе; Android email flow проверен, Google/iOS приёмка открыта |
| Phase 8 — Firestore synchronization | Завершена; offline/reconnect, Android restart, LWW и Rules проверены |
| Phase 9 — Living Portfolio / Smart GitHub Sync | Завершена; импорт/review/ignore, overrides, совместимость draft и Android restart проверены |
| Phase 10 — Portfolio Suggestions | Завершена; pure rules, объяснения ru/en, явные Preview/editor actions и Android-запуск проверены |
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
- [Эскизы](../design/design-system.md#5-layout--composition) согласованы с реализованной
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

- [x] Выполнить обязательную для курса эволюцию одного простого сценария, например
  переключения темы: `setState → InheritedWidget → Provider`.
- [x] Сохранить сравнение подходов и этапов рефакторинга; в рабочем коде оставить
  одну итоговую реализацию сценария.
- [x] Ограничить Provider базовыми ThemeMode/Locale; ввести Riverpod для первого
  реального состояния продукта и обосновать выбор в документации.

**Проверки и приёмка**

- [x] Один сценарий продемонстрирован последовательно через setState,
  InheritedWidget и Provider; итоговое состояние обновляет нужные widgets.
- [x] Сравнение и обоснование Provider/Riverpod сохранены; в рабочем коде
  осталась одна итоговая реализация сценария.
- [x] Поведение состояния проверено; разработчик может объяснить различия
  подходов. Persistence не заявлена до Phase 5.

**Готово, когда:** базовое состояние доступно нужным widgets, обновляется
предсказуемо, а разработчик может объяснить различия трёх подходов. Сохранение
настроек между запусками добавляется на Phase 5.

**Реализовано и проверено в Phase 2**

- Один сценарий темы прошёл все три подхода. Итоговый AppearanceController
  принадлежит `ChangeNotifierProvider`; `Selector/select` обновляют MaterialApp
  и Settings, повторный выбор mode не вызывает уведомление. GoRouter сохраняет
  экземпляр и больше не передаёт theme callbacks. Locale вводится вместе с переводами.
- Query/filter state Projects вынесен в immutable Riverpod Notifier; производный
  provider фильтрует mock data. Выбор восстанавливается после удаления экрана
  из навигации; TextEditingController синхронизируется при внешнем изменении/reset.
- [Учебный guide](../learning/state-management.md) содержит сравнение, обоснование
  границ и два независимых patches. Каждый применён во временной копии приложения
  и прошёл пять UI tests. В `lib` осталась одна итоговая реализация темы.
- Format и `flutter analyze` прошли. Полный suite — **119 tests**, включая
  уведомления контроллера, поиск/сочетания фильтров, изоляцию sessions, system theme,
  навигацию и синхронизацию поля. **40 golden-сравнений** с PNG Phase 1 прошли
  без обновления снимков; палитра, компоновка и общие компоненты сохранены.
- Android debug APK собран и запущен на `main_phone` (Android 17 / API 37, arm64).
  UI hierarchy и снимки подтвердили сохранение light theme, query и фильтра
  при Android Back и повторном открытии Projects. Force-stop и новый запуск
  вернули dark theme, пустой query и фильтр «Все».
- `flutter doctor -v` подтверждает неполный Xcode и отсутствие CocoaPods;
  iOS не проверен. В Android SDK отсутствуют cmdline-tools и не подтверждены
  лицензии, хотя debug сборка и запуск прошли. Документы/ссылки и project context
  проверены; `git diff --check` чистый.
- Persistence, repository/data layers и network не добавлены: они относятся
  к следующим фазам. Commit/push не выполнялись; Phase 3 не начата.

### Phase 3 — Architecture

**Задачи**

- [x] Разделить существующие auth/profile/projects сценарии на features с
  `presentation/domain/data`, Repository pattern и Riverpod dependency injection.
- [x] Убрать бизнес-правила из widgets; domain не связывать с Flutter, Dio, Hive
  или Firebase. Mock-реализации пока остаются источником данных.
- [x] Ограничить слои текущими сценариями: отдельные UseCase/DataSource для
  демонстрационных источников не потребовались.
- [x] Завершить синхронизацию architecture и обоснования Provider/Riverpod
  с итоговой реализацией и результатами приёмки.

**Проверки и приёмка**

- [x] UI получает данные через Repository и Riverpod DI; смена mock-источника
  не требует переписывать widgets.
- [x] Domain не зависит от Flutter, Dio, Hive или Firebase; бизнес-правила
  вынесены из widgets, пустые слои не созданы.
- [x] Существующие сценарии и значимые tests проходят; architecture и
  обоснование state management согласованы с кодом; Android-сценарии подтверждены.

**Реализовано и проверено в Phase 3 — 3 октября 2026**

- Публичные API `auth.dart`, `profile.dart` и `projects.dart` объединяют
  используемые модели, Repository contracts и presentation/providers каждой
  feature. Domain содержит правила email, выбора проектов и демонстрационный
  снимок готовности профиля; data владеет mock-реализациями. Общий
  `shared/mock_portfolio.dart` удалён, widgets получают модели через DI.
- `AuthController` открывает демо через `AuthRepository`: pending блокирует
  форму, ошибка позволяет повторить действие, навигация выполняется после
  успеха. Email нормализуется в `DemoSession` внутри app session; постоянное
  хранение и настоящая авторизация появятся в соответствующих фазах.
- `ProfileRepository` и `ProjectsRepository` доступны через Riverpod
  FutureProvider. Home и Portfolio используют общий `PortfolioOverview`,
  Settings читает идентичность из того же profile state. Поиск/фильтры Projects
  остаются независимым Notifier; выбор featured не зависит от фильтра экрана.
  Loading/error/retry используют общий UI-компонент, ожидание повторного
  запроса заменяет прежнюю ошибку состоянием загрузки.
- Замена источников проверяется Repository/DI tests, включая форму входа,
  loading/error/retry, альтернативный профиль и проекты в Home, Portfolio
  и предпросмотре. Domain остаётся чистым Dart; новых зависимостей,
  network, persistence и сервисов будущих фаз не добавлено. Полный Portfolio
  domain, правила заполнения и локальный Builder остаются задачами Phase 6.
- `flutter pub get --offline` прошёл; manifest и lockfile не изменились.
  Итоговый format: 50 Dart-файлов, без изменений; `flutter analyze --no-pub` —
  без замечаний. Полный suite — **142 tests**, включая подмену Repository
  в реальных widgets, loading/error/empty/retry, pending повторной загрузки,
  навигацию и неизменяемость моделей. **40 golden-сравнений** с сохранёнными
  PNG прошли без обновления снимков; палитра и компоновка Phase 1 сохранены.
- Android debug APK собран и запущен на `main_phone` (arm64). UI hierarchy
  и снимки подтверждают demo-вход, загрузку Home/Projects, поиск `React`
  → один Readme Studio, Portfolio Preview с отметкой неопубликованного draft,
  единый профиль в Settings и переключение в light mode. Снимки просмотрены.
- `flutter doctor -v`: Xcode неполный, CocoaPods отсутствует; iOS не проверен.
  Android cmdline-tools и подтверждение лицензий по-прежнему отсутствуют,
  хотя debug сборка и запуск прошли. Domain imports проверены: зависимостей
  от Flutter/Riverpod/data/presentation нет. Widgets не импортируют concrete
  mock-источники. Architecture, ADR, AI scope и учебные материалы синхронизированы;
  документы/ссылки, project context и `git diff --check` проверены.
- Учебные patches темы адаптированы к новым source paths и DI. Оба варианта
  проверены отдельно во временных копиях; рабочий код сохранил Provider.
  Commit/push не выполнялись; Phase 4 не начата.

**Готово, когда:** UI получает данные через согласованные границы, источник можно
заменить без переписывания widgets, существующие сценарии продолжают работать.

### Phase 4 — GitHub API

**Задачи**

- [x] Реализовать отдельный GitHub Import: ввод username, публичный профиль и repositories
  через Dio, модели и JSON serialization.
- [x] Добавить pagination, timeout, retry, pull-to-refresh и поиск/filter с debounce,
  где он нужен сценарию. Проверить актуальные rate limits и поведение API перед кодом.
- [x] Показать loading/success/empty/error; отделить сетевой источник от UI и подготовить
  используемый контракт кэша. Протестировать parsing и обработку сетевых сбоев.

**Проверки и приёмка**

- [x] Публичный профиль и repositories загружаются; pagination, refresh
  и используемый поиск/filter с debounce работают.
- [x] Loading/success/empty/error, timeout и retry проверены; пустой профиль
  и сетевой сбой не ломают экран.
- [x] Parsing и обработка сбоев покрыты tests; rate limits и поведение API
  сверены с актуальной документацией. Импорт в portfolio ещё не выполняется.

**Реализовано и проверено в Phase 4 — 3 октября 2026**

- Из Projects открывается отдельный `/github-import`: username валидируется до
  запроса, публичный профиль и repositories загружаются через Dio. JSON DTO
  преобразуются в pure Dart domain models; widgets используют Repository через
  Riverpod DI. Новый экран сохраняет существующие tokens и shared components.
- Следующая страница берётся из GitHub `Link`; разрешены только проверенные
  GitHub API URL текущего пользователя. Повторяющиеся repositories удаляются по
  ID. Поиск с debounce и фильтры работают по загруженным страницам; UI показывает
  их число и явно объясняет эту границу. Есть refresh и pull-to-refresh.
- Ошибки timeout/network/not found/rate limit/invalid response преобразуются
  в типизированные состояния с понятным текстом и явным retry. Ошибка refresh
  или следующей страницы сохраняет уже загруженный список. Замена username
  и закрытие экрана отменяют запросы; устаревший ответ не меняет актуальное состояние.
- Используется контракт `GitHubResponseCache` и его реализация в памяти app session:
  JSON, ETag и Link поддерживают conditional requests и ответы 304. Repository
  сохраняет rate-limit deadline при повторном открытии экрана. Disk cache,
  offline fallback и импорт в portfolio остаются задачами последующих фаз.
  Версия API, pagination и rate limits сверены с официальной документацией;
  ссылки и HTTP/cache contract записаны в [architecture](../architecture/architecture.md#github-import-http-и-persistent-кэш).
- Добавлены 72 tests: 37 для DTO/HTTP/cache/errors, 17 для controller и 18 для
  widgets/DI/responsive. Полный `flutter test` прошёл: **214 tests**, включая
  **40 golden-сравнений**. После добавления входа в GitHub Import обновлены
  8 Projects preview; остальные 32 preview сохранены. `flutter analyze` — без
  замечаний, format — 70 Dart-файлов без изменений.
- Debug APK собран и установлен на Android-эмулятор. Реальный API загрузил
  профили `flutter` и `google`; локальный поиск, следующая страница и явный refresh
  проверены на устройстве. Две страницы `google` дали 59 уникальных repositories
  после удаления дубля по ID; финальная сборка успешно обновила первую страницу.
  Pull-to-refresh, пустые данные и ошибки дополнительно проверены widget tests.
- Учебные patches темы проверены отдельно: оба применяются и проходят по 5 tests.
  Документы, локальные ссылки, project context и diff проверены. Android debug
  работает; doctor по-прежнему отмечает отсутствие cmdline-tools и неизвестный
  статус licenses. iOS-запуск не проверен: Xcode и CocoaPods не готовы.
  На момент приёмки Phase 4 следующий этап Phase 5 ещё не выполнялся.

**Готово, когда:** repositories загружаются и листаются, ошибку можно повторить,
пустой профиль не ломает экран. Импорт в портфолио и Firebase ещё не выполняется.

### Phase 5 — Local persistence / offline

**Задачи**

- [x] Сохранять theme, locale и простые настройки в SharedPreferences.
- [x] Использовать Hive для GitHub cache и local portfolio draft; альтернативу
  обосновать в ADR до реализации.
- [x] Определить cache lifetime, хранение несинхронизированных изменений и версию
  локальной модели; показывать доступные сохранённые данные без сети.
- [x] Проверить перезапуск, отсутствие сети, пустой/повреждённый кэш и восстановление
  соединения без потери draft.

**Проверки и приёмка**

- [x] Theme, locale и простые настройки сохраняются после перезапуска.
- [x] Ранее загруженные repositories и local draft доступны без сети;
  несинхронизированные изменения не теряются.
- [x] Пустой/повреждённый кэш и reconnect проверены; cache lifetime,
  версия модели и решение о локальном хранилище зафиксированы.

**Реализовано и проверено в Phase 5 — 3 октября 2026**

- `StackCardBootstrap` восстанавливает настройки и открывает отдельные Hive boxes
  в Application Support до первого экрана. SharedPreferencesAsync хранит цельный
  snapshot v1: dark/light/system, ru/en и показ описаний GitHub cards. UI имеет
  реальные переводы; source/user content сохраняет исходный язык. Ошибка записи
  оставляет выбор в session с явным retry, повреждённые preferences дают defaults.
- GitHub cache использует envelope v1 с JSON body, ETag, Link и UTC validatedAt.
  Network-first GET/304 обновляет дату; hard TTL — **7 дней**. Только network,
  timeout и server failures допускают сохранённую копию. UI показывает её источник
  и дату, storage failures не скрывают успешный HTTP. Expired/corrupt/unknown cache
  исключается из fallback; отмена проверяется после storage awaits.
- Из Portfolio открываются локальные заметки: явный Save сохраняет notes,
  revision, UTC updatedAt и pendingSync в draft envelope v1. Это предварительный
  notes draft; полный portfolio domain и Builder остаются Phase 6. Несохранённый
  ввод живёт в session; ошибка Save его не теряет и не выдаёт результат за saved.
  Remote sync пока отсутствует.
- Cache recovery/очистка не затрагивают draft. Повреждённый cache file сохраняется
  как backup и пересоздаётся; повреждённый draft или неизвестная schema сохраняются
  с блокировкой перезаписи. Реальные Hive tests проверяют reopen и файлы, включая
  закрытие draft при ошибке закрытия cache. Первая persistent версия не требует
  миграции старой модели; решения записаны в [ADR](../decisions/README.md#принято-для-phase-5).
- Добавлены **109 tests** для persistence, localization, draft и bootstrap.
  Полный `flutter test --no-pub --dart-define=UPDATE_UI_PREVIEWS=true` прошёл:
  **323 tests**, включая **40 golden-сравнений**. Обновлены 16 Portfolio/Settings
  previews для новых controls; остальные 24 сохранены. Проверены responsive,
  увеличенный текст, контраст и tap targets. Format — 98 Dart-файлов без изменений;
  `flutter analyze --no-pub` — без замечаний.
- Финальный debug APK собран и установлен на `main_phone` (Android 17/API 37).
  Force-stop/relaunch восстановил Light, English и выключенные source descriptions.
  После запрета сети только тестовому приложению профиль `google` и **30 ранее
  загруженных repositories** доступны с cached-copy notice/date; username без
  cache показывает «No connection» с retry. Notes доступны offline, новая правка
  увеличила revision до 2. Возврат сети и явный refresh убрали cache notice;
  повторный cold start сохранил правку, revision 2 и pendingSync. Native UI и
  снимки просмотрены; сетевые настройки эмулятора восстановлены.
- Оба учебных theme patches применяются независимо к свежим копиям проекта;
  каждый прошёл 5 widget и 9 localization/settings tests и targeted analyze.
  Bootstrap, Hive и feature DI сохранены. Architecture, ADR, design, mobile guide
  и AI context синхронизированы; документы/ссылки и project context проверены.
- `flutter doctor -v` по-прежнему отмечает отсутствие Android cmdline-tools и
  неизвестный статус licenses при успешной debug сборке. iOS не проверен:
  Xcode неполный, CocoaPods отсутствует. Commit/push не выполнялись;
  На момент приёмки Phase 5 следующий этап Phase 6 ещё не выполнялся.

**Готово, когда:** настройки переживают перезапуск, ранее загруженные repositories
доступны offline, локальные изменения сохраняются. Remote sync появится на Phase 8.

### Phase 6 — Portfolio domain и локальный Builder

**Задачи**

- [x] Ввести Profile, Skill, Project, Experience, Education, SocialLink, PortfolioBlock
  и PortfolioTheme по реальным формам, без окончательной Firestore schema заранее.
- [x] Реализовать ручные проекты и редактирование профиля, skills, links, experience,
  education и содержимого Resume; формат resume определить перед реализацией.
- [x] Добавить add/edit/delete, featured, block reorder, show/hide, validation и preview.
  Сохранять изменения в локальный draft.
- [x] Рассчитать portfolio completion и покрыть правила/validation unit tests,
  основной сценарий editor — widget tests.

**Проверки и приёмка**

- [x] Ручные проекты и данные профиля можно добавить, изменить и удалить;
  featured, порядок и видимость блоков отражаются в preview.
- [x] Draft сохраняется, открывается после перезапуска и просматривается offline.
- [x] Validation и completion покрыты unit tests, основной путь editor —
  widget tests; формат Resume определён. Public publication ещё не доступна.

**Готово, когда:** портфолио можно собрать, сохранить, открыть после перезапуска
и просмотреть offline. Публичной публикации пока нет.

**Реализовано и проверено в Phase 6 — 3 октября 2026**

- Pure Dart `PortfolioContent` объединяет профиль, skills, ручные projects,
  experience, education, links, Resume, десять ordered/visible блоков и PortfolioTheme.
  Коллекции immutable, сущности имеют стабильные IDs и structural equality.
  Demo Profile/Project остались моделями чтения; mock/GitHub данные не копируются в draft.
- Семь редакторов используют общие components, ru/en validation и Apply/Cancel.
  Apply изменяет только свою секцию актуального рабочего content; Cancel не меняет
  draft. Списки поддерживают CRUD; проект — featured и visibility. Resume выбран
  plain text с переносами строк и лимитом 20 000 символов, без файлов/upload.
- Preview читает рабочий draft; порядок, visibility и dark/light оформление
  применяются сразу. Private notes отделены от рендеримого типа. Home, Portfolio,
  Projects, Settings и shell показывают тот же content; скрытые проекты остаются
  доступны владельцу на Projects, но исключаются из featured/preview.
- Completion вычисляется из пяти шагов: профиль, About, skills, хотя бы один
  видимый проект, links. Опциональные секции не блокируют 100%; скрытие блока
  не увеличивает процент. Незавершённый draft можно сохранить, неверные значения — нельзя.
- Hive schema v2 сохраняет nullable content отдельно от notes/metadata. V1 читается
  без записи; первый явный Save оставляет raw backup перед заменой. Notes patch
  сохраняет content; expectedRevision предотвращает устаревшую запись. Corrupt/unknown
  draft не перезаписывается. Read gate объединяет cold reads и допускает demo
  только после успешного чтения; ошибки имеют явный retry.
- Save захватывает content/notes/revision, обновляет durable snapshot после успеха
  и сохраняет более новый рабочий ввод. Duplicate Save блокируется; failure не
  удаляет правки. Reload требует подтверждения сброса unsaved content и notes.
- `dart format lib test`: 131 файл; `flutter analyze`: без замечаний.
  Полный `flutter test --dart-define=UPDATE_UI_PREVIEWS=true`: **530 tests passed**,
  включая миграцию, конфликты/races, CRUD, validation/completion, чтение/DI, privacy,
  keyboard, ru/en и responsive. Сравнение **56 PNG эталонов** прошло: 40 основных
  и 16 Builder; 16 Portfolio/Projects обновлены из-за новых входов в редактор.
  Контраст AA и 48px targets новых экранов проверены стандартными guidelines
  для всей высоты содержимого; реальная прокрутка и 320px/text2.0 проверены отдельно.
- Оба учебных patch независимо применены к свежим копиям финального source:
  `git apply --check`, `flutter analyze lib` и по **14/14** widget/localization tests.
- Финальный Android debug APK собран и установлен на `main_phone`, Android 17/API37,
  arm64. Через native UI заполнены профиль/About и ручной featured-проект;
  Save увеличил revision 2→3→4, completion 0→40→60%. После force-stop и нового
  запуска с Wi-Fi/mobile data отключёнными Home и preview восстановили имя,
  описание, технологии и проект. Исходное состояние сети восстановлено.
  [Builder](../design/previews/portfolio_builder_android_phone.png) и
  [offline preview](../design/previews/portfolio_preview_android_phone.png) просмотрены.
- Flutter doctor подтверждает неполный Xcode и отсутствие CocoaPods: iOS-запуск
  не выполнен. Android cmdline-tools отсутствуют, статус лицензий неизвестен;
  debug build/run при этом успешны. Физические phone/tablet не проверены;
  tablet/landscape покрыты Flutter rendering. Dependencies не добавлены.
  Документы/ссылки и diff проверены; commit/push не выполнялись. Phase 7 не начата.

### Phase 7 — Firebase authentication

**Задачи**

- [x] Подключить Firebase configuration для Android/iOS; описать generation,
  dev environment и необязательный Auth Emulator в CONTRIBUTING.
- [ ] Завершить email/password и Google sign-in, регистрацию, восстановление пароля,
  auth state и sign out: реализация готова; Google provider/OAuth configuration
  и native Google приёмка остаются открытыми.
- [x] Добавить именованные routes, параметры, вложенную навигацию и auth redirects
  в GoRouter; unit/widget проверки transitions и session restore проходят.
- [x] Привязать local draft к Firebase UID; реализовать явный guest transfer
  и изоляцию данных при смене аккаунта.

**Проверки и приёмка**

- [ ] Все обязательные auth сценарии проверены на native targets. Android live
  registration/email sign-in/sign out и reset API acceptance подтверждены;
  Google flow, фактическое письмо/reset пароля и iOS ещё не приняты.
- [x] Auth redirects, именованные routes, параметры и вложенная навигация
  проверены для owner/guest/restoring/error/signedOut в Flutter tests.
- [x] Гостевой draft переносится явно только в пустой target; sign out, UID switch,
  late save, сбой transfer/reopen и private form state проверены без чужих данных.

**Реализовано и проверено в Phase 7 — 4 октября 2026**

- Firebase CLI доступен, Google login выполнен; FlutterFire CLI и Ruby `xcodeproj`
  установлены для generation. Создан отдельный development project;
  canonical project/app IDs находятся в [Firebase options](../../apps/mobile/lib/firebase_options.dart)
  и [native configuration](../../apps/mobile/firebase.json). Android/iOS apps
  зарегистрированы с существующими package/bundle IDs, debug SHA-1 добавлен.
  Billing upgrade, Firestore, deploy и публикация не выполнялись.
- Email/Password включён в Firebase Console. Google provider требует support
  email, видимого на OAuth-экране: ждём подтверждения адреса пользователя перед
  сохранением. После включения требуется regeneration native configs, iOS client
  ID/URL scheme и отдельная live Google проверка.
- Pure Dart account repository/user/failures, Firebase adapter и Riverpod session
  отделены от legacy demo preview. Password/token не сохраняются приложением.
  SDK restoring/error блокируют private routes и repository; ошибка не открывает
  guest/старый UID fallback. Sign out подтверждает отбрасывание unsaved changes.
- GoRouter использует именованные routes, безопасный локальный `from`, auth forms,
  вложенные Builder routes и project parameters. UID/access boundary очищает
  controller/projections, filters, editor/dialog state. Profile loading/error
  не показывает cached initials предыдущего пользователя.
- Hive сохраняет старый guest namespace и отдельные UID namespaces. Явный transfer
  сохраняет envelope/revision/legacy backup; durable owner journal и generation
  защищают retry/reopen и запрещают старому guest adapter воскресить draft.
  Чужой UID не получает retry reserved transfer. Новые working edits во время
  transfer сохраняются; при отсутствии новых правок controller перечитывает target.
- Native Android [acceptance test](../../apps/mobile/integration_test/account_runtime_test.dart)
  прошёл на `emulator-5554`: создание disposable аккаунта → sign out → отказ при
  неверном пароле → email sign-in с тем же UID → reset API → sign out → удаление
  только созданного тестового аккаунта. Reset подтверждает SDK/backend acceptance;
  адрес `example.invalid` исключает доставку письма и не доказывает реальный reset.
- Итоговый format check прошёл, `flutter analyze` без замечаний,
  `flutter test` — **621 tests passed**, включая прежние visual checks и новые
  auth/navigation/UID/transfer/recovery regressions. Docs links и diff проверены.
  Native SDK session restore между процессами прошёл: `seed` создаёт account,
  `check` после перезапуска восстанавливает тестового пользователя до любого
  sign-in и удаляет account. Seed даёт SDK время на асинхронную persistence
  перед принудительной остановкой test runner; runtime persistence не изменялась.
  Native lifecycle/bootstrap suite — **2 passed, 1 skipped** (restore запускается
  отдельной парой): реальная account форма и явный guest переход в app shell
  подтверждены. Screenshot Android auth формы сохранён отдельно от suite.
- Первый native runner без `--no-uninstall` удалил приложение эмулятора после
  проверки. Прежние draft/cache/settings восстановлены из существующего
  `default_boot` snapshot; отдельная локальная копия сохранена перед повтором.
  Повторные запуски используют `--no-uninstall`; контрольная сумма draft после
  тестов совпала. Команды исправлены в CONTRIBUTING.
- Android debug APK собран; обычный `main.dart` снова запущен после native tests.
  Контрольная сумма восстановленного draft после запуска совпала.
  iOS config сгенерирован, но сборка/запуск недоступны:
  Xcode установлен неполностью, CocoaPods отсутствует. Doctor также отмечает
  отсутствие Android cmdline-tools и неизвестный статус лицензий; Android
  debug build и native auth test при этом прошли. Commit/push не выполнялись.

**Готово, когда:** оба способа входа работают, защищённые экраны доступны владельцу,
sign out и смена пользователя не раскрывают чужой локальный draft. Phase 7 остаётся
в работе до приёмки открытых native auth сценариев. По отдельному поручению
пользователя завершена Phase 8; незавершённые проверки Phase 7 сохранены.

### Phase 8 — Firestore synchronization

**Задачи**

- [x] До remote writes спроектировать private account/draft, public snapshot,
  username uniqueness и проверяемую атомарность publish/unpublish. Зафиксирован
  [ADR 0001](../decisions/0001-firestore-sync-and-publication.md) до remote writes.
- [x] Ввести remote repository поверх local cache; выбрать conflict strategy для
  нескольких устройств и будущего web-клиента, описать последствия.
- [x] Реализовать `pending/synced/error`, повтор синхронизации и обработку потери сети.
- [x] Создать Firestore Rules и проверки owner access, отказа чужому пользователю
  и анонимного доступа только к опубликованным данным.

**Проверки и приёмка**

- [x] Offline-правки синхронизируются после reconnect; pending/synced/error
  и повтор после сбоя отражают фактическое состояние.
- [x] Конфликт нескольких клиентов обработан по выбранной стратегии;
  private/public schema, username uniqueness и атомарность публикации описаны в ADR.
- [x] Firestore Rules tests подтверждают owner access, отказ чужому пользователю
  и анонимное чтение только published данных; private draft остаётся private.

**Готово, когда:** offline-правки доходят до облака после восстановления сети,
конфликт обрабатывается по выбранной стратегии, private данные остаются private.
Механизм явной публикации подготовлен; public web появится на Phase 13.

**Результат проверки (2026-10-04): Phase 8 завершена.**

- Dev-база `(default)` проекта `stackcard-dev-snownumb` создана в согласованном
  `europe-west3`; CLI подтвердил `freeTier: true`. Rules и indexes успешно
  развёрнуты; billing upgrade не выполнялся.
- Account draft синхронизируется поверх Hive с durable outbox, server ACK,
  восстановлением очереди и состояниями `pending/synced/error/retry` в Builder
  и private notes. Whole-draft LWW определяется порядком server commits;
  локальные revisions разных устройств не сравниваются. Несохранённый ввод
  сохраняется при remote update; повторный Save явно отправляет свою версию.
- Guest transfer проверяет облачный destination и атомарно занимает только
  пустой draft. Occupied account сохраняет свой draft и исходный guest;
  owner journal, потерянный ACK и незавершённый Phase 7 transfer восстанавливаются
  без переноса чужому UID и без блокировки shared Hive queue.
- `flutter analyze` — **No issues found**; `flutter test` — **688 tests passed**;
  format check — **165 files, 0 changed**. Проверены adapter/schema/public
  projection, outbox/retry/ACK, UID lifecycle, transfer recovery и UI states.
- `npm run test:rules` — **24 passed, 0 failed**. Emulator tests подтверждают
  owner access, отказ foreign/anonymous к private draft, anonymous `get` только
  published snapshot, запрет listing, username uniqueness и атомарность
  publish/rename/unpublish. Publication repository подготовлен; public UI ещё
  не вводится. Hidden fields и private notes не входят в public projection.
- Android native lifecycle suite — **1 passed, 1 skipped**: настоящий SDK
  проверил offline Save, Hive reopen, reconnect/server ACK, LWW двух клиентов,
  foreign/anonymous denial и cloud-aware guest transfer. Отдельные процессы
  `seed` и `check` — **по 1 passed, 1 skipped**: SDK восстановил account до sign-in,
  Hive сохранил pending outbox, новая session отправила его после reconnect.
  Skipped test в каждом запуске относится к другому режиму этой же suite.
  Тестовые accounts/drafts и изолированное restore-хранилище удалены.
- Обычный `main.dart` собран и запущен на `emulator-5554` после native tests.
  Native tests использовали `--no-uninstall`; checksum исходного guest draft совпал.
  Docs links и diff проверены; Markdown render отдельно не проверялся.
  iOS native sync не проверен из-за незавершённого Xcode/CocoaPods toolchain;
  Google/reset/iOS приёмка Phase 7 остаётся открытой. Commit/push не выполнялись.

По отдельному следующему поручению завершена Phase 9; дальнейшие этапы требуют
отдельного поручения пользователя.

### Phase 9 — Living Portfolio / Smart GitHub Sync

**Задачи**

- [x] Добавить импорт repository → Project с `source = manual | github`,
  `githubRepositoryId`, `lastGitHubSyncAt` и sync status.
- [x] Разделить source metadata и пользовательские overrides; повторный импорт
  одного repository не должен создавать дубликаты.
- [x] Обнаруживать новые/изменённые repositories и показывать Ignore, Preview,
  Add to portfolio и Review changes.
- [x] Проверить повторную синхронизацию, сохранение ручных правок и отсутствие
  автоматического изменения published snapshot.

**Проверки и приёмка**

- [x] Выбранный repository импортируется в Project; повторный импорт
  не создаёт дубликат, source metadata и overrides сохраняются раздельно.
- [x] Новые и изменённые repositories предлагают Ignore, Preview,
  Add to portfolio и Review changes; владелец выбирает действие.
- [x] Повторный sync сохраняет ручные правки и не меняет published snapshot
  без явной публикации; сценарии проверены.

**Готово, когда:** владелец импортирует и принимает выбранные изменения,
а обновление GitHub не перезаписывает curated данные и публичную версию молча.

**Текущий результат (2026-10-04):** Phase 9 завершена. Контракт импорта и review
зафиксирован в [ADR 0002](../decisions/0002-github-import-and-review.md).

- Добавлены явные Add, Preview, Ignore и Review changes. GitHub source и ручные
  overrides хранятся раздельно; повторный импорт и rename repository используют
  стабильный GitHub ID и не создают дубликат. Accept обновляет только поля без
  ручного override; live URL, featured и visibility остаются под контролем владельца.
  Source refresh не меняет draft; выбранные изменения требуют отдельного Save.
- Ignore сохраняет fingerprint конкретной версии source в private draft;
  следующая версия снова предлагает review. `lastGitHubSyncAt` использует дату
  проверки конкретного repository, включая pagination/cache; неизвестная дата
  остаётся `null`. Изменения статистики и активности тоже видны в review.
- Hive пишет envelope v3 и читает v1/v2/v3; Firestore пишет private schema 2
  и читает 1/2. Legacy проекты остаются manual, новые поля не требуют eager
  rewrite. Public projection исключает source metadata, overrides и ignore;
  импорт/review не вызывает publication repository и не меняет published snapshot.
- `dart format --output=none --set-exit-if-changed lib test integration_test` —
  **174 files, 0 changed**; `flutter analyze` — **No issues found**;
  `flutter test` — **772 passed**. Проверены domain/codec, legacy migration,
  controller/UID guards, provenance отдельных repositories, public boundary и UI.
  Stale review/editor и некорректный source не перезаписывают свежий draft.
- `npm run test:rules` — **27 passed, 0 failed**. Проверены owner isolation,
  schema 2 и запрет downgrade, public projection и publication transactions.
  Firestore Rules и indexes успешно развёрнуты в существующий dev-проект
  `stackcard-dev-snownumb`; регион `(default)` остаётся `europe-west3`.
- Android native lifecycle suite — **1 passed, 1 skipped**: offline Save,
  Hive reopen, cloud ACK и повторный GitHub review сохраняют source metadata
  и ручные правки; LWW и private access проверены настоящим SDK.
  Отдельные процессы `seed` и `check` — **по 1 passed, 1 skipped**: pending
  GitHub draft пережил завершение процесса и синхронизировался после reconnect.
  Skipped test относится к другому режиму той же suite; тестовые accounts/drafts
  и изолированное restore-хранилище удалены.
- Карточки и review визуально проверены в light/dark при 390×844; обычный
  `main.dart` собран и запущен на `emulator-5554`. Native tests использовали
  `--no-uninstall`; checksum исходного guest draft совпал после проверок.
  Docs links и diff проверены; Markdown render отдельно не проверялся.
  iOS native sync не проверен из-за незавершённого Xcode/CocoaPods toolchain;
  Google/reset/iOS приёмка Phase 7 остаётся открытой. Commit/push не выполнялись.

По следующему отдельному поручению начата Phase 10; дальнейшие этапы требуют
отдельного поручения пользователя.

### Phase 10 — Portfolio Suggestions

**Задачи**

- [x] Реализовать deterministic rules: новый repository, активность, отсутствующие
  description/preview и кандидаты для featured.
- [x] Если нужен внутренний ProjectScore, определить факторы и пороги в одном месте;
  UI показывает причину и полезное действие.
- [x] Проверить правила unit tests независимо от UI и внешних сервисов.

**Проверки и приёмка**

- [x] Одинаковые входные данные дают одинаковые suggestions;
  новый repository, активность и отсутствие description/preview проверены.
- [x] Каждая suggestion объясняет причину и предлагает действие владельцу;
  факторы и пороги ProjectScore определены в одном месте, если он используется.
- [x] Unit tests правил проходят без UI и внешних сервисов; AI и
  автоматическая публикация не введены.

**Готово, когда:** одинаковые входные данные дают объяснимые suggestions,
владелец выбирает действие; AI и автоматическая публикация не используются.

**Текущий результат (2026-10-04):** Phase 10 завершена. Pure rules и причины
описаны в [architecture](../architecture/architecture.md#portfolio-suggestions).

- `buildPortfolioSuggestions` принимает content, source snapshots и явное время;
  возвращает immutable рекомендации со stable IDs и порядком. Реализованы новый
  repository, недавнее известное обновление, длительный простой, отсутствующие
  description/demo и candidate для featured. Hidden проекты исключены, повторные
  sources объединяются по ID; Ignore конкретной версии учитывается, ручные
  overrides не меняются. Projects использует accepted source offline, GitHub cards —
  загруженный snapshot конкретного repository.
- `PortfolioSuggestionThresholds` хранит пороги в одном месте: recent ≤30 дней,
  inactive ≥180 дней, featured ≥5 stars либо recent при заполненных curated полях;
  future date не считается recent. Manual candidate требует description,
  technologies и demo. UI объясняет фактическое условие и предлагает действие;
  `ProjectScore` не понадобился. Preview означает demo link (`liveUrl`),
  изображения и screenshots остаются Phase 11.
- Projects и source cards показывают причины ru/en и открывают прежний
  Preview/project editor. Нет автоматических Add/Accept, изменения featured,
  Save или публикации. Provider не читает private draft без account/explicit guest,
  не показывает demo advice при отсутствии content и сбрасывает рекомендации
  прежнего UID. Новых зависимостей, storage schema или Firebase конфигурации не вводилось.
- `dart format --output=none --set-exit-if-changed lib test integration_test` —
  **180 files, 0 changed**; `flutter analyze` — **No issues found**;
  `flutter test` — **822 passed**. Включены **33 pure rules**, **5 provider**
  и **12 widget** tests: границы времени, future dates, dedup/order, ignored
  versions, manual/legacy, hidden/featured/forks/archived, overrides и отсутствие
  мутаций; working edits, UID/private read guards, editor/Preview actions,
  loading/failure, ru/en и responsive при увеличенном тексте.
- Synthetic Projects/source screenshots при 390×844 просмотрены в light/dark;
  overflow не обнаружен, оригинальные assets и прежние goldens сохранены.
  Обычный `main.dart` собран и запущен на `emulator-5554`, процесс работает;
  checksum исходного guest draft совпал. Docs links и diff проверены;
  Markdown render отдельно не проверялся. iOS native запуск не проверен при
  незавершённом Xcode/CocoaPods toolchain; Google/reset/iOS приёмка Phase 7
  остаётся открытой. Commit/push не выполнялись.

Phase 11 и последующие этапы требуют отдельного поручения пользователя.

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

**Phase 0–6 и Phase 8–10 завершены. Google/reset/iOS приёмка Phase 7 остаётся открытой. Phase 11 и последующие этапы требуют отдельного поручения.**

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
