import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import 'stackcard_states.dart';

class StackCardAsyncView<T> extends StatelessWidget {
  const StackCardAsyncView({
    super.key,
    required this.state,
    required this.data,
    required this.onRetry,
    this.retainDataDuringRefresh = false,
  });

  final AsyncValue<T> state;
  final Widget Function(T) data;
  final VoidCallback onRetry;

  /// Включается владельцем списка; initial loading/error не подменяет данными.
  final bool retainDataDuringRefresh;

  @override
  Widget build(BuildContext context) {
    if (retainDataDuringRefresh &&
        state.isRefreshing &&
        state.hasValue &&
        !state.hasError) {
      return Stack(
        children: [
          data(state.requireValue),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              semanticsLabel: context.strings.tr('common.loading'),
            ),
          ),
        ],
      );
    }
    return state.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: false,
      data: data,
      loading: () => SingleChildScrollView(
        child: StackCardStateView(
          kind: StackCardViewState.loading,
          title: context.strings.tr('async.loadingTitle'),
          message: context.strings.tr('async.loadingMessage'),
        ),
      ),
      error: (_, _) => SingleChildScrollView(
        child: StackCardStateView(
          kind: StackCardViewState.error,
          title: context.strings.tr('async.errorTitle'),
          message: context.strings.tr('async.errorMessage'),
          onRetry: onRetry,
        ),
      ),
    );
  }
}
