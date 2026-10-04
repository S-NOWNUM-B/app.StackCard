import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import 'builder_editor_widgets.dart';
import 'portfolio_draft_controller.dart';

class PortfolioResumeEditorScreen extends ConsumerStatefulWidget {
  const PortfolioResumeEditorScreen({super.key});

  @override
  ConsumerState<PortfolioResumeEditorScreen> createState() =>
      _PortfolioResumeEditorScreenState();
}

class _PortfolioResumeEditorScreenState
    extends ConsumerState<PortfolioResumeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  Map<String, TextEditingController>? _controllers;
  static const _fields = [
    BuilderFieldSpec(
      name: 'resumeText',
      labelKey: 'builderForm.resumeText',
      maxLength: 20000,
      kind: BuilderFieldKind.multiline,
    ),
  ];

  @override
  void dispose() {
    disposeBuilderFieldControllers(_controllers);
    super.dispose();
  }

  void _apply() {
    if (_formKey.currentState?.validate() != true) return;
    final state = ref.read(portfolioDraftControllerProvider);
    final current = state.content;
    if (!state.canEdit || current == null) return;
    ref
        .read(portfolioDraftControllerProvider.notifier)
        .updateContent(
          current.copyWith(resumeText: _controllers!['resumeText']!.text),
        );
    closeBuilderEditor(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    return BuilderEditorScaffold(
      titleKey: 'builderForm.resumeTitle',
      onApply: state.canEdit && state.content != null ? _apply : null,
      child: BuilderContentGate(
        data: (content) {
          _controllers ??= {
            'resumeText': TextEditingController(text: content.resumeText),
          };
          return Padding(
            padding: EdgeInsets.zero,
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(context.strings.tr('builderForm.resumeHint')),
                  const SizedBox(height: StackCardSpacing.lg),
                  BuilderFields(
                    fields: _fields,
                    controllers: _controllers!,
                    onSubmit: _apply,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
