import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/dio_github_import_repository.dart';
import 'data/github_response_cache.dart';
import 'domain/github_import_repository.dart';

final githubImportClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Только session-кэш; постоянное хранение вводится на Phase 5.
final githubResponseCacheProvider = Provider<GitHubResponseCache>(
  (ref) => MemoryGitHubResponseCache(),
);

// Repository живёт в app session: выход с экрана не сбрасывает rate deadline.
final githubImportRepositoryProvider = Provider<GitHubImportRepository>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://api.github.com',
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      followRedirects: false,
      headers: {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2026-03-10',
        'User-Agent': 'StackCard',
      },
    ),
  );
  final repository = DioGitHubImportRepository(
    dio,
    cache: ref.watch(githubResponseCacheProvider),
    clock: ref.watch(githubImportClockProvider),
  );
  ref.onDispose(() {
    repository.cancelRequests();
    dio.close(force: true);
  });
  return repository;
});
