# AI router StackCard

Начало: [общие правила](AGENTS.md). Общие правила хранятся в репозитории;
отдельные копии для разных AI-клиентов не требуются.

Перед любой задачей по разработке продукта обязательно прочитай
[план разработки](../product/product-spec.md#план-разработки),
[текущий статус](../product/product-spec.md#статус-и-границы-текущей-работы)
и раздел выполняемой фазы. Порядок работы и переходов задают
[общие правила выполнения плана](AGENTS.md#разработка-по-плану).

| Задача | Читать | Canonical source |
| --- | --- | --- |
| Разработка продукта: scope, фазы, задачи и сценарии | [План разработки](../product/product-spec.md#план-разработки), [Product spec](../product/product-spec.md), [правила фаз](AGENTS.md#разработка-по-плану) | Статус и критерии фазы в product spec, подтверждение пользователя и фактическая реализация |
| Структура/зависимости mobile | [Mobile rules](scopes/mobile.md), [architecture](../architecture/architecture.md), [решения](../decisions/README.md) | `apps/mobile/pubspec.yaml`, `apps/mobile/pubspec.lock`, `apps/mobile/lib`, platform configs |
| Структура и scope web | [Web README](../../apps/web/README.md), [architecture](../architecture/architecture.md) | `apps/web/README.md`; configs/code появятся при создании Next.js-приложения |
| UI и branding | [Design system](../design/design-system.md) | `assets/branding/stackcard-link-brand-kit.json`, SVG; существующие widgets |
| Запуск, lint, tests | [CONTRIBUTING](../../CONTRIBUTING.md#быстрый-старт), [Mobile README](../../apps/mobile/README.md) | `apps/mobile/analysis_options.yaml`, `test`, Flutter SDK |
| State management и учебные этапы | [Mobile rules](scopes/mobile.md), [state management](../learning/state-management.md) | AppearanceController, Projects providers в `apps/mobile/lib`; учебные patches вне runtime |
| Публичное описание проекта | [Root README](../../README.md), [Product spec](../product/product-spec.md) | Назначение, подтверждённые сценарии и фактическая доступность продукта |

Порядок: инструкции → актуальные sources и аналог → непосредственно применимые
skills из доступного каталога → минимальные изменения → проверки и diff.
Если skill недоступен, продолжить по project rules без его установки.

`project-documentation` — единый skill для текста, визуального оформления и
синхронизации docs с реализацией; `project-context-bootstrapper` — для
устойчивых placement/check rules; `codex-subagent-orchestrator` — для независимых
частей при разрешённой делегации. Skill не меняет scope фазы и не добавляет
неиспользуемые зависимости. Новые guides создаются только при реальной необходимости.

Корневой README — публичный обзор StackCard: назначение, аудитория, возможности,
пользовательский путь и принцип работы. Он не содержит дерево
репозитория, roadmap, фазы, команды разработки или внутренние AI-правила.
Принятую редакцию README сохранять: статус реализации раскрывается в product spec,
служебная отметка статуса и отдельный раздел контроля публикации в README не нужны.
Пользовательский путь уже объясняет явную публикацию; готовый релиз не заявляется.
Product spec владеет требованиями и roadmap; architecture — устройством системы
и техническими схемами; CONTRIBUTING — локальным запуском, командами и проверками.

Проектные docs используют центрированную шапку с названием, кратким описанием,
читаемыми badges `for-the-badge` и содержанием. Таблицы добавляются для сопоставлений.
Для viewer с ограничениями SVG используется PNG Shields; alt содержит название
и значение метки. Badge отражает факт или явно помеченный план. CONTRIBUTING и
module README используют тот же визуальный профиль. AGENTS, AI router, ADR и
standalone runbook сохраняют рабочий формат. Источники фактов — code/configs;
оформление не требует переписывать все документы под публичную аудиторию.

В architecture Mermaid-схемы объясняют связи компонентов и границы данных.
Исходники хранятся в `docs/diagrams/*.mmd`; PNG с теми же узлами и связями
позволяет читать их в viewer без поддержки Mermaid. При изменении схемы
обновлять исходник и изображение вместе, проверять отображение. Целевые узлы
и интеграции помечаются планом. Папки проекта сохраняют принятые имена.

AI-контекст и optional registry размещаются в `docs/AI/`; scope rules —
в `docs/AI/scopes/`. Корневой и вложенные AGENTS направляют к ним. Runtime configs и secrets в эту
директорию не переносятся; product/architecture/design guides остаются в `docs/`.
