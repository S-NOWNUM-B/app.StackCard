<div align="center">

# StackCard Mobile

**Flutter-клиент для Android и iOS с мобильным редактором общего портфолио**

![Mobile Android + iOS](https://raster.shields.io/badge/Mobile-Android_%2B_iOS-09090B?style=for-the-badge)
![Stage Phase 0](https://raster.shields.io/badge/Stage-Phase_0-FF0012?style=for-the-badge)

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

Сейчас здесь только стартовый счётчик Phase 0, без backend, навигации и
продуктовых экранов. Сайт развивается отдельно в [apps/web](../web/README.md)
на Next.js; desktop и Flutter web targets в mobile не входят.

---

## Что хранится здесь

<div align="center">

| **Материал** | **Назначение** |
|:---|:---|
| [lib/main.dart](lib/main.dart) | `StackCardApp`, временная seed-тема и стартовый счётчик |
| [test/widget_test.dart](test/widget_test.dart) | Проверка запуска и увеличения счётчика |
| [pubspec.yaml](pubspec.yaml), [pubspec.lock](pubspec.lock) | SDK constraint, dependencies и разрешённые версии |
| [analysis_options.yaml](analysis_options.yaml) | Dart analyzer и lint rules |
| `android/`, `ios/` | Native scaffolds и платформенные настройки |

</div>

Feature modules, theme tokens, маршруты и data sources добавляются по мере
реальных сценариев; сейчас их нет. Brand originals находятся в
[assets/branding](../../assets/branding/) и пока не подключены к Flutter assets.

---

## Типовые сценарии

### Проверить Flutter-основу

Запусти приложение на Android-устройстве/эмуляторе или iOS-устройстве/симуляторе.
Стартовый экран StackCard и изменяющийся счётчик проверяют bootstrap и состояние.

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
