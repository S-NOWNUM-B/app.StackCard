import 'package:app_stackcard/features/inbox/data/firestore_inbox_repository.dart';
import 'package:app_stackcard/features/inbox/inbox.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in: только demo emulators и именованные SDK sessions; default session не затрагивается.
/// Seed trusted HTTP fixture в emulator и передай параметры через временный --dart-define-from-file.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_INBOX_EMULATOR_ACCEPTANCE');
  testWidgets(
    'native Inbox reads trusted fixture, pages on server and writes readAt only',
    (tester) async {
      const project = String.fromEnvironment('INBOX_EMULATOR_PROJECT');
      const host = String.fromEnvironment(
        'INBOX_EMULATOR_HOST',
        defaultValue: '10.0.2.2',
      );
      const authPort = int.fromEnvironment(
        'INBOX_AUTH_EMULATOR_PORT',
        defaultValue: 9099,
      );
      const firestorePort = int.fromEnvironment(
        'INBOX_FIRESTORE_EMULATOR_PORT',
        defaultValue: 8080,
      );
      const email = String.fromEnvironment('INBOX_OWNER_EMAIL');
      const password = String.fromEnvironment('INBOX_OWNER_PASSWORD');
      const id = String.fromEnvironment('INBOX_REQUEST_ID');
      expect(
        project.startsWith('demo-'),
        isTrue,
        reason: 'Production SDK access is forbidden in this acceptance test.',
      );
      expect(['localhost', '127.0.0.1', '10.0.2.2', '::1'], contains(host));
      expect(email, isNotEmpty);
      expect(password, isNotEmpty);
      expect(isContactRequestId(id), isTrue);
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final options = FirebaseOptions(
        apiKey: 'demo-api-key',
        appId: '1:123456789:android:1234567890abcdef',
        messagingSenderId: '123456789',
        projectId: project,
      );
      FirebaseApp? ownerApp, foreignApp;
      FirebaseAuth? foreignAuth;
      FirebaseFirestore? ownerDb, foreignDb;
      try {
        ownerApp = await Firebase.initializeApp(
          name: 'inbox-owner-$stamp',
          options: options,
        );
        foreignApp = await Firebase.initializeApp(
          name: 'inbox-foreign-$stamp',
          options: options,
        );
        final ownerAuth = FirebaseAuth.instanceFor(app: ownerApp);
        foreignAuth = FirebaseAuth.instanceFor(app: foreignApp);
        await ownerAuth.useAuthEmulator(
          host,
          authPort,
          automaticHostMapping: false,
        );
        await foreignAuth.useAuthEmulator(
          host,
          authPort,
          automaticHostMapping: false,
        );
        ownerDb = FirebaseFirestore.instanceFor(app: ownerApp);
        foreignDb = FirebaseFirestore.instanceFor(app: foreignApp);
        ownerDb.settings = const Settings(persistenceEnabled: false);
        foreignDb.settings = const Settings(persistenceEnabled: false);
        ownerDb.useFirestoreEmulator(
          host,
          firestorePort,
          automaticHostMapping: false,
        );
        foreignDb.useFirestoreEmulator(
          host,
          firestorePort,
          automaticHostMapping: false,
        );
        final user = (await ownerAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).user!;
        final repository = FirestoreInboxRepository(
          firestore: ownerDb,
          ownerUid: user.uid,
          isActive: () => ownerAuth.currentUser?.uid == user.uid,
        );
        final before = await repository.get(id);
        expect(before, isNotNull);
        final reference = ownerDb.doc(
          'accounts/${user.uid}/contactRequests/$id',
        );
        final rawBefore = (await reference.get(
          const GetOptions(source: Source.server),
        )).data()!;
        final page = await repository.list();
        expect(page.requests, isNotEmpty);
        expect(page.requests.length, lessThanOrEqualTo(50));
        for (var i = 1; i < page.requests.length; i++) {
          final previous = page.requests[i - 1], current = page.requests[i];
          expect(
            previous.createdAt.isAfter(current.createdAt) ||
                (previous.createdAt == current.createdAt &&
                    previous.requestId.compareTo(current.requestId) > 0),
            isTrue,
          );
        }
        final last = page.requests.last;
        final next = await repository.list(
          after:
              page.nextCursor ??
              InboxCursor(
                ownerUid: user.uid,
                createdAt: last.createdAt,
                requestId: last.requestId,
              ),
        );
        expect(
          next.requests
              .map((request) => request.requestId)
              .toSet()
              .intersection(
                page.requests.map((request) => request.requestId).toSet(),
              ),
          isEmpty,
        );
        if (page.nextCursor != null) {
          expect(
            next.requests,
            isNotEmpty,
            reason: 'Acceptance fixture must contain at least 51 requests to exercise the second page.',
          );
        }
        final read = await repository.markRead(id);
        expect(read.readAt, isNotNull);
        expect(read.unread, isFalse);
        final after = (await reference.get(
          const GetOptions(source: Source.server),
        )).data()!;
        expect({...after}..remove('readAt'), {...rawBefore}..remove('readAt'));
        expect(after['readAt'], isA<Timestamp>());
        final repeated = await repository.markRead(id);
        expect(
          repeated.readAt,
          read.readAt,
          reason: 'Repeated explicit read must not rewrite the first acknowledgement.',
        );
        await foreignAuth.createUserWithEmailAndPassword(
          email: 'inbox.foreign.$stamp@example.invalid',
          password: 'inbox-disposable-password',
        );
        final foreign = FirestoreInboxRepository(
          firestore: foreignDb,
          ownerUid: user.uid,
          isActive: () => true,
        );
        await expectLater(
          foreign.get(id),
          throwsA(
            isA<InboxFailure>().having(
              (e) => e.kind,
              'kind',
              InboxFailureKind.permissionDenied,
            ),
          ),
        );
        await expectLater(
          foreign.list(),
          throwsA(
            isA<InboxFailure>().having(
              (e) => e.kind,
              'kind',
              InboxFailureKind.permissionDenied,
            ),
          ),
        );
        await expectLater(
          foreign.markRead(id),
          throwsA(
            isA<InboxFailure>().having(
              (e) => e.kind,
              'kind',
              InboxFailureKind.permissionDenied,
            ),
          ),
        );
        await foreignAuth.currentUser!.delete();
        await expectLater(
          foreign.get(id),
          throwsA(
            isA<InboxFailure>().having(
              (e) => e.kind,
              'kind',
              InboxFailureKind.permissionDenied,
            ),
          ),
        );
        await ownerAuth.signOut();
        await expectLater(
          repository.get(id),
          throwsA(
            isA<InboxFailure>().having(
              (e) => e.kind,
              'kind',
              InboxFailureKind.unauthenticated,
            ),
          ),
        );
        // ignore: avoid_print
        print(
          'Inbox emulator acceptance: trusted fixture, server pagination, readAt-only, owner/foreign/anonymous/session guards PASS.',
        );
      } finally {
        await foreignAuth?.signOut();
        await ownerDb?.terminate();
        await foreignDb?.terminate();
        await ownerApp?.delete();
        await foreignApp?.delete();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
