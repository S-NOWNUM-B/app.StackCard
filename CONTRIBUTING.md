<div align="center">

# Разработка StackCard

**Процесс работы, проверки и правила внесения согласованных изменений**

![Contributing guide](https://raster.shields.io/badge/Contributing-guide-09090B?style=for-the-badge)
![Scope Phase 4](https://raster.shields.io/badge/Scope-Phase_4-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Что вносить](#что-вносить)
- [Процесс работы](#процесс-работы)
- [Требования к изменениям](#требования-к-изменениям)
- [Быстрый старт](#быстрый-старт)
- [Основные команды](#основные-команды)
- [Проверки](#проверки)
- [Коммиты](#коммиты)
- [Pull Requests](#pull-requests)

---

## Что вносить

Phase 0–4 завершены; последнее поручение — GitHub API на Phase 4.
Реализован отдельный GitHub Import для чтения публичного профиля и repositories.
Окончательный статус приёмки и результаты проверок находятся в
[product spec](docs/product/product-spec.md#phase-4--github-api).
Продуктовые функции вводятся последовательно по
[roadmap](docs/product/product-spec.md#roadmap),
переход к следующей фазе требует подтверждения пользователя.

[План разработки](docs/product/product-spec.md#план-разработки) обязателен
для дальнейшей работы над продуктом. Он задаёт задачи, последовательность
и критерии готовности; текущая фаза и прогресс хранятся в product spec.
Общие [правила выполнения фаз](docs/AI/AGENTS.md#разработка-по-плану)
применяются к mobile, web и backend.

<div align="center">

| **Направление** | **Допустимые изменения сейчас** |
|:---|:---|
| Документация | Уточнение сценариев, границ, источников и способов работы |
| Mobile UI и GitHub API | Demo-экраны, app shell, темы, общие компоненты и отдельный GitHub Import с публичными данными |
| Mobile state и architecture | Provider для ThemeMode; Riverpod для repository loading/actions, DI и filters; presentation/domain/data в auth/profile/projects/github_import, учебные patches вне runtime |
| Структура | Согласование путей, ignore rules и общего AI-контекста |
| Brand assets | Сохранение оригиналов и описания их применения |

</div>

В `apps/mobile` реализованы UI foundation и Repository/DI границы
для Android/iOS с GoRouter: core-портфолио использует demo/mock sources,
GitHub Import читает public API через Dio. Его ETag-кэш хранится в памяти app
session; disk cache и offline fallback относятся к Phase 5. Прочитанные данные
не добавляются автоматически в curated-портфолио.
В `apps/web` подготовлен README; Next.js-приложение появится на Phase 13.
Firebase, web dependencies и packages будущих фаз заранее не подключаются.

---

## Процесс работы

### 1. Определить область изменения

Начни с [README](README.md), [общих правил](docs/AI/AGENTS.md) и
[AI router](docs/AI/README.md). Для mobile прочитай
[scope rules](docs/AI/scopes/mobile.md). Затем прочитай
[план разработки](docs/product/product-spec.md#план-разработки) и раздел нужной
фазы. Соотнеси задачу с её критериями готовности, установи текущий статус,
владельца контракта и конкретный проверяемый результат.

### 2. Изучить источники и сделать локальное изменение

Перед реализацией открой затронутые code/config и ближайший аналог.
Версии и зависимости проверяй в manifests/lockfiles. Разделяй работу на
небольшие самостоятельные шаги; сначала используй существующий механизм.

Auth/profile/projects/github_import используют `presentation/domain/data`; DI связывается у
корня feature. Domain остаётся pure Dart; concrete repositories не импортируются
widgets. Между features используй публичные barrels. `PortfolioOverview` —
presentation read model для Home, Portfolio и preview, а не полный Builder domain.
В GitHub Import data слой владеет Dio, DTO mapping, Link pagination и ETag
validators; controller — загрузкой, refresh, локальным debounce и обработкой
typed failures. Сетевые ошибки и rate-limit deadline проверяются через
подменяемые repository и clock providers.
Подробное направление зависимостей — в
[architecture](docs/architecture/architecture.md#mobile-modules--при-реальных-сценариях).

Flutter/Dart-команды выполняются в `apps/mobile`; Git — из корня monorepo.
Нативные платформы mobile — Android и iOS, для iOS-разработки нужен macOS host.
Установку и запуск описывает [быстрый старт](#быстрый-старт).

### 3. Обновить документы и проверить результат

Изменение пути, команды, контракта или устойчивого правила сопровождается
обновлением затронутых links и guides в той же задаче. AI-контекст хранится
в `docs/AI/`, рабочие configs остаются рядом с кодом. Решение с последствиями
для нескольких областей фиксируй в [ADR](docs/decisions/README.md).

Выполни проверки по затронутому поведению и просмотри фактический diff.
Сообщи выполненные проверки и ограничения среды; наличие файла или успешный
link check не доказывают правильность его содержания.

Обнови фактический прогресс и результаты проверок в product spec. Перед завершением
фазы сверь все её критерии готовности; оставшиеся задачи и непроверенные сценарии
укажи явно. Следующую фазу начинай после завершения текущей и подтверждения
пользователя; прямое поручение на неё считается подтверждением.

---

## Требования к изменениям

- одна задача и понятный scope без unrelated правок;
- существующие архитектура, naming и визуальный стиль сохраняются;
- новые зависимости добавляются только при использовании в текущей фазе;
- native configs Android/iOS и generated-file ownership сохраняются;
- документы отделяют готовое поведение от целевых решений и планов;
- локальные caches, builds, SDK paths, signing keys и secrets не попадают в Git;
- чужие изменения не удаляются и не включаются в свой commit автоматически.

---

## Быстрый старт

Установи Flutter stable с Dart, удовлетворяющим `environment.sdk` в pubspec.
Для Android нужны Android SDK, JDK и эмулятор/устройство; для iOS — macOS и Xcode.
Точные проблемы окружения покажет `flutter doctor -v`.

macOS — zsh/bash, из корня репозитория:

```sh
cd apps/mobile
flutter --version
flutter doctor -v
flutter pub get
flutter devices
flutter run -d <device-id>
```

`<device-id>` замени ID Android-устройства/эмулятора или iOS-устройства/симулятора
из `flutter devices`. Android — первый release target; iOS также входит в scope.
Открывай `apps/mobile`, если IDE не обнаруживает Flutter-проект в корне monorepo.

После запуска появляется экран знакомства со StackCard. «Открыть демо» ведёт
на главную; в навигации доступны Портфолио, Проекты и Настройки. Core-портфолио
использует демонстрационные данные. Кнопка «GitHub Import» на Projects открывает
`/github-import`: отправка username загружает публичный профиль и repositories.
Поиск работает по уже загруженным данным с debounce 300 ms; «Загрузить ещё»
читает следующую страницу из Link. Ошибки повторяются только по действию
пользователя; rate-limit deadline блокирует сетевой retry до разрешённого времени.
Тема переключается в Настройках и пока не сохраняется после закрытия приложения;
авторизация, сохранение draft и web-редактор вводятся на своих фазах.

---

## Основные команды

macOS — zsh/bash, команды выполняются из `apps/mobile`:

<div align="center">

| **Команда** | **Назначение** |
|:---|:---|
| `flutter pub get` | Разрешить зависимости приложения |
| `flutter doctor -v` | Проверить Flutter и нативные toolchains |
| `flutter devices` | Получить доступные target IDs |
| `dart format --output=none --set-exit-if-changed lib test` | Проверить форматирование |
| `flutter analyze` | Статический анализ Dart |
| `flutter test` | Проверить состояние, UI-сценарии, адаптивность, контраст и touch targets |

</div>

Проверки запускай по затронутому поведению. Порядок и ограничения описаны в
[разделе проверок](#проверки).

Секреты, service-account keys, signing keys и локальные SDK paths в Git не попадают.
Firebase/env setup пока отсутствует и будет спроектирован при подключении сервисов.

---

## Проверки

Для изменения Flutter UI сначала разреши зависимости, затем проверь
формат, анализ и значимое поведение. macOS — zsh/bash; Windows — WSL/Ubuntu.
Рабочая директория — `apps/mobile`:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Ожидаются успешный exit code, отсутствие ошибок анализа и прошедшие tests.
`test/widget_test.dart` проверяет вход в демо, переходы и возврат, поиск проектов,
предпросмотр, смену темы, UI states и клавиатуру. `test/responsive_test.dart`
проверяет пять экранов в двух темах на размерах телефона и планшета, portrait/landscape,
включая узкий экран и удвоенный текст. При обычном масштабе проверяются контраст
текста и touch targets; это автоматические проверки, не полный accessibility audit.
`test/appearance_controller_test.dart` проверяет начальную тему и уведомления,
`test/project_filters_test.dart` — правила поиска, сочетания фильтров и срок жизни.
`test/state_management_test.dart` проверяет общую тему, system brightness,
сохранение query/filter при навигации, синхронизацию поля и новую app session.
`test/auth_repository_test.dart`, `test/profile_repository_test.dart` и
`test/projects_repository_test.dart` проверяют contracts, чистые правила и
immutable данные. Соответствующие `auth_di_test.dart`, `profile_di_test.dart`,
`projects_di_test.dart` подменяют источник в реальных экранах через
`StackCardApp.providerOverrides`, проверяют loading/error/empty и явный retry.
`test/github_data_test.dart` проверяет DTO, HTTP failures, Link pagination и
условные ETag-запросы; `test/github_import_controller_test.dart` — debounce,
retry deadline, отмену, конкурирующие запросы и сохранение результатов.
`test/github_import_widget_test.dart` проверяет GitHub Import на реальном экране
с подменяемым источником, включая refresh, pagination и UI states.
Сравнение подходов и проверка сохранённых учебных вариантов — в
[state management guide](docs/learning/state-management.md).
Учебные patches применяются независимо к временным копиям текущего проекта;
они сохраняют Repository/DI и меняют только механизм темы. Цель coverage
из roadmap относится к Phase 17.

Снимки для визуальной сверки сохраняются в `docs/design/previews`; это результаты
рендеринга Flutter. Чтобы обновить их после согласованного изменения UI,
из той же директории в zsh/bash:

```sh
flutter test test/responsive_test.dart --dart-define=UPDATE_UI_PREVIEWS=true --update-goldens
```

Для сравнения с существующими PNG без их обновления убери `--update-goldens`.

Перед приёмкой просмотреть снимки всех пяти экранов в обеих темах и ориентациях;
обновление PNG само по себе не подтверждает качество дизайна. Нативный запуск
проверяется отдельно на доступном Android/iOS target.

Для применения форматирования, тот же терминал и директория:

```sh
dart format lib test
```

Для правки только документации проверь local links, anchors, соответствие TOC
заголовкам и отображение Markdown. Flutter tests без изменения кода не требуются.
При изменении архитектурной схемы обнови Mermaid-исходник в `docs/diagrams/`
и его PNG вместе. Изображение должно сохранять узлы, направления и подписи связей
исходника; проверь читаемость схемы и badges в используемом preview.
Команды проверки web будут выбраны по реальным configs при создании приложения.

---

## Коммиты

Commit и push выполняются только по запросу пользователя. До staging проверь
status и diff; добавляй явные пути текущей задачи и повторно просмотри staged diff.

Действующий формат — `type(scope): description`: type/scope на английском,
lowercase; описание на русском, lowercase, без точки, с глаголом в прошедшем
времени и объяснением изменения. Body обязателен: отдельный пункт для каждого
созданного, изменённого, удалённого или переименованного файла.

При подключённом remote синхронизируй через rebase/autostash. После конфликтов
проверь сохранность локальных изменений и повтори релевантные проверки.
Не обходи hooks ради завершения операции.

---

## Pull Requests

При работе через PR описание должно объяснять проблему,
получившееся поведение, выполненные проверки и существенные ограничения.
Сохраняй размер одной задачи; актуальный diff должен позволять проверить выводы.
CI ещё не настроен: его проверки вводятся на соответствующей фазе.
