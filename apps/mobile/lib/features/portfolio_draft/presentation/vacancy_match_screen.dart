import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../media/media.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_pdf.dart';
import '../domain/vacancy_match.dart';
import '../portfolio_pdf_providers.dart';
import '../vacancy_providers.dart';
import 'portfolio_draft_controller.dart';

const _sectionTitles = {
  PortfolioBlockKind.skills: 'Навыки',
  PortfolioBlockKind.featuredProjects: 'Проекты',
  PortfolioBlockKind.experience: 'Опыт',
  PortfolioBlockKind.education: 'Образование',
  PortfolioBlockKind.links: 'Контакты',
};

/// Подбор под вакансию. Текст живёт только в памяти экрана: не попадает
/// в draft, Hive, Firestore и историю версий.
class VacancyMatchScreen extends ConsumerStatefulWidget {
  const VacancyMatchScreen({super.key});

  @override
  ConsumerState<VacancyMatchScreen> createState() => _VacancyMatchState();
}

class _VacancyMatchState extends ConsumerState<VacancyMatchScreen> {
  final _text = TextEditingController();
  VacancyMatch? _match;
  PortfolioContent? _matchedSaved;
  Set<String> _projects = {};
  Set<PortfolioBlockKind> _sections = {};
  bool _exporting = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  PortfolioContent? _saved() {
    final workspace = ref.read(portfolioDraftControllerProvider).draft?.content;
    if (workspace == null) return null;
    final saved = resolvedMainPortfolioContent(workspace);
    return saved != null && portfolioHasDisplayContent(saved) ? saved : null;
  }

  bool get _longEnough => _text.text.trim().length >= vacancyMinimumLength;

  void _compare() {
    final saved = _saved();
    if (saved == null || !_longEnough) return;
    final match = matchVacancy(vacancyText: _text.text, content: saved);
    final relevant = match.projects.where((item) => item.score > 0);
    setState(() {
      _match = match;
      _matchedSaved = saved;
      // По умолчанию в PDF идут релевантные проекты (или все, если их нет).
      _projects = {
        for (final item in relevant.isEmpty ? match.projects : relevant)
          item.projectId,
      };
      _sections = mainPortfolioSectionKinds.toSet();
    });
  }

  void _applyOrder() {
    final match = _match;
    if (match == null) return;
    ref
        .read(mainPortfolioEditorOrderProvider.notifier)
        .request(
          VacancyOrder(
            projects: match.projectOrder,
            sections: match.sectionOrder,
          ),
        );
    context.go('/editor');
  }

  Future<void> _export() async {
    final match = _match;
    final saved = _matchedSaved;
    final actions = ref.read(portfolioPdfFileActionsProvider);
    if (match == null || saved == null || _exporting) return;
    void message(String text) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    }

