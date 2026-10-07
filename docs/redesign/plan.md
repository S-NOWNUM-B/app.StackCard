<div align="center">

# StackCard Design v2 — план

**Поэтапный редизайн с явными границами, проверками и приёмкой**

![Phase R7](https://raster.shields.io/badge/Phase-R7-C7FF1A?style=for-the-badge)
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

**Действующее поручение 2026-10-07, D045/D046:** последовательная очередь фаз на
паузе, разрешена functional mobile работа по Figma и концепции общей базы.
Навигация/библиотеки Resume/Portfolio/редакторы/private model совместимо
расширяют existing draft API, Hive6/cloud5 и UID boundaries; D046 добавляет
captured base review с отдельным Save. R7 remains
awaiting_review; DESIGN_READY/REDESIGN_DONE и native visual gates открыты.
Actual scope/проверки — в
[product status](../product/product-spec.md#статус-и-границы-текущей-работы),
контракт — в [architecture](../architecture/architecture.md#общая-база-и-независимые-документы).
Public documents/URL/web/full account пока отсутствуют. No-preview/run сохраняется;
последним поручением commit/push/deploy не выполняются.

Обновление roadmap 2026-10-08 (D047) связывает remaining mobile/settings,
publication/URL/public reader, web owner editor и Phase 14–20 с multiple outputs.
[Актуальная очередь](../product/product-spec.md#актуальная-последовательность-2026-10-08)
не требует full owner web editor до первого mobile→public документа.
R7/native/user acceptance остаётся открытой; обновлённый план не устанавливает
DESIGN_READY/REDESIGN_DONE и не запускает backend/web/deploy автоматически.

Правила/решения 2026-10-05 ниже описывают историю фаз. D045 переопределяет
очередность для разрешённого mobile scope; не превращает историческую QA или
новый source diff в full acceptance. Незавершённые PR-* requirements сохраняются
в [prerequisites](prerequisites.md).

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
R7 — `awaiting_review`, D041: source package/structural QA завершены;
явная пользовательская приёмка/DESIGN_READY pending. Пакет R6 принят D040 после D039. Последнее прямое
поручение завершить R7/R8/R9, увеличить число агентов и применить результат на
`redesign/full-app` разрешает перенос и регрессию; повторного phase approval нет.
Все четыре задачи R7 выполняются одним пакетом. В том же разрешённом parallel
режиме независимые R8 theme/controls/assets, Projects и поддерживаемые Settings
уже перенесены, R9 проверила существующий slice:950/950 tests PASS/analyze0issues.
Полная R8/R9 остаётся `in_progress`, зависимые capabilities ждут prerequisite
scope; Home/Portfolio не объявляются полностью перенесёнными. R7 graph QA PASS
D041; явная приёмка и DESIGN_READY/REDESIGN_DONE не установлены. No-preview/run сохранён.
Перенос `redesign/full-app` в `dev` и commit/push разрешены D042;
deployment не запрошен. [Конкретное proposed scope](prerequisites.md)
подготовлено для решения пользователя, а не автоматического запуска roadmap.
R3.4 принята D034; поручение D032 ранее
приняло R3.3 и разрешило R3.4.
По прямому запросу независимые компоненты, motion, QA и документация подготовлены
параллельно четырьмя агентами; ведущий последовательно интегрировал Figma. Поручение
«переходи к следующему этапу разраотки» после R3.2 принято как её приёмка
и разрешение только R3.3, D030.
Результаты R3.2:
[Navigation/cards/TechnologyBadge](screens.md#r32--навигация-карточки-и-technologybadge)
собраны и проверены в Dark/Light, R3.2 — done D030. Поручение «переходи к следующему этапу
разраотки» после review R3.1 принято как её приёмка и разрешение R3.2, D028.
Для продолжения закреплена рекомендация Manrope; отдельного сообщения с названием
семейства не было. Палитра и Wordmark A сохранены.
[Формы, stepper, фото и секции R3.3](screens.md#r33--формы-stepper-фото-и-секции)
приняты D032. [Состояния, motion и адаптивность R3.4](screens.md#r34--состояния-motion-и-адаптивность)
собраны и проверены в четырёх Dark/Light boards; runtime/backend и Git mutations
не входят в этот шаг.
Ответ пользователя о постоянном адресе документа закрыл выбор политики D007
(D019); реализация и точная схема URL остаются отдельной предпосылкой R8.
Основная разработка функций приостановлена перед Phase 11 Media; открытая
Google/reset/iOS приёмка Phase 7 сохранена. Подробности — [README](README.md)
и [audit](audit.md), основной roadmap остаётся в [product spec](../product/product-spec.md#план-разработки).

Базовое правило — одна активная фаза и согласованный scope. Для R4 принято
исключение D034: девять задач одним пакетом; D036 сохранило режим для R5, D038 —
для R6. D040 разрешило весь R7/R8/R9 и максимальный parallel режим. Независимые
поддерживаемые R8 slices и их R9 regression выполнены параллельно R7; зависимые
model/media/publication/web задачи не запускаются до решения prerequisite scope.
Это исключение не закрывает финальные gates и не возвращает roadmap Phase11.
Допустимые статусы: `todo`, `in_progress`, `blocked`, `awaiting_review`, `done`.
Новый артефакт переводит визуальную задачу в awaiting_review; done требует
приёмки пользователя. Следующий шаг начинается по явному поручению.
R0 завершена после пользовательского разрешения R1.1; R1.1 принята отдельным
поручением продолжить; R1.2 принята после правок D015, R1.3 — поручением D017.
R1.4 принята условным поручением D020 после проверки цветовых правок.
Приёмка сравнения R2.1 сама по себе не означала выбора направления/логотипа;
последующий прямой выбор A закрыл R2 (D024). Manrope закреплён D028; полная DS принята D034.

R1–R7 создают UX, editable макеты и прототип. Авторизация R8/R9 уже получена
D040; независимые поддерживаемые slices перенесены параллельно R7, dependent
flows требуют actual design contract и определённого integration scope.
DESIGN_READY не устанавливается до фактического итога R7; REDESIGN_DONE требует
actual R8/R9 результата и приёмки согласованного scope. Новое разрешение не
является выполнением prerequisite/backend work или финальной приёмкой. Mock,
prototype, implemented UI и backend capability отмечаются отдельно.

Requirement IDs принадлежат [requirements](requirements.md), S-* экраны и
current paths — [screens](screens.md), GAP-* — [audit](audit.md#продуктовые-пробелы).
Диапазон IDs означает каждое требование диапазона. Будущие Figma-имена в таблицах
явно предлагаемые; существующие frame IDs указаны только в проверенном реестре.
Доказательство в строках todo — требуемый будущий результат, а не уже выполненная проверка.
Каждая задача получает собственные IDs и evidence; R6 принята общим пакетом
D040, текущая R7 выполняется общим пакетом. R4.7 и R8.2–R8.5 используют буквенные
IDs; R8/R9 уже разрешены D040. Независимая parallel интеграция явно отражена
ниже; это не отменяет design gates и выбора prerequisite scope.

---

## Обзор фаз

| **Фаза** | **Результат / точка согласования** | **Статус** |
|:---|:---|:---|
| R0 — Аудит и план | Комплект docs/redesign и сохранённая точка roadmap. Принята прямым поручением начать R1; D009. | done |
| R1 — UX и информационная архитектура | IA и 88 low-fi экранов приняты; цветовые правки D020 выполнены. Постоянные адреса документов приняты D019; URL backend ещё не реализован. | done |
| R2 — Визуальное направление | Принят бренд A D024; связанные пилоты A / Cyber Editorial — основа R3. A families закреплены с прежними IDs; B сохранён как история. R2.1–R2.3 done. | done |
| R3 — Дизайн-система | R3.1–R3.4 приняты; полная DS done D034. Manrope, shared controls и state/motion/adapt evidence сохранены; runtime migration не выполнялась. | done |
| R4 — Основные экраны и настройки | Весь пакет R4.1–R4.7c принят D036: 61 state / 122 Dark/Light frames / 9 boards. Metadata/contrast evidence D035 сохранено; visual preview/run пропущены по D034. Unsupported функции остаются target-design. | done |
| R5 — Создание, редактирование и публикация | Все 13 задач R5.1a–R5.4c приняты одним пакетом D038; evidence D037: 83 состояния / 166 Dark/Light frames / 13 boards. Structural/contrast/bindings PASS; visual preview/run omitted D034/D036. Отдельные Save/sync/Publish и ownership сохранены. | done |
| R6 — Web | Все четыре задачи R6.1–R6.4 приняты D040; evidence D039: 24 состояния / 96 wide-narrow Dark-Light frames / 4 boards. Structural/contrast/CTA PASS; visual preview/run omitted. Только Figma target, Next.js/runtime не создан. | done |
| R7 — Прототип, адаптивность и приёмка дизайна | D041: source build/structural QA завершены,2736 expected bindings,723roots,328starts,6 motion pairs PASS. Package awaiting_review; visual/playback omitted, DESIGN_READY требует явной приёмки. | awaiting_review |
| R8 — Перенос согласованного UI | D040: partial runtime — semantic Lime/Manrope/shared controls/SVG/Brand A, Projects и поддерживаемые Settings. Home/Portfolio legacy composition, 3 roots; Resume/model/media/account/publication/web ждут prerequisite scope. | in_progress |
| R9 — Регрессия и завершение | Существующий Flutter slice:950/950 PASS, analyze0issues, 0SVGwarnings. Полная acceptance матрица, native/web и prerequisite scope не закрыты; REDESIGN_DONE не установлен. | in_progress |

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

**Статус фазы:** `done`, D034 (R3.1 done D028; R3.2 done D030; R3.3 done D032; R3.4 принята D034 после review D033).

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R3.1 | REQ-PALETTE-01..03, REQ-TYPE-01..02, REQ-FIGMA-01 | [Foundations123:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=123-7), [Typography125:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=125-19), Font Review138:19; page121:7 | После сравнения трёх семейств закреплён Manrope D028. 244 foundation texts обновлены; прежние variables/styles и Wordmark A сохранены. | C-PALETTE, C14, C-ASSET; C16 static | [Текущая типографика](screens.md#закреплённая-типографика-manrope-d028); повторные renders/contrast/bounds PASS. OS scaling/native shaping ещё pending. | done |
| R3.2 | REQ-NAV-01..05, REQ-HOME-01..02, REQ-TECH-01..02, REQ-PROJECT-03 | [Navigation148:340](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=148-340), [Cards148:894](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=148-894); DS page121:7 | Четыре root labels, gear/back, три Home filters; document/project cards, Copy states, badge icon+text/+N/full wrap. 9 sets/44 variants, 2 single components/14 SVG icons. | C01–C05, C08, C11, C12, C14, C15, C-ASSET | [Metadata, bindings и renders](screens.md#r32--навигация-карточки-и-technologybadge) PASS; 164 новых specimen texts ≥4.5, overflow0. Native routing/clipboard/assets и responsive states pending. | done D030 |
| R3.3 | REQ-EDITOR-01..03, REQ-RESUME-02..03, REQ-SETTINGS-02 | [Forms163:1334](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=163-1334), [Editing163:1576](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=163-1576), Keyboard163:2060 / Scale166:1988; DS121:7 | 10 sets/67 variants, PhotoSourceSheet,6 Lucide icons; поля/выбор/фото/пять шагов, Save над клавиатурой, drag+Выше/Ниже. | C06, C07, C12, C15, C16 static | [Компоненты и фактическое evidence](screens.md#r33--формы-stepper-фото-и-секции):513 texts ≥4.5,103 strokes ≥3, bounds/overlap/references/touch PASS. Native keyboard/media/scaling и полные flows pending. | done D032 |
| R3.4 | REQ-MOTION-01..02, REQ-ADAPT-01..03, REQ-EDITOR-03 | [States176:2036](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2036), Lifecycle176:2110, Motion176:2214, Adaptive176:2418; DS121:7 | StatePanel5/LifecycleStatus13, независимые Save/Sync/Publish и подтверждённый Unpublish; шесть180/240/280ms эффектов с0ms reduced,10fixtures320/390/430/768/844. | C10, C13, C14, C15, C16 static, C-MOTION | [Фактическое evidence](screens.md#r34--состояния-motion-и-адаптивность):393 text nodes/786 mode samples ≥4.5,342 strokes ≥3,96targets≥48, bindings/scopes/bounds/overlaps/refs PASS; prototype/native pending. | done D034 |

### R4 — Основные экраны и настройки

**Цель:** Собрать четыре библиотеки и полноценные настройки из DS.

**Зависимости:** Принятые R1–R3; backend gaps маркируются, не реализуются.

**Входит:** Root screens, Profile/photo, contacts/links, account/app/privacy settings.

**Не входит:** Wizard/editors/publication flows R5; заявления о backend готовности.

**Результат:** Набор hi-fi full/empty/errors и focused settings screens.

**Критерии приёмки:** Все запреты выполнены; Settings содержит editable profile/contacts/account сценарии, а не только theme/language.

**Проверка:** Metadata/contrast/bindings/viewport geometry в Dark/Light и requirement contracts. По прямому запросу D034 renders/preview/run не выполняются; визуальная проверка явно остаётся пропущенной.

**Решения пользователя:** Все девять задач R4.1–R4.7c выполняются одним пакетом D034. По завершении принять весь набор; неподдерживаемые функции остаются target-design.

**Статус фазы:** `done`, D036. Все девять задач приняты поручением продолжить; metadata evidence D035 сохранено, visual preview/run пропущены D034.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R4.1 | REQ-HOME-01..03, REQ-NAV-01..03 | [186:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-7); S-HOME; existing /home | Header+gear, ровно Все/Резюме/Проекты, recent mixed cards и отдельная Copy зона; убрать dashboard элементы. | C01–C04, C09 | 7 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |
| R4.2 | REQ-RESUME-01, REQ-SHARE-01 | [187:1340](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1340); S-RESUMES; нового runtime route ещё нет | Create + cards role/preview/date/status/open/copy; без completion percent. | C01, C02, C09, C10 | 7 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |
| R4.3 | REQ-PROJECT-01..04, REQ-TECH-01..02 | [187:2342](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2342); S-PROJECTS; existing /projects | Import/Create в компактном горизонтальном ряду → поиск с лупой без внешнего заголовка → List; cover/placeholder, badges, без filters/hero. | C05, C08, C13, C15 | 7 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |
| R4.4 | REQ-PORTFOLIO-01, REQ-SHARE-01 | [187:11625](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11625); S-PORTFOLIOS; existing /portfolio пока singleton | Список named Portfolio и доступ к create/edit/duplicate/publish/unpublish/share. | C09, C10, C13 | 7 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |
| R4.5 | REQ-SETTINGS-01,04, REQ-RESUME-03 | [187:12466](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12466); S-SETTINGS/S-PROFILE; existing profile editor | Focused profile и photo selector/replace/remove/no-photo, опыт/образование/навыки. | C06, C07, C12, C16 | 7 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |
| R4.6 | REQ-SETTINGS-02..03 | [187:13712](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13712); S-CONTACTS; existing /portfolio/builder/links | Отделить contact email от login, custom label+URL, CRUD/reorder и public selection. | C06, C17 | 7 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |
| R4.7a | REQ-SETTINGS-01,03,04 | [187:14648](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14648); S-ACCOUNT; existing /settings account actions | Отдельный экран аккаунта: login email/password/provider inventory, reauth/link error/last-provider protection; выход и delete отдельно. | C06, C10, C12, C13 | 9 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |
| R4.7b | REQ-SETTINGS-01,03, REQ-SHARE-01 | [187:15400](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15400); S-PRIVACY; существующего privacy route нет | Экран privacy: selected contacts/location/обращения, не смешивать login email с public contact. | C06, C12, C17 | 5 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |
| R4.7c | REQ-SETTINGS-01, REQ-MOTION-02 | [187:16002](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16002); S-APP; existing /settings preferences | Экран приложения: dark/light/system, ru/en, notifications/reduced motion; unsupported backend обозначен. | C06, C12, C13, C-MOTION | 5 states × Dark/Light; [реестр и QA](screens.md#r4--основные-экраны-и-настройки). Metadata/contrast PASS; visual preview/run skipped D034. | done D036 |

### R5 — Создание, редактирование и публикация

**Цель:** Завершить сценарии документов, проектов и общего sharing.

**Зависимости:** Принятые R3–R4, IA и правила модели. Каждая задача получает отдельное evidence, все13 задач проходят общее review пакета D036.

**Входит:** Resume wizard/edit, manual/GitHub Projects, Portfolio builder, shared publish/share/delete.

**Не входит:** Backend migration/media/OAuth implementation и свободный canvas.

**Результат:** Полные hi-fi flows с input/error/back/preview и отдельным Publish.

**Критерии приёмки:** Нет потери ввода, смешения Save/sync/publish, тихого overwrite, duplicate import или удаления общей работы через attachment.

**Проверка:** Metadata/contrast/bindings и сравнение обычного/пустого/ошибочного flow с source contract. Визуальный просмотр, preview и запуск приложения пропущены в сохранённом режиме D034/D036; static evidence не доказывает playable flow.

**Решения пользователя:** Поручение перейти к следующему этапу интерпретировано как переход к всей следующей R5 в ранее согласованном режиме, D036. Принять общий пакет; последствия delete/rename проверяются отдельно в его evidence.

**Статус фазы:** `done`, D038. Все 13 задач приняты поручением продолжить; фактические IDs и QA D037 сохранены, visual preview/run пропущены по запросу.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R5.1a | REQ-RESUME-02..04, REQ-SETTINGS-02 | [194:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-7); S-RESUME-WIZARD; предлагаемое Mobile / Resume / Steps 1-2 | Profile/title/role/photo/bio и selected contacts; использовать базу, локальные overrides, no-photo и Skip. | C06, C07, C12, C16 | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.1b | REQ-RESUME-02,04, REQ-TECH-01..02 | [194:1160](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-1160); S-RESUME-WIZARD; предлагаемые Steps 3-4 | Выбор опыта/образования/tech/projects, optional skip; не выдумывать факты и skill levels. | C08, C12, C16, C-MODEL | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.1c | REQ-RESUME-04, REQ-EDITOR-01..03, REQ-MODEL-07 | [194:2270](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-2270); S-RESUME-EDITOR; existing plain /portfolio/builder/resume — только legacy | Список секций и focused edit без повторного wizard, local overrides и review изменений профиля. | C10, C12, C-MODEL | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.1d | REQ-RESUME-02..03, REQ-SHARE-01 | [194:3295](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-3295); S-PREVIEW/S-PUBLISH; предлагаемый Resume Step 5 | Структурированный preview с выбранным фото и отдельный переход к Publish. | C07, C09, C10, C17 | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.2a | REQ-PROJECT-03..04, REQ-TECH-01..02 | [194:4782](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-4782); S-PROJECT-EDITOR; /projects/new, /projects/:id/edit | Ручной global Project: форма/media placeholder/badges, validation/Save/Cancel. | C08, C12, C13 | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.2b | REQ-PROJECT-04, REQ-MODEL-02 | [194:5710](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-5710); S-GITHUB; /github-import | Выбор repos, already imported, pagination/cache/rate/error, без повторного Project. | C-GITHUB, C13 | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.2c | REQ-PROJECT-04, REQ-MODEL-06 | [194:6468](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-6468); S-GITHUB-REVIEW; existing GitHub review sheet | Показать diff source/curated, Accept/Ignore/Cancel, stale review и отдельный Save. | C-GITHUB, C10, C13 | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.3a | REQ-PORTFOLIO-01..02, REQ-EDITOR-01 | [194:7176](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-7176); S-PORTFOLIO-EDITOR; /portfolio/builder пока singleton | Создать named Portfolio из предложения Profile, content/appearance/preview отдельно. | C-MODEL, C10, C12 | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.3b | REQ-PORTFOLIO-03, REQ-MODEL-02, REQ-MODEL-05 | [194:8156](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-8156); S-PORTFOLIO-EDITOR; предлагаемый Project selector | Add existing или create global+attach; order/visibility/featured association, remove relation. | C-MODEL, C12 | 7 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.3c | REQ-EDITOR-01..03, REQ-PORTFOLIO-02 | [195:6196](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=195-6196); S-PORTFOLIO-EDITOR/S-PREVIEW; existing /portfolio/preview | Focused sections, show/hide/order, layout/accent/photo visibility, no three narrow mobile panels. | C07, C08, C10, C12 | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.4a | REQ-EDITOR-03, REQ-MODEL-08 | [195:7277](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=195-7277); S-PUBLISH; prepared publication adapter, UI отсутствует | Draft/locally saved/pending/synced/published различимы; Publish explicit, dirty published draft не меняет public. | C10, C17 | 8 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.4b | REQ-SHARE-01 | [195:7949](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=195-7949); S-SHARE + cards/detail | Постоянные Copy/Open/Share у опубликованного; подтверждение Copy; draft предлагает Publish. | C09, C15 | 6 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |
| R5.4c | REQ-SHARE-01, REQ-SETTINGS-04, REQ-PORTFOLIO-01 | [195:8628](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=195-8628); S-PUBLISH/S-SHARE/S-ACCOUNT | Unpublish/delete/duplicate/rename confirmations; постоянный адрес документа по D019, сохранность draft и связей; фактическую поддержку URL проверить перед R8. | C-MODEL, C09, C10, C17 | 8 состояний × Dark/Light; [реестр и QA](screens.md#r5--создание-редактирование-и-публикация). Structural/contrast PASS; visual preview/run omitted D034/D036. | done D038 |

### R6 — Web

**Цель:** Спроектировать три web-поверхности как части того же продукта.

**Зависимости:** Принятые модель/DS/flows R1–R5; actual web runtime пока отсутствует.

**Входит:** Landing, auth/download, рабочий кабинет/editor, public Resume/Portfolio.

**Не входит:** Next.js scaffold/code, hosting/deploy, фиктивные store links/отзывы/цифры.

**Результат:** Полный web design visitor/owner flow, не один hero.

**Критерии приёмки:** Различимы marketing/private/public, narrow/wide editing; публичный просмотр без входа и приватных полей.

**Проверка:** Desktop/narrow metadata и responsive geometry, contrast/bindings, keyboard/focus contract, CTA destinations, anonymous/owner states. Visual inspection/preview/run пропущены по сохранённому запросу D038; static evidence не доказывает браузерный walkthrough.

**Решения пользователя:** D038 интерпретирует поручение продолжить как переход к следующей полной R6 с сохранением прежнего режима фаза целиком/параллельно/без preview/run. Принять общий пакет после фактических checks; URL policy D019 не означает реализованную route scheme.

**Статус фазы:** `done`, D040. Все четыре задачи приняты продолжением; actual IDs и structural/contrast/CTA evidence D039 сохранены, visual preview/run пропущены по запросу.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R6.1 | REQ-WEB-01..02, REQ-VISUAL-01..03 | [204:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=204-7); S-WEB-LANDING; apps/web/README.md; предлагаемый Web / Landing | Объяснить общая база→разные Resume/Portfolio; настоящее product preview и все секции задания. | C-WEB, C-ASSET | 1 base × wide/narrow × Dark/Light; [реестр и QA](screens.md#r6--веб-поверхности). Structural/contrast/CTA PASS; visual preview/run omitted. | done D040 |
| R6.2 | REQ-WEB-02, REQ-PRESERVE-04 | [205:625](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=205-625); S-WEB-AUTH/S-WEB-DOWNLOAD; runtime отсутствует | Auth/register/reset/return route и download с честным unavailable-state. | C-WEB, C12, C13 | 8 base × wide/narrow × Dark/Light; [реестр и QA](screens.md#r6--веб-поверхности). Structural/contrast/CTA PASS; visual preview/run omitted. | done D040 |
| R6.3 | REQ-WEB-03, REQ-EDITOR-01..03 | [206:1593](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=206-1593); S-WEB-WORKSPACE; предлагаемый Web / Workspace | Wide параметры+preview, narrow modes, shared base/library/documents, explicit publishing. | C-WEB, C10, C13, C16 | 8 base × wide/narrow × Dark/Light; [реестр и QA](screens.md#r6--веб-поверхности). Structural/contrast/CTA PASS; visual preview/run omitted. | done D040 |
| R6.4 | REQ-WEB-04, REQ-PORTFOLIO-02, REQ-SHARE-01 | [206:28486](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=206-28486); S-PUBLIC-RESUME/S-PUBLIC-PORTFOLIO; предлагаемые Web / Public | Документный Resume и showcase Portfolio, выбранные фото/контакты, not-found/unpublished. | C07, C08, C17, C-WEB | 7 base × wide/narrow × Dark/Light; [реестр и QA](screens.md#r6--веб-поверхности). Structural/contrast/CTA PASS; visual preview/run omitted. | done D040 |

### R7 — Прототип, адаптивность и приёмка дизайна

**Цель:** Проверить целостные сценарии и зафиксировать DESIGN_READY.

**Зависимости:** Принятые R1–R6, реальные frames и complete state matrix.

**Входит:** Linked prototype, phone/tablet/landscape/text/keyboard/motion/a11y evidence.

**Не входит:** Реализация runtime/backend и автоматическая установка DESIGN_READY.

**Результат:** Пакет финальных frames/prototype, результатов и известных ограничений.

**Критерии приёмки:** Все C01–C17 и дополнительные проверки имеют evidence; пользователь принял дизайн.

**Проверка:** Actual prototype graph/targets, metadata/contrast, adaptive/text/keyboard/motion coverage. Visual preview/playback/app launch пропущены по сохранённому прямому запросу; simulated keyboard/static reflow не равны native acceptance.

**Решения пользователя:** D040 разрешило завершить всю R7 и далее R8/R9. DESIGN_READY фиксируется только по actual итоговому пакету, без повторного запроса авторизации R8; пропущенные checks и limitations остаются явными.

**Статус фазы:** `awaiting_review`, D041. Source build/структурная QA R7.1–R7.3 завершены; R7.4 и явная пользовательская приёмка/DESIGN_READY pending.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R7.1 | REQ-WORKFLOW-04, REQ-FIGMA-02 | Все S-*; реальные frame IDs появятся в screens.md | Связать root/settings/create/edit/preview/publish/share и error/back paths. | C01–C13, C17 | Source graph2736bindings/723roots/328starts;22contract chunks+topology PASS. Mobile879semantic contracts/1758themed edges;web946contracts/978bindings. Playback omitted. | awaiting_review |
| R7.2 | REQ-ADAPT-01..03, REQ-NAV-01,05 | Mobile frames 320/390/large phone/tablet/landscape (контрольный набор предлагаемый) | SafeArea, centered max width, без rail, keyboard-safe/long content, scale1/2. | C11, C12, C15, C16 | 12 новых adaptive fixtures+10существующих+2 keyboard sources;1876nodes/490texts/170targets/314strokes,180 static ×2texts;16failure categories0. Native keyboard/OS scaling omitted. | awaiting_review |
| R7.3 | REQ-CHECK-01..02, REQ-MOTION-01..02 | DS + все critical states | Контраст/targets/focus/semantics specs; reduced-motion 180–280/static, empty/error/offline. | C13–C17, C-MOTION, C-ASSET | Text contrast min4.832909811:1/strokes min4.364564811:1;6motion pairs180/240/280ms+reduced0ms,same targets,noTIMERS/noSET_VARIABLE. Native semantics/playback omitted. | awaiting_review |
| R7.4 | REQ-WORKFLOW-04..05, REQ-WORKFLOW-07, REQ-FIGMA-02 | screens.md финальный реестр, этот журнал | Свести requirements→frames→checks→results; явная приёмка пользователя. | C-SCOPE, C01–C17 | Portable r7-handoff.json +screens/results +D041 source package ready;explicit user acceptance pending. DESIGN_READY не установлен. | awaiting_review |

**Фактическое начало R7, D040:** создана page [R7, 221:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-7) и
adaptive board [221:8](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-8). Первые восемь fixtures:
[221:11](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-11), [221:274](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-274), [221:412](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-412), [221:601](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-601), [221:760](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-760), [221:890](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-890), [221:987](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-987), [221:1150](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-1150). Это partial construction;
на момент D040 final coverage/graph QA ещё не были готовы. Итоговый
[source handoff D041](source/r7-handoff.json) фиксирует структурно проверенный пакет;
runtime keyboard иDESIGN_READY одним этим списком не подтверждаются.

**Исходный regression baseline до R8:** на `redesign/full-app`, HEAD
`f55f017ec263048b3c84a193327a2d5e42348cdf`, Flutter3.47.4/Dart3.13.3:
`flutter analyze --no-pub` — PASS, `flutter test --no-pub --reporter expanded`
— **832 passed**. Команды выполнены в zsh из `apps/mobile` до переноса Design v2.
Это headless проверки прежнего runtime; app/device/visual запуск не выполнялся.
Baseline не является результатом новых R8 изменений или завершением R9.


### R8 — Перенос согласованного UI

**Цель:** Внедрить принятый дизайн постепенно, сохранив реальное поведение.

**Зависимости:** Авторизация переноса получена D040; D045 разрешает functional
private mobile scope вне последовательной очереди. R7/final native acceptance
открыты; public/URL/web/full account prerequisites ещё не реализованы.

**Входит:** Tokens/components, shell/roots/settings/editors и поддерживаемые web surfaces по одному срезу.

**Не входит:** Тихая domain/backend/Rules migration, OAuth/media/публикация новых функций, смена стека, fake success.

**Результат:** Реальные экраны в согласованном scope; неподдерживаемые действия обозначены честно.

**Критерии приёмки:** Старые данные/UID/cache/outbox/notes/review сохранены, новое UI проверено; нет mock-success вместо backend.

**Проверка:** По изменённому scope: format/analyze/focused tests, визуальный native run; web scripts по реальным manifests.

**Решения пользователя:** R8 разрешена D040, private mobile capabilities D045;
повторного phase approval для них нет. D042 относится к исторической Git delivery;
новые changes не сопровождаются commit/push/deploy автоматически.

**Статус фазы:** `in_progress`: D040 shared slice сохранён, D045 расширяет mobile
functional scope. Full public/web/account/native parity и final acceptance открыты.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R8.1 | REQ-SCOPE-01..04, REQ-PRESERVE-01..04 | audit.md gaps; actual domain/Hive/Firestore/Rules; apps/web/README.md | Сопоставить actions с actual contracts; D045/D046 private compatibility выполнять вместе с dependency slice, remaining public/web gaps сохранять. | C-SCOPE, C-MODEL, C-WEB | D045/D046 разрешают private mobile scope; PortfolioContent.documents/relations/base review, Hive6/cloud5 и compatible backups реализованы в source. Remaining public/account/web proposal не выполнен. | in_progress |
| R8.2a | REQ-PALETTE-01..03, REQ-TYPE-01..02 | apps/mobile/lib/core/theme/stackcard_colors.dart, stackcard_theme.dart, stackcard_tokens.dart | Перенести semantic colors/type/spacing, сохранив единый theme mechanism и Material 3. | C14, C16, C-PALETTE | Semantic Dark/Light colors, Manrope400/600/700/800+Noto fallback и tokens в существующем core/theme; focused/full headless950 PASS, native preview omitted. | awaiting_review |
| R8.2b | REQ-NAV-01..05, REQ-EDITOR-02..03 | apps/mobile/lib/shared/widgets; actual component files по approved DS | По одному shared control: button/input/back/gear/navigation/state; сохранить loading/semantics/retry. | C12, C13, C15, C16 | Existing shared button/input/state controls обновлены; focus/loading/disabled/retry/48px/scale2 headless checks PASS. Визуальный/native acceptance omitted. | awaiting_review |
| R8.2c | REQ-TECH-01..02, REQ-PROJECT-03 | apps/mobile/lib/shared/widgets/stackcard_icon.dart, stackcard_technology_badge.dart, stackcard_brand.dart | Ввести badge icon+text/+N/wrap и entity-card presentation; проверять по одному компоненту. | C08, C14, C15, C-ASSET | StackCardIcon + StackCardTechnologyBadge/MoreTechnologies;40canonical entries+1explicit render derivative;32runtime SVG decoded, provenance strict check PASS. Native parity pending. | awaiting_review |
| R8.3a | REQ-NAV-01..05 | apps/mobile/lib/app/app_router.dart, apps/mobile/lib/app/app_shell.dart | Shell/routes: четыре permanent labels, gear/settings nested, origin Back, guards/deep links, tablet bottom nav. | C01, C02, C11, C12, C16 | D045: StatefulShellRoute.indexedStack с Home/Resumes/Projects/Portfolios, constant labels и gear/settings origin Back. Новая native parity/приёмка открыта. | in_progress |
| R8.3b | REQ-HOME-01..03 | apps/mobile/lib/features/home/home_screen.dart; S-HOME | Перенести только Home: три фильтра/recent mixed list и separate Copy, после готовности library модели. | C03, C04, C09, C13 | D045: mixed document/project list, Все/Резюме/Проекты, Portfolio в Все, сортировка updatedAt. Public Copy ожидает URL/publication contract; native review открыт. | in_progress |
| R8.3c | REQ-RESUME-01, REQ-SHARE-01 | apps/mobile/lib/features/portfolio_draft/presentation/portfolio_document_library_screen.dart; portfolio_document_editor_screen.dart; /resumes | Перенести Resume list/create entry/status/link presentation только при настоящем Resume contract. | C09, C10, C13 | D045: реальная private Resume library/create/edit/duplicate/delete, draft state без fictitious URL. Publish/Copy/Open/Share и native visual parity ещё pending. | in_progress |
| R8.3d | REQ-PROJECT-01..04 | apps/mobile/lib/features/projects/presentation/projects_screen.dart; S-PROJECTS | Перенести Projects Import/Create/Search/List, без categories/hero, сохранить repository/search states. | C05, C08, C13, C15 | Projects query-only Import/Create/Search/List и badges внедрены; legacy filter provider сохранён отдельно, empty/no-results/error/retry/navigation headless PASS. Native preview omitted. | awaiting_review |
| R8.3e | REQ-PORTFOLIO-01, REQ-SHARE-01 | apps/mobile/lib/features/portfolio_draft/presentation/portfolio_document_library_screen.dart; /portfolio | Перенести Portfolio list после multiple-output contract; настоящие actions, без mock success. | C09, C10, C13 | D045: private Portfolio library и independent snapshots/Library relations, create/edit/duplicate/delete. Permanent published links/backend и native review pending. | in_progress |
| R8.3f | REQ-SETTINGS-01..04, REQ-NAV-05 | apps/mobile/lib/features/settings/settings_screen.dart; S-SETTINGS и children | Переносить по одному согласованному settings экрану R4.5/4.6/4.7a/b/c; поддерживаемые Save/auth actions, origin Back. | C02, C06, C12, C13, C17 | D045: settings base profile/skills/experience/education/links и scoped Save; existing appearance/account actions сохранены. Full public contacts/privacy/provider management/delete/notifications pending. | in_progress |
| R8.4a | REQ-EDITOR-01..03 | apps/mobile/lib/features/portfolio_draft/presentation/builder_editor_widgets.dart; existing section editors | Перенести focused section scaffold/Apply/Cancel/visible Save, сохранив validation/input/retry. | C10, C12, C13, C16 | D045: новый document editor с focused sections/Save/Cancel/unsaved и input/conflict retention. Existing shared controls сохранены; final native review pending. | in_progress |
| R8.4b | REQ-PROJECT-03..04 | apps/mobile/lib/features/portfolio_draft/presentation/portfolio_project_editor_screen.dart | Перенести manual Project create/edit после library gate, stable IDs и validation без потери ввода. | C08, C10, C12, C13 | D045: Project — единая Library запись, scoped Save/delete и relation cleanup. Document buffer + saveDocument(newProjects) создаёт Library Project и relation одной revision. Local project overrides/full native review pending. | in_progress |
| R8.4c | REQ-PROJECT-04, REQ-MODEL-06 | apps/mobile/lib/features/github_import/presentation/github_import_screen.dart, github_source_cards.dart | Перенести import/review controls; dedup, Add/Accept/Ignore, stale/UID/cached behavior сохраняются. | C-GITHUB, C10, C13 | Действующий GitHub import/review использует обновлённые shared controls; Add/Accept/Ignore/cache/UID регрессии сохранены, native target walkthrough omitted. | in_progress |
| R8.4d | REQ-RESUME-02..04, REQ-MODEL-07 | apps/mobile/lib/features/portfolio_draft/presentation/portfolio_document_library_screen.dart; portfolio_document_editor_screen.dart; /resumes | Перенести wizard и прямую правку по одному согласованному этапу R5.1; без fake structured storage. | C07, C08, C10, C12, C16 | D045: настоящий Resume snapshot, пять шагов creation и focused sections для существующего CV; фото/секции/Library/preview используют actual state. D046: captured base review сохраняет local overrides, Apply/Save раздельны. Public publication/native acceptance pending. | in_progress |
| R8.4e | REQ-PORTFOLIO-02..03, REQ-EDITOR-01..03 | apps/mobile/lib/features/portfolio_draft/presentation/portfolio_document_editor_screen.dart; portfolio_document.dart | Перенести Portfolio sections/appearance/preview по одному flow; attach/remove только после готовой relation модели. | C-MODEL, C07, C08, C10, C12, C17 | D045: private Portfolio editor/sections/theme/Library attach/detach/order/visible/featured и private Resume ID; legacy Builder сохраняется. Public publish/native acceptance pending. | in_progress |
| R8.5a | REQ-WEB-01..02 | apps/web; source paths после отдельно разрешённого Next.js runtime | Перенести landing/auth/download по одному accepted page, реальные CTA без отсутствующих store links. | C-WEB, C12, C13 | apps/web README-only; actual Next.js prerequisite scope proposed, runtime/build/routes отсутствуют. | blocked |
| R8.5b | REQ-WEB-03, REQ-EDITOR-01..03 | apps/web; S-WEB-WORKSPACE, actual paths после prerequisites | Перенести supported workspace/section editor/preview, actual owner guards и explicit publication только при готовом contract. | C-WEB, C10, C13, C16 | Owner web runtime и новый shared workspace contract отсутствуют; prerequisite scope pending. | blocked |
| R8.5c | REQ-WEB-04, REQ-SHARE-01 | apps/web; S-PUBLIC-RESUME/S-PUBLIC-PORTFOLIO, actual paths после prerequisites | Перенести публичные renderer по одному документу, anonymous unavailable и payload privacy. | C-WEB, C07, C08, C09, C17 | Public document web renderer/trusted projection/permanent IDs не внедрены; prerequisite scope pending. | blocked |

### R9 — Регрессия и завершение

**Цель:** Подтвердить принятый scope и возвращение к основной разработке.

**Зависимости:** Реализованные R8 slices, решённые blockers либо явно принятые scope changes.

**Входит:** Поведение/данные/integrations, visual parity, ограничения, пользовательская приёмка.

**Не входит:** Деплой, автоматический старт Phase 11, закрытие непроверенной Phase 7, заявление о полном продукте.

**Результат:** Принятый redesign с REDESIGN_DONE и сохранённой точкой roadmap.

**Критерии приёмки:** C01–C17 проверены в реализации, необходимые tests/native/web выполнены; незавершённое перечислено и принято.

**Проверка:** Existing/focused regression tests, migration checks если отдельно менялись, native Android/iOS по доступности, визуальное сопоставление frames.

**Решения пользователя:** Принять R9 и поставить REDESIGN_DONE; затем отдельно решить следующую продуктовую задачу.

**Статус фазы:** `in_progress`, D040: actual950-case suite и analyze проверили перенесённый существующий Flutter slice; полная R9/REDESIGN_DONE ещё не закрыта.

| **ID** | **Requirements** | **Файл / route / frame** | **Изменение и готовность** | **Проверка** | **Evidence** | **Статус** |
|:---|:---|:---|:---|:---|:---|:---|
| R9.1 | REQ-PRESERVE-01..04, REQ-MODEL-05..08 | Existing tests в audit + CONTRIBUTING; root/nested routes | Проверить UID/auth/guest/offline/restart/review/notes/local-save/sync и данные без reset/cleanup. | C-GITHUB, C-MODEL, C10, C13 | Actual existing Flutter:950/950 PASS29s, analyze0issues3.8s;UID/Save/sync/GitHub/domain regressions preserved. New models/migration/native contracts not verified. | in_progress |
| R9.2 | REQ-CHECK-01..02, REQ-NAV-01..05, REQ-WEB-04 | Финальные accepted Figma frames и actual UI | Сравнить layout/actions/photo/badges/links/tablet/a11y; public payload/private isolation отдельно. | C01–C17, C-WEB, C-MOTION | Supported widget scale1/2,ru/en,7viewports/buttons/SVG checks PASS; native visual/browser/private-public acceptance и полнота target scope pending. | in_progress |
| R9.3 | REQ-WORKFLOW-07..08 | Этот журнал, README.md, product-spec.md | Записать limitations/accepted scope, приёмку REDESIGN_DONE и предложение вернуться перед Phase 11. | C-SCOPE | Ограничения и proposed prerequisites записаны; user scope/final acceptance ещё pending, REDESIGN_DONE не установлен. | in_progress |

---

## Зависимости реализации

R1–R7 проектируют target; функциональность требует actual data/source contracts.
D045 разрешает private mobile capabilities: base/Library/documents/relations,
nav/editor и совместимые private adapters. Этот scope больше прежнего UI-only
переноса D040; он не ждёт повторного phase approval. Existing aggregate/UID/queue/
outbox/LWW сохраняются. Детали — в architecture и actual subset
[prerequisites](prerequisites.md).

Public multioutput snapshots/permanent URLs/trusted projection, full account,
contact/privacy, actual web/native sharing остаются prerequisites. Captured
base review реализован D046 в private mobile. Наличие private schema5 не реализует
оставшиеся public/account/web capabilities. Таблица ниже сохраняет зависимости;
фазовая привязка описывает историю/план, действующий mobile scope — D045.

| **Зависимость из audit** | **Основной roadmap / решение перед R8** |
|:---|:---|
| GAP-DATA-01..03 | Общая база/library/multiple documents/association/profile-review: предлагаемые дополнения к domain/persistence/sync tasks Phase 6/8 и web 13b, без отмены прежней приёмки |
| GAP-MEDIA-01 | Phase 11 Media: camera/gallery/upload/media lifecycle/Storage; дизайн состояний возможен раньше |
| GAP-PUB-01, GAP-PUB-02 | Phase 8 publication contract + Phase 13c public UI: multiple snapshots/URL и отдельное public validation hardening; не считать client codec доказательством server security |
| GAP-URL-01 | Политика принята D019: постоянный адрес документа, независимый от username/названия; unpublish закрывает доступ, повторный Publish использует тот же адрес. Спроектировать route scheme и миграцию: нынешний adapter удаляет старый username snapshot/claim; target-контракт ещё не реализован |
| GAP-AUTH-01, GAP-ACCOUNT-01 | Открытая Phase 7 и отдельно спланированные account management/linking/reauth/delete; Google sign-in не означает provider linking |
| GAP-CONTACT-01 | Public contact/privacy contract отдельно; Inbox/Contact/FCM — Phase 14, location integrations — Phase 12 |
| GAP-WEB-01 | Phase 13: минимальный runtime + публикация/public reader до полного owner editor; зависимости по актуальному roadmap: новый Next.js runtime/owner/public scenarios; R6 — только дизайн |
| GAP-PREF-01 / native share | Phase 15 sharing и отдельно согласованные notification/reduced-motion settings; существующий app stack сохраняется |

Никакие перечисленные prerequisites не отмечены выполненными в R0. Если они
не готовы, зависимая R8-задача получает blocked, независимый поддерживаемый UI
переносится в согласованном scope. Уменьшение scope фиксируется в журнале и
утверждается пользователем. R9 не объявляет весь запрошенный редизайн завершённым
при нерешённых blockers; completion возможен после их закрытия либо явной
приёмки пересмотренного scope с конкретными исключениями.

---

## Проверки и результаты

Прослеживаемость: requirement → task в таблицах выше и requirements → S-* в
screens → C-* ниже → actual evidence. Таблица сохраняет результаты R0/D040;
новый D045 functional source и проверки ведутся отдельно в product status.
Исторический PASS не является новым document-model PASS. Поиск текста в source
не подтверждает выполнение визуального требования.

| **Check** | **Способ проверки и ожидаемый результат** | **Задача / экран** | **Результат R0** |
|:---|:---|:---|:---|
| C01 | Render + walkthrough: на roots нет greeting/logout/STACKCARD DEMO | R4.1..4, R8.3; roots | Target не выполнен; source/Figma conflicts в audit |
| C02 | Нажать gear на каждом root, открыть нужные settings/back | R1.2, R4.5, R4.6, R4.7a..c, R8.3; S-SETTINGS | D045: gear/standalone Settings доступны с четырёх stateful roots; новая native/visual review остаётся открытой |
| C03 | Нажать ровно Все/Резюме/Проекты; Все включает Portfolio | R4.1, R7.1, R8.3; S-HOME | D045 source: три Home filters реализованы, Portfolio включён в Все; итоговые проверки в product status |
| C04 | Визуально проверить Home без readiness/progress/old quick actions | R4.1, R9.2; S-HOME | D045 source: Home заменён mixed library без readiness dashboard; native visual review не выполнен |
| C05 | Проверить порядок actions/search/list без categories/hero | R4.3, R9.2; S-PROJECTS | Projects query-only Import/Create/Search/List внедрён; UI не применяет legacy categories, search/empty/retry tests PASS; native preview omitted |
| C06 | Изменить имя/ник/фото/contacts/links, validation+save+reopen | R4.5, R4.6, R4.7a..c, R8.3; Settings groups | Полный сценарий отсутствует |
| C07 | Выбрать/убрать фото; проверить Resume editor и preview | R5.1a,d, R9.2; Resume | Avatar URL есть; нужного photo flow/renderer нет |
| C08 | Inspect semantics + render icon/text/+N/wrap TechnologyBadge | R3.2, R4.3, R9.2; cards/detail | StackCardTechnologyBadge +StackCardMoreTechnologies внедрены; живой text/wrap,32runtimeSVGdecoded,+N/unknownlabel headless PASS |
| C09 | Published card/detail: Copy/Open/Share после повторного открытия; draft без URL | R5.4b,c, R9.2; S-SHARE/cards | Document link UI отсутствует |
| C10 | Change→local Save→sync ACK→explicit Publish; previous public snapshot unchanged | R5.4a, R8.4, R9.1; editors/publish | Save/sync contracts есть; user publication flow нет |
| C11 | Tablet portrait/landscape: та же bottom nav, нет sidebar/rail | R7.2, R8.3, R9.2; roots | D045: четыре stateful roots сохраняют bottom nav без rail; historical D040 responsive PASS не аттестует новую native parity |
| C12 | Back/close, system navigation, cancel/unsaved handling и возврат origin | R1, R5, R7.1, R9.1; nested | Existing nested Back есть; новая IA не проверена |
| C13 | Empty/loading/error/retry/offline/long content; ввод и previous success не теряются | R3.4, R7.3, R9.1; все | R3.4 StatePanel5 + LifecycleStatus13 static PASS; полный flow/runtime pending |
| C14 | sRGB contrast всех actual text/surface/disabled/focus pairs; normal text >=4.5:1 | R3.1, R7.3, R9.2; DS/UI | Shared controls/theme actual Dark/Light contrast widget checks PASS; полный target/newbackend/public/native UI не аттестован |
| C15 | Metadata/hit tests реальных tap regions >=48×48 logical px, включая Copy/back/gear | R3, R7.2, R9.2; controls | Shared button/gear/+N/control external targets≥48 проверены headless; полный target и native hit regions pending |
| C16 | Text scale1/2 и OS увеличенный текст, ru/en, узкие экраны/keyboard | R7.2, группы R8.3–R8.5, R9.2 | Supported5routes×7viewports×Dark/Light×scale1/2 иru/en headless PASS; OS/native keyboard/font acceptance omitted |
| C17 | Anonymous payload/renderer без private notes/contacts/account/editor; absent/unpublished | R6.4, R9.2; public | Client projection есть, web отсутствует; server hardening gap |
| C-MODEL | Один Project в разных outputs; create+attach/remove relation; profile diff/local override | R1.1, R5.1c, R5.3b, R8.1 | Singleton source, migration pending |
| C-GITHUB | Selection/Add/reimport/Accept/Ignore/stale/UID/offline; curated fields сохраняются | R5.2b,c, R9.1 | Existing import/review/domain/UID/cache regressions входят в950PASS; новый native target walkthrough не выполнялся |
| C-ASSET | License/provenance fonts/icons/photos; настоящий текст badges, editable Figma | R2.2, R3.2, R7.3 | 40canonical records+1explicit Flutter derivative,9originalBrandASVG,4ManropeTTF imported; strict provenance PASS. Native font/AppIcon acceptance pending |
| C-PALETTE | Exact dark HEX/semantic roles, lime primary, error red; light actual pairs | R2.1, R3.1, R8.2 | Semantic Lime/ink Dark-Light и Manrope перенесены в единый core/theme; focused controls contrast PASS, full target/native parity pending |
| C-WEB | Полный visitor/owner/public path, реальные CTA и download availability | R6.1..4, R8.5 | Web source отсутствует; legacy concepts не runtime |
| C-MOTION | 180–280 ms, ввод доступен, reduced/static variants и Copy feedback | R3.4, R7.3, R9.2 | R3.4 static spec и R7 шесть standard/reduced graph pairs с одинаковыми targets PASS; prototype playback/native motion pending |
| C-SCOPE | Изменения только разрешённой фазы; сохранены user edits/assets/history/stack | R0.5, R8.1, R9.3 | R7/R8/R9 авторизованы D040; supported UI partial перенесён/950tests PASS; prerequisites proposed, backend/model/web не выполнены; Git delivery в dev разрешена D042 |

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

### Повторная проверка R3.1: foundations и Font Review

- Пользователь уточнил продолжение: остаться на R3.1 и пересмотреть foundations
  и шрифт, D026. R3.1 не принята, R3.2–R3.4 остаются todo.
- Оба исходных renders повторно просмотрены; контраст всех246 texts пересчитан:
  failures0, minimum4.585348853507275. Цветовые роли и принятый бренд A сохранены.
- Создан один editable [Font Review138:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=138-19),
  1400×2074: Noto Sans, Manrope и Golos Text на шести390×588 Dark/Light
  specimens, русский/английский, glyphs, metadata12/13 и static16/32 reflow.
  [Размеры, IDs и ограничения](screens.md#пересмотр-foundations-и-шрифта-d026d027).
- 48 matched samples совпадают по content/size/weight/line/width. Наложение
  из-за фиксированной высоты новых texts исправлено на HEIGHT/HUG; итоговый
  render просмотрен. Bounds/font/fixture failures0; все82 painted texts≥4.5,
  minimum4.8329098110002136. Manrope на long-caption32 занимает две строки
  против трёх у Noto/Golos; это статический пример, не OS scaling.
- Официальные Latin/Cyrillic metadata и OFL1.1 проверены; actual Figma
  Regular/SemiBold/Bold/ExtraBold доступны. Manrope рекомендован как кандидат,
  пользовательский выбор не сделан, D027 awaiting_review.
- Создано102 nodes; все93 прежних variables/values и40 shared styles сохранены.
  Components/sets/font files/dependencies/runtime/schema не добавлены.
  Flutter tests/native shaping/OS scaling для этого Figma/doc review не выполнялись.
  DESIGN_READY/REDESIGN_DONE не установлены.
- macOS, zsh: `check_docs.py --require-hero --require-badges` — шесть docs PASS;
  `git diff --check` — PASS. Diff содержит только шесть docs, staged diff пуст.
  Markdown-render в целевом viewer отдельно не проверен.

---

### Фактический результат R3.2, D028–D029

- Поручение продолжить после R3.1 принято как её приёмка; закреплён
  рекомендованный Manrope, без отдельного сообщения о названии семейства.
  Десять styles `StackCard/v2/Manrope/*`; 244 UI-texts на123:7/125:19 обновлены,
  два instance texts Wordmark A сохранены. Typography теперь1400×1423.
- DS page121:7: Navigation148:340 **900×1570**, Cards148:894 **900×1565**.
  Main components находятся отдельно. Созданы9 sets/44 variants, TechnologyBadge
  и MoreTechnologies, 14 editable vector icons. TEXT/INSTANCE_SWAP bindings — PASS;
  ни одного unbound свойства или missing style на новых review boards.
- Четыре root tabs с постоянными labels, геометрический selected marker,
  Root gear/Nested Back и независимый фильтр Все/Резюме/Проекты — проверены.
  Settings specimen не имеет bottom navigation; origin записан в контракте.
- DocumentCard12 variants: Resume/Portfolio × Published/Draft ×3 states.
  Во всех6 published variants Copy visible, у6 Draft скрыт и показана причина.
  Open/Copy — раздельные, не пересекающиеся области. Фактический clipboard
  success не симулируется; Ready/Pressed/Focus/Copied/Unavailable — дизайн состояний.
- ProjectCard: optional cover placeholder, title/description/source/Updated,
  два compact technology badges +N48 и полный wrapped list. Badges32 — информация,
  action labels16 и navigation labels12. Все interactive masters ≥48×48.
- Новые4 variables technology/react/typescript:2 primitives +2 mode aliases,
  scopes/codeSyntax проверены. Все93 прежних variables byte-for-byte по values
  сохранены; 40 прежних styles не редактировались, всего50. Бренд не расширен.
  Scopes четырёх text roles расширены для SVG/marker paints; values не менялись.
- Lucide10 exact SVGs, React/TypeScript2 Simple Icons paths; Flutter/Dart2
  официальных approved white knockout. Проверены shape/source/license caveats,
  без raster/external href. Полные Lucide ISC/MIT notices в Figma153:6036.
  [Проверенные источники](references.md#иконки-r32) не означают native exports.
  22 фактических technology paint samples с исходной opacity имеют
  minimum4.4419243488:1 при пороге3; failures0.
- Итоговый audit четырёх boards: **410 texts**, min **4.5853488535:1**, failures0;
  R3.2 содержит164 texts. 36 painted stroke samples и14 visible selection markers
  имеют минимум **5.2824191159:1**; bounds failures0, touch failures0.
  Повторные Navigation/Cards/Typography renders просмотрены после исправлений
  Draft footer, header Fill и Light marker. Цветовые foundations также просмотрены.
  Дополнительный audit всех44 variant masters,2 single components и provenance
  увеличил выборку до558 texts: contrast/bounds/touch/property bindings — PASS.
- Шесть изменённых документов прошли check_docs.py с hero/badges и локальными
  ссылками;78 requirement IDs/78 trace rows сохранены. git diff --check — PASS.
- R3.2 awaiting_review D029; R3.3/R3.4, prototype/R4 screens, runtime/backend/schema
  не начаты. OS scaling, keyboard, native routing/clipboard/assets ещё не проверены.
  Flutter tests для Figma/doc-only задачи не запускались.

---

### Фактический результат R3.3, D030–D031

Поручение продолжить после R3.2 принято как её приёмка и разрешение только
R3.3, D030. Созданы [четыре review boards](screens.md#r33--формы-stepper-фото-и-секции)
на DS121:7: Forms163:1334, Editing163:1576, Keyboard163:2060 и Scale166:1988.
Каждый показывает реальные instances в Dark/Light; main components отдельно.
R3.3 — awaiting_review D031, R3.4 — todo; полная R3 ещё не принята.

Новый набор содержит10 sets/67 variants, один PhotoSourceSheet и6 Lucide icons.
Поля single/multiline, selectors, checkbox/switch, SettingsRow, пять шагов,
фото/no-photo и CollectionRow используют прежние Manrope/styles/theme roles.
Видимые действия сохраняют минимум48×48; Label/Value/Helper и причины ошибок
читаемы. Drag имеет альтернативы «Выше / Ниже»; первый/последний элемент
объясняет недоступное направление. «Убрать» меняет связь с документом,
не удаляет базовую ссылку или Project. Добавление ссылки ведёт к форме label+URL.

Keyboard fixtures390×844: Save bar114h заканчивается на y580, сразу перед
резервом264h. Static ×2 fixture использует 12 намеренных font-size overrides
16→32,14→28,12→24 и отдельную композицию из исходных button instances:
«Отмена»144w / «Сохранить»198w, измеренные надписи120/170px не ломаются внутри
слов. Action bar153h также заканчивается y580; весь focused field/helper виден.
Это Figma reflow, а не подтверждение native keyboard/OS scaling.

Финальный audit15 roots (все67 masters, standalone sheet, четыре boards):
**513 видимых texts**, minimum **4.8329098110:1**, contrast failures0;
**103 control/selection stroke samples**, minimum **4.3645648113:1**, failures0.
**160 interactive samples ≥48×48**; bounds/overlaps/bad references/unbound
solid paints/missing normal styles — 0. Все четыре итоговых renders просмотрены.
50 прежних text styles сохранены; всего98 variables, новый `size/inputHeight=56`
в Metrics с WIDTH_HEIGHT scope и WEB syntax. Все93 исходных variable values
сверены с baseline: drift0; четыре technology roles R3.2 не менялись.

Фото — вымышленный generated_demo, созданный встроенным image_gen и явно
обозначенный в Selected state. [PNG](assets/r33-demo-portrait.png) и
[metadata/prompt](assets/r33-demo-portrait.json) сохранены в репозитории;
оригинальные bytes1254×1254/SHA256 сохранены. Raster загружен через upload_assets,
imageHashc5809a5c0f968bd8ed1f163a5adfeb2d0b2a077b. Это specimen, не пользовательское
фото и не camera/gallery/storage implementation. Полные ISC/MIT notices и
source provenance расширены в153:6036; [источники](references.md#assets-r33).

Документация: validator6 файлов PASS (локальные ссылки/anchors/hero/badges),
78 requirement headings соответствуют78 trace rows, отсутствующие/дублирующиеся
IDs не найдены. SHA256/размер PNG совпадают с metadata; git diff --check PASS.
Runtime/pubspec/Firestore/backend не менялись. Native caret, scroll-to-focus,
semantics/announcements, permission/picker/cancel/persistence, safe area и
OS scaling ещё не проверены; full screens/flows относятся к R4–R5, motion и
широкая state matrix — R3.4. Flutter tests для Figma/docs/assets не запускались.

---

### Фактический результат R3.4, D032–D033

Поручение «переходи к следующему этапу», ускорить работу и постоянно подключать
несколько агентов приняло R3.3 и разрешило R3.4, D032. Четыре независимых агента
подготовили states, motion contract, QA и два документа; ведущий интегрировал
изменения Figma последовательно и проверил результат. R3.4 — awaiting_review D033.

- StatePanel175:2056:5variants Empty/Loading/Error/Offline/NoResults.
- LifecycleStatus175:2101:13variants Working/Unsaved/Saving/LocalSaved/SyncPending/
  SyncError/Synced/Draft/Published/SaveError/Publishing/PublishError/Unpublished.
  Working, persistence и publication независимы; PublishError не объявляет
  неизвестный результат успешным. Unpublished требует подтверждённого Unpublish.
- Четыре editable boards:176:2036 900×1443,176:2110 900×2019,
  176:2214 900×1472,176:2418 1808×3619. State-only props, shared Manrope,
  ActionButton/CopyAction/BottomNavigation/WizardStepper и прежние icons.
- Десять Dark/Light fixtures:320×568,390×680,430×680,768×680,844×390.
  Content cap600; long ru/en/URL wrapping; Save/Отмена закреплены над четырьмя
  нижними вкладками. Вертикальный overflow разрешён только в явно clipped
  scroll viewport. SafeArea — геометрический резерв, не native acceptance.
- Шесть motion events: press/active tab/content/wizard/editor/copy. Timings
  180/240/280ms, easing cubic-bezier(0.2,0,0,1), reduced0ms сохраняет feedback.
  Это статическая спецификация; интерактивный прототип проверяется в R7.3.
- Финальный metadata audit:393 text nodes,786 Dark/Light contrast samples,
  minimum4.833:1;342 interactive stroke samples,minimum4.365:1;
  96interactive samples≥48×48. Bounds/overlaps/property references/bindings/
  TEXT scopes/styles/fixture failures0. Все четыре boards визуально просмотрены;
  после точечных правок — lifecycle и оба430fixtures.
- Из93 прежних variable values изменён только motion/slow36:13:300→280.
  Палитра и Wordmark A сохранены;98variables/50text styles, новых assets нет.
  Flutter/runtime/backend не менялись; Git-операции не выполнялись. Native scroll/keyboard/text scaling,
  actual Save/ACK/Publish и full flows остаются отдельными проверками.

Реестр и контракты: [R3.4 в screens](screens.md#r34--состояния-motion-и-адаптивность).
После пользовательской приёмки полной R3 следующая задача — R4.1.

### Фактический результат R4, D034–D035

Пользователь принял полную R3 и разрешил весь пакет R4.1–R4.7c одним
поручением D034, с параллельной подготовкой и без промежуточных остановок.
Все девять задач собраны на новой editable page [StackCard Design v2 / Screens, 184:2785](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=184-2785).
**R4 — awaiting_review D035**: 61 экранное состояние, 122 Dark/Light frames,
девять review boards. Это hi-fi target design, без runtime/backend изменений.

| **Задача / область** | **Проверенный board** | **Набор** |
|:---|:---|:---|
| R4.1 — Главная | [186:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=186-7) | 7 состояний × Dark/Light = 14 frames |
| R4.2 — Резюме | [187:1340](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-1340) | 7 состояний × Dark/Light = 14 frames |
| R4.3 — Проекты | [187:2342](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-2342) | 7 состояний × Dark/Light = 14 frames |
| R4.4 — Портфолио | [187:11625](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-11625) | 7 состояний × Dark/Light = 14 frames |
| R4.5 — Настройки и базовый профиль | [187:12466](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-12466) | 7 состояний × Dark/Light = 14 frames |
| R4.6 — Контакты и ссылки | [187:13712](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-13712) | 7 состояний × Dark/Light = 14 frames |
| R4.7a — Аккаунт и безопасность | [187:14648](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-14648) | 9 состояний × Dark/Light = 18 frames |
| R4.7b — Приватность | [187:15400](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-15400) | 5 состояний × Dark/Light = 10 frames |
| R4.7c — Приложение | [187:16002](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=187-16002) | 5 состояний × Dark/Light = 10 frames |

- Четыре root-библиотеки используют подписанные нижние tabs и gear. Home
  сохраняет ровно Все/Резюме/Проекты, mixed recent cards и отдельные Copy actions;
  greeting/readiness/quick-access не добавлены. Projects использует компактный
  Import/Create → поиск с лупой без внешнего заголовка → первый Project;
  narrow320 представлен отдельным состоянием, categories/hero отсутствуют.
- Settings/Profile/Contacts/Account/Privacy/App имеют focused состояния ввода,
  validation/error/unsaved/confirmation. Формы используют отдельные Save/Cancel;
  preferences приложения сохраняются автоматически с saving/error/retry feedback.
  Нет активной root-вкладки Settings; login email отделён от публичного контакта.
  Reorder имеет drag и Выше/Ниже; permission/provider/deletion/notification
  ограничения не обозначают новые работающие API. Unknown deletion/publication
  outcome не объявляется подтверждённым success.
- Составные ProjectListItem185:2771 и PortfolioListItem188:2861 переиспользуют
  shared R3 elements. Portfolio Published188:2817/Draft188:2841 имеют отдельный
  48px «Действия» trigger. Новый SearchField184:2784 содержит Empty/Filled/Focus;
  SearchIcon184:2762 — единственный новый pinned Lucide SVG. Итого три scoped
  families: два sets и один single component, шесть input/composition variants.
- При source/contract review исправлены шесть Portfolio action triggers,
  два дублирующих default CTA в Resume empty и два Contacts empty footer.
  Эти исправления проверены структурно в обеих темах, без visual preview.
  Три feedback-title в Light переведены в textPrimary для контраста;
  color/onPrimary получил STROKE_COLOR scope без изменения значений палитры.

Финальный audit122 frames: **7902 nodes**, включая **2074 TEXT** и
**2074 actual-mode contrast samples**, minimum
**4.7395198980:1**; **1446 control/selection stroke samples**,
minimum **4.3645648113:1**; **840 interactive targets ≥48×48**.
Все17 failure categories —0: geometry/bounds/unintended overlaps, text/stroke
contrast, styles, variable bindings/scopes, property refs, root/nested navigation,
Home/Projects contracts и Dark/Light pairs. Прежние98 variable values и50
text style IDs сохранены; STROKE_COLOR scope onPrimary расширен отдельно.
**70 fixed-brand VECTOR fills** исключены только для canonical Flutter/Dart
source assets, чтобы сохранить оригинальную геометрию и paints. Это не общее
исключение для unbound UI paints. Все шесть IMAGE nodes — прежний generated_demo
Portrait80×80 с тем же imageHash; full UI не вставлен растровым screenshot.

Projects390: первый Project занимает y252–675 и помещается до границы
viewport y746. В narrow320 он занимает y273–816: начало/title видны до fold,
нижние детали требуют scroll; полная видимость карточки до fold не заявлена.

По прямому запросу D034 **визуальный просмотр, render preview и запуск
приложения не выполнялись**. Metadata/contrast PASS не доказывает качество
отрисовки, интерактивный walkthrough, native accessibility или backend outcome.
122 frames не являются 122 реализованными screens/routes. Scroll viewport и
SafeArea остаются статической геометрией; public/source/user capabilities
проверяются в своих последующих фазах. Full editor/publication flows — R5,
prototype — R7, runtime — отдельно разрешаемая R8.

Реестр состояний и IDs: [R4 в screens](screens.md#r4--основные-экраны-и-настройки).
На момент D035 следующей задачей предполагалась R5.1a. Поручение продолжить
D036 приняло всю R4 и сохранило режим всей фазы для пакета R5.1a–R5.4c.

---

### Фактический результат R5, D036–D037

D036 приняло весь пакет R4 и продолжило следующую R5 в сохранённом режиме:
фаза целиком, параллельно, без visual preview/run. Это интерпретация поручения
«переходи к следующему этапу разработки» с прежними предпочтениями; пользователь
не перечислял все задачи R5 буквально. **Все 13 задач R5.1a–R5.4c —
awaiting_review D037**: 83 состояния, 166 Dark/Light frames на 13 boards.
Editable page [StackCard Design v2 / Flows, 193:2914](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=193-2914)
содержит статический hi-fi target design. Runtime/backend не менялись.

| **Задача / область** | **Проверенный board** | **Набор** |
|:---|:---|:---|
| R5.1a — Профиль и публичные контакты Resume | [194:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-7) | 6 состояний × Dark/Light = 12 frames |
| R5.1b — Опыт, образование, технологии и проекты Resume | [194:1160](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-1160) | 6 состояний × Dark/Light = 12 frames |
| R5.1c — Focused редактор Resume | [194:2270](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-2270) | 6 состояний × Dark/Light = 12 frames |
| R5.1d — Resume Step 5 и структурированный просмотр | [194:3295](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-3295) | 6 состояний × Dark/Light = 12 frames |
| R5.2a — Ручной проект | [194:4782](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-4782) | 6 состояний × Dark/Light = 12 frames |
| R5.2b — Импорт из GitHub | [194:5710](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-5710) | 6 состояний × Dark/Light = 12 frames |
| R5.2c — Review изменений GitHub | [194:6468](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-6468) | 6 состояний × Dark/Light = 12 frames |
| R5.3a — Создание и содержимое Portfolio | [194:7176](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-7176) | 6 состояний × Dark/Light = 12 frames |
| R5.3b — Связи Portfolio и Projects Library | [194:8156](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=194-8156) | 7 состояний × Dark/Light = 14 frames |
| R5.3c — Секции, внешний вид и preview Portfolio | [195:6196](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=195-6196) | 6 состояний × Dark/Light = 12 frames |
| R5.4a — Сохранение и явная публикация | [195:7277](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=195-7277) | 8 состояний × Dark/Light = 16 frames |
| R5.4b — Постоянная ссылка и sharing | [195:7949](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=195-7949) | 6 состояний × Dark/Light = 12 frames |
| R5.4c — Последствия действий с документом | [195:8628](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=195-8628) | 8 состояний × Dark/Light = 16 frames |

- Resume Wizard1–5 охватывает профиль/контакты, фото/no-photo/denied,
  optional experience/education/tech/projects, Skip и Back. Focused editor
  показывает local overrides, изменения базового Profile и отдельное сохранение.
  Структурированный preview использует фактическую identity документа, фото
  либо no-photo и длинный контент; owner editor controls не вставлены в документ.
- Manual Project имеет input/validation/media placeholder/Save/Cancel.
  GitHub import охватывает selection, already imported/dedup, pagination/cache,
  rate/error; source review показывает Accept/Ignore/Cancel, protected curated
  overrides, stale UID/retry и отдельный Save. Это макеты source contracts,
  без нового SDK/OAuth или работающей сетевой операции.
- Named Portfolio разделяет content/appearance/preview. Add existing и create
  global+attach оставляют global Project в library; order/visibility/featured
  принадлежат association. Remove relation не удаляет общий Project. Секции,
  reorder и оформление показаны focused состояниями; preview без фото полный.
- Local Save, private sync ACK и explicit Publish представлены отдельными
  состояниями. First/update Publish имеют отдельные gates и feedback;
  dirty draft не объявляется новым public snapshot. Неизвестный исход Publish,
  Unpublish или Delete требует проверки статуса операции, без ложного success
  или гарантии сохранности публичной версии. Copy/Open/Share доступны повторно
  у опубликованного документа; Copy confirmation/error и draft→Publish отдельны.
  Unpublish/delete/duplicate/rename показывают последствия и подтверждения;
  политика постоянного адреса D019 сохранена, real URL migration ещё prerequisite.
- DS дополнили три scoped reusable families: DocumentIdentity193:2864 с двумя
  photo/no-photo variants, ChangeComparison193:2865 и ProjectAssociationRow193:2872.
  Они составлены из принятой R3–R4 DS; используются те же fonts/tokens/assets.

Финальный структурный audit **166 frames / 10 872 nodes**: **3474 TEXT** и
**3474 actual-mode text contrast samples**, minimum **4.8329098110:1**;
**1280 control/selection stroke samples**, minimum **4.3645648113:1**;
**966 interactive targets ≥48×48**. Все **18 failure categories — 0**:
geometry/bounds/unintended overlaps, styles, bindings/scopes/property refs,
text/stroke contrast, navigation, footer, wizard, preview и Dark/Light pairs.
Проверены активные шаги Wizard1–5, 16 структурированных preview, 84 form screens
и 152 fixed footer. Footer расположен у нижнего края, с внутренним SafeArea
padding20; это проверка статической геометрии, не native SafeArea.

Прежние **98 variable values и 50 text style IDs сохранены точно**.
48 проверок текста фактической identity документа в preview — PASS. Все **14 IMAGE
fills** имеют прежний generated_demo imageHash
`c5809a5c0f968bd8ed1f163a5adfeb2d0b2a077b` и геометрию **80×80**.
**274 original Flutter/Dart VECTOR fills** сохранены как targeted source-brand
exemption; это не общее исключение для unbound UI paints. Новые внешние media,
fonts или palette roles не добавлены; full UI не заменён растровым screenshot.

**Визуальный просмотр, render preview и запуск приложения не выполнялись**
по сохранённому запросу пользователя D034/D036. Structural/contrast PASS не
доказывает отрисовку, playable transitions, native keyboard/input retention,
media permissions, GitHub/cloud mutations или работу sharing/public routes.
16 preview — frames документа, не подтверждённый runtime renderer; 166 frames
не означают 166 реализованных screens. Prototype относится к R7, перенос UI —
к отдельно разрешаемой R8. На момент D037 следующей была полная R6 после
приёмки R5; D038 приняло весь пакет R5 и начало R6.1–R6.4.

Реестр состояний и IDs: [R5 в screens](screens.md#r5--создание-редактирование-и-публикация).

---

### Фактический результат R6, D038–D039

Поручение «переходи к следующему этапу разработки» после D037 принято как
приёмка всей R5 и переход к следующей полной R6 в сохранённом режиме:
phase package, параллельно, без visual preview/run. Это интерпретация контекста;
пользователь не называл весь набор R6 буквально. **Все четыре задачи R6.1–R6.4
— awaiting_review D039**: **24 базовых состояния / 96 frames**,
wide1440/narrow390 × Dark/Light, четыре boards. Editable page
[StackCard Design v2 / Web, 202:2989](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=202-2989)
содержит static Figma target; Next.js/runtime/backend не менялись.

| **Задача / область** | **Проверенный board** | **Набор** |
|:---|:---|:---|
| R6.1 — Полный landing StackCard | [204:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=204-7) | 1 базовых состояний × wide/narrow × Dark/Light = 4 frames |
| R6.2 — Web auth и скачивание | [205:625](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=205-625) | 8 базовых состояний × wide/narrow × Dark/Light = 32 frames |
| R6.3 — Адаптивный рабочий кабинет | [206:1593](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=206-1593) | 8 базовых состояний × wide/narrow × Dark/Light = 32 frames |
| R6.4 — Публичные Resume и Portfolio | [206:28486](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=206-28486) | 7 базовых состояний × wide/narrow × Dark/Light = 28 frames |

- Landing объясняет общую базу → разные Resume/Portfolio и включает полный
  marketing путь с собственным product preview, Projects/GitHub, документами,
  публикацией/ссылками, приложением и CTA/footer. Финальные размеры полного
  landing: wide **1440×3475**, narrow **390×5628**; это scroll-page geometry,
  не проверка browser rendering. Фиктивная release availability не заявляется.
- Auth охватывает login/register/validation/error/reset/check-mail и restoring
  с безопасным return guard. Download содержит честный unavailable-state;
  действие с отсутствующим release/store target не обозначается рабочей загрузкой.
  Proposed `/login` и `/workspace` — адреса в CTA contract, не созданные routes.
- Workspace разделяет shared base/library/documents, focused edit/overrides,
  appearance/no-photo и preview. Wide допускает параметры рядом с просмотром;
  narrow использует отдельные Edit/Preview modes. Unsaved route guard и Save
  error сохраняют ввод по контракту; current ACK и explicit Publish разделены.
- Anonymous Resume/Portfolio показывают selected public fields, фото/no-photo
  и минимальный набор; missing/unpublished и load-error отдельны. Owner editor
  controls/private account/draft fields не включены в public composition.
  Published документы имеют постоянные Copy/Open/Share, в том числе minimal;
  unavailable/error не получают публичных links. Это статическая privacy
  композиция, не доказательство server payload/access checks.

Финальный structural QA **96 frames / 8962 nodes**: **2810 TEXT** и
**2810 actual-mode text contrast samples**, minimum **4.8329098110:1**;
**690 stroke samples**, minimum **4.3645648113:1**;
**726 interactive targets ≥48×48**. Все **20 failure categories — 0**:
geometry/bounds/overlaps, styles/bindings/scopes/property refs, text/stroke
contrast, navigation/footer, workspace/public contracts, four-mode coverage,
CTA и Wordmark. Проверены 24 workspace pane frames и 8 overview frames;
28 public frames включают missing/unpublished и load-error states.

**116 source CTA records** сопоставлены с proposed destinations/action intents.
Это static contract audit; реальные URL, stores, auth и операции не запускались.
Доступные Published card Copy actions сохранены, у Draft card Copy отсутствует;
unavailable actions имеют disabled/target-null состояние. WebHeader202:2932
содержит две variants; WorkspaceNavigation202:2933 — reusable workspace family.
После структурных правок перепроверены layout в 32 frames, 96 Wordmarks,
четыре public navigation и 16 public contact hit areas.

Baseline: **98 variable values и 50 style IDs сохранены точно**. Все **28 IMAGE
fills** — прежний generated_demo Portrait80×80 с тем же imageHash
`c5809a5c0f968bd8ed1f163a5adfeb2d0b2a077b`.
В landing встроены **8 editable clones фактического R5 document content**;
product preview не заменён raster UI. **96 Noto Wordmark texts** — targeted
exception только для сохранённого Editable Wordmark A; их paints всё ещё
проверены. **462 canonical Flutter/Dart VECTOR fills** сохранены как targeted
source-brand exemption. Эти исключения не распространяются на остальной UI.

**Visual inspection, render preview и запуск приложения пропущены** по
сохранённому прямому запросу пользователя D034/D038. Structural/contrast PASS
не доказывает browser focus/keyboard, auth, cloud writes, store fulfillment,
экспорт, clipboard/sharing или действующие public URLs. D019 сохраняет target
постоянного адреса документа; `/u/[username]` остаётся legacy singleton plan,
новая route scheme/migration — отдельный prerequisite. apps/web по-прежнему
содержит только README; web implementation не создана. На момент D039
следующей была R7; D040 приняло R6 и разрешило R7, затем R8/R9. Actual R7
package/DESIGN_READY и prerequisite scope ещё не готовы.

Реестр, geometry и IDs: [R6 в screens](screens.md#r6--веб-поверхности).

### Фактический source package R7 (D040/D041)

Сборка R7 и структурная QA завершены. Все четыре задачи и весь пакет —
**awaiting_review**: явная приёмка R7.4/DESIGN_READY ещё отсутствует.
[r7-handoff.json](source/r7-handoff.json) содержит переносимый реестр frames,
transitions, проверок, hashes и ограничений. Авторизация R8 уже получена D040.
Отказ от preview/playback/native run учтён как пропущенные проверки.

Проверены 22 expected-contract chunks и один topology call — PASS.
Все 2736 expected bindings совпали: 1758 mobile (879 contracts × Dark/Light)
и 978 web. Web содержит 946 contracts и 974 уникальных control nodes.
Общий scope: 723 root frames, 52255 nodes, 15822 TEXT, 328 flow starts;
все 11 failure categories равны нулю. Destinations принадлежат реальным roots.
Проверены validity и уникальность фактических start IDs/names; точный expected
набор start names не предоставлен. Journey walkthrough не выполнялся
(checked=0, omitted); `fullR7Pass` остаётся null. Эти результаты не заменяют
исторические QA R4–R6 и не доказывают исполнение маршрута пользователем.

Шесть standard/reduced motion pairs используют одинаковые source/targets:
180/240/280 ms и статическую альтернативу без transition (эквивалент 0 ms).
Timers и SET_VARIABLE отсутствуют. Значения 98 variables и IDs 50 styles
сохранены точно по baseline fingerprints. Snapshot свойств styles не
предоставлен, сохранность самих свойств не проверялась. Преобразование 380 host
copies в Page сохранило explicit Dark/Light и backup/audit/rollback; это
операция Figma source, а не миграция пользовательских данных.

Adaptive scope: 12 новых fixtures, 10 повторно использованных R3.4 adaptive
и два R3.3 keyboard sources. Проверены 1876 nodes, 490 texts, 170 targets,
314 stroke samples; все 16 failure categories равны нулю. Минимумы контраста:
text 4.832909811:1, stroke 4.364564811:1. 180 static ×2 text samples подтверждают
source reflow; native OS text scaling и input/IME не проверены.

Visual inspection, preview, prototype playback/native app launch и golden
updates пропущены по запросу. Public web/media/SDK/auth и новая model/schema
не реализованы graph-проверкой. R7 — awaiting_review, DESIGN_READY pending.
Частичный R8 и [R9 supported UI validation](source/r9-supported-ui-validation.json)
с 950 тестами подтверждены отдельно; полный REDESIGN_DONE не установлен.
[Prerequisite scope](prerequisites.md) — proposed, ответа пользователя ещё нет;
Phase 11 автоматически не начата.

### Фактический перенос поддерживаемого UI R8/R9 (D040)

На `redesign/full-app` внедрён независимый существующий Flutter slice:
semantic Dark/Light Lime, Manrope400/600/700/800 с Noto fallback, единый
`core/theme`, shared button/input/state controls, `StackCardIcon`,
`StackCardTechnologyBadge` и `StackCardMoreTechnologies`. Projects использует
query-only presentation без категорий; legacy filter provider не удалён.
Settings/appearance/account открываются вне Shell; gear target≥48 и bottom
navigation сохранены на tablet. В Shell три реальные roots; Resume library
не создана. Home/Portfolio имеют прежнюю composition, полная R4/R5 UI parity
не заявляется. Domain/Hive/outbox/UID/Rules/multiple-doc schema не мигрированы.

Live `StackCardBrand` выбирает один исходный outlined Wordmark A (включает
Mark) либо compact Mark: Dark paper/Light ink, contain, без набора Text/tint.
Импортированы9original Brand A SVG; native AppIcon packaging не заменялось.
[Source manifest](../../apps/mobile/assets/design_v2/source-manifest.json)
содержит40canonical asset/license entries и отдельный CSS-inline Flutter
render derivative. Итого41files/33SVG;32runtime SVG реально compiled/decoded.
Flutter source geometry/white fill/.72 opacity сохранены в derivative, исходный
canonical SVG неизменён. Portable
[check_imports.py](../../tools/redesign/check_imports.py) strict PASS и12negative
cases; headless10-case SVG paint suite PASS. Новый raster UI не создавался.
[figma-design-v2.json](source/figma-design-v2.json) — переносимый источник
variables/styles, не доказательство полного R7 graph или runtime acceptance.

Итог после SVG compatibility и live Brand A fixes: Flutter3.47.4/Dart3.13.3,
`flutter analyze --no-pub` — PASS/0issues3.8s;
`flutter test --no-pub --reporter expanded` — **950/950 PASS29s**,118 новых
случаев относительно832baseline,0SVGwarnings.184lib/test Dart files заморожены
до/после прогона, агрегатный SHA-256
`d51aee259557296fde1a16682973dd03b3c96b5cee614ac536f82bfade2d30e2`.
Intermediate946-case runs предшествовали live Brand A и сохранены как история.
Переносимое evidence с командами, results, source/log hashes и limitations —
[r9-supported-ui-validation.json](source/r9-supported-ui-validation.json);
он явно содержит fullR9CompletionAsserted=false/REDESIGN_DONE=false.
Локальный подробный отчёт — `/private/tmp/stackcard-r9-actual-validation.md`;
полные логи `stackcard-r9-actual-analyze-brand-final.log`,
`stackcard-r9-actual-tests-brand-final.log` и source snapshot с тем же suffix
лежат в `/private/tmp`, являются локальным evidence текущей сессии.

Команды фактического прогона, macOS zsh/bash, cwd `apps/mobile`:

```zsh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

UI checks измеряли Dark/Light, scale1/2,ru/en,7viewports включая320×568 и
568×320,focus/keyboard/48px,loading/error/retry/previousvalue/UID; это headless
widget/engine evidence. No-preview/run запрос исключил native launch, device/
emulator smoke, Figma playback, golden creation/update и визуальное сопоставление.
Нативные font/SVG/AppIcon, live Google/reset/iOS и весь новый web/security не
подтверждены. Новые model/media/account/publication prerequisites предложены
в [отдельном scope](prerequisites.md), ответ pending. R7 full graph QA PASS D041,
пакет awaiting_review; полная R8/R9 и пользовательская приёмка не завершены;
DESIGN_READY/REDESIGN_DONE не установлены, Phase11 автоматически не начата.

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
| D011 / позднее | R8 отдельное разрешение и R9 REDESIGN_DONE | Авторизация R8/R9 получена D040; actual scope/limitations и evidence ещё нужны. REDESIGN_DONE не установлен |
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
| D026 / 2026-10-05 | После «r2 завершён, переходи к следующей фазе» пользователь уточнил: «Остаться на R3.1 — сначала пересмотреть foundations и шрифт» | Разрешён только review текущей R3.1; foundations/шрифт ещё не приняты, R3.2 не начинается |
| D027 / 2026-10-05 | Повторный audit foundations и editable Font Review Noto Sans / Manrope / Golos Text | awaiting_review; board138:19, шесть390×588 specimens,82 texts contrast PASS. Цвета/styles сохранены; Manrope — рекомендация, пользовательский выбор не сделан; R3.2–R3.4 todo |
| D028 / 2026-10-05 | «переходи к следующему этапу разраотки» после Font Review R3.1 | Поручение принято как приёмка review R3.1 и разрешение только R3.2. Для продолжения закреплён рекомендованный Manrope; отдельного сообщения с названием шрифта не было. R3.1 done; палитра/Wordmark A сохранены. R3.3/R3.4/runtime/Git mutations не разрешены |
| D029 / 2026-10-05 | Editable Navigation/cards/TechnologyBadge R3.2 | awaiting_review; boards148:340/148:894, 9 sets/44 variants, 14 SVG icons. 410 actual texts/36 stroke samples/14 markers contrast PASS; bounds/property bindings/touch targets PASS. R3.3–R3.4 todo; native routing/clipboard/exports pending |
| D030 / 2026-10-05 | «переходи к следующему этапу разраотки» после результата R3.2 | Принята R3.2; разрешена только R3.3 — формы, stepper, фото и секции. R3.4/R4/runtime/backend/Git mutations не разрешены |
| D031 / 2026-10-05 | Editable forms/stepper/photo/sections R3.3 и keyboard/scale specimens | awaiting_review;163:1334/163:1576/163:2060/166:1988,10 sets/67 variants,1 sheet/6 SVG icons.513 texts/103 strokes/160 interactive samples PASS; bounds/reference/normal styles PASS. Фото generated_demo, native keyboard/media/OS scaling pending; R3.4 todo |
| D032 / 2026-10-05 | «переходи к следующему этапу», ускорить работу, несколько агентов постоянно, ограничения на агентов сняты | Принята R3.3; разрешена R3.4. Независимые части делегированы, Figma writes последовательные. Переходы фаз и DESIGN_READY сохраняют приёмку; runtime/backend/Git не разрешены |
| D033 / 2026-10-05 | Editable states/motion/adaptive R3.4 | awaiting_review;2sets/18variants,4boards176:2036/2110/2214/2418,10Dark/Light fixtures.393texts/786mode samples,342strokes/96targets PASS;0bounds/refs/bindings/scopes failures.180/240/280ms+reduced0ms — static spec; R7prototype/native pending |
| D034 / 2026-10-05 | Прямое поручение выполнить всю R4.1–R4.7c параллельно, без visual preview и запуска приложения | Принята полная R3, включая R3.4/D033. Разрешены все девять задач R4 одним пакетом; промежуточные остановки по экранам отменены для этого пакета. R4 in_progress; renders/preview/run пропускаются явно, metadata/contrast/docs checks сохраняются. R5/R8/runtime/backend/Git mutations не разрешены |
| D035 / 2026-10-05 | Editable hi-fi весь пакет R4.1–R4.7c | awaiting_review; 9boards/61states/122Dark-Light frames на page184:2785. 2074actual-mode text samples ≥4.739:1,1446strokes ≥4.364:1,840targets≥48;17failure categories0.70targeted original-brand fill exemptions. Три scoped families/6variants, один pinned Search SVG;98variable values/50style IDs preserved; onPrimary STROKE_COLOR scope расширен. Visual preview/run пропущены по D034; runtime/backend не менялись, R5/R8 не разрешены |
| D036 / 2026-10-05 | «переходи к следующему этапу разработки» после результата всей R4 | Принята вся R4/D035. Следующей фазой начата R5, все13 задач одним пакетом с сохранением ранее согласованных full-phase/parallel/no-preview предпочтений. Это интерпретация продолжения; пользователь не называл весь набор R5 буквально. R5 in_progress; R6+/R8/runtime/backend/Git mutations не начаты |
| D037 / 2026-10-05 | Editable hi-fi весь пакет R5.1a–R5.4c | awaiting_review; 13 boards / 83 states / 166 Dark-Light frames, page193:2914. 10 872 nodes;3474text samples min4.832909811:1;1280strokes min4.364564811:1;966targets≥48;18failure categories0. Wizard1–5/16preview/84forms/152fixedfooter PASS;98values/50styleIDs unchanged;48identity checks PASS;14existing demo imagefills80×80;274targeted originalFlutter/Dart fills retained. Три scoped DS families; visual inspection/preview/runtime omitted D034/D036. R6todo/R8 не начаты; backend/Git не менялись |
| D038 / 2026-10-05 | «переходи к следующему этапу разработки» после общего результата R5/D037 | Принята вся R5. Следующей начата полная R6.1–R6.4 одним пакетом с сохранением phase-package/parallel/no-preview/run предпочтений. Это интерпретация next-stage context; пользователь не называл весь набор R6 буквально. R6 in_progress; R7+/R8/runtime/backend/Git не начаты |
| D039 / 2026-10-05 | Editable hi-fi весь пакет R6.1–R6.4 | awaiting_review; 4 boards / 24 states / 96 wide-narrow Dark-Light frames, page202:2989. 8962 nodes;2810text samples min4.832909811:1;690strokes min4.364564811:1;726targets≥48;20failure categories0.116sourceCTA records checked against proposed destinations.98values/50styleIDs exact preserved;28existing demo80×80 imagefills,8actualR5 editable preview clones.96targeted Noto Wordmark exceptions and462canonicalFlutter/Dart originalfills preserved. Landing1440×3475/390×5628. Visual inspection/preview/runtime omitted by request; R7todo/R8closed, apps/web README-only |
| D040 / 2026-10-05 | Прямое поручение завершить R7/R8/R9, увеличить число агентов и применить результат на redesign/full-app | Принята R6/D039. R7 full graph QA pending; independent R8 shared UI/Projects/supported Settings/Brand A перенесены параллельно, R9 existing slice950/950 PASS/analyze0issues. Full product prerequisites предложены, scope ответа нет; повторного phase approval нет. DESIGN_READY/REDESIGN_DONE не установлены; no-preview/run сохранён, commit/push/deploy/Phase11 не запрошены |
| D041 / 2026-10-05 | Завершённый R7 source package и структурная QA | awaiting_review: 2736 matched bindings (1758 mobile / 978 web), 879 mobile / 946 web contracts, 974 web controls; 723 roots / 52255 nodes / 15822 TEXT, 328 unique starts. 22 contract chunks + topology PASS, 11 failure categories = 0. 6 motion pairs same targets, 180/240/280 ms + static/reduced, no timers/SET_VARIABLE. 12 new adaptive + 10 reused + 2 keyboard; 180 static ×2 texts, 16 adaptive failure categories = 0. 98 variable values / 50 style IDs exact; style properties not checked. Portable r7-handoff.json, fullR7Pass=null. Visual/playback/native omitted; R7.4 explicit acceptance/DESIGN_READY pending. Partial R8/R9 supported 950 PASS не означает полный REDESIGN_DONE; prerequisites proposed, scope pending |
| D042 / 2026-10-05 | «теперь всё из ветки redesign/full-app перенеси в dev. закомментируй все изменения и отправь в гитхаб» | Разрешены commit всех изменений редизайна, исправление сообщения неопубликованного коммита, линейный перенос всей ветки в dev и push origin/dev. «Закомментируй» интерпретировано как «закоммить». Это Git delivery; R7 acceptance/DESIGN_READY, prerequisite scope, deployment и Phase11 этим поручением не подтверждены; no-preview/run сохранён |
| D043 / 2026-10-07 | «перейди в локальную ветку dev. убедись что в ней есть изменения дизайна из redesign/full-app и приступай к разработке 11 фазы» | Подтверждены одинаковые refs dev/redesign/full-app на16ec4ed; разрешена Phase11 Media и возобновление этого функционального этапа. Полная Design v2 acceptance/REDESIGN_DONE не закрыта; Phase12, commit/push/deploy/billing не разрешены. |
| D044 / 2026-10-07 | «переходи к следующей фазе», затем «вычеркнем полностью пункты по добавлению карты, удали что было создано под это и продолжи разработку без этого» | Разрешена Phase12 с изменённым scope: ручной город/страна и optional geolocation, без карты/marker/Maps SDK/API keys. Созданные Maps-зависимости/config/type удаляются. Открытая Phase11/Phase7/Design v2 acceptance сохраняется; Phase13 и commit/push/deploy/billing не разрешены. |
| D045 / 2026-10-07 | Пользователь просматривает dev и Figma, указывает на отсутствие новой навигации/логики и просит поставить разработку по фазам на паузу, развивая функционал под Figma и идею программы | Разрешён capability-based private mobile scope: stateful four roots, mixed Home/library, independent Resume/Portfolio snapshots/relations/editors, Developer base и compatible Hive5/cloud4 adapters. История фаз/R7 awaiting_review сохранена. Public multioutput Publish/URL/web/full account/native review остаются pending; no-preview/run сохранён. Полная Design v2 acceptance, commit/push/deploy этим поручением не выполнены. |
| D046 / 2026-10-07 | «продолжи разработку», затем явный выбор «Продолжить mobile по Figma» | Продолжен D045 private mobile scope: captured base review для Resume/Portfolio по R5.1c194:2999/3051, выбор field/stable-ID updates с сохранением local overrides и отдельным Save; совместимые Hive6/cloud5. Web/публикация/commit/push/deploy не начаты, no-preview/run и полная Design v2 acceptance открыты. Проверки — в product spec. |
| D047 / 2026-10-08 | Пользователь уточнил полноту переноса/функций и поручил обновить основные пункты разработки под Figma и ранее присланную концепцию | Основной roadmap обновлён под общую базу/Library и multiple Resume/Portfolio: remaining mobile/settings, trusted publication/permanent URL/public reader, web кабинет, Inbox/Share и качество/выпуск. История Phase 0–12/D045/D046 сохранена; full Figma acceptance и возобновление старой очереди не объявлены. В этом шаге только документы/source audit, без runtime/deploy/Git mutations. |

Новый scope change записывается отдельной строкой с причиной, requirement IDs,
влиянием на задачи/gaps и явным решением пользователя. Исторические результаты
не переписываются. R6 принята D040; R7 source/graph QA PASS D041,
весь пакет awaiting_review, явная приёмка/DESIGN_READY pending.
D040 independent slice и historical R9 Flutter950/analyze evidence сохранены.
D045 разрешает private mobile functional work и ставит phase queue на паузу.
Actual subset/remaining proposal разделены в [prerequisites](prerequisites.md).
No-preview/run сохранён, DESIGN_READY/REDESIGN_DONE и full acceptance открыты.
D042 Git delivery историческая; новые commit/push/deploy не выполнены.
