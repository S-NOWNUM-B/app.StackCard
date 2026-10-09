import 'dart:async';

import '../inbox/inbox.dart';
import 'domain/push_notifications.dart';

/// Одна очередь SDK на приложение: старый deleteToken не удалит новый token.
final class NotificationsController {
  NotificationsController({
    required this.messaging,
    required this.registrationForOwner,
    PushConsentStore? consent,
  }) : consent = consent ?? MemoryPushConsentStore() {
    _ready = _initialize();
    _subscriptions.add(
      messaging.opened.listen(
        _tap,
        onError: (_) => _fail(PushFailureKind.unavailable),
      ),
    );
    _subscriptions.add(
      messaging.foreground.listen(
        _foreground,
        onError: (_) => _fail(PushFailureKind.unavailable),
      ),
    );
    _subscriptions.add(
      messaging.tokenRefresh.listen(
        _refresh,
        onError: (_) => _fail(PushFailureKind.registration),
      ),
    );
  }
  final PushMessagingGateway messaging;
  final PushDeviceRegistration? Function(String uid) registrationForOwner;
  final PushConsentStore consent;
  final _events = StreamController<PushNotificationState>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  late final Future<void> _ready;
  Future<void> _work = Future.value();
  String? _owner, _consentedOwner, _token, _tokenOwner, _pendingTap;
  Map<String, dynamic>? _coldTap;
  int _generation = 0, _foregroundCount = 0;
  bool _ownerSet = false,
      _disposed = false,
      _enabled = false,
      _busy = false,
      _cleanupFailed = false;
  PushPermission _permission = PushPermission.unavailable;
  PushFailureKind? _failure;
  PushNotificationState get state => PushNotificationState(
    ownerUid: _owner,
    permission: _permission,
    enabled: _enabled,
    busy: _busy,
    failure: _failure,
    cleanupFailed: _cleanupFailed,
    pendingRequestId: _pendingTap,
    foregroundCount: _foregroundCount,
  );
  Stream<PushNotificationState> get states => Stream.multi((listener) {
    // Подписка устанавливается до initial value, чтобы быстрый ACK не потерялся между yield.
    final subscription = _events.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.add(state);
    listener.onCancel = subscription.cancel;
  }, isBroadcast: true);

  bool _active(int generation, String? uid) =>
      !_disposed && generation == _generation && uid == _owner;
  void _publish() {
    if (!_disposed) _events.add(state);
  }

  void _fail(PushFailureKind failure) {
    if (!_disposed) {
      _failure = failure;
      _publish();
    }
  }

  Future<void> _initialize() async {
    try {
      await messaging.setAutoInitEnabled(false);
      _consentedOwner = await consent.readOwner();
      _permission = await messaging.permission();
      final initialGeneration = _generation, initiallyRestoring = !_ownerSet;
      final initial = await messaging.initialMessage();
      if (initial != null &&
          (initialGeneration == _generation ||
              (initiallyRestoring && _generation == 1))) {
        _tap(initial);
      }
    } catch (_) {
      _failure = PushFailureKind.unavailable;
    }
    _publish();
  }

  Future<void> _queue(Future<void> Function() action) {
    _work = _work.then((_) => action()).catchError((Object error) {
      if (!_disposed) {
        _fail(error is PushFailure ? error.kind : PushFailureKind.unavailable);
      }
    });
    return _work;
  }

  /// Вызывается при подтверждённом restore/session transition, без permission prompt.
  Future<void> setOwner(String? uid) {
    if (_disposed || (_ownerSet && _owner == uid)) return Future.value();
    final oldOwner = _owner;
    _ownerSet = true;
    _owner = uid;
    final generation = ++_generation;
    _enabled = false;
    _busy = true;
    _failure = null;
    _pendingTap = null;
    _foregroundCount = 0;
    _publish();
    return _queue(() async {
      await _ready;
      final rememberedOwner = _consentedOwner;
      if (oldOwner != null ||
          (rememberedOwner != null && rememberedOwner != uid)) {
        await _cleanup();
      }
      if (!_active(generation, uid)) return;
      final cold = _coldTap;
      _coldTap = null;
      if (cold != null) _tap(cold);
      if (uid != null && rememberedOwner == uid && !_cleanupFailed) {
        await _enable(generation, uid, request: false);
      } else {
        _busy = false;
        _publish();
      }
    });
  }

  Future<void> enable() {
    final uid = _owner, generation = _generation;
    if (uid == null || _disposed || _busy) return Future.value();
    _busy = true;
    _failure = null;
    _publish();
    return _queue(() async {
      await _ready;
      await _enable(generation, uid, request: true);
    });
  }

