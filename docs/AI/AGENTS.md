# Правила StackCard

Перед работой прочитай [AI router](README.md), затем применимые guides и
актуальные configs/code. Более глубокие AGENTS действуют только в своей области.

## Scope и принятые решения

- Действующий scope определяется по
  [статусу продукта](../product/product-spec.md#статус-и-границы-текущей-работы).
  С 2026-10-07 пользователь поставил последовательную разработку по фазам на
  паузу и разрешил функциональное развитие mobile по Figma и концепции общей
  базы: навигация, библиотеки Resume/Portfolio, редакторы и связи с Projects.
  [План](../product/product-spec.md#план-разработки) сохраняет историю, требования
  и открытые проверки; пауза очереди не запрещает этот разрешённый scope.
  Обновление roadmap 2026-10-08 —
  [актуальные capabilities](../product/product-spec.md#актуальная-последовательность-2026-10-08).
  D048 (2026-10-08): прямое поручение «закончи перенос» и явный ответ «Также
  реализовать web и публикацию» расширяют разрешённый scope на mobile, actual
  web и document publication. Старые singleton/public-username задачи не задают
  target; это не приёмка полного переноса или разрешение deploy/billing/Git.
- Flutter-проект находится в `apps/mobile`; не создавать второе приложение в корне.
  Git относится ко всему monorepo. Next.js-приложение находится в `apps/web`;
  его правила — [Web scope](scopes/web.md), версии/команды — actual manifest.
  CI остаётся отдельной capability; mobile Firebase Auth введён на Phase 7,
  Firestore sync и Rules введены на Phase 8; явный GitHub import/review — Phase 9.
- Mobile targets — только Android и iOS. Сайт развивается отдельно в `apps/web`
  на Next.js; desktop и Flutter web не входят в scope мобильного проекта.
- Целевой продукт включает mobile и полноценный web: landing, download page,
  личный кабинет/редактор и публичные резюме/портфолио. Редакторы используют общие
  owner data и правила явной публикации; новый target предусматривает multiple
  outputs. Mobile хранит общую базу и независимые документы внутри существующего
  `PortfolioContent`, через один UID-bound draft repository. D048 вводит отдельные
  trusted public snapshots и постоянный `/d/<publicId>`: server читает сохранённый
  workspace, клиент не записывает public payload напрямую. Sync не публикует.
- Existing Pattern First: сначала изучить аналог и canonical source, затем менять.
  Минимальный scope, без лишних слоёв, зависимостей и unrelated изменений.
- Архитектура в [guide](../architecture/architecture.md) помечена как текущая или
  целевая. Не создавать пустые features/repositories/use cases заранее.
- Корневой README предназначен посетителю репозитория: назначение продукта,
  возможности и принцип работы. Структура и схемы — в architecture, roadmap —
  в product spec, запуск и команды — в CONTRIBUTING. Сохранять принятую редакцию
  README без служебной отметки статуса и отдельного раздела контроля публикации.
  Фактическая готовность описана в product spec; не заявлять о готовом релизе.
- GitHub — источник; curated portfolio и опубликованное представление контролирует
  пользователь. Sync не перезаписывает публичное портфолио автоматически.
- Сохранять стиль из [design guide](../design/design-system.md) и оригиналы
  `assets/branding`. Mobile использует `lib/core/theme` и `lib/shared/widgets`;
  расширять эти механизмы, не вводить параллельные tokens и компоненты.
  Актуальная инициатива — [StackCard Design v2](../redesign/README.md): сначала
  читать её README и [план](../redesign/plan.md), сопоставлять capability с реальными
  Figma/source contracts. D048 разрешает перенос mobile/web/publication вне
  последовательной очереди фаз; прежние поручения Phase 11/12
  сохранены как история. Карта полностью исключена. Приёмка редизайна открыта.
  Прежний [Figma-first план](../design/redesign-plan.md) сохраняется
  как история и не переопределяет последние требования. По D040 Lime/Manrope,
  shared controls и original Design v2 SVG/Brand A перенесены в существующий
  runtime через `core/theme`/`shared/widgets`; provenance —
  `apps/mobile/assets/design_v2/source-manifest.json`, текущий contract —
  [design guide](../design/design-system.md#действующий-runtime-contract-r8).
  Runtime использует четыре stateful roots: Home / Resumes / Projects / Portfolios;
  Home — mixed library, Resume/Portfolio — независимые private documents.
  Legacy Builder остаётся редактором общей базы. Полную Figma parity и live
  publication acceptance не считать выполненными из screens/headless checks.
  При UI-переносе сверять target и реальный source.
  Экраны получают demo/mock и GitHub source data через Repository и Riverpod DI; widgets
  не импортируют concrete sources. Публичные feature APIs и направления
  зависимостей описаны в [architecture](../architecture/architecture.md#mobile-modules--при-реальных-сценариях).
  Наличие demo-кнопки не разрешает
  подключение функций будущих фаз.
- GitHub Import — отдельный просмотр публичного источника. HTTP/DTO/response cache
  принадлежат `features/github_import/data`, контроллер — presentation;
  domain и публичные metadata остаются pure Dart. Чтение/refresh не меняют
  curated/published данные; Add/Accept/Ignore явно меняют working draft через
  публичный draft API, Save остаётся отдельным действием. Source snapshot и
  override fields разделены; repository ID исключает повторный импорт.
  Stale review и смена UID не применяют captured action к новому draft.
  Контракт — в [ADR 0002](../decisions/0002-github-import-and-review.md).
  Suggestions принадлежат pure draft domain: явное время и snapshots, стабильный
  read-only результат; UI объясняет правило и ведёт к Preview/editor, не пишет
  draft/publication. Пороги берутся из одного API; контракт — в
  [architecture](../architecture/architecture.md#portfolio-suggestions).
  Hive cache проверяется сетью; hard TTL 7 дней
  и fallback только для network/timeout/server определены в data contract.
  UI явно показывает сохранённую копию, дату и ошибки локального хранения.
- Native bootstrap через `LocalRuntime` восстанавливает `AppSettings` и открывает
  раздельные Hive boxes для GitHub cache и portfolio draft, инициализирует
  Firebase Auth/Firestore до `StackCardApp`. Configuration failure не включает demo fallback.
  ThemeMode/Locale и простые preferences принадлежат Provider AppearanceController;
  SharedPreferencesAsync сохраняет цельный settings snapshot, UI переведён на ru/en.
  `portfolio_draft` — публичный API общей базы, private documents и notes.
  Profile/Projects — проекции working content, запись принадлежит только draft
  repository. Документы хранят собственные структурированные секции и связи с
  Library; legacy `resumeText` сохраняется без парсинга. PortfolioTheme не
  заменяет app ThemeMode.
  Cache recovery/очистка не изменяют draft; неизвестный или повреждённый
  формат draft сохраняется с блокировкой перезаписи. Sources — в
  [mobile rules](scopes/mobile.md).
- Account authentication принадлежит pure Dart `AccountAuthRepository`/`AuthUser`
  и Firebase adapter через Riverpod. Session restoring/error/signedOut без явного
  guest access блокируют private routes/repository. Legacy demo API остаётся
  preview-механизмом без native account configuration. Local draft выбирается
  по UID; configured guest transfer явный, online, только в пустой local/cloud
  target: durable owner journal, create-if-absent claim и ACK до cleanup.
  Recovery не повторяет completed claim; normal sync сохраняет LWW.
  Guest generation защищает от stale saves. При смене UID очищать controller/projections, фильтры и
  private widget state; unsaved discard при sign out требует подтверждения.
  Settings/cache не зависят от UID; password/token не сохраняются приложением.
  Firestore sync Phase 8 использует тот же UID boundary поверх Hive; guest
  остаётся local-only. Save завершается локально, durable outbox хранит captured
  mutation/revision до server ACK; новый Save не теряет pending при старом ACK.
  Whole-document LWW определяется порядком server commits, не device clock.
  Remote update не отбрасывает unsaved working input; private/public границы,
  атомарность и последствия фиксирует [ADR 0001](../decisions/0001-firestore-sync-and-publication.md).
  Sync не вызывает publication repository; public UI/web вводятся отдельно.
  Rules/indexes/emulator config принадлежат `firebase`, их отдельные правила — в
  [Firebase scope](scopes/firebase.md). Generated mobile configs остаются у приложения.
- Имена кода/файлов — английские; комментарии и объяснения — русские.

## Разработка по плану

Прямое поручение пользователя 2026-10-09 разрешает Phase 14 Contact/Inbox/FCM
по [ADR 0004](../decisions/0004-contact-inbox-notifications.md). Scope и фактическая
приёмка находятся в product spec; новые фазы не разрешены этим переходом.
Обращения и device registrations — отдельные private collections, не часть draft.
Push не заменяет durable Inbox; demo/default runtime не обещает живой FCM.

**Действующее исключение D045/D046/D048:** по прямому поручению пользователя
последовательная очередь фаз поставлена на паузу. Разрешённый mobile/web/publication scope
из [product spec](../product/product-spec.md#статус-и-границы-текущей-работы)
выполняется по конкретным capabilities и сценариям, без повторного запроса
разрешения фазы для навигации, документов, базы и совместимой private migration.
Ответ 2026-10-08 явно разрешает web и публикацию документов; повторное разрешение
для них не требуется. Это не приёмка полного Figma/runtime и не разрешение
commit/push/deploy/billing. Последующий явный ответ пользователя «Да, выполнить
визуальную проверку web/mobile» разрешает preview/browser/native проверки D048;
фактические результаты и ограничения среды записывать отдельно.
Правила ниже описывают режим очереди фаз
при её возобновлении; минимальные изменения, проверки и сохранность данных
действуют всегда.

- Перед любой продуктовой задачей прочитай
  [план разработки](../product/product-spec.md#план-разработки), текущий статус
  и раздел нужной фазы. План обязателен для дальнейшей разработки mobile, web
  и backend; список будущих функций сам по себе не разрешает их реализацию.
- Соотнеси запрос с задачами и критериями готовности фазы, проверь фактическую
  реализацию. В начале работы кратко назови фазу, выполняемый пункт и проверяемый
  результат. Незавершённые задачи текущей фазы имеют приоритет.
- При возобновлении очереди выполняй фазы по согласованному scope и зависимостям.
  В обновлённой Phase 13 минимальный public runtime/reader и публикация из mobile
  могут появиться до полного owner web editor; 13a/13b/13c — части результата,
  prerequisites задаёт актуальный roadmap.
  Не переноси будущие зависимости, сервисы и функции в текущую фазу заранее.
  После каждого шага сохраняй запускаемое приложение.
- Завершай фазу только после выполнения её задач и критериев, подходящих проверок
  из [CONTRIBUTING](../../CONTRIBUTING.md#проверки) и отчёта о результате.
  Не объявляй её завершённой при непроверенном обязательном сценарии;
  фиксируй оставшуюся работу и ограничения.
- По завершении задачи обновляй фактический прогресс фазы и результаты проверок
  в product spec. При разрешённом переходе обновляй текущую фазу в его статусе
  и связанные описания. Не создавай отдельную копию плана или параллельный
  источник статуса в AI-инструкциях.
- Переход к следующей фазе требует подтверждения пользователя. Прямое поручение
  реализовать конкретную следующую фазу считается подтверждением; уже полученное
  разрешение повторно не запрашивай. Общий запрос следовать плану не разрешает
  автоматически реализовать все фазы.
- Изменение очередности, scope или учебного графика сначала согласуй с пользователем,
  затем обнови план и затронутые guides. Требования и
  [учебные сроки](../product/product-spec.md#учебные-требования-и-сдача)
  учитывай явно. Commit, push и публикация сохраняют отдельные правила авторизации.

## Хранение AI-контекста

AI-инструкции, router и optional registry хранятся в `docs/AI/`. Корневой и вложенные
`AGENTS.md` — точки входа со ссылками на общий контекст. Продуктовые guides остаются
в `docs/`, рабочие configs приложения — рядом с code и canonical sources.

## Источники и проверки

- Mobile dependencies/SDK: `apps/mobile/pubspec.yaml`, `apps/mobile/pubspec.lock`.
- Анализ: `apps/mobile/analysis_options.yaml`; entrypoint: `apps/mobile/lib/main.dart`.
- Native settings — внутри соответствующих platform directories `apps/mobile`.
  Generated-файлы и `.metadata` вручную не редактировать.
- Зависимость добавляется при реальном использовании в текущей фазе, без установок
  пакетов будущих этапов. Lockfile приложения отслеживается.
- После изменения выполнить подходящие format/analyze/tests из
  [CONTRIBUTING](../../CONTRIBUTING.md), проверить diff, ссылки и отсутствие секретов.
  Проверки и ограничения сообщать по фактическим результатам.
- При изменении source path/контракта обновить затронутые ссылки и guides вместе.
  Runtime values и версии остаются в configs, не копируются в AI-инструкции.

## Работа команды и Git

- Независимые части составной задачи можно делегировать. Средняя задача — до 3
  активных агентов включительно с ведущим; сложная — до 10 при доступных слотах.
  Каждому файлу один владелец; ведущий согласует контракты и проверяет интеграцию.
- Commit/push только по запросу пользователя. Не stage-ить посторонние изменения.
- Перед commit/pull/rebase/push прочитай [Git workflow](GIT_WORKFLOW.md).
  Subject: `type(scope):` на английском lowercase, затем подробное русское
  описание lowercase, в прошедшем времени мужского рода от первого лица.
  Обязательны одна пустая строка и отдельный пункт body для каждого фактического
  файла. Проверять сохранённый объект commit и точное совпадение путей до push.
- При будущей синхронизации с remote использовать rebase с autostash; не удалять
  локальные изменения и не обходить hooks ради завершения операции.
