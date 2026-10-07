/// Координаты существуют только в picker, без codec/storage/public API данных.
final class PortfolioCoordinates {
  PortfolioCoordinates(this.latitude, this.longitude) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90 ||
        !longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError('Invalid coordinates');
    }
  }

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) => other is PortfolioCoordinates &&
      latitude == other.latitude && longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Единственный результат подтверждения: город и страна, без адреса/GPS.
final class PortfolioPlace {
  PortfolioPlace({required String city, required String country})
    : city = city.trim(), country = country.trim();

  final String city;
  final String country;
  bool get isValid => city.isNotEmpty && country.isNotEmpty &&
      city.length <= 100 && country.length <= 96;
  String get displayText => '$city, $country';
}

enum PortfolioLocationFailureKind {
  denied, permanentlyDenied, serviceDisabled, timeout, unavailable,
  placeUnavailable,
}

final class PortfolioLocationFailure implements Exception {
  const PortfolioLocationFailure(this.kind);
  final PortfolioLocationFailureKind kind;
}

abstract interface class PortfolioLocationRepository {
  Future<PortfolioCoordinates> currentCoordinates();
  Future<PortfolioPlace> placeForCoordinates(PortfolioCoordinates coordinates);
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}
