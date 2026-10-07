import 'portfolio_collection_equality.dart';
import 'portfolio_github_sync.dart';

enum PortfolioProjectSource { manual, github }

final class PortfolioProject {
  PortfolioProject({
    required this.id,
    required this.title,
    required this.description,
    required List<String> technologies,
    this.repositoryUrl = '',
    this.liveUrl = '',
    this.featured = false,
    this.visible = true,
    this.source = PortfolioProjectSource.manual,
    this.githubMetadata,
    List<String> imagePaths = const [],
  }) : technologies = List.unmodifiable(technologies),
       imagePaths = List.unmodifiable(imagePaths);

  final String id;
  final String title;
  final String description;
  final List<String> technologies;
  final String repositoryUrl;
  final String liveUrl;
  final bool featured;
  final bool visible;
  final PortfolioProjectSource source;
  final GitHubProjectMetadata? githubMetadata;
  final List<String> imagePaths;

  int? get githubRepositoryId => githubMetadata?.acceptedSource.repositoryId;
  DateTime? get lastGitHubSyncAt => githubMetadata?.lastGitHubSyncAt;

  PortfolioProject copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? technologies,
    String? repositoryUrl,
    String? liveUrl,
    bool? featured,
    bool? visible,
    PortfolioProjectSource? source,
    GitHubProjectMetadata? githubMetadata,
    List<String>? imagePaths,
  }) => PortfolioProject(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    technologies: technologies ?? this.technologies,
    repositoryUrl: repositoryUrl ?? this.repositoryUrl,
    liveUrl: liveUrl ?? this.liveUrl,
    featured: featured ?? this.featured,
    visible: visible ?? this.visible,
    source: source ?? this.source,
    githubMetadata: githubMetadata ?? this.githubMetadata,
    imagePaths: imagePaths ?? this.imagePaths,
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
      technologies: edited.technologies,
      repositoryUrl: edited.repositoryUrl,
      liveUrl: edited.liveUrl,
      featured: edited.featured,
      visible: edited.visible,
      source: source,
      githubMetadata: metadata?.copyWith(overrideFields: overrides),
      imagePaths: imagePaths,
    );
  }

  Object get _fields => (
    id,
    title,
    description,
    repositoryUrl,
    liveUrl,
    featured,
    visible,
    source,
    githubMetadata,
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
