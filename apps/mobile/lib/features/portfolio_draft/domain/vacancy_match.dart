import 'portfolio_content.dart';

/// Минимальная длина текста вакансии для разбора.
const vacancyMinimumLength = 20;

/// Разбор ограничен: длиннее текст обрезается, чтобы экран не зависал.
const vacancyMaximumLength = 20000;

/// Термин словаря: технология или роль. [aliases] — варианты написания
/// (регистр и знаки не важны), многословные задаются через пробел.
final class VacancyTerm {
  const VacancyTerm(this.id, this.label, this.aliases, {this.role = false});
  final String id;
  final String label;
  final List<String> aliases;

  /// Название направления (frontend, backend), а не технология.
  final bool role;
}

/// Небольшой расширяемый словарь; свои термины передаются в [matchVacancy].
const defaultVacancyDictionary = <VacancyTerm>[
  VacancyTerm('javascript', 'JavaScript', ['javascript', 'js', 'ecmascript']),
  VacancyTerm('typescript', 'TypeScript', ['typescript', 'ts']),
  VacancyTerm('node', 'Node.js', ['node', 'nodejs', 'node.js', 'node js']),
  VacancyTerm('react', 'React', ['react', 'reactjs', 'react.js', 'react js']),
  VacancyTerm('react native', 'React Native', ['react native']),
  VacancyTerm('next', 'Next.js', ['nextjs', 'next.js']),
  VacancyTerm('vue', 'Vue', ['vue', 'vuejs', 'vue.js', 'vue js']),
  VacancyTerm('angular', 'Angular', ['angular', 'angularjs']),
  VacancyTerm('html', 'HTML', ['html', 'html5']),
  VacancyTerm('css', 'CSS', ['css', 'css3']),
  VacancyTerm('tailwind', 'Tailwind', ['tailwind', 'tailwindcss']),
  VacancyTerm('flutter', 'Flutter', ['flutter', 'флаттер']),
  VacancyTerm('dart', 'Dart', ['dart', 'дарт']),
  VacancyTerm('kotlin', 'Kotlin', ['kotlin', 'котлин']),
  VacancyTerm('java', 'Java', ['java', 'джава']),
  VacancyTerm('spring', 'Spring', ['spring', 'spring boot', 'springboot']),
  VacancyTerm('swift', 'Swift', ['swift']),
  VacancyTerm('ios', 'iOS', ['ios']),
  VacancyTerm('android', 'Android', ['android', 'андроид']),
  VacancyTerm('python', 'Python', ['python', 'питон', 'питоне', 'пайтон']),
  VacancyTerm('django', 'Django', ['django']),
  VacancyTerm('fastapi', 'FastAPI', ['fastapi']),
  VacancyTerm('go', 'Go', [
    'golang',
    'go lang',
    'go developer',
    'go engineer',
    'go dev',
    'go разработчик',
    'go разработчика',
    'go программист',
  ]),
  VacancyTerm('rust', 'Rust', ['rust']),
  VacancyTerm('csharp', 'C#', ['c#', 'csharp']),
  VacancyTerm('dotnet', '.NET', ['dotnet', '.net']),
  VacancyTerm('cpp', 'C++', ['c++', 'cpp']),
  VacancyTerm('sql', 'SQL', ['sql']),
  VacancyTerm('postgresql', 'PostgreSQL', ['postgresql', 'postgres', 'pg']),
  VacancyTerm('mysql', 'MySQL', ['mysql']),
  VacancyTerm('mongodb', 'MongoDB', ['mongodb', 'mongo']),
  VacancyTerm('redis', 'Redis', ['redis']),
  VacancyTerm('kafka', 'Kafka', ['kafka']),
  VacancyTerm('graphql', 'GraphQL', ['graphql']),
  VacancyTerm('rest', 'REST', ['restful', 'rest api']),
  VacancyTerm('docker', 'Docker', ['docker', 'докер', 'докере']),
  VacancyTerm('kubernetes', 'Kubernetes', ['kubernetes', 'k8s', 'кубернетес']),
  VacancyTerm('cicd', 'CI/CD', ['ci cd', 'cicd']),
  VacancyTerm('terraform', 'Terraform', ['terraform']),
  VacancyTerm('aws', 'AWS', ['aws']),
  VacancyTerm('gcp', 'GCP', ['gcp', 'google cloud']),
  VacancyTerm('azure', 'Azure', ['azure']),
  VacancyTerm('firebase', 'Firebase', ['firebase']),
  VacancyTerm('git', 'Git', ['git']),
  VacancyTerm('linux', 'Linux', ['linux', 'линукс']),
  VacancyTerm('figma', 'Figma', ['figma', 'фигма']),
  VacancyTerm('jest', 'Jest', ['jest']),
  VacancyTerm('testing', 'Тестирование', [
    'jest',
    'testing',
    'тестирование',
    'unit tests',
  ]),
  VacancyTerm('frontend', 'Frontend', [
    'frontend',
    'front end',
    'фронтенд',
    'фронтенда',
    'фронтэнд',
    'фронт энд',
  ], role: true),
  VacancyTerm('backend', 'Backend', [
    'backend',
    'back end',
    'бэкенд',
    'бэкенда',
    'бэкэнд',
    'бекенд',
    'бекенда',
    'бэк энд',
  ], role: true),
  VacancyTerm('fullstack', 'Fullstack', [
    'fullstack',
    'full stack',
    'фулстек',
    'фуллстек',
  ], role: true),
  VacancyTerm('mobile', 'Mobile', [
    'mobile',
    'мобильный',
    'мобильная',
    'мобильного',
    'мобильной',
    'мобильные',
    'мобильную',
    'мобильных',
    'мобильным',
    'мобильное',
    'мобильная',
  ], role: true),
  VacancyTerm('devops', 'DevOps', ['devops', 'девопс'], role: true),
];

