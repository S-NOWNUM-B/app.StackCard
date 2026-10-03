import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_validation.dart';
import 'portfolio_content_codec.dart';

final class HivePortfolioDraftRepository implements PortfolioDraftRepository {
  HivePortfolioDraftRepository(this._box, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'draft';
  static const schemaVersion = 2;
  static const legacyBackupKey = 'draft.v1.backup';

  final Box<dynamic> _box;
  final DateTime Function() _clock;
  Future<void> _operations = Future.value();

  @override
  Future<PortfolioDraft?> read() => _serial(() => _readRecord().draft);

  @override
  Future<PortfolioDraft> saveNotes(String notes) => _serial(() async {
    final previous = _readRecord();
    return _write(previous, notes: notes, content: previous.draft?.content);
  });

  @override
  Future<PortfolioDraft> save(
    PortfolioContent content, {
    required int expectedRevision,
    required String notes,
  }) => _serial(() async {
    final previous = _readRecord();
    if ((previous.draft?.revision ?? 0) != expectedRevision) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.conflict);
    }
    if (validatePortfolioContent(content).isNotEmpty) {
      throw const PortfolioDraftFailure(
        PortfolioDraftFailureKind.invalidContent,
      );
    }
    return _write(previous, notes: notes, content: content);
  });

  Future<PortfolioDraft> _write(
    _DraftRecord previous, {
    required String notes,
    required PortfolioContent? content,
  }) async {
    final draft = PortfolioDraft(
      notes: notes,
      revision: (previous.draft?.revision ?? 0) + 1,
      updatedAt: _clock(),
      pendingSync: true,
      content: content,
    );
    final envelope = jsonEncode({
      'schemaVersion': schemaVersion,
      'notes': draft.notes,
      'revision': draft.revision,
      'updatedAt': draft.updatedAt!.toIso8601String(),
      'pendingSync': draft.pendingSync,
      'content': content == null ? null : encodePortfolioContent(content),
    });
    if (previous.version == 1) {
      if (_box.containsKey(legacyBackupKey)) {
        if (_box.get(legacyBackupKey) != previous.raw) throw _corrupted;
      } else {
        // Backup завершается до замены: сбой оставляет исходный v1 нетронутым.
        await _box.put(legacyBackupKey, previous.raw);
      }
    }
    // Future put завершается после записи backend; при сбое Hive откатывает её.
    await _box.put(storageKey, envelope);
    return draft;
  }

  _DraftRecord _readRecord() {
    if (!_box.containsKey(storageKey)) return const _DraftRecord();
    final raw = _box.get(storageKey);
    if (raw is! String) throw _corrupted;
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      throw _corrupted;
    }
    if (decoded is! Map<String, dynamic>) throw _corrupted;
    final version = decoded['schemaVersion'];
    if (version is! int) throw _corrupted;
    if (version != 1 && version != schemaVersion) {
      throw const PortfolioDraftFailure(
        PortfolioDraftFailureKind.unsupportedVersion,
      );
    }
    final notes = decoded['notes'];
    final revision = decoded['revision'];
    final updatedAt = decoded['updatedAt'];
    final pendingSync = decoded['pendingSync'];
    if (notes is! String ||
        revision is! int ||
        revision < 0 ||
        pendingSync is! bool ||
        !decoded.containsKey('updatedAt')) {
      throw _corrupted;
    }
    DateTime? parsedDate;
    if (updatedAt != null) {
      if (updatedAt is! String || !updatedAt.endsWith('Z')) throw _corrupted;
      parsedDate = DateTime.tryParse(updatedAt);
      if (parsedDate == null || parsedDate.toIso8601String() != updatedAt) {
        throw _corrupted;
      }
    }
    PortfolioContent? content;
    if (version == schemaVersion) {
      if (!decoded.containsKey('content')) throw _corrupted;
      if (decoded['content'] != null) {
        try {
          content = decodePortfolioContent(decoded['content']);
        } on FormatException {
          throw _corrupted;
        }
      }
    }
    return _DraftRecord(
      raw: raw,
      version: version,
      draft: PortfolioDraft(
        notes: notes,
        revision: revision,
        updatedAt: parsedDate,
        pendingSync: pendingSync,
        content: content,
      ),
    );
  }

  Future<T> _serial<T>(FutureOr<T> Function() operation) {
    final result = Completer<T>();
    _operations = _operations.then((_) async {
      try {
        result.complete(await operation());
      } on PortfolioDraftFailure catch (failure) {
        result.completeError(failure);
      } catch (_) {
        result.completeError(
          const PortfolioDraftFailure(PortfolioDraftFailureKind.unavailable),
        );
      }
    });
    return result.future;
  }

  static const _corrupted = PortfolioDraftFailure(
    PortfolioDraftFailureKind.corrupted,
  );
}

final class _DraftRecord {
  const _DraftRecord({this.draft, this.raw, this.version});

  final PortfolioDraft? draft;
  final String? raw;
  final int? version;
}
