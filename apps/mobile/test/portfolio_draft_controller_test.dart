import 'dart:async';

import 'package:app_stackcard/features/portfolio_draft/data/memory_portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft.dart';
import 'package:app_stackcard/features/portfolio_draft/domain/portfolio_draft_repository.dart';
import 'package:app_stackcard/features/portfolio_draft/portfolio_draft_providers.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_draft_controller.dart';
import 'package:app_stackcard/features/portfolio_draft/presentation/portfolio_draft_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Initial asynchronous read exposes loading then empty editable state',
    () async {
      final repository = _FakeRepository();
      final scope = _scope(repository);
      expect(scope.state.loading, isTrue);
      expect(scope.state.canEdit, isFalse);
      await scope.controller.load();
      expect(repository.reads, 1);
      expect(scope.state.loading, isFalse);
      expect(scope.state.loaded, isTrue);
      expect(scope.state.draft, isNull);
      expect(scope.state.canEdit, isTrue);
      expect(scope.state.canSave, isFalse);
    },
  );

  test(
    'Existing draft is read without saving or changing pending status',
    () async {
      final repository = _FakeRepository(
        read: () async => _draft('Saved', revision: 4),
      );
      final scope = _scope(repository);
      await scope.controller.load();
      expect(scope.state.notes, 'Saved');
      expect(scope.state.draft!.revision, 4);
      expect(scope.state.draft!.pendingSync, isTrue);
      expect(scope.state.hasUnsavedChanges, isFalse);
      expect(repository.savedNotes, isEmpty);
    },
  );

  test('Edits are unsaved until completed durable save', () async {
    final pending = Completer<PortfolioDraft>();
    final repository = _FakeRepository(save: (_) => pending.future);
    final scope = _scope(repository);
    await scope.controller.load();
    scope.controller.editNotes('Local note');
    expect(scope.state.canSave, isTrue);
    final saving = scope.controller.save();
    expect(scope.state.saving, isTrue);
    expect(scope.state.draft, isNull);
    expect(scope.state.hasUnsavedChanges, isTrue);
    pending.complete(_draft('Local note'));
    await saving;
    expect(scope.state.saving, isFalse);
    expect(scope.state.hasUnsavedChanges, isFalse);
    expect(scope.state.draft!.pendingSync, isTrue);
  });

  test('Typing during save preserves newer unsaved input', () async {
    final pending = Completer<PortfolioDraft>();
    final scope = _scope(_FakeRepository(save: (_) => pending.future));
    await scope.controller.load();
    scope.controller.editNotes('Old input');
    final saving = scope.controller.save();
    scope.controller.editNotes('New input');
    pending.complete(_draft('Old input'));
    await saving;
    expect(scope.state.notes, 'New input');
    expect(scope.state.draft!.notes, 'Old input');
    expect(scope.state.hasUnsavedChanges, isTrue);
    expect(scope.state.canSave, isTrue);
  });

  test('Duplicate save and unchanged notes do not create writes', () async {
    final pending = Completer<PortfolioDraft>();
    final repository = _FakeRepository(save: (_) => pending.future);
    final scope = _scope(repository);
    await scope.controller.load();
    await scope.controller.save();
    expect(repository.savedNotes, isEmpty);
    scope.controller.editNotes('Changed');
    final saving = scope.controller.save();
    await scope.controller.save();
    expect(repository.savedNotes, ['Changed']);
    pending.complete(_draft('Changed'));
    await saving;
    await scope.controller.save();
    expect(repository.savedNotes, ['Changed']);
  });

  test('Failed save retains both durable draft and user input then explicitly retries', () async {
    var saves = 0;
    final repository = _FakeRepository(
      read: () async => _draft('Stored', revision: 3),
      save: (notes) async {
        if (++saves == 1) {
          throw const PortfolioDraftFailure(
            PortfolioDraftFailureKind.unavailable,
          );
        }
        return _draft(notes, revision: 4);
      },
    );
    final scope = _scope(repository);
    await scope.controller.load();
    scope.controller.editNotes('My changes');
    await scope.controller.save();
    expect(scope.state.notes, 'My changes');
    expect(scope.state.draft!.notes, 'Stored');
    expect(scope.state.draft!.revision, 3);
    expect(scope.state.hasUnsavedChanges, isTrue);
    expect(scope.state.canSave, isTrue);
    expect(scope.state.failure!.kind, PortfolioDraftFailureKind.unavailable);
    await scope.container.pump();
    expect(saves, 1);
    await scope.controller.save();
    expect(scope.state.notes, 'My changes');
    expect(scope.state.draft!.revision, 4);
    expect(scope.state.failure, isNull);
    expect(scope.state.hasUnsavedChanges, isFalse);
  });

  test('Generic read and write exceptions become typed failures', () async {
    var reads = 0;
    final scope = _scope(
      _FakeRepository(
        read: () async {
          if (++reads == 1) throw StateError('Internal path');
          return null;
        },
        save: (_) async => throw StateError('Backend detail'),
      ),
    );
    await scope.controller.load();
    expect(scope.state.failure!.kind, PortfolioDraftFailureKind.unavailable);
    expect(scope.state.canEdit, isFalse);
    await scope.controller.load();
    scope.controller.editNotes('Retained');
    await scope.controller.save();
    expect(scope.state.notes, 'Retained');
    expect(scope.state.failure!.kind, PortfolioDraftFailureKind.unavailable);
  });

  for (final kind in [
    PortfolioDraftFailureKind.corrupted,
    PortfolioDraftFailureKind.unsupportedVersion,
  ]) {
    test('$kind never enables overwriting an unreadable draft', () async {
      final repository = _FakeRepository(
        read: () async => throw PortfolioDraftFailure(kind),
      );
      final scope = _scope(repository);
      await scope.controller.load();
      expect(scope.state.failure!.kind, kind);
      expect(scope.state.canEdit, isFalse);
      scope.controller.editNotes('Unsafe overwrite');
      await scope.controller.save();
      expect(scope.state.notes, '');
      expect(repository.savedNotes, isEmpty);
    });

    test(
      '$kind encountered during save preserves input and blocks another write',
      () async {
        final repository = _FakeRepository(
          save: (_) async => throw PortfolioDraftFailure(kind),
        );
        final scope = _scope(repository);
        await scope.controller.load();
        scope.controller.editNotes('Keep my input');
        await scope.controller.save();
        expect(scope.state.notes, 'Keep my input');
        expect(scope.state.canSave, isFalse);
        expect(scope.state.hasUnsavedChanges, isTrue);
        await scope.controller.save();
        expect(repository.savedNotes, ['Keep my input']);
      },
    );
  }

  test(
    'Explicit read after loaded state cannot replace unsaved input',
    () async {
      final repository = _FakeRepository();
      final scope = _scope(repository);
      await scope.controller.load();
      scope.controller.editNotes('Unsaved');
      await scope.controller.load();
      expect(scope.state.notes, 'Unsaved');
      expect(repository.reads, 1);
    },
  );

  test(
    'Repository replacement ignores a late read from previous source',
    () async {
      final pending = Completer<PortfolioDraft?>();
      final scope = _scope(_FakeRepository(read: () => pending.future));
      final oldRead = scope.controller.load();
      scope.container.updateOverrides([
        portfolioDraftRepositoryProvider.overrideWithValue(
          _FakeRepository(read: () async => _draft('New source')),
        ),
      ]);
      await scope.container.pump();
      await Future<void>.delayed(Duration.zero);
      pending.complete(_draft('Stale source'));
      await oldRead;
      expect(scope.state.notes, 'New source');
    },
  );

  test(
    'Dispose during save permits durable completion without stale state writes',
    () async {
      final pending = Completer<PortfolioDraft>();
      final container = ProviderContainer(
        overrides: [
          portfolioDraftRepositoryProvider.overrideWithValue(
            _FakeRepository(save: (_) => pending.future),
          ),
        ],
      );
      final controller = container.read(
        portfolioDraftControllerProvider.notifier,
      );
      await controller.load();
      controller.editNotes('Persistent operation');
      final saving = controller.save();
      container.dispose();
      pending.complete(_draft('Persistent operation'));
      await expectLater(saving, completes);
    },
  );

  test(
    'Controller retains unsaved edits when its screen listener leaves',
    () async {
      final scope = _scope(MemoryPortfolioDraftRepository(), listen: false);
      await scope.controller.load();
      final listener = scope.container.listen(
        portfolioDraftControllerProvider,
        (_, _) {},
      );
      scope.controller.editNotes('Navigation stays in app session');
      listener.close();
      await scope.container.pump();
      expect(scope.state.notes, 'Navigation stays in app session');
      expect(scope.state.hasUnsavedChanges, isTrue);
    },
  );
}

