import 'dart:convert';

import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_public_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_validation.dart';
import 'package:flutter_test/flutter_test.dart';

const _avatar = 'accounts/owner/media/0123456789abcdef0123456789abcdef.jpg';
const _image = 'accounts/owner/media/abcdef0123456789abcdef0123456789.jpg';

void main() {
  test('Avatar paths default empty and participate in copy and equality', () {
    const profile = PortfolioProfile(
      avatarUrl: 'https://example.com/avatar.png',
    );
    expect(profile.avatarPath, isEmpty);
    final local = profile.copyWith(avatarPath: _avatar);
    expect(local, isNot(profile));
    expect(local.copyWith(), local);
    expect(local.copyWith().hashCode, local.hashCode);
    expect(local.avatarUrl, profile.avatarUrl);
    expect(local.copyWith(avatarPath: ''), profile);
  });

  test('Project images are immutable, ordered and included in equality', () {
    final paths = [_avatar, _image];
    final project = _project().copyWith(imagePaths: paths);
    paths.clear();
    expect(project.imagePaths, [_avatar, _image]);
    expect(() => project.imagePaths.clear(), throwsUnsupportedError);
    expect(project.copyWith(), project);
    expect(project.copyWith().hashCode, project.hashCode);
    expect(project.copyWith(imagePaths: [_image, _avatar]), isNot(project));
    expect(project.copyWith(imagePaths: []), _project());
    expect(_project().imagePaths, isEmpty);
  });

  test('Text editor and GitHub acceptance preserve owner media', () {
    final original = addGitHubProject(PortfolioContent(), _source('Original'));
    final project = original.projects.single.copyWith(imagePaths: [_image]);
    final edited = project.withUserEdits(
      PortfolioProject(
        id: project.id,
        title: 'Owner title',
        description: 'Owner description',
        technologies: ['Kotlin'],
        repositoryUrl: project.repositoryUrl,
      ),
    );
    expect(edited.imagePaths, [_image]);
    expect(edited.githubMetadata!.overrideFields, {
      PortfolioGitHubField.title,
      PortfolioGitHubField.description,
      PortfolioGitHubField.technologies,
    });
    final content = original.copyWith(projects: [edited]);
    final review = reviewGitHubProject(content, _source('Updated source'));
    final accepted = acceptGitHubProjectChanges(content, review);
    expect(accepted.projects.single.imagePaths, [_image]);
    expect(accepted.projects.single.title, 'Owner title');
    expect(accepted.projects.single.description, 'Owner description');
    expect(
      _project()
          .copyWith(imagePaths: [_image])
          .withUserEdits(_project())
          .imagePaths,
      [_image],
    );
  });

  test(
    'Private content round-trips media and legacy content defaults empty',
    () {
      final content = _content();
      final encoded = _json(content);
      final restored = decodePortfolioContent(encoded);
      expect(restored, content);
      expect(restored.hashCode, content.hashCode);
      expect(restored.profile.avatarPath, _avatar);
      expect(restored.projects.single.imagePaths, [_image]);
      (encoded['profile'] as Map).remove('avatarPath');
      ((encoded['projects'] as List).single as Map).remove('imagePaths');
      final legacy = decodePortfolioContent(encoded, allowMedia: false);
      expect(legacy.profile.avatarPath, isEmpty);
      expect(legacy.projects.single.imagePaths, isEmpty);
      expect((encoded['profile'] as Map).containsKey('avatarPath'), isFalse);
    },
  );

  test('Legacy decoder rejects new media fields without dropping them', () {
    for (final field in ['avatarPath', 'imagePaths']) {
      final encoded = _json(_content());
      if (field == 'avatarPath') {
        ((encoded['projects'] as List).single as Map).remove('imagePaths');
      } else {
        (encoded['profile'] as Map).remove('avatarPath');
      }
      expect(
        () => decodePortfolioContent(encoded, allowMedia: false),
        throwsFormatException,
        reason: field,
      );
    }
  });

  final invalidPaths = [
    '',
    'https://example.com/avatar.jpg',
    'gs://bucket/$_image',
    '$_image?token=secret',
    'accounts//media/0123456789abcdef0123456789abcdef.jpg',
    'accounts/owner/other/media/0123456789abcdef0123456789abcdef.jpg',
    'accounts/owner/media/0123456789ABCDEF0123456789ABCDEF.jpg',
    'accounts/owner/media/0123456789abcdef0123456789abcdef.jpeg',
    'accounts/owner/media/0123456789abcdef0123456789abcdef.png',
    'accounts/owner/media/0123456789abcdef0123456789abcde.jpg',
    '$_image\n',
  ];
  for (final path in invalidPaths) {
    test('Media codec rejects malformed project path ${jsonEncode(path)}', () {
      expect(
        validatePortfolioMediaPath(path, required: true),
        PortfolioValidationCode.invalidStructure,
      );
      final payload = _json(_content());
      ((payload['projects'] as List).single as Map)['imagePaths'] = [path];
      expect(() => decodePortfolioContent(payload), throwsFormatException);
      if (path.isNotEmpty) {
        (payload['profile'] as Map)['avatarPath'] = path;
        ((payload['projects'] as List).single as Map)['imagePaths'] = [];
        expect(() => decodePortfolioContent(payload), throwsFormatException);
      }
    });
  }

  test('Domain validates shape and six-image limit independently of owner', () {
    expect(validatePortfolioMediaPath(''), isNull);
    expect(validatePortfolioMediaPath(_avatar), isNull);
    expect(
      validatePortfolioMediaPath(
        'accounts/${'x' * 128}/media/0123456789abcdef0123456789abcdef.jpg',
      ),
      isNull,
    );
    final project = _project().copyWith(
      imagePaths: List.generate(
        6,
        (index) =>
            'accounts/foreign/media/${index.toRadixString(16).padLeft(32, '0')}.jpg',
      ),
    );
    expect(
      validatePortfolioContent(PortfolioContent(projects: [project])),
      isEmpty,
    );
    final tooMany = project.copyWith(
      imagePaths: [...project.imagePaths, _image],
    );
    expect(
      validatePortfolioContent(PortfolioContent(projects: [tooMany])),
      contains(PortfolioValidationCode.invalidStructure),
    );
    expect(
      () =>
          decodePortfolioContent(_json(PortfolioContent(projects: [tooMany]))),
      throwsFormatException,
    );
  });

  test('Codec rejects malformed media value and list types', () {
    for (final avatar in [null, 123, <String>[]]) {
      final json = _json(_content());
      (json['profile'] as Map)['avatarPath'] = avatar;
      expect(() => decodePortfolioContent(json), throwsFormatException);
    }
    for (final images in [
      null,
      _image,
      [123],
      <String, Object>{},
    ]) {
      final json = _json(_content());
      ((json['projects'] as List).single as Map)['imagePaths'] = images;
      expect(() => decodePortfolioContent(json), throwsFormatException);
    }
  });

  test('Public object and schema-one payload omit all private media', () {
    final content = _content();
    for (final hidden in [false, true]) {
      final source = hidden
          ? content.copyWith(
              blocks: content.blocks
                  .map((block) => block.copyWith(visible: false))
                  .toList(),
            )
          : content;
      final projected = projectPublicPortfolioContent(source);
      expect(projected.profile.avatarPath, isEmpty);
      expect(
        projected.projects.every((project) => project.imagePaths.isEmpty),
        isTrue,
      );
      final payload = encodePublicPortfolioContent(source);
      final json = jsonEncode(payload);
      for (final secret in ['avatarPath', 'imagePaths', _avatar, _image]) {
        expect(json, isNot(contains(secret)));
      }
      expect((payload['profile'] as Map).keys.toSet(), {
        'name',
        'username',
        'headline',
        'bio',
        'locationText',
        'avatarUrl',
      });
      expect(decodePortfolioContent(payload), projected);
    }
    expect(content.profile.avatarPath, _avatar);
    expect(content.projects.single.imagePaths, [_image]);
    expect(
      encodePublicPortfolioContent(content)['profile'],
      containsPair('avatarUrl', 'https://example.com/avatar.png'),
    );
  });
}

PortfolioProject _project() => PortfolioProject(
  id: 'project',
  title: 'Project',
  description: '',
  technologies: [],
  featured: true,
);

PortfolioContent _content() => PortfolioContent(
  profile: const PortfolioProfile(
    avatarUrl: 'https://example.com/avatar.png',
    avatarPath: _avatar,
  ),
  projects: [
    _project().copyWith(imagePaths: [_image]),
  ],
);

Map<String, dynamic> _json(PortfolioContent content) =>
    jsonDecode(jsonEncode(encodePortfolioContent(content)))
        as Map<String, dynamic>;

GitHubProjectSource _source(String name) => GitHubProjectSource(
  repositoryId: 42,
  name: name,
  fullName: 'owner/project',
  htmlUrl: 'https://github.com/owner/project',
  description: 'Source description',
  language: 'Dart',
  stars: 1,
  forks: 0,
  isFork: false,
  archived: false,
  updatedAt: DateTime.utc(2026, 10, 7),
);
