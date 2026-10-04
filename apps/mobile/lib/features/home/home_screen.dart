import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_async_view.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../../shared/widgets/stackcard_card.dart';
import '../../shared/widgets/stackcard_poster.dart';
import '../../shared/widgets/stackcard_states.dart';
import '../portfolio/portfolio.dart';
import '../portfolio_draft/portfolio_draft.dart';
import '../profile/profile.dart';
import '../projects/projects.dart';

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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide =
          constraints.maxWidth >= 760 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.7;
      final profile = overview.profile;
      final hero = _ProfilePoster(
        profile: profile,
        hasDraft: overview.hasDraft,
      );
      final featured = _FeaturedProject(project: overview.highlightedProject);
      return SingleChildScrollView(
        padding: EdgeInsets.all(
          constraints.maxWidth >= 700
              ? StackCardSpacing.xl
              : StackCardSpacing.lg,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1160),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overview.hasDraft && profile.firstName.isEmpty
                      ? context.strings.tr('builderIntegration.welcome')
                      : context.strings.tr('home.greeting', {
                          'name': profile.firstName,
                        }),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: StackCardSpacing.xl),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: hero),
                      const SizedBox(width: StackCardSpacing.xl),
                      Expanded(child: featured),
                    ],
                  )
                else
                  hero,
                const SizedBox(height: StackCardSpacing.xl),
                _ReadinessStrip(
                  readiness: profile.readiness,
                  hasDraft: overview.hasDraft,
                ),
                const SizedBox(height: StackCardSpacing.xxl),
                if (!wide) ...[
                  featured,
                  const SizedBox(height: StackCardSpacing.xxl),
                ],
                StackCardCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: StackCardSpacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: StackCardSpacing.xl,
                        runSpacing: StackCardSpacing.sm,
                        children: [
                          Text(
                            context.strings.projectCount(
                              overview.projects.length,
                            ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            context.strings.skillCount(profile.skills.length),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: context.colors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: StackCardSpacing.lg),
                      Wrap(
                        spacing: StackCardSpacing.sm,
                        runSpacing: StackCardSpacing.sm,
                        children: [
                          StackCardButton(
                            label: context.strings.tr('nav.projects'),
                            icon: Icons.arrow_outward_rounded,
                            onPressed: () => context.push('/projects'),
                          ),
                          StackCardButton(
                            label: context.strings.tr('home.githubTitle'),
                            icon: Icons.code_rounded,
                            onPressed: () => context.push('/github-import'),
                          ),
                        ],
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

class _ProfilePoster extends StatelessWidget {
  const _ProfilePoster({required this.profile, required this.hasDraft});
  final Profile profile;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.ink;
    final text = Theme.of(context).textTheme;
    return StackCardPoster(
      color: context.colors.acid,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  profile.handle.isEmpty ? 'STACKCARD' : profile.handle,
                  style: text.labelLarge?.copyWith(color: ink),
                ),
              ),
              Icon(Icons.north_east_rounded, color: ink),
            ],
          ),
          StackCardArtwork(color: ink, height: 155),
          Text(
            profile.name.isEmpty
                ? context.strings.tr('builderIntegration.emptyProfile')
                : profile.name,
            style: text.displaySmall?.copyWith(color: ink),
          ),
          if (profile.role.isNotEmpty) ...[
            const SizedBox(height: StackCardSpacing.sm),
            Text(profile.role, style: text.bodyLarge?.copyWith(color: ink)),
          ],
          const SizedBox(height: StackCardSpacing.xl),
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              StackCardButton(
                label: context.strings.tr('home.myPortfolio'),
                icon: Icons.arrow_outward_rounded,
                onPressed: () => context.push('/portfolio'),
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

class _ReadinessStrip extends StatelessWidget {
  const _ReadinessStrip({required this.readiness, required this.hasDraft});
  final ProfileReadiness readiness;
  final bool hasDraft;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              context.strings.tr('home.readiness'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(width: StackCardSpacing.lg),
          Text(
            '${readiness.percent}%',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ],
      ),
      const SizedBox(height: StackCardSpacing.md),
      LinearProgressIndicator(
        value: readiness.fraction,
        minHeight: 2,
        color: context.colors.acid,
        semanticsLabel: context.strings.tr(
          hasDraft
              ? 'builderIntegration.readinessSemantics'
              : 'home.readinessSemantics',
          {'percent': readiness.percent},
        ),
      ),
    ],
  );
}

class _FeaturedProject extends StatelessWidget {
  const _FeaturedProject({required this.project});
  final Project? project;

  @override
  Widget build(BuildContext context) {
    final item = project;
    if (item == null) {
      return StackCardStateView(
        kind: StackCardViewState.empty,
        title: context.strings.tr('home.noFeatured'),
        message: context.strings.tr('home.noFeaturedMessage'),
      );
    }
    final ink = context.colors.ink;
    final text = Theme.of(context).textTheme;
    return StackCardPoster(
      color: context.colors.pink,
      variant: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '01 / ${context.strings.tr('home.featured')}',
            style: text.labelMedium?.copyWith(color: ink),
          ),
          StackCardArtwork(color: ink, variant: 1, height: 130),
          Text(item.title, style: text.headlineLarge?.copyWith(color: ink)),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: StackCardSpacing.md),
            Text(
              item.description,
              style: text.bodyMedium?.copyWith(color: ink),
            ),
          ],
          if (item.technologies.isNotEmpty) ...[
            const SizedBox(height: StackCardSpacing.lg),
            Text(
              item.technologies.join(' / '),
              style: text.labelMedium?.copyWith(color: ink),
            ),
          ],
          const SizedBox(height: StackCardSpacing.xl),
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
