import 'dart:async';

import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft_providers.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_draft_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 11);
PortfolioDocument _doc(String id, String name) => PortfolioDocument(
  id: id,
  title: name,
  kind: PortfolioDocumentKind.resume,
  createdAt: _now,
  updatedAt: _now,
  content: PortfolioContent(
    profile: PortfolioProfile(name: name, locationText: 'Private city'),
  ),
);
ProviderContainer _scope(PortfolioDraftRepository repository) {
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('Selected legacy document keeps ID/kind/archive without merging conflicting texts', () async {
    final repository = MemoryPortfolioDraftRepository();
    final a = _doc('a', 'Первый');
    final b = _doc('b', 'Второй');
    await repository.save(
      PortfolioContent(
        profile: const PortfolioProfile(name: 'База'),
        documents: [a, b],
      ),
      expectedRevision: 0,
      notes: 'private',
    );
    final scope = _scope(repository);
    final controller = scope.read(portfolioDraftControllerProvider.notifier);
    await controller.load();
    expect(
      await controller.initializeMainPortfolio(
        sourceDocumentId: 'b',
        expectedRepository: repository,
      ),
      isTrue,
    );
    final saved = (await repository.read())!;
    expect(saved.content!.mainPortfolioId, 'b');
    expect(saved.content!.legacyMainSnapshot, b);
    expect(saved.content!.documents.first, a);
    expect(
      mainPortfolioDocument(saved.content!)!.kind,
      PortfolioDocumentKind.resume,
    );
    expect(
      mainPortfolioDocument(saved.content!)!.content.profile.name,
      'Второй',
    );
    expect(
      mainPortfolioDocument(saved.content!)!.content.profile.locationText,
      isEmpty,
    );
    expect(saved.content!.profile.name, 'База');
    expect(saved.notes, 'private');
    await expectLater(
      repository.save(
        saved.content!.copyWith(clearLegacyMainSnapshot: true),
        expectedRevision: saved.revision,
        notes: saved.notes,
      ),
      throwsA(
        isA<PortfolioDraftFailure>().having(
          (failure) => failure.kind,
          'kind',
          PortfolioDraftFailureKind.conflict,
        ),
      ),
    );
    expect((await repository.read())!.content!.legacyMainSnapshot, b);
  });
  test(
    'Base selection retains twenty legacy documents plus one main',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final old = PortfolioContent(
        documents: [for (var i = 0; i < 20; i++) _doc('legacy-$i', 'Имя$i')],
      );
      await repository.save(old, expectedRevision: 0, notes: '');
      final scope = _scope(repository);
      final controller = scope.read(portfolioDraftControllerProvider.notifier);
      await controller.load();
      expect(
        await controller.initializeMainPortfolio(
          expectedRepository: repository,
        ),
        isTrue,
      );
      final saved = (await repository.read())!.content!;
      expect(saved.documents.length, 21);
      expect(saved.documents.take(20).toList(), old.documents);
      expect(mainPortfolioDocument(saved)!.content.profile.name, isEmpty);
    },
  );
  test('Migration rejects a workspace changed after preview', () async {
    final repository = MemoryPortfolioDraftRepository();
    final source = _doc('legacy', 'Previewed');
    final basis = PortfolioContent(documents: [source]);
    await repository.save(basis, expectedRevision: 0, notes: '');
    final scope = _scope(repository);
    final controller = scope.read(portfolioDraftControllerProvider.notifier);
    await controller.load();
    final remote = basis.copyWith(mainPortfolioId: source.id);
    await repository.save(remote, expectedRevision: 1, notes: '');
    expect(
      await controller.initializeMainPortfolio(
        sourceDocumentId: source.id,
        expectedWorkspace: basis,
        expectedRepository: repository,
      ),
      isFalse,
    );
    final saved = (await repository.read())!;
    expect(saved.revision, 2);
    expect(saved.content, remote);
    expect(
      scope.read(portfolioDraftControllerProvider).failure?.kind,
      PortfolioDraftFailureKind.conflict,
    );
  });
  test(
    'Empty onboarding steps persist progress/completion and do not restart',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final scope = _scope(repository);
      final controller = scope.read(portfolioDraftControllerProvider.notifier);
      await controller.load();
      expect(
        await controller.initializeMainPortfolio(
          newAccount: true,
          expectedRepository: repository,
        ),
        isTrue,
      );
      expect(
        (await repository.read())!.content!.personalization.status,
        PortfolioPersonalizationStatus.inProgress,
      );
      expect(
        await controller.savePersonalizationStep(
          step: 2,
          status: PortfolioPersonalizationStatus.inProgress,
          profile: const PortfolioProfile(),
          githubUsername: '',
          expectedRepository: repository,
        ),
        isTrue,
      );
      final restoredScope = _scope(repository);
      final restored = restoredScope.read(
        portfolioDraftControllerProvider.notifier,
      );
      await restored.load();
      expect(
        restoredScope
            .read(portfolioDraftControllerProvider)
            .draft!
            .content!
            .personalization
            .step,
        2,
      );
      expect(
        await restored.savePersonalizationStep(
          step: 3,
          status: PortfolioPersonalizationStatus.completed,
          expectedRepository: repository,
        ),
        isTrue,
      );
      expect(
        await restored.initializeMainPortfolio(
          newAccount: true,
          expectedRepository: repository,
        ),
        isTrue,
      );
      expect(
        (await repository.read())!.content!.personalization.status,
        PortfolioPersonalizationStatus.completed,
      );
      expect(
        mainPortfolioDocument((await repository.read())!.content!)!
            .content
            .profile
            .name,
        isEmpty,
      );
    },
  );
  test(
    'Batch import is durable, deduplicated and retains unrelated unsaved input',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final scope = _scope(repository);
      final controller = scope.read(portfolioDraftControllerProvider.notifier);
      await controller.load();
      await controller.initializeMainPortfolio(expectedRepository: repository);
      final saved = (await repository.read())!.content!;
      final main = mainPortfolioDocument(saved)!;
      controller.updateContent(
        saved.copyWith(
          documents: [
            main.copyWith(
              content: main.content.copyWith(
                profile: const PortfolioProfile(name: 'Не сохранено'),
              ),
            ),
          ],
        ),
      );
      controller.updateNotes('Unsaved note');
      expect(
        await controller.importSelectedGitHubRepositories(
          [_source(1), _source(2), _source(1)],
          validatedAt: {1: _now, 2: _now},
          expectedRepository: repository,
        ),
        isTrue,
      );
      final imported = (await repository.read())!.content!;
      expect(imported.projects.map((project) => project.githubRepositoryId), [
        1,
        2,
      ]);
      expect(mainPortfolioDocument(imported)!.projects, isEmpty);
      expect(mainPortfolioDocument(imported)!.content.profile.name, isEmpty);
      expect((await repository.read())!.notes, isEmpty);
      final working = scope.read(portfolioDraftControllerProvider);
      expect(
        mainPortfolioDocument(working.content!)!.content.profile.name,
        'Не сохранено',
      );
      expect(working.notes, 'Unsaved note');
      expect(working.hasUnsavedChanges, isTrue);
      final project = imported.projects.first;
      await controller.saveProject(
        project.withUserEdits(
          project.copyWith(title: 'Ручное имя', iconId: 'home'),
        ),
        expectedProject: project,
        expectedRepository: repository,
      );
      expect(
        await controller.importSelectedGitHubRepositories([
          _source(1, name: 'Changed'),
        ], expectedRepository: repository),
        isTrue,
      );
      expect(
        (await repository.read())!.content!.projects.first.title,
        'Ручное имя',
      );
      expect((await repository.read())!.content!.projects.first.iconId, 'home');
      final reopened = _scope(repository);
      await reopened.read(portfolioDraftControllerProvider.notifier).load();
      expect(
        reopened
            .read(portfolioDraftControllerProvider)
            .content!
            .projects
            .length,
        2,
      );
    },
  );
  test('Main Save atomically writes document, GitHub and icons; invalid values change nothing', () async {
    final repository = MemoryPortfolioDraftRepository();
    final scope = _scope(repository);
    final controller = scope.read(portfolioDraftControllerProvider.notifier);
    await controller.load();
    await controller.initializeMainPortfolio(expectedRepository: repository);
    await controller.importSelectedGitHubRepositories([
      _source(1),
    ], expectedRepository: repository);
    final original = mainPortfolioDocument(
      (await repository.read())!.content!,
    )!;
    final invalid = original.copyWith(
      content: original.content.copyWith(
        profile: PortfolioProfile(headline: 'x' * 161),
      ),
    );
    expect(
      await controller.saveMainPortfolio(
        invalid,
        expectedDocument: original,
        githubUsername: 'https://github.com/owner',
        projectIconUpdates: const {'github-1': 'camera'},
        expectedRepository: repository,
      ),
      isFalse,
    );
    final unchanged = (await repository.read())!.content!;
    expect(mainPortfolioDocument(unchanged), original);
    expect(unchanged.githubUsername, isEmpty);
    expect(unchanged.projects.single.iconId, 'folder');
    expect(
      await controller.saveMainPortfolio(
        original.copyWith(
          projects: const [PortfolioProjectAttachment(projectId: 'github-1')],
        ),
        expectedDocument: original,
        githubUsername: 'https://github.com/OWNER/',
        projectIconUpdates: const {'github-1': 'camera'},
        expectedRepository: repository,
      ),
      isTrue,
    );
    final saved = (await repository.read())!.content!;
    expect(saved.githubUsername, 'owner');
    expect(saved.projects.single.iconId, 'camera');
    expect(mainPortfolioDocument(saved)!.projects.single.projectId, 'github-1');
  });
  test('Main Save rejects a stale GitHub field baseline after a scoped identity update', () async {
    final repository = MemoryPortfolioDraftRepository();
    final original = _doc('main', 'Saved');
    final project = PortfolioProject(
      id: 'p',
      title: 'Project',
      description: '',
      technologies: const [],
    );
    final workspace = PortfolioContent(
      mainPortfolioId: 'main',
      githubUsername: 'old-owner',
      documents: [original],
      projects: [project],
    );
    await repository.save(workspace, expectedRevision: 0, notes: 'private');
    final scope = _scope(repository);
    final controller = scope.read(portfolioDraftControllerProvider.notifier);
    await controller.load();
    final edited = original.copyWith(
      content: original.content.copyWith(
        profile: const PortfolioProfile(name: 'Unsaved main input'),
      ),
    );
    controller.updateContent(
      workspace.copyWith(
        documents: [edited],
        githubUsername: 'my-edited-owner',
      ),
    );
    controller.updateNotes('Unsaved private note');
    expect(
      await controller.saveGitHubIdentity(
        'other-owner',
        expectedRepository: repository,
      ),
      isTrue,
    );
    final before = (await repository.read())!;
    expect(
      await controller.saveMainPortfolio(
        edited,
        expectedDocument: original,
        githubUsername: 'my-edited-owner',
        expectedGitHubUsername: 'old-owner',
        projectIconUpdates: const {'p': 'camera'},
        expectedRepository: repository,
      ),
      isFalse,
    );
    final durable = (await repository.read())!;
    expect(durable, before);
    expect(durable.content!.githubUsername, 'other-owner');
    expect(mainPortfolioDocument(durable.content!), original);
    expect(durable.content!.projects.single.iconId, 'folder');
    final state = scope.read(portfolioDraftControllerProvider);
    expect(state.failure?.kind, PortfolioDraftFailureKind.conflict);
    expect(mainPortfolioDocument(state.content!), edited);
    expect(state.content!.githubUsername, 'my-edited-owner');
    expect(state.notes, 'Unsaved private note');
    expect(state.hasUnsavedChanges, isTrue);
  });

  test('Main Save checks the captured GitHub baseline against authoritative repository data', () async {
    final repository = MemoryPortfolioDraftRepository();
    final original = _doc('main', 'Saved');
    final workspace = PortfolioContent(
      mainPortfolioId: 'main',
      githubUsername: 'old-owner',
      documents: [original],
    );
    final initial = await repository.save(
      workspace,
      expectedRevision: 0,
      notes: 'private',
    );
    final scope = _scope(repository);
    final controller = scope.read(portfolioDraftControllerProvider.notifier);
    await controller.load();
    final updated = await repository.save(
      workspace.copyWith(githubUsername: 'remote-owner'),
      expectedRevision: initial.revision,
      notes: initial.notes,
    );
    expect(
      await controller.saveMainPortfolio(
        original,
        expectedDocument: original,
        githubUsername: 'old-owner',
        expectedGitHubUsername: 'old-owner',
        expectedRepository: repository,
      ),
      isFalse,
    );
    expect(await repository.read(), updated);
    expect(
      scope.read(portfolioDraftControllerProvider).failure?.kind,
      PortfolioDraftFailureKind.conflict,
    );
  });

  test(
    'Main Save without a GitHub change retains the newly saved identity',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final original = _doc('main', 'Saved');
      await repository.save(
        PortfolioContent(
          mainPortfolioId: 'main',
          githubUsername: 'old-owner',
          documents: [original],
        ),
        expectedRevision: 0,
        notes: 'private',
      );
      final scope = _scope(repository);
      final controller = scope.read(portfolioDraftControllerProvider.notifier);
      await controller.load();
      expect(
        await controller.saveGitHubIdentity(
          'new-owner',
          expectedRepository: repository,
        ),
        isTrue,
      );
      final edited = original.copyWith(
        content: original.content.copyWith(
          profile: const PortfolioProfile(name: 'New name'),
        ),
      );
      expect(
        await controller.saveMainPortfolio(
          edited,
          expectedDocument: original,
          expectedRepository: repository,
        ),
        isTrue,
      );
      final durable = (await repository.read())!;
      expect(durable.content!.githubUsername, 'new-owner');
      expect(mainPortfolioDocument(durable.content!), edited);
      expect(durable.notes, 'private');
    },
  );

  test(
    'Project deletion detaches from main and keeps immutable original archive',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final project = PortfolioProject(
        id: 'p',
        title: 'Проект',
        description: '',
        technologies: const [],
      );
      final old = _doc(
        'a',
        'Автор',
      ).copyWith(projects: const [PortfolioProjectAttachment(projectId: 'p')]);
      await repository.save(
        PortfolioContent(projects: [project], documents: [old]),
        expectedRevision: 0,
        notes: '',
      );
      final scope = _scope(repository);
      final controller = scope.read(portfolioDraftControllerProvider.notifier);
      await controller.load();
      await controller.initializeMainPortfolio(
        sourceDocumentId: 'a',
        expectedRepository: repository,
      );
      expect(
        await controller.deleteProject(project, expectedRepository: repository),
        isTrue,
      );
      final saved = (await repository.read())!.content!;
      expect(saved.projects, isEmpty);
      expect(mainPortfolioDocument(saved)!.projects, isEmpty);
      expect(saved.legacyMainSnapshot, old);
    },
  );
  test(
    'Main save captures icon selection and preserves newer document input',
    () async {
      final repository = _DelayedRepository();
      final project = PortfolioProject(
        id: 'p',
        title: 'Project',
        description: '',
        technologies: const [],
      );
      final original = _doc('main', 'Saved');
      final workspace = PortfolioContent(
        projects: [project],
        documents: [original],
        mainPortfolioId: 'main',
      );
      await repository.delegate.save(workspace, expectedRevision: 0, notes: '');
      final scope = _scope(repository);
      final controller = scope.read(portfolioDraftControllerProvider.notifier);
      await controller.load();
      final icons = {'p': 'camera'};
      final captured = original.copyWith(
        content: original.content.copyWith(
          profile: const PortfolioProfile(name: 'Captured'),
        ),
      );
      final saving = controller.saveMainPortfolio(
        captured,
        expectedDocument: original,
        projectIconUpdates: icons,
        expectedRepository: repository,
      );
      await repository.started.future;
      icons['p'] = 'home';
      final newer = original.copyWith(
        content: original.content.copyWith(
          profile: const PortfolioProfile(name: 'Later input'),
        ),
      );
      controller.updateContent(workspace.copyWith(documents: [newer]));
      repository.release.complete();
      expect(await saving, isTrue);
      expect(
        mainPortfolioDocument((await repository.read())!.content!)!
            .content
            .profile
            .name,
        'Captured',
      );
      expect(
        (await repository.read())!.content!.projects.single.iconId,
        'camera',
      );
      final state = scope.read(portfolioDraftControllerProvider);
      expect(
        mainPortfolioDocument(state.content!)!.content.profile.name,
        'Later input',
      );
      expect(state.hasUnsavedChanges, isTrue);
    },
  );

  test(
    'Hidden legacy project block stays only in backup after migration',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final project = PortfolioProject(
        id: 'p',
        title: 'Hidden',
        description: '',
        technologies: const [],
      );
      final source = _doc('legacy', 'Name').copyWith(
        projects: const [PortfolioProjectAttachment(projectId: 'p')],
        content: PortfolioContent(
          blocks: PortfolioBlockKind.values
              .map(
                (kind) => PortfolioBlock(
                  kind: kind,
                  visible: kind != PortfolioBlockKind.featuredProjects,
                ),
              )
              .toList(),
        ),
      );
      await repository.save(
        PortfolioContent(projects: [project], documents: [source]),
        expectedRevision: 0,
        notes: '',
      );
      final scope = _scope(repository);
      final controller = scope.read(portfolioDraftControllerProvider.notifier);
      await controller.load();
      expect(
        await controller.initializeMainPortfolio(
          sourceDocumentId: 'legacy',
          expectedRepository: repository,
        ),
        isTrue,
      );
      final content = (await repository.read())!.content!;
      expect(mainPortfolioDocument(content)!.projects, isEmpty);
      expect(content.legacyMainSnapshot!.projects.single.projectId, 'p');
    },
  );

  test('A late batch save cannot replace another repository session', () async {
    final repository = _DelayedRepository();
    final scope = _scope(repository);
    final controller = scope.read(portfolioDraftControllerProvider.notifier);
    await controller.load();
    final importing = controller.importSelectedGitHubRepositories([
      _source(1),
    ], expectedRepository: repository);
    await repository.started.future;
    final other = MemoryPortfolioDraftRepository();
    scope.updateOverrides([
      portfolioDraftRepositoryProvider.overrideWithValue(other),
    ]);
    await scope.pump();
    await scope.read(portfolioDraftControllerProvider.notifier).load();
    repository.release.complete();
    expect(await importing, isFalse);
    expect(scope.read(portfolioDraftControllerProvider).content, isNull);
    expect(await other.read(), isNull);
    expect(
      (await repository.read())!.content!.projects.single.githubRepositoryId,
      1,
    );
  });
}

GitHubProjectSource _source(int id, {String name = 'Repository'}) =>
    GitHubProjectSource(
      repositoryId: id,
      name: name,
      fullName: 'owner/$name',
      htmlUrl: 'https://github.com/owner/$name',
      stars: 0,
      forks: 0,
      isFork: false,
      archived: false,
      updatedAt: _now,
    );

final class _DelayedRepository implements PortfolioDraftRepository {
  final delegate = MemoryPortfolioDraftRepository();
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<PortfolioDraft?> read() => delegate.read();
  @override
  Future<PortfolioDraft> saveNotes(String notes) => delegate.saveNotes(notes);
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) async {
    started.complete();
    await release.future;
    return delegate.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }
}
