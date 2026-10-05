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
- [Переходы и действия](#переходы-и-действия)
- [Состояния и компоненты](#состояния-и-компоненты)
- [Реестр Figma](#реестр-figma)

---

## Как читать карту

Срез R0 — 2026-10-05, статический аудит; далее добавлены результаты R1.1–R1.4
и шесть визуальных пилотов R2.1, brand specimens R2.2, выбор A в R2.3
и Dark/Light foundations R3.1.
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

Hi-fi и реализация новых экранов имеют статус `todo`. Их предлагаемая Figma-область —
`StackCard Design v2 / Mobile` либо `/ Web`; это имена будущих frames, не IDs.
Реальные low-fi R1.2–R1.4 находятся на `/ UX` и перечислены ниже.

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
R1.4 принята после цветовых правок D020; R2 `done` D024, R3.1 `awaiting_review` D025;
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
Сравнение R2.1 принято D022; бренд A и R2 приняты D024; R3.1 awaiting_review D025; runtime не перенесён.

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

R1.1–R1.4 done, D020; R2 done D024, R3.1 awaiting_review D025. Runtime не перенесён,
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

**Статус: `awaiting_review`, D025.** Page **121:7 / StackCard Design v2 / DS**:
[Foundations 123:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=123-7)
**1400×1657**, Dark123:13 / Light123:22;
[Typography and Metrics 125:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=125-19)
**1400×1471**, Dark125:25 / Light125:64. Editable Auto Layout и живой текст.
Foundations используют принятый Wordmark A, без новых logo variants.

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
| Design v2 / DS / R3.1 / Foundations | Page121:7; [123:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=123-7), 1400×1657, Dark123:13 / Light123:22; colors/contrast/boundaries, awaiting_review D025 |
| Design v2 / DS / R3.1 / Typography and Metrics | [125:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=125-19), 1400×1471, Dark125:25 / Light125:64; nine type roles, static16/32 reflow, awaiting_review D025 |
| Финальные Design v2 frames | Ещё не созданы; IDs, variant/state и evidence добавляются после R4–R7, без подстановки legacy ссылок |

Prototype reactions старой итерации не приняты и полностью не прогонялись в R0.
Публичного Resume среди перечисленных top-level legacy web frames не найдено;
карточка Resume в предыдущей итерации не заменяет финальный документный frame.
