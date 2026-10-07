import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_draft.dart';
import 'hive_portfolio_draft_repository.dart';
import 'hive_portfolio_sync_metadata_store.dart';

/// Local device isolation; this does not encrypt drafts or synchronize them.
/// Transfer is explicit. A pending journal reserves the guest draft for one
/// owner and blocks guest/owner edits until that owner explicitly retries.
final class LocalDraftAccounts {
  LocalDraftAccounts(this._box);

  static const _journalKey = 'draft.guest.transfer';
  static const _generationKey = 'draft.guest.generation';
  static const _guestKey = HivePortfolioDraftRepository.storageKey;
  static const _guestBackupKey = HivePortfolioDraftRepository.legacyBackupKey;

  final Box<dynamic> _box;

  HivePortfolioDraftRepository get guestRepository {
    final generation = _generation();
    return HivePortfolioDraftRepository(
      _box,
      beforeAccess: () {
        if (_journal() != null || generation != _generation()) throw _conflict;
      },
    );
  }

  HivePortfolioDraftRepository repositoryForUser(String uid) {
    final key = _userKey(uid);
    return HivePortfolioDraftRepository(
      _box,
      storageKey: key,
      backupKey: _backupKey(key),
      beforeAccess: () {
        if (_journal()?.ownerKey == key) throw _conflict;
      },
    );
  }

  Future<bool> hasGuestDraft({String? forUid}) => HiveDraftOperations.run(
    _box,
    () {
      final journal = _journal();
      if (journal != null) {
        return forUid == null || journal.ownerKey == _userKey(forUid);
      }
      _generation();
      if (!_box.containsKey(_guestKey)) return false;
      HivePortfolioDraftRepository.validateStoredEnvelope(_box.get(_guestKey));
      return true;
    },
  );

  Future<bool> hasPendingTransferForUser(String uid) => HiveDraftOperations.run(
    _box,
    () => _journal()?.ownerKey == _userKey(uid),
  );

  Future<void> transferGuestToUser(
    String uid, {
    Future<PortfolioSyncRecord?> Function(
      PortfolioDraft draft,
      String transferId,
    )?
    beforeCommit,
  }) => HiveDraftOperations.run(_box, () async {
    final ownerKey = _userKey(uid);
    var journal = _journal();
    if (journal == null) {
      if (!_box.containsKey(_guestKey)) return;
      final raw = _validatedRaw(_guestKey);
      final backup = _optionalBackup(_guestBackupKey);
      final backups = {
        for (
          var version = 2;
          version < HivePortfolioDraftRepository.schemaVersion;
          version++
        )
          if (_box.containsKey(_versionBackupKey(_guestKey, version)))
            version: _optionalBackup(
              _versionBackupKey(_guestKey, version),
              version: version,
            )!,
      };
      if ((jsonDecode(raw) as Map)['schemaVersion'] == 1 &&
          backup != null &&
          backup != raw) {
        throw _corrupted;
      }
      _requireEmpty(ownerKey);
      journal = _TransferJournal(
        ownerKey: ownerKey,
        raw: raw,
        backup: backup,
        backups: backups,
        generation: _generation(),
        committed: false,
      );
      // Durable reservation precedes destination: a second account cannot
      // claim the original if the process stops after the next write.
      await _persist(_journalKey, journal.encode());
    } else if (journal.ownerKey != ownerKey) {
      throw _conflict;
    }

    _checkSource(journal);
    _checkDestination(journal);
    if (journal.legacy && _box.containsKey(ownerKey)) {
      // Phase 7 already committed this explicit local transfer. Finish its
      // cleanup; the authored pending draft follows ordinary sync semantics.
      journal = journal.asLegacyLocalCommit();
      await _persist(_journalKey, journal.encode());
    }
    if (beforeCommit != null &&
        !journal.syncPrepared &&
        !journal.legacyLocalCommit) {
      final transferJournal = journal;
      final source = HivePortfolioDraftRepository.validateStoredEnvelope(
        journal.raw,
      );
      try {
        final record = await beforeCommit(
          source,
          'guest-transfer-${journal.generation}-${source.revision}',
        );
        if (record != null) {
          final acknowledged = record.draft;
          if (record.pending ||
              acknowledged.pendingSync ||
              acknowledged.revision != source.revision ||
              acknowledged.notes != source.notes ||
              acknowledged.content != source.content ||
              acknowledged.updatedAt != source.updatedAt) {
            throw _corrupted;
          }
          await _persist(
            HivePortfolioSyncMetadataStore.storageKeyForUser(uid),
            encodePortfolioSyncRecord(record),
          );
        }
        journal = journal.asSyncPrepared();
        await _persist(_journalKey, journal.encode());
      } on PortfolioDraftFailure catch (failure) {
        // A confirmed occupied server leaves the original guest intact.
        // Before the local destination commits, release an abandoned claim
        // rather than permanently locking both guest and account access.
        if (failure.kind == PortfolioDraftFailureKind.conflict &&
            !transferJournal.committed &&
            !_box.containsKey(ownerKey)) {
          final syncKey = HivePortfolioSyncMetadataStore.storageKeyForUser(uid);
          if (_box.containsKey(syncKey)) {
            final record = HivePortfolioSyncMetadataStore.validateStoredRecord(
              _box.get(syncKey),
            );
            if (record.mutationId !=
                    'guest-transfer-${transferJournal.generation}-${source.revision}' ||
                record.pending ||
                record.draft.notes != source.notes ||
                record.draft.content != source.content ||
                record.draft.revision != source.revision ||
                record.draft.updatedAt != source.updatedAt) {
              throw _corrupted;
            }
            await _delete(syncKey);
          }
          await _delete(_journalKey);
        }
        rethrow;
      }
    }
    if (!_box.containsKey(ownerKey)) {
      await _persist(ownerKey, journal.raw);
    }
    if (journal.backup != null && !_box.containsKey(_backupKey(ownerKey))) {
      await _persist(_backupKey(ownerKey), journal.backup);
    }
    for (final backup in journal.backups.entries) {
      final key = _versionBackupKey(ownerKey, backup.key);
      if (!_box.containsKey(key)) await _persist(key, backup.value);
    }
    if (!journal.committed) {
      journal = journal.asCommitted();
      await _persist(_journalKey, journal.encode());
    }
    // Retain a generation tombstone after cleanup. Already-created guest
    // repositories (including queued saves) cannot resurrect this owner.
    await _persist(_generationKey, journal.generation + 1);
    await _delete(_guestKey);
    await _delete(_guestBackupKey);
    for (final version in journal.backups.keys) {
      await _delete(_versionBackupKey(_guestKey, version));
    }
    await _delete(_journalKey);
  });

