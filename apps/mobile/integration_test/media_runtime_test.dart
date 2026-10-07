import 'package:app_stackcard/features/media/media.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:integration_test/integration_test.dart';

/// Только локальные emulators и named apps; обычный account/draft не меняется.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_MEDIA_ACCEPTANCE');
  const host = String.fromEnvironment(
    'MEDIA_EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  const options = FirebaseOptions(
    apiKey: 'emulator-only-key',
    appId: '1:123456789:android:0123456789abcdef',
    messagingSenderId: '123456789',
    projectId: 'demo-stackcard-test',
    storageBucket: 'demo-stackcard-test.appspot.com',
  );
  testWidgets(
    'native Storage upload/read/retry and private ownership',
    (tester) async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final ownerApp = await Firebase.initializeApp(
        name: 'media-owner-$stamp',
        options: options,
      );
      final foreignApp = await Firebase.initializeApp(
        name: 'media-foreign-$stamp',
        options: options,
      );
      final ownerAuth = FirebaseAuth.instanceFor(app: ownerApp);
      final foreignAuth = FirebaseAuth.instanceFor(app: foreignApp);
      final storage = FirebaseStorage.instanceFor(app: ownerApp);
      final foreignStorage = FirebaseStorage.instanceFor(app: foreignApp);
      String? path;
      FirebasePortfolioMediaRepository? repository;
      try {
        await ownerAuth.useAuthEmulator(host, 9099);
        await foreignAuth.useAuthEmulator(host, 9099);
        await storage.useStorageEmulator(host, 9199);
        await foreignStorage.useStorageEmulator(host, 9199);
        final user = (await ownerAuth.createUserWithEmailAndPassword(
          email: 'media.owner.$stamp@example.invalid',
          password: 'EmulatorOnly-$stamp!',
        )).user!;
        await foreignAuth.createUserWithEmailAndPassword(
          email: 'media.foreign.$stamp@example.invalid',
          password: 'EmulatorOnly-$stamp!',
        );
        repository = FirebasePortfolioMediaRepository(
          storage: storage,
          ownerUid: user.uid,
          isActive: () => ownerAuth.currentUser?.uid == user.uid,
        );
        final source = image.Image(width: 64, height: 48);
        image.fill(source, color: image.ColorRgb8(120, 170, 80));
        final prepared = await const PortfolioImageProcessor().prepare(
          image.encodePng(source),
          mimeType: 'image/png',
        );
        final progress = <double>[];
        path = await repository.upload(prepared, onProgress: progress.add);
        expect(isPortfolioMediaPathForOwner(path, user.uid), isTrue);
        expect(progress, isNotEmpty);
        expect(progress.last, 1);
        final bytes = await repository.read(path);
        expect(bytes, prepared.bytes);
        expect(image.decodeJpg(bytes)?.width, 64);
        await expectLater(
          foreignStorage.ref(path).getData(portfolioImageMaxBytes),
          throwsA(isA<FirebaseException>()),
        );
        await foreignAuth.signOut();
        await expectLater(
          foreignStorage.ref(path).getData(portfolioImageMaxBytes),
          throwsA(isA<FirebaseException>()),
        );
        // Отказ не повреждает выбранное изображение; retry нового repo успешен.
        final unavailable = FirebasePortfolioMediaRepository(
          storage: storage,
          ownerUid: user.uid,
          isActive: () => false,
        );
        await expectLater(
          unavailable.upload(prepared, onProgress: (_) {}),
          throwsA(isA<PortfolioMediaFailure>()),
        );
        await unavailable.dispose();
        expect(await repository.read(path), prepared.bytes);
        await repository.delete(path);
        path = null;
      } finally {
        if (path != null) {
          await storage.ref(path).delete().catchError((_) {});
        }
        await repository?.dispose();
        await ownerAuth.currentUser?.delete();
        // foreign user после signOut нужен только локальному emulator namespace.
        await ownerApp.delete();
        await foreignApp.delete();
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
