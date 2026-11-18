import 'portfolio_content.dart';
import 'portfolio_suggestions.dart';

/// Разделы оценки; порядок и вес задают важность совета.
enum PortfolioHealthSection {
  profile(20),
  avatar(5),
  projects(25),
  experience(10),
  education(5),
  skills(15),
  contacts(10),
  publication(10);

  const PortfolioHealthSection(this.weight);
  final int weight;
}

enum PortfolioHealthCheckKind {
  profileName,
  profileHeadline,
  profileBio,
  avatar,
  projectsAny,
  projectDescription,
  projectTechnologies,
  projectLink,
  projectInactive,
  experienceAny,
  educationAny,
  skillsAny,
  skillUnused,
  contactsAny,
  published,
}

/// Одна проверка: [ok] — всё хорошо, иначе нужен совет и действие в Editor.
final class PortfolioHealthCheck {
  const PortfolioHealthCheck({
    required this.section,
    required this.kind,
    required this.ok,
    this.targetId,
    this.targetTitle,
  });

  final PortfolioHealthSection section;
  final PortfolioHealthCheckKind kind;
  final bool ok;

  /// Проект или навык, к которому относится совет.
  final String? targetId;
  final String? targetTitle;

  String get id => '${kind.name}:${targetId ?? ''}';

  Object get _fields => (section, kind, ok, targetId, targetTitle);

  @override
  bool operator ==(Object other) =>
      other is PortfolioHealthCheck && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}

final class PortfolioHealth {
  PortfolioHealth({
    required this.score,
    required List<PortfolioHealthCheck> checks,
  }) : checks = List.unmodifiable(checks);

  /// Общий балл 0–100.
  final int score;
  final List<PortfolioHealthCheck> checks;

  Iterable<PortfolioHealthCheck> get improvements =>
      checks.where((check) => !check.ok);
  bool get isPerfect => score == 100 && improvements.isEmpty;

  Iterable<PortfolioHealthCheck> forSection(PortfolioHealthSection section) =>
      checks.where((check) => check.section == section);

  /// Доля выполненных проверок раздела; null, если проверок нет.
  double? sectionFraction(PortfolioHealthSection section) {
    final items = forSection(section).toList();
    if (items.isEmpty) return null;
    return items.where((check) => check.ok).length / items.length;
  }
}

/// Оценка только читает контент. [published] == null — статус неизвестен,
/// раздел публикации тогда не учитывается. Пороги совпадают с Suggestions.
PortfolioHealth buildPortfolioHealth({
  required PortfolioContent content,
  required DateTime now,
  bool? published,
}) {
  final checks = <PortfolioHealthCheck>[];
  void add(
    PortfolioHealthSection section,
    PortfolioHealthCheckKind kind,
    bool ok, {
    String? targetId,
    String? targetTitle,
  }) => checks.add(
    PortfolioHealthCheck(
      section: section,
      kind: kind,
      ok: ok,
      targetId: targetId,
      targetTitle: targetTitle,
    ),
  );

  final profile = content.profile;
  add(
    PortfolioHealthSection.profile,
    PortfolioHealthCheckKind.profileName,
    profile.name.trim().isNotEmpty,
  );
  add(
    PortfolioHealthSection.profile,
    PortfolioHealthCheckKind.profileHeadline,
    profile.headline.trim().isNotEmpty,
  );
  add(
    PortfolioHealthSection.profile,
    PortfolioHealthCheckKind.profileBio,
    profile.bio.trim().isNotEmpty,
  );
  add(
    PortfolioHealthSection.avatar,
    PortfolioHealthCheckKind.avatar,
    profile.avatarPath.trim().isNotEmpty || profile.avatarUrl.trim().isNotEmpty,
  );

  final projects = content.projects
      .where((project) => project.visible)
      .toList();
  add(
    PortfolioHealthSection.projects,
    PortfolioHealthCheckKind.projectsAny,
    projects.isNotEmpty,
  );
  // Описание и давность берутся из существующих Suggestions, без копии порогов.
  final suggestions = buildPortfolioSuggestions(content: content, now: now);
  bool flagged(PortfolioSuggestionKind kind, String projectId) => suggestions
      .any((item) => item.kind == kind && item.projectId == projectId);
  for (final project in projects) {
    void addProjectCheck(PortfolioHealthCheckKind kind, bool ok) => add(
      PortfolioHealthSection.projects,
      kind,
      ok,
      targetId: project.id,
      targetTitle: project.title,
    );
    addProjectCheck(
      PortfolioHealthCheckKind.projectDescription,
      !flagged(PortfolioSuggestionKind.missingDescription, project.id),
    );
    addProjectCheck(
      PortfolioHealthCheckKind.projectTechnologies,
      project.technologies.any((value) => value.trim().isNotEmpty),
    );
    addProjectCheck(
      PortfolioHealthCheckKind.projectLink,
      project.liveUrl.trim().isNotEmpty ||
          project.repositoryUrl.trim().isNotEmpty,
    );
    if (flagged(PortfolioSuggestionKind.inactiveProject, project.id)) {
      addProjectCheck(PortfolioHealthCheckKind.projectInactive, false);
    }
  }

  add(
    PortfolioHealthSection.experience,
    PortfolioHealthCheckKind.experienceAny,
    content.experience.isNotEmpty,
  );
  add(
    PortfolioHealthSection.education,
    PortfolioHealthCheckKind.educationAny,
    content.education.isNotEmpty,
  );

  add(
    PortfolioHealthSection.skills,
    PortfolioHealthCheckKind.skillsAny,
    content.skills.isNotEmpty,
  );
  final used = {
    for (final project in projects)
      for (final technology in project.technologies)
        technology.trim().toLowerCase(),
  };
  // Навыки без проектов не проверяются: советовать нечего связывать.
  if (projects.isNotEmpty) {
    for (final skill in content.skills) {
      add(
        PortfolioHealthSection.skills,
        PortfolioHealthCheckKind.skillUnused,
        used.contains(skill.name.trim().toLowerCase()),
        targetId: skill.id,
        targetTitle: skill.name,
      );
    }
  }

  add(
    PortfolioHealthSection.contacts,
    PortfolioHealthCheckKind.contactsAny,
    content.links.any((link) => link.visible && link.publishAllowed),
  );
  if (published != null) {
    add(
      PortfolioHealthSection.publication,
      PortfolioHealthCheckKind.published,
      published,
    );
  }

  var weighted = 0.0;
  var total = 0;
  for (final section in PortfolioHealthSection.values) {
    final items = checks.where((check) => check.section == section).toList();
    if (items.isEmpty) continue;
    total += section.weight;
    weighted +=
        section.weight * items.where((check) => check.ok).length / items.length;
  }
  var score = total == 0 ? 0 : (100 * weighted / total).round();
  // 100 только когда не осталось ни одного совета.
  if (score == 100 && checks.any((check) => !check.ok)) score = 99;
  checks.sort((left, right) {
    if (left.ok != right.ok) return left.ok ? 1 : -1;
    final bySection = right.section.weight.compareTo(left.section.weight);
    return bySection != 0 ? bySection : left.id.compareTo(right.id);
  });
  return PortfolioHealth(score: score, checks: checks);
}
