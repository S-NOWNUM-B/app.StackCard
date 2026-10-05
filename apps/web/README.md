<div align="center">

# StackCard Web

**План отдельного сайта, web-редактора и публичных Resume/Portfolio**

![Web Next.js planned](https://raster.shields.io/badge/Web-Next.js_planned-09090B?style=for-the-badge)
![Stage Phase 13 planned](https://raster.shields.io/badge/Stage-Phase_13_planned-FF0012?style=for-the-badge)

</div>

---

## Содержание

- [Назначение](#назначение)
- [Что хранится здесь](#что-хранится-здесь)
- [Типовые сценарии](#типовые-сценарии)
- [Правила](#правила)

---

## Назначение

Каталог предназначен для отдельного Next.js-приложения StackCard: главной
о проекте, страницы скачивания mobile, защищённого web-редактора и публичных
Resume/Portfolio. Это второй редактор общей профессиональной базы и
публичный вход в продукт; текущий runtime ещё использует singleton draft.

Сейчас здесь только README. Приложение, dependencies,
конфигурация и команды запуска появятся на Phase 13 по
[roadmap](../../docs/product/product-spec.md#roadmap).
Принятые основы и flows [StackCard Design v2 R1–R5](../../docs/redesign/README.md)
задают текущий target; весь [web-дизайн R6.1–R6.4](../../docs/redesign/screens.md#r6--веб-поверхности)
принят D040; evidence D039:24состояния/96wide-narrow Dark-Light frames.
Structural/contrast/CTA checks PASS; visual inspection/preview/run пропущены
по запросу. Next.js scaffold, зависимости, routes и deployment не созданы;
Figma target не означает работающую веб-функцию.
R7 source graph/structural QA PASS D041; [пакет](../../docs/redesign/source/r7-handoff.json)
awaiting_review, явная пользовательская приёмка/DESIGN_READY pending. D040 уже разрешило R8/R9 на
`redesign/full-app`; независимый существующий Flutter slice перенесён и
проверен950headless tests/analyze, но это не создаёт web runtime. Новый
Next.js, workspace model и trusted public projection предложены в
[prerequisites](../../docs/redesign/prerequisites.md), статус proposed/scope
ответа нет. Full R8/R9 и DESIGN_READY/REDESIGN_DONE не закрыты.
No-preview/run сохранён, commit/push/deploy не запрошены; Phase13/Phase11
не начинаются автоматически из авторизации UI-переноса.

---

## Что хранится здесь

<div align="center">

| **Материал** | **Назначение** |
|:---|:---|
| `README.md` | Scope сайта, будущие сценарии и границы этой области |

</div>

Страницы, components, styles, auth и data access ещё не созданы.
Их размещение определяется при реализации по фактическим configs и правилам
[архитектуры](../../docs/architecture/architecture.md#web-и-общие-контракты).
Пустые packages и web scaffolds заранее не добавляются.

---

## Типовые сценарии

Все сценарии ниже — план, а не готовые маршруты.

### Познакомиться с проектом и скачать mobile

Главная объяснит пользу, возможности и путь создания портфолио.
Страница скачивания покажет поддерживаемые платформы и действительные способы
установки после появления релизов; ссылки не должны обещать отсутствующую сборку.

### Редактировать базу и документы

После входа владелец сможет управлять DeveloperProfile, Projects Library и
разными Resume/Portfolio; wide layout допускает параметры рядом с preview,
narrow layout использует отдельные modes. Save, sync ACK и explicit Publish
различимы; новая правка draft не меняет public snapshot автоматически.
Web v1 планируется online-first, с одним аккаунтом и общими ownership/data
contracts; миграция нынешнего singleton остаётся отдельной предпосылкой.

### Посмотреть опубликованный документ

Каждый Resume/Portfolio показывает только опубликованный snapshot, без входа,
private draft/account data и owner controls; missing/unpublished имеют отдельные
состояния. [D019](../../docs/redesign/plan.md#журнал-решений) приняло постоянный
адрес документа, сохраняемый при rename и смене username; duplicate не
наследует публичную ссылку исходного документа. Конкретные document IDs/route scheme/migration ещё не реализованы.
`/u/[username]` — прежний singleton-план Phase 13 и username-based adapter,
не обещание уже работающего адреса Design v2. SEO/metadata/OpenGraph остаются
Phase 13; Contact me/Inbox — Phase 14.

---

## Правила

- перед работой прочитай [общие правила](../../docs/AI/AGENTS.md) и [AI router](../../docs/AI/README.md);
- создавай приложение и выбирай команды только на подтверждённой фазе;
- сохраняй общие data contracts, ownership и явную публикацию из [архитектуры](../../docs/architecture/architecture.md);
- различай публичные страницы и защищённый редактор, route guards не заменяют checks доступа к данным;
- используй принятый [Design v2](../../docs/redesign/README.md) и согласованные R3–R5 tokens/components; прежний [design guide](../../docs/design/design-system.md) описывает runtime/историю, а не актуальный Figma target;
- проверяй responsive layout, keyboard/focus, UI states и фактическую доступность download/CTA;
- не связывай mobile с React runtime ради общих визуальных идей.
