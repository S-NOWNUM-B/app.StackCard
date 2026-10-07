import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/location/domain/portfolio_location.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_public_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test(
    'Confirmed city/country survives Hive reopen without GPS or address fields',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'stackcard-location-',
      );
      Box<dynamic>? box;
      try {
        box = await Hive.openBox<dynamic>('location', path: directory.path);
        final place = PortfolioPlace(
          city: '  Алматы  ',
          country: ' Казахстан ',
        );
        final content = PortfolioContent(
          profile: PortfolioProfile(locationText: place.displayText),
        );
        await HivePortfolioDraftRepository(box)
            .save(content, expectedRevision: 0, notes: 'private notes');
        final envelope = jsonDecode(box.get('draft') as String) as Map;
        expect(
          envelope['schemaVersion'],
          HivePortfolioDraftRepository.schemaVersion,
        );
        final privateProfile = (envelope['content'] as Map)['profile'] as Map;
        expect(privateProfile['locationText'], 'Алматы, Казахстан');
        expect(privateProfile.keys.toSet(), {
          'name',
          'username',
          'headline',
          'bio',
          'locationText',
          'avatarUrl',
          'avatarPath',
        });
        await box.close();
        box = await Hive.openBox<dynamic>('location', path: directory.path);
        final restored = await HivePortfolioDraftRepository(box).read();
        expect(restored!.content, content);
        final publicProfile =
            encodePublicPortfolioContent(restored.content!)['profile'] as Map;
        expect(publicProfile['locationText'], 'Алматы, Казахстан');
        expect(publicProfile.keys.toSet(), {
          'name',
          'username',
          'headline',
          'bio',
          'locationText',
          'avatarUrl',
        });
      } finally {
        if (box?.isOpen ?? false) await box!.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('Hidden Location is physically removed from the public payload', () {
    final content = PortfolioContent(
      profile: const PortfolioProfile(locationText: 'Алматы, Казахстан'),
      blocks: PortfolioBlockKind.values
          .map(
            (kind) => PortfolioBlock(
              kind: kind,
              visible: kind != PortfolioBlockKind.location,
            ),
          )
          .toList(),
    );
    final encoded = encodePublicPortfolioContent(content);
    expect((encoded['profile'] as Map)['locationText'], '');
    expect(jsonEncode(encoded), isNot(contains('Алматы')));
    expect(
      encodePortfolioContent(content)['profile'],
      containsPair('locationText', 'Алматы, Казахстан'),
    );
  });

  test('Existing free text location still round trips without migration', () {
    final content = PortfolioContent(
      profile: const PortfolioProfile(locationText: 'Remote / Алматы'),
    );
    expect(decodePortfolioContent(encodePortfolioContent(content)), content);
  });

  test('City/country confirmation trims input and fits the existing 200 character field', () {
    expect(PortfolioPlace(city: ' ', country: 'Казахстан').isValid, isFalse);
    expect(PortfolioPlace(city: 'Алматы', country: '').isValid, isFalse);
    final place = PortfolioPlace(city: 'a' * 100, country: 'b' * 96);
    expect(place.isValid, isTrue);
    expect(place.displayText.length, lessThanOrEqualTo(200));
    expect(
      PortfolioPlace(city: 'a' * 101, country: 'Казахстан').isValid,
      isFalse,
    );
  });
}
