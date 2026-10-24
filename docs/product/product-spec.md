<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../../apps/web/public/branding/stackcard-v2-mark-paper.svg">
  <img src="../../apps/web/public/branding/stackcard-v2-mark-ink.svg" width="64" height="64" alt="Логотип StackCard — Brand A">
</picture>

# StackCard Product

**Мобильный и web-конструктор developer-портфолио с контролируемой публикацией**

![Stage local transfer verified](https://img.shields.io/badge/Stage-local_transfer_verified-111111?style=for-the-badge)
![Mobile + Web source](https://img.shields.io/badge/Mobile_%2B_Web-source-111111?style=for-the-badge)

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

**2026-10-24: дополнительный аудит Flutter coverage завершён по запросу пользователя.**
Проверены все32 файла вне LCOV:17 constant translation catalogs,9 export-only
barrels,4 abstract repository contracts,1 constant token file и1 неиспользуемый
legacy `DeveloperProfileScreen`. Последний не импортируется/не открывается runtime;
старые settings/profile/contact URL переводятся в main Editor, что проверяется
existing navigation tests. Файлы не исключались из checker и не удалялись ради метрики.
Добавлены13 регрессий: ошибки scoped Save/read и CAS, owner transition во время
Save/journal/inventory/exit confirmation, отказ очистки publication journal и
status recovery без повторного POST, чужие ACK IDs и Delete без tombstone.
Focused63 и полный1399 tests PASS, analyze/format PASS. LCOV13495/15530 =86,90%
(было13492/15530 =86,88%); runtime source hash, denominator и список32 unreported
не изменились. [Пофайловый аудит и результаты](evidence/phase19/coverage-audit.json).
Runtime/dependencies/CI threshold не менялись; native/live suites повторно не запускались.

**2026-10-24: Phase19 — Production hardening завершена.** Бесплатная opt-in
диагностика доставлена и проверена в Android/iOS Crashlytics Console: фиксированный
код, очищенный stack, без app UID/contact/token/private content. Исправлены HTTP
граница, видимость Copy feedback и iOS symbols delivery; обновлены privacy/help
и Next16.4.3 с production audit0. По требованию пользователя установлен Xcode27.1:
обычный iOS Simulator build, SDK journey11 checkpoints в двух процессах и native
UI smoke PASS на iOS27.0. Android build/SDK/UI и responsive web PASS.
Пользователь отдельно разрешил iOS dSYM upload/автозагрузку; matching symbols
приняты Console, foreground upload failure завершает build ошибкой.
Phase20/hosting/billing/Git этим переходом не запускаются; прежние физические,
system/live/profile/Figma/release gates сохраняются отдельно.

**2026-10-23: Phase 18 — CI/CD завершена и проверена на GitHub.** Пользователь попросил проверить
остановку продукта и продолжить следующий этап. Phase17 source/local и Android
проверки сохранены; iOS отложен. Незакрытые Phase15 QR/system/live и Phase16
profile gates не считаются выполненными. Разрешены GitHub Actions checks,
coverage и debug APK artifacts; Phase19–20/deploy/billing не запускаются.
Последующий запрос 2026-10-23 явно разрешает commit/push в dev, проверку
GitHub Actions и завершение Phase18. Отдельная проверочная ветка содержит
негативный coverage-сценарий; Phase19 автоматически не начинается.

**2026-10-21: разрешена Phase 17 — Testing.** После source/local результатов
Phase 15–16 пользователь явно разрешил следующий этап по обновлённому плану.
ADR 0005, одно основное портфолио, «Главная / Проекты / Редактор», светлый русский
UI, Manrope и Brand A сохраняются. Незакрытые native/live/iOS проверки Phase 15
и native DevTools gate Phase 16 остаются отдельно в своих разделах.
Phase 18–20, commit/push/deploy и billing этим переходом не запускаются.
Постоянный hosting Contact/Inbox/FCM остаётся отложенным.
Продолжение «доделай незаконченное»: source/local и Android SDK/controller/Card
journey проверены; iOS 2026-10-21 явно оставлен отдельно по ответу пользователя.

**2026-10-12: функциональный редизайн одного основного портфолио** разрешён
прямым заданием пользователя. [ADR 0005](../decisions/0005-single-main-portfolio.md)
заменяет повседневный сценарий общей базы/независимых Resume/Portfolio:
три раздела «Главная / Проекты / Редактор», сохранённое портфолио на главной,
настоящий PDF, явная публикация, компактная Library и выборочный пакетный импорт
из одного GitHub-профиля. Все персональные поля необязательны; пустой Save допустим.
Новый аккаунт проходит четыре пропускаемых шага с устойчивым UID-bound progress.
Единственное пользовательское изображение — avatar через бесплатный Firestore;
город/страна вводятся вручную, GPS packages и permissions удалены.

Перенос выбирает прежнюю основу явно и сохраняет неизменяемую копию. Старые
документы, Library overrides и постоянные опубликованные URL не удаляются;
Save/импорт/перенос не публикуют автоматически. Hive8/cloud7 и public schema2
читают прежние версии. На дату этой реализации Phase15 ещё не была запрошена;
её разрешение 2026-10-21 указано выше. Deploy, billing и commit/push не запрошены.
Результаты этой реализации фиксируются ниже отдельно от старых gates и live hosting.

**2026-10-11: светлый web и mobile redesign** по прямому поручению адаптировать
[Openship](https://openship.io/) под StackCard, удалить dark и добавить страницы.
[Web brief](../redesign/web-openship.md) фиксирует композицию, русские тексты,
новые `/features`, `/use-cases`, `/examples`, `/help`, `/about` и обновлённый
`/download`. White-only охватывает Auth, кабинет, preview и public reader.
Совместимая mobile/cloud тема старых документов сохраняется без миграции при
чтении. Пользователь одобрил web и поручил перенести этот дизайн в Flutter:
только светлая тема, русский интерфейс и собственный контент StackCard.
Работа сохраняет совместимые legacy preferences/документы и ранее принятые
изменения горизонтального аккаунта из параллельного чата.
Это работа внутри существующего mobile/web UI scope; Phase15, deploy и выпуск не начаты.

**2026-10-09: переход к Phase14 разрешён** прямым поручением «переходи к следующей
фазе разработки». Активная разработка — ContactRequest/Contact me, private Inbox
в mobile/web и mobile FCM по [ADR0004](../decisions/0004-contact-inbox-notifications.md).
Переход не закрывает открытые Phase13/live/iOS/Figma проверки. Следующие фазы,
commit/push/deploy/billing этим поручением автоматически не разрешаются.

**2026-10-10: продолжена незавершённая Phase14.** Исправлены потеря retry
серверной очистки FCM registration и поздний token-refresh register при смене UID.
Android SDK permission mapping проверен на локальном эмуляторе. Последующее
поручение разрешило live Firebase/deploy/FCM проверки; затем пользователь потребовал
сохранять бесплатный Spark и использовать бесплатные открытые аналоги. Backend
перенесён в обычный Node без Cloud Functions/App Hosting; платный TTL отключён.
Android live Contact/FCM acceptance — **5/5 PASS**, включая настоящий tray tap
и cold start. Пользователь затем отложил постоянный запуск: hosting отсутствует,
функцию сохранить для будущего подключения с требованиями в env examples.
Временные endpoints очищены; iOS/APNs и production readiness не подтверждены.
[Результаты](#phase-14--contact--inbox--fcm) не запускают Phase15.

**2026-10-08, D048:** поручение «закончи перенос» и явный ответ «Также реализовать
web и публикацию» разрешают завершение mobile-сценариев, actual Next.js web и
публикацию независимых Resume/Portfolio. Запрошенная реализация D048 выполнена
и локально проверена: mobile, trusted publication и web работают в текущем
source. Headless/emulator/browser/Android evidence ниже отделён от release,
full device/Figma acceptance и live availability. Deploy/billing/
commit/push не запрошены. Последующий явный ответ «Да, выполнить визуальную
проверку web/mobile» разрешает D048 preview/browser/native checks; результаты
и ограничения среды записываются отдельно.
R7 awaiting_review, DESIGN_READY/REDESIGN_DONE и пользовательская приёмка открыты.

**2026-10-09: продолжение незавершённого D048 / Phase 13b–13c.** Проверка текущего
`dev` подтвердила историческую остановку после Phase 10 и позднейшие реализации
Media/Location/mobile/web/publication. Продолжена проверка уже разрешённого scope:
web Save сохраняет поздний ввод и повторяет прежнюю операцию после потерянного
ACK; public metadata и unavailable states исправлены. Двусторонний cloud6
контракт web→Dart→web подтверждён. Последующее продолжение исправляет captured
base review/атомарный выбор фото и выход из аккаунта во время получения token;
[отдельные результаты](#проверки-base-review-и-uid--2026-10-09) не заменяют live приёмку.
Результаты предыдущего продолжения — [ниже](#проверки-продолжения-phase-13--2026-10-09);
вся Phase 13 и native/live/Figma приёмка остаются открытыми.

**2026-10-07: последовательная разработка по фазам поставлена на паузу**
по прямому поручению пользователя. Действующая работа — развитие mobile по Figma
и концепции «общая профессиональная база → несколько резюме и портфолио»:
новая навигация, библиотеки документов, редакторы, общая Library и связи.
Это разрешение функциональной разработки; история фаз и незакрытые проверки
сохраняются. Карта и Google Maps по прежнему решению исключены.

**Исторический private mobile scope D048 (заменён ADR0005):**

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

**Исторический D048 publication/web baseline:** authenticated HTTP
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

**Открытая приёмка прежних фаз:** полная Figma parity, полный password reset,
iOS/APNs и live media. Прежний GPS scope удалён ADR0005; результаты текущих
visual/native проверок фиксируются отдельно. Android Google-вход и
восстановление сессии приняты 2026-10-11; Android live Contact/FCM — 5/5 PASS
по Phase 14. Постоянные HTTPS Node API и web hosting отложены; временный запуск
не доказывает production availability. Cloud Functions/App Hosting/billing не
включены. QR/Developer Card и store release остаются в плане. Новые результаты tests
не закрывают эти gates. Production публикации пользователя этим запуском не создаются.

Наличие кода не подтверждает проверку нового сценария. Итоговые проверки этой
работы фиксируются здесь по фактам; прежние 950/1068 PASS относятся к своим
историческим версиям и не доказывают новую document модель.

### Продолжение единого портфолио — 2026-10-21

Актуальная остановка — завершённая локальная реализация ADR 0005 и последующие
правки редактора/порядка секций. Продолжена проверка разрешённого mobile/web
scope; Phase 15 и постоянный hosting остаются отдельными задачами.

Исправлен retry web GitHub Import: после ошибки обновления кешированного списка
повторяются исходные page/replace, а не следующая страница по длине кеша.
До восстановления запроса пагинация заблокирована; успешное обновление заменяет
старый список. Ошибка scoped сохранения выбранных проектов сохраняет выбор
и больше не предлагает постороннее действие «Повторить загрузку».

Изолированный browser harness воспроизвёл ошибку до правки: запросы **[1, 2]**
вместо **[1, 1]**. После правки — PASS: повтор refresh, сохранность кеша/выбора,
замена кеша после успеха и retry пагинации **[1, 1, 2, 2]** без дублей.
GitHub HTTP и ошибка сохранения подменены; реальные аккаунты/workspace не менялись.
Стенд: `/private/tmp/stackcard-github-retry/check.cjs`, результат — `verified.log`
в той же папке. Это отдельная browser-проверка, не часть `npm test`.

Текущие полные проверки: Flutter — **1344/1344 PASS**, analyze — **0 issues**;
web — **163/163 PASS**, typecheck, production build, формат изменённого TSX
и `git diff --check` — PASS. Логи — `/private/tmp/stackcard-resume-mobile-tests.log`,
`stackcard-resume-web-final-tests.log`, `stackcard-resume-web-build.log`.
Новых native/live/iOS проверок, commit/push и deploy нет; прежние открытые gates
сохраняются.

### Проверки единого портфолио — 2026-10-12

Реализация [ADR 0005](../decisions/0005-single-main-portfolio.md) проверена из
активного checkout на macOS zsh. Прежние результаты ниже относятся к своим версиям.

| Проверка | Фактический результат |
| --- | --- |
| Полный Flutter suite | `flutter test --no-pub --reporter expanded` — **1295/1295 PASS** после последних GitHub CAS и legacy avatar/PDF исправлений. Миграция/точный backup, Hive8/cloud7, Dart↔web, пустое Save, privacy, scoped imports/delete, UID/late ACK, сохранённая Home и явная публикация покрыты regressions. |
| Анализ / формат | `flutter analyze --no-pub` — **0 issues**. Формат 110 затронутых Dart файлов — **0 changes**; `git diff --check` — PASS. |
| Web | Typecheck, **142/142 tests**, форматирование и финальный production build — PASS. QA routes удалены; обычные 15 routes сохранены. Новая password policy/visibility согласована с mobile. |
| Backend / Rules | Node syntax check и **42/42 unit tests** — PASS; `npm run test:all-rules` — **81/81 PASS** на demo Auth/Firestore/Storage. Проверены cloud7/cap21, public1/2, owner-only avatar и запрет новых Storage uploads. Это локальные эмуляторы, не deploy. |
| PDF | Настоящие Manrope/Cyrillic PDF: mobile long fixture — 7 страниц, web — 6; повторённый длинный текст полностью сохранён, в каждом 1 avatar и 16 URI links, private/empty sections исключены. URL-only legacy avatar проходит bounded client reader и JPEG preprocessing; image embed, timeout/size/MIME/UID failures проверены тестами. |
| Android PDF / media | На emulator-5554 системный SAF Save и Cancel — PASS. Сохранённый PDF: 30 858 bytes, 3 страницы, кириллица, 1 image и 15 URI links; SHA-256 совпал с original. Named demo SDK avatar upload/read/server persistence/repository reopen и ownership/lifecycle denials — PASS. Тестовые данные удалены. |
| Настоящий web SDK | В локальном demo Auth/Firestore проверены регистрация, Skip/Back/resume/completion, пустое Save, проект/attachment/icon после reload и saved Home при dirty Editor. Browser download дал настоящий PDF сохранённой версии без позднего несохранённого текста. Два созданных тестовых аккаунта и drafts удалены. |
| Компоновка / доступность | Width320, keyboard, text scale2, scroll/targets и Tab/Shift-Tab — PASS в widget tests. Убраны лишний заголовок Editor и ловушка focus пустой Home. Actual web owner просмотрен при320/desktop/text2; последняя обычная Android APK установлена без uninstall, просмотрены Auth, read-only Home с тремя вкладками и Settings. Legacy основу не выбирали и реальные drafts не изменяли. |
| Документы / assets | Product/architecture/design/AI scopes и setup согласованы. Local docs links/format — PASS; `check_imports.py --require-brand --require-imported` — PASS. Android APK оставлена с обычным `lib/main.dart`; временные web servers/Firebase emulators остановлены, QA tabs закрыты. |

Правка поиска 2026-10-12: кнопка «Очистить поиск» убрана из пустого результата
Projects; очистка текста в поле возвращает список. Обновлены существующие
widget/state/DI проверки. Widget и state suites — **11/11 PASS**; анализ пяти
затронутых Dart-файлов и формат — PASS. Общий запуск трёх suites — **14 PASS,
2 FAIL** из-за уже изменённых ожиданий подписей «Импортировать»/«Создать» в
`projects_di_test.dart`; общий анализ нашёл два замечания в параллельных правках
main/project editors. Эти посторонние изменения сохранены.
Следующее поручение сократило подписи кнопок Projects до «Импортировать» и
«Создать»; повторный `projects_di_test.dart` — **5/5 PASS**, формат двух
изменённых Dart-файлов и `git diff --check` — PASS.

Правка mobile персонализации 2026-10-12: корректная ссылка
`https://github.com/LINESKL` уже принималась parser, но старая ошибка формы
оставалась после исправления ввода. Autovalidation обновляет её при редактировании;
поле называется «GitHub-профиль». «Назад»/«Далее» стоят рядом, первый Back
отключён, последний Next — «Готово». Отдельная «Пропустить» удалена вместе
с неиспользуемыми ветками; пустые поля проходят через Next. Personalization и
main portfolio contract suites — **23/23 PASS**, включая stale error regression,
сохранение/возврат/UID и width320/text2/keyboard на всех четырёх шагах. Анализ
трёх Dart-файлов, формат и `git diff --check` — PASS; native визуальная проверка
этой правки не выполнялась.

Перенос города/страны 2026-10-12: в mobile персонализации поле находится под
должностью на втором шаге, а третий шаг содержит только «О себе». Сохранение
локации выполняется со вторым шагом; прежняя privacy неизменённого города
сохраняется. Personalization suite — **13/13 PASS**, включая Next/Back, resume
и width320/text2/keyboard; анализ двух Dart-файлов — **0 issues**, формат и
`git diff --check` — PASS.

Кнопка «Скачать портфолио» 2026-10-12: убран индикатор загрузки в mobile,
размеры кнопки и положение надписи не меняются при подготовке PDF. Повторное
нажатие остаётся заблокированным. Существующий Home suite — **15/15 PASS**,
включая проверку геометрии при незавершённом скачивании; анализ двух изменённых
Dart-файлов — **0 issues**, формат и `git diff --check` — PASS.

Кнопки mobile Home/Projects 2026-10-12: «Импортировать»/«Создать» заполняют
ширину контейнера той же адаптивной компоновкой, что Home; «Поделиться»
получила чёрную заливку primary. Существующие Projects DI и Home suites —
**21/21 PASS**, анализ двух изменённых экранов — **0 issues**, формат и
`git diff --check` — PASS.

Исправление mobile Home 2026-10-12: подготовка и сохранение PDF больше не
отключают «Поделиться»; кнопка сохраняет чёрный фон и отправляет подтверждённую
ссылку. Повторное скачивание заблокировано до завершения операции.
Home/shared button suites — **92/92 PASS**, включая новый regression;
анализ двух Dart-файлов — **0 issues**, формат и `git diff --check` — PASS.
На устройстве этот сценарий отдельно не проверялся.

Карточка mobile Projects 2026-10-12: удаление перенесено в красный минус справа
сверху, «Редактировать» — вправо вниз с чёрной обводкой через shared outlined role.
Диалог «Удалить проект?» предлагает «Отмена»/«Подтвердить»; отмена сохраняет
Library и связи, смена owner во время диалога не удаляет данные.
Parity/GitHub widget/shared button suites — **88/88 PASS**, включая геометрию,
width320/text2, контраст/focus и подтверждение/отмену. Анализ пяти затронутых
Dart-файлов, формат и `git diff --check` — PASS; общий анализ обнаружил unrelated
`use_null_aware_elements` в main editor. Headless preview Projects просмотрен;
проверка этой карточки на native device не выполнялась.

Уточнение карточки Projects 2026-10-12: красный минус заменён крестиком,
как в редакторе тегов; «Редактировать» занимает всю внутреннюю ширину карточки.
Existing parity/GitHub widget suites — **16/16 PASS**, включая ширину кнопки,
width320/text2 и подтверждение удаления; анализ двух Dart-файлов — **0 issues**,
формат и `git diff --check` — PASS. Native-проверка отдельно не выполнялась.

Контакты mobile 2026-10-12: редактор использует ту же секцию тегов, что навыки,
с «+», редактированием по названию и крестиком удаления. Добавление —
«Отмена» слева / «Сохранить» справа; одинаково для добавления и изменения контакта.
Home показывает категорию с её иконкой и пользовательское название-ссылку,
без raw URL; приватность и существующий typed URL validation сохранены.
Добавлены семь монохромных pinned Lucide/Feather SVG с exact hashes/лицензиями.
Home/editor/SVG/mobile parity suites — **59/59 PASS**, анализ десяти Dart-файлов
— **0 issues**, формат восьми файлов, asset checker и `git diff --check` — PASS.
Лог: `/private/tmp/stackcard-contact-ui-tests.log`. Проверки локальные,
без изменения реальных пользовательских данных и нового live/device acceptance.
Просмотрены headless снимки `/private/tmp/stackcard-home-contacts.png` и
`/private/tmp/stackcard-home-contacts-narrow.png`: категории с иконками и
подчёркнутые пользовательские названия, адаптивные колонки и перенос text2.

Единые действия mobile/web 2026-10-12: группы форм и диалогов выровнены вправо,
«Отмена» слева с обводкой, основное действие справа с заливкой. Формы используют
«Сохранить», подтверждения — «Подтвердить», просмотр — «Закрыть», последний
шаг персонализации теперь «Завершить». Shared mobile footer и web confirmation
dialog сохраняют порядок при переносе; Escape отменяет web confirmation,
фокус возвращается к источнику. Системное предупреждение закрытия вкладки
управляется браузером. Полный Flutter suite — **1317/1317 PASS**, анализ —
**0 issues**; web — **152/152 PASS**, typecheck и production build — PASS.
Геометрия/keyboard/text2 проверены widget tests; headless снимок формы контакта
просмотрен. Web components/styles проверены в browser harness при1280/320px,
включая Tab/Shift-Tab, Escape и возврат focus; это не новый native/live acceptance.
Логи: `/private/tmp/stackcard-dialog-actions-verified-tests.log` и
`/private/tmp/stackcard-dialog-actions-final-analyze.log`.

Порядок mobile Home/Editor 2026-10-12: после профиля идут контакты, навыки,
реализованные проекты, опыт работы и образование. Секция проектов в Editor
использует общую outlined карточку с «+»; удержание точек слева перед иконкой
переставляет проекты, крестик справа снимает связь, сохраняя Library.
Общий Save сохраняет порядок и удаление; Home читает durable snapshot.
При узком viewport/крупном тексте название проекта переносится под controls.
Home/Editor widget suites — **53/53 PASS**, `flutter analyze --no-pub` —
**0 issues**, format и `git diff --check` — PASS. Проверен actual gesture,
сохранение порядка, privacy и320px/text2/keyboard; headless снимок
`/private/tmp/stackcard-main-project-order-narrow.png` просмотрен.
Лог: `/private/tmp/stackcard-project-order-tests.log`; это локальные проверки,
без новой native/live приёмки.

Управляемый порядок разделов 2026-10-12 отменён пользователем 2026-10-21:
точки у заголовков mobile Editor и перестановка разделов удалены. Записи
(контакты, навыки, проекты, опыт, образование) переставляются только внутри
своего раздела. Ранее сохранённый порядок в `document.content.blocks` по-прежнему
читается; Home, web outputs и PDF его учитывают. Профиль остаётся первым, GitHub следует рядом с контактами.
Технологии внутри редактора проекта переставляются отдельно за точки слева;
единый sliver scroll позволяет переносить элемент до конца длинного списка.
Общий Save портфолио и scoped Save проекта сохраняют соответствующие изменения;
ошибка записи сохраняет buffer для retry, смена owner исключает late results.
Полный mobile suite — **1344/1344 PASS**, полный analyze — **0 issues**;
последняя правка порядка blocks дополнительно проверена Home/Editor suite
**55/55 PASS** и targeted analyze. Web — **163/163 PASS**, typecheck и
production build — PASS. Actual held drag вверх/вниз, автопрокрутка раздела,
перенос первой технологии на последнее место из20, Save/reopen/Hive и privacy
проверены локально. Просмотрены narrow/text2 headless снимки
`/private/tmp/stackcard-main-skill-tags.png` и
`/private/tmp/stackcard-project-technologies-narrow.png`.
Логи: `/private/tmp/stackcard-section-reorder-full-tests.log`,
`/private/tmp/stackcard-sections-editor-final.log`,
`/private/tmp/stackcard-section-web-tests.log`; новой native/live приёмки нет.

GitHub в редакторе 2026-10-12: дублирующий раздел профиля удалён в mobile и web;
он остаётся в Settings и персонализации. Main Save не записывает GitHub identity,
поэтому сохранённое изменение настроек не откатывается соседним вводом редактора.
Mobile editor/contract/settings suites — **43/43 PASS**, анализ двух Dart-файлов
— **0 issues**; web — **154/154 PASS**, typecheck и production build — PASS.
Проверены отсутствие поля, сохранность root identity при scoped Settings Save,
dirty buffer и смене owner. Логи mobile:
`/private/tmp/stackcard-editor-github-removal-tests.log`,
`/private/tmp/stackcard-editor-github-removal-analyze.log`.
Проверки локальные, без нового native/live acceptance.

Ссылки проектов 2026-10-12: saved mobile портфолио и web preview/public reader
показывают два независимых действия под полным описанием — «Репозиторий»
с `github` и «Продукт» с `globe`. Пустая ссылка скрывает только своё действие;
без обеих ссылок нет строки действий. Название и описание больше не открывают
одну выбранную ссылку, ограничение mobile описания в три строки удалено.
Existing Home suite — **30/30 PASS**, анализ двух затронутых Dart-файлов —
**0 issues**; web — **154/154 PASS**, typecheck, format и production build — PASS.
Проверены правильные назначения ссылок, отсутствие пустых controls, keyboard,
targets48 и width320/text2. Mobile headless и web browser снимки просмотрены;
original SVG/Feather license перенесены из mobile в web с pinned hashes.
Это локальные UI проверки, без нового native/live acceptance.
Логи: `/private/tmp/stackcard-project-links-preview-tests.log` и
`/private/tmp/stackcard-project-links-analyze.log`.

Цвет крестика mobile Library 2026-10-12: удаление использует чёрный `textPrimary`,
как остальные крестики интерфейса. Existing mobile parity suite — **6/6 PASS**,
анализ двух Dart-файлов — **0 issues**, формат и `git diff --check` — PASS.

Аудит остальных экранов 2026-10-12: Import mobile/web больше не дублирует
форму GitHub-профиля и ведёт в Settings; после возврата источник перечитывается.
В mobile Inbox/Import ошибка содержит одно действие повторения; Notifications
показывает включение либо отключение по состоянию, с отдельным retry cleanup
только при незавершённой очистке. Повторный переход во «Входящие» убран.
В web public reader удалены self-open и Share без Web Share API; Download
сохраняет статус релизов без неработающих кнопок. Footer/demo используют
канонические разделы вместо нескольких aliases в один Editor.
Целевые mobile suites — **49/49 PASS**, анализ семи файлов — **0 issues**;
web screen actions — **5/5 PASS**, typecheck, production build и формат — PASS.
Общий snapshot Flutter — **1324 PASS, 8 FAIL** в параллельно изменённом
виртуализированном Main Editor; общий анализ — один deprecated `cacheExtent`
в том же редакторе. Web общий snapshot — **161 PASS, 1 FAIL** в параллельном
`public-document.test.ts` (schema2 fixture возвращает null). Эти исходники
не менялись ради обхода проверок. CUA вернул пустой список браузеров, поэтому
runtime Copy/Share не подтверждён; временный harness остановлен и удалён.
Логи mobile: `/private/tmp/stackcard_mobile_duplicates_final_tests.log`,
`/private/tmp/stackcard-screen-dedup-final-tests.log`,
`/private/tmp/stackcard-screen-dedup-final-analyze.log`.

Повторная проверка редактора и public reader 2026-10-12 закрыла указанные выше
падения. В project editor состояния загрузки, ошибки, смены owner и удалённого
проекта прокручиваются отдельно от рабочего sliver списка; четыре новых
проверки охватывают width320/landscape844×390 с text2. Widget tests прокручивают
lazy списки перед взаимодействием и сохраняют проверки drag/autoscroll,
Save/reopen, UID isolation, accessibility и targets48. Public order fixture
сохраняет `about/location`, когда содержит biography/location; отдельный test
проверяет обе public schemas: скрытые данные отклоняются до очистки полей.
Финальный полный Flutter — **1344/1344 PASS**, analyze — **0 issues**;
web — **163/163 PASS**, typecheck, build и формат — PASS; Firebase demo
Auth/Firestore/Storage — **81/81 PASS**, Functions — **42/42 PASS**, syntax check — PASS.
Формат девяти затронутых Dart-файлов — PASS; общая проверка295 файлов отмечает
четыре неизменённых файла прежнего форматирования вне этой задачи.
Логи: `/private/tmp/stackcard-editor-repair-mobile-final-tests.log`,
`/private/tmp/stackcard-editor-repair-mobile-final-analyze.log`,
`/private/tmp/stackcard-editor-repair-firebase-tests.log`,
`/private/tmp/stackcard-editor-repair-functions-tests.log`; web results receipt —
`/private/tmp/stackcard-web-gate-evidence-20261012/gate-receipt.txt`.
Это локальный automated gate, без новой native/live приёмки.

Основные логи: `/private/tmp/stackcard-single-portfolio-final-verified-tests.log`,
`stackcard-single-portfolio-final-flutter-analyze.log`, `stackcard-web-tests-final.log`,
`stackcard-web-build-final.log`, `stackcard-single-all-rules.log`,
`stackcard-native-pdf.log`, `stackcard-native-avatar.log` и
`stackcard-single-portfolio-final-android-run.log`. Длинные PDF inspection results —
`/private/tmp/stackcard-pdf-fixtures/inspection.json`.

**Незакрытые средовые проверки:** новые Rules/indexes и Node service не deployed;
API URLs/hosting остаются отключёнными, поэтому actual public URL/system Share в
новом live окружении не подтверждены. UI сообщает о недоступности вместо фиктивного
успеха. Native Gallery/Camera permissions и полный process restart с новым avatar
этим gate не проверены; проверен reopen repository. Live CORS внешнего legacy avatar
не подтверждён: IAB стал недоступен; сервер фото должен разрешать browser CORS.
iOS runtime/build/document picker, APNs и новый Google `isNewUser` onboarding на
device не подтверждены; Swift syntax и Info.plist lint — PASS. Xcode/iOS device
недоступны. Эти ограничения не закрывают старые Phase13/14/Figma/release gates.
Blaze/billing, commit, push и deploy не выполнялись.

### Сверка актуальной версии и документации — 2026-10-11

`main` и `dev` локально и на GitHub синхронизированы на `daf6482`; перенос
сохранил точное содержимое последнего `dev` и линейную историю. Последний gate:
Flutter **1242/1242 PASS**, analyze **0 issues**; web typecheck, format и production
build **PASS**, **97/97 tests**; Node handler syntax check и **31/31 tests**;
Git message validator **15/15 tests**, source asset checker **PASS**. Эти проверки
не повторяют emulator Rules, native iOS или live backend acceptance.

Документация использует текущий Brand A и SVG Shields `for-the-badge` с logos
и версиями из canonical источников. Версия Next.js сверена с web manifest
и lockfile, Flutter — с установленным SDK. Бейджи показывают основные технологии:
Flutter, Next.js и Firebase; вложенные Dart, React/TypeScript и tooling не
дублируются в шапке. Developer Card/QR остаются
планом, независимые Resume/Portfolio, общая Library, Inbox и условие подключённого
backend описаны по фактическому runtime. Исторические результаты ниже
сохраняют свою дату и scope.

### Проверки светлого web — 2026-10-11

| Проверка | Результат |
| --- | --- |
| TypeScript / форматирование | `npm run typecheck` и `npm run format:check` — PASS. |
| Контракты | `npm test` — **97/97 PASS**. Старые dark данные читаются без изменения; renderer светлый, создание из базы получает light. ReturnTo принимает только owner paths и разрешённые workspace hashes. |
| Production build | `npm run build` — PASS; 15 маршрутов приложения и служебный `/_not-found`. Финальный preview запущен через `npm run start` локально. |
| Браузер / компоновка | Главная, пять новых страниц, download, примеры документов и Auth просмотрены; ширины 375/390/768/1280/1920, горизонтальная прокрутка на проверенных экранах отсутствует. Desktop hero сопоставлен с Openship при 1280×720. |
| Взаимодействия | Переключение портфолио/резюме, mobile menu, FAQ, якоря помощи и переход к `/workspace#base` через вход — PASS. Keyboard Enter/Tab и видимый focus проверены на demo и меню. Console errors финального preview — 0. |

Desktop и phone screenshots сохранены как артефакты текущей задачи. Команды
подтверждены tool output; отдельные log-файлы не создавались. Авторизованные
live Save/Publish и обмен с mobile в этом пакете повторно не запускались;
web одобрен пользователем. Flutter перенос разрешён отдельным последующим
поручением; его проверки и мобильная оценка фиксируются отдельно.

### Проверки светлого Flutter — 2026-10-11

Перенос одобренного web выполнен в существующих theme/shared widgets/shell и
редакторах. Runtime всегда light/ru; theme/language selectors удалены. Старые
preferences и document theme читаются без миграции, новые документы получают
light. Горизонтальная строка аккаунта и provider metadata из параллельного чата
сохранены; разделение файлов согласовано с разрешения пользователя.

| Проверка | Результат |
| --- | --- |
| Полный Flutter suite | **1242/1242 PASS**, последний прогон после исправления навигации и итоговой APK. Legacy dark/en + OS dark показывают white/ru без записи preferences; schema/UID/Save/Publish regression tests сохранены. |
| Анализ / формат | `flutter analyze --no-pub` — no issues. Formatter 65 затронутых Dart файлов — 0 changes; `git diff --check` — PASS. |
| Адаптивность / доступность | Responsive + Builder preview suite **114/114 PASS**: 7 phone/tablet viewports, text scale 1/2, scroll/overflow, contrast и tap targets. При scale 1 все четыре nav labels остаются одной строкой, включая ширину 320. |
| Визуальная сверка | 32 light PNG обновлены: 24 основных в четырёх phone/tablet ориентациях и 8 Builder. Все просмотрены; последний перенос «Портфолио» исправлен и перепроверен. Manrope/Brand A, белые поверхности, чёрные CTA и русские подписи сохранены. |
| Источники | `check_imports.py --require-imported --require-brand` — PASS: 30/10/19 mappings, исходные SVG/TTF/SHA/licenses. Семь контрольных повреждений временной копии корректно дали FAIL. |
| Android | Итоговый `flutter build apk --debug --no-pub` — PASS; APK установлена через replace на emulator-5554 с сохранением данных. Во время переноса нативно просмотрены Auth, гостевая Home, библиотека резюме и первый шаг нового несохранённого документа. Native Home PNG сохранён в артефактах чата. |

Полная format-проверка дерева выявила четыре прежних отклонения в
`local_draft_accounts.dart`, `portfolio_public_content_codec.dart`,
`location/portfolio_location_persistence_test.dart` и `workspace_controller_test.dart`;
эти файлы совпадают с исходным 511625f и не изменялись в этом UI scope.
Логи локальных проверок — `/private/tmp/stackcard-mobile-light-final-full.log`,
`stackcard-mobile-light-nav-previews.log` и `stackcard-mobile-light-build-final.log`.
iOS runtime, live Auth/Save/Publish/FCM и мобильная пользовательская оценка
остаются отдельными проверками; этот пакет их не закрывает.

### Монохромный бренд и системные иконки — 2026-10-11

По прямому поручению устранён прежний зелёный знак в Android Google account
picker: native AppIcon переведён с Accent на original Brand A MonoDark,
Android label и iOS display/bundle name — StackCard. Exporter читает текущий
[brand kit](../../assets/branding/stackcard-v2-brand-kit.json); 20 PNG Android/iOS
пересозданы без изменения исходных SVG. Android LaunchTheme/NormalTheme
остаются светлыми при любом OS mode. Website favicon использует тот же
MonoDark source; прежний lime CSS token стал alias текущего primary.
Шапки документации и brand guidance приведены к монохромному contract.
Технологические/semantic цвета и исторические SVG/Figma sources сохранены.

- Native export exact check: **20/20 PASS**; strict imported source check,
  iOS plist validation и `git diff --check` — **PASS**.
- Android debug build и `adb install -r` на `emulator-5554` — **PASS**.
  Readback установленного APK подтвердил StackCard label и точное совпадение
  всех пяти mipmap PNG с новым source. Home/Settings просмотрены; существующая
  account session сохранена. Google picker повторно не открывался через выход
  из аккаунта; iOS runtime отдельно не проверялся.
- Web: **97/97 tests PASS**, typecheck и scoped Prettier — **PASS**;
  isolated и actual production builds — **PASS**, MonoDark favicon есть в 14 app HTML.
  Текущее local preview на `127.0.0.1:3000` пересобрано и перезапущено.
  В браузере главной и Auth подтверждены Ink wordmark, MonoDark favicon,
  white background и neutral primary/accent. Снимок —
  `/private/tmp/stackcard-brand-web.png`.

### Упрощение web-входа — 2026-10-11

По прямому поручению пользователя Auth формы приведены к компактной стандартной
композиции: центрированная карточка, основной submit перед Google, регистрация
внизу. По последующему уточнению пользователя отдельная кнопка «На главную»
убрана: возврат выполняется по логотипу в шапке. Убраны дополнительные пояснения,
«Отмена» и ссылка проверки удаления с экрана входа. Сам recovery route сохранён;
Firebase Auth и безопасный returnTo не изменены.

Typecheck, формат, production build и **97/97 tests — PASS**. В браузере проверены
desktop 1280×720 и phone 390×844, переходы регистрации/восстановления/главной и
Tab из почты в пароль. Live sign-in/Google и отправка reset email не повторялись.

### Проверки base review и UID — 2026-10-09

Следующий пакет Phase13b использует существующие mobile review/CAS/UID contracts.
Web сравнивает captured saved base/document/buffer; avatar URL/path — одна замена.
Apply не сохраняет и не публикует, Cancel оставляет прежние данные. Изменение
buffer, выбранного saved document, base или UID отклоняет прежний выбор.
Изменение Library/соседнего документа не отменяет сравнение. Перед HTTP POST
проверяется UID после ожидания ID token; recovery/inventory callbacks проверяют
активную owner session перед следующим действием.

| Проверка | Фактический результат |
| --- | --- |
| Web static/contracts | `npm test` — **89/89 PASS**, в том числе 15 новых review regression cases; `npm run typecheck`, `npm run format:check`, `npm run build` — **PASS**. До fix три focused avatar/captured-value cases падали. Production build11 routes. |
| Browser review | Actual Chrome + demo Auth/Firestore/Storage/Functions: local override не выбран автоматически; Escape/Cancel сохраняют форму и возвращают focus; footer inert. Apply меняет buffer, отдельный Save пишет выбранный документ, sibling/Library/notes остаются прежними. |
| Позднее фото | Удержан ACK реально загруженного Storage объекта. Открытый dialog сохраняет captured строки; после ACK фото остаётся в buffer, устаревший Apply отклоняется. Серверный документ не изменён. |
| Browser UID | Второй tab завершает вход, пока первый ждёт ответ `getIdToken(true)`. Mutation POST не отправлен, прежняя UID-scoped publication receipt сохранена. Uncaught page errors — **0**; comprehensive console audit не выполнялся. |
| Двусторонний contract | Actual web→Dart→web focused Flutter test — **1/1 PASS** после model changes. Полный mobile suite/native SDK/live обмен не повторялся. |
| Layout | Dialog1440px/390px просмотрен; narrow scrollWidth390, кнопки доступны, background actions блокируются. Это локальные screenshots, новый Figma/a11y matrix не выполнен. |

Browser script/log — `/private/tmp/stackcard-phase13-review-uid-smoke.mjs` и `.log`;
screenshots — `/private/tmp/stackcard-phase13-review-wide.png` и `-narrow.png`.
Локальные artifacts optional; checks используют disposable demo accounts.
Functions emulator использовал host Node24 вместо manifest Node22. Task servers
остановлены; production данные и deployment не затронуты. Результаты сохранены
отдельным follow-up в [verification report](../redesign/source/d048-transfer-verification.json).
Phase13/live/mobile-device/iOS/Figma/user acceptance остаются открытыми;
commit/push/deploy в этом продолжении не выполнялись.

### Проверки продолжения Phase 13 — 2026-10-09

macOS zsh; текущая implementation проверена локально, без production deploy.
Новые результаты добавлены к [verification report](../redesign/source/d048-transfer-verification.json),
исторические D048 результаты сохранены отдельно.

| Проверка | Фактический результат |
| --- | --- |
| Web gate | `npm run check` — typecheck, **74/74 tests** и production build **PASS**; `npm run format:check` — **PASS**. Log `/private/tmp/stackcard-phase13-web-check.log`. |
| Двусторонний contract | Actual web helpers → Dart `decodeCloudPortfolioDraft`/`encodeCloudPortfolioDraft` → web parser: **1/1 Flutter test PASS**, focused analyze **0 issues**. Два независимых Resume, Portfolio/attached Resume, одна Library запись, nullable/empty overrides, privacy, captured base review/baseline и точные Unicode notes/text сохранены. Scoped mobile правка меняет только один документ. |
| Browser Save | Actual Auth/Firestore/Functions demo emulators и отдельный account. Удержанный ответ принятой transaction не заменил поздний ввод. Искусственно потерянный ACK → retry сохранил прежний mutation ID; новые правки остались в форме и записались следующим Save. Sibling/Library/notes сохранились. |
| Browser/public UI | Dark editor1440px показывает editor/preview рядом; narrow390px переключает modes, scrollWidth390. Publish → anonymous page200: бренд в title один раз, Twitter summary, no-photo без OG image, private notes/baseline отсутствуют. Unpublish → friendly404/noindex; missing404. Uncaught page errors — **0**. Screenshots wide/narrow просмотрены; новый Figma comparison не выполнялся. |
| Public metadata/errors | 11 новых contract tests: canonical exact HTTPS origin, выбранное фото той же public version, скрытый/чужой/private payload, no-photo, missing/withdrawn404/noindex и config/service unavailable/retry. Metadata/body читают один request-scoped snapshot; отсутствие постоянного cache сохранено. Actual HTTPS canonical/OG crawler-photo и concurrent publication runtime требуют отдельной приёмки. |

Browser script/log — `/private/tmp/stackcard-phase13-save-smoke.mjs` и `.log`;
images — `/private/tmp/stackcard-phase13-editor-wide.png` и `-narrow.png`.
Локальные artifacts optional; test не требует production credentials. Полный
mobile suite/native device/live sync и Figma/a11y matrix в этом продолжении не
повторялись. Контрактный Flutter test требует Node и установленных `apps/web`
dependencies; предусловия обновлены в CONTRIBUTING. Dev404 transition выдал
Next/React script warning; отсутствие всех console warnings этим прогоном не заявляется.
Phase13/R7/full R8/R9 и user acceptance не закрыты. Commit/push/deploy не выполнялись.

### Проверки D048 — 2026-10-08

Компактный [verification report](../redesign/source/d048-transfer-verification.json)
сохраняет команды, результаты и hash/size/local paths logs/screenshots. Logs и
images — optional evidence; native argv использовал временный isolated fixture
с Memory repository и actual StackCardApp, а не production dataset/entry point.

Результаты ведущего по текущему пакету; emulator/browser использовали demo
accounts и fixture, production данные/публикации не менялись. Числа отдельных
focused прогонов не суммируются с полным suite.

| Проверка | Фактический результат |
| --- | --- |
| Mobile regression | Полный `flutter test --no-pub --reporter expanded` — **1323/1323 PASS**; run log `/private/tmp/stackcard-full-tests-final2.log`. Root-focused проверки — **45 PASS**. |
| Mobile static | Финальный whole-app `flutter analyze --no-pub` — **0 issues**, 4.4s; log `/private/tmp/stackcard-analysis-final3.log`. |
| Assets | Strict `check_imports.py --require-brand --require-imported` — **41 files PASS**; `export_native_icons.mjs --check` с `SHARP_MODULE_ROOT=firebase/functions/node_modules` — **20 exact PNG PASS**. |
| Backend | `npm run test:all-rules` — **51 PASS**: Firestore30, actual Admin-SDK service11, Storage10. Focused barrier/race service run — **11 PASS**; latest pure projection suite — **14 PASS**. |
| Web static/contracts | Финальный `npm run check` — **PASS**: typecheck, **62/62 tests**, production build11 routes; `npm run format:check` — **PASS**, `npm audit` — **0 vulnerabilities**. Final log file не сохранён; actual tool output записан в report, прежний log не используется как новый. |
| Browser E2E | Actual demo Auth → mobile cloud6 fixture → web CAS Save → Publish → anonymous HTML. HTML не содержит private fields. Save новой роли сохранил прежний public snapshot; dirty Unpublish сохранил ввод, withdrawn Next page404 дала friendly unavailable state; Save+Republish сохранили publicId. Реальный Copy UI показал success. Fresh workspace390px: four tabs + header Settings, actual Settings click, scrollWidth390/390; public1280px:1280/1280, console errors=[] после Next Script fix. |
| Native Android | Debug source build и isolated actual StackCardApp launch — **PASS**. Actual isolated demo Home/Resume editor и native Share screenshots просмотрены. Системное Share sheet открылось с настоящим emulator publication URL; адресат не выбран, сообщение не отправлено. Project editor/Contacts Dark-Light просмотрены на промежуточных screenshots до последних Save-label/helper/counter правок; они не объявляются final exact renders. |
| Figma visual comparison | Actual screenshot206:28992, R6.4 public Resume no-photo wide Dark1440×1513, сопоставлен с published web1280px: Brand A header, open600px document column, Manrope, flat sections, badges и Share panel согласованы. Количество секций соответствует projected fixture. Это одно конкретное сравнение; full matrix/user acceptance отдельно. |
| Documentation | 11 updated files: оформление/local links — **PASS**; hero/badges и TOC order семи guides — **PASS**; owned-document `git diff --check` clean. |

Проверены реальный web service flow и выбранные Android экраны. Полная Figma
parity/journey matrix и user acceptance не объявляются завершёнными. iOS runtime
недоступен: нет полного Xcode/simctl. Actual native Auth/Google, camera/picker,
успешная geolocation, native Open/handoff и live cloud6/Rules/Functions/web deployment
этим evidence не закрыты. Temporary web/Firebase/Flutter task processes остановлены;
использованный existing Android emulator-5554 сохранён. Commit/push/deploy не выполнялись. R7 awaiting_review, DESIGN_READY/REDESIGN_DONE
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

**StackCard** — mobile/web-конструктор одного developer-портфолио. Владелец
ведёт Projects Library, выбирает работы в редакторе, сохраняет результат и явно
публикует его по постоянной ссылке. Home показывает сохранённую версию;
PDF строится из неё, Developer Card/QR — из опубликованной версии.

Платформы — Android/iOS через Flutter в `apps/mobile` и отдельный Next.js web
в `apps/web`. Оба клиента используют один UID-bound workspace. Старые независимые
Resume/Portfolio сохранены как совместимый архив с прежними URL; их библиотеки
не входят в современный пользовательский путь. Desktop и Flutter web исключены.

Аудитория — разработчики, студенты и начинающие специалисты, которым нужно
показать работодателю или заказчику выбранные проекты, навыки и свой вклад.
GitHub — необязательный источник публичных metadata; ручные проекты равноправны.
Пользователь выбирает описание, технологии и repository/product ссылки.
Единственная пользовательская картинка — avatar; проекты используют catalog icons.

Современный адрес — `/d/<publicId>`, независимо от имени и username. Rename и
republish сохраняют URL. Локальный source/runtime реализован; постоянный hosting,
iOS/store release и live availability не следуют из наличия кода.

---

## Living Portfolio: данные и контроль пользователя

Основная ценность — **одна Library → одно основное портфолио → saved PDF и
явная публичная версия с постоянной ссылкой**. **Living Portfolio / Smart GitHub Sync**
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
| Curated workspace / document draft | Projects Library, основное портфолио и отдельный Editor buffer, отобранные и отредактированные владельцем. Ручные проекты равноправны импортированным. |
| Published document | Одобренный пользователем public snapshot основного портфолио. Сайт читает только её; private база, notes и черновики доступны владельцу. |

</div>

При импорте пользователь выбирает репозиторий и может изменить описание и
технологии и live/product URL. В основном портфолио отдельно выбираются
порядок, featured и видимость attachment; удаление связи сохраняет Project в
Library. Проект имеет происхождение `manual | github`;
для импортированного проекта нужны связь с GitHub repository и сведения о sync.
Модель и правила сопоставления Phase 9 зафиксированы в
[ADR 0002](../decisions/0002-github-import-and-review.md).

Smart Sync обнаруживает новый репозиторий или изменения существующего и предлагает
действия: **Ignore**, **Preview / Review changes**, **Add to Library**. Исторический
UI может сохранять прежнюю подпись Add to portfolio; target — одна Library запись,
которую пользователь отдельно включает в основное портфолио.
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
Фото проектов исключены ADR 0005; новые технологии и другие сигналы могут
расширить правила позже при отдельном scope.

`ProjectScore` не вводится: для текущих действий достаточно конкретных условий.
Пороги активности и stars определены в одном pure API; подробный контракт — в
[architecture](../architecture/architecture.md#portfolio-suggestions).
Правила проверяются отдельно от UI и не публикуют изменения сами.

---

## Пользовательский путь и экраны

### Мобильное приложение

`Вход / явный local guest → optional onboarding → Projects Library / Editor →
Save → сохранённая Home / PDF → sync ACK → явный Publish → public URL / Card / QR`.

<div align="center">

| **Раздел** | **Содержимое и границы** |
|:---|:---|
| Главная | Durable main: профиль, только непустые разделы в сохранённом порядке. Два постоянных действия: скачать PDF и поделиться. |
| Проекты | Единая Library: выборочный GitHub import, ручное создание, поиск, contribution, technologies и catalog icon; без фото проектов. |
| Редактор | Необязательные профиль/контакты/навыки/опыт/образование и ordered attachments. Явный Save и защита выхода; GitHub identity меняется в Settings. |
| Settings через gear | GitHub identity, reduced motion, account/security, Inbox/notifications и delete/sign out; отдельной root-вкладки нет. |
| Персонализация | Четыре необязательных UID-bound шага: GitHub; имя/должность/город; о себе; avatar. Next/Back/Finish сохраняют progress. |
| Share / Developer Card | Постоянная public ссылка и QR после подтверждения публикации; карточка не берёт private/несохранённый текст. |

</div>

Три roots сохраняются на телефоне/планшете. Card, Import и Settings открываются
отдельно; Back возвращает origin. Светлый русский UI использует Manrope, Brand A,
existing theme/shared controls; dark/language/GPS controls не возвращаются.
Все поля optional, пустой Save допустим. Legacy backup и прежние public URLs
сохраняются при явном выборе основы, без автоматической публикации.

### Сайт и web-редактор

Next.js runtime уже содержит маркетинг/download, Firebase-вход, owner workspace
и anonymous published-only reader. Web online-first; mobile сохраняет local draft
и durable outbox. Оба клиента используют совместимый aggregate и LWW/CAS policy.

<div align="center">

| **Область** | **Назначение** |
|:---|:---|
| `/`, `/features`, `/use-cases`, `/examples`, `/help`, `/about`, `/download` | Русский сайт StackCard, реальные возможности и статус релизов без фиктивных download buttons. |
| `/sign-in`, `/sign-up`, `/reset-password` | Auth, восстановление и безопасный returnTo. Login email не становится public contact. |
| `/workspace` | Home/Projects/Editor, Settings, optional onboarding и saved PDF. Legacy owner links ведут в современный Editor. |
| `/d/[publicId]` | Только опубликованный snapshot. Missing/withdrawn — unavailable/404 без private lookup; public1/2 совместимы. |

</div>

Publish/Update/Unpublish — отдельные действия trusted runtime. Draft/Library/Settings
изменения не меняют public snapshot; более поздний ввод не теряется после ACK.
Permanent HTTPS origin и доступность hosting требуют отдельного разрешённого
запуска и проверки. Старые public URLs не удаляются ради нового UI.

## Portfolio Builder и Developer Card

Современный Editor управляет одним main: профиль, контакты, навыки, проекты,
опыт и образование. Порядок секций/проектов сохраняется явно; Home/PDF используют
saved snapshot. GitHub identity — Settings/персонализация. Legacy Builder,
независимые documents и base snapshots остаются для чтения и совместимости.

Developer Card содержит опубликованные avatar/name/role/technologies/username,
Brand A и permanent URL. QR кодирует exact URL этого snapshot; private draft,
неизвестная операция и неподключённый сервер не дают фиктивного QR. Android
использует existing MethodChannel/Kotlin `ACTION_SEND`, iOS — отдельную
UIActivityViewController проверку. Показ системного меню не доказывает отправку.


---

## MVP и полный scope v1

MVP соответствует одному основному портфолио и общей Projects Library. Таблица — критерии
продукта, а не объявление всех возможностей готовыми. Actual scope/evidence —
[в статусе](#статус-и-границы-текущей-работы).

<div align="center">

| **Область** | **Обязательный результат** |
|:---|:---|
| Authentication | Email/password и Google, восстановление доступа; реальные native flows и UID isolation. |
| DeveloperProfile | Имя/ник/роль/фото, навыки, опыт, образование, location и public contacts; login email отдельно. |
| Projects Library | Manual/GitHub работы, описание/вклад, catalog icon, technologies, repository/product; одна запись на работу. |
| Основное портфолио | Один main, необязательные поля, ordered секции/attachments, явный Save, durable Home и настоящий PDF; legacy архив сохранён. |
| Living Portfolio | Явный import/review/ignore и ручные overrides; без тихой перепубликации. |
| Publication | Publish/Update/Unpublish выбранного документа, постоянный URL, public renderer и безопасные delete/republish последствия. |
| Website | Светлый русский marketing/download, Home/Projects/Editor, Settings/onboarding и anonymous published main. |
| Inbox / Notifications | ContactRequest по published документу и owner Inbox в обоих клиентах; FCM после подключения настоящего сервиса. |
| Offline | Mobile local draft/cache/outbox; web online-first с настоящими saving/error/retry и conflict states. |
| Settings / Sharing | Mobile и web только light и русский; legacy preferences/schema совместимы. Reduced motion, account/privacy, native share и Card/QR по возможностям платформы. |

</div>

Public projection включает только выбранные секции, контакты и visible projects;
private notes, login/provider data, baseSnapshot и скрытые поля не передаются
посетителю. Contact me появляется вместе с validation/anti-spam/owner Inbox на
Phase 14; отсутствие push не теряет само обращение. Карта/Google Maps исключены,
город/страна вводятся вручную без GPS permissions.

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
- Location — необязательный ручной город/страна. GPS/geocoding/Maps и location
  permissions исключены; ранее запрещённая legacy location не раскрывается.
- Camera/gallery используются только для avatar: MIME/dimensions/byte limits,
  JPEG512/256KiB и удаление EXIF до owner-only Firestore upload. Новые Storage
  uploads/фото проектов не включаются; legacy paths читаются без удаления данных.
- Native permissions относятся к camera/gallery/notifications. Web использует
  browser file input и свой UX; Android MethodChannel/Kotlin и iOS native actions
  проверяются отдельно, их возможности не объявляются идентичными по одному test.
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

**Результат поручения 2026-10-23:** Phase19 production hardening завершена2026-10-24
после принятой Phase18, включая настройку Xcode и обязательную iOS проверку.
Незакрытые system/live/profile/Figma/release проверки сохраняются отдельно.
Phase20, deployment и billing не запускаются.
Разрешённый capability scope и оставшаяся работа перечислены
[в текущем статусе](#статус-и-границы-текущей-работы). Phase 11/12 и R0–R9 ниже
сохраняют историю реализации и evidence; новые mobile changes не считаются
автоматическим завершением этих фаз или full Design v2 acceptance.

План объединяет исходное описание StackCard, требования учебного задания
`individual_project_flutter_ru.docx` и актуальный scope выше: mobile, полноценный
web-редактор и публичное основное портфолио с совместимым архивом. Этот раздел
владеет roadmap; технические решения
подробно фиксируются в architecture и ADR, команды — в CONTRIBUTING.

### Актуальная последовательность 2026-10-21

Действующий контракт — ADR 0005, а не прежние библиотеки Resume/Portfolio.
Один UID-bound aggregate содержит Projects Library, основное портфолио и
совместимый архив. Hive8/cloud7/public2 читают прежние версии без перезаписи
при чтении. Новые задачи используют текущие shared controls и светлые tokens;
старые Figma frames и D048 source/evidence сохраняются как история.

| **Этап** | **Действующий результат и оставшаяся работа** | **Критерий приёмки** |
| --- | --- | --- |
| Совместимость и общая модель | Основное портфолио, точный backup legacy, optional onboarding и scoped Library уже реализованы. Сохранять regression coverage и завершить открытые native/live проверки. | Старые данные/URL сохранны; Save, импорт и перенос не публикуют, соседний ввод не записывается. |
| Phase 7/11/12/13: открытая приёмка | Android/iOS Auth, avatar camera/gallery и restart, ручной город, web/mobile обмен и публичный reader. Новые фото проектов, GPS и отдельные Resume libraries не требуются. | Проверен действующий путь с одним main, тремя roots и private/public границей; local evidence отделён от live/iOS. |
| Phase 14: сохранённая capability | Contact/Inbox/FCM реализованы, Android live принят ранее. Постоянный hosting отложен; iOS/APNs открыт. Inbox доступен из Settings. | Новый запуск только по отдельному поручению; push не заменяет durable Inbox и не создаёт root-вкладку. |
| Phase 15: source/local результат, отдельная приёмка | Developer Card из опубликованного основного портфолио, QR permanent URL и existing native Share. Вход через «Поделиться», без новой root-вкладки. | Карточка соответствует public snapshot; unpublished/unknown/unavailable не дают фиктивного QR или успеха. |
| Phase 16–17: измерения и качество | Профилирование saved Home/PDF/Card, Library/GitHub import и Editor; сквозные Save/sync/Publish/QR/UID journeys и coverage. | Измерения воспроизводимы; миграция, offline/retry и поздние ACK не теряют данные и не публикуют автоматически. |
| Phase 18–20: доставка и выпуск | CI по actual configs, бесплатное окружение, hardening, release artifacts и материалы нового UI. Каждая следующая фаза требует отдельного перехода. | Проверки блокируют дефекты; signing безопасен, live rollout и распространение выполняются только по разрешению. |

Чекбоксы исходных фаз ниже сохраняют историю. Их оставшиеся задачи и критерии
обновлены под действующий контракт; удалённые возможности не возвращаются ради
старой приёмки. Источники текущего UI — design guide, ADR 0005 и actual runtime.

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
| Phase 12 — Location | ADR 0005: только ручной город/страна; GPS удалён, прежняя геолокационная приёмка снята со scope |
| Phase 13a — Public shell | D048 source реализован: Next.js shell/landing/download; browser runtime и production build PASS; full Figma/release acceptance отдельно |
| Phase 13b — Auth и редактор | ADR 0005: три roots, одно main, Projects Library, optional onboarding и cloud7; full cross-client/live/iOS acceptance открыта |
| Phase 13c — Public Resume/Portfolio | Современный public2 main и legacy reader1; explicit Publish/permanent URL реализованы, live acceptance открыта |
| Phase 14 — Contact / Inbox / FCM | Реализована; Android live 5/5 PASS 2026-10-10, постоянный запуск отложен пользователем; iOS/APNs и production readiness открыты |
| Phase 15 — Developer Card и native sharing | Source/local gate реализованы:1365 tests, QR decode и APK PASS; native/live/iOS приёмка открыта |
| Phase 16 — Performance | В работе: локальные baseline/after и две оптимизации; native DevTools gate открыт |
| Phase 17 — Testing | Source/local и Android QA PASS; iOS SDK journey11 checkpoints дополнительно PASS в Phase19; system/touch/live gates отдельно |
| Phase 18 — CI/CD | Завершена: GitHub green/red runs, полный suite/coverage и скачанные APK/LCOV artifacts проверены |
| Phase 19 — Production hardening | Завершена2026-10-24: Android/iOS build/SDK/UI и Crashlytics delivery/payload PASS; security/privacy review выполнен |
| Phase 20 — Release | Запланирована |

</div>

### Как выполнять план

Прямое поручение 2026-10-21 разрешает Phase 17 после source/local результатов
Phase 15–16. Источник — ADR 0005; выполненные x-задачи прошлых фаз остаются
историей, оставшаяся приёмка относится к текущему UI. Проверки Phase 15 и16
сохраняются отдельно; следующий переход требует поручения.

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
  auth state и sign out: реализация готова; Android Google provider/OAuth
  configuration завершена 2026-10-10, Android native Google приёмка прошла
  2026-10-11; iOS и полный password reset остаются открытыми.
- [x] Добавить именованные routes, параметры, вложенную навигацию и auth redirects
  в GoRouter; unit/widget проверки transitions и session restore проходят.
- [x] Привязать local draft к Firebase UID; реализовать явный guest transfer
  и изоляцию данных при смене аккаунта.

**Проверки и приёмка**

- [ ] Все обязательные auth сценарии проверены на native targets. Android live
  registration/email sign-in/sign out и reset API acceptance подтверждены;
  Android Google flow и restart session restoration приняты 2026-10-11;
  фактическое письмо/reset пароля и iOS ещё не приняты.
- [x] Auth redirects, именованные routes, параметры и вложенная навигация
  проверены для owner/guest/restoring/error/signedOut в Flutter tests.
- [x] Гостевой draft переносится явно только в пустой target; sign out, UID switch,
  late save, сбой transfer/reopen и private form state проверены без чужих данных.

**Формы аккаунта — 11 октября 2026**

- Вход, регистрация и reset центрируют общий блок, heading и текстовые действия.
  Auth viewport убирает пустое поле original Wordmark справа; SVG bytes сохранены.
  Keyboard/overflow прокручивает форму, fields сохраняют ввод.
- Password и confirmation имеют независимые show/hide controls≥48, autofill и
  отключённые autocorrect/suggestions/smart quotes/dashes также при показе текста.
- Регистрация проверяет 8–128 Unicode code points (минимум снижен по запросу
  2026-10-12), очевидные простые варианты,
  короткие повторы/последовательности и точное совпадение с email/local-part.
  Requirements и конкретная ошибка обновляются при вводе; confirmation повторно
  проверяется после изменения password. Пробелы разрешены и передаются без trim.
  Sign-in сохраняет правила существующих аккаунтов. Это client validation;
  remote Firebase policy, проверка утечек и рабочие аккаунты не менялись.
- Focused gate: **136/136 PASS** — policy, auth UI, account navigation,
  shared controls и localization. `flutter analyze`, Dart format и diff check —
  PASS. Headless previews входа/регистрации/reset и validation states просмотрены;
  320px/text2/ru-en, keyboard и доступность покрыты. Это проверка UI/source,
  без новой native Auth acceptance или установки на устройство.

**Минимальная длина пароля — 12 октября 2026**

По прямому запросу минимум регистрации снижен с15 до8 Unicode code points
в mobile и web; требования и сообщения об ошибке обновлены. Максимум128,
проверки простых паролей, повторы, совпадение с почтой и raw SDK input сохранены.
Mobile policy/auth UI/localization — **63/63 PASS**, web password tests —
**5/5 PASS**; targeted Flutter analyze, web typecheck, Dart/Prettier format и
`git diff --check` — PASS. Границы7/8 и128/129 покрыты.

По дополнительному прямому запросу 2026-10-12 live Firebase Auth проекта
`stackcard-dev-snownumb` настроен через Identity Toolkit Admin API: политика
`ENFORCE`, `minPasswordLength: 8`, без принудительного обновления пароля при входе.
До изменения отдельная политика отсутствовала. Повторное server GET подтвердило
сохранённый минимум8; рабочие аккаунты и пароли не менялись. Создание аккаунта
с новым минимумом отдельно не проверялось; source Firebase configs этой настройкой
не управляют.

**Google Auth и публичные API keys — 11 октября 2026**

- В Google Cloud Android/iOS keys ограничены 11 Firebase API, без AI Logic,
  Gemini, Cloud SQL и других неиспользуемых сервисов. Android restriction —
  package и зарегистрированный SHA-1, iOS — native bundle ID; service-account
  binding отсутствует. API keys остаются публичной клиентской configuration.
- Live REST проверки для обоих keys: Identity Toolkit и Token Service с правильными
  app headers достигают token validation (`INVALID_CUSTOM_TOKEN`/`INVALID_REFRESH_TOKEN`),
  Identity Toolkit без app headers возвращает `403` с Android/iOS app-blocked reason.
  Эти проверки не создают пользователей и не меняют рабочие данные.
- Android `google_auth_runtime_test.dart`: `seed` и `check` — **2/2 PASS** на
  `emulator-5554` после настройки restrictions. Подтверждены Firebase
  `google.com` provider, принудительное обновление ID token, защищённый AppShell,
  server-only owner Firestore read, восстановление того же UID в новом процессе
  и sign out named session. `defaultSessionPreserved=true`; owner draft отсутствует,
  поэтому это не повторная приёмка sync. Пароли и токены в evidence не сохранялись.
- iOS config обновлён по актуальному Firebase SDK config: OAuth client IDs,
  `FirebaseOptions.iosClientId` и callback URL scheme в `Info.plist` согласованы.
  Plist/source consistency и `flutter analyze` — PASS; настоящий iOS flow
  остаётся открытым, configuration не считается native acceptance.
- GitHub Secret scanning alerts #1/#2 закрыты как `False positive` после проверки
  restrictions: это публичные Firebase client keys, не server credentials.
  Репозиторий остаётся публичным; billing/visibility/deploy не менялись.

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

**Актуализация ADR 0005:** единственная новая картинка — avatar в Firestore на Spark.
Отмеченные исходные задачи и результаты ниже исторические: новые Storage uploads,
фото проектов и файлы Resume не возвращаются. Legacy paths сохраняются для чтения.

**Задачи**

- [x] Подключить Firebase Storage для avatar и project images, camera/gallery.
  При выбранном файловом формате resume добавить его загрузку здесь.
- [x] Ввести MIME/size validation, compression/resize, upload progress, retry
  и image caching через cached_network_image; обработать отказ в permissions
  и отмену выбора.
- [x] Создать Storage Rules, проверку ownership и public/private доступа,
  определить очистку заменённых файлов.

**Проверки и приёмка**

- [ ] Avatar выбирается через camera/gallery, проходит JPEG512/256KiB validation
  и сохраняется в owner-only Firestore; после Save/restart читается тем же UID.
- [ ] На Android/iOS проверены progress, retry, отказ permissions, отмена и смена UID.
  Фото проектов и загрузка Resume исключены; PDF генерируется из saved main.
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

**Актуальный scope ADR 0005:** только необязательный ручной город/страна.
GPS, reverse geocoding, picker и их permissions удалены. Исходные выполненные
задачи/измерения ниже сохранены как история; их незакрытая GPS-приёмка снята
со scope, iOS и сохранность ручного ввода проверяются в действующем сценарии.

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
- [ ] Ручной город/страна сохраняется из персонализации и Editor, переживает
  restart и mobile↔web sync; Cancel не меняет durable snapshot.
- [ ] Современный runtime не запрашивает GPS permissions, не содержит Maps/
  geocoding SDK и не переносит ранее запрещённую legacy location автоматически.
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

Актуальный scope ADR 0005: три roots, одно основное портфолио, Projects Library,
optional onboarding, saved Home/PDF и явная публикация с постоянным URL.
Отдельные Resume/Portfolio остаются совместимым архивом; их библиотеки,
дублирование и base review не возвращаются в повседневный интерфейс. Legacy `publish(username, content)` и
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

Web target переопределён поручением 2026-10-11: только светлая тема и
[русский StackCard по Openship](../redesign/web-openship.md). Отмеченные ниже
R6 задачи сохраняют историю реализации; новый target не изменяет Flutter.

**Задачи**

- [x] Создать Next.js runtime в apps/web по реальному manifest/config, выбрать
  необходимые зависимости и format/typecheck/test/build команды из actual manifest.
- [x] Перенести tokens/shared controls и минимальную оболочку public reader
  Resume/Portfolio по Figma R6; phone/tablet/wide, dark/light и photo/no-photo.
- [x] Реализовать landing и download по Figma с пользой base→outputs;
  CTA/store links отражают фактическую доступность сборок и редактора.

**Проверки и приёмка**

- [ ] Реальный browser runtime/build работает; layout, keyboard/focus и UI states
  проверены в действующем white-only/ru UI; screenshot review учитывает ADR 0005.
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
- [x] Проверить двусторонний cloud6 contract web→mobile→web с actual codecs,
  независимыми документами, общей Library, privacy и scoped правкой.
- [x] Проверить newer input during Save и retry после потерянного ACK в actual
  browser + Firestore emulator; более поздние правки требуют отдельного Save.
- [x] Проверить captured web base review, атомарный avatar и stale buffer через
  contract tests/actual Storage ACK; проверить выход во время token refresh до POST.
- [ ] Проверить live mobile↔web SDK обмен, UID transitions,
  повреждённые/неизвестные данные и последствия whole-aggregate LWW на устройствах.

**Проверки и приёмка**

- [ ] Anonymous/foreign access к private базе, документам и media отклоняется
  на стороне данных; routing guard сам по себе не считается защитой.
- [ ] Home показывает durable main, Editor сохраняет явным Save и защищает выход;
  scoped импорт/удаление/Settings Save не записывают соседний несохранённый ввод.
- [ ] Legacy backup/documents/public URLs переживают явный перенос; Library хранит
  одну запись проекта, attachment order и overrides сохраняются.
- [ ] Светлый русский UI с Brand A/Manrope проверен на phone/tablet/wide,
  width320/text2/keyboard: три roots, Settings, необязательные поля/персонализация,
  scroll/drag/autoscroll, focus, targets и loading/error/empty/retry без overflow.
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
- [x] Проверить published-only metadata/SEO/OpenGraph/Twitter и безопасные
  missing/unpublished/config/service states contract tests и локальным browser.
- [ ] Проверить actual HTTPS canonical/OG-photo crawler и одинаковую выбранную
  версию на mobile preview и public web в live окружении.

**Проверки и приёмка**

- [ ] Изменение основного портфолио/Library/Settings не меняет public snapshot
  до отдельного Publish/Update; local Save, server sync ACK и publication различимы.
- [ ] Anonymous получает только allowlisted published данные; malicious nested
  payload, foreign UID, hidden contacts/media и listing отклонены.
- [ ] Rename/republish сохраняют URL, duplicate получает новую идентичность;
  unknown operation перечитывает подтверждённое состояние вместо ложного success.
- [ ] Unpublish закрывает public main и его QR/Card; delete не воскресает после
  delayed Save/ACK/retry. Library и совместимый архив не теряются.
- [ ] URL действительно открывается без login на телефоне/desktop; Copy/Open
  используют подтверждённый адрес, private attachment не становится ссылкой.

**Готово, когда:** владелец публикует основное портфолио из mobile и web;
посетитель открывает именно опубликованный snapshot по постоянному адресу.
Public2 исключает attached Resume/project images; reader1 и старые URL совместимы.
Первые mobile→public сценарии допустимы до полного 13b; Phase 13 целиком закрывается
после приёмки всех трёх частей. Contact me/Inbox подключаются на Phase 14.

### Phase 14 — Contact / Inbox / FCM

**Задачи**

- [x] Добавить web Contact me с name/email/message и validation; определить
  anti-spam/rate limiting до публичного открытия формы. Форма относится к выбранному
  published документу и учитывает его contact/privacy selection.
- [x] Создать ContactRequest и Inbox в mobile/web; обращения читает только владелец.
  Проверить переход к обращению без добавления новой root-вкладки и передачу
  только разрешённых полей; private owner identity не раскрывать отправителю.
- [x] Настроить Android FCM: device tokens, permissions и переход из уведомления
  к обращению. Trusted Node sender работает без платного Cloud Functions.
  iOS/APNs configuration и device acceptance остаются отдельной открытой проверкой.
- [x] Проверить actual live доставку на Android, запрет уведомлений и смену аккаунта;
  Inbox остаётся источником обращения при выключенном push.

**Проверки и приёмка**

- [x] В локальном demo окружении валидное обращение с public page появляется
  в mobile/web Inbox; validation, honeypot, transaction rate limits и безопасный
  retry проверены. Production App Check и публичное открытие остаются отдельным gate.
- [x] Обращение читает только владелец; отказ постороннему подтверждён
  actual emulator SDK Rules/service tests и native Android SDK acceptance.
- [x] Actual Android FCM доставлен, настоящий tray tap открывает обращение
  из background и terminated; denied notifications и смена аккаунта проверены,
  без push обращение остаётся в Inbox. Это Android acceptance, не iOS/APNs.
- [ ] iOS/APNs device delivery и постоянный публичный запуск. Hosting отложен
  по решению пользователя; конфигурация будущего подключения описана в env examples.

**Готово, когда:** обращение с public page появляется в обоих кабинетах,
владелец получает mobile notification, посторонний не читает Inbox. Это не чат;
browser push автоматически в scope не добавляется.

**Фактический прогресс — 2026-10-10**

[ADR 0004](../decisions/0004-contact-inbox-notifications.md) фиксирует принятый
contract; [архитектура](../architecture/architecture.md#contact-inbox-и-уведомления--phase-14)
и [инструкция запуска](../../CONTRIBUTING.md#contactinboxfcm--phase-14)
обновлены по текущему source. Private draft остаётся Hive7/cloud6; Inbox и device
registrations находятся в отдельных owner-only collections.

- Contact form доступна только при открытом projected typed contact выбранного
  published документа. Trusted submit проверяет exact payload, privacy, active
  owner, honeypot и quotas; отправитель получает только receipt без owner UID/email.
  Повтор accepted payload с тем же requestId не дублирует обращение или notification.
- Mobile/web Inbox доступны из Settings, без новой root-вкладки. Server pagination
  ограничена 50 записями; клиент меняет только readAt. UID transition и поздние
  ответы не раскрывают прежний Inbox. UI отмечает неподтверждённые sender name/email.
- Mobile FCM runtime и trusted sender реализованы: явный permission, token refresh,
  register/unregister, single-UID binding, foreground/cold/background tap guards,
  generic payload и cleanup. Fake transport/SDK tests проверяют эти переходы;
  live notification delivery ими не подтверждается. Inbox сохраняется при сбое push.

| Проверка | Фактический результат |
| --- | --- |
| Web | **95/95 tests PASS**, typecheck, format:check и production build (11 routes) PASS. |
| Backend | Functions syntax check и **25/25 pure tests PASS**; actual Auth/Firestore/Storage Rules и service suite **68/68 PASS**, без skipped. Canonical indexes прошли проверку installed Firebase CLI. |
| Mobile | Полный `flutter test --no-pub --reporter expanded` — **1352/1352 PASS**; `flutter analyze --no-pub` — 0 issues; format всех 24 затронутых Dart файлов PASS. |
| Browser | Actual trusted Publish → anonymous submit → owner web Inbox/readAt PASS; accepted ACK после позднего ввода, lost ACK/retry без duplicate, honeypot/unknown fields, email quota и новый submit после Unpublish проверены. Page errors 0; 390px без horizontal overflow. |
| Native Android | **1/1 integration test PASS** на `main_phone`: actual trusted browser request, server pagination 50+4, readAt idempotency, foreign/anonymous denial и session guards. Обычный debug APK собран и восстановлен через install -r после test APK. |
| iOS | Info.plist, entitlements и project syntax PASS; compilation, signing, APNs и device delivery не проверены. |

Raw local logs сохранены в `/private/tmp/stackcard-phase14-mobile-full-tests.log`,
`stackcard-phase14-mobile-analysis.log`, `stackcard-phase14-mobile-changed-format.log`,
`stackcard-phase14-web-tests.log`, `stackcard-phase14-web-build.log`,
`stackcard-phase14-native-inbox.log` и `stackcard-phase14-browser.log`.
Полный backend 68-test result зафиксирован в tool output; отдельный raw log для
этого прогона не сохранялся. Общий mobile format gate выявил четыре прежних файла
вне Phase 14: `local_draft_accounts.dart`, `portfolio_public_content_codec.dart`,
`portfolio_location_persistence_test.dart`, `workspace_controller_test.dart`;
они не изменены этой фазой.

**Открыто:** production App Check provider/site key/intended app ID, token verifier
IAM и HMAC secret; deployment Rules/indexes/Functions/web; реальная FCM доставка,
permission denial/revocation и tap на устройстве; iOS compilation/signing/APNs
и доставка. Уже открытые live/iOS/Figma и пользовательская приёмка Phase 13
не закрываются этими результатами. Phase 14 целиком не завершена; Phase 15
автоматически не начата. Config/deploy/billing требуют отдельного поручения.

**Продолжение Phase14 — 2026-10-10**

- Две regression failures до исправления подтвердили потерю повторного backend
  unregister после успешного SDK deleteToken и отсутствие cleanup нового token
  при позднем register ACK после смены UID. Controller хранит captured UID/token
  в памяти до подтверждённого revoke. После SDK/consent cleanup новый UID может
  явно включить push; прежний backend warning остаётся видимым, retry может
  требовать Auth прежнего владельца. Queue не сохраняет tokens на диск.
- UI различает подтверждённую регистрацию нового аккаунта и незавершённую
  очистку прежней. Новый widget regression подтверждает warning и доступ к Inbox.

| Проверка | Фактический результат |
| --- | --- |
| Focused controller/UI/locale | **34/34 PASS**, включая 4 новых controller regressions и 1 widget scenario. |
| Полный mobile gate | **1357/1357 PASS**; `flutter analyze --no-pub` — 0 issues; format всех 6 затронутых Dart-файлов PASS. |
| Native Android permission | Actual Firebase Messaging SDK на `main_phone`: **3 отдельных прогона по 1 PASS** — notDetermined, authorized, revoked/denied. System flags заданы ADB; prompt/token/register/Auth/draft не вызываются. Это permission mapping, не live FCM или ручной отказ в prompt. |
| Восстановление | Исходный `POST_NOTIFICATIONS granted=false` без user flags восстановлен; обычный debug APK собран и установлен через `install -r` без uninstall. Task emulator остановлен. |

Raw logs: `/private/tmp/stackcard-phase14-notifications-focused.log`,
`stackcard-phase14-continuation-tests.log`, `stackcard-phase14-continuation-analyze.log`,
`stackcard-phase14-permission-initial.log`, `stackcard-phase14-permission-granted.log`,
`stackcard-phase14-permission-revoked.log`, `stackcard-phase14-restored-apk-build.log`.
Команда opt-in SDK test и восстановление — в CONTRIBUTING. Web/backend не
изменены и их suites не повторялись. Production App Check/IAM/secrets/deployment,
live FCM delivery/tap, ручной permission prompt и iOS/APNs остаются открытыми;
Phase14 целиком не завершена. Commit/push/deploy не выполнялись.

**Бесплатное live-окружение и отложенное подключение — 2026-10-10**

- Firebase `stackcard-dev-snownumb` остаётся Spark: `billingEnabled=false`,
  платёжный аккаунт не связан. Cloud Functions/App Hosting/Storage не развёрнуты.
  `contactRateLimits.expiresAt` больше не включает платную TTL policy; фиксированные
  quota windows работают по server clock, старые docs требуют отдельной maintenance.
- Plain Node `firebase/functions/src/server.mjs` переиспользует shared Auth,
  publication, Contact и FCM services. Submit вызывает sender после durable commit;
  matching retry восстанавливает лишь ещё не начатую попытку. Transport failure
  сохраняет Inbox. Без bucket доступен text-only Publish; media/account delete
  отклоняются до необратимой записи, прежние Phase13 release gates остаются открытыми.
- Actual Firestore Rules/indexes развёрнуты. Registered Firebase web app и бесплатный
  App Check Enterprise Essentials provider настроены. В live-тесте Node/Next.js
  работали через временные HTTPS Quick Tunnels с этого Mac; это dev acceptance,
  постоянный hosting этим не обеспечен. Секреты/ADC не помещены в Git.
- Backend **31/31 pure/real HTTP tests PASS**, syntax PASS; actual emulator
  Rules/service suite **74/74 PASS**. Web **96/96 PASS**, typecheck, format и production
  build PASS с actual public Firebase env. Mobile unit/widget suite **1357/1357 PASS**,
  полный analyze — 0 issues; затронутые Dart files format PASS. Android opt-in
  live entrypoint compiled/analyzed; обычный runtime не включает его автоматически.
- Первый actual run остановился на отсутствующем App Check consumption permission
  и завершился **failed**, не PASS. Пользователь затем явно разрешил ADB tray tap
  и временное `roles/firebaseappcheck.tokenVerifier` для существующего project owner.
  Новый run использовал настоящую web форму и Enterprise limited-use token:
  intended app verified, `alreadyConsumed=false`, без debug/bypass token.
  Owner/project/default Auth/Hive state не подменялись: отдельные named test sessions,
  saved text fixtures и actual authenticated HTTP Publish.

| Actual Android live сценарий | Проверенное поведение | Результат |
| --- | --- | --- |
| Foreground | SDK `onMessage`, нет автоматического перехода; exact обращение читается из server Inbox | **PASS** |
| Background + tray tap | Реальное системное FCM notification → `onMessageOpenedApp` → правильный `InboxRequestScreen` и текст Firestore | **PASS** |
| Terminated + tray tap | `am kill`, отсутствие процесса до send; настоящий tap → PID 8680 → 10227, `getInitialMessage`, правильное обращение | **PASS** |
| Смена A → B + notification A | Actual `onMessageOpenedApp` A под B; переход отсутствует, actual Firestore SDK читает A с `permission-denied` | **PASS** |
| Уведомления запрещены | Actual SDK denied, device registration отсутствует; browser submit accepted, exact server Inbox detail доступен без push | **PASS** |

Четыре transport сценария подтвердили server FCM `successCount=1/failureCount=0`;
в denied сценарии device count — 0, обращение сохранено. Каждый native run завершён
`status=passed`, SDK token удалён, pending backend cleanup отсутствует, named
sessions закрыты, default Auth/consent сохранены. Actual requestId получен от
браузерного submit и передан host handshake; synthetic notification intent не
использовался. Revocation SDK mapping ранее проверен отдельно; реальный ручной
отказ в системном prompt и iOS/APNs device delivery этим не подтверждены.

- После теста временное IAM-право **удалено**, остальные bindings сохранены,
  Spark без billing повторно подтверждён. Все пять тестовых public документов
  штатно сняты через reversible Unpublish; own push bindings — 0. Обычный debug APK
  восстановлен через `install -r`; `POST_NOTIFICATIONS granted=false`, без
  `user-set/user-fixed`. Node/Next.js/tunnels и запущенный для теста emulator
  остановлены, временный ADC credential file удалён, исходная CLI сессия сохранена.
- Автоматическая review отклонила irreversible удаление disposable Auth accounts/
  Firestore fixtures без явного разрешения. Тестовые аккаунты/private fixtures
  сохранены; прежний failed run также снял свою публикацию и удалил own bindings.
  Рабочие аккаунты не удалялись.
- Пользователь сообщил, что постоянного бесплатного hosting нет, и поручил
  сохранить функцию для будущего подключения. В own web `.env.local` очищены
  временные API URLs, App Check site key и web origin; normal mobile build не
  содержит тестовых endpoint defines. UI использует существующий unavailable
  state. Будущий setup описан в [web env](../../apps/web/.env.example),
  [backend env](../../firebase/functions/.env.example),
  [web guide](../../apps/web/README.md#бесплатное-окружение-spark),
  [mobile guide](../../apps/mobile/README.md#локальная-разработка) и CONTRIBUTING.
  Нужны собственные HTTPS Node/Next.js hosts, реальные env/defines, Rules/indexes,
  App Check SCORE provider/intended app и права runtime ADC, включая token verifier.
  Временный grant owner не заменяет постоянную настройку backend principal.
  Final web production build с очищенными временными endpoints — **PASS**;
  локальные Markdown targets после обновления guides: **545 проверены, 0 broken**.

Raw metadata: `/private/tmp/stackcard-phase14-spark-live-results.json`,
`stackcard-phase14-live-{foreground,background,terminated,foreign,denied}.json`;
safe server diagnostics — `stackcard-phase14-spark-api.log`.
Screenshot принятой формы — `stackcard-phase14-spark-live-contact-accepted.jpg`;
реального background tray tap/detail — `stackcard-phase14-background-shade.png`
и `stackcard-phase14-background-opened.png`.

Android live gate Phase14 выполнен, функциональность сохранена для будущего
подключения. Постоянный публичный запуск отложен по решению пользователя;
iOS/APNs, полная production/Figma/user acceptance и release не объявляются
завершёнными. Phase15 не начата.

### Phase 15 — Developer Card и native sharing

**Переход разрешён 2026-10-21.** Один main по ADR 0005; native open/share канал
уже реализован, его следует расширять только при необходимом поведении.

**Задачи**

- [x] Создать Developer Card из опубликованного snapshot основного портфолио:
  avatar/no-photo, name, role, technologies, username, Brand A и permanent URL.
  Несохранённый Editor и более новый private draft не являются источником карточки.
- [x] Построить QR локально из подтверждённого `/d/<publicId>`, сохранить quiet zone
  и читаемый контраст. QR не содержит UID, notes, private media paths или mock URL.
- [x] Открывать карточку из «Поделиться», без четвёртой root-вкладки и без третьего
  постоянного действия Home. Сохранить действующий светлый русский UI/Manrope,
  shared controls и white/ink Brand A; width320/text2/keyboard/scroll доступны.
- [x] Использовать existing MethodChannel → Kotlin → `Intent.ACTION_SEND`
  для Share, existing Open и Copy подтверждённой ссылки. Показ share sheet
  не означает фактическую отправку. Для iOS сохранить отдельную проверку.
- [x] Разделить unpublished/deleted, loading, unknown/pending, unavailable и
  изменённую public version; повтор не публикует автоматически. Смена UID,
  поздние ответы и withdrawal не оставляют активными старые QR/actions.

**Проверки и приёмка**

Отметки ниже подтверждают local unit/widget/adapter/decoder evidence;
настоящие system/device/live/iOS проверки остаются отдельным открытым пунктом.

- [x] Карточка соответствует published main, включая необязательные/скрытые поля
  и avatar; private правки до Publish не меняют её. Legacy архив не выбирается
  пользователем как второе современное портфолио.
- [x] QR декодируется в exact permanent URL; rename/republish сохраняют URL,
  чужой publicId/несовпадающая version отклоняются, старые mappings не теряются.
- [x] Draft/unpublished/unknown/unavailable/смена UID не дают фиктивной ссылки;
  Copy/Open/Share используют выбранную подтверждённую публикацию.
- [ ] Реальный Android share sheet через собственный Kotlin channel передаёт
  exact URL; результат emulator/physical device указан явно. iOS sharing
  проверяется отдельно; отсутствие live hosting не выдаётся за доступность страницы.

**Готово, когда:** карточка/QR читаются и соответствуют public snapshot,
Android channel и share sheet проверены на устройстве, QR открывает anonymous
public portfolio в разрешённом окружении. Source/widget/emulator evidence и
незакрытая physical/live/iOS приёмка записываются отдельно.

**Фактический результат — 2026-10-21**

- Реализованы public read model/codec, UID-bound Firestore listener и standalone
  white-only Card/QR. Новой schema/collection/write store нет; private buffer
  не читается. Avatar использует existing image validation/bounded legacy reader.
- Home → «Поделиться» предлагает ссылку либо Card/QR. Root-вкладок три,
  постоянных Home CTA два; auto-Publish при открытии карточки отсутствует.
  Copy/Open/Share повторно сверяют inventory/version и owner перед native action.
- Полный `flutter test --no-pub --reporter expanded` — **1365/1365 PASS**,
  включая21 новых cases; `flutter analyze --no-pub` — **0 issues**.
  Формат15 затронутых Dart-файлов, asset integrity, docs links и diff — PASS.
- QR из actual Flutter render независимо декодирован macOS Vision в exact
  `https://portfolio.example/d/0123456789abcdef0123456789abcdef`.
  Это synthetic published fixture: проверен image decoder, не доступность сайта.
  Width320/text2, landscape, scroll/targets, avatar, cache/pending/withdrawal,
  stale version/publicId, owner transition и Home Share regressions — PASS.
- Android `flutter build apk --debug --no-pub` — PASS; APK собран с обычным
  `main.dart`, без установки/очистки пользовательского приложения. Kotlin/iOS
  Share channel переиспользован; настоящий share sheet в этой проверке не открывался.
- **Открыто:** native QR scan/Share/Open и iOS/live public URL. На момент Phase15
  подключённых устройств не было; запуск `main_phone` завершился `No initial system image for this
  configuration` из-за отсутствующего образа. SDK images/AVD/user data не изменялись.
  Отложенный hosting не запускался; Phase15 целиком не закрыта. На момент этой
  проверки Phase16 ещё не начиналась; следующий переход разрешён отдельно ниже.
  Позже Phase17 подтвердил Android Card/Copy на отдельном AVD из другого
  установленного SDK; оставшиеся QR scan/Share/Open/live/iOS gates этим не закрыты.

Логи: `/private/tmp/stackcard-phase15-all-tests.log`,
`stackcard-phase15-final-analyze.log`, `stackcard-phase15-build.log`;
preview — `/private/tmp/stackcard-phase15-card.png`. Commit/push/deploy не выполнялись.

### Phase 16 — Performance

**Переход разрешён 2026-10-21.** Открытая приёмка Phase 15 сохраняется
[в её разделе](#phase-15--developer-card-и-native-sharing); результаты ниже
не закрывают native QR scan/Share/Open, iOS или live public URL.

**Задачи**

- [x] Добавить воспроизводимый локальный benchmark на валидном большом workspace,
  сохранить CPU/mounted elements/RSS/PDF и before/after для найденных проблем.
- [x] Убрать построение невидимых Library cards и повторное кодирование/paint QR
  при прежнем URL; проверить поиск/прокрутку, смену URL и существующий Editor drag.

- [ ] Измерить в Flutter DevTools saved Home, длинный Editor с drag/autoscroll,
  Projects Library/GitHub pagination, avatar, PDF и Developer Card/QR. Использовать
  реальные aggregate limits и указать устройство/build mode/fixture.
- [ ] Сохранить frames/rebuilds/memory и время PDF/QR до изменений; исправлять
  только обнаруженные проблемы и повторять тот же сценарий на том же устройстве.
- [x] Проверить responsive web Editor/public main с длинным текстом и avatar,
  local fonts/SVG и отсутствие PDF кода до экспорта в изолированном browser harness.
  Настоящий Next SSR/live route и пользовательские данные остаются отдельной приёмкой.

**Проверки и приёмка**

- [ ] Есть воспроизводимые измерения больших Library/Editor и saved outputs;
  legacy архив не строится в скрытых библиотеках и не меняется ради ускорения.
- [ ] Сопоставимые before/after measurements/screenshots подтверждают улучшение
  без потери scroll/keyboard/UID/privacy, порядка секций и late input.
- [ ] PDF/QR и web с реальными данными проверены; микрооптимизации без выявленной
  проблемы не добавляются.

**Готово, когда:** сохранены исходные и повторные измерения; каждая оптимизация
имеет наблюдаемую причину и не меняет продуктовый контракт.

**Локальный результат — 2026-10-21**

Fixture: 200 Library projects ×20 technologies, 200 skills, 30 experience,
20 education, 10 links, main +20 legacy documents (лимит21); domain validation
PASS. Saved main разрешается прежним API; legacy документы не появляются в UI.
Измерения выполнены одним `flutter_tester` debug на macOS arm64, Dart3.13.5,
viewport390×844; это wall clock CPU diagnostics, не native кадры и не FPS.

<div align="center">

| Сценарий | До | После |
| :---: | :---: | :---: |
| Library, первый mount | 878,4 мс / 32 990 elements | 184,2 мс / 1 417 elements |
| QR60, parent rebuild median / p95, 25 samples | 4,89 / 6,17 мс | 3,16 / 4,80 мс |
| QR1024, parent rebuild median / p95, 25 samples | 22,59 / 23,52 мс | 4,64 / 6,20 мс |
| QR repaint requests, прежний URL | 25 из25 | 0 из25 |
| PDF с JPEG512, median из3 | 372,2 мс | 393,3 мс |

</div>

Library теперь использует `ListView.builder` с прежними controls/spacing/max width,
loading/error/empty/retry и стабильными card keys. QR хранит матрицу в widget State,
пересчитывает при смене URL, при resize повторно размещается; глобального кэша нет.
QR60/1024 — стрессовые encoder inputs, не live publication URLs. PDF не менялся;
разница его времени не заявляется улучшением. Raw evidence:
[baseline](evidence/phase16/2026-10-21-mobile-before.json) и
[повтор](evidence/phase16/2026-10-21-mobile-after.json), один fixture SHA256.

- `flutter analyze --no-pub` — **0 issues**; полный mobile suite — **1367/1367 PASS**.
  Новые regressions: lazy Library/последний элемент/search после scroll;
  QR same URL/change URL/resize. Существующие UID/privacy/Save/late ACK и
  Editor drag/autoscroll tests проходят.
- Home: 36 394 mounted elements, первый mount 1164–1219 мс; Editor:18 093,
  449–535 мс. Это оставшиеся кандидаты для native профилирования, а не
  доказательство достигнутого frame budget. RSS записан как process-wide snapshot;
  снижение retained heap или отсутствие утечек не заявляется.
- Для native DevTools подготовлен изолированный `tool/performance/main.dart`
  с Memory repository: Home/Projects/Editor и настоящий PDF, без LocalRuntime,
  Auth/Firebase или изменения сохранённых данных пользователя. Android AOT profile
  APK этого target собран успешно; сборка не означает device runtime acceptance.
- Browser harness настоящих ContentEditor/AttachmentsEditor/DocumentView,
  production React, Chrome155, Apple M1 Pro, ширины320/390/1440: **6/6 PASS**,
  horizontal overflow0, local Manrope/SVG/avatar загружены, PDF renderer не
  запрашивается до экспорта. После экспорта настоящий PDF298500bytes за3508,7мс.
  Editor mount162–239мс, public133–137мс; JS heap после forced GC7,4/4,3MB.
  Input→two RAF4,2–32,1мс — diagnostic, не field INP. Данные синтетические;
  это проверка компонентов и existing PDF API, не Next SSR/live route.
  [Raw browser evidence](evidence/phase16/2026-10-21-web.json),
  [mobile public layout](evidence/phase16/2026-10-21-web-public-320.png) и
  [desktop Editor](evidence/phase16/2026-10-21-web-editor-1440.png).
- **Открыто Phase 16:** native profile frame/raster/rebuild/retained-memory
  capture, длинный Editor drag/autoscroll, реальная GitHub pagination/cache/network,
  avatar/PDF/Card и сопоставимые device traces/screenshots. В момент замеров `adb devices -l` пуст,
  `xcrun simctl` недоступен; существующий AVD без system image. Полная приёмка
  Phase16 не объявляется. Команды повторения — в CONTRIBUTING.
  В Phase17 использован отдельный Android15 AVD для функциональных SDK checks;
  profile frame/heap captures на нём не выполнялись, performance gates остаются открыты.

### Phase 17 — Testing

**Переход разрешён 2026-10-21.** Отдельные открытые проверки
[Phase 15](#phase-15--developer-card-и-native-sharing) и
[Phase 16](#phase-16--performance) не закрываются результатами этой фазы.

**Задачи**

- [x] Довести unit/widget coverage Auth, scoped saves, migration/backup,
  Library/import/review, необязательных полей, public projection, PDF/Card/QR
  и loading/error/empty/retry; сохранить legacy compatibility regressions.
- [x] Проверить core/browser и связанный Android SDK/controller journeys: новый аккаунт → optional4step onboarding → Project import/
  create → attachment в Editor → Save → durable Home/PDF → sync ACK → явный Publish
  → public URL/Card/QR. Добавить изменение private draft без публикации,
  Unpublish/delete, offline/reconnect, process restart и смену UID.
- [x] Проверить совместимость mobile↔web на Hive8/cloud7/public1|2 и выбранную
  LWW/CAS policy, неизвестные schemas и сохранность архива/старых URL.
- [x] Получить `flutter test --coverage` с coverage **более 40%**, clean analyze
  и сохранённый отчёт; выполнить actual web/backend/Rules commands.

**Проверки и приёмка**

- [x] Локальные unit/widget/contract suites проходят; width320/text2/landscape,
  keyboard/focus, scroll/drag, contrast/targets и reduced motion проверены.
- [x] Journeys подтверждают одно main, отдельный Editor buffer, scoped Library,
  точный backup, server ACK и явную публикацию без смешения состояний.
- [x] Отказы permissions/network, late ACK/retry и owner transition не раскрывают
  предыдущий аккаунт и не теряют saved данные; Android/iOS/live evidence разделён.
- [x] iOS native SDK journey — первоначально отложен2026-10-21; после установки
  Xcode в Phase19 проверен2026-10-24:11 checkpoints в двух процессах.
- [ ] iOS system picker/permissions, full native onboarding/import touch и
  live/APNs приёмка остаются отдельными открытыми проверками.
- [x] Coverage превышает учебный порог40%; web auth guards, public reader,
  publication и двусторонний codec/SDK обмен проверены подходящими suites.

**Готово, когда:** tests/coverage/analyze проходят и сквозной действующий путь
подтверждён. Исторические tests сохраняют совместимость, но не возвращают старый UI.

**Фактический source/local результат — 2026-10-21**

- Полный `flutter test --no-pub --coverage --reporter expanded` — **1372/1372 PASS**,
  `flutter analyze --no-pub` — **0 issues**. LCOV: **13303/15305 =86,92%**
  исполняемых DA-строк, 171 reported source files из203 Dart runtime files.
  Все32 unreported files перечислены в отчёте (exports/interfaces/const catalogs
  и wrapper); они не названы покрытыми. Фильтры/исключения ради порога не добавлялись.
  [Coverage JSON](evidence/phase17/mobile-coverage.json) хранит source/LCOV SHA256,
  denominator и список файлов; [полный LCOV](evidence/phase17/mobile-coverage.lcov).
- `tools/testing/check_coverage.py` проверяет строгий порог **>40%**, не считает
  повторные SF/DA дважды, отклоняет пустой/повреждённый отчёт и source вне `lib`;
  **4/4 Python regressions PASS**. Автоматизация CI остаётся Phase 18.
- Добавлен `main_portfolio_journey_test.dart`: новый main, четыре optional шага,
  manual project + GitHub import, scoped Library Save при dirty Editor/notes,
  attachment + main Save, offline outbox, настоящий close/reopen Hive,
  восстановление exact mutation ACK, изоляция другого UID, cloud7 roundtrip через
  actual web parser и trusted backend projection, public schema2 → Dart Card,
  настоящий saved PDF. Transport здесь **fake**; это core/codec journey,
  не native Firestore SDK acceptance и не сетевой Publish.
- Найден и исправлен воспроизводимый дефект: backend пишет `publishedAt` через
  `serverTimestamp()`, а Card adapter передавал SDK Timestamp в string-only codec.
  Regression сначала RED с `DeveloperCardFailure`, после нормализации Timestamp
  в ISO UTC только на SDK boundary — GREEN; raw snapshot не мутируется.
  Pure domain/public parser и cache/pending/UID ограничения не ослаблены.
- Второй дефект подтверждён RED regression: после inventory refresh первый
  SDK cache/pending error преждевременно завершал Copy/Open/Share через `.future`.
  Action теперь ждёт только server data до20s; cache не используется, withdrawal,
  invalid data и смена owner прекращают ожидание. Три regressions проверяют
  cache→server Copy и late data после withdrawal/owner change; Card suite
  **11/11 PASS**, полный suite **1372/1372 PASS**, настоящий Android Clipboard PASS.
- Web: **163/163 PASS**, typecheck и production build PASS. Backend:
  syntax check и **42/42 PASS**. Полный `npm run test:all-rules`:
  **82/82 PASS** на disposable `demo-stackcard-test` Auth/Firestore/Storage.
  Новый SDK journey проверяет schema2 main Save → explicit Publish → реальный
  public Timestamp → private Save без auto-Publish → stale mutation conflict →
  republish с прежним URL → Unpublish → поздний retry без воскрешения публикации.
  Существующие migration/legacy URL/delete/Rules/Contact/UID tests сохранены.
- Настоящий browser journey: production Next16.4 + Chrome155 + Auth/Firestore
  emulators + standalone Node HTTP API, **7/7 checkpoints PASS**. Проверены
  registration/4step onboarding → manual project → attachment/Save → keyboard
  Escape/cancel/discard → page reload → PDF download → явный Publish с Auth token →
  anonymous Next SSR public reader → private Save без auto-Publish → withdrawal
  через authenticated HTTP → public404 → logout/deep-link guard. Width320/1440
  без overflow, reduced-motion preference включён. Clipboard **stub**, отправки
  кому-либо нет; GitHub import отдельно покрыт core/HTTP suites.
  [Browser evidence](evidence/phase17/web-emulator-journey.json),
  [скриншот actual Editor](evidence/phase17/web-emulator-journey.png),
  [скачанный PDF](evidence/phase17/web-journey.pdf), `%PDF-` signature PASS.
- Responsive suite покрывает7 viewport ×2 text scale ×5 routes, отдельные
  Editor keyboard/drag/autoscroll, Library width320/text2/search/refresh и Card
  narrow/landscape проверки. Theme light/ru сохранена; focus/targets/contrast и
  reduced motion проверяются существующими widget/browser tests. Это не полный
  accessibility audit и не Figma/native visual parity.

**Дополнительно подтверждено на Android — 2026-10-21**

- Изолированный AOSP Android15/API35 arm64 AVD, Flutter3.47.7/Dart3.13.5,
  debug/SwiftShader. Существующий `main_phone` не менялся. На этом Mac найден
  исправный образ в другом установленном SDK; скачивание/ремонт SDK не потребовались.
- `main_portfolio_runtime_test.dart` + `tools/testing/native_journey.py`:
  **11/11 checkpoints PASS**, разные PID **4693/4810**. Настоящие named native
  Auth/Firestore SDK, отдельный Hive/outbox, два процесса, exact server ACK/cloud7,
  HTTP Publish с этим ACK, anonymous public Timestamp → Card, QR/Clipboard,
  private Save без auto-Publish, настоящий переход на другой UID с исчезновением
  QR и Rules denial прежнего private draft, возврат owner, Unpublish и delete.
  [Связанный native отчёт](evidence/phase17/android-emulator-journey.json).
- Registration/onboarding/import здесь исполняются SDK/controller с fixture
  GitHub source; Card/Copy и публикация после смены UID — mounted native UI/
  controller. Это не полный touch journey регистрации/import и не production
  hosting/live public URL. Session restore проверяется до нового sign-in;
  subsequent disposable credential rotation/reauth нужна для UID-switch, пароли/
  токены не сохраняются тестом. Demo account/Hive очищены, emulators остановлены.
- Existing `notification_permission_runtime_test.dart`: настоящий Android
  `POST_NOTIFICATIONS=denied` прочитан дважды, FCM auto-init выключен, token не
  запрашивался; permission flags после проверки побайтно совпадают с исходными.
- Existing `pdf_runtime_test.dart`: настоящий системный Save **PASS**, второй
  picker отменён Android Back — **PASS**. Сохранённые **30884 bytes** идентичны
  generated bytes; pypdf проверил **3 страницы**, кириллицу и ссылки, все страницы
  отрендерены Poppler и просмотрены без обрезки/потери текста.
  [Native checks](evidence/phase17/android-native-checks.json),
  [сохранённый PDF](evidence/phase17/android-saved.pdf),
  render [1](evidence/phase17/android-pdf-page-1.png),
  [2](evidence/phase17/android-pdf-page-2.png), [3](evidence/phase17/android-pdf-page-3.png).
- Runner использует официальный `flutter drive` и сохраняет app data через
  `--keep-app-running --no-uninstall-first` + отдельный force-stop. SDK приложения/
  Rules не ослаблялись ради test tooling; **4/4 native runner guard tests PASS**,
  вместе с coverage tool — **8/8 Python tests PASS**.

**Исторически отложено в Phase17:** iOS native journey и системная приёмка — по
ответу пользователя2026-10-21. В Phase19 Xcode установлен и iOS SDK journey
прошёл2026-10-24; system/live gates сохраняются. Полный native touch smoke
регистрации/import не исполнялся; эти экраны отдельно покрыты widget/browser
suites. Core fake ACK, client SDK emulators, browser и Android SDK/UI перечислены
раздельно. Phase17 целиком с system/live/touch gates не объявляется закрытой.

**Незакрытые проверки прошлых фаз сохранены отдельно:** Phase 15 — native
QR scan/Share/Open, live public URL и iOS; Phase 16 — device DevTools frame/raster/
rebuild/retained-memory traces, длинный Editor drag и реальные GitHub network/cache
сценарии. Эти gates не перенесены в выполненные checkbox и не смешаны с coverage.
Команды повторения — в CONTRIBUTING. Commit/push/deploy не выполнялись.

### Phase 18 — CI/CD

**Переход разрешён 2026-10-23.** Следующий этап подтверждён прямым поручением
пользователя; Phase17/iOS и отдельные Phase15–16 gates сохраняются.

**План выполнения**

1. Закрепить runtime и locked installs по действующим manifests; проверить
   существующие format/asset/coverage команды на чистом окружении зависимостей.
2. Добавить push/PR workflow с отдельными jobs web/backend/emulators/mobile,
   неизменным coverage denominator, debug APK и узкими artifact paths.
3. Проверить YAML и локальные эквиваленты quality gates, включая отказы при
   дефектном coverage/asset; записать результаты и открытый remote gate.
4. После отдельной Git авторизации проверить настоящий GitHub green/red run
   и доступность artifacts. Phase19 автоматически не начинать.

**Задачи**

- [x] Добавить GitHub Actions на push/PR: locked dependency resolution, format,
  analyze, tests/coverage>40%, Android APK build и artifact по actual manifests.
- [x] Добавить actual web typecheck/tests/build/format, backend tests/check,
  demo Firestore/Storage Rules, mobile↔web fixtures и pinned asset integrity.
  Проверять основной portfolio/public2, Firestore avatar и legacy read compatibility.
- [x] Подтвердить failed pipeline при ошибке проверки; исключить secrets/private
  fixtures из логов/artifacts. Signing и release AAB остаются в Phase20.

**Проверки и приёмка**

- [x] Pipeline воспроизводим, запускается на push/PR и отдаёт APK artifact;
  SDK/package-manager versions берутся из текущих configs.
- [x] Ошибка format/analyze/tests/coverage/build делает pipeline неуспешным;
  негативный сценарий проверен.
- [x] Web/backend/Rules и asset checks работают без production credentials,
  billing и автоматического deployment.

**Готово, когда:** проверки проходят на рабочей версии и блокируют дефектную;
APK artifact доступен, release signing/deploy не выполняются без разрешения.

**Фактический source/local результат — 2026-10-23**

- Добавлен `.github/workflows/ci.yml`: push/PR/manual, отдельные assets/web/
  Firebase/mobile jobs и обязательный aggregate `All checks`. Actions закреплены
  полными SHA, checkout не сохраняет credentials, token только contents:read.
  Failed/cancelled/skipped job не превращается в зелёный aggregate.
- Flutter закреплён в `.fvmrc`, Node в `.node-version`, Java в `.java-version`,
  npm через `packageManager` трёх manifests. Проверены locked Flutter resolution
  и чистые npm installs на Node22; Firebase CLI закреплён в package-lock без
  изменения версий прежних зависимостей. Linux SDK archive совпадает с текущим
  Flutter3.47.7/Dart3.13.5/revision, installer использует upstream manifest.
- Формат всего Dart tree331files PASS после автоматического форматирования
  четырёх прежних файлов без изменения поведения/config values. Analyze0,
  **1378/1378 Flutter tests PASS**, настоящий LCOV **13407/15422 =86,93%**,
  173 reported files из205, 32 unreported перечислены без фильтров.
- Web **163/163**, format/typecheck/production build PASS; backend syntax и
  **42/42** unit PASS; полный demo Auth/Firestore/Storage suite **82/82 PASS**.
  Cross-client codecs выполнялись с actual web dependencies. Backend/API live
  не запускались; emulator session остановлена после checks.
- Существующий asset checker дополнен каталогом159 Simple Icons: exact
  inventory/provenance/bytes/SHA256 и vector parser. **4/4** новых failure
  regressions, **8/8** coverage/native runner guards и **15/15** commit-validator
  tests PASS. Actionlint1.7.12 PASS. Нулевой coverage report возвращает1;
  подмена/активный SVG/duplicate inventory отвергаются; aggregate проверен для
  success/failure/cancelled/skipped. Это локальные negative gates, не GitHub red run.
- `flutter build apk --debug --no-pub` PASS из обычного main. APK остаётся в
  ignored build directory; в workflow загружается только точный APK path,
  отдельный artifact содержит только LCOV/summary, срок хранения7дней.
  Release signing/AAB/deploy не добавлены. Существующее предупреждение Flutter
  про KGP в Firebase plugins не блокирует текущую сборку; upgrade SDK/dependencies
  ради предупреждения не выполнялся.
- [Source/local evidence](evidence/phase18/checks.json) содержит versions,
  coverage denominator/hashes, APK size/SHA256 и ограничения. Проверки выполнены
  на macOS/Java25; actual GitHub Ubuntu/Java21, зелёный и намеренно красный run,
  скачивание artifacts остаются открытыми до отдельного разрешённого push.
  Это историческая граница source/local проверки; удалённая приёмка подтверждена ниже.

**Удалённая приёмка и завершение — 2026-10-23**

- [Основной GitHub run](https://github.com/S-NOWNUM-B/app.StackCard/actions/runs/39985614786)
  на `e51359f` — **SUCCESS всех6 jobs**, включая `All checks`. Push проверен
  настоящим запуском; pull_request trigger задан тем же workflow без path filters/
  PR-only условий, YAML проверен actionlint. Отдельный PR в рамках приёмки не создавался.
- Первый Ubuntu run обнаружил24 ложных contrast failures: SDK histogram matcher
  выбирал сглаженные оттенки Manrope вместо заданной краски текста. Полный suite
  перенесён на macos-15/CoreText, Android APK выделен в Ubuntu job после всех
  quality gates. **Все1378 tests, WCAG thresholds, fonts, tokens и runtime UI сохранены.**
  Analyze0, coverage **13407/15422 =86,93%**; web163, backend42, Rules82 PASS.
- [Негативный GitHub run](https://github.com/S-NOWNUM-B/app.StackCard/actions/runs/39985722398)
  на `AIrevision/phase18-coverage-gate` — ожидаемый **FAILURE**. Единственная разница
  workflow с dev — `--minimum 100`. После1378 PASS checker вернул1 на86,93%,
  APK job был skipped, `All checks` — failure. Ослабления/skip tests нет;
  проверочная ветка не объединяется с dev.
- [APK artifact](https://github.com/S-NOWNUM-B/app.StackCard/actions/runs/39985614786/artifacts/12515569979)
  и [coverage artifact](https://github.com/S-NOWNUM-B/app.StackCard/actions/runs/39985614786/artifacts/12515238910)
  скачаны. В них ровно `app-debug.apk`, `lcov.info`, `summary.json` — без env,
  emulator data, private fixtures и logs. Срок хранения7дней; архивные digest и
  APK SHA256 сохранены в [evidence](evidence/phase18/checks.json).
- APK **184009424 bytes**: ZIP CRC PASS, AndroidManifest/classes.dex/Flutter
  assets/native libraries присутствуют; aapt подтвердил `com.example.app_stackcard`
  и debuggable. LCOV SHA256 совпадает с summary; числитель/denominator независимо
  пересчитаны, reported/unreported files сохранены. Raw APK не коммитится.
- **Phase18 завершена.** GitHub artifacts доказывают CI packaging, не релиз/store
  или device acceptance. Прежние iOS/live/QR/profile gates остаются открытыми;
  Phase19 автоматически не начиналась. Billing, deploy, signing и branch rules
  не менялись. Следующий этап — Phase19 только после отдельного поручения.

### Phase 19 — Production hardening

**Задачи**

- [x] Настроить разрешённую бесплатную диагностику/Crashlytics и подтвердить
  тестовый отчёт без UID/contact text/token/private content в error logging.
- [x] Проверить Rules/public projection, bounded avatar/PDF/QR inputs, permanent
  IDs/version, unknown outcomes, late retry, account deletion/withdrawal и
  UID isolation. Новые Storage uploads/TTL/billing не включать.
- [x] Завершить review действующего UI: optional onboarding, три roots,
  saved Home/dirty Editor guard, Library, public Card/QR и unavailable states;
  русский светлый дизайн, Brand A, icon/splash/versioning и privacy policy.
- [x] Перед возможным live запуском отдельно проверить HTTPS origins/CORS/
  App Check, конфигурацию endpoints и recovery. Отложенный hosting не запускать
  автоматически; отсутствие backend не превращать в mock success.

**Проверки и приёмка**

- [x] Диагностический отчёт доставлен, sensitive data отсутствуют в app error payload.
- [x] Значимые security/validation/lifecycle дефекты устранены; permissions
  проверены в final APK/iOS plist: реальные media/notifications сценарии и
  normal network/FCM/Auth SDK permissions, без GPS. Android biometric declarations
  приходят из Firebase Auth → AndroidX Credentials; отдельной biometric функции нет.
- [x] Android/iOS и responsive web проверены по одному main и светлому UI;
  privacy policy объясняет публикацию контактов/фото и сохранение private draft.
- [x] Live preconditions/recovery проверены только в разрешённом окружении;
  граница source, emulator и production evidence явно сохранена.

**Готово, когда:** диагностика подтверждена, значимые security/UX дефекты устранены,
реальное обращение с данными/permissions описано без обещания неподключённого hosting.

**Проверено2026-10-24:** Flutter analyze/format,1386 tests, LCOV13492/15530
(86,88%), web163 tests/typecheck/Next16.4.3 build, backend42 и Rules/service82,
Python tooling11; production audit web/backend0. Final Android APK и обычная iOS
Simulator сборка PASS. Xcode27.1/iOS27.0: native SDK seed/check в двух процессах,
11 checkpoints; Android/iOS UI smoke проверяет три roots, saved/dirty guard,
Library, unavailable publication, diagnostics opt-in/out и privacy help.
Source/SDK/runtime результаты и screenshots — [evidence](evidence/phase19/checks.json).

**iOS диагностика принята:** [Console issue](https://console.firebase.google.com/project/stackcard-dev-snownumb/crashlytics/app/ios:com.example.appStackcard/issues/053e5a3192e3e02df7b81355cc8877d9)
содержит `StackCard.acceptance`, stack `StackCard.redacted` и только
`flutter_error_exception=StackCard.acceptance`; logs/breadcrumbs пусты, Analytics
выключен, Data содержит только технические device/OS/app metadata.
Matching dSYM UUID `E371B022-F1B3-3ADA-B005-B4A91926758B` (`Runner.debug.dylib`)
имеет статус Uploaded. Пользователь отдельно разрешил текущую загрузку и
следующие auto-uploads; full bundle передаётся в foreground, upload error
останавливает build. Обычная iOS Simulator сборка с этим script тоже PASS.
Physical QR scan, system Share/Open/PDF picker, iOS/APNs, live hosting и
DevTools/Figma/release gates прежних фаз этим не объявляются закрытыми.

### Phase 20 — Release

**Задачи**

- [ ] Утвердить application IDs/signing, безопасно сохранить Android keystore,
  собрать подписанный release AAB с obfuscation и сохранить symbols.
- [ ] Проверить release на устройстве: optional onboarding, Home/Projects/Editor,
  avatar/manual city, saved PDF, явный Publish/Card/QR и отказ недоступного сервиса.
- [ ] Подготовить screenshots/описание/privacy policy нового white-only/ru UI:
  одно портфолио и три roots, без старых libraries/wizard/GPS/project photos.
- [ ] Подготовить Google Play internal testing либо AAB/материалы при отсутствии
  developer account. Распространение/App Distribution выполнять только по запросу.
- [ ] Добавить настоящие download links после появления релиза; отдельно проверить
  iOS build/document picker/sharing/APNs и описать шаги App Store/демонстрации.

**Проверки и приёмка**

- [ ] Подписанный Android release проверен на устройстве; signing и symbols
  сохранены безопасно, секретов в repo/artifacts нет.
- [ ] Материалы соответствуют одному main, текущим screens и реальной
  доступности backend/public URL; неподключённые возможности не обещаны.
- [ ] Выполнен только разрешённый способ распространения; download links ведут
  к настоящему release, web/API deployment разрешён и проверен отдельно.
- [ ] iOS результат указан отдельно; Android AAB не доказывает iOS/App Store release.

**Готово, когда:** release проверен, материалы готовы, разрешённый канал
распространения работает. Новая платная инфраструктура, публикация в store и
постоянный web/API hosting требуют отдельного поручения.

**История Phase 0–14 сохранена. Действующая реализация — ADR 0005, source/local
Phase 15–16 и source/local результаты Phase17; Phase18 CI/CD завершена и проверена2026-10-23.
Phase19 завершена2026-10-24, Phase20 остаётся планом. Новые local checks
не закрывают прежние live/iOS/Figma/release gates.**

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

### Проверка требований недель 7–8 — 2026-10-10

Аудит 2026-10-10 сохраняет результаты на дату проверки. Последующее обновление
2026-10-11: Android Google-вход и восстановление сессии приняты по Phase 7.
Полное соответствие неделе 8 требует повторяемой FCM-демонстрации и учебных
материалов; постоянный backend отложен владельцем проекта.

| Требование | Фактический результат текущей проверки |
| --- | --- |
| GoRouter, параметры, nested navigation, protected redirect | **190/190 PASS**: account navigation, widget, responsive и state management suites. Четыре stateful root-вкладки сохраняют свою навигацию, проверены UID transitions и безопасный возврат после входа. |
| Телефон/планшет, portrait/landscape | Responsive suite входит в указанные 190 tests: **168 PASS**, семь размеров от 320×568 до 1024×768, две темы, text scale 1×/2×, шесть экранов. Это headless widget evidence; физические телефон/планшет и iOS в этом аудите не запускались. |
| Email/password, Firestore sync, notifications logic | Отдельный focused Flutter suite — **112/112 PASS**. В живом dev Firebase зарегистрированы два demo email/password аккаунта; sign out/relogin и owner server read/write прошли через клиентский SDK. Native offline/restart/LWW evidence сохраняется в Phase 8. |
| Google Authentication | Google provider включён после подтверждения владельцем support email и названия StackCard Development. Android config заново получена Firebase CLI: Android OAuth связан с package/debug SHA-1, web OAuth client доступен Gradle plugin. Native real Google suite запущена и ожидает вход владельца в системном экране Android; mocked tests не закрывают этот пункт. |
| Firestore Security Rules | **30/30 PASS** на demo эмуляторе. Actual deployed Rules совпадают с repository source. Live client SDK отклонил чтение A→B, B→A и anonymous→A с `permission-denied`. Firebase остаётся Spark без billing. |
| Push на устройстве | Историческая Android live acceptance **5/5 PASS** описана в Phase 14. В обычной сборке без `CONTACT_INBOX_API_URL` registration unavailable; постоянный hosting отложен пользователем. Для текущей демонстрации push требуется отдельно подключённый HTTPS backend. iOS/APNs остаются открытыми. |
| РК1 | Оценка и сдача заданий недель 1–7 относятся к преподавателю; наличие runtime/tests не подтверждает выставленные баллы или сдачу материалов. |

Для просмотра реальных коллекций созданы аккаунты с вымышленными профилями
Айданы Сейтовой и Данияра Омарова. Auth emails используют `example.invalid`:
вход работает, почтовые сообщения на эти адреса недоступны. Каждый owner имеет
`accounts/{uid}` с lifecycle metadata и `accounts/{uid}/drafts/current` schema 6:
private notes, profile, skills, experience, education, links, Projects Library,
Resume/Portfolio snapshots и связь Portfolio→Resume. Коллекции проектов и
резюме отдельно не создавались: они входят в existing `content` aggregate.
Публикация и фиктивные push tokens не создавались; passwords/tokens не входят
в Firestore или Git. Account delete/cleanup не выполнялись.

Для завершения учебной приёмки остаются подключение FCM backend для повторяемой
демонстрации и материалы РК1. Android Google live sign-in и восстановление
сессии приняты последующей проверкой 2026-10-11 (Phase 7).
Недельный аудит не запускает следующую продуктовую фазу и не закрывает
полную iOS/release/Figma приёмку.

### Упрощение мобильных текстов — 2026-10-11

По прямому поручению пользователя очищены Home, вход/регистрация, Settings,
Projects, редакторы Resume/Portfolio, Inbox и уведомления: убраны постоянные
поясняющие абзацы, demo/будущие этапы и технические сведения о локальном режиме,
placeholder и Firebase. Пустые списки оставляют один короткий заголовок.
Проектные ссылки названы «Ссылка на проект», фото — с краткой причиной disabled
состояния; ошибки, несохранённые изменения и подтверждения опасных действий
сохранены. Ru/en обновлены вместе; shared `StackCardStateView` допускает
отсутствие дополнительного сообщения. Правило copy — в existing design guide.

- Focused mobile gate: **384/384 PASS** в 18 существующих suites: auth/navigation,
  settings/localization, responsive, project/document editors, media, persistence,
  GitHub, Inbox и publication UI. Ожидания прежних надписей обновлены; проверка
  контактов при text2 подтвердила читаемость короткой подписи Email.
- Итоговый `flutter analyze --no-pub`: **0 issues**; format затронутых Dart files
  и `git diff --check`: **PASS**. Full mobile suite и backend/web не повторялись.
- Обычная Android debug сборка установлена на `emulator-5554` без uninstall/clear.
  Actual вход/Home/Project editor и блок обложки/ссылок просмотрены; тестовые
  проекты не сохранялись. Это не новая Firebase/Google/FCM или iOS приёмка.

Логи: `/private/tmp/stackcard-ui-copy-verified-tests.log`,
`stackcard-ui-copy-final-analyze.log`, `stackcard-ui-copy-final-native.log`;
снимки `stackcard-ui-copy-screen.png`, `stackcard-ui-copy-home.png`,
`stackcard-ui-copy-project-editor.png`, `stackcard-ui-copy-project-cover.png`.

### Упрощение мобильных настроек — 2026-10-11

Итоговое поручение: сначала список настроек, затем линия 1dp в отступе 16dp
и строка аккаунта. «Выйти» — красный текст без фона, обводки и карточки;
компактная иконка также красная. Гостевые подписи и перенос черновика удалены из Settings
и общей account section; legacy storage/transfer API сохранены без изменения
данных. Подтверждение выхода с несохранёнными правками сохранено.

- Focused gate: **129/129 PASS** — session/removed transfer UI (27), responsive
  Settings (14), auth/navigation/account management/settings/local accounts (88).
- `flutter analyze --no-pub`: **0 issues**; format пяти затронутых Dart files
  и `git diff --check`: **PASS**.
- Светлое Flutter-превью с тестовым аккаунтом отрендерено и просмотрено:
  `/private/tmp/stackcard-settings-account.png`. Native install не выполнялся:
  существующий `emulator-5554` был offline, после ADB reconnect устройств нет.
  Full suite, новая live Auth/iOS приёмка и Git delivery не выполнялись.

Промежуточное уточнение пользователя: обводка «Выйти» убрана; между аккаунтом и настройками
добавлена линия 1dp по ширине содержимого, в прежнем отступе 16dp.
Button/session/removed transfer UI suites: **83/83 PASS**, analyze **0 issues**,
format и diff check — **PASS**; обновлённое Flutter-превью просмотрено.

Последнее уточнение заменяет прежний порядок: аккаунт внизу, после разделителя.
`StackCardButtonRole.dangerQuiet` расширяет существующую кнопку для красного
текстового действия без фона и контура; прежние destructive controls сохраняют
свою роль. Button/session/removed transfer UI suites: **91/91 PASS**,
analyze **0 issues**, format и diff check — **PASS**; итоговое Flutter-превью просмотрено.
