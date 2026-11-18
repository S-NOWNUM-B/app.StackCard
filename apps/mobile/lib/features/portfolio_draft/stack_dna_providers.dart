import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/stack_dna.dart';
import 'presentation/portfolio_draft_controller.dart';

/// «ДНК стека» читает только проекты сохранённого портфолио: новых сетевых
/// запросов и записи нет. null — черновик ещё не загружен.
final stackDnaProvider = Provider<StackDna?>((ref) {
  final state = ref.watch(portfolioDraftControllerProvider);
  if (!state.loaded) return null;
  final content = state.draft?.content ?? state.content;
  return buildStackDna(
    content == null ? const [] : stackDnaProjectsFrom(content),
  );
});
