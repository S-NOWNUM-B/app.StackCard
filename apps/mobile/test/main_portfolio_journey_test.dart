import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_stackcard/features/portfolio_draft/data/asset_portfolio_pdf_generator.dart';
import 'package:app_stackcard/features/portfolio_draft/data/developer_card_codec.dart';
import 'package:app_stackcard/features/portfolio_draft/data/firestore_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/data/hive_portfolio_sync_metadata_store.dart';
import 'package:app_stackcard/features/portfolio_draft/data/local_draft_accounts.dart';
import 'package:app_stackcard/features/portfolio_draft/data/synced_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('offline new main survives restart, exact ACK and web projection feeds Card/PDF without buffer data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'stackcard-journey-',
    );
    var box = await Hive.openBox<dynamic>('journey', path: directory.path);
    final remote = _Remote();
    var mutation = 0;
    SyncedPortfolioDraftRepository open() => SyncedPortfolioDraftRepository(
      ownerUid: 'owner',
      local: LocalDraftAccounts(box).repositoryForUser('owner'),
      metadata: HivePortfolioSyncMetadataStore(box, ownerUid: 'owner'),
      remote: remote,
      retryDelay: const Duration(hours: 1),
      mutationId: () => 'journey-${++mutation}',
    );
    var repository = open();
    ProviderContainer scope() => ProviderContainer(
      overrides: [
        portfolioDraftRepositoryProvider.overrideWithValue(repository),
      ],
    );
    var container = scope();
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
      await box.close();
      await directory.delete(recursive: true);
    });
    var controller = container.read(portfolioDraftControllerProvider.notifier);
    await controller.load();
    expect(
      await controller.initializeMainPortfolio(
        newAccount: true,
        expectedRepository: repository,
      ),
      isTrue,
    );
    for (var step = 0; step < 4; step++) {
      expect(
        await controller.savePersonalizationStep(
          step: step,
          status: step == 3
              ? PortfolioPersonalizationStatus.completed
              : PortfolioPersonalizationStatus.inProgress,
          profile: step == 1
              ? const PortfolioProfile(name: 'Saved author')
              : null,
          githubUsername: step == 3 ? 'owner' : null,
          expectedRepository: repository,
        ),
        isTrue,
      );
    }
    final savedMain = mainPortfolioDocument(
      (await repository.read())!.content!,
    )!;
    final working = container.read(portfolioDraftControllerProvider).content!;
    controller.updateNotes('PRIVATE_NOTES');
    controller.updateContent(
      working.copyWith(
        documents: [
          savedMain.copyWith(
            content: savedMain.content.copyWith(
              profile: const PortfolioProfile(name: 'PRIVATE_BUFFER'),
            ),
          ),
        ],
      ),
    );
    final manual = PortfolioProject(
      id: 'manual',
      title: 'Manual case',
      description: '',
      technologies: const ['Flutter'],
      liveUrl: 'https://example.com/saved',
    );
    expect(
      await controller.saveProject(manual, expectedRepository: repository),
      isTrue,
    );
    expect(
      await controller.importSelectedGitHubRepositories([
        GitHubProjectSource(
          repositoryId: 42,
          name: 'Repository',
          fullName: 'owner/Repository',
          htmlUrl: 'https://github.com/owner/Repository',
          stars: 0,
          forks: 0,
          isFork: false,
          archived: false,
          language: 'TypeScript',
          updatedAt: DateTime.utc(2026, 10, 21),
        ),
      ], expectedRepository: repository),
      isTrue,
    );
    var saved = (await repository.read())!;
    expect(
      mainPortfolioDocument(saved.content!)!.content.profile.name,
      'Saved author',
    );
    expect(
      mainPortfolioDocument(
        container.read(portfolioDraftControllerProvider).content!,
      )!.content.profile.name,
      'PRIVATE_BUFFER',
    );
    expect(saved.notes, isEmpty);
    final attached = savedMain.copyWith(
      projects: [
        for (final project in saved.content!.projects)
          PortfolioProjectAttachment(projectId: project.id),
      ],
    );
    expect(
      await controller.saveMainPortfolio(
        attached,
        expectedDocument: mainPortfolioDocument(saved.content!),
        expectedRepository: repository,
      ),
      isTrue,
    );
    saved = (await repository.read())!;
    expect(saved.pendingSync, isTrue);
    expect(repository.syncState.confirmedMutationId, isNull);
    final outbox = (await HivePortfolioSyncMetadataStore(
      box,
      ownerUid: 'owner',
    ).read())!;
    expect(outbox.pending, isTrue);

    // Настоящий reopen Hive/outbox; transport — явный fake, не server SDK evidence.
    container.dispose();
    await repository.dispose();
    await box.close();
    box = await Hive.openBox<dynamic>('journey', path: directory.path);
    remote.online = true;
    repository = open();
    container = scope();
    controller = container.read(portfolioDraftControllerProvider.notifier);
    await controller.load();
    await _until(
      () => repository.syncState.status == PortfolioSyncStatus.synced,
    );
    final acknowledged = (await repository.read())!;
    expect(acknowledged.pendingSync, isFalse);
    expect(acknowledged.content, saved.content);
    expect(repository.syncState.confirmedMutationId, outbox.mutationId);
    expect(
      await LocalDraftAccounts(box).repositoryForUser('other-owner').read(),
      isNull,
    );

    final raw = encodeCloudPortfolioDraft(remote.accepted!);
    raw['updatedAt'] = DateTime.utc(2026, 10, 21).toIso8601String();
    final input = File('${directory.path}/cloud.json');
    final output = File('${directory.path}/public.json');
    await input.writeAsString(jsonEncode(raw));
    final bridge = await Process.run('node', [
      '--import',
      'tsx',
      'tests/main-portfolio-journey.bridge.mjs',
      input.path,
      output.path,
    ], workingDirectory: Directory('../web').absolute.path);
    expect(bridge.exitCode, 0, reason: '${bridge.stdout}\n${bridge.stderr}');
    final result =
        jsonDecode(await output.readAsString()) as Map<String, dynamic>;
    final returned = result['cloud'] as Map<String, dynamic>;
    returned['updatedAt'] = Timestamp.fromDate(
      DateTime.parse(returned['updatedAt'] as String),
    );
    final webReadback = decodeCloudPortfolioDraft(returned, ownerUid: 'owner');
    expect(webReadback.content, saved.content);
    final published = result['publication'] as Map<String, dynamic>;
    final publication = DocumentPublication(
      documentId: published['documentId'] as String,
      publicId: published['publicId'] as String,
      version: 1,
      visibility: DocumentPublicationVisibility.published,
      sourceMutationId: outbox.mutationId,
      url: Uri.parse(published['url'] as String),
    );
    final card = decodeDeveloperCard(result['publicDocument'], publication);
    expect(card.name, 'Saved author');
    expect(card.technologies, ['Flutter', 'TypeScript']);
    expect(card.url.path, '/d/${publication.publicId}');
    final buffer = acknowledged.content!;
    controller.updateContent(
      buffer.copyWith(
        documents: [
          attached.copyWith(
            content: attached.content.copyWith(
              profile: const PortfolioProfile(name: 'PRIVATE_LATE_INPUT'),
            ),
          ),
        ],
      ),
    );
    final durable = resolvedMainPortfolioContent(
      (await repository.read())!.content!,
    )!;
    final pdf = await AssetPortfolioPdfGenerator().generate(durable);
    expect(isPortfolioPdfBytes(pdf), isTrue);
    expect(latin1.decode(pdf), contains('https://example.com/saved'));
    expect(durable.profile.name, card.name);
    expect((await repository.read())!.content, saved.content);
  });
}

Future<void> _until(bool Function() condition) async {
  final timeout = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(timeout)) {
      fail('Sync did not reach the expected state');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

class _Remote implements RemotePortfolioDraftRepository {
  bool online = false;
  CloudPortfolioDraft? accepted;
  @override
  Stream<DraftRemoteEvent> watch() => Stream.value(
    DraftRemoteEvent(
      draft: accepted,
      fromCache: false,
      hasPendingWrites: false,
    ),
  );
  @override
  Future<void> write(CloudPortfolioDraft draft) async {
    if (!online) {
      throw const PortfolioSyncFailure(PortfolioSyncFailureKind.unavailable);
    }
    accepted = draft;
  }
}
