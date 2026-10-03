import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../profile/profile.dart';
import '../projects/projects.dart';
import '../portfolio/portfolio.dart';
import '../portfolio_draft/portfolio_draft.dart';
import '../../shared/widgets/stackcard_async_view.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => StackCardAsyncView(
    state: ref.watch(portfolioOverviewProvider),
    onRetry: () {
      ref.read(portfolioDraftControllerProvider.notifier).load();
      ref.invalidate(profileProvider);
      ref.invalidate(projectsProvider);
    },
    data: (overview) => _HomeContent(overview: overview),
  );
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.overview});

  final PortfolioOverview overview;

  @override
  Widget build(BuildContext context) {
    final pageTextColor = Theme.of(context).brightness == Brightness.light
        ? context.colors.textPrimary
        : context.colors.textSecondary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= 760 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.7;
        return SingleChildScrollView(
          padding: EdgeInsets.all(
            constraints.maxWidth >= 700
                ? StackCardSpacing.xl
                : StackCardSpacing.lg,
          ),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overview.hasDraft && overview.profile.firstName.isEmpty
                        ? context.strings.tr('builderIntegration.welcome')
                        : context.strings.tr('home.greeting', {
                            'name': overview.profile.firstName,
                          }),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    context.strings.tr(
                      overview.hasDraft
                          ? 'builderIntegration.homeSubtitle'
                          : 'home.subtitle',
                    ),
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: pageTextColor),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _ProfileHero(
                            profile: overview.profile,
                            hasDraft: overview.hasDraft,
                          ),
                        ),
                        const SizedBox(width: StackCardSpacing.lg),
                        Expanded(
                          flex: 4,
                          child: _ReadinessCard(
                            readiness: overview.profile.readiness,
                            hasDraft: overview.hasDraft,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _ProfileHero(
                      profile: overview.profile,
                      hasDraft: overview.hasDraft,
                    ),
                    const SizedBox(height: StackCardSpacing.lg),
                    _ReadinessCard(
                      readiness: overview.profile.readiness,
                      hasDraft: overview.hasDraft,
                    ),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  _SectionHeading(
                    title: context.strings.tr('home.featured'),
                    subtitle: context.strings.tr(
                      overview.hasDraft
                          ? 'builderIntegration.featuredSubtitle'
                          : 'home.featuredSubtitle',
                    ),
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _FeaturedProject(
                            project: overview.highlightedProject,
                          ),
                        ),
                        const SizedBox(width: StackCardSpacing.lg),
                        Expanded(
                          flex: 4,
                          child: _WorkspaceCard(overview: overview),
                        ),
                      ],
                    )
                  else ...[
                    _FeaturedProject(project: overview.highlightedProject),
                    const SizedBox(height: StackCardSpacing.lg),
                    _WorkspaceCard(overview: overview),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  StackCardCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.science_outlined,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: StackCardSpacing.md),
                        Expanded(
                          child: Text(
                            context.strings.tr(
                              overview.hasDraft
                                  ? 'builderIntegration.localNote'
                                  : 'home.demoNote',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.hasDraft});

  final Profile profile;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEVELOPER PORTFOLIO',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(StackCardRadius.large),
                  border: Border.all(color: context.colors.border),
                ),
                child: Text(
                  profile.initials,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: StackCardSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name.isEmpty
                          ? context.strings.tr(
                              'builderIntegration.emptyProfile',
                            )
                          : profile.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: StackCardSpacing.xs),
                    Text(
                      profile.role,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Text(
            context.strings.tr(
              hasDraft ? 'builderIntegration.yourStory' : 'home.hero',
            ),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: StackCardSpacing.md),
          Text(
            hasDraft
                ? (profile.about.isEmpty
                      ? context.strings.tr('builderIntegration.aboutHint')
                      : profile.about)
                : context.strings.tr('home.heroDescription'),
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Wrap(
            spacing: StackCardSpacing.md,
            runSpacing: StackCardSpacing.md,
            children: [
              StackCardButton(
                label: context.strings.tr('home.myPortfolio'),
                icon: Icons.arrow_forward_rounded,
                primary: true,
                onPressed: () => context.push('/portfolio'),
              ),
              StackCardButton(
                label: context.strings.tr('nav.projects'),
                icon: Icons.grid_view_rounded,
                onPressed: () => context.push('/projects'),
              ),
              if (hasDraft)
                StackCardButton(
                  label: context.strings.tr('builderIntegration.edit'),
                  icon: Icons.edit_outlined,
                  onPressed: () => context.push('/portfolio/builder'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.readiness, required this.hasDraft});

  final ProfileReadiness readiness;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.donut_large_rounded,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: StackCardSpacing.sm),
              Expanded(
                child: Text(
                  context.strings.tr('home.readiness'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Text(
            '${readiness.percent}%',
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            context.strings.tr(
              hasDraft
                  ? 'builderIntegration.readiness'
                  : 'home.readinessDescription',
              {
                'completed': readiness.completedBlocks,
                'total': readiness.totalBlocks,
              },
            ),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Semantics(
            label: context.strings.tr(
              hasDraft
                  ? 'builderIntegration.readinessSemantics'
                  : 'home.readinessSemantics',
              {'percent': readiness.percent},
            ),
            child: ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(StackCardRadius.small),
                child: LinearProgressIndicator(
                  value: readiness.fraction,
                  minHeight: 6,
                  color: context.colors.accent,
                  backgroundColor: context.colors.surfaceHover,
                ),
              ),
            ),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Divider(color: context.colors.borderSubtle),
          const SizedBox(height: StackCardSpacing.md),
          _CompactInfo(
            icon: Icons.visibility_off_outlined,
            title: context.strings.tr('common.draft'),
            description: context.strings.tr('home.unpublished'),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          _CompactInfo(
            icon: Icons.add_link_rounded,
            title: context.strings.tr('home.publicLink'),
            description: context.strings.tr('home.afterPublish'),
          ),
        ],
      ),
    );
  }
}

class _FeaturedProject extends StatelessWidget {
  const _FeaturedProject({required this.project});

  final Project? project;

  @override
  Widget build(BuildContext context) {
    final project = this.project;
    if (project == null) {
      return StackCardCard(
        child: StackCardStateView(
          kind: StackCardViewState.empty,
          title: context.strings.tr('home.noFeatured'),
          message: context.strings.tr('home.noFeaturedMessage'),
        ),
      );
    }
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(StackCardSpacing.xl),
            decoration: BoxDecoration(
              color: context.colors.surfaceElevated,
              borderRadius: BorderRadius.circular(StackCardRadius.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: StackCardSpacing.sm,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: context.colors.textSecondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: StackCardSpacing.xl),
                Text(
                  '${project.symbol} / ${project.title.split(' ').first.toUpperCase()}',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: StackCardSpacing.sm),
                Text(
                  project.id == null
                      ? 'Less noise. More craft.'
                      : project.description,
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: StackCardSpacing.xl),
                Wrap(
                  spacing: StackCardSpacing.sm,
                  runSpacing: StackCardSpacing.sm,
                  children: [
                    for (final label
                        in project.id == null
                            ? ['Components', 'Typography', 'Themes']
                            : project.technologies)
                      _Tag(label: label),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(project.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            project.description,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          StackCardButton(
            label: context.strings.tr('home.viewProjects'),
            icon: Icons.arrow_outward_rounded,
            onPressed: () => context.push('/projects'),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  const _WorkspaceCard({required this.overview});

  final PortfolioOverview overview;

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.tr('home.workspace'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StackCardSpacing.xl),
          _CompactInfo(
            icon: Icons.layers_outlined,
            title: context.strings.projectCount(overview.projects.length),
            description: context.strings.tr('home.featuredCount', {
              'count': overview.featuredProjects.length,
            }),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          _CompactInfo(
            icon: Icons.code_rounded,
            title: context.strings.skillCount(overview.profile.skills.length),
            description: context.strings.tr('home.development'),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Divider(color: context.colors.borderSubtle),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            context.strings.tr('home.githubTitle'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            context.strings.tr('home.githubNote'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CompactInfo extends StatelessWidget {
  const _CompactInfo({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: context.colors.textSecondary),
        const SizedBox(width: StackCardSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: StackCardSpacing.xs),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: StackCardSpacing.xs),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).brightness == Brightness.light
                ? context.colors.textPrimary
                : context.colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StackCardSpacing.md,
        vertical: StackCardSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(StackCardRadius.small),
        border: Border.all(color: context.colors.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
