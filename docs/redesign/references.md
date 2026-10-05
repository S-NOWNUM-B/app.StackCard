<div align="center">

# StackCard Design v2 — референсы

**Проверенные источники, приёмы и границы их применения в редизайне**

![Reference audit R0](https://raster.shields.io/badge/References-R0_audit-111111?style=for-the-badge)
![Direction A selected](https://raster.shields.io/badge/Direction-A_selected-C7FF1A?style=for-the-badge)

</div>

---

## Содержание

- [Статус и метод проверки](#статус-и-метод-проверки)
- [Визуальная подача](#визуальная-подача)
- [Структура содержимого](#структура-содержимого)
- [Конкретные компоненты 21st](#конкретные-компоненты-21st)
- [Проверки доступности](#проверки-доступности)
- [Шрифты R3.1](#шрифты-r31)
- [Иконки R3.2](#иконки-r32)
- [Assets R3.3](#assets-r33)
- [Состояния и motion R3.4](#состояния-и-motion-r34)
- [Источники экранов R4](#источники-экранов-r4)
- [Источники сценариев R5](#источники-сценариев-r5)
- [Применение в StackCard](#применение-в-stackcard)
- [Ограничения и следующий шаг](#ограничения-и-следующий-шаг)

---

## Статус и метод проверки

Срез проверки — 2026-10-05. Это результат R0: источники прочитаны, публичные
изображения просмотрены, несколько демонстраций проверены в браузере.
Этот исторический срез предшествовал выбору направления/логотипа R2.
Теперь бренд A принят D024; fonts review R3.1 добавлен D027. R3.3 принята D032;
state/adapt/motion specimens R3.4 и полная R3 приняты D034 после review D033.
R4.1–R4.7c приняты D036 после review D035; следующая R5 ожидает review D037
по интерпретации продолжения с прежним full-phase/parallel/no-preview режимом; визуальный просмотр/preview/run
пропущены по прямому запросу D034, не считаются пройденной проверкой.
Результаты исходного исследования ниже не переаттестованы.
Правила переноса заданы в [требованиях](requirements.md#референсы-и-сохранность-проекта):
`REQ-REFERENCE-01..02`; применение планируется в [R1–R8](plan.md), экраны
обозначены по [карте S-*](screens.md#целевые-экраны).

«Визуально» ниже означает просмотр реально отрисованной страницы или shot в
браузере. «По исходнику» — чтение публичного registry/source; это не результат
запуска всех его ветвей. Текст web-извлечения использован для документации и
ссылок, но сам по себе не считается просмотром изображения. В приватные
аккаунты не входили, доступный исходник не разблокировали платным действием.

Палитра референсов не переносится. Продукт использует закреплённые роли
[StackCard](requirements.md#визуальное-направление-и-палитра): фон `#070708`,
поверхности `#0D0E11` / `#14161B` / `#1B1E24`, акценты `#C7FF1A` /
`#6FE7F2` / `#FF6AB2` / `#9B7BFF`. Красный остаётся только для ошибок и
destructive. Светлая тема получает свои семантические поверхности; лайм на
белом не становится мелким текстом. Референсы — варианты приёмов для сравнения
двух направлений R2, а не готовое направление.

---

## Визуальная подача

### REF-01 — Cyberpunk mobile app concept

Источник: [shot Aleksey Kostiuk](https://dribbble.com/shots/24939208-Cyberpunk-mobile-app-concept).
Доступ: страница и изображение открылись публично; визуально просмотрена
композиция из трёх мобильных экранов. Полный интерактивный flow не представлен.

На shot видны крупная угловатая display-типографика, доминирующее изображение
товара, резко различающиеся светлая, синяя и красная сцены. Информация о товаре
собрана в отдельной контрастной панели. Это приём локальной выразительности
через изображение и форму, а не основание делать весь продукт декоративным.

Для StackCard кандидат — выразительная обложка Project, первый экран публичного
Portfolio и showcase на сайте. Он помогает отличать работы человека от
редакторских форм: `S-PROJECTS`, `S-PUBLIC-PORTFOLIO`, `S-WEB-LANDING`.
В R2 можно проверить геометрию и display-акцент, сохранив обычную типографику
описаний и читаемую документную композицию Resume.

Не переносим красно-синюю палитру, e-commerce категории, покупку, вращённые
служебные надписи, огромную иллюстрацию в каждом экране и мелкие контролы.
Shot не доказывает доступность или адаптивность. Лицензия на графику и код на
странице не подтверждена: изображения, логотипы, рендеры и шрифтовые начертания
автора не включаются в продукт; создаются собственные материалы.

### REF-02 — App Dark Cyberpunk

Источник: [shot Manuel Rovira / Orizon](https://dribbble.com/shots/7438663-App-Dark-Cyberpunk).
Доступ: публичная страница и shot визуально просмотрены. Видны три тёмных
мобильных экрана с авторизацией и плиточным содержимым; реальные состояния
формы, ошибки и навигация не проверены.

Наблюдаемый приём — спокойная тёмная основа с контрастным медиа, тонкими линиями
и повторяемыми срезами углов плиток. Для StackCard можно сравнить один
сдержанный геометрический мотив в обложках и новом знаке: `S-PROJECTS`,
`S-PORTFOLIOS`, `S-PUBLIC-PORTFOLIO`. Это кандидат на характер бренда, который
не мешает чтению полей редактора.

Не переносим нижнее меню из пяти иконок без постоянных подписей, игровые
декорации, фоновые изображения под формой и декоративный body-шрифт.
`REQ-NAV-01` уже требует четыре root-раздела с видимыми названиями. Размеры
контролов из статичного shot не служат спецификацией hit area. Разрешение на
чужие изображения, фирменный знак и код не установлено; используются только
принципы композиции и собственные ассеты.

### REF-03 — Openship

Источник: [публичный сайт Openship](https://openship.io/).
Доступ: визуально просмотрены hero, продуктовый preview и начало секций;
структура последовательности действий дополнительно прочитана с сайта.
Работа платформы и её панели управления не тестировалась.

На странице крупный короткий заголовок, иерархия двух CTA, свободное пространство
и заметный preview настоящего интерфейса. Последующая последовательность
действий объясняет продукт постепенно. Для `S-WEB-LANDING` это решает проблему
сайта, который показывает стиль, но не объясняет путь от общей базы человека
к Resume, Projects и Portfolio. R6.1 использует собственный preview и понятные
доступные действия входа/скачивания.

Не переносим лозунги, терминальную команду установки, инфраструктурную лексику,
чужие метрики, панель/сайдбар на Home и наклонённые preview как обязательный
формат. Палитра Openship не определяет light-theme StackCard.
Лицензирование его кода не проверено до уровня конкретного файла; сайт,
брендовые изображения и screenshot не считаются свободными ассетами.
Копирование не предлагается.

---

## Структура содержимого

### REF-04 — Framer CMS

Источник: [публичная страница Framer CMS](https://www.framer.com/cms/).
Доступ: визуально просмотрены hero и демонстрация списка коллекции; текст
страницы описывает Fields, Drafts & publishing и preview перед публикацией.
Это маркетинговые демонстрации, а не проверенный сеанс в рабочем CMS.

Наблюдаемый приём — повторяемые строки содержимого с названием, thumbnail и
прикладными полями, плюс отдельные средства редактирования и публикации.
Для StackCard он помогает воспринимать библиотеку как материал для нескольких
outputs, а не как dashboard готовности. Применение: `S-HOME`, `S-RESUMES`,
`S-PROJECTS`, `S-PORTFOLIOS`, selectors редакторов и `S-WEB-WORKSPACE`.
Разделение Save и Publish поддерживает `REQ-EDITOR-03` и `S-PUBLISH`.

Не переносим категории Framer в Projects, плотную desktop-таблицу на телефон,
сайдбар на mobile/tablet, AI-chat, автоматическую публикацию после сохранения,
CMS-архитектуру или возможности bulk-edit без продуктового основания.
Не делаем статус draft/saved/published свидетельством существующей backend
реализации. Лицензия на интерфейсные изображения и исходный код Framer не
проверена; их не копируем и Framer CMS как сервис не подключаем.

---

## Конкретные компоненты 21st

Проверены заданные [каталог tabs](https://21st.dev/community/components/explore/react-tabs),
[каталог stepper](https://21st.dev/community/components/explore/react-stepper)
и [21st](https://21st.dev/). Каталоги используются для поиска; ниже закреплены
три конкретных компонента с авторами и ограничениями. Они не образуют набор
библиотек для установки. Для Flutter переносятся взаимодействия и композиция,
для будущего web выбор кода возможен только после согласованной системы R3.

### REF-05 — ARC Animated Tabs

Источник: [Animated Tabs, kuratlielia](https://21st.dev/@kuratlielia/components/tabs).
В публичном preview проверены выбор `Overview → Activity` и переход клавишей
ArrowRight к `Settings`: меняются выбранная вкладка и её содержимое.
Видны текстовые вкладки и единый перемещаемый индикатор. Overflow и системный
reduced-motion в браузере не проверялись.

Публичный [registry tabs.json](https://raw.githubusercontent.com/kuratlielia/arc-library/main/public/r/tabs.json)
содержит TSX/CSS, зависимости `@radix-ui/react-tabs`, `lucide-react`, `motion`
и registry-зависимость [arc-foundation](https://uiarc.dev/r/arc-foundation.json).
Её URL не удалось прочитать web-инструментом. В исходнике tabs есть клавиатурная семантика
Radix, подписанные кнопки прокрутки и `useReducedMotion`; поведение последнего
подтверждено чтением, не OS-тестом. Весь foundation и транзитивные версии не
аудированы. [MIT](https://github.com/kuratlielia/arc-library/blob/main/LICENSE)
требует сохранить copyright и permission notice при копировании кода.

Приём для `S-HOME` и R3.2 — компактное текстовое переключение с одним ясным
active-состоянием. Оно поддерживает `REQ-HOME-01`: только Все / Резюме / Проекты.
Фильтр списка проектируется как фильтр, без механического переноса tabpanel.
Нельзя превращать его во вторую root-навигацию, копировать чужие цвета или
скрывать названия. Flutter-реализация будет собственной; web-копирование
зависит от проверки полного registry, focus и reduced-motion.

### REF-06 — ReUI Progress Bar Stepper

Источник: [Progress Bar Stepper, Sean Hello](https://21st.dev/@sean0205/components/c-stepper-11).
В preview видны четыре тонкие полосы, подписи этапов и отдельный content.
Проверен прямой переход с `Payment Info` к `Preview Form`: предыдущие полосы
заполняются по позиции, без подтверждения заполненной формы.

Вкладка полного `Component.tsx` на 21st закрыта механизмом Unlock Code.
Открытый [registry c-stepper-11.json](https://reui.io/r/c-stepper-11.json)
показывает demo-wrapper с `defaultValue={2}` и `registryDependencies: ["@reui/stepper"]`.
Пустой массив npm dependencies wrapper не означает отсутствие зависимостей.
Базовый [Stepper](https://reui.io/docs/components/base/stepper) — отдельный
React/Tailwind primitive. Публичный [base source](https://github.com/keenthemes/reui/blob/main/registry-reui/bases/base/reui/stepper.tsx)
импортирует `@base-ui/react/merge-props`, `@base-ui/react/use-render` и локальный
`cn`; содержит tab-семантику и клавиатурные обработчики. Совпадение издания
registry с этим source и полная транзитивная цепочка/версии не проверены.

Приём для `S-RESUME-WIZARD`, `S-PORTFOLIO-EDITOR` и R3.3 — локальный указатель
текущего этапа с «Шаг N из 5», при сохранении ввода при Back: `REQ-RESUME-02`.
Не переносим demo-названия, свободный прыжок к финалу с ложным completed,
dashboard/progress готовности на Home и фиксированную ширину desktop-strip.

[Условия ReUI](https://reui.io/legal/license) отделяют бесплатные examples/
primitives с MIT от платных blocks/templates; публичный репозиторий содержит
[MIT LICENSE.md](https://github.com/keenthemes/reui/blob/main/LICENSE.md).
Ссылка `reui.io/docs/license` из карточки ведёт на Introduction и не доказывает
лицензию. При будущем копировании нужен точный публичный файл, проверка
принадлежности к бесплатной части и сохранение notice. Сейчас переносится
принцип, код не копируется.

### REF-07 — Motion Primitives Animated Tabs / Segmented Control

Источник: [Animated Tabs, ibelick / Julien Thibeaut](https://21st.dev/@ibelick/components/animated-tabs).
Вариант `Segmented Control` визуально просмотрен; клик `Day → Week` переместил
светлую подложку под Week. Связанный список содержимого отсутствует: проверено
выделение сегмента, не фильтрация продуктовых данных.

Карточка указывает `framer-motion` и `lucide-react`; usage использует
`AnimatedBackground`. Текущий [package.json автора](https://github.com/ibelick/motion-primitives/blob/main/package.json)
использует пакет `motion`: совпадение старой карточки с текущей версией исходника
не подтверждено. [MIT](https://github.com/ibelick/motion-primitives/blob/main/LICENCE.md)
подтверждена в официальном репозитории; при копировании сохраняется notice.
[Документация AnimatedBackground](https://motion-primitives.com/docs/animated-background)
при web-чтении ответила 403, поэтому детали
полного primitive и reduced-motion здесь не утверждаются.

Приём — спокойная подложка active-фильтра `S-HOME`, альтернативный вариант к
REF-05 в R3.2. Usage icon-only варианта содержит кнопки `h-9 w-9` без доступных
названий; размер 36px и иконки без текста не годятся для root StackCard.
Не переносим hover как единственный способ выбора, пружину с bounce и
само название «tabs» без нужной семантики. Hit area ≥48 logical px, подписи,
focus, selected-state и статический reduced-motion проектируются отдельно.

### Исключённый кандидат

[Tabs, edwinvakayil](https://21st.dev/@edwinvakayil/components/r-tabs) проверен
по метаданным: указаны `motion`, `@radix-ui/react-tabs` и внешний source.
Лицензия точного исходника не подтверждена; живой preview не тестировался.
Он не предлагается для переноса кода и не нужен сверх проверенных REF-05–07.

---

## Проверки доступности

### REF-08 — Flutter: дизайн доступного интерфейса

Источник: [Accessibility — UI design and styling](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling).
Доступ: прочитан официальный документ, визуальный макет из него не оценивался.
Он задаёт проверяемые ограничения, а не стиль: учёт системного размера текста,
контраст и минимальные цели касания.

Для всех S-* проверяются крупнейшие поддерживаемые настройки текста на
маленьком экране; элементы сохраняют подписи и функции без обрезания.
Требование пользователя ≥48 logical px применяется и на iOS, хотя документ
указывает для iOS минимум 44pt. Приём решает риск компактных референсов с
нечитаемыми контролами: R3.2/R3.3, R7 и R8; `C16` и контракт hit area.

Не переносим web-навигацию или Material-внешний вид как обязательный бренд.
Текст Flutter-документа лицензирован CC BY 4.0, code samples — BSD 3-Clause
по footer; здесь только ссылка и собственные проектные условия.

### REF-09 — Flutter: проверка доступности

Источник: [Accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing).
Доступ: прочитана официальная документация. В R0 проверки Flutter из неё
не запускались и не выдаются за пройденную приёмку.

Приём — сочетать Guideline API для tap targets, подписей и text contrast с
ручной проверкой Android Accessibility Scanner / iOS Accessibility Inspector.
Для StackCard это обнаруживает мелкие icon-actions, потерянные labels и
неправильные цвета на реальных контролах. Применение: все интерактивные S-*,
R7-прототип и соответствующие widget/native проверки в R8.

Не считаем тест размеров и контраста доказательством качества всех состояний,
screen-reader порядка, text-scale или готовности iOS-запуска. Раздел Flutter
web не меняет заданную архитектуру отдельного Next.js-продукта. Условия
документа/примеров: CC BY 4.0 / BSD 3-Clause; примеры сейчас не копируются.

### REF-10 — WCAG: контраст текста

Источник: [Understanding SC 1.4.3 — Contrast Minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
Доступ: прочитан официальный объясняющий документ к критерию, а не выполнен
аудит соответствия StackCard целиком.

Приём — проверять конкретные пары foreground/background: ≥4.5:1 для обычного
текста и ≥3:1 для крупного; значение ниже порога не округляется вверх для pass.
Применение: `C14`, все S-*, обе темы и active/disabled/error состояния R3/R7/R8.
Особенно проверяются secondary/muted на elevated-поверхностях и тёмный текст
в кнопках с lime/cyan/pink/violet fill.

Не считаем яркость неона доказательством контраста и не расширяем исключение
для логотипов на меню, кнопки или содержимое Resume. Текст W3C не копируется;
страница используется как основание числовых условий. Это не заявление о
полной WCAG-сертификации Flutter-приложения.

---

## Шрифты R3.1

Срез **2026-10-05, D027**. Официальный Google Fonts metadata подтверждает
Latin/Latin-ext и Cyrillic/Cyrillic-ext для всех трёх кандидатов;
лицензии прочитаны отдельно. Это проверка языковых subsets и условий
распространения, не доказательство native rendering.

| **Семейство** | **Официальный metadata / лицензия** | **Варианты и границы** |
|:---|:---|:---|
| Noto Sans | [metadata](https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/METADATA.pb), [OFL](https://raw.githubusercontent.com/google/fonts/main/ofl/notosans/OFL.txt) | normal/italic, weight100–900, width62.5–100; уже bundled baseline |
| Manrope | [metadata](https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/METADATA.pb), [OFL](https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/OFL.txt) | normal, weight200–800; основной альтернативный кандидат |
| Golos Text | [metadata](https://raw.githubusercontent.com/google/fonts/main/ofl/golostext/METADATA.pb), [OFL](https://raw.githubusercontent.com/google/fonts/main/ofl/golostext/OFL.txt) | normal, weight400–900; третий сравниваемый вариант |

Все три — SIL OFL1.1; при будущем включении binaries сохраняются copyright и
license. Назначение Golos для длительного экранного чтения описано в
[официальном проекте](https://github.com/googlefonts/golos-text).
Начертания Manrope400/600/700/800 дополнительно подтверждены
[source config](https://raw.githubusercontent.com/googlefonts/manrope/master/sources/config.yaml).
Фактический Figma font API отдельно подтвердил Regular/SemiBold/Bold/ExtraBold
всех трёх. Default full_name в metadata не используется как название style.

[Font Review138:19](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard?node-id=138-19)
показывает одинаковые ru/en, glyphs, metadata12/13 и static reflow16/32.
Manrope рекомендован по визуальному сравнению: выразительнее display при
спокойном body. После поручения продолжить закреплена эта рекомендация D028;
это интерпретация продолжения, отдельного сообщения о семействе не было.
Wordmark A/палитра/прежние shared styles сохранены;10 новых Manrope styles — Figma UI;
новые fonts/dependencies не установлены. Android/iOS shaping и OS scaling
остаются отдельной проверкой. [Evidence и IDs](screens.md#пересмотр-foundations-и-шрифта-d026d027).

---

## Иконки R3.2

Срез2026-10-05, D029. Source SVGs проверены как editable vectors без scripts,
images/href/external paints; badges используют настоящее текстовое имя.
Ни package, ни runtime asset этим шагом не добавлены.

| **Источник** | **Использованные assets / условия** |
|:---|:---|
| [Lucide pinned500620a2](https://github.com/lucide-icons/lucide/tree/500620a2e8123f8d1db191538886dc0c223f69a9/icons), [LICENSE](https://raw.githubusercontent.com/lucide-icons/lucide/500620a2e8123f8d1db191538886dc0c223f69a9/LICENSE) | house(home), file-text, folder, panels-top-left, settings, arrow-left, copy, check, image, ellipsis(more-horizontal). ISC; arrow-left/check/ellipsis также MIT Feather-derived. Полные copyright/ISC/MIT notices сохранены в Figma153:6036 |
| [Simple Icons pinned98820a4d](https://github.com/simple-icons/simple-icons/tree/98820a4dc8c363ca72fa2c0d294ea4a0a9bba75d/icons), [metadata](https://raw.githubusercontent.com/simple-icons/simple-icons/98820a4dc8c363ca72fa2c0d294ea4a0a9bba75d/data/simple-icons.json), [CC0 project](https://raw.githubusercontent.com/simple-icons/simple-icons/98820a4dc8c363ca72fa2c0d294ea4a0a9bba75d/LICENSE.md) | react.svg #61DAFB / typescript.svg #3178C6: shapes не изменены, icon18 на Ink tile24; label нейтральная. Individual license metadata отсутствует; CC0 проекта не доказывает права на любой брендовый знак |
| [React source MIT](https://raw.githubusercontent.com/facebook/create-react-app/282c03f9525fdf8061ffa1ec50dce89296d916bd/LICENSE) | Исходный source repository, указанный Simple Icons, проверен отдельно; trademark права не подменяются MIT |
| [TypeScript branding](https://www.typescriptlang.org/branding/) | Официальный single-color cut-out variant разрешён для идентификации технологии; shape не менять, не включать в логотип приложения и не подразумевать endorsement |
| [Flutter official archive](https://flutter.dev/flutter-brand-assets.zip), [guidelines](https://docs.flutter.dev/brand) | Flutter/icon_flutter/icon_flutter_wht.svg: approved white logomark, original shape/white/opacity0.72 сохранены; aspect ratio вписан в24 grid. Технологическая идентификация, не часть StackCard mark |
| [Dart official archive](https://services.google.com/fh/files/misc/dart_brand_guidelines_assets.zip), [guidelines](https://dart.dev/brand) | Dart Brand Guidelines Assets/Logomark (Icon)/icon_dart_knockout.svg: original knockout shape/fill/opacity, на Ink tile |

[Simple Icons disclaimer](https://github.com/simple-icons/simple-icons/blob/98820a4dc8c363ca72fa2c0d294ea4a0a9bba75d/DISCLAIMER.md)
отделяет CC0 проекта от прав на индивидуальные marks; отсутствие license metadata
не означает отсутствия ограничений. Simple Icons Flutter/Dart monochrome paths
не использованы: выбран approved knockout из официальных archives.
Все четыре технологии показываются только в badges, без endorsement или смешивания
с собственным логотипом. React/TypeScript color roles остаются `technology/*`,
не новой брендовой палитрой. Native distribution notices/exports — отдельный gate R8.

---

## Assets R3.3

Срез2026-10-05, D031; компоненты приняты D032. R3.3 расширяет прежний набор
шестью нужными Lucide SVG:
camera, user-round, chevron-down, grip-vertical, pencil, plus.
Источник — тот же [pinned commit500620a2](https://github.com/lucide-icons/lucide/tree/500620a2e8123f8d1db191538886dc0c223f69a9/icons)
и [LICENSE](https://raw.githubusercontent.com/lucide-icons/lucide/500620a2e8123f8d1db191538886dc0c223f69a9/LICENSE).
XML/viewBox24/vector-only/no scripts/href/external paint проверены; оригинальные
paths сохранены. ISC для всех, chevron-down/plus также MIT Feather-derived;
полные notices уже есть в153:6036, source inventory расширен. Роли stroke
семантические; собственная геометрия вместо оригинальных icons не рисовалась.

PhotoControl использует собственный [демопортрет](assets/r33-demo-portrait.png),
созданный built-in image_gen.imagegen для этого specimen. [Metadata](assets/r33-demo-portrait.json)
сохраняет точный prompt, source/type=generated_demo,1254×1254 PNG и SHA256
`4579846cf4006cfb403562a1ecfb9ee4920da4e9e9c2fc8f974b9509487ff67d`.
Bytes скопированы без редактирования, raster загружен через upload_assets;
выбранное фото явно подписано «Демопортрет · вымышленный человек».
Изображение не обозначается фотографией пользователя или лицензированным stock;
не входит в Flutter assets/pubspec. Реальные camera/gallery/profile media,
permission/storage/cancel и фотографии конечного пользователя — будущая реализация.
Generated demo не заменяет подтверждение прав на реальные пользовательские assets.

---

## Состояния и motion R3.4

Срез2026-10-05, D033. R3.4 переиспользует принятые Manrope styles,
semantic color/metrics и R3.2–R3.3 components/icons. Новые изображения,
icon sources, fonts или packages не добавлены. Проектные основания —
[REQ-EDITOR-03](requirements.md#req-editor-03--данные-и-ограниченное-оформление),
[адаптивность и motion](requirements.md#адаптивность-и-motion):
REQ-ADAPT-01..03 и REQ-MOTION-01..02. Новый внешний visual source не заявляется.

Шесть событий и обычные180/240/280ms transitions документированы
[в DS specimens R3.4](screens.md#r34--состояния-motion-и-адаптивность).
Reduced/static0ms сохраняет те же title/status/selected/check и доступность
действия. Existing motion/slow исправлен300→280, fast180/standard240
сохранены; easing `cubic-bezier(0.2, 0, 0, 1)`. Bounce и длительности
внешних tabs/stepper demos не перенесены. Board задаёт editable контракт;
проигрываемый motion-прототип R7.3 и native implementations R8 этим шагом
не проверены.

StatePanel и LifecycleStatus показывают18 variants в Dark/Light. Working,
persistence и publication независимы: local Saved/server Synced не
обновляют public snapshot. Адаптивные320/390/430/768/844 fixtures используют
existing contentMaxWidth600, четыре bottom tabs и horizontal actions.
REF-08/09/10 остаются основаниями checks размеров, labels и контраста;
статические Figma measurements не подменяют native accessibility acceptance.

---

## Источники экранов R4

Scope D034 — все девять задач R4.1–R4.7c одним пакетом; результат D035
принят D036. Экраны собраны из принятой DS R3: Manrope/brand A, semantic tokens, shared
Navigation/Cards/TechnologyBadge/Forms/Photo/CollectionRow/StatePanel и
LifecycleStatus. Повторное использование сохраняет указанные выше sources
и license notices; новых icon packs или изображений автоматически не добавляет.
Единственный дополнительный asset — [Lucide search.svg](https://raw.githubusercontent.com/lucide-icons/lucide/500620a2e8123f8d1db191538886dc0c223f69a9/icons/search.svg)
из того же pinned commit500620a2. XML/vector-only/viewBox24 и отсутствие
scripts/images/href проверены; SHA256
`283d371c2e433817bb9c0c8310caa6c77fa4177c0f4f1168d9c83b97af7389dc`.
Source/license notices переиспользуют прежний [Lucide LICENSE](https://raw.githubusercontent.com/lucide-icons/lucide/500620a2e8123f8d1db191538886dc0c223f69a9/LICENSE)
и полные ISC/MIT notices в153:6036. SearchIcon184:2762 и отдельный
SearchField184:2784 (Empty184:2766/Filled184:2772/Focus184:2778) добавлены
для поиска Projects после отсутствия совместимого local/library компонента.
Экран поиска не получает дополнительного заголовка; остальные assets
переиспользованы из R3. Runtime assets/dependencies не добавлялись.

Визуальный просмотр, preview и запуск приложения пропускаются по прямому
запросу. Metadata/contrast/bindings checks не обозначаются visual review.
[Фактический реестр и QA R4](screens.md#r4--основные-экраны-и-настройки)
содержит9boards/61states/122Dark-Light frames; palette values/styles/variable counts сохранены
без drift; onPrimary расширен STROKE_COLOR scope без смены color values. ProjectListItem185:2771 и PortfolioListItem188:2861 — scoped
compositions прежних R3 elements; новых media/font sources не добавлено.
R5 flows собраны отдельно в scope D036–D037; backend/media/schema
и native implementation остаются будущими отдельно разрешаемыми результатами.

---

## Источники сценариев R5

Следующая R5 начата D036 после приёмки всего пакета R4. Поручение продолжить
интерпретировано в сохранённом full-phase/parallel/no-preview режиме;
пользователь не перечислял все 13 задач R5 буквально. Wizard/edit/import/review/
attachments/publication используют принятые fonts/tokens/assets R3–R4:
Manrope, brand A, Lucide/Simple Icons/official Flutter-Dart и помеченный
R3.3 generated_demo Portrait. Новые external visual sources, icons, fonts или media не добавлены.
Три scoped DS families DocumentIdentity193:2864 (photo/no-photo),
ChangeComparison193:2865 и ProjectAssociationRow193:2872 составлены из прежних
shared controls/assets. Все14IMAGE fills — тот же generated_demo Portrait80×80,
imageHash `c5809a5c0f968bd8ed1f163a5adfeb2d0b2a077b`.
98variable values и50style IDs сохранены точно;274originalFlutter/Dart VECTOR
fills retained — только targeted canonical source-brand exemption.

Save, private sync ACK и explicit Publish остаются отдельными результатами;
import/source review не перезаписывают curated/public данные автоматически.
R5 static specimens не доказывают работу native camera/gallery, SDK/OAuth,
cloud publication или реального sharing. Визуальный просмотр/preview/run
остаются пропущенными по сохранённому запросу. [Реестр и QA R5](screens.md#r5--создание-редактирование-и-публикация)
фиксируют13boards/83states/166Dark-Light frames,18failure categories0,
3474text samples min4.832909811:1,1280stroke samples min4.364564811:1,
966targets≥48 и48actual identity checks PASS. Wizard1–5/16preview/84forms/
152fixedfooter проверены структурно; SafeArea padding20 — static geometry.
Весь пакет awaiting_review D037; R6+ и runtime R8 не начаты.

---

## Применение в StackCard

Связь с задачами показывает, где принцип проверяется, а не что уже реализовано.

<div align="center">

| **Проблема и приём** | **Экран и условие приёмки** |
|:---|:---|
| REF-01/02: выразительность через собственную обложку и геометрию | S-PROJECTS, S-PUBLIC-PORTFOLIO; две различимые гипотезы R2, читаемый body |
| REF-03: продукт объясняется preview и последовательностью | S-WEB-LANDING; R6.1, реальные CTA и собственные материалы |
| REF-04: библиотека, редактор и Publish различимы | S-HOME, S-PUBLISH, S-WEB-WORKSPACE; REQ-HOME-01, REQ-EDITOR-03, R6.3 |
| REF-05 или REF-07: один ясный активный фильтр | S-HOME; R3.2, только Все / Резюме / Проекты, независимая root navigation |
| REF-06: прогресс текущего создания | S-RESUME-WIZARD; REQ-RESUME-02, R3.3, данные сохраняются при Back |
| REF-08/09: размеры, labels, масштаб текста | Все S-*; ≥48 logical px, C16, keyboard/SafeArea, native-проверки R8 |
| REF-10: роли цвета проверяются числами | Все S-*; C14, обе темы, без замены закреплённой палитры |

</div>

`REQ-TECH-02` проверяется отдельно: название технологии остаётся настоящим
текстом, а целый badge не заменяется растровой картинкой. Чужие icon packs не добавляются автоматически
вместе с tabs; лицензия и source каждого переносимого ассета проверяются.
Обычные transitions приводятся к 180–280ms, а reduced-motion имеет статическую
альтернативу (`C-MOTION`); длительности и bounce чужих демонстраций не становятся
токенами StackCard.

---

## Ограничения и следующий шаг

Все заданные внешние URL проверены. Обе Dribbble-композиции, Openship и
публичная CMS-демонстрация Framer просмотрены визуально; для трёх выбранных
21st-компонентов зафиксированы реальные действия. Просмотрена текущая
desktop-демонстрация, а не набор mobile/tablet, light/dark, keyboard/OS состояний.

Открытые ограничения для возможного web-копирования: полный source stepper
на 21st закрыт, а публичный base source не сопоставлен точному изданию
`@reui/stepper`; ARC foundation недоступен web-инструменту; версия старого
Motion Primitives registry не сопоставлена текущему
репозиторию; документация его AnimatedBackground ответила 403. Они не мешают
выбрать принципы для собственного Flutter UI, но не разрешают объявить React-код
готовым к установке. Лицензии брендовых/иллюстративных материалов не получены.

R1 проверяет информационные сценарии, R2 сравнивает две новые системы на
одинаковых pilot-экранах, R3 определяет компоненты и их состояния. Лишь затем
конкретный перенос может быть принят или отклонён. R0 завершается предложением
плана для согласования; исследование не разрешает переход к макетам или коду.

Оформление и локальные ссылки проверены скриптом `project-documentation`
с `--require-hero --require-badges`: ошибок не найдено.
Продуктовые макеты и Markdown-render в целевом viewer в рамках этого
исследования не создавались и визуально не принимались.
