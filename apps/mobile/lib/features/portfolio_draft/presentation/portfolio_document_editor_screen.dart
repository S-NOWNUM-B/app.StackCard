import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_theme.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_states.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../../media/media.dart';
import '../../auth/auth.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_document_base_review.dart';
import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';
import 'builder_editor_widgets.dart';
import 'portfolio_content_view.dart';
import 'portfolio_draft_controller.dart';
import 'portfolio_document_base_review_screen.dart';

enum _DocumentSection {
  profile,
  contacts,
  qualifications,
  projects,
  appearance,
  preview,
}

/// Буфер документа отделён от общей базы и сохраняется одним явным действием.
class PortfolioDocumentEditorScreen extends ConsumerStatefulWidget {
  const PortfolioDocumentEditorScreen({
    super.key,
    this.documentId,
    required this.kind,
  });

  final String? documentId;
  final PortfolioDocumentKind kind;

  @override
  ConsumerState<PortfolioDocumentEditorScreen> createState() =>
      _PortfolioDocumentEditorScreenState();
}

class _PortfolioDocumentEditorScreenState
    extends ConsumerState<PortfolioDocumentEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mediaKey = GlobalKey<PortfolioMediaEditorState>();
  PortfolioDraftRepository? _repository;
  PortfolioDocument? _expected;
  PortfolioContent? _content;
  PortfolioContent? _baseSnapshot;
  (Object?, String?, bool, bool)? _initialOwner;
  Map<String, TextEditingController>? _fields;
  List<PortfolioProjectAttachment> _projects = [];
  List<PortfolioProject> _newProjects = [];
  String? _resumeId;
  String? _id;
  DateTime? _createdAt;
  _DocumentSection? _section;
  var _step = 0;
  var _dirty = false;
  var _saving = false;
  var _mediaBusy = false;
  var _saveError = false;
  var _saveConflict = false;
  var _bufferGeneration = 0;
  var _ownerInvalid = false;
  var _allowPop = false;
  var _exitDialog = false;
  var _missing = false;
  var _reloaded = false;

  bool get _wizard => widget.documentId == null;
  bool get _resume => widget.kind == PortfolioDocumentKind.resume;
  _DocumentSection? get _activeSection => _wizard
      ? [
          _DocumentSection.profile,
          _DocumentSection.contacts,
          _DocumentSection.qualifications,
          _DocumentSection.projects,
          _DocumentSection.preview,
        ][_step]
      : _section;
  String _tr(String key, [Map<String, Object> parameters = const {}]) =>
      context.strings.tr('documentEditor.$key', parameters);

  @override
  void dispose() {
    disposeBuilderFieldControllers(_fields);
    super.dispose();
  }

  void _initialize(PortfolioContent workspace, PortfolioDocument? document) {
    _repository = ref.read(portfolioDraftRepositoryProvider);
    _initialOwner = _owner();
    _expected = document;
    _content = document?.content ?? seedDocumentContent(workspace);
    _baseSnapshot = document == null
        ? developerProfileData(workspace)
        : document.baseSnapshot;
    _projects = [...?document?.projects];
    _resumeId = document?.attachedResumeId;
    _id =
        document?.id ??
        ref.read(portfolioDraftControllerProvider.notifier).createId();
    _createdAt = document?.createdAt ?? DateTime.now().toUtc();
    final profile = _content!.profile;
    _fields = {
      'title': TextEditingController(text: document?.title ?? ''),
      'name': TextEditingController(text: profile.name),
      'headline': TextEditingController(text: profile.headline),
      'bio': TextEditingController(text: profile.bio),
      'locationText': TextEditingController(text: profile.locationText),
    };
    for (final controller in _fields!.values) {
      controller.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted && !_ownerInvalid) {
      setState(() {
        _dirty = true;
        _saveError = false;
        _bufferGeneration++;
      });
    }
  }

  bool get _sameOwner =>
      !_ownerInvalid &&
      _initialOwner == _owner() &&
      identical(_repository, ref.read(portfolioDraftRepositoryProvider));

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

  void _invalidateOwner() {
    _ownerInvalid = true;
    _content = null;
    _expected = null;
    _baseSnapshot = null;
    _projects = [];
    _newProjects = [];
    _resumeId = null;
    for (final field in _fields?.values ?? <TextEditingController>[]) {
      field.removeListener(_changed);
      field.clear();
    }
    _dirty = false;
  }

  PortfolioDocument? _findDocument(PortfolioContent? content) => content
      ?.documents
      .where((document) => document.id == widget.documentId)
      .firstOrNull;

  bool _conflicted() {
    if (_saveConflict) return true;
    if (_wizard) return false;
    final state = ref.read(portfolioDraftControllerProvider);
    if (!_reloaded && state.remoteUpdateAvailable) return true;
    return !_reloaded && _findDocument(state.draft?.content) != _expected;
  }

  PortfolioContent _buffer() {
    final values = builderFieldValues(_fields!);
    return _content!.copyWith(
      profile: _content!.profile.copyWith(
        name: values['name']!.trim(),
        headline: values['headline']!.trim(),
        bio: values['bio']!.trim(),
        locationText: values['locationText']!.trim(),
      ),
    );
  }

  PortfolioDocument _document() => PortfolioDocument(
    id: _id!,
    title: _fields!['title']!.text.trim(),
    kind: widget.kind,
    createdAt: _createdAt!,
    updatedAt: DateTime.now().toUtc(),
    content: _buffer(),
    baseSnapshot: _baseSnapshot,
    projects: _projects,
    attachedResumeId: _resumeId,
  );

  bool _validateProfile() {
    final valid = [
      'title',
      'name',
      'headline',
    ].every((key) => _fields![key]!.text.trim().isNotEmpty);
    if (!valid) {
      setState(() {
        _step = 0;
        _section = _DocumentSection.profile;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _formKey.currentState?.validate();
      });
      return false;
    }
    return _activeSection != _DocumentSection.profile ||
        _formKey.currentState?.validate() == true;
  }

  Future<bool> _save({bool leave = false}) async {
    if (!_sameOwner ||
        _saving ||
        _mediaBusy ||
        _missing ||
        _conflicted() ||
        !_validateProfile()) {
      return false;
    }
    final document = _document();
    final newProjects = List<PortfolioProject>.of(_newProjects);
    final bufferGeneration = _bufferGeneration;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    final success = await ref
        .read(portfolioDraftControllerProvider.notifier)
        .saveDocument(
          document,
          expectedDocument: _expected,
          newProjects: newProjects,
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
      _saveConflict =
          !success &&
          ref.read(portfolioDraftControllerProvider).failure?.kind ==
              PortfolioDraftFailureKind.conflict;
      if (success) {
        _newProjects = _newProjects
            .where((project) => !newProjects.any((saved) => saved == project))
            .toList();
        _dirty = _bufferGeneration != bufferGeneration;
        _expected = document;
      }
    });
    if (success && leave && !_dirty) _close();
    return success;
  }

  void _close() {
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(_resume ? '/resumes' : '/portfolio');
      }
    });
  }

  Future<void> _requestExit() async {
    if (_saving || _mediaBusy || _exitDialog) return;
    if (!_dirty || !_sameOwner) {
      _close();
      return;
    }
    _exitDialog = true;
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('leaveTitle')),
        content: Text(_tr('leaveHint')),
        actions: [
          TextButton(
            key: const Key('document.leave.stay'),
            onPressed: () => Navigator.of(dialogContext).pop('stay'),
            child: Text(_tr('stay')),
          ),
          TextButton(
            key: const Key('document.leave.discard'),
            onPressed: () => Navigator.of(dialogContext).pop('discard'),
            child: Text(_tr('discard')),
          ),
          TextButton(
            key: const Key('document.leave.save'),
            onPressed: () => Navigator.of(dialogContext).pop('save'),
            child: Text(_tr('save')),
          ),
        ],
      ),
    );
    _exitDialog = false;
    if (!mounted) return;
    if (!_sameOwner || action == 'discard') {
      _close();
    } else if (action == 'save') {
      await _save(leave: true);
    }
  }

  void _back() {
    if (_saving || _mediaBusy) return;
    if (_wizard && _step > 0) {
      setState(() => _step--);
    } else if (!_wizard && _section != null) {
      setState(() => _section = null);
    } else {
      _requestExit();
    }
  }

  Future<void> _reload() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_tr('reloadTitle')),
        content: Text(_tr('reloadHint')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_tr('reload')),
          ),
        ],
      ),
    );
    if (!mounted || !_sameOwner || accepted != true) return;
    try {
      final snapshot = await _repository!.read();
      if (!mounted || !_sameOwner) return;
      final document = _findDocument(snapshot?.content);
      setState(() {
        disposeBuilderFieldControllers(_fields);
        _fields = null;
        _newProjects = [];
        _missing = document == null;
        if (document != null) _initialize(snapshot!.content!, document);
        _dirty = false;
        _reloaded = true;
        _saveError = false;
        _saveConflict = false;
      });
    } on Object {
      if (mounted && _sameOwner) setState(() => _saveError = true);
    }
  }

  Future<void> _reviewBase() async {
    if (!_sameOwner || _saving || _mediaBusy || _conflicted()) return;
    final workspace = ref.read(portfolioDraftControllerProvider).draft?.content;
    if (workspace == null) return;
    final review = PortfolioDocumentBaseReview(
      document: _document(),
      base: workspace,
    );
    final generation = _bufferGeneration;
    final result = await Navigator.of(context).push<PortfolioDocument>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PortfolioDocumentBaseReviewScreen(
          review: review,
          isActive: () => mounted && _sameOwner,
        ),
      ),
    );
    if (!mounted || !_sameOwner || result == null) return;
    final currentBase = ref
        .read(portfolioDraftControllerProvider)
        .draft
        ?.content;
    if (generation != _bufferGeneration ||
        currentBase == null ||
        developerProfileData(currentBase) != review.base ||
        _findDocument(currentBase) != _expected ||
        _conflicted()) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_tr('baseReviewStale'))));
      return;
    }
    _edit(() {
      _content = result.content;
      _baseSnapshot = result.baseSnapshot;
      final profile = result.content.profile;
      final values = {
        'name': profile.name,
        'headline': profile.headline,
        'bio': profile.bio,
        'locationText': profile.locationText,
      };
      for (final entry in values.entries) {
        final field = _fields![entry.key]!;
        field.removeListener(_changed);
        if (field.text.trim() != entry.value) field.text = entry.value;
        field.addListener(_changed);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final state = ref.watch(portfolioDraftControllerProvider);
    final owner = _owner(watch: true);
    ref.listen(portfolioDraftRepositoryProvider, (_, next) {
      if (_repository != null && !identical(_repository, next)) {
        setState(_invalidateOwner);
      }
    });
    final savedWorkspace = state.draft?.content;
    final workspace = (savedWorkspace ?? state.content ?? PortfolioContent())
        .copyWith(
          projects: _options(
            savedWorkspace?.projects ?? [],
            _newProjects,
            (item) => item.id,
          ),
        );
    if (_fields == null && !_ownerInvalid && state.canEdit && !state.loading) {
      final existing = _findDocument(workspace);
      if (!_wizard && (existing == null || existing.kind != widget.kind)) {
        _missing = true;
      } else {
        _initialize(workspace, existing);
      }
    }
    final ownerChanged =
        _ownerInvalid ||
        (_initialOwner != null && _initialOwner != owner) ||
        (_repository != null && !identical(_repository, repository));
    if (ownerChanged && !_ownerInvalid) _invalidateOwner();
    final ready =
        !ownerChanged && !_missing && _fields != null && state.canEdit;
    final title = _tr(
      _wizard
          ? (_resume ? 'createResume' : 'createPortfolio')
          : (_resume ? 'editResume' : 'editPortfolio'),
    );
    return PopScope<Object?>(
      canPop:
          _allowPop ||
          (!_dirty &&
              !_saving &&
              !_mediaBusy &&
              _section == null &&
              (!_wizard || _step == 0)),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('document.back'),
            tooltip: _tr('back'),
            onPressed: _back,
            icon: const StackCardIcon(name: 'arrow-left'),
          ),
          title: Text(title),
        ),
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: !ready
                  ? SingleChildScrollView(
                      child: StackCardStateView(
                        kind: state.loading
                            ? StackCardViewState.loading
                            : StackCardViewState.error,
                        title: context.strings.tr(
                          state.loading
                              ? 'common.loading'
                              : 'builderForm.unavailable',
                        ),
                        message: ownerChanged
                            ? _tr('ownerChanged')
                            : _missing
                            ? _tr('missing')
                            : context.strings.tr('builderForm.loadingHint'),
                      ),
                    )
                  : SingleChildScrollView(
                      key: const Key('document.scroll'),
                      padding: const EdgeInsets.all(StackCardSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_conflicted()) ...[
                            _notice(_tr('conflict')),
                            StackCardButton(
                              key: const Key('document.reload'),
                              label: _tr('reload'),
                              onPressed: _reload,
                            ),
                            const SizedBox(height: StackCardSpacing.lg),
                          ],
                          if (_saveError) ...[
                            _notice(_tr('saveError')),
                            const SizedBox(height: StackCardSpacing.lg),
                          ],
                          if (_wizard) ...[
                            _stepper(),
                            const SizedBox(height: StackCardSpacing.lg),
                          ],
                          _body(workspace),
                          Offstage(
                            offstage:
                                _activeSection != _DocumentSection.profile,
                            child: PortfolioMediaEditor(
                              key: _mediaKey,
                              paths: [
                                if (_content!.profile.avatarPath.isNotEmpty)
                                  _content!.profile.avatarPath,
                              ],
                              maxImages: 1,
                              titleKey: 'documentEditor.photo',
                              formNoteKey: 'documentEditor.photoHint',
                              enabled: !_saving,
                              onBusyChanged: (busy) {
                                if (mounted && _sameOwner) {
                                  setState(() => _mediaBusy = busy);
                                }
                              },
                              onChanged: (paths) => _edit(() {
                                _content = _content!.copyWith(
                                  profile: _content!.profile.copyWith(
                                    avatarPath: paths.firstOrNull ?? '',
                                    avatarUrl: '',
                                  ),
                                );
                              }),
                            ),
                          ),
                          if (_activeSection == _DocumentSection.profile) ...[
                            const SizedBox(height: StackCardSpacing.lg),
                            BuilderFields(
                              fields: const [
                                BuilderFieldSpec(
                                  name: 'bio',
                                  labelKey: 'documentEditor.bio',
                                  maxLength: 4000,
                                  kind: BuilderFieldKind.multiline,
                                ),
                                BuilderFieldSpec(
                                  name: 'locationText',
                                  labelKey: 'documentEditor.location',
                                  maxLength: 200,
                                ),
                              ],
                              controllers: _fields!,
                            ),
                          ],
                        ],
                      ),
                    ),
            ),
          ),
        ),
        bottomNavigationBar: ready
            ? Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: _footer(),
              )
            : null,
      ),
    );
  }

  Widget _notice(String text) => StackCardCard(child: Text(text));

  Widget _stepper() {
    final labels = [
      'profile',
      'contacts',
      'qualifications',
      'projects',
      'preview',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _tr('step', {'step': _step + 1, 'label': _tr(labels[_step])}),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: StackCardSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: Column(
                  children: [
                    Semantics(
                      label: '${index + 1}: ${_tr(labels[index])}',
                      selected: index == _step,
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _step
                              ? context.colors.primary
                              : Colors.transparent,
                          border: Border.all(
                            color: index <= _step
                                ? context.colors.primary
                                : context.colors.controlOutline,
                          ),
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: index == _step
                                      ? context.colors.onPrimary
                                      : context.colors.textPrimary,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: StackCardSpacing.sm),
                    Text(
                      _tr(labels[index]),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _body(PortfolioContent workspace) => switch (_activeSection) {
    null => _overview(),
    _DocumentSection.profile => _profile(workspace),
    _DocumentSection.contacts => _contacts(workspace),
    _DocumentSection.qualifications => _qualifications(workspace),
    _DocumentSection.projects => _projectSelection(workspace),
    _DocumentSection.appearance => _appearance(),
    _DocumentSection.preview => _preview(workspace),
  };

  Widget _overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        _fields!['title']!.text,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: StackCardSpacing.lg),
      StackCardButton(
        key: const Key('document.baseReview'),
        label: _tr('baseReview'),
        role: StackCardButtonRole.secondary,
        onPressed: !_saving && !_mediaBusy && !_conflicted()
            ? _reviewBase
            : null,
      ),
      const SizedBox(height: StackCardSpacing.lg),
      for (final entry in <(_DocumentSection, String, String)>[
        (_DocumentSection.profile, 'profile', 'user-round'),
        (_DocumentSection.contacts, 'contacts', 'file-text'),
        (_DocumentSection.qualifications, 'qualifications', 'file-text'),
        (_DocumentSection.projects, 'projects', 'folder'),
        (_DocumentSection.appearance, 'appearance', 'panels-top-left'),
        (_DocumentSection.preview, 'preview', 'file-text'),
      ])
        ListTile(
          key: ValueKey('document.section.${entry.$1.name}'),
          contentPadding: EdgeInsets.zero,
          minTileHeight: 72,
          leading: StackCardIcon(name: entry.$3),
          title: Text(_tr(entry.$2)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => setState(() => _section = entry.$1),
        ),
    ],
  );

  Widget _profile(PortfolioContent workspace) {
    final profile = _content!.profile;
    final fields = [
      BuilderFieldSpec(
        name: 'title',
        labelKey: 'documentEditor.title',
        hintKey: 'documentEditor.titleHint',
        maxLength: 160,
        required: true,
      ),
      const BuilderFieldSpec(
        name: 'name',
        labelKey: 'documentEditor.name',
        maxLength: 100,
        required: true,
      ),
      const BuilderFieldSpec(
        name: 'headline',
        labelKey: 'documentEditor.role',
        maxLength: 160,
        required: true,
      ),
    ];
    final photo = profile.avatarPath.isNotEmpty || profile.avatarUrl.isNotEmpty;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_tr('profileHint')),
          const SizedBox(height: StackCardSpacing.lg),
          BuilderFields(fields: fields, controllers: _fields!),
          const SizedBox(height: StackCardSpacing.lg),
          if (photo && profile.avatarPath.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: StackCardAvatar(
                url: profile.avatarUrl,
                image: profile.avatarPath.isEmpty
                    ? null
                    : PortfolioMediaImage(
                        path: profile.avatarPath,
                        width: 80,
                        height: 80,
                      ),
              ),
            )
          else if (!photo)
            Row(
              children: [
                const StackCardIcon(name: 'image'),
                const SizedBox(width: StackCardSpacing.sm),
                Expanded(child: Text(_tr('noPhoto'))),
              ],
            ),
          const SizedBox(height: StackCardSpacing.md),
          StackCardButton(
            label: _tr(photo ? 'removePhoto' : 'useProfilePhoto'),
            onPressed:
                photo ||
                    workspace.profile.avatarPath.isNotEmpty ||
                    workspace.profile.avatarUrl.isNotEmpty
                ? () => _edit(() {
                    _content = _content!.copyWith(
                      profile: profile.copyWith(
                        avatarPath: photo ? '' : workspace.profile.avatarPath,
                        avatarUrl: photo ? '' : workspace.profile.avatarUrl,
                      ),
                    );
                  })
                : null,
            unavailableReason: photo ? null : _tr('noPhoto'),
          ),
        ],
      ),
    );
  }

  void _edit(VoidCallback update) {
    if (!_sameOwner || _saving) return;
    setState(() {
      update();
      _dirty = true;
      _saveError = false;
      _bufferGeneration++;
    });
  }

  List<T> _options<T>(List<T> base, List<T> local, String Function(T) id) => {
    for (final item in base) id(item): item,
    for (final item in local) id(item): item,
  }.values.toList();

  Widget _contacts(PortfolioContent workspace) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(_tr('contactsHint')),
      const SizedBox(height: StackCardSpacing.lg),
      for (final link in _options(
        workspace.links,
        _content!.links,
        (item) => item.id,
      ))
        _selection(
          key: 'link.${link.id}',
          title: link.label,
          subtitle: link.url,
          selected: _content!.links.any((item) => item.id == link.id),
          onChanged: (selected) => _edit(
            () => _content = _content!.copyWith(
              links: [
                ..._content!.links.where((item) => item.id != link.id),
                if (selected) link,
              ],
            ),
          ),
          onEdit: () => _editLink(link),
        ),
      StackCardButton(
        key: const Key('document.link.add'),
        label: _tr('addLink'),
        onPressed: _editLink,
      ),
    ],
  );

  Future<void> _editLink([SocialLink? link]) async {
    final values = await showBuilderRecordEditor(
      context,
      titleKey: 'documentEditor.contacts',
      fields: [
        BuilderFieldSpec(
          name: 'label',
          labelKey: 'documentEditor.linkLabel',
          value: link?.label ?? '',
          maxLength: 100,
          required: true,
        ),
        BuilderFieldSpec(
          name: 'url',
          labelKey: 'documentEditor.linkUrl',
          value: link?.url ?? '',
          maxLength: 2048,
          required: true,
          kind: BuilderFieldKind.url,
        ),
      ],
    );
    if (!mounted || !_sameOwner || values == null) return;
    final record = SocialLink(
      id:
          link?.id ??
          ref.read(portfolioDraftControllerProvider.notifier).createId(),
      label: values['label']!.trim(),
      url: values['url']!.trim(),
      kind: link?.kind ?? SocialLinkKind.other,
    );
    _edit(
      () => _content = _content!.copyWith(
        links: [
          for (final current in _content!.links)
            if (current.id == record.id) record else current,
          if (!_content!.links.any((item) => item.id == record.id)) record,
        ],
      ),
    );
  }

  Widget _qualifications(PortfolioContent workspace) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('experience'),
      for (final item in _options(
        workspace.experience,
        _content!.experience,
        (item) => item.id,
      ))
        _selection(
          key: 'experience.${item.id}',
          title: item.role,
          subtitle: '${item.organization} · ${item.period}',
          selected: _content!.experience.any((entry) => entry.id == item.id),
          onChanged: (selected) => _edit(
            () => _content = _content!.copyWith(
              experience: [
                ..._content!.experience.where((entry) => entry.id != item.id),
                if (selected) item,
              ],
            ),
          ),
          onEdit: () => _editQualification(item),
        ),
      StackCardButton(
        label: _tr('addExperience'),
        onPressed: () => _editQualification(null),
      ),
      const SizedBox(height: StackCardSpacing.lg),
      _heading('education'),
      for (final item in _options(
        workspace.education,
        _content!.education,
        (item) => item.id,
      ))
        _selection(
          key: 'education.${item.id}',
          title: item.qualification,
          subtitle: '${item.institution} · ${item.period}',
          selected: _content!.education.any((entry) => entry.id == item.id),
          onChanged: (selected) => _edit(
            () => _content = _content!.copyWith(
              education: [
                ..._content!.education.where((entry) => entry.id != item.id),
                if (selected) item,
              ],
            ),
          ),
          onEdit: () => _editQualification(item, education: true),
        ),
      StackCardButton(
        label: _tr('addEducation'),
        onPressed: () => _editQualification(null, education: true),
      ),
    ],
  );

  Future<void> _editQualification(
    Object? item, {
    bool education = false,
  }) async {
    final work = item is Experience ? item : null;
    final study = item is Education ? item : null;
    final values = await showBuilderRecordEditor(
      context,
      titleKey: education
          ? 'documentEditor.education'
          : 'documentEditor.experience',
      fields: [
        BuilderFieldSpec(
          name: 'role',
          labelKey: education
              ? 'documentEditor.qualification'
              : 'documentEditor.role',
          value: work?.role ?? study?.qualification ?? '',
          maxLength: 160,
          required: true,
        ),
        BuilderFieldSpec(
          name: 'organization',
          labelKey: education
              ? 'documentEditor.institution'
              : 'documentEditor.organization',
          value: work?.organization ?? study?.institution ?? '',
          maxLength: 200,
          required: true,
        ),
        BuilderFieldSpec(
          name: 'period',
          labelKey: 'documentEditor.period',
          value: work?.period ?? study?.period ?? '',
          maxLength: 100,
        ),
        BuilderFieldSpec(
          name: 'description',
          labelKey: 'documentEditor.description',
          value: work?.description ?? study?.description ?? '',
          maxLength: 4000,
          kind: BuilderFieldKind.multiline,
        ),
      ],
    );
    if (!mounted || !_sameOwner || values == null) return;
    final id =
        work?.id ??
        study?.id ??
        ref.read(portfolioDraftControllerProvider.notifier).createId();
    _edit(() {
      if (education) {
        final record = Education(
          id: id,
          institution: values['organization']!,
          qualification: values['role']!,
          period: values['period']!,
          description: values['description']!,
        );
        _content = _content!.copyWith(
          education: [
            for (final entry in _content!.education)
              if (entry.id == id) record else entry,
            if (!_content!.education.any((entry) => entry.id == id)) record,
          ],
        );
      } else {
        final record = Experience(
          id: id,
          organization: values['organization']!,
          role: values['role']!,
          period: values['period']!,
          description: values['description']!,
        );
        _content = _content!.copyWith(
          experience: [
            for (final entry in _content!.experience)
              if (entry.id == id) record else entry,
            if (!_content!.experience.any((entry) => entry.id == id)) record,
          ],
        );
      }
    });
  }

  Widget _heading(String key) => Padding(
    padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.md),
    child: Text(_tr(key), style: Theme.of(context).textTheme.titleLarge),
  );

  Widget _selection({
    required String key,
    required String title,
    String? subtitle,
    required bool selected,
    required ValueChanged<bool> onChanged,
    VoidCallback? onEdit,
  }) => Column(
    children: [
      CheckboxListTile(
        key: ValueKey('document.select.$key'),
        contentPadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        value: selected,
        onChanged: _saving ? null : (value) => onChanged(value ?? false),
      ),
      if (onEdit != null && selected)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _saving ? null : onEdit,
            child: Text(context.strings.tr('builderForm.edit')),
          ),
        ),
    ],
  );

  Widget _projectSelection(PortfolioContent workspace) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _heading('skills'),
      for (final skill in _options(
        workspace.skills,
        _content!.skills,
        (item) => item.id,
      ))
        _selection(
          key: 'skill.${skill.id}',
          title: skill.name,
          selected: _content!.skills.any((item) => item.id == skill.id),
          onChanged: (selected) => _edit(
            () => _content = _content!.copyWith(
              skills: [
                ..._content!.skills.where((item) => item.id != skill.id),
                if (selected) skill,
              ],
            ),
          ),
        ),
      StackCardButton(label: _tr('addSkill'), onPressed: _addSkill),
      const SizedBox(height: StackCardSpacing.lg),
      _heading('libraryProjects'),
      if (workspace.projects.isEmpty) Text(_tr('libraryEmpty')),
      StackCardButton(
        key: const Key('document.addProject'),
        label: _tr('addProject'),
        onPressed: _saving ? null : () => _editNewProject(),
      ),
      const SizedBox(height: StackCardSpacing.sm),
      for (final project in workspace.projects)
        _selection(
          key: 'project.${project.id}',
          title: project.title,
          subtitle: project.description,
          selected: _projects.any((entry) => entry.projectId == project.id),
          onEdit: _newProjects.any((item) => item.id == project.id)
              ? () => _editNewProject(project)
              : null,
          onChanged: (selected) => _edit(
            () => _projects = [
              ..._projects.where((entry) => entry.projectId != project.id),
              if (selected) PortfolioProjectAttachment(projectId: project.id),
            ],
          ),
        ),
      for (var index = 0; index < _projects.length; index++)
        _attachment(workspace, index),
      if (!_resume) ...[
        _heading('attachResume'),
        RadioGroup<String>(
          groupValue: _resumeId ?? '',
          onChanged: (value) =>
              _edit(() => _resumeId = value == '' ? null : value),
          child: Column(
            children: [
              RadioListTile<String>(value: '', title: Text(_tr('noResume'))),
              for (final document in workspace.documents.where(
                (item) => item.kind == PortfolioDocumentKind.resume,
              ))
                RadioListTile<String>(
                  value: document.id,
                  title: Text(document.title),
                ),
            ],
          ),
        ),
        if (_resumeId != null) Text(_tr('resumePrivate')),
      ],
    ],
  );

  Future<void> _editNewProject([PortfolioProject? project]) async {
    final values = await showBuilderRecordEditor(
      context,
      titleKey: project == null
          ? 'documentEditor.addProject'
          : 'documentEditor.editNewProject',
      fields: [
        BuilderFieldSpec(
          name: 'title',
          labelKey: 'builderForm.projectName',
          value: project?.title ?? '',
          required: true,
          maxLength: 120,
        ),
        BuilderFieldSpec(
          name: 'description',
          labelKey: 'builderForm.description',
          value: project?.description ?? '',
          kind: BuilderFieldKind.multiline,
          maxLength: 4000,
        ),
        BuilderFieldSpec(
          name: 'technologies',
          labelKey: 'builderForm.technologies',
          hintKey: 'builderForm.technologiesHint',
          value: project?.technologies.join(', ') ?? '',
          maxLength: 1238,
          validate: (context, value) {
            final technologies = _projectTechnologies(value);
            if (technologies.length > 20) {
              return context.strings.tr('builderForm.tooManyTechnologies', {
                'limit': 20,
              });
            }
            if (technologies.any((technology) => technology.length > 60)) {
              return context.strings.tr('builderForm.technologyTooLong', {
                'limit': 60,
              });
            }
            return null;
          },
        ),
        BuilderFieldSpec(
          name: 'repositoryUrl',
          labelKey: 'builderForm.repositoryUrl',
          value: project?.repositoryUrl ?? '',
          kind: BuilderFieldKind.url,
          maxLength: 2048,
        ),
        BuilderFieldSpec(
          name: 'liveUrl',
          labelKey: 'builderForm.liveUrl',
          value: project?.liveUrl ?? '',
          kind: BuilderFieldKind.url,
          maxLength: 2048,
        ),
      ],
    );
    if (!mounted || !_sameOwner || values == null) return;
    final id =
        project?.id ??
        ref.read(portfolioDraftControllerProvider.notifier).createId();
    final created = PortfolioProject(
      id: id,
      title: values['title']!.trim(),
      description: values['description']!.trim(),
      technologies: _projectTechnologies(values['technologies']!),
      repositoryUrl: values['repositoryUrl']!.trim(),
      liveUrl: values['liveUrl']!.trim(),
      updatedAt: DateTime.now().toUtc(),
    );
    _edit(() {
      final index = _newProjects.indexWhere((item) => item.id == id);
      if (index == -1) {
        _newProjects.add(created);
      } else {
        _newProjects[index] = created;
      }
      if (!_projects.any((item) => item.projectId == id)) {
        _projects.add(PortfolioProjectAttachment(projectId: id));
      }
    });
  }

  List<String> _projectTechnologies(String value) => [
    for (final part in value.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  Future<void> _addSkill() async {
    final values = await showBuilderRecordEditor(
      context,
      titleKey: 'documentEditor.skills',
      fields: [
        const BuilderFieldSpec(
          name: 'name',
          labelKey: 'documentEditor.skillName',
          maxLength: 80,
          required: true,
        ),
      ],
    );
    if (!mounted || !_sameOwner || values == null) return;
    _edit(
      () => _content = _content!.copyWith(
        skills: [
          ..._content!.skills,
          Skill(
            id: ref.read(portfolioDraftControllerProvider.notifier).createId(),
            name: values['name']!.trim(),
          ),
        ],
      ),
    );
  }

  Widget _attachment(PortfolioContent workspace, int index) {
    final relation = _projects[index];
    final project = workspace.projects
        .where((item) => item.id == relation.projectId)
        .firstOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: StackCardSpacing.sm),
      child: StackCardCard(
        key: ValueKey('document.attachment.${relation.projectId}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              project?.title ?? _tr('missing'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_tr('visible')),
              value: relation.visible,
              onChanged: (value) => _edit(
                () => _projects[index] = relation.copyWith(
                  visible: value ?? false,
                ),
              ),
            ),
            if (!_resume)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_tr('featured')),
                value: relation.featured,
                onChanged: (value) => _edit(
                  () => _projects[index] = relation.copyWith(
                    featured: value ?? false,
                  ),
                ),
              ),
            Wrap(
              spacing: StackCardSpacing.sm,
              children: [
                IconButton(
                  tooltip: _tr('moveUp'),
                  onPressed: index > 0 ? () => _moveProject(index, -1) : null,
                  icon: const StackCardIcon(name: 'arrow-up'),
                ),
                IconButton(
                  tooltip: _tr('moveDown'),
                  onPressed: index + 1 < _projects.length
                      ? () => _moveProject(index, 1)
                      : null,
                  icon: const StackCardIcon(name: 'arrow-down'),
                ),
                TextButton(
                  onPressed: () => _edit(() => _projects.removeAt(index)),
                  child: Text(_tr('detach')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _moveProject(int index, int offset) => _edit(() {
    final relation = _projects.removeAt(index);
    _projects.insert(index + offset, relation);
  });

  Widget _appearance() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RadioGroup<PortfolioTheme>(
        groupValue: _content!.theme,
        onChanged: (value) {
          if (value != null) {
            _edit(() => _content = _content!.copyWith(theme: value));
          }
        },
        child: Column(
          children: [
            RadioListTile<PortfolioTheme>(
              value: PortfolioTheme.dark,
              title: Text(_tr('dark')),
            ),
            RadioListTile<PortfolioTheme>(
              value: PortfolioTheme.light,
              title: Text(_tr('light')),
            ),
          ],
        ),
      ),
      for (var index = 0; index < _content!.blocks.length; index++) ...[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.strings.tr(
              'builder.block.${_content!.blocks[index].kind.name}',
            ),
          ),
          value: _content!.blocks[index].visible,
          onChanged: (visible) => _edit(() {
            final blocks = [..._content!.blocks];
            blocks[index] = blocks[index].copyWith(visible: visible ?? false);
            _content = _content!.copyWith(blocks: blocks);
          }),
        ),
        Row(
          children: [
            IconButton(
              tooltip: _tr('moveUp'),
              onPressed: index > 0 ? () => _moveBlock(index, -1) : null,
              icon: const StackCardIcon(name: 'arrow-up'),
            ),
            IconButton(
              tooltip: _tr('moveDown'),
              onPressed: index + 1 < _content!.blocks.length
                  ? () => _moveBlock(index, 1)
                  : null,
              icon: const StackCardIcon(name: 'arrow-down'),
            ),
          ],
        ),
      ],
    ],
  );

  void _moveBlock(int index, int offset) => _edit(() {
    final blocks = [..._content!.blocks];
    final block = blocks.removeAt(index);
    blocks.insert(index + offset, block);
    _content = _content!.copyWith(blocks: blocks);
  });

  Widget _preview(PortfolioContent workspace) {
    // Удалённая Library relation требует явного выбора, а не молчаливой потери.
    if (_projects.any(
      (entry) => !workspace.projects.any((item) => item.id == entry.projectId),
    )) {
      return _notice(_tr('conflict'));
    }
    final resolved = resolveDocumentContent(workspace, _document());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _fields!['title']!.text,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: StackCardSpacing.lg),
        if (_resume)
          _ResumePreview(content: resolved)
        else
          PortfolioContentView(content: resolved),
        if (!_resume && _resumeId != null) ...[
          const SizedBox(height: StackCardSpacing.lg),
          Text(
            _tr('attachResume'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            workspace.documents
                    .where((item) => item.id == _resumeId)
                    .firstOrNull
                    ?.title ??
                _tr('missing'),
          ),
          Text(_tr('resumePrivate')),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        StackCardButton(
          label: _tr('publish'),
          unavailableReason: _tr('publishUnavailable'),
        ),
      ],
    );
  }

  Widget _footer() {
    final wizardActions = _wizard && _step < 4;
    final actions = <Widget>[
      StackCardButton(
        key: const Key('document.previous'),
        label: _tr(_wizard ? 'back' : 'cancel'),
        onPressed: _saving || _mediaBusy
            ? null
            : _wizard
            ? _back
            : _requestExit,
      ),
      if (wizardActions)
        StackCardButton(
          key: const Key('document.skip'),
          label: _tr('skip'),
          role: StackCardButtonRole.quiet,
          onPressed: _step == 0 || _saving || _mediaBusy
              ? null
              : () => setState(() => _step++),
        ),
      StackCardButton(
        key: Key(wizardActions ? 'document.next' : 'document.save'),
        label: _tr(wizardActions ? 'next' : 'save'),
        primary: true,
        loading: _saving,
        onPressed: _saving || _mediaBusy || _conflicted()
            ? null
            : wizardActions
            ? () {
                if (_step != 0 || _validateProfile()) setState(() => _step++);
              }
            : (_dirty || _expected == null)
            ? () => _save(leave: true)
            : null,
      ),
    ];
    return ColoredBox(
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(StackCardSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _tr(
                      _saving
                          ? 'saving'
                          : _dirty || _expected == null
                          ? 'unsaved'
                          : 'saved',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow =
                          constraints.maxWidth < 320 ||
                          MediaQuery.textScalerOf(context).scale(1) >= 1.5;
                      if (narrow) {
                        return Wrap(
                          spacing: StackCardSpacing.sm,
                          runSpacing: StackCardSpacing.sm,
                          children: [
                            for (final action in actions)
                              SizedBox(
                                width:
                                    (constraints.maxWidth -
                                        StackCardSpacing.sm) /
                                    2,
                                child: action,
                              ),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (
                            var index = 0;
                            index < actions.length;
                            index++
                          ) ...[
                            if (index != 0)
                              const SizedBox(width: StackCardSpacing.sm),
                            Expanded(child: actions[index]),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Структурированное CV без dashboard, редакторских кнопок и private notes.
class _ResumePreview extends StatelessWidget {
  const _ResumePreview({required this.content});
  final PortfolioContent content;

  @override
  Widget build(BuildContext context) => Theme(
    data: content.theme == PortfolioTheme.dark
        ? StackCardTheme.dark
        : StackCardTheme.light,
    child: Builder(
      builder: (context) => ColoredBox(
        color: context.colors.background,
        child: Padding(
          padding: const EdgeInsets.all(StackCardSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final block in content.blocks.where((item) => item.visible))
                ..._block(context, block.kind),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _block(BuildContext context, PortfolioBlockKind kind) {
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(
        top: StackCardSpacing.lg,
        bottom: StackCardSpacing.md,
      ),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    );
    String tr(String key) => context.strings.tr('documentEditor.$key');
    return switch (kind) {
      PortfolioBlockKind.profile => [
        if (content.profile.avatarPath.isNotEmpty ||
            content.profile.avatarUrl.isNotEmpty) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: StackCardAvatar(
              url: content.profile.avatarUrl,
              image: content.profile.avatarPath.isEmpty
                  ? null
                  : PortfolioMediaImage(
                      path: content.profile.avatarPath,
                      width: 80,
                      height: 80,
                    ),
            ),
          ),
          const SizedBox(height: StackCardSpacing.md),
        ],
        Text(
          content.profile.name,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        Text(
          content.profile.headline,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
      PortfolioBlockKind.about =>
        content.profile.bio.isEmpty
            ? []
            : [
                const SizedBox(height: StackCardSpacing.md),
                Text(content.profile.bio),
              ],
      PortfolioBlockKind.location =>
        content.profile.locationText.isEmpty
            ? []
            : [heading(tr('location')), Text(content.profile.locationText)],
      PortfolioBlockKind.skills =>
        content.skills.isEmpty
            ? []
            : [
                heading(tr('skills')),
                Wrap(
                  spacing: StackCardSpacing.sm,
                  runSpacing: StackCardSpacing.sm,
                  children: [
                    for (final skill in content.skills)
                      StackCardTechnologyBadge(label: skill.name),
                  ],
                ),
              ],
      PortfolioBlockKind.experience =>
        content.experience.isEmpty
            ? []
            : [
                heading(tr('experience')),
                for (final item in content.experience) ...[
                  Text(
                    item.role,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${item.organization} · ${item.period}'),
                  Text(item.description),
                  const SizedBox(height: StackCardSpacing.md),
                ],
              ],
      PortfolioBlockKind.education =>
        content.education.isEmpty
            ? []
            : [
                heading(tr('education')),
                for (final item in content.education) ...[
                  Text(
                    item.qualification,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text('${item.institution} · ${item.period}'),
                  Text(item.description),
                  const SizedBox(height: StackCardSpacing.md),
                ],
              ],
      PortfolioBlockKind.links =>
        content.links.isEmpty
            ? []
            : [
                heading(tr('contacts')),
                for (final link in content.links)
                  Text('${link.label}: ${link.url}'),
              ],
      PortfolioBlockKind.featuredProjects =>
        content.projects.where((item) => item.visible).isEmpty
            ? []
            : [
                heading(tr('libraryProjects')),
                for (final project in content.projects.where(
                  (item) => item.visible,
                )) ...[
                  Text(
                    project.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(project.description),
                  Wrap(
                    spacing: StackCardSpacing.sm,
                    runSpacing: StackCardSpacing.sm,
                    children: [
                      for (final technology in project.technologies)
                        StackCardTechnologyBadge(label: technology),
                    ],
                  ),
                  if (project.liveUrl.isNotEmpty) Text(project.liveUrl),
                  if (project.repositoryUrl.isNotEmpty)
                    Text(project.repositoryUrl),
                  const SizedBox(height: StackCardSpacing.md),
                ],
              ],
      PortfolioBlockKind.resume =>
        content.resumeText.isEmpty
            ? []
            : [
                const SizedBox(height: StackCardSpacing.lg),
                Text(content.resumeText),
              ],
      PortfolioBlockKind.github => [],
    };
  }
}
