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

## Принято для Phase 3

| Решение | Причина и последствия |
| --- | --- |
| `presentation/domain/data` в auth/profile/projects | Реальные demo-сценарии получают pure Dart модели/правила и repository contracts; data хранит mock content, widgets рендерят состояния |
| Repository contracts + Riverpod DI у корня feature | Concrete реализации заменяются provider override без переписывания экранов; FutureProvider/AsyncNotifier обслуживают загрузку и действия, Provider остаётся владельцем темы |
| Public feature barrels для межмодульных зависимостей | `auth.dart`, `profile.dart`, `projects.dart`, `portfolio.dart` раскрывают намеренный API; внутренние файлы другой feature не становятся общим контрактом |
| Immutable models и domain selection | `ProjectSource` отделяет происхождение от UI-подписи; query/filter и featured-отбор работают без Flutter/Riverpod; коллекции защищены от внешней мутации |
| `PortfolioOverview` как presentation read model | Объединяет profile/projects для Home, Portfolio и preview; полный featured-список не зависит от поиска на Projects. Full Builder/domain остаётся задачей Phase 6 |
| `ProfileReadiness` как demo-snapshot | Валидация счётчиков и расчёт доли не утверждают алгоритм полноты будущего Builder |
| Без дополнительных UseCase/DataSource | Текущие mock repositories и простые правила не требуют пустого промежуточного слоя; network/persistence вводятся на соответствующих фазах |
| Явный retry для asynchronous repository state | Loading/error отображаются shared widgets; пользовательский retry повторяет запрос, сохранённые query/filter остаются в app session |

Подробные границы и текущие источники — в
[architecture](../architecture/architecture.md#mobile-modules--при-реальных-сценариях),
сравнение state mechanisms — в [учебном guide](../learning/state-management.md).
Результаты приёмки и ограничения фиксируются в
[product spec](../product/product-spec.md#phase-3--architecture).

## Принято для Phase 4

| Решение | Рассмотренная альтернатива | Причина и последствия |
| --- | --- | --- |
| Отдельный GitHub Import и public `github_import.dart` | Сразу заменить curated Projects ответами API | Публичные GitHub metadata читаются на `/github-import`; demo-портфолио и будущие curated/draft/published модели сохраняют собственные contracts |
| Dio и DTO в data, pure Dart repository/models/failures в domain | HTTP и raw JSON внутри widgets | Data проверяет ответы и преобразует их в immutable модели; feature-root DI подменяет repository, clock и response cache, widgets читают presentation state |
| Controller через `NotifierProvider.autoDispose` | Хранить запросы и таймеры в widget или бессрочной app session | Controller владеет атомарной initial load, refresh и pagination; уход с экрана отменяет запросы и debounce, generation guards и `ref.mounted` отсекают поздние ответы |
| Pagination по `Link` с проверкой origin и user path | Угадывать следующий номер страницы | Поддерживаются username и canonical numeric-ID paths GitHub; объединение по repository ID сохраняет порядок и исключает дубли |
| Локальные фильтры и query debounce 300 ms | Новый API search на каждый ввод | Поиск применяется только к загруженным repositories; новый username сбрасывает filters, refresh сохраняет их |
| Typed failures и явный retry с rate-limit deadline | Автоматические повторы без учёта API headers | Initial error, refresh error и page error различаются; успешный список сохраняется при ошибке refresh/more, повторный HTTP блокируется до разрешённого времени. Repository живёт в app session, чтобы закрытие экрана не сбрасывало deadline |
| ETag conditional requests с serialized response cache в памяти | Сразу добавить Hive и offline fallback | Cache индексируется request URI и переживает закрытие экрана в app session; `304` повторно использует проверенный ответ. Disk persistence, TTL и versioned schema остаются Phase 5 |

Границы реализации — в
[architecture](../architecture/architecture.md#mobile-modules--при-реальных-сценариях),
использование экрана — в [mobile guide](../../apps/mobile/README.md#прочитать-публичные-данные-github),
состояния и lifecycle — в [state management guide](../learning/state-management.md#github-import-на-phase-4).
Результаты приёмки фиксируются в
[product spec](../product/product-spec.md#phase-4--github-api).

## Решить перед соответствующими фазами

- Sync conflict strategy и поведение при нескольких устройствах, включая правки
  из mobile и web; согласование и проверка совместимости data contracts.
- Firestore schema, private draft/public snapshot, username uniqueness,
  атомарность publish/unpublish.
- На Phase 5 определить TTL, versioned storage/cache schema и migrations,
  сохранение ETag validators и offline fallback; обосновать альтернативу Hive,
  если она нужна.
- Contact spam/rate limiting и доверенная отправка notifications.
- Application IDs, signing и release configuration до публикации.
- Точные web routes, зависимости, способы auth/session и проверки определить
  перед Phase 13 по реальному Next.js/Firebase стеку. Browser push и равенство
  нативных функций не включаются автоматически в mobile-требования.

## Формат ADR

Файл: `NNNN-short-title.md`. Поля: дата, статус (`proposed`, `accepted`, `superseded`),
контекст, решение, альтернативы, последствия и способ проверки.
Пересмотренное решение сохраняется со ссылкой на заменяющий ADR.
