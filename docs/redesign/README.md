<div align="center">

# StackCard Design v2

**Отдельная инициатива полного редизайна mobile, web и публичных документов**

![Phase R7](https://raster.shields.io/badge/Phase-R7-C7FF1A?style=for-the-badge)
![Status awaiting review](https://raster.shields.io/badge/Status-awaiting_review-14161B?style=for-the-badge)

</div>

---

## Содержание

- [Цель и статус](#цель-и-статус)
- [Документы](#документы)
- [Остановка основной разработки](#остановка-основной-разработки)
- [Актуальная версия](#актуальная-версия)
- [Как продолжать](#как-продолжать)

---

## Цель и статус

**Действующее поручение 2026-10-08 (D048):** «закончи перенос» и явный ответ
«Также реализовать web и публикацию» разрешают mobile + actual Next.js web +
trusted publication независимых документов. Очередь фаз остаётся на паузе;
D045/D046 private core, captured base review и отдельный Save сохраняются.
D048 расширяет модель до Hive7/cloud6/privacy/attachment overrides, server
inventory/operation recovery/permanent `/d/<publicId>`/public media/delete lifecycle.
Текущие source/results - в [product status](../product/product-spec.md#статус-и-границы-текущей-работы)
и [prerequisites](prerequisites.md#перенос-d048--2026-10-08).
[Проверки D048](../product/product-spec.md#проверки-d048--2026-10-08): mobile1323/1323,
backend51/projection14 и web62/check/format/audit0 PASS; browser publication и Android isolated actual-app build/Home/Resume/Share
проверены. Final analyze0 и Android Share sheet PASS; запрошенная D048
implementation/local verification выполнены, full acceptance/release отдельно.
[Verification report](source/d048-transfer-verification.json) хранит результаты и screenshot digests.

R7 остаётся awaiting_review; DESIGN_READY/REDESIGN_DONE не установлены.
Последующий ответ «Да, выполнить визуальную проверку web/mobile» разрешает
D048 preview/browser/native проверки; headless evidence не означает
visual/device/live parity, actual результаты фиксируются отдельно. Deploy/billing/commit/push не запрошены.
[Capabilities roadmap](../product/product-spec.md#актуальная-последовательность-2026-10-08)
разделяет current source, открытую приёмку и следующие Inbox/FCM/QR/release задачи.

Дальнейшие записи о состоянии 2026-10-05 — история переноса D040–D042.
Последующие Phase 11 Media и Phase 12 Location без карты сохраняют свои
открытые device/live проверки; последнее поручение не закрывает их автоматически.

StackCard создаёт разные структурированные Resume и публичные Portfolio из
общей профессиональной базы DeveloperProfile и библиотеки Project. Design v2
перепроектирует визуальную систему и сценарии, сохраняя бизнес-логику, данные,
интеграции и Material 3 как техническую основу Flutter.

На **2026-10-05** R7.1–R7.4 — `awaiting_review`, D041; R6 принята D040.
R7 source build и структурная QA завершены D041; пакет — `awaiting_review`.
[Переносимый handoff](source/r7-handoff.json) фиксирует 2736 фактических bindings
(1758 mobile +978 web),723 roots/52255nodes/15822 TEXT и328 уникальных starts;
22 expected-contract chunks +topology PASS,11 failure categories0.
Шесть motion pairs сохраняют targets,180/240/280ms иreduced0ms; нет timers
и SET_VARIABLE.98 variables/50 style IDs сохранены точно.12 новых adaptive
fixtures используют10существующих adaptive и2 keyboard sources;180 static ×2
text samples иcontrast PASS. Это structural/graph evidence; preview/playback/
native launch пропущены по запросу. R7.4/явная приёмка пользователя открыта,
DESIGN_READY/REDESIGN_DONE не установлены; новая авторизация R8 не требуется.

R8/R9 прямо разрешены D040 на `redesign/full-app`. Независимая часть переноса
выполнена параллельно подготовке R7: Manrope/semantic Lime, shared controls,
проверенные SVG, live Brand A, Projects search/list и поддерживаемые Settings.
R8 остаётся частично выполненной; R9 проверила этот существующий Flutter slice:
`flutter analyze --no-pub` — 0 issues, 3.8s; полный
`flutter test --no-pub --reporter expanded` — 950/950 PASS, 29s,
118 новых случаев относительно baseline832, 0 SVG warnings.
На момент D040 Home/Portfolio сохраняли прежнюю композицию; Shell имел три
roots, Resume library/web отсутствовали. Это baseline history; D045 private
mobile scope и remaining public/account/web предложение разделены в
[prerequisites](prerequisites.md).
R7 graph QA PASS D041; явная пользовательская приёмка/DESIGN_READY pending.
Полный R8/R9 и REDESIGN_DONE не закрыты.
Visual preview/playback/native launch пропущены по запросу; headless tests не
подтверждают native visual parity, live Google/iOS или backend новых сценариев.
Перенос `redesign/full-app` в `dev` и commit/push разрешены D042.
D042 не разрешало deployment/автоматический старт Phase11; поздние поручения
Phase11/12 и D045 отражены в текущем статусе.
R7 пакет создан на [page221:7](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-7)
и [board221:8](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=221-8).
Подробные результаты — в [плане](plan.md#фактический-перенос-поддерживаемого-ui-r8r9-d040)
и [переносимом R9 evidence](source/r9-supported-ui-validation.json);
оно явно не утверждает полный R9/REDESIGN_DONE.
Историческое evidence R6/D039:
[24 состояния / 96 frames / 4 boards](screens.md#r6--веб-поверхности), wide/narrow × Dark/Light.
Structural/contrast/CTA PASS: 2810text samples min4.832909811:1,690strokes
min4.364564811:1,726targets≥48;20failure categories0.116sourceCTA records
проверены против proposed destinations; live URLs/stores не запускались.
98values/50style IDs сохранены точно;28existing demo80×80 imagefills и
8actual R5 editable preview clones. Wordmark Noto96 и source-brand fills462
имеют только targeted preservation exceptions. Это static Figma evidence.
Поручение «переходи к следующему этапу разработки» после D037 принято как
приёмка всей R5 и переход к следующей полной R6. Сохраняется режим фаза целиком,
несколько агентов, без visual preview/run; это интерпретация контекста,
пользователь не перечислял R6 буквально. Все четыре задачи охватывают landing,
auth/download, responsive owner workspace и anonymous Resume/Portfolio.
R5 принята D038: [83 состояния / 166 Dark/Light frames / 13 boards](screens.md#r5--создание-редактирование-и-публикация).
R4 принята D036: 61 state / 122 Dark/Light frames на девяти boards.
Визуальный просмотр, preview и запуск приложения пропускаются по прямому запросу;
Исторические checks R5/D037 — Structural/contrast/bindings PASS: 3474 actual-mode text samples
(min4.832909811:1), 1280 strokes(min4.364564811:1), 966 targets≥48;
все18 failure categories0. Wizard1–5/16preview/84forms/152fixedfooter проверены
структурно;98values/50style IDs сохранены,48identity checks PASS.
Три DS families переиспользуют прежние assets;14image fills — прежний demo80×80.
274 original Flutter/Dart fills сохранены отдельным source-brand exemption.
План R0 и три схемы IA R1.1 приняты прямыми поручениями начать первую фазу
и перейти к следующему шагу. **R1.1–R1.3 — `done`**: R1.2 принята поручением
исправить кнопки/поиск и затем продолжить (D015), правки проверены.
R1.3 принята поручением «переходи к следующему этапу» (D017).
**R1.4 и R1 — `done`**: поручение добавить цветовые акценты и затем продолжить
выполнено с проверкой (D020). На 88 low-fi экранах выделены основные действия,
выбранные состояния и ошибки; компактные горизонтальные ряды сохранены.
**R2.1 — `done`**, D022: сравнение принято поручением продолжить.
**R2.2, R2.3 и R2 — `done`**, D024: пользователь выбрал бренд A и поручил
перейти к следующей фазе. Mark/Wordmark/AppIcon A закреплены без смены IDs;
связанные пилоты A / Cyber Editorial служат основой R3. B сохранён как история.
**R3.1 — `done`**, D028: после Font Review D027 пользователь поручил перейти
к следующему этапу. Для продолжения закреплён рекомендованный Manrope;
UI foundations обновлены, принятый Wordmark A и палитра сохранены.
**R3.2 — `done`**, D030: Navigation/cards/TechnologyBadge приняты поручением
продолжить. **R3.3 — `done`**, D032: формы, stepper, фото и секции приняты
поручением продолжить. **R3.4 и полная R3 — `done`**, D034:
states/motion/adaptive собраны и проверены в review D033, затем приняты. Добавлены2sets/18variants и10Dark/Light fixtures; четыре
агента подготовили независимые части, ведущий интегрировал Figma последовательно.
Постоянный адрес каждого документа принят D019; реализация URL-контракта предстоит.

| **Состояние** | **Что подтверждено** |
|:---|:---|
| Аудит и план | R0 принята поручением начать R1; исходные результаты и ограничения сохранены в audit/references |
| IA Design v2 | [Navigation, ownership и lifecycle](screens.md#r11--информационная-архитектура); R1.1 принята поручением продолжить, D013 |
| Low-fi Design v2 | [24 экрана R1.2](screens.md#r12--low-fi-основных-сценариев), [24 экрана R1.3](screens.md#r13--low-fi-resume-wizard-и-редактора) и [40 экранов R1.4](screens.md#r14--low-fi-projects-portfolio-и-публикации) приняты. Всего 88 phone frames, цветовые правки D020 проверены |
| Визуальные макеты Design v2 | [Бренд A](screens.md#r23--принятый-бренд-и-направление) принят D024; R3.1 done D028, Manrope. [Navigation/cards/badges R3.2](screens.md#r32--навигация-карточки-и-technologybadge) приняты D030; [Forms/stepper/photo/sections R3.3](screens.md#r33--формы-stepper-фото-и-секции) приняты D032; [States/motion/adaptive R3.4](screens.md#r34--состояния-motion-и-адаптивность) приняты D034; [все девять задач R4](screens.md#r4--основные-экраны-и-настройки) приняты D036; [весь пакет R5](screens.md#r5--создание-редактирование-и-публикация) принят D038; [весь пакет R6](screens.md#r6--веб-поверхности) принят D040; R7 awaiting_review D041, R8/R9 partial авторизованы D040 |
| Интерактивный прототип Design v2 | R7 source graph/structural QA завершены D041; package awaiting_review. Playback/visual omitted, DESIGN_READY pending |
| Реализованный Design v2 UI | D040 shared slice сохранён; D045 private mobile navigation/libraries/editor реализуются на той же DS. Полная Figma/native/public/web parity не подтверждена |
| Backend новых сценариев | D048 private cloud6 и trusted document publication functions с permanent ID/public media/delete lifecycle; actual Next.js owner/public runtime. Live deployment/acceptance не подтверждены |

---

## Документы

- [requirements.md](requirements.md) — требования с ID, запреты, модель продукта и прослеживаемость.
- [audit.md](audit.md) — фактические routes/source/Figma, расхождения и продуктовые пробелы.
- [references.md](references.md) — изученные источники, конкретные компоненты, применимые приёмы и условия переноса.
- [plan.md](plan.md) — главный поэтапный план R0–R9, задачи, проверки, зависимости и журнал решений.
- [screens.md](screens.md) — текущие и предлагаемые экраны, переходы, состояния и компоненты.
- [prerequisites.md](prerequisites.md) — действующий private slice и оставшийся proposal модели/publication/account/web; статус каждого дополнения разделён.

Основной продуктовый roadmap остаётся в
[product-spec.md](../product/product-spec.md#план-разработки), устройство действующей
системы — в [architecture.md](../architecture/architecture.md).

---

## Остановка основной разработки

**Действующий режим D048:** очередь фаз на паузе, mobile/web/publication scope
по концепции/Figma разрешён. История ниже описывает первоначальную остановку
2026-10-05 перед Phase11, а не запрет нынешних mobile changes.

Последняя завершённая функциональная фаза по сохранённой приёмке — **Phase 10:
Portfolio Suggestions**. Phase 0–6 и 8–10 отмечены завершёнными в основном roadmap;
Google/reset/iOS приёмка Phase 7 остаётся открытой. Следующая запланированная
фаза — **Phase 11: Media**, она не начата в этой инициативе.

Эти отметки сверены с актуальным roadmap и source, но R0 не повторяет прежние
Flutter tests, native launch или live Firebase-проверки. Их прежние результаты
не доказывают готовность нового дизайна или новых продуктовых функций.

По историческому поручению D001 основная разработка новых функций была приостановлена.
Первоначально возвращение предлагалось после пользовательской приёмки R9 и
`REDESIGN_DONE`, с сохранённой точкой «перед Phase 11» и открытой приёмкой Phase 7.
Это историческая точка остановки: D043/D044 разрешили Media/Location, D045/D046
разрешили нынешние mobile capabilities. Полный REDESIGN_DONE остаётся отдельной
приёмкой; он не блокирует уже разрешённую функциональную работу.

В [audit](audit.md#продуктовые-пробелы) отмечены зависимости, без которых часть
Design v2 нельзя честно реализовать. Перед R8 пользователь согласует отдельные
продуктовые предпосылки либо явно ограничивает scope переноса; автоматического
возобновления roadmap ради макетов нет.

---

## Актуальная версия

Порядок требований: последнее задание Design v2 → последующие явно согласованные
решения → совместимая существующая документация → прежние макеты как справочник функций.
[requirements.md](requirements.md) фиксирует новое задание, [plan.md](plan.md#журнал-решений)
фиксирует согласования. Ни создание файла, ни screenshot не означают приёмку.

Документы [docs/design](../design/redesign-plan.md) и прежние Figma-экраны сохранены
как история. Их greeting/quick-access carousel, фильтры Projects, recolor старого
знака S и обязательный декоративный artwork не являются требованиями Design v2.
Существующие lime-цвета сохраняются по новому заданию; бренд A выбран D024.

Созданы отдельные страницы Figma
[StackCard Design v2 / UX](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=58-7)
и [StackCard Design v2 / Directions](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=99-8),
а также [StackCard Design v2 / DS](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=123-7).
Старые девять страниц и компоненты сохранены. Реальные IDs новых артефактов
добавляются в screens вместе со статусом приёмки; awaiting_review не означает
финальный принятый frame. Типографика схемы не является выбором шрифта для R2/R3.

---

## Как продолжать

Сначала прочитать этот README, [plan.md](plan.md) и
[текущий product scope](../product/product-spec.md#статус-и-границы-текущей-работы).
Последнее поручение D048 разрешает mobile/web/publication, compatible private
migration и trusted lifecycle без повторного phase approval. Existing contracts
описаны в [architecture](../architecture/architecture.md#общая-база-и-независимые-документы);
[prerequisites](prerequisites.md) показывает реализованный subset и remaining
remaining requirements и actual D048 source. Работа ведётся по проверяемым capabilities.

Результаты D040/D041/R9-supported остаются историческими; проверки новой модели
фиксируются по фактам в product spec. R7 awaiting_review/DESIGN_READY pending,
полная R8/R9/public web/security/native visual parity и итоговая пользовательская
приёмка ещё открыты. D048 preview/browser/native checks разрешены последующим
явным ответом пользователя; historical skip evidence сохраняется. Commit/push/deploy не выполнены
последним поручением; D042 относится к прежней Git delivery.
