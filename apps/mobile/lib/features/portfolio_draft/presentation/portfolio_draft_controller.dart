import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_content.dart';
import '../portfolio_draft_providers.dart';
import 'portfolio_draft_state.dart';

// App session сохраняет введённые, но ещё не записанные заметки при навигации.
final portfolioDraftControllerProvider =
    NotifierProvider<PortfolioDraftController, PortfolioDraftState>(
      PortfolioDraftController.new,
    );

final portfolioWorkingContentProvider = Provider<PortfolioContent?>(
  (ref) => ref.watch(portfolioDraftControllerProvider).content,
);

class PortfolioDraftController extends Notifier<PortfolioDraftState> {
  int _generation = 0;
  int _idCounter = 0;
  Future<void>? _loadOperation;

  PortfolioContent? get workingContent => state.content;

  @override
  PortfolioDraftState build() {
    ref.watch(portfolioDraftRepositoryProvider);
    _loadOperation = null;
    final initialRef = ref;
    final generation = ++_generation;
    Future<void>.microtask(() async {
      if (initialRef.mounted && generation == _generation) await load();
    });
    return const PortfolioDraftState();
  }

  Future<void> load() {
    if (state.saving || state.loaded) return Future<void>.value();
    final loading = _loadOperation;
    if (loading != null) return loading;
    late final Future<void> operation;
    operation = _readDraft().whenComplete(() {
      if (identical(_loadOperation, operation)) _loadOperation = null;
    });
    _loadOperation = operation;
    return operation;
  }

  /// Read models ждут единое чтение до решения использовать demo fallback.
  Future<void> ensureLoaded() async {
    final operationRef = ref;
    if (state.loaded) return;
    // Providers могут ждать controller при собственном build; чтение начинает
    // microtask, чтобы mutation не происходила во время чужого provider build.
    await Future<void>.value();
    if (!operationRef.mounted) return;
    if (!state.loading) {
      final failure = state.failure;
      if (failure != null) throw failure;
    }
    await load();
    if (!operationRef.mounted) return;
    if (!state.loaded) throw state.failure ?? _unavailable;
  }

  Future<void> _readDraft() async {
    final operationRef = ref;
    final generation = ++_generation;
    final repository = ref.read(portfolioDraftRepositoryProvider);
    state = state.copyWith(loading: true, failure: null);
    try {
      final draft = await repository.read();
      if (!operationRef.mounted || generation != _generation) return;
      state = PortfolioDraftState(
        notes: draft?.notes ?? '',
        draft: draft,
        content: draft?.content,
        loading: false,
        loaded: true,
      );
    } on PortfolioDraftFailure catch (failure) {
      _loadFailure(operationRef, generation, failure);
    } catch (_) {
      _loadFailure(operationRef, generation, _unavailable);
    }
  }

  void editNotes(String notes) {
    updateNotes(notes);
  }

  void updateNotes(String notes) {
    if (!state.canEdit) return;
    state = state.copyWith(notes: notes, failure: null);
  }

  void startBuilder() {
    if (!state.canEdit || state.content != null) return;
    updateContent(PortfolioContent());
  }

  void updateContent(PortfolioContent content) {
    if (!state.canEdit) return;
    state = state.copyWith(content: content, failure: null);
  }

  String createId() =>
      '${DateTime.now().toUtc().microsecondsSinceEpoch}-${++_idCounter}';

  /// Явное чтение заново отбрасывает только текущие несохранённые правки.
  Future<void> reload() async {
    if (state.saving) return;
    state = state.copyWith(loaded: false);
    await load();
  }

  Future<void> save() async {
    if (!state.canSave) return;
    final operationRef = ref;
    final generation = ++_generation;
    final notes = state.notes;
    final content = state.content;
    final expectedRevision = state.draft?.revision ?? 0;
    final repository = ref.read(portfolioDraftRepositoryProvider);
    state = state.copyWith(saving: true, failure: null);
    try {
      final draft = content == null
          ? await repository.saveNotes(notes)
          : await repository.save(
              content,
              expectedRevision: expectedRevision,
              notes: notes,
            );
      if (!operationRef.mounted || generation != _generation) return;
      // Новые правки во время save остаются unsaved, а сохранённая revision честная.
      state = state.copyWith(
        draft: draft,
        content: state.content == content ? draft.content : state.content,
        saving: false,
      );
    } on PortfolioDraftFailure catch (failure) {
      _saveFailure(operationRef, generation, failure);
    } catch (_) {
      _saveFailure(operationRef, generation, _unavailable);
    }
  }

  void _loadFailure(
    Ref operationRef,
    int generation,
    PortfolioDraftFailure failure,
  ) {
    if (!operationRef.mounted || generation != _generation) return;
    state = state.copyWith(loading: false, loaded: false, failure: failure);
  }

  void _saveFailure(
    Ref operationRef,
    int generation,
    PortfolioDraftFailure failure,
  ) {
    if (!operationRef.mounted || generation != _generation) return;
    state = state.copyWith(saving: false, failure: failure);
  }

  static const _unavailable = PortfolioDraftFailure(
    PortfolioDraftFailureKind.unavailable,
  );
}
