import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../media/media.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_validation.dart';
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
  var _mediaKey = GlobalKey<PortfolioMediaEditorState>();
  List<String> _imagePaths = const [];
  bool _mediaBusy = false;

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
      _mediaKey = GlobalKey<PortfolioMediaEditorState>();
      _imagePaths = const [];
      _mediaBusy = false;
    }
  }

  @override
  void dispose() {
    disposeBuilderFieldControllers(_controllers);
    super.dispose();
  }

  PortfolioProject? _findProject(PortfolioContent content) {
    final id = widget.projectId ?? _initialProject?.id;
    for (final project in content.projects) {
      if (project.id == id) return project;
    }
    return null;
  }

  void _initialize(PortfolioProject? project) {
    if (_fields != null) return;
    _initialProject = project;
    _initialRepository = ref.read(portfolioDraftRepositoryProvider);
    _imagePaths = project?.imagePaths ?? const [];
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

  Future<void> _apply() async {
    if (_mediaBusy || ref.read(portfolioDraftControllerProvider).saving) return;
    if (_formKey.currentState?.validate() != true) return;
    final state = ref.read(portfolioDraftControllerProvider);
    final current = state.content;
    if (!state.canEdit || current == null) return;
    final existingProject = _findProject(current);
    if (!identical(
          _initialRepository,
          ref.read(portfolioDraftRepositoryProvider),
        ) ||
        (_initialProject != null && existingProject != _initialProject)) {
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
      id: widget.projectId ?? _initialProject?.id ?? controller.createId(),
      title: values['title']!,
      description: values['description']!,
      technologies: _technologies(values['technologies']!),
      repositoryUrl: values['repositoryUrl']!,
      liveUrl: values['liveUrl']!,
      featured: _featured,
      visible: _visible,
      imagePaths: _imagePaths,
      updatedAt: DateTime.now().toUtc(),
    );
    final project =
        existingProject
            ?.withUserEdits(edited)
            .copyWith(imagePaths: _imagePaths, updatedAt: edited.updatedAt) ??
        edited;
    final saved = await controller.saveProject(
      project,
      expectedProject: _initialProject,
      expectedRepository: _initialRepository!,
    );
    if (!mounted ||
        !identical(
          _initialRepository,
          ref.read(portfolioDraftRepositoryProvider),
        )) {
      return;
    }
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.tr('workspace.failure'))),
      );
      return;
    }
    _initialProject = project;
    _mediaKey.currentState?.retainUploads(paths: project.imagePaths);
    // Ввод после нажатия Save остаётся в форме, даже если старый snapshot сохранён.
    if (!mapEquals(values, builderFieldValues(_controllers!)) ||
        !listEquals(project.imagePaths, _imagePaths)) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/projects');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final ownerChanged =
        _initialRepository != null &&
        !identical(_initialRepository, repository);
    final content = state.content;
    if (state.canEdit && content == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            ref.read(portfolioDraftControllerProvider).content == null) {
          ref.read(portfolioDraftControllerProvider.notifier).startBuilder();
        }
      });
    }
    final found =
        widget.projectId == null ||
        (content != null && _findProject(content) != null);
    return PopScope(
      canPop: !state.saving,
      child: BuilderEditorScaffold(
        allowClose: !state.saving,
        applyLabelKey: 'builder.save',
        titleKey: widget.projectId == null
            ? 'builderForm.newProjectTitle'
            : 'builderForm.editProjectTitle',
        onApply:
            state.canEdit &&
                content != null &&
                found &&
                !_mediaBusy &&
                !ownerChanged &&
                !state.saving
            ? _apply
            : null,
        child: BuilderContentGate(
          data: (content) {
            if (ownerChanged) {
              return Text(context.strings.tr('media.ownerChanged'));
            }
            final project = _findProject(content);
            if (widget.projectId != null && project == null) {
              return StackCardStateView(
                kind: StackCardViewState.empty,
                title: context.strings.tr('builderForm.projectMissing'),
                message: context.strings.tr('builderForm.projectMissingHint'),
              );
            }
            _initialize(project);
            return Padding(
              padding: EdgeInsets.zero,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PortfolioMediaEditor(
                      key: _mediaKey,
                      maxImages: portfolioProjectImageLimit,
                      paths: _imagePaths,
                      enabled: !state.saving && !ownerChanged,
                      onChanged: (paths) => setState(() => _imagePaths = paths),
                      onBusyChanged: (busy) =>
                          setState(() => _mediaBusy = busy),
                    ),
                    const SizedBox(height: StackCardSpacing.xl),
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
                    if (project != null)
                      StackCardButton(
                        label: context.strings.tr('workspace.delete'),
                        role: StackCardButtonRole.danger,
                        onPressed: !state.saving
                            ? () async {
                                final accepted = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text(
                                      context.strings.tr(
                                        'workspace.deleteProjectTitle',
                                      ),
                                    ),
                                    content: Text(
                                      context.strings.tr(
                                        'workspace.deleteProjectHint',
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text(
                                          context.strings.tr('builder.cancel'),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: Text(
                                          context.strings.tr(
                                            'workspace.delete',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                                if (accepted != true || !mounted) return;
                                final removed = await ref
                                    .read(
                                      portfolioDraftControllerProvider.notifier,
                                    )
                                    .deleteProject(
                                      project,
                                      expectedRepository: repository,
                                    );
                                if (removed && mounted) {
                                  if (this.context.canPop()) {
                                    this.context.pop();
                                  } else {
                                    this.context.go('/projects');
                                  }
                                }
                              }
                            : null,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
