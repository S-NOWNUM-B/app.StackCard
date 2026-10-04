import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final checkedAt = DateTime.utc(2026, 10, 4, 10);

  test(
    'Import creates one curated GitHub project without mutating its source',
    () {
      final initial = PortfolioContent();
      final source = _source();
      final imported = addGitHubProject(
        initial,
        source,
        validatedAt: checkedAt,
      );
      final project = imported.projects.single;
      expect(initial.projects, isEmpty);
      expect(project.id, 'github-42');
      expect(project.source, PortfolioProjectSource.github);
      expect(project.githubRepositoryId, 42);
      expect(project.lastGitHubSyncAt, checkedAt);
      expect(project.title, source.name);
      expect(project.description, source.description);
      expect(project.technologies, ['Dart']);
      expect(project.repositoryUrl, source.htmlUrl);
      expect(project.liveUrl, isEmpty);
      expect(project.featured, isFalse);
      expect(project.githubMetadata!.overrideFields, isEmpty);
      expect(validatePortfolioContent(imported), isEmpty);
    },
  );

  test('Repeated import is stable by repository ID even after rename', () {
    final initial = addGitHubProject(PortfolioContent(), _source());
    final renamed = _source(
      name: 'renamed',
      fullName: 'snownumb/renamed',
      htmlUrl: 'https://github.com/snownumb/renamed',
    );
    final repeated = addGitHubProject(initial, renamed);
    expect(repeated.projects.length, 1);
    expect(repeated.projects.single, initial.projects.single);
    expect(
      reviewGitHubProject(repeated, renamed).status,
      PortfolioGitHubReviewStatus.changesAvailable,
    );
  });

  test('An existing manual project ID cannot be overwritten by import', () {
    final initial = PortfolioContent(
      projects: [
        PortfolioProject(
          id: 'github-42',
          title: 'Manual project',
          description: '',
          technologies: [],
        ),
      ],
    );
    expect(
      () => addGitHubProject(initial, _source()),
      throwsA(_failure(PortfolioGitHubFailureKind.conflict)),
    );
    expect(initial.projects.single.source, PortfolioProjectSource.manual);
    expect(initial.projects.single.title, 'Manual project');
  });

  test(
    'Review detects metadata-only changes without editing curated fields',
    () {
      final initial = addGitHubProject(PortfolioContent(), _source());
      final review = reviewGitHubProject(initial, _source(stars: 99));
      expect(review.status, PortfolioGitHubReviewStatus.changesAvailable);
      expect(review.changedFields, isEmpty);
      expect(review.project, initial.projects.single);
      expect(initial.projects.single.githubMetadata!.acceptedSource.stars, 12);
      expect(
        reviewGitHubProject(initial, _source()).status,
        PortfolioGitHubReviewStatus.synced,
      );
    },
  );

  test('User edits mark only actually changed source-backed fields', () {
    final original = addGitHubProject(
      PortfolioContent(),
      _source(),
    ).projects.single;
    final ownerOnly = original.withUserEdits(
      original.copyWith(
        liveUrl: 'https://example.com/demo',
        featured: true,
        visible: false,
      ),
    );
    expect(ownerOnly.githubMetadata!.overrideFields, isEmpty);
    final overridden = ownerOnly.withUserEdits(
      ownerOnly.copyWith(
        title: 'Owner title',
        description: '',
        technologies: [],
        repositoryUrl: '',
      ),
    );
    expect(
      overridden.githubMetadata!.overrideFields,
      PortfolioGitHubField.values.toSet(),
    );
    expect(
      overridden.githubMetadata!.acceptedSource,
      original.githubMetadata!.acceptedSource,
    );
    expect(overridden.liveUrl, ownerOnly.liveUrl);
    expect(overridden.featured, isTrue);
    expect(overridden.visible, isFalse);
    final unchanged = overridden.withUserEdits(overridden.copyWith());
    expect(unchanged, overridden);
  });

  test('Accept preserves blank overrides and owner-only fields while advancing source', () {
    final imported = addGitHubProject(
      PortfolioContent(),
      _source(),
      validatedAt: checkedAt,
    );
    final original = imported.projects.single;
    final curated = original.withUserEdits(
      original.copyWith(
        title: 'Owner title',
        description: '',
        technologies: [],
        repositoryUrl: '',
        liveUrl: 'https://example.com/demo',
        featured: true,
        visible: false,
      ),
    );
    final initial = imported.copyWith(projects: [curated]);
    final refreshed = _source(
      name: 'new-name',
      description: 'New source description',
      language: 'TypeScript',
      stars: 100,
    );
    final result = acceptGitHubProjectChanges(
      initial,
      reviewGitHubProject(initial, refreshed),
      validatedAt: checkedAt.add(const Duration(days: 1)),
    );
    final project = result.projects.single;
    expect(project.title, 'Owner title');
    expect(project.description, isEmpty);
    expect(project.technologies, isEmpty);
    expect(project.repositoryUrl, isEmpty);
    expect(project.liveUrl, curated.liveUrl);
    expect(project.featured, isTrue);
    expect(project.visible, isFalse);
    expect(project.githubMetadata!.acceptedSource, refreshed);
    expect(project.lastGitHubSyncAt, checkedAt.add(const Duration(days: 1)));
    expect(curated.githubMetadata!.acceptedSource, _source());
  });

  test('Accept updates unoverridden source-backed fields only', () {
    final imported = addGitHubProject(PortfolioContent(), _source());
    final initial = imported.copyWith(
      projects: [
        imported.projects.single.copyWith(
          featured: true,
          visible: false,
          liveUrl: 'https://example.com/live',
        ),
      ],
    );
    final refreshed = _source(
      name: 'renamed',
      description: 'New description',
      language: 'Java',
      htmlUrl: 'https://github.com/snownumb/renamed',
    );
    final review = reviewGitHubProject(initial, refreshed);
    expect(review.changedFields, PortfolioGitHubField.values.toSet());
    final accepted = acceptGitHubProjectChanges(
      initial,
      review,
    ).projects.single;
    expect(accepted.title, 'renamed');
    expect(accepted.description, 'New description');
    expect(accepted.technologies, ['Java']);
    expect(accepted.repositoryUrl, refreshed.htmlUrl);
    expect(accepted.featured, isTrue);
    expect(accepted.visible, isFalse);
    expect(accepted.liveUrl, 'https://example.com/live');
  });

  test(
    'Unknown source validation time stays null after explicit acceptance',
    () {
      final initial = addGitHubProject(
        PortfolioContent(),
        _source(),
        validatedAt: checkedAt,
      );
      final review = reviewGitHubProject(initial, _source(stars: 50));
      expect(
        acceptGitHubProjectChanges(
          initial,
          review,
        ).projects.single.lastGitHubSyncAt,
        isNull,
      );
    },
  );

  test('A stale review cannot replace a project changed by its owner', () {
    final initial = addGitHubProject(PortfolioContent(), _source());
    final review = reviewGitHubProject(
      initial,
      _source(description: 'New source'),
    );
    final original = initial.projects.single;
    final edited = original.withUserEdits(
      original.copyWith(description: 'Owner changed after review'),
    );
    final current = initial.copyWith(projects: [edited]);
    expect(
      () => acceptGitHubProjectChanges(current, review),
      throwsA(_failure(PortfolioGitHubFailureKind.conflict)),
    );
    expect(current.projects.single.description, 'Owner changed after review');
    expect(
      () => acceptGitHubProjectChanges(current.copyWith(projects: []), review),
      throwsA(_failure(PortfolioGitHubFailureKind.conflict)),
    );
  });

  test(
    'Ignore suppresses exactly one observed fingerprint and is idempotent',
    () {
      final source = _source();
      final initial = PortfolioContent();
      final ignored = ignoreGitHubProject(initial, source);
      expect(ignored.projects, isEmpty);
      expect(
        ignored.ignoredGitHubRepositories.single.repositoryId,
        source.repositoryId,
      );
      expect(
        reviewGitHubProject(ignored, source).status,
        PortfolioGitHubReviewStatus.ignored,
      );
      expect(ignoreGitHubProject(ignored, source), ignored);
      expect(
        reviewGitHubProject(ignored, _source(stars: 20)).status,
        PortfolioGitHubReviewStatus.newRepository,
      );
      expect(
        addGitHubProject(ignored, source).ignoredGitHubRepositories,
        isEmpty,
      );
    },
  );

  test(
    'Accept clears ignored proposals without affecting another repository',
    () {
      final initial = addGitHubProject(PortfolioContent(), _source());
      final latest = _source(stars: 20);
      final ignored = ignoreGitHubProject(
        ignoreGitHubProject(initial, latest),
        _source(id: 99),
      );
      final review = reviewGitHubProject(ignored, latest);
      expect(review.status, PortfolioGitHubReviewStatus.ignored);
      final result = acceptGitHubProjectChanges(ignored, review);
      expect(
        result.ignoredGitHubRepositories.map((item) => item.repositoryId),
        [99],
      );
      expect(
        reviewGitHubProject(result, latest).status,
        PortfolioGitHubReviewStatus.synced,
      );
    },
  );

  test('Fingerprint has a fixed cross-runtime value and includes every source field', () {
    final source = _source();
    expect(source.fingerprint, 'v1:7ae35202f179c4e8');
    final changed = [
      _source(id: 43),
      _source(name: 'other'),
      _source(fullName: 'other/stackcard'),
      _source(htmlUrl: 'https://github.com/other/stackcard'),
      _source(description: ''),
      _source(language: ''),
      _source(stars: 13),
      _source(forks: 4),
      _source(isFork: true),
      _source(archived: true),
      _source(updatedAt: DateTime.utc(2026, 10, 4, 0, 0, 1)),
    ];
    for (final value in changed) {
      expect(value.fingerprint, isNot(source.fingerprint));
    }
    expect(_source().fingerprint, source.fingerprint);
  });

  test('Domain validation rejects malformed links and duplicate repository identities', () {
    final initial = addGitHubProject(PortfolioContent(), _source());
    final project = initial.projects.single;
    expect(
      validatePortfolioContent(
        initial.copyWith(
          projects: [
            project,
            project.copyWith(id: 'other-id'),
          ],
        ),
      ),
      contains(PortfolioValidationCode.duplicateId),
    );
    expect(
      validatePortfolioContent(
        PortfolioContent(
          projects: [
            PortfolioProject(
              id: 'broken',
              title: 'Broken',
              description: '',
              technologies: [],
              source: PortfolioProjectSource.github,
            ),
          ],
        ),
      ),
      contains(PortfolioValidationCode.invalidStructure),
    );
    expect(
      validatePortfolioContent(
        initial.copyWith(
          projects: [project.copyWith(source: PortfolioProjectSource.manual)],
        ),
      ),
      contains(PortfolioValidationCode.invalidStructure),
    );
    expect(
      validatePortfolioContent(
        initial.copyWith(
          ignoredGitHubRepositories: const [
            GitHubIgnoredRepository(repositoryId: 42, fingerprint: 'one'),
            GitHubIgnoredRepository(repositoryId: 42, fingerprint: 'two'),
          ],
        ),
      ),
      contains(PortfolioValidationCode.duplicateId),
    );
  });

  test('Invalid source/content produce typed failures without mutations', () {
    final content = PortfolioContent();
    for (final source in [
      _source(id: 0),
      _source(stars: -1),
      _source(name: ' '),
      _source(htmlUrl: 'javascript:alert(1)'),
      _source(language: ''),
      _source(description: 'x' * 4001),
    ]) {
      expect(
        () => addGitHubProject(content, source),
        throwsA(_failure(PortfolioGitHubFailureKind.invalidSource)),
      );
      expect(content.projects, isEmpty);
    }
    expect(
      () => ignoreGitHubProject(PortfolioContent(blocks: []), _source()),
      throwsA(_failure(PortfolioGitHubFailureKind.invalidContent)),
    );
  });

  test(
    'Metadata and ignore collections are immutable and compare structurally',
    () {
      final fields = {
        PortfolioGitHubField.title,
        PortfolioGitHubField.description,
      };
      final metadata = GitHubProjectMetadata(
        acceptedSource: _source(),
        overrideFields: fields,
      );
      fields.clear();
      expect(metadata.overrideFields.length, 2);
      expect(() => metadata.overrideFields.clear(), throwsUnsupportedError);
      final same = GitHubProjectMetadata(
        acceptedSource: _source(),
        overrideFields: {
          PortfolioGitHubField.description,
          PortfolioGitHubField.title,
        },
      );
      expect(same, metadata);
      expect(same.hashCode, metadata.hashCode);
      final ignored = [
        GitHubIgnoredRepository(
          repositoryId: 42,
          fingerprint: _source().fingerprint,
        ),
      ];
      final content = PortfolioContent(ignoredGitHubRepositories: ignored);
      ignored.clear();
      expect(content.ignoredGitHubRepositories.length, 1);
      expect(
        () => content.ignoredGitHubRepositories.clear(),
        throwsUnsupportedError,
      );
      expect(
        content,
        PortfolioContent(
          ignoredGitHubRepositories: [
            GitHubIgnoredRepository(
              repositoryId: 42,
              fingerprint: _source().fingerprint,
            ),
          ],
        ),
      );
    },
  );
}

Matcher _failure(PortfolioGitHubFailureKind kind) =>
    isA<PortfolioGitHubFailure>().having(
      (failure) => failure.kind,
      'kind',
      kind,
    );

GitHubProjectSource _source({
  int id = 42,
  String name = 'stackcard',
  String fullName = 'snownumb/stackcard',
  String htmlUrl = 'https://github.com/snownumb/stackcard',
  String description = 'Source description',
  String language = 'Dart',
  int stars = 12,
  int forks = 3,
  bool isFork = false,
  bool archived = false,
  DateTime? updatedAt,
}) => GitHubProjectSource(
  repositoryId: id,
  name: name,
  fullName: fullName,
  htmlUrl: htmlUrl,
  description: description,
  language: language,
  stars: stars,
  forks: forks,
  isFork: isFork,
  archived: archived,
  updatedAt: updatedAt ?? DateTime.utc(2026, 10, 4),
);
