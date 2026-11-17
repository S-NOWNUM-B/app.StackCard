import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/portfolio_content.dart';

/// Порядок из подбора под вакансию: Editor кладёт его в буфер без сохранения.
final class VacancyOrder {
  const VacancyOrder({required this.projects, required this.sections});
  final List<String> projects;
  final List<PortfolioBlockKind> sections;
}

final mainPortfolioEditorOrderProvider =
    NotifierProvider<MainPortfolioEditorOrder, VacancyOrder?>(
      MainPortfolioEditorOrder.new,
    );

final class MainPortfolioEditorOrder extends Notifier<VacancyOrder?> {
  @override
  VacancyOrder? build() => null;

  void request(VacancyOrder order) => state = order;
  void consume() => state = null;
}
