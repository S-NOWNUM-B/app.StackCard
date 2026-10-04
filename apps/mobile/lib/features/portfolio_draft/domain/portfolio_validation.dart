import 'portfolio_content.dart';
import 'portfolio_github_sync.dart';

enum PortfolioValidationCode {
  required,
  tooLong,
  invalidUsername,
  invalidUrl,
  duplicateId,
  invalidStructure,
}

PortfolioValidationCode? validatePortfolioText(
  String value, {
  bool required = false,
  int maxLength = 200,
}) {
  if (required && value.trim().isEmpty) return PortfolioValidationCode.required;
  if (value.length > maxLength) return PortfolioValidationCode.tooLong;
  return null;
}

PortfolioValidationCode? validatePortfolioUsername(String value) {
  if (value.isEmpty) return null;
  if (!RegExp(r'^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$').hasMatch(value)) {
    return PortfolioValidationCode.invalidUsername;
  }
  return null;
}

PortfolioValidationCode? validatePortfolioUrl(String value) {
  if (value.isEmpty) return null;
  if (value.length > 2048) return PortfolioValidationCode.tooLong;
  final uri = Uri.tryParse(value);
  final authority = RegExp(r'^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]*)')
      .firstMatch(value)
      ?.group(1);
  if (uri == null ||
      value != value.trim() ||
      RegExp(r'\s').hasMatch(value) ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      authority == null ||
      authority.contains('@')) {
    return PortfolioValidationCode.invalidUrl;
  }
  return null;
}

/// Незаполненный профиль допустим; добавленные элементы имеют обязательные поля.
List<PortfolioValidationCode> validatePortfolioContent(
  PortfolioContent content,
) {
  final issues = <PortfolioValidationCode>{};
  void add(PortfolioValidationCode? issue) {
    if (issue != null) issues.add(issue);
  }

  void text(String value, int limit, {bool required = false}) =>
      add(validatePortfolioText(value, required: required, maxLength: limit));
  void ids(Iterable<String> values) {
    final seen = <String>{};
    for (final id in values) {
      text(id, 200, required: true);
      if (!seen.add(id)) issues.add(PortfolioValidationCode.duplicateId);
    }
  }

  final profile = content.profile;
  text(profile.name, 100);
  add(validatePortfolioUsername(profile.username));
  text(profile.headline, 160);
  text(profile.bio, 4000);
  text(profile.locationText, 200);
  add(validatePortfolioUrl(profile.avatarUrl));
  ids(content.skills.map((skill) => skill.id));
  for (final skill in content.skills) {
    text(skill.name, 60, required: true);
  }
  ids(content.projects.map((project) => project.id));
  final githubIds = <int>{};
  for (final project in content.projects) {
    text(project.title, 120, required: true);
    text(project.description, 4000);
    if (project.technologies.length > 20) {
      issues.add(PortfolioValidationCode.invalidStructure);
    }
    for (final technology in project.technologies) {
      text(technology, 60, required: true);
    }
    add(validatePortfolioUrl(project.repositoryUrl));
    add(validatePortfolioUrl(project.liveUrl));
    final metadata = project.githubMetadata;
    if (project.source == PortfolioProjectSource.manual) {
      if (metadata != null) {
        issues.add(PortfolioValidationCode.invalidStructure);
      }
    } else if (metadata == null) {
      issues.add(PortfolioValidationCode.invalidStructure);
    } else {
      issues.addAll(validatePortfolioGitHubSource(metadata.acceptedSource));
      if (!githubIds.add(metadata.acceptedSource.repositoryId)) {
        issues.add(PortfolioValidationCode.duplicateId);
      }
      if (metadata.lastGitHubSyncAt?.isUtc == false) {
        issues.add(PortfolioValidationCode.invalidStructure);
      }
    }
  }
  final ignoredIds = <int>{};
  for (final ignored in content.ignoredGitHubRepositories) {
    if (ignored.repositoryId < 1) {
      issues.add(PortfolioValidationCode.invalidStructure);
    }
    if (!ignoredIds.add(ignored.repositoryId)) {
      issues.add(PortfolioValidationCode.duplicateId);
    }
    text(ignored.fingerprint, 200, required: true);
  }
  ids(content.experience.map((item) => item.id));
  for (final item in content.experience) {
    text(item.role, 120, required: true);
    text(item.organization, 160, required: true);
    text(item.period, 120);
    text(item.description, 4000);
  }
  ids(content.education.map((item) => item.id));
  for (final item in content.education) {
    text(item.institution, 160, required: true);
    text(item.qualification, 160, required: true);
    text(item.period, 120);
    text(item.description, 4000);
  }
  ids(content.links.map((link) => link.id));
  for (final link in content.links) {
    text(link.label, 80, required: true);
    add(validatePortfolioText(link.url, required: true, maxLength: 2048));
    add(validatePortfolioUrl(link.url));
  }
  text(content.resumeText, 20000);
  if (content.blocks.length != PortfolioBlockKind.values.length ||
      content.blocks.map((block) => block.kind).toSet().length !=
          PortfolioBlockKind.values.length) {
    issues.add(PortfolioValidationCode.invalidStructure);
  }
  return List.unmodifiable(issues);
}

List<PortfolioValidationCode> validatePortfolioGitHubSource(
  GitHubProjectSource source,
) {
  final issues = <PortfolioValidationCode>{};
  void text(String value, int limit, {bool required = false}) {
    final issue = validatePortfolioText(
      value,
      maxLength: limit,
      required: required,
    );
    if (issue != null) issues.add(issue);
  }

  if (source.repositoryId < 1 ||
      source.stars < 0 ||
      source.forks < 0 ||
      !source.updatedAt.isUtc) {
    issues.add(PortfolioValidationCode.invalidStructure);
  }
  text(source.name, 120, required: true);
  text(source.fullName, 300, required: true);
  text(source.htmlUrl, 2048, required: true);
  final urlIssue = validatePortfolioUrl(source.htmlUrl);
  if (urlIssue != null) issues.add(urlIssue);
  if (source.description != null) text(source.description!, 4000);
  if (source.language != null) text(source.language!, 60, required: true);
  return List.unmodifiable(issues);
}
