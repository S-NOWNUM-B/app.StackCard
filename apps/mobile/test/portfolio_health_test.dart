import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_health.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 11, 16, 12);

PortfolioProject _project({
  String id = 'p1',
  String description = 'Описание',
  List<String> technologies = const ['Dart'],
  String liveUrl = 'https://example.com',
  String repositoryUrl = '',
  bool visible = true,
}) => PortfolioProject(
  id: id,
  title: 'Проект $id',
  description: description,
  technologies: technologies,
  liveUrl: liveUrl,
  repositoryUrl: repositoryUrl,
  visible: visible,
);

PortfolioContent _complete() => PortfolioContent(
  profile: const PortfolioProfile(
    name: 'Имя',
    headline: 'Разработчик',
    bio: 'О себе',
    avatarPath: 'accounts/u/media/a.jpg',
  ),
  skills: const [Skill(id: 's1', name: 'Dart')],
  projects: [_project()],
  experience: const [
    Experience(
      id: 'e1',
      role: 'Dev',
      organization: 'Org',
      period: '2024',
      description: '',
    ),
  ],
  education: const [
    Education(
      id: 'd1',
      institution: 'Uni',
      qualification: 'BSc',
      period: '2020',
      description: '',
    ),
  ],
  links: const [
    SocialLink(
      id: 'l1',
      label: 'GitHub',
      url: 'https://github.com/example',
      kind: SocialLinkKind.github,
      publishAllowed: true,
    ),
  ],
);

PortfolioHealth _health(PortfolioContent content, {bool? published}) =>
    buildPortfolioHealth(content: content, now: _now, published: published);

Set<PortfolioHealthCheckKind> _improve(PortfolioHealth health) =>
    health.improvements.map((check) => check.kind).toSet();

void main() {
  test('Empty portfolio scores low with a tip for every section', () {
    final health = _health(PortfolioContent());
    expect(health.score, 0);
    expect(health.isPerfect, isFalse);
    expect(
      _improve(health),
      containsAll([
        PortfolioHealthCheckKind.profileName,
        PortfolioHealthCheckKind.avatar,
        PortfolioHealthCheckKind.projectsAny,
        PortfolioHealthCheckKind.experienceAny,
        PortfolioHealthCheckKind.educationAny,
        PortfolioHealthCheckKind.skillsAny,
        PortfolioHealthCheckKind.contactsAny,
      ]),
    );
  });

  test('Complete portfolio without publication data scores 100', () {
    final health = _health(_complete());
    expect(health.score, 100);
    expect(health.isPerfect, isTrue);
    expect(health.forSection(PortfolioHealthSection.publication), isEmpty);
  });

  test(
    'Unknown publication is ignored, known unpublished lowers the score',
    () {
      final unpublished = _health(_complete(), published: false);
      expect(unpublished.score, lessThan(100));
      expect(_improve(unpublished), {PortfolioHealthCheckKind.published});
      expect(_health(_complete(), published: true).score, 100);
    },
  );

  test(
    'Project gaps produce per-project tips; hidden projects are ignored',
    () {
      final content = _complete().copyWith(
        projects: [
          _project(description: '  ', technologies: const [], liveUrl: ''),
          _project(id: 'hidden', description: '', visible: false),
        ],
      );
      final health = _health(content);
      final tips = health.improvements
          .where((check) => check.section == PortfolioHealthSection.projects)
          .toList();
      expect(tips.map((check) => check.kind), {
        PortfolioHealthCheckKind.projectDescription,
        PortfolioHealthCheckKind.projectTechnologies,
        PortfolioHealthCheckKind.projectLink,
      });
      expect(tips.every((check) => check.targetId == 'p1'), isTrue);
    },
  );

  test('Repository URL alone counts as a project link', () {
    final content = _complete().copyWith(
      projects: [
        _project(liveUrl: '', repositoryUrl: 'https://github.com/a/b'),
      ],
    );
    expect(_improve(_health(content)), isEmpty);
  });

  test('A skill not used by any project is flagged case-insensitively', () {
    final content = _complete().copyWith(
      skills: const [
        Skill(id: 's1', name: ' dart '),
        Skill(id: 's2', name: 'Rust'),
      ],
    );
    final tips = _health(content).improvements.toList();
    expect(tips.single.kind, PortfolioHealthCheckKind.skillUnused);
    expect(tips.single.targetId, 's2');
  });

  test(
    'Skills are not matched against projects when there are no projects',
    () {
      final content = _complete().copyWith(projects: const []);
      final kinds = _improve(_health(content));
      expect(kinds, contains(PortfolioHealthCheckKind.projectsAny));
      expect(kinds, isNot(contains(PortfolioHealthCheckKind.skillUnused)));
    },
  );

  test('Hidden or non-publishable contacts do not count', () {
    final content = _complete().copyWith(
      links: const [
        SocialLink(
          id: 'l1',
          label: 'Mail',
          url: 'mailto:a@b.co',
          kind: SocialLinkKind.email,
          publishAllowed: true,
          visible: false,
        ),
      ],
    );
    expect(_improve(_health(content)), {PortfolioHealthCheckKind.contactsAny});
  });

  test(
    'Improvements are ordered by section weight; score stays within 0..100',
    () {
      final health = _health(PortfolioContent(), published: false);
      final weights = health.improvements
          .map((check) => check.section.weight)
          .toList();
      expect([...weights]..sort((a, b) => b.compareTo(a)), weights);
      expect(health.score, inInclusiveRange(0, 100));
    },
  );

  test('Evaluation does not mutate content and is deterministic', () {
    final content = _complete();
    final first = _health(content, published: true);
    final second = _health(content, published: true);
    expect(first.checks, second.checks);
    expect(content, _complete());
  });
}
