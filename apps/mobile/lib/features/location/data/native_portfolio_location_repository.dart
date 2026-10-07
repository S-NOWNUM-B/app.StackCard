import 'dart:async';

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

import '../domain/portfolio_location.dart';

final class NativePortfolioLocationRepository
    implements PortfolioLocationRepository {
  NativePortfolioLocationRepository({
    GeolocatorPlatform? geolocator,
    Future<List<geocoding.Placemark>> Function(double, double)? reverseGeocode,
    this.locationTimeout = const Duration(seconds: 20),
    this.geocodingTimeout = const Duration(seconds: 15),
  }) : _geolocator = geolocator ?? GeolocatorPlatform.instance,
       _reverseGeocode = reverseGeocode ?? _nativeReverseGeocode;

  final GeolocatorPlatform _geolocator;
  final Future<List<geocoding.Placemark>> Function(double, double)
  _reverseGeocode;
  final Duration locationTimeout;
  final Duration geocodingTimeout;
  bool _requesting = false;

  @override
  Future<PortfolioPlace> currentPlace() async {
    if (_requesting) {
      throw const PortfolioLocationFailure(
        PortfolioLocationFailureKind.unavailable,
      );
    }
    _requesting = true;
    try {
      if (!await _geolocator.isLocationServiceEnabled()) {
        throw const PortfolioLocationFailure(
          PortfolioLocationFailureKind.serviceDisabled,
        );
      }
      var permission = await _geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _geolocator.requestPermission();
      }
      switch (permission) {
        case LocationPermission.denied:
          throw const PortfolioLocationFailure(
            PortfolioLocationFailureKind.denied,
          );
        case LocationPermission.deniedForever:
          throw const PortfolioLocationFailure(
            PortfolioLocationFailureKind.permanentlyDenied,
          );
        case LocationPermission.unableToDetermine:
          throw const PortfolioLocationFailure(
            PortfolioLocationFailureKind.unavailable,
          );
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }
      final position = await _geolocator
          .getCurrentPosition(
            locationSettings: LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: locationTimeout,
            ),
          )
          .timeout(locationTimeout);
      if (!position.latitude.isFinite ||
          position.latitude < -90 ||
          position.latitude > 90 ||
          !position.longitude.isFinite ||
          position.longitude < -180 ||
          position.longitude > 180) {
        throw const PortfolioLocationFailure(
          PortfolioLocationFailureKind.unavailable,
        );
      }
      return await _resolvePlace(position.latitude, position.longitude);
    } on PortfolioLocationFailure {
      rethrow;
    } on LocationServiceDisabledException {
      throw const PortfolioLocationFailure(
        PortfolioLocationFailureKind.serviceDisabled,
      );
    } on PermissionDeniedException {
      throw const PortfolioLocationFailure(PortfolioLocationFailureKind.denied);
    } on TimeoutException {
      throw const PortfolioLocationFailure(
        PortfolioLocationFailureKind.timeout,
      );
    } catch (_) {
      throw const PortfolioLocationFailure(
        PortfolioLocationFailureKind.unavailable,
      );
    } finally {
      _requesting = false;
    }
  }

  Future<PortfolioPlace> _resolvePlace(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await _reverseGeocode(
        latitude,
        longitude,
      ).timeout(geocodingTimeout);
      for (final placemark in placemarks) {
        // Район, улица и адрес не заменяют выбранный пользователем город.
        final place = PortfolioPlace(
          city: placemark.locality ?? '',
          country: placemark.country ?? '',
        );
        if (place.isValid) return place;
      }
      throw const PortfolioLocationFailure(
        PortfolioLocationFailureKind.placeUnavailable,
      );
    } on PortfolioLocationFailure {
      rethrow;
    } on TimeoutException {
      throw const PortfolioLocationFailure(
        PortfolioLocationFailureKind.timeout,
      );
    } catch (_) {
      throw const PortfolioLocationFailure(
        PortfolioLocationFailureKind.placeUnavailable,
      );
    }
  }

  // Native geocoder создаётся при действии пользователя, а не при bootstrap.
  static Future<List<geocoding.Placemark>> _nativeReverseGeocode(
    double latitude,
    double longitude,
  ) => geocoding.Geocoding().placemarkFromCoordinates(latitude, longitude);

  @override
  Future<bool> openAppSettings() => _openSettings(_geolocator.openAppSettings);

  @override
  Future<bool> openLocationSettings() =>
      _openSettings(_geolocator.openLocationSettings);

  Future<bool> _openSettings(Future<bool> Function() open) async {
    try {
      return await open().timeout(const Duration(seconds: 5));
    } catch (_) {
      return false;
    }
  }
}
