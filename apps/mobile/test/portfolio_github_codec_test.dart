import 'dart:convert';

import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Private codec round-trips source metadata, overrides and ignored repositories', () {
    final imported = addGitHubProject(
      PortfolioContent(),
      _source(),
      validatedAt: DateTime.utc(2026, 10, 4, 1),
    );
    final original = imported.projects.single;
    final edited = original.withUserEdits(
      original.copyWith(description: 'Owner description', technologies: []),
    );
    final content = ignoreGitHubProject(
      imported.copyWith(projects: [edited]),
      _source(id: 99),
    );
    final json = _json(content);
    final decoded = decodePortfolioContent(json);
    expect(decoded, content);
    expect(decoded.hashCode, content.hashCode);
    expect(decoded.projects.single.githubMetadata!.overrideFields, {
      PortfolioGitHubField.description,
      PortfolioGitHubField.technologies,
    });
    expect(
      reviewGitHubProject(decoded, _source(id: 99)).status,
      PortfolioGitHubReviewStatus.ignored,
    );
    expect(
      decoded.projects.single.githubMetadata!.acceptedSource.fingerprint,
      _source().fingerprint,
    );
  });

  test('Legacy content without new keys remains manual with an empty ignore registry', () {
    final old = _json(
      PortfolioContent(
        projects: [
          PortfolioProject(
            id: 'manual',
            title: 'Legacy',
            description: 'Kept',
            technologies: ['Dart'],
          ),
        ],
      ),
    );
    old.remove('ignoredGitHubRepositories');
    final project = (old['projects'] as List).single as Map<String, dynamic>;
    project.remove('source');
    project.remove('githubMetadata');
    final decoded = decodePortfolioContent(old);
    expect(decoded.projects.single.source, PortfolioProjectSource.manual);
    expect(decoded.projects.single.githubRepositoryId, isNull);
    expect(decoded.projects.single.description, 'Kept');
    expect(decoded.ignoredGitHubRepositories, isEmpty);
    expect(project.containsKey('source'), isFalse);
  });

  test('Nullable source values and unknown validation time remain null', () {
    final decoded = decodePortfolioContent(
      _json(addGitHubProject(PortfolioContent(), _source(nullable: true))),
    );
    final project = decoded.projects.single;
    expect(project.description, isEmpty);
    expect(project.technologies, isEmpty);
    expect(project.lastGitHubSyncAt, isNull);
    expect(project.githubMetadata!.acceptedSource.language, isNull);
    expect(project.githubMetadata!.acceptedSource.description, isNull);
  });

  final malformed = <String, void Function(Map<String, dynamic>)>{
    'unknown project source': (json) =>
        _project(json)['source'] = 'future-source',
    'non-string project source': (json) => _project(json)['source'] = 1,
    'GitHub project missing metadata': (json) =>
        _project(json).remove('githubMetadata'),
    'manual with GitHub metadata': (json) =>
        _project(json)['source'] = 'manual',
    'metadata wrong root': (json) => _project(json)['githubMetadata'] = [],
    'unknown metadata field': (json) => _metadata(json)['unknown'] = true,
    'missing metadata nullable date': (json) =>
        _metadata(json).remove('lastGitHubSyncAt'),
    'non-UTC metadata date': (json) =>
        _metadata(json)['lastGitHubSyncAt'] = '2026-10-04T00:00:00.000',
    'overflow metadata date': (json) =>
        _metadata(json)['lastGitHubSyncAt'] = '2026-02-31T00:00:00.000Z',
    'wrong metadata date type': (json) =>
        _metadata(json)['lastGitHubSyncAt'] = 123,
    'unknown override field': (json) =>
        _metadata(json)['overrideFields'] = ['future'],
    'duplicate override field': (json) =>
        _metadata(json)['overrideFields'] = ['title', 'title'],
    'wrong override collection': (json) =>
        _metadata(json)['overrideFields'] = null,
    'source unknown field': (json) => _sourceJson(json)['unknown'] = true,
    'source missing nullable field': (json) =>
        _sourceJson(json).remove('language'),
    'negative source identity': (json) =>
        _sourceJson(json)['repositoryId'] = -1,
    'fractional source identity': (json) =>
        _sourceJson(json)['repositoryId'] = 1.5,
    'negative stars': (json) => _sourceJson(json)['stars'] = -1,
    'negative forks': (json) => _sourceJson(json)['forks'] = -1,
    'wrong source flag': (json) => _sourceJson(json)['archived'] = 'true',
    'wrong source description': (json) =>
        _sourceJson(json)['description'] = 123,
    'empty source language': (json) => _sourceJson(json)['language'] = '',
    'unsafe source URL': (json) =>
        _sourceJson(json)['htmlUrl'] = 'javascript:alert(1)',
    'non-UTC source date': (json) =>
        _sourceJson(json)['updatedAt'] = '2026-10-04T00:00:00.000+00:00',
    'invalid source date': (json) =>
        _sourceJson(json)['updatedAt'] = 'not-a-date',
    'null source date': (json) => _sourceJson(json)['updatedAt'] = null,
    'wrong ignore root': (json) => json['ignoredGitHubRepositories'] = {},
    'ignore unknown field': (json) => json['ignoredGitHubRepositories'] = [
      {'repositoryId': 42, 'fingerprint': 'valid', 'unknown': true},
    ],
    'duplicate ignored identity': (json) =>
        json['ignoredGitHubRepositories'] = [
          {'repositoryId': 42, 'fingerprint': 'one'},
          {'repositoryId': 42, 'fingerprint': 'two'},
        ],
    'negative ignored identity': (json) => json['ignoredGitHubRepositories'] = [
      {'repositoryId': -1, 'fingerprint': 'one'},
    ],
    'empty fingerprint': (json) => json['ignoredGitHubRepositories'] = [
      {'repositoryId': 42, 'fingerprint': ''},
    ],
    'duplicate imported identity': (json) {
      final duplicate =
          jsonDecode(jsonEncode(_project(json))) as Map<String, dynamic>;
      duplicate['id'] = 'other-local-id';
      (json['projects'] as List).add(duplicate);
    },
  };
  for (final entry in malformed.entries) {
    test('Codec rejects ${entry.key}', () {
      final json = _json(addGitHubProject(PortfolioContent(), _source()));
      entry.value(json);
      expect(() => decodePortfolioContent(json), throwsFormatException);
    });
  }
}

Map<String, dynamic> _json(PortfolioContent content) =>
    jsonDecode(jsonEncode(encodePortfolioContent(content)))
        as Map<String, dynamic>;
Map<String, dynamic> _project(Map<String, dynamic> json) =>
    (json['projects'] as List).single as Map<String, dynamic>;
Map<String, dynamic> _metadata(Map<String, dynamic> json) =>
    _project(json)['githubMetadata'] as Map<String, dynamic>;
Map<String, dynamic> _sourceJson(Map<String, dynamic> json) =>
    _metadata(json)['acceptedSource'] as Map<String, dynamic>;

GitHubProjectSource _source({int id = 42, bool nullable = false}) =>
    GitHubProjectSource(
      repositoryId: id,
      name: 'stackcard',
      fullName: 'snownumb/stackcard',
      htmlUrl: 'https://github.com/snownumb/stackcard',
      description: nullable ? null : 'Description',
      language: nullable ? null : 'Dart',
      stars: 12,
      forks: 3,
      isFork: false,
      archived: false,
      updatedAt: DateTime.utc(2026, 10, 4),
    );
