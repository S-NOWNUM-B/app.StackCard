import 'package:flutter/material.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../portfolio_draft/portfolio_draft.dart';

const _iconLabels = <String, String>{
  'folder': 'Папка',
  'file-text': 'Документ',
  'panels-top-left': 'Приложение',
  'home': 'Дом',
  'image': 'Изображение',
  'camera': 'Камера',
  'user-round': 'Профиль',
};

/// Только закреплённый каталог; произвольный путь или SVG не отображается.
class ProjectStockIcon extends StatelessWidget {
  const ProjectStockIcon({super.key, this.iconId = 'folder', this.size = 32});

  final String iconId;
  final double size;

  @override
  Widget build(BuildContext context) => StackCardIcon(
    name: portfolioProjectIconIds.contains(iconId) ? iconId : 'folder',
    size: size,
  );
}

Future<String?> showProjectIconPicker(
  BuildContext context, {
  required String selectedIconId,
}) => showModalBottomSheet<String>(
  context: context,
  showDragHandle: true,
  useSafeArea: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: StackCardSize.contentMaxWidth),
  builder: (context) => SingleChildScrollView(
    padding: const EdgeInsets.all(StackCardSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Иконка проекта', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: StackCardSpacing.lg),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (final id in portfolioProjectIconIds)
                Semantics(
                  button: true,
                  selected: id == selectedIconId,
                  child: SizedBox(
                    width: (constraints.maxWidth - StackCardSpacing.lg) / 3,
                    child: Material(
                      color: id == selectedIconId
                          ? context.colors.surfaceElevated
                          : context.colors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          StackCardRadius.medium,
                        ),
                        side: BorderSide(
                          color: id == selectedIconId
                              ? context.colors.textPrimary
                              : context.colors.border,
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('project.icon.$id'),
                        borderRadius: BorderRadius.circular(
                          StackCardRadius.medium,
                        ),
                        onTap: () => Navigator.pop(context, id),
                        child: Padding(
                          padding: const EdgeInsets.all(StackCardSpacing.md),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ProjectStockIcon(iconId: id),
                              const SizedBox(height: StackCardSpacing.sm),
                              Text(
                                _iconLabels[id]!,
                                textAlign: TextAlign.center,
                              ),
                              if (id == selectedIconId) ...[
                                const SizedBox(height: StackCardSpacing.xs),
                                const StackCardIcon(name: 'check', size: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  ),
);
