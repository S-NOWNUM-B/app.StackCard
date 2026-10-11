import 'portfolio_content.dart';

enum PortfolioPersonalizationStatus { notRequired, inProgress, completed }

final class PortfolioPersonalization {
  const PortfolioPersonalization({
    this.status = PortfolioPersonalizationStatus.notRequired,
    this.step = 0,
  });

  final PortfolioPersonalizationStatus status;
  final int step;

  @override
  bool operator ==(Object other) =>
      other is PortfolioPersonalization &&
      other.status == status &&
      other.step == step;

  @override
  int get hashCode => Object.hash(status, step);
}

/// GitHub identity отдельно от slug портфолио. null означает ошибку ввода.
String? normalizePortfolioGitHubUsername(String input) {
  var value = input.trim().toLowerCase();
  if (value.isEmpty) return '';
  if (value.contains('://')) {
    final uri = Uri.tryParse(value);
    final authority = RegExp(r'^https://([^/?#]+)').firstMatch(value)?.group(1);
    if (uri == null ||
        uri.scheme != 'https' ||
        !const {'github.com', 'www.github.com'}.contains(authority) ||
        !const {'github.com', 'www.github.com'}.contains(uri.host) ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final segments = uri.pathSegments.where((segment) => segment.isNotEmpty);
    if (segments.length != 1 || uri.path.contains('//')) return null;
    value = segments.single;
  }
  return value.length <= 39 &&
          RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value)
      ? value
      : null;
}

PortfolioDocument? mainPortfolioDocument(PortfolioContent workspace) {
  final id = workspace.mainPortfolioId;
  if (id == null) return null;
  return workspace.documents.where((document) => document.id == id).firstOrNull;
}

bool portfolioHasDisplayContent(PortfolioContent content) {
  final profile = content.profile;
  return [
        profile.name,
        profile.headline,
        profile.bio,
        profile.locationText,
        profile.avatarUrl,
        profile.avatarPath,
      ].any((value) => value.trim().isNotEmpty) ||
      content.projects.any((project) => project.visible) ||
      content.skills.isNotEmpty ||
      content.experience.isNotEmpty ||
      content.education.isNotEmpty ||
      content.links.any((link) => link.visible && link.publishAllowed);
}

/// Современные outputs не используют legacy images, layout и permissions.
PortfolioContent? resolvedMainPortfolioContent(PortfolioContent workspace) {
  final document = mainPortfolioDocument(workspace);
  if (document == null) return null;
  final resolved = resolveDocumentContent(workspace, document);
  return resolved.copyWith(
    profile: resolved.profile.copyWith(publishLocation: true),
    resumeText: '',
    blocks: const [
      PortfolioBlock(kind: PortfolioBlockKind.profile),
      PortfolioBlock(kind: PortfolioBlockKind.about),
      PortfolioBlock(kind: PortfolioBlockKind.location),
      PortfolioBlock(kind: PortfolioBlockKind.featuredProjects),
      PortfolioBlock(kind: PortfolioBlockKind.skills),
      PortfolioBlock(kind: PortfolioBlockKind.experience),
      PortfolioBlock(kind: PortfolioBlockKind.education),
      PortfolioBlock(kind: PortfolioBlockKind.links),
      PortfolioBlock(kind: PortfolioBlockKind.github),
      PortfolioBlock(kind: PortfolioBlockKind.resume, visible: false),
    ],
    projects: resolved.projects
        .where((project) => project.visible)
        .map((project) => project.copyWith(imagePaths: const []))
        .toList(),
    links: resolved.links
        .where((link) => link.visible && link.publishAllowed)
        .toList(),
  );
}

/// Прежняя приватность применяется до создания современного содержимого.
PortfolioContent mainPortfolioMigrationContent(
  PortfolioContent workspace,
  PortfolioContent source,
) {
  bool visible(PortfolioBlockKind kind) =>
      source.blocks.any((block) => block.kind == kind && block.visible);
  final profileVisible = visible(PortfolioBlockKind.profile);
  final allowedLinks = workspace.links
      .where((link) => link.visible && link.publishAllowed)
      .map((link) => link.id)
      .toSet();
  return PortfolioContent(
    profile: source.profile.copyWith(
      name: profileVisible ? source.profile.name : '',
      username: profileVisible ? source.profile.username : '',
      headline: profileVisible ? source.profile.headline : '',
      avatarUrl: profileVisible ? source.profile.avatarUrl : '',
      avatarPath: profileVisible ? source.profile.avatarPath : '',
      bio: visible(PortfolioBlockKind.about) ? source.profile.bio : '',
      locationText:
          visible(PortfolioBlockKind.location) &&
              workspace.profile.publishLocation &&
              source.profile.publishLocation
          ? source.profile.locationText
          : '',
      publishLocation: true,
    ),
    skills: visible(PortfolioBlockKind.skills) ? source.skills : const [],
    experience: visible(PortfolioBlockKind.experience)
        ? source.experience
        : const [],
    education: visible(PortfolioBlockKind.education)
        ? source.education
        : const [],
    links: source.links
        .where(
          (link) =>
              allowedLinks.contains(link.id) &&
              link.publishAllowed &&
              link.visible &&
              visible(
                link.kind == SocialLinkKind.github
                    ? PortfolioBlockKind.github
                    : PortfolioBlockKind.links,
              ),
        )
        .toList(),
    // Legacy plain text сохраняется посимвольно, без попытки вывести из него факты.
    resumeText: source.resumeText,
  );
}
