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
- Использовать `npm ci` для web, firebase и functions, Flutter
  `pub get --enforce-lockfile`. npm остаётся canonical package manager CI;
  неиспользуемые pnpm lock/workspace удалены, второй dependency graph не поддерживается. Firebase CLI — точная
  devDependency в `firebase/package.json`, без global/latest установки CLI.
  npm закреплён `packageManager` в трёх package manifests; workflow устанавливает
  эту версию до `npm ci`, backend и firebase используют одну версию.
- Cross-client Flutter tests требуют предварительного `npm ci` в `apps/web`.
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
