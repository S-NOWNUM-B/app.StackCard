import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_dialog_actions.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../projects/projects.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_validation.dart';
import '../portfolio_draft_providers.dart';
import 'builder_editor_widgets.dart';
import 'builder_tag_editor.dart';
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
  String _iconId = 'folder';
  String _baselineIconId = 'folder';
  Map<String, String>? _baselineValues;
  List<String> _technologies = [];
  List<String> _baselineTechnologies = [];
  bool _allowPop = false;
  bool _confirmingExit = false;
  bool _saveFailed = false;

  bool get _dirty =>
      _controllers != null &&
      (!mapEquals(_baselineValues, builderFieldValues(_controllers!)) ||
          _baselineIconId != _iconId ||
          !listEquals(_baselineTechnologies, _technologies));

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
      _iconId = 'folder';
      _baselineIconId = 'folder';
      _baselineValues = null;
      _technologies = [];
      _baselineTechnologies = [];
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
    _iconId = project?.iconId ?? 'folder';
    _baselineIconId = _iconId;
    _technologies = List.of(project?.technologies ?? const <String>[]);
    _baselineTechnologies = List.of(_technologies);
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
    for (final controller in _controllers!.values) {
      controller.addListener(_inputChanged);
    }
  }

  Future<void> _apply() async {
    if (ref.read(portfolioDraftControllerProvider).saving) return;
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
    final technologies = List<String>.of(_technologies);
    final controller = ref.read(portfolioDraftControllerProvider.notifier);
    final edited = PortfolioProject(
      id: widget.projectId ?? _initialProject?.id ?? controller.createId(),
      title: values['title']!,
      description: values['description']!,
      contribution: values['contribution']!,
      technologies: technologies,
      repositoryUrl: values['repositoryUrl']!,
      liveUrl: values['liveUrl']!,
      featured: _featured,
      visible: _visible,
      imagePaths: existingProject?.imagePaths ?? const [],
      iconId: _iconId,
      updatedAt: DateTime.now().toUtc(),
    );
    final project = existingProject?.withUserEdits(edited) ?? edited;
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
    _baselineIconId = project.iconId;
    _baselineTechnologies = technologies;
    // Ввод после нажатия Save остаётся в форме, даже если старый snapshot сохранён.
    if (!mapEquals(values, builderFieldValues(_controllers!)) ||
        project.iconId != _iconId ||
        !listEquals(technologies, _technologies)) {
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
          ],
        ),
        actions: [
          StackCardDialogActions(
            cancelKey: const ValueKey('project.leave.stay'),
            confirmKey: const ValueKey('project.leave.discard'),
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (discard == true && mounted) _leave();
  }

  Widget _field(String name) {
    final field = _fields!.firstWhere((item) => item.name == name);
    final multiline = field.kind == BuilderFieldKind.multiline;
    return StackCardInput(
      key: ValueKey('builder_form_$name'),
      label: context.strings.tr(field.labelKey),
      controller: _controllers![name],
      hint: field.hintKey == null ? null : context.strings.tr(field.hintKey!),
      keyboardType: field.kind == BuilderFieldKind.url
          ? TextInputType.url
          : multiline
          ? TextInputType.multiline
          : TextInputType.text,
      minLines: multiline ? 3 : null,
      maxLines: multiline ? 8 : 1,
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
    );
  }

  Widget _technologiesSection() => BuilderTagsEditor(
    key: const ValueKey('project.technologies.editor'),
    sliver: true,
    title: context.strings.tr('builderForm.technologies'),
    items: _technologies,
    keyPrefix: 'project.technology',
    addLabel: context.strings.tr('mobileParity.addTechnology'),
    removeLabel: (name) =>
        context.strings.tr('mobileParity.removeTechnology', {'name': name}),
    enabled: !ref.watch(portfolioDraftControllerProvider).saving,
    onAdd: _addTechnology,
    onReorder: _reorderTechnology,
    onRemove: (index) => setState(() {
      _technologies = [..._technologies]..removeAt(index);
      _saveFailed = false;
    }),
  );

  Widget _scrollableGateState(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.all(StackCardSpacing.lg),
    child: child,
  );

  void _reorderTechnology(int oldIndex, int newIndex) {
    final state = ref.read(portfolioDraftControllerProvider);
    if (!state.canEdit ||
        state.saving ||
        _confirmingExit ||
        !identical(
          _initialRepository,
          ref.read(portfolioDraftRepositoryProvider),
        ) ||
        oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= _technologies.length ||
        newIndex < 0 ||
        newIndex >= _technologies.length) {
      return;
    }
    setState(() {
      final technologies = List<String>.of(_technologies);
      technologies.insert(newIndex, technologies.removeAt(oldIndex));
      _technologies = technologies;
      _saveFailed = false;
    });
  }

  Future<void> _addTechnology() async {
    final repository = _initialRepository;
    final controllers = _controllers;
    FocusManager.instance.primaryFocus?.unfocus();
    final existing = List.of(_technologies);
    final technology = await showDialog<String>(
      context: context,
      builder: (_) => BuilderTagDialog(
        title: context.strings.tr('mobileParity.technology'),
        keyPrefix: 'project.technology',
        validate: (context, name) {
          final issue = validatePortfolioText(
            name,
            required: true,
            maxLength: 60,
          );
          if (issue != null) {
            return builderValidationMessage(context, issue, maxLength: 60);
          }
          if (name.contains(',')) {
            return context.strings.tr('mobileParity.singleTechnology');
          }
          if (existing.any(
            (item) => item.trim().toLowerCase() == name.toLowerCase(),
          )) {
            return context.strings.tr('mobileParity.technologyDuplicate');
          }
          if (existing.length >= 20) {
            return context.strings.tr('builderForm.tooManyTechnologies', {
              'limit': 20,
            });
          }
          return null;
        },
      ),
    );
    if (!mounted ||
        technology == null ||
        !identical(controllers, _controllers) ||
        !identical(repository, ref.read(portfolioDraftRepositoryProvider)) ||
        ref.read(portfolioDraftControllerProvider).saving) {
      return;
    }
    setState(() {
      _technologies = [..._technologies, technology];
      _saveFailed = false;
    });
  }

  Future<void> _selectIcon() async {
    final repository = _initialRepository;
    final controllers = _controllers;
    final selected = await showProjectIconPicker(
      context,
      selectedIconId: _iconId,
    );
    if (!mounted ||
        selected == null ||
        !identical(controllers, _controllers) ||
        !identical(repository, ref.read(portfolioDraftRepositoryProvider)) ||
        ref.read(portfolioDraftControllerProvider).saving) {
      return;
    }
    setState(() => _iconId = selected);
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
        content: const Text(
          'Проект будет удалён из StackCard и портфолио. Репозиторий GitHub останется. Если проект опубликован, обновите публичную версию портфолио.',
        ),
        actions: [
          StackCardDialogActions(
            onCancel: () => Navigator.pop(context, false),
            onConfirm: () => Navigator.pop(context, true),
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
        !ownerChanged &&
        !state.saving;
    return PopScope<Object?>(
      canPop: _allowPop || (!_dirty && !state.saving),
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
              child: Builder(
                builder: (context) {
                  final gate = BuilderContentGate(
                    data: (content) {
                      if (ownerChanged) {
                        return Text(context.strings.tr('media.ownerChanged'));
                      }
                      final project = _findProject(content);
                      if (widget.projectId != null && project == null) {
                        return StackCardStateView(
                          kind: StackCardViewState.empty,
                          title: context.strings.tr(
                            'builderForm.projectMissing',
                          ),
                          message: context.strings.tr(
                            'builderForm.projectMissingHint',
                          ),
                        );
                      }
                      _initialize(project);
                      return Form(
                        key: _formKey,
                        child: CustomScrollView(
                          key: const Key('project.editor.scroll'),
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.all(
                                StackCardSpacing.lg,
                              ),
                              sliver: SliverMainAxisGroup(
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
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
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: context.colors.error,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: StackCardSpacing.lg,
                                          ),
                                        ],
                                        Center(
                                          child: Semantics(
                                            button: true,
                                            label: 'Иконка проекта',
                                            child: SizedBox.square(
                                              key: const ValueKey(
                                                'project.icon.editor',
                                              ),
                                              dimension: 128,
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: Material(
                                                      color: context
                                                          .colors
                                                          .surfaceElevated,
                                                      shape: CircleBorder(
                                                        side: BorderSide(
                                                          color: context
                                                              .colors
                                                              .borderStrong,
                                                        ),
                                                      ),
                                                      clipBehavior:
                                                          Clip.antiAlias,
                                                      child: InkWell(
                                                        key: const ValueKey(
                                                          'project.icon.edit',
                                                        ),
                                                        onTap: state.saving
                                                            ? null
                                                            : _selectIcon,
                                                        child: Center(
                                                          child:
                                                              ProjectStockIcon(
                                                                iconId: _iconId,
                                                                size: 48,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Material(
                                                      color: context
                                                          .colors
                                                          .primary,
                                                      shape: CircleBorder(
                                                        side: BorderSide(
                                                          color: context
                                                              .colors
                                                              .surface,
                                                          width: 2,
                                                        ),
                                                      ),
                                                      child: IconButton(
                                                        key: const ValueKey(
                                                          'project.icon.select',
                                                        ),
                                                        tooltip:
                                                            'Иконка проекта',
                                                        onPressed: state.saving
                                                            ? null
                                                            : _selectIcon,
                                                        icon: StackCardIcon(
                                                          name: 'pencil',
                                                          size: 22,
                                                          color: context
                                                              .colors
                                                              .onPrimary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                          height: StackCardSpacing.lg,
                                        ),
                                        _field('title'),
                                        const SizedBox(
                                          height: StackCardSpacing.lg,
                                        ),
                                        _field('description'),
                                        const SizedBox(
                                          height: StackCardSpacing.lg,
                                        ),
                                        _field('contribution'),
                                        const SizedBox(
                                          height: StackCardSpacing.lg,
                                        ),
                                      ],
                                    ),
                                  ),
                                  _technologiesSection(),
                                  SliverToBoxAdapter(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const SizedBox(
                                          height: StackCardSpacing.lg,
                                        ),
                                        _field('repositoryUrl'),
                                        const SizedBox(
                                          height: StackCardSpacing.lg,
                                        ),
                                        _field('liveUrl'),
                                        if (project != null) ...[
                                          const SizedBox(
                                            height: StackCardSpacing.lg,
                                          ),
                                          StackCardButton(
                                            label: context.strings.tr(
                                              'workspace.delete',
                                            ),
                                            role: StackCardButtonRole.danger,
                                            onPressed: !state.saving
                                                ? () => _deleteProject(
                                                    project,
                                                    repository,
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                  if (state.loading ||
                      !state.canEdit ||
                      content == null ||
                      ownerChanged ||
                      !found) {
                    return _scrollableGateState(gate);
                  }
                  return gate;
                },
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
                    StackCardSpacing.lg,
                    StackCardSpacing.lg,
                    StackCardSpacing.lg,
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
