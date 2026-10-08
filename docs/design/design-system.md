<div align="center">

# StackCard Design

**Действующий shared UI contract R8 и история визуального target от 2026-10-04**

![Design partial runtime](https://raster.shields.io/badge/Design-partial_runtime-111111?style=for-the-badge)
![Accent Acid Lime](https://raster.shields.io/badge/Accent-Acid_Lime-C7FF1A?style=for-the-badge)

</div>

---

Этот guide описывает действующий shared Flutter UI после независимого R8
переноса D040; разделы1–9 ниже сохраняют **исторический target2026-10-04**.
Актуальные требования — [Design v2](../redesign/requirements.md), scope/acceptance —
[план](../redesign/plan.md). R3 DS/Manrope приняты; Brand A выбран D024.
Shared theme/controls/assets перенесены D040. Функциональный mobile scope
2026-10-07 использует четыре stateful roots, смешанную Home library,
независимые Resume/Portfolio и секционные редакторы с прежними shared controls.
Legacy Builder/resumeText сохранены для совместимости. D048 (2026-10-08)
добавляет mobile privacy/attachments/publication и Next.js owner/public surfaces;
контракты/remaining acceptance — в [prerequisites](../redesign/prerequisites.md);
R7 source QA PASS D041/awaiting_review,
DESIGN_READY/REDESIGN_DONE не установлены. Старые recolor S/DM Sans/greeting/
categories/artwork требования не переопределяют Design v2.

## Содержание

- [Действующий runtime contract R8](#действующий-runtime-contract-r8)
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

[StackCardColors](../../apps/mobile/lib/core/theme/stackcard_colors.dart),
[StackCardTheme](../../apps/mobile/lib/core/theme/stackcard_theme.dart) и
[tokens](../../apps/mobile/lib/core/theme/stackcard_tokens.dart) остаются единым
source для Material3 и shared widgets. Dark/Light используют semantic Lime/ink
`primary/onPrimary`; error/destructive отделены от brand. Важный текст получает
textPrimary/textSecondary/textMeta; accentText/successText и controlOutline/
primaryOutline/focus проверяются по реальной поверхности и состоянию. Цвета
брендов технологий не превращаются в цвета UI действий.

Manrope400/600/700/800 — живой UI font с Noto Sans fallback; регистрация/
исходные TTF/OFL в [pubspec](../../apps/mobile/pubspec.yaml) и [manifest](../../apps/mobile/assets/design_v2/source-manifest.json).
Оригинальный outlined Wordmark A сохраняет Noto ExtraBold36/44 source geometry:
[StackCardBrand](../../apps/mobile/lib/shared/widgets/stackcard_brand.dart)
выбирает один Wordmark (уже содержит Mark) либо compact Mark, Dark paper/
Light ink, contain/no tint/no дублирующий Text.9BrandA SVG импортированы.
D048 экспортирует pinned AppIcon source в existing Android mipmaps и iOS
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
проверяет источники независимо от headless SVG paint tests.

Controls используют внешний tap target≥48, input height56 и content max600;
focus/loading/disabled/error сохраняют доступное имя и input. Timing constants
180/240/280ms существуют в StackCardMotion. D048 добавляет persisted
`AppSettings.reducedMotion` в прежний SharedPreferences snapshot: runtime
объединяет его с OS `MediaQuery.disableAnimations`, nav duration становится zero.
Web сочетает `prefers-reduced-motion` с local preference из Account settings;
prototype/native playback отдельно.
Shell сохраняет bottom navigation на phone/tablet и четыре stateful roots
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

Web tokens/shared controls находятся в `apps/web/src/app/globals.css` и
`src/components/ui.tsx`, original Manrope/Brand A — в `apps/web/public`.
Figma R6 target переиспользует тот же visual language; React не импортирует
Flutter runtime. Wide/narrow layout, focus и state implementation проверяются
headless contracts/build; visual/browser/native проверка D048 разрешена
последующим явным ответом пользователя. Actual acceptance/evidence отдельно.

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
| Auth | Центрированная форма, text слева, matte controls, без тяжёлой декорации |

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
