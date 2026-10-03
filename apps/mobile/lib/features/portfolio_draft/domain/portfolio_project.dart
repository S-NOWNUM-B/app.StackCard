import 'portfolio_collection_equality.dart';

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
  }) : technologies = List.unmodifiable(technologies);

  final String id;
  final String title;
  final String description;
  final List<String> technologies;
  final String repositoryUrl;
  final String liveUrl;
  final bool featured;
  final bool visible;

  PortfolioProject copyWith({
    String? id,
    String? title,
    String? description,
    List<String>? technologies,
    String? repositoryUrl,
    String? liveUrl,
    bool? featured,
    bool? visible,
  }) => PortfolioProject(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    technologies: technologies ?? this.technologies,
    repositoryUrl: repositoryUrl ?? this.repositoryUrl,
    liveUrl: liveUrl ?? this.liveUrl,
    featured: featured ?? this.featured,
    visible: visible ?? this.visible,
  );

  Object get _fields =>
      (id, title, description, repositoryUrl, liveUrl, featured, visible);

  @override
  bool operator ==(Object other) =>
      other is PortfolioProject &&
      other._fields == _fields &&
      portfolioListEquals(other.technologies, technologies);

  @override
  int get hashCode => Object.hash(_fields, Object.hashAll(technologies));
}
