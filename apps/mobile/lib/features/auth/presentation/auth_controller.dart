import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_providers.dart';
import '../domain/account_auth_repository.dart';
import '../domain/auth_failure.dart';
import '../domain/demo_session.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, DemoSession?>(AuthController.new);

class AuthController extends AsyncNotifier<DemoSession?> {
  @override
  DemoSession? build() => null;

  Future<bool> openDemo(String email) async {
    if (state.isLoading) return false;
    final actionRef = ref;
    state = const AsyncLoading();
    final result = await AsyncValue.guard<DemoSession?>(
      () => actionRef.read(authRepositoryProvider).openDemo(email),
    );
    if (!actionRef.mounted) return false;
    state = result;
    return result.hasValue;
  }
}

final accountAuthControllerProvider =
    AsyncNotifierProvider<AccountAuthController, void>(
      AccountAuthController.new,
    );

class AccountAuthController extends AsyncNotifier<void> {
  int _operation = 0;

  @override
  void build() {
    ref.watch(accountAuthRepositoryProvider);
    _operation++;
  }

  Future<bool> signInEmail(String email, String password) => _run(
    (repository) => repository.signInEmail(email.trim(), password),
    leaveGuest: true,
  );

  Future<bool> registerEmail(String email, String password) => _run(
    (repository) => repository.registerEmail(email.trim(), password),
    leaveGuest: true,
  );

  Future<bool> sendPasswordReset(String email) =>
      _run((repository) => repository.sendPasswordReset(email.trim()));

  Future<bool> signInGoogle() =>
      _run((repository) => repository.signInGoogle(), leaveGuest: true);

  Future<bool> signOut() {
    if (state.isLoading) return Future.value(false);
    ref.read(guestAccessProvider.notifier).leave();
    return _run((repository) => repository.signOut());
  }

  void clearError() {
    if (!state.isLoading) state = const AsyncData(null);
  }

  Future<bool> _run(
    Future<void> Function(AccountAuthRepository repository) action, {
    bool leaveGuest = false,
  }) async {
    if (state.isLoading) return false;
    final actionRef = ref;
    final repository = actionRef.read(accountAuthRepositoryProvider);
    if (repository == null) {
      state = AsyncError(
        const AuthFailure(AuthFailureKind.configuration),
        StackTrace.empty,
      );
      return false;
    }
    final operation = ++_operation;
    state = const AsyncLoading();
    try {
      await action(repository);
      if (!actionRef.mounted || operation != _operation) return false;
      if (leaveGuest) actionRef.read(guestAccessProvider.notifier).leave();
      state = const AsyncData(null);
      return true;
    } catch (error) {
      if (!actionRef.mounted || operation != _operation) return false;
      final failure = error is AuthFailure
          ? error
          : const AuthFailure(AuthFailureKind.unknown);
      state = failure.kind == AuthFailureKind.cancelled
          ? const AsyncData(null)
          : AsyncError(failure, StackTrace.empty);
      return false;
    }
  }
}
