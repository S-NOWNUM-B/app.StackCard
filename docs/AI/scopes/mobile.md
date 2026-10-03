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
- Цвета, typography и tokens: [core/theme](../../../apps/mobile/lib/core/theme/);
  общие UI-компоненты: [shared/widgets](../../../apps/mobile/lib/shared/widgets/).
  Перед новым widget искать существующий аналог и использовать `context.colors`.
- ThemeMode: [AppearanceController](../../../apps/mobile/lib/core/state/appearance_controller.dart)
  через Provider. Query/filter state Projects:
  [project_filters.dart](../../../apps/mobile/lib/features/projects/project_filters.dart)
  через Riverpod. Не дублировать эти значения в widget state или router callbacks.
  Provider ограничивается базовыми настройками ThemeMode/Locale; Locale вводится
  только вместе с переводами. Сравнение и учебные patches — в
  [state management guide](../../learning/state-management.md), вне runtime `lib`.
- Демонстрационные данные: [mock_portfolio.dart](../../../apps/mobile/lib/shared/mock_portfolio.dart).
  Demo-вход и UI действия не обращаются к GitHub/backend и не сохраняют draft.
- UI checks: [widget_test.dart](../../../apps/mobile/test/widget_test.dart),
  [responsive_test.dart](../../../apps/mobile/test/responsive_test.dart).
- State checks: [appearance_controller_test.dart](../../../apps/mobile/test/appearance_controller_test.dart),
  [project_filters_test.dart](../../../apps/mobile/test/project_filters_test.dart),
  [state_management_test.dart](../../../apps/mobile/test/state_management_test.dart).
  При смене владельца состояния проверять навигацию, reset и новую app session.
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
