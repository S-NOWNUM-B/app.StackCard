# Firestore draft synchronization and explicit publication

Дата: 2026-10-04. Статус: accepted.

Phase 9 расширяет private payload GitHub metadata и меняет версии writers:
Hive v3/private Firestore schema 2, public schema 1 сохраняется. Совместимость
и защита от downgrade описаны в [ADR 0002](0002-github-import-and-review.md);
ownership, LWW, outbox и atomic publication этого ADR остаются действующими.

## Контекст

Phase 8 разрешена отдельным поручением пользователя. Android email authentication
работает; оставшаяся приёмка Google/reset/iOS Phase 7 сохраняется открытой.
Hive уже хранит guest и UID drafts. Mobile и будущий web должны использовать
одинаковую границу private/public; синхронизация не публикует draft.

## Решение

| Путь | Данные и доступ |
| --- | --- |
| `accounts/{uid}/drafts/current` | Только владелец: schemaVersion, ownerUid, mutationId, localRevision, notes, content, updatedAt. Timestamp задаёт сервер |
| `accounts/{uid}` | Только владелец: ownerUid, username (nullable), publicationVersion, updatedAt. Username указывает на текущую явную публикацию |
| `publicPortfolios/{username}` | Публичный snapshot: schemaVersion, ownerUid, username, publicationVersion, sourceMutationId, content, publishedAt. Нет notes, email, auth/session |
| `usernames/{username}` | Уникальная reservation ownerUid/username; authenticated get для проверки занятости, list запрещён |

Username соответствует существующей lowercase validation 3–30 символов.
Publish выполняет transaction: читает account и reservation, записывает
reservation/public snapshot/account вместе, освобождает старое имя при rename.
Unpublish удаляет оба public документа и обнуляет account pointer в одной
transaction. Rules через getAfter/existsAfter запрещают частичное изменение
этой тройки и захват занятого имени. Publication version увеличивается при каждом
переходе и совпадает у account/snapshot. Draft writes не меняют публикацию.
Механизм готовится для последующих экранов; public web остаётся Phase 13.

Public projection использует только видимые блоки: поля скрытых блоков пусты,
скрытые проекты исключены; GitHub links и обычные links учитывают свои блоки.
Private notes никогда не входят в content codec или public write.
Rules разрешают public только с явно перечисленными полями; владельцу нельзя
изменять чужие records, anonymous доступ ограничен published snapshots.

Sync — whole-document last-write-wins по порядку server commits, не по часам
устройства. Local revision относится только к local optimistic concurrency;
между устройствами её не сравнивают. Mutation ID связывает конкретный snapshot
с ACK. Save сначала завершается в Hive; outbox сохраняется до отправки.
После рестарта pending draft восстанавливает outbox, в том числе если процесс
остановился между local Save и записью sync metadata. ACK старой записи не
снимает pending с более нового Save. Cache/pending SDK snapshots не считаются
подтверждением сервера. Remote update обновляет durable cache; несохранённый
рабочий ввод остаётся у пользователя до явного reload или Save.

Guest остаётся local-only. Account adapters фиксируют UID; смена session
отключает subscriptions/retry, данные другого UID не используются как fallback.
Явный guest transfer требует пустого target одновременно в Hive и Firestore.
Online transaction создаёт cloud draft только при его отсутствии; retry принимает
только тот же transfer mutation и snapshot. Пустой offline cache не подтверждает
пустоту аккаунта. Guest journal резервирует source до cloud claim; доказанный ACK
metadata записывается перед local destination и cleanup, durable syncPrepared
позволяет завершить cleanup после сбоя без повторного remote overwrite.
Confirmed occupied cloud до local destination освобождает source, сохраняя оба
draft; потерянный ACK оставляет source тому же UID для явного retry. Если за это
время другое устройство изменило cloud, retry conflict освобождает незавершённый
journal и его transfer-only ACK metadata вместо вечной блокировки аккаунта.
Metadata-first ACK относится только к точному payload/revision.
Legacy envelope переносится точно; подтверждение синхронизации может записать v2
после этого явного действия с сохранением raw v1 backup.
Журналы Phase 7 без syncPrepared, у которых destination уже записана, завершают
ранее начатый локальный перенос. Это сохранённая пользователем offline-версия:
она участвует в обычном LWW, без нового требования пустого cloud target. Такой
путь помечается durable legacyLocalCommit и не выдаётся за server ACK.
Network failure сохраняет pending outbox, error показывает отказ/сбой; retry
явный и после восстановления сети. Native Firestore persistence дополняет Hive,
но не заменяет его и не владеет рабочим вводом редактора.

## Альтернативы

Revision compare-and-set transactions требуют online connection и отдельного
conflict resolution UX; их можно ввести при реальном сценарии совместного
редактирования. Field merge/CRDT сейчас усложняют модель без требования продукта.
Один published-флаг в private документе не обеспечивает разграничения полей.

## Последствия

Одновременные сохранения не сливаются: поздний server commit заменяет ранний
draft целиком. Offline-клиент после reconnect может заменить новый online draft.
Повтор после потерянного ACK тоже может стать более поздней записью; mutationId
обеспечивает корректный local ACK, но не глобальное exactly-once исполнение.
Следовательно, редактор не обещает сохранение обеих конкурирующих версий.
Published snapshot сохраняется неизменным до отдельного publish/unpublish.
Firestore document ограничен 1 MiB; oversized write остаётся локальным с error.
Регион и стоимость базы настраиваются отдельно; billing upgrade не требуется
и автоматически не выполняется.

## Проверка

Unit tests: durable offline Save/restart/retry, newer Save during ACK, UID boundary,
LWW двух клиентов, failure без потери local content и unsaved UI protection,
cloud-aware guest claim и recovery journal/ACK до source cleanup.
Firestore Emulator Rules tests: owner/foreign/anonymous, private/public separation,
username race, atomic publish/rename/unpublish и отказ partial writes.
Native Android: реальные SDK offline/reconnect, server ACK, второй клиент и restart;
запуск без удаления имеющихся app data. Native iOS проверяется при доступном toolchain.
