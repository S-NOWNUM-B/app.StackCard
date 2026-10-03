import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/portfolio_draft_repository.dart';
import '../portfolio_draft_providers.dart';
import 'portfolio_draft_state.dart';

// App session сохраняет введённые, но ещё не записанные заметки при навигации.
final portfolioDraftControllerProvider =
    NotifierProvider<PortfolioDraftController, PortfolioDraftState>(
      PortfolioDraftController.new,
    );

class PortfolioDraftController extends Notifier<PortfolioDraftState> {
  int _generation = 0;

  @override
  PortfolioDraftState build() {
    ref.watch(portfolioDraftRepositoryProvider);
    final initialRef = ref;
    final generation = ++_generation;
    Future<void>.microtask(() async {
      if (initialRef.mounted && generation == _generation) await load();
    });
    return const PortfolioDraftState();
  }

  Future<void> load() async {
    if (state.saving || state.loaded) return;
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
    if (!state.canEdit) return;
    state = state.copyWith(notes: notes, failure: null);
  }

  Future<void> save() async {
    if (!state.canSave) return;
    final operationRef = ref;
    final generation = ++_generation;
    final notes = state.notes;
    final repository = ref.read(portfolioDraftRepositoryProvider);
    state = state.copyWith(saving: true, failure: null);
    try {
      final draft = await repository.saveNotes(notes);
      if (!operationRef.mounted || generation != _generation) return;
      // Новые правки во время save остаются unsaved, а сохранённая revision честная.
      state = state.copyWith(draft: draft, saving: false);
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
