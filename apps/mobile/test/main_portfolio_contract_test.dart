import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_public_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_validation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft_providers.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_draft_controller.dart';

final _now = DateTime.utc(2026, 10, 11);
PortfolioDocument _document({
  String id = 'legacy',
  PortfolioContent? content,
}) => PortfolioDocument(
  id: id,
  title: 'Старое резюме',
  kind: PortfolioDocumentKind.resume,
  createdAt: _now,
  updatedAt: _now,
  content: content ?? PortfolioContent(),
  projects: const [PortfolioProjectAttachment(projectId: 'project')],
);
PortfolioProject _project() => PortfolioProject(
  id: 'project',
  title: 'Проект',
  description: '',
  technologies: const [],
  iconId: 'home',
  imagePaths: const [
    'accounts/owner/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
  ],
);
PortfolioContent _workspace() {
  final source = PortfolioContent(
    profile: const PortfolioProfile(
      name: 'Автор',
      locationText: 'Скрытый город',
      publishLocation: false,
    ),
    skills: const [Skill(id: 'skill', name: 'Dart')],
  );
  return PortfolioContent(
    profile: source.profile,
    skills: source.skills,
    projects: [_project()],
    documents: [_document(content: source)],
  );
}

void main() {
  test('GitHub profile identity normalizes separately from portfolio slug', () {
    for (final input in [
      'SNOWNUMB',
      '  snownumb  ',
      'https://github.com/SNOWNUMB/',
    ]) {
      expect(normalizePortfolioGitHubUsername(input), 'snownumb');
    }
    expect(normalizePortfolioGitHubUsername(' '), '');
    for (final input in [
      'https://github.com/user/repo',
      'https://github.com/user?tab=repositories',
      'https://evil.test/user',
      'https://user@github.com/name',
      'https://github.com:443/name',
      'https://github.com//name',
      'two--hyphens',
      '-leading',
      'trailing-',
    ]) {
      expect(normalizePortfolioGitHubUsername(input), isNull, reason: input);
    }
  });
  test(
    'Pasted GitHub profile URL accepts uppercase username with optional slash',
    () {
      for (final input in [
        'https://github.com/LINESKL',
        'https://github.com/LINESKL/',
      ]) {
        expect(
          normalizePortfolioGitHubUsername(input),
          'lineskl',
          reason: input,
        );
      }
    },
  );
  test('Legacy hidden location and contacts remain excluded; archive remains exact', () {
    final workspace = _workspace().copyWith(
      links: const [
        SocialLink(
          id: 'private',
          label: 'Почта',
          url: 'mailto:owner@example.com',
          kind: SocialLinkKind.email,
        ),
        SocialLink(
          id: 'public',
          label: 'Сайт',
          url: 'https://example.com',
          kind: SocialLinkKind.website,
          publishAllowed: true,
        ),
      ],
    );
    final source = workspace.documents.single.content.copyWith(
      links: workspace.links,
    );
    final migrated = mainPortfolioMigrationContent(workspace, source);
    expect(migrated.profile.locationText, isEmpty);
    expect(migrated.profile.publishLocation, isTrue);
    expect(migrated.links.map((link) => link.id), ['public']);
    expect(workspace.profile.locationText, 'Скрытый город');
    expect(source.links.length, 2);
    expect(
      mainPortfolioMigrationContent(
        workspace.copyWith(
          profile: workspace.profile.copyWith(publishLocation: true),
        ),
        source.copyWith(
          profile: source.profile.copyWith(publishLocation: true),
        ),
      ).profile.locationText,
      'Скрытый город',
    );
  });
  test(
    'Modern main resolves ordered library relations and removes legacy images',
    () {
      final workspace = _workspace();
      final document = workspace.documents.single.copyWith(
        content: PortfolioContent(
          profile: const PortfolioProfile(locationText: 'Алматы / Казахстан'),
          resumeText: 'Legacy private plaintext',
          blocks: PortfolioBlockKind.values
              .map((kind) => PortfolioBlock(kind: kind, visible: false))
              .toList(),
          links: const [
            SocialLink(
              id: 'new',
              label: 'Сайт',
              url: 'https://example.com',
              kind: SocialLinkKind.website,
              publishAllowed: true,
            ),
          ],
        ),
      );
      final main = workspace.copyWith(
        documents: [document],
        mainPortfolioId: document.id,
        legacyMainSnapshot: workspace.documents.single,
      );
      final resolved = resolvedMainPortfolioContent(main)!;
      expect(resolved.projects.single.iconId, 'home');
      expect(resolved.projects.single.imagePaths, isEmpty);
      expect(resolved.profile.locationText, 'Алматы / Казахстан');
      expect(resolved.links.single.id, 'new');
      expect(resolved.resumeText, isEmpty);
      expect(resolved.blocks[3].kind, PortfolioBlockKind.featuredProjects);
      expect(resolved.blocks[4].kind, PortfolioBlockKind.skills);
      expect(resolved.blocks.last.visible, isFalse);
      expect(document.content.resumeText, 'Legacy private plaintext');
      expect(resolved.mainPortfolioId, isNull);
      expect(resolved.legacyMainSnapshot, isNull);
      final projected = encodePublicPortfolioContent(main);
      expect(projected.containsKey('mainPortfolioId'), isFalse);
      expect(projected.containsKey('legacyMainSnapshot'), isFalse);
      expect(projected['resumeText'], isEmpty);
      final project = (projected['projects'] as List).single as Map;
      expect(project['iconId'], 'home');
      expect(project.containsKey('imagePaths'), isFalse);
    },
  );
  test(
    'Main metadata and archive roundtrip but cannot nest inside snapshots',
    () {
      final workspace = _workspace();
      final main = workspace.copyWith(
        mainPortfolioId: 'legacy',
        githubUsername: 'snownumb',
        personalization: const PortfolioPersonalization(
          status: PortfolioPersonalizationStatus.inProgress,
          step: 2,
        ),
        legacyMainSnapshot: workspace.documents.single,
      );
      expect(decodePortfolioContent(encodePortfolioContent(main)), main);
      final encoded = encodePortfolioContent(main);
      final nested =
          ((encoded['documents'] as List).single as Map)['content'] as Map;
      for (final key in [
        'mainPortfolioId',
        'githubUsername',
        'personalization',
        'legacyMainSnapshot',
      ]) {
        expect(nested.containsKey(key), isFalse);
      }
      nested['githubUsername'] = 'hidden';
      expect(() => decodePortfolioContent(encoded), throwsFormatException);
      expect(
        () => decodePortfolioContent(
          encodePortfolioContent(main),
          allowMainPortfolio: false,
        ),
        throwsFormatException,
      );
      expect(
        validatePortfolioContent(main.copyWith(mainPortfolioId: 'missing')),
        isNotEmpty,
      );
      expect(
        validatePortfolioContent(
          main.copyWith(githubUsername: 'HTTPS://github.com/name'),
        ),
        isNotEmpty,
      );
      expect(
        validatePortfolioContent(
          main.copyWith(
            personalization: const PortfolioPersonalization(step: 4),
          ),
        ),
        isNotEmpty,
      );
    },
  );
  test('Archive survives removal of the original project relation', () {
    final workspace = _workspace();
    final main = workspace.copyWith(
      projects: const [],
      mainPortfolioId: 'legacy',
      documents: [workspace.documents.single.copyWith(projects: const [])],
      legacyMainSnapshot: workspace.documents.single,
    );
    expect(validatePortfolioContent(main), isEmpty);
    expect(decodePortfolioContent(encodePortfolioContent(main)), main);
    expect(main.legacyMainSnapshot!.projects.single.projectId, 'project');
  });
  test(
    'Icon allowlist rejects injected SVG and GitHub refresh retains owner icon',
    () {
      final invalid = PortfolioContent(
        projects: [_project().copyWith(iconId: '<svg/>')],
      );
      expect(validatePortfolioContent(invalid), isNotEmpty);
      var workspace = addGitHubProject(PortfolioContent(), _source());
      final project = workspace.projects.single;
      final edited = project.withUserEdits(
        project.copyWith(title: 'Мой проект', iconId: 'camera'),
      );
      workspace = workspace.copyWith(projects: [edited]);
      final refreshed = acceptGitHubProjectChanges(
        workspace,
        reviewGitHubProject(workspace, _source(name: 'Changed')),
      );
      expect(refreshed.projects.single.title, 'Мой проект');
      expect(refreshed.projects.single.iconId, 'camera');
    },
  );
  test('Cloud7 writer roundtrips metadata and rejects archive media of another UID', () {
    final workspace = _workspace().copyWith(
      mainPortfolioId: 'legacy',
      legacyMainSnapshot: _workspace().documents.single,
    );
    final draft = CloudPortfolioDraft(
      ownerUid: 'owner',
      mutationId: 'main-save',
      localRevision: 1,
      notes: '',
      content: workspace,
    );
    final encoded = encodeCloudPortfolioDraft(draft);
    expect(encoded['schemaVersion'], 7);
    encoded['updatedAt'] = Timestamp.fromDate(_now);
    expect(
      decodeCloudPortfolioDraft(encoded, ownerUid: 'owner').content,
      workspace,
    );
    final archive = workspace.legacyMainSnapshot!;
    final foreign = workspace.copyWith(
      legacyMainSnapshot: archive.copyWith(
        content: archive.content.copyWith(
          profile: archive.content.profile.copyWith(
            avatarPath:
                'accounts/foreign/media/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg',
          ),
        ),
      ),
    );
    expect(
      () => encodeCloudPortfolioDraft(
        CloudPortfolioDraft(
          ownerUid: 'owner',
          mutationId: 'foreign',
          localRevision: 1,
          notes: '',
          content: foreign,
        ),
      ),
      throwsA(isA<PortfolioSyncFailure>()),
    );
  });
  test(
    'Batch imported projects and icon edits survive actual Hive close/reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'stackcard-main-import-',
      );
      var box = await Hive.openBox<dynamic>(
        'main_import',
        path: directory.path,
      );
      ProviderContainer? scope;
      try {
        final repository = HivePortfolioDraftRepository(box);
        scope = ProviderContainer(
          overrides: [
            portfolioDraftRepositoryProvider.overrideWithValue(repository),
          ],
        );
        final controller = scope.read(
          portfolioDraftControllerProvider.notifier,
        );
        await controller.load();
        await controller.initializeMainPortfolio(
          expectedRepository: repository,
        );
        expect(
          await controller.importSelectedGitHubRepositories(
            [_source(), _source()],
            validatedAt: {42: _now},
            expectedRepository: repository,
          ),
          isTrue,
        );
        final imported = (await repository.read())!.content!.projects.single;
        expect(
          await controller.saveProject(
            imported.withUserEdits(
              imported.copyWith(iconId: 'camera', title: 'Owner title'),
            ),
            expectedProject: imported,
            expectedRepository: repository,
          ),
          isTrue,
        );
        scope.dispose();
        scope = null;
        await box.close();
        box = await Hive.openBox<dynamic>('main_import', path: directory.path);
        final restored = (await HivePortfolioDraftRepository(
          box,
        ).read())!.content!;
        expect(restored.projects.length, 1);
        expect(restored.projects.single.githubRepositoryId, 42);
        expect(restored.projects.single.title, 'Owner title');
        expect(restored.projects.single.iconId, 'camera');
        expect(mainPortfolioDocument(restored)!.projects, isEmpty);
      } finally {
        scope?.dispose();
        await box.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('Hive8 preserves raw legacy7 backup, onboarding and immutable archive across restart', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stackcard-main-migration-',
    );
    var box = await Hive.openBox<dynamic>(
      'main_migration',
      path: directory.path,
    );
    try {
      final legacy = encodePortfolioContent(_workspace())
        ..remove('mainPortfolioId')
        ..remove('githubUsername')
        ..remove('personalization')
        ..remove('legacyMainSnapshot');
      for (final project in legacy['projects'] as List) {
        (project as Map).remove('iconId');
      }
      final raw = jsonEncode({
        'schemaVersion': 7,
        'notes': 'точные заметки',
        'revision': 1,
        'updatedAt': _now.toIso8601String(),
        'pendingSync': false,
        'content': legacy,
      });
      await box.put('draft', raw);
      final repository = HivePortfolioDraftRepository(box);
      final read = (await repository.read())!;
      expect(box.get('draft'), raw);
      final main = read.content!.copyWith(
        mainPortfolioId: 'legacy',
        githubUsername: 'snownumb',
        legacyMainSnapshot: read.content!.documents.single,
        personalization: const PortfolioPersonalization(
          status: PortfolioPersonalizationStatus.inProgress,
          step: 2,
        ),
      );
      await repository.save(main, expectedRevision: 1, notes: read.notes);
      expect(box.get('draft.v7.backup'), raw);
      await box.close();
      box = await Hive.openBox<dynamic>('main_migration', path: directory.path);
      final reopened = (await HivePortfolioDraftRepository(box).read())!;
      expect(reopened.content, main);
      expect(reopened.content!.personalization.step, 2);
      expect(reopened.notes, 'точные заметки');
      expect(
        (jsonDecode(box.get('draft') as String) as Map)['schemaVersion'],
        8,
      );
      await expectLater(
        HivePortfolioDraftRepository(box).save(
          main.copyWith(clearLegacyMainSnapshot: true),
          expectedRevision: reopened.revision,
          notes: reopened.notes,
        ),
        throwsA(
          isA<PortfolioDraftFailure>().having(
            (failure) => failure.kind,
            'kind',
            PortfolioDraftFailureKind.conflict,
          ),
        ),
      );
      expect((await HivePortfolioDraftRepository(box).read())!.content, main);
    } finally {
      await box.close();
      await directory.delete(recursive: true);
    }
  });
}

GitHubProjectSource _source({String name = 'Repository'}) =>
    GitHubProjectSource(
      repositoryId: 42,
      name: name,
      fullName: 'owner/$name',
      htmlUrl: 'https://github.com/owner/$name',
      stars: 0,
      forks: 0,
      isFork: false,
      archived: false,
      updatedAt: _now,
    );
