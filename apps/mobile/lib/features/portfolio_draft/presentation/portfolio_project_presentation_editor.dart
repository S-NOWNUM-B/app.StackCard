import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../domain/portfolio_content.dart';
import '../portfolio_draft_providers.dart';

class PortfolioProjectPresentationEditor extends ConsumerStatefulWidget {
  const PortfolioProjectPresentationEditor({
    super.key,
    required this.project,
    required this.attachment,
    required this.isActive,
  });

  final PortfolioProject project;
  final PortfolioProjectAttachment attachment;
  final bool Function() isActive;

  @override
  ConsumerState<PortfolioProjectPresentationEditor> createState() =>
      _PortfolioProjectPresentationEditorState();
}

class _PortfolioProjectPresentationEditorState
    extends ConsumerState<PortfolioProjectPresentationEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.attachment.titleOverride ?? widget.project.title,
  );
  late final _description = TextEditingController(
    text: widget.attachment.descriptionOverride ?? widget.project.description,
  );
  late final _contribution = TextEditingController(
    text: widget.attachment.contributionOverride ?? widget.project.contribution,
  );
  late bool _inheritTitle = widget.attachment.titleOverride == null;
  late bool _inheritDescription = widget.attachment.descriptionOverride == null;
  late bool _inheritContribution =
      widget.attachment.contributionOverride == null;

  String _tr(String key) => context.strings.tr('projectPresentation.$key');

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _contribution.dispose();
    super.dispose();
  }

  void _apply() {
    if (!widget.isActive() || _form.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      widget.attachment.copyWith(
        titleOverride: _inheritTitle ? null : _title.text.trim(),
        descriptionOverride: _inheritDescription
            ? null
            : _description.text.trim(),
        contributionOverride: _inheritContribution
            ? null
            : _contribution.text.trim(),
        clearTitleOverride: _inheritTitle,
        clearDescriptionOverride: _inheritDescription,
        clearContributionOverride: _inheritContribution,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Owner transition перестраивает модальный экран и убирает прежний ввод.
    ref.watch(portfolioDraftRepositoryProvider);
    final active = widget.isActive();
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr('title')),
        leading: IconButton(
          tooltip: context.strings.tr('builder.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          icon: const StackCardIcon(name: 'arrow-left'),
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
              child: !active
                  ? Text(context.strings.tr('documentEditor.ownerChanged'))
                  : Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_tr('hint')),
                          const SizedBox(height: StackCardSpacing.xl),
                          _field(
                            'name',
                            _title,
                            _inheritTitle,
                            120,
                            (value) => setState(() => _inheritTitle = value),
                            widget.project.title,
                            required: true,
                          ),
                          _field(
                            'description',
                            _description,
                            _inheritDescription,
                            4000,
                            (value) =>
                                setState(() => _inheritDescription = value),
                            widget.project.description,
                            multiline: true,
                          ),
                          _field(
                            'contribution',
                            _contribution,
                            _inheritContribution,
                            4000,
                            (value) =>
                                setState(() => _inheritContribution = value),
                            widget.project.contribution,
                            multiline: true,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: StackCardButton(
                  label: context.strings.tr('builder.cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: StackCardSpacing.sm),
              Expanded(
                child: StackCardButton(
                  key: const ValueKey('project-presentation.apply'),
                  label: _tr('apply'),
                  primary: true,
                  onPressed: active ? _apply : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    String name,
    TextEditingController controller,
    bool inherit,
    int maxLength,
    ValueChanged<bool> onInherit,
    String libraryValue, {
    bool required = false,
    bool multiline = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StackCardInput(
        key: ValueKey('project-presentation.$name'),
        label: _tr(name),
        controller: controller,
        enabled: !inherit,
        maxLines: multiline ? null : 1,
        minLines: multiline ? 3 : null,
        keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
        validator: (value) =>
            !inherit &&
                ((required && (value ?? '').trim().isEmpty) ||
                    (value ?? '').length > maxLength)
            ? _tr('invalid')
            : null,
      ),
      CheckboxListTile(
        key: ValueKey('project-presentation.inherit.$name'),
        contentPadding: EdgeInsets.zero,
        title: Text(_tr('inherit')),
        value: inherit,
        onChanged: (value) {
          if (!widget.isActive()) return;
          onInherit(value ?? false);
          if (value == true) controller.text = libraryValue;
        },
      ),
      const SizedBox(height: StackCardSpacing.lg),
    ],
  );
}
