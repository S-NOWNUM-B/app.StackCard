/// Единственный результат подтверждения: город и страна, без адреса/GPS.
final class PortfolioPlace {
  PortfolioPlace({required String city, required String country})
    : city = city.trim(),
      country = country.trim();

  final String city;
  final String country;
  bool get isValid =>
      city.isNotEmpty &&
      country.isNotEmpty &&
      city.length <= 100 &&
      country.length <= 96;
  String get displayText => '$city, $country';
}

enum PortfolioLocationFailureKind {
  denied,
  permanentlyDenied,
  serviceDisabled,
  timeout,
  unavailable,
  placeUnavailable,
}

final class PortfolioLocationFailure implements Exception {
  const PortfolioLocationFailure(this.kind);
  final PortfolioLocationFailureKind kind;
}

abstract interface class PortfolioLocationRepository {
  /// Разрешение и одно определение города только после действия пользователя.
  Future<PortfolioPlace> currentPlace();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}
