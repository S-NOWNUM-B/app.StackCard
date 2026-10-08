import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_theme.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../../media/media.dart';
import '../domain/portfolio_content.dart';

/// R5 document renderer: живая идентичность, секции и полный набор технологий.
class PortfolioContentView extends StatelessWidget {
  const PortfolioContentView({
    super.key,
    required this.content,
    this.showAllProjects = false,
  });
  final PortfolioContent content;
  final bool showAllProjects;

  @override
  Widget build(BuildContext context) => Theme(
    data: content.theme == PortfolioTheme.dark
        ? StackCardTheme.dark
        : StackCardTheme.light,
    child: Builder(
      builder: (context) {
        final sections = <Widget>[];
        for (final block in content.blocks.where((item) => item.visible)) {
          final children = _block(context, block.kind);
          if (children.isEmpty) continue;
          if (sections.isNotEmpty) {
            sections.add(const SizedBox(height: StackCardSpacing.xl));
          }
          sections.add(
            Column(
              key: ValueKey('portfolio_block_${block.kind.name}'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!{
                  PortfolioBlockKind.profile,
                  PortfolioBlockKind.about,
                }.contains(block.kind)) ...[
                  Text(
                    context.strings.tr('builder.block.${block.kind.name}'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StackCardSpacing.md),
                ],
                ...children,
              ],
            ),
          );
        }
        return ColoredBox(
          color: context.colors.surface,
          child: Padding(
            padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: sections.isEmpty
                  ? [
                      StackCardStateView(
                        kind: StackCardViewState.empty,
                        title: context.strings.tr('builder.previewEmpty'),
                        message: context.strings.tr('builder.previewEmptyHint'),
                      ),
                    ]
                  : sections,
            ),
          ),
        );
      },
    ),
  );

  List<Widget> _block(BuildContext context, PortfolioBlockKind kind) {
    final profile = content.profile;
    final text = Theme.of(context).textTheme;
    return switch (kind) {
      PortfolioBlockKind.profile => [
        if (profile.avatarPath.isNotEmpty || profile.avatarUrl.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: StackCardAvatar(
              size: 80,
              url: profile.avatarUrl,
              image: profile.avatarPath.isEmpty
                  ? null
                  : PortfolioMediaImage(
                      path: profile.avatarPath,
                      width: 80,
                      height: 80,
                    ),
            ),
          ),
          const SizedBox(height: StackCardSpacing.md),
        ],
        if (profile.name.isNotEmpty)
          Text(profile.name, style: text.headlineMedium),
        if (profile.headline.isNotEmpty) ...[
          const SizedBox(height: StackCardSpacing.md),
          Text(profile.headline, style: text.titleLarge),
        ],
      ],
      PortfolioBlockKind.about => [
        if (profile.bio.isNotEmpty) Text(profile.bio, style: text.bodyLarge),
      ],
      PortfolioBlockKind.skills => [
        if (content.skills.isNotEmpty)
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final skill in content.skills)
                StackCardTechnologyBadge(label: skill.name),
            ],
          ),
      ],
      PortfolioBlockKind.featuredProjects => [
        for (final project in content.projects.where(
          (item) => item.visible && (showAllProjects || item.featured),
        ))
          Padding(
            key: ValueKey('portfolio_preview_project_${project.id}'),
            padding: const EdgeInsets.only(bottom: StackCardSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(project.title, style: text.titleLarge),
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: StackCardSpacing.md),
                  Text(project.description, style: text.bodyLarge),
                ],
                if (project.contribution.isNotEmpty) ...[
                  const SizedBox(height: StackCardSpacing.md),
                  Text(
                    context.strings.tr('projectPresentation.contribution'),
                    style: text.labelLarge,
                  ),
                  Text(project.contribution, style: text.bodyLarge),
                ],
                if (project.imagePaths.isNotEmpty) ...[
                  const SizedBox(height: StackCardSpacing.md),
                  Wrap(
                    spacing: StackCardSpacing.sm,
                    runSpacing: StackCardSpacing.sm,
                    children: [
                      for (final path in project.imagePaths)
                        PortfolioMediaImage(
                          path: path,
                          width: 160,
                          height: 120,
                        ),
                    ],
                  ),
                ],
                if (project.technologies.isNotEmpty) ...[
                  const SizedBox(height: StackCardSpacing.md),
                  Wrap(
                    spacing: StackCardSpacing.sm,
                    runSpacing: StackCardSpacing.sm,
                    children: [
                      for (final technology in project.technologies)
                        StackCardTechnologyBadge(label: technology),
                    ],
                  ),
                ],
                for (final url in [project.repositoryUrl, project.liveUrl])
                  if (url.isNotEmpty) ...[
                    const SizedBox(height: StackCardSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: SelectableText(
                        url,
                        style: text.bodyMedium?.copyWith(
                          color: context.colors.accentText,
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ),
      ],
      PortfolioBlockKind.experience => [
        for (final entry in content.experience)
          _entry(context, entry.role, [
            entry.organization,
            entry.period,
            entry.description,
          ]),
      ],
      PortfolioBlockKind.education => [
        for (final entry in content.education)
          _entry(context, entry.institution, [
            entry.qualification,
            entry.period,
            entry.description,
          ]),
      ],
      PortfolioBlockKind.github => _links(context, SocialLinkKind.github),
      PortfolioBlockKind.links => _links(context, null),
      PortfolioBlockKind.resume => [
        if (content.resumeText.isNotEmpty)
          Text(content.resumeText, style: text.bodyLarge),
      ],
      PortfolioBlockKind.location => [
        if (profile.locationText.isNotEmpty)
          Text(profile.locationText, style: text.bodyLarge),
      ],
    };
  }

  List<Widget> _links(BuildContext context, SocialLinkKind? kind) => [
    for (final link in content.links.where(
      (item) =>
          item.visible &&
          (kind == null
              ? item.kind != SocialLinkKind.github
              : item.kind == kind),
    ))
      Padding(
        padding: const EdgeInsets.only(bottom: StackCardSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              link.label,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(height: StackCardSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: SelectableText(
                link.url,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: context.colors.accentText),
              ),
            ),
          ],
        ),
      ),
  ];

  Widget _entry(BuildContext context, String title, List<String> details) =>
      Padding(
        padding: const EdgeInsets.only(bottom: StackCardSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            for (final value in details.where((item) => item.isNotEmpty)) ...[
              const SizedBox(height: StackCardSpacing.sm),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ],
        ),
      );
}
