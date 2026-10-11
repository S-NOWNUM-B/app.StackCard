import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/app/app_shell.dart';
import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/firebase_options.dart';
import 'package:app_stackcard/main.dart';
import 'package:app_stackcard/shared/widgets/stackcard_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

// Реальный Google picker: ручной вход, без fake credentials и удаления аккаунта.
// Named Auth и временная metadata сохраняют обычные Firebase/Hive/settings.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_GOOGLE_AUTH_ACCEPTANCE');
  const phase = String.fromEnvironment('GOOGLE_AUTH_PHASE');
  const runId = String.fromEnvironment('GOOGLE_AUTH_RUN_ID');

  testWidgets(
    'Android Google sign-in and session restoration',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect(phase, anyOf('seed', 'check'));
      expect(runId, matches(r'^[a-f0-9]{32}$'));
      expect(
        const String.fromEnvironment('FIREBASE_AUTH_EMULATOR_HOST'),
        isEmpty,
      );
      expect(const String.fromEnvironment('FIRESTORE_EMULATOR_HOST'), isEmpty);
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.projectId, 'stackcard-dev-snownumb');
      final defaultApp = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: options)
          : Firebase.app();
      final defaultAuth = FirebaseAuth.instanceFor(app: defaultApp);
      final defaultUid = (await defaultAuth.authStateChanges().first)?.uid;
      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/stackcard-google-$runId',
      );
      await directory.create(recursive: true);
      final evidence = File('${directory.path}/evidence.json');
      final prior = evidence.existsSync()
          ? jsonDecode(await evidence.readAsString()) as Map<String, dynamic>
          : null;
      if (phase == 'seed') {
        expect(prior, isNull, reason: 'Use a fresh acceptance run ID.');
      } else {
        expect(prior?['status'], 'seed-passed');
        expect(prior?['processId'], isNot(pid));
        expect(defaultUid, prior?['defaultUid']);
      }
      final app = await Firebase.initializeApp(
        name: 'stackcard-google-$runId',
        options: options,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      firestore.settings = const Settings(persistenceEnabled: false);
      final repository = FirebaseAccountAuthRepository(auth: auth);
      await auth.authStateChanges().first;

      try {
        if (phase == 'seed') expect(auth.currentUser, isNull);
        // Memory-only workspace: тест не открывает обычные Hive/preferences.
        await tester.pumpWidget(
          StackCardApp(
            providerOverrides: [
              accountAuthRepositoryProvider.overrideWithValue(repository),
            ],
          ),
        );
        if (phase == 'seed') {
          await _wait(tester, () {
            final google = find.byKey(const Key('account.google'));
            return google.evaluate().isNotEmpty &&
                tester.widget<StackCardButton>(google).onPressed != null;
          });
          await _write(evidence, {
            'status': 'awaiting-google-selection',
            'runId': runId,
            'processId': pid,
            'defaultUid': defaultUid,
          });
          final google = find.byKey(const Key('account.google'));
          await tester.ensureVisible(google);
          await tester.tap(google);
          await _wait(tester, () => auth.currentUser != null);
        } else {
          expect(auth.currentUser?.uid, prior?['uid']);
        }
        await _wait(tester, () => find.byType(AppShell).evaluate().isNotEmpty);
        final user = auth.currentUser!;
        expect(
          user.providerData.any(
            (provider) => provider.providerId == 'google.com',
          ),
          isTrue,
        );
        final token = await tester.runAsync(() => user.getIdTokenResult(true));
        expect(token?.signInProvider, 'google.com');
        final session = await repository.watchSession().first;
        expect(session?.uid, user.uid);
        final snapshot = await tester.runAsync(
          () => firestore
              .doc('accounts/${user.uid}/drafts/current')
              .get(const GetOptions(source: Source.server)),
        );
        expect(snapshot, isNotNull);
        if (snapshot!.exists) expect(snapshot.data()?['ownerUid'], user.uid);
        expect(defaultAuth.currentUser?.uid, defaultUid);

        if (phase == 'check') {
          await tester.runAsync(repository.signOut);
          await _wait(
            tester,
            () => find.byKey(const Key('account.google')).evaluate().isNotEmpty,
          );
          expect(auth.currentUser, isNull);
          expect(await repository.watchSession().first, isNull);
          expect(defaultAuth.currentUser?.uid, defaultUid);
        } else {
          // Дождаться асинхронной записи SDK session перед новым процессом.
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(seconds: 2)),
          );
        }
        await _write(evidence, {
          'status': phase == 'seed' ? 'seed-passed' : 'passed',
          'runId': runId,
          'processId': pid,
          if (phase == 'check') 'priorProcessId': prior?['processId'],
          'uid': user.uid,
          'defaultUid': defaultUid,
          'defaultSessionPreserved': true,
          'googleProvider': true,
          'serverSignInProvider': token?.signInProvider,
          'protectedRoute': 'AppShell',
          'ownerServerRead': true,
          'draftExists': snapshot.exists,
          'restoredBeforeSignIn': phase == 'check',
          'signedOut': phase == 'check',
        });
      } catch (error) {
        // Только failed named session; successful seed остаётся для check.
        var namedSessionCleared = false;
        try {
          await auth.signOut();
          namedSessionCleared = auth.currentUser == null;
        } catch (_) {
          // Сохраняем исходную ошибку и явный cleanup outcome для retry.
        }
        await _write(evidence, {
          'status': 'failed',
          'runId': runId,
          'processId': pid,
          'errorType': error.runtimeType.toString(),
          'namedSessionCleared': namedSessionCleared,
        });
        rethrow;
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await firestore.terminate();
        await app.delete();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _wait(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(minutes: 8));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
  }
  expect(
    ready(),
    isTrue,
    reason: 'Complete the real Google picker on Android.',
  );
}

Future<void> _write(File evidence, Map<String, Object?> value) async {
  final pending = File('${evidence.path}.pending');
  await pending.writeAsString(jsonEncode(value), flush: true);
  await pending.rename(evidence.path);
}
