# ADR 0004: обращения по опубликованным документам и mobile notifications

Статус: принято для Phase14 по поручению пользователя 2026-10-09
«переходи к следующей фазе разработки». Приёмка доставки на устройстве и
production deploy отдельно; открытые проверки Phase13 сохраняются.

## Контракт

- `contactInbox` — trusted HTTP Function. Public `submit` принимает только
  `action`, `publicId`, `requestId` (32 lowercase hex), `name` (1–100), `email`
  (valid address, до 254), `message` (1–4000), `website` (пустой honeypot).
  Visitor name single-line без controls; email lowercase, message CRLF→LF,
  outer whitespace удаляется. Published documentTitle и stable documentId
  сохраняются буквально по существующему snapshot contract (120/200 символов).
  Ответ только `{status:'accepted',requestId}`; UID/адрес владельца не возвращаются.
- Форма разрешена, только если текущий `publicDocuments/publicId` имеет видимый
  `links` block и хотя бы один projected typed contact `email`/`phone`/`telegram`.
  Hidden/private links не дают разрешения. Existing public schema1 не меняется.
  Server находит private owner publication по publicId и проверяет её состояние,
  current public snapshot и active account внутри transaction.
- Production submit требует Firebase App Check limited-use token, server
  `consume:true`, intended web app ID и HMAC secret для rate keys. Отсутствующая
  конфигурация закрывает submit. Исключение только для actual Functions emulator
  в `demo-` project; client flag сам по себе не отключает защиту.
- Payload allowlist/размер/honeypot + transaction limits: 5 обращений на publicId
  за 10 минут, 30 за сутки, 3 на publicId/sender email за час. Sender email rate key
  HMAC; rate docs не содержат raw email/message/IP, expiresAt для TTL.
  Fixed windows не обещают идеальную защиту от всех видов spam/DoS.
- Повтор с тем же requestId и тем же normalized payload не создаёт новое
  обращение/notification и не увеличивает quota; иной payload с этим ID отклоняется.
  Accepted durable retry подтверждается и после withdrawal, при active owner и
  прежнем private mapping; новое обращение требует current published contact.
  Browser retry захватывает immutable payload/ID, поздний ввод сохраняет отдельно.
- `accounts/{uid}/contactRequests/{requestId}` содержит ровно `schemaVersion:1`,
  `requestId`, `publicId`, `documentId`, `documentTitle`, `name`, `email`, `message`,
  `createdAt` (server timestamp), `readAt` (null/server timestamp).
  Отправитель не авторизован как владелец email; UI отмечает это.
- Owner-only SDK get/list с active account; list newest-first/limit ≤50, pagination
  по createdAt/document ID. Owner может менять только readAt на request.time.
  Client create/delete/изменение sender/content запрещены. Account delete удаляет
  обращения/registrations прежним recursive cleanup; draft schema не меняется.

## Notifications

- Authenticated `contactInbox` actions `registerDevice`/`unregisterDevice`
  принимают `token` (1–4096), register дополнительно `platform:'android'|'ios'`.
  Server records: private `accounts/uid/pushDevices/<sha256(token)>`; private
  `pushTokenOwners/<sha256(token)>` связывает token с одним UID. Rebind переносит
  token из предыдущего account атомарно; максимум 10 registrations на account.
  Client напрямую tokens не читает/не пишет; SDK/app logs их не выводят.
  Valid Auth owner может зарегистрироваться до создания root account; locked/deleted
  lifecycle блокирует device actions. Submit и sender требуют существующий active root.
  Оба authenticated actions возвращают только `{status:'completed'}`.
- Trusted Firestore on-create handler отправляет FCM после durable Inbox write.
  Generic notification, data `{type:'contactRequest',requestId,ownerUid}`;
  sender/email/message не входят в push. Проверять active owner/token binding
  перед отправкой, удалять invalid registrations. Notification failure не
  удаляет обращение. Durable attempt receipt подавляет повторный transport trigger;
  transient failure автоматически не повторяется, FCM не гарантирует exactly-once.
  Уже начатый внешний send нельзя отменить последующей сменой UID; generic payload
  и client UID tap gate защищают это окно. Server transport подменяется в tests; live FCM acceptance
  этим не доказывается.
- Mobile просит permission только по явному действию; показывает actual
  denied/authorized/unavailable и registration failure. Использует token refresh,
  foreground event, getInitialMessage/onMessageOpenedApp. Tap допускается только
  при совпадении captured owner/current UID и валидном requestId.
- При UID transition очищаются Inbox/private state/subscriptions/pending tap,
  прежний token отключается/удаляется. Enable/disable и late token futures
  проверяют captured UID/generation. Offline cleanup failure показывается;
  generic push не раскрывает прежний contact payload. Inbox работает без push.
- `/inbox` и `/inbox/:requestId` — standalone guarded routes, вход через Settings,
  без пятой root вкладки. Web Inbox внутри owner workspace, без browser push.

## Проверки и эксплуатация

Pure validation/privacy/idempotency/rate tests; actual demo Firestore SDK Rules
owner/foreign/anonymous/readAt/list-limit tests; real service transaction tests.
Client tests: strict parser/UID/late callback/permission denied/notification tap.
Browser public submit → web Inbox → read; mobile repository/widget integration.

Для публичного открытия нужны deployed Rules/indexes/Functions, configured
App Check provider/site key/intended app ID/token verifier IAM и HMAC secret;
для FCM — native Firebase project/provider/APNs capability и device delivery.
До этого UI сообщает unavailable; configuration/deploy/billing не выполняются
автоматически. Локальный demo path проверяет feature, не production protection.

API сверены по [App Check replay protection](https://firebase.google.com/docs/app-check/custom-resource-backend#replay_protection_beta)
и [Flutter FCM interaction](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages#handling_interaction).
