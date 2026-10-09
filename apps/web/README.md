<div align="center">

# StackCard Web

**Сайт, редактор общей базы и публичные резюме и портфолио**

![Next.js](https://raster.shields.io/badge/Web-Next.js-09090B?style=for-the-badge)
![Firebase](https://raster.shields.io/badge/Data-Firebase-C7FF1A?style=for-the-badge)

</div>

---

## Содержание

- [Назначение](#назначение)
- [Что хранится здесь](#что-хранится-здесь)
- [Типовые сценарии](#типовые-сценарии)
- [Запуск и проверка](#запуск-и-проверка)
- [Правила](#правила)

---

## Назначение

Next.js-приложение включает главную, страницу приложения, Firebase-вход,
защищённый кабинет и публичные документы. Web использует ту же профессиональную
базу, Projects Library и независимые Resume/Portfolio, что и mobile.
Актуальные версии и команды хранятся в [package.json](package.json),
точные зависимости — в [package-lock.json](package-lock.json).

Дизайн основан на [принятых поверхностях R6](../../docs/redesign/screens.md#r6--веб-поверхности):
Lime Brand A, локальный Manrope, исходные SVG и широкая/узкая компоновка.
Историческое no-preview/run относится к прежним проверкам; D048 разрешает
browser и native-проверки текущей задачи. Headless-проверки и сборка отдельно
от визуальной приёмки, production-конфигурации и deploy.

---

## Что хранится здесь

<div align="center">

| **Материал** | **Назначение** |
|:---|:---|
| `src/app` | Маршруты и общие CSS tokens |
| `src/components` | Общие controls, формы, кабинет и документный renderer |
| `src/lib/model.ts`, `draft-repository.ts` | Mobile-совместимый private aggregate и запись с проверкой серверной версии |
| `src/lib/publication.ts`, `publication-contract.ts` | Trusted HTTP API, metadata операций и проверки подтверждений |
| `src/lib/public-document.ts` | Строгий anonymous-reader только опубликованных snapshots |
| `public` | Исходные Brand A, Manrope, icons и лицензии |
| `tests` | Совместимость реальной Dart fixture, публикация, public reader и account recovery |

</div>

---

## Типовые сценарии

### Познакомиться с проектом и открыть редактор

`/` объясняет разделение базы и документов. `/download` показывает наличие
способов установки без выдуманных store-ссылок. `/examples/resume` и
`/examples/portfolio` показывают явно обозначенные примеры.

`/sign-in`, `/sign-up` и `/reset-password` используют Firebase Auth: пароль
или Google. Почта входа не переносится в публичные контакты автоматически.
Если Firebase config отсутствует, вход сообщает о недоступности; фиктивной
сессии или тестового владельца в runtime нет.

### Редактировать базу и независимые документы

`/workspace` требует реального UID. Четыре раздела дают доступ к общей базе,
резюме, Projects Library и портфолио. Документы можно создать, изменить,
дублировать, просмотреть и удалить. Один проект хранится в Library и имеет
отдельные title/description/contribution overrides в каждом документе.
Обновление из базы фиксирует сравнение с загруженной серверной версией.
Фото выбирается целиком; локальные варианты остаются, если их не выбрать.
Изменение документа во время сравнения требует открыть его заново. Применение
меняет только форму, сохранение остаётся отдельным действием.

Web online-first: загрузка идёт с сервера; Save выполняет transaction по
прочитанной версии `accounts/{uid}/drafts/current`, записывает cloud schema6
и ждёт ACK. Неподдерживаемая schema, чужие media и конфликт блокируют запись,
сохраняя введённые данные. Private notes, snapshots и owner data не читаются SSR.
Во время Save можно продолжать ввод: ACK подтверждает захваченную версию,
более поздние правки сохраняются отдельным следующим Save. После неизвестного
ответа повтор сначала подтверждает прежний mutation ID, сохраняя новый buffer.

Публикация — отдельное действие доверенного Firebase сервиса. Publish фиксирует
сохранённый snapshot; Unpublish отзывает доступ, сохраняя постоянный ID.
Удаление документа снимает публичную страницу и удаляет его из aggregate.
Неизвестный ответ сохраняет тот же operation ID для проверки и повторения;
повторное действие не создаёт новую операцию. Отозвать существующую публикацию
можно и при несохранённых правках формы.

Настройки аккаунта работают через Firebase SDK с повторным подтверждением
личности для чувствительных действий. `/account-deletion` восстанавливает
статус уже подтверждённого удаления по локальной квитанции после потери сессии.
Квитанции не содержат password или Firebase token. Из настроек доступен Inbox
(`/workspace#inbox`, обращение — `#inbox/32hex`): server-only чтение своего UID,
50 newest-first с пагинацией и явная отметка прочтения. Inbox независим от draft;
неподдерживаемые данные блокируют отображение обращения. Смена UID/страницы
не применяет поздние ответы к новой сессии.

### Посмотреть опубликованный документ

`/d/[publicId]` принимает permanent 32hex ID и читает только
`publicDocuments/{publicId}` через anonymous REST. Публичная schema1 содержит
allowlist выбранных данных; private draft не служит fallback.
Отсутствующий или отозванный документ и недоступность сервиса имеют честные
состояния. Прикреплённое резюме открывается только пока оно независимо опубликовано.
Public media ограничены данным ID/версией; private paths и bearer URLs не принимаются.

Contact form появляется только при открытом projected email/phone/Telegram
и visible links block. `NEXT_PUBLIC_CONTACT_INBOX_API_URL` указывает на
trusted `contactInbox`; production требует `NEXT_PUBLIC_APP_CHECK_SITE_KEY`
зарегистрированного reCAPTCHA v3 provider и consumed limited-use token. Отсутствие
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
