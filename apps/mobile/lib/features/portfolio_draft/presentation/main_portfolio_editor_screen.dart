import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_dialog_actions.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../auth/auth.dart';
import '../../media/media.dart';
import '../../projects/projects.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_validation.dart';
import '../portfolio_draft_providers.dart';
import 'builder_editor_widgets.dart';
import 'builder_tag_editor.dart';
import 'portfolio_draft_controller.dart';
import 'portfolio_contact_visual.dart';

/// Shell спрашивает редактор перед сменой вкладки, включая Save его local buffer.
final mainPortfolioEditorNavigationProvider =
    NotifierProvider<MainPortfolioEditorNavigation, Future<bool> Function()?>(
      MainPortfolioEditorNavigation.new,
    );

class MainPortfolioEditorNavigation extends Notifier<Future<bool> Function()?> {
  @override
  Future<bool> Function()? build() => null;

  void attach(Future<bool> Function() callback) {
    if (ref.mounted) state = callback;
  }

  void detach(Future<bool> Function() callback) {
    if (ref.mounted && identical(state, callback)) state = null;
  }
}

/// Одна вертикальная форма; Save пишет только основное портфолио и его иконки.
class MainPortfolioEditorScreen extends ConsumerWidget {
  const MainPortfolioEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final account = ref.watch(accountAuthRepositoryProvider);
    final session = account == null ? null : ref.watch(accountSessionProvider);
    final ready =
        session == null ||
        (session.hasValue && !session.isLoading && !session.hasError);
    final guest = account == null || ref.watch(guestAccessProvider);
    // StatefulShellRoute сохраняет ветку даже при смене MaterialApp.key.
    // Новый owner получает новый State; старый private buffer уничтожается.
    return _MainPortfolioEditorBody(
      key: ValueKey((repository, account, session?.value?.uid, guest, ready)),
    );
  }
}

class _MainPortfolioEditorBody extends ConsumerStatefulWidget {
  const _MainPortfolioEditorBody({super.key});

  @override
  ConsumerState<_MainPortfolioEditorBody> createState() =>
      _MainPortfolioEditorScreenState();
}

