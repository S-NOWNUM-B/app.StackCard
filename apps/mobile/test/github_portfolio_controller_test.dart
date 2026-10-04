import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/github_import/github_import.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Explicit import keeps notes and other sections; Save owns persistence',
    () async {
      final repository = _TrackedRepository();
      final container = _container(repository);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.load();
      controller.updateNotes('Private note');
      controller.updateContent(
        PortfolioContent(
          profile: const PortfolioProfile(name: 'Owner'),
          skills: const [Skill(id: 'skill', name: 'Dart')],
        ),
      );
      final validatedAt = DateTime.utc(2026, 9, 30);
      expect(
        controller.addGitHubProject(
          _source(),
          validatedAt: validatedAt,
          expectedRepository: repository,
        ),
        isTrue,
      );
      expect(
        controller.addGitHubProject(
          _source(),
          validatedAt: validatedAt,
          expectedRepository: repository,
        ),
        isTrue,
      );
      final state = container.read(portfolioDraftControllerProvider);
      expect(state.content!.projects, hasLength(1));
      expect(state.content!.projects.single.lastGitHubSyncAt, validatedAt);
      expect(state.content!.profile.name, 'Owner');
      expect(state.content!.skills.single.name, 'Dart');
      expect(state.notes, 'Private note');
      expect(state.hasUnsavedChanges, isTrue);
      expect(repository.writes, 0);
      await controller.save();
      expect(repository.writes, 1);
      expect((await repository.read())!.content, state.content);
      expect((await repository.read())!.notes, 'Private note');
    },
  );

  test(
    'Stale review preserves newer input and fresh review retains overrides',
    () async {
      final repository = _TrackedRepository();
      final container = _container(repository);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.load();
      controller.addGitHubProject(_source(), expectedRepository: repository);
      final content = controller.workingContent!;
      final review = reviewGitHubProject(content, _source(name: 'renamed'));
      final original = content.projects.single;
      final edited = original.withUserEdits(
        original.copyWith(
          title: 'My title',
          description: 'My story',
          liveUrl: 'https://example.com',
        ),
      );
      controller.updateContent(content.copyWith(projects: [edited]));
      expect(
        controller.acceptGitHubChanges(review, expectedRepository: repository),
        isFalse,
      );
      expect(controller.workingContent!.projects.single, edited);
      final fresh = reviewGitHubProject(
        controller.workingContent!,
        review.source,
      );
      expect(
        controller.acceptGitHubChanges(fresh, expectedRepository: repository),
        isTrue,
      );
      final accepted = controller.workingContent!.projects.single;
      expect(accepted.title, 'My title');
      expect(accepted.description, 'My story');
      expect(accepted.liveUrl, 'https://example.com');
      expect(accepted.githubMetadata!.acceptedSource.name, 'renamed');
      expect(accepted.githubRepositoryId, 42);
      expect(repository.writes, 0);
    },
  );

  test(
    'Captured owner cannot import, accept or ignore after UID switch',
    () async {
      final auth = _AccountAuth(const AuthUser(uid: 'first'));
      addTearDown(auth.changes.close);
      final first = _TrackedRepository();
      final second = _TrackedRepository();
      final container = ProviderContainer(
        overrides: [
          accountAuthRepositoryProvider.overrideWithValue(auth),
          portfolioDraftRepositoryFactoryProvider.overrideWithValue(
            (uid) => uid == 'first' ? first : second,
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        githubPortfolioDraftStateProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.pump();
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.load();
      expect(
        controller.addGitHubProject(_source(), expectedRepository: first),
        isTrue,
      );
      final review = reviewGitHubProject(
        controller.workingContent!,
        _source(name: 'new'),
      );
      auth.emit(const AuthUser(uid: 'second'));
      await container.pump();
      final current = container.read(portfolioDraftControllerProvider.notifier);
      await current.load();
      expect(
        current.addGitHubProject(_source(), expectedRepository: first),
        isFalse,
      );
      expect(
        current.acceptGitHubChanges(review, expectedRepository: first),
        isFalse,
      );
      expect(
        current.ignoreGitHubRepository(_source(), expectedRepository: first),
        isFalse,
      );
      expect(current.workingContent, isNull);
      expect(second.writes, 0);
      expect(first.writes, 0);
    },
  );

  test(
    'Public browsing does not open guest storage without explicit access',
    () async {
      final auth = _AccountAuth();
      addTearDown(auth.changes.close);
      final guest = _TrackedRepository();
      var factoryCalls = 0;
      final container = ProviderContainer(
        overrides: [
          accountAuthRepositoryProvider.overrideWithValue(auth),
          portfolioDraftRepositoryFactoryProvider.overrideWithValue((uid) {
            ++factoryCalls;
            expect(uid, isNull);
            return guest;
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        githubPortfolioDraftStateProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await container.pump();
      expect(container.read(githubPortfolioDraftStateProvider), isNull);
      expect(factoryCalls, 0);
      container.read(guestAccessProvider.notifier).enter();
      await container.pump();
      await container.read(portfolioDraftControllerProvider.notifier).load();
      expect(
        container.read(githubPortfolioDraftStateProvider)!.canEdit,
        isTrue,
      );
      expect(factoryCalls, 1);
    },
  );

  test('Restoring and session errors never read a private draft', () async {
    final auth = _AccountAuth(null, false);
    addTearDown(auth.changes.close);
    var factoryCalls = 0;
    final container = ProviderContainer(
      overrides: [
        accountAuthRepositoryProvider.overrideWithValue(auth),
        portfolioDraftRepositoryFactoryProvider.overrideWithValue((_) {
          ++factoryCalls;
          return _TrackedRepository();
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      githubPortfolioDraftStateProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.pump();
    expect(container.read(githubPortfolioDraftStateProvider), isNull);
    auth.changes.addError(const AuthFailure(AuthFailureKind.unknown));
    await container.pump();
    expect(container.read(githubPortfolioDraftStateProvider), isNull);
    expect(factoryCalls, 0);
  });

  test('Unreadable draft cannot be replaced through a GitHub action', () async {
    final repository = _TrackedRepository(
      readFailure: const PortfolioDraftFailure(
        PortfolioDraftFailureKind.corrupted,
      ),
    );
    final container = _container(repository);
    final controller = container.read(
      portfolioDraftControllerProvider.notifier,
    );
    await controller.load();
    expect(
      controller.addGitHubProject(_source(), expectedRepository: repository),
      isFalse,
    );
    expect(
      controller.ignoreGitHubRepository(
        _source(),
        expectedRepository: repository,
      ),
      isFalse,
    );
    expect(controller.workingContent, isNull);
    expect(repository.writes, 0);
  });
}

ProviderContainer _container(PortfolioDraftRepository repository) {
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

GitHubProjectSource _source({String name = 'repository'}) =>
    GitHubProjectSource(
      repositoryId: 42,
      name: name,
      fullName: 'owner/$name',
      htmlUrl: 'https://github.com/owner/$name',
      description: 'Source description',
      language: 'Dart',
      stars: 1,
      forks: 0,
      isFork: false,
      archived: false,
      updatedAt: DateTime.utc(2026, 10, 4),
    );

class _TrackedRepository implements PortfolioDraftRepository {
  _TrackedRepository({this.readFailure});
  final PortfolioDraftFailure? readFailure;
  final memory = MemoryPortfolioDraftRepository();
  int writes = 0;
  @override
  Future<PortfolioDraft?> read() async {
    if (readFailure != null) throw readFailure!;
    return memory.read();
  }

  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) {
    ++writes;
    return memory.save(
      content,
      expectedRevision: expectedRevision,
      notes: notes,
    );
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) {
    ++writes;
    return memory.saveNotes(notes);
  }
}

class _AccountAuth implements AccountAuthRepository {
  _AccountAuth([this.current, this.emitInitial = true]);
  AuthUser? current;
  final bool emitInitial;
  final changes = StreamController<AuthUser?>.broadcast();
  @override
  Stream<AuthUser?> watchSession() => Stream.multi((controller) {
    if (emitInitial) controller.add(current);
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = subscription.cancel;
  });
  void emit(AuthUser? user) {
    current = user;
    changes.add(user);
  }

  @override
  Future<void> signInEmail(String email, String password) async {}
  @override
  Future<void> registerEmail(String email, String password) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signInGoogle() async {}
  @override
  Future<void> signOut() async => emit(null);
}
