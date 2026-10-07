import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_draft.dart';
import '../domain/portfolio_sync.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_github_sync.dart' as github;
import '../../auth/auth.dart';
import '../portfolio_draft_providers.dart';
import 'portfolio_draft_state.dart';

// App session сохраняет введённые, но ещё не записанные заметки при навигации.
final portfolioDraftControllerProvider =
    NotifierProvider<PortfolioDraftController, PortfolioDraftState>(
      PortfolioDraftController.new,
    );

final portfolioWorkingContentProvider = Provider<PortfolioContent?>(
  (ref) => ref.watch(portfolioDraftControllerProvider).content,
);

class PortfolioDraftController extends Notifier<PortfolioDraftState> {
  int _generation = 0;
  int _idCounter = 0;
  int _sourceGeneration = 0;
  Object? _queuedDraft = _noDraftEvent;
  Future<void>? _loadOperation;

  PortfolioContent? get workingContent => state.content;

  @override
  PortfolioDraftState build() {
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    _loadOperation = null;
    _queuedDraft = _noDraftEvent;
    final initialRef = ref;
    final generation = ++_generation;
    final sourceGeneration = ++_sourceGeneration;
    if (repository is SyncPortfolioDraftRepository) {
      final subscription = repository.watchDraft().listen((draft) {
        if (!initialRef.mounted || sourceGeneration != _sourceGeneration) {
          return;
        }
        if (!state.loaded || state.loading || state.saving) {
          _queuedDraft = draft;
        } else {
          _acceptDurableDraft(draft);
        }
      });
      ref.onDispose(() {
        ++_sourceGeneration;
        unawaited(subscription.cancel());
      });
    }
    Future<void>.microtask(() async {
      if (initialRef.mounted && generation == _generation) await load();
    });
    return const PortfolioDraftState();
  }

  Future<void> load() {
    if (state.saving || state.loaded) return Future<void>.value();
    final loading = _loadOperation;
    if (loading != null) return loading;
    late final Future<void> operation;
    operation = _readDraft().whenComplete(() {
      if (identical(_loadOperation, operation)) _loadOperation = null;
    });
    _loadOperation = operation;
    return operation;
  }

  /// Read models ждут единое чтение до решения использовать demo fallback.
  Future<void> ensureLoaded() async {
    final operationRef = ref;
    if (state.loaded) return;
    // Providers могут ждать controller при собственном build; чтение начинает
    // microtask, чтобы mutation не происходила во время чужого provider build.
    await Future<void>.value();
    if (!operationRef.mounted) return;
    if (!state.loading) {
      final failure = state.failure;
      if (failure != null) throw failure;
    }
    await load();
    if (!operationRef.mounted) return;
    if (!state.loaded) throw state.failure ?? _unavailable;
  }

  Future<void> _readDraft() async {
    final operationRef = ref;
    final generation = ++_generation;
    final repository = ref.read(portfolioDraftRepositoryProvider);
    state = state.copyWith(loading: true, failure: null);
    try {
      final readDraft = await repository.read();
      if (!operationRef.mounted || generation != _generation) return;
      final draft = identical(_queuedDraft, _noDraftEvent)
          ? readDraft
          : _queuedDraft as PortfolioDraft?;
      _queuedDraft = _noDraftEvent;
      state = PortfolioDraftState(
        notes: draft?.notes ?? '',
        draft: draft,
        content: draft?.content,
        loading: false,
        loaded: true,
      );
    } on PortfolioDraftFailure catch (failure) {
      _loadFailure(operationRef, generation, failure);
    } catch (_) {
      _loadFailure(operationRef, generation, _unavailable);
    }
  }

  void editNotes(String notes) {
    updateNotes(notes);
  }

  void updateNotes(String notes) {
    if (!state.canEdit) return;
    state = state.copyWith(notes: notes, failure: null);
  }

  void startBuilder() {
    if (!state.canEdit || state.content != null) return;
    updateContent(PortfolioContent());
  }

  void updateContent(PortfolioContent content) {
    if (!state.canEdit) return;
    state = state.copyWith(content: content, failure: null);
  }

  String createId() =>
      '${DateTime.now().toUtc().microsecondsSinceEpoch}-${++_idCounter}';

