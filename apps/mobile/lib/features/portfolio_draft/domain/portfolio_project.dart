import 'portfolio_collection_equality.dart';
import 'portfolio_github_sync.dart';

enum PortfolioProjectSource { manual, github }

final class PortfolioProject {
  PortfolioProject({
    required this.id,
    required this.title,
    required this.description,
    required List<String> technologies,
    this.contribution = '',
    this.repositoryUrl = '',
    this.liveUrl = '',
    this.featured = false,
    this.visible = true,
    this.source = PortfolioProjectSource.manual,
    this.githubMetadata,
    this.updatedAt,
    List<String> imagePaths = const [],
  }) : technologies = List.unmodifiable(technologies),
       imagePaths = List.unmodifiable(imagePaths);

  final String id;
  final String title;
  final String description;
  final String contribution;
  final List<String> technologies;
  final String repositoryUrl;
  final String liveUrl;
  final bool featured;
  final bool visible;
  final PortfolioProjectSource source;
  final GitHubProjectMetadata? githubMetadata;
  final List<String> imagePaths;
  final DateTime? updatedAt;

  int? get githubRepositoryId => githubMetadata?.acceptedSource.repositoryId;
  DateTime? get lastGitHubSyncAt => githubMetadata?.lastGitHubSyncAt;

  PortfolioProject copyWith({
    String? id,
    String? title,
    String? description,
    String? contribution,
    List<String>? technologies,
    String? repositoryUrl,
    String? liveUrl,
    bool? featured,
    bool? visible,
    PortfolioProjectSource? source,
    GitHubProjectMetadata? githubMetadata,
    List<String>? imagePaths,
    DateTime? updatedAt,
  }) => PortfolioProject(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    contribution: contribution ?? this.contribution,
    technologies: technologies ?? this.technologies,
    repositoryUrl: repositoryUrl ?? this.repositoryUrl,
    liveUrl: liveUrl ?? this.liveUrl,
    featured: featured ?? this.featured,
    visible: visible ?? this.visible,
    source: source ?? this.source,
    githubMetadata: githubMetadata ?? this.githubMetadata,
    imagePaths: imagePaths ?? this.imagePaths,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Track changed source-backed fields, while retaining the accepted snapshot.
  PortfolioProject withUserEdits(PortfolioProject edited) {
    if (edited.id != id) {
      throw const PortfolioGitHubFailure(PortfolioGitHubFailureKind.conflict);
    }
    final metadata = githubMetadata;
    final overrides = {...?metadata?.overrideFields};
    if (source == PortfolioProjectSource.github) {
      if (metadata == null) {
        throw const PortfolioGitHubFailure(
          PortfolioGitHubFailureKind.invalidContent,
        );
      }
      if (edited.title != title) overrides.add(PortfolioGitHubField.title);
      if (edited.description != description) {
        overrides.add(PortfolioGitHubField.description);
      }
      if (!portfolioListEquals(edited.technologies, technologies)) {
        overrides.add(PortfolioGitHubField.technologies);
      }
      if (edited.repositoryUrl != repositoryUrl) {
        overrides.add(PortfolioGitHubField.repositoryUrl);
      }
    }
    return PortfolioProject(
      id: id,
      title: edited.title,
      description: edited.description,
      contribution: edited.contribution,
      technologies: edited.technologies,
      repositoryUrl: edited.repositoryUrl,
      liveUrl: edited.liveUrl,
      featured: edited.featured,
      visible: edited.visible,
      source: source,
      githubMetadata: metadata?.copyWith(overrideFields: overrides),
      imagePaths: imagePaths,
      updatedAt: edited.updatedAt ?? updatedAt,
    );
  }

  Object get _fields => (
    id,
    title,
    description,
    contribution,
    repositoryUrl,
    liveUrl,
    featured,
    visible,
    source,
    githubMetadata,
    updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is PortfolioProject &&
      other._fields == _fields &&
      portfolioListEquals(other.technologies, technologies) &&
      portfolioListEquals(other.imagePaths, imagePaths);

  @override
  int get hashCode => Object.hash(
    _fields,
    Object.hashAll(technologies),
    Object.hashAll(imagePaths),
  );
}
