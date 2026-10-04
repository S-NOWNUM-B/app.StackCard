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

## Изменение и проверка

- Private notes/account data не смешивать с public snapshot; hidden content
  удаляется public projection перед записью, а не только скрывается renderer.
  Source snapshots, override flags и Ignore registry также private и удаляются
  public codec. Private writer schema 2 читает 1/2; Rules запрещают downgrade 2→1,
  public schema 1 сохраняется. Контракт миграции — в
  [ADR 0002](../../decisions/0002-github-import-and-review.md).
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
