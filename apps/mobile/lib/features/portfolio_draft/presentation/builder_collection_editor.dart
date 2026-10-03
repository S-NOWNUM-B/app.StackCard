import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_content.dart';
import 'builder_editor_widgets.dart';
import 'portfolio_draft_controller.dart';

/// Общий CRUD для четырёх списков; Cancel оставляет working draft без изменений.
class BuilderCollectionEditor<T> extends ConsumerStatefulWidget {
  const BuilderCollectionEditor({
    super.key,
    required this.titleKey,
    required this.readItems,
    required this.writeItems,
    required this.itemId,
    required this.itemTitle,
    required this.itemSummary,
    required this.fields,
    required this.createItem,
  });

  final String titleKey;
  final List<T> Function(PortfolioContent) readItems;
  final PortfolioContent Function(PortfolioContent, List<T>) writeItems;
  final String Function(T) itemId;
  final String Function(T) itemTitle;
  final String Function(T) itemSummary;
  final List<BuilderFieldSpec> Function(T?) fields;
  final T Function(String, Map<String, String>) createItem;

  @override
  ConsumerState<BuilderCollectionEditor<T>> createState() =>
      _BuilderCollectionEditorState<T>();
}

class _BuilderCollectionEditorState<T>
    extends ConsumerState<BuilderCollectionEditor<T>> {
  List<T>? _items;

  Future<void> _edit([T? item]) async {
    final values = await showBuilderRecordEditor(
      context,
      titleKey: widget.titleKey,
      fields: widget.fields(item),
    );
    if (!mounted || values == null) return;
    final id = item == null
        ? ref.read(portfolioDraftControllerProvider.notifier).createId()
        : widget.itemId(item);
    final updated = widget.createItem(id, values);
    setState(() {
      _items = [
        for (final current in _items!)
          if (widget.itemId(current) == id) updated else current,
        if (item == null) updated,
      ];
    });
  }

  void _delete(T item) => setState(() {
    _items = [
      for (final current in _items!)
        if (widget.itemId(current) != widget.itemId(item)) current,
    ];
  });

  void _apply() {
    final state = ref.read(portfolioDraftControllerProvider);
    final current = state.content;
    if (!state.canEdit || current == null || _items == null) return;
    ref
        .read(portfolioDraftControllerProvider.notifier)
        .updateContent(widget.writeItems(current, _items!));
    closeBuilderEditor(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    return BuilderEditorScaffold(
      titleKey: widget.titleKey,
      onApply: state.canEdit && state.content != null ? _apply : null,
      child: BuilderContentGate(
        data: (content) {
          _items ??= [...widget.readItems(content)];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StackCardButton(
                key: const ValueKey('builder_collection_add'),
                label: context.strings.tr('builderForm.add'),
                icon: Icons.add_rounded,
                onPressed: () => _edit(),
              ),
              const SizedBox(height: StackCardSpacing.lg),
              if (_items!.isEmpty)
                StackCardCard(
                  child: StackCardStateView(
                    kind: StackCardViewState.empty,
                    title: context.strings.tr('builderForm.empty'),
                    message: context.strings.tr('builderForm.emptyHint'),
                  ),
                ),
              for (final item in _items!) ...[
                StackCardCard(
                  key: ValueKey((
                    'builder_collection_item',
                    widget.itemId(item),
                  )),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              widget.itemTitle(item),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            key: ValueKey((
                              'builder_collection_edit',
                              widget.itemId(item),
                            )),
                            tooltip: context.strings.tr('builderForm.edit'),
                            onPressed: () => _edit(item),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            key: ValueKey((
                              'builder_collection_delete',
                              widget.itemId(item),
                            )),
                            tooltip: context.strings.tr('builderForm.delete'),
                            onPressed: () => _delete(item),
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      if (widget.itemSummary(item).isNotEmpty) ...[
                        const SizedBox(height: StackCardSpacing.sm),
                        Text(
                          widget.itemSummary(item),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.colors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: StackCardSpacing.lg),
              ],
            ],
          );
        },
      ),
    );
  }
}
