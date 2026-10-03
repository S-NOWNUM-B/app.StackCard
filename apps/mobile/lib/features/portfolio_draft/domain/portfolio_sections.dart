enum SocialLinkKind { other, github, website, linkedin }

enum PortfolioBlockKind {
  profile,
  about,
  skills,
  featuredProjects,
  experience,
  education,
  github,
  links,
  resume,
  location,
}

enum PortfolioTheme { dark, light }

final class Skill {
  const Skill({required this.id, required this.name});

  final String id;
  final String name;

  Skill copyWith({String? id, String? name}) =>
      Skill(id: id ?? this.id, name: name ?? this.name);

  Object get _fields => (id, name);

  @override
  bool operator ==(Object other) => other is Skill && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}

final class Experience {
  const Experience({
    required this.id,
    required this.role,
    required this.organization,
    required this.period,
    required this.description,
  });

  final String id;
  final String role;
  final String organization;
  final String period;
  final String description;

  Experience copyWith({
    String? id,
    String? role,
    String? organization,
    String? period,
    String? description,
  }) => Experience(
    id: id ?? this.id,
    role: role ?? this.role,
    organization: organization ?? this.organization,
    period: period ?? this.period,
    description: description ?? this.description,
  );

  Object get _fields => (id, role, organization, period, description);

  @override
  bool operator ==(Object other) =>
      other is Experience && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}

final class Education {
  const Education({
    required this.id,
    required this.institution,
    required this.qualification,
    required this.period,
    required this.description,
  });

  final String id;
  final String institution;
  final String qualification;
  final String period;
  final String description;

  Education copyWith({
    String? id,
    String? institution,
    String? qualification,
    String? period,
    String? description,
  }) => Education(
    id: id ?? this.id,
    institution: institution ?? this.institution,
    qualification: qualification ?? this.qualification,
    period: period ?? this.period,
    description: description ?? this.description,
  );

  Object get _fields => (id, institution, qualification, period, description);

  @override
  bool operator ==(Object other) =>
      other is Education && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}

final class SocialLink {
  const SocialLink({
    required this.id,
    required this.label,
    required this.url,
    this.kind = SocialLinkKind.other,
  });

  final String id;
  final String label;
  final String url;
  final SocialLinkKind kind;

  SocialLink copyWith({
    String? id,
    String? label,
    String? url,
    SocialLinkKind? kind,
  }) => SocialLink(
    id: id ?? this.id,
    label: label ?? this.label,
    url: url ?? this.url,
    kind: kind ?? this.kind,
  );

  Object get _fields => (id, label, url, kind);

  @override
  bool operator ==(Object other) =>
      other is SocialLink && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}

final class PortfolioBlock {
  const PortfolioBlock({required this.kind, this.visible = true});

  final PortfolioBlockKind kind;
  final bool visible;

  PortfolioBlock copyWith({PortfolioBlockKind? kind, bool? visible}) =>
      PortfolioBlock(kind: kind ?? this.kind, visible: visible ?? this.visible);

  Object get _fields => (kind, visible);

  @override
  bool operator ==(Object other) =>
      other is PortfolioBlock && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}