_Scope _scope(PortfolioDraftRepository repository, {bool listen = true}) {
  final container = ProviderContainer(
    overrides: [portfolioDraftRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  if (listen) container.listen(portfolioDraftControllerProvider, (_, _) {});
  final controller = container.read(portfolioDraftControllerProvider.notifier);
  return _Scope(container, controller);
}

class _Scope {
  const _Scope(this.container, this.controller);
  final ProviderContainer container;
  final PortfolioDraftController controller;
  PortfolioDraftState get state =>
      container.read(portfolioDraftControllerProvider);
}

PortfolioDraft _draft(String notes, {int revision = 1}) => PortfolioDraft(
  notes: notes,
  revision: revision,
  updatedAt: DateTime.utc(2026, 10, 3),
  pendingSync: true,
);

class _FakeRepository implements PortfolioDraftRepository {
  _FakeRepository({
    Future<PortfolioDraft?> Function()? read,
    Future<PortfolioDraft> Function(String)? save,
  }) : onRead = read,
       onSave = save;
  final Future<PortfolioDraft?> Function()? onRead;
  final Future<PortfolioDraft> Function(String)? onSave;
  int reads = 0;
  final savedNotes = <String>[];

  @override
  Future<PortfolioDraft?> read() async {
    reads++;
    return onRead == null ? null : await onRead!();
  }

  @override
  Future<PortfolioDraft> saveNotes(String notes) async {
    savedNotes.add(notes);
    return onSave == null
        ? _draft(notes, revision: savedNotes.length)
        : await onSave!(notes);
  }
}
