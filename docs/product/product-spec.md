<div align="center">

# StackCard Product

**Мобильный и web-конструктор developer-портфолио с контролируемой публикацией**

![Stage full transfer in progress](https://raster.shields.io/badge/Stage-full_transfer_in_progress-111111?style=for-the-badge)
![Mobile + Web source](https://raster.shields.io/badge/Mobile_%2B_Web-source-C7FF1A?style=for-the-badge)

</div>

---

## Содержание

- [Статус и границы текущей работы](#статус-и-границы-текущей-работы)
- [Редизайн мобильного интерфейса](#редизайн-мобильного-интерфейса)
- [Концепция и аудитория](#концепция-и-аудитория)
- [Living Portfolio: данные и контроль пользователя](#living-portfolio-данные-и-контроль-пользователя)
- [Portfolio Suggestions](#portfolio-suggestions)
- [Пользовательский путь и экраны](#пользовательский-путь-и-экраны)
- [Portfolio Builder и Developer Card](#portfolio-builder-и-developer-card)
- [MVP и полный scope v1](#mvp-и-полный-scope-v1)
- [Offline, приватность и безопасность](#offline-приватность-и-безопасность)
- [Техническое направление и качество](#техническое-направление-и-качество)
- [Non-goals v1](#non-goals-v1)
- [План разработки](#план-разработки)
- [Учебные требования и сдача](#учебные-требования-и-сдача)

---

## Статус и границы текущей работы

**2026-10-08, D048:** поручение «закончи перенос» и явный ответ «Также реализовать
web и публикацию» разрешают завершение mobile-сценариев, actual Next.js web и
публикацию независимых Resume/Portfolio. Source пакета реализован; текущие
headless/emulator/browser/Android результаты ниже отделены от full acceptance
и live availability. Deploy/billing/
commit/push не запрошены. Последующий явный ответ «Да, выполнить визуальную
проверку web/mobile» разрешает D048 preview/browser/native checks; результаты
и ограничения среды записываются отдельно.
R7 awaiting_review, DESIGN_READY/REDESIGN_DONE и пользовательская приёмка открыты.

**2026-10-07: последовательная разработка по фазам поставлена на паузу**
по прямому поручению пользователя. Действующая работа — развитие mobile по Figma
и концепции «общая профессиональная база → несколько резюме и портфолио»:
новая навигация, библиотеки документов, редакторы, общая Library и связи.
Это разрешение функциональной разработки; история фаз и незакрытые проверки
сохраняются. Карта и Google Maps по прежнему решению исключены.

**Реализованный private mobile scope в исходниках:**

- Четыре stateful вкладки Home / Resumes / Projects / Portfolios с постоянными
  labels, Settings через gear, standalone редакторами и origin Back.
- Home показывает документы и проекты, три фильтра Все/Резюме/Проекты и порядок
  по дате изменения. Пустая Library не наполняется demo автоматически.
- Независимые Resume/Portfolio: создание, изменение, preview, дублирование,
  подтверждаемое удаление. Resume создаётся за пять шагов; существующий документ
  редактируется по секциям. Название/роль/секции/тема относятся к документу.
- Settings открывает общую базу профиля/навыков/опыта/образования/ссылок.
  Новый документ получает начальные значения базы; её изменение не переписывает
  уже созданные документы. «Обновление из профиля» в редакторе сравнивает
  сохранённую базу с последним просмотренным снимком: унаследованные изменения
  выбраны, собственные правки остаются невыбранными. Apply меняет только buffer,
  Save отдельно сохраняет документ. Legacy без снимка не предлагает автозамену.
- Project остаётся одной записью Library с отдельным contribution. Документ
  хранит ordered relations projectId/visible/featured и optional title/description/
  contribution overrides: null наследует Library, явное значение меняет только
  этот документ. Удаление связи сохраняет проект, удаление проекта
  очищает его связи. «Создать проект» в документе держит новую Library запись
  в local buffer; общий Save пишет Project и attachment атомарно одной revision,
  Cancel не добавляет проект. Portfolio может выбрать private Resume по ID.
- Scoped Save документа, проекта или базы использует прежний UID-bound draft
  repository; соседний несохранённый ввод и notes не публикуются/не сохраняются
  этим действием. Hive writer7/private cloud6 читают старые версии без rewrite
  при чтении, с raw backups до upgrade; legacy public schema1 прежняя.
- Public contacts отделены от login email: typed email/phone/telegram/links,
  разрешение базы `publishAllowed` default false и document selection `visible`
  default true. Публикация location разрешается отдельно (default false);
  privacy изменение требует explicit Publish/Unpublish для public snapshots.
- Старый Builder и `resumeText` сохраняются. Явный импорт legacy создаёт
  документы со stable legacy IDs; неизвестные/повреждённые записи блокируют
  перезапись. Полный контракт — в
  [architecture](../architecture/architecture.md#общая-база-и-независимые-документы).

**D048 publication/web реализованы в source:** authenticated HTTP
`documentPublication` читает server-saved workspace, создаёт trusted public
projection отдельного документа и постоянный `/d/<publicId>`. Реализованы exact
saved mutation/CAS, inventory/version, recovery unknown operations, immutable
public media и Unpublish/delete lifecycle. Next.js содержит landing/download,
Auth, owner базу/Library/document editors и anonymous published-only reader.
Account actions используют Firebase SDK; deletion journal восстанавливает прежнюю
операцию после утраты Auth. Проверки D048 приведены ниже; prepared legacy
username API не определяет этот public contract.
Private Resume attachment даёт public link только после отдельной подтверждённой
публикации Resume. Фиктивные URL или success для отсутствующего сервиса запрещены.

**Открытая приёмка:** полная Figma/visual/native/browser parity и прежние
Google/reset/iOS/media/location сценарии; live cloud6 sync и deployment Rules/
Functions/web ещё не подтверждены. Inbox/FCM, QR/Developer Card, store release
и billing остаются отдельными будущими capabilities. Новые результаты tests
не закрывают эти gates. Production публикации пользователя этим запуском не создаются.

Наличие кода не подтверждает проверку нового сценария. Итоговые проверки этой
работы фиксируются здесь по фактам; прежние 950/1068 PASS относятся к своим
историческим версиям и не доказывают новую document модель.

### Проверки D048 — 2026-10-08

Результаты ведущего по текущему пакету; emulator/browser использовали demo
accounts и fixture, production данные/публикации не менялись. Числа отдельных
focused прогонов не суммируются с полным suite.

| Проверка | Фактический результат |
| --- | --- |
| Mobile regression | Полный `flutter test --no-pub --reporter expanded` — **1323/1323 PASS**; run log `/private/tmp/stackcard-full-tests-final2.log`. Root-focused проверки — **45 PASS**. |
| Mobile static | Предыдущий final2 `flutter analyze --no-pub` — **0 issues**; final3 повтор ещё выполняется. Его итог не подменяется предыдущим PASS. |
| Assets | Strict `check_imports.py --require-brand --require-imported` — **41 files PASS**; `export_native_icons.mjs --check` с `SHARP_MODULE_ROOT=firebase/functions/node_modules` — **20 exact PNG PASS**. |
| Backend | `npm run test:all-rules` — **51 PASS**: Firestore30, actual Admin-SDK service11, Storage10. Focused barrier/race service run — **11 PASS**; latest pure projection suite — **14 PASS**. |
| Web static/contracts | Последний завершённый `npm test` — **61 PASS**, typecheck — **PASS**. Final production build ещё ожидает завершения browser session; новый build PASS не заявлен. |
| Browser E2E | Actual demo Auth → mobile cloud6 fixture → web CAS Save → Publish → anonymous HTML. HTML не содержит private fields. Save новой роли сохранил прежний public snapshot; dirty Unpublish сохранил ввод, withdrawn403 дал friendly unavailable state; Save+Republish сохранили publicId. Реальный Copy UI показал success. |
| Native Android | Debug build текущего source — **PASS**. Изолированная demo session: Home, Project editor, Resume editor и Contacts Dark/Light запущены; screenshots просмотрены ведущим. Native Share sheet ещё проверяется. |
| Documentation | 11 updated files: оформление/local links — **PASS**; hero/badges и TOC order семи guides — **PASS**; owned-document `git diff --check` clean. |

Проверены реальный web service flow и выбранные Android экраны. Полная Figma
parity/journey matrix и user acceptance не объявляются завершёнными. iOS runtime
недоступен: нет полного Xcode/simctl. Actual native Auth/Google, camera/picker,
успешная geolocation, native Share/Open и live cloud6/Rules/Functions/web deployment
этим evidence пока не закрыты. R7 awaiting_review, DESIGN_READY/REDESIGN_DONE
сохраняются; Inbox/FCM/QR/release остаются будущим scope.

**Проверки функционального обновления 2026-10-07, macOS zsh:**
`flutter analyze` — без замечаний; полный `flutter test --no-pub` — **1163/1163 PASS**;
format `lib test integration_test` — 222 файла, без изменений;
Firestore Emulator `npm run test:rules` — **36/36 PASS**; проверка импортированных
Figma assets `check_imports.py --require-brand --require-imported` — PASS;
`git diff --check` и ссылки/оформление 13 обновлённых Markdown документов — без ошибок.
Проверены независимые Save/Discard, reopen, scope/revision конфликты, смена UID,
очистка открытых modal, ввод во время записи, create-and-attach одной revision,
неразрушающие upgrades/backups и четыре вкладки. Responsive матрица содержит
168 случаев, отдельно проверены narrow editor, увеличенный текст и keyboard inset.
Эти проверки не заменяют native camera/gallery, live Firebase sync/deploy,
визуальную приёмку пользователем и multiple-document public flow.

**Проверки обновления из общей базы (D046), macOS zsh:**
полный `flutter test --no-pub --reporter expanded` — **1212/1212 PASS**;
`flutter analyze --no-pub` — без замечаний; format `lib test integration_test` —
227 файлов, без изменений; Firestore Emulator `npm run test:rules` — **42/42 PASS**.
Проверены local overrides, stable-ID добавление/удаление, legacy без baseline,
Cancel/Apply/Save, повторное открытие, stale base/input и смена владельца.
Migration checks сохраняют raw backups и pending/ACK; Rules принимают 20 документов
с разными собственными snapshot/baseline avatar paths и отклоняют чужой путь
в последнем документе. Literal UID quoting проверен с regex-символами и вложенным
`\E`; missing обязательные поля и downgrade отклоняются. Public schema1 не
получает private documents/baselines. Strict Figma asset checker, `git diff --check`
и validator 11 обновлённых Markdown документов — PASS. На этапе D046 действовало
no-preview/run: native launch и визуальная приёмка пропущены; Rules не развёрнуты,
live sync cloud5 payload ещё требует отдельной проверки окружения.

История выполненных этапов и состояния перед этим поручением:

**Phase 0: Product foundation завершена.** Проверки кода и документов пройдены;
debug APK собран и запущен на Android-эмуляторе, изменение счётчика подтверждено.
По прямому поручению пользователя выполнена **Phase 1: UI foundation**:
пять экранов на mock data, Material 3 темы, общие компоненты и GoRouter.
По следующему поручению выполнена **Phase 2: Basic state management**:
эволюция темы `setState → InheritedWidget → Provider`, Riverpod для поиска/фильтров
Projects и воспроизводимые учебные этапы вне рабочего кода.
По следующему поручению завершена **Phase 3: Architecture**: features
auth/profile/projects разделены на `presentation/domain/data`, Repository
contracts и Riverpod DI позволяют заменять демонстрационные источники.
По следующему поручению завершена **Phase 4: GitHub API**: отдельный GitHub Import
загружает публичный профиль и repositories через Dio, поддерживает pagination,
refresh, локальный поиск/filter и повтор запроса после ошибки.
Результаты проверок и Android-запуска зафиксированы в
[разделе Phase 4](#phase-4--github-api).
По предыдущему поручению завершена **Phase 5: Local persistence / offline**:
theme, ru/en locale и настройка описаний источника сохраняются в SharedPreferences;
Hive хранит GitHub cache и отдельные локальные заметки с revision/pendingSync.
Перезапуск, offline и reconnect проверены на Android;
подробности — в [приёмке Phase 5](#phase-5--local-persistence--offline).
По предыдущему поручению завершена **Phase 6: Portfolio domain и локальный Builder**:
единый draft, ручные формы и preview без публикации. Resume выбран обычным
текстом с сохранением переносов строк; файловые вложения в этой фазе не вводятся.
По предыдущему поручению реализована **Phase 7: Firebase authentication**: account
session, защищённые routes и UID isolation. Обязательная Google/reset/iOS приёмка
остаётся открытой в [Phase 7](#phase-7--firebase-authentication). По явному следующему
поручению пользователя завершена **Phase 8: Firestore synchronization**: private draft,
состояния синхронизации и правила доступа; схема зафиксирована в
[ADR](../decisions/0001-firestore-sync-and-publication.md).
По следующему прямому поручению завершена **Phase 9: Living Portfolio / Smart GitHub Sync**:
явный импорт repositories, review изменений и сохранение ручных overrides.
По следующему прямому поручению завершена **Phase 10: Portfolio Suggestions**:
детерминированные подсказки с объяснением и явным действием владельца.
Этот документ отделяет реализованный интерфейс от целевых функций.
Flutter-приложение находится в `apps/mobile`; D048 создаёт Next.js runtime в
`apps/web` и trusted publication service в `firebase/functions`.
Историческая Git delivery: remote `origin` уже подключён; `main` отслеживает `origin/main`.
Для дальнейшей разработки выбрана ветка `dev`, отслеживающая `origin/dev`.
Commit и push выполняются только по запросу пользователя.

План фаз 0–20 документирован как история, требования и будущие зависимости.
Действующее исключение для mobile/web/publication capabilities закреплено в
[общих AI-правилах](../AI/AGENTS.md#разработка-по-плану), mobile AGENTS и router.

Текущие Home/document libraries читают реальную общую базу из draft; пустая база
остаётся пустой. Legacy preview/read models сохраняют demo только для
исторических изолированных сценариев. GitHub Import отдельно читает публичный
HTTP-источник с cache/offline fallback; чтение и refresh не меняют curated базу.
Add/Accept/Ignore явно меняют working Library, Save отдельный. Firebase Auth и
Firestore sync подключены в native bootstrap; draft хранится по guest/UID.
Settings/cache независимы от UID; auth session восстанавливается SDK.
Unsaved ввод остаётся session state, сохранённые документы/notes переживают reopen.
Whole-document server-order LWW сохраняется и не обещает merge между устройствами.

R7 source/graph QA D041 остаётся historical PASS и **awaiting_review**:
явная приёмка/DESIGN_READY и REDESIGN_DONE не установлены. Новый private mobile
scope разрешён последним поручением, а remaining
[prerequisites](../redesign/prerequisites.md) разделяют pending public/web/account
контракты. Исторический перенос UI D040 и его результаты сохранены ниже.

---

## Редизайн мобильного интерфейса

**Результат (2026-10-04):** по прямому поручению пользователя в существующей
ветке `redesign/full-app` переработан UI возможностей Phase 0–10. Палитра
Obsidian/Signal Red расширена acid/cyan/pink; UI адаптирует композицию
прикреплённого референса и короткие controls/sections из 21st.dev.
Общий визуальный контракт для mobile и будущего web находится в
[design system](../design/design-system.md).

**Задачи и приёмка**

- [x] Обновить canonical theme/shared widgets, навигацию и Home.
- [x] Переработать auth, Portfolio, Projects, Settings, GitHub Import/review,
  Builder, формы, notes и preview; убрать вложенные cards, повторные подписи
  и декоративные badges. Metadata/revision/date доступны через раскрытие.
- [x] Сохранить critical states и явные actions; auth/guest/transfer, CRUD,
  Save/reload, sync, Add/Accept/Ignore, visibility/order и private preview
  проверены existing tests. Domain/data/controllers/providers, Rules/schema,
  dependencies и оригинальные branding assets не изменены.
- [x] `dart format lib test integration_test` — **181 files, 0 changed**;
  `flutter analyze` — **No issues found**; полный `flutter test` — **822 passed**.
  UI expectations адаптированы к коротким действиям и раскрытию metadata.
  Contrast/touch-target проверки измеряют целиком отрисованный контент при
  исходной ширине; пороги WCAG/Android не снижались, overflow/goldens остаются
  на исходных viewports.
- [x] Обновлены **56** Flutter previews для основных экранов и Builder в
  light/dark, portrait/landscape phone/tablet. Выборочно просмотрены Home,
  Sign In, Portfolio, Projects, Settings, Builder hub и light preview,
  включая phone и tablet layouts.
  Responsive checks включают 320 px и text scale 2, Builder/review — ru/en
  и клавиатуру. Ordinary `main.dart` собран и запущен на `emulator-5554`,
  native Sign In и Home после guest access просмотрены; checksum существующего
  `portfolio_draft.hive` совпал до/после запуска.
- [ ] Native iOS запуск не проверен; прежняя открытая приёмка Phase 7 сохраняется.

**Уточнение входа (2026-10-04):** по обратной связи пользователя удалён весь
розовый декоративный poster со слоганом. Вход, регистрация и сброс пароля
используют центрированный по обеим осям блок шириной до 400 px и отдельно
центрированный brand; текст формы остаётся слева. По следующему уточнению
введены нейтральные ссылки и матовые поля/кнопки с radius 12;
recovery, submit/Google, переход режима и guest образуют последовательные группы.
Прошли 52 auth/navigation/widget/localization tests, включая 6 новых проверок
геометрии центрирования, контраста, targets и доступности submit с клавиатурой
на phone/tablet для всех трёх режимов и обеих тем. Дополнительно прошли 20
responsive checks демо-входа, включая 320 px и text scale 2; обновлены 8 demo
previews и созданы 6 account previews. `flutter analyze` — **No issues found**.
Все три account формы собраны и просмотрены на `emulator-5554`;
checksum локального draft до/после совпал.

**Единые основные кнопки (2026-10-04):** по последнему уточнению пользователя
auth наследует красный CTA всего приложения с белыми текстом и иконками.
`ColorScheme.primary/onPrimary` используют существующий `#E60010` и `#FFFFFF`
с контрастом 4.80:1; исходный brand остаётся Signal Red `#FF0012`.
Проверены все 10 primary-вызовов: auth/demo, Portfolio, Builder/редакторы/notes,
GitHub import/review. Loading сохраняет красный фон и белый spinner,
disabled без loading получает нейтральные фон и читаемый текст.
Приёмка: `dart format` — **182 files, 0 changed**; `flutter analyze` —
**No issues found**; полный `flutter test` — **832 passed** после восстановления
отсутствовавшего RU `account.guestNote`. Четыре новых button regression cases
проверяют реальные цвета текста/иконки/spinner, contrast, hover/press/focus,
loading/disabled и secondary в обеих темах, включая auth.
Перегенерированы все **62** previews; выборочно просмотрены auth, Portfolio
и Builder в light/dark. На Android просмотрены Sign In и Portfolio с белыми
надписями на красном; checksum сохранённого draft совпал.

Редизайн не начинает Phase 11 или web implementation. Commit/push не выполнялись.

### Новый Figma-first target (2026-10-04)

По следующему прямому запросу принят новый UX/UI target: DeveloperProfile и
глобальная Projects Library дают несколько структурированных Resumes и Portfolios;
featured/visible/order относятся к связи Project с Portfolio. Root navigation —
Home / Resumes / Projects / Portfolios с постоянными labels; Settings открывается
через contextual gear, nested Back сохраняется. Target brand заменяет Signal Red
на acid lime с neutral foundation и cyan/pink artwork; 390 px — основной размер,
большие экраны сохраняют ту же IA.

Первый scope — repository и
[Figma audit](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard), IA,
target design system и пять key screens. Через MCP изучены 9 Figma pages,
31 COMPONENT/COMPONENT_SET узел на components page и color/metrics collections.
Первая итерация выполнена: по пять ключевых экранов в dark/light на 390×844,
обновлённые shared masters/variables и root prototype с 19 переходами в каждой
теме. Структура через MCP и все десять renders просмотрены; это не закрывает
полные flows, responsive и accessibility QA.
Экранная карта, relations и pending acceptance — в
[redesign plan](../design/redesign-plan.md); canonical visual target — в
[design system](../design/design-system.md).

Текущий Flutter сохраняет red primary, одиночный PortfolioContent, plain
resumeText и прежнюю навигацию. Runtime/schema/Rules, dependencies и original
branding assets этой Figma-first задачей не изменены. Исторические checks выше
сохраняют свой scope и не подтверждают target. Core flows, state/responsive set,
web design, multiple-output migration и Flutter/web implementation остаются
следующими шагами. Node links и фактическая приёмка — в redesign plan.

---

## Концепция и аудитория

**StackCard** — приложение для управления developer identity: базовый профиль,
глобальная библиотека проектов, несколько резюме и портфолио под разные роли.
Flutter-приложение и будущий web-кабинет используют общие данные владельца и
явную публикацию документов. В mobile уже есть один private aggregate с общей
базой, Library и несколькими независимыми Resume/Portfolio. Общий aggregate
хранения не означает единственное выходное портфолио. Сайт объясняет проект,
предлагает скачать приложение и показывает опубликованные документы;
web runtime и новый public lifecycle ещё предстоит реализовать.

Платформы продукта — Android, iOS и web. Mobile реализуется на Flutter в
`apps/mobile`, сайт — отдельно на Next.js в `apps/web`. Каталог сайта уже подготовлен
с README; приложение появится на Phase 13. Desktop-приложения
и Flutter web не входят в scope. Android выпускается первым; iOS остаётся
целевой мобильной платформой.

Целевая аудитория — разработчики, особенно студенты и начинающие специалисты,
которым нужно представить проекты работодателю или заказчику. GitHub содержит
полезные технические данные, но сам по себе не даёт отобранного рассказа о навыках
и результатах работы. StackCard помогает выбрать проекты, дополнить их понятным
описанием, изображениями и demo, а затем поделиться одной ссылкой.

Прежний singleton-план публичного профиля использовал `/u/[username]`.
Актуальный Design v2 принял D019: постоянный адрес каждого Resume/Portfolio,
независимый от названия и username. Это target-политика; новая route scheme
и миграция прежнего adapter ещё не реализованы.

---

## Living Portfolio: данные и контроль пользователя

Основная ценность — **одна профессиональная база → несколько целевых резюме
и портфолио без повторного заполнения**. **Living Portfolio / Smart GitHub Sync**
помогает наполнять и поддерживать общую Library. GitHub поставляет
публичные профиль, avatar, bio, repositories, descriptions, repository URLs,
languages, topics, stars, forks и сведения об активности. Это источник данных,
но не абсолютный source of truth для публичного портфолио.

Нужно сохранять три смысловых состояния; это продуктовый контракт, а не готовая
Firestore schema:

<div align="center">

| **Состояние** | **Назначение и управление** |
|:---|:---|
| GitHub source data | Полученные metadata и их кэш. Обновление источника не означает одобрение публикации. |
| Curated workspace / document draft | Общая база/Library и независимые документы, отобранные и отредактированные владельцем. Ручные проекты равноправны импортированным. |
| Published document | Одобренная пользователем публичная версия отдельного Resume/Portfolio. Сайт читает только её; private база, notes и черновики доступны владельцу. |

</div>

При импорте пользователь выбирает репозиторий и может изменить описание и
технологии, добавить screenshot и live/demo URL. В документе отдельно выбираются
порядок, featured и видимость attachment; удаление связи сохраняет Project в
Library. Проект имеет происхождение `manual | github`;
для импортированного проекта нужны связь с GitHub repository и сведения о sync.
Модель и правила сопоставления Phase 9 зафиксированы в
[ADR 0002](../decisions/0002-github-import-and-review.md).

Smart Sync обнаруживает новый репозиторий или изменения существующего и предлагает
действия: **Ignore**, **Preview / Review changes**, **Add to Library**. Исторический
UI может сохранять прежнюю подпись Add to portfolio; target — одна Library запись,
которую пользователь отдельно включает в нужные документы.
Пользователь видит изменения до их принятия. Ручные правки сохраняют смысл и не
должны молча заменяться новыми данными GitHub.

**Ни обновление GitHub, ни синхронизация локального draft с облаком не могут без
подтверждения владельца переписать опубликованное портфолио.** Изменения черновика
попадают в публичную версию только через явное действие публикации. Unpublish
убирает доступ к опубликованной странице, сохраняя редактируемые данные владельца.
Физическое хранение версий и процедура публикации определяются на соответствующей
фазе, с сохранением этого контракта.

---

## Portfolio Suggestions

Рекомендации Phase 10 используют понятные deterministic rules, без AI:
новый репозиторий, недавнее известное обновление или длительный простой,
отсутствующие description/demo и кандидат для featured. UI объясняет причину
и открывает Preview или редактор; владелец выбирает и сохраняет изменения сам.
Screenshot относится к Media Phase 11; новые технологии и другие сигналы могут
расширить правила позже при отдельном scope.

`ProjectScore` не вводится: для текущих действий достаточно конкретных условий.
Пороги активности и stars определены в одном pure API; подробный контракт — в
[architecture](../architecture/architecture.md#portfolio-suggestions).
Правила проверяются отдельно от UI и не публикуют изменения сами.

---

## Пользовательский путь и экраны

### Мобильное приложение

Принятые экраны и переходы — в [Design v2](../redesign/screens.md), требования —
в [requirements](../redesign/requirements.md). Основной путь:

`Вход или local guest → общая база и Library → выбор Resume/Portfolio →
содержимое → оформление → preview → Save → явный Publish → ссылка/Share`.

GitHub import необязателен; ручные Projects поддерживают закрытые и командные
работы. Guest сохраняет local draft; sync и будущая публикация требуют аккаунта.
Publish/Share в этом пути — план до проверяемого public lifecycle.

<div align="center">

| **Раздел** | **Содержимое и границы** |
|:---|:---|
| Authentication | Splash, Onboarding, Sign In, Sign Up, Forgot Password; готовность реальных способов входа проверяется отдельно. |
| Home | Лента Resume/Project/Portfolio по изменению, ровно Все/Резюме/Проекты; без приветствия, completion, dashboard и глобального поиска. |
| Resumes | Библиотека CV, пять шагов создания, прямая правка секций, preview, duplicate/delete; Publish/Copy/Open/Share требуют public lifecycle. |
| Projects | Единая Library: import, manual create, query-only поиск, фото и technology badges; featured/visible задаются в attachment документа. |
| Portfolios | Независимые визитки, content/appearance/preview, выбор Library projects и Resume; постоянный адрес после публикации. |
| Settings через gear | DeveloperProfile, контакты/ссылки, аккаунт/безопасность, приложение, приватность, sign out/delete; группы реализованы частично. |
| Inbox | Будущие обращения по published документу; не дополнительная root-вкладка. |

</div>

Четыре root-вкладки остаются на телефоне и планшете. Settings, focused editors,
GitHub Import, location picker, base review и будущие Share/Inbox открываются
отдельно. Назад возвращает к исходному разделу; private state изолирован по UID.

### Сайт и web-редактор

Web имеет три назначения: маркетинг/download, защищённый кабинет/редактор,
анонимные публичные Resume/Portfolio. Mobile и web используют один аккаунт,
общую базу/Library и независимые документы. Ниже **целевые области маршрутов**,
а не созданное приложение или окончательная URL-схема.

<div align="center">

| **Область** | **Доступ и назначение** |
|:---|:---|
| `/`, `/download` | Landing с пользой общей базы, примерами Resume/Portfolio и реальными действиями/download links. |
| `/sign-in`, `/sign-up`, password recovery | Auth общего Firebase backend; поля входа не становятся публичными контактами. |
| Private кабинет и библиотеки | Resume/Project/Portfolio, общая база, Library и те же смысловые действия, что mobile. |
| Private editor выбранного document ID | Content/appearance/preview, scoped Save, base review и отдельный Publish/Unpublish. |
| Settings/Inbox | Данные своего владельца; обращения появляются с Phase 14. |
| Permanent public document route | Published-only Resume/Portfolio по постоянному public ID; photo/no-photo, metadata/SEO/OpenGraph и missing/unpublished states. |

</div>

Точные вложенные paths и public route фиксируются в контракте Phase 13 до
реализации. D019: URL документа сохраняется после rename/смены username и
unpublish→republish; дубликат получает отдельную идентичность. Legacy
`/u/[username]` остаётся вопросом совместимости прежнего prepared adapter.
Ни production host, ни рабочая ссылка этим планом не объявляются выбранными.

Wide web editor допускает параметры рядом с preview; narrow использует
самостоятельные Edit/Preview modes. Web v1 online-first, mobile сохраняет offline
draft. Обмен правками требует общих JSON fixtures и явно принятой conflict policy;
нынешний whole-aggregate LWW не обещает слияние двух параллельных версий.

---

## Portfolio Builder и Developer Card

Portfolio editor использует секции Profile, About, Skills, Featured Projects,
Experience, Education, GitHub, Links, Resume, Location. Resume имеет собственную
структурированную документную подачу. Content → Appearance → Preview → Publish —
разные действия; Save не публикует. В документе задаются порядок/видимость секций,
ограниченное Figma оформление и фото. Legacy Builder сохраняет старые данные,
но не заменяет библиотеки. Свободный canvas и редактор уровня Figma/Webflow
не входят в v1.

Developer Card строится из выбранного Portfolio: фото, имя, роль, technologies
и логотип. URL/QR принадлежат этому опубликованному документу. Обычный Share
поддерживает также выбранное Resume; черновик не получает фиктивную ссылку.
Android sharing планируется через MethodChannel/Kotlin/native share sheet;
iOS проверяется отдельно. Полная Card/QR относится к Phase 15.

---

## MVP и полный scope v1

MVP соответствует общей базе и нескольким документам. Таблица — критерии
продукта, а не объявление всех возможностей готовыми. Actual scope/evidence —
[в статусе](#статус-и-границы-текущей-работы).

<div align="center">

| **Область** | **Обязательный результат** |
|:---|:---|
| Authentication | Email/password и Google, восстановление доступа; реальные native flows и UID isolation. |
| DeveloperProfile | Имя/ник/роль/фото, навыки, опыт, образование, location и public contacts; login email отдельно. |
| Projects Library | Manual и GitHub работы, описание/вклад, изображения, technologies, repository/demo; одна запись на работу. |
| Resume / Portfolio | Независимые title/role/секции/оформление, attachments order/visible/featured, base review с сохранением local overrides. |
| Living Portfolio | Явный import/review/ignore и ручные overrides; без тихой перепубликации. |
| Publication | Publish/Update/Unpublish выбранного документа, постоянный URL, public renderer и безопасные delete/republish последствия. |
| Website | Landing/download, защищённый кабинет с базой/Library/документами, anonymous Resume/Portfolio. |
| Inbox / Notifications | ContactRequest по published документу и owner Inbox в обоих клиентах; FCM после подключения настоящего сервиса. |
| Offline | Mobile local draft/cache/outbox; web online-first с настоящими saving/error/retry и conflict states. |
| Settings / Sharing | Theme light/dark/system, ru/en, reduced motion, account/privacy, native share и Card/QR по возможностям платформы. |

</div>

Public projection включает только выбранные секции, контакты и visible projects;
private notes, login/provider data, baseSnapshot и скрытые поля не передаются
посетителю. Contact me появляется вместе с validation/anti-spam/owner Inbox на
Phase 14; отсутствие push не теряет само обращение. Карта/Google Maps исключены,
город/страна и permission states сохраняют контракт Phase 12.

---

## Offline, приватность и безопасность

- В mobile без сети доступны ранее загруженные profile и projects, GitHub cache и
  редактирование локального draft. После восстановления сети изменения
  синхронизируются с облаком; состояния: `pending`, `synced`, `error`.
- Web v1 требует сети для auth, удалённого сохранения и публикации. UI явно
  показывает несохранённые изменения, сохранение, sync error и повтор действия;
  не сообщает об успешном сохранении до подтверждения. Поведение при потере сети
  не должно создавать ложное ожидание mobile offline-возможностей.
- Conflict strategy для mobile, web и нескольких устройств должна быть явной
  и документированной. Simple last-write-wins допустим на раннем этапе после
  отдельного решения; это не разрешение на
  автоматическую перезапись публичной версии.
- GitHub v1 использует публичные repositories и endpoints. Private repository
  access не требуется; private token нельзя хранить в Firestore открытым текстом.
- Владелец может изменять только свои private данные; чужое опубликованное
  портфолио доступно только для чтения. Firestore и Storage Rules должны проверять
  ownership; draft, account data, contact requests и device tokens не становятся
  публичными вместе с портфолио.
- Location — подтверждённый город и страна, например «Almaty, Kazakhstan».
  Ручной ввод доступен без разрешений; опциональное определение города запрашивает
  геопозицию только по нажатию. Точные coordinates и адрес не сохраняются и не
  передаются в public snapshot. Denied, permanently denied, service disabled
  и ошибка определения города оставляют ручной ввод доступным.
- Camera/gallery используются для avatar и project images. До upload нужны
  validation, compression/resize; для Storage — ограничения размера, разрешённые
  MIME types, access rules и стратегия очистки старых файлов.
- Camera, location permissions и sharing реализуются с учётом конкретной платформы.
  Web поддержит загрузку файлов и подходящий browser UX; MethodChannel и Kotlin
  относятся к Android. Полное равенство нативных возможностей клиентов не обещается.
- Входящие данные, URL и contact form требуют validation. Защита от contact spam
  и rate limiting проектируется до публичного запуска соответствующего сценария.
- Secrets не входят в репозиторий. Environment contract и handling Firebase
  config описываются при подключении сервисов. Privacy policy, объяснения
  permissions и account deletion входят в подготовку production-версии.
- Сетевые сценарии требуют loading, success, empty, error, timeout, retry,
  pagination, pull-to-refresh и caching. Ошибки должны давать понятное действие,
  не ломая доступ к сохранённым данным.

---

## Техническое направление и качество

Целевые стек, границы приложения и развитие слоёв описаны в
[architecture.md](../architecture/architecture.md). Они вводятся по фазам,
без enterprise framework и лишнего backend. Web планируется на Next.js для
главной, скачивания mobile, защищённого редактора и публичных страниц с SEO/OpenGraph.
Mobile и web используют один Firebase project и согласованные data contracts,
когда сервисы будут подключены. Dart- и TypeScript-клиенты реализуют эти контракты
в своих стеках; общей runtime-библиотеки между ними сейчас нет.

Визуальный язык **Obsidian / Signal Red / Electric**: цельные цветные поверхности,
крупная типографика и открытые секции без вложенных карточек;
палитры и правила компонентов закреплены в
[design-system.md](../design/design-system.md). Решения и нерешённые вопросы
фиксируются в [ADR](../decisions/README.md).

Приоритеты: correctness → simplicity → maintainability → user experience →
architecture purity → fancy features. Не создавать abstraction без реального
сценария. Производительность проверяется профилированием, затем исправляются
найденные проблемы; результаты до/после сохраняются.

Целевая проверка продукта: unit tests для repositories, suggestions, completion,
sync и validation; widget tests для auth, project card, editor и UI states;
integration test пути sign in → edit project → preview → publish. Учебная цель —
coverage **более 40%**, `flutter analyze` без ошибок. Проверки поведения добавляются
по мере реализации; Phase 17 доводит покрытие, а не запрещает тесты раньше.
Перед реализацией web определить его format/lint/typecheck/test команды по реальным
configs. Проверить auth guards, owner access, draft → publish и чтение public snapshot
в browser, а также синхронизацию изменений между клиентами.

---

## Non-goals v1

Не входят: social network, likes/comments/followers, recruiter platform, jobs
marketplace, messaging/chat, custom domains, template marketplace, complex
analytics, AI portfolio generation / recruiter / CV scoring, multi-user teams,
paid subscriptions, full GitHub client, private GitHub repositories,
сложный drag/resize canvas.

---

<a id="roadmap"></a>

## План разработки

**Актуальное поручение 2026-10-07:** поставить последовательную разработку
по фазам на паузу и развивать mobile функциональность по Figma/концепции.
Разрешённый capability scope и оставшаяся работа перечислены
[в текущем статусе](#статус-и-границы-текущей-работы). Phase 11/12 и R0–R9 ниже
сохраняют историю реализации и evidence; новые mobile changes не считаются
автоматическим завершением этих фаз или full Design v2 acceptance.

План объединяет исходное описание StackCard, требования учебного задания
`individual_project_flutter_ru.docx` и актуальный scope выше: mobile, полноценный
web-редактор и публичные Resume/Portfolio. Этот раздел владеет roadmap; технические решения
подробно фиксируются в architecture и ADR, команды — в CONTRIBUTING.

### Актуальная последовательность 2026-10-08

План обновлён под Figma и концепцию общей базы. Полный перенос не завершён:
D045/D046 private core сохранён, D048 явно разрешает mobile/web/publication.
Contacts/privacy/Project overrides, actual Next.js owner/public runtime и trusted
publication source используют Hive7/cloud6. Mobile1323/1323, backend51 и
projection14 PASS; actual browser publication и Android source/screen smoke
проверены, final analyze/build и native Share ещё ожидают итога.
R7 user acceptance и full native/browser/Figma parity остаются открытыми.
Ожидание REDESIGN_DONE не блокирует разрешённые capabilities; новая source
реализация не означает deployment или запуск всех будущих сервисов.

| **Очередь / capability** | **Что уже есть → что осталось** | **Готово, когда / зависимость** |
| --- | --- | --- |
| База и private документы; PR-DATA-01/02/03 | D045/D046 core сохранён; D048 добавляет отдельный contribution и per-document title/description/contribution overrides с Hive7/cloud6. Figma/native варианты и final acceptance открыты. | Выборочные overrides не меняют Library/соседние документы, Save/Discard/reopen/UID и schema compatibility проверены; реализованное ядро повторно не строится. |
| Ближайший mobile блок; PR-CONTACT-01, PR-PREF-01, PR-AUTH-01, PR-ACCOUNT-01/02 | D048 source: typed Contacts/selection/privacy, reduced motion и Account actions/deletion lifecycle. Native media/location/Google/iOS и visual acceptance остаются отдельными проверками. | Login/providers отделены от public contacts; изменение базы не переписывает документы; unsupported действие не показывает success. Account deletion требует public withdrawal/cleanup contract и выполняется после него. |
| Публикация; PR-PUB-01/02/03, PR-URL-01 | D048 trusted Functions, permanent /d/<publicId>, inventory/version/unknown recovery, public media/current-version access и delete tombstones/account lock. Deployment/live reader ещё не подтверждены. | Выбранный документ доступен по настоящему URL, draft/Library/base edits не меняют public snapshot; rename/republish сохраняют URL, duplicate его не наследует, delete не воскресает после позднего retry. |
| Web; PR-WEB-13A/B/C | D048 actual Next.js landing/download/Auth, owner база/Library/document editors и anonymous /d/[publicId]. Headless checks и browser/live acceptance фиксируются отдельно. | Full owner editor не является предпосылкой первого public документа: source сначала mobile. После расширения оба клиента используют совместимую базу/Library/документы и owner guards. |
| Связь и распространение; Phase 14/15 | D048 confirmed URL Copy/Open/native Share actions; device acceptance открыта. Затем отдельно ContactRequest/Inbox/FCM и Developer Card/QR. | Контактная форма следует выбранному published документу и privacy; notifications не подменяются локальным toggle. QR/Share никогда не передают фиктивную ссылку. |
| Качество и выпуск; Phase 16–20 | Tests/security/CI идут вместе с capabilities; профилирование, полная native/live приёмка и release — отдельные результаты. | Есть воспроизводимые измерения/checks, приёмка критических journeys Android/iOS/web и разрешённый пользователем выпуск. |

Детальные PR-* контракты и Figma/task mappings остаются в
[prerequisites](../redesign/prerequisites.md#product-tasks-gap-и-владельцы-источников)
и [R8/R9 plan](../redesign/plan.md#r8--перенос-согласованного-ui). Эта таблица задаёт
актуальные приоритеты; Phase 0–12 ниже сохраняют историю/учебную прослеживаемость,
Phase13 описывает D048 source и открытую приёмку, Phase14–20 - будущие результаты.

### История фаз до функционального mobile scope 2026-10-07

Следующие записи описывают исходный процесс и результат соответствующих версий.
Их фразы о pending scope/паузе перед Phase11 не переопределяют последнее
поручение в текущем статусе.

**Phase 0–6 завершены:** основа, UI, состояние, архитектура, GitHub Import, offline и Builder проверены;
результаты и ограничения записаны в соответствующих разделах ниже.
**С 2026-10-05 основная разработка новых функций приостановлена:** R7
[Design v2](../redesign/README.md) awaiting_reviewD041:source package/graphQA
PASS,явная приёмка/DESIGN_READY pending.
D040 также разрешило R8/R9 на `redesign/full-app`; независимые поддерживаемые
slices перенесены параллельно, actual950-case regression PASS. Полная
implementation/acceptance и prerequisite scope ещё не закрыты; конкретный
[proposed пакет](../redesign/prerequisites.md) готов для решения пользователя.
Full-phase/parallel/no-preview/run сохранён; commit/push/deploy не запрошены.
Прямое поручение
использовать [план R0–R9](../redesign/plan.md) и начать первую фазу приняло R0
и разрешило R1.1. Поручение «переходи к следующей фазе» приняло
[три схемы IA](../redesign/screens.md#r11--информационная-архитектура)
и разрешило следующую задачу R1.2. Поручение исправить кнопки/поиск и затем
продолжить приняло [24 low-fi экрана R1.2](../redesign/screens.md#r12--low-fi-основных-сценариев)
после проверенных правок: последовательные кнопки горизонтально, поиск с лупой
без заголовка. Приняты поручением «переходи к следующему этапу» ещё
[24 low-fi экрана R1.3](../redesign/screens.md#r13--low-fi-resume-wizard-и-редактора):
пять шагов Resume, optional skip, фото/no-photo, focused sections и отдельный Save.
Созданы и визуально проверены
[40 low-fi экранов R1.4](../redesign/screens.md#r14--low-fi-projects-portfolio-и-публикации):
Project create/import/review, Portfolio attachments/preview, отдельный Publish,
errors/unsaved/public access. Ответом пользователя принята политика постоянных
адресов документов, сохраняемых при смене названия/никнейма (D019).
Поручение добавить цветовые акценты и затем продолжить выполнено (D020):
основные действия и выбранные состояния выделены lime, опасные — красным;
размеры и горизонтальные ряды сохранены. **R1 — done; R2.1 — done D022**:
[шесть пилотов](../redesign/screens.md#r21--два-визуальных-направления) сравнивают
два направления на одинаковых Home, public Resume без фото и Настройках.
Сравнение принято поручением продолжить. **R2.2/R2.3/R2 — done D024**:
[brand specimens](../redesign/screens.md#r22--знак-написание-и-иконка-приложения)
обоих вариантов содержат знак/написание/иконку, dark/light/mono, проверку
16–48 px и восьми UI-шапок. Пользователь выбрал бренд A и поручил продолжить;
связанные пилоты A / Cyber Editorial служат основой R3. B сохранён как история.
**R3.1 — done D028**: после сравнения Noto Sans / Manrope / Golos Text
пользователь поручил перейти к следующему этапу. Закреплена рекомендация Manrope;
[Dark/Light foundations](../redesign/screens.md#закреплённая-типографика-manrope-d028)
обновлены, исходная палитра/Wordmark A сохранены. На момент R3 это было
Figma UI; subsequent R8 импортировала Manrope в существующий Flutter. **R3.2 — done D030**:
[Navigation/cards/TechnologyBadge](../redesign/screens.md#r32--навигация-карточки-и-technologybadge)
содержат9 sets/44variants,4 root labels,3 Home filters, gear/back, отдельное Copy
и badges icon+text/+N/full wrap. Итоговые410 texts contrast/bounds PASS;
**R3.3 — done D032**:
[формы, stepper, фото и секции](../redesign/screens.md#r33--формы-stepper-фото-и-секции)
содержат10 sets/67 variants, PhotoSourceSheet и6 SVG icons; четыре Dark/Light
boards показывают keyboard и static ×2 reflow.513 texts/103 strokes, bounds,
references и touch audit PASS. Фотография — обозначенный generated_demo,
не пользовательский upload. Поручение D032 приняло R3.3 и разрешило R3.4,
работу нескольких агентов и ускорение.
**R3.4 и полная R3 — done D034**:
[states/motion/adaptive](../redesign/screens.md#r34--состояния-motion-и-адаптивность)
содержат2sets/18variants и10Dark/Light fixtures320/390/430/768/844landscape.
Local Save, server ACK иPublish разделены; unknown publication result честно
обозначен. Save/Отмена закреплены над bottom tabs; motion180/240/280ms и0ms
reduced — статические specs.393texts/786mode samples,342strokes/96targets,
geometry/bindings/references/scopes PASS. Native keyboard/media/OS scaling/
routing/clipboard/icon exports иplayable prototype ещё pending.
**R4 — done D036**: пользователь принял полную R3 и разрешил
все девять задач R4.1–R4.7c одним пакетом D034. Собраны четыре root-библиотеки
и Settings/Profile/Contacts/Account/Privacy/App: [61state/122Dark-Light frames,
9boards](../redesign/screens.md#r4--основные-экраны-и-настройки).
Metadata/contrast: 2074actual-mode text samples ≥4.739:1,
1446strokes ≥4.364:1,840targets≥48;17failure categories0.
70fixed-brand vector fills сохраняют original Flutter/Dart assets; scope
onPrimary расширен STROKE_COLOR без смены palette values.
Добавлены три scoped families/6input-composition variants и один pinned Search SVG;
98variables/50styles сохранены без drift. Визуальный просмотр, preview и запуск
приложения не выполнялись по прямому запросу D034. Полный пакет принят
следующим поручением продолжить, D036. Это Figma target; новые screens/routes/
backend этим пакетом не реализованы.
**R5 — done D038**, фактический результат D037: поручение «переходи к следующему этапу
разработки» приняло всю R4 и продолжило следующую R5 в сохранённом режиме
фаза целиком/параллельно/без preview и запуска. Это интерпретация прежних
предпочтений; пользователь не называл весь набор R5 буквально.
Все 13 задач собраны: [83 состояния / 166 Dark/Light frames / 13 boards](../redesign/screens.md#r5--создание-редактирование-и-публикация).
Resume wizard/edit/structured preview, manual/GitHub Projects/review,
Portfolio content/associations/appearance и Publish/Share/Unpublish/delete
сохраняют отдельные local Save, sync ACK и explicit Publish. Unknown outcome
не объявляется success. Structural QA:3474actual-mode text samples
min4.832909811:1,1280strokes min4.364564811:1,966targets≥48;18failure categories0.
Wizard1–5/16preview/84forms/152fixedfooter и48actual identity checks PASS.
98variable values/50style IDs сохранены точно;274originalFlutter/Dart fills
retained targeted source exemption,14existing demo imagefills80×80. DS дополнили
DocumentIdentity(photo/no-photo), ChangeComparison и ProjectAssociationRow.
Visual inspection/preview/run пропущены по сохранённому запросу. Это статический
Figma target, без native input/media/SDK/OAuth/schema/backend/cloud evidence.
Весь пакет R5 принят последним поручением продолжить, D038.
**R6 — done D040**, evidence D039: следующая полная R6.1–R6.4 начата с сохранением
прежнего phase-package/parallel/no-preview/run режима. Это интерпретация
«переходи к следующему этапу разработки»; пользователь не называл все задачи
R6 буквально. Web target охватывает landing/auth/download, owner workspace
и public Resume/Portfolio. [24 состояния / 96 wide-narrow Dark-Light frames /
4boards](../redesign/screens.md#r6--веб-поверхности) собраны на page202:2989.
Structural QA:2810actual-mode text samples min4.832909811:1,690strokes
min4.364564811:1,726targets≥48;20failure categories0.116sourceCTA records
проверены против proposed destinations, без live URL/store/auth execution.
98values/50styleIDs сохранены точно;28existing demo80×80 imagefills и8actual
R5 editable document clones.96Noto Wordmark и462originalFlutter/Dart fills —
targeted preservation exemptions. Landing1440×3475/390×5628; structural PASS
не доказывает browser rendering/native/cloud/route availability. Visual
inspection/preview/run пропущены по сохранённому запросу.
**R7 — awaiting_review D041**: source package/structural QA завершены;
[portable handoff](../redesign/source/r7-handoff.json) фиксирует2736 actualbindings
(1758mobile/978web),879 mobile / 946 web contracts,974 web controls;723 roots / 52255 nodes /
15822 TEXT,328 unique starts.22 contract chunks+topology PASS,11 failure categories0;
6 standard/reduced motionpairs same targets,noTIMERS/noSET_VARIABLE;
98values/50 style IDs exact.12 new adaptive+10 reused+2 keyboard sources,180 static ×2
texts/contrast PASS;native keyboard/OS scaling не доказаны. Preview/playback/run
omitted; R7.4 явная приёмка/DESIGN_READY pending. **R8/R9 — in_progress D040**, независимая
часть UI внедрена на `redesign/full-app`: Manrope/semantic Lime/shared
controls, StackCardIcon/TechnologyBadge, live Brand A, query-only Projects,
Settings/appearance/account и tablet bottom navigation. Три действующих roots
сохраняют legacy Home/Portfolio composition; Resume library/multiple-doc storage,
full profile/contacts/account/media/publication и новый web отсутствуют.
950/950 headless tests PASS29s,analyze0issues3.8s;118 новых случаев vs832baseline,
0SVGwarnings;184Dartfiles SHA-256
`d51aee259557296fde1a16682973dd03b3c96b5cee614ac536f82bfade2d30e2` preserved
во время финального прогона. 40canonical entries+1explicit SVG derivative
(41files/33SVG),32runtimeSVGdecoded,9BrandAexports, strict provenance PASS.
NativeAppIcon packaging не менялось. [Подробный результат](../redesign/plan.md#фактический-перенос-поддерживаемого-ui-r8r9-d040)
и [переносимый source/result ledger](../redesign/source/r9-supported-ui-validation.json)
с командами и hashes.
No-preview/run исключил native launch/playback/visual parity; headless evidence
не закрывает новые models/web/private-public security или Google/reset/iOS.
[Proposed prerequisites](../redesign/prerequisites.md) покрывают12GAP,
ответ о scope pending; нового phase approval R8 не требуется.
DESIGN_READY/REDESIGN_DONE не установлены; commit/push/deploy не запрошены,
основной roadmap сохраняет pause перед Phase11.

На исторической точке D040 новая URL route scheme и миграция adapter были
предпосылкой R8; private schema ещё не была мигрирована. D045/D046 позднее
реализовали private документы/base review/Hive6/cloud5; public URL и adapter
остаются текущими пробелами. UI acceptance сохраняется частичной.
Проверки и ограничения — в [результатах R8/R9](../redesign/plan.md#фактический-перенос-поддерживаемого-ui-r8r9-d040);
предыдущие цветовые правки и результаты R2 сохранены отдельно.
Историческая точка остановки функционального roadmap до поручений 2026-10-07 —
после Phase 10, перед Phase 11 Media; Google/reset/iOS приёмка Phase 7 остаётся
открытой. Тогда возврат к roadmap предлагался после пользовательской приёмки
REDESIGN_DONE; D045/D046 позднее разрешили нынешнюю mobile работу вне очереди. Новые model/migration/media/account/
publication/web возможности перечислены как [продуктовые пробелы](../redesign/audit.md#продуктовые-пробелы)
и [предпосылки R8](../redesign/plan.md#зависимости-реализации). Сам перенос R8
и R9 уже разрешены D040; D045/D046 реализовали private subset, оставшийся
public/account/web scope раскрыт в актуальном roadmap. Повторного phase approval нет. Последние требования Design v2 имеют приоритет над прежними макетами.

Phase 10 завершена. Предыдущее прямое поручение — Figma-first refactor:
audit, IA, design system и ключевые экраны по [redesign plan](../design/redesign-plan.md).
Первый этап Figma выполнен; core flows/states и перенос Flutter/web остаются
отдельными последующими шагами. История runtime-redesign выше сохраняется.
Открытые Google/reset/iOS проверки Phase 7 сохранены; Phase 11 и Phase 12 разрешены
отдельными поручениями 2026-10-07, Phase 13–20 остаются планом и требуют поручения.

Чекбокс `- [x]` означает подтверждённый результат, `- [ ]` — оставшуюся задачу
или непроверенный сценарий. При отметке проверки рядом фиксируются результат
и ограничения среды. Фаза завершена только после приёмки обязательных сценариев.

<div align="center">

| **Фаза** | **Статус** |
|:---|:---|
| Phase 0 — Product foundation | Завершена; код, документы и нативный запуск на Android проверены |
| Phase 1 — UI foundation | Завершена; UI, темы, навигация и mock-сценарии проверены |
| Phase 2 — Basic state management | Завершена; три этапа темы, итоговый Provider и Riverpod state проверены |
| Phase 3 — Architecture | Завершена; Repository/DI, чистый domain, UI и Android-запуск проверены |
| Phase 4 — GitHub API | Завершена; HTTP, pagination, refresh, состояния и Android-запуск проверены |
| Phase 5 — Local persistence / offline | Завершена; settings, Hive cache/draft, offline/reconnect и Android restart проверены |
| Phase 6 — Portfolio domain и локальный Builder | Завершена; CRUD, validation/completion, preview, migration и Android offline restart проверены |
| Phase 7 — Firebase authentication | В работе; Android email flow проверен, Google/iOS приёмка открыта |
| Phase 8 — Firestore synchronization | Завершена; offline/reconnect, Android restart, LWW и Rules проверены |
| Phase 9 — Living Portfolio / Smart GitHub Sync | Завершена; импорт/review/ignore, overrides, совместимость draft и Android restart проверены |
| Phase 10 — Portfolio Suggestions | Завершена; pure rules, объяснения ru/en, явные Preview/editor actions и Android-запуск проверены |
| Phase 11 — Media | Реализована; 1013 Flutter/40 Rules/Android SDK PASS; полная device/live приёмка открыта |
| Phase 12 — Location | Реализована без карты; 1068 Flutter/2 native cases PASS; device geolocation/iOS приёмка открыта |
| Phase 13a — Public shell | D048 source реализован: Next.js shell/landing/download; browser runtime проверен, final build/full Figma acceptance отдельно |
| Phase 13b — Auth и редактор | D048 source реализован: Auth/UID owner база/Library/document editors; mobile fixture/web CAS browser flow PASS, full cross-client/live acceptance отдельно |
| Phase 13c — Public Resume/Portfolio | D048 source реализован: trusted publication/permanent URL/public media/reader; backend51/projection14 и browser Publish/Unpublish/republish/Copy PASS, live acceptance отдельно |
| Phase 14 — Contact / Inbox / FCM | Запланирована |
| Phase 15 — Developer Card и native sharing | Запланирована |
| Phase 16 — Performance | Запланирована |
| Phase 17 — Testing | Запланирована |
| Phase 18 — CI/CD | Запланирована |
| Phase 19 — Production hardening | Запланирована |
| Phase 20 — Release | Запланирована |

</div>

### Как выполнять план

С 2026-10-07 последовательная очередь на паузе. Для разрешённого D048
mobile/web/publication scope
выполнять самостоятельные сценарии с сохранением architecture, данных и
подходящими проверками. При возобновлении очереди применяются правила ниже.

- Выполнять одну фазу за раз. Сначала завершить её задачи и проверки, затем
  показать результат. Переходить дальше по уже полученному разрешению пользователя;
  если следующая фаза не разрешена, получить подтверждение перед её началом.
- Внутри фазы двигаться небольшими изменениями с проверяемым пользовательским
  сценарием. После каждого шага приложение должно запускаться.
- Добавлять зависимости и слои вместе с реальным использованием. До соответствующей
  фазы не создавать Firebase, Next.js, пустые features или универсальные abstractions.
- Добавлять значимые tests по мере появления поведения. Phase 17 доводит покрытие;
  security rules проверяются при подключении сервиса, а не только перед релизом.
- При приёмке фиксировать: выполненные задачи, результат запуска, проверки,
  ограничения и решения. Не отмечать фазу готовой по одному списку файлов.
- В этом документе обновлять фактический прогресс и результаты проверок фазы.
  После подтверждённого перехода обновлять текущую фазу в разделе статуса
  и связанные описания; правила работы по плану закреплены в
  [общих инструкциях](../AI/AGENTS.md#разработка-по-плану).
- Commit, push, подключение remote и публикация выполняются по отдельному запросу.
  План не задаёт календарные сроки; темы курса сопоставлены в следующем разделе.

### Phase 0 — Product foundation

**Задачи**

- [x] Проверить существующий monorepo и сохранить Flutter-приложение в `apps/mobile`
  с Android/iOS targets; повторно генерировать scaffold не нужно.
- [x] Зафиксировать scope, MVP, экраны, архитектурное направление и дизайн в текущих
  README и guides. Сохранить `.gitignore`, lockfile, ADR и branding originals.
- [x] Выполнить доступные проверки окружения, зависимостей, format, analyze, widget test
  и попытку запуска по [CONTRIBUTING](../../CONTRIBUTING.md#проверки);
  ограничения нативной проверки записаны ниже.
- [x] Подготовить отчёт о фундаменте и ограничениях среды. Commit возможен
  только по запросу пользователя.

**Проверки и приёмка**

- [x] Подтверждены структура monorepo, Android/iOS targets, lockfile, ignore rules,
  ADR и сохранность оригиналов branding.
- [x] Окружение и зависимости проверены; format, analyze и widget test выполнены
  по CONTRIBUTING, результаты и ограничения записаны.
- [x] Минимальное приложение запущено на Android-эмуляторе `main_phone`;
  экран StackCard и изменение счётчика `0 → 1` подтверждены. iOS не проверен;
  причина указана ниже.
- [x] Документы согласованы с существующей основой; отчёт о фазе подготовлен.

**Результаты проверки — 3 октября 2026**

- `flutter --version`: Flutter 3.47.4 stable, Dart 3.13.3; SDK constraint выполнен.
- `flutter pub get`: успешно; manifest и lockfile не изменились.
- `dart format --output=none --set-exit-if-changed lib test`: успешно,
  оба файла уже отформатированы.
- `flutter analyze`: `No issues found`.
- `flutter test`: 1/1 widget test прошёл, включая обновление счётчика.
- Проверка документации: 12 файлов без ошибок оформления и локальных ссылок;
  `project_context.py` и `git diff --check` прошли.
- Mobile содержит только Android/iOS targets; builds, caches и `local.properties`
  исключены из Git. Все шесть SVG совпадают с embedded originals brand kit.
- Android debug APK успешно собран: Gradle 9.3.1, `assembleDebug`,
  `build/app/outputs/flutter-apk/app-debug.apk`. Первая загрузка Gradle завершена;
  исходники и отслеживаемые configs не менялись.
- APK установлен и запущен на `main_phone` (Android 17 / API 37, arm64).
  После завершения оконного эмулятора проверка выполнена в режиме `-no-window`:
  `adb install` завершился успешно, `MainActivity` открылась. Android UI hierarchy
  и снимки экрана подтвердили StackCard, начальный счётчик `0` и значение `1`
  после нажатия кнопки. Физическое устройство не проверялось.
- `flutter doctor -v`: для Android отсутствуют cmdline-tools, статус лицензий
  неизвестен; это не помешало проверенной Android-сборке. Xcode установлен
  неполностью, CocoaPods отсутствует; iOS-запуск не проверялся.
- Локальная ветка `dev` создана от текущего `main` и выбрана для дальнейшей работы;
  незакоммиченные изменения сохранены. В этой задаче commit/push не выполнялись.

**Готово, когда:** минимальное приложение запускается, документы согласованы,
проверки выполнены или их ограничения явно указаны. Firebase, GitHub API,
продуктовые features и Next.js на этой фазе не вводятся.

### Phase 1 — UI foundation

**Задачи**

- [x] Перенести tokens из [design system](../design/design-system.md) в Material 3
  theme: light/dark, typography, spacing, radius и правила Signal Red.
- [x] Создать используемые общие buttons, cards, inputs и состояния loading/error/empty.
- [x] Добавить app shell и GoRouter; показать Sign In, Home, Portfolio, Projects,
  Settings на mock data. Inbox подключается со своим сценарием позднее.
- [x] Подготовить эскизы и проверить пять экранов на телефоне и планшете,
  в portrait/landscape; проверить читаемость, контраст и работу с клавиатурой.

**Проверки и приёмка**

- [x] Sign In, Home, Portfolio, Projects и Settings доступны через app shell;
  переходы и возврат работают на mock data.
- [x] Light/dark темы, typography, spacing, radius и применение Signal Red
  соответствуют design system; общие компоненты используются на экранах.
- [x] Экраны сверены с эскизами на телефоне и планшете в обеих ориентациях;
  читаемость, контраст, keyboard navigation и отсутствие overflow проверены.
- [x] Loading/error/empty состояния проверены; format, analyze и значимые
  UI tests проходят, результаты запуска и ограничения записаны.

**Результаты проверки — 3 октября 2026**

- Палитра из нового поручения перенесена полностью: 15 ролей каждой темы,
  dark по умолчанию. Типографика — локальные DM Sans и Noto Sans для кириллицы,
  лицензии SIL OFL поставляются вместе со шрифтами. Логотип отрисован по оригинальным
  vector paths; исходники branding сохранены.
- Работают вход в демо с локальной валидацией email, переходы/возврат,
  поиск и фильтры проектов, сброс пустого результата, предпросмотр проекта/портфолио,
  dark/light/system, состояния loading/empty/error и retry. Авторизации нет;
  email не сохраняется. Учебная эволюция управления состоянием остаётся Phase 2.
- `flutter pub get`, `flutter analyze` и проверка `dart format` прошли;
  анализ — `No issues found`. `flutter test`: **105/105** tests прошли.
  Пять tests проверяют пользовательские сценарии, включая Tab, отправку формы
  и активацию навигации Enter. Ещё 100 проверяют пять экранов в двух темах,
  text scale 1×/2× и размерах 390×844, 844×390, 768×1024, 1024×768, 320×640.
- При обычном масштабе автоматические проверки контраста текста проходят
  в начале и конце страницы; Android touch target guideline проходит на начальном
  viewport. Это не полный accessibility audit и не подтверждение всех платформ.
- [Эскизы](../design/design-system.md#5-layout--composition) согласованы с реализованной
  компоновкой. 40 Flutter PNG в `docs/design/previews` просмотрены для всех пяти
  экранов, двух тем, phone/tablet и обеих ориентаций. Overflow при обычном и
  удвоенном тексте не обнаружен; красный используется локально в CTA и индикаторах.
- Android debug APK собран и установлен на `main_phone` (Android 17 / API 37,
  arm64). Все пять экранов открыты; native UI hierarchy и снимки подтвердили
  переходы, светлую тему и Android Back. Физические phone/tablet и iOS не проверены;
  tablet/landscape проверялись рендерингом Flutter, а не отдельными устройствами.
- Текущий `flutter doctor -v` подтверждает неполную установку Xcode и отсутствие
  CocoaPods, поэтому iOS-запуск недоступен. В Android SDK отсутствуют cmdline-tools
  и неизвестен статус лицензий; Android debug сборка и запуск при этом прошли.
- Документы и ссылки проверены; `git diff --check` чистый. Commit/push не выполнялись.

**Готово, когда:** навигация и обе темы работают, основные экраны соответствуют
эскизам и сохраняют компоновку на разных размерах. Backend не требуется.

### Phase 2 — Basic state management

**Задачи**

- [x] Выполнить обязательную для курса эволюцию одного простого сценария, например
  переключения темы: `setState → InheritedWidget → Provider`.
- [x] Сохранить сравнение подходов и этапов рефакторинга; в рабочем коде оставить
  одну итоговую реализацию сценария.
- [x] Ограничить Provider базовыми ThemeMode/Locale; ввести Riverpod для первого
  реального состояния продукта и обосновать выбор в документации.

**Проверки и приёмка**

- [x] Один сценарий продемонстрирован последовательно через setState,
  InheritedWidget и Provider; итоговое состояние обновляет нужные widgets.
- [x] Сравнение и обоснование Provider/Riverpod сохранены; в рабочем коде
  осталась одна итоговая реализация сценария.
- [x] Поведение состояния проверено; разработчик может объяснить различия
  подходов. Persistence не заявлена до Phase 5.

**Готово, когда:** базовое состояние доступно нужным widgets, обновляется
предсказуемо, а разработчик может объяснить различия трёх подходов. Сохранение
настроек между запусками добавляется на Phase 5.

**Реализовано и проверено в Phase 2**

- Один сценарий темы прошёл все три подхода. Итоговый AppearanceController
  принадлежит `ChangeNotifierProvider`; `Selector/select` обновляют MaterialApp
  и Settings, повторный выбор mode не вызывает уведомление. GoRouter сохраняет
  экземпляр и больше не передаёт theme callbacks. Locale вводится вместе с переводами.
- Query/filter state Projects вынесен в immutable Riverpod Notifier; производный
  provider фильтрует mock data. Выбор восстанавливается после удаления экрана
  из навигации; TextEditingController синхронизируется при внешнем изменении/reset.
- [Учебный guide](../learning/state-management.md) содержит сравнение, обоснование
  границ и два независимых patches. Каждый применён во временной копии приложения
  и прошёл пять UI tests. В `lib` осталась одна итоговая реализация темы.
- Format и `flutter analyze` прошли. Полный suite — **119 tests**, включая
  уведомления контроллера, поиск/сочетания фильтров, изоляцию sessions, system theme,
  навигацию и синхронизацию поля. **40 golden-сравнений** с PNG Phase 1 прошли
  без обновления снимков; палитра, компоновка и общие компоненты сохранены.
- Android debug APK собран и запущен на `main_phone` (Android 17 / API 37, arm64).
  UI hierarchy и снимки подтвердили сохранение light theme, query и фильтра
  при Android Back и повторном открытии Projects. Force-stop и новый запуск
  вернули dark theme, пустой query и фильтр «Все».
- `flutter doctor -v` подтверждает неполный Xcode и отсутствие CocoaPods;
  iOS не проверен. В Android SDK отсутствуют cmdline-tools и не подтверждены
  лицензии, хотя debug сборка и запуск прошли. Документы/ссылки и project context
  проверены; `git diff --check` чистый.
- Persistence, repository/data layers и network не добавлены: они относятся
  к следующим фазам. Commit/push не выполнялись; Phase 3 не начата.

### Phase 3 — Architecture

**Задачи**

- [x] Разделить существующие auth/profile/projects сценарии на features с
  `presentation/domain/data`, Repository pattern и Riverpod dependency injection.
- [x] Убрать бизнес-правила из widgets; domain не связывать с Flutter, Dio, Hive
  или Firebase. Mock-реализации пока остаются источником данных.
- [x] Ограничить слои текущими сценариями: отдельные UseCase/DataSource для
  демонстрационных источников не потребовались.
- [x] Завершить синхронизацию architecture и обоснования Provider/Riverpod
  с итоговой реализацией и результатами приёмки.

**Проверки и приёмка**

- [x] UI получает данные через Repository и Riverpod DI; смена mock-источника
  не требует переписывать widgets.
- [x] Domain не зависит от Flutter, Dio, Hive или Firebase; бизнес-правила
  вынесены из widgets, пустые слои не созданы.
- [x] Существующие сценарии и значимые tests проходят; architecture и
  обоснование state management согласованы с кодом; Android-сценарии подтверждены.

**Реализовано и проверено в Phase 3 — 3 октября 2026**

- Публичные API `auth.dart`, `profile.dart` и `projects.dart` объединяют
  используемые модели, Repository contracts и presentation/providers каждой
  feature. Domain содержит правила email, выбора проектов и демонстрационный
  снимок готовности профиля; data владеет mock-реализациями. Общий
  `shared/mock_portfolio.dart` удалён, widgets получают модели через DI.
- `AuthController` открывает демо через `AuthRepository`: pending блокирует
  форму, ошибка позволяет повторить действие, навигация выполняется после
  успеха. Email нормализуется в `DemoSession` внутри app session; постоянное
  хранение и настоящая авторизация появятся в соответствующих фазах.
- `ProfileRepository` и `ProjectsRepository` доступны через Riverpod
  FutureProvider. Home и Portfolio используют общий `PortfolioOverview`,
  Settings читает идентичность из того же profile state. Поиск/фильтры Projects
  остаются независимым Notifier; выбор featured не зависит от фильтра экрана.
  Loading/error/retry используют общий UI-компонент, ожидание повторного
  запроса заменяет прежнюю ошибку состоянием загрузки.
- Замена источников проверяется Repository/DI tests, включая форму входа,
  loading/error/retry, альтернативный профиль и проекты в Home, Portfolio
  и предпросмотре. Domain остаётся чистым Dart; новых зависимостей,
  network, persistence и сервисов будущих фаз не добавлено. Полный Portfolio
  domain, правила заполнения и локальный Builder остаются задачами Phase 6.
- `flutter pub get --offline` прошёл; manifest и lockfile не изменились.
  Итоговый format: 50 Dart-файлов, без изменений; `flutter analyze --no-pub` —
  без замечаний. Полный suite — **142 tests**, включая подмену Repository
  в реальных widgets, loading/error/empty/retry, pending повторной загрузки,
  навигацию и неизменяемость моделей. **40 golden-сравнений** с сохранёнными
  PNG прошли без обновления снимков; палитра и компоновка Phase 1 сохранены.
- Android debug APK собран и запущен на `main_phone` (arm64). UI hierarchy
  и снимки подтверждают demo-вход, загрузку Home/Projects, поиск `React`
  → один Readme Studio, Portfolio Preview с отметкой неопубликованного draft,
  единый профиль в Settings и переключение в light mode. Снимки просмотрены.
- `flutter doctor -v`: Xcode неполный, CocoaPods отсутствует; iOS не проверен.
  Android cmdline-tools и подтверждение лицензий по-прежнему отсутствуют,
  хотя debug сборка и запуск прошли. Domain imports проверены: зависимостей
  от Flutter/Riverpod/data/presentation нет. Widgets не импортируют concrete
  mock-источники. Architecture, ADR, AI scope и учебные материалы синхронизированы;
  документы/ссылки, project context и `git diff --check` проверены.
- Учебные patches темы адаптированы к новым source paths и DI. Оба варианта
  проверены отдельно во временных копиях; рабочий код сохранил Provider.
  Commit/push не выполнялись; Phase 4 не начата.

**Готово, когда:** UI получает данные через согласованные границы, источник можно
заменить без переписывания widgets, существующие сценарии продолжают работать.

### Phase 4 — GitHub API

**Задачи**

- [x] Реализовать отдельный GitHub Import: ввод username, публичный профиль и repositories
  через Dio, модели и JSON serialization.
- [x] Добавить pagination, timeout, retry, pull-to-refresh и поиск/filter с debounce,
  где он нужен сценарию. Проверить актуальные rate limits и поведение API перед кодом.
- [x] Показать loading/success/empty/error; отделить сетевой источник от UI и подготовить
  используемый контракт кэша. Протестировать parsing и обработку сетевых сбоев.

**Проверки и приёмка**

- [x] Публичный профиль и repositories загружаются; pagination, refresh
  и используемый поиск/filter с debounce работают.
- [x] Loading/success/empty/error, timeout и retry проверены; пустой профиль
  и сетевой сбой не ломают экран.
- [x] Parsing и обработка сбоев покрыты tests; rate limits и поведение API
  сверены с актуальной документацией. Импорт в portfolio ещё не выполняется.

**Реализовано и проверено в Phase 4 — 3 октября 2026**

- Из Projects открывается отдельный `/github-import`: username валидируется до
  запроса, публичный профиль и repositories загружаются через Dio. JSON DTO
  преобразуются в pure Dart domain models; widgets используют Repository через
  Riverpod DI. Новый экран сохраняет существующие tokens и shared components.
- Следующая страница берётся из GitHub `Link`; разрешены только проверенные
  GitHub API URL текущего пользователя. Повторяющиеся repositories удаляются по
  ID. Поиск с debounce и фильтры работают по загруженным страницам; UI показывает
  их число и явно объясняет эту границу. Есть refresh и pull-to-refresh.
- Ошибки timeout/network/not found/rate limit/invalid response преобразуются
  в типизированные состояния с понятным текстом и явным retry. Ошибка refresh
  или следующей страницы сохраняет уже загруженный список. Замена username
  и закрытие экрана отменяют запросы; устаревший ответ не меняет актуальное состояние.
- Используется контракт `GitHubResponseCache` и его реализация в памяти app session:
  JSON, ETag и Link поддерживают conditional requests и ответы 304. Repository
  сохраняет rate-limit deadline при повторном открытии экрана. Disk cache,
  offline fallback и импорт в portfolio остаются задачами последующих фаз.
  Версия API, pagination и rate limits сверены с официальной документацией;
  ссылки и HTTP/cache contract записаны в [architecture](../architecture/architecture.md#github-import-http-и-persistent-кэш).
- Добавлены 72 tests: 37 для DTO/HTTP/cache/errors, 17 для controller и 18 для
  widgets/DI/responsive. Полный `flutter test` прошёл: **214 tests**, включая
  **40 golden-сравнений**. После добавления входа в GitHub Import обновлены
  8 Projects preview; остальные 32 preview сохранены. `flutter analyze` — без
  замечаний, format — 70 Dart-файлов без изменений.
- Debug APK собран и установлен на Android-эмулятор. Реальный API загрузил
  профили `flutter` и `google`; локальный поиск, следующая страница и явный refresh
  проверены на устройстве. Две страницы `google` дали 59 уникальных repositories
  после удаления дубля по ID; финальная сборка успешно обновила первую страницу.
  Pull-to-refresh, пустые данные и ошибки дополнительно проверены widget tests.
- Учебные patches темы проверены отдельно: оба применяются и проходят по 5 tests.
  Документы, локальные ссылки, project context и diff проверены. Android debug
  работает; doctor по-прежнему отмечает отсутствие cmdline-tools и неизвестный
  статус licenses. iOS-запуск не проверен: Xcode и CocoaPods не готовы.
  На момент приёмки Phase 4 следующий этап Phase 5 ещё не выполнялся.

**Готово, когда:** repositories загружаются и листаются, ошибку можно повторить,
пустой профиль не ломает экран. Импорт в портфолио и Firebase ещё не выполняется.

### Phase 5 — Local persistence / offline

**Задачи**

- [x] Сохранять theme, locale и простые настройки в SharedPreferences.
- [x] Использовать Hive для GitHub cache и local portfolio draft; альтернативу
  обосновать в ADR до реализации.
- [x] Определить cache lifetime, хранение несинхронизированных изменений и версию
  локальной модели; показывать доступные сохранённые данные без сети.
- [x] Проверить перезапуск, отсутствие сети, пустой/повреждённый кэш и восстановление
  соединения без потери draft.

**Проверки и приёмка**

- [x] Theme, locale и простые настройки сохраняются после перезапуска.
- [x] Ранее загруженные repositories и local draft доступны без сети;
  несинхронизированные изменения не теряются.
- [x] Пустой/повреждённый кэш и reconnect проверены; cache lifetime,
  версия модели и решение о локальном хранилище зафиксированы.

**Реализовано и проверено в Phase 5 — 3 октября 2026**

- `StackCardBootstrap` восстанавливает настройки и открывает отдельные Hive boxes
  в Application Support до первого экрана. SharedPreferencesAsync хранит цельный
  snapshot v1: dark/light/system, ru/en и показ описаний GitHub cards. UI имеет
  реальные переводы; source/user content сохраняет исходный язык. Ошибка записи
  оставляет выбор в session с явным retry, повреждённые preferences дают defaults.
- GitHub cache использует envelope v1 с JSON body, ETag, Link и UTC validatedAt.
  Network-first GET/304 обновляет дату; hard TTL — **7 дней**. Только network,
  timeout и server failures допускают сохранённую копию. UI показывает её источник
  и дату, storage failures не скрывают успешный HTTP. Expired/corrupt/unknown cache
  исключается из fallback; отмена проверяется после storage awaits.
- Из Portfolio открываются локальные заметки: явный Save сохраняет notes,
  revision, UTC updatedAt и pendingSync в draft envelope v1. Это предварительный
  notes draft; полный portfolio domain и Builder остаются Phase 6. Несохранённый
  ввод живёт в session; ошибка Save его не теряет и не выдаёт результат за saved.
  Remote sync пока отсутствует.
- Cache recovery/очистка не затрагивают draft. Повреждённый cache file сохраняется
  как backup и пересоздаётся; повреждённый draft или неизвестная schema сохраняются
  с блокировкой перезаписи. Реальные Hive tests проверяют reopen и файлы, включая
  закрытие draft при ошибке закрытия cache. Первая persistent версия не требует
  миграции старой модели; решения записаны в [ADR](../decisions/README.md#принято-для-phase-5).
- Добавлены **109 tests** для persistence, localization, draft и bootstrap.
  Полный `flutter test --no-pub --dart-define=UPDATE_UI_PREVIEWS=true` прошёл:
  **323 tests**, включая **40 golden-сравнений**. Обновлены 16 Portfolio/Settings
  previews для новых controls; остальные 24 сохранены. Проверены responsive,
  увеличенный текст, контраст и tap targets. Format — 98 Dart-файлов без изменений;
  `flutter analyze --no-pub` — без замечаний.
- Финальный debug APK собран и установлен на `main_phone` (Android 17/API 37).
  Force-stop/relaunch восстановил Light, English и выключенные source descriptions.
  После запрета сети только тестовому приложению профиль `google` и **30 ранее
  загруженных repositories** доступны с cached-copy notice/date; username без
  cache показывает «No connection» с retry. Notes доступны offline, новая правка
  увеличила revision до 2. Возврат сети и явный refresh убрали cache notice;
  повторный cold start сохранил правку, revision 2 и pendingSync. Native UI и
  снимки просмотрены; сетевые настройки эмулятора восстановлены.
- Оба учебных theme patches применяются независимо к свежим копиям проекта;
  каждый прошёл 5 widget и 9 localization/settings tests и targeted analyze.
  Bootstrap, Hive и feature DI сохранены. Architecture, ADR, design, mobile guide
  и AI context синхронизированы; документы/ссылки и project context проверены.
- `flutter doctor -v` по-прежнему отмечает отсутствие Android cmdline-tools и
  неизвестный статус licenses при успешной debug сборке. iOS не проверен:
  Xcode неполный, CocoaPods отсутствует. Commit/push не выполнялись;
  На момент приёмки Phase 5 следующий этап Phase 6 ещё не выполнялся.

**Готово, когда:** настройки переживают перезапуск, ранее загруженные repositories
доступны offline, локальные изменения сохраняются. Remote sync появится на Phase 8.

### Phase 6 — Portfolio domain и локальный Builder

**Задачи**

- [x] Ввести Profile, Skill, Project, Experience, Education, SocialLink, PortfolioBlock
  и PortfolioTheme по реальным формам, без окончательной Firestore schema заранее.
- [x] Реализовать ручные проекты и редактирование профиля, skills, links, experience,
  education и содержимого Resume; формат resume определить перед реализацией.
- [x] Добавить add/edit/delete, featured, block reorder, show/hide, validation и preview.
  Сохранять изменения в локальный draft.
- [x] Рассчитать portfolio completion и покрыть правила/validation unit tests,
  основной сценарий editor — widget tests.

**Проверки и приёмка**

- [x] Ручные проекты и данные профиля можно добавить, изменить и удалить;
  featured, порядок и видимость блоков отражаются в preview.
- [x] Draft сохраняется, открывается после перезапуска и просматривается offline.
- [x] Validation и completion покрыты unit tests, основной путь editor —
  widget tests; формат Resume определён. Public publication ещё не доступна.

**Готово, когда:** портфолио можно собрать, сохранить, открыть после перезапуска
и просмотреть offline. Публичной публикации пока нет.

**Реализовано и проверено в Phase 6 — 3 октября 2026**

- Pure Dart `PortfolioContent` объединяет профиль, skills, ручные projects,
  experience, education, links, Resume, десять ordered/visible блоков и PortfolioTheme.
  Коллекции immutable, сущности имеют стабильные IDs и structural equality.
  Demo Profile/Project остались моделями чтения; mock/GitHub данные не копируются в draft.
- Семь редакторов используют общие components, ru/en validation и Apply/Cancel.
  Apply изменяет только свою секцию актуального рабочего content; Cancel не меняет
  draft. Списки поддерживают CRUD; проект — featured и visibility. Resume выбран
  plain text с переносами строк и лимитом 20 000 символов, без файлов/upload.
- Preview читает рабочий draft; порядок, visibility и dark/light оформление
  применяются сразу. Private notes отделены от рендеримого типа. Home, Portfolio,
  Projects, Settings и shell показывают тот же content; скрытые проекты остаются
  доступны владельцу на Projects, но исключаются из featured/preview.
- Completion вычисляется из пяти шагов: профиль, About, skills, хотя бы один
  видимый проект, links. Опциональные секции не блокируют 100%; скрытие блока
  не увеличивает процент. Незавершённый draft можно сохранить, неверные значения — нельзя.
- Hive schema v2 сохраняет nullable content отдельно от notes/metadata. V1 читается
  без записи; первый явный Save оставляет raw backup перед заменой. Notes patch
  сохраняет content; expectedRevision предотвращает устаревшую запись. Corrupt/unknown
  draft не перезаписывается. Read gate объединяет cold reads и допускает demo
  только после успешного чтения; ошибки имеют явный retry.
- Save захватывает content/notes/revision, обновляет durable snapshot после успеха
  и сохраняет более новый рабочий ввод. Duplicate Save блокируется; failure не
  удаляет правки. Reload требует подтверждения сброса unsaved content и notes.
- `dart format lib test`: 131 файл; `flutter analyze`: без замечаний.
  Полный `flutter test --dart-define=UPDATE_UI_PREVIEWS=true`: **530 tests passed**,
  включая миграцию, конфликты/races, CRUD, validation/completion, чтение/DI, privacy,
  keyboard, ru/en и responsive. Сравнение **56 PNG эталонов** прошло: 40 основных
  и 16 Builder; 16 Portfolio/Projects обновлены из-за новых входов в редактор.
  Контраст AA и 48px targets новых экранов проверены стандартными guidelines
  для всей высоты содержимого; реальная прокрутка и 320px/text2.0 проверены отдельно.
- Оба учебных patch независимо применены к свежим копиям финального source:
  `git apply --check`, `flutter analyze lib` и по **14/14** widget/localization tests.
- Финальный Android debug APK собран и установлен на `main_phone`, Android 17/API37,
  arm64. Через native UI заполнены профиль/About и ручной featured-проект;
  Save увеличил revision 2→3→4, completion 0→40→60%. После force-stop и нового
  запуска с Wi-Fi/mobile data отключёнными Home и preview восстановили имя,
  описание, технологии и проект. Исходное состояние сети восстановлено.
  [Builder](../design/previews/portfolio_builder_android_phone.png) и
  [offline preview](../design/previews/portfolio_preview_android_phone.png) просмотрены.
- Flutter doctor подтверждает неполный Xcode и отсутствие CocoaPods: iOS-запуск
  не выполнен. Android cmdline-tools отсутствуют, статус лицензий неизвестен;
  debug build/run при этом успешны. Физические phone/tablet не проверены;
  tablet/landscape покрыты Flutter rendering. Dependencies не добавлены.
  Документы/ссылки и diff проверены; commit/push не выполнялись. Phase 7 не начата.

### Phase 7 — Firebase authentication

**Задачи**

- [x] Подключить Firebase configuration для Android/iOS; описать generation,
  dev environment и необязательный Auth Emulator в CONTRIBUTING.
- [ ] Завершить email/password и Google sign-in, регистрацию, восстановление пароля,
  auth state и sign out: реализация готова; Google provider/OAuth configuration
  и native Google приёмка остаются открытыми.
- [x] Добавить именованные routes, параметры, вложенную навигацию и auth redirects
  в GoRouter; unit/widget проверки transitions и session restore проходят.
- [x] Привязать local draft к Firebase UID; реализовать явный guest transfer
  и изоляцию данных при смене аккаунта.

**Проверки и приёмка**

- [ ] Все обязательные auth сценарии проверены на native targets. Android live
  registration/email sign-in/sign out и reset API acceptance подтверждены;
  Google flow, фактическое письмо/reset пароля и iOS ещё не приняты.
- [x] Auth redirects, именованные routes, параметры и вложенная навигация
  проверены для owner/guest/restoring/error/signedOut в Flutter tests.
- [x] Гостевой draft переносится явно только в пустой target; sign out, UID switch,
  late save, сбой transfer/reopen и private form state проверены без чужих данных.

**Реализовано и проверено в Phase 7 — 4 октября 2026**

- Firebase CLI доступен, Google login выполнен; FlutterFire CLI и Ruby `xcodeproj`
  установлены для generation. Создан отдельный development project;
  canonical project/app IDs находятся в [Firebase options](../../apps/mobile/lib/firebase_options.dart)
  и [native configuration](../../apps/mobile/firebase.json). Android/iOS apps
  зарегистрированы с существующими package/bundle IDs, debug SHA-1 добавлен.
  Billing upgrade, Firestore, deploy и публикация не выполнялись.
- Email/Password включён в Firebase Console. Google provider требует support
  email, видимого на OAuth-экране: ждём подтверждения адреса пользователя перед
  сохранением. После включения требуется regeneration native configs, iOS client
  ID/URL scheme и отдельная live Google проверка.
- Pure Dart account repository/user/failures, Firebase adapter и Riverpod session
  отделены от legacy demo preview. Password/token не сохраняются приложением.
  SDK restoring/error блокируют private routes и repository; ошибка не открывает
  guest/старый UID fallback. Sign out подтверждает отбрасывание unsaved changes.
- GoRouter использует именованные routes, безопасный локальный `from`, auth forms,
  вложенные Builder routes и project parameters. UID/access boundary очищает
  controller/projections, filters, editor/dialog state. Profile loading/error
  не показывает cached initials предыдущего пользователя.
- Hive сохраняет старый guest namespace и отдельные UID namespaces. Явный transfer
  сохраняет envelope/revision/legacy backup; durable owner journal и generation
  защищают retry/reopen и запрещают старому guest adapter воскресить draft.
  Чужой UID не получает retry reserved transfer. Новые working edits во время
  transfer сохраняются; при отсутствии новых правок controller перечитывает target.
- Native Android [acceptance test](../../apps/mobile/integration_test/account_runtime_test.dart)
  прошёл на `emulator-5554`: создание disposable аккаунта → sign out → отказ при
  неверном пароле → email sign-in с тем же UID → reset API → sign out → удаление
  только созданного тестового аккаунта. Reset подтверждает SDK/backend acceptance;
  адрес `example.invalid` исключает доставку письма и не доказывает реальный reset.
- Итоговый format check прошёл, `flutter analyze` без замечаний,
  `flutter test` — **621 tests passed**, включая прежние visual checks и новые
  auth/navigation/UID/transfer/recovery regressions. Docs links и diff проверены.
  Native SDK session restore между процессами прошёл: `seed` создаёт account,
  `check` после перезапуска восстанавливает тестового пользователя до любого
  sign-in и удаляет account. Seed даёт SDK время на асинхронную persistence
  перед принудительной остановкой test runner; runtime persistence не изменялась.
  Native lifecycle/bootstrap suite — **2 passed, 1 skipped** (restore запускается
  отдельной парой): реальная account форма и явный guest переход в app shell
  подтверждены. Screenshot Android auth формы сохранён отдельно от suite.
- Первый native runner без `--no-uninstall` удалил приложение эмулятора после
  проверки. Прежние draft/cache/settings восстановлены из существующего
  `default_boot` snapshot; отдельная локальная копия сохранена перед повтором.
  Повторные запуски используют `--no-uninstall`; контрольная сумма draft после
  тестов совпала. Команды исправлены в CONTRIBUTING.
- Android debug APK собран; обычный `main.dart` снова запущен после native tests.
  Контрольная сумма восстановленного draft после запуска совпала.
  iOS config сгенерирован, но сборка/запуск недоступны:
  Xcode установлен неполностью, CocoaPods отсутствует. Doctor также отмечает
  отсутствие Android cmdline-tools и неизвестный статус лицензий; Android
  debug build и native auth test при этом прошли. Commit/push не выполнялись.

**Готово, когда:** оба способа входа работают, защищённые экраны доступны владельцу,
sign out и смена пользователя не раскрывают чужой локальный draft. Phase 7 остаётся
в работе до приёмки открытых native auth сценариев. По отдельному поручению
пользователя завершена Phase 8; незавершённые проверки Phase 7 сохранены.

### Phase 8 — Firestore synchronization

**Задачи**

- [x] До remote writes спроектировать private account/draft, public snapshot,
  username uniqueness и проверяемую атомарность publish/unpublish. Зафиксирован
  [ADR 0001](../decisions/0001-firestore-sync-and-publication.md) до remote writes.
- [x] Ввести remote repository поверх local cache; выбрать conflict strategy для
  нескольких устройств и будущего web-клиента, описать последствия.
- [x] Реализовать `pending/synced/error`, повтор синхронизации и обработку потери сети.
- [x] Создать Firestore Rules и проверки owner access, отказа чужому пользователю
  и анонимного доступа только к опубликованным данным.

**Проверки и приёмка**

- [x] Offline-правки синхронизируются после reconnect; pending/synced/error
  и повтор после сбоя отражают фактическое состояние.
- [x] Конфликт нескольких клиентов обработан по выбранной стратегии;
  private/public schema, username uniqueness и атомарность публикации описаны в ADR.
- [x] Firestore Rules tests подтверждают owner access, отказ чужому пользователю
  и анонимное чтение только published данных; private draft остаётся private.

**Готово, когда:** offline-правки доходят до облака после восстановления сети,
конфликт обрабатывается по выбранной стратегии, private данные остаются private.
Механизм явной публикации подготовлен; public web появится на Phase 13.

**Результат проверки (2026-10-04): Phase 8 завершена.**

- Dev-база `(default)` проекта `stackcard-dev-snownumb` создана в согласованном
  `europe-west3`; CLI подтвердил `freeTier: true`. Rules и indexes успешно
  развёрнуты; billing upgrade не выполнялся.
- Account draft синхронизируется поверх Hive с durable outbox, server ACK,
  восстановлением очереди и состояниями `pending/synced/error/retry` в Builder
  и private notes. Whole-draft LWW определяется порядком server commits;
  локальные revisions разных устройств не сравниваются. Несохранённый ввод
  сохраняется при remote update; повторный Save явно отправляет свою версию.
- Guest transfer проверяет облачный destination и атомарно занимает только
  пустой draft. Occupied account сохраняет свой draft и исходный guest;
  owner journal, потерянный ACK и незавершённый Phase 7 transfer восстанавливаются
  без переноса чужому UID и без блокировки shared Hive queue.
- `flutter analyze` — **No issues found**; `flutter test` — **688 tests passed**;
  format check — **165 files, 0 changed**. Проверены adapter/schema/public
  projection, outbox/retry/ACK, UID lifecycle, transfer recovery и UI states.
- `npm run test:rules` — **24 passed, 0 failed**. Emulator tests подтверждают
  owner access, отказ foreign/anonymous к private draft, anonymous `get` только
  published snapshot, запрет listing, username uniqueness и атомарность
  publish/rename/unpublish. Publication repository подготовлен; public UI ещё
  не вводится. Hidden fields и private notes не входят в public projection.
- Android native lifecycle suite — **1 passed, 1 skipped**: настоящий SDK
  проверил offline Save, Hive reopen, reconnect/server ACK, LWW двух клиентов,
  foreign/anonymous denial и cloud-aware guest transfer. Отдельные процессы
  `seed` и `check` — **по 1 passed, 1 skipped**: SDK восстановил account до sign-in,
  Hive сохранил pending outbox, новая session отправила его после reconnect.
  Skipped test в каждом запуске относится к другому режиму этой же suite.
  Тестовые accounts/drafts и изолированное restore-хранилище удалены.
- Обычный `main.dart` собран и запущен на `emulator-5554` после native tests.
  Native tests использовали `--no-uninstall`; checksum исходного guest draft совпал.
  Docs links и diff проверены; Markdown render отдельно не проверялся.
  iOS native sync не проверен из-за незавершённого Xcode/CocoaPods toolchain;
  Google/reset/iOS приёмка Phase 7 остаётся открытой. Commit/push не выполнялись.

По отдельному следующему поручению завершена Phase 9; дальнейшие этапы требуют
отдельного поручения пользователя.

### Phase 9 — Living Portfolio / Smart GitHub Sync

**Задачи**

- [x] Добавить импорт repository → Project с `source = manual | github`,
  `githubRepositoryId`, `lastGitHubSyncAt` и sync status.
- [x] Разделить source metadata и пользовательские overrides; повторный импорт
  одного repository не должен создавать дубликаты.
- [x] Обнаруживать новые/изменённые repositories и показывать Ignore, Preview,
  Add to portfolio и Review changes.
- [x] Проверить повторную синхронизацию, сохранение ручных правок и отсутствие
  автоматического изменения published snapshot.

**Проверки и приёмка**

- [x] Выбранный repository импортируется в Project; повторный импорт
  не создаёт дубликат, source metadata и overrides сохраняются раздельно.
- [x] Новые и изменённые repositories предлагают Ignore, Preview,
  Add to portfolio и Review changes; владелец выбирает действие.
- [x] Повторный sync сохраняет ручные правки и не меняет published snapshot
  без явной публикации; сценарии проверены.

**Готово, когда:** владелец импортирует и принимает выбранные изменения,
а обновление GitHub не перезаписывает curated данные и публичную версию молча.

**Текущий результат (2026-10-04):** Phase 9 завершена. Контракт импорта и review
зафиксирован в [ADR 0002](../decisions/0002-github-import-and-review.md).

- Добавлены явные Add, Preview, Ignore и Review changes. GitHub source и ручные
  overrides хранятся раздельно; повторный импорт и rename repository используют
  стабильный GitHub ID и не создают дубликат. Accept обновляет только поля без
  ручного override; live URL, featured и visibility остаются под контролем владельца.
  Source refresh не меняет draft; выбранные изменения требуют отдельного Save.
- Ignore сохраняет fingerprint конкретной версии source в private draft;
  следующая версия снова предлагает review. `lastGitHubSyncAt` использует дату
  проверки конкретного repository, включая pagination/cache; неизвестная дата
  остаётся `null`. Изменения статистики и активности тоже видны в review.
- Hive пишет envelope v3 и читает v1/v2/v3; Firestore пишет private schema 2
  и читает 1/2. Legacy проекты остаются manual, новые поля не требуют eager
  rewrite. Public projection исключает source metadata, overrides и ignore;
  импорт/review не вызывает publication repository и не меняет published snapshot.
- `dart format --output=none --set-exit-if-changed lib test integration_test` —
  **174 files, 0 changed**; `flutter analyze` — **No issues found**;
  `flutter test` — **772 passed**. Проверены domain/codec, legacy migration,
  controller/UID guards, provenance отдельных repositories, public boundary и UI.
  Stale review/editor и некорректный source не перезаписывают свежий draft.
- `npm run test:rules` — **27 passed, 0 failed**. Проверены owner isolation,
  schema 2 и запрет downgrade, public projection и publication transactions.
  Firestore Rules и indexes успешно развёрнуты в существующий dev-проект
  `stackcard-dev-snownumb`; регион `(default)` остаётся `europe-west3`.
- Android native lifecycle suite — **1 passed, 1 skipped**: offline Save,
  Hive reopen, cloud ACK и повторный GitHub review сохраняют source metadata
  и ручные правки; LWW и private access проверены настоящим SDK.
  Отдельные процессы `seed` и `check` — **по 1 passed, 1 skipped**: pending
  GitHub draft пережил завершение процесса и синхронизировался после reconnect.
  Skipped test относится к другому режиму той же suite; тестовые accounts/drafts
  и изолированное restore-хранилище удалены.
- Карточки и review визуально проверены в light/dark при 390×844; обычный
  `main.dart` собран и запущен на `emulator-5554`. Native tests использовали
  `--no-uninstall`; checksum исходного guest draft совпал после проверок.
  Docs links и diff проверены; Markdown render отдельно не проверялся.
  iOS native sync не проверен из-за незавершённого Xcode/CocoaPods toolchain;
  Google/reset/iOS приёмка Phase 7 остаётся открытой. Commit/push не выполнялись.

По следующему отдельному поручению начата Phase 10; дальнейшие этапы требуют
отдельного поручения пользователя.

### Phase 10 — Portfolio Suggestions

**Задачи**

- [x] Реализовать deterministic rules: новый repository, активность, отсутствующие
  description/preview и кандидаты для featured.
- [x] Если нужен внутренний ProjectScore, определить факторы и пороги в одном месте;
  UI показывает причину и полезное действие.
- [x] Проверить правила unit tests независимо от UI и внешних сервисов.

**Проверки и приёмка**

- [x] Одинаковые входные данные дают одинаковые suggestions;
  новый repository, активность и отсутствие description/preview проверены.
- [x] Каждая suggestion объясняет причину и предлагает действие владельцу;
  факторы и пороги ProjectScore определены в одном месте, если он используется.
- [x] Unit tests правил проходят без UI и внешних сервисов; AI и
  автоматическая публикация не введены.

**Готово, когда:** одинаковые входные данные дают объяснимые suggestions,
владелец выбирает действие; AI и автоматическая публикация не используются.

**Текущий результат (2026-10-04):** Phase 10 завершена. Pure rules и причины
описаны в [architecture](../architecture/architecture.md#portfolio-suggestions).

- `buildPortfolioSuggestions` принимает content, source snapshots и явное время;
  возвращает immutable рекомендации со stable IDs и порядком. Реализованы новый
  repository, недавнее известное обновление, длительный простой, отсутствующие
  description/demo и candidate для featured. Hidden проекты исключены, повторные
  sources объединяются по ID; Ignore конкретной версии учитывается, ручные
  overrides не меняются. Projects использует accepted source offline, GitHub cards —
  загруженный snapshot конкретного repository.
- `PortfolioSuggestionThresholds` хранит пороги в одном месте: recent ≤30 дней,
  inactive ≥180 дней, featured ≥5 stars либо recent при заполненных curated полях;
  future date не считается recent. Manual candidate требует description,
  technologies и demo. UI объясняет фактическое условие и предлагает действие;
  `ProjectScore` не понадобился. Preview означает demo link (`liveUrl`),
  изображения и screenshots остаются Phase 11.
- Projects и source cards показывают причины ru/en и открывают прежний
  Preview/project editor. Нет автоматических Add/Accept, изменения featured,
  Save или публикации. Provider не читает private draft без account/explicit guest,
  не показывает demo advice при отсутствии content и сбрасывает рекомендации
  прежнего UID. Новых зависимостей, storage schema или Firebase конфигурации не вводилось.
- `dart format --output=none --set-exit-if-changed lib test integration_test` —
  **180 files, 0 changed**; `flutter analyze` — **No issues found**;
  `flutter test` — **822 passed**. Включены **33 pure rules**, **5 provider**
  и **12 widget** tests: границы времени, future dates, dedup/order, ignored
  versions, manual/legacy, hidden/featured/forks/archived, overrides и отсутствие
  мутаций; working edits, UID/private read guards, editor/Preview actions,
  loading/failure, ru/en и responsive при увеличенном тексте.
- Synthetic Projects/source screenshots при 390×844 просмотрены в light/dark;
  overflow не обнаружен, оригинальные assets и прежние goldens сохранены.
  Обычный `main.dart` собран и запущен на `emulator-5554`, процесс работает;
  checksum исходного guest draft совпал. Docs links и diff проверены;
  Markdown render отдельно не проверялся. iOS native запуск не проверен при
  незавершённом Xcode/CocoaPods toolchain; Google/reset/iOS приёмка Phase 7
  остаётся открытой. Commit/push не выполнялись.

Phase 11 разрешена отдельным поручением 2026-10-07; переход к Phase 12 требует нового поручения.

### Phase 11 — Media

**Задачи**

- [x] Подключить Firebase Storage для avatar и project images, camera/gallery.
  При выбранном файловом формате resume добавить его загрузку здесь.
- [x] Ввести MIME/size validation, compression/resize, upload progress, retry
  и image caching через cached_network_image; обработать отказ в permissions
  и отмену выбора.
- [x] Создать Storage Rules, проверку ownership и public/private доступа,
  определить очистку заменённых файлов.

**Проверки и приёмка**

- [ ] Avatar и project images выбираются через camera/gallery,
  проходят MIME/size validation, compression/resize и отображаются после upload.
- [ ] Progress, retry, caching, отказ в permissions и отмена выбора проверены
  на устройстве; выбранный файловый Resume обрабатывается, если он предусмотрен.
- [x] Storage Rules tests подтверждают ownership и public/private доступ;
  чужие/private файлы недоступны, очистка заменённых файлов определена.

**Готово, когда:** изображения загружаются и отображаются, сбой даёт повтор,
чужие/private файлы недоступны. Нативный сценарий проверен на устройстве.

**Текущий результат (2026-10-07):** реализация Phase 11 выполнена на `dev`;
фаза остаётся в работе до полной нативной приёмки. Контракт —
[ADR 0003](../decisions/0003-private-portfolio-media.md).

- Profile/project editors используют camera/gallery, JPEG/PNG/WebP validation,
  isolate resize/compression с удалением EXIF/GPS, progress, typed failure и
  retry без повторного выбора. Cancel не меняет draft; Apply и Save отдельны.
  Resume остаётся обычным текстом. Upload доступен аккаунту, guest local-only.
- `avatarPath` и до шести `imagePaths` сохраняются в Hive v4/private Firestore
  schema 3; legacy versions читаются без перезаписи, downgrade запрещён.
  GitHub import/review и текстовые правки сохраняют media. Portfolio/preview и
  Projects показывают private SDK bytes; внешние public avatars используют
  cached_network_image. Private cache только memory/UID scoped, без disk persistence.
- Storage Rules разрешают owner get/create/delete только immutable JPEG до 2 MiB,
  запрещают overwrite/list/foreign/unauthenticated/public namespace. App не
  получает download URLs/tokens; сознательно раскрытый owner bearer URL Rules
  не защищают. Public codec физически исключает private media fields.
- Новые отменённые uploads очищаются best effort; old saved paths сохраняются
  для offline/LWW references. Server garbage collection отсутствует, политика
  retention/очистки определена в ADR. Lost picker result после Android process
  death автоматически не применяется к новому owner/draft.
- Проверки macOS zsh, cwd `apps/mobile`: формат **202 files, 0 changed**;
  итоговый `flutter analyze --no-pub` — **0 issues (3.4s)**; полный
  `flutter test --no-pub --reporter expanded` — **1013/1013 PASS (34s)**.
  После уточнения ru/en сообщений и общего лимита повторены focused
  media/localization tests — **24/24 PASS**. Pure model, migration, public
  projection, provider UID/races, processor, forms/retry/cancel, narrow320/
  text scale2 и locale parity входят в эти результаты.
- `npm run test:all-rules` (cwd `firebase`) — **40/40 PASS**: 32 Firestore,
  8 Storage; strict Design v2 asset/source integrity — **PASS**; local docs links
  и `git diff --check` — **PASS**. NativeAppIcon/полная Design v2 parity этим
  checker не подтверждаются.
- `media_runtime_test.dart` на **emulator-5554** с Auth/Storage demo emulators
  — **1/1 PASS (8s)**: настоящий Android SDK upload/progress/read и отказ
  foreign/unauthenticated access. APK собран; обычный app session/draft не
  менялся named SDK apps. Для emulator HTTP добавлен debug-only network config
  с разрешением localhost/10.0.2.2; release исключение не получает.
- После SDK теста обычный `main.dart` снова собран и запущен на emulator-5554
  через `flutter run --no-pub --no-resident`, без uninstall. Две synthetic
  media-формы с progress45% отрисованы при 390×844 с локальными Manrope/Noto
  и просмотрены; controls/progress/form fields без overflow. Снимки временные,
  mock preview не подтверждает системный picker или native visual parity.
- **Открыто:** системные camera/gallery, отказ permissions и network retry на
  устройстве, live bucket/Rules deployment, private image после native
  Save/restart, iOS. Android SDK тест не подменяет эти сценарии. Live Storage
  требует Blaze/созданный bucket; billing upgrade и deployment не выполнялись.
  Google/reset/iOS Phase 7 и полная Design v2 acceptance остаются открытыми.
  По следующему поручению 2026-10-07 разрешена Phase 12; эта открытая приёмка
  Phase 11 не считается завершённой при переходе.

### Phase 12 — Location

**Изменение scope 2026-10-07:** по прямому решению пользователя карта, marker,
Google Maps SDK и настройка Maps API исключены из проекта. Location остаётся
обычным выбором города/страны с опциональным определением по геопозиции.
Это изменение требований проекта, а не подтверждение соответствия исходному
учебному пункту о карте.

**Задачи**

- [x] Добавить ручной выбор города и страны в Profile Location Picker.
- [x] Подключить geolocator и native reverse geocoding к действию
  «Определить мой город»; результат редактируется и подтверждается пользователем.
- [x] Обработать denied, permanently denied и service disabled; в публичное
  представление передавать только выбранный город/страну без точных coordinates
  и адреса. При timeout или ошибке определения города оставить ручной ввод.

**Проверки и приёмка**

- [x] Ручной выбор и отмена работают без геолокации и без запросов разрешений:
  widget checks подтверждают нулевой запрос при открытии/manual/cancel;
  Android manual picker → confirm → Hive reopen/public payload —1 PASS.
- [ ] Геопозиция запрашивается только по действию пользователя;
  город/страна подтверждаются, Apply меняет форму/draft, Save сохраняет результат.
- [ ] Denied, permanently denied и service disabled проверены;
  отказ не блокирует editor.
- [x] Public представление содержит только выбранный город/страну;
  точные GPS coordinates и адрес не раскрываются; скрытый Location исключён.

**Готово, когда:** location выбирается и сохраняется, отказ не блокирует editor,
публичное портфолио не раскрывает точную геопозицию.

**Реализация и проверки 2026-10-07:**

- Google Maps packages и transitive Maps dependencies удалены из manifest/lockfile;
  Maps enable flag и подготовленный coordinate contract удалены. Карты/marker/API
  configuration не входят в активные требования. Geolocator/native geocoding
  остаются только для optional «Определить мой город».
- `features/location` возвращает `PortfolioPlace` без координат/адреса; SDK data
  использует только locality/country. Android — coarse permission, iOS — When In Use;
  fix20s/geocoding15s ограничены, stream/background updates отсутствуют.
- Picker редактирует/подтверждает город/страну, legacy `locationText` сохраняется.
  Apply и Save отдельны; manual edits/Cancel/UID/repository transitions не получают
  поздний результат. Public projection исключает скрытый Location.
- Полный `flutter test --no-pub --reporter expanded` — **1068/1068 PASS**, 33s,
  **55 новых cases**: data28, UI23, persistence/public4. Focused финальный UI/Builder/
  media/localization —65/65 PASS. Проверены explicit request, typed failures,
  settings/retry, late results, same-repository UID change, Apply/Save,
  ru/en,320×568/568×320,text scale2 и keyboard.
- `flutter analyze --no-pub` — **0 issues**, 4.3s; format212files/0changes,
  `git diff --check` clean. Source integrity checker PASS, documentation validator
  PASS. Dark/Light390×844 с реальными Manrope/Noto отрисованы и просмотрены,
  без overflow; headless preview не доказывает native visual parity.
- Android `integration_test/location_runtime_test.dart`, `serviceDisabled` —
  **1 PASS**, 3s; actual SDK отказ проверен. Прежний master location switch восстановлен.
  Debug APK собран81.3s. Tests используют отдельный Hive test storage и
  `--no-uninstall`, ordinary account/draft не очищаются.
- Android `manual` — **1 PASS**, 15s: настоящий picker → ручной город/страна →
  подтверждение → Save → Hive reopen → city-only public payload, при coarse
  permission=false. После закрытия зависшего Google Play Services dialog и
  перезапуска test runner сценарий выполнен; process restart этим тестом не доказан.
- Обычный `main` восстановлен через `flutter run --no-pub -d emulator-5554
  --no-resident` — exit0. Состояния эмулятора восстановлены: coarse permission=false,
  master Location=true. Commit/push в этом этапе не выполнялись.
- **Открыто:** успешный native geolocation/reverse geocoding и системные denied/
  permanently denied flows на устройстве. `granted` на API37.2 эмуляторе завершился
  timeout20s; Google Play Services Location Accuracy dialog затем дал ANR,
  поэтому успешный fix не подтверждён. Fine permission ради эмулятора не добавлялась.
  iOS build/runtime не проверены: выбран только CommandLineTools, полного Xcode нет.
  Открытые Phase7/Phase11/Design v2 gates сохраняются; Phase13 не начата.

### Phase 13 — Website и web editor

Обновлённый scope: общая база/Library, разные Resume/Portfolio и постоянный URL
каждого опубликованного документа. Legacy `publish(username, content)` и
`/u/[username]` не определяют новый public API; их совместимость и миграция
решаются до переключения. D048 (2026-10-08) явно разрешает web и публикацию:
actual Next.js/Functions и mobile clients реализованы в source. Итоговые
checks и разрешённые browser/native попытки фиксируются в текущем статусе;
live deployment не подтверждён, Phase13 целиком не объявляется завершённой.
Отметки source-задач ниже не означают приёмку соответствующего сценария.

13a/13b/13c обозначают части результата. Минимальный 13a runtime и public slice
13c могут дать работающую публикацию из mobile до полного owner editor 13b.
Единственная обязательная последовательность — data/privacy/URL contract и
trusted validation → public reader → доступные Publish/Copy/Open действия.
Ни Figma frame, ни новый scaffold не доказывают готовность этих сценариев.

#### 13a — Public shell

**Задачи**

- [x] Создать Next.js runtime в apps/web по реальному manifest/config, выбрать
  необходимые зависимости и format/typecheck/test/build команды из actual manifest.
- [x] Перенести tokens/shared controls и минимальную оболочку public reader
  Resume/Portfolio по Figma R6; phone/tablet/wide, dark/light и photo/no-photo.
- [x] Реализовать landing и download по Figma с пользой base→outputs;
  CTA/store links отражают фактическую доступность сборок и редактора.

**Проверки и приёмка**

- [ ] Реальный browser runtime/build работает; layout, keyboard/focus и UI states
  проверены, screenshots сопоставлены с согласованными Figma frames.
- [ ] Пустые/unavailable/download состояния не обещают отсутствующих функций.
- [ ] В public shell отсутствуют private data/owner controls; интеграция с
  published reader принимается по 13c, не по наличию статического макета.

#### 13b — Auth и редактор

**Задачи**

- [x] Реализовать sign-in/register/reset и owner guards общего backend;
  login/provider data отделить от публичных контактов.
- [x] Создать кабинет с общей базой, Library и библиотеками Resume/Portfolio;
  создавать, редактировать, дублировать и удалять выбранный документ по ID.
- [x] Поддержать document content/appearance/preview, выбор Library projects,
  attachment order/visible/featured, attached Resume и выборочный base review.
- [x] Использовать совместимые versioned JSON fixtures/private schema;
  сохранять только выбранный scope, показывать dirty/saving/error/retry/conflict.
- [ ] Проверить обмен mobile↔web, newer input during Save, UID transitions,
  повреждённые/неизвестные данные и последствия whole-aggregate LWW.

**Проверки и приёмка**

- [ ] Anonymous/foreign access к private базе, документам и media отклоняется
  на стороне данных; routing guard сам по себе не считается защитой.
- [ ] Frontend Resume и Backend Resume одного владельца остаются независимыми;
  один Project выбирается в оба без копирования Library записи.
- [ ] Base review сохраняет local overrides; правка базы/Library не публикует
  ничего автоматически, изменение одного scope не захватывает соседний ввод.
- [ ] Wide editor показывает параметры/preview рядом, narrow — отдельные modes;
  Save/Cancel и ошибки доступны с keyboard/увеличенным текстом.
- [ ] Совместимость двух клиентов и явно выбранная conflict policy подтверждены
  contract/integration tests; online-first ограничения web объяснены.

#### 13c — Public Resume и Portfolio

**Задачи**

- [x] Утвердить documentId→permanent publicId mapping, exact route, publication
  inventory/version и совместимость legacy username snapshot/alias.
- [x] Реализовать trusted validation/projection выбранного saved+ACK документа:
  selected contacts/sections и resolved visible projects; закрыть прямую запись
  неподтверждённого public payload из клиента.
- [x] Исключить notes, baseSnapshot, Ignore/source metadata, login/providers,
  private Storage paths и hidden data до записи public snapshot.
- [x] Определить безопасный public media lifecycle: выбранные фото доступны
  посетителю; draft replacement/removal не уничтожает published assets.
- [x] Реализовать Publish/Update/Unpublish выбранного Resume/Portfolio, stale/unknown
  outcomes/retry/reopen reconciliation и generation защиту withdraw/delete.
- [x] Реализовать anonymous published-only reader и настоящие Copy/Open actions;
  постоянная ссылка доступна у опубликованного документа в библиотеке/редакторе.
- [x] Сохранить URL после rename/username change/unpublish→republish;
  duplicate начинает отдельный draft без URL исходника.
- [x] Публичное Portfolio может ссылаться только на отдельно published Resume;
  private/unpublished/deleted Resume attachment не раскрывается посетителю.
- [ ] Проверить metadata/SEO/OpenGraph, безопасные missing/unpublished states и
  одинаковую выбранную версию на mobile preview и public web.

**Проверки и приёмка**

- [ ] Изменение draft, базы или Library не меняет published snapshot до отдельного
  Update/Publish. Save local, sync ACK и publication — различимые состояния.
- [ ] Anonymous получает только allowlisted published данные; malicious nested
  payload, foreign UID, hidden contacts/media и listing отклонены.
- [ ] Rename/republish сохраняют URL, duplicate получает новую идентичность;
  unknown operation перечитывает подтверждённое состояние вместо ложного success.
- [ ] Unpublish закрывает доступ, delete не воскресает после delayed Save/ACK/retry;
  соседние документы и Library остаются доступны владельцу.
- [ ] URL действительно открывается без login на телефоне/desktop; Copy/Open
  используют подтверждённый адрес, private attachment не становится ссылкой.

**Готово, когда:** владелец публикует выбранный Resume/Portfolio из mobile и web;
посетитель открывает именно опубликованный snapshot по постоянному адресу.
Первые mobile→public сценарии допустимы до полного 13b; Phase 13 целиком закрывается
после приёмки всех трёх частей. Contact me/Inbox подключаются на Phase 14.

### Phase 14 — Contact / Inbox / FCM

**Задачи**

- [ ] Добавить web Contact me с name/email/message и validation; определить
  anti-spam/rate limiting до публичного открытия формы. Форма относится к выбранному
  published документу и учитывает его contact/privacy selection.
- [ ] Создать ContactRequest и Inbox в mobile/web; обращения читает только владелец.
  Проверить переход к обращению без добавления пятой root-вкладки и передачу
  только разрешённых полей; private owner identity не раскрывать отправителю.
- [ ] Настроить mobile FCM: device tokens, permissions и переход из уведомления
  к обращению. Отправку выполнять с доверенной стороны, с Functions при необходимости.
- [ ] Проверить доставку на устройстве, отказ в уведомлениях и смену аккаунта;
  Inbox остаётся источником обращения при недоставленном push.

**Проверки и приёмка**

- [ ] Валидное обращение с public page появляется в mobile/web Inbox;
  validation, anti-spam и rate limiting проверены до публичного открытия формы.
- [ ] Обращение читает только владелец; отказ постороннему подтверждён
  проверками доступа.
- [ ] FCM доставлен на устройство, переход открывает обращение;
  отказ в notifications и смена аккаунта проверены, без push обращение остаётся в Inbox.

**Готово, когда:** обращение с public page появляется в обоих кабинетах,
владелец получает mobile notification, посторонний не читает Inbox. Это не чат;
browser push автоматически в scope не добавляется.

### Phase 15 — Developer Card и native sharing

**Задачи**

- [ ] Создать карточку с avatar, name, role, technologies, username, logo и public URL.
  Источник — выбранное опубликованное Portfolio, с его title/role/выбранным содержимым.
- [ ] Добавить QR-код этого permanent public URL; для Copy/Open/Share поддержать
  выбранное Resume или Portfolio, draft/unpublished/unknown обработать отдельно.
- [ ] Реализовать собственный MethodChannel → Android/Kotlin → `Intent.ACTION_SEND`.
  Поведение sharing для iOS определить и проверить отдельно.

**Проверки и приёмка**

- [ ] Developer Card содержит avatar, name, role, technologies, username,
  logo и корректный public URL; unpublished состояние обработано.
- [ ] QR открывает выбранное опубликованное Portfolio; rename и republish не
  ломают ссылку, дубликат не использует public ID исходника.
- [ ] Собственный Kotlin MethodChannel и Android share sheet передают ссылку
  на реальном устройстве; результат проверки iOS sharing указан отдельно.

**Готово, когда:** QR открывает public portfolio, native Android share sheet
передаёт корректную ссылку, Platform Channel работает на реальном устройстве.

### Phase 16 — Performance

**Задачи**

- [ ] Проверить большие списки, pagination, изображения, rebuilds, memory и frames
  в Flutter DevTools: mixed Home, обе document libraries, project attachments,
  wizard/base review и media; учитывать реальные limits private aggregate.
- [ ] Сохранить исходные измерения и screenshots, исправить обнаруженные проблемы
  и повторить тот же сценарий на том же устройстве.
- [ ] Проверить public web/editor после появления реальных данных и изображений.

**Проверки и приёмка**

- [ ] Большие списки, pagination, изображения, rebuilds, memory и frames
  измерены в Flutter DevTools на указанном устройстве.
- [ ] Сохранены сопоставимые measurements/screenshots до и после;
  один сценарий повторён на том же устройстве, каждая оптимизация объяснена.
- [ ] Public web/editor проверены с реальными данными и изображениями;
  ненужные микрооптимизации не добавлены.

**Готово, когда:** есть сопоставимые результаты до/после и объяснение каждой
оптимизации. Микрооптимизация без измеренной проблемы не требуется.

### Phase 17 — Testing

**Задачи**

- [ ] Довести unit tests repositories, validation, completion, sync и suggestions;
  widget tests auth, project card, builder и loading/error/empty states.
- [ ] Добавить integration journeys: общая база → Library → два разных Resume →
  Portfolio с выбранными projects/Resume → preview → scoped Save → Publish → public URL.
  Проверить base review, duplicate/rename, Unpublish/delete, offline/reconnect
  и private/public границу в обоих клиентах.
- [ ] Получить `flutter test --coverage` с coverage **более 40%**, clean analyze
  и отчёт о покрытии. Проверить web auth guards, публикацию и обмен draft с mobile.

**Проверки и приёмка**

- [ ] Unit и widget tests для repositories, validation, completion, sync,
  suggestions, auth, project card, builder и UI states проходят.
- [ ] Journeys подтверждают независимость документов, сохранность Library и
  local overrides, постоянство URL и явную публикацию; offline/reconnect,
  delayed retries/UID transitions и private/public граница проверены.
- [ ] Coverage по flutter test --coverage превышает 40%, analyze чистый;
  отчёт сохранён, web auth guards, publication и обмен draft с mobile проверены.

**Готово, когда:** tests проходят, coverage превышает учебный порог, сквозной
сценарий подтверждён. Tests предыдущих фаз сохраняются и дополняются.

### Phase 18 — CI/CD

**Задачи**

- [ ] Добавить GitHub Actions для каждого push/PR: dependency resolution, format check,
  analyze, tests с coverage, APK build и сохранение artifact.
- [ ] Настроить проверку порога coverage, воспроизводимое окружение и отдельные
  проверки web по его реальным configs. Добавить Rules/Storage, общие JSON fixtures,
  private migration/public projection и Figma source asset integrity checks.
- [ ] Проверить, что ошибка проверки делает pipeline неуспешным; signing secrets
  не хранить в коде. Release AAB подключить на фазе выпуска.

**Проверки и приёмка**

- [ ] Pipeline запускается на push/PR, проходит dependency resolution,
  format, analyze, tests, coverage и APK build; artifact доступен.
- [ ] Ошибка format/analyze/tests или недостаточное coverage делает
  pipeline неуспешным; негативный сценарий проверен.
- [ ] Окружение воспроизводимо, web checks соответствуют реальным configs;
  signing secrets отсутствуют в коде, release AAB остаётся задачей выпуска.

**Готово, когда:** pipeline проходит на рабочей версии, APK artifact доступен,
нарушение format/analyze/tests/coverage блокирует успешный результат.

### Phase 19 — Production hardening

**Задачи**

- [ ] Подключить Crashlytics и подтвердить доставку тестового отчёта; настроить
  безопасное error logging без private данных.
- [ ] Провести audit Firestore/Storage Rules и public/private границ, проверить
  nested projection/media, стабильные public IDs, unknown outcomes, поздние retry,
  account deletion/withdrawal, permission descriptions и обработку сбоев.
- [ ] Завершить onboarding, loading/error/empty UX, app icon, splash, versioning
  и privacy policy; проверить оба мобильных targets и responsive web.

**Проверки и приёмка**

- [ ] Тестовый Crashlytics report доставлен; error logging не содержит
  private данных.
- [ ] Firestore/Storage Rules, validation, account deletion, permission
  descriptions и обработка сбоев проверены; значимые дефекты устранены.
- [ ] Onboarding, loading/error/empty UX, icon, splash, versioning и privacy
  policy готовы; Android, iOS и responsive web проверены.

**Готово, когда:** диагностический отчёт доставлен, значимые security/UX дефекты
устранены, разрешения и работа с данными объяснены пользователю.

### Phase 20 — Release

**Задачи**

- [ ] Утвердить application IDs и signing configuration, создать и безопасно хранить
  Android keystore; собрать подписанный release AAB с obfuscation и сохранить symbols.
- [ ] Проверить release на устройстве, подготовить screenshots, описание и privacy policy.
  Материалы отражают четыре вкладки и base→multiple Resume/Portfolio, а не старый
  singleton dashboard; критические сценарии проверены на release build.
- [ ] Подготовить Google Play internal testing; при отсутствии developer account —
  подписанный AAB и пакет материалов, раздачу через Firebase App Distribution.
- [ ] Опубликовать реальные download links после появления релиза; отдельно описать
  шаги iOS/App Store и подготовить демонстрацию проекта.

**Проверки и приёмка**

- [ ] Подписанный Android release AAB с obfuscation собран и проверен
  на устройстве; signing configuration, keystore и symbols хранятся безопасно.
- [ ] Screenshots, описание, privacy policy и демонстрация готовы;
  Google Play internal testing либо пакет AAB/App Distribution подготовлен.
- [ ] Выполнен только разрешённый пользователем способ распространения;
  download links ведут к реальному release.
- [ ] Шаги iOS/App Store описаны отдельно; Android release не выдаётся
  за выполненную iOS-публикацию.

**Готово, когда:** подписанный Android release проверен, материалы для магазина
готовы, выполнен разрешённый способ распространения. Загрузка в Google Play,
App Distribution или deploy web требует запроса пользователя; iOS-публикация
не заявляется выполненной по одному Android release.

**История Phase 0–6/8–10 и результаты Phase 11/12 сохранены; открытые native/live
сценарии остаются открытыми. Действующий режим — mobile capabilities при паузе
последовательной очереди. Web/publication/release readiness не подтверждены.**

---

## Учебные требования и сдача

Учебное задание задаёт **16 недель**, продуктовый план — **21 фазу (0–20)**.
Это разные единицы: таблица сопоставляет темы и результаты, не назначает
фазе длительность в одну неделю. Все обязательные компоненты курса включены
в задачи выше; готовность подтверждается работой приложения и проверками.

<div align="center">

| **Неделя курса** | **Фазы и подтверждение результата** |
|:---|:---|
| 1 — Flutter/Dart | Phase 0: окружение и Hello World; Dart-задачи на null safety, classes, collections, async/await; постановка задачи, аудитория, список экранов и сравнение 2–3 аналогов. |
| 2 — Widgets/UI | Phase 1: эскизы и статические экраны, Stateless/Stateful widgets, Material 3. |
| 3 — Basic state | Phase 2: один сценарий setState → InheritedWidget → Provider и сравнительная заметка. |
| 4 — Advanced state/architecture | Phases 2–3: Riverpod, presentation/domain/data, Repository, DI и обоснование выбора. |
| 5 — REST/JSON | Phase 4: GitHub API, serialization, states, timeout/retry, refresh и debounce. |
| 6 — Persistence | Phase 5: настройки, кэш и доступ без сети; локальный Builder развивается на Phase 6. |
| 7 — Navigation/adaptive UI | Phases 1 и 7: routes/parameters/nested navigation, auth redirect после подключения auth, телефон/планшет и обе ориентации. |
| 8 — Firebase/РК1 | Phases 7–8 и 14: email/Google, Firestore, Rules, FCM на устройстве; материалы текущих заданий недель 1–7. |
| 9 — Location | Phase 12: ручной город/страна, опциональная геопозиция, подтверждение и отказ в permissions; карта исключена по решению владельца проекта 2026-10-07. |
| 10 — Performance | Phase 16 и предыдущие API/media фазы: lazy lists, pagination, image cache, DevTools screenshots до/после. |
| 11 — Native | Phases 11 и 15: camera/gallery и собственный Kotlin MethodChannel на устройстве. |
| 12 — CI/CD | Phase 18: зелёный pipeline, build/analyze/tests на push и APK artifact. |
| 13 — Tests | Phase 17: unit/widget/integration tests, coverage >40%, отчёт и запуск в CI. |
| 14 — Publication | Phases 19–20: Crashlytics, signed AAB, store materials/internal testing либо App Distribution; описание iOS-публикации. |
| 15 — Presentation/РК2 | Демонстрация 7–10 минут: сценарий, архитектура, tests и profiling; материалы заданий недель 8–15. |
| 16 — Exam | Индивидуальная защита: работа приложения, разбор кода/архитектуры и способность объяснить и воспроизвести выбранный фрагмент. |

</div>

**Календарное расхождение:** курс требует FCM уже на неделе 8, карты — на 9,
CI — на 12; текущий продуктовый roadmap вводит их на Phases 14, 12 и 18.
Web-редактор добавляет работу сверх обязательного учебного объёма. Если недельные сроки обязательны,
до начала следующих фаз нужен отдельно согласованный учебный график: он должен
перенести учебные milestones раньше и выделить дополнительные функции продукта.
Следование текущей последовательности само по себе не гарантирует сдачу по неделям.

Для учебной подготовки дополнительно:

- Подтвердить у преподавателя закрепление темы Developer Portfolio; менять тему
  только по согласованию. Текущая документация не подтверждает административное согласование.
- Подготовить Dart-упражнения и сравнение 2–3 аналогов. В публичном README
  оставить краткое обоснование state management со ссылкой на подробное решение;
  требования/MVP и план остаются в product spec по правилам проекта.
- Сохранять доказательства по мере работы: эскизы, результаты запусков, отчёт
  coverage, DevTools до/после, CI artifact, Crashlytics report и release materials.
- После разрешённых commits использовать историю изменений для объяснения этапов.
  На защите уметь самостоятельно объяснить код, ограничения и принятые решения.
