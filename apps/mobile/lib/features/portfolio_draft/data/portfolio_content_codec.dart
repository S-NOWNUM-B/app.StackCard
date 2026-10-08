import '../domain/portfolio_content.dart';
import '../domain/portfolio_validation.dart';
import '../domain/portfolio_github_sync.dart';

Map<String, Object?> encodePortfolioContent(
  PortfolioContent content, {
  bool includeDocuments = true,
}) => {
  'profile': {
    'name': content.profile.name,
    'username': content.profile.username,
    'headline': content.profile.headline,
    'bio': content.profile.bio,
    'locationText': content.profile.locationText,
    'publishLocation': content.profile.publishLocation,
    'avatarUrl': content.profile.avatarUrl,
    'avatarPath': content.profile.avatarPath,
  },
  'skills': content.skills
      .map((item) => {'id': item.id, 'name': item.name})
      .toList(),
  'projects': content.projects
      .map(
        (item) => {
          'id': item.id,
          'title': item.title,
          'description': item.description,
          'contribution': item.contribution,
          'technologies': item.technologies,
          'repositoryUrl': item.repositoryUrl,
          'liveUrl': item.liveUrl,
          'featured': item.featured,
          'visible': item.visible,
          'imagePaths': item.imagePaths,
          if (item.updatedAt != null)
            'updatedAt': item.updatedAt!.toIso8601String(),
          'source': item.source.name,
          'githubMetadata': item.githubMetadata == null
              ? null
              : encodeGitHubProjectMetadata(item.githubMetadata!),
        },
      )
      .toList(),
  'experience': content.experience
      .map(
        (item) => {
          'id': item.id,
          'role': item.role,
          'organization': item.organization,
          'period': item.period,
          'description': item.description,
        },
      )
      .toList(),
  'education': content.education
      .map(
        (item) => {
          'id': item.id,
          'institution': item.institution,
          'qualification': item.qualification,
          'period': item.period,
          'description': item.description,
        },
      )
      .toList(),
  'links': content.links
      .map(
        (item) => {
          'id': item.id,
          'label': item.label,
          'url': item.url,
          'kind': item.kind.name,
          'publishAllowed': item.publishAllowed,
          'visible': item.visible,
        },
      )
      .toList(),
  'blocks': content.blocks
      .map((item) => {'kind': item.kind.name, 'visible': item.visible})
      .toList(),
  'resumeText': content.resumeText,
  'theme': content.theme.name,
  'ignoredGitHubRepositories': content.ignoredGitHubRepositories
      .map(
        (item) => {
          'repositoryId': item.repositoryId,
          'fingerprint': item.fingerprint,
        },
      )
      .toList(),
  if (includeDocuments)
    'documents': content.documents.map(_encodePortfolioDocument).toList(),
};

Map<String, Object?> _encodePortfolioDocument(PortfolioDocument document) {
  final snapshot = document.content;
  if (snapshot.documents.isNotEmpty ||
      snapshot.projects.isNotEmpty ||
      snapshot.ignoredGitHubRepositories.isNotEmpty) {
    throw const FormatException('Документ содержит вложенную базу');
  }
  return {
    'id': document.id,
    'title': document.title,
    'kind': document.kind.name,
    'createdAt': document.createdAt.toIso8601String(),
    'updatedAt': document.updatedAt.toIso8601String(),
    'content': encodePortfolioContent(snapshot, includeDocuments: false),
    'projects': document.projects
        .map(
          (attachment) => {
            'projectId': attachment.projectId,
            'visible': attachment.visible,
            'featured': attachment.featured,
            'titleOverride': attachment.titleOverride,
            'descriptionOverride': attachment.descriptionOverride,
            'contributionOverride': attachment.contributionOverride,
          },
        )
        .toList(),
    'attachedResumeId': document.attachedResumeId,
    if (document.baseSnapshot != null)
      'baseSnapshot': _encodeBaseSnapshot(document.baseSnapshot!),
  };
}

Map<String, Object?> _encodeBaseSnapshot(PortfolioContent snapshot) {
  if (snapshot != developerProfileData(snapshot) ||
      validatePortfolioContent(snapshot).isNotEmpty) {
    throw const FormatException('Некорректный snapshot общей базы');
  }
  final encoded = encodePortfolioContent(snapshot, includeDocuments: false);
  return {
    for (final key in ['profile', 'skills', 'experience', 'education', 'links'])
      key: encoded[key],
  };
}

