import 'portfolio_collection_equality.dart';
import 'portfolio_content.dart';

/// Сколько снимков хранится на владельца; самые старые вытесняются.
const portfolioHistoryLimit = 20;

/// Снимок основного портфолио на момент успешного Save. Аватар не копируется:
/// хранится только флаг [hasAvatar]; восстановление сохраняет текущее фото.
final class PortfolioSnapshot {
  PortfolioSnapshot({
    required this.id,
    required DateTime savedAt,
    required this.content,
    List<PortfolioProjectAttachment> attachments = const [],
    this.hasAvatar = false,
  }) : savedAt = savedAt.toUtc(),
       attachments = List.unmodifiable(attachments);

  final String id;
  final DateTime savedAt;

  /// Разрешённое содержимое документа: проекты внутри, аватар очищен.
  final PortfolioContent content;

  /// Порядок и флаги проектов документа для восстановления.
  final List<PortfolioProjectAttachment> attachments;
  final bool hasAvatar;

  /// Равенство содержимого без учёта id и времени; нужно для дедупликации.
  bool sameContentAs(PortfolioSnapshot other) =>
      other.content == content &&
      other.hasAvatar == hasAvatar &&
      portfolioListEquals(other.attachments, attachments);
}

/// Снимок текущего main-документа; null — основного портфолио нет или оно
/// ссылается на проект, которого нет в Library.
PortfolioSnapshot? buildPortfolioSnapshot({
  required PortfolioContent workspace,
  required DateTime at,
  required String id,
}) {
  final document = mainPortfolioDocument(workspace);
  if (document == null) return null;
  final PortfolioContent resolved;
  try {
    resolved = resolveDocumentContent(workspace, document);
  } on ArgumentError {
    return null;
  }
  final profile = resolved.profile;
  return PortfolioSnapshot(
    id: id,
    savedAt: at,
    hasAvatar: profile.avatarPath.isNotEmpty || profile.avatarUrl.isNotEmpty,
    attachments: document.projects,
    content: resolved.copyWith(
      profile: profile.copyWith(avatarPath: '', avatarUrl: ''),
    ),
  );
}

/// Добавляет снимок новейшим первым. Равный последнему по содержимому
/// не добавляется; сверх [portfolioHistoryLimit] вытесняются самые старые.
List<PortfolioSnapshot> appendPortfolioSnapshot(
  List<PortfolioSnapshot> newestFirst,
  PortfolioSnapshot next,
) {
  if (newestFirst.isNotEmpty && newestFirst.first.sameContentAs(next)) {
    return newestFirst;
  }
  return List.unmodifiable([next, ...newestFirst].take(portfolioHistoryLimit));
}

/// Результат отката: документ для буфера Editor и число пропущенных проектов,
/// которых уже нет в Library.
final class PortfolioRestore {
  const PortfolioRestore({
    required this.document,
    required this.skippedProjects,
  });
  final PortfolioDocument document;
  final int skippedProjects;
}

/// Подставляет содержимое снимка в [current]; текущее фото сохраняется.
/// Ничего не пишет: результат попадает только в буфер Editor.
PortfolioRestore restorePortfolioSnapshot({
  required PortfolioContent workspace,
  required PortfolioDocument current,
  required PortfolioSnapshot snapshot,
}) {
  final library = {for (final project in workspace.projects) project.id};
  final attachments = [
    for (final item in snapshot.attachments)
      if (library.contains(item.projectId)) item,
  ];
  final avatar = current.content.profile;
  return PortfolioRestore(
    skippedProjects: snapshot.attachments.length - attachments.length,
    document: current.copyWith(
      content: snapshot.content.copyWith(
        projects: const [],
        profile: snapshot.content.profile.copyWith(
          avatarPath: avatar.avatarPath,
          avatarUrl: avatar.avatarUrl,
        ),
      ),
      projects: attachments,
    ),
  );
}

/// Содержимое снимка для просмотра: тот же вид, что у сохранённого Home.
PortfolioContent portfolioSnapshotView(PortfolioSnapshot snapshot) {
  final content = snapshot.content;
  return content.copyWith(
    profile: content.profile.copyWith(publishLocation: true),
    resumeText: '',
    blocks: mainPortfolioBlocks(content),
    projects: content.projects
        .where((project) => project.visible)
        .map((project) => project.copyWith(imagePaths: const []))
        .toList(),
    links: content.links
        .where((link) => link.visible && link.publishAllowed)
        .toList(),
  );
}

