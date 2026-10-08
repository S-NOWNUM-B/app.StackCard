import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _Info extends Fake implements UserInfo {
  _Info(this.providerId);
  @override
  final String providerId;
}

class _Credential extends Fake implements UserCredential {}

class _User extends Fake implements User {
  _User(this.uid, this.providers);
  @override
  final String uid;
  final List<String> providers;
  final actions = <String>[];
  final List<AuthCredential> credentials = [];
  Completer<void>? reloadGate;
  Object? failure;
  String? changedEmail;
  String? changedPassword;
  @override
  String? get email => 'login@example.com';
  @override
  bool get emailVerified => true;
  @override
  List<UserInfo> get providerData => providers.map(_Info.new).toList();
  @override
  Future<void> reload() async {
    actions.add('reload');
    await reloadGate?.future;
  }

  @override
  Future<void> sendEmailVerification([ActionCodeSettings? settings]) async {
    actions.add('verify');
    if (failure != null) throw failure!;
  }

  @override
  Future<void> verifyBeforeUpdateEmail(
    String value, [
    ActionCodeSettings? settings,
  ]) async {
    changedEmail = value;
    actions.add('email');
  }

  @override
  Future<void> updatePassword(String value) async {
    changedPassword = value;
    actions.add('password');
    if (failure != null) throw failure!;
  }

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential value,
  ) async {
    credentials.add(value);
    actions.add('reauth');
    return _Credential();
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    actions.add(forceRefresh ? 'refreshToken' : 'token');
    return 'test';
  }

  @override
  Future<UserCredential> linkWithCredential(AuthCredential value) async {
    credentials.add(value);
    actions.add('link');
    return _Credential();
  }

  @override
  Future<User> unlink(String provider) async {
    actions.add('unlink:$provider');
    providers.remove(provider);
    return this;
  }
}

class _Auth extends Fake implements FirebaseAuth {
  _Auth(this.currentUser);
  @override
  User? currentUser;
}

void main() {
  late _User user;
  late _Auth sdk;
  late FirebaseAccountAuthRepository repository;
  setUp(() {
    user = _User('owner', ['password']);
    sdk = _Auth(user);
    repository = FirebaseAccountAuthRepository(auth: sdk);
  });
  Matcher failure(AccountManagementFailureKind kind) =>
      isA<AccountManagementFailure>().having((e) => e.kind, 'kind', kind);
  test(
    'security inventory is read from SDK and provider set is immutable',
    () async {
      final security = await repository.readSecurity('owner');
      expect(security.emailVerified, isTrue);
      expect(security.hasPassword, isTrue);
      expect(security.hasGoogle, isFalse);
      expect(
        () => security.providers.add('google.com'),
        throwsUnsupportedError,
      );
    },
  );
  test('incorrect UID cannot access or mutate the current account', () async {
    await expectLater(
      repository.changePassword('different', 'secret'),
      throwsA(failure(AccountManagementFailureKind.ownerChanged)),
    );
    expect(user.actions, isEmpty);
  });
  test('password reauthentication refreshes backend recent-auth token and preserves bytes', () async {
    await repository.reauthenticatePassword('owner', ' secret ');
    expect(user.actions, ['reauth', 'refreshToken']);
    expect(user.credentials.single, isA<EmailAuthCredential>());
    expect(
      (user.credentials.single as EmailAuthCredential).password,
      ' secret ',
    );
  });
  test(
    'email change requests confirmation and never writes public profile',
    () async {
      await repository.requestEmailChange('owner', ' next@example.com ');
      expect(user.changedEmail, 'next@example.com');
      expect(user.actions, ['email']);
    },
  );
  test('last provider is protected by current SDK inventory', () async {
    await expectLater(
      repository.unlinkProvider('owner', 'password'),
      throwsA(failure(AccountManagementFailureKind.lastProvider)),
    );
    expect(user.providers, ['password']);
    expect(user.actions, ['reload']);
  });
  test(
    'unlink rechecks UID after SDK reload before changing providers',
    () async {
      user.providers.add('google.com');
      user.reloadGate = Completer<void>();
      final pending = repository.unlinkProvider('owner', 'password');
      final expected = expectLater(
        pending,
        throwsA(failure(AccountManagementFailureKind.ownerChanged)),
      );
      await Future<void>.delayed(Duration.zero);
      sdk.currentUser = _User('different', ['password']);
      user.reloadGate!.complete();
      await expected;
      expect(user.providers, ['password', 'google.com']);
    },
  );
  test(
    'unsupported provider cannot replace the last usable app sign-in method',
    () async {
      user.providers.add('unsupported-provider');
      expect(
        (await repository.readSecurity('owner')).canUnlink('password'),
        isFalse,
      );
      await expectLater(
        repository.unlinkProvider('owner', 'password'),
        throwsA(failure(AccountManagementFailureKind.lastProvider)),
      );
      expect(user.providers, ['password', 'unsupported-provider']);
    },
  );

  test('existing alternative provider allows unlink', () async {
    user.providers.add('google.com');
    await repository.unlinkProvider('owner', 'password');
    expect(user.providers, ['google.com']);
  });
  test('requires recent login exposes typed failure without sensitive SDK messages', () async {
    user.failure = FirebaseAuthException(
      code: 'requires-recent-login',
      message: 'private payload',
    );
    await expectLater(
      repository.changePassword('owner', 'new-secret'),
      throwsA(failure(AccountManagementFailureKind.reauthenticationRequired)),
    );
  });
  test(
    'UID change while Google picker is open prevents credential link',
    () async {
      final gate = Completer<AuthCredential>();
      repository = FirebaseAccountAuthRepository(
        auth: sdk,
        googleCredential: () => gate.future,
      );
      final pending = repository.linkGoogle('owner');
      final expected = expectLater(
        pending,
        throwsA(failure(AccountManagementFailureKind.ownerChanged)),
      );
      await Future<void>.delayed(Duration.zero);
      sdk.currentUser = _User('different', ['password']);
      gate.complete(GoogleAuthProvider.credential(idToken: 'sample'));
      await expected;
      expect(user.credentials, isEmpty);
    },
  );
}
