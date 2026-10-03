import 'portfolio_collection_equality.dart';
import 'portfolio_profile.dart';
import 'portfolio_project.dart';
import 'portfolio_sections.dart';

export 'portfolio_profile.dart';
export 'portfolio_project.dart';
export 'portfolio_sections.dart';

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
    this.theme = PortfolioTheme.dark,
  }) : skills = List.unmodifiable(skills),
       projects = List.unmodifiable(projects),
       experience = List.unmodifiable(experience),
       education = List.unmodifiable(education),
       links = List.unmodifiable(links),
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
  );

  @override
  bool operator ==(Object other) =>
      other is PortfolioContent &&
      other.profile == profile &&
      other.resumeText == resumeText &&
      other.theme == theme &&
      portfolioListEquals(other.skills, skills) &&
      portfolioListEquals(other.projects, projects) &&
      portfolioListEquals(other.experience, experience) &&
      portfolioListEquals(other.education, education) &&
      portfolioListEquals(other.links, links) &&
      portfolioListEquals(other.blocks, blocks);

  @override
  int get hashCode => Object.hash(
    profile,
    resumeText,
    theme,
    Object.hashAll(skills),
    Object.hashAll(projects),
    Object.hashAll(experience),
    Object.hashAll(education),
    Object.hashAll(links),
    Object.hashAll(blocks),
  );
}
