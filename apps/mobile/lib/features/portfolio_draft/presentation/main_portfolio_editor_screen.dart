import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_input.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../auth/auth.dart';
import '../../media/media.dart';
import '../../projects/projects.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_validation.dart';
import '../portfolio_draft_providers.dart';
import 'builder_editor_widgets.dart';
import 'portfolio_draft_controller.dart';

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
  String? _expectedGitHubUsername;
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
    _expectedGitHubUsername = saved.githubUsername;
    _buffer = document.content;
    _projects = [...document.projects];
    final profile = document.content.profile;
    _fields = {
      'name': TextEditingController(text: profile.name),
      'headline': TextEditingController(text: profile.headline),
      'bio': TextEditingController(text: profile.bio),
      'locationText': TextEditingController(text: profile.locationText),
      'github': TextEditingController(text: workspace.githubUsername),
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
    _expectedGitHubUsername = null;
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
            githubUsername: normalizePortfolioGitHubUsername(
              _fields!['github']!.text,
            ),
          ),
        );
  }

  bool get _conflict {
    final state = ref.read(portfolioDraftControllerProvider);
    return state.remoteUpdateAvailable ||
        (state.draft?.content?.githubUsername ?? '') !=
            _expectedGitHubUsername ||
        mainPortfolioDocument(state.draft?.content ?? PortfolioContent()) !=
            _expected;
  }

  void _refreshUneditedGitHub(PortfolioContent? saved) {
    final input = _fields?['github'];
    if (!_sameOwner || _saving || input == null || saved == null) return;
    final username = saved.githubUsername;
    if (username == _expectedGitHubUsername ||
        normalizePortfolioGitHubUsername(input.text) !=
            _expectedGitHubUsername) {
      return;
    }
    // Обновление соседней формы не должно превращаться в откат старого кэша.
    input.removeListener(_changed);
    input.text = username;
    input.addListener(_changed);
    _expectedGitHubUsername = username;
  }

  Future<bool> _save() async {
    _refreshUneditedGitHub(
      ref.read(portfolioDraftControllerProvider).draft?.content,
    );
    if (!_sameOwner ||
        _busy ||
        _conflict ||
        _formKey.currentState?.validate() != true) {
      return false;
    }
    final document = _document();
    final generation = _generation;
    final githubUsername = _fields!['github']!.text;
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
          githubUsername: githubUsername,
          expectedGitHubUsername: _expectedGitHubUsername,
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
        _expectedGitHubUsername = normalizePortfolioGitHubUsername(
          githubUsername,
        );
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
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Остаться'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Открыть'),
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
          actions: [
            TextButton(
              key: const Key('main.editor.leave.stay'),
              onPressed: () => Navigator.pop(context, 'stay'),
              child: const Text('Остаться'),
            ),
            TextButton(
              key: const Key('main.editor.leave.discard'),
              onPressed: () => Navigator.pop(context, 'discard'),
              child: const Text('Не сохранять'),
            ),
            TextButton(
              key: const Key('main.editor.leave.save'),
              onPressed: () => Navigator.pop(context, 'save'),
              child: const Text('Сохранить'),
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

  void _moveProject(int index, int offset) {
    final other = index + offset;
    if (other < 0 || other >= _projects.length || _busy) return;
    setState(() {
      final entry = _projects.removeAt(index);
      _projects.insert(other, entry);
    });
    _changed();
  }

  Future<void> _editSkill([Skill? item]) async {
    final values = await showBuilderRecordEditor(
      context,
      titleKey: 'builderForm.skillsTitle',
      fields: [
        BuilderFieldSpec(
          name: 'name',
          labelKey: 'builderForm.skillName',
          value: item?.name ?? '',
          maxLength: 60,
          required: true,
        ),
      ],
    );
    if (!mounted || !_sameOwner || values == null) return;
    final next = Skill(
      id: item?.id ?? _createId(),
      name: values['name']!.trim(),
    );
    setState(
      () => _buffer = _buffer!.copyWith(
        skills: [
          for (final previous in _buffer!.skills)
            previous.id == next.id ? next : previous,
          if (item == null) next,
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
    _refreshUneditedGitHub(state.draft?.content);
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
      body = SingleChildScrollView(
        key: const Key('main.editor.scroll'),
        padding: const EdgeInsets.all(StackCardSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
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
              _field('locationText', 'Город / страна', 200),
              _field('bio', 'О себе', 4000, multiline: true),
              _title('Контакты и ссылки'),
              for (final link in _buffer!.links)
                _record(
                  link.id,
                  link.label,
                  link.url,
                  onEdit: () => _editLink(link),
                  onRemove: () {
                    setState(
                      () => _buffer = _buffer!.copyWith(
                        links: _buffer!.links
                            .where((item) => item.id != link.id)
                            .toList(),
                      ),
                    );
                    _changed();
                  },
                ),
              _addButton(
                'main.editor.addLink',
                'Добавить контакт или ссылку',
                _editLink,
              ),
              _title('Проекты'),
              for (var index = 0; index < _projects.length; index++)
                _projectRow(workspace!, index),
              _addButton(
                'main.editor.addProject',
                'Добавить проект',
                _addProjects,
              ),
              _title('Навыки'),
              for (final skill in _buffer!.skills)
                _record(
                  skill.id,
                  skill.name,
                  '',
                  onEdit: () => _editSkill(skill),
                  onRemove: () {
                    setState(
                      () => _buffer = _buffer!.copyWith(
                        skills: _buffer!.skills
                            .where((item) => item.id != skill.id)
                            .toList(),
                      ),
                    );
                    _changed();
                  },
                ),
              _addButton('main.editor.addSkill', 'Добавить навык', _editSkill),
              _title('Опыт'),
              for (final entry in _buffer!.experience)
                _record(
                  entry.id,
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
                ),
              _addButton(
                'main.editor.addExperience',
                'Добавить опыт',
                _editExperience,
              ),
              _title('Образование'),
              for (final entry in _buffer!.education)
                _record(
                  entry.id,
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
                ),
              _addButton(
                'main.editor.addEducation',
                'Добавить образование',
                _editEducation,
              ),
              if (_buffer!.resumeText.isNotEmpty) ...[
                _title('Дополнительно'),
                _field(
                  'legacyText',
                  'Дополнительный текст',
                  20000,
                  multiline: true,
                ),
              ],
              _title('GitHub'),
              _field(
                'github',
                'Профиль GitHub',
                200,
                hint: 'https://github.com/username',
                validate: (value) =>
                    normalizePortfolioGitHubUsername(value) == null
                    ? 'Введите username или ссылку на профиль GitHub'
                    : null,
              ),
            ],
          ),
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

  Widget _title(String value) => Padding(
    padding: const EdgeInsets.only(
      top: StackCardSpacing.xl,
      bottom: StackCardSpacing.lg,
    ),
    child: Text(value, style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _field(
    String name,
    String label,
    int maxLength, {
    bool multiline = false,
    String? hint,
    String? Function(String)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: StackCardSpacing.lg),
    child: StackCardInput(
      key: ValueKey('main.editor.$name'),
      controller: _fields![name],
      label: label,
      hint: hint,
      enabled: !_saving,
      minLines: multiline ? 3 : null,
      maxLines: multiline ? 8 : 1,
      keyboardType: multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: multiline
          ? TextInputAction.newline
          : TextInputAction.next,
      validator: (value) =>
          builderValidationMessage(
            context,
            validatePortfolioText(value ?? '', maxLength: maxLength),
            maxLength: maxLength,
          ) ??
          validate?.call(value ?? ''),
    ),
  );

  Widget _addButton(String key, String label, VoidCallback callback) =>
      StackCardButton(
        key: ValueKey(key),
        label: label,
        icon: Icons.add_rounded,
        onPressed: _busy ? null : callback,
      );

  Widget _record(
    String id,
    String title,
    String summary, {
    required VoidCallback onEdit,
    required VoidCallback onRemove,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: StackCardSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (summary.isNotEmpty)
          Text(summary, maxLines: 3, overflow: TextOverflow.ellipsis),
        Wrap(
          spacing: StackCardSpacing.sm,
          children: [
            TextButton(
              key: ValueKey('main.record.edit.$id'),
              onPressed: _busy ? null : onEdit,
              child: const Text('Редактировать'),
            ),
            TextButton(
              key: ValueKey('main.record.remove.$id'),
              onPressed: _busy ? null : onRemove,
              child: const Text('Удалить'),
            ),
          ],
        ),
        Divider(color: context.colors.border),
      ],
    ),
  );

  Widget _projectRow(PortfolioContent workspace, int index) {
    final attachment = _projects[index];
    final project = workspace.projects
        .where((item) => item.id == attachment.projectId)
        .firstOrNull;
    if (project == null) return const SizedBox.shrink();
    return Padding(
      key: ValueKey('main.editor.project.${project.id}'),
      padding: const EdgeInsets.only(bottom: StackCardSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                key: ValueKey('main.editor.icon.${project.id}'),
                tooltip: 'Выбрать иконку',
                onPressed: _busy ? null : () => _chooseIcon(project),
                icon: ProjectStockIcon(
                  iconId: _iconUpdates[project.id] ?? project.iconId,
                ),
              ),
              const SizedBox(width: StackCardSpacing.sm),
              Expanded(
                child: Text(
                  attachment.titleOverride ?? project.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          Wrap(
            spacing: StackCardSpacing.sm,
            children: [
              IconButton(
                key: ValueKey('main.editor.up.${project.id}'),
                tooltip: 'Выше',
                onPressed: _busy || index == 0
                    ? null
                    : () => _moveProject(index, -1),
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
              IconButton(
                key: ValueKey('main.editor.down.${project.id}'),
                tooltip: 'Ниже',
                onPressed: _busy || index == _projects.length - 1
                    ? null
                    : () => _moveProject(index, 1),
                icon: const Icon(Icons.arrow_downward_rounded),
              ),
              TextButton(
                key: ValueKey('main.editor.removeProject.${project.id}'),
                onPressed: _busy
                    ? null
                    : () {
                        setState(() => _projects.removeAt(index));
                        _changed();
                      },
                child: const Text('Убрать из портфолио'),
              ),
            ],
          ),
          Divider(color: context.colors.border),
        ],
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
    return Dialog(
      insetPadding: const EdgeInsets.all(StackCardSpacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StackCardSize.contentMaxWidth,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(StackCardSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Контакт или ссылка',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: StackCardSpacing.lg),
                BuilderFields(
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
                          SocialLinkKind.values.byName(
                            _controllers['kind']!.text,
                          ),
                        ),
                      ),
                    ),
                  ],
                  onSubmit: _apply,
                  autofocus: true,
                ),
                const SizedBox(height: StackCardSpacing.lg),
                Wrap(
                  spacing: StackCardSpacing.sm,
                  runSpacing: StackCardSpacing.sm,
                  children: [
                    StackCardButton(
                      key: const Key('main.contact.apply'),
                      label: 'Добавить или обновить',
                      primary: true,
                      onPressed: _apply,
                    ),
                    StackCardButton(
                      label: 'Отмена',
                      onPressed: () => Navigator.pop(context),
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
