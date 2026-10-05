<div align="center">

# StackCard Design v2 — экраны

**Карта текущих маршрутов, целевых переходов и обязательных состояний**

![Scope screen map](https://raster.shields.io/badge/Scope-screen_map-C7FF1A?style=for-the-badge)

</div>

---

## Содержание

- [Как читать карту](#как-читать-карту)
- [Текущие маршруты](#текущие-маршруты)
- [Целевые экраны](#целевые-экраны)
- [R1.1 — Информационная архитектура](#r11--информационная-архитектура)
- [R1.2 — Low-fi основных сценариев](#r12--low-fi-основных-сценариев)
- [R1.3 — Low-fi Resume wizard и редактора](#r13--low-fi-resume-wizard-и-редактора)
- [R1.4 — Low-fi Projects, Portfolio и публикации](#r14--low-fi-projects-portfolio-и-публикации)
- [Цветовые правки low-fi](#цветовые-правки-low-fi)
- [R2.1 — Два визуальных направления](#r21--два-визуальных-направления)
- [R2.2 — Знак, написание и иконка приложения](#r22--знак-написание-и-иконка-приложения)
- [R2.3 — Принятый бренд и направление](#r23--принятый-бренд-и-направление)
- [R3.1 — Цвета, типографика и метрики](#r31--цвета-типографика-и-метрики)
- [R3.2 — Навигация, карточки и TechnologyBadge](#r32--навигация-карточки-и-technologybadge)
- [R3.3 — Формы, stepper, фото и секции](#r33--формы-stepper-фото-и-секции)
- [R3.4 — Состояния, motion и адаптивность](#r34--состояния-motion-и-адаптивность)
- [R4 — Основные экраны и настройки](#r4--основные-экраны-и-настройки)
- [R5 — Создание, редактирование и публикация](#r5--создание-редактирование-и-публикация)
- [Переходы и действия](#переходы-и-действия)
- [Состояния и компоненты](#состояния-и-компоненты)
- [Реестр Figma](#реестр-figma)

---

## Как читать карту

Срез R0 — 2026-10-05, статический аудит; далее добавлены результаты R1.1–R1.4
и шесть визуальных пилотов R2.1, brand specimens R2.2, выбор A в R2.3
и Dark/Light foundations R3.1, components R3.2–R3.4, state/motion/adapt specimens,
R4 roots/settings и согласованный пакет R5 editors/wizard/publication.
`S-*` — ID целевого экрана, а не реализованный route. Новые route paths и
runtime screen IDs не назначены; созданные IA и low-fi frames перечислены отдельно. Конкретные
paths согласуются вместе с guards/deep links перед переносом. Существующие пути
ниже проверены по [app_router.dart](../../apps/mobile/lib/app/app_router.dart).

Карта R0 задаёт требования к будущим сценариям. Low-fi создаётся в R1,
визуальный макет — в R4–R6, интерактивность — в R7, реализация — в R8.

---

## Текущие маршруты

| **Существующий route** | **Файл и поведение** |
|:---|:---|
| `/`, `/home` | Redirect и [Home](../../apps/mobile/lib/features/home/home_screen.dart), прежний dashboard |
| `/portfolio` | [PortfolioScreen](../../apps/mobile/lib/features/portfolio/presentation/portfolio_screen.dart), единственный preview |
| `/projects` | [ProjectsScreen](../../apps/mobile/lib/features/projects/presentation/projects_screen.dart), проекция draft |
| `/settings` | [Settings](../../apps/mobile/lib/features/settings/settings_screen.dart), root старого ShellRoute |
| `/sign-in`, `/register`, `/reset-password` | [SignInScreen](../../apps/mobile/lib/features/auth/presentation/sign_in_screen.dart), режимы auth |
| `/github-import` | [GitHubImportScreen](../../apps/mobile/lib/features/github_import/presentation/github_import_screen.dart), публичное чтение, guarded import |
| `/portfolio-draft` | [PortfolioDraftScreen](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_draft_screen.dart), приватные notes |
| `/portfolio/builder` | [PortfolioBuilderScreen](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_builder_screen.dart), один content |
| `/portfolio/builder/profile` | [Profile editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_profile_editor_screen.dart) |
| `/portfolio/builder/skills` | [Skills editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_skills_editor_screen.dart) |
| `/portfolio/builder/experience` | [Experience editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_experience_editor_screen.dart) |
| `/portfolio/builder/education` | [Education editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_education_editor_screen.dart) |
| `/portfolio/builder/links` | [Links editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_links_editor_screen.dart) |
| `/portfolio/builder/resume` | [Resume editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_resume_editor_screen.dart), одна строка resumeText |
| `/projects/new`, `/projects/:id/edit` | [Project editor](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_project_editor_screen.dart) |
| `/portfolio/preview` | [PortfolioPreviewScreen](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_preview_screen.dart), working preview |

В `apps/web` только [README](../../apps/web/README.md). `/u/[username]` описан там
как план; существующего web-route, Resume-root или публичного viewer нет.

---

## Целевые экраны

R4.1–R4.7c разрешены единым пакетом D034: hi-fi основных мобильных экранов
и настроек подготовлены на `StackCard Design v2 / Screens`. Редакторы R5 и web R6
остаются `todo`; runtime перенос выполняется только в R8. Реальные low-fi
R1.2–R1.4 находятся на `/ UX` и перечислены ниже.

| **ID и экран** | **Контракт, requirements, компоненты и задача** |
|:---|:---|
| S-HOME — Главная | Компактный header+gear, Все/Резюме/Проекты, смешанная библиотека по изменению; REQ-HOME-01..03; HomeFilter, EntityCard, CopyLink; R4.1 |
| S-RESUMES — Резюме | Header+gear, создать, список role/preview/date/status; REQ-RESUME-01; ResumeCard; R4.2 |
| S-PROJECTS — Проекты | Header+gear → горизонтальный ряд импорт/создать → поиск с лупой без заголовка → список; REQ-PROJECT-01..04; ProjectCard, TechnologyBadge; R4.3 |
| S-PORTFOLIOS — Портфолио | Список Portfolio, create/open/edit/duplicate/publish/unpublish/share; REQ-PORTFOLIO-01; PortfolioCard; R4.4 |
| S-SETTINGS — Настройки | Отдельный вложенный экран, группы профиль/контакты/аккаунт/приложение/приватность/выход; REQ-NAV-05, REQ-SETTINGS-01; SettingsRow; R4.5, R4.6, R4.7a..c |
| S-PROFILE — Базовый профиль | Фото, имя, ник, заголовок, bio, location, skills/experience/education; REQ-SETTINGS-01,04; PhotoField, SectionEditor; R4.5 |
| S-CONTACTS — Контакты и ссылки | Публичная почта, optional phone, соцссылки и label+URL, CRUD/reorder; REQ-SETTINGS-02,03; LinkRow; R4.6 |
| S-ACCOUNT — Аккаунт | Login email отдельно; действительно поддерживаемые providers, reauth, change/confirm email, password, deletion; REQ-SETTINGS-03,04; ProviderRow; R4.7a |
| S-PRIVACY — Приватность | Выбор открытых контактов/location и обращений; REQ-SETTINGS-01; VisibilityControl; R4.7b |
| S-APP — Приложение | Dark/light/system, ru/en, notifications, reduced motion; REQ-SETTINGS-01; OptionRow; R4.7c |
| S-RESUME-WIZARD — Создать Resume | Пять этапов и Шаг N из 5; необязательные части пропускаются, Back сохраняет ввод; REQ-RESUME-02..04; Stepper, PhotoField, Selectors; R5.1a,b |
| S-RESUME-EDITOR — Изменить Resume | Прямой вход в секцию, selected data/visibility/local overrides; REQ-RESUME-04, REQ-EDITOR-01..03; SectionRow; R5.1c,d |
| S-PROJECT-EDITOR — Project | Ручной Project в общей library; media placeholder, описание/технологии/ссылки; REQ-PROJECT-03,04; ProjectForm; R5.2a |
| S-GITHUB — Import | Выбор repositories, already imported, search/pagination/cache/retry; REQ-PROJECT-04; RepositoryRow; R5.2b |
| S-GITHUB-REVIEW — Изменения source | Сравнить новые сведения и curated fields, Accept/Ignore/Cancel; REQ-PROJECT-04; ChangeRow; R5.2c |
| S-PORTFOLIO-EDITOR — Portfolio | Секции отдельно от appearance; выбрать/создать Project+attach, order/featured/remove relation; REQ-PORTFOLIO-03, REQ-EDITOR-01..03; Selectors, ReorderControls; R5.3a..c |
| S-PREVIEW — Просмотр черновика | Resume документный, Portfolio showcase; выбранное фото, весь tech набор, без private notes; REQ-RESUME-03, REQ-PORTFOLIO-02; DocumentRenderer; R5.1d, R5.3c |
| S-PUBLISH — Публикация | Explicit действие отдельно от Save/sync, summary доступных публичных полей и ошибок; REQ-EDITOR-03, REQ-SHARE-01; PublicationStatus; R5.4a |
| S-SHARE — Ссылка | Повторное Copy/Open/Share у опубликованного, после unpublish ссылка недоступна; REQ-SHARE-01; CopyLinkButton, Toast; R5.4b,c |
| S-WEB-LANDING — Сайт | Общая база → разные outputs, реальное product preview, Projects/GitHub/Resume/Portfolio/links/app; CTA без фиктивных цифр; R6.1 |
| S-WEB-AUTH — Web auth | Sign-in/register/reset/session error, return to guarded destination; R6.2 |
| S-WEB-DOWNLOAD — Download | Android/iOS способы установки только когда доступны; честный unavailable-state; R6.2 |
| S-WEB-WORKSPACE — Кабинет | Общие owner data и явный Publish; wide settings+preview, narrow раздельные режимы; R6.3 |
| S-PUBLIC-RESUME — Публичное Resume | Без входа, читабельный документ, public selections/photo, нет private controls; R6.4 |
| S-PUBLIC-PORTFOLIO — Публичное Portfolio | Человек и работы, выбранное Resume, ссылки/контакты, без private data; R6.4 |

У S-SETTINGS и его дочерних экранов нет активной root-вкладки. Root navigation
одинакова на телефоне и планшете: Главная / Резюме / Проекты / Портфолио,
все подписи всегда видимы. Большой web-редактор не определяет mobile tablet layout.

---

## R1.1 — Информационная архитектура

На 2026-10-05 подготовлены три editable схемы на новой странице Figma
[StackCard Design v2 / UX, 58:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-7).
Статус — `done`: принята поручением «переходи к следующей фазе», D013.
Это принятая карта сущностей и переходов,
а не low-fi, интерактивный прототип или реализация новых контрактов.
Source для сравнения: текущие [router](../../apps/mobile/lib/app/app_router.dart),
[PortfolioContent](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_content.dart)
и [продуктовые пробелы](audit.md#продуктовые-пробелы).

### Четыре roots и вложенные screens

[Navigation, 58:8](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-8)
показывает один и тот же состав bottom navigation на телефоне и планшете.
Все четыре подписи всегда видимы; rail/sidebar не входят в mobile target.

| **Root** | **Данные и вложенные назначения** |
|:---|:---|
| Главная / S-HOME | Объединённое представление Resume, Project и Portfolio по изменению; Все/Резюме/Проекты фильтруют только Home. Карточка ведёт в соответствующий editor; отдельного Home store нет |
| Резюме / S-RESUMES | Resume library → Create/Wizard или прямая правка выбранного документа/секции → Preview → отдельный Publish → Share |
| Проекты / S-PROJECTS | Общая Project library → ручной editor или GitHub Import; source changes → Review. Повторный import не создаёт новый вид Project или дубликат |
| Портфолио / S-PORTFOLIOS | Portfolio library → editor → выбор/создание Project и attachment, необязательный выбор Resume → Preview → отдельный Publish → Share |

Gear любого root открывает S-SETTINGS поверх текущего контекста. Его группы:
S-PROFILE, S-CONTACTS, S-ACCOUNT, S-PRIVACY и S-APP. В Settings нет активной
root-вкладки; выход расположен в Account. Root header содержит компактное
название/брендинг и gear, без greeting/logout/STACKCARD DEMO и второго огромного header.

Контекст возврата содержит исходный root, Home filter, scroll, выбранный
document ID и секцию. Settings child возвращает в Settings, затем в источник;
editor возвращает к caller, Preview — в тот же editor. Back/Close видимы.
При unsaved вводе предлагаются сохранить, продолжить редактирование или явно
отбросить; неудачный Save удерживает ввод. Подробные low-fi и проверка действий
принадлежат R1.2–R1.4; paths/deep links/UID guards уточняются перед R8.

### Владение данными и связи

[Ownership, 58:41](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-41)
отделяет общую профессиональную базу от библиотек и конкретных outputs.
Названия связей ниже — предлагаемые понятия IA, не новые Dart-классы или schema.

| **Владелец** | **Состав и граница изменения** |
|:---|:---|
| DeveloperProfile: один у владельца | Необязательное фото, имя/ник/специализация/bio, публичные контакты/ссылки, навыки, опыт, образование. Правка базы предлагает review существующим outputs; не меняет их молча |
| Project library: 0..N | Ручные и GitHub Projects с описанием/технологиями/ссылками/source и ручными overrides. Один Project используется в нескольких Resume и Portfolio; Add/Accept/Ignore отделены от Save |
| Resume: 0..N у владельца | Документ для выбранной роли: selected data, локальные overrides, отображение, порядок и видимость. Правка Resume не меняет базу или соседний документ |
| Portfolio: 0..N у владельца | Showcase с отдельными секциями/appearance, attachments и необязательным выбором одного Resume; выбор не публикует Resume автоматически |
| PortfolioProject: связь N:M | Portfolio 1 → 0..N attachments; Project 1 → 0..N attachments. Order/visible/featured принадлежат связи. Create из Portfolio создаёт library Project + связь; remove удаляет только связь |
| ResumeProject: связь N:M | Resume 1 → 0..N selections; Project 1 → 0..N включений. Выбор/порядок/видимость принадлежат документу; source update предлагает review вместо молчаливой правки готового документа |
| Account / app preferences / private notes | Отдельные данные. Login email не становится публичным контактом; private notes не включаются в output или public snapshot |

Текущий Flutter содержит один PortfolioContent/resumeText и глобальные
Project featured/visible. GAP-DATA-01..03 сохраняют необходимость отдельно
разрешённой миграции; IA не изменяет storage, auth или sync.

### Жизненный цикл и сценарии проверки

[Lifecycle and walkthrough, 58:75](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-75)
показывает working input → local Save → private sync ACK и отдельное действие
saved document draft → Publish → public snapshot. Guest остаётся local-only.
Правка опубликованного документа создаёт dirty draft, предыдущая public версия
сохраняется до явного Publish. Unpublish прекращает доступ, сохраняя draft.
Private notes, login email и source/override/Ignore metadata исключаются.

| **Проверка и требования** | **Пройденный сценарий IA / результат** |
|:---|:---|
| C-MODEL; REQ-MODEL-01..04 | Одна база, несколько независимых Resume/Portfolio, общая library и Home read view обозначены; пустая база/library не блокирует roots и не порождает фиктивные данные |
| C-MODEL; REQ-MODEL-02,05 | P1 включён в Resume R1 и Portfolio A/B с разными order/featured. Remove из A сохраняет P1 в library, R1 и B; Create P2 из A создаёт Project + attachment |
| C-MODEL; REQ-MODEL-03,07 | Base headline изменился, Resume R1 имеет local override: review сохраняет override; R2 и public snapshot не меняются без отдельного действия |
| C-MODEL; REQ-MODEL-06 | GitHub refresh только читает source; Add/Accept/Ignore явные, Save отдельный; dedup по repository ID и curated overrides сохранены в карте |
| C-MODEL; REQ-MODEL-08 | Local Save/pending sync/server ACK не публикуют; Publish отдельный. Draft не получает public URL; Copy/Open/Share доступны опубликованному документу |
| C01; REQ-NAV-03 | Для каждого из четырёх roots записан компактный header+gear; greeting/logout/DEMO/дублирующий header запрещены |
| C02/C12; REQ-NAV-02,04,05 | Home с фильтром Резюме и scroll → gear → Profile → Back → тот же Home/filter/scroll; описаны child/Preview/unsaved возвраты и удержание ввода при ошибке |
| C11; REQ-NAV-01 | Телефон/tablet: те же четыре нижние подписи без rail/sidebar; Home filter не становится глобальной навигацией |

Результат этой сверки — соответствие **правил IA** заданию. Renders всех трёх
frames просмотрены: текст читается, обрезаний и наложений не обнаружено.
Tap/keyboard/system Back, настоящий tablet UI, data tests и backend действия
ещё не проверены. C01/C02/C11/C12 не закрываются как UI acceptance этими схемами.

Политика D007 закрыта решением D019 о постоянных адресах документов;
GAP-URL-01 (route scheme/миграция), global delete Project consequences
и GAP-PUB-01/02 остаются открытыми. Публичный
Portfolio открывает выбранное Resume только через его опубликованную версию;
выбор draft не разрешает публичный доступ. R1.1 принята на уровне IA;
это не готовность backend. R1.2 принята с правками D015, R1.3 — D017,
R1.4 принята после цветовых правок D020; R2 `done` D024, R3.1 `done` D028; R3.2 `awaiting_review` D029;
DESIGN_READY/REDESIGN_DONE не установлены.

---

## R1.2 — Low-fi основных сценариев

На 2026-10-05 созданы **24 editable экрана 390×844** на странице
`StackCard Design v2 / UX`. Статус — `done`, D015: поручение продолжить
после исправления кнопок/поиска; правки выполнены и проверены.
Переходы описаны в captions и walkthrough; кликабельный prototype — R7.
Это схема расположения данных и действий, без выбора направления R2,
финальной DS R3 или реализации Flutter/backend.

| **Board** | **Экраны и проверенная ссылка** |
|:---|:---|
| Roots and Settings | F01–F08; [61:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-7), 1752×2273 |
| Profile to Document | F09–F16; [61:491](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-491), 1752×2273 |
| Errors and Settings Groups | F17–F24; [61:833](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-833), 1752×2273 |

### Экранные состояния и пути

F01–F24 — локальные обозначения low-fi этой задачи, не новые routes.
Все ссылки ниже указывают на реально созданные phone frames.

| **Low-fi / целевой экран** | **Frame** | **Состояние и переход** |
|:---|:---|:---|
| F01 / S-HOME | [61:14](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-14) | Все: Resume + Project + Portfolio, недавние выше; gear → F08; Copy только у published |
| F02 / S-HOME | [61:89](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-89) | Резюме: только Resume; origin Home/filter/scroll 120 сохраняется через Settings |
| F03 / S-HOME | [61:147](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-147) | Проекты: только Project; нижняя Главная остаётся активной |
| F04 / S-HOME | [61:200](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-200) | Empty Resume filter при непустой library; Все → F01, создать → F16 |
| F05 / S-RESUMES | [61:250](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-250) | Создать → F16; published/draft различаются, Copy отдельно от открытия |
| F06 / S-PROJECTS | [61:311](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-311) | Импорт → создать → поиск → список, без категорий/hero; подробный flow R1.4 |
| F07 / S-PORTFOLIOS | [61:378](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-378) | Несколько Portfolio и create; editor/Publish принадлежат R1.4 |
| F08 / S-SETTINGS | [61:439](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-439) | Пять групп; child Back → F08, Settings Back → origin. Bottom navigation отсутствует |
| F09 / S-PROFILE | [61:498](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-498) | Фото optional, имя/ник/роль/bio; карьера → F10, Save → F24, errors → F17/F18 |
| F10 / S-PROFILE | [61:550](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-550) | Location, skills/experience/education и Add; общая база, Back → F09 |
| F11 / S-CONTACTS | [61:600](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-600) | Public email, optional phone, ссылки; label+URL → F12, reorder → F13 |
| F12 / S-CONTACTS | [61:648](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-648) | Правка подписи/URL; Save → F11, Delete требует подтверждения, invalid URL удерживает ввод |
| F13 / S-CONTACTS | [61:680](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-680) | Выше/Ниже как альтернатива drag; Save order и Back → F11 |
| F14 / S-PROFILE | [61:726](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-726) | Пустая база без фото; заполнение не навязывается на Home, создание допустимо |
| F15 / S-CONTACTS | [61:777](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-777) | Empty contacts, public email/phone optional; Add link → F12, login email не копируется |
| F16 / вход S-RESUME-WIZARD | [61:808](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-808) | Использовать базовый профиль / начать с пустого → R1.3; собственного wizard здесь ещё нет |
| F17 / S-PROFILE | [61:840](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-840) | Taken username, остальные поля сохранены; исправить → F09, Save недоступен до исправления |
| F18 / S-PROFILE | [61:876](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-876) | Failed Save удерживает ввод; Retry → F24 после successful local write, продолжить → F09 |
| F19 / S-PROFILE | [61:914](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-914) | Unsaved Back: Save → F24/F18, продолжить → F09, явный discard → F08 |
| F20 / S-PROFILE | [61:933](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-933) | Обновлён D019: смена username сохраняет постоянные ссылки документов; target confirmation доступен, фактический adapter требует миграции |
| F21 / S-ACCOUNT | [61:964](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-964) | Private login email, Google not connected, Sign out; sensitive actions обозначены как target, GAP-ACCOUNT-01 |
| F22 / S-PRIVACY | [61:1001](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-1001) | Contact defaults для выбора в outputs; обращения planned, GAP-CONTACT-01 |
| F23 / S-APP | [61:1026](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-1026) | Тема dark/light/system, ru/en; reduced motion target, notifications planned, GAP-PREF-01 |
| F24 / S-PROFILE | [61:1058](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-1058) | Locally saved, pending sync без Publish; Settings → F08 → origin F02, Resumes → F05 → F16 |

### Walkthrough и пределы проверки

Основной путь: **F02 → F08 → F09/F10 и F11/F12/F13 → F24 → F08 → F02 →
F05 → F16**. Правка общей базы оставляет существующие документы без изменений;
review и local overrides проектируются дальше. F14/F15 допускают тот же вход
в создание, отсутствие фото/телефона/ссылок не блокирует документ.

Для четырёх roots предусмотрены одинаковые gear и labels; Home filter не
меняет root. Возврат хранит root/filter/scroll/document/section. Unsaved выход
отдельно предлагает Save/Continue/Discard; failed Save удерживает поля. Local
Save/pending sync не обозначаются публикацией. После D019 F20 показывает
принятую политику постоянных адресов документов. Поддержка нового URL-контракта
текущим runtime ещё не реализована; redirects макетом не обещаются.

| **Проверка / требования** | **Фактический результат low-fi** |
|:---|:---|
| C01/C02/C12; REQ-NAV-01..05 | F01–F08: четыре подписанных roots, compact header+gear, Settings без активной вкладки; вложенные кадры имеют Back. Origin/unsaved записаны в captions и F19 |
| C03/C04; REQ-HOME-01..03 | F01–F04: ровно три фильтра, правильные типы, mixed recent list, empty filter, отдельный Copy; запрещённые dashboard blocks отсутствуют |
| C05 | F06 показывает требуемый порядок Projects без категорий/hero; карточка/полный import не закрываются этим каркасом |
| C06/C12; REQ-SETTINGS-01..04 | F09–F15/F17–F24: поля, публичная/приватная почта, reorder, empty, taken username, Save failure/success, unsaved и rename warning. Reopen и media/provider actions остаются непроверенными |
| C-SCOPE / editable structure | При первоначальном создании 959 nodes; после правок D015 — 967 descendants и три board roots. Image fills отсутствуют; переиспользованы локальные mains и semantic variables |

Три board screenshots просмотрены после исправления Auto Layout rows и
автовысоты текстов. Дополнительно просмотрен F24 отдельно: сохранённые имя/роль
видны. Все 24 phone frames имеют 390×844; content bounds не выходят за body,
нижняя навигация либо pinned Save помещаются. В low-fi использован существующий
Noto Sans с кириллицей, это не выбор новой типографики. Старые страницы/IA/mains
не редактировались; новые components/variables не создавались.

Это статический walkthrough и осмотр дизайна. Реальные tap/system Back,
keyboard/text scale/tablet, повторное открытие storage, auth, sync и publication
не проверены. C01–C06/C12 не закрыты как prototype/runtime acceptance.
Hi-fi error/photo/provider states уточняются R4/R5; пять шагов Resume показаны R1.3,
Projects/Portfolio/Publish flow — R1.4. Последующие результаты R2.1 приведены
ниже; runtime ещё не перенесён.

---

### Правки кнопок и поиска, D015

Все последовательные соседние действия R1.2 размещены горизонтально в девяти
Auto Layout rows 70:519–70:527: Projects, contacts, вход в Resume, unsaved,
rename, две группы account, privacy и Save success. Всего 20 кнопок; height
48 px, gap 8 px, font 13 px, ширина 167 px для пары или около 109 px для тройки.
Уменьшены padding и длинные подписи; labels заполняют доступную ширину.

Поиск Projects — input 61:361 342×48 с существующей лупой 18:204; heading
61:360 удалён. Подсказка «Название проекта» остаётся внутри поля. Три итоговых
board renders просмотрены после правок: кнопки и их подписи на одном уровне,
поиск без внешнего heading. Правило перенесено в R1.3 и requirements.

---

## R1.3 — Low-fi Resume wizard и редактора

На 2026-10-05 созданы **24 editable экрана 390×844** на той же UX page 58:7.
Статус — `done`: создана D016, принята поручением продолжить D017;
задача разрешена поручением D015 после правок R1.2.
G01–G24 — обозначения low-fi, не новые runtime routes.
Переходы пока описаны captions; кликабельный prototype — R7.

| **Board** | **Экраны и проверенная ссылка** |
|:---|:---|
| Resume Wizard | G01–G08; [72:537](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-537), 1752×2273 |
| Optional Photo and Back | G09–G16; [72:941](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-941), 1752×2273 |
| Section Editing and Save | G17–G24; [72:1242](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1242), 1752×2273 |

### Экранные состояния Resume

| **Low-fi / целевой экран** | **Frame** | **Состояние и переход** |
|:---|:---|:---|
| G01 / S-RESUME-WIZARD | [72:544](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-544) | Профиль: название/имя/роль/optional bio, фото; F16 → G01, Далее → G02, фото → G12; Back удерживает ввод |
| G02 / S-RESUME-WIZARD | [72:607](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-607) | Контакты из публичной базы/своя ссылка; login email исключён. Back → G01, Далее/skip → G03 |
| G03 / S-RESUME-WIZARD | [72:661](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-661) | Опыт и образование выбираются; стаж не придумывается, Add optional. Back → G02, Далее/skip → G04 |
| G04 / S-RESUME-WIZARD | [72:707](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-707) | Навыки и проекты из library, поиск с лупой без заголовка. Выбор принадлежит Resume; Далее/skip → G05 |
| G05 / S-PREVIEW | [72:769](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-769) | Шаг 5: структурированный документ с wireframe-слотом выбранного фото. Save → G06/G22; Publish доступен отдельным flow после Save |
| G06 / S-RESUME-EDITOR | [72:810](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-810) | Сохранено локально / draft / pending sync; public ссылки нет. Редактор → G16, просмотр → G05, публикация → R1.4 |
| G07 / S-PREVIEW | [72:838](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-838) | Тот же документ без фото; имя занимает всю ширину. Фото необязательно; Save → G06/G22 |
| G08 / S-RESUME-WIZARD | [72:878](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-878) | Пустое название блокирует Далее; остальные значения/фото сохраняются, исправление → G01 |
| G09 / S-RESUME-WIZARD | [72:948](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-948) | Empty contacts: почта входа не предлагается; skip исключает только контакты этого Resume → G03 |
| G10 / S-RESUME-WIZARD | [72:979](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-979) | Empty experience/education: пропуск → G04, пустые секции не выводятся; можно добавить сведения |
| G11 / S-RESUME-WIZARD | [72:1010](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1010) | Ничего не выбрано в skills/projects: поиск, выбор из library или skip → G05; без пустых badges/cards |
| G12 / S-RESUME-WIZARD | [72:1048](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1048) | Фото из профиля / gallery / camera; replace/remove; Apply → исходный editor, Remove → no-photo. Asset обозначен, не загружен |
| G13 / S-RESUME-WIZARD | [72:1094](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1094) | Permission/load failure удерживает поля; Retry → G12, Без фото → исходный шаг/no-photo, ошибка не считается успехом |
| G14 / S-RESUME-WIZARD | [72:1118](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1118) | Keyboard intent: условная область 264 px, Save/Next над ней; body допускает scroll. Закрытие keyboard не закрывает документ |
| G15 / S-RESUME-EDITOR | [72:1159](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1159) | Unsaved exit: Save → G06/G22, продолжить → исходный шаг/editor, discard → F05; System Back следует этому правилу |
| G16 / S-RESUME-EDITOR | [72:1178](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1178) | Сохранённый документ: пять focused sections, Данные/Вид/Просмотр; без Stepper, одна правка не запускает весь wizard |
| G17 / S-RESUME-EDITOR | [72:1249](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1249) | Имя/роль/bio/photo только этого Resume, например local role Frontend Developer. Apply → G21; Cancel → G16 |
| G18 / S-RESUME-EDITOR | [72:1300](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1300) | Выбор/visibility/order публичных контактов и local email/URL; login email исключён. Apply → G21; база не меняется |
| G19 / S-RESUME-EDITOR | [72:1345](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1345) | Выбор опыта/образования; пустой опыт допустим, Add не придумывает работодателей/даты. Apply → G21 |
| G20 / S-RESUME-EDITOR | [72:1388](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1388) | Project selection, Выше/Ниже, local description override и Remove relation; Project остаётся в library/других outputs. Apply → G21 |
| G21 / S-RESUME-EDITOR | [72:1438](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1438) | Working draft изменён после Apply, отдельный Save → G06/G22, Close → G15. Если опубликован, public snapshot прежний |
| G22 / S-RESUME-EDITOR | [72:1503](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1503) | Local Save failure: ввод/local role сохраняются, Retry → G06 только после successful write; назад → G21 с правками |
| G23 / S-RESUME-EDITOR | [72:1536](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1536) | Review diff базы: собственная роль сохраняется, выбираются изменения ссылок. Apply → G21, затем отдельный Save; соседние outputs прежние |
| G24 / S-RESUME-EDITOR | [72:1570](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1570) | Ограниченное оформление отдельно от content: layout, photo/education visibility. Apply → G21; final style/accent — R2/R3 |

### Walkthrough Resume и пределы проверки

Основной путь: **F16 → G01 → G02 → G03 → G04 → G05 → local Save G06**.
G09/G10/G11 допускают пропуск необязательных сведений только для этого Resume;
Back возвращает к предыдущему шагу с сохранённым выбором. Название обязательно
G08; фото G12/G13 необязательно и не блокирует документ G07.

Прямая правка: **F05/G06 → G16 → G17–G20/G24 → Apply G21 → Save G06/G22**.
Apply меняет working Resume, отдельный Save пишет draft локально.
G23 предлагает явный review выбранных изменений базы, сохраняя local override.
Правка не изменяет DeveloperProfile, Project source, соседние документы или
опубликованный snapshot. Publication flow показан R1.4 ниже.

| **Проверка / требования** | **Фактический результат low-fi** |
|:---|:---|
| C12/C16; REQ-RESUME-02/04 | Пять шагов с согласованным прогрессом, skip G09–G11, Back/validation/unsaved; G16 открывает отдельную секцию без wizard |
| C07; REQ-RESUME-03 | G05/G07 используют один preview component с/без фото; G12/G13 показывают выбор/replace/remove/permission failure. Фото — wireframe-слот, реального asset нет; C07/native media не закрыты |
| C10/C12; REQ-EDITOR-01..03 | Секции → Apply → dirty → отдельный local Save/error/retry; content/appearance/preview разделены. G20 remove relation и G23 review сохраняют ownership |
| C16 / keyboard intent | G14 имеет условную keyboard area 264 px, pinned actions над ней и body 396 px; это layout-схема, не native keyboard/scale 2 acceptance |
| C-SCOPE / editable structure | 1003 descendants трёх boards: 372 TEXT, 293 FRAME, 216 INSTANCE, 87 RECTANGLE, 35 VECTOR; плюс три board roots. No image fills; existing Noto Sans, mains/styles/variables переиспользованы |

Создан один временный component [ResumeDocument 72:521](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-521):
`Show photo` переключает wireframe-слот, `Headline` задаёт роль. Имя без фото
занимает 318 px вместо 222 px. Это low-fi reuse, не финальная DS R3.
Новых styles/variables не создано; legacy pages и mains не изменялись.

Три итоговых board renders просмотрены после исправления Stepper и ширины имени.
По реальным IDs проверены все 24 phone frames: 390×844, content bounds помещаются
в body, pinned actions видны. Во всех новых поисках только поле/лупа/подсказка,
соседние кнопки располагаются горизонтально; вертикальных последовательностей
таких кнопок в R1.2/R1.3 не найдено.

Это статический осмотр и walkthrough. Настоящие выбранное фото, permissions,
input retention/Back reactions, keyboard, scale 2/tablet, reopen/storage/sync
и publication не проверены. Реальный `resumeText` editor остаётся прежним,
GAP-DATA-01/GAP-MEDIA-01 и остальные предпосылки реализации сохранены.
R1.3 принята D017; R1.4 принята после правок D020, показана ниже.
Сравнение R2.1 принято D022; бренд A и R2 приняты D024; R3.1 done D028; R3.2 done D030; R3.3 done D032; R3.4 done D034 (подготовлена D033); runtime не перенесён.

---

## R1.4 — Low-fi Projects, Portfolio и публикации

На 2026-10-05 созданы **40 editable экранов 390×844** на UX page 58:7.
R1.3 принята прямым поручением продолжить, D017; R1.4 первоначально ожидала
review (D018), теперь `done` после цветовых правок D020. H01–H40 обозначают
low-fi states, не runtime routes. Переходы записаны
captions; интерактивный prototype принадлежит R7. Постоянные адреса документов
приняты отдельным ответом пользователя, D019.

| **Board** | **Экраны и проверенная ссылка** |
|:---|:---|
| Manual Projects | H01–H08; [78:1012](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1012), 1752×2248 |
| GitHub Import and Review | H09–H16; [78:1013](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1013), 1752×2288 |
| Portfolio and Attachments | H17–H24; [78:1014](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1014), 1752×2288 |
| Publication Lifecycle | H25–H32; [78:1015](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1015), 1752×2308 после уточнения H28 |
| Access Links and Recovery | H33–H40; [78:1016](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1016), 1752×2328 после D019 |

### Экранные состояния Projects, Portfolio и Publish

| **Low-fi / целевой экран** | **Frame** | **Состояние и переход** |
|:---|:---|:---|
| H01 / S-PROJECT-EDITOR | [79:1046](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1046) | Ручной проект: название, описание, технологии/ссылки, optional cover. Apply → working H03; Cancel возвращает к источнику без записи |
| H02 / S-PROJECT-EDITOR | [79:1106](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1106) | Пустое название блокирует Apply; исправление → H01, остальные поля удерживаются |
| H03 / S-PROJECT-EDITOR | [79:1167](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1167) | Project в общей library после Apply, есть несохранённые правки. Save → local saved (caption) / H08; Edit → H04, attach → H19 |
| H04 / S-PROJECT-EDITOR | [79:1215](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1215) | Редактирование GitHub Project: своё описание защищено, source metadata сохранены. Apply → H03, Cancel → исходный Project |
| H05 / S-PROJECTS | [79:1262](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1262) | Empty library: header+gear → горизонтальный import/create → search с лупой → empty state; Create → H01, Import → H09 |
| H06 / S-PROJECTS | [79:1314](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1314) | Поиск без результатов: query сохранён, clear возвращает список; библиотека не удаляется |
| H07 / S-PROJECT-EDITOR / S-PORTFOLIO-EDITOR | [79:1368](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1368) | Unsaved exit: Save → успех к origin / H08; продолжить → тот же editor; discard → origin. Действие сохраняет контекст владельца/документа |
| H08 / S-PROJECT-EDITOR / S-PORTFOLIO-EDITOR | [79:1388](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1388) | Local Save failure: ввод остаётся в working state, Retry повторяет запись; Back возвращает к правкам |
| H09 / S-GITHUB | [79:1418](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1418) | Username и loading: повторная загрузка disabled, Cancel доступен. Успех → H10, failure → H12; вход из library либо сохранённого origin |
| H10 / S-GITHUB | [79:1451](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1451) | Выбор repositories: новый выбран, ранее импортированный отмечен и повторно не добавляется. Add → H13; Refresh/следующая страница сохраняют выбор по ID |
| H11 / S-GITHUB | [79:1496](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1496) | Нет repositories/результатов query: изменить username/query или обновить; private repositories не обещаются |
| H12 / S-GITHUB | [79:1521](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1521) | Network failure оставляет cached list с датой обновления. Retry → H10; rate-limit deadline/другие typed errors описаны caption, отдельных frames нет |
| H13 / S-GITHUB | [79:1557](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1557) | Один новый repository добавлен в working library; отдельный Save, ошибка → H08; дубль ранее импортированного отсутствует |
| H14 / S-GITHUB-REVIEW | [79:1583](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1583) | Diff: ручное описание защищено, technologies Dart → Dart/Kotlin. Принять → working H03, Отклонить → H16, Cancel → H10; Publish не выполняется |
| H15 / S-GITHUB-REVIEW | [79:1627](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1627) | Stale source/project/owner: Accept disabled; Refresh строит новый review, возврат сохраняет исходный контекст |
| H16 / S-GITHUB-REVIEW | [79:1647](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1647) | Ignore относится к одной версии источника; сохраняется отдельно. Следующая версия может снова предложить review, private metadata не попадает в public |
| H17 / S-PORTFOLIO-EDITOR | [79:1685](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1685) | Создать именованное Portfolio из DeveloperProfile либо пустое → working H18. Title validation описана caption, отдельного frame нет |
| H18 / S-PORTFOLIO-EDITOR | [79:1722](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1722) | Dirty document: focused sections профиль/контакты, проекты, Resume, оформление; Данные/Вид/Просмотр раздельны. Save и Close/unsaved отдельные |
| H19 / S-PORTFOLIO-EDITOR | [79:1779](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1779) | Добавить из library: выбран новый Project, уже прикреплённый отмечен; Apply создаёт одну relation → H18, без дублей |
| H20 / S-PORTFOLIO-EDITOR | [79:1819](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1819) | Empty library при attach: Create → H21; Back → Portfolio без изменений |
| H21 / S-PROJECT-EDITOR / S-PORTFOLIO-EDITOR | [79:1845](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1845) | Создать и прикрепить: Apply создаёт working Project + relation → H18. Cancel не оставляет orphan; failure Save сохраняет оба изменения |
| H22 / S-PORTFOLIO-EDITOR | [79:1891](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1891) | Association: Выше/Ниже, Главный проект, visibility, local description override; Apply → dirty H18, remove → H23. Другие документы прежние |
| H23 / S-PORTFOLIO-EDITOR | [79:1946](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1946) | Remove relation confirmation: убрать только из этого Portfolio; Project остаётся в library/других outputs, public snapshot прежний |
| H24 / S-PREVIEW | [79:1964](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1964) | Working Portfolio preview: тот же no-photo document component, опубликованное Resume. Back → editor; Publish проходит Save/sync gate H25/H26/H34 |
| H25 / S-PUBLISH | [79:2013](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2013) | Saved и synced текущий draft: review публичного состава, отдельный Publish → H27. Общий lifecycle Resume/Portfolio, тип определяется входным документом |
| H26 / S-PUBLISH | [79:2062](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2062) | Dirty draft блокирует Publish; Save → H34, после ACK именно текущей версии → H25 |
| H27 / S-PUBLISH | [79:2096](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2096) | Publication pending: submit disabled, captured version сохраняется; успех → H29, error/unknown outcome → H28 |
| H28 / S-PUBLISH | [79:2123](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2123) | Нет ответа/unknown outcome: private draft сохранён, до сверки показывается last-known public состояние; сервер уже мог завершить Publish. Проверить статус → H29 при успехе / recovery при failure; retry после сверки |
| H29 / S-SHARE | [79:2151](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2151) | Published detail: постоянно видны Copy/Open/Share, feedback копирования. Адрес обозначен без выдуманного production URL; native действия не исполнены |
| H30 / S-PORTFOLIO-EDITOR / S-SHARE | [79:2194](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2194) | Опубликованный документ с dirty draft: прежняя публичная ссылка доступна; Save/sync/review и явное обновление публикации меняют public |
| H31 / S-PUBLISH | [79:2236](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2236) | Unpublish confirmation: private draft/library сохраняются. Успех → H36, failure → H35 |
| H32 / S-PORTFOLIO-EDITOR | [79:2254](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2254) | Выбор Resume: опубликованное либо draft с понятным статусом; публичная ссылка показывается только на опубликованное Resume, draft не открывается посетителю |
| H33 / S-PUBLISH | [79:2292](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2292) | Guest: локальный draft сохранён, Publish disabled до account; вход/перенос данных требует явного owner-контекста |
| H34 / S-PUBLISH | [79:2312](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2312) | Local saved, offline/pending sync: Publish disabled. Retry sync, ACK текущей mutation → H25; local Save сам по себе не публикация |
| H35 / S-PUBLISH / S-SHARE | [79:2347](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2347) | Unpublish failure/unknown outcome: проверить статус перед повторной отправкой; last-known published controls не объявляют успешное снятие |
| H36 / S-SHARE | [79:2380](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2380) | Unpublished: private document остаётся, доступная публичная ссылка не предлагается. Publish проходит H25, адрес документа сохраняется по D019 |
| H37 / S-PUBLIC-PORTFOLIO | [79:2407](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2407) | Anonymous snapshot: имя/роль, контакты, технологии, Project и опубликованное Resume; owner controls/private metadata отсутствуют |
| H38 / PUBLIC | [79:2445](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2445) | Unavailable после unpublish/отсутствия документа: без private preview, owner editor или утечки данных |
| H39 / S-PORTFOLIO-EDITOR / S-PROFILE | [79:2466](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2466) | Переименование по D019: постоянная ссылка прежняя; Rename → working draft → Save/sync → отдельный Publish. F20 подтверждает ту же политику для username |
| H40 / S-PORTFOLIO-EDITOR | [79:2500](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-2500) | Duplicate: новая private identity и свои relations на общую library; публикация/URL исходного документа не копируются |

### Walkthrough Projects, Portfolio и публикации

Ручной путь: **Projects → H01 → Apply H03 → отдельный Save**.
H02 удерживает поля при validation, H04 сохраняет GitHub metadata/ручное
описание; H07/H08 показывают unsaved exit и failed local write.
«Создать и прикрепить» **H20 → H21 → H18** создаёт обычный Project в общей
library и связь с конкретным Portfolio; Cancel не оставляет orphan.

GitHub: **H09 → H10 → H13 → Save** либо **H10 → H14 → Accept/Ignore/Cancel**.
Dedup использует repository ID, Refresh не добавляет проекты сам.
Accept не перезаписывает ручное описание; Ignore H16 относится к одной версии,
stale H15 блокирует применение устаревшего review. H12 сохраняет cached list
при network failure; подробные typed errors остаются дальнейшими hi-fi states.

Portfolio: **H17 → H18 → H19/H21 → H22 → H24**. Порядок, featured, visibility
и description override принадлежат relation этого документа. Remove H23
сохраняет Project в library и других Resume/Portfolio. Изменения working
документа не меняют public snapshot до явной публикации.

Общий lifecycle Resume/Portfolio: **working → Save → pending sync H34 →
ACK текущего draft → review H25 → Publish H27 → published H29**.
Dirty H26 и guest H33 не проходят Publish gate. H30 оставляет старую public
версию доступной, пока новые правки проходят Save/sync/Publish.
H28 при неизвестном исходе операции показывает последнее известное состояние:
сервер уже мог завершить Publish. Сначала сверка статуса, затем безопасный retry.
**H31 → H36** снимает публикацию и сохраняет private draft;
failure H35 не выдаёт успех. Copy/Open/Share доступны published detail;
H36/H38 не показывают private draft посетителю.

По D019 адрес связан с identity документа и сохраняется при смене названия
и username. H39 показывает rename draft, F20 — rename username; оба обновлены
после ответа пользователя. Unpublish делает страницу недоступной, повторный
Publish использует прежний адрес. Duplicate H40 получает новую identity
и не наследует публичный URL. Точная route scheme и миграция нынешнего
username adapter ещё не реализованы; в макетах нет выдуманного production URL.

### Проверки R1.4 и пределы результата

| **Проверка / требования** | **Фактический результат low-fi** |
|:---|:---|
| C-GITHUB; REQ-PROJECT-04/REQ-MODEL-06 | H09–H16: loading/empty/network cached/dedup/review/Ignore/stale и сохранение ручного описания; rate-limit deadline только caption |
| C-MODEL; REQ-MODEL-02/04/05, REQ-PORTFOLIO-03 | H01–H04/H17–H24/H40: library/independent documents/association ownership, remove relation, create+attach, duplicate |
| C09/C10; REQ-MODEL-08/REQ-SHARE-01 | H25–H36: dirty/local/pending sync/synced/published/unpublished, отдельный Publish, постоянно видимые link controls |
| C12; REQ-NAV-04/REQ-EDITOR-01..03 | Origin/Back/unsaved/error retention записаны в captions/H07/H08; focused editor отдельно от preview/publication |
| C17; REQ-PORTFOLIO-02/REQ-SHARE-01 | H32/H37/H38: только опубликованное Resume доступно публично, private metadata/owner controls не показываются. Server payload/security не проверены |
| C-SCOPE / editable structure | 1418 descendants пяти boards: 534 TEXT, 456 FRAME, 300 INSTANCE, 55 RECTANGLE, 73 VECTOR; плюс пять roots. Existing mains/styles/variables, без image fills |

Один временный component [PortfolioDocument 79:1012](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1012)
имеет размеры 342×398, 27 descendants, `Show photo` и `Show Resume link`.
H24/H37 используют тот же main без фото и с published Resume. Нет новых
styles/variables или финального выбора typography/logo; это не DS R3.

После исправления длинной подписи review и упрощения видимых текстов
просмотрены пять итоговых board renders. После D019 дополнительно просмотрены
H39 и F20, затем H28 после contract review. По реальным IDs проверены 40 phone frames: content bounds помещаются,
48 px tap areas соседних действий горизонтальны, button labels без overflow.
Шесть search inputs показывают лупу и поле без внешнего heading.

Static walkthrough не подтверждает native Back/keyboard/scale 2/tablet,
input retention/reopen, owner races/auth, storage/sync/network/Firebase,
real photo, clipboard/native share или безопасность anonymous reader.
Переходы ещё не кликабельны. Текущие singleton PortfolioContent/plain resumeText,
global project featured/visible и username publication adapter прежние;
GAP-DATA-01..03/GAP-PUB-01/02/GAP-URL-01 остаются предпосылками реализации R8.

R1.1–R1.4 done, D020; R2 done D024, R3.1 done D028; R3.2 done D030; R3.3 done D032; R3.4 done D034 (подготовлена D033). Runtime не перенесён,
DESIGN_READY/REDESIGN_DONE не установлены.

---

## Цветовые правки low-fi

Поручение D020 выполнено на **88 экранах R1.2–R1.4** без изменения их размеров,
порядка и сценариев. **74 основных действия** получили lime-fill с ink-текстом,
**девять опасных** — error outline/text или error-fill с ink. **12 выбранных
controls** используют surfaceActive + lime outline/text и существующую
геометрию/подпись выбора. **Десять заголовков** ошибок/ожидания получили
семантический error/warning. **16 disabled controls** оставлены нейтральными.
Main components старой библиотеки сохранены; overrides принадлежат low-fi instances.

Горизонтальные ряды с hit area 48 px и search с лупой без внешнего заголовка
сохранены. Bounds кнопочных подписей всех 88 frames — PASS. Просмотрены
цветовые renders 61:7, 72:537, 78:1012, 78:1013, 78:1015; после замены legacy
selected-fill на surfaceActive дополнительно проверен 61:7. Это пять
репрезентативных boards, а не новый визуальный просмотр всех 11 boards.
R1 принята условным поручением продолжить после этих правок, D020.

---

## R2.1 — Два визуальных направления

**Статус: `done`, D022.** Сравнение принято поручением продолжить;
на этом шаге направление A/B ещё не было выбрано. Последующий выбор A — D024.
На новой странице
`99:7 / StackCard Design v2 / Directions` создан
[comparison wrapper 99:8](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=99-8),
1400×2297. Все шесть пилотов — editable Auto Layout **390×844**.

| **Пилот** | **A / Cyber Editorial** | **B / Developer Identity** |
|:---|:---|:---|
| S-HOME / Главная | [101:53](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=101-53) | [103:149](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=103-149) |
| S-PUBLIC-RESUME / Опубликованный документ | [101:146](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=101-146) | [103:241](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=103-241) |
| S-SETTINGS / Пять групп | [101:180](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=101-180) | [103:272](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=103-272) |

### Одинаковые данные и состояния

- Home: Все выбран; ровно три фильтра; published «Основное резюме», Project
  «StackCard», published Portfolio «Web & Mobile» в одном порядке. Отдельные
  области Open и Copy, четыре постоянно подписанные root tabs. Нет greeting,
  progress, dashboard, большого декоративного hero или глобального поиска.
- Public Resume: Станислав Мамаев, Fullstack Developer, Алматы, Казахстан,
  «Разрабатываю web и mobile», hello@example.test и GitHub snownumb,
  TypeScript/Kotlin, AlmaU / Software Engineering, StackCard / «Редактор
  developer-портфолио». Те же сведения взяты из low-fi fixture, а не придуманы
  как опыт/работодатели/достижения. «Написать» и GitHub расположены рядом;
  owner/account controls отсутствуют. Это опубликованный snapshot.
- Полноценный no-photo Resume в обоих направлениях: нет аватара, инициалов,
  fake-photo, пустой колонки под фото или обязательной загрузки.
- Settings: Профиль, Контакты, Аккаунт, Приватность, Приложение; одинаковые
  строки, тёмная тема, русский язык, neutral logout. Back подписан в структуре
  как возврат к Home; Settings не добавлены в root nav.

### Различия и переиспользование

**A / Cyber Editorial**, [99:10](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=99-10):
имя 40 px ExtraBold, плоские разделы, линии и срезанный многослойный знак.
**B / Developer Identity**, [99:11](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=99-11):
имя 28 px Bold в собранном блоке, мягкие карточки, editable document miniatures,
небольшие cyan/pink детали и открытая рамка знака. Настройки остаются спокойными.
Оба используют **Noto Sans** для Cyrillic и Latin, существующие text styles и
variables заданной dark-палитры; финальный выбор ещё не сделан.

Переиспользованы Button, SettingsButton, SettingsRow, CopyLinkButton,
BottomNavigation и ProjectCard. За пределами review wrapper размещены пять
временных mains: **100:10 / Mark A**, **100:13 / Mark B**, **100:16 / DocumentCard A**,
**100:30 / DocumentCard B**, **104:266 / ProjectCard B**, последний клонирован
из 38:2366 с сохранением текстовых properties. Знаки — новые авторские векторы;
старый S не перекрашен. В исходном срезе R2.1 новых variables/text styles нет;
это не DS R3. В R2.2 marks 100:10/100:13 сохранены внутри variant sets;
в центре B добавлены две карточки, связанные экземпляры шапок обновились.
Маленький текст 7–8 px в B — дополнительный preview, а читаемые названия,
статусы и controls находятся рядом.

### Проверки и ограничения

Все шесть phone bounds и видимые text/vector extents — PASS; исправлены
Copy-подпись и inner widths/reflow Project B. Итоговый comparison render
просмотрен после исправлений, включая surfaceActive вместо legacy selected tint.
Независимый metadata review подтвердил одинаковые content/state, пять Settings
groups, no-photo composition и только Noto Sans. [Предварительные contrast/font
license проверки](plan.md#фактические-результаты-цветовых-правок-и-r21) записаны
отдельно; это не заявление о WCAG-приёмке всего продукта.

Только static pilots: linked prototype/native Back, clipboard/share, payload
security, light/scale/keyboard/motion и настоящий photo/media flow не проверены.
TechnologyBadge с иконками/+N/wrap относится к R3, здесь показан краткий текст.
Small-size 16–48/mono/wordmark/app-icon review выполнен отдельным шагом R2.2
ниже. R2.3 фиксирует окончательный выбор.
Runtime/backend не изменены, DESIGN_READY/REDESIGN_DONE не установлены.

---

## R2.2 — Знак, написание и иконка приложения

**Статус: `done`, D024.** Исходный результат ожидал review D023; прямой выбор
бренда A закрыл R2.2/R2.3. Ниже сохранены факты сравнения обоих вариантов.
Поручение продолжить разрешило этот последовательный шаг (D022), без выбора A/B.
На page 99:7 создан
[Brand Comparison 110:268](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=110-268),
**1400×1992**, editable Auto Layout. Колонки A — 110:274, B — 110:275.
Ровно две концепции, без дополнительных logo-only фаз.

### Смысл и редактируемые семейства

A сохраняет срезанные слои карточки; плотное Noto Sans ExtraBold поддерживает
крупную типографику пилота. B соединяет открытую рамку и две внутренние карточки,
обозначающие Resume/Portfolio; Noto Sans SemiBold делает написание спокойнее.
Legacy S и прежние страницы/компоненты сохранены.

| **Семейство** | **A / component set** | **B / component set** | **Variants** |
|:---|:---|:---|:---|
| Mark | 110:282 | 110:289 | Tone=Accent / Ink / Paper |
| Wordmark | 111:284 | 111:314 | Tone=Accent / Ink / Paper |
| AppIcon | 111:297 | 111:327 | Appearance=Accent / MonoDark / MonoLight |

**Шесть sets, 18 main variants**, вне review wrapper. Исходные mark mains
100:10/100:13 сохранены, создано 16 дополнительных mains. Wordmark — живой
текст StackCard 36 px/44 line и знак 48 px; исходный AppIcon — 108×108,
центрированный знак 56 px, specimen — 96 px. Два экспериментальных shared
text styles `R2.2/Experimental/Wordmark A/B`, на шаге R2.2 новых variables нет.
A принят D024; три его sets закреплены ниже. B сохранён как альтернативная
история. Wordmark styles остаются с прежними IDs; runtime assets не экспортированы.

### Контраст, размеры и UI

- Accent: lime #C7FF1A на ink #070708; Ink: тёмный знак на paper #F4F5F7;
  Paper: белый монохром на тёмном. Все paints привязаны к существующим
  variables. Ink/lime — **17.02:1**, ink/paper — **18.46:1**.
  Lime/paper — 1.08:1, поэтому на светлом фоне используется Ink.
- Small grids A **113:311**, B **113:470** содержат по десять экземпляров:
  **16/20/24/32/48 px** в Accent и Ink. Внутренняя геометрия действительно
  масштабирована через rescale, а не только resized outer frame.
  Оба grids просмотрены при естественном размере 628×255, без уменьшения.
  A чище на 16 px. Рамка B узнаваема на 16, внутренние карточки яснее с 24;
  для основного применения B рекомендуется минимум **24 px**, в шапках — 32.
- Монохромные wordmarks: A **113:365**, B **113:524**; AppIcon sections
  **113:374 / 113:533**: Accent, MonoDark, MonoLight и круглая маска 96 px.
  Mask specimens проверяют композицию, не являются системными экспортами.
- Шапки Главной и public Resume клонированы из тех же R2.1 пилотов 390×64:
  для A источники 101:55/101:148, для B — 103:151/103:243. Dark/Light сохраняют
  геометрию и знак 32 px; Light использует Ink, тёмный текст и иконку settings.
  Контексты A: **113:406 / 113:418 / 113:432 / 113:439**;
  B: **113:565 / 113:577 / 113:591 / 113:598**.
  Settings pilots сохраняют спокойную Back-шапку, дополнительный знак не вставлен.
  Интерактивная область gear остаётся 48×48; small mark не задаёт hit area.
- Noto Sans используется для Latin/Cyrillic и всех 83 текстовых узлов листа.
  Проверены текущая регистрация bundled fonts в pubspec и SIL OFL 1.1 в
  [Noto_Sans_OFL.txt](../../apps/mobile/assets/fonts/Noto_Sans_OFL.txt).
  Знаки — оригинальные editable vectors, внешние logo/image assets не импортированы.

### Проверки и ограничения

Итоговый composition render просмотрен после исправления высоты cells 48 px;
labels и видимые shapes не выходят за контейнеры — **PASS**.
317 descendants, 83 text nodes, только Noto Sans, image fills — 0;
все texts имеют автоматическую высоту. Четыре унаследованных непокрашенных
SVG viewBox 24 px внутри settings icon instance 22 px не являются видимым
overflow; painted paths помещаются в control/header. Metadata не заменяет
визуальную проверку: отдельно просмотрены два small grids в размере 1:1.

На шаге R2.2 полная light theme, text scale/keyboard/motion, interactive prototype,
font shaping на устройствах и native Android/iOS icon exports ещё предстояли.
Новые font files/dependencies, runtime/schema/backend не менялись;
Flutter tests не запускались для Figma/doc-only задачи.
Выбор A записан в R2.3; foundations созданы в R3.1. Создание листа не являлось
приёмкой; основание done — прямой выбор D024. DESIGN_READY/REDESIGN_DONE не установлены.

---

## R2.3 — Принятый бренд и направление

**Статус: `done`, D024.** Пользователь: «вариант бренда мне понавился А.
приступай к следующей фазе». Принят бренд A: срезанные слои карточки,
плотное написание StackCard и его AppIcon. Связанные пилоты **A / Cyber Editorial**
служат композиционной основой R3 на поручение продолжить; крупная типографика
и плоские разделы сохраняют компактные горизонтальные действия low-fi.

В Figma закреплены существующие component sets с прежними IDs:

| **Выбранный set** | **ID** | **Прежние main variants** |
|:---|:---|:---|
| StackCard / v2 / Mark | 110:282 | Accent100:10 / Ink110:276 / Paper110:279 |
| StackCard / v2 / Wordmark | 111:284 | Accent111:269 / Ink111:274 / Paper111:279 |
| StackCard / v2 / AppIcon | 111:297 | Accent111:285 / MonoDark111:289 / MonoLight111:293 |

Пилоты A: Home101:53 / public Resume101:146 / Settings101:180, без пересоздания.
Не выбран B: sets110:289 / 111:314 / 111:327 и его пилоты сохранены как история;
legacy S и девять прежних страниц не изменены. Существующий wordmark style A
`S:bd0cabb3e521d11fc53fe82c41f8fdc9a16b2cb4,` сохранён.
Выбор бренда не является приёмкой шрифтового набора, всей DS или DESIGN_READY.

---

## R3.1 — Цвета, типографика и метрики

**Статус: `done`, D028.** Текущая UI-family — Manrope, Wordmark A сохранён. Page **121:7 / StackCard Design v2 / DS**:
[Foundations 123:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=123-7)
**1400×1657**, Dark123:13 / Light123:22;
[Typography and Metrics 125:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=125-19)
**1400×1423**, Dark125:25 / Light125:64. Editable Auto Layout и живой текст.
Foundations используют принятый Wordmark A, без новых logo variants.
Подразделы ниже сохраняют **исторический срез D025** до выбора Manrope;
актуальное продолжение — [D028](#закреплённая-типографика-manrope-d028) и R3.2.

### Семантические роли и темы

Повторно использованы collections Primitives `VariableCollectionId:2:2`,
Color `VariableCollectionId:2:3` (Dark2:1 / Light2:2), Metrics
`VariableCollectionId:2:4`. Все **25 прежних color variables** сохраняют значения
обеих тем; locked Dark HEX не изменены. Новой collection нет.
Добавлены **семь variables**: пять semantic aliases ниже, Light primitive
`VariableID:121:8 / hex/147B44` и `VariableID:121:14 / typography/displayA=40`.

| **Новая роль / VariableID** | **Dark / Light** | **Scope и назначение** |
|:---|:---|:---|
| color/textMeta / 121:9 | #A4A8B3 / #676C77 | TEXT_FILL; читаемые metadata на всех четырёх нейтральных поверхностях |
| color/controlOutline / 121:10 | #737884 / #676C77 | STROKE_COLOR; граница поля/secondary control |
| color/accentText / 121:11 | #C7FF1A / #526B00 | TEXT_FILL; небольшая акцентная подпись на нейтральной поверхности |
| color/successText / 121:12 | #41E68A / #147B44 | TEXT_FILL; текст успеха на нейтральной поверхности |
| color/primaryOutline / 121:13 | #C7FF1A / #070708 | STROKE_COLOR; видимая граница lime CTA, в Light — Ink |

В таблице ID сокращены после `VariableID:`. Aliases ведут к существующим
primitives, кроме нового Light successText. У primitive scope[] и hidden;
у displayA — FONT_SIZE. WEB codeSyntax `var(--color-text-meta)` и аналогичные
имена назначены семантическим ролям для handoff; это не реализованный CSS.
Новый display font-size связан с metric через shared text style.

Поверхности в порядке **background / surface / elevated / active**:
Dark **#070708 / #0D0E11 / #14161B / #1B1E24**;
Light **#F5F5F6 / #FFFFFF / #FAFAFA / #EFEFF1**.
Active переиспользует существующую `color/surfaceHover`; ID не переименован.

### Контраст и допустимое применение

Непрозрачные sRGB paints; WCAG relative luminance, `(Lmax+.05)/(Lmin+.05)`.
Порог сравнивается **до округления**, ниже значения округлены до трёх знаков.
В каждой ячейке пары идут в указанном выше порядке четырёх поверхностей.

| **Роль** | **Dark HEX** | **Dark contrast** | **Light HEX** | **Light contrast** | **Порог** |
|:---|:---|:---|:---|:---|:---|
| textPrimary | #F4F5F7 | 18.458 / 17.693 / 16.591 / 15.305 | #18181B | 16.261 / 17.717 / 16.974 / 15.428 | 4.5 |
| textSecondary | #A4A8B3 | 8.467 / 8.116 / 7.610 / 7.021 | #52525B | 7.095 / 7.730 / 7.406 / 6.731 | 4.5 |
| textMeta | #A4A8B3 | 8.467 / 8.116 / 7.610 / 7.021 | #676C77 | 4.833 / 5.266 / 5.045 / 4.585 | 4.5 |
| accentText | #C7FF1A | 17.017 / 16.312 / 15.295 / 14.110 | #526B00 | 5.568 / 6.066 / 5.812 / 5.282 | 4.5 |
| successText | #41E68A | 12.379 / 11.866 / 11.127 / 10.264 | #147B44 | 4.884 / 5.321 / 5.098 / 4.634 | 4.5 |
| warning | #FFD166 | 13.965 / 13.386 / 12.552 / 11.579 | #996000 | 4.786 / 5.214 / 4.995 / 4.540 | 4.5 |
| error | #F06272 | 6.420 / 6.153 / 5.770 / 5.323 | #C92D45 | 4.886 / 5.323 / 5.100 / 4.636 | 4.5 |
| sourceText | #6FE7F2 | 13.796 / 13.224 / 12.400 / 11.439 | #0B6570 | 6.198 / 6.753 / 6.470 / 5.881 | 4.5 |
| controlOutline | #737884 | 4.553 / 4.365 / 4.093 / 3.775 | #676C77 | 4.833 / 5.266 / 5.045 / 4.585 | 3 |
| focus | #C7FF1A | 17.017 / 16.312 / 15.295 / 14.110 | #526B00 | 5.568 / 6.066 / 5.812 / 5.282 | 3 |
| textMuted, диагностика | #737884 | 4.553 / **4.365 / 4.093 / 3.775 FAIL** | #676C77 | 4.833 / 5.266 / 5.045 / 4.585 | 4.5 |

**64 допустимые text pairs и 16 outline/focus pairs — PASS.** Восемь
диагностических textMuted pairs включают три Dark-fail; на этих поверхностях
обычный текст использует textMeta. Dark textMuted допустим только на background
для обычного текста. Существующий Light success#168449 имеет 4.350/4.740/4.541/4.127:
для текста на всех фонах нужен successText; исходный success остаётся для графики.
Border/borderStrong имеют <3 на нейтральных поверхностях и служат декоративными
разделителями; границу интерактивного control задаёт controlOutline.

На lime/cyan/pink заливке текст — **Ink #070708**; onPrimary/lime — **17.017:1**.
Цветные текстовые роли выше разрешены на нейтральных поверхностях, не на neon fill.
Lime на Light имеет 1.030–1.183:1, поэтому lime CTA использует primaryOutline Ink.
У Dark primary заливка и stroke одинаковы: contrast stroke/inside=1 допустим
для их общей фигуры, внешняя граница/background имеет17.017:1.

Applied specimens 588×48: Dark **124:120 / 124:124 / 124:126**, Light
**124:236 / 124:240 / 124:242** (ordinary / focus / primary). Высота шести
frames bound к `VariableID:36:9 / size/touchTarget=48`; это static examples,
без новых component sets и интерактивного API. Матрица состояний — R3.2–R3.4.

### Типографика и размеры

Предложен **Noto Sans** для кириллицы/латиницы; body и editor спокойные,
ExtraBold только display/принятое написание A. Восемь существующих UI styles
переиспользованы без изменения; добавлен один `StackCard/v2/displayA`,
`S:84ad2dd11edb53de4db05af19f14c77b4797c0af,`, font-size bound к displayA40.
Все 20 прежних styles, включая два wordmark, сохранены.

| **Роль** | **Размер / line px** | **Начертание** | **Shared style** | **Dark / Light text IDs** |
|:---|:---|:---|:---|:---|
| Display | 40 / 48 | ExtraBold | StackCard/v2/displayA, новый | 125:30 / 125:69 |
| Heading | 28 / 33.6 | Bold | StackCard/Cyrillic/headlineMedium | 125:33 / 125:72 |
| Section | 24 / 30 | Bold | StackCard/Cyrillic/headlineSmall | 125:36 / 125:75 |
| Title | 20 / 26 | Bold | StackCard/Cyrillic/titleLarge | 125:39 / 125:78 |
| Body | 16 / 24 | Regular | StackCard/Cyrillic/bodyLarge | 125:42 / 125:81 |
| Secondary | 14 / 21 | Regular | StackCard/Cyrillic/bodyMedium | 125:45 / 125:84 |
| Metadata | 12 / 18 | Regular | StackCard/Cyrillic/bodySmall | 125:48 / 125:87 |
| Control | 16 / 22.4 | SemiBold | StackCard/Cyrillic/titleMedium | 125:51 / 125:90 |
| Label | 14 / 18.2 | Bold | StackCard/Cyrillic/labelLarge | 125:54 / 125:93 |

На каждом mode показаны живые ru/en specimens. В phone-frame390 с padding20
длинная ru подпись имеет ширину350: **125:59 / 125:98**, 16/24, height24;
увеличенный статический пример **125:62 / 125:101**, 32/48, height144,
перенос на три строки. Фиксированная высота текста не используется.
Это вручную увеличенный specimen, не проверка OS text scaling/keyboard/native shaping.

Metrics125:103 переиспользует spacing4/8/12/16/20/24/32/48, radius8/12/16/24,
touchTarget48 и contentMaxWidth600. Это базовые usage rules, а не проверка
всех touch areas/адаптивных экранов. Текущие bundled Noto fonts и SIL OFL1.1
прочитаны в [pubspec](../../apps/mobile/pubspec.yaml) и
[Noto_Sans_OFL.txt](../../apps/mobile/assets/fonts/Noto_Sans_OFL.txt).
Новое семейство, font files и dependencies не добавлены; Figma font не объявлен
byte-identical локальному binary. Финальный шрифт требует приёмки.

### Фактическая проверка и пределы результата

Оба итоговых composition renders просмотрены. Visible overflow/image fills/
unbound text fills — **0**; все texts — Noto Sans. Проверены resolved modes,
alias chains и фактический ближайший непрозрачный фон для **246 text nodes**:
183 на colors и63 на typography; failures0, minimum **4.5853488535:1**.
Независимый read-only расчёт подтвердил исходную contrast matrix.
R3.1 awaiting_review; navigation/cards/badges, поля/stepper и полные states
R3.2–R3.4 ещё todo. Runtime/backend/schema/configs не изменены, prototype и
DESIGN_READY/REDESIGN_DONE не установлены. Flutter tests для Figma/doc-only
работы не запускались; приёмка foundations не подменяет native a11y-проверку.

### Пересмотр foundations и шрифта, D026–D027

**Исторический срез D026–D027.** Пользователь выбрал «Остаться на R3.1 — сначала пересмотреть foundations и
шрифт», D026. R3.1 остаётся `awaiting_review`; R3.2 не разрешена.
Повторно просмотрены оба исходных boards и пересчитаны фактические backgrounds
всех 246 texts: failures0, minimum **4.585348853507275:1**. Палитра и Wordmark A
сохранены. Dark textMuted по-прежнему ограничен background; Light lime получает
Ink outline. Оснований менять эти семантические решения при проверке не найдено.

На той же page121:7 создан [Font Review 138:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=138-19),
**1400×2074**, `R3.1 / Font Review / Unselected`. Это один editable
сравнительный лист, а не новый экран или выбранное семейство.
Три колонки содержат одинаковые имя/роль, русский и английский body, даты,
glyph specimen `Ёё Йй Дд Лл Жж Щщ Il1 O0 0123456789 {} <> @ # + /`
и static CTA48; по два mode-specimens **390×588**, текстовое поле350.

| **Семейство** | **Dark / Light IDs** | **Long-caption16 / 32 IDs** | **Height при 16/24 / 32/48** |
|:---|:---|:---|:---|
| Noto Sans, текущий baseline | 138:27 / 138:38 | 138:52 / 138:54 | 24 / 144 px |
| Manrope, альтернативный кандидат | 138:59 / 138:70 | 138:84 / 138:86 | 24 / 96 px |
| Golos Text, альтернативный кандидат | 138:91 / 138:102 | 138:116 / 138:118 | 24 / 144 px |

Все **48 matched samples** имеют одинаковые тексты, размеры, line-height,
weight и ширину: display40/48 ExtraBold800, heading28/33.6 Bold700,
title20/26 Bold700, body16/24 Regular400, metadata12/18 и13/20,
controls16/22.4 SemiBold600. Отличаются семейство и естественный перенос.
Metadata13 — образец для выбора, базовый meta12 не заменён.
На длинной русской подписи при32 Manrope занимает две строки, остальные — три.
Это один статический fixture, не гарантия меньшей высоты любых экранов.

**Рекомендация для review — Manrope:** в этих specimens геометрические
заголовки выразительнее, body остаётся спокойным. Noto Sans сохраняет
нейтральный baseline, Golos Text — третий сравниваемый вариант.
Это дизайнерская оценка, не решение пользователя и не смена wordmark.
Latin/Cyrillic subsets и OFL1.1 проверены по
[официальным источникам](references.md#шрифты-r31). Figma API подтвердил
Regular/SemiBold/Bold/ExtraBold всех трёх семейств; missing-font failures0.
Лицензия и metadata не доказывают native shaping или byte-identical binaries.

Исходная фиксированная высота новых texts вызвала наложение; она исправлена
на HEIGHT/HUG без изменения размеров шрифта. **Итоговый render после правки
просмотрен:** bounds failures0, fixture mismatches0, все82 texts имеют bound
fills и contrast≥4.5, minimum **4.8329098110002136:1**.
Всего создано102 nodes; components/sets/variables/styles не добавлены.
Все **93 variables и их значения** совпадают с baseline до review;
40 shared text styles и оба исходных boards сохранены.
Новые font files/dependencies/runtime не добавлены. Выбор одного UI-семейства,
приёмка R3.1 и отдельный следующий шаг остаются открытыми.

---

### Закреплённая типографика Manrope, D028

Последующее поручение перейти к следующему этапу принято как приёмка review
R3.1. Для продолжения закреплён рекомендованный Manrope; отдельного сообщения
с названием семейства не было. 244 texts двух foundation boards обновлены;
два Wordmark instance texts и исходные40 styles сохранены. Созданы10 shared
styles с префиксом `StackCard/v2/Manrope/`; размер/line/weight прежних9 ролей
сохранены. Новый `navigationLabel`12/18 SemiBold поддерживает4 постоянные подписи.

| **Роль** | **StyleID, префикс S:** |
|:---|:---|
| displayA | 5c69a84cfb6c7f914e5ea7e293e38453da3ed2c2 |
| heading | 785b7b0fc2e09602baff4f2e94183aaf82c67b77 |
| section | 77eee136a57b096416dfa0af61defa6177e3b44f |
| title | 22de2df69b85117637eaa9c3faa12f2f28cc5cc0 |
| body | 69814583b61be40ade874d855f631363121d119e |
| secondary | 4a6ee253646c7d0f3a4662db841d5e13a350367f |
| metadata | 7905b448a5162790854f3c924725c287574c7e0b |
| control | 8ac920cc9e10d056b3db3e3e0632dd8c4d1bdade |
| label | 51cb8df0f776afc4ff9b82937d5fe0d33174b252 |
| navigationLabel | 81c4c41a63ec9f51ebb83f17943f6e230e8ee5c8 |

В Figma style IDs заканчиваются запятой; таблица хранит ключ без `S:` и запятой.
Display/body/metadata font sizes bound к существующим Metrics. Static32 specimen
теперь переносится на две строки/96px; это всё ещё не OS scaling.
Font Review138:19 сохраняет три исторических семейства; имя/подпись отмечают
Manrope selected. Native fonts/pubspec остаются прежними до R8.

---

## R3.2 — Навигация, карточки и TechnologyBadge

**Статус: `done`, D030; исходный срез D029.** DS page121:7, Manrope, принятый бренд A:
[Navigation and States148:340](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=148-340)
**900×1570**, Dark148:344 / Light148:619;
[Cards and TechnologyBadge148:894](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=148-894)
**900×1565**, Dark148:898 / Light148:1043. Columns390, внутренние карточки350.
В review только instances; main components и license notices находятся отдельно.

### Компоненты, свойства и варианты

Имена начинаются `StackCard/v2/`. TEXT/INSTANCE_SWAP свойства связаны с реальными
дочерними text/instance nodes; variant matrix каждой семьи не превышает12.

| **Компонент / ID** | **Variants и свойства** | **Размер / контракт** |
|:---|:---|:---|
| IconAction144:78 | State=Default/Pressed/Focus; Icon swap | 48×48; gear/back, semantic label при R8 |
| NavItem144:127 | Selected=No/Yes ×3 states; Label TEXT, Icon swap | 87.5×64; постоянная label12/18, underline geometry |
| FilterItem144:148 | Selected=No/Yes ×3 states; Label TEXT | 48h; выбранный check, label16/22.4 |
| CopyAction144:175 | Ready/Pressed/Focus/Copied/Unavailable | 154×48; copy/check+живой текст, причина отсутствия ссылки |
| BottomNavigation146:253 | Active=Home/Resume/Projects/Portfolio | 390×96;4 labels,24px inset — placeholder для native SafeArea |
| SectionHeader146:274 | Mode=Root/Nested; Title TEXT | 390×72; title Fill, root gear / nested Back |
| HomeFilter146:337 | Active=All/Resume/Projects | 350×48; Все/Резюме/Проекты, query без смены root tab |
| DocumentCard146:632 | Kind=Resume/Portfolio × Publication=Published/Draft ×3 states; Title/Summary/Updated TEXT | 350w/Hug; type/icon/summary отличают сущности, недавние выше |
| ProjectCard146:696 | State=Default/Pressed/Focus; Title/Description/Source/Updated TEXT | 350w/Hug; optional CoverSlot, no-cover placeholder, badges/source |
| TechnologyBadge144:180 | single main; Icon swap, Name TEXT | 32h informational; fixed Ink tile24, оригинальный vector18 |
| MoreTechnologies144:198 | single main; Count TEXT | 48×48; +N открывает detail с полным wrapped list |

Всего9 sets/44 variants,2 single components и14 icon mains. Shared Metrics
переиспользуются для spacing/padding/radius; nav marker24×3 и icon grid24/20/18
— фиксированная геометрия. Не созданы поля, stepper или broad states R3.3/R3.4.

### Поведение и handoff

Root header не повторяет огромный брендовый заголовок. Settings — nested:
Back возвращает к сохранённому origin; нижняя вкладка Resume там не активна.
All включает Portfolio, отдельная четвёртая Home filter не добавлена.
Selected получает check/underline, в Light маркер использует `accentText #526B00`.
Pressed отличается заливкой; Focus имеет отдельную2px границу.

У DocumentCard верхний `OpenHitArea` и footer `CopyHitArea` геометрически
разделены. Во всех6 Published variants copy visible; у6 Draft copy скрыт,
показано «Ссылка появится после публикации». Published URL берётся из snapshot,
не из draft. Copied показывается только после настоящего clipboard write;
Figma не симулирует успешный clipboard/native Back или сортировку данных.

ProjectCard показывает сознательный placeholder «Обложка не добавлена», без
декоративных инициалов. Реальный image fill — slot для будущего пользовательского
asset, fixture не имеет фото. Compact list React/TypeScript/+2 и detail wrap
React/TypeScript/Flutter/Dart сохраняют доступный живой текст. Badge32 не button;
+N48 — самостоятельная touch zone. Source TEXT принимает GitHub или ручной источник.

### Assets, темы и фактическая проверка

Lucide mains: home144:19, file-text144:23, folder144:30, panels-top-left144:33,
settings144:38, arrow-left144:42, copy144:46, check144:50, image144:53,
more-horizontal144:58. React144:63 / TypeScript144:66 — точные Simple Icons SVG;
Flutter145:65 / Dart145:70 — официальные белые knockout без изменения shape/fill/opacity.
[Provenance153:6036](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=153-6036)
**1200×1202** хранит источники и полные Lucide ISC/MIT notices;
[license caveats](references.md#иконки-r32) проверены отдельно от project CC0.

Добавлены4 technology variables: primitive144:176 / semantic144:177 React,
primitive144:178 / semantic144:179 TypeScript. Scoped SHAPE_FILL aliases двух
тем, WEB `var(--technology-react)` / `var(--technology-typescript)` — будущий
handoff, не CSS runtime. Всего97 vars/50 text styles; все93 прежних values
сохранены. Фирменные цвета технологий не меняют StackCard palette.
Четыре существующие роли textPrimary/textSecondary/accentText/successText
получили дополнительные SHAPE_FILL/STROKE_COLOR scopes для icons/selection,
с сохранением всех values. Измерены22 technology paint samples, включая
исходную opacity approved knockout: minimum4.4419243488:1, failures0 при пороге3.

Итоговый audit123:7/125:19/148:340/148:894: **410 painted texts ≥4.5**,
minimum **4.5853488535:1**, failures0. Из них164 новых R3.2 texts, все со shared
Manrope styles. 36 painted stroke samples/14 visible selection markers имеют
minimum **5.2824191159:1**. Bounds failures0; все interactive masters ≥48×48;
propertyUnbound0/stylesMissing0. Dark/Light renders просмотрены после исправлений.
Дополнительный audit всех variant masters/single components/provenance:
общая выборка558 texts, contrast/bounds/property bindings/touch targets — PASS.
Это структурная и визуальная проверка390px, не native a11y certification.

R3.2 принята D030; R3.3 принята D032. Ниже добавлены её компоненты
и следующий срез R3.4: state/adapt/motion specimens подготовлены D033,
приняты D034.
Runtime/fonts/assets/backend не переносились. OS scaling, keyboard, native
clipboard/Back/SafeArea и responsive pages проверяются в следующих своих фазах.

---

## R3.3 — Формы, stepper, фото и секции

**Статус: `done`, D032.** R3.2 принята поручением продолжить D030;
её исходное разрешение R3.3 и результаты review D031 приняты новым поручением
перейти к следующему этапу, D032. Page121:7, Manrope/brand A; четыре editable boards:

| **Board / проверенный ID** | **Размер и specimen** |
|:---|:---|
| [Forms163:1334](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=163-1334) | 900×2219; Dark163:1338 / Light163:1340, fields/selection/settings/actions |
| [Editing163:1576](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=163-1576) | 900×2532; Dark163:1580 / Light163:1582, step2/photo/sections/link/add/Save |
| [Keyboard163:2060](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=163-2060) | 900×1193; Dark163:2064 / Light163:2066, fixtures163:2068/163:2101 по390×844 |
| [Scale166:1988](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=166-1988) | 900×1103; fixtures166:1994/166:2016 по390×844, text ×2 и reserved keyboard264h |

Review показывает instances; layout containers связывают их auto-layout.
Scale action bar — отдельная композиция исходных ActionButton instances,
проверяющая измеренные widths; это stress fixture, не новая продуктовая кнопка.
Masters находятся вне review: x200/y8900–13048, icons y8750. Палитра и branding
R2 не менялись. Broad lifecycle/motion и full screens/flows ещё R3.4/R4–R5.

### Формы и общие контролы

| **Компонент / ID** | **Variants / свойства** | **Контракт** |
|:---|:---|:---|
| ActionButton160:1106 | Role=Primary/Secondary/Quiet/Danger × Default/Pressed/Focus/Unavailable =16; Label TEXT | Min48h/Hug, горизонтальные siblings; focus вне Face с neutral gap, причина unavailable у owner |
| TextField160:1157 | Kind=Single/Multiline × Empty/Filled/Focus/Error/Unavailable =10; Label/Value/Helper TEXT | Постоянный label, single min56, multiline min120/Hug; input/error не только цвет |
| SelectField160:1190 | Default/Focus/Error/Unavailable =4; Label/Value/Helper TEXT | Whole control min56, long values wrap; короткий выбор/sheet, helper объясняет отсутствие вариантов |
| SelectionRow160:1266 | Kind=Checkbox/Switch × Selected=No/Yes × Default/Focus/Unavailable =12; Label/Helper TEXT | Whole row min56, marker24 или track40×24 informational внутри hit area; check/knob position |
| SettingsRow160:1313 | Default/Focus/Unavailable =3; Icon SWAP, Label/Value TEXT | Whole row min64; value под label, focused settings group и source/add action |
| StepIndicator160:1279 | Complete/Current/Upcoming =3; Step/Label TEXT | Info mark32; это не32px tap target и не процент готовности документа |
| WizardStepper161:1462 | Active=1..5 =5 | Профиль → Контакты → Опыт/образование → Технологии/проекты → Просмотр; caption выводится из Active |
| PhotoControl161:1564 | Photo=Absent/Selected × Default/Focus/Unavailable =6 | Optional no-photo, choose/replace/delete, отдельный Show photo switch; state copy следует Photo |
| PhotoSourceSheet161:1565 | Single component | Profile/gallery/camera через SettingsRow; cancel не меняет документ, permissions — runtime target |
| CollectionRow161:1850 | Visible=Yes/No × Position=First/Middle/Last =6; Title/Subtitle TEXT, ShowRemove BOOLEAN | Edit48/drag48, «Выше/Ниже»48+; первый/последний элемент объясняет недоступность, visibility относится к документу |
| EditorActionBar161:1872 | Mode=Focused/Wizard =2; Status TEXT | Focused Отмена/Сохранить; Wizard Назад/Пропуск/Дальше, горизонтально48+, Status задаёт owner |

Всего10 sets/67 variants и один source-sheet component; максимальная matrix16.
При выборе варианта Label/Value/Helper/Status получает реальные данные от caller;
Figma TEXT default не заменяет owner state. Step caption и photo state copy
не вынесены в независимые TEXT props, чтобы variant merge не давал неверный шаг
или «Можно без фото» над выбранным портретом. CollectionRow вложенная
SelectionRow сохраняет собственный Label/Helper API; refs не пишутся на sublayer.

Прежние `spacing/*` и `radius/*` связаны с gap/padding/radius; общий новый
Metrics token `size/inputHeight=56` / VariableID160:1057, WIDTH_HEIGHT scope,
WEB `var(--size-input-height)` — design handoff. Multiline120, portrait80,
step32 и switch geometry40×24 фиксированы осознанно. Всего98 vars/50 styles;
все93 исходных variable values сверены с baseline, drift0.

### Keyboard, крупный текст и смысл действий

Focused edit не перезапускает wizard; Back сохраняет working input, необязательный
шаг имеет Skip. Save сохраняет документ локально; Apply меняет working state,
Sync и Publish — отдельные действия. R3.3 не симулирует их успешное выполнение.
«Убрать» удаляет association с документом, не базовый Project/профиль/ссылку.
Новая ссылка открывает форму с именем, URL и типом; публичная почта отделена
от login email/OAuth. Drag и «Выше/Ниже» имеют один смысл; сортировка невозможна
в недоступном направлении. Вариант without-photo не блокирует публикацию.

Keyboard fixture: header72 + viewport394 + Save bar114 + keyboard264 =844;
bar заканчивается на y580, клавиатура начинается y580. Viewport прокручивается
при реализации, fixed toolbar не участвует в этом scroll. Long labels/values
растут по высоте. Здесь есть статический резерв, не работающая системная клавиатура.

Static ×2:12 явных overrides Manrope16→32/14→28/12→24 только внутри Scale board;
normal shared styles не менялись. Focused field337h помещается в viewport427h
с padding20; helper полностью виден. Action bar153h начинается y427 и заканчивается
y580. Подписи «Отмена»120px/«Сохранить»170px измерены в Manrope32; buttons144/198w
с gap8 сохраняют целые слова и соседний горизонтальный уровень. В stress bar
использованы исходные button instances с нужными widths, не detached copies.
Native TextFormField horizontal scroll/caret, keyboard resize/safe area,
scroll-to-focus и TalkBack/VoiceOver остаются проверками R8; Figma wrap URL
не обещает такое же отображение native single-line input.

### Фото, источники и проверка R3.3

Selected state использует обозначенный «Демопортрет · вымышленный человек»:
[PNG](assets/r33-demo-portrait.png), [source/prompt/SHA256](assets/r33-demo-portrait.json).
Новый portrait создан built-in image_gen.imagegen,1254×1254, исходные bytes
сохранены; raster загружен через upload_assets, не network-fetch внутри plugin.
Source rectangle160:1314, imageHashc5809a5c0f968bd8ed1f163a5adfeb2d0b2a077b.
Это visual fixture, не фотография пользователя и не реализованный picker/storage.
Profile/gallery/camera, replace/remove/cancel/permission/persistence входят
в последующие реальные flows и prerequisite media scope; готовность не заявлена.

Шесть новых Lucide mains: camera160:1022, user-round160:1026,
chevron-down160:1030, grip-vertical160:1033, pencil160:1049, plus160:1053.
Точные pinned SVG paths, semantic stroke и полные ISC/MIT notices сохранены;
[источники](references.md#assets-r33), provenance153:6036 расширен до1200×1288.
Check/image переиспользованы из R3.2; runtime assets/dependencies не добавлены.

Финальный audit всех67 variant masters, sheet и четырёх boards: **513 видимых
texts**, minimum **4.8329098110:1**; **103 control/selection strokes**,
minimum **4.3645648113:1**. Contrast/bounds/overlaps/bad property refs/unbound
solid paints/missing normal styles —0. **160 interactive samples ≥48×48**.
12 stress font overrides учитываются отдельно как намеренная проверка ×2.
Все четыре итоговых renders Dark/Light просмотрены; C06/C07/C12/C15 и C16 static
подтверждены на component specimens. Это не native a11y certification.

R3.3 принята D032; R3.4 подготовлена отдельно D033 и принята D034. Полные hi-fi flows,
prototype/runtime, OS text scaling, media permission/persistence и реальная
reorder/Save остаются непроверенными в своих этапах. Flutter/pubspec/Firestore
не менялись; DESIGN_READY/REDESIGN_DONE ещё не установлены.

---

## R3.4 — Состояния, motion и адаптивность

**Статус: `awaiting_review`, D033.** Поручение перейти к следующему этапу
приняло R3.3 и разрешило R3.4, D032. На DS page121:7 созданы четыре editable
boards с Dark/Light specimens. Полные hi-fi screens принадлежат R4–R6;
интерактивный motion-прототип — R7.3, runtime — R8.

| **Board / проверенный ID** | **Размер и mode columns** |
|:---|:---|
| [Data states 176:2036](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2036) | 900×1443; Dark 176:2040 / Light 176:2042 |
| [Save / Sync / Publication 176:2110](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2110) | 900×2019; Dark 176:2114 / Light 176:2116 |
| [Motion / Reduced 176:2214](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2214) | 900×1472; Dark 176:2218 / Light 176:2220 |
| [Adaptive fixtures 176:2418](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2418) | 1808×3619; Dark 176:2422 / Light 176:2424 |

### Состояния и жизненный цикл

| **Component set / ID** | **Variants и контракт** |
|:---|:---|
| [StatePanel 175:2056](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=175-2056) | State=Empty/Loading/Error/Offline/NoResults; пять variants. Empty только после успешного пустого чтения, NoResults только для query/filter projection; Loading без фиктивного процента; Error с явным Retry; Offline не обещает server ACK |
| [LifecycleStatus 175:2101](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=175-2101) | State=Working/Unsaved/Saving/SaveError/LocalSaved/SyncPending/SyncError/Synced/Draft/Publishing/PublishError/Published/Unpublished; тринадцать variants. Local Save, matching server ACK и явный Publish имеют отдельный смысл |

Оба семейства имеют только State variant property: label/title/helper выводятся
из состояния, без независимых TEXT defaults, которые могли бы смешаться
при смене variant. Vertical Hug, wrapping и Fill children сохраняют длинные
подписи. ActionButton и check переиспользованы из R3.2–R3.3; новые icons,
images, text styles или token roles не вводились. Masters расположены отдельно
от review: StatePanel x200/y13600, LifecycleStatus x1800/y13600.

Working, persistence и publication — независимые группы. «Опубликовано» может
сосуществовать с «Есть несохранённые изменения» или «Ожидает синхронизации»:
читатель получает прежнюю публичную версию до следующего успешного Publish.
Preview не означает Save, local Save не означает Synced, Synced не означает
Publish. Старый server ACK не подтверждает новую revision; guest остаётся
local-only. Ошибки/retry и refresh сохраняют working input и предыдущий успех;
refresh-state располагается рядом с успешным контентом. SaveError удерживает
несохранённые правки, Publishing не объявляет успех по таймеру. PublishError
не объявляет успех или сохранность прежней публичной версии при неизвестном
исходе; сначала проверяется статус операции. Unpublished закрывает ссылку
и оставляет draft. Эти правила показаны как DS contract, не как выполненный
backend/clipboard flow.

### Motion и статические equivalents

| **Событие** | **Обычный transition** | **Reduced motion** |
|:---|:---|:---|
| Нажатие | 180ms: заливка pressed; геометрия/hit area стабильны | 0ms: pressed сразу |
| Active item | 180ms: цвет и маркер выбранного пункта | 0ms: label/selected/marker сразу |
| Смена контента | 240ms: opacity без масштабирования | 0ms: новый контент сразу |
| Wizard step | 240ms: opacity; шаг/title/focus меняются сразу | 0ms: шаг, input и ошибки сразу |
| Открытие редактора | 280ms: fade и optional shift ≤8px | 0ms: поля и действия сразу |
| Copy confirmation | 180ms: «Скопировано» и check только после успеха | 0ms: те же подпись/check после успеха |

Existing variables motion/fast=180 и motion/standard=240 сохранены;
motion/slow, VariableID36:13, изменён300→280. Easing:
`cubic-bezier(0.2, 0, 0, 1)`. Значение состояния, focus, валидация и доступность
ввода не ждут transition; исходящий слой не перехватывает ввод. Reduced motion
сохраняет тот же результат без движения. Loading имеет статический текст,
не бесконечный spinner/shimmer как единственное сообщение. В Copy specimen
обычный settled и reduced immediate варианты несут одинаковый feedback.

Board документирует шесть событий и static equivalents. Анимации не
проигрывались; системная reduced-motion preference, реальные clipboard outcome
и screen-reader announcements остаются R7.3/R8.

### Адаптивность и проверка

| **Fixture** | **Dark / Light IDs** |
|:---|:---|
| 320×568 | [176:2427](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2427) / [176:2672](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2672) |
| 390×680 | [176:2488](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2488) / [176:2733](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2733) |
| 430×680 | [177:2646](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=177-2646) / [177:2707](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=177-2707) |
| 768×680 | [176:2549](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2549) / [176:2794](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2794) |
| 844×390 | [176:2610](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2610) / [176:2855](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2855) |

Geometry перестраивается по ширине: content288 на320,350 на390,390 на430
и cap600 на768/844; wide content центрирован. Внутренняя область имеет собственные
padding12, long RU title/EN link переносятся. Четыре подписанные bottom tabs
сохраняются, rail/sidebar отсутствуют. На коротком landscape прокручивается
только content viewport; горизонтальные «Отмена/Сохранить» и navigation
закреплены вне него. Overflow content viewport намеренно clipped; это
спецификация scroll, не работающий scroll-прототип.

Top20/bottom16 обозначают статический резерв SafeArea; реальные device insets
не проверялись. Existing R3.3 keyboard и static×2 specimens переиспользуются
как прежнее evidence. Полный набор продуктовых экранов, OS scaling,
клавиатура и native semantics остаются R7.2/R8.

Финальный audit двух component sets и четырёх boards: **393 text nodes**,
**786 Dark/Light text contrast samples**, minimum
**4.8329098110:1**; **342 control/selection stroke samples**,
minimum **4.3645648113:1**. **96 interactive samples ≥48×48**.
Text/stroke contrast, bounds, unintended overlap, property refs, variable
bindings/scopes, missing styles и fixture checks —0 failures. Intentional
viewport clipping учитывается отдельно. Четыре исходных renders просмотрены;
после расширения повторно просмотрены Lifecycle и оба430 fixtures.

Всего98 variables/50 text styles — прежнее количество. Из93 baseline variables
изменилось только значение motion/slow300→280; palette и Wordmark A сохранены.
C10/C13/C-MOTION подтверждены на static DS specimens. Это не результаты
native Save/sync/publication, доступности screen readers или работы анимаций.

R3.4 подготовлена D033; поручением продолжить всю R4 принята полная R3, D034.
DESIGN_READY ещё не достигнут: необходимы следующие дизайн-фазы и приёмка R7.
Flutter, Firestore, runtime fonts и configs этим шагом не изменены.

---

## R4 — Основные экраны и настройки

D034 приняла R3 и разрешила **всю R4.1–R4.7c одновременно**, без промежуточных
согласований отдельных подпунктов. Сборка использует editable instances общей
R3, Manrope и semantic Dark/Light variables. R5 editors/wizard/full publication
flows и runtime R8 в этот пакет не входят. Итоговый пакет подготовлен и ожидает
приёмки пользователя, `awaiting_review` D035.

Статические экраны имеют viewport 390×844; `projects_narrow` — 320×844. Каждое
состояние представлено в Dark и Light. Captions с демонстрационным характером
данных и runtime-пробелами находятся **вне продуктового viewport**. Screenshots,
показ макетов и запуск приложения пропущены по прямому поручению D034;
структурная проверка не заменяет визуальную или native приёмку.

### Состав и границы R4

| **Задача** | **Базовых состояний / Dark+Light** | **Контракт и покрытие** |
|:---|:---|:---|
| R4.1 / Главная | 7 / 14 | Ровно Все/Резюме/Проекты; mixed recent list, filtered/all empty, retained refresh error/offline; отдельные Open/Copy. Нет dashboard, readiness, hero или глобального поиска |
| R4.2 / Резюме | 7 / 14 | Named role/preview/date/status cards; full/empty/loading/error, create entry, dirty published document и Copy feedback/browser/share. Полный wizard остаётся R5 |
| R4.3 / Проекты | 7 / 14 | Horizontal Import/Create → SearchField с лупой без внешнего label → list; full/empty/no-results/loading/error/offline/narrow. Placeholder, icon+text/+N/wrap; без категорий и hero |
| R4.4 / Портфолио | 7 / 14 | Named multiple list и draft/published/unpublished action menus. Edit/duplicate/publish/unpublish/share представлены как доступные действия; full flows остаются R5 |
| R4.5 / Настройки и профиль | 7 / 14 | Hub пяти групп, отдельные sign out/delete; full/empty optional photo, replacement sources, permission/load failure, taken username и focused skills/experience/education SaveError |
| R4.6 / Контакты и ссылки | 7 / 14 | Public email отдельно от login; optional phone, website/social/custom label+URL; full/empty/add/edit/validation/reorder/delete confirmation. Public selection — доступность для документов |
| R4.7a / Аккаунт | 9 / 18 | Login email/password и действительные provider types; email validation/confirmation, saving, reauth error, Google link failure/last-provider protection, unsaved sign out, delete confirmation/unknown result |
| R4.7b / Приватность | 5 / 10 | Defaults выбранных контактов/location/visitor requests; full/empty/unsaved/saved/save error. Login email/provider/private notes не попадают в public selection |
| R4.7c / Приложение | 5 / 10 | Dark/Light/System, ru/en, notifications/reduced motion; full/changed/saving/error/reduced saved. Theme/locale сохраняются автоматически; feedback при 0 ms сохраняет смысл |

Все четыре roots имеют подписанные нижние вкладки и gear. Nested Settings и
children имеют Back без bottom navigation; возвращение сохраняет origin,
Home filter и scroll. Save/Cancel в формах закреплены вне прокручиваемого
содержимого. Disabled actions имеют причины; validation и failed writes
удерживают ввод. Contacts reorder сохраняет drag и альтернативы Выше/Ниже.

**Публикация:** working changes, durable local Save, matching server ACK и
published snapshot различимы. Publish доступен только для сохранённой версии
с совпадающим ACK; Save/sync её не публикуют. Ссылки опубликованных документов
сохраняются при изменении title/username по D019. Copy имеет отдельную зону и
состояние успеха; draft/closed public access не получают вымышленный URL.
Duplicate создаёт новый private ID без наследования чужой public ссылки.
Portfolio list item имеет отдельную 48 px кнопку «Действия» для открытия меню.

**Пять групп настроек:** Profile редактирует общую базу и optional photo;
Contacts — публичные email/phone/label+URL; Account — private credentials и
providers; Privacy — defaults доступности для новых outputs и обращения;
App — локальные preferences. Изменение базы/defaults не перезаписывает
существующие документы или опубликованные snapshots автоматически. Фото —
прежний обозначенный `generated_demo` R3.3; опыт/образование и example.com/org
адреса иллюстративны. Google provider не является public link, GitHub link
не является импортом.

Текущий singleton draft, plain-text Resume и существующий username-based
publication adapter ещё требуют multiple-output/contact/URL migration.
Provider management, coordinated deletion, privacy/visitor requests,
notification permissions и reduced-motion integration остаются target gaps;
эти макеты не заявляют работающий backend. Неизвестный исход опасного действия
требует проверки статуса и не выдаётся за успешное удаление или сохранность.

### Реестр экранов R4

Page [184:2785](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=184-2785) — `StackCard Design v2 / Screens`: **61 состояния / 122 phone frames**.
IDs взяты из завершённой editable-сборки; название и state соответствуют source specs.
Все frames 390×844, кроме пары `projects_narrow` 320×844. Gap относится к runtime,
а не к отсутствию статического макета.

| **Задача / ключ** | **Экран · состояние** | **Dark** | **Light** | **Граница target** |
|:---|:---|:---|:---|:---|
| R4.1 / `h01_all` | Главная · `all_full` | [186:13](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-13) | [186:340](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-340) | Mixed library/filter/clipboard/URL — target |
| R4.1 / `h02_resumes` | Главная · `resume_full` | [186:514](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-514) | [186:642](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-642) | Mixed library/filter/clipboard/URL — target |
| R4.1 / `h03_projects` | Главная · `projects_full` | [186:751](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-751) | [186:891](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-891) | Mixed library/filter/clipboard/URL — target |
| R4.1 / `h04_resume_empty` | Главная · `resume_empty` | [186:1023](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-1023) | [186:1090](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-1090) | Mixed library/filter/clipboard/URL — target |
| R4.1 / `h05_all_empty` | Главная · `all_empty` | [186:1155](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-1155) | [186:1220](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-1220) | Mixed library/filter/clipboard/URL — target |
| R4.1 / `h06_refresh_error` | Главная · `refresh_error` | [186:1285](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-1285) | [186:1448](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-1448) | Mixed library/filter/clipboard/URL — target |
| R4.1 / `h07_offline` | Главная · `offline` | [186:1609](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-1609) | [186:1698](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-1698) | Mixed library/filter/clipboard/URL — target |
| R4.2 / `r01_full` | Резюме · `full` | [187:1346](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1346) | [187:1480](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1480) | Resume route/records/share/URL — target |
| R4.2 / `r02_empty` | Резюме · `empty` | [187:1582](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1582) | [187:1639](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1639) | Resume route/records/share/URL — target |
| R4.2 / `r03_loading` | Резюме · `initial_loading` | [187:1696](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1696) | [187:1751](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1751) | Resume route/records/share/URL — target |
| R4.2 / `r04_error_retained` | Резюме · `refresh_error` | [187:1806](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1806) | [187:1885](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1885) | Resume route/records/share/URL — target |
| R4.2 / `r05_create_entry` | Создать резюме · `create_entry` | [187:1964](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1964) | [187:1997](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1997) | Resume route/records/share/URL — target |
| R4.2 / `r06_published_changed` | Резюме · `published_changed` | [187:2026](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2026) | [187:2100](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2100) | Resume route/records/share/URL — target |
| R4.2 / `r07_copy_confirmed` | Резюме · `copy_confirmed` | [187:2174](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2174) | [187:2260](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2260) | Resume route/records/share/URL — target |
| R4.3 / `projects_full` | Проекты · `Full` | [187:2348](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2348) | [187:2619](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2619) | Новый UI/search/clipboard — R8; import/editor flows — R5 |
| R4.3 / `projects_empty` | Проекты · `Empty` | [187:2832](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2832) | [187:2898](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2898) | Новый UI/search/clipboard — R8; import/editor flows — R5 |
| R4.3 / `projects_no_results` | Проекты · `NoResults` | [187:2964](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2964) | [187:3035](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3035) | Новый UI/search/clipboard — R8; import/editor flows — R5 |
| R4.3 / `projects_loading` | Проекты · `Loading` | [187:3101](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3101) | [187:3164](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3164) | Новый UI/search/clipboard — R8; import/editor flows — R5 |
| R4.3 / `projects_error` | Проекты · `Error` | [187:3227](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3227) | [187:3364](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3364) | Новый UI/search/clipboard — R8; import/editor flows — R5 |
| R4.3 / `projects_offline` | Проекты · `Offline` | [187:3501](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3501) | [187:3638](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3638) | Новый UI/search/clipboard — R8; import/editor flows — R5 |
| R4.3 / `projects_narrow` | Проекты · `Narrow` | [187:3775](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3775) | [187:3905](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-3905) | Новый UI/search/clipboard — R8; import/editor flows — R5 |
| R4.4 / `portfolios_full` | Портфолио · `Full` | [187:11631](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11631) | [187:11727](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11727) | Multiple Portfolio/actions/URL — target |
| R4.4 / `portfolios_empty` | Портфолио · `Empty` | [187:11818](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11818) | [187:11875](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11875) | Multiple Portfolio/actions/URL — target |
| R4.4 / `portfolios_loading` | Портфолио · `Loading` | [187:11932](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11932) | [187:11986](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11986) | Multiple Portfolio/actions/URL — target |
| R4.4 / `portfolios_error` | Портфолио · `Error` | [187:12040](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12040) | [187:12117](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12117) | Multiple Portfolio/actions/URL — target |
| R4.4 / `portfolio_draft_actions` | Действия портфолио · `DraftPending` | [187:12194](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12194) | [187:12235](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12235) | Multiple Portfolio/actions/URL — target |
| R4.4 / `portfolio_published_actions` | Действия портфолио · `Published` | [187:12276](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12276) | [187:12330](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12330) | Multiple Portfolio/actions/URL — target |
| R4.4 / `portfolio_unpublished_actions` | Действия портфолио · `Unpublished` | [187:12384](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12384) | [187:12426](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12426) | Multiple Portfolio/actions/URL — target |
| R4.5 / `settings_hub` | Настройки · `full` | [187:12472](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12472) | [187:12568](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12568) | Общая база/media/rename migration — target |
| R4.5 / `profile_full` | Профиль · `full` | [187:12664](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12664) | [187:12787](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12787) | Общая база/media/rename migration — target |
| R4.5 / `profile_empty` | Профиль · `empty_no_photo` | [187:12910](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12910) | [187:13023](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13023) | Общая база/media/rename migration — target |
| R4.5 / `profile_photo_sources` | Фото профиля · `replace_sources` | [187:13136](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13136) | [187:13223](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13223) | Общая база/media/rename migration — target |
| R4.5 / `profile_photo_permission` | Фото профиля · `permission_load_error` | [187:13310](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13310) | [187:13368](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13368) | Общая база/media/rename migration — target |
| R4.5 / `profile_username_taken` | Профиль · `taken_username_unsaved` | [187:13426](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13426) | [187:13478](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13478) | Общая база/media/rename migration — target |
| R4.5 / `profile_qualifications` | Навыки и опыт · `save_error_qualifications` | [187:13530](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13530) | [187:13622](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13622) | Общая база/media/rename migration — target |
| R4.6 / `contacts-full` | Контакты и ссылки · `full` | [187:13718](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13718) | [187:13853](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13853) | Public contacts/owner base/selections — target |
| R4.6 / `contacts-empty` | Контакты и ссылки · `empty` | [187:13988](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13988) | [187:14021](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14021) | Public contacts/owner base/selections — target |
| R4.6 / `contacts-add` | Добавить ссылку · `add` | [187:14054](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14054) | [187:14097](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14097) | Public contacts/owner base/selections — target |
| R4.6 / `contacts-edit` | Изменить ссылку · `edit` | [187:14140](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14140) | [187:14184](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14184) | Public contacts/owner base/selections — target |
| R4.6 / `contacts-validation` | Добавить ссылку · `validation` | [187:14228](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14228) | [187:14271](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14271) | Public contacts/owner base/selections — target |
| R4.6 / `contacts-reorder` | Порядок ссылок · `reorder` | [187:14314](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14314) | [187:14454](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14454) | Public contacts/owner base/selections — target |
| R4.6 / `contacts-remove` | Удалить ссылку · `remove_confirmation` | [187:14590](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14590) | [187:14620](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14620) | Public contacts/owner base/selections — target |
| R4.7a / `account_overview_success` | Аккаунт · `full_success` | [187:14654](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14654) | [187:14736](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14736) | Provider/account management/delete — target |
| R4.7a / `account_email_validation` | Почта для входа · `validation` | [187:14818](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14818) | [187:14854](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14854) | Provider/account management/delete — target |
| R4.7a / `account_email_confirmation` | Подтверждение почты · `confirmation_pending` | [187:14890](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14890) | [187:14935](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14935) | Provider/account management/delete — target |
| R4.7a / `account_password_saving` | Пароль · `saving` | [187:14980](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14980) | [187:15023](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15023) | Provider/account management/delete — target |
| R4.7a / `account_reauthentication_error` | Подтвердите вход · `reauthentication_error` | [187:15066](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15066) | [187:15105](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15105) | Provider/account management/delete — target |
| R4.7a / `account_google_link_error_last_method` | Способы входа · `link_error_last_method` | [187:15144](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15144) | [187:15175](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15175) | Provider/account management/delete — target |
| R4.7a / `account_signout_unsaved` | Выход из аккаунта · `unsaved_confirmation` | [187:15206](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15206) | [187:15241](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15241) | Provider/account management/delete — target |
| R4.7a / `account_delete_confirmation` | Удаление аккаунта · `delete_confirmation` | [187:15276](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15276) | [187:15316](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15316) | Provider/account management/delete — target |
| R4.7a / `account_delete_result_unknown` | Удаление аккаунта · `delete_unknown` | [187:15356](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15356) | [187:15379](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15379) | Provider/account management/delete — target |
| R4.7b / `privacy-full` | Приватность · `full` | [187:15406](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15406) | [187:15466](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15466) | Privacy storage/visitor requests — target |
| R4.7b / `privacy-empty` | Приватность · `empty_contacts` | [187:15526](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15526) | [187:15571](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15571) | Privacy storage/visitor requests — target |
| R4.7b / `privacy-changed` | Приватность · `unsaved` | [187:15616](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15616) | [187:15679](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15679) | Privacy storage/visitor requests — target |
| R4.7b / `privacy-saved` | Приватность · `saved` | [187:15742](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15742) | [187:15803](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15803) | Privacy storage/visitor requests — target |
| R4.7b / `privacy-save-error` | Приватность · `save_error` | [187:15864](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15864) | [187:15934](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15934) | Privacy storage/visitor requests — target |
| R4.7c / `app-full` | Приложение · `full` | [187:16008](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16008) | [187:16064](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16064) | UI перенос; notifications/reduced — target |
| R4.7c / `app-changed` | Приложение · `changed` | [187:16120](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16120) | [187:16176](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16176) | UI перенос; notifications/reduced — target |
| R4.7c / `app-saving` | Приложение · `saving` | [187:16232](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16232) | [187:16289](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16289) | UI перенос; notifications/reduced — target |
| R4.7c / `app-save-error` | Приложение · `save_error` | [187:16346](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16346) | [187:16412](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16412) | UI перенос; notifications/reduced — target |
| R4.7c / `app-reduced-saved` | Приложение · `reduced_motion_saved` | [187:16478](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16478) | [187:16535](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16535) | UI перенос; notifications/reduced — target |

### Проверки и ограничения R4

Полный static QA R4 — **PASS**: 122 phone frames / 61 Dark+Light pair,
7902 editable nodes, 2074 text contrast samples с minimum **4.739519898:1**;
1446 control/selection stroke samples с minimum **4.364564811:1**;
840 interactive samples **≥48×48**. Все 17 групп проверок имеют 0 failures:
contrast/styles/Manrope, paint bindings/scopes, bounds/overlap, touch,
property references, screen/nav/Home/Projects contracts и Dark/Light pairing.
Intentional scroll viewport clipping учитывается отдельно.

Сохранены значения 98 variables и IDs 50 text styles. Единственное расширение
scope — `color/onPrimary` разрешён также для `STROKE_COLOR`; palette values
не менялись. 70 fixed SVG brand paints Flutter/Dart — явные исключения из
semantic paint binding. Raster содержимое ограничено 6 экземплярами прежнего
80×80 `generated_demo` портрета; UI собран editable text/vector/instances.

**До первого Project:** в 390×844 full варианте первая карточка начинается
на y252 и заканчивается на y675, до нижней границы content viewport y746.
В 320×844 narrow её начало y273, конец y816: начало/название доступны без
прокрутки, нижние детали требуют scroll. Horizontal Import/Create и unlabeled
search с лупой сохраняются в обеих темах; первый Project не скрыт за hero.

Эти числа относятся к R4, а прежние R3.4 результаты сохранены отдельно.
Визуальный просмотр/рендеры, запуск приложения и native walkthrough пропущены
по прямому поручению D034. Runtime routing/filtering/clipboard/media,
Save/sync/Publish/provider/delete/OS behavior ими не доказаны. Playable prototype
и DESIGN_READY остаются R7. **R4.1–R4.7c и вся R4 — `awaiting_review`, D035**;
следующая R5 требует отдельного поручения.

---

## R5 — Создание, редактирование и публикация

Поручение продолжить после R4 принято как её приёмка и разрешение **всей
R5.1a–R5.4c**, D036. Пакет сохраняет Manrope, принятый бренд A и editable
instances общей DS. Текущий статус — `in_progress`: реальные node IDs,
числа и результаты проверки публикуются только после завершённой сборки.
Прежний срез R4/D035 и его 122 phone IDs выше сохранён как история.

Сценарии предусматривают nested 390×844 screens с Back и возвращением к
captured origin, без bottom navigation. Поля, selection, section controls и
fixed footer отделены от прокручиваемого содержимого. Демонстрационные данные
и runtime-пробелы отмечаются в captions **вне продуктового viewport**.
Визуальный просмотр, preview и запуск приложения пропускаются в сохранённом
режиме D034/D036; static frames не считаются playable prototype.

### Состав и границы R5

| **Задача** | **Контракт и обязательные состояния** |
|:---|:---|
| R5.1a / Resume: профиль и контакты | Wizard Steps1–2, предложения базового Profile и документные overrides; optional photo/no-photo, selected public contacts, Back/Skip, denied/retry без потери ввода |
| R5.1b / Resume: опыт, технологии и проекты | Steps3–4: опыт/образование/technologies/global Project selection, empty и optional skip; icon+label/wrap без вымышленных достижений или skill levels |
| R5.1c / Resume: focused editor | Список секций, отдельная правка без повторного wizard, document-local overrides и явный review Profile diff; Save/Cancel и сохранность текущего ввода |
| R5.1d / Resume: preview | Step5 и структурированный одно-column preview с выбранным фото, no-photo и длинным содержимым; пустые секции скрыты, переход к отдельному Publish |
| R5.2a / Ручной Project | Global create/edit со stable ID, no-cover placeholder, icon+text technologies; blank title/URL validation, media failure, local Save error и unsaved exit; без association-owned featured/visible в global форме |
| R5.2b / GitHub Import | Выбор repositories, already imported и dedup по stable repository ID; pagination/cache/rate/empty/error с удержанием selection, explicit Add и отдельный Save |
| R5.2c / GitHub Review | Source/curated diff, сохранённые ручные overrides, explicit Accept/Ignore/Cancel; stale source/owner блокирует старый apply, после mutation нужен отдельный Save |
| R5.3a / Portfolio: создание и editor | Named private Portfolio из предложения Profile; content/appearance/preview раздельны, validation/Save/Cancel, несколько outputs вместо singleton preview |
| R5.3b / Portfolio: Project attachments | Add existing либо create global+attach; порядок, visible/featured принадлежат связи; remove relation сохраняет global Project, drag имеет альтернативы Выше/Ниже |
| R5.3c / Portfolio: секции и оформление | Focused section edit, show/hide/order, ограниченные layout/accent/photo controls; full/no-photo readable preview, без трёх узких панелей или свободного canvas |
| R5.4a / Публикация | Working/Unsaved, durable local Save, pending/error, matching server ACK и Published различимы; first/update Publish explicit, unknown result требует status reconciliation |
| R5.4b / Ссылка и sharing | Постоянные Copy/Open/Share после re-open опубликованного документа; отдельные hit areas и Copied только после clipboard write, draft предлагает Publish без фиктивной ссылки |
| R5.4c / Опасные действия и адреса | Unpublish/delete/duplicate/rename confirmations, unknown outcomes без ложного success; stable document URL при rename, duplicate новый private ID без inherited publication/link, сохранность общей библиотеки и связей |

**Сохранение и публикация:** изменение формы/Apply не равно durable Save.
Local Save завершает запись captured revision; Synced требует matching server
ACK этой же версии. Старый ACK не подтверждает новый ввод. Publish доступен
только для текущей сохранённой и подтверждённой версии и обновляет public
snapshot отдельным явным действием. Редактирование, local Save и sync не
изменяют уже опубликованный snapshot. Неизвестный Publish/Unpublish/delete
outcome требует сверки статуса до утверждения результата.

**База и документы:** Profile suggestions не перезаписывают существующие
outputs без review; локальные overrides сохраняются. Resume/Portfolio используют
selected public contacts, не login email, providers или private notes. Project
живёт в общей библиотеке; order/visible/featured и remove из Portfolio относятся
к attachment. Включённое Resume может быть частным в owner preview, но его
public link требует собственной публикации.

**Постоянные ссылки:** демонстрационные `example.com/d/r_7f4c` и
`example.com/d/p_8a2e` показывают document-owned адрес по D019. Rename документа
или username не меняет его адрес; republish использует прежний адрес.
Duplicate создаёт новый private документ и не наследует public URL/status.
Макеты не утверждают, что текущий username adapter уже поддерживает эту схему.

### Реестр экранов R5

Реальные ссылки на boards и пары Dark/Light будут добавлены из фактического
ledger завершённой сборки. До этого node IDs, количество созданных screens и
успешная проверка здесь не заявлены.

### Проверки и ограничения R5

Финальная структурная проверка должна подтвердить requirement coverage,
Dark/Light pairing, Manrope/styles, semantic paints, contrast, bounds/overlap,
≥48×48 interactive areas, fixed Save/Cancel/step footer, отсутствие вымышленных
фактов и разделение global/association/publication. Пока результат не получен,
PASS и пользовательская готовность не установлены.

Current runtime сохраняет singleton content, plain-text Resume, legacy global
Project flags и username-based publication adapter. Multiple-output/contact/URL
migration, document-local overrides/attachments, Project cover/media,
provider/storage/controller integration и реальные anonymous pages остаются
предпосылками переноса R8. GitHub source/cache/review и local/sync contracts
существуют отдельно от нового Figma UI; их наличие не подтверждает новый
end-to-end flow. Native keyboard/SafeArea, caret/scroll-to-focus, OS text scale,
TalkBack/VoiceOver, clipboard/share/browser/permissions и unknown-outcome
recovery требуют реальной приёмки. Playable prototype и DESIGN_READY — R7;
web R6, runtime R8 и Git mutations этим пакетом не выполняются.

---

## Переходы и действия

| **Сценарий** | **Последовательность и сохранность** |
|:---|:---|
| Настройки | Любой root → gear → Settings → нужная группа → Back → исходный root с прежним фильтром/scroll; без активного Resume |
| Общая база → Resume | Settings/Profile → изменить базу → Resumes/Create → предложить профиль → пять шагов → Preview → explicit Publish |
| Wizard | Профиль с фото → контакты → опыт+образование → технологии+проекты → preview+publish; skip optional, previous step сохраняет данные |
| Правка готового Resume | Карточка → документ → конкретная секция → сохранить → preview; повторное прохождение wizard не требуется |
| Project вручную | Projects/Create → форма → сохранить Project → library; создать из Portfolio → тот же Project + attachment |
| GitHub | Projects/Import → выбрать repositories → Add → явный Save; повторный import не дублирует repository ID |
| Review GitHub | Project/Changes → diff → Accept/Ignore/Cancel; ручные описания и published snapshot не меняются молча |
| Portfolio | Portfolios/Create → базовые данные → проекты из library или create+attach → секции → appearance → Preview → Publish |
| Убрать Project из Portfolio | Attachment action → убрать связь → Project остаётся в library и других outputs; global delete — другое действие |
| Изменить базовый профиль | Предложить diff существующему Resume/Portfolio → явное применение → сохранить draft → отдельное обновление публикации |
| Повторная ссылка | Published card и document → Copy с подтверждением либо Open/Share; открытие карточки и Copy имеют разные hit areas |
| Unpublish | Подтверждение → backend outcome → статус unpublished; посетитель видит недоступный документ, draft сохраняется |
| Не сохранён ввод | Back/Close → ясное решение сохранить/оставить/отбросить согласно согласованному сценарию; ошибки удерживают ввод |
| Web посетитель/owner | Landing → auth → workspace → preview → publish → public URL; anonymous public view не открывает editor |

В R1 уточняются информационные переходы и минимальный набор low-fi. Эти
последовательности не являются новыми реализованными функциями. Guest сохраняет
local-only поведение; право публикации определяется настоящим auth/backend contract.

---

## Состояния и компоненты

| **Область** | **Минимальная матрица будущего дизайна** |
|:---|:---|
| Все private roots | Full, empty, loading, error+Retry, offline/cached, long names/URLs, text scale, theme/locale |
| Home | Все/Резюме/Проекты; empty выбранного фильтра, mixed types и recent order; нет global search/readiness/greeting |
| Projects | Нет проектов, no results, import loading/error/rate limit, already imported, refresh/page failure, no cover |
| Фото | Profile photo, gallery/camera selection, replace/remove, без фото, permission denial/recovery, load/upload failure |
| Editors | Empty optional section, validation, unsaved, saving, locally saved, pending sync, synced, sync error, remote change/conflict |
| Resume | Каждый из пяти шагов, skip, Back с вводом, прямое редактирование секции, selected/hidden/overridden fields |
| Settings | Invalid/taken username, rename consequences, email verification, reauth, provider error, last-provider denial, save success/failure |
| Publication/share | Draft без ссылки, first publish, dirty published draft, pending/error/success, repeat Copy, unpublish, deleted/not found |
| Public | Published, absent/unpublished, loading/error, long content, no photo; никаких private fields/account settings |
| Responsive/motion | 390 и узкий/большой телефон, tablet/landscape, SafeArea/keyboard, scale 1/2; reduced-motion static variants |

Рабочие состояния уже представлены в existing
[AsyncView](../../apps/mobile/lib/shared/widgets/stackcard_async_view.dart),
[StateView](../../apps/mobile/lib/shared/widgets/stackcard_states.dart),
[Button](../../apps/mobile/lib/shared/widgets/stackcard_button.dart) и draft/sync
contracts. В R3 проектируются новые variants; в R8 адаптируются существующие
механизмы theme/shared widgets, без параллельной runtime-библиотеки.

TechnologyBadge — планируемый доступный icon+text компонент: compact несколько
badges и +N, detail полный набор wrap, неизвестная технология с текстом и
нейтральной иконкой. Reorder имеет drag handle и альтернативу Выше/Ниже.
PhotoField не требует фото для публикации. Toast копирования сообщает
результат, не подменяет публикацию.

---

## Реестр Figma

В R0 проверены существующие IDs через MCP metadata; визуально просмотрены
Home/Settings/Projects новой прежней итерации и legacy landing/public Portfolio.
Остальные записи ниже — проверенная структура, не полная визуальная приёмка.

| **Материал** | **Проверенная существующая ссылка и статус** |
|:---|:---|
| Legacy mobile dark/light | [2:100](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-100), [2:101](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-101), история |
| Прежние пять dark roots | [Home 38:3901](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3901), [Resume 38:3902](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3902), [Projects 38:3903](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3903), [Portfolios 38:3904](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3904), [Settings 38:3905](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=38-3905); не Design v2 |
| Прежняя light итерация | [Home 44:474](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=44-474), [Settings 44:852](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=44-852), структура проверена |
| Tablet legacy | [2:102](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-102), восемь существующих frames; новый tablet не принят |
| Website concepts | [Desktop 2:103](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-103), [Mobile 2:104](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-104); legacy, backend отсутствует |
| Legacy landing/public | [Landing 9:2](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=9-2), [Portfolio 9:535](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=9-535); renders просмотрены |
| Components/states | [2:99](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-99), [Specimen 43:1069](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=43-1069), [States 2:105](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=2-105), структура проверена |
| Design v2 / UX / IA / Navigation | [58:8](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-8), editable Auto Layout, 1600×1529; R1.1 done, D013 |
| Design v2 / UX / IA / Ownership | [58:41](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-41), editable Auto Layout, 1600×1814; R1.1 done, D013 |
| Design v2 / UX / IA / Lifecycle and walkthrough | [58:75](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-75), editable Auto Layout, 1600×1683; R1.1 done, D013 |
| Design v2 / UX / R1.2 / Roots and Settings | [61:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-7), восемь editable phone frames; done, D015 |
| Design v2 / UX / R1.2 / Profile to Document | [61:491](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-491), восемь editable phone frames; done, D015 |
| Design v2 / UX / R1.2 / Errors and Settings Groups | [61:833](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-833), восемь editable phone frames; done, D015 |
| Design v2 / UX / R1.3 / Resume Wizard | [72:537](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-537), восемь editable phone frames; done, D017 |
| Design v2 / UX / R1.3 / Optional Photo and Back | [72:941](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-941), восемь editable phone frames; done, D017 |
| Design v2 / UX / R1.3 / Section Editing and Save | [72:1242](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1242), восемь editable phone frames; done, D017 |
| UX / R1.3 / ResumeDocument low-fi | [72:521](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-521), main с Show photo/Headline и 15 descendants; не DS R3 |
| Design v2 / UX / R1.4 / Manual Projects | [78:1012](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1012), восемь editable phone frames; done, D020 |
| Design v2 / UX / R1.4 / GitHub Import and Review | [78:1013](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1013), восемь editable phone frames; done, D020 |
| Design v2 / UX / R1.4 / Portfolio and Attachments | [78:1014](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1014), восемь editable phone frames; done, D020 |
| Design v2 / UX / R1.4 / Publication Lifecycle | [78:1015](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1015), восемь editable phone frames; done, D020 |
| Design v2 / UX / R1.4 / Access Links and Recovery | [78:1016](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1016), восемь editable phone frames; done, D020; URL D019 |
| UX / R1.4 / PortfolioDocument low-fi | [79:1012](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=79-1012), main с Show photo/Show Resume link и 27 descendants; не DS R3 |
| Design v2 / Directions / R2.1 / Comparison | [99:8](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=99-8), 1400×2297; A 99:10 / B 99:11, шесть пилотов; сравнение принято D022, выбор бренда A и основа R3 — D024 |
| Directions / R2.1 / Experimental mains | 100:10 / 100:13 marks, 100:16 / 100:30 DocumentCards, 104:266 ProjectCard B; editable components вне comparison wrapper, не финальная DS R3 |
| Design v2 / Directions / R2.2 / Brand Comparison | [110:268](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=110-268), 1400×1992; A 110:274 / B 110:275; done D024, принят бренд A |
| Directions / Selected A brand families | StackCard / v2 / Mark110:282, Wordmark111:284, AppIcon111:297; девять variants, прежние IDs; B110:289/111:314/111:327 сохранён как история, native exports pending |
| Design v2 / DS / R3.1 / Foundations | Page121:7; [123:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=123-7),1400×1657; Dark123:13/Light123:22; Manrope/brand A, done D028 |
| Design v2 / DS / R3.1 / Typography and Metrics | [125:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=125-19),1400×1423; Dark125:25/Light125:64; Manrope9 core roles + navigationLabel shared style, done D028 |
| Design v2 / DS / R3.1 / Font Review | [138:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=138-19); historical Noto/Manrope/Golos specimens сохранены, выбран рекомендованный Manrope D028 |
| Design v2 / DS / R3.2 / Navigation and States | [148:340](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=148-340),900×1570; Dark148:344/Light148:619, done D030 |
| Design v2 / DS / R3.2 / Cards and TechnologyBadge | [148:894](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=148-894),900×1565; Dark148:898/Light148:1043, done D030 |
| Design v2 / DS / R3.2 / Asset provenance | [153:6036](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=153-6036),1200×1288 после R3.3; source links + full Lucide ISC/MIT notices/generated_demo provenance |
| Design v2 / DS / R3.3 / Forms and Selection | [163:1334](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=163-1334),900×2219, Dark163:1338/Light163:1340; done D032 |
| Design v2 / DS / R3.3 / Stepper Photo and Sections | [163:1576](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=163-1576),900×2532, Dark163:1580/Light163:1582; done D032 |
| Design v2 / DS / R3.3 / Keyboard and Long Labels | [163:2060](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=163-2060),900×1193; fixtures390×844; done D032 |
| Design v2 / DS / R3.3 / Static text scale2 | [166:1988](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=166-1988),900×1103; Manrope ×2 stress, not OS scaling; done D032 |
| Design v2 / DS / R3.4 / Data states | [176:2036](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2036); 900×1443, Dark 176:2040 / Light 176:2042; подготовлены D033, done D034 |
| Design v2 / DS / R3.4 / Save / Sync / Publication | [176:2110](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2110); 900×2019, Dark 176:2114 / Light 176:2116; подготовлены D033, done D034 |
| Design v2 / DS / R3.4 / Motion / Reduced | [176:2214](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2214); 900×1472, Dark 176:2218 / Light 176:2220; подготовлены D033, done D034 |
| Design v2 / DS / R3.4 / Adaptive fixtures | [176:2418](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2418); 1808×3619, Dark 176:2422 / Light 176:2424; подготовлены D033, done D034 |
| Design v2 / Screens / R4.1 / Главная | [186:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-7); 7 states /14 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| Design v2 / Screens / R4.2 / Резюме | [187:1340](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1340); 7 states /14 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| Design v2 / Screens / R4.3 / Проекты | [187:2342](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2342); 7 states /14 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| Design v2 / Screens / R4.4 / Портфолио | [187:11625](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11625); 7 states /14 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| Design v2 / Screens / R4.5 / Настройки и базовый профиль | [187:12466](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12466); 7 states /14 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| Design v2 / Screens / R4.6 / Контакты и ссылки | [187:13712](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13712); 7 states /14 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| Design v2 / Screens / R4.7a / Аккаунт и безопасность | [187:14648](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14648); 9 states /18 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| Design v2 / Screens / R4.7b / Приватность | [187:15400](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15400); 5 states /10 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| Design v2 / Screens / R4.7c / Приложение | [187:16002](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16002); 5 states /10 Dark+Light phone frames; [все ключи и IDs](#реестр-экранов-r4); awaiting_review D035 |
| DS / R4 shared extensions | Search SVG [184:2762](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=184-2762); SearchField [184:2784](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=184-2784) с Empty/Filled/Focus; compact list ProjectCard [185:2771](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=185-2771); PortfolioListItem [188:2861](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=188-2861), Published 188:2817 / Draft 188:2841 с отдельным entry «Действия» 48 px. Прежние R3 families сохранены; standalone SVG provenance в references |
| Остальные Design v2 frames | Full editor/wizard/publication R5, web R6 и проверяемый prototype R7 остаются планом; DESIGN_READY ещё не достигнут |

Prototype reactions старой итерации не приняты и полностью не прогонялись в R0.
Публичного Resume среди перечисленных top-level legacy web frames не найдено;
карточка Resume в предыдущей итерации не заменяет финальный документный frame.
