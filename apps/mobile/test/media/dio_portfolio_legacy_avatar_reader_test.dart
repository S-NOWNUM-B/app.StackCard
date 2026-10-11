import 'dart:async';
import 'dart:typed_data';

import 'package:app_stackcard/features/media/data/dio_portfolio_legacy_avatar_reader.dart';
import 'package:app_stackcard/features/media/media.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const url = 'https://avatars.githubusercontent.com/u/123';

  test('public JPEG, PNG and WebP legacy avatars become bounded metadata-free JPEG', () async {
    final original = image.Image(width: 900, height: 450);
    image.fill(original, color: image.ColorRgb8(20, 120, 200));
    original.exif.imageIfd.imageDescription = 'PRIVATE_METADATA';
    for (final fixture in [
      (image.encodeJpg(original), 'image/jpeg'),
      (image.encodePng(original), 'image/png'),
      (image.encodeWebP(original), 'image/webp'),
    ]) {
      final adapter = _Adapter((_) => _response(fixture.$1, fixture.$2));
      final bytes = await _reader(adapter).read(url);
      await const PortfolioImageProcessor().validatePrepared(bytes);
      final decoded = image.decodeJpg(bytes)!;
      expect((decoded.width, decoded.height), (512, 256));
      expect(decoded.exif.isEmpty, isTrue);
      expect(decoded.getPixel(0, 0).b, greaterThan(180));
      expect(bytes.length, lessThanOrEqualTo(portfolioAvatarMaxBytes));
      expect(adapter.requests.single.uri.toString(), url);
      expect(adapter.requests.single.followRedirects, isFalse);
      expect(
        adapter.requests.single.headers.containsKey('Authorization'),
        isFalse,
      );
    }
  });

  test('unsafe or local URLs never reach the network adapter', () async {
    final adapter = _Adapter((_) => throw StateError('must not request'));
    final reader = _reader(adapter);
    for (final invalid in [
      '',
      'file:///private/avatar.jpg',
      'data:image/jpeg;base64,AAAA',
      'https://name:password@example.com/avatar.jpg',
      'https://@example.com/avatar.jpg',
      'https://example.com:443/avatar.jpg',
      'https://example.com/avatar.jpg#private',
      'https://example.com/avatar.jpg\n',
      r'https://example.com\avatar.jpg',
      'https://%65xample.com/avatar.jpg',
      'http://localhost/avatar.jpg',
      'https://localhost.localdomain/avatar.jpg',
      'https://printer.local/avatar.jpg',
      'https://service.internal/avatar.jpg',
      'https://service.test/avatar.jpg',
      'http://127.0.0.1/avatar.jpg',
      'http://10.0.0.1/avatar.jpg',
      'http://169.254.169.254/avatar.jpg',
      'https://[::1]/avatar.jpg',
      'https://2130706433/avatar.jpg',
      'https://example.com./avatar.jpg',
    ]) {
      await expectLater(
        reader.read(invalid),
        throwsA(_failure(PortfolioMediaFailureKind.permissionDenied)),
        reason: invalid,
      );
    }
    expect(adapter.requests, isEmpty);
  });

  test(
    'legacy public HTTP remains readable without a redirect or upload',
    () async {
      final adapter = _Adapter((_) => _response(_jpeg(), 'image/jpeg'));
      final bytes = await _reader(adapter)
          .read('http://images.example.com/avatar.jpg');
      expect(image.decodeJpg(bytes), isNotNull);
      expect(adapter.requests.single.method, 'GET');
    },
  );

  test(
    'redirects and unavailable responses fail without following their target',
    () async {
      for (final status in [302, 404, 500]) {
        final adapter = _Adapter(
          (_) => ResponseBody.fromBytes(
            const [],
            status,
            headers: {
              'location': ['http://127.0.0.1/private'],
            },
          ),
        );
        await expectLater(
          _reader(adapter).read(url),
          throwsA(_failure(PortfolioMediaFailureKind.unavailable)),
        );
        expect(adapter.requests, hasLength(1));
      }
    },
  );

  test(
    'MIME and actual image bytes must agree before a PDF receives the photo',
    () async {
      for (final fixture in [
        (_jpeg(), 'image/svg+xml'),
        (Uint8List.fromList('<html>private</html>'.codeUnits), 'image/jpeg'),
        (image.encodePng(image.Image(width: 1, height: 1)), 'image/jpeg'),
      ]) {
        final adapter = _Adapter((_) => _response(fixture.$1, fixture.$2));
        await expectLater(
          _reader(adapter).read(url),
          throwsA(_failure(PortfolioMediaFailureKind.invalidType)),
        );
      }
    },
  );

  test(
    'declared and streamed content are both limited to the legacy byte budget',
    () async {
      final declared = _Adapter(
        (_) => _response(
          _jpeg(),
          'image/jpeg',
          length: portfolioImageMaxBytes + 1,
        ),
      );
      await expectLater(
        _reader(declared).read(url),
        throwsA(_failure(PortfolioMediaFailureKind.tooLarge)),
      );
      final streamed = _Adapter(
        (_) => ResponseBody(
          Stream.fromIterable([
            Uint8List(portfolioImageMaxBytes),
            Uint8List(1),
          ]),
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg'],
          },
        ),
      );
      await expectLater(
        _reader(streamed).read(url),
        throwsA(_failure(PortfolioMediaFailureKind.tooLarge)),
      );
    },
  );

  test(
    'stalled HTTP response times out and cancels the underlying request',
    () async {
      final pending = Completer<ResponseBody>();
      final adapter = _Adapter((_) => pending.future);
      await expectLater(
        _reader(adapter, timeout: const Duration(milliseconds: 20)).read(url),
        throwsA(_failure(PortfolioMediaFailureKind.unavailable)),
      );
      await adapter.cancelled.future;
      pending.complete(_response(_jpeg(), 'image/jpeg'));
    },
  );

  test(
    'stalled response body also respects the total download timeout',
    () async {
      final stream = StreamController<Uint8List>();
      addTearDown(stream.close);
      final adapter = _Adapter(
        (_) => ResponseBody(
          stream.stream,
          200,
          headers: {
            Headers.contentTypeHeader: ['image/jpeg'],
          },
        ),
      );
      await expectLater(
        _reader(adapter, timeout: const Duration(milliseconds: 20)).read(url),
        throwsA(_failure(PortfolioMediaFailureKind.unavailable)),
      );
      await adapter.cancelled.future;
    },
  );
}

Uint8List _jpeg() => image.encodeJpg(image.Image(width: 2, height: 2));
Matcher _failure(PortfolioMediaFailureKind kind) => isA<PortfolioMediaFailure>()
    .having((failure) => failure.kind, 'kind', kind);
ResponseBody _response(List<int> bytes, String mime, {int? length}) =>
    ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: [mime],
        if (length != null) Headers.contentLengthHeader: ['$length'],
      },
    );

DioPortfolioLegacyAvatarReader _reader(
  _Adapter adapter, {
  Duration timeout = const Duration(seconds: 10),
}) {
  final dio = Dio()..httpClientAdapter = adapter;
  addTearDown(() => dio.close(force: true));
  return DioPortfolioLegacyAvatarReader(dio, timeout: timeout);
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final FutureOr<ResponseBody> Function(RequestOptions) respond;
  final requests = <RequestOptions>[];
  final cancelled = Completer<void>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    cancelFuture?.then((_) {
      if (!cancelled.isCompleted) cancelled.complete();
    });
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
