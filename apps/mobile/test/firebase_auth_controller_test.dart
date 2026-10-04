import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ControlledRepository implements AccountAuthRepository {
  final sessions = StreamController<AuthUser?>.broadcast();
  final requests = <String>[];
  Completer<void>? pending;
  Object? failure;

  @override
  Stream<AuthUser?> watchSession() => sessions.stream;

  Future<void> _action(String request) async {
    requests.add(request);
    if (pending != null) await pending!.future;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signInEmail(String email, String password) => _action(email);

  @override
  Future<void> registerEmail(String email, String password) => _action(email);

  @override
  Future<void> sendPasswordReset(String email) => _action(email);

  @override
  Future<void> signInGoogle() => _action('google');

  @override
  Future<void> signOut() => _action('signOut');
}

void main() {
  late _ControlledRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = _ControlledRepository();
    container = ProviderContainer(
      overrides: [accountAuthRepositoryProvider.overrideWithValue(repository)],
    );
  });
  tearDown(() async {
    container.dispose();
    await repository.sessions.close();
  });

  test(
    'Absent Firebase is signed out and rejects account commands safely',
    () async {
      final local = ProviderContainer();
      addTearDown(local.dispose);
      final subscription = local.listen(accountSessionProvider, (_, _) {});
      addTearDown(subscription.close);
      expect(await local.read(accountSessionProvider.future), isNull);
      expect(local.read(accountAuthControllerProvider).hasValue, isTrue);
      expect(
        await local.read(accountAuthControllerProvider.notifier).signInGoogle(),
        isFalse,
      );
      expect(
        (local.read(accountAuthControllerProvider).error as AuthFailure).kind,
        AuthFailureKind.configuration,
      );
    },
  );

  test('Session stream alone determines the authenticated account', () async {
    final subscription = container.listen(accountSessionProvider, (_, _) {});
    addTearDown(subscription.close);
    expect(container.read(accountSessionProvider).isLoading, isTrue);
    const account = AuthUser(uid: 'owner', email: 'owner@example.dev');
    repository.sessions.add(account);
    expect(await container.read(accountSessionProvider.future), account);
    final controller = container.read(accountAuthControllerProvider.notifier);
    expect(await controller.signOut(), isTrue);
    expect(container.read(accountSessionProvider).requireValue, account);
    repository.sessions.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(accountSessionProvider).requireValue, isNull);
  });

  test(
    'Duplicate commands are blocked and password is absent from state',
    () async {
      repository.pending = Completer<void>();
      final controller = container.read(accountAuthControllerProvider.notifier);
      final result = controller.signInEmail(' owner@example.dev ', 'secret');
      expect(container.read(accountAuthControllerProvider).isLoading, isTrue);
      expect(await controller.signInGoogle(), isFalse);
      expect(repository.requests, ['owner@example.dev']);
      expect(
        container.read(accountAuthControllerProvider).toString(),
        isNot(contains('secret')),
      );
      repository.pending!.complete();
      expect(await result, isTrue);
      expect(container.read(accountAuthControllerProvider).hasValue, isTrue);
    },
  );

  test('Unknown errors are sanitized and clearError allows retry', () async {
    repository.failure = StateError('secret password and internal token');
    final controller = container.read(accountAuthControllerProvider.notifier);
    expect(
      await controller.registerEmail('owner@example.dev', 'secret'),
      isFalse,
    );
    final state = container.read(accountAuthControllerProvider);
    expect((state.error as AuthFailure).kind, AuthFailureKind.unknown);
    expect(state.toString(), isNot(contains('secret')));
    expect(state.stackTrace, StackTrace.empty);
    controller.clearError();
    repository.failure = null;
    expect(await controller.sendPasswordReset(' owner@example.dev '), isTrue);
  });

  test(
    'Google cancellation is silent and typed errors are preserved',
    () async {
      repository.failure = const AuthFailure(AuthFailureKind.cancelled);
      final controller = container.read(accountAuthControllerProvider.notifier);
      expect(await controller.signInGoogle(), isFalse);
      expect(container.read(accountAuthControllerProvider).hasError, isFalse);
      repository.failure = const AuthFailure(AuthFailureKind.network);
      expect(await controller.signInGoogle(), isFalse);
      expect(
        (container.read(accountAuthControllerProvider).error as AuthFailure)
            .kind,
        AuthFailureKind.network,
      );
    },
  );

  test(
    'A late completion cannot update a disposed or replaced controller',
    () async {
      repository.pending = Completer<void>();
      final controller = container.read(accountAuthControllerProvider.notifier);
      final result = controller.signInGoogle();
      container.invalidate(accountAuthControllerProvider);
      expect(container.read(accountAuthControllerProvider).hasValue, isTrue);
      repository.pending!.complete();
      expect(await result, isFalse);
      expect(container.read(accountAuthControllerProvider).hasValue, isTrue);
    },
  );

  test(
    'Guest access is explicit and never creates an account identity',
    () async {
      expect(container.read(guestAccessProvider), isFalse);
      container.read(guestAccessProvider.notifier).enter();
      expect(container.read(guestAccessProvider), isTrue);
      expect(container.read(accountSessionProvider).isLoading, isTrue);
      container.read(guestAccessProvider.notifier).leave();
      expect(container.read(guestAccessProvider), isFalse);
    },
  );

  test(
    'Pending account command cannot update a disposed app session',
    () async {
      final local = ProviderContainer(
        overrides: [
          accountAuthRepositoryProvider.overrideWithValue(repository),
        ],
      );
      repository.pending = Completer<void>();
      final result = local
          .read(accountAuthControllerProvider.notifier)
          .signInGoogle();
      local.dispose();
      repository.pending!.complete();
      expect(await result, isFalse);
    },
  );

  test('Account sign in and sign out revoke previous guest access', () async {
    final guest = container.read(guestAccessProvider.notifier);
    final controller = container.read(accountAuthControllerProvider.notifier);
    guest.enter();
    expect(await controller.signInEmail('owner@example.dev', 'secret'), isTrue);
    expect(container.read(guestAccessProvider), isFalse);
    guest.enter();
    repository.pending = Completer<void>();
    final result = controller.signOut();
    expect(container.read(guestAccessProvider), isFalse);
    repository.pending!.complete();
    expect(await result, isTrue);
  });

  test('AuthUser value equality includes nullable identity details', () {
    expect(const AuthUser(uid: 'owner'), const AuthUser(uid: 'owner'));
    expect(const AuthUser(uid: 'owner'), isNot(const AuthUser(uid: 'other')));
    expect(
      const AuthUser(uid: 'owner', email: 'a@example.dev'),
      isNot(const AuthUser(uid: 'owner')),
    );
    expect(
      const AuthUser(uid: 'owner').hashCode,
      const AuthUser(uid: 'owner').hashCode,
    );
  });
}
