<div align="center">

# StackCard Design v2 — план

**Поэтапный редизайн с явными границами, проверками и приёмкой**

![Phase R3](https://raster.shields.io/badge/Phase-R3-C7FF1A?style=for-the-badge)
![Status awaiting review](https://raster.shields.io/badge/Status-awaiting_review-14161B?style=for-the-badge)

</div>

---

## Содержание

- [Правила выполнения](#правила-выполнения)
- [Обзор фаз](#обзор-фаз)
- [Фазы и задачи](#фазы-и-задачи)
- [Зависимости реализации](#зависимости-реализации)
- [Проверки и результаты](#проверки-и-результаты)
- [Журнал решений](#журнал-решений)

---

## Правила выполнения

На 2026-10-05 R0 принята прямым поручением использовать план и начать первую
фазу. Поручение «переходи к следующей фазе» принято как приёмка R1.1
и разрешение следующей последовательной задачи R1.2 (D013).
Поручение исправить соседние кнопки/поиск и затем продолжить принято как
условная приёмка R1.2 после проверенных правок и разрешение R1.3 (D015).
Поручение «переходи к следующему этапу» приняло R1.3 и разрешило R1.4 (D017).
Поручение добавить цветовые акценты и затем продолжить выполнено, D020:
R1.4 и R1 — `done`. Поручение «переходи к следующему этапу» приняло сравнение
R2.1 и разрешило R2.2 (D022), без выбора A/B. Поручение «вариант бренда мне
понавился А. приступай к следующей фазе» приняло бренд A и разрешило R3.1,
D024: R2.2/R2.3/R2 done. Связанные пилоты A служат основой следующей фазы.
Активна R3, текущая задача **R3.1 — `awaiting_review`**: созданы и проверены
[Dark/Light foundations, типографика и метрики](screens.md#r31--цвета-типографика-и-метрики), D025.
Ответ пользователя о постоянном адресе документа закрыл выбор политики D007
(D019); реализация и точная схема URL остаются отдельной предпосылкой R8.
Основная разработка функций приостановлена перед Phase 11 Media; открытая
Google/reset/iOS приёмка Phase 7 сохранена. Подробности — [README](README.md)
и [audit](audit.md), основной roadmap остаётся в [product spec](../product/product-spec.md#план-разработки).

Одновременно активна одна фаза и только текущая согласованная задача внутри неё.
Допустимые статусы: `todo`, `in_progress`, `blocked`, `awaiting_review`, `done`.
Новый артефакт переводит визуальную задачу в awaiting_review; done требует
приёмки пользователя. Следующий шаг начинается по явному поручению.
R0 завершена после пользовательского разрешения R1.1; R1.1 принята отдельным
поручением продолжить; R1.2 принята после правок D015, R1.3 — поручением D017.
R1.4 принята условным поручением D020 после проверки цветовых правок.
Приёмка сравнения R2.1 сама по себе не означала выбора направления/логотипа;
последующий прямой выбор A закрыл R2 (D024). Шрифт и полная DS ещё не приняты.

R1–R7 создают UX, editable макеты и прототип. Только после пользовательского
DESIGN_READY и отдельного разрешения R8 начинается перенос UI. R9 устанавливает
REDESIGN_DONE только после пользовательской приёмки реализации в согласованном
scope. Mock, prototype, implemented UI и backend capability отмечаются отдельно.

Requirement IDs принадлежат [requirements](requirements.md), S-* экраны и
current paths — [screens](screens.md), GAP-* — [audit](audit.md#продуктовые-пробелы).
Диапазон IDs означает каждое требование диапазона. Будущие Figma-имена в таблицах
явно предлагаемые; существующие frame IDs указаны только в проверенном реестре.
Доказательство в строках todo — требуемый будущий результат, а не уже выполненная проверка.
Каждый step R5.1/R5.2/R5.3/R5.4 согласуется отдельно.
R4.7 и R8.2–R8.5 — группы отдельных задач с буквенными IDs ниже, не задачи
на весь раздел. При задаче о shared controls или нескольких секциях выполнять
один компонент/экран за проверяемый срез; запись evidence перечисляет каждый срез.

---

## Обзор фаз

| **Фаза** | **Результат / точка согласования** | **Статус** |
|:---|:---|:---|
| R0 — Аудит и план | Комплект docs/redesign и сохранённая точка roadmap. Принята прямым поручением начать R1; D009. | done |
| R1 — UX и информационная архитектура | IA и 88 low-fi экранов приняты; цветовые правки D020 выполнены. Постоянные адреса документов приняты D019; URL backend ещё не реализован. | done |
| R2 — Визуальное направление | Принят бренд A D024; связанные пилоты A / Cyber Editorial — основа R3. A families закреплены с прежними IDs; B сохранён как история. R2.1–R2.3 done. | done |
| R3 — Дизайн-система | R3.1: editable Dark/Light foundations и Noto Sans specimens проверены, awaiting_review D025. Принять foundations/шрифт; R3.2–R3.4 todo. | awaiting_review |
| R4 — Основные экраны и настройки | Набор hi-fi full/empty/errors и focused settings screens. Принять roots и каждую settings группу; неподдерживаемые функции остаются target-design. | todo |
| R5 — Создание, редактирование и публикация | Полные hi-fi flows с input/error/back/preview и отдельным Publish. Принять последовательно R5.1 → R5.2 → R5.3 → R5.4; уточнить delete/rename consequences. | todo |
| R6 — Web | Полный web design visitor/owner flow, не один hero. Принять web-подачу и доступность CTA/download; URL scheme с GAP-URL-01. | todo |
| R7 — Прототип, адаптивность и приёмка дизайна | Пакет финальных frames/prototype, результатов и известных ограничений. Принять итоговый дизайн; после явного подтверждения установить DESIGN_READY. | todo |
| R8 — Перенос согласованного UI | Реальные экраны в согласованном scope; неподдерживаемые действия обозначены честно. Разрешить R8 отдельно, выбрать prerequisite work или явно сузить scope; перенос не разрешает deploy/commit/push. | todo |
| R9 — Регрессия и завершение | Принятый redesign с REDESIGN_DONE и сохранённой точкой roadmap. Принять R9 и поставить REDESIGN_DONE; затем отдельно решить следующую продуктовую задачу. | todo |

---

## Фазы и задачи

### R0 — Аудит и план

**Цель:** Установить фактическую базу и отдельный согласуемый план.

**Зависимости:** Полный запрос пользователя, инструкции, source, существующие docs/Figma и референсы.

**Входит:** Чтение репозитория/Figma/сайтов; шесть полезных документов и согласование R0.

**Не входит:** Новые экраны, изменения Figma/runtime/backend, зависимости, deploy и Git mutations.

**Результат:** Комплект docs/redesign и сохранённая точка roadmap.

**Критерии приёмки:** Все выводы имеют источник или пометку ограничения; требования покрыты задачами и проверками; пользовательские правки сохранены.

**Проверка:** Статический source audit, read-only Figma, внешние источники, doc validator и ручная проверка противоречий.

**Решения пользователя:** Принять план и разрешить R1.1; само создание документа не является разрешением.

**Статус фазы:** `done` (D009).

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R0.1 | REQ-WORKFLOW-01, REQ-PRESERVE-01 | [audit](audit.md), основной roadmap | Проверить tree/status/routes/domain, зафиксировать Phase 10 и открытые проверки Phase 7. | C-SCOPE, C-MODEL | Source-ссылки и исходный dirty snapshot в audit. | done |
| R0.2 | REQ-REFERENCE-01..02, REQ-WORKFLOW-01, REQ-FIGMA-02 | [Figma registry](screens.md#реестр-figma), [references](references.md) | Прочитать Figma и референсы; назвать реально увиденное и недоступное. | C-ASSET, C-SCOPE | Проверенные node IDs и источник/приём/ограничение в документах. | done |
| R0.3 | REQ-CHECK-01, REQ-MODEL-01 | [requirements](requirements.md), [screens](screens.md) | Назначить ID и карту текущих/целевых экранов, сохранить все явные решения. | C01–C17, C-MODEL | Реестр requirements → task → screen → check → result. | done |
| R0.4 | REQ-WORKFLOW-02..03, REQ-WORKFLOW-05, REQ-SCOPE-01 | Этот plan; [audit gaps](audit.md#продуктовые-пробелы) | Разбить R0–R9, выделить продуктовые предпосылки R8 и approval gates. | C-SCOPE | Задачи, зависимости, criteria/evidence/status и журнал ниже. | done |
| R0.5 | REQ-CHECK-02, REQ-PRESERVE-01 | Все шесть документов и existing docs pointers | Проверить ссылки, соответствие требованиям, сохранность source; показать результат и остановиться. | C-SCOPE | Фактические R0 doc checks сохранены; план принят поручением начать R1, D009. | done |

### R1 — UX и информационная архитектура

**Цель:** Согласовать пользовательские пути и владение данными до визуального дизайна.

**Зависимости:** Принятый R0 и отдельное разрешение R1.1.

**Входит:** Карта переходов, перечень экранов и low-fi ключевых сценариев.

**Не входит:** Hi-fi, новый logo, выбор шрифтов, runtime/schema implementation.

**Результат:** Согласованная IA и проверяемые low-fi. IA R1.1 принята;
low-fi R1.2/R1.3 приняты, R1.4 принята после цветовых правок D020.

**Критерии приёмки:** Home-фильтр отделён от root nav; Settings возвращает к источнику; база → документ → Publish понятны; attachment не удаляет Project.

**Проверка:** Walkthrough на обычных/пустых данных, Back/skip/unsaved paths, связь с S-* и requirement IDs.

**Решения пользователя:** IA и все low-fi приняты; поручение продолжить после правок D020 выполнено. Политика постоянных output URLs принята D019; route scheme и миграция относятся к будущему backend.

**Статус фазы:** `done` (R1.1–R1.4 done).

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R1.1 | REQ-MODEL-01..08, REQ-NAV-01..05 | [Navigation 58:8](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-8), [Ownership 58:41](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-41), [Lifecycle 58:75](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-75); S-HOME/S-SETTINGS и остальные S-* в IA | Сопоставлены DeveloperProfile, library, Resume, Portfolio и связи; четыре roots, вложенные screens и origin/Back. | C-MODEL, C01, C02, C11, C12 | [Ownership, сценарии и evidence](screens.md#r11--информационная-архитектура); три renders просмотрены, правила IA сверены; принята поручением продолжить, D013. | done |
| R1.2 | REQ-HOME-01..03, REQ-SETTINGS-01..04, REQ-NAV-01..05 | [Roots/Settings 61:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-7), [Profile-to-document 61:491](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-491), [Errors/Groups 61:833](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=61-833); ROOT, SETTINGS и вход S-RESUME-WIZARD | 24 low-fi 390×844: Home/settings/profile/contacts; соседние кнопки в девяти компактных рядах, поиск без заголовка с лупой. | C01–C06, C12 | [Реестр и walkthrough](screens.md#r12--low-fi-основных-сценариев); итоговые renders правок просмотрены. Принята поручением продолжить после исправлений, D015; prototype/runtime pending. | done |
| R1.3 | REQ-RESUME-01..04, REQ-EDITOR-01..03 | [Wizard 72:537](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-537), [Optional/Back 72:941](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-941), [Sections/Save 72:1242](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=72-1242); S-RESUME-WIZARD/S-RESUME-EDITOR | 24 low-fi: пять шагов, skip, фото/no-photo, Back/unsaved/error, focused sections и local overrides; один low-fi preview component. | C07, C10, C12, C16 | [Реестр и walkthrough](screens.md#r13--low-fi-resume-wizard-и-редактора); три итоговых renders и bounds всех 24 screens проверены. Принята поручением продолжить, D017; фото — wireframe-слот, prototype/runtime pending. | done |
| R1.4 | REQ-PROJECT-01..04, REQ-PORTFOLIO-01..03, REQ-SHARE-01, REQ-MODEL-02/04..08, REQ-EDITOR-01..03, REQ-NAV-04 | [Manual 78:1012](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1012), [GitHub 78:1013](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1013), [Portfolio 78:1014](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1014), [Publish 78:1015](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1015), [Access 78:1016](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=78-1016); S-PROJECT-EDITOR/S-GITHUB/S-PORTFOLIO-EDITOR/S-PUBLISH/PUBLIC | 40 low-fi: create/import/review, attach/remove relation, preview, Save/sync/Publish, errors/unsaved/access; один временный PortfolioDocument component. | C-GITHUB, C-MODEL, C09, C10, C12, C17 | [Реестр и walkthrough](screens.md#r14--low-fi-projects-portfolio-и-публикации); пять итоговых boards и два обновлённых rename screens просмотрены, bounds/actions/search проверены. D019 постоянный адрес; цветовые правки проверены, приёмка D020; prototype/runtime pending. | done |

### R2 — Визуальное направление

**Цель:** Выбрать один выразительный язык внутри неизменяемой палитры.

**Зависимости:** Принятая R1; точная палитра и запреты requirements.

**Входит:** Два различающихся направления на одинаковых пилотах и данных; новый logo внутри UI.

**Не входит:** Полный продукт, финальная component library, новая палитра, код.

**Результат:** Два сопоставимых варианта Home, public Resume, Settings и принятое направление.

**Критерии приёмки:** Одинаковые содержание/фото/состояния; различия в typography/composition/motive видны; редактор спокойный; знак читается малым.

**Проверка:** Side-by-side renders 390, оба брендинга в реальном UI; preliminary contrast и font/asset license review.

**Решения пользователя:** Бренд A выбран D024; связанные пилоты A / Cyber Editorial — основа R3. Окончательная типографика и DS согласуются в R3.

**Статус фазы:** `done` (R2.1–R2.3 done, D024).

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R2.1 | REQ-VISUAL-01..03, REQ-PALETTE-01..03 | [Comparison 99:8](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=99-8); Direction A 99:10 / B 99:11; S-HOME/S-PUBLIC-RESUME/S-SETTINGS | Два направления: крупная типографика/плоские разделы A и предпросмотры/собранный профиль/цветные детали B. Одинаковые данные, full no-photo Resume, Noto Sans и palette; light не входит в пилоты. | C-PALETTE, C01, C03, C04, C14 | [Шесть реальных frames и проверки](screens.md#r21--два-визуальных-направления); bounds/content/font/contrast и итоговый render проверены. Сравнение принято D022; выбор бренда A и основание R3 зафиксированы отдельно D024. | done |
| R2.2 | REQ-LOGO-01..02, REQ-TYPE-01..02 | [Brand Comparison 110:268](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=110-268); A 110:274 / B 110:275 | Два editable mark/wordmark/app icon направления: шесть sets, 18 variants; dark/light/mono, размеры 16–48, восемь шапок тех же Home/public UI. | C-ASSET, C14 | [IDs, проверки и ограничения](screens.md#r22--знак-написание-и-иконка-приложения); render/bounds и 1:1 малые образцы проверены. A чище на 16; B рекомендуется от 24, шапки 32. Бренд A принят D024. | done |
| R2.3 | REQ-VISUAL-01..03, REQ-WORKFLOW-06 | Пилоты A 101:53 / 101:146 / 101:180; Mark 110:282, Wordmark 111:284, AppIcon 111:297 | Записан выбор бренда A; связанные A / Cyber Editorial pilots — основа R3. Три sets A закреплены в namespace StackCard / v2 без смены IDs; B сохранён как история. | C-PALETTE, C14; C16 полностью позднее | [Решение и selected IDs](screens.md#r23--принятый-бренд-и-направление), D024; предварительные R2 проверки сохранены. Выбор шрифта/полная DS не принят автоматически. | done |

### R3 — Дизайн-система

**Цель:** Сделать принятую композицию переиспользуемой и доступной.

**Зависимости:** Принятая R2, лицензии и существующие integration points.

**Входит:** Semantic tokens, typography, Auto Layout, variables, components/variants/states.

**Не входит:** Runtime theme migration, импорты React-кода в Flutter, библиотека ради каталога.

**Результат:** Editable DS dark/light с нужными variants и usage rules.

**Критерии приёмки:** Long ru labels, 48×48, text scaling, contrast всех используемых поверхностей; state определяется не только цветом.

**Проверка:** Variables/bindings/component audit + specimen renders dark/light/ru/en и state matrix.

**Решения пользователя:** Принять DS; выбрать шрифты после проверки кириллицы/латиницы и лицензии.

**Статус фазы:** `awaiting_review` (R3.1 awaiting_review; R3.2–R3.4 todo).

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R3.1 | REQ-PALETTE-01..03, REQ-TYPE-01..02, REQ-FIGMA-01 | [Foundations 123:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=123-7), [Typography 125:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=125-19), page 121:7; existing core/theme как будущий integration point | Сохранены 25 color variables; пять семантических ролей, один Light primitive, display40/48 style и metric. Dark/Light: четыре поверхности, 9 type roles, ru/en, статический reflow16/32. | C-PALETTE, C14, C-ASSET; C16 частично static | [Bindings, реальные пары и ограничения](screens.md#r31--цвета-типографика-и-метрики); 246 painted texts ≥4.5, control outlines/focus ≥3, оба renders и bounds PASS. Полная DS/font choice/OS scaling pending D025. | awaiting_review |
| R3.2 | REQ-NAV-01..05, REQ-TECH-01..02, REQ-PROJECT-03 | Предлагаемый DS / Navigation-Cards-TechnologyBadge; S-HOME/S-PROJECTS | Четыре постоянных labels, gear/back, три Home tabs, entity cards и доступные badges/placeholder. | C01–C05, C08, C11, C12, C15 | Component sets и states; metadata + renders + icon licenses. | todo |
| R3.3 | REQ-EDITOR-01..03, REQ-RESUME-02..03, REQ-SETTINGS-02 | Предлагаемый DS / Forms-Stepper-Sections; S-RESUME-WIZARD/S-PROFILE | Fields/selectors/photo/stepper/settings rows, visible Save и reorder drag+Выше/Ниже. | C06, C07, C12, C15, C16 | Keyboard/long-label specimens и alternative-action сценарий. | todo |
| R3.4 | REQ-MOTION-01..02, REQ-ADAPT-01..03, REQ-EDITOR-03 | Предлагаемый DS / States-Motion; S-PUBLISH/S-SHARE | Empty/loading/error/offline/saved/synced/published variants; 180–280 ms и статические equivalents. | C10, C13, C-MOTION | State matrix, motion timings и reduced-motion specimens. | todo |

### R4 — Основные экраны и настройки

**Цель:** Собрать четыре библиотеки и полноценные настройки из DS.

**Зависимости:** Принятые R1–R3; backend gaps маркируются, не реализуются.

**Входит:** Root screens, Profile/photo, contacts/links, account/app/privacy settings.

**Не входит:** Wizard/editors/publication flows R5; заявления о backend готовности.

**Результат:** Набор hi-fi full/empty/errors и focused settings screens.

**Критерии приёмки:** Все запреты выполнены; Settings содержит editable profile/contacts/account сценарии, а не только theme/language.

**Проверка:** Requirement walkthrough, renders+metadata dark/light, реальная viewport-height до первого Project.

**Решения пользователя:** Принять roots и каждую settings группу; неподдерживаемые функции остаются target-design.

**Статус фазы:** `todo`.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R4.1 | REQ-HOME-01..03, REQ-NAV-01..03 | S-HOME; existing /home | Header+gear, ровно Все/Резюме/Проекты, recent mixed cards и отдельная Copy зона; убрать dashboard элементы. | C01–C04, C09 | Design v2 Home frames full/empty; фильтр проверен вручную. | todo |
| R4.2 | REQ-RESUME-01, REQ-SHARE-01 | S-RESUMES; нового runtime route ещё нет | Create + cards role/preview/date/status/open/copy; без completion percent. | C01, C02, C09, C10 | Resume list frames с draft/published состояниями. | todo |
| R4.3 | REQ-PROJECT-01..04, REQ-TECH-01..02 | S-PROJECTS; existing /projects | Import/Create в компактном горизонтальном ряду → поиск с лупой без внешнего заголовка → List; cover/placeholder, badges, без filters/hero. | C05, C08, C13, C15 | Project list frames full/empty/no-results/narrow. | todo |
| R4.4 | REQ-PORTFOLIO-01, REQ-SHARE-01 | S-PORTFOLIOS; existing /portfolio пока singleton | Список named Portfolio и доступ к create/edit/duplicate/publish/unpublish/share. | C09, C10, C13 | List и action states; отличить target от storage gap. | todo |
| R4.5 | REQ-SETTINGS-01,04, REQ-RESUME-03 | S-SETTINGS/S-PROFILE; existing profile editor | Focused profile и photo selector/replace/remove/no-photo, опыт/образование/навыки. | C06, C07, C12, C16 | Settings/Profile frames, permission/taken-name states. | todo |
| R4.6 | REQ-SETTINGS-02..03 | S-CONTACTS; existing /portfolio/builder/links | Отделить contact email от login, custom label+URL, CRUD/reorder и public selection. | C06, C17 | Contact/link screens full/validation/edit/reorder. | todo |
| R4.7a | REQ-SETTINGS-01,03,04 | S-ACCOUNT; existing /settings account actions | Отдельный экран аккаунта: login email/password/provider inventory, reauth/link error/last-provider protection; выход и delete отдельно. | C06, C10, C12, C13 | Account screens и ошибки/подтверждения, backend gaps явны. | todo |
| R4.7b | REQ-SETTINGS-01,03, REQ-SHARE-01 | S-PRIVACY; существующего privacy route нет | Экран privacy: selected contacts/location/обращения, не смешивать login email с public contact. | C06, C12, C17 | Privacy full/save/error states и проверка public selections. | todo |
| R4.7c | REQ-SETTINGS-01, REQ-MOTION-02 | S-APP; existing /settings preferences | Экран приложения: dark/light/system, ru/en, notifications/reduced motion; unsupported backend обозначен. | C06, C12, C13, C-MOTION | App settings full/save/error/reduced-motion states. | todo |

### R5 — Создание, редактирование и публикация

**Цель:** Завершить сценарии документов, проектов и общего sharing.

**Зависимости:** Принятые R3–R4, IA и правила модели; каждый R5.x проверяется отдельно.

**Входит:** Resume wizard/edit, manual/GitHub Projects, Portfolio builder, shared publish/share/delete.

**Не входит:** Backend migration/media/OAuth implementation и свободный canvas.

**Результат:** Полные hi-fi flows с input/error/back/preview и отдельным Publish.

**Критерии приёмки:** Нет потери ввода, смешения Save/sync/publish, тихого overwrite, duplicate import или удаления общей работы через attachment.

**Проверка:** Пошаговый walkthrough обычного/пустого/ошибочного flow, сравнение с source contract.

**Решения пользователя:** Принять последовательно R5.1 → R5.2 → R5.3 → R5.4; уточнить delete/rename consequences.

**Статус фазы:** `todo`.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R5.1a | REQ-RESUME-02..04, REQ-SETTINGS-02 | S-RESUME-WIZARD; предлагаемое Mobile / Resume / Steps 1-2 | Profile/title/role/photo/bio и selected contacts; использовать базу, локальные overrides, no-photo и Skip. | C06, C07, C12, C16 | Steps 1–2 с Back/data retention, photo denied/error. | todo |
| R5.1b | REQ-RESUME-02,04, REQ-TECH-01..02 | S-RESUME-WIZARD; предлагаемые Steps 3-4 | Выбор опыта/образования/tech/projects, optional skip; не выдумывать факты и skill levels. | C08, C12, C16, C-MODEL | Steps 3–4 с empty/selected/hidden и сохранением ввода. | todo |
| R5.1c | REQ-RESUME-04, REQ-EDITOR-01..03, REQ-MODEL-07 | S-RESUME-EDITOR; existing plain /portfolio/builder/resume — только legacy | Список секций и focused edit без повторного wizard, local overrides и review изменений профиля. | C10, C12, C-MODEL | Edit section/override/profile-diff frames. | todo |
| R5.1d | REQ-RESUME-02..03, REQ-SHARE-01 | S-PREVIEW/S-PUBLISH; предлагаемый Resume Step 5 | Структурированный preview с выбранным фото и отдельный переход к Publish. | C07, C09, C10, C17 | Step 5/no-photo/long Resume; публикация связана с R5.4. | todo |
| R5.2a | REQ-PROJECT-03..04, REQ-TECH-01..02 | S-PROJECT-EDITOR; /projects/new, /projects/:id/edit | Ручной global Project: форма/media placeholder/badges, validation/Save/Cancel. | C08, C12, C13 | Create/edit/error/no-cover frames. | todo |
| R5.2b | REQ-PROJECT-04, REQ-MODEL-02 | S-GITHUB; /github-import | Выбор repos, already imported, pagination/cache/rate/error, без повторного Project. | C-GITHUB, C13 | Import full/empty/error/duplicate paths. | todo |
| R5.2c | REQ-PROJECT-04, REQ-MODEL-06 | S-GITHUB-REVIEW; existing GitHub review sheet | Показать diff source/curated, Accept/Ignore/Cancel, stale review и отдельный Save. | C-GITHUB, C10, C13 | Review frames с сохранёнными overrides и retry. | todo |
| R5.3a | REQ-PORTFOLIO-01..02, REQ-EDITOR-01 | S-PORTFOLIO-EDITOR; /portfolio/builder пока singleton | Создать named Portfolio из предложения Profile, content/appearance/preview отдельно. | C-MODEL, C10, C12 | Create/basic editor frames с draft status. | todo |
| R5.3b | REQ-PORTFOLIO-03, REQ-MODEL-02, REQ-MODEL-05 | S-PORTFOLIO-EDITOR; предлагаемый Project selector | Add existing или create global+attach; order/visibility/featured association, remove relation. | C-MODEL, C12 | Attach/create/remove/reorder paths; library Project сохраняется. | todo |
| R5.3c | REQ-EDITOR-01..03, REQ-PORTFOLIO-02 | S-PORTFOLIO-EDITOR/S-PREVIEW; existing /portfolio/preview | Focused sections, show/hide/order, layout/accent/photo visibility, no three narrow mobile panels. | C07, C08, C10, C12 | Sections/appearance/full/no-photo preview frames. | todo |
| R5.4a | REQ-EDITOR-03, REQ-MODEL-08 | S-PUBLISH; prepared publication adapter, UI отсутствует | Draft/locally saved/pending/synced/published различимы; Publish explicit, dirty published draft не меняет public. | C10, C17 | Status diagram и first/update publish/error states. | todo |
| R5.4b | REQ-SHARE-01 | S-SHARE + cards/detail | Постоянные Copy/Open/Share у опубликованного; подтверждение Copy; draft предлагает Publish. | C09, C15 | Повторное sharing после re-open, отдельные hit areas. | todo |
| R5.4c | REQ-SHARE-01, REQ-SETTINGS-04, REQ-PORTFOLIO-01 | S-PUBLISH/S-SHARE/S-ACCOUNT | Unpublish/delete/duplicate/rename confirmations; постоянный адрес документа по D019, сохранность draft и связей; фактическую поддержку URL проверить перед R8. | C-MODEL, C09, C10, C17 | Подтверждения и anonymous unavailable state; URL decision logged. | todo |

### R6 — Web

**Цель:** Спроектировать три web-поверхности как части того же продукта.

**Зависимости:** Принятые модель/DS/flows R1–R5; actual web runtime пока отсутствует.

**Входит:** Landing, auth/download, рабочий кабинет/editor, public Resume/Portfolio.

**Не входит:** Next.js scaffold/code, hosting/deploy, фиктивные store links/отзывы/цифры.

**Результат:** Полный web design visitor/owner flow, не один hero.

**Критерии приёмки:** Различимы marketing/private/public, narrow/wide editing; публичный просмотр без входа и приватных полей.

**Проверка:** Desktop/narrow renders, keyboard/focus план, CTA destination audit, anonymous/owner walkthrough.

**Решения пользователя:** Принять web-подачу и доступность CTA/download; URL scheme с GAP-URL-01.

**Статус фазы:** `todo`.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R6.1 | REQ-WEB-01..02, REQ-VISUAL-01..03 | S-WEB-LANDING; apps/web/README.md; предлагаемый Web / Landing | Объяснить общая база→разные Resume/Portfolio; настоящее product preview и все секции задания. | C-WEB, C-ASSET | Полный landing desktop/mobile и проверка утверждений/CTA. | todo |
| R6.2 | REQ-WEB-02, REQ-PRESERVE-04 | S-WEB-AUTH/S-WEB-DOWNLOAD; runtime отсутствует | Auth/register/reset/return route и download с честным unavailable-state. | C-WEB, C12, C13 | Полные страницы и путь visitor→owner, без ложных store buttons. | todo |
| R6.3 | REQ-WEB-03, REQ-EDITOR-01..03 | S-WEB-WORKSPACE; предлагаемый Web / Workspace | Wide параметры+preview, narrow modes, shared base/library/documents, explicit publishing. | C-WEB, C10, C13, C16 | Workspace/edit/preview/error/unsaved frames. | todo |
| R6.4 | REQ-WEB-04, REQ-PORTFOLIO-02, REQ-SHARE-01 | S-PUBLIC-RESUME/S-PUBLIC-PORTFOLIO; предлагаемые Web / Public | Документный Resume и showcase Portfolio, выбранные фото/контакты, not-found/unpublished. | C07, C08, C17, C-WEB | Anonymous full/empty/unpublished frames, privacy checklist. | todo |

### R7 — Прототип, адаптивность и приёмка дизайна

**Цель:** Проверить целостные сценарии и зафиксировать DESIGN_READY.

**Зависимости:** Принятые R1–R6, реальные frames и complete state matrix.

**Входит:** Linked prototype, phone/tablet/landscape/text/keyboard/motion/a11y evidence.

**Не входит:** Реализация runtime/backend и автоматическая установка DESIGN_READY.

**Результат:** Пакет финальных frames/prototype, результатов и известных ограничений.

**Критерии приёмки:** Все C01–C17 и дополнительные проверки имеют evidence; пользователь принял дизайн.

**Проверка:** Prototype walkthrough + screenshots + metadata/contrast; simulated keyboard states, фактический native keyboard в R8/R9.

**Решения пользователя:** Принять итоговый дизайн; после явного подтверждения установить DESIGN_READY.

**Статус фазы:** `todo`.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R7.1 | REQ-WORKFLOW-04, REQ-FIGMA-02 | Все S-*; реальные frame IDs появятся в screens.md | Связать root/settings/create/edit/preview/publish/share и error/back paths. | C01–C13, C17 | Prototype link + выполненный сценарий и зафиксированные ошибки. | todo |
| R7.2 | REQ-ADAPT-01..03, REQ-NAV-01,05 | Mobile frames 320/390/large phone/tablet/landscape (контрольный набор предлагаемый) | SafeArea, centered max width, без rail, keyboard-safe/long content, scale1/2. | C11, C12, C15, C16 | Сравнимые renders dark/light ru/en; landscape/tablet evidence. | todo |
| R7.3 | REQ-CHECK-01..02, REQ-MOTION-01..02 | DS + все critical states | Контраст/targets/focus/semantics specs; reduced-motion 180–280/static, empty/error/offline. | C13–C17, C-MOTION, C-ASSET | Таблица contrast и state/motion review; native semantics остаются runtime check. | todo |
| R7.4 | REQ-WORKFLOW-04..05, REQ-WORKFLOW-07, REQ-FIGMA-02 | screens.md финальный реестр, этот журнал | Свести requirements→frames→checks→results; явная приёмка пользователя. | C-SCOPE, C01–C17 | Принятый пакет + решение DESIGN_READY; до решения awaiting_review. | todo |

### R8 — Перенос согласованного UI

**Цель:** Внедрить принятый дизайн постепенно, сохранив реальное поведение.

**Зависимости:** DESIGN_READY, отдельное разрешение R8, принятый integration scope и выполненные продуктовые prerequisites.

**Входит:** Tokens/components, shell/roots/settings/editors и поддерживаемые web surfaces по одному срезу.

**Не входит:** Тихая domain/backend/Rules migration, OAuth/media/публикация новых функций, смена стека, fake success.

**Результат:** Реальные экраны в согласованном scope; неподдерживаемые действия обозначены честно.

**Критерии приёмки:** Старые данные/UID/cache/outbox/notes/review сохранены, новое UI проверено; нет mock-success вместо backend.

**Проверка:** По изменённому scope: format/analyze/focused tests, визуальный native run; web scripts по реальным manifests.

**Решения пользователя:** Разрешить R8 отдельно, выбрать prerequisite work или явно сузить scope; перенос не разрешает deploy/commit/push.

**Статус фазы:** `todo`.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R8.1 | REQ-SCOPE-01..04, REQ-PRESERVE-01..04 | audit.md gaps; actual domain/Hive/Firestore/Rules; apps/web/README.md | Сопоставить каждый action с реальным contract. Несовместимые gaps block соответствующий slice; миграцию здесь не выполнять. | C-SCOPE, C-MODEL, C-WEB | Согласованный список prerequisites/исключений; без этого UI slice blocked. | todo |
| R8.2a | REQ-PALETTE-01..03, REQ-TYPE-01..02 | apps/mobile/lib/core/theme/stackcard_colors.dart, stackcard_theme.dart, stackcard_tokens.dart | Перенести semantic colors/type/spacing, сохранив единый theme mechanism и Material 3. | C14, C16, C-PALETTE | Theme diff, contrast checks и dark/light native renders. | todo |
| R8.2b | REQ-NAV-01..05, REQ-EDITOR-02..03 | apps/mobile/lib/shared/widgets; actual component files по approved DS | По одному shared control: button/input/back/gear/navigation/state; сохранить loading/semantics/retry. | C12, C13, C15, C16 | Для каждого компонента diff и focused widget/render evidence. | todo |
| R8.2c | REQ-TECH-01..02, REQ-PROJECT-03 | apps/mobile/lib/shared/widgets; новые TechnologyBadge/card paths предлагаемые до выбора source placement | Ввести badge icon+text/+N/wrap и entity-card presentation; проверять по одному компоненту. | C08, C14, C15, C-ASSET | Реальные widget tests, icon provenance и long-label renders. | todo |
| R8.3a | REQ-NAV-01..05 | apps/mobile/lib/app/app_router.dart, apps/mobile/lib/app/app_shell.dart | Shell/routes: четыре permanent labels, gear/settings nested, origin Back, guards/deep links, tablet bottom nav. | C01, C02, C11, C12, C16 | Navigation/state tests и phone/tablet renders. | todo |
| R8.3b | REQ-HOME-01..03 | apps/mobile/lib/features/home/home_screen.dart; S-HOME | Перенести только Home: три фильтра/recent mixed list и separate Copy, после готовности library модели. | C03, C04, C09, C13 | Home behavioral/filter tests и accepted-frame render. | todo |
| R8.3c | REQ-RESUME-01, REQ-SHARE-01 | S-RESUMES; новые source/route пути предлагаются после GAP-DATA-01 | Перенести Resume list/create entry/status/link presentation только при настоящем Resume contract. | C09, C10, C13 | List states/reopen tests и render; без contract задача blocked. | todo |
| R8.3d | REQ-PROJECT-01..04 | apps/mobile/lib/features/projects/presentation/projects_screen.dart; S-PROJECTS | Перенести Projects Import/Create/Search/List, без categories/hero, сохранить repository/search states. | C05, C08, C13, C15 | Projects search/action/state tests и narrow render. | todo |
| R8.3e | REQ-PORTFOLIO-01, REQ-SHARE-01 | apps/mobile/lib/features/portfolio/presentation/portfolio_screen.dart; S-PORTFOLIOS | Перенести Portfolio list после multiple-output contract; настоящие actions, без mock success. | C09, C10, C13 | List/actions/reopen tests и render; contract gate. | todo |
| R8.3f | REQ-SETTINGS-01..04, REQ-NAV-05 | apps/mobile/lib/features/settings/settings_screen.dart; S-SETTINGS и children | Переносить по одному согласованному settings экрану R4.5/4.6/4.7a/b/c; поддерживаемые Save/auth actions, origin Back. | C02, C06, C12, C13, C17 | Отдельный diff и native acceptance каждого settings сценария. | todo |
| R8.4a | REQ-EDITOR-01..03 | apps/mobile/lib/features/portfolio_draft/presentation/builder_editor_widgets.dart; existing section editors | Перенести focused section scaffold/Apply/Cancel/visible Save, сохранив validation/input/retry. | C10, C12, C13, C16 | Forms/input retention tests + keyboard native render. | todo |
| R8.4b | REQ-PROJECT-03..04 | apps/mobile/lib/features/portfolio_draft/presentation/portfolio_project_editor_screen.dart | Перенести manual Project create/edit после library gate, stable IDs и validation без потери ввода. | C08, C10, C12, C13 | Project CRUD/Cancel/validation tests и no-cover render. | todo |
| R8.4c | REQ-PROJECT-04, REQ-MODEL-06 | apps/mobile/lib/features/github_import/presentation/github_import_screen.dart, github_source_cards.dart | Перенести import/review controls; dedup, Add/Accept/Ignore, stale/UID/cached behavior сохраняются. | C-GITHUB, C10, C13 | Existing smart-sync tests и native source/review walkthrough. | todo |
| R8.4d | REQ-RESUME-02..04, REQ-MODEL-07 | S-RESUME-WIZARD/S-RESUME-EDITOR; новые paths после отдельно принятого Resume contract | Перенести wizard и прямую правку по одному согласованному этапу R5.1; без fake structured storage. | C07, C08, C10, C12, C16 | Step/Back/selection/override/photo tests и native evidence; gaps block. | todo |
| R8.4e | REQ-PORTFOLIO-02..03, REQ-EDITOR-01..03 | apps/mobile/lib/features/portfolio_draft/presentation/portfolio_builder_screen.dart, portfolio_preview_screen.dart | Перенести Portfolio sections/appearance/preview по одному flow; attach/remove только после готовой relation модели. | C-MODEL, C07, C08, C10, C12, C17 | Builder/reorder/preview/private data tests и native evidence. | todo |
| R8.5a | REQ-WEB-01..02 | apps/web; source paths после отдельно разрешённого Next.js runtime | Перенести landing/auth/download по одному accepted page, реальные CTA без отсутствующих store links. | C-WEB, C12, C13 | Actual build/page/focus/responsive checks; нет runtime → blocked. | todo |
| R8.5b | REQ-WEB-03, REQ-EDITOR-01..03 | apps/web; S-WEB-WORKSPACE, actual paths после prerequisites | Перенести supported workspace/section editor/preview, actual owner guards и explicit publication только при готовом contract. | C-WEB, C10, C13, C16 | Actual owner/edit/reopen/input-retention acceptance. | todo |
| R8.5c | REQ-WEB-04, REQ-SHARE-01 | apps/web; S-PUBLIC-RESUME/S-PUBLIC-PORTFOLIO, actual paths после prerequisites | Перенести публичные renderer по одному документу, anonymous unavailable и payload privacy. | C-WEB, C07, C08, C09, C17 | Actual anonymous/public/private checks и matched renders. | todo |

### R9 — Регрессия и завершение

**Цель:** Подтвердить принятый scope и возвращение к основной разработке.

**Зависимости:** Реализованные R8 slices, решённые blockers либо явно принятые scope changes.

**Входит:** Поведение/данные/integrations, visual parity, ограничения, пользовательская приёмка.

**Не входит:** Деплой, автоматический старт Phase 11, закрытие непроверенной Phase 7, заявление о полном продукте.

**Результат:** Принятый redesign с REDESIGN_DONE и сохранённой точкой roadmap.

**Критерии приёмки:** C01–C17 проверены в реализации, необходимые tests/native/web выполнены; незавершённое перечислено и принято.

**Проверка:** Existing/focused regression tests, migration checks если отдельно менялись, native Android/iOS по доступности, визуальное сопоставление frames.

**Решения пользователя:** Принять R9 и поставить REDESIGN_DONE; затем отдельно решить следующую продуктовую задачу.

**Статус фазы:** `todo`.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R9.1 | REQ-PRESERVE-01..04, REQ-MODEL-05..08 | Existing tests в audit + CONTRIBUTING; root/nested routes | Проверить UID/auth/guest/offline/restart/review/notes/local-save/sync и данные без reset/cleanup. | C-GITHUB, C-MODEL, C10, C13 | Реальные command results и state/data acceptance; ограничения iOS отдельно. | todo |
| R9.2 | REQ-CHECK-01..02, REQ-NAV-01..05, REQ-WEB-04 | Финальные accepted Figma frames и actual UI | Сравнить layout/actions/photo/badges/links/tablet/a11y; public payload/private isolation отдельно. | C01–C17, C-WEB, C-MOTION | Matched screenshots, визуальный review + public security checks в разрешённом scope. | todo |
| R9.3 | REQ-WORKFLOW-07..08 | Этот журнал, README.md, product-spec.md | Записать limitations/accepted scope, приёмку REDESIGN_DONE и предложение вернуться перед Phase 11. | C-SCOPE | Явное решение пользователя и обновлённый status; незакрытое не помечать done. | todo |

---

## Зависимости реализации

R1–R7 могут спроектировать все заданные функции без изменения backend. Перенос
невозможной модели нельзя решить переименованием вкладок. До R8.1 для каждого
GAP пользователь согласует отдельную продуктовую задачу или явное ограничение
implementation scope. Такие задачи принадлежат основному roadmap и требуют
отдельного разрешения; пока основная разработка на паузе, они не запускаются.

| **Зависимость из audit** | **Основной roadmap / решение перед R8** |
|:---|:---|
| GAP-DATA-01..03 | Общая база/library/multiple documents/association/profile-review: предлагаемые дополнения к domain/persistence/sync tasks Phase 6/8 и web 13b, без отмены прежней приёмки |
| GAP-MEDIA-01 | Phase 11 Media: camera/gallery/upload/media lifecycle/Storage; дизайн состояний возможен раньше |
| GAP-PUB-01, GAP-PUB-02 | Phase 8 publication contract + Phase 13c public UI: multiple snapshots/URL и отдельное public validation hardening; не считать client codec доказательством server security |
| GAP-URL-01 | Политика принята D019: постоянный адрес документа, независимый от username/названия; unpublish закрывает доступ, повторный Publish использует тот же адрес. Спроектировать route scheme и миграцию: нынешний adapter удаляет старый username snapshot/claim; target-контракт ещё не реализован |
| GAP-AUTH-01, GAP-ACCOUNT-01 | Открытая Phase 7 и отдельно спланированные account management/linking/reauth/delete; Google sign-in не означает provider linking |
| GAP-CONTACT-01 | Public contact/privacy contract отдельно; Inbox/Contact/FCM — Phase 14, location integrations — Phase 12 |
| GAP-WEB-01 | Phase 13a → 13b → 13c: новый Next.js runtime/owner/public scenarios; R6 — только дизайн |
| GAP-PREF-01 / native share | Phase 15 sharing и отдельно согласованные notification/reduced-motion settings; существующий app stack сохраняется |

Никакие перечисленные prerequisites не отмечены выполненными в R0. Если они
не готовы, зависимая R8-задача получает blocked, независимый поддерживаемый UI
переносится в согласованном scope. Уменьшение scope фиксируется в журнале и
утверждается пользователем. R9 не объявляет весь запрошенный редизайн завершённым
при нерешённых blockers; completion возможен после их закрытия либо явной
приёмки пересмотренного scope с конкретными исключениями.

---

## Проверки и результаты

Прослеживаемость: requirement → task в таблицах выше и requirements →
S-* в screens → C-* ниже → фактический результат/evidence. Сейчас есть
статическое доказательство расхождений; target UI ещё не создан. Поиск текста
в source не подтверждает выполнение визуального требования.

| **Check** | **Способ проверки и ожидаемый результат** | **Задача / экран** | **Результат R0** |
|:---|:---|:---|:---|
| C01 | Render + walkthrough: на roots нет greeting/logout/STACKCARD DEMO | R4.1..4, R8.3; roots | Target не выполнен; source/Figma conflicts в audit |
| C02 | Нажать gear на каждом root, открыть нужные settings/back | R1.2, R4.5, R4.6, R4.7a..c, R8.3; S-SETTINGS | Runtime gear-flow отсутствует |
| C03 | Нажать ровно Все/Резюме/Проекты; Все включает Portfolio | R4.1, R7.1, R8.3; S-HOME | В current UI нет такого фильтра |
| C04 | Визуально проверить Home без readiness/progress/old quick actions | R4.1, R9.2; S-HOME | Legacy source содержит запрещённые элементы |
| C05 | Проверить порядок actions/search/list без categories/hero | R4.3, R9.2; S-PROJECTS | Current source и прежний Figma содержат filters |
| C06 | Изменить имя/ник/фото/contacts/links, validation+save+reopen | R4.5, R4.6, R4.7a..c, R8.3; Settings groups | Полный сценарий отсутствует |
| C07 | Выбрать/убрать фото; проверить Resume editor и preview | R5.1a,d, R9.2; Resume | Avatar URL есть; нужного photo flow/renderer нет |
| C08 | Inspect semantics + render icon/text/+N/wrap TechnologyBadge | R3.2, R4.3, R9.2; cards/detail | Runtime использует slash text |
| C09 | Published card/detail: Copy/Open/Share после повторного открытия; draft без URL | R5.4b,c, R9.2; S-SHARE/cards | Document link UI отсутствует |
| C10 | Change→local Save→sync ACK→explicit Publish; previous public snapshot unchanged | R5.4a, R8.4, R9.1; editors/publish | Save/sync contracts есть; user publication flow нет |
| C11 | Tablet portrait/landscape: та же bottom nav, нет sidebar/rail | R7.2, R8.3, R9.2; roots | Current shell имеет rail >=700 px |
| C12 | Back/close, system navigation, cancel/unsaved handling и возврат origin | R1, R5, R7.1, R9.1; nested | Existing nested Back есть; новая IA не проверена |
| C13 | Empty/loading/error/retry/offline/long content; ввод и previous success не теряются | R3.4, R7.3, R9.1; все | Shared states есть; полный target набор pending |
| C14 | sRGB contrast всех actual text/surface/disabled/focus pairs; normal text >=4.5:1 | R3.1, R7.3, R9.2; DS/UI | Полная target матрица pending; R0 расчёты ниже |
| C15 | Metadata/hit tests реальных tap regions >=48×48 logical px, включая Copy/back/gear | R3, R7.2, R9.2; controls | Existing Button min48; полный target UI pending |
| C16 | Text scale1/2 и OS увеличенный текст, ru/en, узкие экраны/keyboard | R7.2, группы R8.3–R8.5, R9.2 | Target ещё не создан; legacy nav скрывает labels |
| C17 | Anonymous payload/renderer без private notes/contacts/account/editor; absent/unpublished | R6.4, R9.2; public | Client projection есть, web отсутствует; server hardening gap |
| C-MODEL | Один Project в разных outputs; create+attach/remove relation; profile diff/local override | R1.1, R5.1c, R5.3b, R8.1 | Singleton source, migration pending |
| C-GITHUB | Selection/Add/reimport/Accept/Ignore/stale/UID/offline; curated fields сохраняются | R5.2b,c, R9.1 | Source implementation есть, R0 tests не запускались |
| C-ASSET | License/provenance fonts/icons/photos; настоящий текст badges, editable Figma | R2.2, R3.2, R7.3 | R2.2: оригинальные vectors, editable families, Noto SIL OFL 1.1 проверена; финальный набор/native assets ещё не приняты |
| C-PALETTE | Exact dark HEX/semantic roles, lime primary, error red; light actual pairs | R2.1, R3.1, R8.2 | R2.1 dark contrast и R2.2 ink/paper 18.46:1 проверены; full light DS/native pending |
| C-WEB | Полный visitor/owner/public path, реальные CTA и download availability | R6.1..4, R8.5 | Web source отсутствует; legacy concepts не runtime |
| C-MOTION | 180–280 ms, ввод доступен, reduced/static variants и Copy feedback | R3.4, R7.3, R9.2 | Только target requirement; current timings не перенесены |
| C-SCOPE | Изменения только разрешённой фазы; сохранены user edits/assets/history/stack | R0.5, R8.1, R9.3 | Документация-only, финальные diff/hash checks фиксируются ниже |

Обычный текст проверяется по 4.5:1 даже при небольших metadata размерах.
48 logical px — критерий этого проекта. WCAG web target-size и Flutter logical
px не смешиваются в отчётах. Figma keyboard/focus/semantics спецификации не
доказывают работу реального IME, TalkBack или VoiceOver.

На R8/R9 команды берутся из фактического [CONTRIBUTING](../../CONTRIBUTING.md#проверки).
macOS, zsh/bash, cwd `apps/mobile`: `dart format --output=none --set-exit-if-changed lib test integration_test`,
`flutter analyze`, `flutter test` с релевантными файлами.
Rules tests из cwd `firebase`: `npm run test:rules` только при отдельно разрешённом
изменении backend contract. Native live acceptance имеет отдельные предусловия
и opt-in; обычный test не доказывает Android/iOS/web readiness.
Web checks назначаются по созданным manifests, отсутствующие npm scripts не придумываются.

### Фактические результаты R0

- Прочитаны инструкции, roadmap, действующий source/config и existing design docs.
- Git status показал исходные user edits; branch `redesign/full-app` сохранена.
- Figma root read подтвердил девять страниц; metadata и пять выбранных renders
  прочитаны; Figma не изменялась. Полный prototype старой итерации не прогонялся.
- Внешние источники и ограничения доступа зафиксированы в references.
- Target UI/native/backend tests в R0 не запускались: код не изменялся.
- Validator оформления, H1, fenced-блоков, anchors и локальных ссылок: шесть новых
  документов и четыре изменённых указателя — PASS. git diff --check — PASS.
- Реестр: 78 уникальных requirements, все 29 исходных IDs сохранены; новые
  требования связаны с задачами и экранами, вымышленных requirement IDs нет.
- Hash-сверка прежних docs/design и root README подтвердила отсутствие изменений.
  Продуктовый source/config, dependencies и Git staging не менялись.
- Markdown-render в целевом viewer не проверен; открытие plan было поставлено
  приложением в очередь, это не подтверждает успешное отображение.
- Результат C01–C17 для нового дизайна: pending. R0 не устанавливает DESIGN_READY/REDESIGN_DONE.

Расчёт в R0 по WCAG sRGB relative luminance даёт следующие пары из заданной
палитры. Это числовая проверка цветов, не приёмка будущего экрана.

| **Пара** | **Контраст / применение** |
|:---|:---|
| textMuted #737884 / background #070708 | 4.55:1; проходит 4.5 только для этой пары |
| textMuted / surface #0D0E11 | 4.36:1; обычный текст не проходит |
| textMuted / surfaceElevated #14161B | 4.09:1; обычный текст не проходит |
| textMuted / surfaceActive #1B1E24 | 3.78:1; обычный текст не проходит |
| ink #070708 / lime #C7FF1A | 17.02:1; подходит для текста на lime fill |

HEX сохраняются. На поверхностях с недостаточным контрастом важный текст
использует подходящую textSecondary/textPrimary роль из той же палитры;
textMuted не назначается автоматически. Light-theme роли и все state-пары
проверяются в R3.1 и R7.3. Источник метода —
[WCAG Contrast Minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

### Фактические результаты R1.1

Исторический срез до D013: R1.1 ожидала review. Текущая приёмка и продолжение
зафиксированы в D013 и результатах R1.2 ниже.

- Поручение использовать план и начать первую фазу принято как согласование R0
  и разрешение R1.1, без повторного запроса подтверждения; D009.
- Проверены текущие router, singleton PortfolioContent и source gaps R0.
  Read-only Figma inspection подтвердил девять прежних страниц до записи.
- Создана новая страница `StackCard Design v2 / UX` (58:7) и три IA frames:
  Navigation 58:8 (1600×1529), Ownership 58:41 (1600×1814),
  Lifecycle and walkthrough 58:75 (1600×1683). Всего 95 новых nodes, включая
  страницу, Auto Layout containers и editable text; старые nodes не редактировались.
- Три screenshots просмотрены: текст читается, обрезаний и наложений не обнаружено.
  Это схемы IA, не low-fi screens, не новый выбор направления/шрифтов и не prototype.
- C-MODEL, C01, C02, C11, C12 сверены на уровне IA по
  [сценариям](screens.md#r11--информационная-архитектура): reuse/remove/create,
  overrides, explicit Publish, четыре roots, Home filter и origin/Back.
  Tap targets, настоящий Back, tablet UI и runtime/data regression остаются pending.
- macOS, zsh: `check_docs.py --require-hero --require-badges` проверил пять
  изменённых документов — PASS для оформления, локальных ссылок и anchors.
  `git diff --check` — PASS. Сверка с HEAD сохранила все 78 requirement IDs
  и их строки прослеживаемости; все 13 требований R1.1 связаны с этой задачей.
  Итоговый diff содержит только пять нужных docs; staged diff пуст.
  Markdown-render документов в целевом viewer не проверен.
- R1.1 и R1 ожидают пользовательской приёмки. R1.2–R1.4 не начаты;
  D007 output URLs/rename и последствия global delete Project остаются открытыми.
  Новое UX-предложение: публичный Portfolio открывает выбранное Resume только
  при наличии его опубликованной версии; это ещё не принятое backend-решение.
- Продуктовый source, configs, зависимости, storage, staging и история Git
  не изменялись; Flutter/native/backend tests в этом срезе не запускались.
  DESIGN_READY и REDESIGN_DONE не установлены.


---

### Фактические результаты R1.2

Исторический срез первоначального создания, до правок и приёмки D015.
Актуальные изменения и переход к R1.3 записаны ниже.

- Поручение «переходи к следующей фазе» принято как приёмка R1.1 и разрешение
  следующей задачи R1.2, D013. Последовательность R1.3/R1.4 → R2 сохранена.
- Изучены текущие Home/theme/settings, локальные Figma components и semantic
  variables. Переиспользованы mains кнопок 4:4/4:9, поля 4:21, gear 38:1758,
  SettingsRow 38:1906, Copy 38:1795 и четыре Navigation variants
  4:174/4:192/4:210/4:228. Component properties и labels проверены до записи.
- На существующей UX page 58:7 созданы boards 61:7, 61:491, 61:833,
  каждый 1752×2273 с восемью phone frames 390×844. Всего 959 новых editable
  nodes; image fills отсутствуют. Использованы существующие Noto Sans и tokens;
  новые components/variables, direction/logo/font selection не создавались.
- Первый render выявил clipped Auto Layout rows и фиксированную высоту
  пояснений; исправлены horizontal sizing и text auto-height. Три итоговых
  board screenshots и отдельный F24 просмотрены. Content bounds всех 24
  экранов помещаются в body; root navigation/pinned Save видимы.
- [Static walkthrough](screens.md#r12--low-fi-основных-сценариев) сверил Home
  filters/empty/recent types/Copy, четыре roots, Settings origin/Back,
  базовый профиль, public contacts отдельно от login email, label+URL/reorder,
  failed Save/Retry, unsaved, rename warning и local Save без Publish.
  Main path F02 → F08 → база/контакты → F24 → origin → F05 → F16
  останавливается на входе в wizard R1.3.
- C01–C06/C12 представлены на уровне low-fi; prototype reactions, tap/system
  Back, keyboard/text scale/tablet, media, reopen/storage/auth/sync/publication
  не проверены. Providers/reauth и planned account/privacy/app functions
  обозначены как target и сохраняют GAP-ACCOUNT-01/GAP-CONTACT-01/GAP-PREF-01.
- macOS, zsh: `check_docs.py --require-hero --require-badges` проверил пять
  документов — PASS; `git diff --check` — PASS. Сверка с HEAD сохранила
  все 78 requirement IDs/строк; 12 Home/Settings/Nav rows связаны с R1.2,
  24 frame IDs совпадают с созданными nodes. R1.3/R1.4 остались todo;
  diff содержит только пять docs, staged diff пуст. Markdown-render
  документов в целевом viewer не проверен; Flutter/native/backend tests не запускались.
- R1.2 awaiting_review, R1.3/R1.4 todo. D007 URL/rename и global delete
  Project consequences остаются открытыми. DESIGN_READY/REDESIGN_DONE
  не установлены; runtime/schema/configs/dependencies/Git mutations не выполнялись.

---

### Правки и приёмка R1.2

- По прямому запросу пользователя последовательные кнопки уменьшены и
  размещены на одном уровне: 20 кнопок в девяти horizontal Auto Layout rows
  70:519–70:527. Ширина двух кнопок 167 px, трёх — около 109 px; gap 8 px,
  высота нажатия сохранена 48 px, подписи 13 px. Исправлены ширины labels,
  короткие подписи сохраняют смысл действий и помещаются в строку.
- У поиска Projects удалён внешний heading 61:360. В input 61:361
  включена существующая векторная лупа 18:204; поле 342×48 с подсказкой
  «Название проекта». Это правило применяется и к поискам R1.3.
- Три итоговых R1.2 board renders просмотрены после правок: rows/labels
  помещаются, лупа видна. Текущие boards содержат 967 descendants и три
  board roots; прежние 959 nodes выше относятся к первоначальному срезу.
- Условие «после этого, переходи» выполнено: R1.2 done, разрешена R1.3,
  D015. Отдельный переход к R2 не разрешён до завершения R1.4.

### Фактические результаты R1.3

Исторический срез создания до D017: задача ожидала приёмки. Она принята
последующим прямым поручением продолжить; исходные проверки ниже сохранены.

- Проверены текущий plain `resumeText` editor, manifests/theme, существующие
  Figma components/styles/tokens. Структурированный Resume остаётся целевой
  моделью; runtime/schema/storage/media этим срезом не реализованы.
- На UX page 58:7 созданы boards 72:537, 72:941, 72:1242 по 1752×2273;
  каждый содержит восемь phone frames 390×844. Переиспользованы buttons,
  input/search, SettingsRow и Stepper 38:2451. Прогресс 11 экземпляров
  Stepper исправлен: число активных сегментов совпадает с шагом 1–5.
- Создан один временный low-fi component ResumeDocument 72:521 с
  `Show photo` и `Headline`, существующими Noto Sans styles и semantic
  variables. В G05 фото представлено wireframe-слотом; G07 использует тот
  же component без фото, имя занимает полную ширину. Это не финальная DS R3
  и не evidence настоящего media asset или camera pipeline.
- Итоговая структура трёх boards: 1003 descendants (372 TEXT, 293 FRAME,
  216 INSTANCE, 87 RECTANGLE, 35 VECTOR), плюс три board roots и component
  с 15 descendants. Image fills отсутствуют; новые variables/styles,
  logo/direction/font selection не создавались; legacy pages/mains сохранены.
- [Static walkthrough](screens.md#r13--low-fi-resume-wizard-и-редактора):
  F16 → G01–G05 → Save G06; необязательные секции G09–G11 допускают skip;
  Back сохраняет выбор; title validation G08 и photo failure G13 удерживают
  остальные поля. G16 → секция G17–G20/G24 → Apply G21 → отдельный Save
  G06/G22. Discard/Continue/Save различаются в G15; review G23 сохраняет
  local override. Remove relation G20 не удаляет Project из library.
- Первый осмотр выявил одинаковый прогресс Stepper и лишнюю фиксированную
  ширину имени без фото; исправлены только новые экземпляры/component.
  Три итоговых board screenshots просмотрены. Bounds всех 24 phone frames
  проверены по их реальным IDs: содержимое помещается, включая G14 с условной
  keyboard area 264 px и pinned actions над ней. В R1.2/R1.3 нет вертикальных
  последовательностей соседних кнопок; все четыре поиска имеют лупу без
  внешнего заголовка.
- C07/C10/C12/C16 представлены схемами и captions; это не закрытая
  interactive/native acceptance. Реальные выбранное фото, Back/input retention,
  camera/media permissions, keyboard, scale 2/tablet, reopen/storage/sync и
  publication не проверены. Кликабельные переходы создаются в R7.
- macOS, zsh: `check_docs.py --require-hero --require-badges` проверил пять
  документов — PASS; `git diff --check` — PASS. Сверка с HEAD сохранила все
  78 requirement IDs и 78 trace rows; 24 R1.3 frame IDs совпадают с Figma
  ledger. R1.2 done / R1.3 awaiting_review / R1.4 и R2 todo согласованы;
  diff содержит только пять docs, staged diff пуст. Markdown-render в целевом
  viewer не проверен; Flutter/native/backend tests не запускались.
- R1.3 awaiting_review (D016), R1.4 todo. Открытые D007/gaps сохранены;
  DESIGN_READY/REDESIGN_DONE не установлены. Продуктовый код, backend,
  configs/dependencies и Git mutations не менялись; Flutter tests не запускались.

---

### Фактические результаты R1.4

Исторический срез до D020: R1.4 ожидала review. Текущий статус после цветовых
правок и перехода к R2.1 записан ниже; предыдущие результаты сохраняются.

- Прямое поручение «переходи к следующему этапу» приняло R1.3 и разрешило
  R1.4, D017. До построения проверены текущие Project editor, GitHub review,
  draft Save, publication adapter и public codec, existing components/tokens/styles.
  Независимый read-only contract audit подтвердил различия между работающими
  contracts и target multiple documents/association model; source не менялся.
- На UX page 58:7 созданы пять boards 78:1012–78:1016 с 40 phone frames
  390×844. Реальные размеры и каждый H01–H40 перечислены в
  [screens](screens.md#r14--low-fi-projects-portfolio-и-публикации).
  Переиспользованы Buttons 4:4/4:9, Input 4:21, SettingsRow 38:1906,
  gear/nav и search icon 18:204; legacy mains/pages не менялись.
- Создан один временный PortfolioDocument 79:1012, 342×398, 27 descendants
  и properties `Show photo`/`Show Resume link`. H24/H37 используют его
  без фото с выбранным опубликованным Resume. Это low-fi reuse с existing
  Noto Sans styles/semantic variables, не финальная DS R3. Новых tokens,
  styles, logo или выбора шрифтов нет; image fills отсутствуют.
- Итог пяти boards: 1418 descendants (534 TEXT, 456 FRAME, 300 INSTANCE,
  55 RECTANGLE, 73 VECTOR), плюс пять board roots. Main component содержит
  ещё 28 nodes вместе с root; всего 1451 node в новом scope.
- Static walkthrough покрывает manual create/validation/Apply/Save/error,
  GitHub dedup и protected description, explicit Accept/Ignore/Cancel и stale
  review, Portfolio create/attach/order/featured/visibility/local override,
  remove relation с сохранением library, preview и отдельный Publish.
  Save local → pending sync → ACK текущей draft mutation → явный Publish;
  public snapshot не меняется от Apply/Save/sync. Неизвестный исход сетевого
  Publish/Unpublish требует проверки статуса до повторной отправки.
- Финальный read-only review выявил неточную гарантию старой public версии
  при неизвестном результате Publish. H28 и его описание исправлены:
  private draft сохранён, сервер уже мог завершить операцию, до сверки
  показывается last-known состояние. Действие — «Проверить статус»;
  обновлённый render и label bounds просмотрены, overflow нет.
- Первые renders выявили длинную подпись GitHub review: заменена на
  «Отклонить». Технические пояснения перенесены в captions, H09 показывает
  недоступную повторную загрузку, H35 — «Проверить статус». Пять итоговых
  board renders просмотрены; bounds всех 40 frames и action labels проходят
  проверку, соседние действия горизонтальны с tap height 48 px.
  Все шесть поисков имеют лупу внутри поля без внешнего заголовка.
- Пользователь выбрал «Постоянный адрес документа», D019: rename документа
  и username сохраняет ссылку. H39 и ранее принятый F20 обновлены под это
  решение, оба renders просмотрены; H39 rename меняет draft, public content
  обновляется отдельным Publish. Unpublish закрывает доступ; republish
  сохраняет адрес. Duplicate H40 создаёт новый private document и новые
  associations, без копирования статуса/публичной ссылки исходника.
- C-GITHUB/C-MODEL/C09/C10/C12/C17 представлены low-fi/captions, не runtime
  acceptance. H12 показывает network failure с сохранённым cached list;
  rate-limit deadline и другие typed failures описаны captions и не имеют
  отдельного rendered state. Clipboard/native share, network/Firebase,
  anonymous reader security, Back/input persistence, auth/owner races,
  media, keyboard/scale 2/tablet и кликабельный prototype не проверены.
- Текущий singleton PortfolioContent/plain resumeText, глобальные project
  featured/visible и username publication adapter остаются прежними.
  GAP-DATA-01..03, GAP-PUB-01/02 и GAP-URL-01 требуют отдельной реализации
  до зависимого R8; принятая URL-политика не означает backend готовность.
- R1.1–R1.3 done; R1.4 awaiting_review, D018. Следующий возможный шаг после
  её приёмки — R2.1. DESIGN_READY/REDESIGN_DONE не установлены, runtime,
  configs/dependencies и Git mutations не менялись; Flutter tests не запускались.
- macOS, zsh: `check_docs.py --require-hero --require-badges` проверил пять
  документов — PASS; `git diff --check` — PASS. Сверка с HEAD сохранила все
  78 requirement IDs и 78 trace rows; 40 H frame IDs совпали с фактическим
  Figma ledger, 24 G frame IDs сохранены. R1.3 done / R1.4 awaiting_review /
  R2.1 todo согласованы; diff содержит только пять docs, staged diff пуст.
  Markdown-render в целевом viewer не проверен; native/backend tests не запускались.

---

### Фактические результаты цветовых правок и R2.1

Ниже сохранён исходный срез D020/D021 до приёмки сравнения D022 и отдельной
работы R2.2. Текущие статусы приведены в таблице задач и следующем разделе.

- Прямое поручение подсветить важные действия и некоторые детали, затем
  продолжить, выполнено: R1.4/R1 done, разрешена R2.1, D020. На 88 low-fi
  frames выделены 74 основных действия, девять опасных действий, 12 выбранных
  controls и десять заголовков ошибок/ожидания. 16 disabled controls сохранили
  нейтральное состояние. Main components старой библиотеки не менялись.
- Сохранены размеры/позиции low-fi, горизонтальные ряды кнопок и search с
  лупой без внешнего заголовка. Bounds подписей всех 88 screens — PASS;
  просмотрены renders 61:7, 72:537, 78:1012, 78:1013, 78:1015. После исправления
  selected-fill на surfaceActive дополнительно проверен render 61:7.
- Создана page `99:7 / StackCard Design v2 / Directions` и сравнение `99:8`,
  1400×2297. A — 99:10, B — 99:11: по три editable 390×844 Home/public Resume/
  Settings, [точные IDs и fixtures](screens.md#r21--два-визуальных-направления).
  Старые девять страниц и UX page сохранены. R2.1 awaiting_review, D021;
  направление ещё не выбрано, R2.2/R2.3 и R3 не начаты.
- Перенесены реальные variables/text styles и совместимые instances:
  Button, SettingsButton, SettingsRow, CopyLinkButton, BottomNavigation,
  ProjectCard. Пять временных mains вынесены за comparison wrapper: два
  оригинальных векторных знака, две DocumentCard и один адаптированный clone
  ProjectCard B. Новых variables/text styles нет; это ограниченные assets
  сравнения R2.1, не финальная DS R3.
- Одинаковый fixture: three-record mixed Home, Все selected, два published
  документа с отдельным Copy; Resume с именем/ролью/городом/bio/выбранными
  контактами/навыками/образованием/проектом; пять Settings groups и Back к Home.
  Нет fake-avatar, опыта/лет/работодателей, dashboard/progress или account
  controls у public visitor. No-photo композиции полноценны; media assets
  в этих шести пилотах не требуются.
- Все тексты шести пилотов — Noto Sans, включая Latin и Cyrillic. Локальный
  bundled Noto содержит русские буквы/Ё и Latin; DM Sans не покрывает русский
  набор и здесь не используется. SIL OFL 1.1 проверена в существующих
  `apps/mobile/assets/fonts/Noto_Sans_OFL.txt` и `DM_Sans_OFL.txt`. Это не
  утверждение о byte-identical font-файле Figma или native shaping.
- Предварительный sRGB contrast: ink/lime 17.02:1; white/lime 1.08:1, поэтому
  текст основной кнопки тёмный. textSecondary на dark surfaces 7.02–8.47:1;
  textMuted на elevated 4.09:1, поэтому значимые метаданные secondary.
  Ink/error #F06272 — 6.42:1. Проверка следует
  [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
  и [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html).
  Это preliminary dark-проверка; focus/light/native semantics остаются R3/R7/R8.
- Во время сборки исправлены тесная Copy-подпись и reflow карточки Project B.
  Все шесть phone bounds, текстовые контейнеры и painted extents — PASS;
  финальный comparison render просмотрен после исправлений. Прозрачные
  SVG viewports старых icons не считаются paint overflow: видимые shapes
  находятся внутри controls/screens. Независимый read-only review подтвердил
  content/state/font равенство; legacy selected-fill заменён на surfaceActive.
- 7–8 px тексты миниатюр B — дополнительный preview; читаемые названия,
  статусы и действия дублируются рядом. TechnologyBadge icon/+N/wrap,
  16–48 px/mono/wordmark/app-icon specimens, light/scale/keyboard/motion,
  prototype, native Back/clipboard/share и public security здесь не закрыты.
  Runtime/schema/backend/configs/dependencies не менялись; Flutter tests
  не запускались. DESIGN_READY/REDESIGN_DONE не установлены.
- macOS, zsh: `check_docs.py --require-hero --require-badges` проверил пять
  документов — PASS; `git diff --check` — PASS. Сверка с HEAD сохранила 78
  requirement IDs и 78 trace rows, F24/G24/H40 и шесть R2.1 IDs совпадают с
  реестром/ledger. Final phone bounds PASS; все тексты пилотов Noto Sans,
  image-fills отсутствуют в выбранном no-photo fixture. R1 done / R2.1
  awaiting_review / R2.2–R2.3 todo согласованы; изменены только пять docs,
  staged diff пуст. Markdown-render в целевом viewer не проверен.

---

### Фактические результаты R2.2

Ниже сохранён исходный срез D023 до выбора A в D024. Текущая приёмка R2
и foundations R3.1 записаны отдельно; прежние результаты не переаттестованы.

- Поручение «переходи к следующему этапу» после R2.1 принято как приёмка
  сравнительного результата и разрешение R2.2, D022. Выбор A/B не сделан.
  R2.1 done; R2.2 awaiting_review D023; R2.3/R3 todo.
- Создан [Brand Comparison 110:268](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=110-268),
  1400×1992, page 99:7. Две колонки содержат wordmarks, 20 small-size mark
  instances, mono и app icons, восемь шапок тех же Home/public Resume 390×64.
  [Точные IDs и usage](screens.md#r22--знак-написание-и-иконка-приложения).
- Шесть component sets, 18 main variants: Mark/Wordmark — Tone, AppIcon —
  Appearance. Исходные mark mains 100:10/100:13 сохранены; B получил две
  внутренние карточки, связанные instances обновились. Создано 16 дополнительных
  mains и два experimental Noto Sans wordmark text styles; variables — 0.
  Внешние logo/image assets не импортированы, legacy S/старые страницы сохранены.
- Current pubspec и Noto SIL OFL 1.1 прочитаны; во всех 83 text nodes — Noto Sans,
  Latin/Cyrillic specimen содержит живой текст. Ink/lime — 17.02:1;
  ink/paper — 18.46:1; lime/paper — 1.08:1, поэтому Light использует Ink.
  Font registration/licensing не доказывают native shaping или byte-identical
  font-файл Figma. Новые font files/dependencies не добавлены.
- Small grids 113:311/113:470 просмотрены в естественном размере **628×255**:
  16/20/24/32/48 px в Accent/Ink, внутренние vectors масштабированы rescale.
  A читается чище на 16; у B рамка узнаваема на 16, две карточки яснее с 24.
  Рекомендованный минимум B — 24 px; UI headers используют 32 px.
- Исправлена высота small-size cells/rows для 48 px и подписи. Итоговый
  full-board render просмотрен после правки: overflow текста/paint — 0,
  image fills — 0; 317 descendants, auto-height всех texts. Независимый
  read-only audit подтвердил 18 variants, exact paints и containment восьми
  UI-шапок; восемь painted settings paths помещаются в controls 48×48,
  несмотря на четыре унаследованных непокрашенных SVG viewBox 24 внутри 22.
  Settings pilots сохраняют Back-шапку без дополнительного logo.
- Light specimens проверяют brand readability; full light DS/scale/keyboard/
  motion/prototype, native font shaping и Android/iOS icon exports предстоят.
  Runtime/schema/backend/configs не менялись; Flutter tests не запускались
  для этой Figma/doc-only задачи. DESIGN_READY/REDESIGN_DONE не установлены.
- macOS, zsh: `check_docs.py --require-hero --require-badges` — пять docs PASS;
  `git diff --check` — PASS. Изменены только пять существующих docs, staged diff
  пуст. Сверка сохранила 78 requirement IDs/78 уникальных trace rows,
  F24/G24/H40 и шесть pilot IDs; family/UI IDs согласованы с фактическим ledger,
  R2.1 done / R2.2 awaiting_review / R2.3 todo — PASS.
  Markdown-render в целевом viewer отдельно не проверен.

---

### Фактические результаты R2.3 и R3.1

- Прямое поручение выбрать бренд A и перейти к следующей фазе принято D024:
  R2.2/R2.3/R2 done. Связанные A / Cyber Editorial pilots — основа R3;
  финальная типографика и полная DS остаются на приёмку. B сохранён как история.
- Три существующих sets A переименованы в `StackCard / v2 / Mark`,
  `Wordmark`, `AppIcon`, IDs 110:282 / 111:284 / 111:297 сохранены.
  Main variants и связанные instances не пересозданы; legacy не изменён.
- Создана page 121:7 `StackCard Design v2 / DS`: [Foundations 123:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=123-7)
  1400×1657 и [Typography and Metrics 125:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=125-19)
  1400×1471. Оба editable Auto Layout, explicit Dark/Light modes, live ru/en texts.
- Повторно использованы три collections, существующие metrics и восемь UI
  text styles. Добавлены ровно семь variables: пять semantic color aliases,
  Light primitive #147B44 и displayA=40; один Noto Sans ExtraBold40/48 style.
  Исходные 25 color variables и все 20 прежних text styles сохранены.
  Новый semantic helper применён к существующей collection, без параллельной DS.
- На четырёх поверхностях каждого mode рассчитаны 64 допустимые text pairs
  и 16 controlOutline/focus pairs: ≥4.5 и ≥3 соответственно. Восемь отдельных
  диагностических textMuted pairs показывают три Dark-fail; metadata использует
  textMeta. Light successText имеет отдельный читаемый primitive; lime CTA
  получает Ink boundary в Light. Значения и usage rules — в screens.
- Независимый read-only расчёт подтвердил исходные пары. Проверка фактических
  resolved paints/aliases/modes и ближайшего непрозрачного фона для всех
  **246 text nodes — PASS**, минимум **4.5853488535:1** до округления.
  Шесть static controls 588×48 bound к существующему touchTarget48;
  samples показывают обычную границу/focus/primary, не являются API компонентов.
- Девять type roles в обеих темах используют Noto Sans; существующие pubspec
  и SIL OFL 1.1 прочитаны. Статический длинный ru specimen в ширине350
  при 16/24 занимает24 px, при 32/48 переносится и занимает144 px.
  Это reflow-пример, не проверка OS text scaling, keyboard или native shaping.
- Оба итоговых composition renders просмотрены: visible overflow — 0,
  image fills — 0, unbound text fills — 0; все texts — Noto Sans.
  Состояния/компоненты R3.2–R3.4 не создавались; R3.1 awaiting_review D025.
  Runtime/schema/backend/configs/fonts/dependencies не изменены; Flutter tests
  для этой Figma/doc-only задачи не запускались. Gates не установлены.
- macOS, zsh: `check_docs.py --require-hero --require-badges` — шесть docs PASS;
  `git diff --check` — PASS. Сверка с началом этой задачи сохранила 78 requirement
  IDs/78 уникальных trace rows, все строки F24/G24/H40 и pilot/brand IDs.
  Фактический Figma ledger согласован с двумя boards, семью variables и одним
  style; R2 done / R3.1 awaiting_review / R3.2–R3.4 todo — PASS.
  Diff содержит только шесть существующих docs; staged diff пуст.
  Markdown-render в целевом viewer отдельно не проверен.

---

## Журнал решений

| **ID / дата** | **Решение / источник** | **Статус и влияние** |
|:---|:---|:---|
| D001 / 2026-10-05 | Полное последнее задание пользователя: только R0; freeze новых функций | Принято заданием; эта работа не разрешает R1/Figma edits/code |
| D002 / 2026-10-05 | Приоритет latest requirements; legacy как functional reference | Принято; greeting/carousel/categories/recolor старого S заменены новым контрактом |
| D003 / 2026-10-05 | Общая база/library, multiple outputs, association order/featured/visibility | Принято; миграция пока продуктовый gap, не действие R0/R8 UI |
| D004 / 2026-10-05 | Существующие документы обновляются через review; draft и public разделены | Принято; live inheritance/тихий Publish не проектируются |
| D005 / 2026-10-05 | Palette/nav/home/settings/photo требования не переуточняются | Принято; точные roles/запреты в requirements |
| D006 / 2026-10-05 | Старые docs/Figma/assets и незакоммиченные правки сохраняются | Принято; новая версия размещается отдельно после approval |
| D007 / 2026-10-05 | Новый URL/slug и rename/старые ссылки | Выбор политики закрыт D019: постоянный адрес документа. Историческое предупреждение не обещало redirect; точная route scheme/миграция backend остаётся GAP-URL-01 |
| D008 / 2026-10-05 | Prerequisites перед R8 / возможный scope change | awaiting_review; не начинать backend/web scaffold автоматически |
| D009 / 2026-10-05 | «используй этот план и приступай к разработке первой фазы» | Принято прямым поручением: R0 done, разрешена R1.1; перенос UI/backend не разрешён |
| D010 / позднее | R2 direction/logo и R7 DESIGN_READY | Выбор бренда A зафиксирован D024 с selected IDs; R7 DESIGN_READY остаётся todo и требует отдельной итоговой приёмки |
| D011 / позднее | R8 отдельное разрешение и R9 REDESIGN_DONE | todo; перечислить actual scope/limitations и evidence |
| D012 / 2026-10-05 | Три editable IA frames R1.1 и схема ownership | awaiting_review; новые IDs в screens, R1.2–R1.4 ещё todo; создание не равно приёмке |
| D013 / 2026-10-05 | «переходи к следующей фазе» после отчёта R1.1 | Принята R1.1; разрешена следующая задача R1.2. R2 ждёт завершения R1.2–R1.4; код/backend/Git mutations не разрешены |
| D014 / 2026-10-05 | 24 editable low-fi экрана R1.2 на трёх boards | awaiting_review; реальные IDs и сценарии в screens. R1.3/R1.4 todo; URL/rename D007 остаётся открытым |
| D015 / 2026-10-05 | Прямое поручение: соседние кнопки на одном горизонтальном уровне, уменьшить их; поиск без заголовка с лупой; «после этого, переходи к следующей фазе разработки» | Правки R1.2 выполнены и проверены, условная приёмка выполнена: R1.2 done; разрешена следующая последовательная задача R1.3. Уточнены REQ-PROJECT-01/REQ-EDITOR-02; R1.4/R2/runtime/Git mutations не разрешены |
| D016 / 2026-10-05 | 24 editable low-fi экрана R1.3 и один ResumeDocument component | awaiting_review; реальные IDs и static walkthrough в screens. Фото показано wireframe-слотом, native media/prototype pending; R1.4 todo |
| D017 / 2026-10-05 | «переходи к следующему этапу» после результата R1.3 | Принята R1.3; разрешена следующая задача R1.4. R2 ждёт её приёмки; runtime/backend/Git mutations не разрешены |
| D018 / 2026-10-05 | 40 editable low-fi экранов R1.4 и один PortfolioDocument component | awaiting_review; пять boards и реальные H01–H40 IDs в screens; positive/error/unsaved/access paths статические, R2 todo |
| D019 / 2026-10-05 | Ответ пользователя на вопрос о публичных ссылках: «Постоянный адрес документа (рекомендую)» | Принята target-политика: адрес каждого Resume/Portfolio сохраняется при смене названия и никнейма; принадлежит документу. Unpublish закрывает доступ, republish использует тот же адрес; duplicate не наследует ссылку. H39/F20 обновлены; URL route/migration/backend не реализованы |
| D020 / 2026-10-05 | Подсветить важные кнопки/действия и некоторые детали цветом, «после этого переходи к следующему этапу» | Цветовые правки проверены; условная приёмка R1.4 выполнена, R1 done. Разрешена следующая задача R2.1; правила акцентов уточнены в REQ-PALETTE-02. Runtime/backend/Git mutations не разрешены |
| D021 / 2026-10-05 | Шесть editable пилотов R2.1: два направления на одинаковых Home/public Resume/Settings | awaiting_review; реальные IDs в screens. Сопоставимые no-photo fixtures, Noto Sans, предварительные знаки и dark contrast проверены. Выбор направления/логотипа не сделан; R2.2/R2.3 todo |
| D022 / 2026-10-05 | «переходи к следующему этапу» после сравнительного результата R2.1 | Принято сравнение R2.1; разрешена следующая задача R2.2 для обоих вариантов. Выбор A/B/логотипа/финальной типографики не сделан; R2.3/R3/runtime/Git mutations не разрешены |
| D023 / 2026-10-05 | Editable brand specimens R2.2: два mark/wordmark/app-icon направления, dark/light/mono и 16–48 px | awaiting_review; 110:268, реальные family/UI IDs в screens. Bounds/render/contrast/font license проверены; A чище16, B рекомендован24+, UI32. Явный выбор направления/логотипа предстоит в R2.3; native exports/runtime не выполнены |
| D024 / 2026-10-05 | «вариант бренда мне понавился А. приступай к следующей фазе» | Принят бренд A, R2.2/R2.3/R2 done; связанные A / Cyber Editorial pilots — основа R3 на поручение продолжить. Selected Mark110:282/Wordmark111:284/AppIcon111:297, IDs сохранены; B — история. Разрешена только следующая задача R3.1; шрифт/полная DS/R3.2–R3.4/runtime/Git mutations не приняты автоматически |
| D025 / 2026-10-05 | Editable Dark/Light foundations и typography/metrics R3.1 | awaiting_review; page121:7, boards123:7/125:19. Семь variables/один style, 25 прежних color values сохранены; 246 texts contrast и bounds/renders PASS. Noto Sans предложен, static16/32 reflow не доказывает OS scaling; R3.2–R3.4 todo |

Новый scope change записывается отдельной строкой с причиной, requirement IDs,
влиянием на задачи/gaps и явным решением пользователя. Исторические результаты
не переписываются. Текущая точка приёмки — R3.1; следующий отдельный шаг после
её review — R3.2: navigation, cards и TechnologyBadge. D024 закрыл выбор A
и разрешил R3.1; полная DS и итоговые gates ещё требуют приёмки.
