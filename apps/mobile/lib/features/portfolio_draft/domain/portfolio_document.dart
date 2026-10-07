import 'portfolio_collection_equality.dart';
import 'portfolio_content.dart';

enum PortfolioDocumentKind { resume, portfolio }

// Firestore Rules проверяют owner каждого snapshot в ограниченном списке.
const portfolioDocumentLimit = 20;

/// Проект остаётся в общей Library; документ хранит только связь и свои флаги.
final class PortfolioProjectAttachment {
  const PortfolioProjectAttachment({
    required this.projectId,
    this.visible = true,
    this.featured = false,
  });

  final String projectId;
  final bool visible;
  final bool featured;

  PortfolioProjectAttachment copyWith({
    String? projectId,
    bool? visible,
    bool? featured,
  }) => PortfolioProjectAttachment(
    projectId: projectId ?? this.projectId,
    visible: visible ?? this.visible,
    featured: featured ?? this.featured,
  );

  @override
  bool operator ==(Object other) =>
      other is PortfolioProjectAttachment &&
      other.projectId == projectId &&
      other.visible == visible &&
      other.featured == featured;

  @override
  int get hashCode => Object.hash(projectId, visible, featured);
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
    List<PortfolioProjectAttachment> projects = const [],
    this.attachedResumeId,
  }) : projects = List.unmodifiable(projects);

  final String id;
  final String title;
  final PortfolioDocumentKind kind;
  final DateTime createdAt;
  final DateTime updatedAt;
  final PortfolioContent content;
  final List<PortfolioProjectAttachment> projects;
  final String? attachedResumeId;

  PortfolioDocument copyWith({
    String? id,
    String? title,
    PortfolioDocumentKind? kind,
    DateTime? createdAt,
    DateTime? updatedAt,
    PortfolioContent? content,
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
        visible: attachment.visible,
        featured: attachment.featured,
      );
    }).toList(),
  );
}
