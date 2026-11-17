# Готовность к учебному ТЗ

Сверка тема №28 Developer Portfolio с обязательными требованиями курса. Матрица
построена по исходникам, тестам и CI на 2026-11-17; выполнение тестов и CI в этой
сверке не запускалось, подтверждение берётся из указанных файлов и product spec.
Планы и фазы — [product spec](product-spec.md#учебные-требования-и-сдача).

Актуально на 2026-11-17 по принятому QA-прогону: mobile 1606 тестов, покрытие LCOV
87,9%; web 224 теста. Новые функции после прошлой сверки: тёмная тема в Настройках,
«Здоровье портфолио» (`/health`), «История версий» (`/history`), «Подбор под вакансию»
(`/vacancy`, mobile). Web имеет здоровье и историю, подбор под вакансию на web открыт.
Открытые пункты: `npm audit` — high в транзитивной зависимости firebase не исправлен;
живая проверка на устройстве, вход Google и физический iPhone не пройдены.

Статусы: **OK** — реализовано и есть проверяемое подтверждение; **частично** —
есть оговорка; **нет** — не найдено; **исключено** — вне объёма по решению владельца
(карты и геолокация, push/FCM, публикация в магазины).

## Обязательные компоненты

<div align="center">

| **Требование ТЗ** | **Где реализовано** | **Чем подтверждено** | **Статус** |
|:---|:---|:---|:---|
| Dart с null safety | `apps/mobile/pubspec.yaml:21` (`sdk: ^3.13.3`) | `flutter analyze` в CI (`.github/workflows/ci.yml`, job mobile) | OK |
| Слои presentation / domain / data | `apps/mobile/lib/features/*/{domain,data,presentation}` | [architecture](../architecture/architecture.md); тесты репозиториев `projects_repository_test.dart` | OK |
| Паттерн Repository | `lib/features/projects/domain/projects_repository.dart:3`, `lib/features/auth/data/firebase_account_auth_repository.dart:9` | `test/projects_repository_test.dart`, `test/auth_repository_test.dart` | OK |
| Dependency Injection | Riverpod providers: `lib/features/auth/auth_providers.dart`, `lib/features/projects/projects_providers.dart`, `ProviderScope` в `lib/main.dart:200` | `test/projects_di_test.dart`, `test/auth_di_test.dart` | OK |
| Material 3 | `lib/core/theme/stackcard_theme.dart:156` (`useMaterial3: true`) | `test/light_runtime_test.dart` | OK |
| Не менее 5 экранов | Маршруты `lib/app/app_router.dart`: home, projects, editor, settings (5 подэкранов), github-import, sign-in/register/reset-password, inbox, personalization, health (`/health`), history (`/history`, `/history/:id`) | `test/account_navigation_test.dart`, `test/widget_test.dart` | OK |
| Светлая и тёмная темы | `lib/main.dart:346-349`: `StackCardTheme.light` и `darkTheme: StackCardTheme.dark`, `themeMode` из `AppearanceController`; выбор System/Light/Dark в `lib/features/settings/settings_screen.dart:145-164`, сохраняется в `AppSettings` через `lib/core/state/appearance_controller.dart` | `test/light_runtime_test.dart:45` (`ThemeMode.dark`), `test/light_runtime_test.dart:68`, `lib/core/theme/stackcard_theme.dart:8` | OK (тёмная тема включена решением владельца 2026-11-15) |
| Адаптивная вёрстка | `lib/app/app_shell.dart:200` (LayoutBuilder), `lib/features/home/home_screen.dart:324` | `test/responsive_test.dart:27-28` (phone/tablet, портрет/альбом) | OK |
| Provider для базовых сценариев | `ChangeNotifierProvider` + `Selector` в `lib/main.dart:202,338` (AppearanceController) | `test/state_management_test.dart`, `test/appearance_controller_test.dart` | OK |
| Riverpod/BLoC для основной логики | `flutter_riverpod` (`pubspec.yaml`), `ProviderScope` `lib/main.dart:200`, Notifier'ы в `*_controller.dart` и `*_providers.dart` | `test/project_filters_test.dart`, `test/workspace_controller_test.dart` | OK |
| Обоснование выбора в README | [README](../../README.md#выбор-state-management) и [учебный guide](../learning/state-management.md#почему-поиск-проектов-использует-riverpod) | Текст документации | OK (дописано в этой сверке) |
| REST/JSON через dio | `lib/features/github_import/data/dio_github_import_repository.dart` (`per_page`, rate limit), таймауты `lib/features/github_import/github_import_providers.dart:22-24` | `test/github_data_test.dart`, `test/github_import_controller_test.dart` | OK |
| Сериализация JSON | Ручной разбор в data-слое (`dio_github_import_repository.dart`, `portfolio_github_codec`); `json_serializable`/`freezed` в `pubspec.yaml` отсутствуют | `test/portfolio_github_codec_test.dart` | частично (ТЗ называет json_serializable/freezed как пример, не как обязательство) |
| loading / error / empty | `lib/shared/widgets/stackcard_async_view.dart`, `stackcard_states.dart` | `test/stackcard_async_view_test.dart` | OK |
| Поиск с debounce, pull-to-refresh | `github_import_controller.dart:198` (Timer 300 мс), `github_import_screen.dart:215` (RefreshIndicator) | `test/github_import_widget_test.dart` | OK |
| SharedPreferences для настроек | `lib/features/settings/data/shared_preferences_settings_repository.dart:8` | `test/settings_persistence_test.dart` | OK |
| Hive для кэша | `lib/core/storage/local_storage.dart:3,47`, `lib/features/github_import/data/hive_github_response_cache.dart:8` | `test/local_storage_test.dart`, `test/github_persistence_test.dart` | OK |
| Работа без интернета | Локальный черновик, кэш GitHub, outbox: `lib/features/portfolio_draft/data/synced_portfolio_draft_repository.dart` | `test/portfolio_sync_repository_test.dart`, `test/portfolio_draft_repository_test.dart` | OK |
| GoRouter, именованные маршруты, параметры | `lib/app/app_router.dart:98` (`GoRouter`), `name: 'editProject'`, `/projects/:id/edit`, `inbox/:requestId` | `test/account_navigation_test.dart` | OK |
| Вложенная навигация | `StatefulShellRoute.indexedStack` `app_router.dart:275` | `test/account_navigation_test.dart` | OK |
| Защита маршрутов (redirect) | `app_router.dart:104-140` (redirect по `AppRouteAccess.authenticated`) | `test/account_navigation_test.dart`, `test/auth_di_test.dart` | OK |
| Firebase Auth: email | `firebase_account_auth_repository.dart:57,69` | `test/firebase_auth_repository_test.dart`, `integration_test/account_runtime_test.dart` | OK |
| Firebase Auth: Google | `google_sign_in` в `pubspec.yaml`, `firebase_account_auth_repository.dart` | `test/firebase_auth_google_test.dart`, `integration_test/google_auth_runtime_test.dart` | OK |
| Cloud Firestore для данных | `firebase/firestore.rules:627` (`accounts/{uid}` и подколлекции), mobile `test/firestore_draft_adapter_test.dart` | `integration_test/firestore_runtime_test.dart` | OK |
| Security Rules | `firebase/firestore.rules`, `firebase/storage.rules` | `firebase/test/firestore_rules.test.mjs`, `storage_rules.test.mjs`; в CI `npm run test:all-rules` (job firebase) | OK |
| Firebase Cloud Messaging | Реализован (`firebase_messaging`, `lib/features/notifications`) | Phase 14 в product spec | исключено владельцем |
| Google Maps и геолокация | Нет, ADR 0005: ручной город/страна | product spec Phase 12 | исключено владельцем |
| ListView.builder | `lib/features/projects/presentation/projects_screen.dart:140` | `test/project_read_models_widget_test.dart` | OK |
| Пагинация | `github_import_controller.dart:148` (`loadMore`), `per_page: 30` | `test/github_import_controller_test.dart` | OK |
| Кэширование изображений | `lib/shared/widgets/stackcard_avatar.dart:44` (`CachedNetworkImage`) | `test/portfolio_media_widget_test.dart` | OK |
| Профилирование в DevTools (скриншоты до/после) | Локальные baseline/after: `docs/product/evidence/phase16/2026-10-21-mobile-{before,after}.json` | Product spec Phase 16: native DevTools frame/memory gate **открыт**, скриншотов DevTools нет | **частично** |
| Камера | `lib/features/media/data/native_portfolio_image_picker.dart:26` (`ImageSource.camera`) | `test/portfolio_media_widget_test.dart`, `integration_test/media_runtime_test.dart` | OK |
| Собственный Kotlin Platform Channel | `android/app/src/main/kotlin/dev/snownumb/stackcard/MainActivity.kt:26` (`stackcard/document_links`: open, share, savePdf), Dart `lib/features/portfolio_draft/presentation/native_document_link_actions.dart:12` | `test/native_document_link_actions_test.dart`, `test/native_portfolio_pdf_actions_test.dart`, `tools/testing/test_android_system_actions.py`, `docs/product/evidence/phase17/android-native-checks.json` | OK |
| Unit-тесты | `apps/mobile/test` (124 Dart-файла вместе с integration) | `flutter test` в CI | OK |
| Widget-тесты | `test/*_widget_test.dart`, `test/widget_test.dart` | то же | OK |
| Integration-тест | `apps/mobile/integration_test/` (15 файлов, `IntegrationTestWidgetsFlutterBinding`) | Запускаются на устройстве/эмуляторе; в CI **не выполняются** (job mobile запускает только `flutter test`) | частично |
| Моки через mocktail | Не используются (`mocktail` отсутствует в `pubspec.yaml`), применяются ручные fakes `test/support/*` | ТЗ упоминает mocktail как пример недели 13 | частично |
| Покрытие > 40% | CI проверяет `tools/testing/check_coverage.py --minimum 40` (строго выше) | `docs/product/evidence/phase17/mobile-coverage.json`: 86.9% строк | OK |
| flutter analyze без ошибок | CI `flutter analyze --no-pub` | Зелёный GitHub run — product spec Phase 18, run 39985614786 | OK |
| CI: pub get | `flutter pub get --enforce-lockfile` (mobile, android) | `ci.yml` | OK |
| CI: format | `dart format --set-exit-if-changed lib test integration_test tool test_driver` | `ci.yml` | OK |
| CI: analyze | `flutter analyze --no-pub` | `ci.yml` | OK |
| CI: test | `flutter test --no-pub --coverage` | `ci.yml` | OK |
| CI: build apk | job android: `flutter build apk --debug --no-pub` после assets/web/firebase/mobile | `ci.yml` | OK |
| CI: артефакт APK | `upload-artifact` `android-debug-${{ github.sha }}`, `if-no-files-found: error`, 7 дней; отдельно LCOV | `ci.yml`; product spec Phase 18 (артефакты скачаны и проверены) | OK |
| CI: закреплённые Actions | Все 14 `uses:` закреплены полным 40-символьным SHA, `contents: read`, `persist-credentials: false` | Проверено разбором `ci.yml` | OK |
| Подписанная release-сборка, Crashlytics, Google Play | Crashlytics подключён (`lib/core/diagnostics/firebase_diagnostics_sink.dart`) | — | исключено владельцем |

</div>

## Недели 1–7

<div align="center">

| **Пункт недели** | **Где** | **Статус** |
|:---|:---|:---|
| 1: репозиторий и README, цель, аудитория | [README](../../README.md#о-проекте), [концепция и аудитория](product-spec.md#концепция-и-аудитория) | OK |
| 1: 2–3 аналога | [Аналоги](product-spec.md#аналоги) | OK (дописано в этой сверке) |
| 1: список экранов | [README](../../README.md#экраны-приложения), [Пользовательский путь и экраны](product-spec.md#пользовательский-путь-и-экраны) | OK (дописано в этой сверке) |
| 1: Dart-задачи, `flutter doctor` | Не найдены в репозитории; `docs/learning/` содержит только state management | **нет** |
| 2: экраны на статических данных, Material 3 | Phase 1 в product spec; тема `stackcard_theme.dart:156` | OK |
| 2: эскизы экранов | `docs/redesign/screens.md`, `docs/design/previews/*.png` (рендеры с устройств, не эскизы до реализации); Figma-ссылки в `docs/design/design-system.md` | частично |
| 3: setState → InheritedWidget → Provider и сравнение | [Один сценарий, три подхода](../learning/state-management.md#один-сценарий-три-подхода), patches в `docs/learning/patches`, краткая заметка в [README](../../README.md#выбор-state-management) | OK |
| 4: Riverpod, слои, Repository, DI | см. таблицу выше | OK |
| 5: REST, JSON, состояния, debounce, refresh | см. таблицу выше | OK |
| 6: SharedPreferences, Hive, offline | см. таблицу выше | OK |
| 7: GoRouter, redirect, BottomNavigationBar, планшет и ориентации | `app_router.dart:275`, `app_shell.dart`, `test/responsive_test.dart` | OK |

</div>

## Пробелы для кодовых отделов

1. Integration-тесты в CI не запускаются: нужен либо отдельный job с эмулятором, либо
   запись о том, что они выполняются локально (`apps/mobile/integration_test/`).
3. DevTools-профилирование: нет скриншотов frame time и memory до/после
   (Phase 16 открыта); нужен прогон на устройстве.
4. Dart-задачи недели 1 и `flutter doctor` как доказательства в репозитории отсутствуют.
5. Эскизы экранов до реализации (Figma или рисунок) не приложены как файлы; есть только
   рендеры реализованных экранов.
6. mocktail не используется (ручные fakes); при требовании недели 13 буквально —
   добавить в `dev_dependencies` и применить в одном-двух unit-тестах.
7. Согласование темы №28 с преподавателем не подтверждено документально.
