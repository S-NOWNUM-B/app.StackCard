import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/memory_portfolio_draft_repository.dart';
import 'domain/portfolio_draft_repository.dart';

final portfolioDraftRepositoryProvider = Provider<PortfolioDraftRepository>(
  (ref) => MemoryPortfolioDraftRepository(),
);