  /// Сохраняет только выбранный документ; соседний ввод и notes остаются рабочими.
  Future<bool> saveDocument(
    PortfolioDocument document, {
    PortfolioDocument? expectedDocument,
    List<PortfolioProject> newProjects = const [],
    required PortfolioDraftRepository expectedRepository,
  }) => _saveScope(
    expectedRepository: expectedRepository,
    change: (content) {
      final existing = content.documents
          .where((item) => item.id == document.id)
          .firstOrNull;
      if (existing != expectedDocument) throw _conflict;
      final ids = content.projects.map((project) => project.id).toSet();
      for (final project in newProjects) {
        if (!ids.add(project.id)) throw _conflict;
      }
      return _withDocument(
        content.copyWith(projects: [...content.projects, ...newProjects]),
        document,
      );
    },
    mergeWorking: (content) {
      for (final project in newProjects) {
        content = _withProject(content, project);
      }
      return _withDocument(content, document);
    },
  );

  Future<bool> deleteDocument(
    PortfolioDocument document, {
    required PortfolioDraftRepository expectedRepository,
  }) => _saveScope(
    expectedRepository: expectedRepository,
    change: (content) {
      if (content.documents
              .where((item) => item.id == document.id)
              .firstOrNull !=
          document) {
        throw _conflict;
      }
      return _withoutDocument(content, document.id);
    },
    mergeWorking: (content) => _withoutDocument(content, document.id),
  );

  Future<bool> saveProject(
    PortfolioProject project, {
    PortfolioProject? expectedProject,
    required PortfolioDraftRepository expectedRepository,
  }) => _saveScope(
    expectedRepository: expectedRepository,
    change: (content) {
      if (content.projects.where((item) => item.id == project.id).firstOrNull !=
          expectedProject) {
        throw _conflict;
      }
      return _withProject(content, project);
    },
    mergeWorking: (content) => _withProject(content, project),
  );

  Future<bool> deleteProject(
    PortfolioProject project, {
    required PortfolioDraftRepository expectedRepository,
  }) => _saveScope(
    expectedRepository: expectedRepository,
    change: (content) {
      if (content.projects.where((item) => item.id == project.id).firstOrNull !=
          project) {
        throw _conflict;
      }
      return _withoutProject(content, project.id);
    },
    mergeWorking: (content) => _withoutProject(content, project.id),
  );

  Future<bool> importLegacyDocuments({
    required String portfolioTitle,
    required String resumeTitle,
    required PortfolioDraftRepository expectedRepository,
  }) {
    final now = DateTime.now().toUtc();
    PortfolioContent migrate(PortfolioContent content) {
      if (content.documents.isNotEmpty) return content;
      final snapshot = seedDocumentContent(content);
      final projects = [
        for (final project in content.projects)
          PortfolioProjectAttachment(
            projectId: project.id,
            visible: project.visible,
            featured: project.featured,
          ),
      ];
      return content.copyWith(
        documents: [
          PortfolioDocument(
            id: 'legacy-portfolio',
            title: portfolioTitle,
            kind: PortfolioDocumentKind.portfolio,
            createdAt: now,
            updatedAt: now,
            content: snapshot,
            projects: projects,
          ),
          if (content.resumeText.trim().isNotEmpty)
            PortfolioDocument(
              id: 'legacy-resume',
              title: resumeTitle,
              kind: PortfolioDocumentKind.resume,
              createdAt: now,
              updatedAt: now,
              content: snapshot,
              projects: projects,
            ),
        ],
      );
    }

    return _saveScope(
      expectedRepository: expectedRepository,
      change: migrate,
      mergeWorking: (content) => content,
    );
  }

  /// База профиля не переписывает snapshots уже созданных документов.
  Future<bool> saveDeveloperProfile({
    required PortfolioDraftRepository expectedRepository,
  }) {
    final working = state.content;
    if (working == null) return Future.value(false);
    final baseline = state.draft?.content ?? PortfolioContent();
    PortfolioContent base(PortfolioContent content) => content.copyWith(
      profile: working.profile,
      skills: working.skills,
      experience: working.experience,
      education: working.education,
      links: working.links,
    );
    return _saveScope(
      expectedRepository: expectedRepository,
      change: (content) {
        if (developerProfileData(content) != developerProfileData(baseline)) {
          throw _conflict;
        }
        return base(content);
      },
      // Новая правка базы во время записи не должна исчезать после ACK.
      mergeWorking: (content) => content,
    );
  }

