import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/demo_account_fixture.dart';

void main() {
  test('demo account fixture is valid and fills every section', () {
    final workspace = demoAccountWorkspace();
    expect(validatePortfolioContent(workspace), isEmpty);
    final main = resolvedMainPortfolioContent(workspace)!;
    expect(main.profile.name, isNotEmpty);
    expect(main.profile.bio, isNotEmpty);
    expect(main.skills, isNotEmpty);
    expect(main.projects.where((project) => project.visible), hasLength(4));
    expect(main.experience, isNotEmpty);
    expect(main.education, isNotEmpty);
    expect(main.links.where((link) => link.publishAllowed), hasLength(6));
    expect(
      main.blocks
          .where((block) => block.kind != PortfolioBlockKind.resume)
          .every((block) => block.visible),
      isTrue,
    );
  });

  test('demo account fixture survives the Firestore codec', () {
    final draft = CloudPortfolioDraft(
      ownerUid: 'demo-owner',
      mutationId: 'demo-seed',
      localRevision: 1,
      notes: demoAccountNotes,
      content: demoAccountWorkspace(),
    );
    final encoded = encodeCloudPortfolioDraft(draft)
      ..['updatedAt'] = Timestamp.fromDate(DateTime.utc(2026, 10, 21));
    final decoded = decodeCloudPortfolioDraft(encoded, ownerUid: 'demo-owner');
    expect(decoded.content, demoAccountWorkspace());
    expect(decoded.notes, demoAccountNotes);
  });
}