    if (actions == null) {
      message('Сохранение PDF недоступно на этом устройстве');
      return;
    }
    setState(() => _exporting = true);
    try {
      final content = buildVacancyExportContent(
        saved,
        projectOrder: match.projectOrder,
        includedProjects: _projects,
        sectionOrder: match.sectionOrder,
        includedSections: _sections,
      );
      Uint8List? avatar;
      final showsProfile = content.blocks.any(
        (block) => block.kind == PortfolioBlockKind.profile && block.visible,
      );
      if (showsProfile && content.profile.avatarPath.isNotEmpty) {
        final media = ref.read(portfolioMediaRepositoryProvider);
        if (media == null) {
          throw const PortfolioPdfFailure(PortfolioPdfFailureKind.unavailable);
        }
        avatar = await media.read(content.profile.avatarPath);
      } else if (showsProfile && content.profile.avatarUrl.isNotEmpty) {
        avatar = await ref
            .read(portfolioLegacyAvatarReaderProvider)
            .read(content.profile.avatarUrl);
      }
      final bytes = await ref
          .read(portfolioPdfGeneratorProvider)
          .generate(content, avatarBytes: avatar);
      final done = await actions.savePdf(
        bytes,
        filename: 'stackcard-vacancy.pdf',
      );
      if (done) message('PDF под вакансию сохранён');
    } catch (_) {
      message('Не удалось сохранить PDF. Повторите попытку');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(portfolioDraftControllerProvider);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final saved = _saved();
    final match = _match;
    Widget body;
    if (!draft.loaded && draft.failure == null) {
      body = const StackCardStateView(
        kind: StackCardViewState.loading,
        title: 'Загрузка',
      );
    } else if (draft.failure != null && !draft.loaded) {
      body = StackCardStateView(
        kind: StackCardViewState.error,
        title: 'Не удалось прочитать портфолио',
        onRetry: ref.read(portfolioDraftControllerProvider.notifier).load,
      );
    } else if (saved == null) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StackCardStateView(
            kind: StackCardViewState.empty,
            title: 'Сначала заполните портфолио',
            message:
                'Сохраните основное портфолио в Редакторе, затем вернитесь',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StackCardSpacing.lg,
            ),
            child: StackCardButton(
              key: const Key('vacancy.openEditor'),
              label: 'Открыть Редактор',
              onPressed: () => context.go('/editor'),
            ),
          ),
        ],
      );
    } else {
      body = ListView(
        key: const Key('vacancy.list'),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(StackCardSpacing.lg),
        children: [
          Text(
            'Вставьте текст вакансии. Он обрабатывается на устройстве и нигде не сохраняется',
            style: text.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.md),
          StackCardInput(
            key: const Key('vacancy.input'),
            label: 'Текст вакансии',
            hint: 'Требования, стек, обязанности',
            controller: _text,
            minLines: 5,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {
              // Результат относится к прежнему тексту: экспорт и порядок скрыты.
              _match = null;
            }),
          ),
          if (_text.text.trim().isNotEmpty && !_longEnough)
            Padding(
              padding: const EdgeInsets.only(top: StackCardSpacing.xs),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Слишком короткий текст: нужно хотя бы $vacancyMinimumLength символов',
                  key: const Key('vacancy.tooShort'),
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ),
            ),
          const SizedBox(height: StackCardSpacing.md),
          StackCardButton(
            key: const Key('vacancy.compare'),
            label: match == null ? 'Сопоставить' : 'Сопоставить снова',
            role: match == null
                ? StackCardButtonRole.primary
                : StackCardButtonRole.outlined,
            onPressed: _longEnough ? _compare : null,
          ),
          if (match != null) ...[
            const SizedBox(height: StackCardSpacing.xl),
            ..._result(context, match),
          ],
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подбор под вакансию'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/projects'),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StackCardSize.contentMaxWidth,
            ),
            child: body is ListView ? body : SingleChildScrollView(child: body),
          ),
        ),
      ),
    );
  }

  List<Widget> _result(BuildContext context, VacancyMatch match) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (match.noRequirements) {
      return const [
        StackCardStateView(
          key: Key('vacancy.noRequirements'),
          kind: StackCardViewState.noResults,
          title: 'Требования не найдены',
          message: 'В тексте нет знакомых технологий и направлений. Проверьте, что вставлен полный текст вакансии',
        ),
      ];
    }
    Widget chips(Iterable<VacancyRequirement> items, {required bool ok}) =>
        Wrap(
          spacing: StackCardSpacing.sm,
          runSpacing: StackCardSpacing.sm,
          children: [
            for (final item in items)
              Chip(
                avatar: Icon(
                  ok ? Icons.check_rounded : Icons.close_rounded,
                  size: 16,
                  color: ok ? colors.successText : colors.textSecondary,
                ),
                label: Text(item.term.label, overflow: TextOverflow.ellipsis),
                backgroundColor: colors.surfaceElevated,
                side: BorderSide(color: colors.border),
              ),
          ],
        );
    final relevantProjects = match.projects;
    return [
      Semantics(
        liveRegion: true,
        child: Text(
          'Совпало ${match.matchedCount} из ${match.totalCount}',
          key: const Key('vacancy.summary'),
          style: text.titleLarge,
        ),
      ),
      Text(
        '${match.percent}% соответствия',
        key: const Key('vacancy.percent'),
        style: text.bodyMedium?.copyWith(color: colors.textSecondary),
      ),
      if (match.matchedCount == 0)
        Padding(
          padding: const EdgeInsets.only(top: StackCardSpacing.sm),
          child: Text(
            'Совпадений нет: в портфолио не нашлось ни одного требования',
            key: const Key('vacancy.noMatches'),
            style: text.bodyMedium,
          ),
        ),
      if (match.matchedRequirements.isNotEmpty) ...[
        const SizedBox(height: StackCardSpacing.lg),
        Semantics(
          header: true,
          child: Text('Совпало', style: text.titleMedium),
        ),
        const SizedBox(height: StackCardSpacing.sm),
        chips(match.matchedRequirements, ok: true),
      ],
      if (match.missingRequirements.isNotEmpty) ...[
        const SizedBox(height: StackCardSpacing.lg),
        Semantics(
          header: true,
          child: Text('Не хватает', style: text.titleMedium),
        ),
        const SizedBox(height: StackCardSpacing.sm),
        chips(match.missingRequirements, ok: false),
      ],
      if (relevantProjects.isNotEmpty) ...[
        const SizedBox(height: StackCardSpacing.xl),
        Semantics(
          header: true,
          child: Text('Проекты: релевантность и PDF', style: text.titleMedium),
        ),
        const SizedBox(height: StackCardSpacing.sm),
        for (final item in relevantProjects)
          CheckboxListTile(
            key: Key('vacancy.project.${item.projectId}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _projects.contains(item.projectId),
            onChanged: (value) => setState(
              () => value == true
                  ? _projects.add(item.projectId)
                  : _projects.remove(item.projectId),
            ),
            title: Text(item.title),
            subtitle: Text(
              item.matched.isEmpty
                  ? 'Совпадений нет'
                  : 'Совпало ${item.score}: ${item.matched.join(', ')}',
            ),
          ),
      ],
      if (match.experience.any((item) => item.score > 0)) ...[
        const SizedBox(height: StackCardSpacing.lg),
        Text('Релевантный опыт', style: text.titleMedium),
        const SizedBox(height: StackCardSpacing.sm),
        for (final item in match.experience.where((item) => item.score > 0))
          Padding(
            padding: const EdgeInsets.only(bottom: StackCardSpacing.xs),
            child: Text('${item.role}: ${item.matched.join(', ')}'),
          ),
      ],
      const SizedBox(height: StackCardSpacing.xl),
      Semantics(
        header: true,
        child: Text('Разделы: порядок и PDF', style: text.titleMedium),
      ),
      const SizedBox(height: StackCardSpacing.sm),
      for (final kind in match.sectionOrder)
        CheckboxListTile(
          key: Key('vacancy.section.${kind.name}'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _sections.contains(kind),
          onChanged: (value) => setState(
            () => value == true ? _sections.add(kind) : _sections.remove(kind),
          ),
          title: Text(
            '${match.sectionOrder.indexOf(kind) + 1}. ${_sectionTitles[kind] ?? kind.name}',
          ),
        ),
      Text(
        'Отметки определяют, что попадёт в PDF. Порядок применяется в Редакторе',
        style: text.bodySmall?.copyWith(color: colors.textMeta),
      ),
      const SizedBox(height: StackCardSpacing.lg),
      StackCardButton(
        key: const Key('vacancy.apply'),
        label: 'Применить порядок',
        role: StackCardButtonRole.primary,
        onPressed: _applyOrder,
      ),
      const SizedBox(height: StackCardSpacing.sm),
      StackCardButton(
        key: const Key('vacancy.export'),
        label: 'Экспорт PDF под вакансию',
        role: StackCardButtonRole.secondary,
        loading: _exporting,
        onPressed: _exporting ? null : _export,
      ),
      const SizedBox(height: StackCardSpacing.lg),
      StackCardCard(
        outlined: true,
        child: Text(
          'Это подсказка по ключевым словам, а не оценка работодателя',
          style: text.bodySmall?.copyWith(color: colors.textMeta),
        ),
      ),
    ];
  }
}
