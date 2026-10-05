<div align="center">

# StackCard Design v2

**Отдельная инициатива полного редизайна mobile, web и публичных документов**

![Phase R3](https://raster.shields.io/badge/Phase-R3-C7FF1A?style=for-the-badge)
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

StackCard создаёт разные структурированные Resume и публичные Portfolio из
общей профессиональной базы DeveloperProfile и библиотеки Project. Design v2
перепроектирует визуальную систему и сценарии, сохраняя бизнес-логику, данные,
интеграции и Material 3 как техническую основу Flutter.

На **2026-10-05** активна **R3: дизайн-система**, текущая задача **R3.4**.
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
поручением продолжить. **R3.4 — `awaiting_review`**, D033: states/motion/adaptive
собраны и проверены. Добавлены2sets/18variants и10Dark/Light fixtures; четыре
агента подготовили независимые части, ведущий интегрировал Figma последовательно.
Постоянный адрес каждого документа принят D019; реализация URL-контракта предстоит.

| **Состояние** | **Что подтверждено** |
|:---|:---|
| Аудит и план | R0 принята поручением начать R1; исходные результаты и ограничения сохранены в audit/references |
| IA Design v2 | [Navigation, ownership и lifecycle](screens.md#r11--информационная-архитектура); R1.1 принята поручением продолжить, D013 |
| Low-fi Design v2 | [24 экрана R1.2](screens.md#r12--low-fi-основных-сценариев), [24 экрана R1.3](screens.md#r13--low-fi-resume-wizard-и-редактора) и [40 экранов R1.4](screens.md#r14--low-fi-projects-portfolio-и-публикации) приняты. Всего 88 phone frames, цветовые правки D020 проверены |
| Визуальные макеты Design v2 | [Бренд A](screens.md#r23--принятый-бренд-и-направление) принят D024; R3.1 done D028, Manrope. [Navigation/cards/badges R3.2](screens.md#r32--навигация-карточки-и-technologybadge) приняты D030; [Forms/stepper/photo/sections R3.3](screens.md#r33--формы-stepper-фото-и-секции) приняты D032; [States/motion/adaptive R3.4](screens.md#r34--состояния-motion-и-адаптивность) проверены, awaiting_review D033; экраны R4–R6 ещё не начаты |
| Интерактивный прототип Design v2 | Не создан; отдельный результат R7 |
| Реализованный Design v2 UI | Не перенесён; отдельное разрешение R8 после DESIGN_READY |
| Backend новых сценариев | Не реализован этим заданием; пробелы и зависимости зафиксированы отдельно |

---

## Документы

- [requirements.md](requirements.md) — требования с ID, запреты, модель продукта и прослеживаемость.
- [audit.md](audit.md) — фактические routes/source/Figma, расхождения и продуктовые пробелы.
- [references.md](references.md) — изученные источники, конкретные компоненты, применимые приёмы и условия переноса.
- [plan.md](plan.md) — главный поэтапный план R0–R9, задачи, проверки, зависимости и журнал решений.
- [screens.md](screens.md) — текущие и предлагаемые экраны, переходы, состояния и компоненты.

Основной продуктовый roadmap остаётся в
[product-spec.md](../product/product-spec.md#план-разработки), устройство действующей
системы — в [architecture.md](../architecture/architecture.md).

---

## Остановка основной разработки

Последняя завершённая функциональная фаза по сохранённой приёмке — **Phase 10:
Portfolio Suggestions**. Phase 0–6 и 8–10 отмечены завершёнными в основном roadmap;
Google/reset/iOS приёмка Phase 7 остаётся открытой. Следующая запланированная
фаза — **Phase 11: Media**, она не начата в этой инициативе.

Эти отметки сверены с актуальным roadmap и source, но R0 не повторяет прежние
Flutter tests, native launch или live Firebase-проверки. Их прежние результаты
не доказывают готовность нового дизайна или новых продуктовых функций.

Основная разработка новых функций приостановлена по прямому запросу пользователя.
Возвращение предлагается только после пользовательской приёмки R9 и
`REDESIGN_DONE`, с сохранённой точкой «перед Phase 11» и открытой приёмкой Phase 7.
Переход к продуктовой задаче требует отдельного поручения.

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

При следующем запросе сначала прочитать этот README и [plan.md](plan.md).
Одновременно активна одна фаза и одна согласованная задача; продолжать с первой
незавершённой, сохраняя предыдущие решения и evidence.

Текущая точка приёмки — **R3.4: состояния, motion и адаптивность**, полная DS.
[Состояния данных](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2036),
[Save/Sync/Publish](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2110),
[motion/reduced](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2214)
и [адаптивные образцы](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=176-2418)
собраны из shared components и прежних tokens. StatePanel5/LifecycleStatus13
разделяют dirty/local Save/server ACK/explicit Publish; ошибка или неизвестный
результат не получают ложного success. Save/Отмена закреплены над bottom tabs.

Проверены10Dark/Light fixtures:320,390,430,768 и844landscape, cap600, ru/en/URL
wrapping. Шесть motion событий180/240/280ms имеют static0ms reduced equivalents
с тем же feedback. Playable prototype — R7.3, native/runtime — R8.
Audit393text nodes/786mode samples:minimum4.833:1;342interactive strokes:
minimum4.365:1;96targets≥48×48. Bounds/overlaps/references/bindings/scopes
failures0; итоговые renders просмотрены.98variables/50styles сохранены;
единственная правка прежних values — motion/slow300→280, палитра/Wordmark A прежние.

R3.1–R3.3 done. После приёмки R3.4 следующая отдельная задача — **R4.1**.
Независимые части дизайна продолжаются несколькими агентами; Figma writes
интегрирует ведущий последовательно. Полные экраны и финальный DESIGN_READY
остаются будущими результатами.
Low-fi сохраняют горизонтальные кнопки и поиск с лупой без заголовка.
Политика URL принята D019; точная route scheme и миграция adapter остаются
предпосылкой R8. DESIGN_READY/REDESIGN_DONE не установлены; runtime/backend
и основная функциональная разработка остаются на прежней точке.
