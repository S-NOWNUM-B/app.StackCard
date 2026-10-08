import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_validation.dart';
import '../domain/portfolio_sync.dart';
import 'portfolio_content_codec.dart';

final class HivePortfolioDraftRepository implements PortfolioDraftRepository {
  HivePortfolioDraftRepository(
    this._box, {
    DateTime Function()? clock,
    this._storageKey = HivePortfolioDraftRepository.storageKey,
    this._backupKey = legacyBackupKey,
    this._beforeAccess,
  }) : _clock = clock ?? DateTime.now;

  static const storageKey = 'draft';
  static const schemaVersion = 7;
  static const legacyBackupKey = 'draft.v1.backup';

  final Box<dynamic> _box;
  final DateTime Function() _clock;
  final String _storageKey;
  final String _backupKey;
  final void Function()? _beforeAccess;

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

  /// An older server ACK cannot acknowledge a newer local save.
  Future<PortfolioDraft?> acknowledgeRevision(int expectedRevision) =>
      _serial(() async {
        final previous = _readRecord();
        final draft = previous.draft;
        if (draft == null || draft.revision != expectedRevision) return null;
        final acknowledged = PortfolioDraft(
          notes: draft.notes,
          revision: draft.revision,
          updatedAt: draft.updatedAt,
          pendingSync: false,
          content: draft.content,
        );
        await _persistSnapshot(previous, acknowledged);
        return acknowledged;
      });

  /// Remote revisions are never compared with the device's revision counter.
  Future<PortfolioDraft> hydrateRemote(
    CloudPortfolioDraft remote, {
    required int expectedRevision,
  }) => _serial(() async {
    final previous = _readRecord();
    if ((previous.draft?.revision ?? 0) != expectedRevision) {
      throw const PortfolioDraftFailure(PortfolioDraftFailureKind.conflict);
    }
    final content = remote.content;
    if (content != null && validatePortfolioContent(content).isNotEmpty) {
      throw const PortfolioDraftFailure(
        PortfolioDraftFailureKind.invalidContent,
      );
    }
    final hydrated = PortfolioDraft(
      notes: remote.notes,
      revision: expectedRevision + 1,
      updatedAt: remote.updatedAt,
      pendingSync: false,
      content: content,
    );
    await _persistSnapshot(previous, hydrated);
    return hydrated;
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
    await _persistSnapshot(previous, draft);
    return draft;
  }

  Future<void> _persistSnapshot(
    _DraftRecord previous,
    PortfolioDraft draft,
  ) async {
    final content = draft.content;
    final envelope = jsonEncode({
      'schemaVersion': schemaVersion,
      'notes': draft.notes,
      'revision': draft.revision,
      'updatedAt': draft.updatedAt?.toIso8601String(),
      'pendingSync': draft.pendingSync,
      'content': content == null ? null : encodePortfolioContent(content),
    });
    final previousVersion = previous.version;
    if (previousVersion != null && previousVersion < schemaVersion) {
      final key = previousVersion == 1
          ? _backupKey
          : '$_storageKey.v$previousVersion.backup';
      if (_box.containsKey(key)) {
        if (_box.get(key) != previous.raw) throw _corrupted;
      } else {
        // Backup завершается до замены: сбой сохраняет исходный envelope.
        await _box.put(key, previous.raw);
      }
      await _box.flush();
    }
    // Future put завершается после записи backend; при сбое Hive откатывает её.
    await _box.put(_storageKey, envelope);
  }

  _DraftRecord _readRecord() {
    if (!_box.containsKey(_storageKey)) return const _DraftRecord();
    return _decodeRecord(_box.get(_storageKey));
  }

  // Transfer проверяет envelope, сохраняя исходные bytes и metadata.
  static PortfolioDraft validateStoredEnvelope(Object? raw) =>
      _decodeRecord(raw).draft!;

  static _DraftRecord _decodeRecord(Object? raw) {
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
    if (version != 1 &&
        version != 2 &&
        version != 3 &&
        version != 4 &&
        version != 5 &&
        version != 6 &&
        version != schemaVersion) {
      throw const PortfolioDraftFailure(
        PortfolioDraftFailureKind.unsupportedVersion,
      );
    }
    if (version < 5 &&
        decoded['content'] is Map &&
        (decoded['content'] as Map).containsKey('documents')) {
      throw _corrupted;
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
    if (version >= 2) {
      if (!decoded.containsKey('content')) throw _corrupted;
      if (decoded['content'] != null) {
        try {
          content = decodePortfolioContent(
            decoded['content'],
            allowMedia: version >= 4,
            allowDocuments: version >= 5,
            allowBaseSnapshot: version >= 6,
            allowPresentationPrivacy: version >= 7,
          );
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

  Future<T> _serial<T>(FutureOr<T> Function() operation) =>
      HiveDraftOperations.run(_box, () {
        _beforeAccess?.call();
        return operation();
      });

  static const _corrupted = PortfolioDraftFailure(
    PortfolioDraftFailureKind.corrupted,
  );
}

// Общая очередь box исключает гонки между разными adapters и transfer.
final class HiveDraftOperations {
  static final _queues = Expando<_HiveDraftQueue>();

  static Future<T> run<T>(Box<dynamic> box, FutureOr<T> Function() operation) {
    final queue = _queues[box] ??= _HiveDraftQueue();
    final result = Completer<T>();
    queue.operations = queue.operations.then((_) async {
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
}

final class _HiveDraftQueue {
  Future<void> operations = Future.value();
}

final class _DraftRecord {
  const _DraftRecord({this.draft, this.raw, this.version});

  final PortfolioDraft? draft;
  final String? raw;
  final int? version;
}
