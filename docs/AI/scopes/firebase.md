# Firebase rules StackCard

Перед работой прочитай [общие правила](../AGENTS.md), [router](../README.md),
[Firestore contract](../../architecture/architecture.md#source-draft-и-публикация)
и [ADR 0001](../../decisions/0001-firestore-sync-and-publication.md).
Scope и фактическая приёмка остаются в [product spec](../../product/product-spec.md).

## Владельцы источников

- [firebase.json](../../../firebase/firebase.json) владеет Rules/indexes paths
  и Emulator Suite configuration; [package.json](../../../firebase/package.json)
  и lockfile — отдельными Rules tests. Mobile SDK dependencies находятся в
  `apps/mobile/pubspec.yaml`, generated app config — в `apps/mobile`.
- [firestore.rules](../../../firebase/firestore.rules) ограничивает private
  account/draft по UID, anonymous exact get public snapshots, запрет public list/
  client write, lifecycle account lock и deleted document tombstones.
  Owner inventory list разрешён только `accounts/UID/publications`.
- [firestore.indexes.json](../../../firebase/firestore.indexes.json) — canonical
  indexes; не добавлять индексы без реального запроса.
- Pure Dart contracts, UID-bound Firestore adapters и Hive outbox принадлежат
  `apps/mobile/lib/features/portfolio_draft`. Runtime composition — LocalRuntime.
  Не переносить SDK в domain или widgets и не дублировать cloud schema.
- [Backend](../../../firebase/functions/) владеет authenticated HTTP
  `documentPublication`: ID token/UID, CORS origin, authoritative saved mutation,
  deep workspace validation/privacy projection, permanent ID, operation CAS/recovery,
  immutable public media и delete lifecycle. [Manifest](../../../firebase/functions/package.json)
  и [.env.example](../../../firebase/functions/.env.example) — runtime/commands/origin.
  Live Spark использует `src/server.mjs` и `npm start` с private ADC/HMAC env;
  `src/index.mjs` — прежний Functions adapter только для demo emulators.
  Cloud Functions/App Hosting/Storage/TTL live не развёртывать: требуют billing.
  Без Storage разрешён text-only Publish; media операции и account delete
  завершаются configuration error до необратимой записи.
  Admin SDK обходит Rules; server validation tests обязательны отдельно.
- [storage.rules](../../../firebase/storage.rules) и `features/media` владеют
  Phase 11 private image доступом. Path `accounts/{uid}/media/{32hex}.jpg`:
  owner get/create/delete при active account, immutable objects, JPEG до 2 MiB;
  list закрыт. `publicMedia/publicId/version/32hex.jpg` создаёт только handler,
  anonymous get требует current publicDocument version; list/client write запрещены.
  App читает SDK bytes без download tokens. Bearer URL при раскрытии
  владельцем Rules не защищают. Контракт/cleanup —
  [ADR 0003](../../decisions/0003-private-portfolio-media.md).

## Изменение и проверка

- Phase 14 `contactInbox` и trusted FCM sender следуют
  [ADR 0004](../../decisions/0004-contact-inbox-notifications.md). Anonymous submit
  требует consumed App Check intended appId и HMAC secret; bypass только actual
  emulator + demo project с actual loopback Auth/Firestore hosts. Transaction перепроверяет active account,
  current publication/contact privacy, idempotency и quotas. Owner collection
  contactRequests отдельна от draft, exact10 fields; list ≤50, update только readAt.
  Private hashed device bindings допускают один UID на token; register/revoke
  authenticated, sender использует только актуальную active binding. Generic push
  без имени/email/message; delivery failure не удаляет обращение.
  HTTP submit вызывает sender после commit; receipt обеспечивает максимум один
  transport attempt, matching retry восстанавливает только ещё не начатый send.
  `expiresAt` — metadata rate window, без платной Firestore TTL policy. Account cleanup
  удаляет и глобальные bindings. Emulator/mocks не доказывают live FCM delivery.

- Private notes/account data не смешивать с public snapshot; hidden content
  удаляется public projection перед записью, а не только скрывается renderer.
  Source snapshots, override flags и Ignore registry также private и удаляются
  public codec. Private writer schema 6 читает 1–6; Rules запрещают downgrade,
  legacy publicPortfolios schema1 сохраняется, новый publicDocuments schema1
  отдельный и исключает notes/owner/baseSnapshot/source/hidden/private paths. Documents list
  ограничен 20; Rules проверяют owner media path каждого snapshot/baseSnapshot, codec —
  структуру, ID и Library/resume relations. Schema5 проверяет пару canonical avatar
  paths одним RE2 matcher с literal UID quoting, включая вложенный `\E`, чтобы
  20 документов укладывались в бюджет выражений. Legacy отсутствие baseline key
  допускается; explicit null при новом cloud write отклоняется. Проверять
  adversarial UID и foreign path в последнем элементе. Новый document handler
  дополнительно рекурсивно валидирует nested структуру до public write. Public
  collection limit200 применяется после visibility/privacy projection; private
  база не ограничивается200 поверх прежних field/document/Firestore-size limits.
  Attached Resume требует видимую Resume секцию и отдельно published target. GitHub миграция — в
  [ADR 0002](../../decisions/0002-github-import-and-review.md), media — в ADR 0003.
- Publish/Update/Unpublish используют owner/document permanent mapping и
  request fingerprint/expected mutation/version/generation. Server transaction
  повторяет CAS после media copy, public snapshot и inventory активируются вместе.
  Rename/republish сохраняют `/d/<publicId>`, duplicate не наследует mapping.
  Sync не вызывает publication repository. Legacy usernames/publicPortfolios
  client writes закрыты; existing snapshots не мигрируют автоматически.
- `deleteDocument` withdraw/delete draft сохраняет account tombstone ID; Rules
  не допускают поздний draft с удалённым ID. Delete account ставит protected
  lifecycle lock до cleanup и удаляет Auth identity последней; minimal recovery
  receipt без content и hash recovery key остаются. Restricted deletionStatus
  допускает только status/retry той же подготовленной операции по 256-bit key,
  даже после утраты Auth; raw key/credentials на server не сохраняются. Ни клиент,
  ни legacy adapter не снимают lock.
- Username и schema validation должны совпадать с domain/ADR. Rules allowlist
  не заменяет полную validation элементов списков в codec.
- Explicit guest transfer требует пустой local/cloud target и online
  create-if-absent transaction; обычный LWW sync не заменяет эту проверку.
  Durable owner journal предшествует cloud claim; retry проверяет тот же
  mutation ID/notes/content. ACK metadata и syncPrepared сохраняются до local
  cleanup; completed claim не повторяется при recovery. Offline cache miss
  не разрешает перезапись существующего remote draft.
  Подтверждённый occupied-cloud conflict освобождает unfinished transfer journal
  до local commit при отсутствии destination; matching validated ACK metadata
  удаляется, guest/cloud данные сохраняются. Неоднозначный network failure
  оставляет source reserved за прежним UID для retry.
- Rules tests выполняются на demo project через Emulator Suite; owner,
  foreign/anonymous denial, direct public write/list, tombstones/account lock проверяются
  через client SDK с Rules, не Admin SDK bypass.
- `test:all-rules` запускает Auth/Firestore/Storage emulators и весь firebase test
  glob, включая publication service integration; `test:service` — только реальный
  service с Admin SDK на demo Auth/Firestore/Storage. `test:storage` — Storage,
  `test:rules` сохраняет Firestore-only contract. Native media SDK acceptance
  использует Auth/Storage emulators и отдельные named apps; системный picker,
  отказ permissions и live bucket требуют отдельной приёмки. Billing/deploy
  автоматически не выполняются; Spark-only правило обязательно. Для handler из `firebase/functions` — `npm run check`
  и `npm test`; команды полного emulated integration берутся из actual manifest.
- Native acceptance имеет explicit opt-in, отдельный test storage/disposable
  accounts и `--no-uninstall`; обычный app draft/session не очищаются.
- Команды и предусловия находятся в
  [CONTRIBUTING](../../../CONTRIBUTING.md#firestore-rules-и-native-sync-acceptance).
  Emulator tests не доказывают live SDK flow; native Android не доказывает iOS.
- Перед deploy проверить Rules tests и явный project target. Deployment выполнять
  только в разрешённом scope настройки окружения; billing upgrade, публичный UI
  и функции будущих фаз не включать автоматически. Credentials/tokens/signing
  keys не хранить в repo и не выводить при проверках.

При изменении schema, SDK/env contract или scripts обновлять ADR/architecture,
mobile rules и CONTRIBUTING в той же задаче. Результаты проверок записываются
ведущим в product spec по фактам, без автоматической отметки завершения фазы.
