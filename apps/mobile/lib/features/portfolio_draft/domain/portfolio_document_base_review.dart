import 'portfolio_content.dart';

enum PortfolioDocumentBaseField {
  name,
  username,
  headline,
  bio,
  locationText,
  publishLocation,
  avatar,
  skills,
  experience,
  education,
  links,
}

/// Сравнение одной строки профиля или одного stable-ID элемента коллекции.
final class PortfolioDocumentBaseChange {
  const PortfolioDocumentBaseChange._({
    required this.field,
    this.itemId,
    required this.previousValue,
    required this.currentValue,
    required this.incomingValue,
    required this.hasLocalOverride,
    required this.defaultSelected,
  });

  final PortfolioDocumentBaseField field;
  final String? itemId;
  final Object? previousValue;
  final Object? currentValue;
  final Object? incomingValue;
  final bool hasLocalOverride;
  final bool defaultSelected;
  String get key => '${field.name}:${itemId ?? ''}';
}

/// Captured diff не читает storage и меняет только буфер выбранного документа.
final class PortfolioDocumentBaseReview {
  factory PortfolioDocumentBaseReview({
    required PortfolioDocument document,
    required PortfolioContent base,
  }) {
    final captured = developerProfileData(base);
    final previous = document.baseSnapshot;
    final changes = <PortfolioDocumentBaseChange>[];
    void add(
      PortfolioDocumentBaseField field,
      String? id,
      Object? old,
      Object? local,
      Object? incoming,
    ) {
      if (local == incoming || (previous != null && old == incoming)) return;
      final override = previous == null || local != old;
      changes.add(
        PortfolioDocumentBaseChange._(
          field: field,
          itemId: id,
          previousValue: old,
          currentValue: local,
          incomingValue: incoming,
          hasLocalOverride: override,
          defaultSelected: !override,
        ),
      );
    }

    final oldProfile = previous == null
        ? <PortfolioDocumentBaseField, Object>{}
        : _profileValues(previous.profile);
    final localProfile = _profileValues(document.content.profile);
    for (final entry in _profileValues(captured.profile).entries) {
      add(
        entry.key,
        null,
        oldProfile[entry.key],
        localProfile[entry.key],
        entry.value,
      );
    }

    void items<T>(
      PortfolioDocumentBaseField field,
      List<T> old,
      List<T> local,
      List<T> incoming,
      String Function(T) id,
    ) {
      final oldById = {for (final item in old) id(item): item};
      final localById = {for (final item in local) id(item): item};
      final incomingById = {for (final item in incoming) id(item): item};
      // У legacy неизвестна прежняя база: не предлагаем удалить local-only записи.
      for (final key in {...oldById.keys, ...incomingById.keys}) {
        add(field, key, oldById[key], localById[key], incomingById[key]);
      }
    }

    items(
      PortfolioDocumentBaseField.skills,
      previous?.skills ?? [],
      document.content.skills,
      captured.skills,
      (item) => item.id,
    );
    items(
      PortfolioDocumentBaseField.experience,
      previous?.experience ?? [],
      document.content.experience,
      captured.experience,
      (item) => item.id,
    );
    items(
      PortfolioDocumentBaseField.education,
      previous?.education ?? [],
      document.content.education,
      captured.education,
      (item) => item.id,
    );
    items(
      PortfolioDocumentBaseField.links,
      previous?.links ?? [],
      document.content.links,
      captured.links,
      (item) => item.id,
    );
    return PortfolioDocumentBaseReview._(
      document,
      captured,
      List.unmodifiable(changes),
    );
  }

  const PortfolioDocumentBaseReview._(this.document, this.base, this.changes);
  final PortfolioDocument document;
  final PortfolioContent base;
  final List<PortfolioDocumentBaseChange> changes;
  bool get hasBaseline => document.baseSnapshot != null;

  PortfolioDocument apply(Set<String> selectedKeys) {
    final validKeys = changes.map((change) => change.key).toSet();
    if (!validKeys.containsAll(selectedKeys)) {
      throw ArgumentError.value(
        selectedKeys,
        'selectedKeys',
        'Неизвестное изменение базы',
      );
    }
    bool selected(PortfolioDocumentBaseField field) =>
        selectedKeys.contains('${field.name}:');
    final local = document.content;
    final profile = local.profile;
    final incoming = base.profile;
    final content = local.copyWith(
      profile: profile.copyWith(
        name: selected(PortfolioDocumentBaseField.name) ? incoming.name : null,
        username: selected(PortfolioDocumentBaseField.username)
            ? incoming.username
            : null,
        headline: selected(PortfolioDocumentBaseField.headline)
            ? incoming.headline
            : null,
        bio: selected(PortfolioDocumentBaseField.bio) ? incoming.bio : null,
        locationText: selected(PortfolioDocumentBaseField.locationText)
            ? incoming.locationText
            : null,
        publishLocation: selected(PortfolioDocumentBaseField.publishLocation)
            ? incoming.publishLocation
            : null,
        avatarUrl: selected(PortfolioDocumentBaseField.avatar)
            ? incoming.avatarUrl
            : null,
        avatarPath: selected(PortfolioDocumentBaseField.avatar)
            ? incoming.avatarPath
            : null,
      ),
      skills: _mergeItems(
        PortfolioDocumentBaseField.skills,
        local.skills,
        base.skills,
        (item) => item.id,
        selectedKeys,
      ),
      experience: _mergeItems(
        PortfolioDocumentBaseField.experience,
        local.experience,
        base.experience,
        (item) => item.id,
        selectedKeys,
      ),
      education: _mergeItems(
        PortfolioDocumentBaseField.education,
        local.education,
        base.education,
        (item) => item.id,
        selectedKeys,
      ),
      links: _mergeItems(
        PortfolioDocumentBaseField.links,
        local.links,
        base.links.map((incoming) {
          final matches = local.links.where((link) => link.id == incoming.id);
          // Выбор контакта принадлежит документу и не меняется от refresh базы.
          return matches.isEmpty
              ? incoming
              : incoming.copyWith(visible: matches.single.visible);
        }).toList(),
        (item) => item.id,
        selectedKeys,
      ),
    );
    // Невыбранные изменения считаются просмотренными и остаются local overrides.
    return document.copyWith(content: content, baseSnapshot: base);
  }
}

Map<PortfolioDocumentBaseField, Object> _profileValues(
  PortfolioProfile profile,
) => {
  PortfolioDocumentBaseField.name: profile.name,
  PortfolioDocumentBaseField.username: profile.username,
  PortfolioDocumentBaseField.headline: profile.headline,
  PortfolioDocumentBaseField.bio: profile.bio,
  PortfolioDocumentBaseField.locationText: profile.locationText,
  PortfolioDocumentBaseField.publishLocation: profile.publishLocation,
  PortfolioDocumentBaseField.avatar: (profile.avatarUrl, profile.avatarPath),
};

List<T> _mergeItems<T>(
  PortfolioDocumentBaseField field,
  List<T> local,
  List<T> incoming,
  String Function(T) id,
  Set<String> selectedKeys,
) {
  final incomingById = {for (final item in incoming) id(item): item};
  final localIds = local.map(id).toSet();
  bool selected(String itemId) =>
      selectedKeys.contains('${field.name}:$itemId');
  return [
    for (final item in local)
      if (!selected(id(item))) item else ?incomingById[id(item)],
    for (final item in incoming)
      if (!localIds.contains(id(item)) && selected(id(item))) item,
  ];
}
