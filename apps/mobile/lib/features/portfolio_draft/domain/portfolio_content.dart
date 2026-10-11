import 'portfolio_collection_equality.dart';
import 'portfolio_profile.dart';
import 'portfolio_project.dart';
import 'portfolio_sections.dart';
import 'portfolio_github_sync.dart';
import 'portfolio_document.dart';
import 'main_portfolio.dart';

export 'portfolio_profile.dart';
export 'portfolio_project.dart';
export 'portfolio_sections.dart';
export 'portfolio_document.dart';
export 'main_portfolio.dart';

/// Редактируемый контент портфолио; private notes остаются в PortfolioDraft.
final class PortfolioContent {
  PortfolioContent({
    this.profile = const PortfolioProfile(),
    List<Skill> skills = const [],
    List<PortfolioProject> projects = const [],
    List<Experience> experience = const [],
    List<Education> education = const [],
    List<SocialLink> links = const [],
    this.resumeText = '',
    List<PortfolioBlock>? blocks,
    List<GitHubIgnoredRepository> ignoredGitHubRepositories = const [],
    List<PortfolioDocument> documents = const [],
    this.theme = PortfolioTheme.light,
    this.mainPortfolioId,
    this.githubUsername = '',
    this.personalization = const PortfolioPersonalization(),
    this.legacyMainSnapshot,
  }) : skills = List.unmodifiable(skills),
       projects = List.unmodifiable(projects),
       experience = List.unmodifiable(experience),
       education = List.unmodifiable(education),
       links = List.unmodifiable(links),
       ignoredGitHubRepositories = List.unmodifiable(ignoredGitHubRepositories),
       documents = List.unmodifiable(documents),
       blocks = List.unmodifiable(
         blocks ??
             PortfolioBlockKind.values.map(
               (kind) => PortfolioBlock(kind: kind),
             ),
       );

  final PortfolioProfile profile;
  final List<Skill> skills;
  final List<PortfolioProject> projects;
  final List<Experience> experience;
  final List<Education> education;
  final List<SocialLink> links;
  final List<PortfolioBlock> blocks;
  final String resumeText;
  final PortfolioTheme theme;
  final List<GitHubIgnoredRepository> ignoredGitHubRepositories;
  final List<PortfolioDocument> documents;
  final String? mainPortfolioId;
  final String githubUsername;
  final PortfolioPersonalization personalization;
  final PortfolioDocument? legacyMainSnapshot;

  PortfolioContent copyWith({
    PortfolioProfile? profile,
    List<Skill>? skills,
    List<PortfolioProject>? projects,
    List<Experience>? experience,
    List<Education>? education,
    List<SocialLink>? links,
    List<PortfolioBlock>? blocks,
    String? resumeText,
    PortfolioTheme? theme,
    List<GitHubIgnoredRepository>? ignoredGitHubRepositories,
    List<PortfolioDocument>? documents,
    String? mainPortfolioId,
    bool clearMainPortfolioId = false,
    String? githubUsername,
    PortfolioPersonalization? personalization,
    PortfolioDocument? legacyMainSnapshot,
    bool clearLegacyMainSnapshot = false,
  }) => PortfolioContent(
    profile: profile ?? this.profile,
    skills: skills ?? this.skills,
    projects: projects ?? this.projects,
    experience: experience ?? this.experience,
    education: education ?? this.education,
    links: links ?? this.links,
    blocks: blocks ?? this.blocks,
    resumeText: resumeText ?? this.resumeText,
    theme: theme ?? this.theme,
    ignoredGitHubRepositories:
        ignoredGitHubRepositories ?? this.ignoredGitHubRepositories,
    documents: documents ?? this.documents,
    mainPortfolioId: clearMainPortfolioId
        ? null
        : mainPortfolioId ?? this.mainPortfolioId,
    githubUsername: githubUsername ?? this.githubUsername,
    personalization: personalization ?? this.personalization,
    legacyMainSnapshot: clearLegacyMainSnapshot
        ? null
        : legacyMainSnapshot ?? this.legacyMainSnapshot,
  );

  @override
  bool operator ==(Object other) =>
      other is PortfolioContent &&
      other.profile == profile &&
      other.resumeText == resumeText &&
      other.theme == theme &&
      other.mainPortfolioId == mainPortfolioId &&
      other.githubUsername == githubUsername &&
      other.personalization == personalization &&
      other.legacyMainSnapshot == legacyMainSnapshot &&
      portfolioListEquals(other.skills, skills) &&
      portfolioListEquals(other.projects, projects) &&
      portfolioListEquals(other.experience, experience) &&
      portfolioListEquals(other.education, education) &&
      portfolioListEquals(other.documents, documents) &&
      portfolioListEquals(other.links, links) &&
      portfolioListEquals(
        other.ignoredGitHubRepositories,
        ignoredGitHubRepositories,
      ) &&
      portfolioListEquals(other.blocks, blocks);

  @override
  int get hashCode => Object.hash(
    profile,
    resumeText,
    theme,
    mainPortfolioId,
    githubUsername,
    personalization,
    legacyMainSnapshot,
    Object.hashAll(skills),
    Object.hashAll(projects),
    Object.hashAll(experience),
    Object.hashAll(education),
    Object.hashAll(documents),
    Object.hashAll(links),
    Object.hashAll(ignoredGitHubRepositories),
    Object.hashAll(blocks),
  );
}

/// Поля общей базы человека без legacy оформления и содержимого документов.
PortfolioContent developerProfileData(PortfolioContent workspace) =>
    PortfolioContent(
      profile: workspace.profile,
      skills: workspace.skills,
      experience: workspace.experience,
      education: workspace.education,
      links: workspace.links,
    );
