import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/demo_account_fixture.dart';

/// Opt-in: создаёт демо-аккаунт только в локальных Auth/Firestore emulators.
/// Повторный запуск перезаписывает его данные исходным заполненным состоянием.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_DEMO_ACCOUNT_SEED');
  const host = String.fromEnvironment(
    'DEMO_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );

  testWidgets('seed fully filled demo account into local emulators', (
    tester,
  ) async {
    expect(host, anyOf('10.0.2.2', '127.0.0.1', 'localhost'));
    // Тот же projectId, что у приложения, чтобы emulator namespace совпал.
    final app = await Firebase.initializeApp(
      name: 'demo-account-seed',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final auth = FirebaseAuth.instanceFor(app: app);
    await auth.useAuthEmulator(host, 9099);
    final db = FirebaseFirestore.instanceFor(app: app);
    db.useFirestoreEmulator(host, 8085);
    try {
      User user;
      try {
        user = (await auth.createUserWithEmailAndPassword(
          email: demoAccountEmail,
          password: demoAccountPassword,
        )).user!;
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') rethrow;
        user = (await auth.signInWithEmailAndPassword(
          email: demoAccountEmail,
          password: demoAccountPassword,
        )).user!;
      }
      await _write(db, user.uid);
    } finally {
      await auth.signOut();
      await app.delete();
    }
  }, skip: !enabled);
}

Future<void> _write(FirebaseFirestore db, String uid) async {
  await FirestorePortfolioDraftRepository(firestore: db, uid: uid).write(
    CloudPortfolioDraft(
      ownerUid: uid,
      mutationId: 'demo-seed-${DateTime.now().microsecondsSinceEpoch}',
      localRevision: 1,
      notes: demoAccountNotes,
      content: demoAccountWorkspace(),
    ),
  );
  final server = await db
      .doc('accounts/$uid/drafts/current')
      .get(const GetOptions(source: Source.server));
  final draft = decodeCloudPortfolioDraft(server.data()!, ownerUid: uid);
  expect(draft.content, demoAccountWorkspace());
}
