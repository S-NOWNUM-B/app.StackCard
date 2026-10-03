import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../domain/portfolio_content.dart';
import 'portfolio_draft_controller.dart';

class PortfolioBuilderSections extends ConsumerWidget {
  const PortfolioBuilderSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final content = state.content!;
    return _Panel(
      title: context.strings.tr('builder.sections'),
      children: [
        for (final (section, count) in [
          ('profile', null),
          ('skills', content.skills.length),
          ('experience', content.experience.length),
          ('education', content.education.length),
          ('links', content.links.length),
          ('resume', null),
        ]) ...[
          StackCardButton(
            key: ValueKey('builder_section_$section'),
            label: context.strings.tr('builder.section.$section'),
            icon: Icons.edit_outlined,
            onPressed: state.canEdit
                ? () => context.push('/portfolio/builder/$section')
                : null,
          ),
          if (count != null) ...[
            const SizedBox(height: StackCardSpacing.xs),
            Text(context.strings.tr('builder.count', {'count': count})),
          ],
          const SizedBox(height: StackCardSpacing.sm),
        ],
      ],
    );
  }
}

class PortfolioBuilderProjects extends ConsumerWidget {
  const PortfolioBuilderProjects({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final content = state.content!;
    final controller = ref.read(portfolioDraftControllerProvider.notifier);
    return _Panel(
      title: context.strings.tr('builder.projects'),
      children: [
        StackCardButton(
          key: const ValueKey('builder_add_project'),
          label: context.strings.tr('builder.addProject'),
          icon: Icons.add_rounded,
          onPressed: state.canEdit ? () => context.push('/projects/new') : null,
        ),
        if (content.projects.isEmpty) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(context.strings.tr('builder.noProjects')),
        ],
        for (final project in content.projects) ...[
          const SizedBox(height: StackCardSpacing.lg),
          StackCardCard(
            key: ValueKey('builder_project_${project.id}'),
            elevated: true,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    project.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (project.description.isNotEmpty) Text(project.description),
                  const SizedBox(height: StackCardSpacing.sm),
                  StackCardButton(
                    label: context.strings.tr('builder.editProject'),
                    icon: Icons.edit_outlined,
                    onPressed: state.canEdit
                        ? () => context.push(
                            '/projects/${Uri.encodeComponent(project.id)}/edit',
                          )
                        : null,
                  ),
                  SwitchListTile(
                    key: ValueKey('builder_featured_${project.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.strings.tr('builder.featured')),
                    value: project.featured,
                    onChanged: state.canEdit
                        ? (value) => _updateProject(
                            controller,
                            project.id,
                            featured: value,
                          )
                        : null,
                  ),
                  SwitchListTile(
                    key: ValueKey('builder_visible_${project.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.strings.tr('builder.visibleProject')),
                    value: project.visible,
                    onChanged: state.canEdit
                        ? (value) => _updateProject(
                            controller,
                            project.id,
                            visible: value,
                          )
                        : null,
                  ),
                  StackCardButton(
                    key: ValueKey('builder_delete_${project.id}'),
                    label: context.strings.tr('builder.deleteProject', {
                      'title': project.title,
                    }),
                    icon: Icons.delete_outline_rounded,
                    onPressed: state.canEdit
                        ? () => _deleteProject(context, controller, project.id)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

void _updateProject(
  PortfolioDraftController controller,
  String id, {
  bool? featured,
  bool? visible,
}) {
  final content = controller.workingContent;
  if (content == null) return;
  controller.updateContent(
    content.copyWith(
      projects: [
        for (final project in content.projects)
          project.id == id
              ? project.copyWith(featured: featured, visible: visible)
              : project,
      ],
    ),
  );
}

Future<void> _deleteProject(
  BuildContext context,
  PortfolioDraftController controller,
  String id,
) async {
  final delete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.strings.tr('builder.deleteTitle')),
      content: Text(context.strings.tr('builder.deleteMessage')),
      actions: [
        StackCardButton(
          label: context.strings.tr('builder.cancel'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        StackCardButton(
          label: context.strings.tr('builder.delete'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (delete != true || !context.mounted) return;
  final content = controller.workingContent;
  if (content == null) return;
  controller.updateContent(
    content.copyWith(
      projects: content.projects.where((project) => project.id != id).toList(),
    ),
  );
}

class PortfolioBuilderBlocks extends ConsumerWidget {
  const PortfolioBuilderBlocks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final content = state.content!;
    final controller = ref.read(portfolioDraftControllerProvider.notifier);
    return _Panel(
      title: context.strings.tr('builder.blocks'),
      children: [
        for (final block in content.blocks) ...[
          SwitchListTile(
            key: ValueKey('builder_block_${block.kind.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.strings.tr('builder.block.${block.kind.name}')),
            value: block.visible,
            onChanged: state.canEdit
                ? (value) => _setBlockVisible(controller, block.kind, value)
                : null,
          ),
          Wrap(
            spacing: StackCardSpacing.sm,
            children: [
              IconButton(
                key: ValueKey('builder_block_up_${block.kind.name}'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: context.strings.tr('builder.block.up', {
                  'block': context.strings.tr(
                    'builder.block.${block.kind.name}',
                  ),
                }),
                onPressed:
                    state.canEdit && content.blocks.first.kind != block.kind
                    ? () => _moveBlock(controller, block.kind, -1)
                    : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                key: ValueKey('builder_block_down_${block.kind.name}'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                tooltip: context.strings.tr('builder.block.down', {
                  'block': context.strings.tr(
                    'builder.block.${block.kind.name}',
                  ),
                }),
                onPressed:
                    state.canEdit && content.blocks.last.kind != block.kind
                    ? () => _moveBlock(controller, block.kind, 1)
                    : null,
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

void _setBlockVisible(
  PortfolioDraftController controller,
  PortfolioBlockKind kind,
  bool visible,
) {
  final content = controller.workingContent;
  if (content == null) return;
  controller.updateContent(
    content.copyWith(
      blocks: [
        for (final block in content.blocks)
          block.kind == kind ? block.copyWith(visible: visible) : block,
      ],
    ),
  );
}

void _moveBlock(
  PortfolioDraftController controller,
  PortfolioBlockKind kind,
  int offset,
) {
  final content = controller.workingContent;
  if (content == null) return;
  final blocks = content.blocks.toList();
  final index = blocks.indexWhere((block) => block.kind == kind);
  final target = index + offset;
  if (index < 0 || target < 0 || target >= blocks.length) return;
  final block = blocks.removeAt(index);
  blocks.insert(target, block);
  controller.updateContent(content.copyWith(blocks: blocks));
}

class PortfolioBuilderTheme extends ConsumerWidget {
  const PortfolioBuilderTheme({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final controller = ref.read(portfolioDraftControllerProvider.notifier);
    return RadioGroup<PortfolioTheme>(
      groupValue: state.content!.theme,
      onChanged: (value) {
        final content = controller.workingContent;
        if (state.canEdit && value != null && content != null) {
          controller.updateContent(content.copyWith(theme: value));
        }
      },
      child: _Panel(
        title: context.strings.tr('builder.theme'),
        children: [
          for (final theme in PortfolioTheme.values)
            RadioListTile<PortfolioTheme>(
              key: ValueKey('builder_theme_${theme.name}'),
              contentPadding: EdgeInsets.zero,
              title: Text(context.strings.tr('builder.theme.${theme.name}')),
              value: theme,
              enabled: state.canEdit,
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => StackCardCard(
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: StackCardSpacing.lg),
          ...children,
        ],
      ),
    ),
  );
}
