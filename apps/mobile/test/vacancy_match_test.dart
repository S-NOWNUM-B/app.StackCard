import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/vacancy_match.dart';
import 'package:flutter_test/flutter_test.dart';

PortfolioProject _project(
  String id, {
  String title = 'Проект',
  String description = '',
  List<String> technologies = const [],
}) => PortfolioProject(
  id: id,
  title: title,
  description: description,
  technologies: technologies,
);

PortfolioContent _content({
  List<String> skills = const [],
  List<PortfolioProject> projects = const [],
  List<Experience> experience = const [],
  String headline = '',
}) => PortfolioContent(
  profile: PortfolioProfile(headline: headline),
  skills: [for (final s in skills) Skill(id: 's-$s', name: s)],
  projects: projects,
  experience: experience,
);

Set<String> _ids(String text) =>
    findVacancyTerms(text).map((term) => term.id).toSet();

void main() {
  exportTests();
  group('разбор текста', () {
    test('регистр, знаки и версии не мешают', () {
      expect(_ids('Требуется: Node 20, REACT!, TypeScript.'), {
        'node',
        'react',
        'typescript',
      });
    });

    test('синонимы сводятся к одному термину', () {
      expect(_ids('js, JavaScript, ECMAScript'), {'javascript'});
      expect(_ids('k8s и Kubernetes'), {'kubernetes'});
      expect(_ids('Postgres / PostgreSQL'), {'postgresql'});
      expect(_ids('ts'), {'typescript'});
      expect(_ids('Spring Boot'), {'spring'});
    });

    test('специальные написания: c++, c#, .net, node.js, ci/cd', () {
      expect(_ids('опыт c++ и C#, .NET, Node.js'), {
        'cpp',
        'csharp',
        'dotnet',
        'node',
      });
      expect(_ids('настройка CI/CD'), {'cicd'});
    });

    test('смесь RU и EN, ё и склонения роли', () {
      expect(_ids('Ищем мобильного разработчика: Флаттер, Dart, Докер'), {
        'mobile',
        'flutter',
        'dart',
        'docker',
      });
      expect(_ids('Фронтенд и бэкенд'), {'frontend', 'backend'});
    });

    test('части слов не считаются совпадением', () {
      expect(_ids('javascripty reactive typescripts'), isEmpty);
    });

    test('пустой и короткий текст без требований', () {
      expect(findVacancyTerms(''), isEmpty);
      expect(findVacancyTerms('   \n  '), isEmpty);
    });

    test('очень длинные слова и огромный текст не ломают разбор', () {
      final long = 'a' * 500;
      expect(_ids('$long react $long'), {'react'});
      final huge = '${'слово ' * 50000}docker';
      // Текст обрезается по лимиту: хвост за пределом не учитывается.
      expect(_ids(huge), isEmpty);
      expect(_ids('docker ${'слово ' * 50000}'), {'docker'});
    });

    test('сто и больше строк разбираются целиком', () {
      final text = [
        for (var i = 0; i < 150; i++) 'Строка $i требования',
        'Flutter',
      ].join('\n');
      expect(_ids(text), {'flutter'});
    });

    test('версия слитно и связки через плюс разбираются', () {
      expect(_ids('Python3, Vue3 и Java17'), {'python', 'vue', 'java'});
      expect(_ids('React+Redux, HTML+CSS'), {'react', 'html', 'css'});
    });

    test('русские формы слов и Golang', () {
      expect(_ids('разработка мобильных приложений'), {'mobile'});
      expect(_ids('опыт бэкенда и работы в докере'), {'backend', 'docker'});
      expect(_ids('Golang developer'), {'go'});
    });

    test('обычные слова не дают ложных требований', () {
      expect(_ids('Next steps: the rest of the team will test'), isEmpty);
    });
  });

  group('сопоставление', () {
    test('считает 5 из 8 и делит на совпавшие и недостающие', () {
      final match = matchVacancy(
        vacancyText:
            'Dart, Flutter, Firebase, Docker, Kubernetes, Postgres, Git, Linux',
        content: _content(
          skills: ['Dart', 'Flutter', 'Git'],
          projects: [
            _project('p', technologies: ['Firebase', 'PostgreSQL']),
          ],
        ),
      );
      expect(match.totalCount, 8);
      expect(match.matchedCount, 5);
      expect(match.percent, 63);
      expect(match.missingRequirements.map((r) => r.term.id).toSet(), {
        'docker',
        'kubernetes',
        'linux',
      });
    });

    test('синоним в портфолио совпадает с вакансией', () {
      final match = matchVacancy(
        vacancyText: 'Нужен Kubernetes и JavaScript',
        content: _content(skills: ['k8s', 'js']),
      );
      expect(match.percent, 100);
    });

    test('пустое портфолио: все требования отсутствуют, без падений', () {
      final match = matchVacancy(
        vacancyText: 'React, Node 20',
        content: PortfolioContent(),
      );
      expect(match.percent, 0);
      expect(match.totalCount, 2);
      expect(match.projects, isEmpty);
      expect(match.experience, isEmpty);
    });

    test(
      'вакансия без известных требований: процент 0, флаг noRequirements',
      () {
        final match = matchVacancy(
          vacancyText: 'Мы дружная команда и любим кофе по пятницам',
          content: _content(skills: ['Dart']),
        );
        expect(match.noRequirements, isTrue);
        expect(match.percent, 0);
      },
    );

    test('нет ни одного совпадения', () {
      final match = matchVacancy(
        vacancyText: 'Rust и Kafka',
        content: _content(skills: ['Dart']),
      );
      expect(match.matchedCount, 0);
      expect(match.percent, 0);
    });

    test('Go: разные написания распознаются, навык «Go» не теряется', () {
      expect(_ids('Go-разработчик'), {'go'});
      expect(_ids('Go developer в команду'), {'go'});
      expect(_ids('Go/Golang, Docker'), {'go', 'docker'});
      for (final vacancy in [
        'Golang developer',
        'Go-разработчик',
        'Go/Golang',
      ]) {
        final match = matchVacancy(
          vacancyText: vacancy,
          content: _content(skills: ['Go']),
        );
        expect(match.percent, 100, reason: vacancy);
      }
      final noSkill = matchVacancy(
        vacancyText: 'Go developer',
        content: _content(skills: ['Dart']),
      );
      expect(noSkill.percent, 0);
      // Обычное слово «go» не создаёт требование даже при навыке Go.
      expect(
        matchVacancy(
          vacancyText: 'We go to market fast, no stack listed here at all',
          content: _content(skills: ['Go']),
        ).noRequirements,
        isTrue,
      );
    });

    test('составной термин не дублируется коротким', () {
      expect(_ids('React Native разработчик'), {'react native'});
      expect(_ids('React Native и React'), {'react native', 'react'});
      expect(_ids('React, затем React Native'), {'react', 'react native'});
      final onlyNative = matchVacancy(
        vacancyText: 'React Native developer',
        content: _content(skills: ['React Native']),
      );
      expect(onlyNative.totalCount, 1);
      expect(onlyNative.percent, 100);
      // Навык «React Native» не закрывает отдельное требование «React».
      final both = matchVacancy(
        vacancyText: 'React Native и React',
        content: _content(skills: ['React Native']),
      );
      expect(both.totalCount, 2);
      expect(both.matchedCount, 1);
    });

    test('«Go backend» не прячет роль Backend', () {
      expect(_ids('Go backend разработчик'), {'backend'});
      expect(_ids('Go developer, backend'), {'go', 'backend'});
    });

    test('«React JS» не даёт отдельного требования JavaScript', () {
      expect(_ids('React JS developer'), {'react'});
      expect(_ids('Node JS и JS'), {'node', 'javascript'});
      final match = matchVacancy(
        vacancyText: 'React JS developer',
        content: _content(skills: ['React']),
      );
      expect(match.percent, 100);
    });

    test('поля портфолио разбираются раздельно', () {
      // Организация не делает технологией; граница полей не склеивает слова.
      final match = matchVacancy(
        vacancyText: 'Нужны Swift и Go developer',
        content: _content(
          projects: [
            _project('p', title: 'Go', description: 'developer portal'),
          ],
          experience: const [
            Experience(
              id: 'e',
              role: 'Менеджер',
              organization: 'Swift Logistics',
              period: '2024',
              description: '',
            ),
          ],
        ),
      );
      expect(match.matchedCount, 0);
      expect(match.experience.single.score, 0);
    });

    test('навыки вне вакансии не меняют процент и не создают требований', () {
      const vacancy = 'Нужны Dart и Zustand, а также Kafka';
      final bare = matchVacancy(
        vacancyText: vacancy,
        content: _content(skills: ['Dart']),
      );
      final padded = matchVacancy(
        vacancyText: vacancy,
        content: _content(
          skills: ['Dart', 'Zustand', 'Figma', 'Rust', 'Agile'],
        ),
      );
      expect(padded.totalCount, bare.totalCount);
      expect(padded.matchedCount, bare.matchedCount);
      expect(padded.percent, bare.percent);
      expect(padded.requirements.map((r) => r.term.id), ['dart', 'kafka']);
    });

    test('роль совпадает по должности и опыту', () {
      final byHeadline = matchVacancy(
        vacancyText: 'Frontend разработчик',
        content: _content(headline: 'Senior Frontend Engineer'),
      );
      expect(byHeadline.percent, 100);
      expect(byHeadline.requirements.single.evidence, [
        VacancyEvidence.headline,
      ]);
      final byExperience = matchVacancy(
        vacancyText: 'Нужен backend',
        content: _content(
          experience: const [
            Experience(
              id: 'e',
              role: 'Backend developer',
              organization: 'Org',
              period: '2024',
              description: '',
            ),
          ],
        ),
      );
      expect(byExperience.percent, 100);
    });

    test('проекты и опыт получают релевантность и порядок', () {
      final match = matchVacancy(
        vacancyText: 'Flutter, Dart, Firebase',
        content: _content(
          projects: [
            _project('web', technologies: ['React']),
            _project('app', technologies: ['Flutter', 'Dart']),
            _project('one', description: 'Использует Firebase'),
          ],
          experience: const [
            Experience(
              id: 'e1',
              role: 'Mobile',
              organization: 'A',
              period: '2023',
              description: 'Писал на Flutter',
            ),
            Experience(
              id: 'e2',
              role: 'QA',
              organization: 'B',
              period: '2022',
              description: '',
            ),
          ],
        ),
      );
      expect(match.projectOrder, ['app', 'one', 'web']);
      expect(match.projects.first.score, 2);
      expect(match.projects.last.score, 0);
      expect(match.experience.first.score, 1);
      expect(match.experience.last.score, 0);
    });

    test('равная релевантность сохраняет исходный порядок проектов', () {
      final match = matchVacancy(
        vacancyText: 'Rust',
        content: _content(
          projects: [_project('b'), _project('a'), _project('c')],
        ),
      );
      expect(match.projectOrder, ['b', 'a', 'c']);
    });

    test('скрытые проекты не участвуют', () {
      final hidden = PortfolioProject(
        id: 'h',
        title: 't',
        description: '',
        technologies: const ['Dart'],
        visible: false,
      );
      final match = matchVacancy(
        vacancyText: 'Dart',
        content: _content(projects: [hidden]),
      );
      expect(match.projectOrder, isEmpty);
    });

    test('порядок разделов — перестановка пяти разделов, сильные первыми', () {
      final match = matchVacancy(
        vacancyText: 'Flutter',
        content: _content(
          projects: [
            _project('p', technologies: ['Flutter']),
          ],
        ),
      );
      expect(match.sectionOrder.toSet(), mainPortfolioSectionKinds.toSet());
      expect(match.sectionOrder, hasLength(mainPortfolioSectionKinds.length));
      expect(match.sectionOrder.first, PortfolioBlockKind.featuredProjects);
    });

    test('порядок разделов без сигнала не сбрасывает текущий', () {
      final blocks = [
        const PortfolioBlock(kind: PortfolioBlockKind.profile),
        const PortfolioBlock(kind: PortfolioBlockKind.education),
        const PortfolioBlock(kind: PortfolioBlockKind.skills),
        const PortfolioBlock(kind: PortfolioBlockKind.featuredProjects),
        const PortfolioBlock(kind: PortfolioBlockKind.experience),
        const PortfolioBlock(kind: PortfolioBlockKind.links),
      ];
      final match = matchVacancy(
        vacancyText: 'Rust',
        content: _content().copyWith(blocks: blocks),
      );
      expect(match.sectionOrder.first, PortfolioBlockKind.education);
    });

    test('результат детерминирован и не меняет контент', () {
      final content = _content(skills: ['Dart']);
      final first = matchVacancy(vacancyText: 'Dart, Rust', content: content);
      final second = matchVacancy(vacancyText: 'Dart, Rust', content: content);
      expect(first.percent, second.percent);
      expect(first.sectionOrder, second.sectionOrder);
      expect(content, _content(skills: ['Dart']));
    });
  });
}

