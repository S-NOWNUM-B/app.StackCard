import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../profile/profile.dart';
import '../../projects/projects.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import 'portfolio_overview.dart';
import '../../../shared/widgets/stackcard_async_view.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(portfolioWorkingContentProvider);
    if (content != null) return _LocalPortfolioContent(content: content);
    return StackCardAsyncView(
      state: ref.watch(portfolioOverviewProvider),
      onRetry: () {
        ref.read(portfolioDraftControllerProvider.notifier).load();
        ref.invalidate(profileProvider);
        ref.invalidate(projectsProvider);
      },
      data: (overview) => _PortfolioContent(overview: overview),
    );
  }
}

class _LocalPortfolioContent extends StatelessWidget {
  const _LocalPortfolioContent({required this.content});
  final PortfolioContent content;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(StackCardSpacing.lg),
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.strings.tr('home.myPortfolio'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: StackCardSpacing.sm),
            Text(context.strings.tr('builderIntegration.localNote')),
            const SizedBox(height: StackCardSpacing.lg),
            Wrap(
              spacing: StackCardSpacing.md,
              runSpacing: StackCardSpacing.md,
              children: [
                StackCardButton(
                  label: context.strings.tr('builderIntegration.edit'),
                  icon: Icons.edit_outlined,
                  onPressed: () => context.push('/portfolio/builder'),
                ),
                StackCardButton(
                  label: context.strings.tr('builderIntegration.preview'),
                  icon: Icons.visibility_outlined,
                  onPressed: () => context.push('/portfolio/preview'),
                ),
                StackCardButton(
                  label: context.strings.tr('draft.open'),
                  icon: Icons.note_alt_outlined,
                  onPressed: () => context.push('/portfolio-draft'),
                ),
              ],
            ),
            const SizedBox(height: StackCardSpacing.xl),
            PortfolioContentView(content: content),
          ],
        ),
      ),
    ),
  );
}

