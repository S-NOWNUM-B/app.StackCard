import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/// Раздельные коробки: восстановление source-кэша не затрагивает draft.
final class LocalStorage {
  LocalStorage._(this.githubResponses, this.portfolioDraft);

  final Box<dynamic> githubResponses;
  final Box<dynamic> portfolioDraft;
  Future<void>? _closeFuture;

  static Future<LocalStorage> open({Directory? directory}) async {
    final support = directory ?? await getApplicationSupportDirectory();
    final storage = Directory('${support.path}/stackcard');
    await storage.create(recursive: true);
    final cache = await _openCache(storage);
    try {
      final draft = await _openBox('portfolio_draft', storage);
      return LocalStorage._(cache, draft);
    } on Exception {
      await cache.close();
      rethrow;
    } on HiveError {
      await cache.close();
      rethrow;
    }
  }

  static Future<Box<dynamic>> _openCache(Directory directory) async {
    try {
      return await _openBox('github_responses', directory);
    } on HiveError {
      await _preserveCacheFile(directory);
    } on FileSystemException {
      await _preserveCacheFile(directory);
    }
    return _openBox('github_responses', directory);
  }

  static Future<Box<dynamic>> _openBox(String name, Directory directory) async {
    // Hive 2.2.3 при ошибке открытия завершает два Future. Второй публичный
    // openBox наблюдает внутреннее ожидание; Future.wait обрабатывает обе ошибки.
    // crashRecovery:false сохраняет повреждённый draft без обрезки файла.
    final boxes = await Future.wait([
      Hive.openBox<dynamic>(name, path: directory.path, crashRecovery: false),
      Hive.openBox<dynamic>(name, path: directory.path, crashRecovery: false),
    ]);
    return boxes.first;
  }

  static Future<void> _preserveCacheFile(Directory directory) async {
    final file = File('${directory.path}/github_responses.hive');
    if (await file.exists()) {
      final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
      await file.rename('${file.path}.unreadable-$stamp');
    }
  }

  Future<void> close() => _closeFuture ??= _closeBoxes();

  Future<void> _closeBoxes() async {
    await Future.wait([
      if (githubResponses.isOpen) githubResponses.close(),
      if (portfolioDraft.isOpen) portfolioDraft.close(),
    ]);
  }
}
