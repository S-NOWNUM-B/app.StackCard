import 'dart:convert';

import 'package:app_stackcard/features/portfolio_draft/data/developer_card_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/developer_card.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/document_publication.dart';

import 'support/developer_card_fixture.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'card projects only the published fields and deduplicates technologies',
    () {
      final raw = publicCardFixture();
      final card = decodeDeveloperCard(raw, publication());
      expect(card.name, 'Анна Ёлкина');
      expect(card.headline, 'Flutter developer');
      expect(card.username, 'anna-dev');
      expect(card.technologies, ['Flutter', 'TypeScript']);
      expect(card.url.toString(), 'https://portfolio.example/d/$publicId');
      expect(() => card.technologies.add('private'), throwsUnsupportedError);
      (raw['content'] as Map)['profile']['name'] = 'Later private input';
      expect(card.name, 'Анна Ёлкина');
    },
  );
  test(
    'public identity and URL stay stable across rename and new versions',
    () {
      final raw = publicCardFixture();
      final before = decodeDeveloperCard(raw, publication());
      raw['title'] = 'Новое название';
      raw['version'] = 2;
      final after = decodeDeveloperCard(raw, publication(version: 2));
      expect(after.url, before.url);
      expect(after.title, 'Новое название');
      expect(after.version, 2);
      expect(
        () => decodeDeveloperCard(raw, publication(id: 'a' * 32, version: 2)),
        throwsA(isA<DeveloperCardFailure>()),
      );
    },
  );
  test('unpublished and deleted publications never get a QR URL', () {
    for (final visibility in [
      DocumentPublicationVisibility.unpublished,
      DocumentPublicationVisibility.deleted,
    ]) {
      expect(
        () => developerCardPublicUrl(publication(visibility: visibility)),
        throwsA(isA<DeveloperCardFailure>()),
      );
    }
  });
  test('URLs must identify the confirmed public document without credentials or query data', () {
    for (final url in [
      'https://portfolio.example/d/${'a' * 32}',
      'https://user:secret@portfolio.example/d/$publicId',
      'https://portfolio.example/d/$publicId?uid=private',
      'https://portfolio.example/d/$publicId#private',
      'javascript:alert(1)',
      'http://portfolio.example/d/$publicId',
    ]) {
      expect(
        () => developerCardPublicUrl(publication(url: url)),
        throwsA(isA<DeveloperCardFailure>()),
        reason: url,
      );
    }
    expect(
      developerCardPublicUrl(
        publication(url: 'http://10.0.2.2:3000/d/$publicId'),
      ).scheme,
      'http',
    );
  });
  test(
    'mismatched schema, version, public kind and private fields fail closed',
    () {
      for (final change in [
        {'schemaVersion': 3},
        {'schemaVersion': 2.0},
        {'version': 2},
        {'publicId': 'a' * 32},
        {'kind': 'resume'},
        {'ownerUid': 'private'},
        {'publishedAt': 'not a date'},
      ]) {
        expect(
          () => decodeDeveloperCard({
            ...publicCardFixture(),
            ...change,
          }, publication()),
          throwsA(isA<DeveloperCardFailure>()),
        );
      }
      final raw = publicCardFixture();
      (raw['content'] as Map)['profile']['avatarPath'] =
          'accounts/private/media/photo.jpg';
      expect(
        () => decodeDeveloperCard(raw, publication()),
        throwsA(isA<DeveloperCardFailure>()),
      );
    },
  );
  test('hidden profile, skills or projects cannot leak into a card', () {
    for (final kind in ['profile', 'skills', 'featuredProjects']) {
      final raw = publicCardFixture();
      ((raw['content'] as Map)['blocks'] as List).removeWhere(
        (block) => block['kind'] == kind,
      );
      expect(
        () => decodeDeveloperCard(raw, publication()),
        throwsA(isA<DeveloperCardFailure>()),
      );
    }
    final raw = publicCardFixture();
    final content = raw['content'] as Map;
    content['profile'] = {
      'name': '',
      'username': '',
      'headline': '',
      'bio': '',
      'locationText': '',
      'avatarUrl': '',
    };
    content['skills'] = [];
    content['projects'] = [];
    content['blocks'] = [];
    final card = decodeDeveloperCard(raw, publication());
    expect(card.name, isEmpty);
    expect(card.technologies, isEmpty);
  });
  test('untrusted avatar locations, SVG and oversized data are rejected', () {
    for (final avatar in [
      'accounts/owner/media/image.jpg',
      'https://evil.example/photo.jpg',
      'data:image/svg+xml;base64,PHN2Zz4=',
      'data:image/jpeg;base64,${base64Encode(List.filled(256 * 1024 + 1, 1))}',
    ]) {
      final raw = publicCardFixture();
      (raw['content'] as Map)['profile']['avatarUrl'] = avatar;
      expect(
        () => decodeDeveloperCard(raw, publication()),
        throwsA(isA<DeveloperCardFailure>()),
      );
    }
  });
}
