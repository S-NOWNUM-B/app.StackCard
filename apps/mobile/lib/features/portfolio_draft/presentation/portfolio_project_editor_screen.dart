import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';
import 'builder_editor_widgets.dart';
import 'portfolio_draft_controller.dart';

class PortfolioProjectEditorScreen extends ConsumerStatefulWidget {
  const PortfolioProjectEditorScreen({super.key, this.projectId});

  final String? projectId;

  @override
  ConsumerState<PortfolioProjectEditorScreen> createState() =>
      _PortfolioProjectEditorScreenState();
}

class _PortfolioProjectEditorScreenState
    extends ConsumerState<PortfolioProjectEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  List<BuilderFieldSpec>? _fields;
  Map<String, TextEditingController>? _controllers;
  bool _featured = false;
  bool _visible = true;
  PortfolioProject? _initialProject;
  PortfolioDraftRepository? _initialRepository;
  bool _stale = false;

  @override
  void didUpdateWidget(PortfolioProjectEditorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId) {
      disposeBuilderFieldControllers(_controllers);
      _controllers = null;
      _fields = null;
      _initialProject = null;
      _initialRepository = null;
      _stale = false;
    }
  }

  @override
  void dispose() {
    disposeBuilderFieldControllers(_controllers);
    super.dispose();
  }

  PortfolioProject? _findProject(PortfolioContent content) {
    for (final project in content.projects) {
      if (project.id == widget.projectId) return project;
    }
    return null;
  }

  void _initialize(PortfolioProject? project) {
    if (_fields != null) return;
    _initialProject = project;
    _initialRepository = ref.read(portfolioDraftRepositoryProvider);
    _featured = project?.featured ?? false;
    _visible = project?.visible ?? true;
    _fields = [
      BuilderFieldSpec(
        name: 'title',
        labelKey: 'builderForm.projectName',
        value: project?.title ?? '',
        maxLength: 120,
        required: true,
      ),
      BuilderFieldSpec(
        name: 'description',
        labelKey: 'builderForm.description',
        value: project?.description ?? '',
        maxLength: 4000,
        kind: BuilderFieldKind.multiline,
      ),
      BuilderFieldSpec(
        name: 'technologies',
        labelKey: 'builderForm.technologies',
        hintKey: 'builderForm.technologiesHint',
        value: project?.technologies.join(', ') ?? '',
        maxLength: 1238,
        validate: _validateTechnologies,
      ),
      BuilderFieldSpec(
        name: 'repositoryUrl',
        labelKey: 'builderForm.repositoryUrl',
        value: project?.repositoryUrl ?? '',
        maxLength: 2048,
        kind: BuilderFieldKind.url,
      ),
      BuilderFieldSpec(
        name: 'liveUrl',
        labelKey: 'builderForm.liveUrl',
        value: project?.liveUrl ?? '',
        maxLength: 2048,
        kind: BuilderFieldKind.url,
      ),
    ];
    _controllers = builderFieldControllers(_fields!);
  }

  List<String> _technologies(String value) => [
    for (final part in value.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  String? _validateTechnologies(BuildContext context, String value) {
    final technologies = _technologies(value);
    if (technologies.length > 20) {
      return context.strings.tr('builderForm.tooManyTechnologies', {
        'limit': 20,
      });
    }
    if (technologies.any((technology) => technology.length > 60)) {
      return context.strings.tr('builderForm.technologyTooLong', {'limit': 60});
    }
    return null;
  }

  void _apply() {
    if (_formKey.currentState?.validate() != true) return;
    final state = ref.read(portfolioDraftControllerProvider);
    final current = state.content;
    if (!state.canEdit || current == null) return;
    final existingProject = _findProject(current);
    if (!identical(
          _initialRepository,
          ref.read(portfolioDraftRepositoryProvider),
        ) ||
        (widget.projectId != null && existingProject != _initialProject)) {
      setState(() => _stale = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.tr('githubSync.editorStale'))),
      );
      return;
    }
    if (widget.projectId != null && existingProject == null) return;
    final values = builderFieldValues(_controllers!);
    final controller = ref.read(portfolioDraftControllerProvider.notifier);
    final edited = PortfolioProject(
      id: widget.projectId ?? controller.createId(),
      title: values['title']!,
      description: values['description']!,
      technologies: _technologies(values['technologies']!),
      repositoryUrl: values['repositoryUrl']!,
      liveUrl: values['liveUrl']!,
      featured: _featured,
      visible: _visible,
    );
    final project = existingProject?.withUserEdits(edited) ?? edited;
    controller.updateContent(
      current.copyWith(
        projects: [
          for (final existing in current.projects)
            if (existing.id == project.id) project else existing,
          if (widget.projectId == null) project,
        ],
      ),
    );
    closeBuilderEditor(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final content = state.content;
    final found =
        widget.projectId == null ||
        (content != null && _findProject(content) != null);
    return BuilderEditorScaffold(
      titleKey: widget.projectId == null
          ? 'builderForm.newProjectTitle'
          : 'builderForm.editProjectTitle',
      onApply: state.canEdit && content != null && found ? _apply : null,
      child: BuilderContentGate(
        data: (content) {
          final project = _findProject(content);
          if (widget.projectId != null && project == null) {
            return StackCardStateView(
              kind: StackCardViewState.empty,
              title: context.strings.tr('builderForm.projectMissing'),
              message: context.strings.tr('builderForm.projectMissingHint'),
            );
          }
          _initialize(project);
          return StackCardCard(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_stale) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        context.strings.tr('githubSync.editorStale'),
                        key: const ValueKey('builder_project_stale'),
                      ),
                    ),
                    const SizedBox(height: StackCardSpacing.lg),
                  ],
                  if (project?.source == PortfolioProjectSource.github) ...[
                    Text(context.strings.tr('githubSync.editorNote')),
                    const SizedBox(height: StackCardSpacing.lg),
                  ],
                  BuilderFields(
                    fields: _fields!,
                    controllers: _controllers!,
                    onSubmit: _apply,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                  Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: [
                        SwitchListTile(
                          key: const ValueKey('builder_form_featured'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            context.strings.tr('builderForm.featured'),
                          ),
                          value: _featured,
                          onChanged: (value) =>
                              setState(() => _featured = value),
                        ),
                        SwitchListTile(
                          key: const ValueKey('builder_form_visible'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            context.strings.tr('builderForm.visible'),
                          ),
                          value: _visible,
                          onChanged: (value) =>
                              setState(() => _visible = value),
                        ),
                      ],
                    ),
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
