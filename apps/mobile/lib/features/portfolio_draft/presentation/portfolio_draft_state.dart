import '../domain/portfolio_draft.dart';
import '../domain/portfolio_draft_repository.dart';
import '../domain/portfolio_content.dart';
import '../domain/portfolio_completion.dart';
import '../domain/portfolio_validation.dart';

const _unchanged = Object();

final class PortfolioDraftState {
  const PortfolioDraftState({
    this.notes = '',
    this.draft,
    this.content,
    this.loading = true,
    this.loaded = false,
    this.saving = false,
    this.failure,
  });

  final String notes;
  final PortfolioDraft? draft;
  final PortfolioContent? content;
  final bool loading;
  final bool loaded;
  final bool saving;
  final PortfolioDraftFailure? failure;

  bool get hasUnsavedChanges =>
      notes != (draft?.notes ?? '') || content != draft?.content;
  List<PortfolioValidationCode> get validationCodes =>
      content == null ? const [] : validatePortfolioContent(content!);
  PortfolioCompletion? get completion =>
      content == null ? null : calculatePortfolioCompletion(content!);
  bool get canEdit =>
      loaded &&
      !loading &&
      failure?.kind != PortfolioDraftFailureKind.corrupted &&
      failure?.kind != PortfolioDraftFailureKind.unsupportedVersion;
  bool get canSave =>
      canEdit && !saving && hasUnsavedChanges && validationCodes.isEmpty;

  PortfolioDraftState copyWith({
    String? notes,
    Object? draft = _unchanged,
    Object? content = _unchanged,
    bool? loading,
    bool? loaded,
    bool? saving,
    Object? failure = _unchanged,
  }) => PortfolioDraftState(
    notes: notes ?? this.notes,
    draft: identical(draft, _unchanged) ? this.draft : draft as PortfolioDraft?,
    content: identical(content, _unchanged)
        ? this.content
        : content as PortfolioContent?,
    loading: loading ?? this.loading,
    loaded: loaded ?? this.loaded,
    saving: saving ?? this.saving,
    failure: identical(failure, _unchanged)
        ? this.failure
        : failure as PortfolioDraftFailure?,
  );
}
