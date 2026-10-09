import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_content.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_sync.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_validation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'web edits survive mobile cloud6 decode, scoped edit and web readback',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'stackcard-web-contract-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final webFile = File('${directory.path}/web.json');
      final mobileFile = File('${directory.path}/mobile.json');
      await _webBridge(['--write-web-envelope', webFile.path]);
      final raw =
          jsonDecode(await webFile.readAsString()) as Map<String, dynamic>;
      final timestamp = DateTime.parse(raw['updatedAt'] as String);
      final draft = decodeCloudPortfolioDraft({
        ...raw,
        'updatedAt': Timestamp.fromDate(timestamp),
      }, ownerUid: 'owner');

      final workspace = draft.content!;
      final frontend = workspace.documents[0];
      final backend = workspace.documents[1];
      final portfolio = workspace.documents[2];
      expect(validatePortfolioContent(workspace), isEmpty);
      expect(
        draft.notes,
        '  Private web notes\nЛичные заметки — не содержимое документа\n',
      );
      expect(workspace.projects.single.title, 'Library from web');
      expect(workspace.documents.map((d) => d.projects.single.projectId), [
        'project',
        'project',
        'project',
      ]);
      expect(frontend.content.profile.headline, 'Frontend role from web');
      expect(backend.content.profile.headline, 'Backend role from web');
      expect(frontend.content.resumeText, '  Frontend résumé\nТочный текст\n');
      expect(frontend.content.skills.map((s) => s.name), [
        'TypeScript / React',
        'Frontend-only skill',
      ]);
      expect(backend.content.skills.single.name, 'TypeScript');
      expect(frontend.baseSnapshot!.profile.headline, 'Updated shared role');
      expect(backend.baseSnapshot!.profile.headline, 'Shared role');
      expect(frontend.content.links.single.visible, isFalse);
      expect(frontend.content.links.single.publishAllowed, isFalse);
      expect(backend.content.links.single.visible, isTrue);
      expect(backend.content.links.single.publishAllowed, isTrue);
      expect(workspace.links.single.publishAllowed, isFalse);
      expect(workspace.profile.publishLocation, isFalse);
      expect(frontend.content.profile.publishLocation, isTrue);
      expect(portfolio.attachedResumeId, frontend.id);
      final frontendProject = resolveDocumentContent(
        workspace,
        frontend,
      ).projects.single;
      final backendProject = resolveDocumentContent(
        workspace,
        backend,
      ).projects.single;
      expect(frontendProject.title, 'Frontend case study');
      expect(frontendProject.description, isEmpty);
      expect(frontendProject.contribution, 'Frontend implementation');
      expect(frontendProject.featured, isTrue);
      expect(backendProject.title, 'Library from web');
      expect(backendProject.contribution, 'Backend implementation');
      expect(backendProject.visible, isFalse);

      // Сначала полный roundtrip проверяет каждый ключ, включая null/пустые overrides.
      final unchanged = encodeCloudPortfolioDraft(draft);
      expect(unchanged['updatedAt'], isA<FieldValue>());
      unchanged['updatedAt'] = timestamp.toIso8601String();
      expect(unchanged, raw);

      // Затем mobile меняет только роль одного документа и отдаёт новый cloud6 в web.
      final edited = workspace.copyWith(
        documents: [
          frontend.copyWith(
            content: frontend.content.copyWith(
              profile: frontend.content.profile.copyWith(
                headline: 'Frontend role edited on mobile',
              ),
            ),
          ),
          backend,
          portfolio,
        ],
      );
      final encoded = encodeCloudPortfolioDraft(
        CloudPortfolioDraft(
          ownerUid: draft.ownerUid,
          mutationId: 'mobile-cross-client',
          localRevision: draft.localRevision + 1,
          notes: draft.notes,
          content: edited,
        ),
      );
      expect(encoded['updatedAt'], isA<FieldValue>());
      encoded['updatedAt'] = timestamp.toIso8601String();
      await mobileFile.writeAsString(jsonEncode(encoded));
      await _webBridge([
        '--check-mobile-envelope',
        mobileFile.path,
        webFile.path,
      ]);
    },
  );
}

Future<void> _webBridge(List<String> arguments) async {
  final result = await Process.run('node', [
    '--import',
    'tsx',
    'tests/mobile-roundtrip.test.ts',
    ...arguments,
  ], workingDirectory: Directory('../web').absolute.path);
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
}
