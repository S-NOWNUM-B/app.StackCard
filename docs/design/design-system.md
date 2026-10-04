<div align="center">

# StackCard Design

**Obsidian / Signal Red / Electric — общий визуальный язык mobile и будущего web**

![Palette](https://raster.shields.io/badge/Palette-Electric-C8FF31?style=for-the-badge)
![Accent](https://raster.shields.io/badge/Accent-Signal_Red-FF0012?style=for-the-badge)

</div>

Единый визуальный язык mobile: **Obsidian / Signal Red / Electric**.
Редизайн от 2026-10-04 выполняется по прямому поручению пользователя поверх
существующих возможностей Phase 0–10. Web остаётся отдельной будущей работой.

## Содержание

- [Visual Theme & Atmosphere](#1-visual-theme--atmosphere)
- [Color](#2-color)
- [Typography](#3-typography)
- [Spacing & Grid](#4-spacing--grid)
- [Layout & Composition](#5-layout--composition)
- [Components](#6-components)
- [Motion & Interaction](#7-motion--interaction)
- [Voice & Brand](#8-voice--brand)
- [Anti-patterns](#9-anti-patterns)

## 1. Visual Theme & Atmosphere

Интерфейс developer-портфолио с редакционной композицией и киберпанк-графикой.
Пользовательский референс задаёт цельные цветные поверхности, крупный текст,
свободную композицию и круглые действия. Переносим эти свойства в StackCard;
персонажей, NFT-тексты, логотип ABYTE и точную композицию не копируем.

Дополнительные UI-ориентиры: [21st Tabs](https://21st.dev/blog/react-tabs-components),
[Minimal Button](https://21st.dev/%40radiumcoders/components/minimal-button),
[Settings sections](https://news.21st.dev/blog/react-settings-page-components).
Их визуальные решения адаптируются на Flutter; этот же контракт применяется к
будущему web через его собственные components. React код в mobile не переносится.

Одна выразительная поверхность на ключевой экран, затем открытые секции с
разделителями. Home, портфолио, Projects и Settings имеют свой цветовой
ритм. Не делать весь продукт одинаковым серым списком. В формах главным остаётся
ввод; графика используется в заголовках и preview, а не за полями. На экранах
авторизации остаются компактный brand и форма без декоративного poster и слогана.

## 2. Color

Canonical source: [StackCardColors](../../apps/mobile/lib/core/theme/stackcard_colors.dart).
Все экраны используют `context.colors`, без локальных случайных HEX.

| Роль | Dark | Light | Назначение |
| --- | --- | --- | --- |
| background | #09090B | #F5F5F6 | Базовая поверхность |
| surface | #111113 | #FFFFFF | Диалоги и необходимые отдельные панели |
| surfaceElevated | #18181B | #FAFAFA | Поля и состояния controls |
| surfaceHover | #202024 | #EFEFF1 | Hover/disabled |
| border / borderSubtle | #29292E / #1F1F23 | #DEDEE3 / #E8E8EC | Разделители |
| textPrimary | #F5F5F7 | #18181B | Основной текст |
| textSecondary | #A1A1AA | #52525B | Подписи |
| accent | #FF0012 | #FF0012 | Signal Red, CTA и active state |
| accentHover / accentSoft | #E60010 / #351014 | #E60010 / #FFE5E7 | Interaction |
| acid | #C8FF31 | #C8FF31 | Профиль, крупные поверхности |
| cyan | #79E8F2 | #79E8F2 | Projects / редактор |
| pink | #FF79B7 | #FF79B7 | Featured / Settings |
| ink | #09090B | #09090B | Текст на цветных поверхностях |
| success | #22C55E | #16A34A | Успех |
| warning | #F59E0B | #D97706 | Предупреждение |
| error | #EF4444 | #DC2626 | Ошибка с текстовым объяснением |

Signal Red и Obsidian сохраняются. Большие цветовые поля теперь разрешены;
каждая секция получает осмысленную роль. На acid/cyan/pink использовать ink.
Красный не заменяет подпись ошибки; декоративный цвет не означает sync success.

## 3. Typography

Локальные **DM Sans** и **Noto Sans** остаются в
[pubspec](../../apps/mobile/pubspec.yaml), лицензии — в `assets/fonts`.
[StackCardTheme](../../apps/mobile/lib/core/theme/stackcard_theme.dart) владеет шкалой.
Display — 40–64, заголовки — 24–36, body — 14–16, подписи — 11–14.
Крупные заголовки имеют плотный интерлиньяж и отрицательный tracking.
Короткие section labels могут быть uppercase; большие русские тексты сохраняют
обычный регистр. Системный text scale не ограничивается.

## 4. Spacing & Grid

[tokens](../../apps/mobile/lib/core/theme/stackcard_tokens.dart) задают spacing:
4, 8, 12, 16, 20, 24, 32, 48. Phone gutter — 16, tablet — 24.
Контент свободно прокручивается. От 700 доступна боковая навигация;
две колонки используются только при достаточной ширине и обычном text scale.
320 px, landscape и text scale 2 должны сохранять все действия без overflow.

## 5. Layout & Composition

- Home: персональный poster → компактная полнота → featured → рабочие действия.
- Portfolio: инструменты → выразительный профиль → открытые ordered sections.
- Projects: компактный поиск и фильтры → счётчик → выразительные строки проектов.
- Settings: цветной заголовок → плоские группы настроек и аккаунта.
- Вход, регистрация и сброс пароля: компактный brand → форма и auth/guest
  действия; единая колонка шириной до 440 px без рекламного блока.
- GitHub: поиск username → источник/кэш → profile/repositories → pagination.
- Builder: статус/Save/preview → строки разделов → projects/blocks/theme/notes.
- Editors: заголовок → поля → Apply/Cancel; клавиатура не закрывает действия.

Большие posters имеют один внешний radius. Внутри них нет дополнительных
карточек. В остальных секциях граница только там, где разделяет реальные группы.

## 6. Components

Расширяем [shared widgets](../../apps/mobile/lib/shared/widgets), не вводим вторую
систему компонентов. `StackCardCard` теперь плоская секция с нижним разделителем.
`StackCardPoster` — цветовая поверхность с общей декоративной геометрией;
картинка рисуется локально, не требует сети и не содержит пользовательские данные.
Графика обрезается поверхностью, исключена из semantics и не принимает pointer.
Кнопки — capsule с target ≥48; icon actions — круг. Поиск/поля имеют спокойную
подложку и нижнюю линию, focus видим. Метаданные проектов — короткая строка,
не набор вложенных badge. Tags оставлять только для реально выбираемых filters.

Brand mark использует геометрию оригиналов
[brand kit](../../assets/branding/stackcard-link-brand-kit.json); оригинальные SVG
не заменяются. ThemeMode и PortfolioTheme остаются отдельными настройками.

## 7. Motion & Interaction

Не добавляем looping glow, scanline animation или параллакс. Статическая геометрия
создаёт характер без отвлечения от данных. Existing navigation и feedback
сохраняются; loading показан явным progress. Декоративное движение не требуется.

## 8. Voice & Brand

UI ru/en остаётся в [localization](../../apps/mobile/lib/core/localization).
Подпись объясняет действие или состояние. Убираем повтор заголовков, рекламные
описания и обещания будущих функций. Demo/working draft, private notes,
cached source, unsaved и sync failures всегда различимы.
Suggestions сохраняют объяснение причины и явное действие владельца.

## 9. Anti-patterns

Запрещены карточка в карточке, badge на badge, одинаковые grey bento panels,
постоянный glow, случайная палитра, NFT-содержание из референса, мелкий текст на
яркой графике, фиксированная высота с обрезанием текста, скрытые critical states.
Редизайн не меняет Repository/DI, auth/UID isolation, storage/sync/import semantics.

Приёмка: format, analyze, existing behavior tests, responsive/contrast/tap targets
и просмотр реальных Flutter renders. Результаты — в
[product spec](../product/product-spec.md). Снимки — в [previews](previews/).
Решения и handoff — [design contract](design-contract.md) и
[implementation handoff](implementation-handoff.md).
