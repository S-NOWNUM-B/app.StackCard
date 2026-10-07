import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_validation.dart';
import '../portfolio_draft_providers.dart';
import 'portfolio_draft_controller.dart';

enum BuilderFieldKind { text, multiline, username, url }

class BuilderFieldSpec {
  const BuilderFieldSpec({
    required this.name,
    required this.labelKey,
    this.value = '',
    this.maxLength = 200,
    this.required = false,
    this.kind = BuilderFieldKind.text,
    this.hintKey,
    this.choices,
    this.validate,
  });

  final String name;
  final String labelKey;
  final String value;
  final int maxLength;
  final bool required;
  final BuilderFieldKind kind;
  final String? hintKey;
  final Map<String, String>? choices;
  final String? Function(BuildContext, String)? validate;
}

Map<String, TextEditingController> builderFieldControllers(
  List<BuilderFieldSpec> fields,
) => {
  for (final field in fields)
    field.name: TextEditingController(text: field.value),
};

void disposeBuilderFieldControllers(
  Map<String, TextEditingController>? controllers,
) {
  if (controllers == null) return;
  for (final controller in controllers.values) {
    controller.dispose();
  }
}

Map<String, String> builderFieldValues(
  Map<String, TextEditingController> controllers,
) => controllers.map((name, controller) => MapEntry(name, controller.text));

String? builderValidationMessage(
  BuildContext context,
  PortfolioValidationCode? code, {
  int maxLength = 200,
}) => switch (code) {
  null => null,
  PortfolioValidationCode.required => context.strings.tr(
    'builderForm.required',
  ),
  PortfolioValidationCode.tooLong => context.strings.tr('builderForm.tooLong', {
    'limit': maxLength,
  }),
  PortfolioValidationCode.invalidUsername => context.strings.tr(
    'builderForm.invalidUsername',
  ),
  PortfolioValidationCode.invalidUrl => context.strings.tr(
    'builderForm.invalidUrl',
  ),
  PortfolioValidationCode.duplicateId ||
  PortfolioValidationCode.invalidStructure => context.strings.tr(
    'builderForm.invalidContent',
  ),
};

class BuilderFields extends StatelessWidget {
  const BuilderFields({
    super.key,
    required this.fields,
    required this.controllers,
    this.onSubmit,
    this.autofocus = false,
  });

  final List<BuilderFieldSpec> fields;
  final Map<String, TextEditingController> controllers;
  final VoidCallback? onSubmit;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < fields.length; index++) ...[
        if (index != 0) const SizedBox(height: StackCardSpacing.lg),
        _field(context, fields[index], index),
      ],
    ],
  );

  Widget _field(BuildContext context, BuilderFieldSpec field, int index) {
    final name = field.name;
    final choices = field.choices;
    if (choices != null) {
      return DropdownButtonFormField<String>(
        key: ValueKey('builder_form_$name'),
        initialValue: controllers[name]!.text,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: context.strings.tr(field.labelKey),
        ),
        items: [
          for (final choice in choices.entries)
            DropdownMenuItem(
              value: choice.key,
              child: Text(context.strings.tr(choice.value)),
            ),
        ],
        onChanged: (value) {
          if (value != null) controllers[name]!.text = value;
        },
      );
    }
    final multiline = field.kind == BuilderFieldKind.multiline;
    return StackCardInput(
      key: ValueKey('builder_form_$name'),
      label: context.strings.tr(field.labelKey),
      hint: field.hintKey == null ? null : context.strings.tr(field.hintKey!),
      controller: controllers[name],
      autofocus: autofocus && index == 0,
      keyboardType: switch (field.kind) {
        BuilderFieldKind.url => TextInputType.url,
        BuilderFieldKind.multiline => TextInputType.multiline,
        _ => TextInputType.text,
      },
      minLines: multiline ? 4 : null,
      maxLines: multiline ? 10 : 1,
      textInputAction: multiline
          ? TextInputAction.newline
          : index == fields.length - 1
          ? TextInputAction.done
          : TextInputAction.next,
      onFieldSubmitted: multiline
          ? null
          : (_) {
              if (index == fields.length - 1 && onSubmit != null) {
                onSubmit!();
              } else {
                FocusScope.of(context).nextFocus();
              }
            },
      validator: (value) {
        final text = value ?? '';
        final basic = validatePortfolioText(
          text,
          required: field.required,
          maxLength: field.maxLength,
        );
        if (basic != null) {
          return builderValidationMessage(
            context,
            basic,
            maxLength: field.maxLength,
          );
        }
        final code = switch (field.kind) {
          BuilderFieldKind.username => validatePortfolioUsername(text),
          BuilderFieldKind.url => validatePortfolioUrl(text),
          _ => null,
        };
        return builderValidationMessage(
              context,
              code,
              maxLength: field.maxLength,
            ) ??
            field.validate?.call(context, text);
      },
    );
  }
}

void closeBuilderEditor(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    final path = GoRouterState.of(context).uri.path;
    context.go(
      path.startsWith('/settings')
          ? '/settings/profile'
          : path.startsWith('/projects')
          ? '/projects'
          : '/portfolio/builder',
    );
  }
}

