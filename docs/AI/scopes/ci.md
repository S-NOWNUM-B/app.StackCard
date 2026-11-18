# CI StackCard

Общие правила — [AGENTS](../AGENTS.md), текущая задача —
[Phase 18](../../product/product-spec.md#phase-18--cicd).

- Workflow — [ci.yml](../../../.github/workflows/ci.yml). Push, pull_request и
  workflow_dispatch запускают все проверки без path filters. `All checks`
  требует success каждого job, включая случаи failure/cancelled/skipped.
  Полный Flutter suite/coverage исполняется на macos-15: SDK pixel contrast
  matcher при Linux FreeType AA ошибочно выбирает оттенки сглаживания Manrope.
  Порог WCAG и весь набор tests сохраняются. Android APK собирается отдельным
  Ubuntu job только после assets/web/firebase/mobile success.
- Flutter закреплён в [`.fvmrc`](../../../.fvmrc), Node — в
  [`.node-version`](../../../.node-version), Java — в
  [`.java-version`](../../../.java-version). Версии менять вместе с проверкой
  actual manifests, lockfiles и локального эквивалента CI. Gradle/AGP/SDK/NDK
  остаются у Android/Flutter; их отдельный дубликат в workflow не вводить.
- Менеджер пакетов JS — pnpm (решение владельца 2026-11-18, заменило прежнее
  правило «npm canonical»). Использовать `pnpm install --frozen-lockfile` для
  web, firebase и functions, Flutter `pub get --enforce-lockfile`. Три проекта
  независимы, workspace не вводится: у каждого свой `pnpm-lock.yaml`;
  `package-lock.json` и второй dependency graph не поддерживаются. Firebase CLI —
  точная devDependency в `firebase/package.json`, без global/latest установки CLI.
  pnpm закреплён `packageManager` в трёх package manifests одной версией
  (`pnpm@12.18.0`: pnpm 12 поддерживает Node 22 по официальной таблице
  совместимости); workflow ставит её через `pnpm/action-setup` (читает manifest).
  Файл `pnpm-workspace.yaml` в каждом проекте хранит только настройки: `overrides`
  (перенесены из npm `overrides`) и явный `allowBuilds` (build-скрипты разрешены
  лишь `esbuild` в web и `re2` в firebase, остальные запрещены явно; защита
  скриптов не отключается). Команды: `pnpm run`, `pnpm --dir functions`, `pnpm exec`.
  Обновления зависимостей (в том числе Dependabot, если подключат) — только в
  формате pnpm и с обновлением соответствующего `pnpm-lock.yaml`.
- Cross-client Flutter tests требуют предварительного `pnpm install --frozen-lockfile`
  в `apps/web`.
  Формат проверяется для `lib test integration_test tool test_driver`, анализ —
  для приложения, полный suite пишет настоящий LCOV. Существующий checker
  требует строго **>40%**, без фильтров и изменения denominator.
- Backend syntax/unit и actual Auth/Firestore/Storage Rules/service suites
  запускаются только на `demo-stackcard-test`, без production credentials.
  Native Android/iOS, browser touch journeys и live hosting этим не принимаются.
- Assets gate расширяет существующий `tools/redesign/check_imports.py`:
  Design v2/Brand A/fonts и весь Simple Icons catalog проходят provenance,
  bytes/SHA256, точный inventory и безопасный vector parser. Нельзя обновлять
  хеши только ради прохождения gate; нужны источник и проверка изменения.
  С 2026-11-18 gate также проверяет, что тёмная палитра `StackCardColors.dark` отдельная
  и содержит тот же набор токенов, что светлая (`dark_palette_errors`); alias Dark=Light
  больше не допускается. Светлая палитра не меняется.
  `tools/release/test_*.py` проверяет согласование выбранного Android Firebase
  client/Dart public key без изменения legacy/iOS и отказ чужого appId/token.
- Actions закреплять полным commit SHA; `contents: read`, checkout без
  сохранения credentials, без `pull_request_target` и write permissions.
  Не добавлять `continue-on-error`/игнорирование exit codes quality steps.
- Artifacts — только debug APK и LCOV/summary по точным путям, срок хранения 7 дней,
  missing artifact — ошибка. Не загружать `.env`, app data, credentials,
  emulator exports, private fixtures, build directories целиком или logs.
- CI не выполняет deployment, release signing/AAB, distribution, billing или
  переход к Phase 19. Git операции требуют отдельного запроса пользователя.
  Публикация workflow и фактический зелёный/красный GitHub run фиксируются
  отдельно от локальной проверки YAML/команд в product spec.

Команды локального повторения и negative gates — в
[CONTRIBUTING](../../../CONTRIBUTING.md#cicd--phase-18).
