import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/media/media.dart';
import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';

/// Только demo emulators и named apps; обычный account/draft не меняется.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled =
      bool.fromEnvironment('RUN_MEDIA_ACCEPTANCE') ||
      bool.fromEnvironment('RUN_AVATAR_ACCEPTANCE');
  const host = String.fromEnvironment(
    'MEDIA_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  const authPort = int.fromEnvironment(
    'AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  const firestorePort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8085,
  );
  const options = FirebaseOptions(
    apiKey: 'emulator-only-key',
    appId: '1:123456789:android:0123456789abcdef',
    messagingSenderId: '123456789',
    projectId: 'demo-stackcard-test',
  );
  testWidgets(
    'native Spark avatar upload/read/reopen and SDK ownership/lifecycle',
    (tester) async {
      expect(['10.0.2.2', '127.0.0.1', 'localhost'], contains(host));
      expect(options.projectId.startsWith('demo-'), isTrue);
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final ownerApp = await Firebase.initializeApp(
        name: 'avatar-owner-$stamp',
        options: options,
      );
      final foreignApp = await Firebase.initializeApp(
        name: 'avatar-foreign-$stamp',
        options: options,
      );
      final auth = FirebaseAuth.instanceFor(app: ownerApp),
          foreignAuth = FirebaseAuth.instanceFor(app: foreignApp);
      final database = FirebaseFirestore.instanceFor(app: ownerApp),
          foreignDatabase = FirebaseFirestore.instanceFor(app: foreignApp);
      database.settings = const Settings(persistenceEnabled: false);
      foreignDatabase.settings = const Settings(persistenceEnabled: false);
      final password = 'Emulator only disposable $stamp!';
      final foreignEmail = 'avatar.foreign.$stamp@example.invalid';
      FirestorePortfolioMediaRepository? repository;
      String? ownerUid, path;
      var lifecycleFixture = false;
      var foreignCreated = false;
      try {
        await auth.useAuthEmulator(host, authPort);
        await foreignAuth.useAuthEmulator(host, authPort);
        database.useFirestoreEmulator(host, firestorePort);
        foreignDatabase.useFirestoreEmulator(host, firestorePort);
        expect(auth.currentUser, isNull);
        expect(foreignAuth.currentUser, isNull);
        ownerUid = (await auth.createUserWithEmailAndPassword(
          email: 'avatar.owner.$stamp@example.invalid',
          password: password,
        )).user!.uid;
        await foreignAuth.createUserWithEmailAndPassword(
          email: foreignEmail,
          password: password,
        );
        foreignCreated = true;
        final owner = ownerUid;
        repository = FirestorePortfolioMediaRepository(
          firestore: database,
          ownerUid: owner,
          isActive: () => auth.currentUser?.uid == owner,
        );
        final source = image.Image(width: 1024, height: 768);
        image.fill(source, color: image.ColorRgb8(120, 170, 80));
        source.exif.imageIfd.imageDescription = 'private disposable EXIF';
        final prepared = await const PortfolioImageProcessor().prepare(
          image.encodeJpg(source),
          mimeType: 'image/jpeg',
        );
        final progress = <double>[];
        path = await repository.upload(prepared, onProgress: progress.add);
        expect(isPortfolioMediaPathForOwner(path, owner), isTrue);
        expect(progress, [0, 1]);
        final bytes = await repository.read(path),
            decoded = image.decodeJpg(bytes)!;
        expect((decoded.width, decoded.height), (512, 384));
        expect(bytes.length, lessThanOrEqualTo(portfolioAvatarMaxBytes));
        expect(decoded.exif.isEmpty, isTrue);
        expect(bytes, prepared.bytes);
        final mediaRecord = {
          'schemaVersion': 1,
          'contentType': 'image/jpeg',
          'base64': base64Encode(bytes),
        };
        final actual = await database
            .doc(path)
            .get(const GetOptions(source: Source.server));
        expect(actual.data(), mediaRecord);

        // Только workspace нового disposable UID, не обычный app draft.
        final now = DateTime.now().toUtc();
        final main = PortfolioDocument(
          id: 'avatar-main',
          title: 'Портфолио',
          kind: PortfolioDocumentKind.portfolio,
          createdAt: now,
          updatedAt: now,
          content: PortfolioContent(
            profile: PortfolioProfile(avatarPath: path),
          ),
        );
        await FirestorePortfolioDraftRepository(
          firestore: database,
          uid: owner,
        ).write(
          CloudPortfolioDraft(
            ownerUid: owner,
            mutationId: 'avatar-$stamp',
            localRevision: 1,
            notes: '',
            content: PortfolioContent(
              documents: [main],
              mainPortfolioId: main.id,
            ),
          ),
        );
        final saved = await database
            .doc('accounts/$owner/drafts/current')
            .get(const GetOptions(source: Source.server));
        expect(saved.data()!['schemaVersion'], 7);
        expect(
          decodeCloudPortfolioDraft(
            saved.data()!,
            ownerUid: owner,
          ).content!.documents.single.content.profile.avatarPath,
          path,
        );
        await repository.dispose();
        repository = FirestorePortfolioMediaRepository(
          firestore: database,
          ownerUid: owner,
          isActive: () => auth.currentUser?.uid == owner,
        );
        expect(await repository.read(path), prepared.bytes);

        await expectLater(
          foreignDatabase
              .doc(path)
              .get(const GetOptions(source: Source.server)),
          throwsA(isA<FirebaseException>()),
        );
        final deniedPath = 'accounts/$owner/media/${'b' * 32}.jpg';
        await expectLater(
          foreignDatabase.doc(deniedPath).set(mediaRecord),
          throwsA(isA<FirebaseException>()),
        );
        await foreignAuth.signOut();
        await expectLater(
          foreignDatabase
              .doc(path)
              .get(const GetOptions(source: Source.server)),
          throwsA(isA<FirebaseException>()),
        );
        await expectLater(
          foreignDatabase.doc(deniedPath).set(mediaRecord),
          throwsA(isA<FirebaseException>()),
        );
        await expectLater(
          database.doc(path).set(mediaRecord),
          throwsA(isA<FirebaseException>()),
        );
        await expectLater(
          database
              .collection('accounts/$owner/media')
              .get(const GetOptions(source: Source.server)),
          throwsA(isA<FirebaseException>()),
        );

        // Emulator admin fixture: own disposable UID и demo loopback endpoint.
        await _lifecycle(host, firestorePort, owner, 'deleting');
        lifecycleFixture = true;
        await expectLater(
          database.doc(path).get(const GetOptions(source: Source.server)),
          throwsA(isA<FirebaseException>()),
        );
        await expectLater(
          database.doc(deniedPath).set(mediaRecord),
          throwsA(isA<FirebaseException>()),
        );
        await expectLater(
          repository.upload(prepared, onProgress: (_) {}),
          throwsA(isA<PortfolioMediaFailure>()),
        );
        await _lifecycle(host, firestorePort, owner, 'active');
        expect(await repository.read(path), prepared.bytes);
        await database.doc('accounts/$owner/drafts/current').delete();
        await repository.delete(path);
        path = null;
      } finally {
        if (ownerUid != null) {
          if (lifecycleFixture) {
            await _lifecycle(host, firestorePort, ownerUid, 'active');
          }
          if (path != null) {
            await database.doc(path).delete().catchError((_) {});
          }
          await database
              .doc('accounts/$ownerUid/drafts/current')
              .delete()
              .catchError((_) {});
          if (lifecycleFixture) {
            await _fixtureRequest(
              host,
              firestorePort,
              ownerUid,
              'DELETE',
              null,
            );
          }
        }
        await repository?.dispose();
        await auth.currentUser?.delete();
        if (foreignCreated && foreignAuth.currentUser == null) {
          await foreignAuth.signInWithEmailAndPassword(
            email: foreignEmail,
            password: password,
          );
        }
        await foreignAuth.currentUser?.delete();
        await database.terminate();
        await foreignDatabase.terminate();
        await ownerApp.delete();
        await foreignApp.delete();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _lifecycle(String host, int port, String uid, String state) =>
    _fixtureRequest(host, port, uid, 'PATCH', {
      'fields': {
        'lifecycleState': {'stringValue': state},
      },
    });

Future<void> _fixtureRequest(
  String host,
  int port,
  String uid,
  String method,
  Map<String, Object?>? data,
) async {
  if (!['10.0.2.2', '127.0.0.1', 'localhost'].contains(host) ||
      uid.isEmpty ||
      uid.contains('/')) {
    throw StateError('Only local disposable emulator fixtures are allowed');
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final uri = Uri.http(
      '$host:$port',
      '/v1/projects/demo-stackcard-test/databases/(default)/documents/accounts/$uid',
    );
    final request = await client.openUrl(method, uri);
    // Стандартный admin token эмулятора; не credential live Firebase.
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer owner');
    if (data != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
    }
    final response = await request.close().timeout(const Duration(seconds: 10));
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Local emulator fixture failed (${response.statusCode})',
      );
    }
  } finally {
    client.close(force: true);
  }
}
