<div align="center">

# StackCard State Management

**Эволюция темы и границы Provider/Riverpod в мобильном приложении**

![Learning state management](https://raster.shields.io/badge/Learning-state_management-09090B?style=for-the-badge)
![Scope Phase 2](https://raster.shields.io/badge/Scope-Phase_2-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Один сценарий, три подхода](#один-сценарий-три-подхода)
- [Переходы темы](#переходы-темы)
- [Итоговые владельцы состояния](#итоговые-владельцы-состояния)
- [Почему поиск проектов использует Riverpod](#почему-поиск-проектов-использует-riverpod)
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
| Отфильтрованный список | visibleDemoProjectsProvider, вычисляется из query/filter и mock data |
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
и вычислял список. Теперь
[`project_filters.dart`](../../apps/mobile/lib/features/projects/project_filters.dart)
задаёт immutable `ProjectFilters`, действия `ProjectFiltersNotifier`
и `visibleDemoProjectsProvider`.

```dart
final filters = ref.watch(projectFiltersProvider);
final projects = ref.watch(visibleDemoProjectsProvider);

// В обработчике поля:
ref.read(projectFiltersProvider.notifier).setQuery(value);
```

Каждое действие заменяет immutable state; derived provider наблюдает его через
[`ref.watch`](https://riverpod.dev/docs/concepts2/refs) и возвращает неизменяемый список результатов. Список не копируется
во второе mutable поле. Правила поиска проверяются через
[ProviderContainer](https://riverpod.dev/docs/concepts2/containers)
без BuildContext; widget отвечает за отображение, input controller и действия.
Рекомендуемый синхронный API —
[Notifier/NotifierProvider](https://riverpod.dev/docs/concepts2/providers).

Providers не используют `autoDispose`: при переходе в другой экран фильтры
сохраняются в текущем ProviderScope. При пересоздании приложения container
создаётся заново, фильтры возвращаются к исходным. Ни Provider, ни Riverpod
не добавляют persistence сами; оно относится к Phase 5. Repository/data layers,
network и расширение архитектуры относятся к следующим фазам.

---

## Воспроизведение учебных вариантов

Patches преобразуют итоговую Provider-версию темы в один учебный вариант.
Применяй каждый patch независимо к новой временной копии итогового проекта.
Остальное состояние продукта остаётся на Riverpod. Рабочий checkout сохраняет
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

Промежуточная InheritedWidget-версия действительно выполнялась: пять tests
из `test/widget_test.dart` прошли, включая переключение темы и навигацию.
Итоговые проверки контроллера, Riverpod state, UI и реконструкции этапов,
результаты запуска и ограничения среды фиксируются в
[product spec](../product/product-spec.md#phase-2--basic-state-management).

Этапы сравнивают одинаковый theme сценарий. Общий mock content и оформление
сохранены; данные не синхронизируются с сетью и не сохраняются на диск.
