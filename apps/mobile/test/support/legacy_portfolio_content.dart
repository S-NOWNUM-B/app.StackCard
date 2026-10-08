/// Fixtures прошлых schemas не должны случайно получать новые writer keys.
void removePresentationPrivacyFields(Map<String, Object?> content) {
  (content['profile'] as Map?)?.remove('publishLocation');
  for (final project in content['projects'] as List? ?? []) {
    (project as Map).remove('contribution');
  }
  for (final link in content['links'] as List? ?? []) {
    (link as Map).remove('publishAllowed');
    link.remove('visible');
  }
  for (final document in content['documents'] as List? ?? []) {
    final item = document as Map;
    for (final attachment in item['projects'] as List? ?? []) {
      (attachment as Map).remove('titleOverride');
      attachment.remove('descriptionOverride');
      attachment.remove('contributionOverride');
    }
    removePresentationPrivacyFields(
      Map<String, Object?>.from(item['content'] as Map),
    );
    if (item['baseSnapshot'] case final Map base) {
      removePresentationPrivacyFields(Map<String, Object?>.from(base));
    }
  }
}
