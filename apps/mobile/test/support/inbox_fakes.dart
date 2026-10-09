import 'dart:async';

import 'package:app_stackcard/features/auth/auth.dart';
import 'package:app_stackcard/features/inbox/inbox.dart';
import 'package:app_stackcard/features/notifications/notifications.dart';

const requestId = '0123456789abcdef0123456789abcdef';
Map<String, dynamic> pushMessage(String uid, {String id = requestId}) => {
  'type': 'contactRequest',
  'ownerUid': uid,
  'requestId': id,
};
ContactRequest enquiry({
  String id = requestId,
  String name = 'Visitor',
  DateTime? readAt,
}) => ContactRequest(
  requestId: id,
  publicId: 'abcdef0123456789abcdef0123456789',
  documentId: 'resume',
  documentTitle: 'Published resume',
  name: name,
  email: 'visitor@example.com',
  message: 'Hello\nPlease contact me.',
  createdAt: DateTime.utc(2026, 10, 9),
  readAt: readAt,
);

class TestAuth implements AccountAuthRepository {
  TestAuth([this.current]);
  AuthUser? current;
  final changes = StreamController<AuthUser?>.broadcast();
  @override
  Stream<AuthUser?> watchSession() => Stream.multi((controller) {
    controller.add(current);
    final sub = changes.stream.listen(controller.add);
    controller.onCancel = sub.cancel;
  });
  void emit(AuthUser? user) {
    current = user;
    changes.add(user);
  }

  @override
  Future<void> signOut() async => emit(null);
  @override
  Future<void> signInEmail(String email, String password) async =>
      emit(AuthUser(uid: 'a', email: email));
  @override
  Future<void> registerEmail(String email, String password) =>
      signInEmail(email, password);
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> signInGoogle() async => emit(const AuthUser(uid: 'a'));
}

class TestInbox implements InboxRepository {
  TestInbox(this.ownerUid, {List<ContactRequest>? items})
    : items = items ?? [enquiry()];
  @override
  final String ownerUid;
  List<ContactRequest> items;
  Future<InboxPage> Function(InboxCursor?)? listing;
  Future<ContactRequest?> Function(String)? getting;
  Object? readFailure;
  int reads = 0, lists = 0;
  final cursors = <InboxCursor?>[];
  @override
  Future<InboxPage> list({InboxCursor? after}) async {
    lists++;
    cursors.add(after);
    return listing != null ? listing!(after) : InboxPage(requests: items);
  }

  @override
  Future<ContactRequest?> get(String id) async => getting != null
      ? getting!(id)
      : items.where((item) => item.requestId == id).firstOrNull;
  @override
  Future<ContactRequest> markRead(String id) async {
    reads++;
    if (readFailure != null) {
      throw readFailure!;
    }
    final result = enquiry(
      id: id,
      name: items.first.name,
      readAt: DateTime.utc(2026, 10, 10),
    );
    items = [result];
    return result;
  }
}

class TestMessaging implements PushMessagingGateway {
  PushPermission status = PushPermission.authorized;
  String? token = 'token-a';
  Future<PushPermission> Function(bool)? permissionAction;
  Future<String?> Function()? tokenAction;
  Future<Map<String, dynamic>?> Function()? initialAction;
  Object? deleteFailure;
  final calls = <String>[];
  final refreshes = StreamController<String>.broadcast(sync: true);
  final foregrounds = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  final opens = StreamController<Map<String, dynamic>>.broadcast(sync: true);
  @override
  Stream<String> get tokenRefresh => refreshes.stream;
  @override
  Stream<Map<String, dynamic>> get foreground => foregrounds.stream;
  @override
  Stream<Map<String, dynamic>> get opened => opens.stream;
  @override
  Future<PushPermission> permission({bool request = false}) async {
    calls.add(request ? 'permission-request' : 'permission-status');
    return permissionAction != null ? permissionAction!(request) : status;
  }

  @override
  Future<void> setAutoInitEnabled(bool enabled) async {
    calls.add('auto-init:$enabled');
  }

  @override
  Future<String?> getToken() async {
    calls.add('get-token');
    return tokenAction != null ? tokenAction!() : token;
  }

  @override
  Future<void> deleteToken() async {
    calls.add('delete-token');
    if (deleteFailure != null) {
      throw deleteFailure!;
    }
  }

  @override
  Future<Map<String, dynamic>?> initialMessage() async =>
      initialAction != null ? initialAction!() : null;
  Future<void> close() async {
    await refreshes.close();
    await foregrounds.close();
    await opens.close();
  }
}

class TestRegistration implements PushDeviceRegistration {
  TestRegistration(this.ownerUid, {List<String>? trace}) : trace = trace ?? [];
  @override
  final String ownerUid;
  final List<String> trace;
  Object? registerFailure, unregisterFailure;
  Future<void> Function(String)? registerAction;
  @override
  Future<void> register(String token) async {
    trace.add('register:$ownerUid:$token');
    if (registerFailure != null) {
      throw registerFailure!;
    }
    await registerAction?.call(token);
  }

  @override
  Future<void> unregister(String token) async {
    trace.add('unregister:$ownerUid:$token');
    if (unregisterFailure != null) {
      throw unregisterFailure!;
    }
  }
}
