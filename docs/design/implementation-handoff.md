# Перенос нового дизайна StackCard

Handoff описывает **следующую реализацию**, а не выполненный перенос.
Сейчас scope — [Figma-first plan](redesign-plan.md): audit, IA,
[design system](design-system.md) и пять key screens. Полный Flutter/web refactor
начинается после целостного Figma flow и согласованного scope implementation.
Прежняя runtime-приёмка — в [product spec](../product/product-spec.md#редизайн-мобильного-интерфейса).

## До реализации

Прочитать root/nested AGENTS, AI router, mobile/Firebase scope, актуальные
manifests/domain/theme/shared widgets и public feature APIs. Сверить Figma
components/variables/layouts/states через MCP; screenshots дополняют структуру.
Сопоставить затронутые contracts с architecture/ADR.

Current code содержит один PortfolioContent, один Firestore draft и singleton
publication. Multiple outputs требуют контракта migration/legacy data,
IDs/slugs, sync/UID boundary; не реализуются одним переименованием tabs.
Schema/Rules migration не входит в эту Figma итерацию.

## Точки переноса

| Область | Existing integration point и задача |
| --- | --- |
| Colors/type/spacing | `apps/mobile/lib/core/theme`; semantic tokens без screen-local HEX |
| Components | `apps/mobile/lib/shared/widgets`; адаптировать existing и расширять по flows |
| Navigation | `app/app_router.dart`, `app/app_shell.dart`; четыре labels, Settings/back, guards/deep links |
| Source data | Public profile/projects/portfolio_draft/github_import APIs; без concrete sources в widgets |
| Output model | Pure selections/overrides/associations + migration до multiple outputs |
| Persistence/publication | Hive/Firestore codecs/Rules/ADR; Save отдельно от sync и publication |
| Web | `apps/web` пока README; собственные Next.js components и общий data contract |

Base Profile/Projects Library — source stores. Add existing создаёт association;
Create inline создаёт global Project + attach. Remove from Portfolio сохраняет
Project. Featured/visible/order не принадлежат global Project; Resume overrides
не меняют base Profile.

## Сохраняемое поведение

- Account/explicit guest/UID isolation; stale action не применяется к другому owner.
- Read failure не включает demo; corrupted/unknown storage не перезаписывается.
- Save сохраняет input при ошибке и новые edits во время записи; Saved/Synced различаются.
- GitHub search/pagination/cache, explicit Add/Accept/Ignore и curated overrides.
- Private notes/source metadata не public; sync не публикует автоматически.
- Unsaved reload/sign out подтверждаются; photo permission denial имеет recovery.
- ru/en, keyboard-safe forms, long content, semantics и reduced motion.

Creation progress только в flow. Editor использует autosave local draft +
Saved/Saving либо доступный sticky Save; стратегия определяется в implementation
contract и не меняет существующую persistence семантику молча.

## Проверка переноса

Проверить 320/390/large phone, landscape, upscaled mobile max-width 600,
text scale 1/2, dark/light, ru/en, keyboard; full/empty/loading/error/offline,
permission/copy success/deletion. Published outputs имеют Copy/Share/Open;
unpublished не обещают публичный URL.

После runtime edits выполнить соответствующие format/analyze, behavior/DI/domain/
migration/Rules tests и визуальный просмотр Flutter renders. Native Android/iOS
acceptance отдельно; web checks по созданным manifests/scripts. Figma frames
и прежние passing tests не подтверждают новый runtime.