class BuilderEditorScaffold extends StatelessWidget {
  const BuilderEditorScaffold({
    super.key,
    required this.titleKey,
    required this.child,
    this.onApply,
    this.applyLabelKey = 'builderForm.apply',
    this.allowClose = true,
  });
  final String titleKey;
  final Widget child;
  final VoidCallback? onApply;
  final String applyLabelKey;
  final bool allowClose;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.strings.tr(titleKey)),
      leading: IconButton(
        tooltip: context.strings.tr('builderForm.cancel'),
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: allowClose ? () => closeBuilderEditor(context) : null,
      ),
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StackCardSize.contentMaxWidth,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
            child: child,
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          StackCardSpacing.lg,
          StackCardSpacing.sm,
          StackCardSpacing.lg,
          StackCardSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Wrap(
          spacing: StackCardSpacing.md,
          runSpacing: StackCardSpacing.md,
          children: [
            StackCardButton(
              key: const ValueKey('builder_form_apply'),
              label: context.strings.tr(applyLabelKey),
              icon: Icons.check_rounded,
              primary: true,
              onPressed: onApply,
            ),
            StackCardButton(
              key: const ValueKey('builder_form_cancel'),
              label: context.strings.tr('builderForm.cancel'),
              onPressed: allowClose ? () => closeBuilderEditor(context) : null,
            ),
          ],
        ),
      ),
    ),
  );
}

class BuilderContentGate extends ConsumerWidget {
  const BuilderContentGate({super.key, required this.data});

  final Widget Function(PortfolioContent) data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(portfolioDraftControllerProvider);
    if (state.loading) {
      return StackCardStateView(
        kind: StackCardViewState.loading,
        title: context.strings.tr('builderForm.loading'),
        message: context.strings.tr('builderForm.loadingHint'),
      );
    }
    if (!state.canEdit) {
      return StackCardStateView(
        kind: StackCardViewState.error,
        title: context.strings.tr('builderForm.unavailable'),
        message: context.strings.tr(switch (state.failure?.kind) {
          PortfolioDraftFailureKind.corrupted => 'builderForm.corrupted',
          PortfolioDraftFailureKind.unsupportedVersion =>
            'builderForm.unsupportedVersion',
          _ => 'builderForm.unavailableHint',
        }),
        onRetry: state.loaded
            ? null
            : ref.read(portfolioDraftControllerProvider.notifier).load,
      );
    }
    final content = state.content;
    if (content == null) {
      return Column(
        children: [
          StackCardStateView(
            kind: StackCardViewState.empty,
            title: context.strings.tr('builderForm.noContent'),
            message: context.strings.tr('builderForm.noContentHint'),
          ),
          StackCardButton(
            label: context.strings.tr('builderForm.openBuilder'),
            onPressed: () => context.go('/portfolio/builder'),
          ),
        ],
      );
    }
    return data(content);
  }
}

Future<Map<String, String>?> showBuilderRecordEditor(
  BuildContext context, {
  required String titleKey,
  required List<BuilderFieldSpec> fields,
}) => showDialog<Map<String, String>>(
  context: context,
  builder: (_) => _BuilderRecordDialog(titleKey: titleKey, fields: fields),
);

class _BuilderRecordDialog extends ConsumerStatefulWidget {
  const _BuilderRecordDialog({required this.titleKey, required this.fields});

  final String titleKey;
  final List<BuilderFieldSpec> fields;

  @override
  ConsumerState<_BuilderRecordDialog> createState() =>
      _BuilderRecordDialogState();
}

class _BuilderRecordDialogState extends ConsumerState<_BuilderRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controllers = builderFieldControllers(widget.fields);
  late final _repository = ref.read(portfolioDraftRepositoryProvider);
  bool _ownerInvalid = false;

  @override
  void initState() {
    super.initState();
    // Захват до первого изменения provider, даже если modal ещё не построен.
    _repository;
  }

  @override
  void dispose() {
    disposeBuilderFieldControllers(_controllers);
    super.dispose();
  }

  void _apply() {
    if (_ownerInvalid ||
        !identical(_repository, ref.read(portfolioDraftRepositoryProvider))) {
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(builderFieldValues(_controllers));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(portfolioDraftRepositoryProvider, (_, next) {
      if (identical(_repository, next) || _ownerInvalid) return;
      for (final controller in _controllers.values) {
        controller.clear();
      }
      setState(() => _ownerInvalid = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
      });
    });
    if (_ownerInvalid) return const SizedBox.shrink();
    return Dialog(
      insetPadding: const EdgeInsets.all(StackCardSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(StackCardSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.strings.tr(widget.titleKey),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: StackCardSpacing.xl),
                BuilderFields(
                  fields: widget.fields,
                  controllers: _controllers,
                  onSubmit: _apply,
                  autofocus: true,
                ),
                const SizedBox(height: StackCardSpacing.xl),
                Wrap(
                  spacing: StackCardSpacing.md,
                  runSpacing: StackCardSpacing.md,
                  children: [
                    StackCardButton(
                      key: const ValueKey('builder_record_apply'),
                      label: context.strings.tr('builderForm.addOrUpdate'),
                      primary: true,
                      onPressed: _apply,
                    ),
                    StackCardButton(
                      key: const ValueKey('builder_record_cancel'),
                      label: context.strings.tr('builderForm.cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
