# Приватные изображения портфолио

Дата: 2026-10-07. Статус: accepted для реализации Phase 11; приёмка ведётся в product spec.

## Контекст

Пользователь разрешил Phase 11 на `dev`, содержащей `redesign/full-app`.
Resume остаётся обычным текстом. Upload не должен публиковать draft, а замена
изображения — разрушать сохранённую или offline версию.

## Решение

- `features/media` владеет pure contracts, preprocessing, Storage adapter и
  UID-scoped Riverpod DI. SDK не входит в domain/widgets.
- `PortfolioProfile.avatarPath` и `PortfolioProject.imagePaths` содержат paths
  `accounts/{uid}/media/{32 lowercase hex}.jpg`; максимум шесть images проекта.
  Прежний `avatarUrl` остаётся внешним URL.
- Camera/gallery вызываются явно. Cancel/permission failure сохраняют форму,
  progress/retry не применяют результат другому UID. Apply меняет working
  content; прежний отдельный Save сохраняет draft.
- JPEG/PNG/WebP проверяются по magic bytes, MIME и размеру. Original — до
  10 MiB, decode — до 8192 px на сторону и 24M pixels, JPEG output — до 1600 px
  и 2 MiB. Isolate выполняет resize/compression и удаляет EXIF/GPS.
- Storage get/create/delete разрешены владельцу; list/overwrite запрещены.
  App не вызывает `getDownloadURL`, не хранит и не выдаёт bearer tokens.
  Private bytes читаются SDK `getData`, cache живёт в UID-scoped provider без
  disk persistence. Внешние public HTTP avatars используют `cached_network_image`.
- Public projection исключает private paths. Public Storage namespace закрыт
  до отдельного explicit publication решения; Phase 13 не реализуется.
- Hive writer v4 читает v1–v4, cloud writer schema 3 читает 1–3; public schema 1
  сохранена. Read не переписывает legacy envelope; old schema отвергает media
  fields. Cloud codec проверяет UID всех paths, Rules запрещают downgrade.
  Rules не умеют обходить произвольные project arrays: их проверяет codec.

## Очистка и ограничения

Upload создаёт уникальный immutable path. Отмена/удаление ещё не применённой
загрузки пытается удалить только созданный этой формой объект. Ошибка cleanup
или завершение процесса могут оставить orphan. Файлы прежних сохранённых
версий не удаляются при Apply/Save/local ACK: другой offline клиент или поздний
LWW commit может ссылаться на них. Автоматической garbage collection нет.
Будущая server cleanup должна учитывать draft/published references,
конкурентные устройства и retention; один локальный snapshot для неё недостаточен.

Firebase backend может создавать download tokens для объектов. Rules защищают
SDK-запросы, но сознательно раскрытый bearer URL даёт доступ предъявителю.
Запрет SDK `getDownloadURL` и отсутствие tokens в draft устраняют такой путь в
приложении; абсолютную защиту при раскрытии токена владельцем не обещаем.

Guest остаётся local-only без Storage uploads. После Android activity
recreation потерянный picker result не применяется автоматически к новому
draft/UID: выбор повторяется явно. Live Storage требует Blaze согласно
[официальному setup](https://firebase.google.com/docs/storage/flutter/start);
billing upgrade и deploy автоматически не выполняются.

## Проверка

Model/codec tests проверяют legacy migration, ownership/public exclusion;
processor/provider/UI tests — validation, resize, progress/retry/cancel и UID.
Storage/Firestore Emulator tests проверяют действующие Rules. Opt-in
`integration_test/media_runtime_test.dart` использует demo emulators и named
SDK apps, сохраняя обычный session/draft. Camera/gallery, permissions и live
bucket — отдельные обязательные сценарии приёмки.
