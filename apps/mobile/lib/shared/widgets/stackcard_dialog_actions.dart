import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/stackcard_tokens.dart';
import 'stackcard_button.dart';

/// Отмена слева, основное действие справа; при переносе оно остаётся последним.
class StackCardDialogActions extends StatelessWidget {
  const StackCardDialogActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.confirmLabel,
    this.confirmKey,
    this.cancelKey,
    this.loading = false,
  });

  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final String? confirmLabel;
  final Key? confirmKey;
  final Key? cancelKey;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OverflowBar(
      alignment: MainAxisAlignment.end,
      overflowAlignment: OverflowBarAlignment.end,
      spacing: StackCardSpacing.sm,
      overflowSpacing: StackCardSpacing.sm,
      children: [
        StackCardButton(
          key: cancelKey,
          label: context.strings.tr('common.cancel'),
          role: StackCardButtonRole.outlined,
          onPressed: loading ? null : onCancel,
        ),
        StackCardButton(
          key: confirmKey,
          label: confirmLabel ?? context.strings.tr('common.confirm'),
          primary: true,
          loading: loading,
          onPressed: onConfirm,
        ),
      ],
    ),
  );
}
