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

const portfolioProjectImageLimit = 6;

/// Domain проверяет формат; соответствие UID проверяет account adapter.
PortfolioValidationCode? validatePortfolioMediaPath(
  String value, {
  bool required = false,
}) {
  if (value.isEmpty && !required) return null;
  final match = RegExp(r'^accounts/[^/]+/media/[0-9a-f]{32}\.jpg$')
      .firstMatch(value);
  if (match == null || match.end != value.length) {
    return PortfolioValidationCode.invalidStructure;
  }
  return null;
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
      RegExp(r'[\s\x00-\x1f\x7f]').hasMatch(value) ||
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

/// Контакт имеет явный тип; URL аккаунта входа не становится контактом.
PortfolioValidationCode? validatePortfolioContactUrl(
  String value,
  SocialLinkKind kind,
) {
  if (value.isEmpty) return PortfolioValidationCode.required;
  if (value.length > 2048) return PortfolioValidationCode.tooLong;
  if (value != value.trim() || RegExp(r'[\x00-\x20\x7f]|\s').hasMatch(value)) {
    return PortfolioValidationCode.invalidUrl;
  }
  final uri = Uri.tryParse(value);
  if (uri == null || uri.hasQuery || uri.hasFragment) {
    if (kind == SocialLinkKind.email ||
        kind == SocialLinkKind.phone ||
        kind == SocialLinkKind.telegram) {
      return PortfolioValidationCode.invalidUrl;
    }
  }
  final valid = switch (kind) {
    SocialLinkKind.email =>
      uri != null &&
          !uri.hasAuthority &&
          RegExp(
            r"^mailto:[A-Za-z0-9.!$&'*+/=_^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$",
          ).hasMatch(value),
    SocialLinkKind.phone => RegExp(r'^tel:\+[0-9]{7,15}$').hasMatch(value),
    SocialLinkKind.telegram =>
      validatePortfolioUrl(value) == null &&
          RegExp(r'^https://t\.me/[A-Za-z0-9_]{1,64}$').hasMatch(value),
    _ => validatePortfolioUrl(value) == null,
  };
  return valid ? null : PortfolioValidationCode.invalidUrl;
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
  add(validatePortfolioMediaPath(profile.avatarPath));
  ids(content.skills.map((skill) => skill.id));
  for (final skill in content.skills) {
    text(skill.name, 60, required: true);
  }
  ids(content.projects.map((project) => project.id));
  final githubIds = <int>{};
  for (final project in content.projects) {
    if (project.updatedAt?.isUtc == false) {
      issues.add(PortfolioValidationCode.invalidStructure);
    }
    text(project.title, 120, required: true);
    text(project.description, 4000);
    text(project.contribution, 4000);
    if (project.technologies.length > 20) {
      issues.add(PortfolioValidationCode.invalidStructure);
    }
    for (final technology in project.technologies) {
      text(technology, 60, required: true);
    }
    add(validatePortfolioUrl(project.repositoryUrl));
    add(validatePortfolioUrl(project.liveUrl));
    if (project.imagePaths.length > portfolioProjectImageLimit) {
      issues.add(PortfolioValidationCode.invalidStructure);
    }
    for (final path in project.imagePaths) {
      add(validatePortfolioMediaPath(path, required: true));
    }
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
    add(validatePortfolioContactUrl(link.url, link.kind));
  }
  text(content.resumeText, 20000);
  if (content.documents.length > portfolioDocumentLimit) {
    issues.add(PortfolioValidationCode.invalidStructure);
  }
  ids(content.documents.map((document) => document.id));
  final libraryIds = content.projects.map((project) => project.id).toSet();
  final documentsById = {
    for (final document in content.documents) document.id: document,
  };
  for (final document in content.documents) {
    text(document.title, 120, required: true);
    if (!document.createdAt.isUtc ||
        !document.updatedAt.isUtc ||
        document.updatedAt.isBefore(document.createdAt)) {
      issues.add(PortfolioValidationCode.invalidStructure);
    }
    final snapshot = document.content;
    if (snapshot.documents.isNotEmpty ||
        snapshot.projects.isNotEmpty ||
        snapshot.ignoredGitHubRepositories.isNotEmpty) {
      issues.add(PortfolioValidationCode.invalidStructure);
    }
    // Невалидную вложенность не обходим рекурсивно; она уже отклонена выше.
    issues.addAll(validatePortfolioContent(seedDocumentContent(snapshot)));
    final base = document.baseSnapshot;
    if (base != null) {
      final data = developerProfileData(base);
      if (base != data) issues.add(PortfolioValidationCode.invalidStructure);
      issues.addAll(validatePortfolioContent(data));
    }
    ids(document.projects.map((attachment) => attachment.projectId));
    for (final attachment in document.projects) {
      final title = attachment.titleOverride;
      if (title != null) text(title, 120, required: true);
      final description = attachment.descriptionOverride;
      if (description != null) text(description, 4000);
      final contribution = attachment.contributionOverride;
      if (contribution != null) text(contribution, 4000);
    }
    if (document.projects.any(
      (attachment) => !libraryIds.contains(attachment.projectId),
    )) {
      issues.add(PortfolioValidationCode.invalidStructure);
    }
    final resumeId = document.attachedResumeId;
    if (resumeId != null) {
      text(resumeId, 200, required: true);
      if (document.kind != PortfolioDocumentKind.portfolio ||
          resumeId == document.id ||
          documentsById[resumeId]?.kind != PortfolioDocumentKind.resume) {
        issues.add(PortfolioValidationCode.invalidStructure);
      }
    }
  }
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
