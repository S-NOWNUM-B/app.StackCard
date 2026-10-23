import 'dart:typed_data';

import '../../media/media.dart';
import '../domain/developer_card.dart';
import '../domain/document_publication.dart';

Never _invalid() =>
    throw const DeveloperCardFailure(DeveloperCardFailureKind.invalidData);
Map<String, dynamic> _map(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic> ||
      value.length != keys.length ||
      !value.keys.toSet().containsAll(keys)) {
    _invalid();
  }
  return value;
}

String _text(Object? value, int limit) {
  if (value is! String || value.length > limit) _invalid();
  return value;
}

List<dynamic> _list(Object? value, [int maximum = 200]) {
  if (value is! List || value.length > maximum) _invalid();
  return value;
}

/// Читает только поля карточки из public1/2. Остальной snapshot не копируется.
DeveloperCard decodeDeveloperCard(
  Object? raw,
  DocumentPublication publication, {
  Uint8List? avatarBytes,
}) {
  developerCardPublicUrl(publication);
  final data = _map(raw, {
    'schemaVersion',
    'publicId',
    'version',
    'title',
    'kind',
    'attachedResumePublicId',
    'publishedAt',
    'content',
  });
  if (data['schemaVersion'] is! int ||
      !{1, 2}.contains(data['schemaVersion']) ||
      data['publicId'] != publication.publicId ||
      data['version'] is! int ||
      data['kind'] != 'portfolio') {
    _invalid();
  }
  if (data['version'] != publication.version) {
    throw const DeveloperCardFailure(DeveloperCardFailureKind.stale);
  }
  final date = _text(data['publishedAt'], 40);
  if (!date.endsWith('Z') || DateTime.tryParse(date) == null) _invalid();
  if (data['schemaVersion'] == 2 && data['attachedResumePublicId'] != null) {
    _invalid();
  }
  final content = _map(data['content'], {
    'profile',
    'skills',
    'projects',
    'experience',
    'education',
    'links',
    'blocks',
    'resumeText',
    'theme',
  });
  final profile = _map(content['profile'], {
    'name',
    'username',
    'headline',
    'bio',
    'locationText',
    'avatarUrl',
  });
  final name = _text(profile['name'], 100),
      headline = _text(profile['headline'], 160);
  final username = _text(profile['username'], 30);
  if (username.isNotEmpty &&
      !RegExp(r'^[a-z0-9][a-z0-9-]{1,28}[a-z0-9]$').hasMatch(username)) {
    _invalid();
  }
  final visible = <String>{};
  const kinds = {
    'profile',
    'about',
    'location',
    'links',
    'github',
    'skills',
    'featuredProjects',
    'experience',
    'education',
    'resume',
  };
  for (final rawBlock in _list(content['blocks'], 10)) {
    final block = _map(rawBlock, {'kind', 'visible'});
    if (!kinds.contains(block['kind']) ||
        block['visible'] != true ||
        !visible.add(block['kind'] as String)) {
      _invalid();
    }
  }
  final avatar = _text(profile['avatarUrl'], 350000);
  final skills = _list(content['skills']),
      projects = _list(content['projects']);
  if ((!visible.contains('profile') &&
          [name, headline, username, avatar].any((v) => v.isNotEmpty)) ||
      (!visible.contains('skills') && skills.isNotEmpty) ||
      (!visible.contains('featuredProjects') && projects.isNotEmpty)) {
    _invalid();
  }
  final technologies = <String>{};
  for (final rawSkill in skills) {
    final skill = _map(rawSkill, {'id', 'name'});
    _text(skill['id'], 200);
    final technology = _text(skill['name'], 60);
    if (technology.trim().isEmpty) _invalid();
    technologies.add(technology);
  }
  for (final project in projects) {
    if (project is! Map || project['visible'] != true) _invalid();
    for (final rawTechnology in _list(project['technologies'], 20)) {
      final technology = _text(rawTechnology, 60);
      if (technology.trim().isEmpty) _invalid();
      technologies.add(technology);
    }
  }
  Uint8List? inline;
  if (avatar.startsWith('data:image/jpeg;base64,')) {
    try {
      inline = decodeFirestorePortfolioImage({
        'schemaVersion': 1,
        'contentType': 'image/jpeg',
        'base64': avatar.substring(23),
      });
      if (inline.length < 5 ||
          inline[0] != 0xff ||
          inline[1] != 0xd8 ||
          inline[2] != 0xff ||
          inline[inline.length - 2] != 0xff ||
          inline.last != 0xd9) {
        _invalid();
      }
    } catch (_) {
      _invalid();
    }
  } else if (avatar.isNotEmpty) {
    final storage = RegExp(
      '^publicMedia/${publication.publicId}/${publication.version}/[a-f0-9]{32}\\.jpg\$',
    ).hasMatch(avatar);
    final uri = Uri.tryParse(avatar);
    final external =
        uri != null &&
        uri.scheme == 'https' &&
        const {
          'avatars.githubusercontent.com',
          'images.unsplash.com',
        }.contains(uri.host) &&
        uri.userInfo.isEmpty &&
        !uri.hasPort;
    if (!storage && !external) _invalid();
  }
  return DeveloperCard(
    publication: publication,
    title: _text(data['title'], 120),
    name: name,
    headline: headline,
    username: username,
    technologies: technologies,
    avatarSource: avatar,
    avatarBytes: avatarBytes ?? inline,
  );
}
