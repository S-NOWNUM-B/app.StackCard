import 'dart:io';

import 'package:app_stackcard/features/notifications/data/firebase_push_messaging.dart';
import 'package:app_stackcard/features/notifications/notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in проверка системного статуса; токены, Auth и данные приложения не изменяются.
/// POST_NOTIFICATIONS задаётся снаружи и восстанавливается после native прогона.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment(
    'RUN_NOTIFICATION_PERMISSION_ACCEPTANCE',
  );
  const expectedName = String.fromEnvironment(
    'NOTIFICATION_EXPECTED_PERMISSION',
  );
  testWidgets(
    'native Android notification permission matches the system without a prompt',
    (tester) async {
      expect(Platform.isAndroid, isTrue);
      const allowed = {
        'notDetermined': PushPermission.notDetermined,
        'authorized': PushPermission.authorized,
        'denied': PushPermission.denied,
      };
      expect(allowed, contains(expectedName));
      await Firebase.initializeApp();
      final sdk = FirebaseMessaging.instance;
      expect(
        sdk.isAutoInitEnabled,
        isFalse,
        reason: 'Acceptance must not create or refresh an FCM token.',
      );
      final gateway = FirebasePushMessaging(sdk);
      expect(await gateway.permission(), allowed[expectedName]);
      // Повторное чтение не меняет решение системы и не открывает permission prompt.
      expect(await gateway.permission(), allowed[expectedName]);
      expect(sdk.isAutoInitEnabled, isFalse);
    },
    skip: !enabled,
  );
}
