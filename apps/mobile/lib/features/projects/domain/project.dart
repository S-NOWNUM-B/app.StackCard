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
  }) : technologies = List.unmodifiable(technologies);

  final String title;
  final String description;
  final List<String> technologies;
  final String symbol;
  final String category;
  final ProjectSource source;
  final bool featured;
  final String details;

  bool get isFromGitHub => source == ProjectSource.github;
}
