import 'dart:async';
import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';

final class HivePortfolioDraftRepository implements PortfolioDraftRepository {
  HivePortfolioDraftRepository(this._box, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const storageKey = 'draft';
  static const schemaVersion = 1;

  final Box<dynamic> _box;
  final DateTime Function() _clock;
  Future<void> _operations = Future.value();

  @override
  Future<PortfolioDraft?> read() => _serial(_read);

  @override
  Future<PortfolioDraft> saveNotes(String notes) => _serial(() async {
    // Проверка перед каждой записью сохраняет неизвестный/повреждённый draft.
    final previous = _read();
    final draft = PortfolioDraft(
      notes: notes,
      revision: (previous?.revision ?? 0) + 1,
      updatedAt: _clock(),
      pendingSync: true,
    );
    final envelope = jsonEncode({
      'schemaVersion': schemaVersion,
      'notes': draft.notes,
      'revision': draft.revision,
      'updatedAt': draft.updatedAt!.toIso8601String(),
      'pendingSync': draft.pendingSync,
    });
    // Future put завершается после записи backend; при сбое Hive откатывает её.
    await _box.put(storageKey, envelope);
    return draft;
  });

  PortfolioDraft? _read() {
    if (!_box.containsKey(storageKey)) return null;
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
    if (version != schemaVersion) {
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
    return PortfolioDraft(
      notes: notes,
      revision: revision,
      updatedAt: parsedDate,
      pendingSync: pendingSync,
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
