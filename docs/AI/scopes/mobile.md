# Правила StackCard Mobile

Область этих правил — `apps/mobile/`.

Общие правила и границы текущей фазы наследуются из [общих правил](../AGENTS.md).
Перед изменениями прочитай [общий AI router](../README.md) и применимые
guides. Этот файл дополняет их только для Flutter-приложения.

## Источники

- SDK constraint и зависимости: [pubspec.yaml](../../../apps/mobile/pubspec.yaml); разрешённые версии:
  [pubspec.lock](../../../apps/mobile/pubspec.lock). Не добавлять неиспользуемые зависимости.
- Анализ: [analysis_options.yaml](../../../apps/mobile/analysis_options.yaml).
- Entry point: [lib/main.dart](../../../apps/mobile/lib/main.dart); GoRouter:
  [app_router.dart](../../../apps/mobile/lib/app/app_router.dart), app shell:
  [app_shell.dart](../../../apps/mobile/lib/app/app_shell.dart).
  Native entry запускает `StackCardBootstrap`:
  [LocalRuntime](../../../apps/mobile/lib/app/local_runtime.dart) читает settings и
  открывает [LocalStorage](../../../apps/mobile/lib/core/storage/local_storage.dart)
  до создания `StackCardApp`. Ошибка startup показывает loading/error/retry;
  storage закрывается при disposal, включая поздно завершившееся открытие.
- Цвета, typography и tokens: [core/theme](../../../apps/mobile/lib/core/theme/);
  общие UI-компоненты: [shared/widgets](../../../apps/mobile/lib/shared/widgets/).
  Перед новым widget искать существующий аналог и использовать `context.colors`.
- ThemeMode/Locale/preferences: [AppearanceController](../../../apps/mobile/lib/core/state/appearance_controller.dart)
  через Provider; pure Dart [AppSettings](../../../apps/mobile/lib/core/state/app_settings.dart)
  и [SettingsRepository](../../../apps/mobile/lib/core/state/settings_repository.dart)
  находятся в нейтральном `core/state`. Query/filter state Projects:
  [project_filters.dart](../../../apps/mobile/lib/features/projects/presentation/project_filters.dart)
  через Riverpod. Не дублировать эти значения в widget state или router callbacks.
  Provider ограничивается базовыми app settings. UI использует реальные ru/en
  переводы из [core/localization](../../../apps/mobile/lib/core/localization/);
  source content не переводится автоматически. Сравнение и учебные patches — в
  [state management guide](../../learning/state-management.md), вне runtime `lib`.
- Settings persistence:
  [SharedPreferencesSettingsRepository](../../../apps/mobile/lib/features/settings/data/shared_preferences_settings_repository.dart)
  использует SharedPreferencesAsync для одного versioned snapshot theme/language/
  source descriptions. Controller последовательно сохраняет последнее состояние;
  failure оставляет выбор в UI с retry. Corrupt/unknown preferences дают defaults;
  пользовательский draft не хранится в preferences.
- Feature APIs: [auth.dart](../../../apps/mobile/lib/features/auth/auth.dart),
  [profile.dart](../../../apps/mobile/lib/features/profile/profile.dart),
  [projects.dart](../../../apps/mobile/lib/features/projects/projects.dart),
  [github_import.dart](../../../apps/mobile/lib/features/github_import/github_import.dart),
  [portfolio_draft.dart](../../../apps/mobile/lib/features/portfolio_draft/portfolio_draft.dart),
  [portfolio.dart](../../../apps/mobile/lib/features/portfolio/portfolio.dart).
  Между features импортировать только публичные APIs; `domain` остаётся pure Dart.
  Presentation использует domain и providers, data реализует repository contracts.
- DI находится у корня feature: auth/projects providers и profile dependencies
  связывают concrete demo/mock repositories. Widgets не импортируют data sources.
  `StackCardApp.providerOverrides` передаётся своему ProviderScope и позволяет
  менять источник для реальных экранов. Native `LocalRuntime` подставляет Hive
  cache/draft adapters; memory defaults сохраняют изоляцию тестов `StackCardApp`.
  Не дублировать DI в widgets и не открывать boxes из экрана.
- Демонстрационные данные принадлежат
  [DemoAuthRepository](../../../apps/mobile/lib/features/auth/data/demo_auth_repository.dart),
  [MockProfileRepository](../../../apps/mobile/lib/features/profile/data/mock_profile_repository.dart) и
  [MockProjectsRepository](../../../apps/mobile/lib/features/projects/data/mock_projects_repository.dart).
  Demo-вход не авторизует аккаунт; эти источники не обращаются к GitHub/backend
  и не сохраняют draft. GitHub Import имеет отдельный публичный HTTP-источник.