/// Где требование найдено в портфолио.
enum VacancyEvidence { skill, project, experience, headline }

final class VacancyRequirement {
  VacancyRequirement({
    required this.term,
    required this.matched,
    List<VacancyEvidence> evidence = const [],
  }) : evidence = List.unmodifiable(evidence);

  final VacancyTerm term;
  final bool matched;
  final List<VacancyEvidence> evidence;
}

final class VacancyProjectScore {
  VacancyProjectScore({
    required this.projectId,
    required this.title,
    required List<String> matched,
  }) : matched = List.unmodifiable(matched);

  final String projectId;
  final String title;

  /// Подписи требований, найденных в проекте.
  final List<String> matched;
  int get score => matched.length;
}

final class VacancyExperienceScore {
  VacancyExperienceScore({
    required this.experienceId,
    required this.role,
    required List<String> matched,
  }) : matched = List.unmodifiable(matched);

  final String experienceId;
  final String role;
  final List<String> matched;
  int get score => matched.length;
}

final class VacancyMatch {
  VacancyMatch({
    required List<VacancyRequirement> requirements,
    required List<VacancyProjectScore> projects,
    required List<VacancyExperienceScore> experience,
    required List<String> projectOrder,
    required List<PortfolioBlockKind> sectionOrder,
  }) : requirements = List.unmodifiable(requirements),
       projects = List.unmodifiable(projects),
       experience = List.unmodifiable(experience),
       projectOrder = List.unmodifiable(projectOrder),
       sectionOrder = List.unmodifiable(sectionOrder);

  final List<VacancyRequirement> requirements;

  /// По убыванию релевантности; при равенстве сохраняется исходный порядок.
  final List<VacancyProjectScore> projects;
  final List<VacancyExperienceScore> experience;

  /// Предложенный порядок id проектов и разделов; ничего не применяет само.
  final List<String> projectOrder;
  final List<PortfolioBlockKind> sectionOrder;

