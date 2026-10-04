import 'dart:math';

import 'package:app_stackcard/app/app_shell.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/firebase_options.dart';
import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in native acceptance: creates and deletes one disposable dev account.
/// Passwords/tokens are generated in memory and never written or printed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_FIREBASE_AUTH_ACCEPTANCE');
  const restorePhase = String.fromEnvironment('FIREBASE_AUTH_RESTORE_PHASE');
  testWidgets(
    'native Firebase email lifecycle',
    (tester) async {
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.projectId, 'stackcard-dev-snownumb');
      final app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: options)
          : Firebase.app();
      final auth = FirebaseAuth.instanceFor(app: app);
      // Never log out an existing user's session for an acceptance test.
      expect(
        auth.currentUser,
        isNull,
        reason: 'Use a signed-out development device',
      );
      final repository = FirebaseAccountAuthRepository(auth: auth);
      final email =
          'phase7.${DateTime.now().microsecondsSinceEpoch}@example.invalid';
      final random = Random.secure();
      final password = List.generate(
        24,
        (_) => random.nextInt(36).toRadixString(36),
      ).join();
      String? createdUid;
      try {
        await repository.registerEmail(email, password);
        final registered = await repository
            .watchSession()
            .firstWhere((user) => user != null)
            .timeout(const Duration(seconds: 30));
        createdUid = registered!.uid;
        expect(registered.email, email);
        await repository.signOut();
        expect(
          await repository.watchSession().first.timeout(
            const Duration(seconds: 30),
          ),
          isNull,
        );
        await expectLater(
          repository.signInEmail(email, 'wrong-password'),
          throwsA(isA<AuthFailure>()),
        );
        expect(auth.currentUser, isNull);
        await repository.signInEmail(email, password);
        final signedIn = await repository.watchSession().first.timeout(
          const Duration(seconds: 30),
        );
        expect(signedIn?.uid, createdUid);
        // A reserved .invalid address cannot deliver mail to another person.
        // This confirms SDK/backend acceptance, not inbox delivery.
        await repository.sendPasswordReset(email);
        await repository.signOut();
        expect(auth.currentUser, isNull);
      } finally {
        if (createdUid != null) {
          if (auth.currentUser?.uid != createdUid) {
            await repository.signInEmail(email, password);
          }
          if (auth.currentUser?.uid == createdUid) {
            await auth.currentUser!.delete();
          }
          await repository.signOut();
        }
      }
    },
    skip: !enabled || restorePhase.isNotEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  // Run seed and check in separate native processes, without app-data reset.
  // Only the SDK persists the session; no password/token is written by this test.
  testWidgets(
    'native Firebase session survives a new process',
    (tester) async {
      expect(restorePhase, anyOf('seed', 'check'));
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.projectId, 'stackcard-dev-snownumb');
      final app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: options)
          : Firebase.app();
      final auth = FirebaseAuth.instanceFor(app: app);
      final repository = FirebaseAccountAuthRepository(auth: auth);
      if (restorePhase == 'seed') {
        expect(auth.currentUser, isNull, reason: 'Use a signed-out dev device');
        final email =
            'phase7.restore.${DateTime.now().microsecondsSinceEpoch}@example.invalid';
        final random = Random.secure();
        final password = List.generate(
          24,
          (_) => random.nextInt(36).toRadixString(36),
        ).join();
        await repository.registerEmail(email, password);
        expect(auth.currentUser?.email, email);
        // The runner force-stops the process without Android lifecycle flush.
        // Allow the SDK's asynchronous SharedPreferences.apply() to reach disk.
        await Future<void>.delayed(const Duration(seconds: 2));
      } else {
        // Initialization above reads the existing native SDK session before any
        // sign-in call. Never delete a user outside this disposable test namespace.
        final restored = await repository.watchSession().first.timeout(
          const Duration(seconds: 30),
        );
        expect(restored, isNotNull);
        expect(
          restored!.email,
          matches(r'^phase7\.restore\.\d+@example\.invalid$'),
        );
        expect(auth.currentUser?.uid, restored.uid);
        await auth.currentUser!.delete();
        await repository.signOut();
        expect(auth.currentUser, isNull);
      }
    },
    skip: !enabled || restorePhase.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  testWidgets(
    'native bootstrap opens real auth and explicit local guest',
    (tester) async {
      expect(FirebaseAuth.instance.currentUser, isNull);
      await tester.pumpWidget(const StackCardBootstrap());
      final guest = find.byKey(const Key('account.guest'));
      for (var frame = 0; frame < 100; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (guest.evaluate().isNotEmpty &&
            tester.widget<StackCardButton>(guest).onPressed != null) {
          break;
        }
      }
      expect(find.byKey(const Key('account.email')), findsOneWidget);
      expect(tester.widget<StackCardButton>(guest).onPressed, isNotNull);
      await tester.ensureVisible(guest);
      await tester.tap(guest);
      for (var frame = 0; frame < 100; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(AppShell).evaluate().isNotEmpty) {
          break;
        }
      }
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byKey(const Key('account.email')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    skip: !enabled || restorePhase.isNotEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
