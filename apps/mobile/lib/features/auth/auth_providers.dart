import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/demo_auth_repository.dart';
import 'domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => const DemoAuthRepository(),
);
