import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_icon.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../portfolio_draft/portfolio_draft.dart';
import '../projects/projects.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _filter = 0;
  @override
  Widget build(BuildContext context) {
    ref.listen(portfolioDraftRepositoryProvider, (previous, next) {
      if (previous != null && !identical(previous, next)) {
        setState(() => _filter = 0);
      }
    });
    return WorkspaceReadGate(
      data: (content) {
        final entries =
            <({DateTime? date, String id, Widget card})>[
              if (_filter != 2)
                for (final document in content.documents)
                  if (_filter == 0 ||
                      document.kind == PortfolioDocumentKind.resume)
                    (
                      date: document.updatedAt,
                      id: document.id,
                      card: PortfolioDocumentCard(document: document),
                    ),
              if (_filter != 1)
                for (final project in content.projects)
                  (
                    date: project.updatedAt,
                    id: project.id,
                    card: _HomeProjectCard(project: project),
                  ),
            ]..sort((a, b) {
              if (a.date == null && b.date == null) return a.id.compareTo(b.id);
              if (a.date == null) return 1;
              if (b.date == null) return -1;
              final dateOrder = b.date!.compareTo(a.date!);
              return dateOrder == 0 ? a.id.compareTo(b.id) : dateOrder;
            });
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StackCardSize.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in [
                      (0, 'workspace.all'),
                      (1, 'nav.resumes'),
                      (2, 'nav.projects'),
                    ]) ...[
                      if (item.$1 != 0)
                        const SizedBox(width: StackCardSpacing.sm),
                      Expanded(
                        child: Semantics(
                          selected: _filter == item.$1,
                          child: TextButton(
                            key: ValueKey('home.filter.${item.$1}'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              foregroundColor: context.colors.textPrimary,
                              backgroundColor: _filter == item.$1
                                  ? context.colors.surfaceHover
                                  : Colors.transparent,
                              side: _filter == item.$1
                                  ? BorderSide(
                                      color: context.colors.controlOutline,
                                    )
                                  : null,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  StackCardRadius.medium,
                                ),
                              ),
                            ),
                            onPressed: () => setState(() => _filter = item.$1),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_filter == item.$1) ...[
                                  StackCardIcon(
                                    name: 'check',
                                    size: 16,
                                    color: context.colors.accentText,
                                  ),
                                  const SizedBox(width: StackCardSpacing.sm),
                                ],
                                Flexible(
                                  child: Text(
                                    context.strings.tr(item.$2),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: StackCardSpacing.lg),
                if (entries.isEmpty)
                  StackCardStateView(
                    kind: StackCardViewState.empty,
                    title: context.strings.tr('workspace.emptyHome'),
                    message: context.strings.tr('workspace.emptyHomeHint'),
                  ),
                for (final entry in entries) ...[
                  entry.card,
                  const SizedBox(height: StackCardSpacing.lg),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeProjectCard extends StatelessWidget {
  const _HomeProjectCard({required this.project});
  final PortfolioProject project;
  @override
  Widget build(BuildContext context) => ProjectLibraryCard(
    key: ValueKey('home.project.card.${project.id}'),
    openKey: ValueKey('home.project.${project.id}'),
    title: project.title,
    description: project.description,
    technologies: project.technologies,
    sourceLabel: project.source == PortfolioProjectSource.github
        ? 'GitHub${project.githubMetadata?.acceptedSource == null ? '' : ' · ${project.githubMetadata!.acceptedSource.fullName}'}'
        : context.strings.tr('filter.manual'),
    imagePaths: project.imagePaths,
    updatedAt: project.updatedAt,
    liveUrl: project.liveUrl,
    onOpen: () =>
        context.push('/projects/${Uri.encodeComponent(project.id)}/edit'),
  );
}
