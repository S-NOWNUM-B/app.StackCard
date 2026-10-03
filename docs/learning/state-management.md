<div align="center">

# StackCard State Management

**Эволюция темы и границы Provider/Riverpod в мобильном приложении**

![Learning state management](https://raster.shields.io/badge/Learning-state_management-09090B?style=for-the-badge)
![Scope Phases 2–4](https://raster.shields.io/badge/Scope-Phases_2--4-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Один сценарий, три подхода](#один-сценарий-три-подхода)
- [Переходы темы](#переходы-темы)
- [Итоговые владельцы состояния](#итоговые-владельцы-состояния)
- [Почему поиск проектов использует Riverpod](#почему-поиск-проектов-использует-riverpod)
- [Repository и DI на Phase 3](#repository-и-di-на-phase-3)
- [GitHub Import на Phase 4](#github-import-на-phase-4)
- [Воспроизведение учебных вариантов](#воспроизведение-учебных-вариантов)
- [Проверки и ограничения](#проверки-и-ограничения)

---

## Один сценарий, три подхода

Учебный сценарий — выбор dark/light/system в Settings. Результат одинаков:
MaterialApp получает новый ThemeMode, текущий маршрут сохраняется, выбор
действует до нового запуска. В Phase 1 этот сценарий использовал `setState`;
на Phase 2 он последовательно прошёл InheritedWidget и Provider.

<div align="center">

| **Подход** | **Владелец значения** | **Как UI получает изменения** |
|:---|:---|:---|
| `setState` | `State<StackCardApp>` | Значение и callback передаются в Settings через router |
| `InheritedWidget` | Тот же родительский `State` | AppearanceScope предоставляет значение/callback зависимым widgets |
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
late ThemeMode _themeMode = widget.initialThemeMode;

void changeTheme(ThemeMode mode) {
  setState(() => _themeMode = mode);
}
```

MaterialApp читает `_themeMode`; Settings получает getter и действие через
аргументы router. Вариант сохранён в
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
Mutable mode всё ещё принадлежит родительскому State. Вариант реально
внедрялся и прошёл пять существовавших UI tests; сохранён в
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
хранит mode и вызывает `notifyListeners` только при новом значении.
[`main.dart`](../../apps/mobile/lib/main.dart) создаёт его через
`ChangeNotifierProvider`; `Selector<AppearanceController, ThemeMode>` передаёт
выбор в MaterialApp. Settings использует `select/read`, router больше не
передаёт theme параметры. `State<StackCardApp>` управляет lifecycle GoRouter.

`select` сокращает перестроения от уведомлений контроллера. Сама смена Flutter
Theme закономерно обновляет использующие её widgets; это необходимое обновление
интерфейса. В runtime осталась только эта реализация темы.

---

## Итоговые владельцы состояния

<div align="center">

| **Состояние** | **Владелец и срок жизни** |
|:---|:---|
| ThemeMode | AppearanceController через Provider, app session |
| Query и выбранный фильтр Projects | ProjectFiltersNotifier через Riverpod, app session |
| Полный список проектов и профиль | projectsProvider/profileProvider, async repository state в app session |
| Отфильтрованный список | visibleProjectsProvider, AsyncValue из query/filter и полного списка |
| Featured проекты | featuredProjectsProvider и pure selectFeaturedProjects, независимы от поиска |
| Demo-session и действие входа | AuthController через AsyncNotifier, repository вызывается через DI |
| Home/Portfolio/preview данные | PortfolioOverview в presentation объединяет публичные profile/projects states |
| GitHub username, профиль, repositories и loading/error flags | GitHubImportController через autoDispose Notifier, время жизни экрана GitHub Import |
| GitHub query и фильтр | Immutable GitHubImportState; controller применяет локальный query после debounce 300 ms |
| GitHub repository и rate-limit deadline | DioGitHubImportRepository через feature-root DI, app session; уход с экрана не сбрасывает deadline |
| GitHub ETag response cache | MemoryGitHubResponseCache через feature-root DI, app session; только online conditional requests |
| Редактируемый текст поля | TextEditingController экрана, синхронизируется с query |
| Form validation и preview loading/empty/error | Локальное UI-состояние соответствующего экрана |
| GoRouter | State корневого приложения, disposal при закрытии дерева |

</div>

Provider ограничен базовыми настройками ThemeMode/Locale. Сейчас есть только
ThemeMode: Locale будет добавлен вместе с переводами. Два state-management
пакета выполняют разные обязанности; тема не дублируется в Riverpod, query/filter
не дублируются в widget `setState`.

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
не добавляют persistence сами; оно относится к Phase 5. Repository/data layers
реализованы на Phase 3. Phase 4 добавила network в отдельную GitHub Import feature;
Projects по-прежнему показывает curated demo-данные через свой repository.

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

Модель ProfileReadiness содержит demo-snapshot счётчиков, PortfolioOverview —
модель чтения presentation. Full Builder, алгоритм полноты и draft/published
контракты вводятся на своих фазах; Repository сам по себе не реализует их.

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

Memory cache хранит сериализованный ответ, ETag и Link по request URI. После
`304` data использует проверенные cached metadata; при ошибке сети cache не
подменяет ответ offline-данными. Cache и repository живут в app session;
закрытие экрана освобождает controller, сохраняя rate-limit deadline источника.
Persistence и TTL относятся к Phase 5; прочитанные GitHub
данные пока не изменяют curated portfolio или draft. Тема продолжает принадлежать
Provider и не зависит от network state.

---

## Воспроизведение учебных вариантов

Patches преобразуют итоговую Provider-версию темы в один учебный вариант.
Применяй каждый patch независимо к новой временной копии итогового проекта.
Repository/DI, `StackCardApp.providerOverrides`, асинхронный профиль Settings,
GitHub Import и остальное состояние продукта остаются на Riverpod. Рабочий checkout сохраняет
итоговую реализацию; `git restore` и переключение веток для урока не нужны.

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

На Phase 3 оба patches согласованы с текущими feature APIs и
`StackCardApp.providerOverrides`. Каждый прошёл `git apply --check` в независимой
временной копии полного проекта, затем пять tests из `test/widget_test.dart`.
Проверены demo-вход, навигация, поиск/детали Projects, смена темы со states/retry
и клавиатура; async profile в Settings и Repository/DI сохранены.

На Phase 4 оба patches повторно прошли `git apply --check` на текущем checkout
и UI tests из `test/widget_test.dart` в независимых временных копиях. GitHub Import
sources, repository lifetime, Provider overrides и async profile Settings
сохранены; runtime-код и сами patches для этой проверки не изменялись.

Промежуточная InheritedWidget-версия действительно выполнялась: пять tests
из `test/widget_test.dart` прошли, включая переключение темы и навигацию.
Итоговые проверки контроллера, Riverpod state, UI и реконструкции этапов,
результаты запуска и ограничения среды фиксируются в
[product spec](../product/product-spec.md#phase-2--basic-state-management).

Этапы сравнивают одинаковый theme сценарий. Учебные patches меняют только
механизм темы; demo/mock портфолио и отдельный network state GitHub Import
сохраняются. ThemeMode, query/filter и GitHub response cache не сохраняются
на диск. Итоговый статус GitHub API и проверки текущего приложения — в
[product spec](../product/product-spec.md#phase-4--github-api).
