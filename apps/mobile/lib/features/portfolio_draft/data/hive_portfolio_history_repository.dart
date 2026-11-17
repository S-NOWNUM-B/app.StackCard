import 'dart:convert';

import 'package:hive/hive.dart';

import '../domain/portfolio_content.dart';
import '../domain/portfolio_history.dart';
import 'hive_portfolio_draft_repository.dart';
import 'portfolio_content_codec.dart';

/// Локальная история одного владельца в отдельной Hive box. В Firestore
/// ничего не пишется; ключ владельца изолирует guest и разные UID.
final class HivePortfolioHistoryRepository
    implements PortfolioHistoryRepository {
  HivePortfolioHistoryRepository(
    this._box, {
    String? uid,
    this.limit = portfolioHistoryLimit,
  }) : _key = storageKeyFor(uid);

  static const schemaVersion = 1;
  static const guestKey = 'history.guest';

  static String storageKeyFor(String? uid) =>
      uid == null ? guestKey : 'history.user.$uid';

  final Box<dynamic> _box;
  final String _key;
  final int limit;
  int _counter = 0;

  @override
  Future<List<PortfolioSnapshot>> list() => _serial(() => _read());

  @override
  Future<void> record(PortfolioContent workspace, DateTime at) =>
      _serial(() async {
        final snapshot = buildPortfolioSnapshot(
          workspace: workspace,
          at: at,
          id: '${at.toUtc().microsecondsSinceEpoch}-${_counter++}',
        );
        if (snapshot == null) return;
        // Повреждённая запись заменяется новой историей, а не блокирует Save.
        List<PortfolioSnapshot> existing;
        try {
          existing = _read();
        } on PortfolioHistoryFailure {
          existing = const [];
        }
        final next = appendPortfolioSnapshot(existing, snapshot);
        if (identical(next, existing)) return;
        await _box.put(_key, _encode(next.take(limit).toList()));
      });

  @override
  Future<void> clear() => _serial(() async {
    if (_box.containsKey(_key)) await _box.delete(_key);
  });

  // Чтение не пишет: старые и неподдерживаемые записи не переписываются.
  List<PortfolioSnapshot> _read() {
    if (!_box.containsKey(_key)) return const [];
    final raw = _box.get(_key);
    try {
      if (raw is! String) throw const FormatException('history');
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['schemaVersion'] != schemaVersion ||
          decoded['entries'] is! List) {
        throw const FormatException('history');
      }
      return List.unmodifiable([
        for (final entry in decoded['entries'] as List) _decode(entry),
      ]);
    } on FormatException {
      throw const PortfolioHistoryFailure();
    } on TypeError {
      throw const PortfolioHistoryFailure();
    }
  }

  static String _encode(List<PortfolioSnapshot> snapshots) => jsonEncode({
    'schemaVersion': schemaVersion,
    'entries': [
      for (final snapshot in snapshots)
        {
          'id': snapshot.id,
          'savedAt': snapshot.savedAt.toIso8601String(),
          'hasAvatar': snapshot.hasAvatar,
          'content': encodePortfolioContent(
            snapshot.content,
            includeDocuments: false,
          ),
          'attachments': [
            for (final item in snapshot.attachments)
              {
                'projectId': item.projectId,
                'visible': item.visible,
                'featured': item.featured,
                'titleOverride': item.titleOverride,
                'descriptionOverride': item.descriptionOverride,
                'contributionOverride': item.contributionOverride,
              },
          ],
        },
    ],
  });

  static PortfolioSnapshot _decode(Object? raw) {
    final map = raw as Map<String, dynamic>;
    final savedAt = DateTime.parse(map['savedAt'] as String);
    return PortfolioSnapshot(
      id: map['id'] as String,
      savedAt: savedAt,
      hasAvatar: map['hasAvatar'] as bool,
      content: decodePortfolioContent(map['content']),
      attachments: [
        for (final item in map['attachments'] as List)
          PortfolioProjectAttachment(
            projectId: (item as Map<String, dynamic>)['projectId'] as String,
            visible: item['visible'] as bool,
            featured: item['featured'] as bool,
            titleOverride: item['titleOverride'] as String?,
            descriptionOverride: item['descriptionOverride'] as String?,
            contributionOverride: item['contributionOverride'] as String?,
          ),
      ],
    );
  }

  Future<T> _serial<T>(T Function() operation) =>
      HiveDraftOperations.run(_box, operation).catchError((Object error) {
        if (error is PortfolioHistoryFailure) throw error;
        throw const PortfolioHistoryFailure();
      });
}
