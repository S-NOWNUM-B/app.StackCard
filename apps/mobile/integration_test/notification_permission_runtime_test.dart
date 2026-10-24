import 'dart:io';

import 'package:app_stackcard/features/notifications/data/firebase_push_messaging.dart';
import 'package:app_stackcard/features/notifications/notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in чтение статуса Android/iOS; request разрешён только на отдельном iOS Simulator.
/// Токены, Auth, consent store и данные обычного приложения не открываются.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment(
    'RUN_NOTIFICATION_PERMISSION_ACCEPTANCE',
  );
  const expectedName = String.fromEnvironment(
    'NOTIFICATION_EXPECTED_PERMISSION',
  );
  const request = bool.fromEnvironment('NOTIFICATION_REQUEST_PERMISSION');
  testWidgets(
    'native notification permission matches the system with auto-init disabled',
    (tester) async {
      expect(Platform.isAndroid || Platform.isIOS, isTrue);
      const allowed = {
        'notDetermined': PushPermission.notDetermined,
        'authorized': PushPermission.authorized,
        'denied': PushPermission.denied,
      };
      expect(allowed, contains(expectedName));
      if (request) {
        expect(Platform.isIOS, isTrue);
        expect({'denied', 'authorized'}, contains(expectedName));
      }
      await Firebase.initializeApp();
      final sdk = FirebaseMessaging.instance;
      expect(
        sdk.isAutoInitEnabled,
        isFalse,
        reason: 'Acceptance must not create or refresh an FCM token.',
      );
      final gateway = FirebasePushMessaging(sdk);
      if (request) {
        expect(await gateway.permission(), PushPermission.notDetermined);
        expect(sdk.isAutoInitEnabled, isFalse);
        // ignore: avoid_print
        print('STACKCARD_NOTIFICATION_ACCEPTANCE:READY expected=$expectedName');
        expect(await gateway.permission(request: true), allowed[expectedName]);
      }
      expect(await gateway.permission(), allowed[expectedName]);
      // Повторное чтение не меняет решение системы и не открывает permission prompt.
      expect(await gateway.permission(), allowed[expectedName]);
      expect(sdk.isAutoInitEnabled, isFalse);
      if (request) {
        // ignore: avoid_print
        print('STACKCARD_NOTIFICATION_ACCEPTANCE:PASS expected=$expectedName');
      }
    },
    skip: !enabled,
  );
}
