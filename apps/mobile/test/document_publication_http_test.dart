import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_stackcard/features/portfolio_draft/data/http_document_publication_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/document_publication.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'authenticated mutation sends CAS metadata and trusts server URL',
    () async {
      final adapter = _Adapter((options) => _response(_result()));
      final repository = _repository(adapter);
      final result = await repository.mutate(_mutation);
      final request = adapter.requests.single;
      expect(request.headers['Authorization'], 'Bearer test-id-token');
      expect(request.followRedirects, isFalse);
      expect(request.data, _mutation.toJson());
      expect(result.action, 'publish');
      expect(
        result.publication!.shareableUrl.toString(),
        'https://public.example/p/public-id',
      );
    },
  );

  test('unsafe public URL and malformed mutation ACK remain unknown', () async {
    for (final value in [
      _result(url: 'https://name:secret@public.example/p/public-id'),
      _result(url: 'javascript:alert(1)'),
      {'status': 'completed', 'operationId': 'other-operation'},
      'broken-success-response',
    ]) {
      final repository = _repository(_Adapter((_) => _response(value)));
      await expectLater(
        repository.mutate(_mutation),
        throwsA(_failure(DocumentPublicationFailureKind.unknown)),
      );
    }
  });

  test(
    'network loss after POST is unknown while inventory loss is unavailable',
    () async {
      final adapter = _Adapter(
        (options) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        ),
      );
      final repository = _repository(adapter);
      await expectLater(
        repository.mutate(_mutation),
        throwsA(_failure(DocumentPublicationFailureKind.unknown)),
      );
      await expectLater(
        repository.inventory(),
        throwsA(_failure(DocumentPublicationFailureKind.unavailable)),
      );
    },
  );

  test(
    'server conflict is a confirmed rejection and absent auth sends no request',
    () async {
      final adapter = _Adapter(
        (_) => _response({
          'error': {'code': 'conflict', 'message': 'Changed'},
        }, 409),
      );
      await expectLater(
        _repository(adapter).mutate(_mutation),
        throwsA(_failure(DocumentPublicationFailureKind.conflict)),
      );
      final unauthenticated = _repository(adapter, token: (_) async => null);
      await expectLater(
        unauthenticated.inventory(),
        throwsA(_failure(DocumentPublicationFailureKind.unauthenticated)),
      );
      expect(adapter.requests, hasLength(1));
    },
  );

  test(
    'unpublished tombstone accepts empty source mutation and has no share link',
    () async {
      final value = _publication(
        state: 'deleted',
        url: null,
        sourceMutationId: '',
      );
      final repository = _repository(
        _Adapter(
          (_) => _response({
            'status': 'completed',
            'lifecycleGeneration': 3,
            'publications': [value],
          }),
        ),
      );
      final inventory = await repository.inventory();
      expect(
        inventory.publications.single.visibility,
        DocumentPublicationVisibility.deleted,
      );
      expect(inventory.publications.single.shareableUrl, isNull);
    },
  );

  test('receipt recovery alone bypasses expired Firebase session', () async {
    var tokenCalls = 0;
    final adapter = _Adapter(
      (_) => _response({
        'action': 'deleteAccount',
        'status': 'completed',
        'operationId': 'delete-operation',
        'lifecycleGeneration': 4,
      }),
    );
    final repository = _repository(
      adapter,
      token: (_) async {
        tokenCalls++;
        return null;
      },
    );
    final key = 'a' * 64;
    final result = await repository.recoverAccountDeletion(
      ownerUid: 'owner',
      operationId: 'delete-operation',
      recoveryKey: key,
      retry: true,
    );
    expect(result.action, 'deleteAccount');
    expect(tokenCalls, 0);
    expect(
      adapter.requests.single.headers.containsKey('Authorization'),
      isFalse,
    );
    expect(adapter.requests.single.data, {
      'action': 'deletionStatus',
      'ownerUid': 'owner',
      'operationId': 'delete-operation',
      'recoveryKey': key,
      'retry': true,
    });
    await expectLater(
      repository.recoverAccountDeletion(
        ownerUid: 'other',
        operationId: 'delete-operation',
        recoveryKey: key,
      ),
      throwsA(_failure(DocumentPublicationFailureKind.unauthenticated)),
    );
    await expectLater(
      repository.inventory(),
      throwsA(_failure(DocumentPublicationFailureKind.unauthenticated)),
    );
    expect(adapter.requests, hasLength(1));
  });
}

const _mutation = DocumentPublicationMutation(
  action: DocumentPublicationAction.publish,
  operationId: 'operation',
  documentId: 'document',
  expectedMutationId: 'saved-mutation',
  expectedVersion: 1,
  expectedGeneration: 2,
);

Matcher _failure(DocumentPublicationFailureKind kind) =>
    isA<DocumentPublicationFailure>().having(
      (failure) => failure.kind,
      'kind',
      kind,
    );

Map<String, Object?> _publication({
  String state = 'published',
  String? url = 'https://public.example/p/public-id',
  String sourceMutationId = 'saved-mutation',
}) => {
  'documentId': 'document',
  'publicId': 'public-id',
  'version': 2,
  'state': state,
  'url': url,
  'sourceMutationId': sourceMutationId,
};

Map<String, Object?> _result({
  String? url = 'https://public.example/p/public-id',
}) => {
  'action': 'publish',
  'status': 'completed',
  'operationId': 'operation',
  'publication': _publication(url: url),
  'lifecycleGeneration': 3,
};

ResponseBody _response(Object body, [int status = 200]) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

HttpDocumentPublicationRepository _repository(
  _Adapter adapter, {
  Future<String?> Function(String)? token,
}) => HttpDocumentPublicationRepository(
  dio: Dio()..httpClientAdapter = adapter,
  endpoint: Uri.parse('https://api.example/documentPublication'),
  ownerUid: 'owner',
  token: token ?? (_) async => 'test-id-token',
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