PortfolioContent _decodeBaseSnapshot(
  Object? raw, {
  required bool allowPresentationPrivacy,
}) {
  final json = _map(raw);
  _fields(json, {'profile', 'skills', 'experience', 'education', 'links'});
  _fields(_map(json['profile']), {
    'name',
    'username',
    'headline',
    'bio',
    'locationText',
    'avatarUrl',
    'avatarPath',
    if (allowPresentationPrivacy &&
        _map(json['profile']).containsKey('publishLocation'))
      'publishLocation',
  });
  for (final key in ['skills', 'experience', 'education', 'links']) {
    for (final item in _list(json, key)) {
      final fields = switch (key) {
        'skills' => {'id', 'name'},
        'experience' => {'id', 'role', 'organization', 'period', 'description'},
        'education' => {
          'id',
          'institution',
          'qualification',
          'period',
          'description',
        },
        _ => {
          'id',
          'label',
          'url',
          'kind',
          if (allowPresentationPrivacy &&
              _map(item).containsKey('publishAllowed'))
            'publishAllowed',
          if (allowPresentationPrivacy && _map(item).containsKey('visible'))
            'visible',
        },
      };
      _fields(_map(item), fields);
    }
  }
  return decodePortfolioContent(
    {
      ...encodePortfolioContent(PortfolioContent(), includeDocuments: false),
      ...json,
    },
    allowDocuments: false,
    allowPresentationPrivacy: allowPresentationPrivacy,
  );
}

PortfolioDocument _decodePortfolioDocument(
  Object? raw, {
  required bool allowBaseSnapshot,
  required bool allowPresentationPrivacy,
}) {
  final item = _map(raw);
  _fields(item, {
    'id',
    'title',
    'kind',
    'createdAt',
    'updatedAt',
    'content',
    'projects',
    'attachedResumeId',
    if (allowBaseSnapshot && item.containsKey('baseSnapshot')) 'baseSnapshot',
  });
  final rawSnapshot = _map(item['content']);
  _fields(rawSnapshot, {
    'profile',
    'skills',
    'projects',
    'experience',
    'education',
    'links',
    'blocks',
    'resumeText',
    'theme',
    'ignoredGitHubRepositories',
  });
  _fields(_map(rawSnapshot['profile']), {
    'name',
    'username',
    'headline',
    'bio',
    'locationText',
    'avatarUrl',
    'avatarPath',
    if (allowPresentationPrivacy &&
        _map(rawSnapshot['profile']).containsKey('publishLocation'))
      'publishLocation',
  });
  final snapshot = decodePortfolioContent(
    rawSnapshot,
    allowDocuments: false,
    allowPresentationPrivacy: allowPresentationPrivacy,
  );
  if (snapshot.projects.isNotEmpty ||
      snapshot.ignoredGitHubRepositories.isNotEmpty) {
    throw const FormatException('Документ содержит копии проектов');
  }
  return PortfolioDocument(
    id: _string(item, 'id'),
    title: _string(item, 'title'),
    kind: _enum(item, 'kind', PortfolioDocumentKind.values),
    createdAt: _utcDate(item['createdAt']),
    updatedAt: _utcDate(item['updatedAt']),
    content: snapshot,
    projects: _list(item, 'projects').map((raw) {
      final attachment = _map(raw);
      _fields(attachment, {
        'projectId',
        'visible',
        'featured',
        if (allowPresentationPrivacy && attachment.containsKey('titleOverride'))
          'titleOverride',
        if (allowPresentationPrivacy &&
            attachment.containsKey('descriptionOverride'))
          'descriptionOverride',
        if (allowPresentationPrivacy &&
            attachment.containsKey('contributionOverride'))
          'contributionOverride',
      });
      return PortfolioProjectAttachment(
        projectId: _string(attachment, 'projectId'),
        visible: _bool(attachment, 'visible'),
        featured: _bool(attachment, 'featured'),
        titleOverride: _nullableString(attachment, 'titleOverride'),
        descriptionOverride: _nullableString(attachment, 'descriptionOverride'),
        contributionOverride: _nullableString(
          attachment,
          'contributionOverride',
        ),
      );
    }).toList(),
    attachedResumeId: _nullableString(item, 'attachedResumeId'),
    baseSnapshot: item['baseSnapshot'] == null
        ? null
        : _decodeBaseSnapshot(
            item['baseSnapshot'],
            allowPresentationPrivacy: allowPresentationPrivacy,
          ),
  );
}

