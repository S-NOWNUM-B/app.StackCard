# Светлый web StackCard — 2026-10-11

Прямое поручение: адаптировать дизайн [Openship](https://openship.io/) под
StackCard, удалить тёмную тему web и расширить страницы. Flutter redesign
отложен до оценки web пользователем. Это реализация текущего web scope Phase 13,
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

White-only относится к web rendering и выбору оформления. Cloud/mobile
`dark | light` schema остаётся совместимой: старые документы читаются, фон
web всегда светлый, автоматической миграции и Save при открытии нет.
Auth, UID boundaries, CAS Save, Publish, public parser и recovery сохраняются.

[Проверки](../product/product-spec.md#проверки-светлого-web--2026-10-11):
97/97 web tests, typecheck, format и production build PASS; desktop/phone/tablet,
навигация, demo switch, FAQ и focus просмотрены в настоящем браузере.
Отличия от референса намеренные: русский текст StackCard, исходные Manrope/Brand A,
собственная HTML-композиция документов, светлые секции и маршруты своего продукта.
Пользовательская приёмка и live backend сценарии остаются отдельными результатами.
