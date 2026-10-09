import 'dart:async';

import 'package:app_stackcard/features/notifications/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/inbox_fakes.dart';

void main() {
  late TestMessaging messaging;
  late NotificationsController controller;
  late Map<String, TestRegistration> devices;
  late MemoryPushConsentStore consent;
  setUp(() {
    messaging = TestMessaging();
    devices = {'a': TestRegistration('a'), 'b': TestRegistration('b')};
    consent = MemoryPushConsentStore();
    controller = NotificationsController(
      messaging: messaging,
      registrationForOwner: (uid) => devices[uid],
      consent: consent,
    );
  });
  tearDown(() async {
    await controller.dispose();
    await messaging.close();
  });

  test('session restore never prompts or creates a token; denied explicit enable registers nothing', () async {
    messaging.status = PushPermission.denied;
    await controller.setOwner('a');
    expect(messaging.calls, ['auto-init:false', 'permission-status']);
    await controller.enable();
    expect(
      messaging.calls.where((call) => call == 'permission-request'),
      hasLength(1),
    );
    expect(messaging.calls, isNot(contains('get-token')));
    expect(devices['a']!.trace, isEmpty);
    expect(consent.ownerUid, isNull);
    expect(controller.state.permission, PushPermission.denied);
    expect(controller.state.enabled, isFalse);
    expect(controller.state.busy, isFalse);
  });
  test('late token from A is cleaned before B can explicitly register its own token', () async {
    final ready = Completer<void>(), token = Completer<String?>();
    await controller.setOwner('a');
    messaging.tokenAction = () {
      ready.complete();
      return token.future;
    };
    final enabling = controller.enable();
    await ready.future;
    final switching = controller.setOwner('b');
    token.complete('late-a');
    await enabling;
    await switching;
    expect(controller.state.ownerUid, 'b');
    expect(controller.state.enabled, isFalse);
    expect(devices['a']!.trace, ['unregister:a:late-a']);
    expect(devices['b']!.trace, isEmpty);
    expect(messaging.calls.last, 'delete-token');
    messaging.tokenAction = null;
    messaging.token = 'token-b';
    await controller.enable();
    expect(devices['b']!.trace, ['register:b:token-b']);
    expect(controller.state.enabled, isTrue);
    expect(consent.ownerUid, 'b');
  });
  test(
    'late permission result after UID switch cannot obtain or register a token',
    () async {
      final ready = Completer<void>(), permission = Completer<PushPermission>();
      await controller.setOwner('a');
      messaging.permissionAction = (request) {
        ready.complete();
        return permission.future;
      };
      final enabling = controller.enable();
      await ready.future;
      final switching = controller.setOwner('b');
      permission.complete(PushPermission.authorized);
      await enabling;
      await switching;
      expect(messaging.calls, isNot(contains('get-token')));
      expect(devices.values.expand((device) => device.trace), isEmpty);
      expect(controller.state.ownerUid, 'b');
      expect(controller.state.enabled, isFalse);
    },
  );
  test(
    'refresh confirms current SDK token and replaces the owner registration',
    () async {
      await controller.setOwner('a');
      await controller.enable();
      final changed = controller.states.firstWhere(
        (_) => devices['a']!.trace.contains('unregister:a:token-a'),
      );
      messaging.token = 'new-a';
      messaging.refreshes.add('stale-a');
      messaging.refreshes.add('new-a');
      // disable is queued after both refresh events, so it is also a deterministic drain.
      await controller.disable();
      // A successful refresh is observable by its backend calls before disable cleanup.
      expect(devices['a']!.trace, [
        'register:a:token-a',
        'unregister:a:token-a',
      ]);
      // Disabling before the queued refresh runs cancels it by generation.
      await changed;
      await controller.enable();
      messaging.token = 'rotated-a';
      final registered = Completer<void>();
      devices['a']!.registerAction = (token) async {
        if (token == 'rotated-a') {
          registered.complete();
        }
      };
      messaging.refreshes.add('stale-a');
      messaging.refreshes.add('rotated-a');
      await registered.future;
      await Future<void>.delayed(Duration.zero);
      expect(devices['a']!.trace, contains('register:a:rotated-a'));
      expect(devices['a']!.trace, contains('unregister:a:new-a'));
      expect(
        devices['a']!.trace.any((call) => call.contains('stale-a')),
        isFalse,
      );
    },
  );
  test('tap and foreground accept only exact generic payload for active UID; logout cancels pending tap', () async {
    await controller.setOwner('a');
    messaging.opens.add(pushMessage('b'));
    messaging.opens.add({...pushMessage('a'), 'message': 'private text'});
    messaging.opens.add(pushMessage('a', id: 'wrong'));
    expect(controller.state.pendingRequestId, isNull);
    messaging.opens.add(pushMessage('a'));
    expect(controller.state.pendingRequestId, requestId);
    controller.consumeTap('b', requestId);
    expect(controller.state.pendingRequestId, requestId);
    messaging.foregrounds.add(pushMessage('b'));
    messaging.foregrounds.add(pushMessage('a'));
    expect(controller.state.foregroundCount, 1);
    await controller.setOwner(null);
    messaging.opens.add(pushMessage('a'));
    expect(controller.state.pendingRequestId, isNull);
    expect(controller.state.foregroundCount, 0);
  });
  test('cold tap waits for session restore and is discarded after an intervening logout', () async {
    final initial = Completer<Map<String, dynamic>?>();
    messaging.initialAction = () => initial.future;
    final restoring = controller.setOwner('a');
    await Future<void>.delayed(Duration.zero);
    initial.complete(pushMessage('a'));
    await restoring;
    expect(controller.state.pendingRequestId, requestId);
    await controller.setOwner(null);
    await controller.setOwner('b');
    expect(controller.state.pendingRequestId, isNull);
  });
  test('late initial message cannot be accepted after logout and login even to same UID', () async {
    final initial = Completer<Map<String, dynamic>?>();
    messaging.initialAction = () => initial.future;
    final restoring = controller.setOwner('a');
    await Future<void>.delayed(Duration.zero);
    final logout = controller.setOwner(null), login = controller.setOwner('a');
    initial.complete(pushMessage('a'));
    await restoring;
    await logout;
    await login;
    expect(controller.state.pendingRequestId, isNull);
  });
  test('failed deleteToken is honest and blocks another account registration until retry succeeds', () async {
    await controller.setOwner('a');
    await controller.enable();
    messaging.deleteFailure = StateError('native failure');
    await controller.setOwner('b');
    expect(controller.state.failure, PushFailureKind.cleanup);
    expect(controller.state.cleanupFailed, isTrue);
    await controller.enable();
    expect(devices['b']!.trace, isEmpty);
    expect(controller.state.enabled, isFalse);
    messaging.deleteFailure = null;
    await controller.disable();
    await controller.enable();
    expect(controller.state.cleanupFailed, isFalse);
    expect(devices['b']!.trace, ['register:b:token-a']);
  });
  test('prior explicit consent restores same owner without prompt and survives normal app close', () async {
    await controller.dispose();
    consent.ownerUid = 'a';
    controller = NotificationsController(
      messaging: messaging,
      registrationForOwner: (uid) => devices[uid],
      consent: consent,
    );
    await controller.setOwner('a');
    expect(controller.state.enabled, isTrue);
    expect(messaging.calls, isNot(contains('permission-request')));
    expect(devices['a']!.trace, ['register:a:token-a']);
    await controller.dispose();
    expect(consent.ownerUid, 'a');
    expect(messaging.calls, isNot(contains('delete-token')));
  });
  test(
    'registration failure cannot be displayed as enabled or persisted consent',
    () async {
      devices['a']!.registerFailure = const PushFailure(
        PushFailureKind.network,
      );
      await controller.setOwner('a');
      await controller.enable();
      expect(controller.state.enabled, isFalse);
      expect(controller.state.failure, PushFailureKind.network);
      expect(consent.ownerUid, isNull);
    },
  );
  test('permission revoked in system settings is refreshed without prompt and removes registration', () async {
    await controller.setOwner('a');
    await controller.enable();
    messaging.status = PushPermission.denied;
    final promptCount = messaging.calls
        .where((call) => call == 'permission-request')
        .length;
    await controller.refreshPermission();
    expect(controller.state.enabled, isFalse);
    expect(controller.state.permission, PushPermission.denied);
    expect(devices['a']!.trace, ['register:a:token-a', 'unregister:a:token-a']);
    expect(
      messaging.calls.where((call) => call == 'permission-request'),
      hasLength(promptCount),
    );
    expect(consent.ownerUid, isNull);
    expect(messaging.calls.last, 'delete-token');
  });
}
