import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';

/// Синтетические данные в рамках текущих контрактов, без пользовательских данных.
PortfolioContent performanceWorkspace() {
  final date = DateTime.utc(2026, 10, 21);
  final content = PortfolioContent(
    profile: PortfolioProfile(
      name: 'Анна Ёлкина',
      headline: 'Разработчик приложений',
      bio: List.filled(40, 'Описание работы и опыта разработки. ').join(),
      locationText: 'Алматы, Казахстан',
      publishLocation: true,
    ),
    skills: List.generate(200, (i) => Skill(id: 'skill-$i', name: 'Навык $i')),
    experience: List.generate(
      30,
      (i) => Experience(
        id: 'experience-$i',
        role: 'Разработчик $i',
        organization: 'Команда $i',
        period: '2024–2026',
        description: List.filled(
          10,
          'Разработка и поддержка продукта. ',
        ).join(),
      ),
    ),
    education: List.generate(
      20,
      (i) => Education(
        id: 'education-$i',
        institution: 'Университет $i',
        qualification: 'Программная инженерия',
        period: '2020–2024',
        description: '',
      ),
    ),
    links: List.generate(
      10,
      (i) => SocialLink(
        id: 'link-$i',
        label: 'Сайт $i',
        url: 'https://example.com/contact/$i',
        publishAllowed: true,
      ),
    ),
  );
  final main = PortfolioDocument(
    id: 'performance-main',
    title: 'Основное портфолио',
    kind: PortfolioDocumentKind.portfolio,
    createdAt: date,
    updatedAt: date,
    content: content.copyWith(blocks: mainPortfolioBlocks(content)),
    projects: List.generate(
      200,
      (i) => PortfolioProjectAttachment(projectId: 'project-$i'),
    ),
  );
  return content.copyWith(
    mainPortfolioId: main.id,
    projects: List.generate(
      200,
      (i) => PortfolioProject(
        id: 'project-$i',
        title: 'Проект $i',
        description: List.filled(
          8,
          'Описание проекта и выполненной работы. ',
        ).join(),
        technologies: List.generate(20, (j) => 'Технология $j'),
        repositoryUrl: 'https://github.com/example/project-$i',
        liveUrl: 'https://example.com/project/$i',
      ),
    ),
    documents: [
      main,
      for (var i = 0; i < portfolioDocumentLimit - 1; i++)
        PortfolioDocument(
          id: 'legacy-$i',
          title: 'LEGACY_PRIVATE_$i',
          kind: PortfolioDocumentKind.resume,
          createdAt: date,
          updatedAt: date,
          content: PortfolioContent(
            profile: PortfolioProfile(name: 'LEGACY_PRIVATE_$i'),
          ),
        ),
    ],
  );
}
