import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_providers.dart';
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
