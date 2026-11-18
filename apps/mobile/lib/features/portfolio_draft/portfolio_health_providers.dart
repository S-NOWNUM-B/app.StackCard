import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'document_publication_providers.dart';
import 'domain/main_portfolio.dart';
import 'domain/portfolio_health.dart';
import 'portfolio_draft_providers.dart';
import 'presentation/portfolio_draft_controller.dart';

/// Оценка читает только сохранённый (durable) основной документ, как Home.
/// null — основного портфолио ещё нет или оно пустое.
final portfolioHealthProvider = Provider<PortfolioHealth?>((ref) {
  final state = ref.watch(portfolioDraftControllerProvider);
  final workspace = state.draft?.content;
  if (!state.loaded || workspace == null) return null;
  final saved = resolvedMainPortfolioContent(workspace);
  if (saved == null || !portfolioHasDisplayContent(saved)) return null;
  final document = mainPortfolioDocument(workspace)!;
  final publication = ref.watch(documentPublicationControllerProvider);
  // Пока инвентарь публикаций не загружен, статус неизвестен.
  final published = publication.inventory == null
      ? null
      : publication.forDocument(document.id)?.shareableUrl != null;
  return buildPortfolioHealth(
    content: saved,
    now: ref.watch(portfolioSuggestionClockProvider)(),
    published: published,
  );
});

/// Раздел, к которому Editor должен прокрутиться после перехода из совета.
final mainPortfolioEditorFocusProvider =
    NotifierProvider<MainPortfolioEditorFocus, PortfolioHealthSection?>(
      MainPortfolioEditorFocus.new,
    );

final class MainPortfolioEditorFocus extends Notifier<PortfolioHealthSection?> {
  @override
  PortfolioHealthSection? build() => null;

  void request(PortfolioHealthSection section) => state = section;
  void consume() => state = null;
}
