import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 4, 12);

void main() {
  test('Empty portfolio and sources have no suggestions', () {
    expect(_build(PortfolioContent()), isEmpty);
  });

  test('A new repository proposes source preview rather than editing', () {
    final source = _source();
    final suggestion = _build(PortfolioContent(), [source]).single;
    expect(suggestion.kind, PortfolioSuggestionKind.newRepository);
    expect(suggestion.action, PortfolioSuggestionAction.previewRepository);
    expect(suggestion.id, 'newRepository:repository:42');
    expect(suggestion.projectId, isNull);
    expect(suggestion.repositoryId, 42);
    expect(suggestion.targetTitle, source.name);
    expect(suggestion.stars, source.stars);
    expect(suggestion.updatedAt, source.updatedAt);
  });

  test('New forks and archived repositories are not recommended', () {
    expect(
      _build(PortfolioContent(), [
        _source(id: 1, isFork: true),
        _source(id: 2, archived: true),
      ]),
      isEmpty,
    );
  });

  test('Imported repositories including hidden projects are not new', () {
    final source = _source();
    final content = PortfolioContent(
      projects: [_imported(source).copyWith(visible: false)],
    );
    expect(_build(content, [source]), isEmpty);
  });

  test('Ignoring a new version suppresses it until the source changes', () {
    final source = _source();
    final content = ignoreGitHubProject(PortfolioContent(), source);
    expect(_build(content, [source]), isEmpty);
    final changed = _source(stars: source.stars + 1);
    expect(
      _build(content, [changed]).single.kind,
      PortfolioSuggestionKind.newRepository,
    );
    expect(
      content.ignoredGitHubRepositories.single.fingerprint,
      source.fingerprint,
    );
  });

  for (final age in [
    Duration.zero,
    const Duration(days: 30),
    const Duration(days: 30, microseconds: 1),
    const Duration(microseconds: -1),
  ]) {
    test('Recent activity uses the exact 0–30 day boundary: $age', () {
      final source = _source(updatedAt: _now.subtract(age), stars: 0);
      final content = PortfolioContent(projects: [_imported(source)]);
      final kinds = _kinds(_build(content));
      final expected = !age.isNegative && age <= const Duration(days: 30);
      expect(kinds.contains(PortfolioSuggestionKind.recentActivity), expected);
      expect(
        kinds.contains(PortfolioSuggestionKind.featuredCandidate),
        expected,
      );
    });
  }

  for (final age in [
    const Duration(days: 180, microseconds: -1),
    const Duration(days: 180),
    const Duration(days: 181),
  ]) {
    test('Inactive activity starts at exactly 180 days: $age', () {
      final source = _source(updatedAt: _now.subtract(age), stars: 0);
      final content = PortfolioContent(projects: [_imported(source)]);
      expect(
        _kinds(_build(content))
            .contains(PortfolioSuggestionKind.inactiveProject),
        age >= const Duration(days: 180),
      );
      expect(
        _kinds(_build(content))
            .contains(PortfolioSuggestionKind.recentActivity),
        isFalse,
      );
    });
  }

  test('Future activity is not recent or inactive; stars remain usable', () {
    final source = _source(
      updatedAt: _now.add(const Duration(days: 1)),
      stars: 5,
    );
    final suggestions = _build(PortfolioContent(projects: [_imported(source)]));
    expect(_kinds(suggestions), {
      PortfolioSuggestionKind.missingPreview,
      PortfolioSuggestionKind.featuredCandidate,
    });
    expect(suggestions.last.stars, 5);
    expect(suggestions.last.updatedAt, source.updatedAt);
  });

  test(
    'UTC and local representations of the same now produce equal results',
    () {
      final source = _source(
        updatedAt: _now.subtract(const Duration(days: 30)),
      );
      final content = PortfolioContent(projects: [_imported(source)]);
      expect(
        buildPortfolioSuggestions(content: content, now: _now.toLocal()),
        _build(content),
      );
    },
  );

  test('Missing description and preview inspect trimmed curated fields', () {
    final project = _manual(description: ' \n ', liveUrl: ' \t ');
    final suggestions = _build(PortfolioContent(projects: [project]));
    expect(_kinds(suggestions), {
      PortfolioSuggestionKind.missingDescription,
      PortfolioSuggestionKind.missingPreview,
    });
    expect(
      suggestions.every(
        (item) => item.action == PortfolioSuggestionAction.editProject,
      ),
      isTrue,
    );
    expect(suggestions.every((item) => item.projectId == project.id), isTrue);
    expect(suggestions.every((item) => item.repositoryId == null), isTrue);
    expect(suggestions.every((item) => item.updatedAt == null), isTrue);
  });

  test('Manual and legacy projects need curated completeness and demo for featured', () {
    final content = PortfolioContent(
      projects: [
        _manual(id: 'eligible'),
        _manual(id: 'no-demo', liveUrl: ''),
        _manual(id: 'no-description', description: ''),
        _manual(id: 'no-tech', technologies: []),
        _manual(id: 'blank-tech', technologies: [' ']),
      ],
    );
    expect(
      _build(content)
          .where(
            (item) => item.kind == PortfolioSuggestionKind.featuredCandidate,
          )
          .map((item) => item.projectId),
      ['eligible'],
    );
    expect(
      _kinds(_build(content)).intersection({
        PortfolioSuggestionKind.recentActivity,
        PortfolioSuggestionKind.inactiveProject,
      }),
      isEmpty,
    );
  });

  test(
    'Featured projects do not get candidates and hidden projects get no advice',
    () {
      final content = PortfolioContent(
        projects: [
          _manual(id: 'featured', featured: true),
          _manual(id: 'hidden', visible: false, description: '', liveUrl: ''),
        ],
      );
      expect(_build(content), isEmpty);
    },
  );

  test('Featured imported projects can still get other useful advice', () {
    final source = _source(description: '');
    final suggestions = _build(
      PortfolioContent(projects: [_imported(source).copyWith(featured: true)]),
    );
    expect(_kinds(suggestions), {
      PortfolioSuggestionKind.recentActivity,
      PortfolioSuggestionKind.missingDescription,
      PortfolioSuggestionKind.missingPreview,
    });
  });

  test('Imported forks and archived projects retain advice but cannot be featured candidates', () {
    final content = PortfolioContent(
      projects: [
        _imported(_source(id: 1, isFork: true)),
        _imported(_source(id: 2, archived: true)),
      ],
    );
    final suggestions = _build(content);
    expect(
      suggestions.where(
        (item) => item.kind == PortfolioSuggestionKind.featuredCandidate,
      ),
      isEmpty,
    );
    expect(
      suggestions
          .where((item) => item.kind == PortfolioSuggestionKind.recentActivity)
          .length,
      2,
    );
  });

  test(
    'Featured GitHub threshold is five stars when the source is not recent',
    () {
      final oldDate = _now.subtract(const Duration(days: 31));
      final content = PortfolioContent(
        projects: [
          _imported(_source(id: 1, updatedAt: oldDate, stars: 4)),
          _imported(_source(id: 2, updatedAt: oldDate, stars: 5)),
        ],
      );
      expect(
        _build(content)
            .where(
              (item) => item.kind == PortfolioSuggestionKind.featuredCandidate,
            )
            .map((item) => item.repositoryId),
        [2],
      );
    },
  );

  test('Accepted source supplies activity without fetched pages', () {
    final source = _source(updatedAt: _now.subtract(const Duration(days: 180)));
    final suggestions = _build(PortfolioContent(projects: [_imported(source)]));
    final inactive = suggestions.singleWhere(
      (item) => item.kind == PortfolioSuggestionKind.inactiveProject,
    );
    expect(inactive.updatedAt, source.updatedAt);
    expect(inactive.repositoryId, source.repositoryId);
  });

  test('Fetched source replaces accepted activity without changing curated content', () {
    final accepted = _source(
      updatedAt: _now.subtract(const Duration(days: 200)),
      stars: 0,
    );
    final project = _imported(accepted);
    final fetched = _source(name: 'renamed', description: '', language: null);
    final suggestions = _build(PortfolioContent(projects: [project]), [
      fetched,
    ]);
    expect(
      _kinds(suggestions).contains(PortfolioSuggestionKind.recentActivity),
      isTrue,
    );
    expect(
      _kinds(suggestions).contains(PortfolioSuggestionKind.inactiveProject),
      isFalse,
    );
    expect(
      _kinds(suggestions).contains(PortfolioSuggestionKind.missingDescription),
      isFalse,
    );
    expect(
      _kinds(suggestions).contains(PortfolioSuggestionKind.featuredCandidate),
      isTrue,
    );
    expect(
      suggestions.every((item) => item.targetTitle == project.title),
      isTrue,
    );
    expect(project.githubMetadata!.acceptedSource, accepted);
  });

  test('Manual overrides determine completeness rather than fetched description or links', () {
    final source = _source();
    final initial = _imported(source);
    final overridden = initial.withUserEdits(
      initial.copyWith(
        title: 'Owner title',
        description: '',
        technologies: [],
        repositoryUrl: '',
      ),
    );
    final suggestions = _build(PortfolioContent(projects: [overridden]), [
      _source(stars: 100),
    ]);
    expect(
      _kinds(suggestions).contains(PortfolioSuggestionKind.missingDescription),
      isTrue,
    );
    expect(
      _kinds(suggestions).contains(PortfolioSuggestionKind.featuredCandidate),
      isFalse,
    );
    expect(
      suggestions.every((item) => item.targetTitle == 'Owner title'),
      isTrue,
    );
    expect(overridden.githubMetadata!.overrideFields, {
      PortfolioGitHubField.title,
      PortfolioGitHubField.description,
      PortfolioGitHubField.technologies,
      PortfolioGitHubField.repositoryUrl,
    });
  });

  test('GitHub candidate requires a curated repository or demo link', () {
    final source = _source();
    final project = _imported(source)
        .copyWith(repositoryUrl: ' ', liveUrl: ' ');
    expect(
      _kinds(_build(PortfolioContent(projects: [project])))
          .contains(PortfolioSuggestionKind.featuredCandidate),
      isFalse,
    );
    expect(
      _kinds(
        _build(
          PortfolioContent(
            projects: [project.copyWith(liveUrl: 'https://example.com')],
          ),
        ),
      ).contains(PortfolioSuggestionKind.featuredCandidate),
      isTrue,
    );
  });

  test('Current ignored import suppresses source hints but retains curated omissions', () {
    final source = _source();
    final project = _imported(source).copyWith(description: '');
    final content = ignoreGitHubProject(
      PortfolioContent(projects: [project]),
      source,
    );
    expect(_kinds(_build(content)), {
      PortfolioSuggestionKind.missingDescription,
      PortfolioSuggestionKind.missingPreview,
    });
    final changed = _source(stars: 99);
    expect(
      _kinds(_build(content, [changed]))
          .contains(PortfolioSuggestionKind.recentActivity),
      isTrue,
    );
  });

  test('Ignore suppresses a complete imported featured candidate until source changes', () {
    final source = _source();
    final content = ignoreGitHubProject(
      PortfolioContent(projects: [_imported(source)]),
      source,
    );
    expect(_kinds(_build(content)), {PortfolioSuggestionKind.missingPreview});
    expect(
      _kinds(_build(content, [_source(stars: 99)]))
          .contains(PortfolioSuggestionKind.featuredCandidate),
      isTrue,
    );
  });

  test('Source dedup picks latest activity regardless of input order', () {
    final oldSource = _source(
      updatedAt: _now.subtract(const Duration(days: 200)),
      stars: 0,
    );
    final newSource = _source(stars: 6);
    final content = PortfolioContent(projects: [_imported(oldSource)]);
    final forward = _build(content, [oldSource, newSource, oldSource]);
    expect(_build(content, [newSource, oldSource, newSource]), forward);
    expect(forward.first.updatedAt, newSource.updatedAt);
    expect(forward.first.stars, 6);
    expect(
      _kinds(forward).contains(PortfolioSuggestionKind.inactiveProject),
      isFalse,
    );
  });

  test(
    'Equal-date dedup resolves by stable fingerprint rather than input order',
    () {
      final left = _source(name: 'left', stars: 0);
      final right = _source(name: 'right', stars: 8);
      final winner = left.fingerprint.compareTo(right.fingerprint) > 0
          ? left
          : right;
      final forward = _build(PortfolioContent(), [left, right]);
      expect(_build(PortfolioContent(), [right, left]), forward);
      expect(forward.single.targetTitle, winner.name);
      expect(forward.single.stars, winner.stars);
    },
  );

  test('Sources and curated ordering do not change suggestion ordering', () {
    final first = _manual(id: 'a', liveUrl: '');
    final second = _manual(id: 'b', description: '');
    final sources = [_source(id: 2), _source(id: 1)];
    final forward = _build(
      PortfolioContent(projects: [first, second]),
      sources,
    );
    final reverse = _build(
      PortfolioContent(projects: [second, first]),
      sources.reversed,
    );
    expect(reverse, forward);
    expect(forward.take(2).map((item) => item.id), [
      'newRepository:repository:1',
      'newRepository:repository:2',
    ]);
    expect(forward.map((item) => item.id).toSet().length, forward.length);
  });

  test('Invalid sources are skipped and invalid supplied versions preserve fallback', () {
    final accepted = _source();
    final content = PortfolioContent(projects: [_imported(accepted)]);
    final sources = [
      _source(id: 0),
      _source(id: 2, name: ' '),
      _source(id: 3, stars: -1),
      _source(id: 4, htmlUrl: 'invalid'),
      _source(id: 5, language: ' '),
      _source(id: accepted.repositoryId, stars: -1),
    ];
    expect(_build(content, sources), _build(content));
    expect(_build(PortfolioContent(), sources), isEmpty);
  });

  test('Missing invalid GitHub metadata still allows curated field advice', () {
    final invalidProject = _manual(
      description: '',
      liveUrl: '',
    ).copyWith(source: PortfolioProjectSource.github);
    expect(_kinds(_build(PortfolioContent(projects: [invalidProject]))), {
      PortfolioSuggestionKind.missingDescription,
      PortfolioSuggestionKind.missingPreview,
    });
  });

  test('Repeated calls preserve inputs and return immutable equal values', () {
    final source = _source();
    final project = _imported(source);
    final content = PortfolioContent(projects: [project]);
    final sources = [source, _source(id: 7)];
    final sourceSnapshot = List.of(sources);
    final contentSnapshot = content.copyWith();
    final first = _build(content, sources);
    final second = _build(content, sources);
    expect(first, second);
    expect(
      first.map((item) => item.hashCode),
      second.map((item) => item.hashCode),
    );
    expect(() => first.clear(), throwsUnsupportedError);
    expect(sources, sourceSnapshot);
    expect(content, contentSnapshot);
    expect(content.projects.single, project);
    expect(project.githubMetadata!.acceptedSource, source);
  });

  test('Suggestion equality covers evidence while identity remains stable through rename', () {
    final first = PortfolioSuggestion(
      kind: PortfolioSuggestionKind.recentActivity,
      action: PortfolioSuggestionAction.editProject,
      targetTitle: 'Original',
      projectId: 'github-42',
      repositoryId: 42,
      updatedAt: _now,
      stars: 5,
    );
    final equal = PortfolioSuggestion(
      kind: first.kind,
      action: first.action,
      targetTitle: first.targetTitle,
      projectId: first.projectId,
      repositoryId: first.repositoryId,
      updatedAt: _now.toLocal(),
      stars: first.stars,
    );
    final renamed = PortfolioSuggestion(
      kind: first.kind,
      action: first.action,
      targetTitle: 'Renamed',
      projectId: first.projectId,
      repositoryId: first.repositoryId,
      updatedAt: _now,
      stars: 99,
    );
    expect(first, equal);
    expect(first.hashCode, equal.hashCode);
    expect(first.updatedAt!.isUtc, isTrue);
    expect(renamed, isNot(first));
    expect(renamed.id, first.id);
  });
}

