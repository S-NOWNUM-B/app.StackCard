# ADR 0005 — Одно основное портфолио

Статус: принят прямым поручением пользователя 2026-10-11; реализация и проверки
фиксируются в product spec. Это новый продуктовый контракт, прежний D048 остаётся
историей. Commit/push/deploy и платные сервисы не входят в поручение.

## Контракт и перенос

Существующий UID-bound `PortfolioContent` остаётся единственным workspace.
Projects Library хранится в root `projects`, основное портфолио — существующий
`PortfolioDocument`, выбранный через root `mainPortfolioId`. Старые документы
сохраняются для восстановления, их библиотеки исчезают из обычного интерфейса.
Root `githubUsername` — единый источник импорта, отдельно от portfolio slug.
Root `personalization` хранит status `notRequired|inProgress|completed` и step0–3;
пустые поля не определяют завершение. Root `legacyMainSnapshot` сохраняет исходный
выбранный документ до современных изменений, включая запрещённые раньше данные.
Эти root metadata отсутствуют во вложенных snapshots.

При конфликтующих исходниках владелец выбирает документ или прежнюю общую базу
после просмотра. Тексты автоматически не склеиваются. Перенос и backup выполняются
атомарно через существующие revision/CAS механизмы. Document ID сохраняется вместе
с permanent public mapping; прежние опубликованные URL не снимаются автоматически.
Private kind выбранного Resume может сохраняться ради legacy relations; современное
основное представление всегда портфолио. Legacy location включается только при
прежних разрешениях base/document, скрытые контакты не раскрываются. В новом
редакторе ручной ввод города/страны явно добавляет его в содержимое.

Максимум новой schema — 21 документ: 20 legacy + main из выбранной базы.
Новые writers: Hive8/cloud7; readers принимают прежние версии без read-time write.
Public writer schema2, reader1/2. Public projection исключает legacy архив,
personalization, GitHub source/overrides, private notes, изображения проектов и
attached Resume. Sync/Save не публикуют автоматически.

## Интерфейсы и владение

Mobile shell содержит Home, Projects, Editor. Home разрешает документ из durable
`state.draft.content`, Editor изменяет working buffer с явным Save и защитой выхода.
Library импорт сохраняется отдельной scoped operation и не сохраняет соседний
несохранённый ввод, не добавляет attachments и не публикует.
Editor захватывает исходный GitHub username вместе с документом для CAS.
Нетронутое поле обновляется после scoped/cloud изменения identity; собственный
изменённый ввод при конфликте сохраняется и не перезаписывает новую запись.

`PortfolioProject.iconId` принадлежит Library. Разрешённый каталог использует
существующие pinned Lucide IDs: `folder`, `file-text`, `panels-top-left`, `home`,
`image`, `camera`, `user-round`; default `folder`. Иконка сохраняется при GitHub
refresh и одинаково читается mobile/web/public/PDF. User SVG/URL не принимается.
Legacy image paths читаются для сохранности, современные outputs их пропускают.

Media сохраняет existing repository boundary. Новый avatar — bounded JPEG512,
до256KiB без metadata, owner-only immutable Firestore media document по existing
`accounts/UID/media/32hex.jpg` path. Trusted service проверяет/reencodes фото,
добавляет bounded JPEG data URI в public snapshot и проверяет общий размер до
записи. Storage/Blaze не нужны; legacy Storage не удаляется и ошибки честные.
Недоступный backend не создаёт фиктивную ссылку или success. Account lifecycle
сохраняет защиту неизвестных legacy media. Новые Storage create закрыты;
legacy read/delete остаются. Без bucket удаление доступно только аккаунтам,
созданным после доказанного operator cutover, задаваемого
`FIRESTORE_MEDIA_ONLY_ACCOUNTS_SINCE`; default пуст. Source date не доказывает deploy.

PDF генерируется из сохранённого содержимого с Manrope, pagination, URI links,
avatar и только catalog SVG. Android SAF/iOS document picker сохраняют байты;
web получает настоящий Blob. Отмена не считается успехом.
Для видимого legacy avatar URL без private path клиент читает ограниченный
HTTP(S) stream≤2MiB с network timeout10s, без credentials/redirects и локальных
адресов, затем применяет существующий MIME/dimensions/JPEG512 preprocessing.
Private path имеет приоритет, его ошибка не запускает URL fallback. Browser CORS
или недоступность старого URL дают ошибку экспорта без изменения сохранённого фото.

## Проверки

Обязательны миграция/backup/reopen, Dart-web roundtrip, UID/late ACK isolation,
optional empty save, privacy projection/Rules, durable batch import/ID dedup,
icon preservation, actual PDF structure/render, keyboard/320/text2 и явная
публикация. Headless, emulator, native и live ограничения записываются отдельно.
