<div align="center">

# StackCard Mobile

**Flutter-клиент для Android и iOS с мобильным редактором общего портфолио**

![Mobile Android + iOS](https://raster.shields.io/badge/Mobile-Android_%2B_iOS-09090B?style=for-the-badge)
![Stage Phase 1 UI](https://raster.shields.io/badge/Stage-Phase_1_UI-FF0012?style=for-the-badge)

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

Сейчас реализована UI foundation: Sign In, Home, Portfolio, Projects и Settings
на mock data, общий app shell и Material 3 light/dark. Demo-вход, локальные
поиск/фильтры и переключение темы позволяют проверить интерфейс; backend,
редактирование и публикация вводятся по roadmap. Результаты проверок — в
[product spec](../../docs/product/product-spec.md#phase-1--ui-foundation).
Сайт развивается отдельно в [apps/web](../web/README.md)
на Next.js; desktop и Flutter web targets в mobile не входят.

---

## Что хранится здесь

<div align="center">

| **Материал** | **Назначение** |
|:---|:---|
| [lib/main.dart](lib/main.dart) | `StackCardApp`, composition и `ThemeMode` через `setState` |
| [lib/app](lib/app/) | GoRouter и адаптивный app shell |
| [lib/core/theme](lib/core/theme/) | Утверждённая палитра, Material 3, typography, spacing/radius |
| [lib/shared](lib/shared/) | Mock data и используемые общие widgets |
| [lib/features](lib/features/) | Пять экранов demo UI |
| [assets/fonts](assets/fonts/) | Локальные DM Sans, Noto Sans fallback и SIL OFL лицензии |
| [test/widget_test.dart](test/widget_test.dart), [test/responsive_test.dart](test/responsive_test.dart) | UI-сценарии, навигация, темы и адаптивность |
| [pubspec.yaml](pubspec.yaml), [pubspec.lock](pubspec.lock) | SDK constraint, dependencies и разрешённые версии |
| [analysis_options.yaml](analysis_options.yaml) | Dart analyzer и lint rules |
| `android/`, `ios/` | Native scaffolds и платформенные настройки |

</div>

Экраны используют общие tokens/widgets. Data sources и domain/data layers
появляются вместе с реальными сценариями. Brand originals находятся в
[assets/branding](../../assets/branding/); `StackCardBrand` отрисовывает
оригинальные mark paths через `CustomPainter` без SVG package.

---

## Типовые сценарии

### Проверить UI foundation

Запусти приложение на Android-устройстве/эмуляторе или iOS-устройстве/симуляторе.
Sign In проверяет формат email для примера и открывает Home.
Через app shell доступны Portfolio, Projects и Settings; переходы поддерживают
возврат назад. Projects позволяет искать и фильтровать mock data, открывать
карточку с подробностями. Settings переключает dark/light/system и показывает
loading/empty/error с retry. Dark — тема по умолчанию; выбор темы действует
до закрытия приложения.

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
