import 'portfolio_content.dart';
import 'portfolio_validation.dart';

enum PortfolioCompletionStep { profile, about, skills, projects, links }

final class PortfolioCompletion {
  PortfolioCompletion({required List<PortfolioCompletionStep> missingSteps})
    : missingSteps = List.unmodifiable(missingSteps);

  final List<PortfolioCompletionStep> missingSteps;
  int get totalSteps => PortfolioCompletionStep.values.length;
  int get completedSteps => totalSteps - missingSteps.length;
  double get fraction => completedSteps / totalSteps;
  int get percent => (fraction * 100).round();
}

/// Видимость блоков не подменяет заполнение данных; optional секции не обязательны.
PortfolioCompletion calculatePortfolioCompletion(PortfolioContent content) {
  final profile = content.profile;
  final profileComplete =
      profile.name.trim().isNotEmpty &&
      profile.username.isNotEmpty &&
      profile.headline.trim().isNotEmpty &&
      validatePortfolioContent(PortfolioContent(profile: profile)).isEmpty;
  final aboutComplete =
      profile.bio.trim().isNotEmpty &&
      validatePortfolioText(profile.bio, maxLength: 4000) == null;
  final skillsComplete =
      content.skills.isNotEmpty &&
      validatePortfolioContent(PortfolioContent(skills: content.skills))
          .isEmpty;
  final projectsComplete =
      content.projects.any((project) => project.visible) &&
      validatePortfolioContent(PortfolioContent(projects: content.projects))
          .isEmpty;
  final linksComplete =
      content.links.isNotEmpty &&
      validatePortfolioContent(PortfolioContent(links: content.links)).isEmpty;
  return PortfolioCompletion(
    missingSteps: [
      if (!profileComplete) PortfolioCompletionStep.profile,
      if (!aboutComplete) PortfolioCompletionStep.about,
      if (!skillsComplete) PortfolioCompletionStep.skills,
      if (!projectsComplete) PortfolioCompletionStep.projects,
      if (!linksComplete) PortfolioCompletionStep.links,
    ],
  );
}