class _MainPortfolioEditorScreenState
    extends ConsumerState<_MainPortfolioEditorBody> {
  final _formKey = GlobalKey<FormState>();
  final _mediaKey = GlobalKey<PortfolioMediaEditorState>();
  PortfolioDraftRepository? _repository;
  PortfolioDocument? _expected;
  PortfolioContent? _buffer;
  Map<String, TextEditingController>? _fields;
  List<PortfolioProjectAttachment> _projects = [];
  final _iconUpdates = <String, String>{};
  (Object?, String?, bool, bool)? _initialOwner;
  var _dirty = false;
  var _saving = false;
  var _mediaBusy = false;
  var _saveError = false;
  var _saved = false;
  var _ownerInvalid = false;
  var _allowPop = false;
  var _exitDialog = false;
  var _generation = 0;
  var _initializing = false;
  late final _navigationGuard = _canLeave;
  MainPortfolioEditorNavigation? _navigation;

  @override
  void initState() {
    super.initState();
    _navigation = ref.read(mainPortfolioEditorNavigationProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigation!.attach(_navigationGuard);
    });
  }

  @override
  void dispose() {
    final navigation = _navigation;
    final guard = _navigationGuard;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => navigation?.detach(guard),
    );
    disposeBuilderFieldControllers(_fields);
    super.dispose();
  }

  (Object?, String?, bool, bool) _owner({bool watch = false}) {
    final account = watch
        ? ref.watch(accountAuthRepositoryProvider)
        : ref.read(accountAuthRepositoryProvider);
    if (account == null) return (null, null, true, true);
    final session = watch
        ? ref.watch(accountSessionProvider)
        : ref.read(accountSessionProvider);
    final guest = watch
        ? ref.watch(guestAccessProvider)
        : ref.read(guestAccessProvider);
    final ready = session.hasValue && !session.isLoading && !session.hasError;
    return (account, ready ? session.value?.uid : null, ready && guest, ready);
  }

  bool get _sameOwner =>
      mounted &&
      !_ownerInvalid &&
      _initialOwner == _owner() &&
      identical(_repository, ref.read(portfolioDraftRepositoryProvider));
  bool get _busy => _saving || _mediaBusy;

  void _initialize(PortfolioContent workspace, PortfolioDocument document) {
    _repository = ref.read(portfolioDraftRepositoryProvider);
    _initialOwner = _owner();
    final saved =
        ref.read(portfolioDraftControllerProvider).draft?.content ?? workspace;
    _expected = mainPortfolioDocument(saved);
    _buffer = document.content;
    _projects = [...document.projects];
    final profile = document.content.profile;
    _fields = {
      'name': TextEditingController(text: profile.name),
      'headline': TextEditingController(text: profile.headline),
      'bio': TextEditingController(text: profile.bio),
      'locationText': TextEditingController(text: profile.locationText),
      'legacyText': TextEditingController(text: document.content.resumeText),
    };
    for (final field in _fields!.values) {
      field.addListener(_changed);
    }
  }

  void _invalidateOwner() {
    _ownerInvalid = true;
    _buffer = null;
    _expected = null;
    _projects = [];
    _iconUpdates.clear();
    for (final field in _fields?.values ?? <TextEditingController>[]) {
      field.removeListener(_changed);
      field.clear();
    }
    _dirty = false;
  }

  PortfolioDocument _document() {
    final profile = _buffer!.profile;
    return _expected!.copyWith(
      content: _buffer!.copyWith(
        resumeText: _fields!['legacyText']!.text,
        profile: profile.copyWith(
          name: _fields!['name']!.text.trim(),
          headline: _fields!['headline']!.text.trim(),
          bio: _fields!['bio']!.text.trim(),
          locationText: _fields!['locationText']!.text.trim(),
          publishLocation: true,
        ),
      ),
      projects: _projects,
      updatedAt: DateTime.now().toUtc(),
      clearAttachedResumeId: true,
    );
  }

  void _changed() {
    if (!mounted || !_sameOwner) return;
    setState(() {
      _dirty = true;
      _saved = false;
      _saveError = false;
      _generation++;
    });
    // Общий working buffer делает несохранённый ввод видимым guard выхода/UID.
    final state = ref.read(portfolioDraftControllerProvider);
    final workspace = state.content;
    if (workspace == null || _expected == null) return;
    final document = _document();
    ref
        .read(portfolioDraftControllerProvider.notifier)
        .updateContent(
          workspace.copyWith(
            documents: [
              for (final item in workspace.documents)
                item.id == document.id ? document : item,
            ],
          ),
        );
  }

  bool get _conflict {
    final state = ref.read(portfolioDraftControllerProvider);
    return state.remoteUpdateAvailable ||
        mainPortfolioDocument(state.draft?.content ?? PortfolioContent()) !=
            _expected;
  }

  Future<bool> _save() async {
    if (!_sameOwner ||
        _busy ||
        _conflict ||
        _formKey.currentState?.validate() != true) {
      return false;
    }
    final document = _document();
    final generation = _generation;
    final icons = Map<String, String>.of(_iconUpdates);
    setState(() {
      _saving = true;
      _saveError = false;
      _saved = false;
    });
    final success = await ref
        .read(portfolioDraftControllerProvider.notifier)
        .saveMainPortfolio(
          document,
          expectedDocument: _expected,
          projectIconUpdates: icons,
          expectedRepository: _repository!,
        );
    if (!mounted || !_sameOwner) return false;
    if (success) {
      _mediaKey.currentState?.retainUploads(
        paths: [
          if (document.content.profile.avatarPath.isNotEmpty)
            document.content.profile.avatarPath,
        ],
      );
    }
    setState(() {
      _saving = false;
      _saveError = !success;
      if (success) {
        _expected = document;
        _dirty = generation != _generation;
        _saved = !_dirty;
        for (final entry in icons.entries) {
          if (_iconUpdates[entry.key] == entry.value) {
            _iconUpdates.remove(entry.key);
          }
        }
      }
    });
    if (success && _dirty) _changed();
    return success && !_dirty;
  }

  Future<void> _reload() async {
    if (_busy || !_sameOwner) return;
    final discard =
        !_dirty ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Открыть сохранённую версию?'),
                content: const Text('Несохранённые изменения будут отменены.'),
                actions: [
                  StackCardDialogActions(
                    onCancel: () => Navigator.pop(context, false),
                    onConfirm: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ) ==
            true;
    if (!mounted || !_sameOwner || !discard) return;
    await ref.read(portfolioDraftControllerProvider.notifier).reload();
    if (!mounted || !_sameOwner) return;
    final workspace = ref.read(portfolioDraftControllerProvider).content;
    final document = workspace == null
        ? null
        : mainPortfolioDocument(workspace);
    if (document == null) return;
    setState(() {
      disposeBuilderFieldControllers(_fields);
      _initialize(workspace!, document);
      _iconUpdates.clear();
      _dirty = false;
      _saveError = false;
      _saved = false;
    });
  }

  Future<bool> _canLeave() async {
    if (_busy || _exitDialog) return false;
    var leave = !_dirty || !_sameOwner;
    if (!leave) {
      _exitDialog = true;
      final action = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Сохранить изменения?'),
          content: const Text('Без сохранения изменения будут потеряны.'),
          actions: [
            // Закрытие окна без выбора оставляет пользователя в редакторе.
            StackCardDialogActions(
              cancelKey: const Key('main.editor.leave.discard'),
              confirmKey: const Key('main.editor.leave.save'),
              cancelLabel: 'Не сохранять',
              confirmLabel: context.strings.tr('common.save'),
              onCancel: () => Navigator.pop(context, 'discard'),
              onConfirm: () => Navigator.pop(context, 'save'),
            ),
          ],
        ),
      );
      _exitDialog = false;
      if (!mounted) return false;
      if (action == 'discard') {
        if (_sameOwner) {
          await ref.read(portfolioDraftControllerProvider.notifier).reload();
          if (!mounted || !_sameOwner) return true;
          final state = ref.read(portfolioDraftControllerProvider);
          final workspace = state.content;
          final document = workspace == null
              ? null
              : mainPortfolioDocument(workspace);
          if (!state.canEdit || document == null) return false;
          setState(() {
            disposeBuilderFieldControllers(_fields);
            _initialize(workspace!, document);
            _iconUpdates.clear();
            _dirty = false;
            _saveError = false;
            _saved = false;
          });
        }
        leave = true;
      } else if (action == 'save') {
        leave = await _save();
      }
    }
    return mounted && leave;
  }

  Future<void> _requestExit() async {
    if (!await _canLeave() || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    });
  }

  Future<void> _addProjects() async {
    if (!_sameOwner || _busy) return;
    final workspace = ref.read(portfolioDraftControllerProvider).draft?.content;
    final library = workspace?.projects ?? const <PortfolioProject>[];
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(
        maxWidth: StackCardSize.contentMaxWidth,
      ),
      builder: (_) => _ProjectSelection(
        library: library,
        selectedIds: _projects.map((item) => item.projectId).toSet(),
        isCurrent: () => _sameOwner,
      ),
    );
    if (!mounted || !_sameOwner || selected == null) return;
    setState(() {
      _projects = [
        ..._projects.where((item) => selected.contains(item.projectId)),
        for (final project in library)
          if (selected.contains(project.id) &&
              !_projects.any((item) => item.projectId == project.id))
            PortfolioProjectAttachment(projectId: project.id),
      ];
    });
    _changed();
  }

  Future<void> _chooseIcon(PortfolioProject project) async {
    final icon = await showProjectIconPicker(
      context,
      selectedIconId: _iconUpdates[project.id] ?? project.iconId,
    );
    if (!mounted || !_sameOwner || icon == null) return;
    setState(() => _iconUpdates[project.id] = icon);
    _changed();
  }

  void _reorderProject(int oldIndex, int newIndex) {
    if (!_sameOwner || _busy || oldIndex == newIndex) return;
    setState(() {
      final entry = _projects.removeAt(oldIndex);
      _projects.insert(newIndex, entry);
    });
    _changed();
  }

  Future<void> _addSkill() async {
    final fields = _fields;
    final existing = _buffer!.skills.map((item) => item.name).toList();
    FocusManager.instance.primaryFocus?.unfocus();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => BuilderTagDialog(
        title: 'Навык',
        keyPrefix: 'main.editor.skill',
        suggestTechnologies: true,
        existing: existing,
        validate: (context, name) {
          final issue = validatePortfolioText(
            name,
            required: true,
            maxLength: 60,
          );
          if (issue != null) {
            return builderValidationMessage(context, issue, maxLength: 60);
          }
          if (existing.any(
            (item) => item.trim().toLowerCase() == name.toLowerCase(),
          )) {
            return 'Этот навык уже добавлен';
          }
          return null;
        },
      ),
    );
    if (!mounted ||
        !_sameOwner ||
        name == null ||
        !identical(fields, _fields) ||
        _busy) {
      return;
    }
    setState(
      () => _buffer = _buffer!.copyWith(
        skills: [
          ..._buffer!.skills,
          Skill(id: _createId(), name: name),
        ],
      ),
    );
    _changed();
  }

  Future<void> _editExperience([Experience? item]) async {
    final values = await showBuilderRecordEditor(
      context,
      titleKey: 'builderForm.experienceTitle',
      fields: [
        BuilderFieldSpec(
          name: 'role',
          labelKey: 'builderForm.role',
          value: item?.role ?? '',
          maxLength: 120,
          required: true,
        ),
        BuilderFieldSpec(
          name: 'organization',
          labelKey: 'builderForm.organization',
          value: item?.organization ?? '',
          maxLength: 160,
          required: true,
        ),
        BuilderFieldSpec(
          name: 'period',
          labelKey: 'builderForm.period',
          value: item?.period ?? '',
          maxLength: 120,
        ),
        BuilderFieldSpec(
          name: 'description',
          labelKey: 'builderForm.description',
          value: item?.description ?? '',
          maxLength: 4000,
          kind: BuilderFieldKind.multiline,
        ),
      ],
    );
    if (!mounted || !_sameOwner || values == null) return;
    final next = Experience(
      id: item?.id ?? _createId(),
      role: values['role']!.trim(),
      organization: values['organization']!.trim(),
      period: values['period']!.trim(),
      description: values['description']!.trim(),
    );
    setState(
      () => _buffer = _buffer!.copyWith(
        experience: [
          for (final previous in _buffer!.experience)
            previous.id == next.id ? next : previous,
          if (item == null) next,
        ],
      ),
    );
    _changed();
  }

  Future<void> _editEducation([Education? item]) async {
    final values = await showBuilderRecordEditor(
      context,
      titleKey: 'builderForm.educationTitle',
      fields: [
        BuilderFieldSpec(
          name: 'institution',
          labelKey: 'builderForm.institution',
          value: item?.institution ?? '',
          maxLength: 160,
          required: true,
        ),
        BuilderFieldSpec(
          name: 'qualification',
          labelKey: 'builderForm.qualification',
          value: item?.qualification ?? '',
          maxLength: 160,
          required: true,
        ),
        BuilderFieldSpec(
          name: 'period',
          labelKey: 'builderForm.period',
          value: item?.period ?? '',
          maxLength: 120,
        ),
        BuilderFieldSpec(
          name: 'description',
          labelKey: 'builderForm.description',
          value: item?.description ?? '',
          maxLength: 4000,
          kind: BuilderFieldKind.multiline,
        ),
      ],
    );
    if (!mounted || !_sameOwner || values == null) return;
    final next = Education(
      id: item?.id ?? _createId(),
      institution: values['institution']!.trim(),
      qualification: values['qualification']!.trim(),
      period: values['period']!.trim(),
      description: values['description']!.trim(),
    );
    setState(
      () => _buffer = _buffer!.copyWith(
        education: [
          for (final previous in _buffer!.education)
            previous.id == next.id ? next : previous,
          if (item == null) next,
        ],
      ),
    );
    _changed();
  }

  Future<void> _editLink([SocialLink? item]) async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) =>
          _MainContactDialog(item: item, isCurrent: () => _sameOwner),
    );
    if (!mounted || !_sameOwner || values == null) return;
    final kind = SocialLinkKind.values.byName(values['kind']!);
    final url = values['url']!;
    final next = SocialLink(
      id: item?.id ?? _createId(),
      label: values['label']!.trim(),
      url: url,
      kind: kind,
      publishAllowed: true,
      visible: true,
    );
    setState(
      () => _buffer = _buffer!.copyWith(
        links: [
          for (final previous in _buffer!.links)
            previous.id == next.id ? next : previous,
          if (item == null) next,
        ],
      ),
    );
    _changed();
  }

  String _createId() =>
      ref.read(portfolioDraftControllerProvider.notifier).createId();

  void _initializeEmpty(PortfolioContent workspace) {
    if (_initializing ||
        _ownerInvalid ||
        workspace.documents.isNotEmpty ||
        workspace.profile != const PortfolioProfile() ||
        workspace.skills.isNotEmpty ||
        workspace.experience.isNotEmpty ||
        workspace.education.isNotEmpty ||
        workspace.links.isNotEmpty ||
        workspace.resumeText.isNotEmpty) {
      return;
    }
    _initializing = true;
    final repository = ref.read(portfolioDraftRepositoryProvider);
    final owner = _owner();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          _ownerInvalid ||
          owner != _owner() ||
          !identical(repository, ref.read(portfolioDraftRepositoryProvider))) {
        return;
      }
      final success = await ref
          .read(portfolioDraftControllerProvider.notifier)
          .initializeMainPortfolio(
            expectedWorkspace: workspace,
            expectedRepository: repository,
          );
      if (mounted && owner == _owner()) {
        setState(() {
          _initializing = false;
          _saveError = !success;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(portfolioDraftControllerProvider);
    final owner = _owner(watch: true);
    if (_initialOwner != null && owner != _initialOwner && !_ownerInvalid) {
      _invalidateOwner();
    }
    ref.listen(portfolioDraftRepositoryProvider, (previous, next) {
      if (_repository != null &&
          !identical(_repository, next) &&
          !_ownerInvalid) {
        setState(_invalidateOwner);
      }
    });
    final workspace = state.content;
    final main = workspace == null ? null : mainPortfolioDocument(workspace);
    if (state.canEdit && main == null && !_initializing && !_saveError) {
      _initializeEmpty(workspace ?? PortfolioContent());
    }
    if (_fields == null && main != null && !_ownerInvalid) {
      _initialize(workspace!, main);
    }
    Widget body;
    if (_ownerInvalid || state.loading || _initializing) {
      body = _scrollableStatus(
        const StackCardStateView(
          kind: StackCardViewState.loading,
          title: 'Загрузка',
        ),
      );
    } else if (!state.canEdit) {
      body = _scrollableStatus(
        StackCardStateView(
          kind: StackCardViewState.error,
          title: 'Не удалось открыть портфолио',
          onRetry: ref.read(portfolioDraftControllerProvider.notifier).load,
        ),
      );
    } else if (main == null || _fields == null || _buffer == null) {
      body = _scrollableStatus(
        Padding(
          padding: const EdgeInsets.all(StackCardSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Выберите содержимое основного портфолио',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: StackCardSpacing.lg),
              StackCardButton(
                key: const Key('main.editor.migrate'),
                label: 'Продолжить',
                primary: true,
                onPressed: () => context.go('/portfolio/migrate'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = Form(
        key: _formKey,
        // Порядок разделов фиксирован; записи переставляются внутри раздела.
        child: ListView(
          key: const Key('main.editor.scroll'),
          padding: const EdgeInsets.all(StackCardSpacing.lg),
          scrollCacheExtent: const ScrollCacheExtent.viewport(3),
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_dirty || _saved) ...[
                  Text(
                    _dirty
                        ? 'Есть несохранённые изменения'
                        : 'Изменения сохранены',
                    key: const Key('main.editor.status'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                if (_conflict) ...[
                  Text(
                    'Сохранённая версия изменилась. Ваш ввод сохранён в редакторе.',
                    style: TextStyle(color: context.colors.error),
                  ),
                  StackCardButton(
                    label: 'Открыть сохранённую версию',
                    onPressed: _reload,
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                if (_saveError) ...[
                  Text(
                    'Не удалось сохранить. Повторите попытку.',
                    key: const Key('main.editor.error'),
                    style: TextStyle(color: context.colors.error),
                  ),
                  const SizedBox(height: StackCardSpacing.lg),
                ],
                PortfolioMediaEditor(
                  key: _mediaKey,
                  maxImages: 1,
                  titleKey: 'media.avatar',
                  paths: [
                    if (_buffer!.profile.avatarPath.isNotEmpty)
                      _buffer!.profile.avatarPath,
                  ],
                  enabled: !_saving,
                  hasExternalAvatar: _buffer!.profile.avatarUrl.isNotEmpty,
                  emptyState: _buffer!.profile.avatarUrl.isEmpty
                      ? null
                      : StackCardAvatar(
                          size: 128,
                          url: _buffer!.profile.avatarUrl,
                        ),
                  onBusyChanged: (value) {
                    if (mounted) setState(() => _mediaBusy = value);
                  },
                  onChanged: (paths) {
                    if (!_sameOwner) return;
                    setState(
                      () => _buffer = _buffer!.copyWith(
                        profile: _buffer!.profile.copyWith(
                          avatarPath: paths.firstOrNull ?? '',
                          avatarUrl: '',
                        ),
                      ),
                    );
                    _changed();
                  },
                ),
                const SizedBox(height: StackCardSpacing.lg),
                _field('name', 'Имя', 100),
                _field('headline', 'Должность', 160),
                _field('locationText', 'Город / Страна', 200),
                _field('bio', 'О себе', 4000, multiline: true),
              ],
            ),
            for (
              var index = 0;
              index < mainPortfolioSectionKinds.length;
              index++
            )
              _editorSection(workspace!, index),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_buffer!.resumeText.isNotEmpty) ...[
                  _title('Дополнительно'),
                  _field(
                    'legacyText',
                    'Дополнительный текст',
                    20000,
                    multiline: true,
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return PopScope(
      canPop: _allowPop || !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        // Название раздела уже отображает AppShell над этой вкладкой.
        // Второй AppBar лишал короткий экран места для доступного target48.
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StackCardSize.contentMaxWidth,
              ),
              child: body,
            ),
          ),
        ),
        bottomNavigationBar: main == null || _ownerInvalid
            ? null
            : SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    StackCardSpacing.lg,
                    StackCardSpacing.sm,
                    StackCardSpacing.lg,
                    StackCardSpacing.sm +
                        MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: StackCardButton(
                    key: const Key('main.editor.save'),
                    label: _saving ? 'Сохранение…' : 'Сохранить',
                    primary: true,
                    onPressed: _busy || _conflict ? null : _save,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _scrollableStatus(Widget child) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      key: const Key('main.editor.statusScroll'),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(child: child),
      ),
    ),
  );

  Widget _title(String value, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(
      top: StackCardSpacing.xl,
      bottom: StackCardSpacing.lg,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(value, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?action,
      ],
    ),
  );

  Widget _field(
    String name,
    String label,
    int maxLength, {
    bool multiline = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: StackCardSpacing.lg),
    child: StackCardInput(
      key: ValueKey('main.editor.$name'),
      controller: _fields![name],
      label: label,
      enabled: !_saving,
      minLines: multiline ? 3 : null,
      maxLines: multiline ? 8 : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      validator: (value) => builderValidationMessage(
        context,
        validatePortfolioText(value ?? '', maxLength: maxLength),
        maxLength: maxLength,
      ),
    ),
  );

  Widget _record(
    String id,
    int index,
    String title,
    String summary, {
    required VoidCallback onEdit,
    required VoidCallback onRemove,
  }) => Padding(
    key: ValueKey('main.record.$id'),
    padding: const EdgeInsets.only(bottom: StackCardSpacing.sm),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(StackCardRadius.small),
      ),
      child: Row(
        children: [
          _itemHandle('main.record.drag.$id', index, title),
          Expanded(
            child: InkWell(
              key: ValueKey('main.record.edit.$id'),
              onTap: _busy ? null : onEdit,
              borderRadius: BorderRadius.circular(StackCardRadius.small),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: StackCardSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (summary.isNotEmpty)
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: context.colors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            key: ValueKey('main.record.remove.$id'),
            tooltip: 'Удалить $title',
            onPressed: _busy ? null : onRemove,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    ),
  );

  /// Точки перетаскивания элемента; работают только внутри ближайшего списка.
  Widget _itemHandle(String key, int index, String label) => Semantics(
    label: 'Изменить порядок $label',
    hint: 'Удерживайте точки и перетащите',
    child: ReorderableDelayedDragStartListener(
      key: ValueKey(key),
      index: index,
      enabled: !_busy && _sameOwner,
      child: const SizedBox(
        width: StackCardSize.touchTarget,
        height: StackCardSize.touchTarget,
        child: ColoredBox(
          color: Colors.transparent,
          child: Center(child: StackCardIcon(name: 'grip-vertical', size: 20)),
        ),
      ),
    ),
  );

  void _reorderItems<T>(
    List<T> items,
    int oldIndex,
    int newIndex,
    PortfolioContent Function(List<T>) apply,
  ) {
    if (!_sameOwner || _busy || oldIndex == newIndex) return;
    final reordered = [...items];
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    setState(() => _buffer = apply(reordered));
    _changed();
  }

  Widget _editorSection(PortfolioContent workspace, int index) {
    final kind = mainPortfolioSectionOrder(_buffer!)[index];
    final section = switch (kind) {
      PortfolioBlockKind.links => BuilderTagsEditor(
        key: const Key('main.editor.contacts'),
        title: 'Контакты и ссылки',
        items: _buffer!.links.map((link) => link.label).toList(),
        keyPrefix: 'main.editor.contact',
        addKey: const Key('main.editor.addLink'),
        addLabel: 'Добавить контакт или ссылку',
        removeLabel: (name) => 'Удалить контакт $name',
        enabled: !_busy,
        onAdd: _editLink,
        onEdit: (index) => _editLink(_buffer!.links[index]),
        iconName: (index) =>
            portfolioContactIconName(_buffer!.links[index].kind),
        onReorder: (oldIndex, newIndex) => _reorderItems(
          _buffer!.links,
          oldIndex,
          newIndex,
          (links) => _buffer!.copyWith(links: links),
        ),
        onRemove: (index) {
          setState(
            () => _buffer = _buffer!.copyWith(
              links: [..._buffer!.links]..removeAt(index),
            ),
          );
          _changed();
        },
      ),
      PortfolioBlockKind.skills => BuilderTagsEditor(
        key: const Key('main.editor.skills'),
        title: 'Навыки',
        items: _buffer!.skills.map((skill) => skill.name).toList(),
        keyPrefix: 'main.editor.skill',
        addKey: const Key('main.editor.addSkill'),
        addLabel: 'Добавить навык',
        removeLabel: (name) => 'Удалить навык $name',
        enabled: !_busy,
        onAdd: _addSkill,
        onReorder: (oldIndex, newIndex) => _reorderItems(
          _buffer!.skills,
          oldIndex,
          newIndex,
          (skills) => _buffer!.copyWith(skills: skills),
        ),
        onRemove: (index) {
          setState(
            () => _buffer = _buffer!.copyWith(
              skills: [..._buffer!.skills]..removeAt(index),
            ),
          );
          _changed();
        },
      ),
      PortfolioBlockKind.featuredProjects => _projectsEditor(workspace),
      PortfolioBlockKind.experience => _recordsEditor(
        'Опыт работы',
        'main.editor.addExperience',
        _editExperience,
        orderKey: 'main.editor.experienceOrder',
        count: _buffer!.experience.length,
        onReorder: (oldIndex, newIndex) => _reorderItems(
          _buffer!.experience,
          oldIndex,
          newIndex,
          (experience) => _buffer!.copyWith(experience: experience),
        ),
        itemBuilder: (index) {
          final entry = _buffer!.experience[index];
          return _record(
            entry.id,
            index,
            entry.role,
            entry.organization,
            onEdit: () => _editExperience(entry),
            onRemove: () {
              setState(
                () => _buffer = _buffer!.copyWith(
                  experience: _buffer!.experience
                      .where((item) => item.id != entry.id)
                      .toList(),
                ),
              );
              _changed();
            },
          );
        },
      ),
      PortfolioBlockKind.education => _recordsEditor(
        'Образование',
        'main.editor.addEducation',
        _editEducation,
        orderKey: 'main.editor.educationOrder',
        count: _buffer!.education.length,
        onReorder: (oldIndex, newIndex) => _reorderItems(
          _buffer!.education,
          oldIndex,
          newIndex,
          (education) => _buffer!.copyWith(education: education),
        ),
        itemBuilder: (index) {
          final entry = _buffer!.education[index];
          return _record(
            entry.id,
            index,
            entry.institution,
            entry.qualification,
            onEdit: () => _editEducation(entry),
            onRemove: () {
              setState(
                () => _buffer = _buffer!.copyWith(
                  education: _buffer!.education
                      .where((item) => item.id != entry.id)
                      .toList(),
                ),
              );
              _changed();
            },
          );
        },
      ),
      _ => const SizedBox.shrink(),
    };
    return Padding(
      key: ValueKey('main.editor.section.${kind.name}'),
      padding: const EdgeInsets.only(bottom: StackCardSpacing.xl),
      child: section,
    );
  }

  Widget _recordsEditor(
    String title,
    String addKey,
    VoidCallback onAdd, {
    required String orderKey,
    required int count,
    required Widget Function(int index) itemBuilder,
    required void Function(int oldIndex, int newIndex) onReorder,
  }) => StackCardCard(
    outlined: true,
    padding: const EdgeInsets.all(StackCardSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BuilderSectionHeader(
          title: title,
          action: IconButton(
            key: ValueKey(addKey),
            tooltip: 'Добавить запись',
            onPressed: _busy ? null : onAdd,
            icon: const StackCardIcon(name: 'plus'),
          ),
        ),
        if (count > 0) ...[
          const SizedBox(height: StackCardSpacing.md),
          // Вложенный список: запись двигается только внутри своего раздела.
          ReorderableListView.builder(
            key: ValueKey(orderKey),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            itemCount: count,
            itemBuilder: (_, index) => itemBuilder(index),
            onReorderItem: onReorder,
          ),
        ],
      ],
    ),
  );

  Widget _projectsEditor(PortfolioContent workspace) => StackCardCard(
    key: const Key('main.editor.projects'),
    outlined: true,
    padding: const EdgeInsets.all(StackCardSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BuilderSectionHeader(
          title: 'Реализованные проекты',
          action: IconButton(
            key: const Key('main.editor.addProject'),
            tooltip: 'Добавить проект',
            onPressed: _busy ? null : _addProjects,
            icon: const StackCardIcon(name: 'plus'),
          ),
        ),
        if (_projects.isNotEmpty) ...[
          const SizedBox(height: StackCardSpacing.md),
          ReorderableListView.builder(
            key: const Key('main.editor.projectOrder'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            padding: EdgeInsets.zero,
            itemCount: _projects.length,
            itemBuilder: (_, index) => _projectRow(workspace, index),
            onReorderItem: _reorderProject,
          ),
        ],
      ],
    ),
  );

  Widget _projectRow(PortfolioContent workspace, int index) {
    final attachment = _projects[index];
    final project = workspace.projects
        .where((item) => item.id == attachment.projectId)
        .firstOrNull;
    if (project == null) return const SizedBox.shrink();
    final handle = Semantics(
      label: 'Изменить порядок проекта ${project.title}',
      hint: 'Удерживайте точки и перетащите',
      child: Tooltip(
        message: 'Удерживайте и перетащите',
        triggerMode: TooltipTriggerMode.manual,
        child: ReorderableDelayedDragStartListener(
          key: ValueKey('main.editor.drag.${project.id}'),
          index: index,
          enabled: !_busy && _sameOwner,
          child: const SizedBox(
            width: StackCardSize.touchTarget,
            height: StackCardSize.touchTarget,
            child: ColoredBox(
              color: Colors.transparent,
              child: Center(
                child: StackCardIcon(name: 'grip-vertical', size: 20),
              ),
            ),
          ),
        ),
      ),
    );
    final icon = IconButton(
      key: ValueKey('main.editor.icon.${project.id}'),
      tooltip: 'Выбрать иконку',
      onPressed: _busy ? null : () => _chooseIcon(project),
      icon: ProjectStockIcon(
        iconId: _iconUpdates[project.id] ?? project.iconId,
      ),
    );
    final title = Padding(
      padding: const EdgeInsets.all(StackCardSpacing.sm),
      child: Text(
        attachment.titleOverride ?? project.title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
    final remove = IconButton(
      key: ValueKey('main.editor.removeProject.${project.id}'),
      tooltip: 'Убрать из портфолио ${project.title}',
      onPressed: _busy
          ? null
          : () {
              setState(() => _projects.removeAt(index));
              _changed();
            },
      icon: const Icon(Icons.close_rounded, size: 20),
    );
    return Padding(
      key: ValueKey('main.editor.project.${project.id}'),
      padding: const EdgeInsets.only(bottom: StackCardSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(StackCardRadius.small),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final titleWidth = 120 * MediaQuery.textScalerOf(context).scale(1);
            if (constraints.maxWidth <
                3 * StackCardSize.touchTarget + titleWidth) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [handle, icon, const Spacer(), remove]),
                  title,
                ],
              );
            }
            return Row(
              children: [
                handle,
                icon,
                Expanded(child: title),
                remove,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProjectSelection extends ConsumerStatefulWidget {
  const _ProjectSelection({
    required this.library,
    required this.selectedIds,
    required this.isCurrent,
  });
  final List<PortfolioProject> library;
  final Set<String> selectedIds;
  final bool Function() isCurrent;
  @override
  ConsumerState<_ProjectSelection> createState() => _ProjectSelectionState();
}

class _ProjectSelectionState extends ConsumerState<_ProjectSelection> {
  late final _selected = Set<String>.of(widget.selectedIds);
  @override
  Widget build(BuildContext context) {
    ref.watch(portfolioDraftRepositoryProvider);
    ref.watch(accountSessionProvider);
    if (!widget.isCurrent()) {
      _selected.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.all(StackCardSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Добавить проект',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: StackCardSpacing.lg),
          if (widget.library.isEmpty) ...[
            const Text(
              'Проектов пока нет',
              key: Key('main.projectSelection.empty'),
            ),
            const SizedBox(height: StackCardSpacing.lg),
            StackCardButton(
              key: const Key('main.projectSelection.library'),
              label: 'Перейти в «Проекты»',
              primary: true,
              onPressed: () {
                Navigator.pop(context);
                context.go('/projects');
              },
            ),
          ] else ...[
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final project in widget.library)
                    CheckboxListTile(
                      key: ValueKey('main.projectSelection.${project.id}'),
                      title: Text(project.title),
                      subtitle: project.description.isEmpty
                          ? null
                          : Text(
                              project.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                      secondary: ProjectStockIcon(iconId: project.iconId),
                      value: _selected.contains(project.id),
                      onChanged: (selected) => setState(() {
                        if (selected == true) {
                          _selected.add(project.id);
                        } else {
                          _selected.remove(project.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: StackCardSpacing.lg),
            StackCardButton(
              key: const Key('main.projectSelection.apply'),
              label: 'Добавить выбранные',
              primary: true,
              onPressed: () => Navigator.pop(context, _selected),
            ),
          ],
        ],
      ),
    );
  }
}

class _MainContactDialog extends ConsumerStatefulWidget {
  const _MainContactDialog({this.item, required this.isCurrent});
  final SocialLink? item;
  final bool Function() isCurrent;

  @override
  ConsumerState<_MainContactDialog> createState() => _MainContactDialogState();
}

class _MainContactDialogState extends ConsumerState<_MainContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _controllers = builderFieldControllers([
    BuilderFieldSpec(
      name: 'label',
      labelKey: 'builderForm.linkLabel',
      value: widget.item?.label ?? '',
    ),
    BuilderFieldSpec(
      name: 'kind',
      labelKey: 'builderForm.linkKind',
      value: (widget.item?.kind ?? SocialLinkKind.website).name,
    ),
    BuilderFieldSpec(
      name: 'url',
      labelKey: 'builderForm.linkUrl',
      value: widget.item?.url ?? '',
    ),
  ]);

  @override
  void dispose() {
    disposeBuilderFieldControllers(_controllers);
    super.dispose();
  }

  String _url(String value) {
    final kind = SocialLinkKind.values.byName(_controllers['kind']!.text);
    var result = value.trim();
    if (kind == SocialLinkKind.email && !result.startsWith('mailto:')) {
      result = 'mailto:$result';
    } else if (kind == SocialLinkKind.phone && !result.startsWith('tel:')) {
      result = 'tel:$result';
    } else if (kind == SocialLinkKind.telegram && result.startsWith('@')) {
      result = 'https://t.me/${result.substring(1)}';
    }
    return result;
  }

  void _apply() {
    if (!widget.isCurrent() || _formKey.currentState?.validate() != true) {
      return;
    }
    final values = builderFieldValues(_controllers);
    values['url'] = _url(values['url']!);
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(portfolioDraftRepositoryProvider);
    ref.watch(accountSessionProvider);
    if (!widget.isCurrent()) {
      for (final controller in _controllers.values) {
        controller.clear();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context);
        }
      });
      return const SizedBox.shrink();
    }
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.item == null
            ? 'Добавить контакт или ссылку'
            : 'Редактировать контакт',
      ),
      content: Form(
        key: _formKey,
        child: BuilderFields(
          controllers: _controllers,
          fields: [
            const BuilderFieldSpec(
              name: 'label',
              labelKey: 'builderForm.linkLabel',
              maxLength: 80,
              required: true,
            ),
            const BuilderFieldSpec(
              name: 'kind',
              labelKey: 'builderForm.linkKind',
              choices: {
                'website': 'builderForm.kindWebsite',
                'github': 'builderForm.kindGitHub',
                'linkedin': 'builderForm.kindLinkedIn',
                'other': 'builderForm.kindOther',
                'email': 'settingsManagement.kind.email',
                'phone': 'settingsManagement.kind.phone',
                'telegram': 'settingsManagement.kind.telegram',
              },
            ),
            BuilderFieldSpec(
              name: 'url',
              labelKey: 'builderForm.linkUrl',
              maxLength: 2048,
              required: true,
              validate: (context, value) => builderValidationMessage(
                context,
                validatePortfolioContactUrl(
                  _url(value),
                  SocialLinkKind.values.byName(_controllers['kind']!.text),
                ),
              ),
            ),
          ],
          onSubmit: _apply,
          autofocus: true,
        ),
      ),
      actions: [
        StackCardDialogActions(
          cancelKey: const Key('main.contact.cancel'),
          onCancel: () => Navigator.pop(context),
          confirmKey: const Key('main.contact.apply'),
          confirmLabel: context.strings.tr('common.save'),
          onConfirm: _apply,
        ),
      ],
    );
  }
}
