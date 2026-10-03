import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
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
    final prefix = 'github.failure.${failure.kind.name}';
    final title = context.strings.tr('$prefix.title');
    final message = context.strings.tr('$prefix.message');
    final deadline = failure.retryAt?.toLocal();
    final retryMessage = deadline == null
        ? ''
        : context.strings.tr('github.retryAfter', {
            'time':
                '${deadline.hour.toString().padLeft(2, '0')}:'
                '${deadline.minute.toString().padLeft(2, '0')}:'
                '${deadline.second.toString().padLeft(2, '0')}',
          });
    return StackCardStateView(
      kind: StackCardViewState.error,
      title: title,
      message: '$message$retryMessage',
      onRetry: onRetry,
    );
  }
}