  int get totalCount => requirements.length;
  int get matchedCount => requirements.where((item) => item.matched).length;
  Iterable<VacancyRequirement> get matchedRequirements =>
      requirements.where((item) => item.matched);
  Iterable<VacancyRequirement> get missingRequirements =>
      requirements.where((item) => !item.matched);

  /// Вакансия не содержит известных требований.
  bool get noRequirements => requirements.isEmpty;

  /// Целый процент совпавших требований; 0 без требований.
  int get percent =>
      totalCount == 0 ? 0 : (100 * matchedCount / totalCount).round();
}

final _wordPattern = RegExp(r'[.]?[\p{L}\p{N}][\p{L}\p{N}+#.]*', unicode: true);
final _plusSuffix = RegExp(r'^[\p{L}]+\+{1,2}$', unicode: true);
final _trailingDots = RegExp(r'\.+$');
final _versionSuffix = RegExp(r'(?<=\p{L})\d+(\.\d+)*$', unicode: true);

/// Токены текста: нижний регистр, слова с «+», «#», «.», без хвостовых точек.
List<String> tokenizeVacancyText(String text) {
  final cut = text.length > vacancyMaximumLength
      ? text.substring(0, vacancyMaximumLength)
      : text;
  final normalized = cut.toLowerCase().replaceAll('ё', 'е');
  final tokens = <String>[];
  for (final match in _wordPattern.allMatches(normalized)) {
    final word = match.group(0)!.replaceAll(_trailingDots, '');
    if (word.isEmpty || word.length > 40) continue;
    tokens.add(word);
    // «react+redux»: части связки; «c++» остаётся целым словом.
    if (word.contains('+') && !_plusSuffix.hasMatch(word)) {
      tokens.addAll(word.split('+').where((part) => part.isNotEmpty));
    }
    // «python3», «vue3»: ещё и слово без хвостовых цифр версии.
    final bare = word.replaceAll(_versionSuffix, '');
    if (bare != word && bare.isNotEmpty) tokens.add(bare);
  }
  return tokens;
}

/// Вхождения алиасов термина как диапазоны токенов [начало, конец).
List<(int, int)> _ranges(VacancyTerm term, List<String> tokens) {
  final found = <(int, int)>[];
  for (final alias in term.aliases) {
    final phrase = tokenizeVacancyText(alias);
    if (phrase.isEmpty) continue;
    for (var start = 0; start + phrase.length <= tokens.length; start++) {
      var ok = true;
      for (var i = 0; i < phrase.length; i++) {
        if (tokens[start + i] != phrase[i]) {
          ok = false;
          break;
        }
      }
      if (ok) found.add((start, start + phrase.length));
    }
  }
  return found;
}

/// Id терминов в [tokens]. Вхождение, целиком лежащее внутри более длинного
/// вхождения другого термина («react» в «react native»), не считается:
/// короткий термин учитывается, только если встречается сам по себе.
Set<String> _termIds(Iterable<VacancyTerm> terms, List<String> tokens) {
  final all = {for (final term in terms) term.id: _ranges(term, tokens)};
  final ids = <String>{};
  for (final entry in all.entries) {
    final standalone = entry.value.any(
      (range) => !all.entries.any(
        (other) =>
            other.key != entry.key &&
            other.value.any(
              (outer) =>
                  outer.$1 <= range.$1 &&
                  range.$2 <= outer.$2 &&
                  (outer.$2 - outer.$1) > (range.$2 - range.$1),
            ),
      ),
    );
    if (standalone) ids.add(entry.key);
  }
  return ids;
}

/// Термины, найденные в [text].
List<VacancyTerm> findVacancyTerms(
  String text, {
  List<VacancyTerm> dictionary = defaultVacancyDictionary,
}) {
  final ids = _termIds(dictionary, tokenizeVacancyText(text));
  return [
    for (final term in dictionary)
      if (ids.contains(term.id)) term,
  ];
}

