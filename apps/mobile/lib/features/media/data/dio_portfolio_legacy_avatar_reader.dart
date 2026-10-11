import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/portfolio_media.dart';
import 'portfolio_image_processor.dart';

/// Legacy URL читается только клиентом, без credentials, redirects и новых uploads.
final class DioPortfolioLegacyAvatarReader
    implements PortfolioLegacyAvatarReader {
  DioPortfolioLegacyAvatarReader(
    this._dio, {
    this.processor = const PortfolioImageProcessor(),
    this.timeout = const Duration(seconds: 10),
  });

  final Dio _dio;
  final PortfolioImageProcessor processor;
  final Duration timeout;

  @override
  Future<Uint8List> read(String url) async {
    final uri = _publicImageUri(url);
    if (uri == null) {
      throw const PortfolioMediaFailure(
        PortfolioMediaFailureKind.permissionDenied,
      );
    }
    final cancel = CancelToken();
    try {
      final input = await _fetch(uri, cancel).timeout(
        timeout,
        onTimeout: () {
          cancel.cancel();
          throw const PortfolioMediaFailure(
            PortfolioMediaFailureKind.unavailable,
          );
        },
      );
      final prepared = await processor.prepare(
        input.bytes,
        mimeType: input.mime,
      );
      return prepared.bytes;
    } on PortfolioMediaFailure {
      rethrow;
    } catch (_) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
    } finally {
      cancel.cancel();
    }
  }

  Future<({Uint8List bytes, String mime})> _fetch(
    Uri uri,
    CancelToken cancel,
  ) async {
    final response = await _dio.getUri<ResponseBody>(
      uri,
      cancelToken: cancel,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: false,
        receiveDataWhenStatusError: false,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        validateStatus: (status) => status == 200,
        headers: const {'Accept': 'image/jpeg,image/png,image/webp'},
      ),
    );
    final body = response.data;
    if (body == null || body.isRedirect || response.statusCode != 200) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.unavailable);
    }
    final mime = response.headers
        .value(Headers.contentTypeHeader)
        ?.split(';')
        .first
        .trim()
        .toLowerCase();
    if (!const [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/webp',
    ].contains(mime)) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.invalidType);
    }
    final declared = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
    if (declared != null && declared > portfolioImageMaxBytes) {
      throw const PortfolioMediaFailure(PortfolioMediaFailureKind.tooLarge);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body.stream) {
      if (bytes.length + chunk.length > portfolioImageMaxBytes) {
        throw const PortfolioMediaFailure(PortfolioMediaFailureKind.tooLarge);
      }
      bytes.add(chunk);
    }
    return (bytes: bytes.takeBytes(), mime: mime!);
  }
}

Uri? _publicImageUri(String value) {
  if (value.isEmpty ||
      value.length > 2048 ||
      value != value.trim() ||
      RegExp(r'[\s\\\x00-\x1f\x7f]').hasMatch(value)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  final authority = RegExp(
    r'^https?://([^/?#]*)',
    caseSensitive: false,
  ).firstMatch(value)?.group(1);
  if (uri == null ||
      !uri.hasAuthority ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasFragment ||
      authority == null ||
      authority.contains('@') ||
      authority.contains(':') ||
      authority.contains('%')) {
    return null;
  }
  final host = uri.host.toLowerCase();
  final labels = host.split('.');
  if (labels.length < 2 ||
      host.length > 253 ||
      labels.any(
        (label) =>
            !RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(label),
      ) ||
      !RegExp(r'^[a-z]{2,63}$').hasMatch(labels.last) ||
      const [
        'localhost',
        'local',
        'localdomain',
        'internal',
        'lan',
        'home',
        'test',
        'invalid',
        'example',
        'onion',
        'arpa',
      ].contains(labels.last)) {
    return null;
  }
  return uri;
}
