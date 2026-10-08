import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/document_publication.dart';

/// Журнал содержит только private ID/CAS metadata, без content или credentials.
final class SharedPreferencesDocumentPublicationOperationStore
    implements DocumentPublicationOperationStore {
  SharedPreferencesDocumentPublicationOperationStore(
    this._preferences, {
    required String ownerUid,
  }) : _key =
           'stackcard.publication.operation.v1.${base64Url.encode(utf8.encode(ownerUid))}';

  final SharedPreferencesAsync _preferences;
  final String _key;

  @override
  Future<DocumentPublicationMutation?> read() async {
    try {
      final raw = await _preferences.getString(_key);
      if (raw == null) return null;
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic> || value['schemaVersion'] != 1) {
        throw const FormatException();
      }
      return DocumentPublicationMutation.fromJson(value);
    } on Object {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.storage,
      );
    }
  }

  @override
  Future<void> write(DocumentPublicationMutation mutation) async {
    try {
      await _preferences.setString(
        _key,
        jsonEncode({'schemaVersion': 1, ...mutation.toJson()}),
      );
    } on Object {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.storage,
      );
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _preferences.remove(_key);
    } on Object {
      throw const DocumentPublicationFailure(
        DocumentPublicationFailureKind.storage,
      );
    }
  }
}
