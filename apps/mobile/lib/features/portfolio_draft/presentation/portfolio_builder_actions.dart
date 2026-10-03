import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../shared/widgets/stackcard_button.dart';
import 'portfolio_draft_controller.dart';

Future<void> confirmDraftReload(
  BuildContext context,
  PortfolioDraftController controller,
) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.strings.tr('builder.reloadTitle')),
      content: Text(context.strings.tr('builder.reloadMessage')),
      actions: [
        StackCardButton(
          label: context.strings.tr('builder.cancel'),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        StackCardButton(
          label: context.strings.tr('builder.reloadConfirm'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  if (accepted == true && context.mounted) await controller.reload();
}
