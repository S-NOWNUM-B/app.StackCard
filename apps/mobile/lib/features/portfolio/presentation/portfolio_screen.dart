import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_async_view.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_poster.dart';
import '../../portfolio_draft/portfolio_draft.dart';
import '../../profile/profile.dart';
import '../../projects/projects.dart';
import 'portfolio_overview.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.watch(portfolioWorkingContentProvider);
    if (content != null) {
      return _PortfolioPage(
        tools: const _PortfolioTools(local: true),
        child: PortfolioContentView(content: content),
      );
    }
    return StackCardAsyncView(
      state: ref.watch(portfolioOverviewProvider),
      onRetry: () {
        ref.read(portfolioDraftControllerProvider.notifier).load();
        ref.invalidate(profileProvider);
        ref.invalidate(projectsProvider);
      },
      data: (overview) => _PortfolioPage(
        tools: _PortfolioTools(
          onPreview: () => _showPreview(context, overview),
        ),
        child: Padding(
          padding: const EdgeInsets.all(StackCardSpacing.lg),
          child: _DemoPortfolio(overview: overview),
        ),
      ),
    );
  }
}

class _PortfolioPage extends StatelessWidget {
  const _PortfolioPage({required this.tools, required this.child});
  final Widget tools;
  final Widget child;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(StackCardSpacing.lg),
              child: tools,
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

class _PortfolioTools extends StatelessWidget {
  const _PortfolioTools({this.local = false, this.onPreview});
  final bool local;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: StackCardSpacing.sm,
        runSpacing: StackCardSpacing.sm,
        children: [
          StackCardButton(
            label: context.strings.tr(
              local ? 'builderIntegration.edit' : 'builderIntegration.open',
            ),
            icon: Icons.edit_outlined,
            primary: true,
            onPressed: () => context.push('/portfolio/builder'),
          ),
          StackCardButton(
            label: context.strings.tr('builderIntegration.preview'),
            icon: Icons.north_east_rounded,
            onPressed: local
                ? () => context.push('/portfolio/preview')
                : onPreview,
          ),
          IconButton(
            tooltip: context.strings.tr('draft.open'),
            onPressed: () => context.push('/portfolio-draft'),
            icon: const Icon(Icons.note_alt_outlined),
          ),
        ],
      ),
    ],
  );
}

class _DemoPortfolio extends StatelessWidget {
  const _DemoPortfolio({required this.overview});
  final PortfolioOverview overview;

  @override
  Widget build(BuildContext context) {
    final profile = overview.profile;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StackCardPoster(
          color: context.colors.acid,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '@${profile.handle}',
                style: text.labelLarge?.copyWith(color: context.colors.ink),
              ),
              StackCardArtwork(color: context.colors.ink, height: 144),
              Text(
                profile.name,
                style: text.displayMedium?.copyWith(color: context.colors.ink),
              ),
              const SizedBox(height: StackCardSpacing.xl),
              Text(
                profile.role,
                style: text.titleLarge?.copyWith(color: context.colors.ink),
              ),
              const SizedBox(height: StackCardSpacing.sm),
              Text(
                profile.location,
                style: text.bodyLarge?.copyWith(color: context.colors.ink),
              ),
            ],
          ),
        ),
        const SizedBox(height: StackCardSpacing.xxl),
        _Section(
          index: '01',
          title: context.strings.tr('portfolio.about'),
          child: Text(
            profile.about,
            style: text.titleLarge?.copyWith(height: 1.5),
          ),
        ),
        _Section(
          index: '02',
          title: context.strings.tr('portfolio.skills'),
          child: Text(
            profile.skills.join(' / '),
            style: text.headlineSmall?.copyWith(height: 1.5),
          ),
        ),
        _Section(
          index: '03',
          title: context.strings.tr('portfolio.featured'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, project)
                  in overview.featuredProjects.indexed) ...[
                if (index != 0) const SizedBox(height: StackCardSpacing.xl),
                StackCardPoster(
                  color: index.isEven
                      ? context.colors.pink
                      : context.colors.cyan,
                  variant: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        project.symbol,
                        style: text.displaySmall?.copyWith(
                          color: context.colors.ink,
                        ),
                      ),
                      StackCardArtwork(
                        color: context.colors.ink,
                        variant: 2,
                        height: 88,
                      ),
                      Text(
                        project.title,
                        style: text.headlineLarge?.copyWith(
                          color: context.colors.ink,
                        ),
                      ),
                      const SizedBox(height: StackCardSpacing.md),
                      Text(
                        project.description,
                        style: text.bodyLarge?.copyWith(
                          color: context.colors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (profile.experience != null || profile.education != null)
          _Section(
            index: '04',
            title: context.strings.tr('portfolio.experience'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (profile.experience != null) ...[
                  Text(profile.experience!.title, style: text.headlineSmall),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(profile.experience!.details, style: text.bodyLarge),
                ],
                if (profile.education != null) ...[
                  const SizedBox(height: StackCardSpacing.xl),
                  Text(profile.education!.title, style: text.headlineSmall),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(profile.education!.details, style: text.bodyLarge),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.index,
    required this.title,
    required this.child,
  });
  final String index;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: StackCardSpacing.xxl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '$index / ${title.toUpperCase()}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: StackCardSpacing.lg),
        child,
        const SizedBox(height: StackCardSpacing.xl),
        Divider(color: context.colors.border, height: 1),
      ],
    ),
  );
}

void _showPreview(BuildContext context, PortfolioOverview overview) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 900),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(StackCardSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.strings.tr('portfolio.previewTitle'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: StackCardSpacing.sm),
            Text(context.strings.tr('portfolio.previewStatus')),
            const SizedBox(height: StackCardSpacing.xl),
            _DemoPortfolio(overview: overview),
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
