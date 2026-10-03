import 'dart:convert';

import 'package:hive/hive.dart';

import 'github_response_cache.dart';

/// Только воспроизводимый GitHub cache; box draft сюда не передаётся.
final class HiveGitHubResponseCache implements EvictableGitHubResponseCache {
  HiveGitHubResponseCache(
    this._box, {
    this.maxAge = githubCacheMaxAge,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (maxAge <= Duration.zero) throw ArgumentError.value(maxAge, 'maxAge');
  }

  final Box<dynamic> _box;
  final Duration maxAge;
  final DateTime Function() _clock;

  @override
  Future<CachedGitHubResponse?> read(String key) async {
    final raw = _box.get(key);
    if (raw == null) return null;
    try {
      if (raw is! String) throw const FormatException('Ожидалась JSON строка');
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['schemaVersion'] is! int ||
          json['schemaVersion'] != 1 ||
          json['body'] is! String ||
          json['validatedAt'] is! int ||
          (json['etag'] != null && json['etag'] is! String) ||
          (json['link'] != null && json['link'] is! String)) {
        throw const FormatException('Некорректный envelope');
      }
      final timestamp = json['validatedAt'] as int;
      if (timestamp < 0 || timestamp > 8640000000000000) {
        throw const FormatException('Некорректная дата cache');
      }
      final validatedAt = DateTime.fromMillisecondsSinceEpoch(
        timestamp,
        isUtc: true,
      );
      final age = _clock().toUtc().difference(validatedAt);
      if (age < Duration.zero || age >= maxAge) {
        await remove(key);
        return null;
      }
      // Окончательная проверка DTO и identity Link выполняется в repository.
      jsonDecode(json['body'] as String);
      return CachedGitHubResponse(
        body: json['body'] as String,
        etag: json['etag'] as String?,
        link: json['link'] as String?,
        validatedAt: validatedAt,
      );
    } on FormatException {
      await remove(key);
      return null;
    }
  }

  @override
  Future<void> write(String key, CachedGitHubResponse response) => _box.put(
    key,
    jsonEncode({
      'schemaVersion': 1,
      'body': response.body,
      'etag': response.etag,
      'link': response.link,
      'validatedAt': (response.validatedAt ?? _clock())
          .toUtc()
          .millisecondsSinceEpoch,
    }),
  );

  @override
  Future<void> remove(String key) => _box.delete(key);
}
