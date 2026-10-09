import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_stackcard/features/notifications/data/http_push_device_registration.dart';
import 'package:app_stackcard/features/notifications/notifications.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

ResponseBody _response(Object payload, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
void main() {
  test('actual HTTP adapter sends captured UID bearer, exact actions and validates exact completed ACK', () async {
    final adapter = _Adapter((_) => _response({'status': 'completed'}));
    final repository = _repository(adapter);
    await repository.register('device-token');
    await repository.unregister('device-token');
    expect(adapter.requests, hasLength(2));
    final register = adapter.requests.first;
    expect(register.headers['Authorization'], 'Bearer captured-a');
    expect(register.followRedirects, isFalse);
    expect(register.data, {
      'action': 'registerDevice',
      'token': 'device-token',
      'platform': 'android',
    });
    expect(adapter.requests.last.data, {
      'action': 'unregisterDevice',
      'token': 'device-token',
    });
  });
  test('unsupported ACK, extra fields and failed HTTP status cannot acknowledge registration', () async {
    for (final response in [
      _response({'status': 'accepted'}),
      _response({'status': 'completed', 'token': 'secret'}),
      _response({'status': 'completed'}, status: 403),
      _response({'error': 'device-limit'}, status: 429),
    ]) {
      await expectLater(
        _repository(_Adapter((_) => response)).register('token'),
        throwsA(
          isA<PushFailure>().having(
            (e) => e.kind,
            'kind',
            PushFailureKind.registration,
          ),
        ),
      );
    }
  });
  test('late response after UID switch is rejected and missing bearer never submits', () async {
    var uid = 'a';
    final dispatched = Completer<void>(), response = Completer<ResponseBody>();
    final adapter = _Adapter((_) {
      dispatched.complete();
      return response.future;
    });
    final repository = _repository(
      adapter,
      token: (owner) async => owner == uid ? 'captured-a' : null,
    );
    final registering = repository.register('token');
    await dispatched.future;
    uid = 'b';
    response.complete(_response({'status': 'completed'}));
    await expectLater(
      registering,
      throwsA(
        isA<PushFailure>().having(
          (e) => e.kind,
          'kind',
          PushFailureKind.unauthenticated,
        ),
      ),
    );
    await expectLater(
      repository.register('token'),
      throwsA(
        isA<PushFailure>().having(
          (e) => e.kind,
          'kind',
          PushFailureKind.unauthenticated,
        ),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });
  test('HTTPS required, HTTP only explicit local demo and token validation matches server', () async {
    for (final endpoint in [
      'http://api.example/contactInbox',
      'http://localhost:5001/contactInbox',
      'https://user@api.example/contactInbox',
      'https://api.example/contactInbox?token=x',
    ]) {
      final adapter = _Adapter((_) => _response({'status': 'completed'}));
      await expectLater(
        _repository(adapter, endpoint: endpoint).register('token'),
        throwsA(isA<PushFailure>()),
      );
      expect(adapter.requests, isEmpty);
    }
    final local = _Adapter((_) => _response({'status': 'completed'}));
    await _repository(
      local,
      endpoint: 'http://10.0.2.2:5001/contactInbox',
      demo: true,
    ).register('token');
    expect(local.requests, hasLength(1));
    for (final token in ['', 'a b', 'a\n', 'x' * 4097]) {
      final adapter = _Adapter((_) => _response({'status': 'completed'}));
      await expectLater(
        _repository(adapter).register(token),
        throwsA(isA<PushFailure>()),
      );
      expect(adapter.requests, isEmpty);
    }
  });
}

HttpPushDeviceRegistration _repository(
  _Adapter adapter, {
  String endpoint = 'https://api.example/contactInbox',
  bool demo = false,
  Future<String?> Function(String)? token,
}) => HttpPushDeviceRegistration(
  dio: Dio()..httpClientAdapter = adapter,
  endpoint: Uri.parse(endpoint),
  ownerUid: 'a',
  platform: 'android',
  allowDemoHttp: demo,
  idToken: token ?? (uid) async => uid == 'a' ? 'captured-a' : null,
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
