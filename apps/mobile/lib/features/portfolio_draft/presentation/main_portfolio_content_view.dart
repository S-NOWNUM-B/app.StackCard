import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../../media/media.dart';
import '../../projects/projects.dart';
import '../document_publication_providers.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_validation.dart';
import 'portfolio_contact_visual.dart';

/// Готовое основное портфолио: только непустое содержимое, без controls редактора.
class MainPortfolioContentView extends ConsumerWidget {
  const MainPortfolioContentView({super.key, required this.content});

  final PortfolioContent content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = content.profile;
    final text = Theme.of(context).textTheme;
    final projects = content.projects.where((project) => project.visible);
    final links = content.links.where(
      (link) => link.visible && link.publishAllowed,
    );
    final sections = <Widget>[];
    if (profile.avatarPath.isNotEmpty || profile.avatarUrl.isNotEmpty) {
      sections.add(
        Center(
          child: StackCardAvatar(
            size: 128,
            url: profile.avatarUrl,
            image: profile.avatarPath.isEmpty
                ? null
                : PortfolioMediaImage(
                    path: profile.avatarPath,
                    width: 128,
                    height: 128,
                  ),
          ),
        ),
      );
    }
    for (final (value, style) in [
      (profile.name, text.headlineSmall),
      (profile.headline, text.titleMedium),
      (profile.locationText, text.bodyMedium),
    ]) {
      if (value.trim().isNotEmpty) {
        sections.add(Text(value, textAlign: TextAlign.center, style: style));
      }
    }
    if (profile.bio.trim().isNotEmpty) {
      sections.add(
        Text(
          profile.bio,
          key: const Key('main.portfolio.bio'),
          textAlign: TextAlign.left,
          style: text.bodyLarge,
        ),
      );
    }
    if (links.isNotEmpty) {
      sections.add(
        _section(context, 'Контакты и ссылки', [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  (constraints.maxWidth /
                          (160 * MediaQuery.textScalerOf(context).scale(1)))
                      .floor()
                      .clamp(1, 4);
              final width =
                  (constraints.maxWidth - StackCardSpacing.lg * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: StackCardSpacing.lg,
                runSpacing: StackCardSpacing.md,
                children: [
                  for (final link in links)
                    SizedBox(
                      width: width,
                      child: _MainContact(link: link),
                    ),
                ],
              );
            },
          ),
        ], key: 'links'),
      );
    }
    if (content.skills.isNotEmpty) {
      sections.add(
        _section(context, 'Навыки', [
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final skill in content.skills)
                StackCardTechnologyBadge(label: skill.name),
            ],
          ),
        ], key: 'skills'),
      );
    }
    if (projects.isNotEmpty) {
      sections.add(
        _section(context, 'Реализованные проекты', [
          for (final project in projects) _MainProjectRow(project: project),
        ], key: 'projects'),
      );
    }
    if (content.experience.isNotEmpty) {
      sections.add(
        _section(context, 'Опыт работы', [
          for (final entry in content.experience)
            _entry(context, entry.role, [
              entry.organization,
              entry.period,
              entry.description,
            ]),
        ], key: 'experience'),
      );
    }
    if (content.education.isNotEmpty) {
      sections.add(
        _section(context, 'Образование', [
          for (final entry in content.education)
            _entry(context, entry.institution, [
              entry.qualification,
              entry.period,
              entry.description,
            ]),
        ], key: 'education'),
      );
    }
    // Непарсенный legacy текст остаётся доступным после переноса.
    if (content.resumeText.trim().isNotEmpty) {
      sections.add(
        _section(context, 'Дополнительно', [
          Text(content.resumeText, style: text.bodyLarge),
        ], key: 'legacyText'),
      );
    }
    if (sections.isEmpty) {
      return Padding(
        key: const Key('main.portfolio.empty'),
        padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.xl),
        child: Column(
          children: [
            Text(
              'Портфолио пока пустое',
              style: text.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: StackCardSpacing.sm),
            Text(
              'Откройте вкладку «Редактор»',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Column(
      key: const Key('main.portfolio.content'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          if (index != 0) const SizedBox(height: StackCardSpacing.lg),
          sections[index],
        ],
      ],
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<Widget> children, {
    required String key,
  }) => Padding(
    key: ValueKey('main.section.$key'),
    padding: const EdgeInsets.only(top: StackCardSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: StackCardSpacing.md),
        ...children,
      ],
    ),
  );

  Widget _entry(BuildContext context, String title, List<String> details) =>
      Padding(
        padding: const EdgeInsets.only(bottom: StackCardSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            for (final detail in details.where(
              (value) => value.isNotEmpty,
            )) ...[
              const SizedBox(height: StackCardSpacing.xs),
              Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      );
}

class _MainProjectRow extends ConsumerWidget {
  const _MainProjectRow({required this.project});
  final PortfolioProject project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repositoryUrl = project.repositoryUrl.trim();
    final liveUrl = project.liveUrl.trim();
    return Padding(
      key: ValueKey('main.project.${project.id}'),
      padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProjectStockIcon(iconId: project.iconId),
              const SizedBox(width: StackCardSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      project.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (project.description.trim().isNotEmpty) ...[
                      const SizedBox(height: StackCardSpacing.xs),
                      Text(
                        project.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (repositoryUrl.isNotEmpty || liveUrl.isNotEmpty) ...[
            const SizedBox(height: StackCardSpacing.sm),
            Wrap(
              key: ValueKey('main.project.links.${project.id}'),
              spacing: StackCardSpacing.sm,
              runSpacing: StackCardSpacing.xs,
              children: [
                if (repositoryUrl.isNotEmpty)
                  StackCardButton(
                    key: ValueKey('main.project.repository.${project.id}'),
                    label: 'Репозиторий',
                    iconWidget: const StackCardIcon(name: 'github'),
                    role: StackCardButtonRole.quiet,
                    onPressed: () => _openLink(context, ref, repositoryUrl),
                  ),
                if (liveUrl.isNotEmpty)
                  StackCardButton(
                    key: ValueKey('main.project.product.${project.id}'),
                    label: 'Продукт',
                    iconWidget: const StackCardIcon(name: 'globe'),
                    role: StackCardButtonRole.quiet,
                    onPressed: () => _openLink(context, ref, liveUrl),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MainContact extends ConsumerWidget {
  const _MainContact({required this.link});
  final SocialLink link;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    key: ValueKey('main.contact.${link.id}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StackCardIcon(name: portfolioContactIconName(link.kind)),
          const SizedBox(width: StackCardSpacing.sm),
          Expanded(
            child: Text(
              portfolioContactCategoryLabel(link.kind),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
      Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('main.contact.link.${link.id}'),
          onTap: () => _openLink(context, ref, link.url, kind: link.kind),
          borderRadius: BorderRadius.circular(StackCardRadius.small),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: StackCardSize.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: StackCardSpacing.sm,
              ),
              child: Text(
                link.label,
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(decoration: TextDecoration.underline),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Future<void> _openLink(
  BuildContext context,
  WidgetRef ref,
  String value, {
  SocialLinkKind? kind,
}) async {
  final uri = Uri.tryParse(value);
  final actions = ref.read(documentLinkActionsProvider);
  try {
    if (kind != null && validatePortfolioContactUrl(value, kind) != null) {
      throw StateError('invalid contact');
    }
    if (uri == null || actions == null) throw StateError('unavailable');
    await actions.open(uri);
  } on Object {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }
}
