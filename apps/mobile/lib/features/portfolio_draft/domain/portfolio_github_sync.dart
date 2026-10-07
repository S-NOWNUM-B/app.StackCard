import 'dart:convert';

import 'portfolio_collection_equality.dart';
import 'portfolio_content.dart';
import 'portfolio_validation.dart';

enum PortfolioGitHubField { title, description, technologies, repositoryUrl }

enum PortfolioGitHubReviewStatus {
  newRepository,
  synced,
  changesAvailable,
  ignored,
}

enum PortfolioGitHubFailureKind { invalidSource, invalidContent, conflict }

final class PortfolioGitHubFailure implements Exception {
  const PortfolioGitHubFailure(this.kind);
  final PortfolioGitHubFailureKind kind;
}

/// Public source metadata; it does not grant permission to alter curated fields.
final class GitHubProjectSource {
  GitHubProjectSource({
    required this.repositoryId,
    required this.name,
    required this.fullName,
    required this.htmlUrl,
    required this.stars,
    required this.forks,
    required this.isFork,
    required this.archived,
    required DateTime updatedAt,
    this.description,
    this.language,
  }) : updatedAt = updatedAt.toUtc();

  final int repositoryId;
  final String name;
  final String fullName;
  final String htmlUrl;
  final String? description;
  final String? language;
  final int stars;
  final int forks;
  final bool isFork;
  final bool archived;
  final DateTime updatedAt;

  String get fingerprint => gitHubProjectFingerprint(this);

  Object get _fields => (
    repositoryId,
    name,
    fullName,
    htmlUrl,
    description,
    language,
    stars,
    forks,
    isFork,
    archived,
    updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is GitHubProjectSource && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}

final class GitHubProjectMetadata {
  GitHubProjectMetadata({
    required this.acceptedSource,
    DateTime? lastGitHubSyncAt,
    Set<PortfolioGitHubField> overrideFields = const {},
  }) : lastGitHubSyncAt = lastGitHubSyncAt?.toUtc(),
       overrideFields = Set.unmodifiable(overrideFields);

  final GitHubProjectSource acceptedSource;
  final DateTime? lastGitHubSyncAt;
  final Set<PortfolioGitHubField> overrideFields;

  GitHubProjectMetadata copyWith({
    GitHubProjectSource? acceptedSource,
    DateTime? lastGitHubSyncAt,
    Set<PortfolioGitHubField>? overrideFields,
  }) => GitHubProjectMetadata(
    acceptedSource: acceptedSource ?? this.acceptedSource,
    lastGitHubSyncAt: lastGitHubSyncAt ?? this.lastGitHubSyncAt,
    overrideFields: overrideFields ?? this.overrideFields,
  );

  @override
  bool operator ==(Object other) =>
      other is GitHubProjectMetadata &&
      other.acceptedSource == acceptedSource &&
      other.lastGitHubSyncAt == lastGitHubSyncAt &&
      other.overrideFields.length == overrideFields.length &&
      other.overrideFields.containsAll(overrideFields);

  @override
  int get hashCode => Object.hash(
    acceptedSource,
    lastGitHubSyncAt,
    Object.hashAll(PortfolioGitHubField.values.where(overrideFields.contains)),
  );
}

final class GitHubIgnoredRepository {
  const GitHubIgnoredRepository({
    required this.repositoryId,
    required this.fingerprint,
  });

  final int repositoryId;
  final String fingerprint;

  @override
  bool operator ==(Object other) =>
      other is GitHubIgnoredRepository &&
      other.repositoryId == repositoryId &&
      other.fingerprint == fingerprint;

  @override
  int get hashCode => Object.hash(repositoryId, fingerprint);
}

final class PortfolioGitHubReview {
  PortfolioGitHubReview({
    required this.source,
    required this.project,
    required this.status,
    Set<PortfolioGitHubField> changedFields = const {},
  }) : changedFields = Set.unmodifiable(changedFields);

  final GitHubProjectSource source;
  final PortfolioProject? project;
  final PortfolioGitHubReviewStatus status;
  final Set<PortfolioGitHubField> changedFields;
}

/// Stable across process/platforms. BigInt avoids platform integer overflow.
String gitHubProjectFingerprint(GitHubProjectSource source) {
  final bytes = utf8.encode(
    jsonEncode([
      source.repositoryId,
      source.name,
      source.fullName,
      source.htmlUrl,
      source.description,
      source.language,
      source.stars,
      source.forks,
      source.isFork,
      source.archived,
      source.updatedAt.toIso8601String(),
    ]),
  );
  var value = BigInt.parse('14695981039346656037');
  final multiplier = BigInt.from(1099511628211);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final byte in bytes) {
    value = ((value ^ BigInt.from(byte)) * multiplier) & mask;
  }
  return 'v1:${value.toRadixString(16).padLeft(16, '0')}';
}

