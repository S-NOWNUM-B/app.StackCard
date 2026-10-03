final class PortfolioProfile {
  const PortfolioProfile({
    this.name = '',
    this.username = '',
    this.headline = '',
    this.bio = '',
    this.locationText = '',
    this.avatarUrl = '',
  });

  final String name;
  final String username;
  final String headline;
  final String bio;
  final String locationText;
  final String avatarUrl;

  PortfolioProfile copyWith({
    String? name,
    String? username,
    String? headline,
    String? bio,
    String? locationText,
    String? avatarUrl,
  }) => PortfolioProfile(
    name: name ?? this.name,
    username: username ?? this.username,
    headline: headline ?? this.headline,
    bio: bio ?? this.bio,
    locationText: locationText ?? this.locationText,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  Object get _fields =>
      (name, username, headline, bio, locationText, avatarUrl);

  @override
  bool operator ==(Object other) =>
      other is PortfolioProfile && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}