  void _checkSource(_TransferJournal journal) {
    final generation = _generation();
    if (generation != journal.generation &&
        !(journal.committed && generation == journal.generation + 1)) {
      throw _corrupted;
    }
    if (_box.containsKey(_guestKey)) {
      if (_validatedRaw(_guestKey) != journal.raw) throw _conflict;
    } else if (!journal.committed) {
      throw _corrupted;
    }
    if (_box.containsKey(_guestBackupKey)) {
      if (_optionalBackup(_guestBackupKey) != journal.backup) throw _conflict;
    } else if (journal.backup != null && !journal.committed) {
      throw _corrupted;
    }
    for (
      var version = 2;
      version < HivePortfolioDraftRepository.schemaVersion;
      version++
    ) {
      final key = _versionBackupKey(_guestKey, version);
      final backup = journal.backups[version];
      if (_box.containsKey(key)) {
        if (_optionalBackup(key, version: version) != backup) throw _conflict;
      } else if (backup != null && !journal.committed) {
        throw _corrupted;
      }
    }
  }

  void _checkDestination(_TransferJournal journal) {
    if (_box.containsKey(journal.ownerKey) &&
        _validatedRaw(journal.ownerKey) != journal.raw) {
      throw _conflict;
    }
    final key = _backupKey(journal.ownerKey);
    if (_box.containsKey(key) && _optionalBackup(key) != journal.backup) {
      throw _conflict;
    }
    for (
      var version = 2;
      version < HivePortfolioDraftRepository.schemaVersion;
      version++
    ) {
      final key = _versionBackupKey(journal.ownerKey, version);
      if (_box.containsKey(key) &&
          _optionalBackup(key, version: version) != journal.backups[version]) {
        throw _conflict;
      }
    }
  }

  void _requireEmpty(String key) {
    if (_box.containsKey(key)) {
      _validatedRaw(key);
      throw _conflict;
    }
    if (_box.containsKey(_backupKey(key))) {
      _optionalBackup(_backupKey(key));
      throw _conflict;
    }
    for (
      var version = 2;
      version < HivePortfolioDraftRepository.schemaVersion;
      version++
    ) {
      final backupKey = _versionBackupKey(key, version);
      if (_box.containsKey(backupKey)) {
        _optionalBackup(backupKey, version: version);
        throw _conflict;
      }
    }
  }

  String _validatedRaw(String key) {
    final raw = _box.get(key);
    HivePortfolioDraftRepository.validateStoredEnvelope(raw);
    return raw as String;
  }

  String? _optionalBackup(String key, {int version = 1}) {
    if (!_box.containsKey(key)) return null;
    final raw = _validatedRaw(key);
    if ((jsonDecode(raw) as Map)['schemaVersion'] != version) throw _corrupted;
    return raw;
  }

  int _generation() {
    if (!_box.containsKey(_generationKey)) return 0;
    final value = _box.get(_generationKey);
    if (value is! int || value < 0) throw _corrupted;
    return value;
  }

