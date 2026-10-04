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
- [Переходы и действия](#переходы-и-действия)
- [Состояния и компоненты](#состояния-и-компоненты)
- [Реестр Figma](#реестр-figma)

---

## Как читать карту

Срез — 2026-10-05, только статический аудит. `S-*` — ID целевого экрана, а не
реализованный route. Новые route paths и Figma frame IDs не назначены; конкретные
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

Все новые экраны имеют статус `todo`. Их предлагаемая Figma-область —
`StackCard Design v2 / Mobile` либо `/ Web`; это имена будущих frames, не IDs.

| **ID и экран** | **Контракт, requirements, компоненты и задача** |
|:---|:---|
| S-HOME — Главная | Компактный header+gear, Все/Резюме/Проекты, смешанная библиотека по изменению; REQ-HOME-01..03; HomeFilter, EntityCard, CopyLink; R4.1 |
| S-RESUMES — Резюме | Header+gear, создать, список role/preview/date/status; REQ-RESUME-01; ResumeCard; R4.2 |
| S-PROJECTS — Проекты | Header+gear → импорт → создать → поиск → список; REQ-PROJECT-01..04; ProjectCard, TechnologyBadge; R4.3 |
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
| Финальные Design v2 frames | Ещё не созданы; IDs, variant/state и evidence добавляются после R4–R7, без подстановки legacy ссылок |

Prototype reactions старой итерации не приняты и полностью не прогонялись в R0.
Публичного Resume среди перечисленных top-level legacy web frames не найдено;
карточка Resume в предыдущей итерации не заменяет финальный документный frame.
