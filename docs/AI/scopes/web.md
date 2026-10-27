# Web rules StackCard

Читайте [общие правила](../AGENTS.md), [router](../README.md),
[архитектуру](../../architecture/architecture.md) и [Web README](../../../apps/web/README.md).
Последнее поручение — [ADR 0005](../../decisions/0005-single-main-portfolio.md):
один main portfolio, Home/Projects/Editor, cloud7 и public2, optional onboarding,
Firestore avatar, catalog icons и настоящий PDF. Home использует saved basis,
scoped Library imports/deletes не записывают unsaved Editor. Legacy documents
архивируются без удаления/автопубликации. Deploy отдельный.
Порядок пяти разделов main берётся из `document.content.blocks` через
`mainPortfolioSectionOrder`; owner preview, public projection и PDF сохраняют
mobile Save. Profile остаётся первым, GitHub следует вместе с контактами;
новая версия schema для перестановки не нужна.

- Runtime — `apps/web/src/app`, shared controls — `src/components/ui.tsx`, tokens —
  `src/app/globals.css`.
  Кабинет (2026-10-26) повторяет функции mobile Editor/Home/Projects, вёрстка своя:
  разделы — `editor-card.tsx`, перестановка мышью/touch/клавиатурой —
  `sortable-list.tsx`, каталог технологий — `src/lib/technology-catalog.ts`
  (данные mobile `technology_catalog_data.dart`), QR визитки — `src/lib/qr-code.ts`.
  Новую функцию mobile переносить в web вместе с ней.
  Пунктуация владельца: в заголовках и в конце последнего предложения текстового
  блока (абзац, подпись, кнопка, сообщение) точки нет; точки между предложениями
  и знаки `?`/`!` сохраняются. Двухстрочные display-заголовки и надзаголовки
  пишутся вовсе без знаков препинания — при необходимости фраза переформулируется.
  Демо-данные сайта без вымышленных персон: имя `DEMO_PROFILE_NAME` («Ваше имя»)
  из `document-view.tsx`, профиль GitHub — `username`.
  Пары действий используют `.dialog-actions`: «Отмена» слева, основное действие
  справа; вся группа выровнена вправо. Подтверждения — shared
  [confirmation dialog](../../../apps/web/src/components/confirmation-dialog.tsx)
  с «Подтвердить» и повторной проверкой owner/state после await. Save/Close/Finish —
  по [design contract](../../design/design-system.md#действующий-runtime-contract-r8).
  Поручение 2026-10-11 заменяет web target R6 светлой
  композицией по Openship: белые поверхности, чёрные CTA, русские тексты StackCard.
  [Web brief](../../redesign/web-openship.md) задаёт страницы и границы переноса.
  Сохранять Brand A, локальный Manrope, исходные SVG/font bytes и лицензии в `public`.
  Screenshot не runtime asset. Web всегда light; переключателей dark нет.
  Действующий [Brand A kit](../../../assets/branding/stackcard-v2-brand-kit.json) —
  монохромный: Ink wordmark/mark, MonoDark favicon; Accent/Link assets — история.
  Shared `dark | light` schema сохраняется для mobile и старых данных: чтение
  не меняет сохранённую тему, новые документы получают light. Web одобрен
  пользователем; последующее поручение переносит white-only/ru дизайн в Flutter.
- `src/lib/model.ts` реализует тот же JSON aggregate mobile PortfolioContent:
  root Projects Library, mainPortfolioId, GitHub identity/onboarding и legacy backup.
  GitHub identity — Settings/onboarding, без поля в ContentEditor; обычный
  Save портфолио не применяет ввод `githubInput` из настроек.
  GitHubImporter использует сохранённый источник и ведёт в Settings, если его нет;
  собственная форма identity Save не дублируется.
  Версии и команды берутся из `apps/web/package.json`, env — из `.env.example`.
- `src/lib/firebase.ts` и `draft-repository.ts` — UID-bound client SDK. Web
  online-first: server read, CAS transaction по captured basis, ошибки сохраняют
  ввод. Unknown fields/schema, malformed data и foreign media блокируют запись.
  Draft save не публикует. Нельзя добавлять второй private schema или SSR private data.
  Save фиксирует basis/content/notes/mutation ID до transaction; unknown retry
  сначала подтверждает ту же операцию. Новые правки во время Save/после ошибки
  остаются в buffer и требуют отдельного Save; ACK не заменяет поздний ввод.
  Совместимый legacy document base review захватывает UID, сохранённую basis base, saved document и
  buffer. Apply проверяет их неизменность, фото URL/path переносит одной парой;
  dialog показывает captured строки и блокирует фоновые Save/Cancel/exit.
  Поздний media ACK сохраняет ввод, но делает прежний review устаревшим.
- [Media repository](../../../apps/web/src/lib/portfolio-media-repository.ts) хранит
  новый avatar в owner-only Firestore. PDF читает private path первым; legacy URL
  без path загружается только браузером с CORS, bounded stream≤2MiB/10s, без
  credentials/redirects/local hosts и с MIME/dimensions/JPEG512 preprocessing.
  Не добавлять server proxy и не скрывать ошибку private path URL fallback.
- `src/lib/publication.ts` вызывает trusted Node HTTP API с ID token;
  operation ID, inventory version/generation и saved mutation защищают retry/races.
  UID-scoped metadata receipts сохраняются в `localStorage` с readback и защитой
  от другой вкладки; неизвестный результат повторяется с тем же ID. Квитанция
  доказывает действие, текущая publication metadata может уже отражать другой клиент.
  Не хранить password/token в приложении, не выводить credentials.
  Trusted publication/contact endpoints требуют HTTPS без credentials/query/fragment;
  loopback HTTP допустим только при emulator mode и project с `demo-` prefix.
  Fetch использует `credentials: omit`, `redirect: error`, чтобы redirect не передал
  token/payload другому адресу. После получения ID token повторно проверять UID до отправки HTTP mutation;
  поздние ответы не изменяют состояние/квитанцию завершённой owner session.
- `/d/[publicId]` читает только anonymous `publicDocuments` snapshot; отсутствие
  и withdrawn отображаются без private lookup. Public parser allowlist и безопасные
  media/contact URL обязательны; никогда не вставлять raw HTML.
  Metadata и body используют один request-scoped snapshot без постоянного cache.
  OG/Twitter фото проходит public media guard; config/service failure имеет
  unavailable/noindex state, missing/withdrawn — 404/noindex.
- Auth route guard служит UX; права обеспечивают Rules и trusted backend. Смена UID
  очищает private state, несохранённый ввод требует подтверждения перед discard.
  Переход ко входу сохраняет owner path и разрешённый workspace hash через
  `safeReturnPath`; ссылки регистрации/восстановления сохраняют тот же returnTo.
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
  CI использует корневую `.node-version`, `packageManager` из manifest и
  `npm ci` по package-lock; общий workflow — [CI scope](ci.md).
  Prettier config/scripts в `apps/web` задают формат новых TS/CSS. `agentRules:false`
  в Next config сохраняет тонкий AGENTS adapter; AI guidance остаётся в `docs/AI`.
  По D048 пользователь разрешил browser/dev server и native проверки в этой задаче.
  Исторические проверки с no-preview/run остаются историей. Build/headless tests
  не означают Figma visual/device/live acceptance.
