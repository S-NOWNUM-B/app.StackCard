import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Suggestions follow working edits without saving or mutating the draft',
    () async {
      final repository = _TrackedRepository();
      final container = ProviderContainer(
        overrides: [
          portfolioDraftRepositoryProvider.overrideWithValue(repository),
          portfolioSuggestionClockProvider.overrideWithValue(
            () => DateTime.utc(2026, 10, 4),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.load();
      controller.updateContent(PortfolioContent(projects: [_project()]));
      controller.updateNotes('Private note');
      final before = container.read(portfolioDraftControllerProvider);
      expect(
        container.read(portfolioSuggestionsProvider).map((item) => item.kind),
        [
          PortfolioSuggestionKind.missingDescription,
          PortfolioSuggestionKind.missingPreview,
        ],
      );
      expect(container.read(portfolioDraftControllerProvider), same(before));
      expect(repository.writes, 0);
      expect(await repository.read(), isNull);

      controller.updateContent(
        before.content!.copyWith(
          projects: [_project().copyWith(description: 'My description')],
        ),
      );
      expect(
        container.read(portfolioSuggestionsProvider).map((item) => item.kind),
        [PortfolioSuggestionKind.missingPreview],
      );
      expect(repository.writes, 0);
      expect(
        controller.workingContent!.projects.single.description,
        'My description',
      );
    },
  );

  test(
    'Empty legacy content and failed reads do not produce demo advice',
    () async {
      for (final failRead in [false, true]) {
        final repository = _TrackedRepository(failRead: failRead);
        final container = ProviderContainer(
          overrides: [
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
          ],
        );
        final subscription = container.listen(
          portfolioSuggestionsProvider,
          (_, _) {},
        );
        expect(container.read(portfolioSuggestionsProvider), isEmpty);
        await container.read(portfolioDraftControllerProvider.notifier).load();
        expect(container.read(portfolioSuggestionsProvider), isEmpty);
        expect(repository.writes, 0);
        subscription.close();
        container.dispose();
      }
    },
  );

  test('Unauthorized suggestion reads never open private storage', () async {
    final auth = _Auth();
    addTearDown(auth.changes.close);
    final repository = _TrackedRepository();
    var factoryCalls = 0;
    final container = ProviderContainer(
      overrides: [
        accountAuthRepositoryProvider.overrideWithValue(auth),
        portfolioDraftRepositoryFactoryProvider.overrideWithValue((uid) {
          ++factoryCalls;
          return repository;
        }),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      portfolioSuggestionsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    expect(container.read(portfolioSuggestionsProvider), isEmpty);
    await container.pump();
    expect(container.read(portfolioSuggestionsProvider), isEmpty);
    expect(factoryCalls, 0);
    expect(repository.reads, 0);

    container.read(guestAccessProvider.notifier).enter();
    await container.pump();
    await container.read(portfolioDraftControllerProvider.notifier).load();
    container
        .read(portfolioDraftControllerProvider.notifier)
        .updateContent(PortfolioContent(projects: [_project()]));
    expect(container.read(portfolioSuggestionsProvider), hasLength(2));
    expect(factoryCalls, 1);
    expect(repository.writes, 0);
  });

  test('Switching UID discards the previous owner suggestions', () async {
    final auth = _Auth(const AuthUser(uid: 'first'));
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
      portfolioSuggestionsProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await container.pump();
    final controller = container.read(
      portfolioDraftControllerProvider.notifier,
    );
    await controller.load();
    controller.updateContent(PortfolioContent(projects: [_project()]));
    expect(container.read(portfolioSuggestionsProvider), hasLength(2));

    auth.emit(const AuthUser(uid: 'second'));
    await container.pump();
    await container.read(portfolioDraftControllerProvider.notifier).load();
    expect(container.read(portfolioSuggestionsProvider), isEmpty);
    expect(container.read(portfolioWorkingContentProvider), isNull);
    expect(first.writes, 0);
    expect(second.writes, 0);
  });

  test('Injected clock controls activity without source reads', () async {
    var now = DateTime.utc(2026, 10, 4);
    final container = ProviderContainer(
      overrides: [
        portfolioSuggestionClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(
      portfolioDraftControllerProvider.notifier,
    );
    await controller.load();
    final source = GitHubProjectSource(
      repositoryId: 42,
      name: 'portfolio',
      fullName: 'owner/portfolio',
      htmlUrl: 'https://github.com/owner/portfolio',
      stars: 0,
      forks: 0,
      isFork: false,
      archived: false,
      updatedAt: DateTime.utc(2026, 10, 4),
    );
    controller.updateContent(addGitHubProject(PortfolioContent(), source));
    expect(
      container
          .read(portfolioSuggestionsProvider)
          .any((item) => item.kind == PortfolioSuggestionKind.recentActivity),
      isTrue,
    );
    now = DateTime.utc(2027, 10, 4);
    container.invalidate(portfolioSuggestionsProvider);
    final kinds = container
        .read(portfolioSuggestionsProvider)
        .map((item) => item.kind);
    expect(kinds, contains(PortfolioSuggestionKind.inactiveProject));
    expect(kinds, isNot(contains(PortfolioSuggestionKind.recentActivity)));
  });
}

PortfolioProject _project() => PortfolioProject(
  id: 'manual',
  title: 'Manual project',
  description: '',
  technologies: const [],
);

class _TrackedRepository implements PortfolioDraftRepository {
  _TrackedRepository({this.failRead = false});
  final bool failRead;
  final memory = MemoryPortfolioDraftRepository();
  int reads = 0;
  int writes = 0;

  @override
  Future<PortfolioDraft?> read() async {
    ++reads;
    if (failRead) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.corrupted);
    }
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

class _Auth implements AccountAuthRepository {
  _Auth([this.current]);
  AuthUser? current;
  final changes = StreamController<AuthUser?>.broadcast();
  @override
  Stream<AuthUser?> watchSession() => Stream.multi((controller) {
    controller.add(current);
    final subscription = changes.stream.listen(
      controller.add,
      onError: controller.addError,
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
