# Светлый StackCard — web и Flutter, 2026-10-11

Прямое поручение: адаптировать дизайн [Openship](https://openship.io/) под
StackCard, удалить тёмную тему web и расширить страницы. Пользователь одобрил
web и 2026-10-11 поручил перенести этот дизайн в Flutter: только light,
русский интерфейс и контент StackCard. Это реализация текущего mobile/web UI scope Phase 13,
не переход к следующей продуктовой фазе.

Референс просмотрен в браузере на desktop 1280×720 и phone 390×844.
Переносимые приёмы: белая поверхность, овальная навигация, чёрные CTA,
центрированный крупный hero, светлая вторичная строка, мягкое свечение за
продуктовой композицией, тонкие разделители, numbered sections и многоколоночный
footer. Тёмные секции Openship переводятся в светлые. Текст, product visuals,
маршруты и взаимодействия принадлежат StackCard; чужие dashboard/assets не копируются.
Локальные Manrope/Brand A/icons и лицензии сохраняются.

## Карта страниц и владельцы

| Приём референса | StackCard route | Source |
| --- | --- | --- |
| Главная и product preview | `/` | `apps/web/src/app/page.tsx`, `components/product-demo.tsx` |
| Capabilities | `/features` | `apps/web/src/app/features/page.tsx` |
| Product scenarios | `/use-cases` | `apps/web/src/app/use-cases/page.tsx` |
| Product examples | `/examples` и существующие `/examples/resume`, `/examples/portfolio` | `apps/web/src/app/examples` |
| Docs/support | `/help` | `apps/web/src/app/help/page.tsx` |
| About | `/about` | `apps/web/src/app/about/page.tsx` |
| Download | `/download` | `apps/web/src/app/download/page.tsx` |
| Shared navigation, footer, typography | Все web routes | `components/ui.tsx`, `components/marketing.tsx`, `app/globals.css` |

Все новые CTA ведут на реальные маршруты. Мобильные store-релизы отсутствуют;
страница приложения сохраняет честный статус. Product preview обозначен как
демонстрационный, не читает private данные и не создаёт fake owner session.

White-only относится к web и Flutter rendering и выбору оформления. Cloud/mobile
`dark | light` schema остаётся совместимой: старые документы читаются, фон
обоих клиентов всегда светлый, автоматической миграции и Save при открытии нет.
Flutter runtime фиксирует русский locale даже при legacy en preferences.
Новые документы получают light; сохранённый пользовательский текст не переводится.
Auth, UID boundaries, CAS Save, Publish, public parser и recovery сохраняются.

[Проверки](../product/product-spec.md#проверки-светлого-web--2026-10-11):
97/97 web tests, typecheck, format и production build PASS; desktop/phone/tablet,
навигация, demo switch, FAQ и focus просмотрены в настоящем браузере.
Отличия от референса намеренные: русский текст StackCard, исходные Manrope/Brand A,
собственная HTML-композиция документов, светлые секции и маршруты своего продукта.
Пользователь одобрил web; мобильная оценка и live backend сценарии остаются
отдельными результатами.

## Перенос в Flutter

`core/theme` и `shared/widgets` сохраняют один механизм: белый фон,
нейтральные поверхности, чёрный primary/белый onPrimary, Manrope и Brand A.
Shell получает овальный брендированный header и нижнюю навигацию, Home —
две строки «Ваша работа. Ваша история.», библиотеки — крупные заголовки
и тонкие разделители. Вход, формы, Settings, Inbox и preview наследуют тему.
Переключатели темы/языка удалены; порядок/видимость секций, reduced motion
и настройки источника сохранены. Legacy dark/en поля по-прежнему читаются
и не переписываются при открытии. Отдельной dark палитры нет.

Параллельный чат «Проверить соответствие требованиям» владеет auth provider
metadata и горизонтальной строкой аккаунта. Разделение согласовано по явному
разрешению пользователя; новая SettingsAppearanceScreen сохраняет его
SettingsScreen, rows и account actions.

Исходные Figma registry/IDs/values сохраняются как provenance. Текущая палитра
и `headlineLarge` описаны в `runtimeSourceMap.acceptedOverrides` существующего
`apps/mobile/assets/design_v2/source-manifest.json`. `check_imports.py` проверяет
этот принятый runtime вместе с прежними 30 color roles, 10 text styles,
19 numeric mappings и SHA/font/SVG/license checks; dark обязан alias light.

[Flutter проверки](../product/product-spec.md#проверки-светлого-flutter--2026-10-11):
1242/1242 tests, analyze, итоговая Android debug build/install и 114 responsive/
Builder cases — PASS. 32 текущих light PNG просмотрены; iOS runtime и мобильная
оценка пользователем остаются отдельными результатами.
