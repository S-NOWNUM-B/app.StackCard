import 'package:dio/dio.dart';

import '../domain/push_notifications.dart';

final class HttpPushDeviceRegistration implements PushDeviceRegistration {
  HttpPushDeviceRegistration({
    required this.dio,
    required this.endpoint,
    required this.ownerUid,
    required this.platform,
    required this.idToken,
    this.allowDemoHttp = false,
  });
  final Dio dio;
  final Uri endpoint;
  @override
  final String ownerUid;
  final String platform;
  final bool allowDemoHttp;
  final Future<String?> Function(String ownerUid) idToken;
  @override
  Future<void> register(String token) =>
      _post({'action': 'registerDevice', 'token': token, 'platform': platform});
  @override
  Future<void> unregister(String token) =>
      _post({'action': 'unregisterDevice', 'token': token});
  Future<void> _post(Map<String, Object> payload) async {
    final token = payload['token'] as String;
    if (token.isEmpty ||
        token.length > 4096 ||
        RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(token) ||
        !['android', 'ios'].contains(platform) ||
        endpoint.host.isEmpty ||
        endpoint.userInfo.isNotEmpty ||
        endpoint.hasFragment ||
        endpoint.hasQuery ||
        !(endpoint.scheme == 'https' ||
            (allowDemoHttp &&
                endpoint.scheme == 'http' &&
                [
                  'localhost',
                  '127.0.0.1',
                  '10.0.2.2',
                  '::1',
                ].contains(endpoint.host)))) {
      throw const PushFailure(PushFailureKind.unavailable);
    }
    try {
      final bearer = await idToken(ownerUid);
      if (bearer == null || bearer.isEmpty) {
        throw const PushFailure(PushFailureKind.unauthenticated);
      }
      final response = await dio.postUri<Object?>(
        endpoint,
        data: payload,
        options: Options(
          headers: {'Authorization': 'Bearer $bearer'},
          contentType: Headers.jsonContentType,
          followRedirects: false,
          validateStatus: (_) => true,
        ),
      );
      if (await idToken(ownerUid) == null) {
        throw const PushFailure(PushFailureKind.unauthenticated);
      }
      final data = response.data;
      if (response.statusCode != 200 ||
          data is! Map ||
          data.length != 1 ||
          data['status'] != 'completed') {
        throw const PushFailure(PushFailureKind.registration);
      }
    } on PushFailure {
      rethrow;
    } on DioException {
      throw const PushFailure(PushFailureKind.network);
    } catch (_) {
      throw const PushFailure(PushFailureKind.unavailable);
    }
  }
}
