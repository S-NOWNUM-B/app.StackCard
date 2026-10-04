import 'portfolio_content.dart';
import 'portfolio_github_sync.dart';
import 'portfolio_validation.dart';

enum PortfolioSuggestionKind {
  newRepository,
  recentActivity,
  inactiveProject,
  missingDescription,
  missingPreview,
  featuredCandidate,
}

enum PortfolioSuggestionAction { previewRepository, editProject }

abstract final class PortfolioSuggestionThresholds {
  static const recentActivityWindow = Duration(days: 30);
  static const inactiveProjectAge = Duration(days: 180);
  static const featuredMinimumStars = 5;
}

final class PortfolioSuggestion {
  PortfolioSuggestion({
    required this.kind,
    required this.action,
    required this.targetTitle,
    this.projectId,
    this.repositoryId,
    DateTime? updatedAt,
    this.stars,
  }) : assert(projectId != null || repositoryId != null),
       updatedAt = updatedAt?.toUtc();

  final PortfolioSuggestionKind kind;
  final PortfolioSuggestionAction action;
  final String targetTitle;
  final String? projectId;
  final int? repositoryId;
  final DateTime? updatedAt;
  final int? stars;

  String get id =>
      '${kind.name}:${projectId == null ? 'repository:$repositoryId' : 'project:$projectId'}';

  Object get _fields =>
      (kind, action, targetTitle, projectId, repositoryId, updatedAt, stars);

  @override
  bool operator ==(Object other) =>
      other is PortfolioSuggestion && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}

/// Suggestions only describe possible owner actions; no draft is changed.
List<PortfolioSuggestion> buildPortfolioSuggestions({
  required PortfolioContent content,
  Iterable<GitHubProjectSource> sources = const [],
  required DateTime now,
}) {
  final currentTime = now.toUtc();
  final latestSources = _latestSources(sources);
  final suggestions = <PortfolioSuggestion>[];

  for (final source in latestSources.values) {
    if (source.isFork || source.archived) continue;
    try {
      if (reviewGitHubProject(content, source).status !=
          PortfolioGitHubReviewStatus.newRepository) {
        continue;
      }
      suggestions.add(
        PortfolioSuggestion(
          kind: PortfolioSuggestionKind.newRepository,
          action: PortfolioSuggestionAction.previewRepository,
          targetTitle: source.name,
          repositoryId: source.repositoryId,
          updatedAt: source.updatedAt,
          stars: source.stars,
        ),
      );
    } on PortfolioGitHubFailure {
      // Invalid draft/source data must not break read-only advice.
    }
  }

  for (final project in content.projects) {
    if (!project.visible) continue;
    final acceptedSource = project.source == PortfolioProjectSource.github
        ? project.githubMetadata?.acceptedSource
        : null;
    final candidateSource =
        latestSources[acceptedSource?.repositoryId] ?? acceptedSource;
    final source =
        candidateSource != null &&
            validatePortfolioGitHubSource(candidateSource).isEmpty
        ? candidateSource
        : null;
    final ignored =
        source != null &&
        content.ignoredGitHubRepositories.any(
          (item) =>
              item.repositoryId == source.repositoryId &&
              item.fingerprint == source.fingerprint,
        );
    final age = source == null
        ? null
        : currentTime.difference(source.updatedAt);
    final recentlyActive =
        age != null &&
        !age.isNegative &&
        age <= PortfolioSuggestionThresholds.recentActivityWindow;

    void add(PortfolioSuggestionKind kind) {
      suggestions.add(
        PortfolioSuggestion(
          kind: kind,
          action: PortfolioSuggestionAction.editProject,
          targetTitle: project.title,
          projectId: project.id,
          repositoryId: source?.repositoryId,
          updatedAt: source?.updatedAt,
          stars: source?.stars,
        ),
      );
    }

    if (!ignored && source != null) {
      if (recentlyActive) add(PortfolioSuggestionKind.recentActivity);
      if (age! >= PortfolioSuggestionThresholds.inactiveProjectAge) {
        add(PortfolioSuggestionKind.inactiveProject);
      }
    }
    if (project.description.trim().isEmpty) {
      add(PortfolioSuggestionKind.missingDescription);
    }
    if (project.liveUrl.trim().isEmpty) {
      add(PortfolioSuggestionKind.missingPreview);
    }
    final curatedComplete =
        project.description.trim().isNotEmpty &&
        project.technologies.isNotEmpty &&
        project.technologies.every((value) => value.trim().isNotEmpty);
    if (!project.featured && curatedComplete) {
      final manualCandidate =
          project.source == PortfolioProjectSource.manual &&
          project.liveUrl.trim().isNotEmpty;
      final githubCandidate =
          source != null &&
          !ignored &&
          !source.isFork &&
          !source.archived &&
          (project.repositoryUrl.trim().isNotEmpty ||
              project.liveUrl.trim().isNotEmpty) &&
          (recentlyActive ||
              source.stars >=
                  PortfolioSuggestionThresholds.featuredMinimumStars);
      if (manualCandidate || githubCandidate) {
        add(PortfolioSuggestionKind.featuredCandidate);
      }
    }
  }

  suggestions.sort((left, right) {
    final kindOrder = left.kind.index.compareTo(right.kind.index);
    return kindOrder != 0 ? kindOrder : left.id.compareTo(right.id);
  });
  return List.unmodifiable(suggestions);
}

Map<int, GitHubProjectSource> _latestSources(
  Iterable<GitHubProjectSource> sources,
) {
  final latest = <int, GitHubProjectSource>{};
  for (final source in sources) {
    if (validatePortfolioGitHubSource(source).isNotEmpty) continue;
    final previous = latest[source.repositoryId];
    if (previous == null ||
        source.updatedAt.isAfter(previous.updatedAt) ||
        (source.updatedAt == previous.updatedAt &&
            source.fingerprint.compareTo(previous.fingerprint) > 0)) {
      latest[source.repositoryId] = source;
    }
  }
  return latest;
}