/// Краткая сводка: числа и что изменилось относительно [previous].
final class PortfolioSnapshotSummary {
  const PortfolioSnapshotSummary({
    required this.projects,
    required this.skills,
    required this.changes,
  });
  final int projects;
  final int skills;
  final List<PortfolioSnapshotChange> changes;
}

enum PortfolioSnapshotChangeKind {
  profile,
  projectsAdded,
  projectsRemoved,
  projectsEdited,
  skillsAdded,
  skillsRemoved,
  experience,
  education,
  contacts,
  layout,
}

final class PortfolioSnapshotChange {
  const PortfolioSnapshotChange(this.kind, [this.count = 0]);
  final PortfolioSnapshotChangeKind kind;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is PortfolioSnapshotChange &&
      other.kind == kind &&
      other.count == count;

  @override
  int get hashCode => Object.hash(kind, count);
}

PortfolioSnapshotSummary summarizePortfolioSnapshot(
  PortfolioSnapshot snapshot, {
  PortfolioSnapshot? previous,
}) {
  final now = snapshot.content;
  final before = previous?.content;
  final changes = <PortfolioSnapshotChange>[];
  if (before != null) {
    if (before.profile != now.profile) {
      changes.add(
        const PortfolioSnapshotChange(PortfolioSnapshotChangeKind.profile),
      );
    }
    final oldProjects = {for (final p in before.projects) p.id: p};
    final newProjects = {for (final p in now.projects) p.id: p};
    final added = newProjects.keys
        .where((id) => !oldProjects.containsKey(id))
        .length;
    final removed = oldProjects.keys
        .where((id) => !newProjects.containsKey(id))
        .length;
    final edited = newProjects.entries
        .where(
          (entry) =>
              oldProjects[entry.key] != null &&
              oldProjects[entry.key] != entry.value,
        )
        .length;
    if (added > 0) {
      changes.add(
        PortfolioSnapshotChange(
          PortfolioSnapshotChangeKind.projectsAdded,
          added,
        ),
      );
    }
    if (removed > 0) {
      changes.add(
        PortfolioSnapshotChange(
          PortfolioSnapshotChangeKind.projectsRemoved,
          removed,
        ),
      );
    }
    if (edited > 0) {
      changes.add(
        PortfolioSnapshotChange(
          PortfolioSnapshotChangeKind.projectsEdited,
          edited,
        ),
      );
    }
    final oldSkills = {for (final s in before.skills) s.name};
    final newSkills = {for (final s in now.skills) s.name};
    final skillsAdded = newSkills.difference(oldSkills).length;
    final skillsRemoved = oldSkills.difference(newSkills).length;
    if (skillsAdded > 0) {
      changes.add(
        PortfolioSnapshotChange(
          PortfolioSnapshotChangeKind.skillsAdded,
          skillsAdded,
        ),
      );
    }
    if (skillsRemoved > 0) {
      changes.add(
        PortfolioSnapshotChange(
          PortfolioSnapshotChangeKind.skillsRemoved,
          skillsRemoved,
        ),
      );
    }
    if (!portfolioListEquals(before.experience, now.experience)) {
      changes.add(
        const PortfolioSnapshotChange(PortfolioSnapshotChangeKind.experience),
      );
    }
    if (!portfolioListEquals(before.education, now.education)) {
      changes.add(
        const PortfolioSnapshotChange(PortfolioSnapshotChangeKind.education),
      );
    }
    if (!portfolioListEquals(before.links, now.links)) {
      changes.add(
        const PortfolioSnapshotChange(PortfolioSnapshotChangeKind.contacts),
      );
    }
    if (changes.isEmpty && !portfolioListEquals(before.blocks, now.blocks)) {
      changes.add(
        const PortfolioSnapshotChange(PortfolioSnapshotChangeKind.layout),
      );
    }
  }
  return PortfolioSnapshotSummary(
    projects: now.projects.length,
    skills: now.skills.length,
    changes: changes,
  );
}

/// Локальная история одного владельца (guest или UID). Только устройство.
abstract interface class PortfolioHistoryRepository {
  /// Новейшие первыми.
  Future<List<PortfolioSnapshot>> list();

  /// Сохраняет снимок main-документа; без документа ничего не делает.
  Future<void> record(PortfolioContent workspace, DateTime at);

  /// Удаляет все снимки владельца.
  Future<void> clear();
}

final class PortfolioHistoryFailure implements Exception {
  const PortfolioHistoryFailure();
}
