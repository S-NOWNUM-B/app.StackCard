import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
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
  const MainPortfolioContentView({super.key, required this.content})
    : _sliver = false;

  const MainPortfolioContentView.sliver({super.key, required this.content})
    : _sliver = true;

  final PortfolioContent content;
  final bool _sliver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = content.profile;
    final text = Theme.of(context).textTheme;
    final projects = content.projects
        .where((project) => project.visible)
        .toList();
    final links = content.links.where(
      (link) => link.visible && link.publishAllowed,
    );
    final colors = context.colors;
    final sections = <Widget>[];
    final orderedSections = <PortfolioBlockKind, Widget>{};
    final header = <Widget>[];
    if (profile.avatarPath.isNotEmpty || profile.avatarUrl.isNotEmpty) {
      header.add(
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
    if (profile.name.trim().isNotEmpty) {
      header.add(
        Text(
          profile.name,
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
      );
    }
    if (profile.headline.trim().isNotEmpty) {
      header.add(
        Text(
          profile.headline,
          textAlign: TextAlign.center,
          style: text.titleMedium?.copyWith(color: colors.textSecondary),
        ),
      );
    }
    if (profile.locationText.trim().isNotEmpty) {
      header.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 16,
              color: colors.textSecondary,
            ),
            const SizedBox(width: StackCardSpacing.xs),
            Flexible(
              child: Text(
                profile.locationText,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }
    if (header.isNotEmpty) {
      // Шапка профиля отделена от разделов отдельной карточкой.
      sections.add(
        _adapt(
          StackCardCard(
            key: const Key('main.portfolio.header'),
            elevated: true,
            padding: const EdgeInsets.all(StackCardSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < header.length; index++) ...[
                  if (index != 0) const SizedBox(height: StackCardSpacing.sm),
                  header[index],
                ],
              ],
            ),
          ),
        ),
      );
    }
    if (profile.bio.trim().isNotEmpty) {
      sections.add(
        _section(context, 'О себе', [
          Text(
            profile.bio,
            key: const Key('main.portfolio.bio'),
            textAlign: TextAlign.left,
            style: text.bodyLarge,
          ),
        ], key: 'bio'),
      );
    }
    if (links.isNotEmpty) {
      orderedSections[PortfolioBlockKind.links] = _section(
        context,
        'Контакты и ссылки',
        [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  (constraints.maxWidth /
                          (136 * MediaQuery.textScalerOf(context).scale(1)))
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
        ],
        key: 'links',
      );
    }
    if (content.skills.isNotEmpty) {
      orderedSections[PortfolioBlockKind.skills] = _section(context, 'Навыки', [
        Wrap(
          spacing: StackCardSpacing.sm,
          runSpacing: StackCardSpacing.sm,
          children: [
            for (final skill in content.skills)
              StackCardTechnologyBadge(label: skill.name),
          ],
        ),
      ], key: 'skills');
    }
    if (projects.isNotEmpty) {
      orderedSections[PortfolioBlockKind.featuredProjects] = _section(
        context,
        'Реализованные проекты',
        const [],
        key: 'projects',
        itemCount: projects.length,
        itemBuilder: (context, index) =>
            _MainProjectRow(project: projects[index]),
      );
    }
    if (content.experience.isNotEmpty) {
      orderedSections[PortfolioBlockKind.experience] = _section(
        context,
        'Опыт работы',
        const [],
        key: 'experience',
        itemCount: content.experience.length,
        itemBuilder: (context, index) {
          final entry = content.experience[index];
          return _entry(context, entry.role, [
            entry.organization,
            entry.period,
            entry.description,
          ], key: 'experience.${entry.id}');
        },
      );
    }
    if (content.education.isNotEmpty) {
      orderedSections[PortfolioBlockKind.education] = _section(
        context,
        'Образование',
        const [],
        key: 'education',
        itemCount: content.education.length,
        itemBuilder: (context, index) {
          final entry = content.education[index];
          return _entry(context, entry.institution, [
            entry.qualification,
            entry.period,
            entry.description,
          ], key: 'education.${entry.id}');
        },
      );
    }
    for (final kind in mainPortfolioSectionOrder(content)) {
      final section = orderedSections[kind];
      if (section != null) sections.add(section);
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
      return _adapt(
        Padding(
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
        ),
      );
    }
    if (_sliver) {
      return SliverMainAxisGroup(
        key: const Key('main.portfolio.content'),
        slivers: [
          for (var index = 0; index < sections.length; index++) ...[
            if (index != 0)
              const SliverToBoxAdapter(
                child: SizedBox(height: StackCardSpacing.lg),
              ),
            sections[index],
          ],
        ],
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

  Widget _adapt(Widget child) =>
      _sliver ? SliverToBoxAdapter(child: child) : child;

  /// Одна геометрия секции для обычного preview и ленивой Home.
  Widget _section(
    BuildContext context,
    String title,
    List<Widget> children, {
    required String key,
    int itemCount = 0,
    IndexedWidgetBuilder? itemBuilder,
  }) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(StackCardRadius.capsule),
              ),
            ),
            const SizedBox(width: StackCardSpacing.sm),
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.md),
          child: Divider(
            height: 1,
            thickness: 1,
            color: context.colors.borderSubtle,
          ),
        ),
      ],
    );
    Widget row(BuildContext context, int index) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (index != 0)
          Divider(
            height: StackCardSpacing.lg,
            thickness: 1,
            color: context.colors.borderSubtle,
          ),
        itemBuilder!(context, index),
      ],
    );
    if (_sliver) {
      return StackCardCard.sliver(
        key: ValueKey('main.section.$key'),
        outlined: true,
        child: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(child: heading),
            if (itemBuilder != null)
              SliverList.builder(itemCount: itemCount, itemBuilder: row)
            else
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
          ],
        ),
      );
    }
    return StackCardCard(
      key: ValueKey('main.section.$key'),
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          ...children,
          for (var index = 0; index < itemCount; index++) row(context, index),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context,
    String title,
    List<String> details, {
    required String key,
  }) => Column(
    key: ValueKey('main.$key'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      for (final detail in details.where((value) => value.isNotEmpty)) ...[
        const SizedBox(height: StackCardSpacing.xs),
        Text(detail, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ],
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
