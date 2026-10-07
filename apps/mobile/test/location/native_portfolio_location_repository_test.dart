import 'dart:async';

import 'package:app_stackcard/features/location/data/native_portfolio_location_repository.dart';
import 'package:app_stackcard/features/location/domain/portfolio_location.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';

Matcher _failure(PortfolioLocationFailureKind kind) =>
    isA<PortfolioLocationFailure>().having((error) => error.kind, 'kind', kind);

Position _position({double latitude = 43.2389, double longitude = 76.8897}) =>
    Position(
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.utc(2026, 10, 7),
      accuracy: 1000,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

class _Geolocator extends GeolocatorPlatform {
  final events = <String>[];
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  Position position = _position();
  LocationSettings? settings;
  Completer<Position>? positionCompletion;
  Object? serviceError;
  Object? checkError;
  Object? requestError;
  Object? positionError;
  Object? appSettingsError;
  Object? locationSettingsError;
  bool appSettingsResult = true;
  bool locationSettingsResult = true;

  @override
  Future<bool> isLocationServiceEnabled() async {
    events.add('service');
    if (serviceError case final error?) throw error;
    return serviceEnabled;
  }

  @override
  Future<LocationPermission> checkPermission() async {
    events.add('check');
    if (checkError case final error?) throw error;
    return permission;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    events.add('request');
    if (requestError case final error?) throw error;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    events.add('position');
    settings = locationSettings;
    if (positionError case final error?) throw error;
    return positionCompletion?.future ?? position;
  }

  @override
  Future<bool> openAppSettings() async {
    events.add('appSettings');
    if (appSettingsError case final error?) throw error;
    return appSettingsResult;
  }

  @override
  Future<bool> openLocationSettings() async {
    events.add('locationSettings');
    if (locationSettingsError case final error?) throw error;
    return locationSettingsResult;
  }
}

void main() {
  late _Geolocator platform;
  late NativePortfolioLocationRepository repository;
  late List<geocoding.Placemark> placemarks;
  late int reverseGeocodeCalls;

  setUp(() {
    platform = _Geolocator();
    placemarks = const [
      geocoding.Placemark(
        locality: '  Алматы  ',
        country: '  Казахстан  ',
        name: 'Личный адрес',
        street: 'Абая 1',
        postalCode: '050000',
      ),
    ];
    reverseGeocodeCalls = 0;
    repository = NativePortfolioLocationRepository(
      geolocator: platform,
      reverseGeocode: (latitude, longitude) async {
        platform.events.add('geocode');
        reverseGeocodeCalls++;
        expect(latitude, platform.position.latitude);
        expect(longitude, platform.position.longitude);
        return placemarks;
      },
    );
  });

  test(
    'constructor does not request permission, position or native geocoder',
    () {
      NativePortfolioLocationRepository(geolocator: platform);
      expect(platform.events, isEmpty);
      expect(reverseGeocodeCalls, 0);
    },
  );

  test(
    'returns only trimmed city/country after a one-shot medium fix',
    () async {
      final place = await repository.currentPlace();
      expect(place.city, 'Алматы');
      expect(place.country, 'Казахстан');
      expect(place.displayText, 'Алматы, Казахстан');
      expect(platform.events, ['service', 'check', 'position', 'geocode']);
      expect(platform.settings?.accuracy, LocationAccuracy.medium);
      expect(platform.settings?.timeLimit, const Duration(seconds: 20));
      expect(reverseGeocodeCalls, 1);
    },
  );

  test(
    'existing always permission is usable without another request',
    () async {
      platform.permission = LocationPermission.always;
      await repository.currentPlace();
      expect(platform.events, ['service', 'check', 'position', 'geocode']);
    },
  );

  test('denied permission is requested once before locating', () async {
    platform.permission = LocationPermission.denied;
    await repository.currentPlace();
    expect(platform.events, [
      'service',
      'check',
      'request',
      'position',
      'geocode',
    ]);
  });

  test(
    'disabled service does not open a permission dialog or locate',
    () async {
      platform.serviceEnabled = false;
      await expectLater(
        repository.currentPlace(),
        throwsA(_failure(PortfolioLocationFailureKind.serviceDisabled)),
      );
      expect(platform.events, ['service']);
      expect(reverseGeocodeCalls, 0);
    },
  );

  test('denied request stays distinct and does not locate', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.denied;
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.denied)),
    );
    expect(platform.events, ['service', 'check', 'request']);
    expect(reverseGeocodeCalls, 0);
  });

  test('permanently denied does not request again', () async {
    platform.permission = LocationPermission.deniedForever;
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.permanentlyDenied)),
    );
    expect(platform.events, ['service', 'check']);
  });

  test('request becoming permanently denied is mapped distinctly', () async {
    platform.permission = LocationPermission.denied;
    platform.requestedPermission = LocationPermission.deniedForever;
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.permanentlyDenied)),
    );
    expect(platform.events, ['service', 'check', 'request']);
  });

  test('undetermined permission never starts location', () async {
    platform.permission = LocationPermission.unableToDetermine;
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.unavailable)),
    );
    expect(platform.events, ['service', 'check']);
  });

  for (final entry in <Object, PortfolioLocationFailureKind>{
    const LocationServiceDisabledException():
        PortfolioLocationFailureKind.serviceDisabled,
    const PermissionDeniedException('permission revoked'):
        PortfolioLocationFailureKind.denied,
    TimeoutException('no fix'): PortfolioLocationFailureKind.timeout,
    PlatformException(code: 'unavailable'):
        PortfolioLocationFailureKind.unavailable,
  }.entries) {
    test('native position error maps to ${entry.value.name}', () async {
      platform.positionError = entry.key;
      await expectLater(
        repository.currentPlace(),
        throwsA(_failure(entry.value)),
      );
      expect(reverseGeocodeCalls, 0);
    });
  }

  test('native check failure maps to unavailable without requesting', () async {
    platform.checkError = MissingPluginException();
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.unavailable)),
    );
    expect(platform.events, ['service', 'check']);
  });

  test('native request failure is typed and allows another attempt', () async {
    platform.permission = LocationPermission.denied;
    platform.requestError = PlatformException(code: 'permissionRequestBusy');
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.unavailable)),
    );
    platform.requestError = null;
    expect((await repository.currentPlace()).city, 'Алматы');
  });

  test('location deadline is bounded and passed to the SDK', () async {
    platform.positionCompletion = Completer<Position>();
    repository = NativePortfolioLocationRepository(
      geolocator: platform,
      locationTimeout: const Duration(milliseconds: 10),
      reverseGeocode: (_, _) async {
        reverseGeocodeCalls++;
        return placemarks;
      },
    );
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.timeout)),
    );
    expect(platform.settings?.timeLimit, const Duration(milliseconds: 10));
    expect(reverseGeocodeCalls, 0);
    // Поздний native result не запускает geocoder и не меняет новый запрос.
    platform.positionCompletion!.complete(platform.position);
    await Future<void>.delayed(Duration.zero);
    expect(reverseGeocodeCalls, 0);
    platform.positionCompletion = null;
    expect((await repository.currentPlace()).city, 'Алматы');
  });

  test(
    'overlapping request never starts a second permission/fix flow',
    () async {
      platform.positionCompletion = Completer<Position>();
      final first = repository.currentPlace();
      await expectLater(
        repository.currentPlace(),
        throwsA(_failure(PortfolioLocationFailureKind.unavailable)),
      );
      platform.positionCompletion!.complete(platform.position);
      await first;
      expect(
        platform.events.where((event) => event == 'service'),
        hasLength(1),
      );
      expect(
        platform.events.where((event) => event == 'position'),
        hasLength(1),
      );
    },
  );

  for (final position in [
    _position(latitude: double.nan),
    _position(latitude: 91),
    _position(longitude: -181),
  ]) {
    test('invalid native coordinates do not reach geocoding', () async {
      platform.position = position;
      await expectLater(
        repository.currentPlace(),
        throwsA(_failure(PortfolioLocationFailureKind.unavailable)),
      );
      expect(reverseGeocodeCalls, 0);
    });
  }

  test('empty geocoder result requires manual city/country input', () async {
    placemarks = [];
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.placeUnavailable)),
    );
  });

  test('district and address are never used as a city fallback', () async {
    placemarks = const [
      geocoding.Placemark(
        country: 'Казахстан',
        administrativeArea: 'Алматинская область',
        subAdministrativeArea: 'Личный район',
        name: 'Личный адрес',
        street: 'Личная улица',
      ),
    ];
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.placeUnavailable)),
    );
  });

  test('city and country come from the same valid placemark', () async {
    placemarks = const [
      geocoding.Placemark(locality: 'Unknown'),
      geocoding.Placemark(country: 'Different country'),
      geocoding.Placemark(locality: 'Алматы', country: 'Казахстан'),
    ];
    expect((await repository.currentPlace()).displayText, 'Алматы, Казахстан');
  });

  test('oversized geocoder fields require manual input', () async {
    placemarks = [
      geocoding.Placemark(locality: 'x' * 101, country: 'Казахстан'),
      geocoding.Placemark(locality: 'Алматы', country: 'x' * 97),
    ];
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.placeUnavailable)),
    );
  });

  test('geocoder platform failure is mapped to place unavailable', () async {
    repository = NativePortfolioLocationRepository(
      geolocator: platform,
      reverseGeocode: (_, _) async => throw PlatformException(code: 'IO_ERROR'),
    );
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.placeUnavailable)),
    );
  });

  test('geocoding deadline is bounded after a successful fix', () async {
    final completion = Completer<List<geocoding.Placemark>>();
    repository = NativePortfolioLocationRepository(
      geolocator: platform,
      geocodingTimeout: const Duration(milliseconds: 10),
      reverseGeocode: (_, _) => completion.future,
    );
    await expectLater(
      repository.currentPlace(),
      throwsA(_failure(PortfolioLocationFailureKind.timeout)),
    );
    completion.complete(placemarks);
  });

  test('settings opens are explicit and report the native result', () async {
    expect(platform.events, isEmpty);
    expect(await repository.openAppSettings(), isTrue);
    platform.locationSettingsResult = false;
    expect(await repository.openLocationSettings(), isFalse);
    expect(platform.events, ['appSettings', 'locationSettings']);
    expect(reverseGeocodeCalls, 0);
  });

  test('settings failures return false without locating', () async {
    platform.appSettingsError = PlatformException(code: 'unavailable');
    platform.locationSettingsError = MissingPluginException();
    expect(await repository.openAppSettings(), isFalse);
    expect(await repository.openLocationSettings(), isFalse);
    expect(platform.events, ['appSettings', 'locationSettings']);
  });
}
