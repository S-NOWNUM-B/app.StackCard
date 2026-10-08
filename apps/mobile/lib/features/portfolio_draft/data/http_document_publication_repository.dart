import 'package:dio/dio.dart';

import '../domain/document_publication.dart';

/// UID фиксируется composition; token callback обязан проверить текущую session.
final class HttpDocumentPublicationRepository
    implements DocumentPublicationRepository {
  HttpDocumentPublicationRepository({
    required this.dio,
    required this.endpoint,
    required this.ownerUid,
    required this.token,
  });

  final Dio dio;
  final Uri endpoint;
  final String ownerUid;
  final Future<String?> Function(String uid) token;

  @override
  Future<DocumentPublicationInventory> inventory() async {
    final value = await _post({'action': 'inventory'});
    final entries = value['publications'];
    if (value['status'] != 'completed' || entries is! List) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.invalidData,
      );
    }
    final publications = entries.map((entry) => _publication(_map(entry)));
    final result = DocumentPublicationInventory(
      publications: publications,
      lifecycleGeneration: _integer(value['lifecycleGeneration']),
    );
    if (result.publications.map((item) => item.documentId).toSet().length !=
        result.publications.length) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.invalidData,
      );
    }
    return result;
  }

  @override
  Future<DocumentPublicationOperation> status(String operationId) async =>
      _operation(
        await _post({'action': 'status', 'operationId': operationId}),
        operationId,
      );

  @override
  Future<DocumentPublicationOperation> mutate(
    DocumentPublicationMutation mutation,
  ) async {
    final value = await _post(mutation.toJson(), mutation: true);
    try {
      return _operation(value, mutation.operationId);
    } on DocumentPublicationFailure {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unknown,
      );
    }
  }

  @override
  Future<DocumentPublicationOperation> deleteAccount({
    required String operationId,
    required int expectedGeneration,
    required String recoveryKey,
  }) async => _operation(
    await _post({
      'action': 'deleteAccount',
      'operationId': operationId,
      'expectedGeneration': expectedGeneration,
      'recoveryKey': recoveryKey,
    }, mutation: true),
    operationId,
  );

  @override
  Future<DocumentPublicationOperation> recoverAccountDeletion({
    required String ownerUid,
    required String operationId,
    required String recoveryKey,
    bool retry = false,
  }) async {
    if (ownerUid != this.ownerUid ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(recoveryKey)) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unauthenticated,
      );
    }
    return _operation(
      await _post(
        {
          'action': 'deletionStatus',
          'ownerUid': ownerUid,
          'operationId': operationId,
          'recoveryKey': recoveryKey,
          'retry': retry,
        },
        mutation: retry,
        authenticate: false,
      ),
      operationId,
    );
  }

  Future<Map<String, dynamic>> _post(
    Map<String, Object> body, {
    bool mutation = false,
    bool authenticate = true,
  }) async {
    if (!_allowedUrl(endpoint) || ownerUid.isEmpty) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.configurationRequired,
      );
    }
    String? bearerToken;
    if (authenticate) {
      try {
        bearerToken = await token(ownerUid);
      } on Object {
        throw const DocumentPublicationFailure(
          DocumentPublicationFailureKind.unauthenticated,
        );
      }
      if (bearerToken == null || bearerToken.isEmpty) {
        throw const DocumentPublicationFailure(
          DocumentPublicationFailureKind.unauthenticated,
        );
      }
    }
    try {
      final response = await dio.postUri<Object?>(
        endpoint,
        data: body,
        options: Options(
          headers: {
            if (bearerToken != null) 'Authorization': 'Bearer $bearerToken',
          },
          contentType: Headers.jsonContentType,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 15),
          validateStatus: (_) => true,
        ),
      );
      final code = response.statusCode ?? 0;
      if (code < 200 || code >= 300) {
        final data = response.data;
        final error = data is Map ? data['error'] : null;
        final errorCode = error is Map ? error['code'] : null;
        throw DocumentPublicationFailure(switch (errorCode) {
          'unauthenticated' => DocumentPublicationFailureKind.unauthenticated,
          'invalid-data' => DocumentPublicationFailureKind.invalidData,
          'conflict' => DocumentPublicationFailureKind.conflict,
          'deleted' => DocumentPublicationFailureKind.deleted,
          'account-deleting' => DocumentPublicationFailureKind.accountDeleting,
          'configuration-required' =>
            DocumentPublicationFailureKind.configurationRequired,
          'reauthentication-required' =>
            DocumentPublicationFailureKind.reauthenticationRequired,
          _ =>
            mutation && (code >= 500 || code == 0)
                ? DocumentPublicationFailureKind.unknown
                : DocumentPublicationFailureKind.unavailable,
        });
      }
      try {
        return _map(response.data);
      } on DocumentPublicationFailure {
        throw DocumentPublicationFailure(
          mutation
              ? DocumentPublicationFailureKind.unknown
              : DocumentPublicationFailureKind.invalidData,
        );
      }
    } on DioException {
      throw DocumentPublicationFailure(
        mutation
            ? DocumentPublicationFailureKind.unknown
            : DocumentPublicationFailureKind.unavailable,
      );
    } on DocumentPublicationFailure {
      rethrow;
    } on Object {
      throw DocumentPublicationFailure(
        mutation
            ? DocumentPublicationFailureKind.unknown
            : DocumentPublicationFailureKind.invalidData,
      );
    }
  }

  DocumentPublicationOperation _operation(
    Map<String, dynamic> value,
    String operationId,
  ) {
    if (value['operationId'] != operationId) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unknown,
      );
    }
    final outcome = DocumentPublicationOutcome.values
        .where((item) => item.name == value['status'])
        .firstOrNull;
    if (outcome == null) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.unknown,
      );
    }
    return DocumentPublicationOperation(
      outcome: outcome,
      operationId: operationId,
      action: value['action'] is String ? value['action'] as String : null,
      publication: value['publication'] == null
          ? null
          : _publication(_map(value['publication'])),
      lifecycleGeneration: value['lifecycleGeneration'] == null
          ? null
          : _integer(value['lifecycleGeneration']),
    );
  }

  DocumentPublication _publication(Map<String, dynamic> value) {
    final visibility = DocumentPublicationVisibility.values
        .where((item) => item.name == value['state'])
        .firstOrNull;
    final rawUrl = value['url'];
    final url = rawUrl is String && rawUrl.isNotEmpty
        ? Uri.tryParse(rawUrl)
        : null;
    if (visibility == null ||
        (rawUrl != null && rawUrl is! String) ||
        (url != null && !_allowedUrl(url)) ||
        (visibility == DocumentPublicationVisibility.published &&
            (url == null ||
                value['sourceMutationId'] is! String ||
                (value['sourceMutationId'] as String).isEmpty))) {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.invalidData,
      );
    }
    return DocumentPublication(
      documentId: _string(value['documentId']),
      publicId: _string(value['publicId']),
      version: _integer(value['version']),
      visibility: visibility,
      sourceMutationId: value['sourceMutationId'] is String
          ? value['sourceMutationId'] as String
          : _string(value['sourceMutationId']),
      url: url,
    );
  }

  static bool _allowedUrl(Uri url) =>
      url.host.isNotEmpty &&
      url.userInfo.isEmpty &&
      (url.scheme == 'https' ||
          (url.scheme == 'http' &&
              {
                'localhost',
                '127.0.0.1',
                '::1',
                '10.0.2.2',
              }.contains(url.host)));

  static Map<String, dynamic> _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    throw const DocumentPublicationFailure(
      DocumentPublicationFailureKind.invalidData,
    );
  }

  static int _integer(Object? value) {
    if (value is int && value >= 0) return value;
    throw const DocumentPublicationFailure(
      DocumentPublicationFailureKind.invalidData,
    );
  }

  static String _string(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    throw const DocumentPublicationFailure(
      DocumentPublicationFailureKind.invalidData,
    );
  }
}
