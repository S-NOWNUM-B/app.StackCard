<div align="center">

# StackCard Design v2 — предпосылки переноса

**Конкретный scope модели, миграции, публикации, media и web для решения пользователя**

![Status partial implementation](https://raster.shields.io/badge/Status-partial_implementation-111111?style=for-the-badge)
![Scope private mobile](https://raster.shields.io/badge/Scope-private_mobile-14161B?style=for-the-badge)

</div>

---

## Содержание

- [Рекомендация и границы решения](#рекомендация-и-границы-решения)
- [Действующий private slice 2026-10-07](#действующий-private-slice-2026-10-07)
- [Проверенный источник и пригодный механизм](#проверенный-источник-и-пригодный-механизм)
- [Предлагаемая модель](#предлагаемая-модель)
- [Migration PR-MIG-01 — один recoverable переход, без потерь](#migration-pr-mig-01--один-recoverable-переход-без-потерь)
- [Publication, URL, delete — отдельный продуктовый пакет](#publication-url-delete--отдельный-продуктовый-пакет)
- [Product tasks, GAP и владельцы источников](#product-tasks-gap-и-владельцы-источников)
- [API compatibility и file ownership](#api-compatibility-и-file-ownership)
- [Последовательность после scope решения](#последовательность-после-scope-решения)
- [Проверки и критерий audit readiness](#проверки-и-критерий-audit-readiness)

---

## Рекомендация и границы решения

С 2026-10-07 D045 пользователь разрешил functional mobile capabilities по
Figma/концепции и поставил последовательную очередь фаз на паузу. Private
модель/навигация/документы развиваются через existing aggregate; принятый ниже
subset отличается от полного proposal. Это не полная приёмка PR-* пакета:
trusted publication/URL, full account/privacy, web и advanced migration/lifecycle
остаются proposed/pending. Deploy/commit/push этим документом не разрешены.
[Product status](../product/product-spec.md#статус-и-границы-текущей-работы)
владеет actual scope и проверками; [R0–R9](plan.md) сохраняет историю acceptance.

Рекомендую полную целевую модель с одним UID workspace aggregate: DeveloperProfile, Projects Library и несколько независимых Resume/Portfolio. Сохранить имеющиеся Riverpod composition, Hive очередь и UID namespaces, outbox, server-commit whole-document LWW. Public snapshots хранить отдельно по постоянному opaque public document ID. Никаких CRDT, event bus, нового sync framework, per-screen write stores или второго mobile runtime.

Полный вариант ниже остаётся proposal для remaining capabilities. D045 разрешает
private mobile subset; его реализация не ждёт повторного phase approval. Новый
public lifecycle, trusted handler и actual Next.js runtime требуют конкретного
контракта/реализации; их нельзя считать существующими из private schema update.

Историческая альтернатива UI-only до D045: перенести foundations/shared controls, поддерживаемые auth/forms/settings/GitHub и оформление существующих singleton screens. Multiple documents, structured Resume, relation semantics, full Account, real media, permanent publications и web остаются blocked либо явно исключаются пользователем. Это не завершение полной R8/R9.

Ниже PR-* IDs описывают полный proposal. Реализованный subset указан отдельно;
наличие subset не делает весь PR-* критерий выполненным и не заменяет R8 UI IDs.

---

## Действующий private slice 2026-10-07

Реализация расширяет `PortfolioContent`, не вводит новый WorkspaceContent/repository:
общая база в root, одна Projects Library и `documents` со snapshot секций,
ordered projectId/visible/featured relations и optional private attachedResumeId.
Максимум 20 документов; doc snapshot не содержит projects/documents/Ignore.
Новый документ предлагает base values, существующий не обновляется от base edits.
Atomic create-and-attach реализован через document local buffer и один
`saveDocument(newProjects: ...)`/revision; Cancel не пишет Library. Review
captured baseline/local project presentation overrides пока pending.

Hive writer5/readers1–5 и private cloud4/readers1–4 читают старые версии без rewrite;
Save/ACK сохраняет raw owner backup v1–v4 до upgrade. Старые UID namespaces,
Box queue, guest transfer journal/generation, outbox/exact ACK и whole-document
server-order LWW сохранены. Явный legacy import создаёт stable legacy-portfolio/
legacy-resume, сохраняя source content/resumeText/notes. Новый migration CAS/
нормализованные entity stores/public lifecycle generations из proposal не вводятся.

Четыре stateful mobile roots, Home filters и private Resume/Portfolio libraries
используют actual workspace. Scoped saveDocument/saveProject/saveDeveloperProfile
проверяют captured repository/expected entity/revision и сохраняют соседний
несохранённый ввод. Resume creation — пять шагов, изменение — focused sections.
Legacy Builder остаётся доступен. Подробные sources и contract — в
[architecture](../architecture/architecture.md#общая-база-и-независимые-документы).

Public schema1/username-addressed prepared adapter остаются прежними; documents
не попадают в public projection. Нет new Publish/Unpublish/permanent URL/trusted
public renderer. Full contacts/privacy/auth management, web/native sharing и
final native visual acceptance остаются pending. Media/location используют
прежние features и открытые проверки; карта исключена.

---

## Проверенный источник и пригодный механизм

<div align="center">

| **Сейчас** | **Файл и проверенный контракт** |
|:---|:---|
| PortfolioContent aggregate | domain/portfolio_content.dart и portfolio_document.dart: общая база/Library, independent documents snapshots/relations, legacy blocks/theme/resumeText и Ignore |
| Private envelope | domain/portfolio_draft.dart и data/hive_portfolio_draft_repository.dart: notes вне content, local revision, pendingSync; writer5 / readers1–5; read не делает eager migration; corrupt/unknown не перезаписываются |
| Local owner boundary | data/local_draft_accounts.dart: guest generation, UID key, shared Box queue, reserved transfer journal, raw backup, metadata-first ACK, syncPrepared, exact retry payload, committed-before-cleanup |
| Outbox / ACK | data/synced_portfolio_draft_repository.dart и data/hive_portfolio_sync_metadata_store.dart: mutation + captured snapshot, cache-before-metadata recovery; older ACK не подтверждает newer Save; metadata version1 |
| Cloud | data/firestore_portfolio_draft_repository.dart: accounts/UID/drafts/current, writer4/readers1–4; server timestamp, captured UID, online create-if-absent transfer claim |
| Prepared publication | data/firestore_portfolio_publication_repository.dart: username-based transaction; domain API publish(username, content)/unpublish; нет UI/DI или stable document inventory |
| Source review | domain/portfolio_project.dart / portfolio_github_sync.dart; github_portfolio_providers.dart: acceptedSource, manual overrideFields, Ignore fingerprints, stale owner/read checks; cache отдельный |
| Ownership / Rules | firebase/firestore.rules: own UID draft get, no list; atomic username/account/public transitions; nested lists проверяются контейнером |
| Web / account / settings | apps/web сейчас README; AuthUser UID/email/displayName; API sign-in/register/reset/Google/signOut; AppSettings theme/language/source descriptions |

</div>

Подробный read-only audit текущей сессии: `/private/tmp/stackcard-r8-integration-audit.md`; переносимый реестр gaps — [audit.md](audit.md#продуктовые-пробелы). Это аудит source, не выполненная миграция.

---

## Предлагаемая модель

Все модели pure Dart, immutable, equality/validation по существующему стилю. JSON contracts и fixtures общие для будущего web; React не импортируется в Flutter.

<div align="center">

| **Тип** | **Минимальные поля и инварианты** |
|:---|:---|
| WorkspaceContent | Один DeveloperProfile; maps projects/documents по stable private ID; GitHub ignore registry; private migration metadata. Не хранит Auth credentials, cache body или public success flags |
| DeveloperProfile | Текущие name/username/headline/bio/locationText + references на photo, contacts/links и прежние stable-ID skills/experience/education; opaque base revision для сравнения, не cross-device clock |
| LibraryProject | Прежние id/title/description/technologies/repositoryUrl/liveUrl/source/githubMetadata + media refs/dates. Удалить global featured/visible из нового writer; при legacy migration перенести их на attachment |
| DocumentDraft | id, kind resume/portfolio, name, createdAt/editedAt (legacy unknown = null), contentRevision token, выбранные секции и их порядок/visibility, own appearance/photo policy, copied profile values + captured baseline для review, local overrides |
| ProjectAttachment | projectId, order, visible, featured; optional local presentation overrides. Remove только relation; create+attach сохраняет одну global запись + одну relation атомарно в workspace |
| ResumeDraft | Структурированные выбранные contacts/skills/experience/education/projects; own layout/sections/local values. Legacy resumeText отдельный retained legacy-text block, без parsing в выдуманные факты |
| PortfolioDraftContent | Snapshot выбранных profile values, blocks, attachments, selected contact/link IDs + local values; optional selectedResumeId. Public ссылка Resume только при confirmed separately published Resume |
| PublicationRecord | Private owner/document/publicId mapping; published flag/version, resolved public digest/source workspace mutation, last operation ID/outcome. Public ID permanent после first Publish, never inherited by duplicate |
| WorkspaceSnapshot / SyncRecord | Прежние notes/local revision/pending/state semantics + workspace payload; ownerUid, mutationId, lifecycle generation. ACK относится к exact workspace payload; local revision не сравнивается между устройствами |

</div>

DeveloperProfile edits не меняют existing documents автоматически. New document предлагает копию; explicit review показывает captured old base → current base, применяет выбранные поля и сохраняет local overrides. Принятие review меняет working document; Save отдельный.

LibraryProject shared по ID. Явное редактирование global Project влияет на его использование в private drafts согласно resolved values; local document overrides сохраняются. Published snapshot остаётся прежним до explicit Publish. Source Add/Accept/Ignore меняет working Library через прежние pure rules, а не cache/public snapshot.

Contacts: login email не становится public email. Global contact eligibility/selected subset/local document override различны. Public projection включает только разрешённые для публикации и выбранные поля. Profile privacy edit сам по себе не обещает изменение уже опубликованной версии: показать affected publications и требуемый explicit republish/unpublish. Если нужен мгновенный revoke, это отдельное явно выбранное publication action, не скрытая синхронизация.

### Working state и Save без случайного сохранения соседнего документа

Один existing controller расширяется на workspace; durable snapshot остаётся один. Working buffers принадлежат конкретному base/project/document/notes scope. Не заводить отдельный repository на каждый экран.

Apply/Cancel работают только с buffer владельца. Save document сливает захваченный slice в актуальный durable workspace под shared queue/expected local revision; другие working buffers остаются unsaved. CreateProjectAndAttach — одна понятная domain операция, сохраняющая обе связанные части. Notes Save не меняет документы. Более новый ввод во время Save остаётся working, как уже делает controller. Remote hydration обновляет durable, но не стирает working buffers; конфликт изменённого target предлагает explicit review/reload.

Public projections для Publish разрешаются из сохранённого workspace, никогда из working buffer. Новый Publish требует текущего saved target и exact server ACK соответствующей workspace mutation; changed resolved Library fields тоже меняют public digest. ACK старой mutation или cache/pending event не разрешают Publish.

### Минимальный storage и его ограничения

Полный proposal первоначально предлагал отдельный workspace payload. D045
реализует совместимое расширение существующего content: paths/keys прежние,
Hive5/private cloud4 уже используются, metadata/public schemas прежние.
Версии будущего workspace/public lifecycle не назначаются здесь заранее.
Old writers не могут downgrade upgraded private cloud schema.

Один aggregate дешевле per-entity sync и позволяет atomic create+attach. Компромисс: одновременные edits с разных устройств по-прежнему могут заменить целый workspace в server commit order. Не обещать merge отдельных документов. Включить current remote-change review/unsaved preservation.

Firestore ограничивает документ 1 MiB. Проверять encoded Firestore size и типизированный oversized после local Save, сохраняя local snapshot/pending; не измерять только длину JSON. Media bytes вне aggregate. До выбора границ выполнить realistic maximum fixtures; если они не укладываются, согласовать normalized storage как дополнительное решение, а не молча вводить его. Источник: [Firebase quotas](https://firebase.google.com/docs/firestore/quotas).

---

## Migration PR-MIG-01 — один recoverable переход, без потерь

Ниже — **оставшийся полный migration proposal**, не описание выполненного
private compatibility slice. Действующий механизм описан выше и в architecture;
он не обещает CAS/journal/two-client entity merge из пунктов ниже.

Не запускать migration на read. Reader создаёт in-memory legacy projection; durable upgrade происходит при явно разрешённом первом Save/upgrade. Notes-only legacy content=null остаётся notes-only: не создавать фальшивое Portfolio или Resume.

1. Зафиксировать owner key/UID и guest generation; закрыть subscriptions/retry старого adapter и инвалидировать in-flight callbacks по generation. Shared Hive queue сериализует migration/save/transfer. Другой UID ничего не читает и не продолжает.
2. Валидировать raw envelope1/2/3, existing v1 backup, sync metadata и guest transfer journal. Corrupt/unknown — stop с оригинальными bytes и retry/error; defaults и reset запрещены.
3. Если guest transfer journal уже reserved/syncPrepared/committed, сначала завершить его прежний exact protocol тем же UID. Не менять captured transfer bytes/ID и не превращать старый matching ACK в доказательство нового workspace. Новый upgrade начинается после подтверждённого завершения transfer. Lost ACK/occupied remote сохраняют нынешние различимые recovery branches.
4. До замены сохранить raw current envelope, raw outbox metadata и original v1 backup под owner-scoped backup; flush. Записать migration journal: source schema/fingerprint, owner/generation, stable ID mapping, exact converted snapshot, new mutation, phase. Journal не содержит auth tokens.
5. Pure mapping сохраняет все source IDs, order и значения. Profile/skills/experience/education/links → base. Projects → Library с acceptedSource/overrideFields/lastGitHubSyncAt/source kinds. Ignore registry без изменений. Legacy Portfolio → один документ с прежним block order/visibility/theme и attachments из старого project featured/visible. ResumeText сохранять посимвольно в legacy-text block; пустой текст не создаёт Resume. Notes остаются отдельно и не становятся document content.
6. Для одного legacy authenticated singleton использовать одинаковые owner-relative logical IDs во всех clients (например legacy-portfolio / legacy-resume в UID namespace); не создавать случайный новый document ID на каждом read/устройстве. Guest-generated IDs один раз записать в journal и сохранять при transfer. External publicId отдельный opaque immutable mapping, поэтому owner-relative legacy ID не становится public collision или username URL.
7. Обновлённый envelope и outbox записать через recoverable journal фазами prepared → localWritten → metadataWritten → committed. Multi-key Hive запись не считать транзакцией. Reopen сравнивает exact fingerprint/converted snapshot и либо завершает собственный partial write, либо блокирует повреждение; не перетирает unrelated newer Save.
8. Pending legacy outbox не выбрасывать. Сохранить его exact raw snapshot/mutation в backup/journal; применить нынешний reconcile выбор последнего local snapshot. Конвертированный payload получает НОВУЮ mutation (другие bytes/schema), linked source fingerprint. Old ACK не снимает новый pending. If старый write уже отправлен, schema downgrade guard не позволяет ему заменить committed new schema.
9. При first online cloud upgrade transaction/CAS читает current legacy mutation/schema и migration identity. Same migrated result разрешает idempotent retry; different remote legacy/new workspace требует explicit reconcile, не silently overwrites и не создаёт вторую legacy копию. Offline miss не означает пустой remote. Journal сохраняется до подтверждения; authoritative mapping новой cloud версии побеждает local provisional mapping.
10. Новый exact server ACK подтверждает только captured new mutation/revision/generation/payload. После него journal можно завершить, backups оставить recoverable согласно выбранной retention policy. Нельзя rollback cloud/new schema до old writer; recovery восстанавливает совместимую новую запись, а исходные raw copies остаются доступными.
11. Legacy published snapshot мигрируется PR-URL-01 отдельно; private migration не публикует новый Resume и не меняет старую public страницу автоматически.

Audit/test fixtures: v1 notes-only, v2 content/resumeText, v3 manual+GitHub with all override flags/ignore; unknown/corrupt; crashes after every write/flush; old ACK vs new migration; new local Save during migration; two clients upgrade same account; UID switch/in-flight callback; every existing guest journal state; transfer remote occupied/lost ACK; no cross-owner access. Reopen проверяет exact notes/resume/source fields, не только количество записей.

---

## Publication, URL, delete — отдельный продуктовый пакет

PR-PUB-01 заменяет username-addressed API документным контрактом: read publication state, explicit publish, update, unpublish, resolve outcome, Copy/Open/Share only confirmed URL. Одна current snapshot на документ; integer publication version не превращается в сложную историю версий. Service получает documentId + expected saved mutation/generation + operationId и сам читает authoritative private workspace. Он не доверяет public content из запроса клиента.

Предлагаемые новые paths (ещё не созданы): accounts/UID/publications/privateDocumentId для permanent mapping/current operation; publicDocuments/publicId для current public payload. Anonymous только get exact published record; list и любой private/account/notes read запрещены. Missing/unpublished/deleted дают одинаковое не раскрывающее private existence состояние. Реальный production host берётся из config после доступного окружения; example.com/d/ID остаётся примером, не live URL.

PR-PUB-02: глубокий recursive allowlist/type validation и projection на trusted стороне. Исключить notes, login email/provider inventory, source snapshots/override flags/Ignore/cache, unselected/hidden contacts/sections/projects и private photo references до public write. Direct SDK public writes deny; SSR props/readers получают только public schema. Нынешние Rules проверяют list/map контейнеры; это не доказательство безопасности всех nested элементов. Официальная документация подтверждает отсутствие общей проверки типов всех элементов: [Firebase field validation](https://firebase.google.com/docs/firestore/security/rules-fields).

Рекомендуемое размещение trusted handler — один authenticated handler в отдельно разрешённом Phase13 Next.js runtime, поскольку полный web всё равно нужен. Не создавать отдельный backend/functions до этого решения. Если требуется mobile publication раньше или web исключён, отдельный минимальный trusted-service вариант потребует явного scope PR-PUB-02-SERVICE. Выбор hosting/deploy/billing не включён автоматически. Server SDK обходит Rules, поэтому handler сам проверяет ID token/UID, lifecycle, source mutation, full schema и transaction invariants; Rules tests не заменяют его unit/security tests. Источник: [Firebase server/Rules boundary](https://firebase.google.com/docs/firestore/security/rules-fields).

PR-URL-01: opaque publicId закрепляется за original document, rename/username change не меняют URL, unpublish удаляет public payload и сохраняет private mapping, republish использует тот же publicId. Duplicate создаёт новый private ID, копирует только draft config/content/relations/local overrides, оставляет global Project IDs, сбрасывает publication/version/op/publicId.

Legacy /u/username: текущий adapter удаляет старый snapshot/reservation при rename. До миграции инвентаризировать owner/account/public record и сохранить approved exact payload/version. Рекомендуемый alias только на permanent ID с permanent ownership/tombstone, имя никогда не перенаправляется на чужой позже занятый username. При отсутствии согласованной alias policy legacy public records не трогать. Новый alias и current username reservation имеют разные назначения.

PR-PUB-03: delete document сначала confirmed public withdrawal, затем private removal/attachment cleanup; Library/прочие outputs не удаляются. Delete global Project перечисляет affected attachments, removes them and Project once, не стирает GitHub cache. Монотонный lifecycle generation сохраняется в protected owner record и фиксируется в workspace/outbox; destructive transaction увеличивает его. Rules/adapter отвергают поздний Save старого поколения — иначе whole-document LWW воскресит удалённый entity. Старый outbox остаётся conflict/recovery с несохранёнными данными, не автоматически retries и не считается deleted success. Generation guard новый contract отдельной задачи, а не уже реализованная возможность.

Publish/update/unpublish/delete имеют request operation identity и read-resolution. Timeout → unknown; retry/read той же операции, никаких false success toasts. After unpublish/delete reader не раскрывает private draft. Media withdrawal/references участвуют в том же lifecycle по PR-MEDIA-01.

---

## Product tasks, GAP и владельцы источников

<div align="center">

| **Proposed ID** | **GAP / roadmap** | **Concrete result / source owner / blocker для R8** |
|:---|:---|:---|
| PR-DATA-01 | GAP-DATA-01; дополнение Phase6/8 | Workspace/base/Library/independent Resume/Portfolio domain + validation. Owner domain: existing features/portfolio_draft/domain + public feature API; новых file names не считать существующими. Blocks R8.3b/c/e/f,4d/e |
| PR-MIG-01 | GAP-DATA-01; Phase6/8 compatibility | Versioned legacy codec, raw backup/journal, UID/guest/outbox/cloud upgrade protocol выше. Owner persistence: existing Hive/LocalDraftAccounts/sync codec + LocalRuntime; no wipe/reinstall. Blocks dependent data flows |
| PR-SYNC-01 | GAP-DATA-01; Phase8 | Workspace payload adapters, exact ACK state/generation, schema upgrade/no downgrade, size failures, Rules private boundary. Owner sync: existing synced/Hive metadata/Firestore repositories; owner Rules separately firebase/firestore.rules/tests |
| PR-DATA-02 | GAP-DATA-02; Phase6/8 | Stable relation order/visible/featured, create+attach atomic, remove relation only, global delete consequences. Owner domain/controller; Blocks R8.3d/e,4b/e |
| PR-DATA-03 | GAP-DATA-03; Phase6/8 | New-doc base suggestion, captured-baseline review, selections/local overrides, preserve existing/public content. Owner domain/controller/forms; Blocks R8.4d/e |
| PR-CONTACT-01 | GAP-CONTACT-01; новый contact/privacy contract | Public contact fields/link reorder/selection/local overrides/privacy, login email separate; inherited links retained. Owner domain/projection/settings. Inbox/contact-request/anti-spam/FCM не включаются этим ID |
| PR-PUB-01 | GAP-PUB-01; дополнение Phase8 +13c | Multiple Resume/Portfolio snapshots, inventory/status/Save-ACK-Publish/unknown/reopen. Owner publication domain/data/DI; Blocks R8.3c/e,4d/e,5b/c |
| PR-PUB-02 | GAP-PUB-02; Phase8 security | Trusted validation/projection + deny direct public writes + malicious nested fixtures. Owner chosen handler + firebase Rules/tests. Требует явно выбранного runtime размещения; Blocks public security acceptance |
| PR-PUB-03 | GAP-PUB-01; delete consequences | Withdraw+remove + generation anti-resurrection + operation recovery + unaffected Library/other docs. Owner publication/workspace transaction, adapters/Rules. Blocks delete/account consequences |
| PR-URL-01 | GAP-URL-01; D019 implementation | Permanent publicId mapping, rename/unpublish/republish/duplicate policy, legacy alias ownership migration. Owner publication/route schema. Blocks real persistent URLs/Copy/Open/Share |
| PR-AUTH-01 | GAP-AUTH-01; открытая Phase7 | Real Google/reset/native config and iOS acceptance. Owner existing auth adapter/platform config/tests. No-launch сохраняет native acceptance pending, mocked tests не закрывают его |
| PR-ACCOUNT-01 | GAP-ACCOUNT-01; дополнение Phase7 | SDK provider inventory/email verification+change/password+reauth/link/unlink/last-provider guard. Owner auth API/data/controller. Только supported providers; Blocks full Account |
| PR-ACCOUNT-02 | GAP-ACCOUNT-01; new deletion contract | Capture UID; withdraw all public, revoke generation/stop sync, recoverably delete owner data/media, Auth identity last; only confirmed same-UID local cleanup. Owner auth + workspace/publication/media; Blocks Delete account |
| PR-MEDIA-01 | GAP-MEDIA-01; Phase11 | Camera/gallery/pick/permission/validation/upload/retry/replace/remove, immutable owner/public media refs, cleanup/reuse protection, Storage Rules. Owner future real media adapter + platform configs; existing no-photo UI раньше разрешён |
| PR-PREF-01 | GAP-PREF-01; app settings addition | Versioned persisted reduced motion + OS static behavior; preserve theme/locale/source preferences write retry. Owner core/state + existing settings repository |
| PR-NOTIFY-14 | GAP-PREF-01/contact-request part GAP-CONTACT-01; Phase14 | Connected notifications require actual ContactRequest/Inbox/anti-spam/mobile FCM service and permissions. Это отдельный choice, не bool-toggle или default backend scaffold. До согласования/службы honest unavailable state, acceptance exclusion явно записать |
| PR-SHARE-15A | native share; subset Phase15 | Confirmed URL Clipboard/Open + Android MethodChannel/Kotlin ACTION_SEND; iOS отдельно. Owner narrow platform adapter; QR/DeveloperCard/fullPhase15 не входят автоматически |
| PR-WEB-13A | GAP-WEB-01; Phase13a | Actual Next.js manifest/config/tokens/shared controls/landing/download with honest CTA; no fake store/releases. Owner apps/web only after scope |
| PR-WEB-13B | GAP-WEB-01; Phase13b | Real auth/owner UID guards/workspace versioned contract/online-first Save/reopen/preview/publication API/mobile↔web compatibility. Owner web editor/data; Blocks R8.5b |
| PR-WEB-13C | GAP-WEB-01; Phase13c | Anonymous permanent route published-only renderer/metadata/missing state/visitor Copy/Open/WebShare; SSR private exclusion. Owner web public readers; Blocks R8.5c |

</div>

Все12canonical GAP IDs из [audit](audit.md#продуктовые-пробелы) покрыты; native sharing выделен отдельно. Location Phase12 разрешена отдельно 2026-10-07 как город/страна с optional geolocation; карта и Maps SDK исключены D044. PDF/uploaded Resume, Inbox/FCM, QR/DeveloperCard, release/store URL/production domain/deploy/billing не появляются из общего разрешения UI. Для notifications connected state и иных невыбранных функций нельзя заявить full runtime completion.

---

## API compatibility и file ownership

- Не создавать параллельные workspace storage/services рядом с действующим repository. Расширить current feature domain/data и composition. Final names можно rename с обновлением public exports/callers/tests; legacy readers остаются explicit migration branches.
- PortfolioDraftRepository.read/saveNotes и прежние constructors имеют transitional adapter к одному legacy document в том же workspace, без собственного Box/outbox. Старый save(content) merges только mapped legacy scope и не удаляет новые документы. Если scope ambiguous, typed unsupported/conflict; не silently flatten workspace.
- profileProvider становится проекцией base, projectsProvider — Library; public read model APIs Profile/Project сохраняются. Featured/order зависит от document relation; прежний global featured helper допустим только как legacy adapter, новый API получает document ID.
- GitHub controllers/acceptedSource/withUserEdits/Ignore domain reuse с новым Library target; public cache ownership/TTL не меняются. Captured owner/stale selection/unique repository ID защищают Add/Accept/batch actions.
- Account session source remains SDK; appearance remains Provider/AppSettings, feature state remains Riverpod. Settings/route UID guards, guest access and from destination checks сохраняются.
- Один owner на shared domain/API contract, один на persistence/migration/LocalRuntime, один на sync/Rules, один на publication/security handler, один на auth/media adapters, один на web. Parallel agents могут делать изолированные UI/test consumers только после общего schema/API review. Files with shared ownership интегрирует root; никто не правит одновременно один codec/controller/pubspec.
- Required docs после согласованной реальной implementation: existing product-spec task IDs/status, ADR0001/0002 amendments or focused new migration ADR, architecture, docs/AI/scopes/mobile.md + firebase.md, CONTRIBUTING references. Реальная web область получает минимальный web scope/router; новые formal guides без runtime не создавать.

---

## Последовательность после scope решения

1. Независимый R8 UI foundations/controls/assets и supported forms продолжаются отдельно, не ждут нового backend.
2. PR-DATA-01/02/03 + CONTACT contracts и migration fixtures; PR-MIG-01 + SYNC/Rules upgrade вместе, без ранней production migration.
3. Publication/URL/delete trusted contract и security fixtures; account/media/preferences/share owners работают параллельно по immutable references/API.
4. Web13a →13b →13c по фактическим dependency contracts; handler/SSR используют те же JSON fixtures и payload policy.
5. Dependent R8 flows подключаются к реальным providers и honest states; R9 unit/widget/Rules/contract checks, затем только отдельно разрешённое runtime/native evidence. Ни один mock/Figma/structural pass не объявляет live media/auth/sharing/web backend working.

No commit/push/deploy/user messaging другим людям. Private mobile subset D045
разрешён; оставшийся proposal не считается реализованным или принятым по этому факту.

---

## Проверки и критерий audit readiness

Tests перечислены по actual source inventory, не объявляются PASS: portfolio_draft_schema_migration_test.dart, local_draft_accounts_test.dart, cloud_guest_transfer_journal_test.dart, portfolio_sync_repository_test.dart, portfolio_draft_controller_test.dart, portfolio_builder_repository_test.dart, portfolio_github_sync_test.dart, github_portfolio_controller_test.dart, portfolio_public_content_test.dart, firestore_publication_adapter_test.dart, account_auth_ui_test.dart, account_navigation_test.dart, settings_persistence_test.dart, firebase/test/firestore_rules.test.mjs.

Добавить содержательные cases: exact lossless mapping всех versions; crash journal phases; two-device idempotency; old/new ACK + pending payload; stale generation delete; private/public/foreignUID/anonymous/list; malicious nested payload direct SDK; contacts/account separation; base review override preservation; duplicate no publication; rename/unpublish/republish same ID; unknown operation read-resolution; new schema downgrade denial; cross-client fixtures; media linked published asset not deleted from draft removal.

Обычные checks после разрешённого diff: macOS zsh/bash, cwd apps/mobile: dart format --output=none --set-exit-if-changed lib test integration_test, flutter analyze, flutter test; cwd firebase: npm run test:rules по actual manifest. Web commands задаются только новым actual manifest. Native Google/reset/iOS/media/share/device acceptance сейчас pending из-за no-launch; headless tests этого не доказывают.

Документ проверяется как actual private subset плюс remaining proposal: existing
paths/schema версии сверены с source, proposed paths отмечены отдельно, нет
falsely completed PR-* tasks. Проверки и дальнейший scope отражаются по фактам
в product status; полная приёмка требований не возникает из наличия private slice.
