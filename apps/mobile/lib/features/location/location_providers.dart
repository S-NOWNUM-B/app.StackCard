import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/native_portfolio_location_repository.dart';
import 'domain/portfolio_location.dart';

final portfolioLocationRepositoryProvider =
    Provider<PortfolioLocationRepository>(
      (ref) => NativePortfolioLocationRepository(),
    );
