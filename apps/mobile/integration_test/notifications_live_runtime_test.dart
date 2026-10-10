import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/inbox/data/firestore_inbox_repository.dart';
import 'package:app_stackcard/features/inbox/inbox.dart';
import 'package:app_stackcard/features/notifications/data/firebase_push_messaging.dart';
import 'package:app_stackcard/features/notifications/data/http_push_device_registration.dart';
import 'package:app_stackcard/features/notifications/notifications.dart';
import 'package:app_stackcard/features/portfolio_draft/data/http_document_publication_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:app_stackcard/firebase_options.dart';
import 'package:app_stackcard/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in live Android FCM с named Auth/Firestore и отдельным acceptance cache.
/// Default Auth/Hive/settings не меняются; credentials и FCM token не печатаются.
/// Host публикует настоящий saved document, отправляет через public form и нажимает tray.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_NOTIFICATION_LIVE_ACCEPTANCE');
  const stage = String.fromEnvironment('NOTIFICATION_LIVE_STAGE');
  const runId = String.fromEnvironment('NOTIFICATION_LIVE_RUN_ID');
  const expectedMessage = String.fromEnvironment('NOTIFICATION_LIVE_MESSAGE');
  const apiUrl = String.fromEnvironment('CONTACT_INBOX_API_URL');
  const publicationApiUrl = String.fromEnvironment(
    'STACKCARD_PUBLICATION_API_URL',
  );

  testWidgets(
    'actual Android FCM delivery, owner tap gate and Inbox with denied permission',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      expect({
        'foreground',
        'background',
        'terminated',
        'foreign',
        'denied',
        'revoked',
      }, contains(stage));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(runId), isTrue);
      expect(expectedMessage.trim() == expectedMessage, isTrue);
      expect(
        expectedMessage.isNotEmpty && expectedMessage.length <= 4000,
        isTrue,
      );
      final endpoint = Uri.tryParse(apiUrl);
      final publicationEndpoint = Uri.tryParse(publicationApiUrl);
      expect(
        endpoint != null &&
            endpoint.scheme == 'https' &&
            endpoint.host.isNotEmpty &&
            endpoint.userInfo.isEmpty &&
            !endpoint.hasQuery &&
            !endpoint.hasFragment,
        isTrue,
        reason: 'Host must supply the actual trusted contactInbox HTTPS URL.',
      );
      expect(
        publicationEndpoint != null &&
            publicationEndpoint.scheme == 'https' &&
            publicationEndpoint.host.isNotEmpty &&
            publicationEndpoint.userInfo.isEmpty &&
            !publicationEndpoint.hasQuery &&
            !publicationEndpoint.hasFragment,
        isTrue,
      );
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options.projectId, 'stackcard-dev-snownumb');
      final defaultApp = Firebase.apps.isEmpty
          ? await Firebase.initializeApp(options: options)
          : Firebase.app();
      expect(defaultApp.options.projectId, options.projectId);
      final defaultAuth = FirebaseAuth.instanceFor(app: defaultApp);
      final defaultUid = (await defaultAuth.authStateChanges().first)?.uid;
      final defaultConsent = SharedPreferencesPushConsentStore(
        SharedPreferencesAsync(),
      );
      expect(
        await defaultConsent.readOwner(),
        isNull,
        reason: 'Abort if default push consent exists; preserve that binding.',
      );
      final sdk = FirebaseMessaging.instance;
      expect(sdk.isAutoInitEnabled, isFalse);

      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/stackcard-phase14-live-$runId',
      );
      await directory.create(recursive: true);
      final evidence = File('${directory.path}/$stage.json');
      final command = File('${directory.path}/$stage.command');
      final targetRequest = File('${directory.path}/$stage.request-id');
      var requestId = '';
      final previous = evidence.existsSync()
          ? jsonDecode(await evidence.readAsString()) as Map<String, dynamic>
          : null;
      final coldResume =
          stage == 'terminated' && previous?['status'] == 'armed';
      expect(
        previous == null || coldResume,
        isTrue,
        reason:
            'Use a fresh run ID; only an armed terminated stage can resume.',
      );
      if (coldResume) expect(previous!['processId'], isNot(pid));

      final app = await Firebase.initializeApp(
        name: 'phase14-live-$runId-$stage',
        options: options,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      await auth.authStateChanges().first;
      final firestore = FirebaseFirestore.instanceFor(app: app);
      firestore.settings = const Settings(persistenceEnabled: false);
      final apps = [app], databases = [firestore], sessions = [auth];
      final createdUids = <String>[];
      final authForOwner = <String, FirebaseAuth>{};
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      final gateway = _ObservedMessaging(FirebasePushMessaging(sdk));
      NotificationsController? controller;
      var assertionsPassed = false;
      String? ownerUid;
      final baseEvidence = <String, Object?>{
        'runId': runId,
        'stage': stage,
        'requestId': null,
        'processId': pid,
        'documentId': 'phase14-live',
        'sourceMutationId': 'phase14-live-$runId-$stage',
      };
      try {
        if (coldResume) {
          expect(auth.currentUser?.uid, previous!['ownerUid']);
          expect(
            auth.currentUser?.email?.startsWith('phase14.$runId.') == true,
            isTrue,
            reason: 'Only this run may resume its named SDK session.',
          );
          createdUids.add(auth.currentUser!.uid);
        } else {
          expect(
            auth.currentUser,
            isNull,
            reason: 'Never replace a named session.',
          );
          createdUids.add(await _createDisposableAccount(auth, runId));
        }
        ownerUid = auth.currentUser!.uid;
        authForOwner[ownerUid] = auth;
        baseEvidence['ownerUid'] = ownerUid;
        if (!coldResume) {
          await _writeEvidence(evidence, {
            ...baseEvidence,
            'status': 'owner-created',
          });
          await _waitCommand(tester, command, 'fixture-ready');
          // Host seed становится обычным saved workspace; публикация идёт через actual Auth HTTP API.
          final publication =
              await HttpDocumentPublicationRepository(
                dio: dio,
                endpoint: publicationEndpoint!,
                ownerUid: ownerUid,
                token: (capturedUid) async {
                  if (auth.currentUser?.uid != capturedUid) return null;
                  final token = await auth.currentUser!.getIdToken();
                  return auth.currentUser?.uid == capturedUid ? token : null;
                },
              ).mutate(
                DocumentPublicationMutation(
                  action: DocumentPublicationAction.publish,
                  operationId: 'phase14-live-$runId-$stage',
                  documentId: 'phase14-live',
                  expectedMutationId: 'phase14-live-$runId-$stage',
                  expectedVersion: 0,
                  expectedGeneration: 0,
                ),
              );
          expect(publication.outcome, DocumentPublicationOutcome.completed);
          expect(publication.publication?.shareableUrl, isNotNull);
          expect(
            publication.publication?.sourceMutationId,
            baseEvidence['sourceMutationId'],
          );
          baseEvidence['publicId'] = publication.publication!.publicId;
          baseEvidence['publicUrl'] = publication.publication!.shareableUrl
              .toString();
        } else {
          expect(previous!['documentId'], baseEvidence['documentId']);
          expect(
            previous['sourceMutationId'],
            baseEvidence['sourceMutationId'],
          );
          baseEvidence['publicId'] = previous['publicId'];
          baseEvidence['publicUrl'] = previous['publicUrl'];
        }
        final consent = MemoryPushConsentStore();
        if (coldResume) consent.ownerUid = ownerUid;
        controller = NotificationsController(
          messaging: gateway,
          consent: consent,
          registrationForOwner: (uid) => HttpPushDeviceRegistration(
            dio: dio,
            endpoint: endpoint!,
            ownerUid: uid,
            platform: 'android',
            idToken: (capturedUid) async {
              final session = authForOwner[capturedUid];
              final user = session?.currentUser;
              if (user?.uid != capturedUid) return null;
              final token = await user!.getIdToken();
              return session?.currentUser?.uid == capturedUid ? token : null;
            },
          ),
        );
        final notifications = controller;
        InboxRepository inbox(
          FirebaseAuth session,
          FirebaseFirestore database,
          String uid,
        ) => FirestoreInboxRepository(
          firestore: database,
          ownerUid: uid,
          isActive: () => session.currentUser?.uid == uid,
        );
        Future<void> showAccount(
          FirebaseAuth session,
          FirebaseFirestore database, {
          String location = '/settings/notifications',
        }) async {
          final uid = session.currentUser!.uid;
          await tester.pumpWidget(
            StackCardApp(
              key: ValueKey('$uid:$location'),
              initialLocation: location,
              providerOverrides: [
                accountAuthRepositoryProvider.overrideWithValue(
                  FirebaseAccountAuthRepository(auth: session),
                ),
                notificationsControllerProvider.overrideWithValue(
                  notifications,
                ),
                inboxRepositoryFactoryProvider.overrideWithValue(
                  (String capturedUid) =>
                      capturedUid == session.currentUser?.uid
                      ? inbox(session, database, capturedUid)
                      : null,
                ),
              ],
            ),
          );
          await _until(
            tester,
            () =>
                notifications.state.ownerUid == uid &&
                !notifications.state.busy,
          );
        }

        await showAccount(auth, firestore);
        if (!coldResume) {
          if (stage == 'denied') {
            await notifications.refreshPermission();
            expect(notifications.state.permission, PushPermission.denied);
            expect(notifications.state.enabled, isFalse);
            expect(gateway.tokenRequested, isFalse);
          } else {
            // Opt-in разрешает только явное enable и системный permission prompt.
            await notifications.enable();
            expect(notifications.state.enabled, isTrue);
            expect(notifications.state.cleanupFailed, isFalse);
            expect(notifications.state.failure, isNull);
          }
          await _writeEvidence(evidence, {
            ...baseEvidence,
            'status': stage == 'terminated' ? 'armed' : 'ready',
            'registrationConfirmed': notifications.state.enabled,
            'permission': notifications.state.permission.name,
          });
        }

        if (coldResume ||
            {'foreground', 'background', 'foreign', 'denied'}.contains(stage)) {
          // Host узнаёт ID actual browser submit по owner + exact message, без изменения формы.
          requestId = await _readRequestId(tester, targetRequest);
          baseEvidence['requestId'] = requestId;
        }

        if (stage == 'foreground') {
          await _until(
            tester,
            () =>
                gateway.foregroundFor(requestId) != null &&
                notifications.state.foregroundCount > 0,
          );
          expect(gateway.foregroundFor(requestId)?['ownerUid'], ownerUid);
          expect(find.byType(InboxRequestScreen), findsNothing);
          await _verifyInbox(
            inbox(auth, firestore, ownerUid),
            requestId,
            expectedMessage,
          );
        } else if (stage == 'background' || coldResume) {
          await _until(
            tester,
            () => find.byType(InboxRequestScreen).evaluate().isNotEmpty,
          );
          final screen = tester.widget<InboxRequestScreen>(
            find.byType(InboxRequestScreen),
          );
          expect(screen.requestId, requestId);
          final payload = coldResume
              ? gateway.lastInitial
              : gateway.openedFor(requestId);
          expect(payload?['requestId'], requestId);
          expect(payload?['ownerUid'], ownerUid);
          if (coldResume) expect(gateway.lastOpened, isNull);
          await _until(
            tester,
            () => find.text(expectedMessage).evaluate().isNotEmpty,
          );
          await _verifyInbox(
            inbox(auth, firestore, ownerUid),
            requestId,
            expectedMessage,
          );
        } else if (stage == 'terminated') {
          // Standalone APK: Home → am kill → actual FCM → tray tap → новый процесс.
          // Первый процесс оставляет armed, но не объявляет delivery/tap PASS.
          await _until(tester, () => false);
        } else if (stage == 'foreign') {
          await _waitCommand(tester, command, 'switch-owner');
          final foreignApp = await Firebase.initializeApp(
            name: 'phase14-live-$runId-foreign-b',
            options: options,
          );
          apps.add(foreignApp);
          final foreignAuth = FirebaseAuth.instanceFor(app: foreignApp);
          sessions.add(foreignAuth);
          await foreignAuth.authStateChanges().first;
          expect(foreignAuth.currentUser, isNull);
          final foreignUid = await _createDisposableAccount(foreignAuth, runId);
          createdUids.add(foreignUid);
          authForOwner[foreignUid] = foreignAuth;
          final foreignDb = FirebaseFirestore.instanceFor(app: foreignApp);
          databases.add(foreignDb);
          foreignDb.settings = const Settings(persistenceEnabled: false);
          await _writeEvidence(evidence, {
            ...baseEvidence,
            'status': 'foreign-owner-created',
            'foreignUid': foreignUid,
          });
          await _waitCommand(tester, command, 'foreign-fixture-ready');
          await showAccount(foreignAuth, foreignDb);
          expect(notifications.state.enabled, isFalse);
          expect(notifications.state.cleanupFailed, isFalse);
          await _writeEvidence(evidence, {
            ...baseEvidence,
            'status': 'owner-switched',
            'foreignUid': foreignUid,
          });
          await _until(tester, () => gateway.openedFor(requestId) != null);
          expect(gateway.openedFor(requestId)?['ownerUid'], ownerUid);
          await tester.pump(const Duration(seconds: 1));
          expect(notifications.state.ownerUid, foreignUid);
          expect(notifications.state.pendingRequestId, isNull);
          expect(find.byType(InboxRequestScreen), findsNothing);
          await expectLater(
            FirestoreInboxRepository(
              firestore: foreignDb,
              ownerUid: ownerUid,
              isActive: () => foreignAuth.currentUser?.uid == foreignUid,
            ).get(requestId),
            throwsA(
              isA<InboxFailure>().having(
                (error) => error.kind,
                'kind',
                InboxFailureKind.permissionDenied,
              ),
            ),
          );
        } else if (stage == 'denied' || stage == 'revoked') {
          if (stage == 'revoked') {
            await _waitCommand(tester, command, 'permission-revoked');
            await notifications.refreshPermission();
            expect(notifications.state.permission, PushPermission.denied);
            expect(notifications.state.enabled, isFalse);
            expect(notifications.state.cleanupFailed, isFalse);
            await _writeEvidence(evidence, {
              ...baseEvidence,
              'status': 'permission-denied',
            });
            requestId = await _readRequestId(tester, targetRequest);
            baseEvidence['requestId'] = requestId;
          }
          await _waitCommand(tester, command, 'inbox-submitted');
          await _verifyInbox(
            inbox(auth, firestore, ownerUid),
            requestId,
            expectedMessage,
          );
          await showAccount(auth, firestore, location: '/inbox/$requestId');
          await _until(
            tester,
            () => find.text(expectedMessage).evaluate().isNotEmpty,
          );
          expect(notifications.state.enabled, isFalse);
          expect(notifications.state.permission, PushPermission.denied);
        }
        expect(tester.takeException(), isNull);
        assertionsPassed = true;
      } finally {
        var sdkTokenDeleted = controller == null;
        var backendCleanupPending = false, isolatedSessionsClosed = true;
        await tester.pumpWidget(const SizedBox.shrink());
        if (controller != null) {
          try {
            await controller.disable();
            backendCleanupPending = controller.state.cleanupFailed;
            await controller.dispose();
            await gateway.deleteToken();
            sdkTokenDeleted = true;
          } catch (_) {
            backendCleanupPending = true;
          }
        }
        for (final session in sessions) {
          try {
            await session.signOut();
          } catch (_) {
            isolatedSessionsClosed = false;
          }
        }
        for (final database in databases) {
          try {
            await database.terminate();
          } catch (_) {
            isolatedSessionsClosed = false;
          }
        }
        for (final isolatedApp in apps.reversed) {
          try {
            await isolatedApp.delete();
          } catch (_) {
            isolatedSessionsClosed = false;
          }
        }
        dio.close(force: true);
        final defaultSessionPreserved =
            defaultAuth.currentUser?.uid == defaultUid;
        final defaultConsentPreserved =
            await defaultConsent.readOwner() == null;
        final completed =
            assertionsPassed &&
            sdkTokenDeleted &&
            !backendCleanupPending &&
            isolatedSessionsClosed &&
            defaultSessionPreserved &&
            defaultConsentPreserved;
        await _writeEvidence(evidence, {
          ...baseEvidence,
          'status': completed ? 'passed' : 'failed',
          'createdUids': createdUids,
          'sdkTokenDeleted': sdkTokenDeleted,
          'backendCleanupPending': backendCleanupPending,
          'isolatedSessionsClosed': isolatedSessionsClosed,
          'defaultSessionPreserved': defaultSessionPreserved,
          'defaultConsentPreserved': defaultConsentPreserved,
          'transport': stage == 'denied' || stage == 'revoked'
              ? 'none'
              : 'actual-firebase-messaging',
          'interaction': coldResume
              ? 'getInitialMessage'
              : stage == 'background' || stage == 'foreign'
              ? 'onMessageOpenedApp'
              : stage == 'foreground'
              ? 'onMessage'
              : 'permission-denied-inbox',
          if (coldResume) 'priorProcessId': previous!['processId'],
        });
        expect(defaultSessionPreserved, isTrue);
        expect(defaultConsentPreserved, isTrue);
        expect(isolatedSessionsClosed, isTrue);
        expect(sdkTokenDeleted, isTrue);
        expect(backendCleanupPending, isFalse);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

Future<String> _createDisposableAccount(FirebaseAuth auth, String runId) async {
  final random = Random.secure();
  final password = base64UrlEncode(
    List.generate(32, (_) => random.nextInt(256)),
  );
  final result = await auth.createUserWithEmailAndPassword(
    email:
        'phase14.$runId.${DateTime.now().microsecondsSinceEpoch}@example.invalid',
    password: password,
  );
  return result.user!.uid;
}

Future<void> _verifyInbox(
  InboxRepository repository,
  String id,
  String message,
) async {
  final request = await repository.get(id);
  expect(request?.requestId, id);
  expect(request?.message, message);
}

Future<void> _waitCommand(WidgetTester tester, File file, String expected) =>
    _until(
      tester,
      () => file.existsSync() && file.readAsStringSync().trim() == expected,
    );

Future<String> _readRequestId(WidgetTester tester, File file) async {
  await _until(tester, file.existsSync);
  final id = (await file.readAsString()).trim();
  expect(
    isContactRequestId(id),
    isTrue,
    reason: 'Host must supply the actual accepted browser request ID.',
  );
  return id;
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(minutes: 8));
  while (!ready()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError(
        'Timed out waiting for the live acceptance host/device stage.',
      );
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  }
}

Future<void> _writeEvidence(File file, Map<String, Object?> value) async {
  final temporary = File('${file.path}.pending');
  await temporary.writeAsString(jsonEncode(value), flush: true);
  await temporary.rename(file.path);
}

/// Spy наблюдает actual adapter и не подменяет transport, payload или SDK futures.
final class _ObservedMessaging implements PushMessagingGateway {
  _ObservedMessaging(this.delegate);
  final FirebasePushMessaging delegate;
  Map<String, dynamic>? lastInitial, lastOpened, lastForeground;
  final _openedMessages = <Map<String, dynamic>>[];
  final _foregroundMessages = <Map<String, dynamic>>[];
  Map<String, dynamic>? openedFor(String id) =>
      _openedMessages.where((data) => data['requestId'] == id).lastOrNull;
  Map<String, dynamic>? foregroundFor(String id) =>
      _foregroundMessages.where((data) => data['requestId'] == id).lastOrNull;
  bool tokenRequested = false;
  @override
  Future<PushPermission> permission({bool request = false}) =>
      delegate.permission(request: request);
  @override
  Future<void> setAutoInitEnabled(bool enabled) =>
      delegate.setAutoInitEnabled(enabled);
  @override
  Future<String?> getToken() {
    tokenRequested = true;
    return delegate.getToken();
  }

  @override
  Future<void> deleteToken() => delegate.deleteToken();
  @override
  Stream<String> get tokenRefresh => delegate.tokenRefresh;
  @override
  Stream<Map<String, dynamic>> get opened => delegate.opened.map((data) {
    lastOpened = data;
    _openedMessages.add(data);
    return data;
  });
  @override
  Stream<Map<String, dynamic>> get foreground =>
      delegate.foreground.map((data) {
        lastForeground = data;
        _foregroundMessages.add(data);
        return data;
      });
  @override
  Future<Map<String, dynamic>?> initialMessage() async {
    lastInitial = await delegate.initialMessage();
    return lastInitial;
  }
}