  Future<void> _enable(
    int generation,
    String uid, {
    required bool request,
  }) async {
    try {
      if (!_active(generation, uid)) return;
      final registration = registrationForOwner(uid);
      if (registration == null ||
          registration.ownerUid != uid ||
          _cleanupFailed) {
        throw const PushFailure(PushFailureKind.unavailable);
      }
      final permission = await messaging.permission(request: request);
      if (!_active(generation, uid)) return;
      _permission = permission;
      if (permission != PushPermission.authorized &&
          permission != PushPermission.provisional) {
        _enabled = false;
        await _cleanup();
        return;
      }
      final token = await messaging.getToken();
      if (token == null || token.isEmpty || token.length > 4096) {
        throw const PushFailure(PushFailureKind.registration);
      }
      _token = token;
      _tokenOwner = uid;
      if (!_active(generation, uid)) return;
      await registration.register(token);
      if (!_active(generation, uid)) return;
      await consent.writeOwner(uid);
      if (!_active(generation, uid)) return;
      _consentedOwner = uid;
      // Auto-init остаётся выключенным; явный getToken создаёт регистрацию.
      _enabled = true;
    } catch (error) {
      if (_active(generation, uid)) {
        _failure = error is PushFailure
            ? error.kind
            : PushFailureKind.registration;
      }
    } finally {
      if (_active(generation, uid)) {
        _busy = false;
        _publish();
      }
    }
  }

  Future<void> disable() {
    if (_disposed) return Future.value();
    final generation = ++_generation, uid = _owner;
    _enabled = false;
    _pendingTap = null;
    _busy = true;
    _failure = null;
    _publish();
    return _queue(() async {
      await _ready;
      await _cleanup();
      if (_active(generation, uid)) {
        _busy = false;
        _publish();
      }
    });
  }

  /// Системное разрешение могло измениться вне приложения; повторного prompt нет.
  Future<void> refreshPermission() {
    final uid = _owner, generation = _generation;
    if (_disposed) return Future.value();
    return _queue(() async {
      await _ready;
      if (!_active(generation, uid)) return;
      _busy = true;
      _publish();
      try {
        final permission = await messaging.permission();
        if (!_active(generation, uid)) return;
        _permission = permission;
        if (permission != PushPermission.authorized &&
            permission != PushPermission.provisional) {
          final registered =
              _enabled || _token != null || _consentedOwner != null;
          _enabled = false;
          if (registered) {
            await _cleanup();
          }
        }
      } catch (_) {
        if (_active(generation, uid)) {
          _failure = PushFailureKind.unavailable;
        }
      } finally {
        if (_active(generation, uid)) {
          _busy = false;
          _publish();
        }
      }
    });
  }

  Future<void> _cleanup() async {
    var failed = false;
    try {
      await messaging.setAutoInitEnabled(false);
    } catch (_) {
      failed = true;
    }
    final token = _token, owner = _tokenOwner;
    if (token != null && owner != null) {
      try {
        final registration = registrationForOwner(owner);
        if (registration == null) {
          throw const PushFailure(PushFailureKind.unavailable);
        }
        await registration.unregister(token);
      } catch (_) {
        failed = true;
      }
    }
    try {
      await messaging.deleteToken();
      _token = null;
      _tokenOwner = null;
    } catch (_) {
      failed = true;
    }
    try {
      await consent.writeOwner(null);
      _consentedOwner = null;
    } catch (_) {
      failed = true;
    }
    _cleanupFailed = failed;
    if (failed) _failure = PushFailureKind.cleanup;
  }

  bool _messageForOwner(Map<String, dynamic> message) =>
      message.length == 3 &&
      message['type'] == 'contactRequest' &&
      message['ownerUid'] == _owner &&
      _owner != null &&
      message['requestId'] is String &&
      isContactRequestId(message['requestId'] as String);
  void _tap(Map<String, dynamic> message) {
    if (_disposed) return;
    if (!_ownerSet) {
      _coldTap = Map.of(message);
      return;
    }
    if (_messageForOwner(message)) {
      _pendingTap = message['requestId'] as String;
      _publish();
    }
  }

  void _foreground(Map<String, dynamic> message) {
    if (!_disposed && _messageForOwner(message)) {
      ++_foregroundCount;
      _publish();
    }
  }

  void consumeTap(String uid, String requestId) {
    if (uid == _owner && _pendingTap == requestId) {
      _pendingTap = null;
      _publish();
    }
  }

  void _refresh(String token) {
    final uid = _owner, generation = _generation;
    if (!_enabled || uid == null || _disposed) return;
    _queue(() async {
      if (!_active(generation, uid) || !_enabled) return;
      try {
        // Позднее событие старого SDK token не привязывается к новому UID.
        if (await messaging.getToken() != token || !_active(generation, uid)) {
          return;
        }
        final registration = registrationForOwner(uid);
        if (registration == null) {
          throw const PushFailure(PushFailureKind.unavailable);
        }
        final oldToken = _token;
        await registration.register(token);
        if (!_active(generation, uid)) return;
        _token = token;
        _tokenOwner = uid;
        if (oldToken != null && oldToken != token) {
          await registration.unregister(oldToken);
        }
      } catch (error) {
        if (_active(generation, uid)) {
          _fail(
            error is PushFailure ? error.kind : PushFailureKind.registration,
          );
        }
      }
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _enabled = false;
    _pendingTap = null;
    _coldTap = null;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    // Закрытие UI не отзывает согласие: background push после закрытия приложения разрешён владельцем.
    await _work;
    await _events.close();
  }
}
