import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _SdkUser extends Fake implements User {
  _SdkUser({
    this.providers = const ['password'],
    this.email = 'owner@example.dev',
  });

  final List<String> providers;
  @override
  String get uid => 'real-firebase-uid';
  @override
  final String? email;
  @override
  String? get displayName => 'Owner';
  @override
  List<UserInfo> get providerData =>
      providers.map(_SdkProviderInfo.new).toList();
}

class _SdkProviderInfo extends Fake implements UserInfo {
  _SdkProviderInfo(this.providerId);

  @override
  final String providerId;
}

class _SdkCredential extends Fake implements UserCredential {
  _SdkCredential({this.isNewUser});

  final bool? isNewUser;

  @override
  User? get user => _SdkUser();

  @override
  AdditionalUserInfo? get additionalUserInfo =>
      isNewUser == null ? null : _SdkAdditionalUserInfo(isNewUser!);
}

class _SdkAdditionalUserInfo extends Fake implements AdditionalUserInfo {
  _SdkAdditionalUserInfo(this.isNewUser);

  @override
  final bool isNewUser;
}

class _SdkAuth extends Fake implements FirebaseAuth {
  final sessions = StreamController<User?>.broadcast();
  final operations = <String>[];
  String? lastEmail;
  String? lastPassword;
  AuthCredential? credential;
  Object? failure;
  bool? isNewUser;

  @override
  Stream<User?> authStateChanges() => sessions.stream;

  void _record(String operation) {
    operations.add(operation);
    if (failure != null) throw failure!;
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    _record('email');
    return _SdkCredential(isNewUser: isNewUser);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    lastEmail = email;
    lastPassword = password;
    _record('register');
    return _SdkCredential(isNewUser: isNewUser);
  }

  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    lastEmail = email;
    _record('reset');
  }

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    this.credential = credential;
    _record('google');
    return _SdkCredential(isNewUser: isNewUser);
  }

  @override
  Future<void> signOut() async => _record('signOut');
}

