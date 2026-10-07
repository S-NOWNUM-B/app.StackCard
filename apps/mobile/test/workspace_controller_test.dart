import 'dart:async';

import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _date = DateTime.utc(2026, 10, 7);
PortfolioDocument _document(String id, {String role = 'Frontend'}) =>
    PortfolioDocument(
      id: id,
      title: id,
      kind: PortfolioDocumentKind.resume,
      createdAt: _date,
      updatedAt: _date,
      content: PortfolioContent(
        profile: PortfolioProfile(name: 'Stanislav', headline: role),
      ),
    );

Future<({ProviderContainer container, PortfolioDraftController controller})>
_scope(PortfolioDraftRepository repository) async {
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  final controller = container.read(portfolioDraftControllerProvider.notifier);
  await controller.ensureLoaded();
  return (container: container, controller: controller);
}

void main() {
  test('Base Save ignores concurrent legacy formatting while retaining its updates', () async {
    final repository = MemoryPortfolioDraftRepository();
    final initial = PortfolioContent(
      profile: const PortfolioProfile(name: 'Saved'),
    );
    await repository.save(initial, expectedRevision: 0, notes: '');
    final scope = await _scope(repository);
    scope.controller.updateContent(
      initial.copyWith(profile: const PortfolioProfile(name: 'New name')),
    );
    await repository.save(
      initial.copyWith(resumeText: 'External legacy resume'),
      expectedRevision: 1,
      notes: '',
    );
    expect(
      await scope.controller.saveDeveloperProfile(
        expectedRepository: repository,
      ),
      isTrue,
    );
    final saved = (await repository.read())!.content!;
    expect(saved.profile.name, 'New name');
    expect(saved.resumeText, 'External legacy resume');
    expect(
      scope.container.read(portfolioDraftControllerProvider).hasUnsavedChanges,
      isFalse,
    );
  });

  test(
    'Create-and-attach saves document and Library project in one revision',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final scope = await _scope(repository);
      final project = PortfolioProject(
        id: 'new-project',
        title: 'Backend API',
        description: '',
        technologies: const ['Java'],
        updatedAt: _date,
      );
      final document = _document('backend').copyWith(
        projects: [const PortfolioProjectAttachment(projectId: 'new-project')],
      );
      expect(
        await scope.controller.saveDocument(
          document,
          newProjects: [project],
          expectedRepository: repository,
        ),
        isTrue,
      );
      final saved = (await repository.read())!;
      expect(saved.revision, 1);
      expect(saved.content!.projects.single, project);
      expect(saved.content!.documents.single, document);
      expect(
        resolveDocumentContent(saved.content!, document).projects.single,
        project,
      );
      expect(
        scope.container
            .read(portfolioDraftControllerProvider)
            .hasUnsavedChanges,
        isFalse,
      );
    },
  );

  test('Create-and-attach conflict cannot save an orphan project or overwrite Library', () async {
    final repository = MemoryPortfolioDraftRepository();
    final project = PortfolioProject(
      id: 'existing',
      title: 'Existing',
      description: '',
      technologies: const [],
    );
    final initial = PortfolioContent(projects: [project]);
    await repository.save(initial, expectedRevision: 0, notes: '');
    final scope = await _scope(repository);
    expect(
      await scope.controller.saveDocument(
        _document('a').copyWith(
          projects: [const PortfolioProjectAttachment(projectId: 'existing')],
        ),
        newProjects: [project.copyWith(title: 'Collision')],
        expectedRepository: repository,
      ),
      isFalse,
    );
    final saved = (await repository.read())!;
    expect(saved.revision, 1);
    expect(saved.content, initial);
    expect(
      scope.container.read(portfolioDraftControllerProvider).failure!.kind,
      PortfolioDraftFailureKind.conflict,
    );
  });

  test('Document Save persists only its slice; unsaved base, project and notes stay working', () async {
    final repository = MemoryPortfolioDraftRepository();
    final base = PortfolioContent(
      profile: const PortfolioProfile(name: 'Saved base'),
      projects: [
        PortfolioProject(
          description: '',
          technologies: const [],
          id: 'p',
          title: 'Saved project',
        ),
      ],
      documents: [_document('a'), _document('b')],
    );
    await repository.save(base, expectedRevision: 0, notes: 'Saved notes');
    final scope = await _scope(repository);
    scope.controller.updateContent(
      base.copyWith(
        profile: const PortfolioProfile(name: 'Unsaved base'),
        projects: [base.projects.single.copyWith(title: 'Unsaved project')],
      ),
    );
    scope.controller.updateNotes('Unsaved notes');
    final edited = base.documents.first.copyWith(title: 'Frontend CV');
    expect(
      await scope.controller.saveDocument(
        edited,
        expectedDocument: base.documents.first,
        expectedRepository: repository,
      ),
      isTrue,
    );
    final durable = (await repository.read())!;
    expect(durable.notes, 'Saved notes');
    expect(durable.content!.profile.name, 'Saved base');
    expect(durable.content!.projects.single.title, 'Saved project');
    expect(durable.content!.documents.last, base.documents.last);
    final working = scope.container.read(portfolioDraftControllerProvider);
    expect(working.notes, 'Unsaved notes');
    expect(working.content!.profile.name, 'Unsaved base');
    expect(working.content!.projects.single.title, 'Unsaved project');
    expect(working.content!.documents.first, edited);
    expect(working.hasUnsavedChanges, isTrue);
  });

  test(
    'Independent document snapshots and duplicate references do not write base',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final scope = await _scope(repository);
      final one = _document('a');
      expect(
        await scope.controller.saveDocument(
          one,
          expectedRepository: repository,
        ),
        isTrue,
      );
      final two = one.copyWith(
        id: 'b',
        title: 'Backend',
        content: one.content.copyWith(
          profile: one.content.profile.copyWith(headline: 'Backend'),
        ),
      );
      expect(
        await scope.controller.saveDocument(
          two,
          expectedRepository: repository,
        ),
        isTrue,
      );
      final saved = (await repository.read())!.content!;
      expect(saved.documents.first.content.profile.headline, 'Frontend');
      expect(saved.documents.last.content.profile.headline, 'Backend');
      expect(saved.profile.name, isEmpty);
      expect(
        scope.container
            .read(portfolioDraftControllerProvider)
            .hasUnsavedChanges,
        isFalse,
      );
    },
  );

  test('Captured document conflict rejects stale overwrite and retains unsaved input', () async {
    final repository = MemoryPortfolioDraftRepository();
    final initial = PortfolioContent(documents: [_document('a')]);
    await repository.save(initial, expectedRevision: 0, notes: '');
    final scope = await _scope(repository);
    final changed = initial.copyWith(
      documents: [_document('a').copyWith(title: 'External')],
    );
    await repository.save(changed, expectedRevision: 1, notes: '');
    scope.controller.updateNotes('Retained');
    expect(
      await scope.controller.saveDocument(
        _document('a').copyWith(title: 'Stale'),
        expectedDocument: initial.documents.single,
        expectedRepository: repository,
      ),
      isFalse,
    );
    expect(
      (await repository.read())!.content!.documents.single.title,
      'External',
    );
    expect(
      scope.container.read(portfolioDraftControllerProvider).notes,
      'Retained',
    );
    expect(
      scope.container.read(portfolioDraftControllerProvider).failure!.kind,
      PortfolioDraftFailureKind.conflict,
    );
  });

  test(
    'Unrelated newer durable slice is merged and cannot disappear on next Save',
    () async {
      final repository = MemoryPortfolioDraftRepository();
      final initial = PortfolioContent(documents: [_document('a')]);
      await repository.save(initial, expectedRevision: 0, notes: '');
      final scope = await _scope(repository);
      await repository.save(
        initial.copyWith(documents: [_document('a'), _document('b')]),
        expectedRevision: 1,
        notes: 'External notes',
      );
      expect(
        await scope.controller.saveDocument(
          _document('a').copyWith(title: 'Edited'),
          expectedDocument: initial.documents.single,
          expectedRepository: repository,
        ),
        isTrue,
      );
      final state = scope.container.read(portfolioDraftControllerProvider);
      expect(state.content!.documents.map((item) => item.id), ['a', 'b']);
      expect(state.notes, 'External notes');
      expect(state.hasUnsavedChanges, isFalse);
    },
  );

  test('Project delete detaches all documents; document delete leaves shared Library', () async {
    final repository = MemoryPortfolioDraftRepository();
    final project = PortfolioProject(
      description: '',
      technologies: const [],
      id: 'p',
      title: 'Shared',
    );
    final doc = _document('a')
        .copyWith(projects: [const PortfolioProjectAttachment(projectId: 'p')]);
    final base = PortfolioContent(
      projects: [project],
      documents: [
        doc,
        doc.copyWith(id: 'b'),
      ],
    );
    await repository.save(base, expectedRevision: 0, notes: '');
    final scope = await _scope(repository);
    expect(
      await scope.controller.deleteDocument(
        doc,
        expectedRepository: repository,
      ),
      isTrue,
    );
    expect((await repository.read())!.content!.projects.single, project);
    expect(
      await scope.controller.deleteProject(
        project,
        expectedRepository: repository,
      ),
      isTrue,
    );
    final saved = (await repository.read())!.content!;
    expect(saved.projects, isEmpty);
    expect(saved.documents.single.id, 'b');
    expect(saved.documents.single.projects, isEmpty);
  });

  test('Explicit legacy conversion is stable and preserves original text and flags', () async {
    final repository = MemoryPortfolioDraftRepository();
    final base = PortfolioContent(
      profile: const PortfolioProfile(name: 'Legacy'),
      resumeText: 'Original text\nNo invented facts',
      projects: [
        PortfolioProject(
          description: '',
          technologies: const [],
          id: 'p',
          title: 'Hidden',
          visible: false,
          featured: true,
        ),
      ],
    );
    await repository.save(base, expectedRevision: 0, notes: 'Private notes');
    final scope = await _scope(repository);
    expect(
      await scope.controller.importLegacyDocuments(
        portfolioTitle: 'Portfolio',
        resumeTitle: 'Resume',
        expectedRepository: repository,
      ),
      isTrue,
    );
    final state = scope.container.read(portfolioDraftControllerProvider);
    expect(state.hasUnsavedChanges, isFalse);
    expect(state.content, (await repository.read())!.content);
    expect(state.content!.documents.length, 2);
    expect(state.content!.documents.last.content.resumeText, base.resumeText);
    expect(state.content!.documents.first.projects.single.visible, isFalse);
    expect(state.content!.documents.first.projects.single.featured, isTrue);
    expect((await repository.read())!.notes, 'Private notes');
  });

  test('Base Save does not alter existing document or save unrelated project/notes', () async {
    final repository = MemoryPortfolioDraftRepository();
    final base = PortfolioContent(
      documents: [_document('a')],
      projects: [
        PortfolioProject(
          description: '',
          technologies: const [],
          id: 'p',
          title: 'Saved',
        ),
      ],
    );
    await repository.save(base, expectedRevision: 0, notes: 'Saved notes');
    final scope = await _scope(repository);
    scope.controller.updateContent(
      base.copyWith(
        profile: const PortfolioProfile(name: 'New base'),
        projects: [base.projects.single.copyWith(title: 'Unsaved')],
      ),
    );
    scope.controller.updateNotes('Unsaved notes');
    expect(
      await scope.controller.saveDeveloperProfile(
        expectedRepository: repository,
      ),
      isTrue,
    );
    final saved = (await repository.read())!;
    expect(saved.content!.profile.name, 'New base');
    expect(saved.content!.documents.single, base.documents.single);
    expect(saved.content!.projects.single.title, 'Saved');
    expect(saved.notes, 'Saved notes');
    expect(
      scope.container.read(portfolioDraftControllerProvider).hasUnsavedChanges,
      isTrue,
    );
  });

  test(
    'Owner switch during authoritative read prevents writing either owner',
    () async {
      final first = _DelayedRepository();
      final second = MemoryPortfolioDraftRepository();
      final scope = await _scope(first);
      first.delayReads = true;
      final operation = scope.controller.saveDocument(
        _document('a'),
        expectedRepository: first,
      );
      scope.container.updateOverrides([
        portfolioDraftRepositoryProvider.overrideWithValue(second),
      ]);
      scope.container.read(portfolioDraftControllerProvider);
      await Future<void>.delayed(Duration.zero);
      first.readGate.complete(null);
      expect(await operation, isFalse);
      expect(first.writes, 0);
      expect(await second.read(), isNull);
    },
  );
}

class _DelayedRepository implements PortfolioDraftRepository {
  final delegate = MemoryPortfolioDraftRepository();
  final readGate = Completer<PortfolioDraft?>();
  bool delayReads = false;
  int writes = 0;
  @override
  Future<PortfolioDraft?> read() =>
      delayReads ? readGate.future : delegate.read();
  @override
  Future<PortfolioDraft> saveNotes(String notes) => delegate.saveNotes(notes);
  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) {
    writes++;
    return delegate.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }
}
