import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';
import 'hive_portfolio_draft_repository.dart';
import 'portfolio_content_codec.dart';

/// Metadata supplements the original draft; it never replaces that envelope.
final class HivePortfolioSyncMetadataStore {
  HivePortfolioSyncMetadataStore(this._box, {required String ownerUid})
    : _key = storageKeyForUser(ownerUid);

  final Box<dynamic> _box;
  final String _key;

  static PortfolioSyncRecord validateStoredRecord(Object? raw) => _decode(raw);

  static String storageKeyForUser(String uid) {
    if (uid.isEmpty) throw ArgumentError.value(uid, 'uid');
    final encoded = base64Url.encode(utf8.encode(uid)).replaceAll('=', '');
    return 'draft.sync.user.$encoded';
  }

  Future<PortfolioSyncRecord?> read() => HiveDraftOperations.run(_box, () {
    if (!_box.containsKey(_key)) return null;
    return _decode(_box.get(_key));
  });

  static PortfolioSyncRecord _decode(Object? raw) {
    if (raw is! String) throw _corrupted;
    try {
      final value = jsonDecode(raw);
      if (value is! Map<String, dynamic>) throw _corrupted;
      final version = value['schemaVersion'];
      if (version is! int) throw _corrupted;
      if (version != 1) {
        throw const PortfolioDraftFailure(
          PortfolioDraftFailureKind.unsupportedVersion,
        );
      }
      final mutationId = value['mutationId'];
      final pending = value['pending'];
      final localRevision = value['localRevision'];
      final snapshot = value['snapshot'];
      if (mutationId is! String ||
          mutationId.isEmpty ||
          pending is! bool ||
          localRevision is! int ||
          localRevision < 0 ||
          snapshot is! Map<String, dynamic>) {
        throw _corrupted;
      }
      final draft = HivePortfolioDraftRepository.validateStoredEnvelope(
        jsonEncode(snapshot),
      );
      if (draft.revision != localRevision || draft.pendingSync != pending) {
        throw _corrupted;
      }
      return PortfolioSyncRecord(
        mutationId: mutationId,
        pending: pending,
        draft: draft,
      );
    } on FormatException {
      throw _corrupted;
    }
  }

  Future<void> write(PortfolioSyncRecord record) =>
      HiveDraftOperations.run(_box, () async {
        // Validate before replacing unknown/corrupt metadata.
        if (_box.containsKey(_key)) _decode(_box.get(_key));
        await _box.put(_key, encodePortfolioSyncRecord(record));
        await _box.flush();
      });

  static const _corrupted = PortfolioDraftFailure(
    PortfolioDraftFailureKind.corrupted,
  );
}

final class PortfolioSyncRecord {
  const PortfolioSyncRecord({
    required this.mutationId,
    required this.pending,
    required this.draft,
  });

  final String mutationId;
  final bool pending;
  final PortfolioDraft draft;
}

/// Used by transfer while it already owns the shared Hive operations queue.
String encodePortfolioSyncRecord(PortfolioSyncRecord record) {
  final content = record.draft.content;
  return jsonEncode({
    'schemaVersion': 1,
    'mutationId': record.mutationId,
    'localRevision': record.draft.revision,
    'pending': record.pending,
    'snapshot': {
      'schemaVersion': HivePortfolioDraftRepository.schemaVersion,
      'notes': record.draft.notes,
      'revision': record.draft.revision,
      'updatedAt': record.draft.updatedAt?.toIso8601String(),
      'pendingSync': record.pending,
      'content': content == null ? null : encodePortfolioContent(content),
    },
  });
}
