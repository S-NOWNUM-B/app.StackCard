import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../../media/media.dart';
import '../../projects/projects.dart';
import '../document_publication_providers.dart';
import '../domain/portfolio_content.dart';

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
      (profile.bio, text.bodyLarge),
      (profile.locationText, text.bodyMedium),
    ]) {
      if (value.trim().isNotEmpty) {
        sections.add(Text(value, textAlign: TextAlign.center, style: style));
      }
    }
    if (projects.isNotEmpty) {
      sections.add(
        _section(context, 'Проекты', [
          for (final project in projects) _MainProjectRow(project: project),
        ], key: 'projects'),
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
    if (content.experience.isNotEmpty) {
      sections.add(
        _section(context, 'Опыт', [
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
    if (links.isNotEmpty) {
      sections.add(
        _section(context, 'Контакты и ссылки', [
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: StackCardSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(link.label, style: text.labelLarge),
                  const SizedBox(height: StackCardSpacing.xs),
                  _MainLink(url: link.url),
                ],
              ),
            ),
        ], key: 'links'),
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
    final url = project.liveUrl.isNotEmpty
        ? project.liveUrl
        : project.repositoryUrl;
    return Padding(
      key: ValueKey('main.project.${project.id}'),
      padding: const EdgeInsets.only(bottom: StackCardSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: url.isEmpty ? null : () => _openLink(context, ref, url),
          borderRadius: BorderRadius.circular(StackCardRadius.medium),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: StackCardSize.touchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: StackCardSpacing.sm,
              ),
              child: Row(
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
                        if (project.description.isNotEmpty) ...[
                          const SizedBox(height: StackCardSpacing.xs),
                          Text(
                            project.description,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (url.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(left: StackCardSpacing.sm),
                      child: Icon(Icons.open_in_new_rounded, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainLink extends ConsumerWidget {
  const _MainLink({required this.url});
  final String url;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: StackCardSize.touchTarget),
    child: InkWell(
      onTap: () => _openLink(context, ref, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.sm),
        child: Text(
          url,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(decoration: TextDecoration.underline),
        ),
      ),
    ),
  );
}

Future<void> _openLink(
  BuildContext context,
  WidgetRef ref,
  String value,
) async {
  final uri = Uri.tryParse(value);
  final actions = ref.read(documentLinkActionsProvider);
  try {
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
