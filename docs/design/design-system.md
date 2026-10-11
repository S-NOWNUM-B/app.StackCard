<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../apps/web/public/branding/stackcard-v2-mark-paper.svg">
  <img src="../../apps/web/public/branding/stackcard-v2-mark-ink.svg" width="64" height="64" alt="Логотип StackCard — Brand A">
</picture>

# StackCard Design

**Действующий shared UI contract R8 и история визуального target от 2026-10-04**

![Design partial runtime](https://img.shields.io/badge/Design-partial_runtime-111111?style=for-the-badge)
![Light UI](https://img.shields.io/badge/UI-light_only-ffffff?style=for-the-badge)

</div>

---

Этот guide описывает действующий shared Flutter UI после независимого R8
переноса D040; разделы1–9 ниже сохраняют **исторический target2026-10-04**.
Актуальные требования — [Design v2](../redesign/requirements.md), scope/acceptance —
[план](../redesign/plan.md). R3 DS/Manrope приняты; Brand A выбран D024.
Shared theme/controls/assets перенесены D040. Функциональный mobile scope
2026-10-07 был заменён [ADR 0005](../decisions/0005-single-main-portfolio.md):
три stateful roots, saved portfolio Home и единый вертикальный Editor.
Legacy Builder/resumeText сохранены для совместимости. D048 (2026-10-08)
добавляет mobile privacy/attachments/publication и Next.js owner/public surfaces;
контракты/remaining acceptance — в [prerequisites](../redesign/prerequisites.md);
R7 source QA PASS D041/awaiting_review,
DESIGN_READY/REDESIGN_DONE не установлены. Старые recolor S/DM Sans/greeting/
categories/artwork требования не переопределяют Design v2.

## Содержание

- [Действующий runtime contract R8](#действующий-runtime-contract-r8)
- [Монохромный бренд](#монохромный-бренд)
- [1. Visual Theme & Atmosphere](#1-visual-theme--atmosphere)
- [2. Color](#2-color)
- [3. Typography](#3-typography)
- [4. Spacing & Grid](#4-spacing--grid)
- [5. Layout & Composition](#5-layout--composition)
- [6. Components](#6-components)
- [7. Motion & Interaction](#7-motion--interaction)
- [8. Voice & Brand](#8-voice--brand)
- [9. Anti-patterns](#9-anti-patterns)

---

## Действующий runtime contract R8

Функциональный контракт ADR 0005: «Главная / Проекты / Редактор», gear рядом
с StackCard. На главной ровно два постоянных действия «Скачать портфолио» и
«Поделиться», затем сохранённый профиль и только непустые разделы.
«Поделиться» использует чёрную заливку primary. Действия Projects
«Импортировать»/«Создать» заполняют доступную ширину по той же адаптивной
компоновке, что и Home: равные колонки либо полная ширина в вертикальном списке.
При скачивании PDF кнопка и её надпись сохраняют размеры и положение без
индикатора загрузки; повторное нажатие блокируется до завершения операции. Avatar128
центрирован; в Editor маленький pencil открывает Gallery/Camera/Remove menu.
Library/портфолио/PDF показывают stock icon и текст проекта, без project photos,
обложек, метрик и действий публикации на строке. Выбор catalog icon — простая grid.
В mobile Library красный минус удаления находится справа сверху; нажатие
открывает «Удалить проект?» с действиями «Отмена» и «Подтвердить».
«Редактировать» стоит справа снизу на белой поверхности с чёрной обводкой:
shared StackCardButtonRole.outlined использует surface/primaryOutline и сохраняет
keyboard/focus/disabled/loading states. Область нажатия минуса — минимум48.
В форме проекта иконка128 центрирована над полями, pencil открывает выбор
так же, как у avatar; отдельного предпросмотра карточки в форме нет.
Технологии редактируются по одной: «+» открывает короткое поле с кнопками
«Отмена» и «Сохранить», крестик внутри тега удаляет запись из формы.
Изменения сохраняются общим Save; отмена добавления не меняет список.
Дубли новых названий и лимиты20/60 валидируются.
Навыки основного портфолио используют тот же компонент тегов и окно добавления;
название обязательно, до60 символов, без новых повторов. Исходные записи и ID
сохраняются. Контакты и ссылки используют тот же компонент тегов с «+»;
иконка определяется выбранной категорией, нажатие на название открывает
редактирование, крестик удаляет контакт из буфера. В окне добавления
«Отмена» слева, «Сохранить» справа как при добавлении, так и при редактировании.
Home показывает иконку и категорию над подчёркнутым названием пользователя,
которое открывает сохранённый адрес; raw URL не выводится. Категории располагаются
адаптивными колонками, скрытые/private контакты исключены.
После контактов/ссылок идут «Навыки», «Реализованные проекты»,
«Опыт работы», «Образование». Mobile поля проекта используют тот же
StackCardInput с плавающим label внутри рамки, что и основной редактор.
Опыт работы и образование добавляются через «+» в заголовке; записи сохраняют
редактирование, крестик удаляет их из буфера. Окна записей используют стандартные
«Отмена» слева и «Сохранить» справа, с переносом кнопок при крупном тексте.
На главной профиль идёт в порядке имя/должность/город/описание; описание
занимает ширину блока и выравнивается по левому краю.
Editor — вертикальные группы optional полей и явный Save; ни grid/CSS/colors,
ни библиотек Resume/Portfolio в повседневном UI. Город/страна вводятся вручную.
В mobile персонализации город/страна находятся под должностью на втором шаге;
третий шаг «О себе» содержит только краткое описание.
Mobile персонализация содержит только «Назад» и «Далее» в одной строке
(последний шаг — «Завершить»); на первом шаге «Назад» отключена.
«Далее» допускает пустые optional поля, отдельной кнопки «Пропустить» нет.
Поле «GitHub-профиль» принимает имя пользователя или HTTPS-ссылку на профиль;
ошибка перепроверяется при редактировании.
Действия диалогов и форм сгруппированы справа: «Отмена» слева с чёрной
обводкой, основное действие справа с чёрной заливкой. На узком экране кнопки
переносятся с тем же порядком чтения и focus; основное действие остаётся последним.
Подписи едины по смыслу: «Сохранить» для форм добавления и редактирования, «Подтвердить» для
подтверждения операции, «Закрыть» для просмотра, «Завершить» для окончания
персонализации. «Готово», «Хорошо» и «ОК» не используются как взаимозаменяемые
названия этих действий. Выбор из нескольких операций сохраняет конкретные
глаголы; в окне несохранённых изменений порядок «Отмена / Не сохранять / Сохранить».
Mobile использует shared `StackCardDialogActions` и `common.*` localization;
web — `.dialog-actions` и `confirmation-dialog.tsx`. Системный browser prompt
при закрытии вкладки остаётся под управлением браузера.
Горизонтальный отступ16, ритм8/12/16/24, controls48/input56, content max600;
320px/text2/keyboard проверяются по настоящим экранам. Старый D048 layout ниже
сохраняется как история и не переопределяет этот контракт.

[StackCardColors](../../apps/mobile/lib/core/theme/stackcard_colors.dart),
[StackCardTheme](../../apps/mobile/lib/core/theme/stackcard_theme.dart) и
[tokens](../../apps/mobile/lib/core/theme/stackcard_tokens.dart) остаются единым
source для Material3 и shared widgets. После одобрения web 2026-10-11
Flutter использует только light: белый фон, нейтральные поверхности, чёрный
`primary` и белый `onPrimary`; error/destructive отделены от brand.
Legacy `StackCardTheme.dark`/`StackCardColors.dark` — совместимые aliases к light,
отдельной тёмной палитры нет. Manrope, original SVG и лицензии сохранены. Важный текст получает
textPrimary/textSecondary/textMeta; accentText/successText и controlOutline/
primaryOutline/focus проверяются по реальной поверхности и состоянию. Цвета
брендов технологий не превращаются в цвета UI действий.

Manrope400/600/700/800 — живой UI font с Noto Sans fallback; регистрация/
исходные TTF/OFL в [pubspec](../../apps/mobile/pubspec.yaml) и [manifest](../../apps/mobile/assets/design_v2/source-manifest.json).
Оригинальный outlined Wordmark A сохраняет Noto ExtraBold36/44 source geometry:
[StackCardBrand](../../apps/mobile/lib/shared/widgets/stackcard_brand.dart)
выбирает один Wordmark (уже содержит Mark) либо compact Mark, contain/no tint/
no дублирующий Text. Текущий light runtime выбирает original ink variant;
Auth использует `trimWordmarkPadding`: viewport убирает пустое правое поле,
оптически центрируя original paths без изменения SVG bytes и пропорций.
исторический paper variant сохранён в исходных assets.9BrandA SVG импортированы.
D048 экспортировал Accent AppIcon; поручение 2026-10-11 заменяет его на
original MonoDark: светлый знак на чёрном фоне. Pinned source из действующего
[brand kit](../../assets/branding/stackcard-v2-brand-kit.json) экспортируется в Android mipmaps и iOS
AppIcon set: 5 Android + 15 iOS PNG. Source geometry/fills/bytes не меняются;
iOS transparent corners flattened на исходный #070708 и RGB без alpha.
[Generator](../../tools/redesign/export_native_icons.mjs) и
[ledger](../redesign/source/native-app-icons.json) фиксируют source/output SHA,
размеры и преобразование. D048 exact check20 PNG и Android debug build PASS;
Current Home/Resume editor/Share screenshots просмотрены; Project/Contacts
Dark-Light screenshots промежуточные до последних label/helper/counter правок.
Full device/icon/Figma acceptance и iOS runtime отдельно; actual evidence — в
[product checks](../product/product-spec.md#проверки-d048--2026-10-08).

[StackCardIcon](../../apps/mobile/lib/shared/widgets/stackcard_icon.dart)
загружает pinned Lucide/technology SVG; tint применим только к monochrome Lucide.
React/TypeScript получают зафиксированные brand fills, Flutter/Dart — source
fills. Отдельный CSS-inline Flutter derivative сохраняет canonical white/.72
opacity/polygon geometry; raw original не менять. [TechnologyBadge](../../apps/mobile/lib/shared/widgets/stackcard_technology_badge.dart)
использует живой Text/полный wrap; неизвестное название остаётся полным,
+N открывает реальный список.40canonical records +1explicit derivative имеют
SHA/provenance; portable [check_imports](../../tools/redesign/check_imports.py)
проверяет источники независимо от headless SVG paint tests. Одобренные light
runtime overrides палитры и `headlineLarge` зафиксированы в прежнем manifest;
исторические Figma IDs/values и исходные bytes сохраняются.

Controls используют внешний tap target≥48, input height56 и content max600;
focus/loading/disabled/error сохраняют доступное имя и input. Timing constants
180/240/280ms существуют в StackCardMotion. D048 добавляет persisted
`AppSettings.reducedMotion` в прежний SharedPreferences snapshot: runtime
объединяет его с OS `MediaQuery.disableAnimations`, nav duration становится zero.
Web сочетает `prefers-reduced-motion` с local preference из Account settings;
prototype/native playback отдельно.
Исторический D048 shell сохранял bottom navigation на phone/tablet и четыре roots
Home/Resumes/Projects/Portfolios с постоянными labels. Settings открывается gear;
редакторы/appearance/account standalone. Home — mixed library с тремя фильтрами,
без readiness dashboard. Projects — Import/Create/Search/List, query-only без
categories; GitHub Import filter contract отдельно. Resume/Portfolio roots —
private libraries, с настоящими create/edit/duplicate/delete actions.
Resume creation использует пять шагов, затем focused section editing; private
preview использует существующий content renderer/theme. Saved private documents
используют real publication inventory; Copy/Open/Share доступны только для
confirmed published URL `/d/<publicId>`. Configuration/unknown/guest не выдают
фиктивную ссылку или success. Это функциональный source slice;
полная Figma/native visual parity не подтверждена.

Mobile copy после поручения 2026-10-11: короткие названия, действия и состояния
без постоянных поясняющих абзацев. Empty state содержит один заголовок; optional
message в `StackCardStateView` выводится только при необходимости. Не показывать
служебные сведения о demo, Firebase tests, будущих этапах или реализации offline.
Не повторять label внутри пустого поля и состояние отсутствующего фото рядом
с каждым действием. Ошибки, причины disabled actions, несохранённые изменения,
подтверждения удаления и последствия публикации сохраняют понятный короткий текст.
Постоянные format/limit подсказки заменяются validation или сообщением при
достижении лимита. Runtime интерфейс русский; сохранённые переводы ru/en следуют одному правилу
и остаются совместимыми для компонентных проверок.

Mobile Settings использует общий `SettingsEditorScaffold`: строки меню от 64dp,
иконки 24dp, единые отступы и разделители. После списка настроек — горизонтальная
линия толщиной 1dp по ширине содержимого в отступе 16dp, затем строка аккаунта
с именем (или email), действием справа и меткой Google только для подключённого
Google provider. «Выйти» — красный текст без фона, обводки и карточки;
компактная иконка также красная. Без сессии строка показывает
нейтральный «Аккаунт» и вход; гостевых подписей и переноса черновика нет. Удаление
доступно только в «Аккаунт и безопасность» через существующее подтверждение;
у гостя его нет. Меню в строке аккаунта отсутствует. Выход расположен только
в строке аккаунта основных настроек и не дублируется в разделе безопасности.
При узком экране или увеличенном шрифте действия становятся иконками с tooltip,
а длинное имя ограничивается двумя строками без вытеснения кнопок.

Web tokens/shared controls находятся в `apps/web/src/app/globals.css` и
`src/components/ui.tsx`, original Manrope/Brand A — в `apps/web/public`.
Поручение 2026-10-11 переопределяет web target R6:
[светлый StackCard по Openship](../redesign/web-openship.md), белые поверхности,
чёрные CTA, овальная навигация и крупная редакционная типографика. Русский контент
описывает StackCard. Web не предлагает dark и показывает старые документы в light
без изменения shared `dark | light` schema. React не импортирует Flutter runtime.
Пользователь одобрил web и поручил перенести этот референс в Flutter.
Runtime mobile всегда light/ru; theme/language selectors удалены, legacy
preferences читаются без перезаписи. PortfolioTheme dark/light остаётся
в data contract, но оба preview используют light. Home получает редакционный
заголовок, Shell — брендированную овальную навигацию, библиотеки — тонкие
разделители и крупную типографику. При компактной высоте заголовок помещается
в header рядом с compact Brand A; text scaling и targets48 сохраняются. Wide/narrow,
focus и states проверяются в браузере отдельно от contract tests/build;
пользовательская приёмка и live сценарии остаются отдельными результатами.

Исторический supported UI результат D040:950headless tests PASS/analyze0issues,
Dark/Light,ru/en,scale1/2,7viewports включая320×568/568×320;32runtime SVGdecoded,
0unsupported warnings. Это engine/widget evidence. Visual preview/playback/
native launch/goldens пропущены по запросу, поэтому native font/SVG/AppIcon и
полная Figma/native visual parity остаются непроверенными. Подробные
[результаты R8/R9](../redesign/plan.md#фактический-перенос-поддерживаемого-ui-r8r9-d040)
не означают полный REDESIGN_DONE или backend новых сценариев.

Следующие разделы1–9 — исторический target2026-10-04; при конфликте применяются
актуальные requirements и текущий shared contract выше.

---

## Монохромный бренд

Действующий [Brand A kit](../../assets/branding/stackcard-v2-brand-kit.json)
задаёт выбор оригинальных SVG: Ink mark/wordmark на светлой поверхности,
Paper на тёмной, MonoDark для системной иконки Android/iOS и favicon сайта.
Ink `#070708` и Paper `#F4F5F7` — исходные цвета знака; UI использует свои
существующие нейтральные tokens. Написание StackCard остаётся original outlined
Wordmark A, интерфейс — Manrope. Не перекрашивать и не перерисовывать геометрию.

Лаймовые Accent SVG и прежний Link kit сохраняются как исторические источники;
новые runtime placements их не используют. Цвета технологий и semantic
success/error/warning не относятся к брендовой палитре. Android `application`
label и iOS display name — `StackCard`: системные окна входа и launcher
получают имя и иконку из установленной сборки. Обновление этих assets требует
новой установки поверх приложения; hot reload не меняет package resources.
Android LaunchTheme/NormalTheme остаются светлыми при любой системной теме.

## 1. Visual Theme & Atmosphere

StackCard управляет developer identity: один базовый профиль и библиотека
проектов дают несколько Resumes и Portfolios. Внутренний UI помогает создавать,
редактировать и делиться; публичное Portfolio допускает более выразительный
showcase, чем editor.

Характер создают крупная typography, чёткая сетка, редакционная композиция,
технические подписи и геометрический artwork. Neutral surfaces занимают
основную площадь; neon выделяет действия и небольшие visual accents.
Ориентир — 80–85% neutral, 10–15% typography/borders и 5–10% accent;
это композиционный ориентир, а не обязательная формула каждого экрана.

Home, Resume, Project и Portfolio имеют разную композицию. Artwork использует
reusable ribbons, wireframe curves, generative lines, grids и dither textures.
Декорация не перекрывает controls и исключается из screen-reader semantics.
[Openship](https://openship.io/) — benchmark typography/rhythm/grids/product demos;
[21st.dev](https://21st.dev/) — источник адаптируемых patterns и motion ideas.
Точные страницы и layouts не копируются.

---

## 2. Color

Таблица — **целевые** semantic roles Figma. При последующей реализации
расширяем [StackCardColors](../../apps/mobile/lib/core/theme/stackcard_colors.dart)
и [StackCardTheme](../../apps/mobile/lib/core/theme/stackcard_theme.dart),
не создаём вторую runtime palette. Значения текущего Flutter пока отличаются.

| Роль | Dark target | Light target | Назначение |
| --- | --- | --- | --- |
| background | #070708 | #F5F5F6 | Основная поверхность |
| surface | #0D0E11 | #FFFFFF | Панели и sheets |
| surfaceElevated | #14161B | #FAFAFA | Inputs и elevated content |
| surfaceActive | #1B1E24 | #EFEFF1 | Neutral active/pressed |
| border | #272A32 | #DEDEE3 | Разделители и controls |
| borderStrong | #373B46 | #B8BBC4 | Усиленная граница |
| textPrimary | #F4F5F7 | #18181B | Основной текст |
| textSecondary | #A4A8B3 | #52525B | Вторичный текст |
| textMuted | #737884 | #676C77 | Необязательная metadata; contrast проверять по месту |
| primary / acid | #C7FF1A | #C7FF1A | Основные действия и navigation selection |
| onPrimary / ink | #070708 | #070708 | Text/icons на neon |
| cyan | #6FE7F2 | #6FE7F2 | Project/source artwork |
| sourceText | #6FE7F2 | #0B6570 | Читаемые GitHub/source labels |
| pink | #FF6AB2 | #FF6AB2 | Portfolio/showcase artwork |
| violet, optional | #9B7BFF | #9B7BFF | Возможное расширение; variable пока не создана |
| paper | #F4F5F7 | #F4F5F7 | CV-thumbnail с ink, независимо от темы |
| focus | #C7FF1A | #526B00 | Focus indicator, различимый на поверхности |
| success | #41E68A | #168449 | Подтверждённый успех + icon/label |
| warning | #FFD166 | #996000 | Предупреждение + пояснение |
| error / destructive | #F06272 | #C92D45 | Семантика ошибок, не brand |

Light сохраняет нейтральную основу существующей темы. Lime/cyan/pink на светлом
фоне используются как fill с ink, не как мелкий text. Muted text не применяется
для важных инструкций. Selected/error/offline/success различаются также label,
icon или формой. Не использовать все supporting accents на каждом экране.

В существующей Figma collection роль `surfaceActive` сохраняет variable name
`color/surfaceHover`, чтобы не ломать bindings. `sourceText` отделён от artwork:
яркий cyan не используется для мелкого текста на светлом фоне. Проверенный
контраст primary/ink — 17.02:1; sourceText/background — 13.80:1 dark и 6.20:1 light.
Полная проверка каждого состояния и соседней поверхности остаётся в QA.

Signal Red удаляется из **целевого brand**, включая logo accent и CTA.
Геометрию сохраняем и recolor в lime в Figma. Оригиналы
[brand kit](../../assets/branding/stackcard-link-brand-kit.json) и SVG остаются
архивным источником; runtime assets этой итерацией не заменяются.
Нужны dark/light/monochrome logo и app icon.

---

## 3. Typography

**DM Sans** для UI/display и **Noto Sans** для fallback, включая кириллицу,
сохраняются: fonts/licenses уже зарегистрированы в [pubspec](../../apps/mobile/pubspec.yaml).
Характер усиливается hierarchy, leading/tracking и композицией. IBM Plex Mono
используется для metadata: наличие DM Sans, Noto Sans и IBM Plex Mono проверено
через Figma API. IBM Plex Mono не считается подключённым к Flutter.

| Роль | Размер / line height | Правило |
| --- | --- | --- |
| Display | 40–56 / 40–58 | Короткие root headings, предусмотренные переносы |
| Heading | 24–32 / 28–36 | Detail, sections и cards |
| Title | 18–20 / 24–28 | Названия сущностей и controls |
| Body | 14–16 / 20–24 | Читаемый neutral text |
| Label / metadata | 12–14 / 16–20 | Короткие подписи; mono выборочно |

Oversized headings не уменьшают body. Uppercase уместен для короткого
`01 / PROJECTS`, а не длинных русских абзацев. Text scaling не блокируется;
long names, multiline descriptions и ru/en входят в layout checks.

---

## 4. Spacing & Grid

Основной target — **390 px**. Phone gutter — **20 px**; spacing —
4, 8, 12, 16, 20, 24, 32, 48. Radius — 8, 12, 16, 24; capsule применяется
к действиям осмысленно. Interactive target — минимум **48×48 px**, включая
settings icon и Copy action.

Большие экраны сохраняют IA и bottom navigation. Контент центрируется с
max-width **600 px** и увеличенными внешними отступами; две колонки допустимы
для естественных списков/selectors. Отдельная sidebar/tablet navigation не
вводится. Landscape/smaller phones остаются scrollable и keyboard-safe.
Existing [runtime tokens](../../apps/mobile/lib/core/theme/stackcard_tokens.dart)
служат точкой последующего переноса; новый gutter пока является target.

---

## 5. Layout & Composition

Root tabs: **Home / Resumes / Projects / Portfolios**. Все labels видны постоянно;
large text не превращает nav в icon-only. Settings открывается компактной
кнопкой каждого root; Logout находится в Settings / Account. Повторяющийся
StackCard/Demo header удаляется из target. Nested screens сохраняют compact
contextual Back и platform gesture. Tab switch отличается от nested navigation.

| Экран | Целевая композиция |
| --- | --- |
| Home | Короткое greeting, quick-access rail, Recent / Continue, GitHub changes при наличии |
| Resumes | Contextual heading, Create, список с role/date/status/preview и постоянным Copy/Open |
| Projects | Import/Create, Search, All/GitHub/Manual, source/usage; без Featured filter |
| Portfolios | Список именованных outputs с project count/status/URL и Copy/Open |
| Settings | Account, connections, social, base profile, appearance, privacy, notifications, session |
| Editor | Compact back/title, focused sections, Saved/Saving либо доступный Save |
| Portfolio Builder | Name/status, mini-preview, section rows/reorder, appearance/publishing |
| Auth | Logo, heading и текстовые действия по центру; вся форма центрируется по вертикали, при keyboard/overflow прокручивается; текст полей слева, matte controls |

Copy Link постоянно доступен у published Resume/Portfolio. Draft показывает
Draft и Edit/Preview, не выдаёт несуществующую ссылку за публичную. Detail содержит
Share/Open in browser. Stepper применяется в creation flow; completion percentage
не возвращается на Home. [Navigation map](redesign-plan.md#navigation-map) задаёт переходы.

---

## 6. Components

Figma использует Auto Layout, semantic variables и variants `state`, `size`,
`theme`, `selected`, `disabled`, `loading` по необходимости. Layer names
объясняют назначение; instances сохраняют связь с masters.

| Группа | Компоненты и контракт |
| --- | --- |
| Actions | Button, IconButton, SettingsButton, CopyLinkButton, ShareButton; normal/pressed/focus/disabled/loading |
| Input | Input, Textarea, SearchInput; label/hint/value/error, keyboard-safe layout |
| Selection | Chip, FilterChip, selected rows; выбор виден без одного цвета |
| Navigation | BottomNavigation с четырьмя labels, SectionHeader, compact nested back |
| Entities | ProjectCard, ResumeCard, PortfolioCard, SocialLink; разная композиция сущностей |
| Flow | Stepper, ProgressStep, CarouselItem; progress текущего процесса |
| Feedback | Status, Toast/Snackbar, Modal/BottomSheet; Copy success, delete confirmation |
| States | EmptyState, ErrorState, LoadingSkeleton; offline/denied/photo/long content |
| Artwork | Reusable ribbon/wire/grid primitives вместо detached duplicates |

Первый набор создаётся под пять key screens. Остальные components расширяются
по core flows; перечень не означает, что все masters уже готовы. Offline
отличается от local save failure, Saved — от Synced. Ошибка сохраняет input,
показывает причину и Retry. Validation находится у поля; snackbar её не заменяет.

При переносе расширяем [shared widgets](../../apps/mobile/lib/shared/widgets).
Card/Poster/Artwork, Button/Input и AsyncView/StateView — existing integration
points, не повод создавать вторую UI library. Source review, UID isolation,
private notes и recovery сохраняют семантику.

---

## 7. Motion & Interaction

Motion следует стабильному layout: обычные transitions **180–300 ms**.
Намеренные варианты — page/back, press feedback, navigation indicator,
card expand, stepper, carousel snap, copy confirmation и publish transition.
Spring допустим для indicator/cards/bottom actions, если не блокирует действия.

Reduced motion отключает decorative reveal/parallax/stagger, сохраняя feedback.
Continuous heavy animations, looping glow и long blocking transitions запрещены.
Motion variables 180/240/300 ms созданы в Figma; key navigation prototype
использует dissolve 180 ms. Native implementation и остальные interactions
вводятся на соответствующем шаге.
Web допускает restrained reveal/background effects с performance/focus/reduced
motion; библиотека выбирается при implementation по реальному стеку.

---

## 8. Voice & Brand

Тон короткий, прямой и developer-oriented. Metadata задаёт ритм, не имитирует
terminal. UI ru/en остаётся в [localization](../../apps/mobile/lib/core/localization);
source content не переводится. Empty Projects предлагает Import GitHub/Create;
empty outputs — Create. Постоянного давления «доделай профиль» нет.

Demo/draft/public/cached/offline/unsaved/sync failures различимы. GitHub suggestions
остаются deterministic с причиной и решением владельца. AI chat/badges и
центральная AI-generation feature не добавляются.

---

## 9. Anti-patterns

Не принимать generic Material/CRUD dashboard, одинаковые cards, outlined-button-heavy
Builder, RGB/glow overload, stock photography, glass на всех surfaces,
бесцельные пустые web sections или набор 21st components без системы.
Не кодировать state одним цветом и не делать body neon; hover не mobile interaction.

Нужны full/empty/loading/error/offline, long content, contrast, logical focus,
screen-reader semantics, targets, keyboard web navigation и reduced motion.
Первые full-data screens не закрывают core flows/state QA. Фактическая Figma-приёмка
и pending checks — в [plan](redesign-plan.md#приёмка). Flutter tests/native run
относятся к последующей реализации; результаты старого UI не доказывают target.