List<PortfolioSuggestion> _build(
  PortfolioContent content, [
  Iterable<GitHubProjectSource> sources = const [],
]) => buildPortfolioSuggestions(content: content, sources: sources, now: _now);

Set<PortfolioSuggestionKind> _kinds(
  Iterable<PortfolioSuggestion> suggestions,
) => suggestions.map((item) => item.kind).toSet();

PortfolioProject _manual({
  String id = 'manual',
  String description = 'Curated description',
  List<String> technologies = const ['Dart'],
  String liveUrl = 'https://example.com/demo',
  bool featured = false,
  bool visible = true,
}) => PortfolioProject(
  id: id,
  title: 'Manual project',
  description: description,
  technologies: technologies,
  liveUrl: liveUrl,
  featured: featured,
  visible: visible,
);

PortfolioProject _imported(GitHubProjectSource source) =>
    addGitHubProject(PortfolioContent(), source).projects.single;

GitHubProjectSource _source({
  int id = 42,
  String name = 'stackcard',
  String? description = 'Source description',
  String? language = 'Dart',
  String htmlUrl = 'https://github.com/snownumb/stackcard',
  int stars = 5,
  bool isFork = false,
  bool archived = false,
  DateTime? updatedAt,
}) => GitHubProjectSource(
  repositoryId: id,
  name: name,
  fullName: 'snownumb/$name',
  htmlUrl: htmlUrl,
  description: description,
  language: language,
  stars: stars,
  forks: 0,
  isFork: isFork,
  archived: archived,
  updatedAt: updatedAt ?? _now,
);
