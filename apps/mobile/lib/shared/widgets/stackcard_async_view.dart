import 'package:flutter/material.dart';
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
    loading: () => const SingleChildScrollView(
      child: StackCardStateView(
        kind: StackCardViewState.loading,
        title: 'Загрузка данных',
        message: 'Готовим портфолио для просмотра.',
      ),
    ),
    error: (_, _) => SingleChildScrollView(
      child: StackCardStateView(
        kind: StackCardViewState.error,
        title: 'Не удалось загрузить данные',
        message: 'Попробуйте ещё раз.',
        onRetry: onRetry,
      ),
    ),
  );
}
