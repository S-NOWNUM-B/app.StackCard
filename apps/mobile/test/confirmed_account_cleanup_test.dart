import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('Confirmed UID cleanup preserves guest and another owner and revokes old handles', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stackcard-deletion-',
    );
    final box = await Hive.openBox<dynamic>('cleanup', path: directory.path);
    try {
      final accounts = LocalDraftAccounts(box);
      final removed = accounts.repositoryForUser('removed');
      final retained = accounts.repositoryForUser('retained');
      await removed.saveNotes('Removed owner');
      await retained.saveNotes('Retained owner');
      await accounts.guestRepository.saveNotes('Guest source');
      await accounts.clearConfirmedDeletedUser('removed');
      expect(await accounts.repositoryForUser('removed').read(), isNull);
      expect((await retained.read())!.notes, 'Retained owner');
      expect((await accounts.guestRepository.read())!.notes, 'Guest source');
      await expectLater(
        removed.saveNotes('Late outbox'),
        throwsA(isA<PortfolioDraftFailure>()),
      );
      await expectLater(removed.read(), throwsA(isA<PortfolioDraftFailure>()));
      expect(await accounts.repositoryForUser('removed').read(), isNull);
      await accounts.clearConfirmedDeletedUser('removed');
      expect((await retained.read())!.notes, 'Retained owner');
    } finally {
      await box.close();
      await directory.delete(recursive: true);
    }
  });
}
