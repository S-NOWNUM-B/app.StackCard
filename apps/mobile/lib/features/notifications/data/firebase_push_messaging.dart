import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/push_notifications.dart';

final class FirebasePushMessaging implements PushMessagingGateway {
  FirebasePushMessaging(this.messaging);
  final FirebaseMessaging messaging;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    final settings = request
        ? await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
          )
        : await messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => PushPermission.authorized,
      AuthorizationStatus.provisional => PushPermission.provisional,
      AuthorizationStatus.denied ||
      AuthorizationStatus.deniedPermanently => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.notDetermined,
    };
  }

  @override
  Future<void> setAutoInitEnabled(bool enabled) =>
      messaging.setAutoInitEnabled(enabled);
  @override
  Future<String?> getToken() => messaging.getToken();
  @override
  Future<void> deleteToken() => messaging.deleteToken();
  @override
  Stream<String> get tokenRefresh => messaging.onTokenRefresh;
  @override
  Stream<Map<String, dynamic>> get foreground =>
      FirebaseMessaging.onMessage.map((message) => message.data);
  @override
  Stream<Map<String, dynamic>> get opened =>
      FirebaseMessaging.onMessageOpenedApp.map((message) => message.data);
  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      (await messaging.getInitialMessage())?.data;
}

/// Сохраняется только явное разрешение конкретного UID, без токена или payload.
final class SharedPreferencesPushConsentStore implements PushConsentStore {
  SharedPreferencesPushConsentStore(this.preferences);
  final SharedPreferencesAsync preferences;
  static const _key = 'notifications.enabledOwner';
  @override
  Future<String?> readOwner() async {
    final value = await preferences.getString(_key);
    return value != null && value.isNotEmpty && !value.contains('/')
        ? value
        : null;
  }

  @override
  Future<void> writeOwner(String? ownerUid) async {
    if (ownerUid == null) {
      await preferences.remove(_key);
    } else {
      await preferences.setString(_key, ownerUid);
    }
    if (await readOwner() != ownerUid) {
      throw const PushFailure(PushFailureKind.registration);
    }
  }
}
