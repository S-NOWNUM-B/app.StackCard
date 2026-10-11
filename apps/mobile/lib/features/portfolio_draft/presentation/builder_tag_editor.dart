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
    this.headerLeading,
    this.onReorder,
    this.sliver = false,
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
  final bool sliver;
  final Widget? headerLeading;
  final void Function(int oldIndex, int newIndex)? onReorder;

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

  Widget _header(BuildContext context) => BuilderSectionHeader(
    title: title,
    leading: headerLeading,
    action: IconButton(
      key: addKey ?? ValueKey('$keyPrefix.add'),
      tooltip: addLabel,
      onPressed: enabled ? onAdd : null,
      icon: const StackCardIcon(name: 'plus'),
    ),
  );

  Widget _reorderableItem(BuildContext context, int index) => Padding(
    key: ValueKey(
      '$keyPrefix.item.${items[index]}.${items.take(index).where((item) => item == items[index]).length}',
    ),
    padding: const EdgeInsets.only(bottom: StackCardSpacing.sm),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(StackCardRadius.small),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Изменить порядок ${items[index]}',
            hint: 'Удерживайте точки и перетащите',
            child: ReorderableDelayedDragStartListener(
              key: ValueKey('$keyPrefix.drag.$index'),
              index: index,
              enabled: enabled,
              child: const SizedBox(
                width: StackCardSize.touchTarget,
                height: StackCardSize.touchTarget,
                child: ColoredBox(
                  color: Colors.transparent,
                  child: Center(
                    child: StackCardIcon(name: 'grip-vertical', size: 20),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: _label(context, index)),
          IconButton(
            key: ValueKey('$keyPrefix.remove.$index'),
            tooltip: removeLabel(items[index]),
            onPressed: enabled ? () => onRemove(index) : null,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    ),
  );

  void _reorder(int oldIndex, int newIndex) {
    if (enabled) onReorder!(oldIndex, newIndex);
  }

  Widget _sliver(BuildContext context) => DecoratedSliver(
    decoration: BoxDecoration(
      color: context.colors.surface,
      border: Border.all(color: context.colors.border),
      borderRadius: BorderRadius.circular(StackCardRadius.large),
    ),
    sliver: SliverPadding(
      padding: const EdgeInsets.all(StackCardSpacing.lg),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(child: _header(context)),
          if (items.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: SizedBox(height: StackCardSpacing.md),
            ),
            SliverReorderableList(
              itemCount: items.length,
              itemBuilder: _reorderableItem,
              onReorderItem: _reorder,
              proxyDecorator: (child, index, animation) =>
                  Material(type: MaterialType.transparency, child: child),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => sliver
      ? _sliver(context)
      : StackCardCard(
          outlined: true,
          padding: const EdgeInsets.all(StackCardSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context),
              if (items.isNotEmpty) ...[
                const SizedBox(height: StackCardSpacing.md),
                if (onReorder != null)
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemBuilder: _reorderableItem,
                    onReorderItem: _reorder,
                  )
                else
                  Wrap(
                    spacing: StackCardSpacing.sm,
                    runSpacing: StackCardSpacing.sm,
                    children: [
                      for (var index = 0; index < items.length; index++)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(
                              StackCardRadius.small,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: StackCardSpacing.xs,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(child: _label(context, index)),
                                const SizedBox(width: StackCardSpacing.xs),
                                IconButton(
                                  key: ValueKey('$keyPrefix.remove.$index'),
                                  tooltip: removeLabel(items[index]),
                                  onPressed: enabled
                                      ? () => onRemove(index)
                                      : null,
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 20,
                                  ),
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

/// Заголовок сохраняет место для крупного текста и controls48.
class BuilderSectionHeader extends StatelessWidget {
  const BuilderSectionHeader({
    super.key,
    required this.title,
    required this.action,
    this.leading,
  });
  final String title;
  final Widget action;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final style = Theme.of(context).textTheme.titleLarge;
      final painter = TextPainter(
        text: TextSpan(
          text: title.split(' ').reduce((a, b) => a.length >= b.length ? a : b),
          style: style,
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final compact =
          painter.width +
              StackCardSize.touchTarget * (leading == null ? 1 : 2) >
          constraints.maxWidth;
      painter.dispose();
      final heading = Text(title, style: style);
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            heading,
            Row(children: [?leading, const Spacer(), action]),
          ],
        );
      }
      return Row(
        children: [
          ?leading,
          Expanded(child: heading),
          action,
        ],
      );
    },
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
