# Контракт редизайна StackCard

Новый запрос 2026-10-04 задаёт Figma-first UX/UI refactor: сначала аудит,
IA, target design system и целостные flows, затем Flutter/web. Он явно заменяет
прежние решения о Signal Red, одиночном Portfolio и root Settings.
Canonical visual contract — [design-system.md](design-system.md), scope/acceptance —
[redesign-plan.md](redesign-plan.md).

| Свидетельство | Достоверность | Следствие |
| --- | --- | --- |
| Новые требования пользователя, 31 раздел | provided | Четыре сущности, multiple outputs, lime вместо red, Figma до кода |
| [StackCard Figma](https://www.figma.com/design/3YhNUPDIJJWB39NSBxbRr6/StackCard) | observed через MCP | Исходный аудит: 9 pages, 31 COMPONENT/COMPONENT_SET узел; результаты итерации и IDs — в plan |
| Flutter routing/theme/domain | observed | Home/Portfolio/Projects/Settings, red primary, один content с resumeText и global featured |
| [Web README](../../apps/web/README.md) и tree | observed | Web runtime отсутствует; website design не равен готовому Next.js-приложению |
| [Openship](https://openship.io/) | observed web benchmark | Светлая бело-чёрная страница, крупные заголовки с italic акцентом, paired CTA и product visuals; dark palette задаёт пользователь, а не этот сайт |
| [21st.dev stepper](https://21st.dev/@sean0205/components/c-stepper-11), [Motion Primitives](https://21st.dev/@ibelick/library/motion-primitives) | observed pattern references | Иерархия шагов и interaction feedback адаптируются к mobile; готовые React controls не являются Flutter/Figma components |
| Cyberpunk reference, упомянутый в требованиях | provided description | Editorial rhythm/controlled neon; отсутствующие pixels не считать изученным screenshot |

Target: DeveloperProfile и Projects Library переиспользуются в нескольких
Resumes/Portfolios. Visibility/featured/order принадлежат PortfolioProject
association; inline create создаёт global Project + attach. Resume — structured
CV с selectors, visibility/overrides и photo. [Plan](redesign-plan.md) задаёт relations.

Направление: neutral dark foundation, lime primary, cyan/pink artwork,
DM Sans/Noto Sans, сильная hierarchy и occasional metadata mono. Основной
viewport 390 px; четыре постоянных tab labels, contextual Settings и nested
Back. Larger screens сохраняют mental model и centered content без sidebar.

| Keep | Change | Не переносить |
| --- | --- | --- |
| Logo geometry и архив оригиналов | Lime recolor в новых Figma assets | Red как target brand/CTA |
| Source review/overrides, offline Save, auth/guest/UID, notes | Presentation/discoverability | Automatic overwrite/publish при refresh |
| Focused editors, order/visibility, preview | Named Portfolios и structured Resumes | Plain Resume textarea, global Featured, дублирование Project |
| Matte auth controls и читаемая форма | Общая lime система | Большой decorative poster за формой |
| Existing theme/tokens/shared widgets | Новые semantic targets | Параллельная runtime UI library |
| Openship: hierarchy, product visuals, paired actions | Neutral dark/lime mobile composition | Полная web-страница и её light palette |
| 21st.dev: stepper и feedback | Пять содержательных creation шагов, touch targets | Сборка интерфейса из несвязанных templates |

Риски: IA требует будущей singleton storage/publication migration; camera/gallery
и permission flows не реализованы; connection не должен блокировать current
public GitHub username import; Copy не обещает URL unpublished output.
Light/large text/keyboard/contrast требуют самостоятельной проверки.

История прежнего redesign и executed checks сохраняется в
[product spec](../product/product-spec.md#редизайн-мобильного-интерфейса).
Прежние completed checkboxes относились к старому Flutter UI и не принимаются
как результат нового Figma target. Runtime/Rules/dependencies/storage и
original branding sources этой итерацией не изменяются.
