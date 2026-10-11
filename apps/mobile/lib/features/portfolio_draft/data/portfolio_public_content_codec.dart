import '../domain/portfolio_content.dart';
import 'portfolio_content_codec.dart';

/// Hidden blocks are removed from the stored payload, not only from rendering.
PortfolioContent projectPublicPortfolioContent(PortfolioContent content) {
  if (content.mainPortfolioId != null) {
    return resolvedMainPortfolioContent(content) ?? PortfolioContent();
  }
  final visible = content.blocks
      .where((block) => block.visible)
      .map((block) => block.kind)
      .toSet();
  bool includes(PortfolioBlockKind kind) => visible.contains(kind);
  final profileVisible = includes(PortfolioBlockKind.profile);
  final profile = content.profile;
  return content.copyWith(
    profile: PortfolioProfile(
      name: profileVisible ? profile.name : '',
      username: profileVisible ? profile.username : '',
      headline: profileVisible ? profile.headline : '',
      avatarUrl: profileVisible ? profile.avatarUrl : '',
      bio: includes(PortfolioBlockKind.about) ? profile.bio : '',
      locationText:
          includes(PortfolioBlockKind.location) && profile.publishLocation
          ? profile.locationText
          : '',
      publishLocation: profile.publishLocation,
    ),
    skills: includes(PortfolioBlockKind.skills) ? content.skills : const [],
    projects: includes(PortfolioBlockKind.featuredProjects)
        ? content.projects
              .where((project) => project.visible && project.featured)
              .map(
                (project) => PortfolioProject(
                  id: project.id,
                  title: project.title,
                  description: project.description,
                  contribution: project.contribution,
                  technologies: project.technologies,
                  repositoryUrl: project.repositoryUrl,
                  liveUrl: project.liveUrl,
                  featured: project.featured,
                  visible: project.visible,
                  iconId: project.iconId,
                ),
              )
              .toList()
        : const [],
    experience: includes(PortfolioBlockKind.experience)
        ? content.experience
        : const [],
    education: includes(PortfolioBlockKind.education)
        ? content.education
        : const [],
    links: content.links.where((link) {
      if (!link.publishAllowed || !link.visible) return false;
      return includes(
        link.kind == SocialLinkKind.github
            ? PortfolioBlockKind.github
            : PortfolioBlockKind.links,
      );
    }).toList(),
    resumeText: includes(PortfolioBlockKind.resume) ? content.resumeText : '',
    ignoredGitHubRepositories: const [],
    documents: const [],
    clearMainPortfolioId: true,
    githubUsername: '',
    personalization: const PortfolioPersonalization(),
    clearLegacyMainSnapshot: true,
  );
}

Map<String, Object?> encodePublicPortfolioContent(PortfolioContent content) {
  final encoded = encodePortfolioContent(
    projectPublicPortfolioContent(content),
    includeDocuments: false,
  );
  encoded.remove('ignoredGitHubRepositories');
  (encoded['profile']! as Map).remove('avatarPath');
  (encoded['profile']! as Map).remove('publishLocation');
  for (final link in encoded['links']! as List) {
    (link as Map).remove('publishAllowed');
    link.remove('visible');
  }
  const projectFields = {
    'id',
    'title',
    'description',
    'contribution',
    'technologies',
    'repositoryUrl',
    'liveUrl',
    'featured',
    'visible',
    'iconId',
  };
  for (final project in encoded['projects']! as List) {
    (project as Map).removeWhere((key, _) => !projectFields.contains(key));
  }
  return encoded;
}