PortfolioContent decodePortfolioContent(
  Object? raw, {
  bool allowMedia = true,
  bool allowDocuments = true,
  bool allowBaseSnapshot = true,
  bool allowPresentationPrivacy = true,
}) {
  final json = _map(raw);
  if (!allowDocuments && json.containsKey('documents')) {
    throw const FormatException('Документы требуют новую версию draft');
  }
  final profile = _map(json['profile']);
  if (!allowMedia && profile.containsKey('avatarPath')) {
    throw const FormatException('Media требует новую версию draft');
  }
  if (!allowPresentationPrivacy && profile.containsKey('publishLocation')) {
    throw const FormatException('Privacy требует новую версию draft');
  }
  final content = PortfolioContent(
    profile: PortfolioProfile(
      name: _string(profile, 'name'),
      username: _string(profile, 'username'),
      headline: _string(profile, 'headline'),
      bio: _string(profile, 'bio'),
      locationText: _string(profile, 'locationText'),
      publishLocation: profile.containsKey('publishLocation')
          ? _bool(profile, 'publishLocation')
          : false,
      avatarUrl: _string(profile, 'avatarUrl'),
      avatarPath: profile.containsKey('avatarPath')
          ? _string(profile, 'avatarPath')
          : '',
    ),
    skills: _list(json, 'skills').map((raw) {
      final item = _map(raw);
      return Skill(id: _string(item, 'id'), name: _string(item, 'name'));
    }).toList(),
    experience: _list(json, 'experience').map((raw) {
      final item = _map(raw);
      return Experience(
        id: _string(item, 'id'),
        role: _string(item, 'role'),
        organization: _string(item, 'organization'),
        period: _string(item, 'period'),
        description: _string(item, 'description'),
      );
    }).toList(),
    education: _list(json, 'education').map((raw) {
      final item = _map(raw);
      return Education(
        id: _string(item, 'id'),
        institution: _string(item, 'institution'),
        qualification: _string(item, 'qualification'),
        period: _string(item, 'period'),
        description: _string(item, 'description'),
      );
    }).toList(),
    links: _list(json, 'links').map((raw) {
      final item = _map(raw);
      if (!allowPresentationPrivacy &&
          (item.containsKey('publishAllowed') ||
              item.containsKey('visible') ||
              !const [
                'other',
                'github',
                'website',
                'linkedin',
              ].contains(item['kind']))) {
        throw const FormatException('Contacts требуют новую версию draft');
      }
      _fields(item, {
        'id',
        'label',
        'url',
        'kind',
        if (item.containsKey('publishAllowed')) 'publishAllowed',
        if (item.containsKey('visible')) 'visible',
      });
      return SocialLink(
        id: _string(item, 'id'),
        label: _string(item, 'label'),
        url: _string(item, 'url'),
        kind: _enum(item, 'kind', SocialLinkKind.values),
        publishAllowed: item.containsKey('publishAllowed')
            ? _bool(item, 'publishAllowed')
            : false,
        visible: item.containsKey('visible') ? _bool(item, 'visible') : true,
      );
    }).toList(),
    projects: _list(json, 'projects').map((raw) {
      final item = _map(raw);
      if (!allowMedia && item.containsKey('imagePaths')) {
        throw const FormatException('Media требует новую версию draft');
      }
      if (!allowPresentationPrivacy && item.containsKey('contribution')) {
        throw const FormatException(
          'Project presentation требует новую версию draft',
        );
      }
      return PortfolioProject(
        id: _string(item, 'id'),
        title: _string(item, 'title'),
        description: _string(item, 'description'),
        contribution: item.containsKey('contribution')
            ? _string(item, 'contribution')
            : '',
        technologies: _list(item, 'technologies').map((value) {
          if (value is! String) {
            throw const FormatException('Некорректная технология');
          }
          return value;
        }).toList(),
        repositoryUrl: _string(item, 'repositoryUrl'),
        liveUrl: _string(item, 'liveUrl'),
        featured: _bool(item, 'featured'),
        visible: _bool(item, 'visible'),
        updatedAt: item['updatedAt'] == null
            ? null
            : _utcDate(item['updatedAt']),
        imagePaths: !item.containsKey('imagePaths')
            ? const []
            : _list(item, 'imagePaths').map((value) {
                if (value is! String) {
                  throw const FormatException('Некорректный путь изображения');
                }
                return value;
              }).toList(),
        source: item.containsKey('source')
            ? _enum(item, 'source', PortfolioProjectSource.values)
            : PortfolioProjectSource.manual,
        githubMetadata: item['githubMetadata'] == null
            ? null
            : decodeGitHubProjectMetadata(item['githubMetadata']),
      );
    }).toList(),
    blocks: _list(json, 'blocks').map((raw) {
      final item = _map(raw);
      return PortfolioBlock(
        kind: _enum(item, 'kind', PortfolioBlockKind.values),
        visible: _bool(item, 'visible'),
      );
    }).toList(),
    resumeText: _string(json, 'resumeText'),
    theme: _enum(json, 'theme', PortfolioTheme.values),
    ignoredGitHubRepositories: !json.containsKey('ignoredGitHubRepositories')
        ? const []
        : _list(json, 'ignoredGitHubRepositories').map((raw) {
            final item = _map(raw);
            _fields(item, {'repositoryId', 'fingerprint'});
            return GitHubIgnoredRepository(
              repositoryId: _integer(item, 'repositoryId'),
              fingerprint: _string(item, 'fingerprint'),
            );
          }).toList(),
    documents: !json.containsKey('documents')
        ? const []
        : _list(json, 'documents')
              .map(
                (raw) => _decodePortfolioDocument(
                  raw,
                  allowBaseSnapshot: allowBaseSnapshot,
                  allowPresentationPrivacy: allowPresentationPrivacy,
                ),
              )
              .toList(),
  );
  if (validatePortfolioContent(content).isNotEmpty) {
    throw const FormatException('Некорректный Builder content');
  }
  return content;
}