- GitHub Import: [contract](../../architecture/architecture.md#github-import-http-и-persistent-кэш)
  и [DI](../../../apps/mobile/lib/features/github_import/github_import_providers.dart).
  Dio/JSON/cache — data; бизнес-модели и username/selection — pure Dart domain;
  cancellable loading/refresh/pagination/debounce — Riverpod controller.
  API next links валидируются по host и identity профиля. Только явный retry,
  rate deadline блокирует запросы; поиск ограничен загруженными страницами.
  Async [response cache contract](../../../apps/mobile/lib/features/github_import/data/github_response_cache.dart)
  используется для ETag/304;
  [Hive adapter](../../../apps/mobile/lib/features/github_import/data/hive_github_response_cache.dart)
  хранит versioned body/ETag/Link по URI. Hard TTL — 7 дней с успешного `200/304`;
  network-first fallback разрешён только для network/timeout/server. Expired,
  corrupt, future-dated и unknown-schema cache entries исключаются из fallback.
  Публичный [GitHubReadMetadata](../../../apps/mobile/lib/features/github_import/domain/github_read_metadata.dart)
  сообщает источник, дату и storage failures; смешанные страницы сохраняют
  предупреждение. Отмена проверяется после storage awaits и перед fallback.
- Local notes draft: публичный `portfolio_draft.dart` раскрывает pure Dart
  `PortfolioDraft`/repository и экран `/portfolio-draft`; сохраняются только notes,
  revision, UTC updatedAt и pendingSync. Полный Builder — Phase 6, remote sync
  ещё не подключён. Session controller сохраняет несохранённый ввод при навигации,
  явный Save и retry — действия repository.
  [HivePortfolioDraftRepository](../../../apps/mobile/lib/features/portfolio_draft/data/hive_portfolio_draft_repository.dart)
  сериализует записи; corrupted/unsupported draft сохраняет исходную запись и
  блокирует перезапись. GitHub cache и draft используют отдельные boxes:
  cache можно удалить/восстановить, draft не затрагивается. LocalStorage сохраняет
  нечитаемый cache file как backup; повреждённый draft не обрезается автоматически.
- [PortfolioOverview](../../../apps/mobile/lib/features/portfolio/presentation/portfolio_overview.dart)
  объединяет profile/projects для Home, Portfolio и preview; query/filter Projects
  не влияет на полный или featured список других экранов. Это presentation read model,
  не draft/published domain. `ProfileReadiness` — demo-snapshot счётчиков; Builder
  и алгоритм полноты вводятся на Phase 6.
- Loading/error/retry: [StackCardAsyncView](../../../apps/mobile/lib/shared/widgets/stackcard_async_view.dart)
  использует существующий StackCardStateView; empty принадлежит экрану.
  Асинхронные запросы повторяются явно через UI retry; сетевой GitHub Import
  показывает typed failure и сохраняет успешный список при refresh/page failure.
- UI checks: [widget_test.dart](../../../apps/mobile/test/widget_test.dart),
  [responsive_test.dart](../../../apps/mobile/test/responsive_test.dart).
- State checks: [appearance_controller_test.dart](../../../apps/mobile/test/appearance_controller_test.dart),
  [project_filters_test.dart](../../../apps/mobile/test/project_filters_test.dart),
  [state_management_test.dart](../../../apps/mobile/test/state_management_test.dart).
  При смене владельца состояния проверять навигацию, reset и новую app session.
- Repository/DI checks: `test/auth_repository_test.dart`, `test/auth_di_test.dart`,
  `test/profile_repository_test.dart`, `test/profile_di_test.dart`,
  `test/projects_repository_test.dart`, `test/projects_di_test.dart`.
  Проверять замену источника на реальных экранах, immutable outputs,
  loading/error/empty и явный retry. Учебные patches должны сохранять Phase 3 DI.
- GitHub checks: `test/github_data_test.dart`, `test/github_import_controller_test.dart`,
  `test/github_import_widget_test.dart`; проверять parsing/cache/HTTP errors,
  cancellation/races, deadline/debounce/pagination, пустые данные и responsive UI.
- Persistence checks: `test/github_persistence_test.dart`, `test/local_storage_test.dart`,
  `test/local_runtime_widget_test.dart`; проверять реальный reopen, TTL boundary,
  offline/reconnect/304, изоляцию draft, повреждённые файлы и bootstrap lifecycle.
  `test/settings_persistence_test.dart`, `test/localization_test.dart` проверяют
  settings restore/write retry и ru/en UI. Draft repository/controller/widget
  проверяются в `test/portfolio_draft_repository_test.dart`,
  `test/portfolio_draft_controller_test.dart`, `test/portfolio_draft_widget_test.dart`:
  revision, input retention, unknown schema, Save failures и навигация.
- Локальные шрифты и лицензии: [assets/fonts](../../../apps/mobile/assets/fonts/);
  регистрация остаётся в pubspec. Logo paths повторяют оригиналы branding.
- Native configs находятся в platform directories этого приложения.
  Generated-файлы и `.metadata` вручную не редактировать.

Flutter/Dart-команды выполнять из `apps/mobile`; Git — из корня monorepo.
Платформы приложения — только Android и iOS; platform directories — `android/`
и `ios/`. Сайт и web-редактор планируются отдельно в `apps/web` на Next.js.
Проверки format/analyze/tests и порядок разработки описаны в
[CONTRIBUTING](../../../CONTRIBUTING.md); запуск — в его
[быстром старте](../../../CONTRIBUTING.md#быстрый-старт).
Границы mobile и web определены в [architecture](../../architecture/architecture.md).
