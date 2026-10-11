import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/asset_portfolio_pdf_generator.dart';
import 'document_publication_providers.dart';
import 'domain/portfolio_pdf.dart';

final portfolioPdfGeneratorProvider = Provider<PortfolioPdfGenerator>(
  (ref) => AssetPortfolioPdfGenerator(),
);

final portfolioPdfFileActionsProvider = Provider<PortfolioPdfFileActions?>((
  ref,
) {
  final actions = ref.watch(documentLinkActionsProvider);
  return actions is PortfolioPdfFileActions
      ? actions as PortfolioPdfFileActions
      : null;
});