void main() {
  late _SdkAuth sdk;
  late FirebaseAccountAuthRepository repository;

  setUp(() {
    sdk = _SdkAuth();
    repository = FirebaseAccountAuthRepository(auth: sdk);
  });
  tearDown(() async => sdk.sessions.close());

  test(
    'Creation result reads SDK isNewUser and captured UID for both methods',
    () async {
      final google = FirebaseAccountAuthRepository(
        auth: sdk,
        googleCredential: () async =>
            GoogleAuthProvider.credential(idToken: 'fixture'),
      );
      for (final isNew in [true, false, null]) {
        sdk.isNewUser = isNew;
        final email = await repository.registerEmailWithResult(
          'owner@example.dev',
          'long password fixture',
        );
        final federated = await google.signInGoogleWithResult();
        for (final result in [email, federated]) {
          expect(result.uid, 'real-firebase-uid');
          expect(result.isNewUser, isNew == true);
        }
      }
    },
  );

  test(
    'SDK stream maps restored session and sign out to immutable domain values',
    () async {
      final values = <AuthUser?>[];
      final subscription = repository.watchSession().listen(values.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(Duration.zero);
      sdk.sessions.add(_SdkUser());
      sdk.sessions.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(values, [
        const AuthUser(
          uid: 'real-firebase-uid',
          email: 'owner@example.dev',
          displayName: 'Owner',
        ),
        null,
      ]);
    },
  );

  test('Stream errors expose safe failures without Firebase details', () async {
    final stream = repository.watchSession();
    final expectation = expectLater(
      stream,
      emitsError(
        isA<AuthFailure>().having(
          (failure) => failure.kind,
          'kind',
          AuthFailureKind.network,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    sdk.sessions.addError(
      FirebaseAuthException(
        code: 'network-request-failed',
        message: 'sensitive server payload',
      ),
    );
    await expectation;
  });

  test(
    'Session Google status comes from linked providers, not email',
    () async {
      final values = <AuthUser?>[];
      final subscription = repository.watchSession().listen(values.add);
      addTearDown(subscription.cancel);
      sdk.sessions.add(
        _SdkUser(email: 'owner@gmail.com', providers: const ['password']),
      );
      sdk.sessions.add(
        _SdkUser(email: 'owner@company.dev', providers: const ['google.com']),
      );
      sdk.sessions.add(_SdkUser(providers: const ['password', 'google.com']));
      sdk.sessions.add(_SdkUser(providers: const []));
      await Future<void>.delayed(Duration.zero);

      expect(values.map((user) => user!.hasGoogle), [false, true, true, false]);
      expect(values[0]!.email, 'owner@gmail.com');
      expect(values[1]!.email, 'owner@company.dev');
      expect(sdk.operations, isEmpty);
    },
  );

  test('Email operations trim addresses and preserve password bytes', () async {
    await repository.signInEmail(' owner@example.dev ', ' secret ');
    expect(sdk.lastEmail, 'owner@example.dev');
    expect(sdk.lastPassword, ' secret ');
    await repository.registerEmail(' new@example.dev ', ' different ');
    expect(sdk.lastEmail, 'new@example.dev');
    expect(sdk.lastPassword, ' different ');
    await repository.sendPasswordReset(' new@example.dev ');
    expect(sdk.operations, ['email', 'register', 'reset']);
  });

  test(
    'Firebase exception categories are safe and do not expose raw payloads',
    () async {
      const kinds = {
        'invalid-email': AuthFailureKind.invalidEmail,
        'weak-password': AuthFailureKind.weakPassword,
        'invalid-credential': AuthFailureKind.invalidCredentials,
        'user-not-found': AuthFailureKind.invalidCredentials,
        'wrong-password': AuthFailureKind.invalidCredentials,
        'email-already-in-use': AuthFailureKind.emailInUse,
        'user-disabled': AuthFailureKind.userDisabled,
        'network-request-failed': AuthFailureKind.network,
        'too-many-requests': AuthFailureKind.tooManyRequests,
        'operation-not-allowed': AuthFailureKind.configuration,
        'unrecognized': AuthFailureKind.unknown,
      };
      for (final entry in kinds.entries) {
        sdk.failure = FirebaseAuthException(
          code: entry.key,
          message: 'secret payload',
        );
        await expectLater(
          repository.signInEmail('owner@example.dev', 'secret'),
          throwsA(
            isA<AuthFailure>()
                .having((failure) => failure.kind, 'kind', entry.value)
                .having(
                  (failure) => failure.toString(),
                  'safe description',
                  isNot(contains('secret')),
                ),
          ),
        );
      }
    },
  );

  test(
    'Password reset does not reveal that an address is unregistered',
    () async {
      sdk.failure = FirebaseAuthException(code: 'user-not-found');
      await repository.sendPasswordReset('missing@example.dev');
      sdk.failure = FirebaseAuthException(code: 'network-request-failed');
      await expectLater(
        repository.sendPasswordReset('missing@example.dev'),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.network,
          ),
        ),
      );
    },
  );

  test(
    'Google credential is exchanged with Firebase without extra OAuth scopes',
    () async {
      final credential = GoogleAuthProvider.credential(
        idToken: 'test-id-token',
      );
      repository = FirebaseAccountAuthRepository(
        auth: sdk,
        googleCredential: () async => credential,
      );
      await repository.signInGoogle();
      expect(sdk.credential, same(credential));
      expect(sdk.operations, ['google']);
    },
  );

  test(
    'Google cancellation never calls Firebase and is a typed cancellation',
    () async {
      repository = FirebaseAccountAuthRepository(
        auth: sdk,
        googleCredential: () async => throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'raw message',
        ),
      );
      await expectLater(
        repository.signInGoogle(),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.kind,
            'kind',
            AuthFailureKind.cancelled,
          ),
        ),
      );
      expect(sdk.operations, isEmpty);
    },
  );

  test('Firebase sign out succeeds even if Google cleanup fails', () async {
    repository = FirebaseAccountAuthRepository(
      auth: sdk,
      googleSignOut: () async {
        expect(sdk.operations, ['signOut']);
        throw const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
        );
      },
    );
    await repository.signOut();
    expect(sdk.operations, ['signOut']);
  });
}
