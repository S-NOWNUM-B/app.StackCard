# Архитектурные решения

Короткие ADR фиксируют решение, контекст, альтернативы и последствия, когда выбор
влияет на несколько частей продукта. Отдельный ADR для каждого widget не нужен.

## Принято для Phase 0

| Решение | Причина и последствия |
| --- | --- |
| Один monorepo, Flutter в `apps/mobile`, будущий сайт в `apps/web` | Mobile и web-редактор/публичные страницы — один продукт; каталог `apps/web` подготовлен с README, приложение ещё не создано |
| Перенос существующего scaffold, mobile только Android/iOS | Сохраняет Android/iOS native configs и настройки; desktop и Flutter web targets удалены, повторный `flutter create` не нужен |
| Минимальный запуск без будущих packages | Счётчик и widget test проверяют фундамент без premature architecture |
| Firebase вместо своего backend в v1 | Единый аккаунт и данные для mobile/web, меньше компонентов; сервисы пока не настроены |
| Next.js для сайта и web-редактора на Phase 13 | Главная, скачивание mobile, защищённый кабинет и public portfolio с SEO/metadata/OpenGraph; отдельное приложение `apps/web` |
| Два редактора одного портфолио | Mobile и web работают с общим private draft и правилами публикации; согласованные data contracts реализуются отдельно в Dart/TypeScript |
| Mobile offline, web v1 online-first | Mobile хранит локальный draft/cache; web показывает статус сохранения/sync и требует сети для удалённых действий |
| GitHub source отдельно от curated/published данных | Пользователь контролирует редактуру и публикацию, sync предлагает изменения |
| Logo originals в `assets/branding` | Имена совпадают с brand kit, SVG bytes сохранены, runtime integration отложена |
| Lockfile mobile отслеживается | Воспроизводимое разрешение зависимостей приложения |
| Общий AI-контекст в `docs/AI/` | Router, общие и scope rules хранятся вместе; root/nested AGENTS остаются точками входа, runtime configs — рядом с кодом |

Реализованная UI foundation и целевые решения описаны в
[architecture](../architecture/architecture.md) и
[design system](../design/design-system.md).
Общий порядок работы и sources описаны в [AI router](../AI/README.md).

## Принято для Phase 2

| Решение | Причина и последствия |
| --- | --- |
| Provider для ThemeMode, Riverpod для Projects query/filter state | Выполняет учебную эволюцию простого app-level состояния; immutable состояние продукта и производный список проверяются независимо от widget tree |
| Один runtime-владелец каждого состояния | AppearanceController владеет темой, ProjectFiltersNotifier — поиском/фильтрами; router не передаёт theme callbacks, TextEditingController остаётся UI-ресурсом |
| Locale после появления переводов | Разрешённая граница Provider ThemeMode/Locale не требует пустой реализации Locale при русскоязычном UI |
| State только в app session | Фильтры сохраняются при навигации, перезапуск сбрасывает выбор; persistence относится к Phase 5 |
| Промежуточные учебные версии вне `lib` | Независимые patches восстанавливают варианты темы во временной копии; рабочий код содержит итоговый Provider |

Сравнение подходов, переходы и воспроизведение находятся в
[state management guide](../learning/state-management.md).

## Решить перед соответствующими фазами

- Sync conflict strategy и поведение при нескольких устройствах, включая правки
  из mobile и web; согласование и проверка совместимости data contracts.
- Firestore schema, private draft/public snapshot, username uniqueness,
  атомарность publish/unpublish.
- Storage/cache schema и migrations; причина альтернативы Hive, если нужна.
- GitHub rate limits, retry и cache lifetime после проверки актуального API.
- Contact spam/rate limiting и доверенная отправка notifications.
- Application IDs, signing и release configuration до публикации.
- Точные web routes, зависимости, способы auth/session и проверки определить
  перед Phase 13 по реальному Next.js/Firebase стеку. Browser push и равенство
  нативных функций не включаются автоматически в mobile-требования.

## Формат ADR

Файл: `NNNN-short-title.md`. Поля: дата, статус (`proposed`, `accepted`, `superseded`),
контекст, решение, альтернативы, последствия и способ проверки.
Пересмотренное решение сохраняется со ссылкой на заменяющий ADR.
