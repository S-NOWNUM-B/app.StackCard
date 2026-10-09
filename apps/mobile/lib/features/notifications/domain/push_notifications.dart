enum PushPermission {
  notDetermined,
  denied,
  authorized,
  provisional,
  unavailable,
}

enum PushFailureKind {
  unavailable,
  unauthenticated,
  network,
  registration,
  cleanup,
}

final class PushFailure implements Exception {
  const PushFailure(this.kind);
  final PushFailureKind kind;
}

abstract interface class PushMessagingGateway {
  Future<PushPermission> permission({bool request = false});
  Future<void> setAutoInitEnabled(bool enabled);
  Future<String?> getToken();
  Future<void> deleteToken();
  Stream<String> get tokenRefresh;
  Stream<Map<String, dynamic>> get foreground;
  Stream<Map<String, dynamic>> get opened;
  Future<Map<String, dynamic>?> initialMessage();
}

abstract interface class PushDeviceRegistration {
  String get ownerUid;
  Future<void> register(String token);
  Future<void> unregister(String token);
}

abstract interface class PushConsentStore {
  Future<String?> readOwner();
  Future<void> writeOwner(String? ownerUid);
}

final class MemoryPushConsentStore implements PushConsentStore {
  String? ownerUid;
  @override
  Future<String?> readOwner() async => ownerUid;
  @override
  Future<void> writeOwner(String? owner) async {
    ownerUid = owner;
  }
}

final class PushNotificationState {
  const PushNotificationState({
    this.ownerUid,
    this.permission = PushPermission.unavailable,
    this.enabled = false,
    this.busy = false,
    this.failure,
    this.cleanupFailed = false,
    this.pendingRequestId,
    this.foregroundCount = 0,
  });
  final String? ownerUid, pendingRequestId;
  final PushPermission permission;
  final bool enabled, busy, cleanupFailed;
  final PushFailureKind? failure;
  final int foregroundCount;
}