/// Сопоставляет вакансию с основным портфолио. Правила: требование — термин
/// словаря, найденный в тексте
/// вакансии; совпало, если он есть в навыках, технологиях и описании проектов,
/// опыте или должности. Всё локально, без внешних сервисов.
VacancyMatch matchVacancy({
  required String vacancyText,
  required PortfolioContent content,
  List<VacancyTerm> dictionary = defaultVacancyDictionary,
}) {
  // Требования берутся только из словаря и только если термин есть в тексте
  // вакансии. Свои навыки не создают требований: иначе совпавшие навыки
  // пользователя попадали бы в знаменатель, а недостающие нет, и процент
  // завышался бы.
  final required = findVacancyTerms(vacancyText, dictionary: dictionary);
  final requiredIds = {for (final term in required) term.id};

  // Поля разбираются по отдельности: граница полей не склеивает слова
  // («Go» + «Developer portal») и не делает технологией название компании.
  List<String> labelsInAll(Iterable<String> fields) {
    final hits = <String>{};
    for (final field in fields) {
      hits.addAll(_termIds(dictionary, tokenizeVacancyText(field)));
    }
    return [
      for (final term in required)
        if (hits.contains(term.id)) term.id,
    ];
  }

  List<String> labelsIn(String text) => labelsInAll([text]);

  // Название навыка или технологии, совпавшее с id/подписью термина, считается
  // его написанием («Go» для термина go); только для коротких названий, не
  // для свободного текста и не для разбора вакансии.
  List<String> labelsInName(String name) {
    final tokens = tokenizeVacancyText(name);
    final key = tokens.join(' ');
    final ids = _termIds(dictionary, tokens);
    for (final term in dictionary) {
      if (key == term.id || key == tokenizeVacancyText(term.label).join(' ')) {
        ids.add(term.id);
      }
    }
    return [
      for (final id in ids)
        if (requiredIds.contains(id)) id,
    ];
  }

  final skillIds = {for (final s in content.skills) ...labelsInName(s.name)};
  final headlineIds = labelsIn(content.profile.headline).toSet();
  final projectHits = <String, Set<String>>{};
  final projects = content.projects.where((p) => p.visible).toList();
  for (final project in projects) {
    projectHits[project.id] = {
      for (final name in project.technologies) ...labelsInName(name),
      ...labelsInAll([project.title, project.description]),
    };
  }
  final experienceHits = <String, Set<String>>{
    for (final item in content.experience)
      item.id: {
        ...labelsInAll([item.role, item.description]),
      },
  };
  String labelOf(String id) => required.firstWhere((t) => t.id == id).label;

  final requirements = <VacancyRequirement>[];
  for (final term in required) {
    final evidence = <VacancyEvidence>[
      if (!term.role && skillIds.contains(term.id)) VacancyEvidence.skill,
      if (!term.role && projectHits.values.any((s) => s.contains(term.id)))
        VacancyEvidence.project,
      if (experienceHits.values.any((s) => s.contains(term.id)))
        VacancyEvidence.experience,
      if (headlineIds.contains(term.id)) VacancyEvidence.headline,
    ];
    requirements.add(
      VacancyRequirement(
        term: term,
        matched: evidence.isNotEmpty,
        evidence: evidence,
      ),
    );
  }

  final projectScores = [
    for (final project in projects)
      VacancyProjectScore(
        projectId: project.id,
        title: project.title,
        matched: [for (final id in projectHits[project.id]!) labelOf(id)],
      ),
  ];
  final sortedProjects = [...projectScores]
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : projectScores.indexOf(a).compareTo(projectScores.indexOf(b));
    });
  final experienceScores = [
    for (final item in content.experience)
      VacancyExperienceScore(
        experienceId: item.id,
        role: item.role,
        matched: [for (final id in experienceHits[item.id]!) labelOf(id)],
      ),
  ];

  // Разделы по числу совпавших требований; остальные — в прежнем порядке.
  final weight = {
    PortfolioBlockKind.skills: skillIds.length,
    PortfolioBlockKind.featuredProjects: {
      for (final hits in projectHits.values) ...hits,
    }.length,
    PortfolioBlockKind.experience: {
      for (final hits in experienceHits.values) ...hits,
    }.length,
  };
  final current = mainPortfolioSectionOrder(content);
  final sections = [...current]
    ..sort((a, b) {
      final byWeight = (weight[b] ?? 0).compareTo(weight[a] ?? 0);
      return byWeight != 0
          ? byWeight
          : current.indexOf(a).compareTo(current.indexOf(b));
    });

  return VacancyMatch(
    requirements: requirements,
    projects: sortedProjects,
    experience: experienceScores,
    projectOrder: [for (final item in sortedProjects) item.projectId],
    sectionOrder: sections,
  );
}

