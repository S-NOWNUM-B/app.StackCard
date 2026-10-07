import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:flutter_test/flutter_test.dart';

final _date = DateTime.utc(2026, 10, 7);
PortfolioDocument _document(PortfolioContent base, {PortfolioContent? local}) =>
    PortfolioDocument(
      id: 'document',
      title: 'Resume',
      kind: PortfolioDocumentKind.resume,
      createdAt: _date,
      updatedAt: _date,
      content: local ?? seedDocumentContent(base),
      baseSnapshot: developerProfileData(base),
    );

void main() {
  test(
    'inherited bio is selected; local role stays until explicitly replaced',
    () {
      final old = PortfolioContent(
        profile: const PortfolioProfile(
          name: 'Alex',
          headline: 'Fullstack',
          bio: 'Old bio',
        ),
      );
      final document = _document(
        old,
        local: seedDocumentContent(old).copyWith(
          profile: old.profile.copyWith(headline: 'Frontend'),
          resumeText: 'Legacy resume retained',
          theme: PortfolioTheme.light,
        ),
      );
      final base = old.copyWith(
        profile: old.profile.copyWith(headline: 'Flutter', bio: 'New bio'),
      );
      final review = PortfolioDocumentBaseReview(
        document: document,
        base: base,
      );
      final role = review.changes.singleWhere(
        (change) => change.field == PortfolioDocumentBaseField.headline,
      );
      final bio = review.changes.singleWhere(
        (change) => change.field == PortfolioDocumentBaseField.bio,
      );
      expect(role.previousValue, 'Fullstack');
      expect(role.currentValue, 'Frontend');
      expect(role.incomingValue, 'Flutter');
      expect(role.hasLocalOverride, isTrue);
      expect(role.defaultSelected, isFalse);
      expect(bio.defaultSelected, isTrue);
      final applied = review.apply({bio.key});
      expect(applied.content.profile.headline, 'Frontend');
      expect(applied.content.profile.bio, 'New bio');
      expect(applied.content.theme, PortfolioTheme.light);
      expect(applied.content.resumeText, 'Legacy resume retained');
      expect(applied.baseSnapshot, developerProfileData(base));
      expect(document.content.profile.bio, 'Old bio');
      expect(base.profile.headline, 'Flutter');
      expect(review.apply({role.key}).content.profile.headline, 'Flutter');
    },
  );

  test(
    'per-ID additions, updates, removals keep local values and document order',
    () {
      final old = PortfolioContent(
        skills: const [
          Skill(id: 'shared', name: 'Dart'),
          Skill(id: 'removed', name: 'Old skill'),
          Skill(id: 'local-edit', name: 'Base skill'),
          Skill(id: 'local-removal', name: 'Hidden skill'),
        ],
      );
      final document = _document(
        old,
        local: seedDocumentContent(old).copyWith(
          skills: const [
            Skill(id: 'local-only', name: 'My own skill'),
            Skill(id: 'local-edit', name: 'My edited skill'),
            Skill(id: 'shared', name: 'Dart'),
            Skill(id: 'removed', name: 'Old skill'),
          ],
        ),
      );
      final base = old.copyWith(
        skills: const [
          Skill(id: 'shared', name: 'Dart 3'),
          Skill(id: 'new', name: 'Flutter'),
          Skill(id: 'local-edit', name: 'New base skill'),
          Skill(id: 'local-removal', name: 'New hidden skill'),
        ],
      );
      final review = PortfolioDocumentBaseReview(
        document: document,
        base: base,
      );
      final selected = review.changes
          .where((change) => change.defaultSelected)
          .map((change) => change.key)
          .toSet();
      expect(selected, {'skills:shared', 'skills:removed', 'skills:new'});
      final applied = review.apply(selected);
      expect(applied.content.skills, const [
        Skill(id: 'local-only', name: 'My own skill'),
        Skill(id: 'local-edit', name: 'My edited skill'),
        Skill(id: 'shared', name: 'Dart 3'),
        Skill(id: 'new', name: 'Flutter'),
      ]);
      expect(
        PortfolioDocumentBaseReview(document: applied, base: base).changes,
        isEmpty,
      );
      final changedAgain = base.copyWith(
        skills: const [Skill(id: 'local-edit', name: 'Newest skill')],
      );
      final next = PortfolioDocumentBaseReview(
        document: applied,
        base: changedAgain,
      );
      expect(
        next.changes
            .singleWhere((change) => change.itemId == 'local-edit')
            .defaultSelected,
        isFalse,
      );
    },
  );

  test('legacy review never selects changes or removes local-only items', () {
    final local = PortfolioContent(
      profile: const PortfolioProfile(headline: 'My role'),
      links: const [
        SocialLink(id: 'my-link', label: 'My site', url: 'https://example.com'),
      ],
    );
    final legacy = PortfolioDocument(
      id: 'legacy',
      title: 'Legacy',
      kind: PortfolioDocumentKind.portfolio,
      createdAt: _date,
      updatedAt: _date,
      content: local,
    );
    final base = PortfolioContent(
      profile: const PortfolioProfile(headline: 'Base role'),
    );
    final review = PortfolioDocumentBaseReview(document: legacy, base: base);
    expect(review.hasBaseline, isFalse);
    expect(
      review.changes.map((change) => change.defaultSelected),
      everyElement(isFalse),
    );
    expect(
      review.changes.any(
        (change) => change.field == PortfolioDocumentBaseField.links,
      ),
      isFalse,
    );
    final applied = review.apply({});
    expect(applied.content, local);
    expect(applied.baseSnapshot, developerProfileData(base));
    expect(
      PortfolioDocumentBaseReview(document: applied, base: base).changes,
      isEmpty,
    );
  });

  test(
    'no changes for identical base or for an independently changed document',
    () {
      final base = PortfolioContent(
        profile: const PortfolioProfile(name: 'Alex'),
      );
      final document = _document(
        base,
        local: seedDocumentContent(base)
            .copyWith(profile: const PortfolioProfile(name: 'Local Alex')),
      );
      expect(
        PortfolioDocumentBaseReview(document: document, base: base).changes,
        isEmpty,
      );
      expect(
        document.copyWith(id: 'duplicate').baseSnapshot,
        document.baseSnapshot,
      );
      expect(
        () => PortfolioDocumentBaseReview(
          document: document,
          base: base,
        ).apply({'name:unknown'}),
        throwsArgumentError,
      );
    },
  );

  test(
    'avatar pair changes atomically; relations and layout remain independent',
    () {
      final base = PortfolioContent(
        profile: const PortfolioProfile(
          name: 'Alex',
          avatarUrl: 'https://example.com/old.jpg',
        ),
      );
      final document = _document(base).copyWith(
        projects: const [
          PortfolioProjectAttachment(projectId: 'project', featured: true),
        ],
        attachedResumeId: 'resume',
        kind: PortfolioDocumentKind.portfolio,
      );
      final incoming = base.copyWith(
        profile: base.profile.copyWith(
          avatarUrl: '',
          avatarPath: 'accounts/owner/media/${'a' * 32}.jpg',
        ),
      );
      final review = PortfolioDocumentBaseReview(
        document: document,
        base: incoming,
      );
      final applied = review.apply({'avatar:'});
      expect(applied.content.profile.avatarUrl, isEmpty);
      expect(applied.content.profile.avatarPath, incoming.profile.avatarPath);
      expect(applied.projects, document.projects);
      expect(applied.attachedResumeId, 'resume');
      expect(applied.updatedAt, document.updatedAt);
    },
  );

  test(
    'experience, education and links update only the selected stable ID',
    () {
      final base = PortfolioContent(
        experience: const [
          Experience(
            id: 'work',
            role: 'Junior',
            organization: 'Team',
            period: '2025',
            description: 'Old',
          ),
        ],
        education: const [
          Education(
            id: 'school',
            institution: 'AlmaU',
            qualification: 'SE',
            period: '2026',
            description: '',
          ),
        ],
        links: const [
          SocialLink(
            id: 'site',
            label: 'Website',
            url: 'https://example.com/old',
          ),
        ],
      );
      final document = _document(base);
      final incoming = base.copyWith(
        experience: [base.experience.single.copyWith(role: 'Developer')],
        education: [base.education.single.copyWith(description: 'Degree')],
        links: [base.links.single.copyWith(url: 'https://example.com/new')],
      );
      final applied = PortfolioDocumentBaseReview(
        document: document,
        base: incoming,
      ).apply({'experience:work', 'links:site'});
      expect(applied.content.experience.single.role, 'Developer');
      expect(applied.content.education, base.education);
      expect(applied.content.links.single.url, 'https://example.com/new');
    },
  );

  test('review captures only base data and rejects nested or invalid baseline storage', () {
    final base = PortfolioContent(
      profile: const PortfolioProfile(name: 'Alex'),
    );
    final document = _document(base);
    final workspace = base.copyWith(
      documents: [document],
      projects: [
        PortfolioProject(
          id: 'project',
          title: 'Project',
          description: '',
          technologies: const [],
        ),
      ],
      resumeText: 'Private legacy text',
    );
    final review = PortfolioDocumentBaseReview(
      document: document,
      base: workspace,
    );
    expect(review.base, developerProfileData(base));
    expect(
      validatePortfolioContent(base.copyWith(documents: [document])),
      isEmpty,
    );
    expect(
      validatePortfolioContent(
        base.copyWith(documents: [document.copyWith(baseSnapshot: workspace)]),
      ),
      contains(PortfolioValidationCode.invalidStructure),
    );
    expect(
      validatePortfolioContent(
        base.copyWith(
          documents: [
            document.copyWith(
              baseSnapshot: base.copyWith(
                skills: const [Skill(id: 'bad', name: '')],
              ),
            ),
          ],
        ),
      ),
      contains(PortfolioValidationCode.required),
    );
    expect(() => review.changes.clear(), throwsUnsupportedError);
  });
}