class _PortfolioContent extends StatelessWidget {
  const _PortfolioContent({required this.overview});

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
                    context.strings.tr('home.myPortfolio'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    context.strings.tr('portfolio.subtitle'),
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: pageTextColor),
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  Wrap(
                    spacing: StackCardSpacing.md,
                    runSpacing: StackCardSpacing.md,
                    children: [
                      StackCardButton(
                        label: context.strings.tr('draft.open'),
                        icon: Icons.note_alt_outlined,
                        onPressed: () => context.push('/portfolio-draft'),
                      ),
                      StackCardButton(
                        label: context.strings.tr('builderIntegration.open'),
                        icon: Icons.edit_outlined,
                        primary: true,
                        onPressed: () => context.push('/portfolio/builder'),
                      ),
                    ],
                  ),
                  const SizedBox(height: StackCardSpacing.xl),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _ProfileCard(profile: overview.profile),
                        ),
                        const SizedBox(width: StackCardSpacing.lg),
                        Expanded(
                          flex: 4,
                          child: _DraftCard(overview: overview),
                        ),
                      ],
                    )
                  else ...[
                    _ProfileCard(profile: overview.profile),
                    const SizedBox(height: StackCardSpacing.lg),
                    _DraftCard(overview: overview),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  Text(
                    context.strings.tr('portfolio.blocks'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: Column(
                            children: [
                              _AboutCard(profile: overview.profile),
                              SizedBox(height: StackCardSpacing.lg),
                              _FeaturedCard(
                                projects: overview.featuredProjects,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: StackCardSpacing.lg),
                        Expanded(
                          flex: 4,
                          child: Column(
                            children: [
                              _SkillsCard(profile: overview.profile),
                              SizedBox(height: StackCardSpacing.lg),
                              _StoryCard(profile: overview.profile),
                              SizedBox(height: StackCardSpacing.lg),
                              _LinksCard(),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _AboutCard(profile: overview.profile),
                    const SizedBox(height: StackCardSpacing.lg),
                    _SkillsCard(profile: overview.profile),
                    const SizedBox(height: StackCardSpacing.lg),
                    _FeaturedCard(projects: overview.featuredProjects),
                    const SizedBox(height: StackCardSpacing.lg),
                    _StoryCard(profile: overview.profile),
                    const SizedBox(height: StackCardSpacing.lg),
                    const _LinksCard(),
                  ],
                  const SizedBox(height: StackCardSpacing.xl),
                  Text(
                    context.strings.tr('portfolio.demoNote'),
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: pageTextColor),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                      profile.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: StackCardSpacing.xs),
                    Text(
                      '@${profile.handle}',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Text(profile.role, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StackCardSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: context.colors.textSecondary,
              ),
              const SizedBox(width: StackCardSpacing.sm),
              Expanded(
                child: Text(
                  profile.location,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.xl),
          Text(
            context.strings.tr('portfolio.available'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            context.strings.tr('portfolio.demoProfile'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.overview});

  final PortfolioOverview overview;
  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: StackCardSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.visibility_off_outlined,
                size: 20,
                color: context.colors.textSecondary,
              ),
              Text(
                context.strings.tr('common.draft'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            context.strings.tr('portfolio.private'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            context.strings.tr('portfolio.previewNote'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          StackCardButton(
            label: context.strings.tr('portfolio.preview'),
            icon: Icons.visibility_outlined,
            primary: true,
            onPressed: () => _showPreview(context, overview),
          ),
          const SizedBox(height: StackCardSpacing.md),
          Text(
            context.strings.tr('portfolio.publishNote'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.tr('portfolio.about'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(profile.about, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.tr('portfolio.skills'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final skill in profile.skills)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StackCardSpacing.md,
                    vertical: StackCardSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(StackCardRadius.small),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Text(
                    skill,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({required this.projects});

  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.tr('portfolio.featured'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          for (final project in projects)
            Padding(
              padding: const EdgeInsets.only(bottom: StackCardSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceElevated,
                      borderRadius: BorderRadius.circular(
                        StackCardRadius.medium,
                      ),
                    ),
                    child: Text(
                      project.symbol,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: StackCardSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: StackCardSpacing.xs),
                        Text(
                          project.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.tr('portfolio.experience'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          if (profile.experience != null) ...[
            Text(
              profile.experience!.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: StackCardSpacing.xs),
            Text(
              profile.experience!.details,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: StackCardSpacing.lg),
            Divider(color: context.colors.borderSubtle),
            const SizedBox(height: StackCardSpacing.lg),
          ],
          if (profile.education != null) ...[
            Text(
              profile.education!.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: StackCardSpacing.xs),
            Text(
              profile.education!.details,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: StackCardSpacing.lg),
          ],
          Text(
            context.strings.tr('portfolio.demoEntries'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _LinksCard extends StatelessWidget {
  const _LinksCard();

  @override
  Widget build(BuildContext context) {
    return StackCardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.strings.tr('portfolio.links'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            context.strings.tr('portfolio.github'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            context.strings.tr('portfolio.noLink'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            context.strings.tr('portfolio.resume'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StackCardSpacing.xs),
          Text(
            context.strings.tr('portfolio.noResume'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

void _showPreview(BuildContext context, PortfolioOverview overview) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 720),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          StackCardSpacing.xl,
          StackCardSpacing.sm,
          StackCardSpacing.xl,
          StackCardSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.strings.tr('portfolio.previewTitle'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: StackCardSpacing.sm),
            Text(
              context.strings.tr('portfolio.previewStatus'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: StackCardSpacing.xl),
            _ProfileCard(profile: overview.profile),
            const SizedBox(height: StackCardSpacing.lg),
            _AboutCard(profile: overview.profile),
            const SizedBox(height: StackCardSpacing.lg),
            _SkillsCard(profile: overview.profile),
            const SizedBox(height: StackCardSpacing.lg),
            _FeaturedCard(projects: overview.featuredProjects),
            const SizedBox(height: StackCardSpacing.lg),
            _StoryCard(profile: overview.profile),
            const SizedBox(height: StackCardSpacing.lg),
            const _LinksCard(),
            const SizedBox(height: StackCardSpacing.xl),
            StackCardButton(
              label: context.strings.tr('portfolio.closePreview'),
              icon: Icons.close_rounded,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
