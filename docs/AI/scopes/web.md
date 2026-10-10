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
  Save фиксирует basis/content/notes/mutation ID до transaction; unknown retry
  сначала подтверждает ту же операцию. Новые правки во время Save/после ошибки
  остаются в buffer и требуют отдельного Save; ACK не заменяет поздний ввод.
  Document base review захватывает UID, сохранённую basis base, saved document и
  buffer. Apply проверяет их неизменность, фото URL/path переносит одной парой;
  dialog показывает captured строки и блокирует фоновые Save/Cancel/exit.
  Поздний media ACK сохраняет ввод, но делает прежний review устаревшим.
- `src/lib/publication.ts` вызывает trusted Node HTTP API с ID token;
  operation ID, inventory version/generation и saved mutation защищают retry/races.
  UID-scoped metadata receipts сохраняются в `localStorage` с readback и защитой
  от другой вкладки; неизвестный результат повторяется с тем же ID. Квитанция
  доказывает действие, текущая publication metadata может уже отражать другой клиент.
  Не хранить password/token в приложении, не выводить credentials.
  После получения ID token повторно проверять UID до отправки HTTP mutation;
  поздние ответы не изменяют состояние/квитанцию завершённой owner session.
- `/d/[publicId]` читает только anonymous `publicDocuments` snapshot; отсутствие
  и withdrawn отображаются без private lookup. Public parser allowlist и безопасные
  media/contact URL обязательны; никогда не вставлять raw HTML.
  Metadata и body используют один request-scoped snapshot без постоянного cache.
  OG/Twitter фото проходит public media guard; config/service failure имеет
  unavailable/noindex state, missing/withdrawn — 404/noindex.
- Auth route guard служит UX; права обеспечивают Rules и trusted backend. Смена UID
  очищает private state, несохранённый ввод требует подтверждения перед discard.
- Phase 14 Contact/Inbox — [ADR 0004](../../decisions/0004-contact-inbox-notifications.md).
  ContactForm только при visible projected typed contact; server проверяет текущую
  публикацию повторно. `contact-repository.ts` получает limited-use App Check token;
  emulator bypass ограничен demo project. Captured submit/requestId сохраняются при
  unknown retry, поздний ввод не стирается ACK. Ответ не содержит owner UID.
  Live Spark использует бесплатный reCAPTCHA Enterprise Essentials provider;
  site key и intended appId берутся из actual registered web app.
  SSR Next.js и Node API размещаются самостоятельно без Cloud Functions/App Hosting;
  временный HTTPS tunnel подтверждает только dev acceptance, не постоянный hosting.
  Private Inbox читает server-only `accounts/UID/contactRequests`, ≤50 newest-first,
  strict parser принимает exact10 fields; update только readAt serverTimestamp.
  Inbox доступен из Settings/hash, не зависит от draft и не добавляет root-вкладку.
  После awaited чтения проверять UID и generation; browser push не подключён.
- Проверять typecheck, meaningful contract tests и build из `apps/web`.
  Prettier config/scripts в `apps/web` задают формат новых TS/CSS. `agentRules:false`
  в Next config сохраняет тонкий AGENTS adapter; AI guidance остаётся в `docs/AI`.
  По D048 пользователь разрешил browser/dev server и native проверки в этой задаче.
  Исторические проверки с no-preview/run остаются историей. Build/headless tests
  не означают Figma visual/device/live acceptance.
