import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/profile.dart';
import '../profile_dependencies.dart';

final profileProvider = FutureProvider<Profile>(
  (ref) => ref.watch(profileRepositoryProvider).getProfile(),
  retry: (_, _) => null,
);
