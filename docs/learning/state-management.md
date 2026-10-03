<div align="center">

# StackCard State Management

**Эволюция темы и границы Provider/Riverpod в мобильном приложении**

![Learning state management](https://raster.shields.io/badge/Learning-state_management-09090B?style=for-the-badge)
![Scope Phases 2–6](https://raster.shields.io/badge/Scope-Phases_2--6-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Один сценарий, три подхода](#один-сценарий-три-подхода)
- [Переходы темы](#переходы-темы)
- [Итоговые владельцы состояния](#итоговые-владельцы-состояния)
- [Почему поиск проектов использует Riverpod](#почему-поиск-проектов-использует-riverpod)
- [Repository и DI на Phase 3](#repository-и-di-на-phase-3)
- [GitHub Import на Phase 4](#github-import-на-phase-4)
- [Локальное сохранение на Phase 5](#локальное-сохранение-на-phase-5)
- [Рабочий draft и Builder на Phase 6](#рабочий-draft-и-builder-на-phase-6)
- [Воспроизведение учебных вариантов](#воспроизведение-учебных-вариантов)
- [Проверки и ограничения](#проверки-и-ограничения)

---

## Один сценарий, три подхода

Учебный сценарий — выбор dark/light/system в Settings. Результат одинаков:
MaterialApp получает новый ThemeMode, текущий маршрут сохраняется. На Phase 2
выбор действовал до нового запуска; Phase 5 добавила сохранение настроек.
В Phase 1 этот сценарий использовал `setState`; на Phase 2 он последовательно
прошёл InheritedWidget и Provider. Учебные patches обновлены под текущие contracts.

<div align="center">

| **Подход** | **Владелец значения** | **Как UI получает изменения** |
|:---|:---|:---|
| `setState` | AppSettings snapshot в `State<StackCardApp>` | ThemeMode getter и callback передаются в Settings через router; MaterialApp читает State |
| `InheritedWidget` | Тот же родительский `State` | AppearanceScope предоставляет ThemeMode/callback; Builder и Settings регистрируют dependency |
| `Provider` | AppearanceController | `Selector`/`select` подписывают UI, `read` вызывает действие |

</div>

`setState` удобен для собственного состояния небольшого widget. В исходной
версии общая тема была поднята в корень, поэтому router передавал её getter
и callback в Settings. Это работало, но связывало навигацию с настройкой темы.

InheritedWidget распространяет уже имеющееся состояние. Он не создаёт mutable
владельца: новый AppearanceScope строился после родительского `setState`.
`dependOnInheritedWidgetOfExactType` регистрировал зависимость,
`updateShouldNotify` уведомлял её при изменении mode. Router больше не участвовал
в передаче темы. Это соответствует
[контракту Flutter InheritedWidget](https://api.flutter.dev/flutter/widgets/InheritedWidget-class.html).

Provider сохраняет доставку через widget tree и берёт управление lifecycle
контроллера. `ChangeNotifierProvider(create:)` создаёт AppearanceController
и освобождает его при удалении provider; `.value` применяется к уже существующему
объекту с другим владельцем. `select` подписывается на выбранное значение,
`read` в обработчике действия не создаёт подписку.
См. [контракт ChangeNotifierProvider](https://pub.dev/documentation/provider/latest/provider/ChangeNotifierProvider-class.html).

---

## Переходы темы

Фрагменты показывают ключевое различие; полный воспроизводимый вариант
содержится в patch соответствующего этапа.

### setState: значение в корне

```dart
Future<void> _changeSettings(AppSettings next) {
  setState(() => _settings = next);
  return _preferences.persistSettings();
}
```

В текущем patch `_settings` — единственный mutable AppSettings snapshot.
ThemeMode вычисляется из него; MaterialApp читает State, Settings получает
getter и действие через router. Сохранение snapshot не создаёт второго владельца
темы. Вариант сохранён в
[theme-set-state.patch](patches/theme-set-state.patch).

### InheritedWidget: доставка через scope

```dart
static AppearanceScope of(BuildContext context) {
  return context.dependOnInheritedWidgetOfExactType<AppearanceScope>()!;
}

@override
bool updateShouldNotify(AppearanceScope oldWidget) =>
    themeMode != oldWidget.themeMode;
```

AppearanceScope расположен над MaterialApp; Builder под scope регистрирует
зависимость для чтения ThemeMode. Settings читает scope самостоятельно.
Mutable snapshot всё ещё принадлежит родительскому State. Историческая версия
Phase 2 реально внедрялась и прошла пять существовавших UI tests; текущий вариант сохранён в
[theme-inherited.patch](patches/theme-inherited.patch).

### Provider: отдельный контроллер

```dart
final mode = context.select<AppearanceController, ThemeMode>(
  (controller) => controller.themeMode,
);

// В обработчике действия:
context.read<AppearanceController>().setThemeMode(ThemeMode.light);
```

[`AppearanceController`](../../apps/mobile/lib/core/state/appearance_controller.dart)
хранит AppSettings snapshot и уведомляет UI о новом выборе и статусе сохранения.
[`main.dart`](../../apps/mobile/lib/main.dart) создаёт его через
`ChangeNotifierProvider`; `Selector<AppearanceController, (ThemeMode, Locale)>` передаёт
тему и язык в MaterialApp. Settings использует `select/read`, router больше не
передаёт theme параметры. `State<StackCardApp>` управляет lifecycle GoRouter.

`select` сокращает перестроения от уведомлений контроллера. Сама смена Flutter
Theme закономерно обновляет использующие её widgets; это необходимое обновление
интерфейса. В runtime осталась только эта реализация темы.

---

## Итоговые владельцы состояния

<div align="center">

| **Состояние** | **Владелец и срок жизни** |
|:---|:---|
| ThemeMode, locale ru/en и showSourceDescriptions | AppSettings в AppearanceController через Provider; восстановление и сохранение через SharedPreferences |
| Очередь сохранения настроек и save failure | AppearanceController, app session; последние изменения записываются последовательно, retry явный |
| Query и выбранный фильтр Projects | ProjectFiltersNotifier через Riverpod, app session |
| Полный список проектов и профиль | projectsProvider/profileProvider, проекции рабочего Builder content либо async demo repository state |
| Отфильтрованный список | visibleProjectsProvider, AsyncValue из query/filter и полного списка |
| Featured проекты | featuredProjectsProvider и pure selectFeaturedProjects, независимы от поиска |
| Demo-session и действие входа | AuthController через AsyncNotifier, repository вызывается через DI |
| Home и demo Portfolio | PortfolioOverview в presentation объединяет публичные profile/projects states |
| Builder Portfolio и preview | Рабочий PortfolioContent через публичный portfolioWorkingContentProvider, порядок/видимость блоков и выбранная тема |
| GitHub username, профиль, repositories и loading/error flags | GitHubImportController через autoDispose Notifier, время жизни экрана GitHub Import |
| GitHub query и фильтр | Immutable GitHubImportState; controller применяет локальный query после debounce 300 ms |
| GitHub repository и rate-limit deadline | DioGitHubImportRepository через feature-root DI, app session; уход с экрана не сбрасывает deadline |
| GitHub response cache и metadata | Native bootstrap подставляет HiveGitHubResponseCache; body/ETag/Link/validatedAt переживают запуск, TTL — 7 дней; readMetadata сообщает offline fallback и проблемы cache |
| Рабочий portfolio content и private notes | PortfolioDraftController через Riverpod, app session; применённые изменения сохраняются при навигации |
| Последний сохранённый portfolio draft, revision и pendingSync | HivePortfolioDraftRepository; успешная запись увеличивает revision и помечает pendingSync |
| Полнота портфолио | Pure calculatePortfolioCompletion от рабочего content; отдельного mutable значения нет |
| Тема портфолио dark/light | PortfolioContent.theme в том же draft; применяется к отображению content независимо от app ThemeMode |
| Редактируемый текст поля | TextEditingController экрана; query/notes синхронизируются с feature state, формы Builder применяют результат целиком |
| Form validation и preview loading/empty/error | Локальное UI-состояние соответствующего экрана |
| GoRouter | State корневого приложения, disposal при закрытии дерева |

</div>

Provider управляет базовыми настройками: ThemeMode, locale с реальными ru/en
переводами и используемая preference описаний GitHub. Два state-management
пакета выполняют разные обязанности; настройки не дублируются в Riverpod,
query/filter не дублируются в widget `setState`.

---

## Почему поиск проектов использует Riverpod

Поиск и фильтры — существующий пользовательский сценарий Projects, а не
абстракция будущего backend. До Phase 2 widget одновременно хранил query/filter
и вычислял список. Phase 2 ввела immutable state и Notifier; Phase 3 разделила
[`ProjectFilters`](../../apps/mobile/lib/features/projects/domain/project_filters.dart)
и правила отбора в pure Dart domain,
[`ProjectFiltersNotifier`](../../apps/mobile/lib/features/projects/presentation/project_filters.dart)
в presentation и async derived providers в feature composition.

```dart
final filters = ref.watch(projectFiltersProvider);
final projects = ref.watch(visibleProjectsProvider);

// В обработчике поля:
ref.read(projectFiltersProvider.notifier).setQuery(value);
```

Каждое действие заменяет immutable state; derived provider наблюдает его через
[`ref.watch`](https://riverpod.dev/docs/concepts2/refs) и возвращает `AsyncValue` с неизменяемым списком результатов через `whenData`. Список не копируется
во второе mutable поле. Правила поиска проверяются через
[ProviderContainer](https://riverpod.dev/docs/concepts2/containers)
без BuildContext; pure domain rules проверяются отдельно. Widget отвечает
за отображение AsyncValue, input controller и действия.
Рекомендуемый синхронный API —
[Notifier/NotifierProvider](https://riverpod.dev/docs/concepts2/providers).

Providers не используют `autoDispose`: при переходе в другой экран фильтры
сохраняются в текущем ProviderScope. При пересоздании приложения container
создаётся заново, фильтры возвращаются к исходным. Ни Provider, ни Riverpod
не добавляют persistence сами; Phase 5 подключает конкретные storage adapters.
Query/filter Projects продолжают жить только в app session. Repository/data layers
реализованы на Phase 3. Phase 4 добавила network в отдельную GitHub Import feature;
На Phase 6 Projects читает проекцию ручных проектов Builder, а до его начала —
curated demo-данные через свой repository.

---

## Repository и DI на Phase 3

Riverpod связывает используемые repository contracts с demo/mock реализациями.
Feature-root `auth_providers.dart`, `profile_dependencies.dart` и
`projects_providers.dart` владеют DI; widgets используют controller/providers и
domain, не concrete repositories. Между features импортируются публичные APIs.

`FutureProvider` загружает Profile и список Project; `AsyncNotifier` выполняет
`AuthRepository.openDemo`. `AsyncValue` распространяет loading/error/data;
shared widgets показывают ожидание, ошибку и явный retry. Смена query/filter
вычисляет новый вид списка и не повторяет repository запрос.
`featuredProjectsProvider` и `PortfolioOverview` используют полный список:
поиск в Projects не меняет карточки Home, Portfolio или preview.

```dart
StackCardApp(
  providerOverrides: [
    projectsRepositoryProvider.overrideWithValue(alternativeRepository),
  ],
)
```

`alternativeRepository` реализует pure Dart `ProjectsRepository`.
`providerOverrides` поступает во внутренний `ProviderScope`; тест видит другой
источник на реальном экране. Это DI, а не второе mutable состояние продукта.
Provider остаётся владельцем простой темы через widget tree, Riverpod — владельцем
product state, асинхронных действий и repository composition. Два механизма
не конкурируют за одно значение.

Модель ProfileReadiness содержит счётчики read model, PortfolioOverview —
модель чтения presentation. Demo repository задаёт счётчики в snapshot;
проекция Builder получает их из pure алгоритма полноты. Notes-only draft появился
на Phase 5, единый portfolio content и Builder — на Phase 6. Repository отвечает
за сохранение draft; published контракты вводятся на своей фазе.

---

## GitHub Import на Phase 4

[`GitHubImportState`](../../apps/mobile/lib/features/github_import/presentation/github_import_state.dart)
хранит username, профиль, immutable repositories, nextPage, query/filter и
отдельные flags initial loading, refreshing и loadingMore. Главная failure и
pageFailure позволяют показать ошибку запроса рядом с сохранёнными карточками.
`visibleRepositories` использует pure domain filter по загруженному списку.

[`GitHubImportController`](../../apps/mobile/lib/features/github_import/presentation/github_import_controller.dart)
публикует новый профиль вместе с первой страницей только после успеха обоих
запросов. Refresh сохраняет query/filter и прежний успешный список до получения
новых данных; его ошибка оставляет список доступным. Load more объединяет
repositories по стабильному ID, не создавая дублей. Новый username очищает
прошлые данные, поиск и фильтр; некорректный username не вызывает HTTP.

Ввод username отправляется формой. `setQuery` откладывает изменение query на
300 ms, не обращаясь к API; `setFilter` применяет локальный отбор. Controller
не запускает одинаковое действие одновременно. Refresh может заменить
незавершённую pagination; generation guards и `ref.mounted` предотвращают
запись позднего ответа. `autoDispose` отменяет запросы и timer при уходе с экрана.
Это отличается от app-session фильтров Projects, которые сохраняются при навигации.

[`github_import_providers.dart`](../../apps/mobile/lib/features/github_import/github_import_providers.dart)
связывает pure `GitHubImportRepository` с Dio-реализацией, clock и response cache.
DTO mapping, HTTP timeout, проверка Link origin/user path и conditional ETag
requests принадлежат data. Публичный
[`github_import.dart`](../../apps/mobile/lib/features/github_import/github_import.dart)
предоставляет contract для router, экрана и provider overrides; widgets не
импортируют concrete repository или DTO.

`GitHubFailure` различает invalid username, not found, network, timeout, rate
limit, forbidden, server, invalid response и cancellation. Retry выполняется
явно; failure с будущим `retryAt` блокирует новый HTTP до deadline. Отмена
запроса не отображается как пользовательская ошибка. Initial и refresh ошибки
повторяются через `retry`, page error — через `loadMore`.

Исторически на Phase 4 memory cache хранил сериализованный ответ, ETag и Link
по request URI, поддерживая только online `304` revalidation. Cache и repository
жили в app session; закрытие экрана освобождало controller, сохраняя rate-limit
deadline источника. Phase 5 добавила persistent cache и offline fallback,
описанные ниже. Прочитанные GitHub данные по-прежнему не изменяют curated portfolio
или draft; network state не управляет темой.

---

## Локальное сохранение на Phase 5

Pure Dart
[`AppSettings`](../../apps/mobile/lib/core/state/app_settings.dart) и
[`SettingsRepository`](../../apps/mobile/lib/core/state/settings_repository.dart)
задают тему, язык и `showSourceDescriptions`. Native
[`LocalRuntime`](../../apps/mobile/lib/app/local_runtime.dart) читает настройки
и открывает Hive до появления первого экрана приложения. `StackCardApp`
получает восстановленный snapshot и repository; ThemeMode/Locale применяются
сразу. `AppStrings` и Flutter delegates переводят interface labels, validation
и states; содержимое профиля, GitHub и draft остаётся данными источника.

[`SharedPreferencesSettingsRepository`](../../apps/mobile/lib/features/settings/data/shared_preferences_settings_repository.dart)
сохраняет versioned JSON snapshot через SharedPreferencesAsync. Отсутствующие,
повреждённые и неподдерживаемые настройки используют defaults; ошибки доступа
имеют typed failure. AppearanceController сразу применяет выбор к UI и
последовательно записывает snapshots, объединяя быстрые изменения. Save failure
не откатывает текущий выбор; Settings показывает ошибку и явный retry.
`showSourceDescriptions` управляет видимостью описаний в GitHub cards.

Native bootstrap подставляет
[`HiveGitHubResponseCache`](../../apps/mobile/lib/features/github_import/data/hive_github_response_cache.dart)
в existing async cache contract. Versioned envelope хранит body, ETag, Link и
UTC validatedAt по request URI. Срок доступности —
[`githubCacheMaxAge`](../../apps/mobile/lib/features/github_import/data/github_response_cache.dart),
сейчас семь дней после validation. Истёкшая, повреждённая или неподдерживаемая
cache entry удаляется; она не заменяет пользовательский draft.

Repository перепроверяет DTO и Link identity, выполняет HTTP revalidation с
ETag при его наличии. При network/timeout/server failure свежий сохранённый
ответ может быть показан offline. `GitHubReadMetadata` сообщает происхождение
снимка, время validation, fallback failure и проблемы чтения/записи cache;
смешанный список остаётся помечен как cached до полного успешного refresh.
Rate limit, not found и forbidden не подменяются успешным offline-ответом.
Memory adapter остаётся для независимых tests и отдельно созданного StackCardApp.

[`PortfolioDraftController`](../../apps/mobile/lib/features/portfolio_draft/presentation/portfolio_draft_controller.dart)
на Phase 5 сохранял несохранённый notes input в app session. Явный save записывал
локальный draft в отдельную Hive box; envelope v1 содержал notes, revision, updatedAt и
pendingSync. Успешный save увеличивает revision, ставит pendingSync и записывает
updatedAt в UTC. Правка во время save остаётся несохранённой, даже если прежний
snapshot записался успешно. При записи failure ввод сохраняется для retry.
Повреждённый или неизвестный draft не очищается и не перезаписывается;
cache eviction его не затрагивает. Phase 6 расширяет тот же механизм portfolio
content; remote sync ещё отсутствует.

---

## Рабочий draft и Builder на Phase 6

[`PortfolioContent`](../../apps/mobile/lib/features/portfolio_draft/domain/portfolio_content.dart)
— immutable значения профиля, навыков, ручных проектов, опыта, образования,
ссылок, Resume, блоков и темы портфолио. Nullable content в `PortfolioDraft`
отделяет ещё не начатый Builder от пустого пользовательского портфолио.
Начало создаёт пустой content без копирования demo/source. Notes остаются
приватными вне content и не отображаются в preview.

Controller хранит рабочие notes/content и последний durable draft. Формы держат
ещё не применённый ввод локально и изменяют feature state одним действием Apply;
Cancel оставляет content прежним. После Apply данные видны на Home, Portfolio,
Projects и Settings через read model проекции публичного
`portfolioWorkingContentProvider`. Эти проекции не создают второго mutable
владельца и не пишут в repository. Preview читает рабочий content в порядке
видимых блоков и показывает статус несохранённых изменений.

```dart
final content = ref.watch(portfolioWorkingContentProvider);

// В обработчике Apply после validation:
ref.read(portfolioDraftControllerProvider.notifier).updateContent(nextContent);

// Явное сохранение всего рабочего draft:
await ref.read(portfolioDraftControllerProvider.notifier).save();
```

Save захватывает content, notes и durable revision; успешная запись обновляет
только durable snapshot. Если пользователь изменил поля во время записи,
новые значения остаются unsaved. Duplicate Save блокируется, failure сохраняет
ввод. Repository последовательно проверяет expected revision; conflict не
перезаписывает более свежую сохранённую версию. Явный reload отбрасывает
несохранённые правки, поэтому вызывается после соответствующего действия UI.

Hive envelope v2 содержит nullable content. Чтение v1 сохраняет notes/metadata
и возвращает content null без записи. Первая явная запись v2 предварительно
сохраняет raw v1 backup; ошибки backup/write оставляют старую durable запись.
`saveNotes` меняет только notes и сохраняет portfolio content.

Validation и вычисление полноты — pure domain, независимо от widget tree/storage.
Неполный профиль допустим для draft; некорректные значения не сохраняются.
Полнота учитывает профиль, About, навыки, видимый проект и ссылки; опциональные
разделы не мешают получить 100%, скрытие блока не увеличивает процент.
`PortfolioTheme` хранится в content отдельно от AppearanceController ThemeMode.
PortfolioContentView и preview используют имеющуюся StackCardTheme; Resume — обычный текст с переносами
строк. Детали persistence и boundaries — в
[architecture](../architecture/architecture.md#portfolio-domain-и-локальный-builder),
приёмка — в [Phase 6](../product/product-spec.md#phase-6--portfolio-domain-и-локальный-builder).

---

## Воспроизведение учебных вариантов

Patches преобразуют итоговую Provider-версию темы в один учебный вариант.
Применяй каждый patch независимо к новой временной копии итогового проекта.
Repository/DI, `StackCardApp.providerOverrides`, асинхронный профиль Settings,
GitHub Import и остальное состояние продукта остаются на Riverpod. Рабочий checkout сохраняет
итоговую реализацию; `git restore` и переключение веток для урока не нужны.

Patches переносят целый AppSettings snapshot в родительский State,
чтобы у темы оставался один владелец и сохранялась запись цельного snapshot.
AppearanceController в учебной копии не содержит ThemeMode API: это forwarding
и persistence adapter для locale/descriptions и save status, читающий snapshot
через getter и изменяющий его через callback. Provider доставляет этот adapter
другим settings consumers, но не хранит и не распространяет тему MaterialApp.
State владеет adapter и его disposal; `ChangeNotifierProvider.value` доставляет
уже созданный объект. Hive bootstrap, localization delegates и Repository DI
сохраняются. Учебные изменения runtime существуют только внутри patches.

macOS — zsh/bash, из корня репозитория; нужны Git, rsync, Flutter и уже
разрешённые зависимости приложения:

```bash
lesson_dir="$(mktemp -d "${TMPDIR:-/tmp}/stackcard-state-lesson.XXXXXX")"
rsync -a --exclude=.git --exclude=build --exclude=.dart_tool ./ "$lesson_dir/"
cd "$lesson_dir"
git apply --check docs/learning/patches/theme-inherited.patch
git apply docs/learning/patches/theme-inherited.patch
cd apps/mobile
flutter pub get --offline
flutter test test/widget_test.dart
flutter run -d <device-id>
```

В `<device-id>` подставь ID доступного Android/iOS target из `flutter devices`.
Проверка должна завершиться успешно, Settings должен менять тему и сохранять
маршрут. Для setState создай ещё одну свежую копию и замени имя patch на
`theme-set-state.patch`. Не применяй оба patch последовательно к одной копии.
`--check` обнаружит рассогласование patch с изменившимся source.

---

## Проверки и ограничения

Финальная проверка Phase 6: оба patches независимо применены к свежим копиям
текущего source через `git apply --check` и `git apply`. В каждой копии
`flutter analyze lib` завершился без замечаний, пять `widget_test.dart` и девять
`localization_test.dart` tests прошли — 14/14. Builder, AppShell identity,
read gate профиля/проектов и persistence sources совпадают с итоговой интеграцией;
отличаются только целевые theme files учебного patch. Canonical controller tests
проверяют итоговый Provider API и не относятся к forwarding adapter учебных вариантов.

Историческая проверка Phase 5: patches независимо применены через `git apply --check` к свежим
копиям полного проекта. В каждом варианте прошли пять `widget_test.dart` tests
и девять `localization_test.dart` tests: theme/navigation, восстановленные ru/en
настройки, locale без смены router, descriptions preference и save failure/retry.
Canonical runtime не изменялся. Для setState patch изменяет main, Settings,
AppearanceController adapter и router; для InheritedWidget — main, Settings,
adapter и добавляет AppearanceScope. Остальные feature/storage sources сохранены.

Историческая проверка Phase 3: оба patches согласованы с feature APIs и
`StackCardApp.providerOverrides`. Каждый прошёл `git apply --check` в независимой
временной копии полного проекта, затем пять tests из `test/widget_test.dart`.
Проверены demo-вход, навигация, поиск/детали Projects, смена темы со states/retry
и клавиатура; async profile в Settings и Repository/DI сохранены.

Историческая проверка Phase 4: оба patches повторно прошли `git apply --check` на тогдашнем checkout
и UI tests из `test/widget_test.dart` в независимых временных копиях. GitHub Import
sources, repository lifetime, Provider overrides и async profile Settings
сохранены; runtime-код и сами patches для этой проверки не изменялись.

Историческая промежуточная InheritedWidget-версия Phase 2 действительно выполнялась: пять tests
из `test/widget_test.dart` прошли, включая переключение темы и навигацию.
Итоговые проверки контроллера, Riverpod state, UI и реконструкции этапов,
результаты запуска и ограничения среды фиксируются в
[product spec](../product/product-spec.md#phase-2--basic-state-management).

Этапы сравнивают одинаковый theme сценарий. Учебные patches меняют только
механизм темы; Riverpod portfolio state и отдельный network state GitHub Import
сохраняются. ThemeMode/Locale/preferences, GitHub cache и явно сохранённый portfolio draft
переживают запуск; query/filter и ещё не сохранённый ввод остаются в app session.
Итоговый статус persistence и проверки текущего приложения — в
[product spec](../product/product-spec.md#phase-6--portfolio-domain-и-локальный-builder).
