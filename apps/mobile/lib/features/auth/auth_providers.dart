import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/demo_auth_repository.dart';
import 'domain/account_auth_repository.dart';
import 'domain/account_management_repository.dart';
import 'domain/auth_repository.dart';
import 'domain/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const DemoAuthRepository(),
);

final accountAuthRepositoryProvider = Provider<AccountAuthRepository?>(
  (ref) => null,
);

final accountManagementRepositoryProvider =
    Provider<AccountManagementRepository?>((ref) {
      final repository = ref.watch(accountAuthRepositoryProvider);
      return repository is AccountManagementRepository
          ? repository as AccountManagementRepository
          : null;
    });

final accountSessionProvider = StreamProvider<AuthUser?>(
  (ref) =>
      ref.watch(accountAuthRepositoryProvider)?.watchSession() ??
      Stream<AuthUser?>.value(null),
  retry: (_, _) => null,
);

final guestAccessProvider = NotifierProvider<GuestAccessController, bool>(
  GuestAccessController.new,
);

class GuestAccessController extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() => state = true;

  void leave() => state = false;
}