  Future<bool> _saveScope({
    required PortfolioDraftRepository expectedRepository,
    required PortfolioContent Function(PortfolioContent) change,
    required PortfolioContent Function(PortfolioContent) mergeWorking,
  }) async {
    if (!state.canEdit ||
        state.saving ||
        !identical(
          ref.read(portfolioDraftRepositoryProvider),
          expectedRepository,
        )) {
      return false;
    }
    final operationRef = ref;
    final generation = ++_generation;
    final baseline = state.draft?.content ?? PortfolioContent();
    final baselineNotes = state.draft?.notes ?? '';
    state = state.copyWith(saving: true, failure: null);
    try {
      final durable = await expectedRepository.read();
      if (!operationRef.mounted || generation != _generation) return false;
      final savedContent = change(durable?.content ?? PortfolioContent());
      final draft = await expectedRepository.save(
        savedContent,
        expectedRevision: durable?.revision ?? 0,
        notes: durable?.notes ?? '',
      );
      if (!operationRef.mounted || generation != _generation) return false;
      state = state.copyWith(
        draft: draft,
        content: mergeWorking(
          _mergeWorkspace(
            baseline,
            draft.content ?? PortfolioContent(),
            state.content ?? baseline,
          ),
        ),
        notes: state.notes == baselineNotes ? draft.notes : state.notes,
        saving: false,
        remoteUpdateAvailable: false,
      );
      _acceptQueuedDraft();
      return true;
    } on PortfolioDraftFailure catch (failure) {
      _saveFailure(operationRef, generation, failure);
    } catch (_) {
      _saveFailure(operationRef, generation, _unavailable);
    }
    return false;
  }

  static PortfolioContent _withDocument(
    PortfolioContent content,
    PortfolioDocument document,
  ) => content.copyWith(
    documents: [
      for (final item in content.documents)
        if (item.id == document.id) document else item,
      if (!content.documents.any((item) => item.id == document.id)) document,
    ],
  );

  static PortfolioContent _withoutDocument(
    PortfolioContent content,
    String id,
  ) => content.copyWith(
    documents: [
      for (final item in content.documents)
        if (item.id != id)
          if (item.attachedResumeId == id)
            item.copyWith(clearAttachedResumeId: true)
          else
            item,
    ],
  );

  static PortfolioContent _withProject(
    PortfolioContent content,
    PortfolioProject project,
  ) => content.copyWith(
    projects: [
      for (final item in content.projects)
        if (item.id == project.id) project else item,
      if (!content.projects.any((item) => item.id == project.id)) project,
    ],
  );

  static PortfolioContent _withoutProject(
    PortfolioContent content,
    String id,
  ) => content.copyWith(
    projects: content.projects.where((item) => item.id != id).toList(),
    documents: [
      for (final document in content.documents)
        document.copyWith(
          projects: document.projects
              .where((item) => item.projectId != id)
              .toList(),
        ),
    ],
  );

  static const _conflict = PortfolioDraftFailure(
    PortfolioDraftFailureKind.conflict,
  );

  // Обновляет неизменённые slices из durable, сохраняя ввод соседних редакторов.
  static PortfolioContent _mergeWorkspace(
    PortfolioContent baseline,
    PortfolioContent saved,
    PortfolioContent working,
  ) => working.copyWith(
    profile: working.profile == baseline.profile
        ? saved.profile
        : working.profile,
    skills: listEquals(working.skills, baseline.skills)
        ? saved.skills
        : working.skills,
    experience: listEquals(working.experience, baseline.experience)
        ? saved.experience
        : working.experience,
    education: listEquals(working.education, baseline.education)
        ? saved.education
        : working.education,
    links: listEquals(working.links, baseline.links)
        ? saved.links
        : working.links,
    projects: listEquals(working.projects, baseline.projects)
        ? saved.projects
        : working.projects,
    documents: listEquals(working.documents, baseline.documents)
        ? saved.documents
        : working.documents,
    blocks: listEquals(working.blocks, baseline.blocks)
        ? saved.blocks
        : working.blocks,
    resumeText: working.resumeText == baseline.resumeText
        ? saved.resumeText
        : working.resumeText,
    theme: working.theme == baseline.theme ? saved.theme : working.theme,
    ignoredGitHubRepositories:
        listEquals(
          working.ignoredGitHubRepositories,
          baseline.ignoredGitHubRepositories,
        )
        ? saved.ignoredGitHubRepositories
        : working.ignoredGitHubRepositories,
  );

  bool addGitHubProject(
    github.GitHubProjectSource source, {
    DateTime? validatedAt,
    required PortfolioDraftRepository expectedRepository,
  }) => _applyGitHubAction(
    expectedRepository,
    (content) =>
        github.addGitHubProject(content, source, validatedAt: validatedAt),
  );

