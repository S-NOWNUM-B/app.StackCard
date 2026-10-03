import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/profile.dart';
import '../../projects/projects.dart';

class PortfolioOverview {
  PortfolioOverview({required this.profile, required List<Project> projects})
    : projects = List.unmodifiable(projects),
      featuredProjects = selectFeaturedProjects(projects);

  final Profile profile;
  final List<Project> projects;
  final List<Project> featuredProjects;

  Project? get highlightedProject =>
      featuredProjects.isEmpty ? null : featuredProjects.first;

  String get projectsLabel =>
      _countLabel(projects.length, 'проект', 'проекта', 'проектов');
  String get skillsLabel =>
      _countLabel(profile.skills.length, 'навык', 'навыка', 'навыков');
}

String _countLabel(int count, String one, String few, String many) {
  final lastTwo = count % 100;
  final word = lastTwo >= 11 && lastTwo <= 14
      ? many
      : switch (count % 10) {
          1 => one,
          2 || 3 || 4 => few,
          _ => many,
        };
  return '$count $word';
}

final portfolioOverviewProvider = Provider<AsyncValue<PortfolioOverview>>((
  ref,
) {
  final profile = ref.watch(profileProvider);
  final projects = ref.watch(projectsProvider);
  if (profile.hasError && !profile.isLoading) {
    return AsyncError(profile.error!, profile.stackTrace!);
  }
  if (projects.hasError && !projects.isLoading) {
    return AsyncError(projects.error!, projects.stackTrace!);
  }
  if (profile.isLoading || projects.isLoading) {
    return const AsyncLoading();
  }
  return AsyncData(
    PortfolioOverview(
      profile: profile.requireValue,
      projects: projects.requireValue,
    ),
  );
});
