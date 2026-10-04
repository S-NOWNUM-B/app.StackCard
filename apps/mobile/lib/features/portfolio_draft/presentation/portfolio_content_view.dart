import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_theme.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_poster.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_content.dart';

/// Общий renderer рабочего content. Private notes не входят в его контракт.
class PortfolioContentView extends StatelessWidget {
  const PortfolioContentView({super.key, required this.content});
  final PortfolioContent content;

  @override
  Widget build(BuildContext context) => Theme(
    data: content.theme == PortfolioTheme.dark
        ? StackCardTheme.dark
        : StackCardTheme.light,
    child: Builder(
      builder: (context) {
        final blocks = <Widget>[];
        for (final block in content.blocks.where((block) => block.visible)) {
          final children = _blockContent(context, block.kind);
          if (children.isEmpty) continue;
          if (blocks.isNotEmpty) {
            blocks.add(const SizedBox(height: StackCardSpacing.xxl));
          }
          if (block.kind == PortfolioBlockKind.profile) {
            blocks.add(
              StackCardPoster(
                key: ValueKey('portfolio_block_${block.kind.name}'),
                color: context.colors.cyan,
                variant: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            );
          } else {
            blocks.add(
              DecoratedBox(
                key: ValueKey('portfolio_block_${block.kind.name}'),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: context.colors.border),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: StackCardSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.strings
                            .tr('builder.block.${block.kind.name}')
                            .toUpperCase(),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: StackCardSpacing.lg),
                      ...children,
                    ],
                  ),
                ),
              ),
            );
          }
        }
        return ColoredBox(
          color: context.colors.background,
          child: Padding(
            padding: const EdgeInsets.all(StackCardSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: blocks.isEmpty
                  ? [
                      StackCardStateView(
                        kind: StackCardViewState.empty,
                        title: context.strings.tr('builder.previewEmpty'),
                        message: context.strings.tr('builder.previewEmptyHint'),
                      ),
                    ]
                  : blocks,
            ),
          ),
        );
      },
    ),
  );

  List<Widget> _blockContent(BuildContext context, PortfolioBlockKind kind) {
    final profile = content.profile;
    final text = Theme.of(context).textTheme;
    return switch (kind) {
      PortfolioBlockKind.profile => [
        if (profile.username.isNotEmpty)
          Text(
            '@${profile.username}',
            style: text.labelLarge?.copyWith(color: context.colors.ink),
          ),
        if (profile.name.isNotEmpty) ...[
          StackCardArtwork(color: context.colors.ink, variant: 1, height: 144),
          Text(
            profile.name,
            style: text.displayMedium?.copyWith(color: context.colors.ink),
          ),
        ],
        if (profile.headline.isNotEmpty) ...[
          const SizedBox(height: StackCardSpacing.xl),
          Text(
            profile.headline,
            style: text.titleLarge?.copyWith(color: context.colors.ink),
          ),
        ],
      ],
      PortfolioBlockKind.about => [
        if (profile.bio.isNotEmpty)
          Text(profile.bio, style: text.titleLarge?.copyWith(height: 1.5)),
      ],
      PortfolioBlockKind.skills => [
        if (content.skills.isNotEmpty)
          Text(
            content.skills.map((skill) => skill.name).join(' / '),
            style: text.headlineSmall?.copyWith(height: 1.5),
          ),
      ],
      PortfolioBlockKind.featuredProjects => [
        for (final (index, project)
            in content.projects
                .where((project) => project.visible && project.featured)
                .indexed)
          Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : StackCardSpacing.xl),
            child: StackCardPoster(
              key: ValueKey('portfolio_preview_project_${project.id}'),
              color: index.isEven ? context.colors.pink : context.colors.acid,
              variant: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: text.labelLarge?.copyWith(color: context.colors.ink),
                  ),
                  const SizedBox(height: StackCardSpacing.xxl),
                  Text(
                    project.title,
                    style: text.headlineLarge?.copyWith(
                      color: context.colors.ink,
                    ),
                  ),
                  if (project.description.isNotEmpty) ...[
                    const SizedBox(height: StackCardSpacing.md),
                    Text(
                      project.description,
                      style: text.bodyLarge?.copyWith(
                        color: context.colors.ink,
                      ),
                    ),
                  ],
                  if (project.technologies.isNotEmpty) ...[
                    const SizedBox(height: StackCardSpacing.xl),
                    Text(
                      project.technologies.join(' / '),
                      style: text.labelLarge?.copyWith(
                        color: context.colors.ink,
                      ),
                    ),
                  ],
                  for (final url in [project.repositoryUrl, project.liveUrl])
                    if (url.isNotEmpty) ...[
                      const SizedBox(height: StackCardSpacing.md),
                      Text(
                        url,
                        style: text.bodySmall?.copyWith(
                          color: context.colors.ink,
                        ),
                      ),
                    ],
                ],
              ),
            ),
          ),
      ],
      PortfolioBlockKind.experience => [
        for (final entry in content.experience)
          _Entry(
            title: entry.role,
            details: [entry.organization, entry.period, entry.description],
          ),
      ],
      PortfolioBlockKind.education => [
        for (final entry in content.education)
          _Entry(
            title: entry.institution,
            details: [entry.qualification, entry.period, entry.description],
          ),
      ],
      PortfolioBlockKind.github => _links(SocialLinkKind.github),
      PortfolioBlockKind.links => _links(null),
      PortfolioBlockKind.resume => [
        if (content.resumeText.isNotEmpty)
          Text(
            content.resumeText,
            style: text.bodyLarge?.copyWith(height: 1.6),
          ),
      ],
      PortfolioBlockKind.location => [
        if (profile.locationText.isNotEmpty)
          Text(profile.locationText, style: text.headlineSmall),
      ],
    };
  }

  List<Widget> _links(SocialLinkKind? kind) => [
    for (final link in content.links.where(
      (link) =>
          kind == null ? link.kind != SocialLinkKind.github : link.kind == kind,
    ))
      _Entry(title: link.label, details: [link.url]),
  ];
}

class _Entry extends StatelessWidget {
  const _Entry({required this.title, required this.details});
  final String title;
  final List<String> details;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: StackCardSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        for (final detail in details.where((value) => value.isNotEmpty)) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(detail, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ],
    ),
  );
}