Map<String, Object?> encodeGitHubProjectMetadata(
  GitHubProjectMetadata metadata,
) => {
  'acceptedSource': encodeGitHubProjectSource(metadata.acceptedSource),
  'lastGitHubSyncAt': metadata.lastGitHubSyncAt?.toIso8601String(),
  'overrideFields': PortfolioGitHubField.values
      .where(metadata.overrideFields.contains)
      .map((field) => field.name)
      .toList(),
};

Map<String, Object?> encodeGitHubProjectSource(GitHubProjectSource source) => {
  'repositoryId': source.repositoryId,
  'name': source.name,
  'fullName': source.fullName,
  'htmlUrl': source.htmlUrl,
  'description': source.description,
  'language': source.language,
  'stars': source.stars,
  'forks': source.forks,
  'isFork': source.isFork,
  'archived': source.archived,
  'updatedAt': source.updatedAt.toIso8601String(),
};

GitHubProjectMetadata decodeGitHubProjectMetadata(Object? raw) {
  final item = _map(raw);
  _fields(item, {'acceptedSource', 'lastGitHubSyncAt', 'overrideFields'});
  final overrides = <PortfolioGitHubField>{};
  for (final rawField in _list(item, 'overrideFields')) {
    final field = _enum(
      {'field': rawField},
      'field',
      PortfolioGitHubField.values,
    );
    if (!overrides.add(field)) {
      throw const FormatException('Duplicate override');
    }
  }
  return GitHubProjectMetadata(
    acceptedSource: decodeGitHubProjectSource(item['acceptedSource']),
    lastGitHubSyncAt: item['lastGitHubSyncAt'] == null
        ? null
        : _utcDate(item['lastGitHubSyncAt']),
    overrideFields: overrides,
  );
}

GitHubProjectSource decodeGitHubProjectSource(Object? raw) {
  final item = _map(raw);
  _fields(item, {
    'repositoryId',
    'name',
    'fullName',
    'htmlUrl',
    'description',
    'language',
    'stars',
    'forks',
    'isFork',
    'archived',
    'updatedAt',
  });
  final source = GitHubProjectSource(
    repositoryId: _integer(item, 'repositoryId'),
    name: _string(item, 'name'),
    fullName: _string(item, 'fullName'),
    htmlUrl: _string(item, 'htmlUrl'),
    description: _nullableString(item, 'description'),
    language: _nullableString(item, 'language'),
    stars: _integer(item, 'stars'),
    forks: _integer(item, 'forks'),
    isFork: _bool(item, 'isFork'),
    archived: _bool(item, 'archived'),
    updatedAt: _utcDate(item['updatedAt']),
  );
  if (validatePortfolioGitHubSource(source).isNotEmpty) {
    throw const FormatException('Invalid GitHub source');
  }
  return source;
}

void _fields(Map<String, dynamic> item, Set<String> expected) {
  if (item.length != expected.length || !expected.containsAll(item.keys)) {
    throw const FormatException('Invalid metadata fields');
  }
}

int _integer(Map<String, dynamic> item, String key) {
  final value = item[key];
  if (value is! int) throw FormatException('Invalid $key');
  return value;
}

String? _nullableString(Map<String, dynamic> item, String key) {
  final value = item[key];
  if (value != null && value is! String) throw FormatException('Invalid $key');
  return value as String?;
}

DateTime _utcDate(Object? raw) {
  if (raw is! String || !raw.endsWith('Z')) {
    throw const FormatException('Invalid UTC date');
  }
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || parsed.toIso8601String() != raw) {
    throw const FormatException('Invalid UTC date');
  }
  return parsed;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Ожидался JSON object');
  }
  return value;
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('Некорректный $key');
  return value;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Некорректный $key');
  return value;
}

List<dynamic> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List<dynamic>) throw FormatException('Некорректный $key');
  return value;
}

T _enum<T extends Enum>(Map<String, dynamic> json, String key, List<T> values) {
  final value = _string(json, key);
  for (final option in values) {
    if (option.name == value) return option;
  }
  throw FormatException('Некорректный $key');
}
