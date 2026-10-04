# Контракт редизайна StackCard

Цель: полностью переработать существующий мобильный UI developer-портфолио,
убрав вложенные карточки, избыток текста и однообразный серый интерфейс.
Canonical visual direction: [design-system.md](design-system.md).

| Свидетельство | Достоверность | Вывод |
| --- | --- | --- |
| Прикреплённый пользователем референс трёх телефонов | observed | Крупные headlines, цельные lime/pink поверхности, круговые CTA, графика |
| Просьба сохранить палитру и расширить в киберпанк | provided | Obsidian + Signal Red сохраняем, добавляем acid/cyan/pink |
| [21st Tabs](https://21st.dev/blog/react-tabs-components), [Minimal Button](https://21st.dev/%40radiumcoders/components/minimal-button), [Settings](https://news.21st.dev/blog/react-settings-page-components) | observed | Компактный active indicator, минимальные controls, плоские группы |
| Текущие theme/shared widgets и screens | observed | Изменяем существующую систему, сохраняем слои и состояния |
| Геометрическая графика вместо anime-персонажей | inferred | Собственный образ продукта, автономный renderer, без внешних assets |

| Референс | Keep | Change | Do not copy |
| --- | --- | --- | --- |
| Три телефона | Seamless composition, большие цвета, типографика, круглые действия | Developer content, ru/en, accessibility и реальные workflows | Персонажи, ABYTE, NFT-claims, точные layout/text |
| 21st.dev components | Короткие controls, раскрытие деталей по требованию, sections/dividers | Flutter widgets и существующая навигация | React dependencies, рекламная copy и несвязанные effects |
| GitKraken screenshot | Существующая ветка `redesign/full-app` | UI мобильного приложения | UI GitKraken не является design reference |

Выбранное направление: редакционный cyberpunk с чёрной основой, цветными
постерами и графикой из геометрических лент. Открытые секции разделяются
типографикой, отступами и линиями. Главный CTA очевиден, вторичные действия
компактны. У каждого экрана собственный визуальный ритм.

Уточнение пользователя: на экранах авторизации большой розовый poster лишний.
Вход, регистрация и сброс пароля используют компактный brand и форму без слогана
и декоративной графики; полезные действия расположены выше.

Риски: overflow русских строк и text scale 2, контраст на bright panels,
сохранение keys/actions существующих tests, выразительность без лишней графики.
Unknown: native iOS readiness не подтверждается widget renders.

- [x] Единое направление и источники решений зафиксированы.
- [x] Палитра, type, grid, components, motion, voice, anti-patterns определены.
- [x] Все существующие экраны адаптированы и проверены.
- [x] Flutter renders просмотрены в light/dark; narrow/large-text layouts проверены tests.
- [x] Critical auth/draft/import/sync actions проходят existing tests.
