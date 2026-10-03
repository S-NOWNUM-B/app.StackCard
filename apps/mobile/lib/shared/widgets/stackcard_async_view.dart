import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stackcard_states.dart';

class StackCardAsyncView<T> extends StatelessWidget {
  const StackCardAsyncView({
    super.key,
    required this.state,
    required this.data,
    required this.onRetry,
  });

  final AsyncValue<T> state;
  final Widget Function(T) data;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => state.when(
    skipLoadingOnRefresh: false,
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
