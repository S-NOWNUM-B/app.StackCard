# Реализация редизайна

Прочитать project AGENTS/router, mobile scope, [design-system](design-system.md),
[contract](design-contract.md), pubspec, core/theme, shared/widgets и целевой screen.
Canonical direction хранится в существующем design guide вместо параллельного DESIGN.md.

Root владеет colors/theme/tokens/shared widgets, shell и Home. Независимые slices:
auth/Settings; Portfolio/Builder/editors; Projects/GitHub. У каждого файла один владелец.

Использовать context.colors acid/cyan/pink/ink; Obsidian/Signal Red сохранить.
StackCardCard — flat section, StackCardPoster — общий цветной hero с геометрией.
Никаких новых business layers, зависимости, network assets или schema changes.
Оригинальные branding assets и локальные fonts сохраняются.

Первый render должен показать крупную иерархию, цельную цветовую поверхность,
короткую copy и отсутствие вложенных cards. Проверить 320/390 phone, landscape,
768/1024 tablet, text scale 1/2, light/dark, ru/en, keyboard и critical states.
Existing keys/actions и явные Save/Add/Accept/Ignore/Retry остаются рабочими.
Format/analyze/full test suite, затем визуальная сверка Flutter screenshots.
