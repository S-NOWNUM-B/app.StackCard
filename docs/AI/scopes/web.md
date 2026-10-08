# Web rules StackCard

Читайте [общие правила](../AGENTS.md), [router](../README.md),
[архитектуру](../../architecture/architecture.md) и [Web README](../../../apps/web/README.md).
Последнее поручение пользователя разрешает web и явную публикацию; deploy отдельный.

- Runtime — `apps/web/src/app`, shared controls — `src/components/ui.tsx`, tokens —
  `src/app/globals.css`. Сохранять Figma R6 Brand A, Lime, локальный Manrope,
  исходные SVG/font bytes и лицензии в `public`. Screenshot не runtime asset.
- `src/lib/model.ts` реализует тот же JSON aggregate mobile PortfolioContent:
  root base/Projects Library, independent document snapshots и attachments.
  Версии и команды берутся из `apps/web/package.json`, env — из `.env.example`.
- `src/lib/firebase.ts` и `draft-repository.ts` — UID-bound client SDK. Web
  online-first: server read, CAS transaction по captured basis, ошибки сохраняют
  ввод. Unknown fields/schema, malformed data и foreign media блокируют запись.
  Draft save не публикует. Нельзя добавлять второй private schema или SSR private data.
- `src/lib/publication.ts` вызывает trusted Firebase HTTP API с ID token;
  operation ID, inventory version/generation и saved mutation защищают retry/races.
  UID-scoped metadata receipts сохраняются в `localStorage` с readback и защитой
  от другой вкладки; неизвестный результат повторяется с тем же ID. Квитанция
  доказывает действие, текущая publication metadata может уже отражать другой клиент.
  Не хранить password/token в приложении, не выводить credentials.
- `/d/[publicId]` читает только anonymous `publicDocuments` snapshot; отсутствие
  и withdrawn отображаются без private lookup. Public parser allowlist и безопасные
  media/contact URL обязательны; никогда не вставлять raw HTML.
- Auth route guard служит UX; права обеспечивают Rules и trusted backend. Смена UID
  очищает private state, несохранённый ввод требует подтверждения перед discard.
- Проверять typecheck, meaningful contract tests и build из `apps/web`.
  Prettier config/scripts в `apps/web` задают формат новых TS/CSS. `agentRules:false`
  в Next config сохраняет тонкий AGENTS adapter; AI guidance остаётся в `docs/AI`.
  По D048 пользователь разрешил browser/dev server и native проверки в этой задаче.
  Исторические проверки с no-preview/run остаются историей. Build/headless tests
  не означают Figma visual/device/live acceptance.
