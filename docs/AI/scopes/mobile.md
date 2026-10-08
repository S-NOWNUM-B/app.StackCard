# Правила StackCard Mobile

Область этих правил — `apps/mobile/`.

Общие правила и границы текущей фазы наследуются из [общих правил](../AGENTS.md).
Перед изменениями прочитай [общий AI router](../README.md) и применимые
guides. Этот файл дополняет их только для Flutter-приложения.

## Источники

Ниже описан действующий Flutter runtime. [Design v2](../../redesign/README.md)
задаёт target; [product status](../../product/product-spec.md#статус-и-границы-текущей-работы)
задаёт разрешённый scope. С 2026-10-07 очередь фаз на паузе, разрешено развитие
mobile capabilities: четыре root tabs, смешанная Home library, независимые
Resume/Portfolio и общая база. D048 (2026-10-08) также разрешает завершение
mobile settings/attachments и публикацию вместе с web. Механизм сохраняет existing draft repository,
UID boundaries, Hive queue и outbox, без второго runtime/write store.
Media и location используют прежние features; карта/Maps исключены.
[Prerequisites](../../redesign/prerequisites.md) разделяет фактически реализованный
private slice и оставшийся proposal. R7 остаётся awaiting_review;
headless проверки не закрывают native visual, public/web или auth acceptance.

- SDK constraint и зависимости: [pubspec.yaml](../../../apps/mobile/pubspec.yaml); разрешённые версии:
  [pubspec.lock](../../../apps/mobile/pubspec.lock). Не добавлять неиспользуемые зависимости.
- Анализ: [analysis_options.yaml](../../../apps/mobile/analysis_options.yaml).
- Entry point: [lib/main.dart](../../../apps/mobile/lib/main.dart); GoRouter:
  [app_router.dart](../../../apps/mobile/lib/app/app_router.dart), app shell:
  [app_shell.dart](../../../apps/mobile/lib/app/app_shell.dart).
  Native entry запускает `StackCardBootstrap`:
  [LocalRuntime](../../../apps/mobile/lib/app/local_runtime.dart) читает settings,
  открывает [LocalStorage](../../../apps/mobile/lib/core/storage/local_storage.dart)
  и инициализирует Firebase Auth/Firestore до создания `StackCardApp`.
  [firebase_options.dart](../../../apps/mobile/lib/firebase_options.dart) и native
  configs — generated configuration; runtime initialization остаётся в LocalRuntime.
  Ошибка startup показывает loading/error/retry без demo fallback;
  storage закрывается при disposal, включая поздно завершившееся открытие.
- Цвета, typography и tokens: [core/theme](../../../apps/mobile/lib/core/theme/);
  общие UI-компоненты: [shared/widgets](../../../apps/mobile/lib/shared/widgets/).
  Перед новым widget искать существующий аналог и использовать `context.colors`.
  Фактический UI contract — [design guide](../../design/design-system.md#действующий-runtime-contract-r8).
  `core/theme` остаётся единственным механизмом: semantic `primary/onPrimary`
  — Lime/ink в обеих темах, error/destructive отделён; `textMeta`, `accentText`,
  `successText`, `controlOutline`, `primaryOutline` задают читаемые пары по состоянию.
  Manrope и Noto fallback зарегистрированы в pubspec; не возвращать red/white CTA.
  `StackCardButton` сохраняет loading/disabled/focus/semantics и внешний target48,
  `StackCardInput` — label/focus/validation/input retention. Auth остаётся scoped
  `StackCardTheme.authentication`, без poster. Имеющиеся Card/Poster/StateView
  расширять, не создавать параллельную UI library; декоративная графика исключена
  из semantics. Legacy композиции не считать target Design v2 parity.
  [StackCardIcon](../../../apps/mobile/lib/shared/widgets/stackcard_icon.dart)
  загружает pinned SVG; Lucide допускает semantic tint, технологии — original
  source fills/зафиксированный React-TypeScript brand mapping. Flutter CSS
  compatibility — отдельный `flutter.render.svg`, canonical raw не менять.
  [TechnologyBadge](../../../apps/mobile/lib/shared/widgets/stackcard_technology_badge.dart)
  сохраняет живой label/wrap; +N — настоящий control с полным списком.
  [StackCardBrand](../../../apps/mobile/lib/shared/widgets/stackcard_brand.dart)
  использует один original outlined Wordmark A либо compact Mark, paper/ink,
  contain/no tint. D048 native AppIcon PNG экспортированы в existing Android
  mipmaps/iOS set; [ledger](../../redesign/source/native-app-icons.json) фиксирует
  pinned source, hashes/dimensions/alpha. Packaging source не означает native
  build/launch/parity.
  Provenance — [source-manifest.json](../../../apps/mobile/assets/design_v2/source-manifest.json),
  Figma variables/styles — [figma-design-v2.json](../../redesign/source/figma-design-v2.json),
  portable strict checker — [check_imports.py](../../../tools/redesign/check_imports.py).
- ThemeMode/Locale/preferences: [AppearanceController](../../../apps/mobile/lib/core/state/appearance_controller.dart)
  через Provider; pure Dart [AppSettings](../../../apps/mobile/lib/core/state/app_settings.dart)
  и [SettingsRepository](../../../apps/mobile/lib/core/state/settings_repository.dart)
  находятся в нейтральном `core/state`. Query/filter state Projects:
  [project_filters.dart](../../../apps/mobile/lib/features/projects/presentation/project_filters.dart)
  через Riverpod. Projects UI применяет только `query`; прежний category/filter
  provider остаётся совместимым для других callers, не скрывает Projects records.
  GitHub Import имеет отдельный search/filter contract. Не дублировать state
  в widget state или router callbacks.
  Provider ограничивается базовыми app settings. UI использует реальные ru/en
  переводы из [core/localization](../../../apps/mobile/lib/core/localization/);
  source content не переводится автоматически. Сравнение и учебные patches — в
  [state management guide](../../learning/state-management.md), вне runtime `lib`.
- Settings persistence:
  [SharedPreferencesSettingsRepository](../../../apps/mobile/lib/features/settings/data/shared_preferences_settings_repository.dart)
  использует SharedPreferencesAsync для одного versioned snapshot theme/language/
  source descriptions/reducedMotion. Runtime объединяет reducedMotion с OS
  disableAnimations; nav duration становится zero. Controller последовательно сохраняет последнее состояние;
  failure оставляет выбор в UI с retry. Corrupt/unknown preferences дают defaults;
  пользовательский draft не хранится в preferences.
- Feature APIs: [auth.dart](../../../apps/mobile/lib/features/auth/auth.dart),
  [profile.dart](../../../apps/mobile/lib/features/profile/profile.dart),
  [projects.dart](../../../apps/mobile/lib/features/projects/projects.dart),
  [github_import.dart](../../../apps/mobile/lib/features/github_import/github_import.dart),
  [portfolio_draft.dart](../../../apps/mobile/lib/features/portfolio_draft/portfolio_draft.dart),
  [portfolio.dart](../../../apps/mobile/lib/features/portfolio/portfolio.dart).
  Между features импортировать только публичные APIs; `domain` остаётся pure Dart.
  Presentation использует domain и providers, data реализует repository contracts.
- DI находится у корня feature: auth/projects providers и profile dependencies
  связывают concrete repositories; profile/projects providers читают рабочий
  Builder content через публичный draft API либо demo repositories при content null.
  Widgets не импортируют data sources.
  `StackCardApp.providerOverrides` передаётся своему ProviderScope и позволяет
  менять источник для реальных экранов. Native `LocalRuntime` подставляет Hive
  cache, account Auth adapter и guest/UID draft factory с Firestore sync для account;
  memory defaults сохраняют изоляцию preview/tests `StackCardApp`.
  Не дублировать DI в widgets и не открывать boxes из экрана.
- Демонстрационные данные принадлежат
  [DemoAuthRepository](../../../apps/mobile/lib/features/auth/data/demo_auth_repository.dart),
  [MockProfileRepository](../../../apps/mobile/lib/features/profile/data/mock_profile_repository.dart) и
  [MockProjectsRepository](../../../apps/mobile/lib/features/projects/data/mock_projects_repository.dart).
  Demo-вход не авторизует аккаунт; эти источники не обращаются к GitHub/backend
  и не сохраняют draft. GitHub Import имеет отдельный публичный HTTP-источник.
- Account Auth: [публичный auth API](../../../apps/mobile/lib/features/auth/auth.dart)
  раскрывает pure Dart `AccountAuthRepository`, `AuthUser` и typed `AuthFailure`.
  [Firebase adapter](../../../apps/mobile/lib/features/auth/data/firebase_account_auth_repository.dart)
  выполняет email/password, registration, reset, Google credential exchange и
  sign out; Firebase session stream остаётся источником истины.
  [auth providers](../../../apps/mobile/lib/features/auth/auth_providers.dart)
  разделяют nullable account repository, session и явный `guestAccessProvider`.
  Password/token/credential не сохраняются приложением; SDK владеет persistence.
  Legacy `AuthRepository`/`DemoSession` остаются preview API без native configuration.
  Restoring/error/signedOut без guest access блокируют private routes и draft;
  нельзя читать guest или предыдущий UID как fallback. Error/retry остаётся явным.
- Stateful Shell имеет четыре roots: `/home`, `/resumes`, `/projects`, `/portfolio`.
  Labels и bottom nav сохраняются на tablet; branch state сохраняется при смене
  вкладки. Home фильтрует Все/Резюме/Проекты и включает Portfolio в «Все».
  Resume/Portfolio roots показывают private document libraries. Gear≥48 открывает
  standalone `/settings`; `/settings/appearance` и `/settings/account` вне Shell.
  Back возвращает origin; UID/access boundary сбрасывает private branch state.
- Routes именованы в `app_router.dart`; `/register` и `/reset-password` — auth
  forms, Builder forms вложены в `/portfolio/builder`, project edit получает `id`.
  Home/Portfolio/Projects/Settings/notes/Builder/editor/preview требуют account
  либо явно выбранного локального guest; GitHub Import публичен.
  `from` допускает только разрешённый локальный destination. UID/access boundary
  заменяет draft controller/projections, сбрасывает фильтры и private form state.
  Sign out с unsaved changes требует подтверждения их отбрасывания; durable
  draft остаётся сохранённым. App settings/public cache сохраняются независимо UID.
- GitHub Import: [contract](../../architecture/architecture.md#github-import-http-и-persistent-кэш)
  и [DI](../../../apps/mobile/lib/features/github_import/github_import_providers.dart).
  Dio/JSON/cache — data; бизнес-модели и username/selection — pure Dart domain;
  cancellable loading/refresh/pagination/debounce — Riverpod controller.
  API next links валидируются по host и identity профиля. Только явный retry,
  rate deadline блокирует запросы; поиск ограничен загруженными страницами.
  Async [response cache contract](../../../apps/mobile/lib/features/github_import/data/github_response_cache.dart)
  используется для ETag/304;
  [Hive adapter](../../../apps/mobile/lib/features/github_import/data/hive_github_response_cache.dart)
  хранит versioned body/ETag/Link по URI. Hard TTL — 7 дней с успешного `200/304`;
  network-first fallback разрешён только для network/timeout/server. Expired,
  corrupt, future-dated и unknown-schema cache entries исключаются из fallback.
  Публичный [GitHubReadMetadata](../../../apps/mobile/lib/features/github_import/domain/github_read_metadata.dart)
  сообщает источник, дату и storage failures; смешанные страницы сохраняют
  предупреждение. Отмена проверяется после storage awaits и перед fallback.
- Local portfolio draft: публичный `portfolio_draft.dart` раскрывает pure Dart
  `PortfolioDraft`, `PortfolioContent`, validation/completion, repository,
  session state/controller и Builder/preview. Private notes лежат вне content;
  экран `/portfolio-draft` использует тот же controller, preview не показывает notes.
  Content null означает прежние заметки или ещё не начатый Builder; начало создаёт
  пустой content без копирования demo/GitHub source. Controller хранит рабочий
  notes/content и durable snapshot; навигация не теряет применённые, но ещё
  не сохранённые правки. Формы применяют валидный результат целиком; отмена
  не меняет content. Save сохраняет захваченный snapshot, более новый ввод
  остаётся unsaved; повторная запись одновременно не выполняется.
  [HivePortfolioDraftRepository](../../../apps/mobile/lib/features/portfolio_draft/data/hive_portfolio_draft_repository.dart)
  последовательно проверяет expected revision и пишет envelope v7; v1–v6 читаются
  без eager migration, explicit Save/ACK пишет текущую версию. Conflict
  сохраняет несохранённые правки и требует явного решения перечитать durable draft.
  `saveNotes` изменяет только notes, сохраняя content. Чтение v1 не пишет migration:
  точные notes/metadata возвращаются с content null; первая явная запись сохраняет
  raw owner-scoped backup исходной версии перед заменой. Ошибка backup/write сохраняет прежний durable draft;
  corrupted/unsupported draft блокирует перезапись. Draft не имеет TTL.
  [LocalDraftAccounts](../../../apps/mobile/lib/features/portfolio_draft/data/local_draft_accounts.dart)
  сохраняет прежние guest keys и отдельные UID namespaces через base64url UTF-8.
  `portfolioDraftRepositoryFactoryProvider` выбирает owner repository; каждый
  экземпляр фиксирует key и выполняет in-flight save только в свой namespace.
  Общая очередь Box сериализует adapters и transfer. Transfer запускается явно
  в Settings; configured runtime требует online claim и пустой local/cloud target,
  offline cache miss не означает cloud emptiness. LocalRuntime server-only preflight
  пропускается только для своего pending journal; transaction закрывает race.
  Source envelope/revision/notes/content и raw backups v1–v6 сохраняются;
  v1 не мигрируется при чтении, ACK после явного transfer пишет текущую версию.
  Durable journal резервирует source одному UID до online create-if-absent claim;
  retry допускает только тот же mutation ID/notes/content. Remote ACK metadata
  сохраняется до local destination/cleanup; durable syncPrepared не позволяет
  повторить claim после завершённого remote этапа. Подтверждённый occupied-cloud
  conflict освобождает unfinished journal при отсутствии local destination и
  !committed, включая retry после потерянного ACK; удаляется только validated
  matching-transfer sync metadata. Guest и cloud данные сохраняются. Неоднозначный
  network failure оставляет reserved recovery; corrupted/unknown
  sync metadata блокирует операцию. Normal account sync сохраняет LWW.
  Phase 7 journal без syncPrepared с уже записанным target завершает исторический
  local transfer через legacyLocalCommit; прежняя pending версия следует LWW,
  без ложного server ACK или нового empty-cloud требования.
  Committed owner claim и generation завершаются перед guest cleanup. Неоднозначный сбой сохраняет
  recoverable source/journal и блокирует guest/owner до explicit retry тем же UID;
  другой UID не может забрать reserved source. Persistent generation запрещает
  старому guest repository/queued save воскресить transferred draft.
  После transfer создавать guest repository нового поколения при новом guest access.
  Profile/Projects сначала ждут coalesced `ensureLoaded()`; demo fallback допустим
  только после успешного read с content null. Подписка read model ставится после
  первого await, чтобы не повторять source call; failure/retry видны общим экранам.
  GitHub cache и draft используют отдельные boxes:
  cache можно удалить/восстановить, draft не затрагивается. LocalStorage сохраняет
  нечитаемый cache file как backup; повреждённый draft не обрезается автоматически.
- Builder routes: `/portfolio/builder` и дочерние `profile`, `skills`, `experience`,
  `education`, `links`, `resume`; ручные проекты — `/projects/new`,
  `/projects/:id/edit`; preview — `/portfolio/preview`. Десять уникальных блоков
  меняют порядок и видимость; preview читает текущий рабочий content.
  Пустые блоки пропускаются; Featured Projects показывает visible/featured проекты,
  Builder/Projects — все ручные записи для редактирования.
  `PortfolioTheme` dark/light использует существующую StackCardTheme при отображении
  content на preview отдельно от app ThemeMode. Legacy `resumeText` — обычный
  текст с переносами строк, без Markdown/файлов. Private документы создаются/
  редактируются по `/resumes/new`, `/resumes/:id/edit`, `/portfolio/new`,
  `/portfolio/:id/edit`; Resume creation — пять шагов, существующий документ —
  focused sections с собственным buffer. Scoped saveDocument/saveProject/
  saveDeveloperProfile используют captured repository/expected entity/revision;
  соседние unsaved slices/notes не отправляются этим Save. New Project в документе
  остаётся local buffer до `saveDocument(newProjects: ...)`: Library+relation
  пишутся одной revision, Cancel не создаёт Project. Полный контракт —
  в [architecture](../../architecture/architecture.md#общая-база-и-независимые-документы).
  [Review базы](../../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_document_base_review.dart)
  сравнивает nullable last-reviewed baseSnapshot, buffer и saved base; profile
  fields/stable-ID items выбираются отдельно. Legacy не имеет предвыбранных замен;
  local-only записи и порядок остаются. Apply сохраняет captured baseline в buffer,
  Save отдельный; Cancel/UID transition/stale base/изменённый buffer не применяют
  captured выбор. Нельзя брать unsaved общую базу или записывать другой документ.
  Attachments содержат optional title/description/contribution overrides;
  null наследует Library, явное значение относится только к документу.
  `SocialLink` отделяет разрешение базы `publishAllowed` (default false) от
  выбора в документе `visible` (default true); email/phone/telegram — typed kinds.
  Login email не является contact. `profile.publishLocation` default false;
  server projection повторно проверяет актуальное разрешение общей базы.
  Pure domain validation/completion живут в `features/portfolio_draft/domain`;
  процент вычисляется, скрытие блоков его не увеличивает. Remote sync сохраняет
  existing Phase 8 boundary; document publication в D048 — отдельное действие.
  Контракт зафиксирован в [ADR 0001](../../decisions/0001-firestore-sync-and-publication.md).
- Smart GitHub Sync: [ADR 0002](../../decisions/0002-github-import-and-review.md),
  [pure rules](../../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_github_sync.dart)
  и [bridge](../../../apps/mobile/lib/features/github_import/github_portfolio_providers.dart).
  Source/cache остаётся read-only для curated content до явных Add/Accept/Ignore;
  actions меняют working draft, Save отдельный. Repository ID задаёт связь и dedup;
  metadata хранит accepted source/UTC validatedAt и override fields, значения
  overrides остаются в curated полях. Editor использует withUserEdits и не теряет
  metadata. Ignore registry принадлежит UID/guest draft и source fingerprint,
  не SharedPreferences/cache. Новая версия source снова предлагает review;
  partial pagination/cache miss не удаляют проект. Cached snapshot не получает
  свежую дату проверки. Stale review/captured owner проверяются до применения;
  public browsing без account/explicit guest не открывает private repository.
  Public codec исключает source/override/ignore state; publication не вызывается.
- Suggestions: [pure rules](../../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_suggestions.dart)
  принимают content/source и явное время, возвращают immutable/stable advice.
  Числовые пороги принадлежат PortfolioSuggestionThresholds, UI не дублирует их.
  Preview suggestion по-прежнему открывает demo link (`liveUrl`);
  отдельные private images принадлежат media Phase 11.
  Projects использует accepted source offline, source cards — загруженную версию;
  updatedAt не выдавать за commit history. Ignore/version и hidden/featured
  учитываются, curated overrides сохраняются. Provider проверяет account/guest
  до private state; при UID transition предыдущие рекомендации убираются.
  [Общий UI](../../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_suggestion_list.dart)
  показывает ru/en причину и ведёт к прежним Preview/editor actions без записи.
  Domain, provider и widget tests — `test/portfolio_suggestions*_test.dart`;
  контракт — в [architecture](../../architecture/architecture.md#portfolio-suggestions).
- Media: [public API](../../../apps/mobile/lib/features/media/media.dart),
  [ADR 0003](../../decisions/0003-private-portfolio-media.md) и
  [Storage Rules](../../../firebase/storage.rules). SDK принадлежит media data;
  widgets читают public APIs. Camera/gallery вызываются явно; MIME/magic/size,
  resize/compression и EXIF cleanup происходят до upload. Private paths
  принадлежат UID, не download URLs. Progress/retry не меняют другой owner;
  Apply и Save отдельны, cancel не меняет draft. Guest не загружает изображения.
  Private bytes cache memory-only и исчезает при UID transition; external public
  avatars используют cached_network_image. Не удалять прежние durable paths
  при замене/ACK: offline/LWW может ещё ссылаться на них. Public projection
  legacy codec исключает media fields, sync не публикует. Новый trusted handler
  копирует выбранные изображения в immutable public namespace отдельно от private
  объектов. Hive writer v7/private cloud writer6 читают legacy versions без
  read-time rewrite; downgrade запрещён.
- Location: [public API](../../../apps/mobile/lib/features/location/location.dart) и
  [контракт](../../architecture/architecture.md#выбор-города-и-страны--phase-12).
  Picker подтверждает город/страну, manual input работает без permissions.
  Одно определение города вызывается явно; SDK/GPS/native geocoding — только data,
  наружу возвращается `PortfolioPlace`, без координат/адреса и background updates.
  Apply/Save отдельны; manual edits/Cancel/UID change защищены от позднего ответа.
  Существующее `locationText` и схемы сохраняются; hidden Location исключён public
  projection. Не возвращать карту, Maps SDK/API keys или billing в этот scope.
- Account sync: [pure contracts](../../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_sync.dart),
  [local-first repository](../../../apps/mobile/lib/features/portfolio_draft/data/synced_portfolio_draft_repository.dart),
  [Hive metadata](../../../apps/mobile/lib/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart)
  и [Firestore adapter](../../../apps/mobile/lib/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart).
  Save завершает local write до отправки captured outbox; pending переживает
  restart и разрыв cache/metadata write. Mutation/revision связывают ACK;
  старый ACK не подтверждает новый Save. Remote/cache pending events не считать
  server success; local revisions не сравнивать между устройствами.
  Whole-document LWW — по server commit order, поздний offline Save/retry может
  заменить другой draft целиком. Controller сохраняет unsaved ввод при remote
  hydration. Guest local-only; UID guard/dispose прекращают прежние subscriptions
  и retry. Permission/invalid-data failures требуют explicit retry; network
  retry не блокирует local Save и не ожидает бесконечно offline SDK future.
- Publication D048: [pure document API](../../../apps/mobile/lib/features/portfolio_draft/domain/document_publication.dart),
  [HTTP adapter](../../../apps/mobile/lib/features/portfolio_draft/data/http_document_publication_repository.dart)
  и [UID-bound providers](../../../apps/mobile/lib/features/portfolio_draft/document_publication_providers.dart)
  используют authenticated trusted service. Inventory/read-resolution и durable
  operation ID отделены от Save/точного server ACK. Unknown/timeout не показывать
  как success; Copy/Open/Share используют только confirmed published URL.
  Server читает saved workspace, deep validation/privacy/media projection
  выполняет до public write. Старый username-based `portfolio_publication.dart`
  остаётся legacy API, sync не вызывает ни один publication adapter.
  Account deletion journal сохраняет captured UID/operation/generation и случайный
  256-bit recoveryKey перед первым запросом. После утраты Auth ограниченный
  deletionStatus разрешает только outcome/retry прежней prepared operation;
  local owner cleanup выполняется после подтверждения, guest/другой UID сохраняются.
  Permanent URL/delete/security — в [architecture](../../architecture/architecture.md#privatepublic-schema-и-явная-публикация)
  и [Firebase scope](firebase.md). Endpoint/origin/deployment отсутствуют в live
  окружении, пока это не подтверждено отдельной проверкой.
- [PortfolioOverview](../../../apps/mobile/lib/features/portfolio/presentation/portfolio_overview.dart)
  объединяет profile/projects для Home и demo Portfolio; query/filter Projects
  не влияет на полный или featured список других экранов. Это presentation read model,
  не draft/published domain. `Profile`/`Project` также остаются read models;
  Home/document libraries/Projects/Settings читают единый workspace через
  публичные feature APIs, без отдельных write stores. `ProfileReadiness` получает
  счётчики из demo snapshot либо pure вычисления полноты Builder.
- Loading/error/retry: [StackCardAsyncView](../../../apps/mobile/lib/shared/widgets/stackcard_async_view.dart)
  использует существующий StackCardStateView; empty принадлежит экрану.
  Manual refresh — opt-in; UID/owner transition не показывает предыдущий owner
  content, loading/error/retry не выдаются за новую successful data.
  Асинхронные запросы повторяются явно через UI retry; сетевой GitHub Import
  показывает typed failure и сохраняет успешный список при refresh/page failure.
- UI checks: [widget_test.dart](../../../apps/mobile/test/widget_test.dart),
  [responsive_test.dart](../../../apps/mobile/test/responsive_test.dart).
- State checks: [appearance_controller_test.dart](../../../apps/mobile/test/appearance_controller_test.dart),
  [project_filters_test.dart](../../../apps/mobile/test/project_filters_test.dart),
  [state_management_test.dart](../../../apps/mobile/test/state_management_test.dart).
  При смене владельца состояния проверять навигацию, reset и новую app session.
- Repository/DI checks: `test/auth_repository_test.dart`, `test/auth_di_test.dart`,
  `test/profile_repository_test.dart`, `test/profile_di_test.dart`,
  `test/projects_repository_test.dart`, `test/projects_di_test.dart`.
  Проверять замену источника на реальных экранах, immutable outputs,
  loading/error/empty и явный retry. Учебные patches должны сохранять Phase 3 DI.
- Account checks: `test/firebase_auth_repository_test.dart`,
  `test/firebase_auth_controller_test.dart`, `test/firebase_auth_google_test.dart`,
  `test/account_auth_ui_test.dart`, `test/account_navigation_test.dart`,
  `test/account_draft_transfer_widget_test.dart` и `test/local_draft_accounts_test.dart`.
  Проверять session restore/error, typed auth failures, explicit guest access,
  guarded/named/nested routes, UID transition и in-flight save, real Hive reopen,
  migration/backup, transfer conflict и recovery после write/flush failure.
  Tests с заменяемым SDK не доказывают live Firebase/Google flow или iOS readiness;
  обязательную приёмку фиксировать по фактам в product spec.
  [Native acceptance](../../../apps/mobile/integration_test/account_runtime_test.dart)
  запускается отдельно с explicit opt-in на signed-out dev device; создаёт/удаляет
  disposable account, reset подтверждает только SDK/backend acceptance.
  Setup и команды — в [CONTRIBUTING](../../../CONTRIBUTING.md#firebase-configuration-и-окружение).
- Firestore checks: [sync repository tests](../../../apps/mobile/test/portfolio_sync_repository_test.dart)
  проверяют offline Save, durable outbox/reopen, crash recovery, newer Save during
  ACK, LWW, UID disposal и сохранность unsaved ввода. SDK mapping/projection и
  actual Rules проверяются отдельно от local wrapper. Native
  [firestore_runtime_test.dart](../../../apps/mobile/integration_test/firestore_runtime_test.dart)
  использует disposable dev accounts и отдельный test storage, без изменения
  ordinary draft/session; restart проверяется seed/check pair. Команды и
  предусловия — в [CONTRIBUTING](../../../CONTRIBUTING.md#firestore-rules-и-native-sync-acceptance).
  Наличие test file не доказывает успешный live run; результаты — в product spec.
- GitHub checks: `test/github_data_test.dart`, `test/github_import_controller_test.dart`,
  `test/github_import_widget_test.dart`; проверять parsing/cache/HTTP errors,
  cancellation/races, deadline/debounce/pagination, пустые данные и responsive UI.
- Persistence checks: `test/github_persistence_test.dart`, `test/local_storage_test.dart`,
  `test/local_runtime_widget_test.dart`; проверять реальный reopen, TTL boundary,
  offline/reconnect/304, изоляцию draft, повреждённые файлы и bootstrap lifecycle.
  `test/settings_persistence_test.dart`, `test/localization_test.dart` проверяют
  settings restore/write retry и ru/en UI. Draft repository/controller/widget
  проверяются в `test/portfolio_draft_repository_test.dart`,
  `test/portfolio_draft_controller_test.dart`, `test/portfolio_draft_widget_test.dart`:
  revision, input retention, unknown schema, Save failures и навигация.
  Builder checks дополнительно проверяют validation/completion, CRUD, порядок/
  видимость/тему preview, v1–v6 → v7 compatibility, stale revision и сохранение новых
  правок во время Save; имена актуальных tests — в `apps/mobile/test`.
- Локальные шрифты и лицензии: [assets/fonts](../../../apps/mobile/assets/fonts/);
  регистрация остаётся в pubspec. Manrope400/600/700/800 и OFL/pinned hashes
  проверяются manifest; original DM Sans/Noto сохранены. Новые original Brand A
  SVG находятся в assets/branding/design_v2; legacy assets не удаляются.
- Native configs находятся в platform directories этого приложения.
  Generated-файлы и `.metadata` вручную не редактировать.

Flutter/Dart-команды выполнять из `apps/mobile`; Git — из корня monorepo.
Платформы приложения — только Android и iOS; platform directories — `android/`
и `ios/`. Сайт и web-редактор находятся отдельно в `apps/web` на Next.js;
их правила — [Web scope](web.md).
Проверки format/analyze/tests и порядок разработки описаны в
[CONTRIBUTING](../../../CONTRIBUTING.md); запуск — в его
[быстром старте](../../../CONTRIBUTING.md#быстрый-старт).
Границы mobile и web определены в [architecture](../../architecture/architecture.md).

Для проверки source integrity, macOS zsh/bash, cwd корень monorepo:

```zsh
python3 tools/redesign/check_imports.py --require-imported --require-brand
```

Для headless regressions, macOS zsh/bash, cwd `apps/mobile`:

```zsh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
```

SVG/badge/brand tests — `stackcard_technology_badge_test.dart`,
`account_auth_ui_test.dart`; focus/buttons/input — `stackcard_button_test.dart`,
async UID/refresh — `stackcard_async_view_test.dart`. Сравнивать фактически
выбранный loader path/canonical geometry/opacity; unsupported SVG warnings
не игнорировать. Headless scale1/2/ru/en/keyboard/viewport checks не подменяют
native font/SVG/AppIcon, device smoke или live backend acceptance. Результаты
и фактические runtime ограничения фиксируются в canonical plan/product spec.
D048 visual/browser/native проверки разрешены последующим явным ответом пользователя;
исторические skipped checks не становятся выполненными автоматически.
