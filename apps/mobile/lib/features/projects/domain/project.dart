enum ProjectSource { manual, github }

/// Проект портфолио; происхождение не зависит от подписи в интерфейсе.
final class Project {
  Project({
    required this.title,
    required this.description,
    required List<String> technologies,
    required this.symbol,
    required this.category,
    required this.source,
    required this.featured,
    required this.details,
    this.id,
    this.visible = true,
    List<String> imagePaths = const [],
  }) : technologies = List.unmodifiable(technologies),
       imagePaths = List.unmodifiable(imagePaths);

  final String title;
  final String description;
  final List<String> technologies;
  final String symbol;
  final String category;
  final ProjectSource source;
  final bool featured;
  final String details;
  final String? id;
  final bool visible;
  final List<String> imagePaths;

  bool get isFromGitHub => source == ProjectSource.github;
}
