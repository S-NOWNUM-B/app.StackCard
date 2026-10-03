import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../domain/github_profile.dart';
import '../domain/github_repository.dart';

class GitHubProfileCard extends StatelessWidget {
  const GitHubProfileCard({super.key, required this.profile});

  final GitHubProfile profile;

  @override
  Widget build(BuildContext context) => StackCardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.name ?? profile.login,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        Text('@${profile.login}', style: Theme.of(context).textTheme.bodyLarge),
        if (profile.bio case final bio?) ...[
          const SizedBox(height: StackCardSpacing.lg),
          Text(bio, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (profile.location case final location?) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(location, style: Theme.of(context).textTheme.bodyMedium),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        Text(
          context.strings.tr('github.publicRepos', {
            'count': profile.publicRepositories,
          }),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: StackCardSpacing.sm),
        GitHubSourceLink(url: profile.htmlUrl),
      ],
    ),
  );
}

class GitHubRepositoryCard extends StatelessWidget {
  const GitHubRepositoryCard({
    super.key,
    required this.repository,
    this.showDescription = true,
  });

  final GitHubRepository repository;
  final bool showDescription;

  @override
  Widget build(BuildContext context) => StackCardCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(repository.name, style: Theme.of(context).textTheme.titleLarge),
        if (showDescription) ...[
          const SizedBox(height: StackCardSpacing.sm),
          Text(
            repository.description ??
                context.strings.tr('github.noDescription'),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.textSecondary),
          ),
        ],
        const SizedBox(height: StackCardSpacing.lg),
        Wrap(
          spacing: StackCardSpacing.lg,
          runSpacing: StackCardSpacing.sm,
          children: [
            Text(
              repository.language ?? context.strings.tr('github.noLanguage'),
            ),
            Text('Stars: ${repository.stars}'),
            Text('Forks: ${repository.forks}'),
            if (repository.isFork) const Text('Fork'),
            if (repository.archived)
              Text(context.strings.tr('github.filter.archived')),
          ],
        ),
        const SizedBox(height: StackCardSpacing.lg),
        GitHubSourceLink(url: repository.htmlUrl),
      ],
    ),
  );
}

class GitHubSourceLink extends StatelessWidget {
  const GitHubSourceLink({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(url, style: Theme.of(context).textTheme.bodySmall)),
      IconButton(
        tooltip: context.strings.tr('github.copyLink'),
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.copy_rounded),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: url));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.strings.tr('github.linkCopied'))),
          );
        },
      ),
    ],
  );
}
