import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_theme.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_content.dart';

/// Один renderer рабочего content для Portfolio и локального preview.
/// Private notes отсутствуют в контракте этого виджета.
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
            blocks.add(const SizedBox(height: StackCardSpacing.lg));
          }
          blocks.add(
            StackCardCard(
              key: ValueKey('portfolio_block_${block.kind.name}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.strings.tr('builder.block.${block.kind.name}'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  ...children,
                ],
              ),
            ),
          );
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
    return switch (kind) {
      PortfolioBlockKind.profile => [
        if (profile.name.isNotEmpty)
          Text(profile.name, style: Theme.of(context).textTheme.headlineMedium),
        if (profile.username.isNotEmpty) Text('@${profile.username}'),
        if (profile.headline.isNotEmpty) Text(profile.headline),
        if (profile.avatarUrl.isNotEmpty) Text(profile.avatarUrl),
      ],
      PortfolioBlockKind.about => [
        if (profile.bio.isNotEmpty) Text(profile.bio),
      ],
      PortfolioBlockKind.skills => [
        if (content.skills.isNotEmpty)
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final skill in content.skills) Chip(label: Text(skill.name)),
            ],
          ),
      ],
      PortfolioBlockKind.featuredProjects => [
        for (final project in content.projects.where(
          (project) => project.visible && project.featured,
        ))
          _Entry(
            key: ValueKey('portfolio_preview_project_${project.id}'),
            title: project.title,
            details: [
              project.description,
              project.technologies.join(' · '),
              project.repositoryUrl,
              project.liveUrl,
            ],
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
        if (content.resumeText.isNotEmpty) Text(content.resumeText),
      ],
      PortfolioBlockKind.location => [
        if (profile.locationText.isNotEmpty) Text(profile.locationText),
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
  const _Entry({super.key, required this.title, required this.details});
  final String title;
  final List<String> details;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: StackCardSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        for (final detail in details.where((value) => value.isNotEmpty)) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(detail),
        ],
      ],
    ),
  );
}
