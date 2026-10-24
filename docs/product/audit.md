# Полный аудит StackCard — Phase20

Аудит начат2026-10-24 по поручению владельца вместо подготовки релиза.
Требования и критерии закрытия принадлежат [плану](product-spec.md#phase-20--полный-аудит-проекта).
Релиз отложен; signing/ID и история прежних проверок сохранены отдельно.

## Матрица сценариев

| Область | Текущие доказательства | Граница проверки |
|:---:|:---:|:---:|
| Guest/Auth/onboarding | `personalization_test`, `local_draft_accounts_test`, account/widget suites; browser registration,4 optional шага, второй пустой аккаунт и повторный вход; browser/actual emulator password reset с одноразовым OOB | Android и iOS SDK по11 checkpoints PASS; live Google и доставка настоящего письма отдельно |
| Editor/Home | `home_main_portfolio_widget_test`33 PASS, Editor32 cases и full suite; bounded mount/field identity/scroll/Save и длинный drag/drop/cancel | Saved main отделён от buffer; Android/iOS UI по3 checkpoints PASS |
| Projects/GitHub | Smart Sync/controller/HTTP suites, scoped Save и attachments в browser; blocked localStorage regression | Browser GitHub HTTP в компонентном regression синтетический, rate-limit/cache проверяются suites |
| Avatar/manual city/PDF |3 media race regressions; actual Android/iOS avatar SDK; image processor/PDF/location suites; настоящий PDF в browser | Android/iOS gallery selection/cancel, Android virtual camera capture/cancel и iOS camera denial PASS; PDF Save/cancel,30884bytes exact match на обеих платформах |
| Sync/cross-client | Cloud7/Hive8 codecs/legacy/Rules и mobile cross-client bridge; browser Firestore server CAS | Android/iOS native process-pair PASS, отдельные named apps/Hive без обычных данных |
| Publication | Backend43 unit +89 Rules/service, web URL/redirect/captured UID tests; browser Publish/Save/Unpublish | Локальный trusted Node API; постоянного hosting нет |
| Public reader/Card/QR | Public parser/privacy; actual Android/iOS QR screenshot decode точного URL, native Share без recipient и foreground Chrome/Safari anonymous reader;404 после withdrawal | Local trusted backend/Next, permanent live reader и physical camera scan отдельно |
| Account lifecycle | Actual browser password/email mutation с wrong reauth/OOB; UI delete теряет ACK после реального удаления Auth/draft/Inbox/Storage, reload восстанавливает receipt; bucketless empty отказ до lock | Bucketless delete требует operator cutover и проверяемый saved schema7 draft; защиту legacy media не ослабляли |
| Contact/Inbox/FCM | Actual browser Contact lost-ACK/retry→Inbox/read, withdrawn submit; permission revoke и две pre-send гонки в Rules/service | Android initial/grant/revoke и iOS actual Deny/Allow readbacks PASS; постоянный hosting отложен, live delivery/APNs отдельно |
| Diagnostics/privacy | Existing opt-in/redaction/consent suites; privacy/help проверяются native UI smoke | Crashlytics delivery Phase19 сохранён как прежнее evidence, новый report не отправлялся |
| Performance | Одинаковый большой fixture: Home39216→5355; Android native Editor23324→2606 mounted elements; web6 размеров/режимов без overflow | Host debug, Android profile и изолированный Chrome; не physical-device FPS |
| Cleanup/docs/tooling | Reference/entry-point audit; Python tooling69 PASS (testing47/release3/redesign4/git15), pinned assets PASS; локальные file links проверены | CLI/glob/generated/provenance/legacy migration не удаляются по отсутствию imports |

Flutter1398 tests PASS; LCOV13165/15080=87,30%,28 unreported (без новых exclusions).
Итоговые native результаты и открытые gates фиксируются в
[checks.json](evidence/phase20/checks.json). Зелёный unit suite не означает «100% функций».

## Исправленные дефекты

| Область | До | После и проверка |
|:---:|:---:|:---:|
| Mobile avatar menu | Открытое меню продолжало picker/remove после смены owner или avatar | Captured repository/generation/basis проверяются после await;2 RED→GREEN regressions |
| Mobile upload retry | Старый prepared upload оставался после внешней смены avatar, retry мог зависнуть busy | Basis change очищает failure/prepared/operation repository; RED→GREEN regression |
| Web GitHub | Getter `localStorage` мог бросить SecurityError до cache adapter и оборвать import | Сбой cache чтения оставляет сетевой import доступным; реальный React/Chrome regression |
| Web public Share | Сохранённый при mount URL мог относиться к предыдущему document | URL зависит от publicId, старый status сбрасывается; same-instance navigation/Copy browser regression |
| Trusted web HTTP | Publication HTTP не проверял demo project; fetch следовал redirects | Общий endpoint guard, cookies omit и redirects error во всех3 POST flows; настоящий307 не получает payload |
| Backend dependency | body-parser2.3.0 завершал процесс на compressed JSON с trailing bytes |2.4.0/qs6.16.1 в lock без смены SDK; actual HTTP RED→GREEN, production audit0 |
| Backend failed Publish | После CAS conflict и временного cleanup failure оставались public JPEG | Повтор той же failed операции повторяет cleanup, сохраняя conflict/private JPEG; real emulator RED→GREEN |
| Native runner | `--no-pub` сохранял release registrant без integration dev plugins | Штатный pub step восстанавливает plugins; regression сохраняет no-uninstall/process-pair guards |
| System evidence | Повтор stage или смена URL могли исказить приёмку | Android/iOS требуют один точный URL, порядок card/share/open и запрет продолжения после failure; guard regressions |
| Native acceptance tooling | Старый browser allowlist и отсутствие loopback reverse мешали Open; iOS Flutter AX markers не видны через системный picker | Observed Chrome URL bar/foreground, owned reverse с readback; iOS phase bridge проверяет только строгие markers, настоящий UI и отдельное PDF byte comparison |
| Main Editor | Eager shrinkWrap списки создавали23324 elements на большом fixture | Один owning scroll и lazy reorderable slivers:2606 elements; Save/controller identity и drag/drop/cancel покрыты stress tests |
| Editor после Library delete | Удалённое вложение возвращало строку без обязательного key в reorderable list | Keyed placeholder сохраняет buffer до explicit reload; Save блокируется при conflict, оставшийся workspace не меняется |

Publication token await и поздний HTTP ACK дополнительно проверены на смену UID:
POST не отправляется новому owner, поздний результат отклоняется. Это защита
существующего контракта, schema/public payload не меняются.

## Удаления и сохранённая совместимость

- Удалены runtime-unreachable `DeveloperProfileScreen`, старые GitHub source cards
  и review sheet,4 теста именно этих архивных компонентов и их unused helpers.
  Действующий bulk import/review и domain Smart Sync tests сохранены.
- Удалены unused `maxImages` и6 однообразных аргументов,2 перевода удалённого
  экрана, web `MediaUpload` wrapper и unused imports.
- Удалены `apps/web/pnpm-lock.yaml`/`pnpm-workspace.yaml`: scripts/CI используют
  npm и package-lock. Второй неиспользуемый dependency graph больше не поддерживается.
- Удалены unreachable attached Resume write branch и unused `prepare.existing`.
  Новый writer по ADR0005 публикует только main portfolio; legacy reader сохранён.
- Удалён отдельный runtime-unreachable demo cluster:7 файлов `features/profile`
  и3 `features/portfolio` (568 строк). Он не содержал persisted codecs; фактический
  профиль — `PortfolioProfile`.6 demo-only tests удалены, актуальные Projects/Home,
  cold read/error/reload/Save/route cases сохранены и усилены в
  `project_read_models_widget_test.dart` и `portfolio_draft_integration_test.dart`.
- Все production Flutter dependencies реально импортируются. Export barrels,
  abstract contracts, переводы с динамическими ключами, migration codecs,
  legacy Storage/Functions adapters, CLI/glob harnesses и pinned assets сохранены.
  Отсутствие runtime import или LCOV недостаточно для удаления совместимости.

Ignored build/.next caches не являются исходниками и не очищались ради размера diff.
Пользовательские draft/session, старая Android установка и приватный ключ сохранены.
Количество tests/строк LCOV меняется вслед за удалением архивных компонентов;
checker/threshold и exclusions не менялись, coverage искусственно не повышался.

## Измерения

Существующий mobile harness:200 projects×20 technologies,200 skills,30 experience,
20 education,10 links,21 documents;390×844/DPR1. SHA256 fixture до/после одинаков:
`ccdb1341879f6568890354f9687f5657f6e5cde9d8a36c989ada06d41c6ac775`.

| Home | До | После |
|:---:|:---:|:---:|
| Mounted elements |39216|5355 (−86,3%)|
| Mount wall clock, host debug |1319,733ms|438,824ms (один замер)|

Один `CustomScrollView` и ленивые project/experience/education rows сохраняют
порядок, tokens и обычный preview constructor. Регрессии проверяют bounded mount,
прокрутку к последним199/29/19 записям и замену saved snapshot после длинной прокрутки.
Пять синтетических screenshots просмотрены на обычной и узкой ширине/text2.
[До](evidence/phase20/mobile-performance-before.json) и
[после](evidence/phase20/mobile-performance-after.json) не доказывают native frame time
или retained heap; RSS/одиночный wall clock чувствительны к окружению.

Web component benchmark проверил editor/public на320/390/1440: overflow0,
PDF renderer не загружается до экспорта, экспорт3697ms/298500bytes.
Новой speculative cache/memoization без измеримого bottleneck не добавляли.
[Web measurements](evidence/phase20/web-performance.json) относятся к локальному
Chrome, не к deployed Next performance.

### Native profile

[Android profile](evidence/phase20/android-profile.json): Android17 emulator,
1080×2400/420dpi, настоящий profile mode/frames и VM post-GC allocation profile.
Home5356 elements, mount418ms; existing Library comparison32991→1902 elements,
post-GC heap уменьшен относительно исторического eager baseline. GitHub через
настоящий HTTP загрузил41 repository; PDF с avatar256334bytes.

Finder в самом harness удерживал прежний Editor Element tree. После явного
`reset()` и повторного полного прогона все4 выбранные UI-класса имеют0 instances
после unmount. Это подтверждает устранение искажения замера; не доказывает
отсутствие всех возможных утечек. Product disposal для этого не менялся.

Большой Main Editor дополнительно переведён с eager shrinkWrap списков на
ленивые `SliverReorderableList`/`BuilderTagsEditor.sliver` в одном owning scroll.
Контроллеры и buffer не пересоздаются при прокрутке. Конечный cache сохраняет
placeholder при длинном drag, затем очищается после drop/cancel; чужой pointer
cancel не сворачивает cache активного drag. Регрессии проверяют прокрутку до
последних записей, controller identity/Save, autoscroll более1500px и cleanup.

| Android profile, тот же fixture | До | После |
|:---:|:---:|:---:|
| Editor mounted elements |23324|2606 (−88,8%)|
| Editor mount wall |681,605ms|347,008ms (−49,1%)|
| Editor build p95 |126,829ms|12,575ms|

[После оптимизации](evidence/phase20/android-editor-profile-after.json): Editor
scroll3569 elements; после unmount все4 выбранные UI-класса снова имеют0 instances.
Library raster p95 в повторном прогоне28–31ms вместо прежних51–111ms при том же
исходном Library: это показывает зависимость virtual GPU от окружения.
Cold Editor sample содержит3 frames; плавность60FPS на физическом устройстве
по этим данным не объявляется. Raw timeline с symbol/source paths остаётся вне Git.

## Проверки и воспроизведение

Команды остаются в [CONTRIBUTING](../../CONTRIBUTING.md#полный-аудит--phase20),
версии/скрипты — в actual manifests и CI. Использованы существующие SDK/emulator,
browser, benchmark и Python harnesses. Новые browser regression cases находятся
в `apps/web/tool/testing/component-regressions.cjs`; runtime зависимости не добавлены.
Flutter full suite1398/analyze/format/LCOV, backend unit43/43, Rules/service89/89, web167/167, production build/typecheck/format,
Python tooling и assets gate прошли; точные счётчики находятся в checks.json.
HIGH [GHSA-27r3-jxmh-p828](https://github.com/advisories/GHSA-27r3-jxmh-p828) закрыт
совместимым transitive обновлением; воспроизводимый npm ci и HTTP compressed-body
regression прошли, fresh production audit web/backend0. Manifest и Firebase SDK неизменны.
Browser full journey8 checkpoints, additional reset/Contact/Inbox/privacy/Account10 и isolated component4 checkpoints прошли;
clipboard в browser stubs, GitHub ответы изолированного компонента синтетические.
Native Android использовал настоящие camera/picker/Share/browser channels.
На iOS Simulator QR декодирован Vision, UIKit Copy проверен системной вставкой
точного URL в Safari без ввода ожидаемой ссылки; Open проверяет foreground,
native address field, saved author и отсутствие private markers. Полный прогон
прошёл автоматически вместе с11 SDK checkpoints в двух процессах.
PHPicker выбирал только точный synthetic asset на созданном для аудита Simulator.
Notification Deny и Allow прошли на свежем/reset только тестовом Simulator
с auto-init=false, без запроса токена; это не delivery.
Отказ камеры подтверждён настоящим SpringBoard prompt и SDK permissionDenied.
`requestFullMetadata:false` не требует полного доступа к Photo Library; Android
modern picker/external camera не запрашивают storage/camera permission StackCard.

Все доступные проверки в текущем окружении завершены. Обычные Android/iOS
`main.dart` debug приложения и normal web production build восстановлены без
очистки пользовательских данных. Исходный iOS Simulator снова выключен,
созданный только для аудита Simulator удалён после проверки UUID/имени.
Результат сохранён в [restoration evidence](evidence/phase20/environment-restoration.json).

Документы обновлены по изменившимся контрактам: product spec/AI router/scopes,
architecture, CONTRIBUTING, web README и исторические ссылки удалённого UI.
Новый аудит не разрешает Git publication, deployment, billing или выпуск.

## Открытые ограничения

Полная приёмка фазы пока открыта. Владелец2026-10-24 подтвердил отсутствие
физического iPhone и Apple Developer team; APNs не принимается по Simulator.

Постоянный hosting/publication/Contact ранее отложен владельцем; новый rollout
аудитом не выполняется. Google OAuth требует реального тестового аккаунта:
в текущем Android emulator настроенных аккаунтов0. Browser и Auth emulator reset
прошли с одноразовым OOB, но доставка настоящего письма/hosted action и live
Google session этим не принимаются. Live App Check/FCM/APNs зависят от внешнего
окружения; текущие локальные результаты их не заменяют.

Android frame/GC traces получены на emulator; QR/Share/Open прошли на Android
emulator и iOS Simulator. Physical
camera scan и frame budget остаются отдельными hardware checks. В установленном
Flutter iOS Simulator поддерживает только debug; physical iOS profile требует
устройство. Отсутствие DevTools GUI не отменяет сохранённые настоящие VM traces,
но виртуальный GPU не доказывает physical60FPS.

Bucketless account deletion консервативно требует доказанный operator cutover и
saved schema7 draft; новый аккаунт без сохранённого draft этим safety contract
не принят. Политика не ослаблялась ради зелёного теста. Отсутствие настроенного
trusted backend должно показывать недоступность, не успешное удаление/публикацию.
Открытые пункты не вычеркнуты и не замаскированы обещанием «всё работает на100%».
