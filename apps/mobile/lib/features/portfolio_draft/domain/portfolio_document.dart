import 'portfolio_collection_equality.dart';
import 'portfolio_content.dart';

enum PortfolioDocumentKind { resume, portfolio }

// Firestore Rules проверяют owner каждого snapshot в ограниченном списке.
const portfolioDocumentLimit = 20;

/// Проект остаётся в Library; документ хранит связь, флаги и свой текст.
final class PortfolioProjectAttachment {
  const PortfolioProjectAttachment({
    required this.projectId,
    this.visible = true,
    this.featured = false,
    this.titleOverride,
    this.descriptionOverride,
    this.contributionOverride,
  });

  final String projectId;
  final bool visible;
  final bool featured;

  /// null наследует Library; пустой текст явно убирает описание или вклад.
  final String? titleOverride;
  final String? descriptionOverride;
  final String? contributionOverride;

  PortfolioProjectAttachment copyWith({
    String? projectId,
    bool? visible,
    bool? featured,
    String? titleOverride,
    String? descriptionOverride,
    String? contributionOverride,
    bool clearTitleOverride = false,
    bool clearDescriptionOverride = false,
    bool clearContributionOverride = false,
  }) => PortfolioProjectAttachment(
    projectId: projectId ?? this.projectId,
    visible: visible ?? this.visible,
    featured: featured ?? this.featured,
    titleOverride: clearTitleOverride
        ? null
        : titleOverride ?? this.titleOverride,
    descriptionOverride: clearDescriptionOverride
        ? null
        : descriptionOverride ?? this.descriptionOverride,
    contributionOverride: clearContributionOverride
        ? null
        : contributionOverride ?? this.contributionOverride,
  );

  @override
  bool operator ==(Object other) =>
      other is PortfolioProjectAttachment &&
      other.projectId == projectId &&
      other.visible == visible &&
      other.featured == featured &&
      other.titleOverride == titleOverride &&
      other.descriptionOverride == descriptionOverride &&
      other.contributionOverride == contributionOverride;

  @override
  int get hashCode => Object.hash(
    projectId,
    visible,
    featured,
    titleOverride,
    descriptionOverride,
    contributionOverride,
  );
}

/// Независимый snapshot профиля/секций; изменения общей базы его не меняют.
final class PortfolioDocument {
  PortfolioDocument({
    required this.id,
    required this.title,
    required this.kind,
    required this.createdAt,
    required this.updatedAt,
    required this.content,
    this.baseSnapshot,
    List<PortfolioProjectAttachment> projects = const [],
    this.attachedResumeId,
  }) : projects = List.unmodifiable(projects);

  final String id;
  final String title;
  final PortfolioDocumentKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PortfolioContent content;

  /// Последняя явно просмотренная база; null у документов старого формата.
  final PortfolioContent? baseSnapshot;
  final List<PortfolioProjectAttachment> projects;
  final String? attachedResumeId;

  PortfolioDocument copyWith({
    String? id,
    String? title,
    PortfolioDocumentKind? kind,
    DateTime? createdAt,
    DateTime? updatedAt,
    PortfolioContent? content,
    PortfolioContent? baseSnapshot,
    List<PortfolioProjectAttachment>? projects,
    String? attachedResumeId,
    bool clearAttachedResumeId = false,
  }) => PortfolioDocument(
    id: id ?? this.id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    content: content ?? this.content,
    baseSnapshot: baseSnapshot ?? this.baseSnapshot,
    projects: projects ?? this.projects,
    attachedResumeId: clearAttachedResumeId
        ? null
        : attachedResumeId ?? this.attachedResumeId,
  );

  @override
  bool operator ==(Object other) =>
      other is PortfolioDocument &&
      other.id == id &&
      other.title == title &&
      other.kind == kind &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.content == content &&
      other.baseSnapshot == baseSnapshot &&
      other.attachedResumeId == attachedResumeId &&
      portfolioListEquals(other.projects, projects);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    kind,
    createdAt,
    updatedAt,
    content,
    baseSnapshot,
    attachedResumeId,
    Object.hashAll(projects),
  );
}

/// Только явное создание документа копирует текущие значения общей базы.
PortfolioContent seedDocumentContent(PortfolioContent workspace) =>
    workspace.copyWith(
      projects: const [],
      documents: const [],
      ignoredGitHubRepositories: const [],
    );

/// Порядок и флаги принадлежат документу, содержимое проектов — общей Library.
PortfolioContent resolveDocumentContent(
  PortfolioContent workspace,
  PortfolioDocument document,
) {
  final library = {
    for (final project in workspace.projects) project.id: project,
  };
  return seedDocumentContent(document.content).copyWith(
    projects: document.projects.map((attachment) {
      final project = library[attachment.projectId];
      if (project == null) {
        throw ArgumentError.value(
          attachment.projectId,
          'projectId',
          'Проект отсутствует в Library',
        );
      }
      return project.copyWith(
        title: attachment.titleOverride,
        description: attachment.descriptionOverride,
        contribution: attachment.contributionOverride,
        visible: attachment.visible,
        featured: attachment.featured,
      );
    }).toList(),
  );
}