void exportTests() {
  group('экспорт под вакансию', () {
    test('GitHub скрывается вместе с контактами, порядок применяется', () {
      final content = PortfolioContent(
        projects: [_project('a'), _project('b')],
        blocks: const [
          PortfolioBlock(kind: PortfolioBlockKind.profile),
          PortfolioBlock(kind: PortfolioBlockKind.github),
          PortfolioBlock(kind: PortfolioBlockKind.links),
          PortfolioBlock(kind: PortfolioBlockKind.skills),
          PortfolioBlock(kind: PortfolioBlockKind.featuredProjects),
        ],
      );
      final result = buildVacancyExportContent(
        content,
        projectOrder: ['b', 'a'],
        includedProjects: {'a', 'b'},
        sectionOrder: [
          PortfolioBlockKind.featuredProjects,
          PortfolioBlockKind.skills,
          PortfolioBlockKind.experience,
          PortfolioBlockKind.education,
          PortfolioBlockKind.links,
        ],
        includedSections: {
          PortfolioBlockKind.featuredProjects,
          PortfolioBlockKind.skills,
        },
      );
      expect(result.projects.map((p) => p.id), ['b', 'a']);
      bool visible(PortfolioBlockKind kind) =>
          result.blocks.firstWhere((b) => b.kind == kind).visible;
      expect(visible(PortfolioBlockKind.links), isFalse);
      expect(visible(PortfolioBlockKind.github), isFalse);
      expect(visible(PortfolioBlockKind.skills), isTrue);
      expect(
        mainPortfolioSectionOrder(result).first,
        PortfolioBlockKind.featuredProjects,
      );
      // Исходное содержимое не изменилось.
      expect(content.projects.map((p) => p.id), ['a', 'b']);
    });
  });
}
