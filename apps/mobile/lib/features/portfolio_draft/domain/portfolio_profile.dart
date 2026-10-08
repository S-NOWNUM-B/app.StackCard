final class PortfolioProfile {
  const PortfolioProfile({
    this.name = '',
    this.username = '',
    this.headline = '',
    this.bio = '',
    this.locationText = '',
    this.publishLocation = false,
    this.avatarUrl = '',
    this.avatarPath = '',
  });

  final String name;
  final String username;
  final String headline;
  final String bio;
  final String locationText;
  final bool publishLocation;
  final String avatarUrl;
  final String avatarPath;

  PortfolioProfile copyWith({
    String? name,
    String? username,
    String? headline,
    String? bio,
    String? locationText,
    bool? publishLocation,
    String? avatarUrl,
    String? avatarPath,
  }) => PortfolioProfile(
    name: name ?? this.name,
    username: username ?? this.username,
    headline: headline ?? this.headline,
    bio: bio ?? this.bio,
    locationText: locationText ?? this.locationText,
    publishLocation: publishLocation ?? this.publishLocation,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    avatarPath: avatarPath ?? this.avatarPath,
  );

  Object get _fields => (
    name,
    username,
    headline,
    bio,
    locationText,
    publishLocation,
    avatarUrl,
    avatarPath,
  );

  @override
  bool operator ==(Object other) =>
      other is PortfolioProfile && other._fields == _fields;

  @override
  int get hashCode => _fields.hashCode;
}
