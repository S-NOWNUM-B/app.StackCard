<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="public/branding/stackcard-v2-mark-paper.svg">
  <img src="public/branding/stackcard-v2-mark-ink.svg" width="64" height="64" alt="Логотип StackCard — Brand A">
</picture>

# StackCard Web

**Сайт, редактор единого портфолио и публичная страница владельца**

![Next.js 16.4.0](https://img.shields.io/badge/Next.js-16.4.0-000000?style=for-the-badge&logo=nextdotjs&logoColor=white)
![Firebase JS 13.0.0](https://img.shields.io/badge/Firebase_JS-13.0.0-FFCA28?style=for-the-badge&logo=firebase&logoColor=000000)

</div>

---

## Содержание

- [Назначение](#назначение)
- [Что хранится здесь](#что-хранится-здесь)
- [Типовые сценарии](#типовые-сценарии)
- [Запуск и проверка](#запуск-и-проверка)
- [Бесплатное окружение Spark](#бесплатное-окружение-spark)
- [Правила](#правила)

---

## Назначение

Next.js-приложение включает главную, возможности, сценарии, примеры, помощь,
страницу проекта и приложения, Firebase-вход, защищённый кабинет и публичные
документы. Web использует ту же профессиональную
базу, библиотеку проектов и одно основное портфолио, что и mobile. Новый
контракт — [ADR 0005](../../docs/decisions/0005-single-main-portfolio.md);
независимые Resume/Portfolio сохранены как совместимый архив прежнего D048.
Актуальные версии и команды хранятся в [package.json](package.json),
точные зависимости — в [package-lock.json](package-lock.json).

Поручение 2026-10-11 адаптирует композицию Openship под StackCard:
белые поверхности, чёрные CTA, крупная типографика и русские тексты.
[Web brief](../../docs/redesign/web-openship.md) фиксирует новый target,
сохраняя Brand A, локальный Manrope, исходные SVG и широкую/узкую компоновку.
Web отображает все документы в светлой теме; прежняя сохранённая тема остаётся
в совместимой mobile/cloud schema без миграции при чтении.
Историческое no-preview/run относится к прежним проверкам; D048 разрешает
browser и native-проверки текущей задачи. Headless-проверки и сборка отдельно
от визуальной приёмки, production-конфигурации и deploy.

---

## Что хранится здесь

<div align="center">

| **Материал**                                        | **Назначение**                                                                    |
| :-------------------------------------------------- | :-------------------------------------------------------------------------------- |
| `src/app`                                           | Маршруты и общие CSS tokens                                                       |
| `src/components`                                    | Общие controls, формы, кабинет и документный renderer                             |
| `src/lib/model.ts`, `draft-repository.ts`           | Mobile-совместимый private aggregate и запись с проверкой серверной версии        |
| `src/lib/publication.ts`, `publication-contract.ts` | Trusted HTTP API, metadata операций и проверки подтверждений                      |
| `src/lib/public-document.ts`                        | Строгий anonymous-reader только опубликованных snapshots                          |
| `public`                                            | Исходные Brand A, Manrope, icons и лицензии                                       |
| `tests`                                             | Совместимость реальной Dart fixture, публикация, public reader и account recovery |

</div>

---

## Типовые сценарии

### Познакомиться с проектом и открыть редактор

`/` и маркетинговые страницы сохраняют прежнюю композицию и примеры D048.
Новый ежедневный интерфейс владельца находится в `/workspace`. `/features`, `/use-cases`, `/about`
раскрывают возможности и назначение StackCard; `/help` объясняет начало работы,
сохранение, публикацию и приватность. `/examples` объединяет образцы.
`/download` показывает наличие
способов установки без выдуманных store-ссылок. `/examples/resume` и
`/examples/portfolio` показывают явно обозначенные примеры.

`/sign-in`, `/sign-up` и `/reset-password` используют Firebase Auth: пароль
или Google. Почта входа не переносится в публичные контакты автоматически.
Пароль и подтверждение можно показать. Регистрация согласована с mobile:
8–128 Unicode-символов, проверка очевидных повторов и совпадения с почтой;
правила показывают текущий результат. Вход существующих аккаунтов не ограничен
новой локальной политикой, дополнительные требования Firebase обрабатываются SDK.
Если Firebase config отсутствует, вход сообщает о недоступности; фиктивной
сессии или тестового владельца в runtime нет.
Ссылки на разделы кабинета сохраняют выбранный раздел при переходе через вход,
регистрацию или восстановление пароля; returnTo ограничен owner маршрутами.

### Заполнить одно основное портфолио

`/workspace` требует реального UID. Три нижние вкладки — «Главная», «Проекты» и
«Редактор». Настройки открываются через шестерёнку рядом с Brand A. Прежние
owner маршруты базы, резюме и документов направляют в единый редактор.

На «Главной» отображается только последняя подтверждённая сохранённая версия.
Поля и управление проектами доступны в «Редакторе» и «Проектах». Профиль,
контакты, навыки, опыт и образование необязательны; пустое портфолио сохраняется.
Пустые разделы не отображаются. Ссылки и добавленные записи проходят прежнюю
строгую проверку. Ручной «Город / страна» входит в портфолио; GPS и постоянных
географических разрешений в новом интерфейсе нет.

При наличии прежних данных владелец один раз выбирает общую базу или документ
после просмотра переноса. Тексты не смешиваются. Выбранный ID и постоянная
публичная ссылка сохраняются, остальные документы и точная legacy-копия остаются
в aggregate для восстановления. Ранее запрещённые location/contacts не переносятся
в основной документ автоматически. Перенос не меняет публичную версию.

Библиотека проектов использует компактные строки без пользовательских изображений.
Для проекта выбирается стабильный ID из встроенного каталога Lucide. Добавление
в портфолио происходит только из библиотеки; удаление связи сохраняет проект.
Удаление проекта после подтверждения сохраняется отдельно и убирает связи со всеми
документами. GitHub-репозиторий и уже опубликованный snapshot не удаляются.

Импорт показывает реальные страницы репозиториев одного root `githubUsername`,
поиск по загруженным страницам и множественный выбор. Неполный поиск явно
обозначен; «Загрузить ещё» использует следующую страницу API. Repository ID
предотвращает дубликаты; уже импортированные записи и ручные overrides сохраняются.
Импорт выполняет scoped transaction и переживает перезапуск, сохраняя соседний
несохранённый ввод редактора. Он не добавляет проекты в портфолио и не публикует.
Кеш репозиториев изолирован по UID и профилю; его очистка не удаляет workspace.

Новый пустой workspace получает четыре необязательных шага персонализации:
GitHub, имя/должность, описание/город, фотография. «Далее», «Пропустить», «Назад»
и «Готово» сохраняют progress в том же UID-bound aggregate. Перезапуск продолжает
сохранённый шаг, завершённый сценарий не повторяется; пустые поля не определяют
завершение. Existing workspace сначала проходит явный совместимый перенос.

Web online-first: чтение идёт с сервера; «Сохранить» выполняет transaction по
captured basis `accounts/{uid}/drafts/current`, пишет cloud schema7 и ждёт ACK.
Readers принимают 1–7. Unknown fields/schema, чужие media и CAS-конфликт
блокируют запись, сохраняя ввод. Во время Save можно продолжать редактирование:
ACK не заменяет поздние правки. После неизвестного результата повтор сначала
подтверждает прежний mutation ID. Смена UID очищает private состояние и поздние
ответы не применяются к следующему аккаунту.

«Скачать портфолио» создаёт настоящий PDF сохранённого содержимого с Manrope,
кириллицей, переносами страниц, URI-ссылками, фотографией и встроенными иконками.
Навигация, поля, изображения проектов и пустые разделы в файл не входят.
Недоступное legacy-фото сообщает об ошибке вместо ложного полного экспорта.
Если сохранился только URL фотографии, клиент пробует CORS-загрузку с публичного
HTTP(S) адреса без cookies, редиректов и proxy: максимум 2 MiB и 10 секунд.
MIME, сигнатура и размеры проверяются до декодирования; существующая обработка
уменьшает изображение до JPEG512 без EXIF. При наличии owner media path он имеет
приоритет: ошибка его чтения не переключает PDF на внешний URL.

«Поделиться» передаёт подтверждённый постоянный `/d/<publicId>` через Web Share
или clipboard/manual fallback. Неопубликованная версия требует явного подтверждения;
при изменении сохранённой версии можно обновить публикацию или отправить существующую.
Обычный Save не публикует. Неизвестная операция использует прежний operation ID и
проверку статуса. При недоступном backend нет фиктивной ссылки или успеха.

Настройки аккаунта сохраняют реальную Firebase security/provider механику и
повторное подтверждение чувствительных действий. `/account-deletion` восстанавливает
ранее подтверждённый запрос по локальной квитанции без password/token.
Внизу настроек после разделителя — строка владельца и красный текст «Выйти».
Inbox (`#inbox`, обращение `#inbox/32hex`) читает server-only данные своего UID,
50 newest-first с пагинацией; не зависит от draft и push. Browser push не подключён.

### Посмотреть опубликованный документ

`/d/[publicId]` принимает permanent 32hex ID и читает только
`publicDocuments/{publicId}` через anonymous REST. Публичный reader принимает schema1/2; новый writer schema2 содержит
allowlist основного портфолио со стабильными иконками и без изображений проектов,
legacy архива, private notes, GitHub source и onboarding metadata; private draft не служит fallback.
Отсутствующий или отозванный документ и недоступность сервиса имеют честные
состояния. Новые outputs не содержат attached Resume. Старые schema1 URL и snapshots
сохраняются; они не перепубликуются автоматически.
Public media ограничены данным ID/версией; private paths и bearer URLs не принимаются.

Contact form появляется только при открытом projected email/phone/Telegram
и visible links block. `NEXT_PUBLIC_CONTACT_INBOX_API_URL` указывает на
trusted `contactInbox`; production требует `NEXT_PUBLIC_APP_CHECK_SITE_KEY`
зарегистрированного score-based reCAPTCHA Enterprise provider и consumed limited-use token. Отсутствие
конфигурации показывает unavailable. Server повторно проверяет публикацию/privacy,
применяет honeypot/validation и transactional HMAC quotas по
[ADR 0004](../../docs/decisions/0004-contact-inbox-notifications.md). Unknown retry
использует прежний requestId и payload; ACK сохраняет более поздний текст.
Anonymous receipt не раскрывает UID/почту автора. Browser push не подключён.
Metadata и body используют один snapshot в пределах запроса. OpenGraph/Twitter
берут выбранное опубликованное фото; отсутствующий сервис показывает retry/noindex,
снятая или отсутствующая публикация — 404/noindex.

---

## Запуск и проверка

macOS — zsh/bash; Windows для dev — WSL/Ubuntu. Рабочая директория `apps/web`.
Нужна поддерживаемая Node-версия из `package.json`.

```bash
npm ci
cp .env.example .env.local
npm run dev
```

Заполните [публичный env example](.env.example) web config того же Firebase
проекта, что и mobile. Admin credentials здесь не нужны. URL публикации —
полный адрес trusted `documentPublication`; web origin — фактический origin сайта.
Настройте разрешённые Auth domains/providers и опубликуйте согласованные Rules
и backend по [Firebase scope](../../docs/AI/scopes/firebase.md).
Команды установки и dev не выполняют deploy.

Локальные эмуляторы разрешены только для отдельного `demo-` проекта.
Порты берутся из [firebase.json](../../firebase/firebase.json) и `.env.example`;
флаги эмуляторов должны совпадать для browser SDK и публичного SSR reader.
Без Firebase config можно просмотреть marketing и явно обозначенные примеры.

```bash
npm run typecheck
npm test
npm run format:check
npm run build
npm start
```

`npm test` использует Node `--import tsx`, чтобы не создавать отдельный IPC
socket CLI. Production build не нужно выполнять параллельно с dev в одном
`.next`: остановите dev перед сборкой. `.next`, `.env.local` и dependencies
не входят в Git. Применяемый scoped gRPC override исправляет advisory
[GHSA-m9gg-hp2v-232j](https://github.com/advisories/GHSA-m9gg-hp2v-232j)
в транзитивном Node-пакете Firebase; private SDK остаётся browser-only.

---

## Бесплатное окружение Spark

Постоянный запуск Contact/Inbox/FCM отложен по решению пользователя 2026-10-10:
своего hosting пока нет. Реализация сохранена, Android live acceptance — **5/5 PASS**;
результаты и отдельные iOS/release gates — в [Phase 14](../../docs/product/product-spec.md#phase-14--contact--inbox--fcm).
До подключения оставьте API URLs и App Check site key пустыми: существующий UI
сообщает о недоступной форме и публикации, опубликованные контакты остаются доступны.
Inbox продолжает читать ранее сохранённые обращения через Firestore при настроенном
Firebase-входе; получение новых обращений и push требует работающего backend.

Firebase остаётся на Spark: Auth, Firestore и FCM работают в пределах бесплатных
квот. Новая фотография проходит существующую обработку медиа: JPEG размером
до 512 px и 256 KiB без EXIF хранится в неизменяемом Firestore-документе владельца;
Firebase Storage и Blaze для неё не нужны. При явной публикации доверенный
сервис проверяет и перекодирует фото, затем помещает ограниченный data URI
в публичный snapshot. Legacy Storage objects не удаляются автоматически.
Rules/backend и настоящий HTTPS endpoint требуют отдельной настройки и проверки
среды. Доверенный API можно запустить обычным Node-процессом из
[`firebase/functions/src/server.mjs`](../../firebase/functions/src/server.mjs),
переиспользуя те же Contact и Publication services. Firebase Functions и App
Hosting для этого запуска не нужны. Параметры API и его порт принадлежат
[`firebase/functions/.env.example`](../../firebase/functions/.env.example).

Настройте private окружение backend: actual project, точный HTTPS web origin,
intended App Check web app ID, HMAC secret не короче 32 символов и стандартные
Firebase Admin ADC. Credentials и HMAC не входят в web env, Git или logs.
Runtime principal ADC требует `roles/firebaseappcheck.tokenVerifier` для consumed
token, а также прав используемых Auth/Firestore/FCM APIs. Временное право личному
owner после live-теста снято; оно не считается настройкой постоянного backend.
Сервер слушает только loopback; `GET /health` возвращает минимальный статус,
`/contactInbox` и `/documentPublication` сохраняют существующие HTTP-контракты.
Запуск backend из `firebase/functions`, macOS — zsh/bash, Windows — WSL/Ubuntu:

```bash
npm ci
node --env-file=.env.local src/server.mjs
```

В `apps/web/.env.local` укажите фактические HTTPS адреса API с соответствующими
paths и origin самого Next.js сайта. Зарегистрируйте Web app в Firebase App Check
с [reCAPTCHA Enterprise score key](https://firebase.google.com/docs/app-check/web/recaptcha-enterprise-provider),
разрешив точный hostname сайта; ключ помещается в `NEXT_PUBLIC_APP_CHECK_SITE_KEY`.
После заполнения `NEXT_PUBLIC_*` пересоберите сайт (`npm run build`), затем
запустите `npm run start -- --hostname 127.0.0.1` за своим HTTPS reverse proxy.
Клиент получает новый limited-use token на каждую отправку или retry, backend
потребляет его и проверяет intended app ID. Auto-refresh выключен. Auth domain
сайта должен быть разрешён в Firebase Authentication.

Для live DEV-проверки Next.js и API можно временно открыть через
[Cloudflare Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).
Они не требуют аккаунта или домена, но URL меняется после перезапуска и работает
лишь пока запущены локальные процессы. Такой адрес не считается постоянным
production deployment. После смены hostname обновите App Check/Auth domains,
точный backend origin и web env, затем пересоберите Next.js: `NEXT_PUBLIC_*`
фиксируются при build. Не подставляйте прежний временный адрес в новые публикации.

Без live Storage bucket доступна публикация новой фотографии из Firestore.
Перенос и очистка legacy Storage media возвращают `storage-unavailable`,
а status/inventory остаются доступными. Удаление аккаунта без Storage разрешается
лишь после явного подтверждённого оператором cutover и проверки, что аккаунт
создан после него и не содержит legacy данных; иначе сохраняется тот же blocker.
Cutover принадлежит private backend env, его нельзя включать по предположению.
Firebase Storage
[требует Blaze даже для существующих buckets](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).
Поэтому `PUBLIC_STORAGE_BUCKET` в live Spark backend остаётся пустым. Bucket и
App Check bypass разрешены только для `demo-*` с actual loopback Auth/Firestore
emulators; для bucket нужен также loopback Storage emulator. Demo-проверки и
мокированный транспорт не подтверждают live FCM или переход по уведомлению.

---

## Правила

- Перед работой прочитайте [общие правила](../../docs/AI/AGENTS.md),
  [AI router](../../docs/AI/README.md) и [web scope](../../docs/AI/scopes/web.md).
- Shared controls и tokens принадлежат `ui.tsx` и `globals.css`; сохраняйте
  исходные asset bytes и лицензии. Figma screenshot не runtime asset.
- Обновляйте общий data contract вместе с mobile/backend и проверяйте
  [schema6 fixture](../../fixtures/workspace/schema6.json). Не вводите второй aggregate.
- Route guard отвечает за UX; доступ обеспечивают Firebase Rules и trusted backend.
  Смена UID сбрасывает private state. Не храните credentials в journal или logs.
- Сохраняйте разделение Save и Publish, CAS, action proof и retry того же ID.
  Публичная страница читает только allowlist опубликованного snapshot.
- Полные контракты и продуктовый статус — в [архитектуре](../../docs/architecture/architecture.md)
  и [плане](../../docs/product/product-spec.md#план-разработки); этот README описывает приложение.
