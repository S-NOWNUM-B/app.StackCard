import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/push_notifications.dart';
import 'notifications_controller.dart';

final notificationsControllerProvider = Provider<NotificationsController?>(
  (ref) => null,
);
final notificationStateProvider = StreamProvider<PushNotificationState>(
  (ref) =>
      ref.watch(notificationsControllerProvider)?.states ??
      Stream.value(const PushNotificationState()),
  retry: (_, _) => null,
);
