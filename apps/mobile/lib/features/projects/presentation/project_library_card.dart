import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import 'project_stock_icon.dart';

/// Компактная строка Library; content и actions имеют отдельные области нажатия.
class ProjectLibraryCard extends StatelessWidget {
  const ProjectLibraryCard({
    super.key,
    required this.title,
    required this.description,
    this.iconId = 'folder',
    this.onOpen,
    this.openKey,
    this.onEdit,
    this.onDelete,
    this.showActions = true,
  });

  final String title;
  final String description;
  final String iconId;
  final VoidCallback? onOpen;
  final Key? openKey;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showActions;
  @override
  Widget build(BuildContext context) => StackCardCard(
    outlined: true,
    padding: const EdgeInsets.all(StackCardSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: StackCardSpacing.xs),
              child: ProjectStockIcon(iconId: iconId),
            ),
            const SizedBox(width: StackCardSpacing.md),
            Expanded(
              child: InkWell(
                key: openKey,
                onTap: onOpen,
                borderRadius: BorderRadius.circular(StackCardRadius.small),
                child: ConstrainedBox(
                  constraints: onOpen == null
                      ? const BoxConstraints()
                      : const BoxConstraints(
                          minHeight: StackCardSize.touchTarget,
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (description.trim().isNotEmpty) ...[
                        const SizedBox(height: StackCardSpacing.xs),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (showActions && onDelete != null) ...[
              const SizedBox(width: StackCardSpacing.xs),
              IconButton(
                tooltip: 'Удалить проект',
                onPressed: onDelete,
                constraints: const BoxConstraints(
                  minWidth: StackCardSize.touchTarget,
                  minHeight: StackCardSize.touchTarget,
                ),
                color: context.colors.error,
                icon: const Icon(Icons.remove_rounded),
              ),
            ],
          ],
        ),
        if (showActions && onEdit != null) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: StackCardButton(
              label: context.strings.tr('builderForm.edit'),
              role: StackCardButtonRole.outlined,
              onPressed: onEdit,
            ),
          ),
        ],
      ],
    ),
  );
}
