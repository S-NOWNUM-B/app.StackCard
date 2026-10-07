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
публичный вход в продукт. Mobile уже хранит общую базу/Library и несколько
private Resume/Portfolio в одном aggregate; будущий web использует тот же контракт.

Сейчас здесь только README. Приложение, dependencies,
конфигурация и команды запуска пока отсутствуют. Приоритеты — в
[актуальном roadmap](../../docs/product/product-spec.md#актуальная-последовательность-2026-10-08).
Минимальный public runtime/reader может работать с публикациями mobile до полного
owner web editor; точные URL и trusted publication contract фиксируются до реализации.
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
Next.js и trusted public projection остаются планом из
[prerequisites](../../docs/redesign/prerequisites.md). D045/D046 уже реализовали
private mobile documents/base review и совместимые Hive6/cloud5 adapters;
это не создаёт web runtime и не реализует public lifecycle. Full R8/R9 и DESIGN_READY/REDESIGN_DONE не закрыты.
No-preview/run сохранён; обновление roadmap 2026-10-08 не запускает web/deploy
автоматически и не закрывает full Figma/native приёмку.

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
contracts. Реализованный mobile private aggregate повторно не создаётся;
совместимость fixtures/readers/writers и public migration проверяются отдельно.

### Посмотреть опубликованный документ

Каждый Resume/Portfolio показывает только опубликованный snapshot, без входа,
private draft/account data и owner controls; missing/unpublished имеют отдельные
состояния. [D019](../../docs/redesign/plan.md#журнал-решений) приняло постоянный
адрес документа, сохраняемый при rename и смене username; duplicate не
наследует публичную ссылку исходного документа. Private document IDs уже реализованы в mobile; permanent public IDs, route
scheme и migration прежней публикации остаются планом.
`/u/[username]` — прежний singleton-план Phase 13 и username-based adapter,
не обещание уже работающего адреса Design v2. SEO/metadata/OpenGraph остаются
Phase 13; Contact me/Inbox — Phase 14.

---

## Правила

- перед работой прочитай [общие правила](../../docs/AI/AGENTS.md) и [AI router](../../docs/AI/README.md);
- создавай runtime по явно разрешённой задаче и dependency contracts актуального roadmap;
- сохраняй общие data contracts, ownership и явную публикацию из [архитектуры](../../docs/architecture/architecture.md);
- различай публичные страницы и защищённый редактор, route guards не заменяют checks доступа к данным;
- используй принятый [Design v2](../../docs/redesign/README.md) и согласованные R3–R5 tokens/components; прежний [design guide](../../docs/design/design-system.md) описывает runtime/историю, а не актуальный Figma target;
- проверяй responsive layout, keyboard/focus, UI states и фактическую доступность download/CTA;
- не связывай mobile с React runtime ради общих визуальных идей.
