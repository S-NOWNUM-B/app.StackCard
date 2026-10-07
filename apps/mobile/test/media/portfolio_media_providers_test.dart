import 'dart:async';
import 'dart:typed_data';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _failure(PortfolioMediaFailureKind kind) => isA<PortfolioMediaFailure>()
    .having((failure) => failure.kind, 'kind', kind);

class _Auth extends Fake implements AccountAuthRepository {
  final sessions = StreamController<AuthUser?>.broadcast();
  @override
  Stream<AuthUser?> watchSession() => sessions.stream;
}

class _Media
    implements PortfolioMediaRepository, PortfolioMediaRepositoryLifecycle {
  _Media(this.ownerUid);
  @override
  final String ownerUid;
  final reads = <String>[];
  final deletes = <String>[];
  final progress = <void Function(double)>[];
  Completer<String>? uploadCompletion;
  Completer<Uint8List>? readCompletion;
  int disposed = 0;
  Object? readFailure;

  @override
  Future<String> upload(
    PreparedPortfolioImage image, {
    required void Function(double) onProgress,
  }) {
    progress.add(onProgress);
    return (uploadCompletion = Completer<String>()).future;
  }

  @override
  Future<Uint8List> read(String path) async {
    reads.add(path);
    if (readFailure != null) throw readFailure!;
    return readCompletion?.future ?? Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> delete(String path) async => deletes.add(path);

  @override
  Future<void> dispose() async => disposed++;
}

String _path(String uid) =>
    'accounts/$uid/media/0123456789abcdef0123456789abcdef.jpg';

void main() {
  test(
    'Unconfigured or explicit guest session never builds a media repository',
    () async {
      var built = 0;
      final container = ProviderContainer(
        overrides: [
          portfolioMediaRepositoryFactoryProvider.overrideWithValue((uid) {
            built++;
            return _Media(uid);
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(guestAccessProvider.notifier).enter();
      expect(container.read(portfolioMediaRepositoryProvider), isNull);
      expect(built, 0);
      await expectLater(
        container.read(portfolioMediaBytesProvider(_path('owner')).future),
        throwsA(_failure(PortfolioMediaFailureKind.unauthenticated)),
      );
    },
  );

  test(
    'Restoring, signed out, error and wrong-owner factory block private media',
    () async {
      final auth = _Auth();
      addTearDown(auth.sessions.close);
      final container = ProviderContainer(
        overrides: [
          accountAuthRepositoryProvider.overrideWithValue(auth),
          portfolioMediaRepositoryFactoryProvider.overrideWithValue(
            (_) => _Media('other'),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(portfolioMediaRepositoryProvider, (_, _) {});
      expect(container.read(portfolioMediaRepositoryProvider), isNull);
      await container.pump();
      auth.sessions.add(null);
      await container.pump();
      container.read(guestAccessProvider.notifier).enter();
      expect(container.read(portfolioMediaRepositoryProvider), isNull);
      auth.sessions.add(const AuthUser(uid: 'owner'));
      await container.pump();
      expect(container.read(portfolioMediaRepositoryProvider), isNull);
      auth.sessions.addError(StateError('session unavailable'));
      await container.pump();
      expect(container.read(portfolioMediaRepositoryProvider), isNull);
    },
  );

  test(
    'UID transition disposes old owner and ignores late upload/progress',
    () async {
      final auth = _Auth();
      addTearDown(auth.sessions.close);
      final repositories = <String, _Media>{};
      final container = ProviderContainer(
        overrides: [
          accountAuthRepositoryProvider.overrideWithValue(auth),
          portfolioMediaRepositoryFactoryProvider.overrideWithValue(
            (uid) => repositories.putIfAbsent(uid, () => _Media(uid)),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(portfolioMediaRepositoryProvider, (_, _) {});
      await container.pump();
      auth.sessions.add(const AuthUser(uid: 'owner'));
      await container.pump();
      final old = container.read(portfolioMediaRepositoryProvider)!;
      final progress = <double>[];
      final upload = old.upload(
        PreparedPortfolioImage(Uint8List.fromList([1])),
        onProgress: progress.add,
      );
      final expectation = expectLater(
        upload,
        throwsA(_failure(PortfolioMediaFailureKind.unauthenticated)),
      );
      auth.sessions.add(const AuthUser(uid: 'other'));
      await container.pump();
      expect(
        container.read(portfolioMediaRepositoryProvider)!.ownerUid,
        'other',
      );
      expect(repositories['owner']!.disposed, 1);
      repositories['owner']!.progress.single(1);
      repositories['owner']!.uploadCompletion!.complete(_path('owner'));
      await expectation;
      expect(progress, isEmpty);
      expect(repositories['owner']!.deletes, [_path('owner')]);
      expect(repositories['other']!.deletes, isEmpty);
    },
  );

  test('Memory image cache is owner scoped and explicit retry repeats a failed read', () async {
    final auth = _Auth();
    addTearDown(auth.sessions.close);
    final repositories = <String, _Media>{};
    final container = ProviderContainer(
      overrides: [
        accountAuthRepositoryProvider.overrideWithValue(auth),
        portfolioMediaRepositoryFactoryProvider.overrideWithValue(
          (uid) => repositories.putIfAbsent(uid, () => _Media(uid)),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(portfolioMediaRepositoryProvider, (_, _) {});
    await container.pump();
    auth.sessions.add(const AuthUser(uid: 'owner'));
    await container.pump();
    final provider = portfolioMediaBytesProvider(_path('owner'));
    container.listen(provider, (_, _) {});
    expect(await container.read(provider.future), [1, 2, 3]);
    expect(await container.read(provider.future), [1, 2, 3]);
    expect(repositories['owner']!.reads.length, 1);
    auth.sessions.add(const AuthUser(uid: 'other'));
    await container.pump();
    await expectLater(
      container.read(provider.future),
      throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
    );
    expect(repositories['other']!.reads, isEmpty);

    final currentProvider = portfolioMediaBytesProvider(_path('other'));
    repositories['other']!.readFailure = const PortfolioMediaFailure(
      PortfolioMediaFailureKind.unavailable,
    );
    container.listen(currentProvider, (_, _) {});
    await expectLater(
      container.read(currentProvider.future),
      throwsA(_failure(PortfolioMediaFailureKind.unavailable)),
    );
    await container.pump();
    expect(repositories['other']!.reads.length, 1);
    repositories['other']!.readFailure = null;
    container.invalidate(currentProvider);
    expect(await container.read(currentProvider.future), [1, 2, 3]);
    expect(repositories['other']!.reads.length, 2);
  });
}
