import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';

const _unchanged = Object();

final class PortfolioDraftState {
  const PortfolioDraftState({
    this.notes = '',
    this.draft,
    this.loading = true,
    this.loaded = false,
    this.saving = false,
    this.failure,
  });

  final String notes;
  final PortfolioDraft? draft;
  final bool loading;
  final bool loaded;
  final bool saving;
  final PortfolioDraftFailure? failure;

  bool get hasUnsavedChanges => notes != (draft?.notes ?? '');
  bool get canEdit =>
      loaded &&
      !loading &&
      failure?.kind != PortfolioDraftFailureKind.corrupted &&
      failure?.kind != PortfolioDraftFailureKind.unsupportedVersion;
  bool get canSave => canEdit && !saving && hasUnsavedChanges;

  PortfolioDraftState copyWith({
    String? notes,
    Object? draft = _unchanged,
    bool? loading,
    bool? loaded,
    bool? saving,
    Object? failure = _unchanged,
  }) => PortfolioDraftState(
    notes: notes ?? this.notes,
    draft: identical(draft, _unchanged) ? this.draft : draft as PortfolioDraft?,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    saving: saving ?? this.saving,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as PortfolioDraftFailure?,
  );
}
