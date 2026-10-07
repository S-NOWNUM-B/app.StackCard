import '../../portfolio_draft/portfolio_draft.dart';
import '../domain/project.dart';

/// Projects показывает и скрытые записи, чтобы владелец мог их редактировать.
List<Project> projectPortfolioProjects(PortfolioContent content) =>
    List.unmodifiable([
      for (final (index, project) in content.projects.indexed)
        Project(
          id: project.id,
          title: project.title,
          description: project.description,
          technologies: project.technologies,
          symbol: '${index + 1}'.padLeft(2, '0'),
          category: 'Portfolio',
          source: project.source == PortfolioProjectSource.github
              ? ProjectSource.github
              : ProjectSource.manual,
          featured: project.featured,
          visible: project.visible,
          imagePaths: project.imagePaths,
          details: [
            project.description,
            project.repositoryUrl,
            project.liveUrl,
          ].where((value) => value.isNotEmpty).join('\n\n'),
        ),
    ]);
