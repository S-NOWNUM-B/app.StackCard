import '../domain/portfolio_content.dart';
import '../domain/portfolio_validation.dart';

Map<String, Object?> encodePortfolioContent(PortfolioContent content) => {
  'profile': {
    'name': content.profile.name,
    'username': content.profile.username,
    'headline': content.profile.headline,
    'bio': content.profile.bio,
    'locationText': content.profile.locationText,
    'avatarUrl': content.profile.avatarUrl,
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
          'technologies': item.technologies,
          'repositoryUrl': item.repositoryUrl,
          'liveUrl': item.liveUrl,
          'featured': item.featured,
          'visible': item.visible,
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
        },
      )
      .toList(),
  'blocks': content.blocks
      .map((item) => {'kind': item.kind.name, 'visible': item.visible})
      .toList(),
  'resumeText': content.resumeText,
  'theme': content.theme.name,
};

PortfolioContent decodePortfolioContent(Object? raw) {
  final json = _map(raw);
  final profile = _map(json['profile']);
  final content = PortfolioContent(
    profile: PortfolioProfile(
      name: _string(profile, 'name'),
      username: _string(profile, 'username'),
      headline: _string(profile, 'headline'),
      bio: _string(profile, 'bio'),
      locationText: _string(profile, 'locationText'),
      avatarUrl: _string(profile, 'avatarUrl'),
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
      return SocialLink(
        id: _string(item, 'id'),
        label: _string(item, 'label'),
        url: _string(item, 'url'),
        kind: _enum(item, 'kind', SocialLinkKind.values),
      );
    }).toList(),
    projects: _list(json, 'projects').map((raw) {
      final item = _map(raw);
      return PortfolioProject(
        id: _string(item, 'id'),
        title: _string(item, 'title'),
        description: _string(item, 'description'),
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
  );
  if (validatePortfolioContent(content).isNotEmpty) {
    throw const FormatException('Некорректный Builder content');
  }
  return content;
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
