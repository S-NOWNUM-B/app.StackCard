import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_completion.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Content owns collections and compares edits structurally', () {
    final skills = [const Skill(id: 'skill', name: 'Dart')];
    final technologies = ['Dart'];
    final project = PortfolioProject(
      id: 'project',
      title: 'Local project',
      description: '',
      technologies: technologies,
    );
    final content = PortfolioContent(skills: skills, projects: [project]);
    skills.clear();
    technologies.add('Changed elsewhere');
    expect(content.skills.single.name, 'Dart');
    expect(content.projects.single.technologies, ['Dart']);
    expect(() => content.skills.clear(), throwsUnsupportedError);
    expect(() => content.blocks.clear(), throwsUnsupportedError);
    expect(() => project.technologies.clear(), throwsUnsupportedError);
    final same = PortfolioContent(
      skills: [const Skill(id: 'skill', name: 'Dart')],
      projects: [
        PortfolioProject(
          id: 'project',
          title: 'Local project',
          description: '',
          technologies: ['Dart'],
        ),
      ],
    );
    expect(content, same);
    expect(content.hashCode, same.hashCode);
    expect(
      content.copyWith(projects: [project.copyWith(featured: true)]),
      isNot(content),
    );
    expect(
      content.copyWith(blocks: content.blocks.reversed.toList()),
      isNot(content),
    );
    expect(content.copyWith(resumeText: 'Line one\nLine two'), isNot(content));
  });

  test('Defaults contain one visible block of every supported kind', () {
    final content = PortfolioContent();
    expect(content.profile, const PortfolioProfile());
    expect(
      content.blocks.map((block) => block.kind),
      PortfolioBlockKind.values,
    );
    expect(content.blocks.every((block) => block.visible), isTrue);
    expect(content.theme, PortfolioTheme.dark);
    expect(validatePortfolioContent(content), isEmpty);
  });

  test(
    'Optional text stays blank while required entries reject whitespace',
    () {
      expect(validatePortfolioText(''), isNull);
      expect(
        validatePortfolioText(' \n', required: true),
        PortfolioValidationCode.required,
      );
      expect(validatePortfolioText('x' * 100, maxLength: 100), isNull);
      expect(
        validatePortfolioText('x' * 101, maxLength: 100),
        PortfolioValidationCode.tooLong,
      );
    },
  );

  test('Username is optional and uses the agreed local syntax', () {
    for (final username in ['', 'abc', 'a-b', 'x' * 30, 'a--b']) {
      expect(validatePortfolioUsername(username), isNull, reason: username);
    }
    for (final username in [
      'ab',
      'x' * 31,
      'Uppercase',
      '-abc',
      'abc-',
      'a_b',
      ' abc',
      'имя',
    ]) {
      expect(
        validatePortfolioUsername(username),
        PortfolioValidationCode.invalidUsername,
        reason: username,
      );
    }
  });

  test(
    'URL admits optional empty and absolute web URLs without credentials',
    () {
      for (final url in [
        '',
        'https://example.com/path?q=a#section',
        'https://example.com/?email=a@b.com',
        'http://localhost:8080',
        'https://[::1]/',
      ]) {
        expect(validatePortfolioUrl(url), isNull, reason: url);
      }
      for (final url in [
        'example.com',
        '/relative',
        'mailto:a@example.com',
        'javascript:alert(1)',
        'https://',
        'https://user:pass@example.com',
        'https://@example.com',
        ' https://example.com',
        'https://example.com/a b',
      ]) {
        expect(
          validatePortfolioUrl(url),
          PortfolioValidationCode.invalidUrl,
          reason: url,
        );
      }
      expect(
        validatePortfolioUrl('https://example.com/${'x' * 2048}'),
        PortfolioValidationCode.tooLong,
      );
    },
  );

  test('Collection validation matches required editor fields', () {
    final invalid = PortfolioContent(
      skills: [const Skill(id: '', name: ' ')],
      projects: [
        PortfolioProject(id: 'p', title: '', description: '', technologies: []),
      ],
      experience: [
        const Experience(
          id: 'e',
          role: '',
          organization: '',
          period: '',
          description: '',
        ),
      ],
      education: [
        const Education(
          id: 'ed',
          institution: '',
          qualification: '',
          period: '',
          description: '',
        ),
      ],
      links: [const SocialLink(id: 'l', label: '', url: '')],
    );
    expect(
      validatePortfolioContent(invalid),
      contains(PortfolioValidationCode.required),
    );
    final valid = _complete().copyWith(
      experience: [
        const Experience(
          id: 'e',
          role: 'Engineer',
          organization: 'Studio',
          period: '',
          description: '',
        ),
      ],
      education: [
        const Education(
          id: 'ed',
          institution: 'University',
          qualification: 'Software engineering',
          period: '',
          description: '',
        ),
      ],
    );
    expect(validatePortfolioContent(valid), isEmpty);
  });

  test('ID duplicates and incomplete block structure cannot be persisted', () {
    final duplicate = PortfolioContent(
      skills: [
        const Skill(id: 'same', name: 'Dart'),
        const Skill(id: 'same', name: 'Flutter'),
      ],
    );
    expect(
      validatePortfolioContent(duplicate),
      contains(PortfolioValidationCode.duplicateId),
    );
    expect(
      validatePortfolioContent(PortfolioContent(blocks: [])),
      contains(PortfolioValidationCode.invalidStructure),
    );
    final blocks = PortfolioContent().blocks.toList();
    blocks[1] = blocks[0];
    expect(
      validatePortfolioContent(PortfolioContent(blocks: blocks)),
      contains(PortfolioValidationCode.invalidStructure),
    );
  });

  test('Every bounded field accepts its boundary and rejects overflow', () {
    final fields = <(int, PortfolioContent Function(String))>[
      (
        100,
        (value) => PortfolioContent(profile: PortfolioProfile(name: value)),
      ),
      (
        160,
        (value) => PortfolioContent(profile: PortfolioProfile(headline: value)),
      ),
      (
        4000,
        (value) => PortfolioContent(profile: PortfolioProfile(bio: value)),
      ),
      (
        200,
        (value) =>
            PortfolioContent(profile: PortfolioProfile(locationText: value)),
      ),
      (
        60,
        (value) => PortfolioContent(
          skills: [Skill(id: 's', name: value)],
        ),
      ),
      (
        120,
        (value) => PortfolioContent(
          projects: [
            PortfolioProject(
              id: 'p',
              title: value,
              description: '',
              technologies: [],
            ),
          ],
        ),
      ),
      (
        4000,
        (value) => PortfolioContent(
          projects: [
            PortfolioProject(
              id: 'p',
              title: 'Project',
              description: value,
              technologies: [],
            ),
          ],
        ),
      ),
      (
        60,
        (value) => PortfolioContent(
          projects: [
            PortfolioProject(
              id: 'p',
              title: 'Project',
              description: '',
              technologies: [value],
            ),
          ],
        ),
      ),
      (
        120,
        (value) => PortfolioContent(
          experience: [
            Experience(
              id: 'e',
              role: value,
              organization: 'Org',
              period: '',
              description: '',
            ),
          ],
        ),
      ),
      (
        160,
        (value) => PortfolioContent(
          experience: [
            Experience(
              id: 'e',
              role: 'Role',
              organization: value,
              period: '',
              description: '',
            ),
          ],
        ),
      ),
      (
        120,
        (value) => PortfolioContent(
          experience: [
            Experience(
              id: 'e',
              role: 'Role',
              organization: 'Org',
              period: value,
              description: '',
            ),
          ],
        ),
      ),
      (
        4000,
        (value) => PortfolioContent(
          experience: [
            Experience(
              id: 'e',
              role: 'Role',
              organization: 'Org',
              period: '',
              description: value,
            ),
          ],
        ),
      ),
      (
        160,
        (value) => PortfolioContent(
          education: [
            Education(
              id: 'e',
              institution: value,
              qualification: 'Degree',
              period: '',
              description: '',
            ),
          ],
        ),
      ),
      (
        160,
        (value) => PortfolioContent(
          education: [
            Education(
              id: 'e',
              institution: 'Institution',
              qualification: value,
              period: '',
              description: '',
            ),
          ],
        ),
      ),
      (
        120,
        (value) => PortfolioContent(
          education: [
            Education(
              id: 'e',
              institution: 'Institution',
              qualification: 'Degree',
              period: value,
              description: '',
            ),
          ],
        ),
      ),
      (
        4000,
        (value) => PortfolioContent(
          education: [
            Education(
              id: 'e',
              institution: 'Institution',
              qualification: 'Degree',
              period: '',
              description: value,
            ),
          ],
        ),
      ),
      (
        80,
        (value) => PortfolioContent(
          links: [
            SocialLink(id: 'l', label: value, url: 'https://example.com'),
          ],
        ),
      ),
      (20000, (value) => PortfolioContent(resumeText: value)),
    ];
    for (final (limit, content) in fields) {
      expect(
        validatePortfolioContent(content('x' * limit)),
        isEmpty,
        reason: 'limit $limit',
      );
      expect(
        validatePortfolioContent(content('x' * (limit + 1))),
        contains(PortfolioValidationCode.tooLong),
        reason: 'overflow $limit',
      );
    }
  });

  test('Technologies have a bounded nonempty item list', () {
    final project = PortfolioProject(
      id: 'p',
      title: 'Project',
      description: '',
      technologies: List.filled(20, 'Dart'),
    );
    expect(
      validatePortfolioContent(PortfolioContent(projects: [project])),
      isEmpty,
    );
    expect(
      validatePortfolioContent(
        PortfolioContent(
          projects: [project.copyWith(technologies: List.filled(21, 'Dart'))],
        ),
      ),
      contains(PortfolioValidationCode.invalidStructure),
    );
    expect(
      validatePortfolioContent(
        PortfolioContent(
          projects: [
            project.copyWith(technologies: [' ']),
          ],
        ),
      ),
      contains(PortfolioValidationCode.required),
    );
  });

  test(
    'Completion has five meaningful steps independent of optional sections',
    () {
      final empty = calculatePortfolioCompletion(PortfolioContent());
      expect(empty.completedSteps, 0);
      expect(empty.totalSteps, 5);
      expect(empty.missingSteps, PortfolioCompletionStep.values);
      final complete = calculatePortfolioCompletion(_complete());
      expect(complete.completedSteps, 5);
      expect(complete.percent, 100);
      expect(complete.fraction, 1);
      expect(complete.missingSteps, isEmpty);
      expect(() => empty.missingSteps.clear(), throwsUnsupportedError);
    },
  );

  test(
    'Hiding blocks cannot inflate completeness; hidden projects do not count',
    () {
      final content = _complete();
      final hiddenBlocks = content.copyWith(
        blocks: content.blocks
            .map((block) => block.copyWith(visible: false))
            .toList(),
      );
      expect(calculatePortfolioCompletion(hiddenBlocks).percent, 100);
      final hiddenProject = content.copyWith(
        projects: content.projects
            .map((project) => project.copyWith(visible: false))
            .toList(),
      );
      expect(calculatePortfolioCompletion(hiddenProject).percent, 80);
      expect(calculatePortfolioCompletion(hiddenProject).missingSteps, [
        PortfolioCompletionStep.projects,
      ]);
    },
  );

  test('Invalid entries and usernames are not treated as completed steps', () {
    final content = _complete().copyWith(
      profile: _complete().profile.copyWith(username: 'INVALID'),
      skills: [const Skill(id: 's', name: ' ')],
      links: [const SocialLink(id: 'l', label: 'Site', url: '/relative')],
    );
    final completion = calculatePortfolioCompletion(content);
    expect(completion.missingSteps, [
      PortfolioCompletionStep.profile,
      PortfolioCompletionStep.skills,
      PortfolioCompletionStep.links,
    ]);
    expect(completion.percent, 40);
  });
}

PortfolioContent _complete() => PortfolioContent(
  profile: const PortfolioProfile(
    name: 'Sam',
    username: 'sam',
    headline: 'Developer',
    bio: 'About me',
  ),
  skills: [const Skill(id: 's', name: 'Dart')],
  projects: [
    PortfolioProject(
      id: 'p',
      title: 'Project',
      description: '',
      technologies: [],
    ),
  ],
  links: [
    const SocialLink(id: 'l', label: 'Website', url: 'https://example.com'),
  ],
);
