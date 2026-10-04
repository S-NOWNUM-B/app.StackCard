import 'package:app_stackcard/features/auth/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
// Прямой доступ к установленному platform interface нужен только для fake SDK.
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class _GooglePlatform extends GoogleSignInPlatform {
  int initializations = 0;
  int authentications = 0;
  bool failInitialization = true;
  String? idToken = 'test-token';
  InitParameters? parameters;

  @override
  Future<void> init(InitParameters params) async {
    initializations++;
    parameters = params;
    if (failInitialization) {
      throw const GoogleSignInException(
        code: GoogleSignInExceptionCode.clientConfigurationError,
      );
    }
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authentications++;
    return AuthenticationResults(
      user: const GoogleSignInUserData(
        email: 'owner@example.dev',
        id: 'google-id',
      ),
      authenticationTokens: AuthenticationTokenData(idToken: idToken),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _GoogleSdkCredential extends Fake implements UserCredential {}

class _GoogleFirebaseAuth extends Fake implements FirebaseAuth {
  final credentials = <AuthCredential>[];

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credentials.add(credential);
    return _GoogleSdkCredential();
  }
}

void main() {
  test(
    'Google initialization retries failure, then is shared across repositories',
    () async {
      final original = GoogleSignInPlatform.instance;
      addTearDown(() => GoogleSignInPlatform.instance = original);
      final platform = _GooglePlatform();
      GoogleSignInPlatform.instance = platform;
      final sdk = _GoogleFirebaseAuth();
      final first = FirebaseAccountAuthRepository(
        auth: sdk,
        googleClientId: 'test-client',
        googleServerClientId: 'test-server-client',
      );
      await expectLater(
        first.signInGoogle(),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.kind,
            'kind',
            AuthFailureKind.configuration,
          ),
        ),
      );
      expect(platform.authentications, 0);
      platform.failInitialization = false;
      await first.signInGoogle();
      await FirebaseAccountAuthRepository(auth: sdk).signInGoogle();
      expect(platform.initializations, 2);
      expect(platform.authentications, 2);
      expect(platform.parameters!.clientId, 'test-client');
      expect(platform.parameters!.serverClientId, 'test-server-client');
      expect(
        sdk.credentials.every(
          (credential) => credential.providerId == 'google.com',
        ),
        isTrue,
      );

      platform.idToken = null;
      await expectLater(
        first.signInGoogle(),
        throwsA(
          isA<AuthFailure>().having(
            (error) => error.kind,
            'kind',
            AuthFailureKind.configuration,
          ),
        ),
      );
      expect(sdk.credentials, hasLength(2));
    },
  );
}
