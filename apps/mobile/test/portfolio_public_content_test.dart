import 'dart:convert';

import 'package:app_stackcard/features/portfolio_draft/data/portfolio_public_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hidden profile fields cannot be read in published JSON', () {
    final source = _content();
    final projected = projectPublicPortfolioContent(
      _visible(source, {PortfolioBlockKind.about, PortfolioBlockKind.location}),
    );
    expect(projected.profile.name, isEmpty);
    expect(projected.profile.username, isEmpty);
    expect(projected.profile.headline, isEmpty);
    expect(projected.profile.avatarUrl, isEmpty);
    expect(projected.profile.bio, source.profile.bio);
    expect(projected.profile.locationText, source.profile.locationText);
    final encoded = jsonEncode(encodePublicPortfolioContent(projected));
    expect(encoded, isNot(contains('Private name')));
    expect(encoded, isNot(contains('private-user')));
  });

  test('Profile does not disclose hidden about and location fields', () {
    final source = _content();
    final projected = projectPublicPortfolioContent(
      _visible(source, {PortfolioBlockKind.profile}),
    );
    expect(projected.profile.name, source.profile.name);
    expect(projected.profile.bio, isEmpty);
    expect(projected.profile.locationText, isEmpty);
  });

  test('Featured block contains only visible featured projects', () {
    final projected = projectPublicPortfolioContent(_content());
    expect(projected.projects.map((project) => project.id), ['public-project']);
    expect(
      jsonEncode(encodePublicPortfolioContent(_content())),
      isNot(contains('hidden-project')),
    );
    expect(
      projectPublicPortfolioContent(
        _visible(_content(), {PortfolioBlockKind.profile}),
      ).projects,
      isEmpty,
    );
  });

  test('Github and ordinary links use independent visible blocks', () {
    final source = _content();
    final github = projectPublicPortfolioContent(
      _visible(source, {PortfolioBlockKind.github}),
    );
    final ordinary = projectPublicPortfolioContent(
      _visible(source, {PortfolioBlockKind.links}),
    );
    expect(github.links.map((link) => link.id), ['github']);
    expect(ordinary.links.map((link) => link.id), ['website']);
    expect(projectPublicPortfolioContent(_visible(source, {})).links, isEmpty);
  });

  test(
    'Hidden collections and resume are absent while order/theme survive',
    () {
      final source = _visible(
        _content(),
        {},
      ).copyWith(theme: PortfolioTheme.light);
      final projected = projectPublicPortfolioContent(source);
      expect(projected.skills, isEmpty);
      expect(projected.experience, isEmpty);
      expect(projected.education, isEmpty);
      expect(projected.resumeText, isEmpty);
      expect(projected.blocks, source.blocks);
      expect(projected.theme, source.theme);
      expect(source.skills, isNotEmpty);
      expect(source.resumeText, isNotEmpty);
    },
  );

  test('Public codec has no private draft or account fields', () {
    final json = encodePublicPortfolioContent(_content());
    expect(json.keys.toSet(), {
      'profile',
      'skills',
      'projects',
      'experience',
      'education',
      'links',
      'blocks',
      'resumeText',
      'theme',
    });
    for (final privateKey in ['notes', 'email', 'pendingSync', 'mutationId']) {
      expect(json.containsKey(privateKey), isFalse);
    }
  });

  test('GitHub source, overrides and ignored decisions are removed from object and JSON', () {
    final original = _content();
    final source = GitHubProjectSource(
      repositoryId: 101,
      name: 'Original source name',
      fullName: 'example/original-source',
      htmlUrl: 'https://github.com/example/original-source',
      description: 'Private original source description',
      language: 'Dart',
      stars: 5,
      forks: 1,
      isFork: false,
      archived: false,
      updatedAt: DateTime.utc(2026, 10, 4),
    );
    final imported = original.copyWith(
      projects: [
        original.projects.first.copyWith(
          source: PortfolioProjectSource.github,
          githubMetadata: GitHubProjectMetadata(
            acceptedSource: source,
            lastGitHubSyncAt: DateTime.utc(2026, 10, 4),
            overrideFields: {PortfolioGitHubField.title},
          ),
        ),
      ],
      ignoredGitHubRepositories: const [
        GitHubIgnoredRepository(
          repositoryId: 202,
          fingerprint: 'private-ignore-fingerprint',
        ),
      ],
    );
    final projected = projectPublicPortfolioContent(imported);
    expect(projected.ignoredGitHubRepositories, isEmpty);
    expect(projected.projects.single.source, PortfolioProjectSource.manual);
    expect(projected.projects.single.githubMetadata, isNull);
    expect(projected.projects.single.title, original.projects.first.title);
    expect(imported.projects.single.githubRepositoryId, 101);
    expect(imported.ignoredGitHubRepositories, isNotEmpty);

    final payload = encodePublicPortfolioContent(imported);
    final project = (payload['projects']! as List).single as Map;
    expect(project.keys.toSet(), {
      'id',
      'title',
      'description',
      'technologies',
      'repositoryUrl',
      'liveUrl',
      'featured',
      'visible',
    });
    final encoded = jsonEncode(payload);
    for (final privatePart in [
      'githubMetadata',
      'acceptedSource',
      'lastGitHubSyncAt',
      'overrideFields',
      'ignoredGitHubRepositories',
      'private-ignore-fingerprint',
      'Private original source description',
      'Original source name',
    ]) {
      expect(encoded, isNot(contains(privatePart)), reason: privatePart);
    }
    final decoded = decodePortfolioContent(payload);
    expect(decoded, projected);
  });
}

PortfolioContent _visible(
  PortfolioContent source,
  Set<PortfolioBlockKind> visible,
) => source.copyWith(
  blocks: source.blocks
      .map((block) => block.copyWith(visible: visible.contains(block.kind)))
      .toList(),
);

PortfolioContent _content() => PortfolioContent(
  profile: const PortfolioProfile(
    name: 'Private name',
    username: 'private-user',
    headline: 'Developer',
    bio: 'About text',
    locationText: 'Almaty',
    avatarUrl: 'https://example.com/avatar.png',
  ),
  skills: [const Skill(id: 'dart', name: 'Dart')],
  projects: [
    PortfolioProject(
      id: 'public-project',
      title: 'Public',
      description: '',
      technologies: const [],
      featured: true,
    ),
    PortfolioProject(
      id: 'hidden-project',
      title: 'Hidden',
      description: '',
      technologies: const [],
      featured: true,
      visible: false,
    ),
    PortfolioProject(
      id: 'not-featured',
      title: 'Other',
      description: '',
      technologies: const [],
    ),
  ],
  experience: [
    const Experience(
      id: 'work',
      role: 'Engineer',
      organization: 'Example',
      period: '',
      description: '',
    ),
  ],
  education: [
    const Education(
      id: 'alma',
      institution: 'AlmaU',
      qualification: 'Software Engineering',
      period: '',
      description: '',
    ),
  ],
  links: [
    const SocialLink(
      id: 'github',
      label: 'GitHub',
      url: 'https://github.com/example',
      kind: SocialLinkKind.github,
    ),
    const SocialLink(
      id: 'website',
      label: 'Website',
      url: 'https://example.com',
      kind: SocialLinkKind.website,
    ),
  ],
  resumeText: 'Private resume',
);
