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
  account/draft по UID, anonymous get только public snapshot, запрет collection
  list и атомарные account/username/publication transitions.
- [firestore.indexes.json](../../../firebase/firestore.indexes.json) — canonical
  indexes; не добавлять индексы без реального запроса.
- Pure Dart contracts, UID-bound Firestore adapters и Hive outbox принадлежат
  `apps/mobile/lib/features/portfolio_draft`. Runtime composition — LocalRuntime.
  Не переносить SDK в domain или widgets и не дублировать cloud schema.
- [storage.rules](../../../firebase/storage.rules) и `features/media` владеют
  Phase 11 private image доступом. Path `accounts/{uid}/media/{32hex}.jpg`:
  owner get/create/delete, immutable objects, JPEG до 2 MiB; list/public paths
  закрыты. App читает SDK bytes без download tokens. Bearer URL при раскрытии
  владельцем Rules не защищают. Контракт/cleanup —
  [ADR 0003](../../decisions/0003-private-portfolio-media.md).

## Изменение и проверка

- Private notes/account data не смешивать с public snapshot; hidden content
  удаляется public projection перед записью, а не только скрывается renderer.
  Source snapshots, override flags и Ignore registry также private и удаляются
  public codec. Private writer schema 4 читает 1/2/3/4; Rules запрещают downgrade,
  public schema 1 сохраняется и исключает media paths/documents. Documents list
  ограничен 20; Rules проверяют owner media path каждого snapshot, codec —
  структуру, ID и Library/resume relations. Полный public-document контракт
  ещё не реализован. GitHub миграция — в
  [ADR 0002](../../decisions/0002-github-import-and-review.md), media — в ADR 0003.
- Publish/rename/unpublish меняют account pointer, username reservation и public
  snapshot атомарно. Проверять linked post-write state через `getAfter`/`existsAfter`
  и отклонение partial writes; sync не вызывает publication repository.
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
  foreign/anonymous denial, username race и partial transitions проверяются
  через client SDK с Rules, не Admin SDK bypass.
- `test:all-rules` запускает Firestore + Storage, `test:storage` — Storage,
  `test:rules` сохраняет Firestore-only contract. Native media SDK acceptance
  использует Auth/Storage emulators и отдельные named apps; системный picker,
  отказ permissions и live bucket требуют отдельной приёмки. Billing/deploy
  автоматически не выполняются.
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