  _TransferJournal? _journal() {
    if (!_box.containsKey(_journalKey)) return null;
    final raw = _box.get(_journalKey);
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
      final owner = value['owner'];
      final source = value['raw'];
      final backup = value['backup'];
      final rawBackups = value['backups'] ?? <String, dynamic>{};
      final generation = value['generation'];
      final committed = value['committed'];
      final syncPrepared = value['syncPrepared'] ?? false;
      final legacyLocalCommit = value['legacyLocalCommit'] ?? false;
      if (owner is! String ||
          !owner.startsWith('draft.user.') ||
          source is! String ||
          (backup != null && backup is! String) ||
          rawBackups is! Map<String, dynamic> ||
          !value.containsKey('backup') ||
          generation is! int ||
          generation < 0 ||
          committed is! bool ||
          syncPrepared is! bool ||
          legacyLocalCommit is! bool) {
        throw _corrupted;
      }
      final encoded = owner.substring('draft.user.'.length);
      if (_userKey(
            utf8.decode(base64Url.decode(base64Url.normalize(encoded))),
          ) !=
          owner) {
        throw _corrupted;
      }
      HivePortfolioDraftRepository.validateStoredEnvelope(source);
      final backups = <int, String>{};
      for (final entry in rawBackups.entries) {
        final version = int.tryParse(entry.key);
        final rawBackup = entry.value;
        if (version == null ||
            version < 2 ||
            version >= HivePortfolioDraftRepository.schemaVersion ||
            entry.key != '$version' ||
            rawBackup is! String) {
          throw _corrupted;
        }
        HivePortfolioDraftRepository.validateStoredEnvelope(rawBackup);
        if ((jsonDecode(rawBackup) as Map)['schemaVersion'] != version) {
          throw _corrupted;
        }
        backups[version] = rawBackup;
      }
      if (backup != null) {
        HivePortfolioDraftRepository.validateStoredEnvelope(backup);
        if ((jsonDecode(backup as String) as Map)['schemaVersion'] != 1) {
          throw _corrupted;
        }
      }
      return _TransferJournal(
        ownerKey: owner,
        raw: source,
        backup: backup as String?,
        backups: backups,
        generation: generation,
        committed: committed,
        syncPrepared: syncPrepared,
        legacy: !value.containsKey('syncPrepared'),
        legacyLocalCommit: legacyLocalCommit,
      );
    } on FormatException {
      throw _corrupted;
    } on ArgumentError {
      throw _corrupted;
    }
  }

  Future<void> _persist(String key, dynamic value) async {
    await _box.put(key, value);
    await _box.flush();
  }

  Future<void> _delete(String key) async {
    await _box.delete(key);
    await _box.flush();
  }

  static String _userKey(String uid) {
    if (uid.isEmpty) throw ArgumentError.value(uid, 'uid', 'Must not be empty');
    return 'draft.user.${base64Url.encode(utf8.encode(uid)).replaceAll('=', '')}';
  }

  static String _backupKey(String key) => '$key.v1.backup';
  static String _versionBackupKey(String key, int version) =>
      '$key.v$version.backup';
  static const _conflict = PortfolioDraftFailure(
    PortfolioDraftFailureKind.conflict,
  );
  static const _corrupted = PortfolioDraftFailure(
    PortfolioDraftFailureKind.corrupted,
  );
}

final class _TransferJournal {
  const _TransferJournal({
    required this.ownerKey,
    required this.raw,
    required this.backup,
    this.backups = const {},
    required this.generation,
    required this.committed,
    this.syncPrepared = false,
    this.legacy = false,
    this.legacyLocalCommit = false,
  });

  final String ownerKey;
  final String raw;
  final String? backup;
  final Map<int, String> backups;
  final int generation;
  final bool committed;
  final bool syncPrepared;
  final bool legacy;
  final bool legacyLocalCommit;

  _TransferJournal asCommitted() => _TransferJournal(
    ownerKey: ownerKey,
    raw: raw,
    backup: backup,
    backups: backups,
    generation: generation,
    committed: true,
    syncPrepared: syncPrepared,
    legacyLocalCommit: legacyLocalCommit,
  );

  _TransferJournal asSyncPrepared() => _TransferJournal(
    ownerKey: ownerKey,
    raw: raw,
    backup: backup,
    backups: backups,
    generation: generation,
    committed: committed,
    syncPrepared: true,
    legacyLocalCommit: legacyLocalCommit,
  );

  _TransferJournal asLegacyLocalCommit() => _TransferJournal(
    ownerKey: ownerKey,
    raw: raw,
    backup: backup,
    backups: backups,
    generation: generation,
    committed: committed,
    syncPrepared: syncPrepared,
    legacyLocalCommit: true,
  );

  String encode() => jsonEncode({
    'schemaVersion': 1,
    'owner': ownerKey,
    'raw': raw,
    'backup': backup,
    'backups': {
      for (final entry in backups.entries) '${entry.key}': entry.value,
    },
    'generation': generation,
    'committed': committed,
    'syncPrepared': syncPrepared,
    'legacyLocalCommit': legacyLocalCommit,
  });
}
