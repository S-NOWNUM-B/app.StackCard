import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/main.dart';
import 'package:flutter/widgets.dart';

import 'fixture.dart';

/// Только явный profile target: изолированная память, без LocalRuntime/Firebase.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = MemoryPortfolioDraftRepository();
  await repository.save(
    performanceWorkspace(),
    expectedRevision: 0,
    notes: 'PRIVATE_NOTES',
  );
  runApp(
    StackCardApp(
      initialLocation: '/home',
      providerOverrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
        documentLinkActionsProvider.overrideWithValue(
          const NativeDocumentLinkActions(),
        ),
      ],
    ),
  );
}
