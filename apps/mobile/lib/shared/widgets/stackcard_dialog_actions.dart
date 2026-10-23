import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_tokens.dart';
import 'stackcard_button.dart';

/// Отмена слева, основное действие справа; обычно — две кнопки равной ширины.
class StackCardDialogActions extends StatelessWidget {
  const StackCardDialogActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.confirmLabel,
    this.cancelLabel,
    this.confirmKey,
    this.cancelKey,
    this.loading = false,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String? confirmLabel;
  final String? cancelLabel;
  final Key? confirmKey;
  final Key? cancelKey;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final cancel = StackCardButton(
      key: cancelKey,
      label: cancelLabel ?? context.strings.tr('common.cancel'),
      role: StackCardButtonRole.outlined,
      onPressed: loading ? null : onCancel,
    );
    final confirm = StackCardButton(
      key: confirmKey,
      label: confirmLabel ?? context.strings.tr('common.confirm'),
      primary: true,
      loading: loading,
      onPressed: onConfirm,
    );
    // Диалог считает intrinsic-размеры, поэтому без LayoutBuilder: по экрану и шрифту.
    final narrow =
        MediaQuery.sizeOf(context).width < 320 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    if (narrow) {
      // Узкое окно или крупный шрифт: ряд по содержимому, перенос — столбцом.
      return SizedBox(
        width: double.infinity,
        child: OverflowBar(
          alignment: MainAxisAlignment.end,
          overflowAlignment: OverflowBarAlignment.end,
          spacing: StackCardSpacing.sm,
          overflowSpacing: StackCardSpacing.sm,
          children: [cancel, confirm],
        ),
      );
    }
    // Ряд равных кнопок; длинная подпись переносится внутри кнопки.
    return Row(
      children: [
        Expanded(child: cancel),
        const SizedBox(width: StackCardSpacing.sm),
        Expanded(child: confirm),
      ],
    );
  }
}
