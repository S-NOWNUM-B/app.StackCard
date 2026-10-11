import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_dialog_actions.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../portfolio_draft_providers.dart';

/// Одинаковые теги для навыков портфолио и технологий проекта.
class BuilderTagsEditor extends StatelessWidget {
  const BuilderTagsEditor({
    super.key,
    required this.title,
    required this.items,
    required this.keyPrefix,
    required this.addLabel,
    required this.removeLabel,
    required this.onAdd,
    required this.onRemove,
    this.enabled = true,
    this.addKey,
    this.onEdit,
    this.iconName,
  });

  final String title;
  final List<String> items;
  final String keyPrefix;
  final String addLabel;
  final String Function(String) removeLabel;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final bool enabled;
  final Key? addKey;
  final ValueChanged<int>? onEdit;
  final String Function(int)? iconName;

  Widget _label(BuildContext context, int index) {
    if (onEdit == null) return StackCardTechnologyBadge(label: items[index]);
    return Tooltip(
      message: 'Редактировать ${items[index]}',
      child: InkWell(
        key: ValueKey('$keyPrefix.edit.$index'),
        onTap: enabled ? () => onEdit!(index) : null,
        borderRadius: BorderRadius.circular(StackCardRadius.small),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: StackCardSize.touchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: StackCardSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconName != null) ...[
                  StackCardIcon(name: iconName!(index), size: 20),
                  const SizedBox(width: StackCardSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    items[index],
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StackCardCard(
    outlined: true,
    padding: const EdgeInsets.all(StackCardSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton(
              key: addKey ?? ValueKey('$keyPrefix.add'),
              tooltip: addLabel,
              onPressed: enabled ? onAdd : null,
              icon: const StackCardIcon(name: 'plus'),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: StackCardSpacing.md),
          Wrap(
            spacing: StackCardSpacing.sm,
            runSpacing: StackCardSpacing.sm,
            children: [
              for (var index = 0; index < items.length; index++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.surfaceElevated,
                    borderRadius: BorderRadius.circular(StackCardRadius.small),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: StackCardSpacing.xs),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: _label(context, index)),
                        const SizedBox(width: StackCardSpacing.xs),
                        IconButton(
                          key: ValueKey('$keyPrefix.remove.$index'),
                          tooltip: removeLabel(items[index]),
                          onPressed: enabled ? () => onRemove(index) : null,
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    ),
  );
}

/// Ввод одного тега с прежними стандартными кнопками и защитой владельца.
class BuilderTagDialog extends ConsumerStatefulWidget {
  const BuilderTagDialog({
    super.key,
    required this.title,
    required this.keyPrefix,
    required this.validate,
  });

  final String title;
  final String keyPrefix;
  final String? Function(BuildContext, String) validate;

  @override
  ConsumerState<BuilderTagDialog> createState() => _BuilderTagDialogState();
}

class _BuilderTagDialogState extends ConsumerState<BuilderTagDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  late final _repository = ref.read(portfolioDraftRepositoryProvider);
  bool _ownerInvalid = false;

  @override
  void initState() {
    super.initState();
    _repository;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_ownerInvalid ||
        !identical(_repository, ref.read(portfolioDraftRepositoryProvider))) {
      return;
    }
    if (_formKey.currentState?.validate() == true) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(portfolioDraftRepositoryProvider, (_, next) {
      if (identical(_repository, next) || _ownerInvalid) return;
      _controller.clear();
      setState(() => _ownerInvalid = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
    });
    if (_ownerInvalid) return const SizedBox.shrink();
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: StackCardInput(
          key: ValueKey('${widget.keyPrefix}.name'),
          label: context.strings.tr('builderForm.name'),
          controller: _controller,
          autofocus: true,
          validator: (raw) => widget.validate(context, (raw ?? '').trim()),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submit(),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
      ),
      actions: [
        StackCardDialogActions(
          confirmKey: ValueKey('${widget.keyPrefix}.confirm'),
          cancelKey: ValueKey('${widget.keyPrefix}.cancel'),
          confirmLabel: context.strings.tr('common.save'),
          onCancel: () => Navigator.pop(context),
          onConfirm: _submit,
        ),
      ],
    );
  }
}