PortfolioGitHubReview reviewGitHubProject(
  PortfolioContent content,
  GitHubProjectSource source,
) {
  _validate(content, source);
  final project = _findProject(content, source.repositoryId);
  final accepted = project?.githubMetadata?.acceptedSource;
  final changed = <PortfolioGitHubField>{};
  if (accepted != null) {
    if (accepted.name != source.name) changed.add(PortfolioGitHubField.title);
    if ((accepted.description ?? '') != (source.description ?? '')) {
      changed.add(PortfolioGitHubField.description);
    }
    if (!portfolioListEquals(_technologies(accepted), _technologies(source))) {
      changed.add(PortfolioGitHubField.technologies);
    }
    if (accepted.htmlUrl != source.htmlUrl) {
      changed.add(PortfolioGitHubField.repositoryUrl);
    }
  }
  final ignored = content.ignoredGitHubRepositories.any(
    (item) =>
        item.repositoryId == source.repositoryId &&
        item.fingerprint == source.fingerprint,
  );
  return PortfolioGitHubReview(
    source: source,
    project: project,
    status: ignored
        ? PortfolioGitHubReviewStatus.ignored
        : project == null
        ? PortfolioGitHubReviewStatus.newRepository
        : accepted == source
        ? PortfolioGitHubReviewStatus.synced
        : PortfolioGitHubReviewStatus.changesAvailable,
    changedFields: changed,
  );
}

PortfolioContent addGitHubProject(
  PortfolioContent content,
  GitHubProjectSource source, {
  DateTime? validatedAt,
}) {
  _validate(content, source);
  final ignored = _clearIgnore(content, source.repositoryId);
  if (_findProject(content, source.repositoryId) != null) {
    return content.copyWith(ignoredGitHubRepositories: ignored);
  }
  final id = 'github-${source.repositoryId}';
  if (content.projects.any((project) => project.id == id)) throw _conflict;
  final project = PortfolioProject(
    updatedAt: validatedAt,
    id: id,
    title: source.name,
    description: source.description ?? '',
    technologies: _technologies(source),
    repositoryUrl: source.htmlUrl,
    source: PortfolioProjectSource.github,
    githubMetadata: GitHubProjectMetadata(
      acceptedSource: source,
      lastGitHubSyncAt: validatedAt,
    ),
  );
  return _validatedContent(
    content.copyWith(
      projects: [...content.projects, project],
      ignoredGitHubRepositories: ignored,
    ),
  );
}

PortfolioContent acceptGitHubProjectChanges(
  PortfolioContent content,
  PortfolioGitHubReview review, {
  DateTime? validatedAt,
}) {
  _validate(content, review.source);
  final current = _findProject(content, review.source.repositoryId);
  if (review.project == null || current != review.project) throw _conflict;
  final metadata = current!.githubMetadata!;
  final overrides = metadata.overrideFields;
  final source = review.source;
  final updated = current.copyWith(
    updatedAt: validatedAt,
    title: overrides.contains(PortfolioGitHubField.title)
        ? current.title
        : source.name,
    description: overrides.contains(PortfolioGitHubField.description)
        ? current.description
        : source.description ?? '',
    technologies: overrides.contains(PortfolioGitHubField.technologies)
        ? current.technologies
        : _technologies(source),
    repositoryUrl: overrides.contains(PortfolioGitHubField.repositoryUrl)
        ? current.repositoryUrl
        : source.htmlUrl,
    githubMetadata: GitHubProjectMetadata(
      acceptedSource: source,
      lastGitHubSyncAt: validatedAt,
      overrideFields: metadata.overrideFields,
    ),
  );
  return _validatedContent(
    content.copyWith(
      projects: content.projects
          .map((project) => project.id == current.id ? updated : project)
          .toList(),
      ignoredGitHubRepositories: _clearIgnore(content, source.repositoryId),
    ),
  );
}

PortfolioContent ignoreGitHubProject(
  PortfolioContent content,
  GitHubProjectSource source,
) {
  _validate(content, source);
  return content.copyWith(
    ignoredGitHubRepositories: [
      ..._clearIgnore(content, source.repositoryId),
      GitHubIgnoredRepository(
        repositoryId: source.repositoryId,
        fingerprint: source.fingerprint,
      ),
    ],
  );
}

void _validate(PortfolioContent content, GitHubProjectSource source) {
  if (validatePortfolioGitHubSource(source).isNotEmpty) {
    throw const PortfolioGitHubFailure(
      PortfolioGitHubFailureKind.invalidSource,
    );
  }
  _validatedContent(content);
}

PortfolioContent _validatedContent(PortfolioContent content) {
  if (validatePortfolioContent(content).isNotEmpty) {
    throw const PortfolioGitHubFailure(
      PortfolioGitHubFailureKind.invalidContent,
    );
  }
  return content;
}

PortfolioProject? _findProject(PortfolioContent content, int repositoryId) {
  for (final project in content.projects) {
    if (project.source == PortfolioProjectSource.github &&
        project.githubRepositoryId == repositoryId) {
      return project;
    }
  }
  return null;
}

List<GitHubIgnoredRepository> _clearIgnore(PortfolioContent content, int id) =>
    content.ignoredGitHubRepositories
        .where((item) => item.repositoryId != id)
        .toList();

List<String> _technologies(GitHubProjectSource source) =>
    source.language == null ? const [] : [source.language!];

const _conflict = PortfolioGitHubFailure(PortfolioGitHubFailureKind.conflict);