/// Блоки с разделами в [order]; не входящие в [included] скрываются.
/// Остальные блоки (профиль, о себе, место) остаются как были.
List<PortfolioBlock> vacancyBlocks(
  List<PortfolioBlock> blocks, {
  required List<PortfolioBlockKind> order,
  Set<PortfolioBlockKind>? included,
}) {
  final sections = mainPortfolioSectionKinds.toSet();
  PortfolioBlock section(PortfolioBlockKind kind) {
    final original = blocks.where((block) => block.kind == kind).firstOrNull;
    return PortfolioBlock(
      kind: kind,
      visible:
          (original?.visible ?? true) &&
          (included == null || included.contains(kind)),
    );
  }

  final linksVisible =
      included == null || included.contains(PortfolioBlockKind.links);
  return [
    for (final block in blocks)
      if (block.kind == PortfolioBlockKind.github)
        // GitHub-контакт — часть контактов и скрывается вместе с ними.
        block.copyWith(visible: block.visible && linksVisible)
      else if (!sections.contains(block.kind))
        block,
    for (final kind in [
      ...order.where(sections.contains),
      ...mainPortfolioSectionKinds.where((kind) => !order.contains(kind)),
    ])
      section(kind),
  ];
}

/// Содержимое для PDF под вакансию: выбранные проекты и разделы в
/// предложенном порядке. Исходное сохранённое портфолио не меняется.
PortfolioContent buildVacancyExportContent(
  PortfolioContent saved, {
  required List<String> projectOrder,
  required Set<String> includedProjects,
  required List<PortfolioBlockKind> sectionOrder,
  required Set<PortfolioBlockKind> includedSections,
}) {
  final byId = {for (final project in saved.projects) project.id: project};
  final ordered = [
    for (final id in projectOrder)
      if (includedProjects.contains(id) && byId.containsKey(id)) byId[id]!,
    for (final project in saved.projects)
      if (includedProjects.contains(project.id) &&
          !projectOrder.contains(project.id))
        project,
  ];
  return saved.copyWith(
    projects: ordered,
    blocks: vacancyBlocks(
      saved.blocks,
      order: sectionOrder,
      included: includedSections,
    ),
  );
}

/// Общее имя технологии для разных написаний («js» → «JavaScript»). Только
/// точное совпадение имени с алиасом, id или подписью термина-технологии;
/// null — имени нет в словаре (вызывающий оставляет написание пользователя).
VacancyTerm? findVacancyTechnology(
  String name, {
  List<VacancyTerm> dictionary = defaultVacancyDictionary,
}) {
  final key = tokenizeVacancyText(name).join(' ');
  if (key.isEmpty) return null;
  for (final term in dictionary) {
    if (term.role) continue;
    if (key == term.id ||
        key == tokenizeVacancyText(term.label).join(' ') ||
        term.aliases.any(
          (alias) => tokenizeVacancyText(alias).join(' ') == key,
        )) {
      return term;
    }
  }
  return null;
}
