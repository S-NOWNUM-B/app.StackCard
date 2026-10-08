import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../../media/media.dart';
import '../../projects/projects.dart';
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
  Map<String, String>? _baselineValues;
  List<String> _baselineImages = const [];
  bool _editingTechnologies = false;
  bool _allowPop = false;
  bool _confirmingExit = false;
  bool _saveFailed = false;

  bool get _dirty =>
      _controllers != null &&
      (!mapEquals(_baselineValues, builderFieldValues(_controllers!)) ||
          !listEquals(_baselineImages, _imagePaths));

  void _inputChanged() {
    if (mounted) setState(() => _saveFailed = false);
  }

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
      _baselineValues = null;
      _baselineImages = const [];
      _editingTechnologies = false;
      _allowPop = false;
      _saveFailed = false;
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
        name: 'contribution',
        labelKey: 'mobileParity.contribution',
        hintKey: 'mobileParity.contributionHint',
        value: project?.contribution ?? '',
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
    _baselineValues = builderFieldValues(_controllers!);
    _baselineImages = List.of(_imagePaths);
    for (final controller in _controllers!.values) {
      controller.addListener(_inputChanged);
    }
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
      contribution: values['contribution']!,
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
      setState(() => _saveFailed = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.strings.tr('workspace.failure'))),
      );
      return;
    }
    _initialProject = project;
    _baselineValues = values;
    _baselineImages = List.of(project.imagePaths);
    _mediaKey.currentState?.retainUploads(paths: project.imagePaths);
    // Ввод после нажатия Save остаётся в форме, даже если старый snapshot сохранён.
    if (!mapEquals(values, builderFieldValues(_controllers!)) ||
        !listEquals(project.imagePaths, _imagePaths)) {
      return;
    }
    _leave();
  }

  void _leave() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/projects');
      }
    });
  }

  Future<void> _close() async {
    if (ref.read(portfolioDraftControllerProvider).saving || _confirmingExit) {
      return;
    }
    if (!_dirty) {
      _leave();
      return;
    }
    _confirmingExit = true;
    FocusManager.instance.primaryFocus?.unfocus();
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        semanticLabel: context.strings.tr('mobileParity.leaveTitle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.strings.tr('mobileParity.leaveTitle'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: StackCardSpacing.md),
            Text(context.strings.tr('mobileParity.leaveHint')),
            const SizedBox(height: StackCardSpacing.lg),
            StackCardButton(
              key: const ValueKey('project.leave.stay'),
              label: context.strings.tr('mobileParity.stay'),
              onPressed: () => Navigator.pop(context, false),
            ),
            const SizedBox(height: StackCardSpacing.sm),
            StackCardButton(
              key: const ValueKey('project.leave.discard'),
              role: StackCardButtonRole.danger,
              label: context.strings.tr('mobileParity.discard'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );
    _confirmingExit = false;
    if (discard == true && mounted) _leave();
  }

  Widget _field(String name, {String? helperKey, int? limit}) {
    final field = _fields!.firstWhere((item) => item.name == name);
    final multiline = field.kind == BuilderFieldKind.multiline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.strings.tr(field.labelKey),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        StackCardInput(
          key: ValueKey('builder_form_$name'),
          label: context.strings.tr(field.labelKey),
          showLabel: false,
          controller: _controllers![name],
          hint: field.hintKey == null
              ? null
              : context.strings.tr(field.hintKey!),
          keyboardType: field.kind == BuilderFieldKind.url
              ? TextInputType.url
              : multiline
              ? TextInputType.multiline
              : TextInputType.text,
          minLines: multiline ? 4 : null,
          maxLines: multiline ? 10 : 1,
          textInputAction: multiline
              ? TextInputAction.newline
              : TextInputAction.next,
          validator: (value) {
            final raw = value ?? '';
            final basic = validatePortfolioText(
              raw,
              required: field.required,
              maxLength: field.maxLength,
            );
            final issue =
                basic ??
                (field.kind == BuilderFieldKind.url
                    ? validatePortfolioUrl(raw)
                    : null);
            return builderValidationMessage(
                  context,
                  issue,
                  maxLength: field.maxLength,
                ) ??
                field.validate?.call(context, raw);
          },
        ),
        if (helperKey != null || limit != null) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            helperKey != null
                ? context.strings.tr(helperKey)
                : context.strings.tr('mobileParity.limit', {'limit': limit!}),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: context.colors.textMeta),
          ),
        ],
      ],
    );
  }

  Widget _technologiesSection() {
    final technologies = _technologies(_controllers!['technologies']!.text);
    return StackCardCard(
      outlined: true,
      padding: const EdgeInsets.all(StackCardSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.strings.tr('builderForm.technologies'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StackCardSpacing.md),
          if (technologies.isEmpty)
            Text(
              context.strings.tr('mobileParity.technologiesEmpty'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.textSecondary),
            )
          else
            Wrap(
              spacing: StackCardSpacing.sm,
              runSpacing: StackCardSpacing.sm,
              children: [
                for (final technology in technologies)
                  StackCardTechnologyBadge(label: technology),
              ],
            ),
          const SizedBox(height: StackCardSpacing.md),
          if (_editingTechnologies) ...[
            _field('technologies'),
            const SizedBox(height: StackCardSpacing.sm),
          ],
          StackCardButton(
            key: const ValueKey('project.technologies.edit'),
            label: context.strings.tr('builderIntegration.edit'),
            role: StackCardButtonRole.quiet,
            onPressed: () => setState(() => _editingTechnologies = true),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteProject(
    PortfolioProject project,
    PortfolioDraftRepository repository,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.strings.tr('workspace.deleteProjectTitle')),
        content: Text(context.strings.tr('workspace.deleteProjectHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.tr('builder.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.tr('workspace.delete')),
          ),
        ],
      ),
    );
    if (accepted != true ||
        !mounted ||
        !identical(repository, ref.read(portfolioDraftRepositoryProvider))) {
      return;
    }
    final removed = await ref
        .read(portfolioDraftControllerProvider.notifier)
        .deleteProject(project, expectedRepository: repository);
    if (removed &&
        mounted &&
        identical(repository, ref.read(portfolioDraftRepositoryProvider))) {
      _leave();
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
    final ready =
        state.canEdit &&
        content != null &&
        found &&
        !_mediaBusy &&
        !ownerChanged &&
        !state.saving;
    return PopScope<Object?>(
      canPop: _allowPop || (!_dirty && !state.saving && !_mediaBusy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            context.strings.tr(
              widget.projectId == null
                  ? 'builderForm.newProjectTitle'
                  : 'builderForm.editProjectTitle',
            ),
          ),
          leading: IconButton(
            tooltip: context.strings.tr('builderForm.cancel'),
            icon: const StackCardIcon(name: 'arrow-left', size: 24),
            onPressed: !state.saving ? _close : null,
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StackCardSize.contentMaxWidth,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(StackCardSpacing.cardPadding),
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
                        message: context.strings.tr(
                          'builderForm.projectMissingHint',
                        ),
                      );
                    }
                    _initialize(project);
                    return Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_stale || _saveFailed) ...[
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                context.strings.tr(
                                  _stale
                                      ? 'githubSync.editorStale'
                                      : 'mobileParity.projectSaveError',
                                ),
                                key: ValueKey(
                                  _stale
                                      ? 'builder_project_stale'
                                      : 'project.save.error',
                                ),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: context.colors.error),
                              ),
                            ),
                            const SizedBox(height: StackCardSpacing.lg),
                          ],
                          if (project?.source ==
                              PortfolioProjectSource.github) ...[
                            Text(context.strings.tr('githubSync.editorNote')),
                            const SizedBox(height: StackCardSpacing.lg),
                          ],
                          _field('title', limit: 120),
                          const SizedBox(height: StackCardSpacing.lg),
                          _field('description', limit: 4000),
                          const SizedBox(height: StackCardSpacing.lg),
                          _field('contribution', limit: 4000),
                          const SizedBox(height: StackCardSpacing.lg),
                          _technologiesSection(),
                          const SizedBox(height: StackCardSpacing.lg),
                          StackCardCard(
                            outlined: true,
                            padding: const EdgeInsets.all(StackCardSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PortfolioMediaEditor(
                                  key: _mediaKey,
                                  titleKey: 'mobileParity.cover',
                                  maxImages: portfolioProjectImageLimit,
                                  paths: _imagePaths,
                                  enabled: !state.saving && !ownerChanged,
                                  emptyState: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        context.strings.tr(
                                          'mobileParity.noCover',
                                        ),
                                        key: const ValueKey(
                                          'project.cover.empty',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      const SizedBox(
                                        height: StackCardSpacing.md,
                                      ),
                                      Text(
                                        context.strings.tr(
                                          'mobileParity.coverHint',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),
                                  onChanged: (paths) =>
                                      setState(() => _imagePaths = paths),
                                  onBusyChanged: (busy) =>
                                      setState(() => _mediaBusy = busy),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: StackCardSpacing.lg),
                          _field(
                            'repositoryUrl',
                            helperKey: 'mobileParity.repositoryHint',
                          ),
                          const SizedBox(height: StackCardSpacing.lg),
                          _field('liveUrl', helperKey: 'mobileParity.demoHint'),
                          const SizedBox(height: StackCardSpacing.lg),
                          Text(
                            context.strings.tr(
                              'mobileParity.projectLibraryHint',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: context.colors.textSecondary),
                          ),
                          const SizedBox(height: StackCardSpacing.xl),
                          Text(
                            context.strings.tr('mobileParity.preview'),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: StackCardSpacing.md),
                          ProjectLibraryCard(
                            key: const ValueKey('project.editor.preview'),
                            title: _controllers!['title']!.text.isEmpty
                                ? context.strings.tr(
                                    'mobileParity.projectNameEmpty',
                                  )
                                : _controllers!['title']!.text,
                            description: _controllers!['description']!.text,
                            technologies: _technologies(
                              _controllers!['technologies']!.text,
                            ),
                            sourceLabel:
                                project?.source == PortfolioProjectSource.github
                                ? 'GitHub'
                                : context.strings.tr('filter.manual'),
                            imagePaths: _imagePaths,
                            showActions: false,
                          ),
                          if (project != null) ...[
                            const SizedBox(height: StackCardSpacing.lg),
                            StackCardButton(
                              label: context.strings.tr('workspace.delete'),
                              role: StackCardButtonRole.danger,
                              onPressed: !state.saving
                                  ? () => _deleteProject(project, repository)
                                  : null,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: ColoredBox(
          color: context.colors.surface,
          child: SafeArea(
            top: false,
            child: Align(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: StackCardSize.contentMaxWidth,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    StackCardSpacing.cardPadding,
                    StackCardSpacing.lg,
                    StackCardSpacing.cardPadding,
                    StackCardSpacing.lg +
                        MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_controllers != null) ...[
                        Text(
                          context.strings.tr(
                            state.saving
                                ? 'builder.saving'
                                : _dirty
                                ? 'mobileParity.unsaved'
                                : 'mobileParity.saved',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.colors.textMeta),
                        ),
                        const SizedBox(height: StackCardSpacing.sm),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: StackCardButton(
                              key: const ValueKey('builder_form_cancel'),
                              label: context.strings.tr('builderForm.cancel'),
                              onPressed: !state.saving ? _close : null,
                            ),
                          ),
                          const SizedBox(width: StackCardSpacing.sm),
                          Expanded(
                            child: StackCardButton(
                              key: const ValueKey('builder_form_apply'),
                              label: context.strings.tr('mobileParity.save'),
                              primary: true,
                              loading: state.saving,
                              onPressed: ready ? _apply : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