  bool acceptGitHubChanges(
    github.PortfolioGitHubReview review, {
    DateTime? validatedAt,
    required PortfolioDraftRepository expectedRepository,
  }) => _applyGitHubAction(
    expectedRepository,
    (content) => github.acceptGitHubProjectChanges(
      content,
      review,
      validatedAt: validatedAt,
    ),
  );

  bool ignoreGitHubRepository(
    github.GitHubProjectSource source, {
    required PortfolioDraftRepository expectedRepository,
  }) => _applyGitHubAction(
    expectedRepository,
    (content) => github.ignoreGitHubProject(content, source),
  );

  bool _applyGitHubAction(
    PortfolioDraftRepository expectedRepository,
    PortfolioContent Function(PortfolioContent content) action,
  ) {
    if (!state.canEdit ||
        state.saving ||
        !identical(
          ref.read(portfolioDraftRepositoryProvider),
          expectedRepository,
        )) {
      return false;
    }
    if (ref.read(accountAuthRepositoryProvider) != null) {
      final session = ref.read(accountSessionProvider);
      if (session.isLoading ||
          session.hasError ||
          !session.hasValue ||
          (session.value == null && !ref.read(guestAccessProvider))) {
        return false;
      }
    }
    try {
      final content = action(state.content ?? PortfolioContent());
      updateContent(content);
      return true;
    } on github.PortfolioGitHubFailure catch (failure) {
      state = state.copyWith(
        failure: PortfolioDraftFailure(
          failure.kind == github.PortfolioGitHubFailureKind.conflict
              ? PortfolioDraftFailureKind.conflict
              : PortfolioDraftFailureKind.invalidContent,
        ),
      );
      return false;
    }
  }

  /// Явное чтение заново отбрасывает только текущие несохранённые правки.
  Future<void> reload() async {
    if (state.saving) return;
    state = state.copyWith(loaded: false);
    await load();
  }

  Future<void> save() async {
    if (!state.canSave) return;
    final operationRef = ref;
    final generation = ++_generation;
    final notes = state.notes;
    final content = state.content;
    final expectedRevision = state.draft?.revision ?? 0;
    final repository = ref.read(portfolioDraftRepositoryProvider);
    state = state.copyWith(saving: true, failure: null);
    try {
      final draft = content == null
          ? await repository.saveNotes(notes)
          : await repository.save(
              content,
              expectedRevision: expectedRevision,
              notes: notes,
            );
      if (!operationRef.mounted || generation != _generation) return;
      // Новые правки во время save остаются unsaved, а сохранённая revision честная.
      state = state.copyWith(
        draft: draft,
        content: state.content == content ? draft.content : state.content,
        saving: false,
        remoteUpdateAvailable: false,
      );
      _acceptQueuedDraft();
    } on PortfolioDraftFailure catch (failure) {
      _saveFailure(operationRef, generation, failure);
    } catch (_) {
      _saveFailure(operationRef, generation, _unavailable);
    }
  }

  void _loadFailure(
    Ref operationRef,
    int generation,
    PortfolioDraftFailure failure,
  ) {
    if (!operationRef.mounted || generation != _generation) return;
    state = state.copyWith(loading: false, loaded: false, failure: failure);
  }

  void _saveFailure(
    Ref operationRef,
    int generation,
    PortfolioDraftFailure failure,
  ) {
    if (!operationRef.mounted || generation != _generation) return;
    state = state.copyWith(saving: false, failure: failure);
    _acceptQueuedDraft();
  }

  void _acceptQueuedDraft() {
    if (identical(_queuedDraft, _noDraftEvent)) return;
    final draft = _queuedDraft as PortfolioDraft?;
    _queuedDraft = _noDraftEvent;
    _acceptDurableDraft(draft);
  }

  void _acceptDurableDraft(PortfolioDraft? draft) {
    final previous = state.draft;
    final contentChanged =
        (previous?.notes ?? '') != (draft?.notes ?? '') ||
        previous?.content != draft?.content;
    if (state.hasUnsavedChanges) {
      // Advance the baseline while retaining input; Save is an explicit LWW choice.
      state = state.copyWith(
        draft: draft,
        remoteUpdateAvailable: state.remoteUpdateAvailable || contentChanged,
      );
      return;
    }
    state = state.copyWith(
      draft: draft,
      notes: draft?.notes ?? '',
      content: draft?.content,
      remoteUpdateAvailable: false,
    );
  }

  static const _noDraftEvent = Object();

  static const _unavailable = PortfolioDraftFailure(
    PortfolioDraftFailureKind.unavailable,
  );
}
