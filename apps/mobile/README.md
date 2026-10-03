<div align="center">

# StackCard Mobile

**Flutter-клиент для Android и iOS с мобильным редактором общего портфолио**

![Mobile Android + iOS](https://raster.shields.io/badge/Mobile-Android_%2B_iOS-09090B?style=for-the-badge)
![Stage Phase 5 Local persistence](https://raster.shields.io/badge/Stage-Phase_5_Local_persistence-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Назначение](#назначение)
- [Что хранится здесь](#что-хранится-здесь)
- [Типовые сценарии](#типовые-сценарии)
- [Локальная разработка](#локальная-разработка)
- [Правила](#правила)

---

## Назначение

Мобильное приложение StackCard — самостоятельный редактор портфолио, который
будет использовать тот же аккаунт, draft и правила публикации, что и web.
Offline draft/cache и нативные функции относятся к мобильному клиенту.

GitHub Import загружает публичный профиль и repositories через Dio.
Phase 5 добавляет Hive cache с offline fallback, отдельный draft заметок и
сохранение настроек с реальными переводами ru/en.
Sign In, Home, Portfolio, Projects и Settings продолжают получать demo/mock data;
общий app shell и Material 3 light/dark сохранены. Core-портфолио, backend,
полный Builder и публикация развиваются по roadmap. Phase 5 завершена;
статус и результаты проверок — в
[product spec](../../docs/product/product-spec.md#phase-5--local-persistence--offline).
ThemeMode/Locale/preferences управляются Provider; product state, repository
loading и DI — Riverpod. Их границы и
учебная эволюция описаны в
[state management guide](../../docs/learning/state-management.md).
Сайт развивается отдельно в [apps/web](../web/README.md)
на Next.js; desktop и Flutter web targets в mobile не входят.

---

## Что хранится здесь

<div align="center">

| **Материал** | **Назначение** |
|:---|:---|
| [lib/main.dart](lib/main.dart) | Bootstrap, восстановление runtime до `StackCardApp`, ProviderScope и lifecycle GoRouter |
| [lib/app](lib/app/) | LocalRuntime composition, GoRouter и адаптивный app shell |
| [lib/core/state](lib/core/state/) | Нейтральные settings contracts и AppearanceController для ThemeMode/Locale/preferences через Provider |
| [lib/core/storage/local_storage.dart](lib/core/storage/local_storage.dart) | Hive boxes в Application Support, изоляция cache/draft и сохранность повреждённых файлов |
| [lib/core/localization](lib/core/localization/) | Согласованные UI-каталоги ru/en и Localizations delegate |
| [lib/core/theme](lib/core/theme/) | Утверждённая палитра, Material 3, typography, spacing/radius |
| [lib/shared/widgets](lib/shared/widgets/) | Используемые общие widgets, loading/error/retry и async view |
| [lib/features](lib/features/) | Auth/profile/projects/github_import/portfolio_draft: presentation/domain/data и public APIs; portfolio read model, Home и Settings |
| [lib/features/github_import/github_import.dart](lib/features/github_import/github_import.dart) | Публичный API GitHub Import; DI связывает repository, clock и response cache, native bootstrap подставляет Hive adapter |
| [lib/features/portfolio_draft/portfolio_draft.dart](lib/features/portfolio_draft/portfolio_draft.dart) | Отдельные локальные заметки: repository, state и экран `/portfolio-draft` |
| [lib/features/settings/data/shared_preferences_settings_repository.dart](lib/features/settings/data/shared_preferences_settings_repository.dart) | Один versioned snapshot настроек через SharedPreferencesAsync |
| [assets/fonts](assets/fonts/) | Локальные DM Sans, Noto Sans fallback и SIL OFL лицензии |
| [test/widget_test.dart](test/widget_test.dart), [test/responsive_test.dart](test/responsive_test.dart) | UI-сценарии, навигация, темы и адаптивность |
| [test/auth_di_test.dart](test/auth_di_test.dart), [test/profile_di_test.dart](test/profile_di_test.dart), [test/projects_di_test.dart](test/projects_di_test.dart) | Подмена repositories в реальных экранах и async states |
| [test/auth_repository_test.dart](test/auth_repository_test.dart), [test/profile_repository_test.dart](test/profile_repository_test.dart), [test/projects_repository_test.dart](test/projects_repository_test.dart) | Domain rules, demo/mock content и immutable collections |
| [test/appearance_controller_test.dart](test/appearance_controller_test.dart), [test/project_filters_test.dart](test/project_filters_test.dart), [test/state_management_test.dart](test/state_management_test.dart) | Владельцы состояния, действия, навигация и новая session |
| [test/github_data_test.dart](test/github_data_test.dart), [test/github_import_controller_test.dart](test/github_import_controller_test.dart), [test/github_import_widget_test.dart](test/github_import_widget_test.dart) | DTO/HTTP/ETag, запросы и lifecycle controller, локальные фильтры и экран GitHub Import |
| [test/github_persistence_test.dart](test/github_persistence_test.dart), [test/local_storage_test.dart](test/local_storage_test.dart) | Реальный Hive reopen, TTL/fallback/304, ошибки записи, изоляция boxes и повреждённые файлы |
| [test/settings_persistence_test.dart](test/settings_persistence_test.dart), [test/localization_test.dart](test/localization_test.dart) | Restore/сохранение настроек, write retry и переведённый UI |
| [test/portfolio_draft_repository_test.dart](test/portfolio_draft_repository_test.dart), [test/portfolio_draft_controller_test.dart](test/portfolio_draft_controller_test.dart), [test/portfolio_draft_widget_test.dart](test/portfolio_draft_widget_test.dart) | Заметки, revisions, unknown schema, асинхронные действия и экран draft |
| [pubspec.yaml](pubspec.yaml), [pubspec.lock](pubspec.lock) | SDK constraint, dependencies и разрешённые версии |
| [analysis_options.yaml](analysis_options.yaml) | Dart analyzer и lint rules |
| `android/`, `ios/` | Native scaffolds и платформенные настройки |

</div>

Экраны используют общие tokens/widgets и публичные feature APIs. Domain хранит
pure Dart модели, правила и repository contracts; data содержит demo/mock
источники, Dio-реализацию GitHub repository и storage adapters. DI связывается у корня
feature, `StackCardApp.providerOverrides`
передаётся внутреннему ProviderScope для замены источника. `PortfolioOverview`
объединяет profile/projects для Home, Portfolio и preview; полный Builder/domain
остаётся задачей Phase 6. Подробные границы — в
[architecture](../../docs/architecture/architecture.md#mobile-modules--при-реальных-сценариях). Brand originals находятся в
[assets/branding](../../assets/branding/); `StackCardBrand` отрисовывает
оригинальные mark paths через `CustomPainter` без SVG package.

---

## Типовые сценарии

### Проверить UI foundation

Запусти приложение на Android-устройстве/эмуляторе или iOS-устройстве/симуляторе.
Sign In проверяет формат demo-email и вызывает repository через AuthController;
успех открывает Home без реальной авторизации аккаунта.
Через app shell доступны Portfolio, Projects и Settings; переходы поддерживают
возврат назад. Projects позволяет искать и фильтровать mock data, открывать
карточку с подробностями. Loading/error/retry работают с текущими repository
states; подмена источника не требует правки widgets. Settings получает профиль
из того же profile provider, переключает dark/light/system и показывает
loading/empty/error с retry. Dark — тема по умолчанию; выбранная тема сохраняется
после перезапуска. Query/filter state остаётся в app session.

### Прочитать публичные данные GitHub

На Projects нажми «GitHub Import»: откроется `/github-import`. Введи username
и отправь форму; неверный формат не вызывает HTTP-запрос. Успешная загрузка
показывает профиль и первую страницу repositories. Username не отправляется
на сервер при каждом нажатии клавиши.

Поиск и фильтры работают по загруженному списку. Query применяется после
300 ms без ввода; сетевой поиск не выполняется. «Загрузить ещё» читает URL из
Link, включая canonical путь с numeric user ID; результаты объединяются по
repository ID. Потяни список для refresh: текущие карточки остаются видимыми
при обновлении и при его ошибке. Ошибка следующей страницы показывается отдельно.

Loading, empty и ошибки сети, timeout, отсутствующего пользователя, ответа API
и rate limit имеют отдельные состояния. Retry выполняется явно; при rate limit
новые HTTP-запросы блокируются до deadline. Новый username сбрасывает поиск и
фильтры; refresh сохраняет их. Уход с экрана освобождает controller, отменяет
запросы и debounce; поздний ответ не меняет новое состояние.

Native bootstrap подключает Hive response cache: request URI индексирует schema 1
envelope с body, ETag, Link и UTC `validatedAt`. Каждый запрос сначала проверяет
сеть; `200`/`304` обновляют дату. При network/timeout/server failure разрешена
сохранённая копия младше 7 дней. Возраст от 7 дней, повреждение или неизвестная
schema исключают запись из fallback. Rate limit, not found, forbidden, неверный
ответ и отмена не подменяются cache.

Экран показывает «Сохранённая копия GitHub» и дату последней проверки; смешанные
страницы сохраняют предупреждение и самую раннюю дату. Ошибка локальной записи
не скрывает успешный HTTP-ответ, но показывает недоступность offline copy.
Данные GitHub пока не импортируются в curated проекты, не редактируют
demo-профиль и не публикуются автоматически.

### Сохранить настройки и локальные заметки

В Settings выбери dark/light/system, Русский/English и показ описаний источника.
UI, navigation и сообщения переведены; исходные названия и тексты контента
сохраняются. Один version 1 snapshot записывается в `stackcard.settings.v1`
через SharedPreferencesAsync. Ошибка сохранения видна с retry; выбор сразу
применяется к UI. Bootstrap восстанавливает настройки и открывает Hive boxes
до первого экрана `StackCardApp`; ошибка открытия показывает повторный запуск.

Из Portfolio открой «Локальные заметки». `/portfolio-draft` сохраняет только
notes в отдельном `portfolio_draft` box: явный Save увеличивает revision,
записывает UTC `updatedAt` и `pendingSync`. Saved notes переживают перезапуск;
несохранённый ввод сохраняется при навигации в текущей session. Ошибка Save
оставляет ввод доступным. Повреждённая запись или неизвестная schema сохраняются
с блокировкой перезаписи. `pendingSync` пока обозначает ожидающую синхронизацию;
cloud sync появится на своей фазе. Полный Builder относится к Phase 6.

### Редактировать портфолио

Целевой сценарий: создать профиль и проекты, импортировать данные GitHub,
сохранить draft, просмотреть результат и явно опубликовать портфолио.
Этот путь вводится по [roadmap](../../docs/product/product-spec.md#roadmap).

### Использовать общий backend и функции устройства

Firebase и синхронизация с web будут подключены на своих фазах. Нативные camera,
location и sharing вводятся под конкретный сценарий и платформу; Kotlin и
MethodChannel относятся к Android. Клиент не публикует draft автоматически.

---

## Локальная разработка

Открывай эту директорию как Flutter-проект в Android Studio/VS Code.
Flutter/Dart-команды выполняются здесь, Git — из корня monorepo.
Предусловия и запуск описаны в [быстром старте](../../CONTRIBUTING.md#быстрый-старт),
проверки — в [CONTRIBUTING](../../CONTRIBUTING.md#проверки).

Для Android нужны SDK, JDK и устройство/эмулятор; для iOS — macOS и Xcode.
Фактические проблемы toolchain показывает `flutter doctor -v`; наличие scaffold
не подтверждает готовность нативной сборки на конкретном компьютере.

---

## Правила

- перед изменением прочитай [AI router](../../docs/AI/README.md),
  [общие правила](../../docs/AI/AGENTS.md) и [mobile scope](../../docs/AI/scopes/mobile.md);
- добавляй dependencies при реальном использовании, сохраняй lockfile приложения;
- generated-файлы и `.metadata` не редактируй вручную;
- feature placement и границы данных согласуй с [архитектурой](../../docs/architecture/architecture.md);
- сохраняй принятый [визуальный язык](../../docs/design/design-system.md), не добавляй параллельные tokens;
- обновляй ссылки и документы при изменении команд, путей или контрактов.
