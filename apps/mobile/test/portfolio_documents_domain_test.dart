import 'dart:convert';

import 'package:app_stackcard/features/portfolio_draft/data/portfolio_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/data/portfolio_public_content_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_github_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 7);
  final project = PortfolioProject(
    id: 'library-project',
    title: 'Library title',
    description: '',
    technologies: ['Dart'],
    featured: false,
    updatedAt: now,
  );
  final base = PortfolioContent(
    profile: const PortfolioProfile(name: 'Base profile'),
    skills: [const Skill(id: 'dart', name: 'Dart')],
    projects: [project],
    ignoredGitHubRepositories: [
      const GitHubIgnoredRepository(repositoryId: 7, fingerprint: 'ignored'),
    ],
    resumeText: 'Legacy text',
  );
  PortfolioDocument document({String id = 'resume'}) => PortfolioDocument(
    id: id,
    title: 'Mobile developer',
    kind: PortfolioDocumentKind.resume,
    createdAt: now,
    updatedAt: now,
    content: seedDocumentContent(base),
  );

  test(
    'explicit document seed is independent and never copies Library or Ignore',
    () {
      final resume = document();
      final workspace = base.copyWith(documents: [resume]);
      expect(resume.content.profile.name, 'Base profile');
      expect(resume.content.skills, base.skills);
      expect(resume.content.projects, isEmpty);
      expect(resume.content.documents, isEmpty);
      expect(resume.content.ignoredGitHubRepositories, isEmpty);
      final edited = workspace.copyWith(
        profile: const PortfolioProfile(name: 'Updated base'),
        resumeText: 'Updated text',
      );
      expect(edited.documents.single.content.profile.name, 'Base profile');
      expect(edited.documents.single.content.resumeText, 'Legacy text');
      expect(edited.documents, workspace.documents);
      expect(() => edited.documents.clear(), throwsUnsupportedError);
      expect(() => resume.projects.clear(), throwsUnsupportedError);
      expect(workspace.copyWith(), workspace);
      expect(workspace.copyWith().hashCode, workspace.hashCode);
      expect(workspace.copyWith(documents: []), isNot(workspace));
    },
  );

  test(
    'ordered per-document project flags resolve from the current Library',
    () {
      final second = project.copyWith(id: 'second', title: 'Second');
      final portfolio = document(id: 'portfolio').copyWith(
        kind: PortfolioDocumentKind.portfolio,
        projects: const [
          PortfolioProjectAttachment(projectId: 'second', visible: false),
          PortfolioProjectAttachment(
            projectId: 'library-project',
            featured: true,
          ),
        ],
      );
      final workspace = base.copyWith(projects: [project, second]);
      final resolved = resolveDocumentContent(workspace, portfolio);
      expect(resolved.projects.map((item) => item.id), [
        'second',
        'library-project',
      ]);
      expect(resolved.projects.first.visible, isFalse);
      expect(resolved.projects.last.featured, isTrue);
      expect(workspace.projects.first.featured, isFalse);
      final editedLibrary = workspace.copyWith(
        projects: [
          project.copyWith(title: 'Updated library'),
          second,
        ],
      );
      expect(
        resolveDocumentContent(editedLibrary, portfolio).projects.last.title,
        'Updated library',
      );
      expect(resolved.documents, isEmpty);
      expect(resolved.ignoredGitHubRepositories, isEmpty);
      expect(
        () => resolveDocumentContent(base, portfolio),
        throwsArgumentError,
      );
    },
  );

  test(
    'attachment and document copyWith preserve equality and detach explicitly',
    () {
      const attachment = PortfolioProjectAttachment(projectId: 'p');
      expect(attachment.copyWith(), attachment);
      expect(attachment.copyWith().hashCode, attachment.hashCode);
      expect(attachment.copyWith(featured: true), isNot(attachment));
      final portfolio = document().copyWith(
        id: 'portfolio',
        kind: PortfolioDocumentKind.portfolio,
        attachedResumeId: 'resume',
      );
      expect(portfolio.copyWith(), portfolio);
      expect(portfolio.copyWith().hashCode, portfolio.hashCode);
      expect(
        portfolio.copyWith(clearAttachedResumeId: true).attachedResumeId,
        isNull,
      );
      expect(portfolio.copyWith(title: 'Other'), isNot(portfolio));
    },
  );

  test('validation rejects dangling, duplicate, nested, invalid date and resume references', () {
    final resume = document();
    final portfolio = document(id: 'portfolio').copyWith(
      kind: PortfolioDocumentKind.portfolio,
      attachedResumeId: resume.id,
      projects: [PortfolioProjectAttachment(projectId: project.id)],
    );
    final valid = base.copyWith(documents: [resume, portfolio]);
    expect(validatePortfolioContent(valid), isEmpty);
    for (final documents in [
      [resume, resume],
      [resume.copyWith(title: ' ')],
      [resume.copyWith(createdAt: DateTime(2026, 10, 7))],
      [resume.copyWith(updatedAt: now.subtract(const Duration(days: 1)))],
      [resume.copyWith(content: base)],
      [
        resume.copyWith(content: resume.content.copyWith(documents: [resume])),
      ],
      [portfolio.copyWith(attachedResumeId: 'missing')],
      [resume.copyWith(attachedResumeId: 'resume')],
      [resume, portfolio.copyWith(attachedResumeId: 'portfolio')],
      [
        resume,
        portfolio.copyWith(
          projects: const [PortfolioProjectAttachment(projectId: 'missing')],
        ),
      ],
      [
        resume,
        portfolio.copyWith(
          projects: [portfolio.projects.single, portfolio.projects.single],
        ),
      ],
      [
        resume.copyWith(
          content: resume.content.copyWith(
            skills: [const Skill(id: 'x', name: '')],
          ),
        ),
      ],
    ]) {
      expect(
        validatePortfolioContent(base.copyWith(documents: documents)),
        isNotEmpty,
      );
    }
    expect(
      validatePortfolioContent(
        base.copyWith(
          documents: [
            for (var i = 0; i < portfolioDocumentLimit; i++)
              document(id: 'resume-$i'),
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      validatePortfolioContent(
        base.copyWith(
          documents: [
            for (var i = 0; i <= portfolioDocumentLimit; i++)
              document(id: 'resume-$i'),
          ],
        ),
      ),
      contains(PortfolioValidationCode.invalidStructure),
    );
  });

  test(
    'codec roundtrip preserves independent documents, UTC dates and ID refs',
    () {
      final resume = document();
      final portfolio = document(id: 'portfolio').copyWith(
        kind: PortfolioDocumentKind.portfolio,
        attachedResumeId: resume.id,
        projects: [
          PortfolioProjectAttachment(projectId: project.id, featured: true),
        ],
      );
      final workspace = base.copyWith(documents: [resume, portfolio]);
      final encoded = encodePortfolioContent(workspace);
      expect(
        decodePortfolioContent(jsonDecode(jsonEncode(encoded))),
        workspace,
      );
      final storedDocument = (encoded['documents'] as List).last as Map;
      expect(
        (storedDocument['content'] as Map).containsKey('documents'),
        isFalse,
      );
      expect((storedDocument['content'] as Map)['projects'], isEmpty);
      expect(storedDocument['projects'], [
        {'projectId': project.id, 'visible': true, 'featured': true},
      ]);
      expect(workspace.projects.single.updatedAt, now);
      expect(
        resolveDocumentContent(workspace, portfolio).resumeText,
        'Legacy text',
      );
    },
  );

  test('old schema opt out rejects documents key including empty list', () {
    final encoded = encodePortfolioContent(base);
    expect(encoded['documents'], isEmpty);
    expect(
      () => decodePortfolioContent(
        jsonDecode(jsonEncode(encoded)),
        allowDocuments: false,
      ),
      throwsFormatException,
    );
    final old = encodePortfolioContent(base, includeDocuments: false);
    expect(old.containsKey('documents'), isFalse);
    expect(
      decodePortfolioContent(
        jsonDecode(jsonEncode(old)),
        allowDocuments: false,
      ),
      base,
    );
    ((old['projects'] as List).single as Map).remove('updatedAt');
    expect(
      decodePortfolioContent(jsonDecode(jsonEncode(old)))
          .projects
          .single
          .updatedAt,
      isNull,
    );
  });

  test('codec rejects nested documents, copied projects, unknown kind and non-UTC dates', () {
    final workspace = base.copyWith(documents: [document()]);
    final encoded = encodePortfolioContent(workspace);
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (item) => item['kind'] = 'unknown',
      (item) => item['createdAt'] = '2026-10-07T00:00:00.000',
      (item) => (item['content'] as Map)['notes'] = 'Private extra',
      (item) => ((item['content'] as Map)['profile'] as Map)['email'] =
          'private@example.test',
      (item) => (item['content'] as Map)['documents'] = [],
      (item) =>
          (item['content'] as Map)['projects'] = (encoded['projects'] as List),
      (item) => item['projects'] = [
        {'projectId': project.id, 'visible': 'yes', 'featured': false},
      ],
    ]) {
      final raw = jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>;
      mutate((raw['documents'] as List).single as Map<String, dynamic>);
      expect(() => decodePortfolioContent(raw), throwsFormatException);
    }
    expect(
      () => encodePortfolioContent(
        base.copyWith(documents: [document().copyWith(content: base)]),
      ),
      throwsFormatException,
    );
  });

  test(
    'public projection excludes all document snapshots, media and timestamps',
    () {
      final workspace = base.copyWith(
        projects: [project.copyWith(featured: true)],
        documents: [
          document().copyWith(
            content: document().content.copyWith(
              profile: const PortfolioProfile(
                name: 'Private document snapshot',
              ),
            ),
          ),
        ],
      );
      final projected = projectPublicPortfolioContent(workspace);
      expect(projected.documents, isEmpty);
      final encoded = encodePublicPortfolioContent(workspace);
      expect(encoded.containsKey('documents'), isFalse);
      expect(jsonEncode(encoded), isNot(contains('Private document snapshot')));
      expect((encoded['profile'] as Map).containsKey('avatarPath'), isFalse);
      for (final project in encoded['projects'] as List) {
        expect((project as Map).containsKey('updatedAt'), isFalse);
      }
    },
  );

  test('project modification time uses explicit user action time, never source age', () {
    GitHubProjectSource source(String name) => GitHubProjectSource(
      repositoryId: 42,
      name: name,
      fullName: 'developer/$name',
      htmlUrl: 'https://github.com/developer/$name',
      stars: 0,
      forks: 0,
      isFork: false,
      archived: false,
      updatedAt: DateTime.utc(2020),
    );
    final imported = addGitHubProject(
      PortfolioContent(),
      source('first'),
      validatedAt: now,
    );
    expect(imported.projects.single.updatedAt, now);
    final unknown = addGitHubProject(PortfolioContent(), source('first'));
    expect(unknown.projects.single.updatedAt, isNull);
    final next = now.add(const Duration(days: 1));
    final accepted = acceptGitHubProjectChanges(
      imported,
      reviewGitHubProject(imported, source('second')),
      validatedAt: next,
    );
    expect(accepted.projects.single.updatedAt, next);
    expect(
      accepted.projects.single.githubMetadata!.acceptedSource.updatedAt,
      DateTime.utc(2020),
    );
    final edited = accepted.projects.single.withUserEdits(
      accepted.projects.single.copyWith(
        title: 'User edit',
        updatedAt: next.add(const Duration(hours: 1)),
      ),
    );
    expect(edited.updatedAt, next.add(const Duration(hours: 1)));
    expect(
      validatePortfolioContent(
        PortfolioContent(
          projects: [project.copyWith(updatedAt: DateTime(2026))],
        ),
      ),
      contains(PortfolioValidationCode.invalidStructure),
    );
  });
}
