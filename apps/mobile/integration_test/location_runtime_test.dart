import 'dart:io';

import 'package:app_stackcard/core/localization/app_strings.dart';
import 'package:app_stackcard/core/theme/stackcard_theme.dart';
import 'package:app_stackcard/features/location/data/native_portfolio_location_repository.dart';
import 'package:app_stackcard/features/location/domain/portfolio_location.dart';
import 'package:app_stackcard/features/location/presentation/portfolio_location_picker.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_public_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in: отдельный test storage; обычный account/draft не меняется.
/// Permissions/location services готовит оператор, test не меняет OS settings.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('RUN_LOCATION_ACCEPTANCE');
  const scenario = String.fromEnvironment(
    'LOCATION_SCENARIO',
    defaultValue: 'granted',
  );
  testWidgets(
    'native location $scenario and city-only persistence',
    (tester) async {
      final repository = NativePortfolioLocationRepository();
      final failure = switch (scenario) {
        'denied' => PortfolioLocationFailureKind.denied,
        'permanentlyDenied' => PortfolioLocationFailureKind.permanentlyDenied,
        'serviceDisabled' => PortfolioLocationFailureKind.serviceDisabled,
        'granted' => null,
        'manual' => null,
        _ => throw ArgumentError('Unknown LOCATION_SCENARIO'),
      };
      if (failure != null) {
        await expectLater(
          repository.currentPlace(),
          throwsA(
            isA<PortfolioLocationFailure>().having(
              (error) => error.kind,
              'kind',
              failure,
            ),
          ),
        );
        return;
      }
      PortfolioPlace? confirmed;
      if (scenario == 'manual') {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: StackCardTheme.dark,
              locale: const Locale('ru'),
              supportedLocales: AppStrings.supportedLocales,
              localizationsDelegates: const [
                AppStrings.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      key: const ValueKey('open_location_acceptance'),
                      onPressed: () async {
                        confirmed = await Navigator.of(context)
                            .push<PortfolioPlace>(
                              MaterialPageRoute(
                                builder: (_) => const PortfolioLocationPicker(),
                              ),
                            );
                      },
                      child: const Text('Location acceptance'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('open_location_acceptance')),
        );
        await tester.pumpAndSettle();
        final city = find.descendant(
          of: find.byKey(const ValueKey('location_city')),
          matching: find.byType(TextFormField),
        );
        final country = find.descendant(
          of: find.byKey(const ValueKey('location_country')),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(city, 'Алматы');
        await tester.enterText(country, 'Казахстан');
        await tester.pumpAndSettle();
        final confirm = find.byKey(const ValueKey('location_confirm'));
        await Scrollable.ensureVisible(tester.element(confirm), alignment: .5);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(confirmed?.displayText, 'Алматы, Казахстан');
      }
      final place = confirmed ?? await repository.currentPlace();
      expect(place.isValid, isTrue);
      final directory = await Directory.systemTemp.createTemp(
        'location-acceptance-',
      );
      Box<dynamic>? box;
      try {
        box = await Hive.openBox<dynamic>(
          'location_acceptance',
          path: directory.path,
        );
        final content = PortfolioContent(
          profile: PortfolioProfile(locationText: place.displayText),
        );
        await HivePortfolioDraftRepository(box)
            .save(content, expectedRevision: 0, notes: '');
        await box.close();
        box = await Hive.openBox<dynamic>(
          'location_acceptance',
          path: directory.path,
        );
        final restored = (await HivePortfolioDraftRepository(
          box,
        ).read())!.content!;
        expect(restored.profile.locationText, place.displayText);
        final publicProfile =
            encodePublicPortfolioContent(restored)['profile'] as Map;
        expect(publicProfile.keys.toSet(), {
          'name',
          'username',
          'headline',
          'bio',
          'locationText',
          'avatarUrl',
        });
        expect(publicProfile['locationText'], place.displayText);
      } finally {
        if (box?.isOpen ?? false) await box!.close();
        await directory.delete(recursive: true);
      }
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
