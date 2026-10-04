# GitHub import, explicit review and user overrides

Дата: 2026-10-04. Статус: accepted.

## Контекст

Phase 9 разрешена после завершения Firestore sync. Публичный GitHub Import уже
читает source metadata с pagination/cache; Builder хранит curated content.
Повторное чтение GitHub не должно заменять ручные правки или public snapshot.

## Решение

- `PortfolioProject.source` — `manual | github`. GitHub-проект связан с source
  положительным числовым `githubRepositoryId`; rename и смена URL не создают
  второй проект. Исходные данные соответствуют существующему GitHub DTO:
  name/fullName, description, language, URL, stars/forks, flags и updatedAt.
  Homepage/topics/README не добавляются отдельными запросами этой фазы.
- Curated title/description/technologies/repositoryUrl остаются существующими
  полями проекта. `githubMetadata.acceptedSource` хранит отдельно согласованный
  source snapshot; `overrideFields` отмечает поля, явно изменённые владельцем.
  Editor сохраняет metadata через `withUserEdits`; liveUrl/featured/visible всегда
  принадлежат владельцу. Повторный review сохраняет override независимо от нового
  source значения; автоматического сброса override нет.
- Refresh/pagination меняют только GitHub source/cache. `reviewGitHubProject`
  вычисляет New/Synced/Changes available/Ignored относительно working draft.
  Add, Accept и Ignore меняют working content явно; отдельный Save сохраняет его
  через существующие Hive/outbox/Firestore adapters. Preview/Cancel не записывают
  draft. Профиль GitHub не переносится в профиль владельца автоматически.
- Accept проверяет captured project против текущего проекта и отклоняет stale
  review, сохраняя новые ручные правки. Controller дополнительно проверяет captured
  repository identity и актуальный account/explicit guest access: открытый sheet
  не может изменить draft нового UID. Во время Save sync actions недоступны.
- Ignore хранит repository ID и детерминированный fingerprint source версии в
  `PortfolioContent.ignoredGitHubRepositories`. Это private owner/guest state;
  решение переживает Save/restart и не относится к shared GitHub cache. Новая
  source версия снова требует review; Add/Accept очищают ignore этого ID.
  Ignore до начала Builder создаёт пустой working content для хранения решения.
- `lastGitHubSyncAt` — известный source `validatedAt` в UTC, а не время нажатия.
  Offline fallback сохраняет прежнюю дату; неизвестная дата остаётся null.
  Статус сравнения вычисляется из загруженного snapshot, отдельно от состояния
  отправки draft в Firestore. Отсутствие repository на странице, ошибка или cache
  fallback не означают удаления curated проекта.
- Writer Hive envelope v3 читает v1/v2/v3 без migration при read. Явный Save/ACK
  пишет v3, raw v1 backup сохраняется. Private Firestore writer schema 2 читает
  schema 1/2; Rules запрещают update 2→1. Старый клиент блокирует неизвестную
  schema вместо записи, которая могла бы удалить source metadata. Sync metadata
  envelope остаётся прежним и содержит актуальный versioned draft snapshot.
- Published schema 1 сохраняет прежние curated поля. Public projection удаляет
  accepted source, override flags и ignore registry физически из payload.
  Import/review/Save не вызывают publication repository. Whole-draft LWW и
  последствия concurrent/offline writes из [ADR 0001](0001-firestore-sync-and-publication.md)
  сохраняются.

## Альтернативы

Автоматическая замена curated проекта source полями теряет ручные правки.
Хранение overrides вторым полным набором строк дублирует curated content.
Observed snapshot в каждом проекте добавляет запись draft при обычном чтении;
текущего source/cache достаточно для review. SharedPreferences для Ignore
нарушает UID isolation и синхронизацию решений. Suggestions/score остаются Phase 10.

## Последствия и проверка

После source обновления проект сохраняет accepted версию до явного Accept;
принятые изменения остаются unsaved до Save. В review видны source изменения
и защищённые ручные значения. Повторный Add не создаёт дубликат.
Domain/controller/widget tests проверяют этот путь, stale review/UID transitions
и ошибки; Hive/Firestore tests — совместимость и round-trip; Rules — запрет
downgrade и неизменность public snapshot при private sync. Opt-in Android suite
проверяет offline/reopen/server ACK и сохранение source metadata/overrides.
Фактические результаты и ограничения — в
[Phase 9](../product/product-spec.md#phase-9--living-portfolio--smart-github-sync).
