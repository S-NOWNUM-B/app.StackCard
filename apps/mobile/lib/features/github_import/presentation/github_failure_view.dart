import 'package:flutter/material.dart';

import '../../../shared/widgets/stackcard_states.dart';
import '../domain/github_failure.dart';

class GitHubFailureView extends StatelessWidget {
  const GitHubFailureView({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final GitHubFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (failure.kind) {
      GitHubFailureKind.invalidUsername => (
        'Проверь username',
        'Введи имя аккаунта GitHub без ссылки.',
      ),
      GitHubFailureKind.notFound => (
        'Профиль не найден',
        'Проверь username. Доступны только публичные данные GitHub.',
      ),
      GitHubFailureKind.network => (
        'Нет соединения',
        'Проверь доступ к интернету и повтори запрос.',
      ),
      GitHubFailureKind.timeout => (
        'GitHub не ответил вовремя',
        'Соединение заняло слишком много времени. Попробуй ещё раз.',
      ),
      GitHubFailureKind.rateLimited => (
        'Лимит запросов GitHub',
        'GitHub временно ограничил запросы. Подожди перед повтором.',
      ),
      GitHubFailureKind.forbidden => (
        'Данные недоступны',
        'GitHub запретил этот запрос. Попробуй другой публичный профиль.',
      ),
      GitHubFailureKind.server => (
        'GitHub временно недоступен',
        'Повтори запрос немного позже.',
      ),
      GitHubFailureKind.invalidResponse => (
        'Не удалось прочитать данные',
        'GitHub вернул неожиданный ответ. Повтори запрос.',
      ),
      GitHubFailureKind.cancelled => (
        'Запрос отменён',
        'Можно загрузить профиль снова.',
      ),
    };
    final deadline = failure.retryAt?.toLocal();
    final retryMessage = deadline == null
        ? ''
        : ' Можно повторить после '
              '${deadline.hour.toString().padLeft(2, '0')}:'
              '${deadline.minute.toString().padLeft(2, '0')}:'
              '${deadline.second.toString().padLeft(2, '0')}.';
    return StackCardStateView(
      kind: StackCardViewState.error,
      title: title,
      message: '$message$retryMessage',
      onRetry: onRetry,
    );
  }
}
