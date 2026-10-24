import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/stackcard_colors.dart';
import '../../../core/theme/stackcard_tokens.dart';
import '../../../shared/widgets/stackcard_avatar.dart';
import '../../../shared/widgets/stackcard_brand.dart';
import '../../../shared/widgets/stackcard_button.dart';
import '../../../shared/widgets/stackcard_card.dart';
import '../../../shared/widgets/stackcard_icon.dart';
import '../../../shared/widgets/stackcard_technology_badge.dart';
import '../developer_card_providers.dart';
import '../document_publication_providers.dart';
import '../domain/developer_card.dart';
import 'developer_card_qr.dart';
import 'portfolio_document_publication_screen.dart';

class DeveloperCardScreen extends ConsumerStatefulWidget {
  const DeveloperCardScreen({super.key, required this.documentId});
  final String documentId;
  @override
  ConsumerState<DeveloperCardScreen> createState() =>
      _DeveloperCardScreenState();
}

class _DeveloperCardScreenState extends ConsumerState<DeveloperCardScreen> {
  DeveloperCardRepository? _owner;
  bool _busy = false;
  String? _message;
  bool get _active =>
      mounted &&
      _owner != null &&
      identical(_owner, ref.read(developerCardRepositoryProvider));
  @override
  void initState() {
    super.initState();
    _owner = ref.read(developerCardRepositoryProvider);
    Future<void>.microtask(() async {
      if (_active) {
        await ref.read(documentPublicationControllerProvider.notifier).load();
      }
    });
  }

  Future<void> _retry() async {
    if (!_active || _busy) return;
    setState(() => _message = null);
    await ref.read(documentPublicationControllerProvider.notifier).load();
    if (_active) ref.invalidate(developerCardProvider(widget.documentId));
  }

  Future<void> _action(String action, DeveloperCard captured) async {
    if (!_active || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // Перед системным действием повторно проверяем inventory и public snapshot.
      await ref.read(documentPublicationControllerProvider.notifier).load();
      if (!_active) return;
      final current = await _confirmedCard();
      if (!_active) return;
      if (current.publicId != captured.publicId ||
          current.version != captured.version ||
          current.url != captured.url) {
        throw const DeveloperCardFailure(DeveloperCardFailureKind.stale);
      }
      if (action == 'copy') {
        await Clipboard.setData(ClipboardData(text: current.url.toString()));
        if (_active) setState(() => _message = 'Ссылка скопирована.');
      } else {
        final actions = ref.read(documentLinkActionsProvider);
        if (actions == null) {
          throw const DeveloperCardFailure(
            DeveloperCardFailureKind.unavailable,
          );
        }
        if (action == 'open') {
          await actions.open(current.url);
        } else {
          await actions.share(current.url);
        }
      }
    } catch (_) {
      if (_active) {
        setState(
          () => _message =
              'Действие недоступно. Проверьте публикацию и повторите.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<DeveloperCard> _confirmedCard() async {
    final result = Completer<DeveloperCard>();
    final subscription = ref.listenManual(
      developerCardProvider(widget.documentId),
      (_, next) {
        if (result.isCompleted) return;
        if (!_active) {
          result.completeError(
            const DeveloperCardFailure(DeveloperCardFailureKind.unavailable),
          );
          return;
        }
        if (next.isLoading) return;
        if (next.hasError) {
          final error = next.error!;
          // SDK может сначала прислать отвергнутый cache/pending event.
          // Action ждёт только новое server data, с прежним ограничением20s.
          if (error is DeveloperCardFailure &&
              error.kind == DeveloperCardFailureKind.unavailable) {
            return;
          }
          result.completeError(error);
        } else if (next.hasValue) {
          result.complete(next.requireValue);
        }
      },
      fireImmediately: true,
    );
    try {
      return await result.future.timeout(const Duration(seconds: 20));
    } finally {
      subscription.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(developerCardRepositoryProvider);
    final ownerChanged = !identical(_owner, repository);
    final card = ref.watch(developerCardProvider(widget.documentId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Card'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const StackCardIcon(name: 'arrow-left'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: _message == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(StackCardSpacing.lg),
              child: Semantics(liveRegion: true, child: Text(_message!)),
            ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: StackCardSize.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.all(StackCardSpacing.lg),
              children: [
                if (ownerChanged)
                  const Text(
                    'Аккаунт изменился. Закройте карточку и откройте её заново.',
                  )
                else if (repository == null)
                  const Text(
                    'Карточка недоступна: нужен аккаунт и настроенная публикация.',
                  )
                else
                  card.when(
                    skipLoadingOnRefresh: false,
                    skipLoadingOnReload: false,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(switch (error) {
                          DeveloperCardFailure(
                            kind: DeveloperCardFailureKind.unpublished,
                          ) =>
                            'Портфолио ещё не опубликовано или снято с публикации. QR-код появится после подтверждённой публикации.',
                          DeveloperCardFailure(
                            kind: DeveloperCardFailureKind.unknown,
                          ) =>
                            'Результат публикации неизвестен. Сначала восстановите предыдущую операцию.',
                          DeveloperCardFailure(
                            kind: DeveloperCardFailureKind.stale,
                          ) =>
                            'Публичная версия изменилась. Обновите карточку.',
                          _ => 'Не удалось проверить опубликованное портфолио. Подключитесь к сети и повторите.',
                        }),
                        const SizedBox(height: StackCardSpacing.md),
                        StackCardButton(
                          label: 'Повторить проверку',
                          role: StackCardButtonRole.outlined,
                          onPressed: _busy ? null : _retry,
                        ),
                        const SizedBox(height: StackCardSpacing.sm),
                        StackCardButton(
                          label: 'Управлять публикацией',
                          onPressed: _busy
                              ? null
                              : () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          PortfolioDocumentPublicationScreen(
                                            documentId: widget.documentId,
                                          ),
                                    ),
                                  );
                                  if (_active) await _retry();
                                },
                        ),
                      ],
                    ),
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Опубликованная версия',
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                        const SizedBox(height: StackCardSpacing.md),
                        DeveloperCardView(card: data),
                        const SizedBox(height: StackCardSpacing.lg),
                        for (final item in const [
                          ('copy', 'Копировать ссылку'),
                          ('open', 'Открыть портфолио'),
                          ('share', 'Поделиться ссылкой'),
                        ]) ...[
                          StackCardButton(
                            key: ValueKey('developerCard.${item.$1}'),
                            label: item.$2,
                            role: item.$1 == 'share'
                                ? StackCardButtonRole.primary
                                : StackCardButtonRole.outlined,
                            onPressed: _busy
                                ? null
                                : () => _action(item.$1, data),
                          ),
                          const SizedBox(height: StackCardSpacing.sm),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Светлая карточка использует опубликованные данные и existing Brand A/Manrope.
class DeveloperCardView extends StatelessWidget {
  const DeveloperCardView({super.key, required this.card});
  final DeveloperCard card;
  @override
  Widget build(BuildContext context) {
    final name = card.name.isEmpty ? card.title : card.name;
    return StackCardCard(
      outlined: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: StackCardBrand(compact: true),
          ),
          const SizedBox(height: StackCardSpacing.lg),
          Center(
            child: StackCardAvatar(
              size: 96,
              initials: name.isEmpty
                  ? '?'
                  : name.characters.first.toUpperCase(),
              image: card.avatarBytes == null
                  ? null
                  : Image.memory(card.avatarBytes!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: StackCardSpacing.md),
          Text(
            name,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (card.headline.isNotEmpty)
            Text(
              card.headline,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
          if (card.username.isNotEmpty)
            Text('@${card.username}', textAlign: TextAlign.center),
          if (card.technologies.isNotEmpty) ...[
            const SizedBox(height: StackCardSpacing.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final technology in card.technologies.take(8))
                  StackCardTechnologyBadge(label: technology),
                if (card.technologies.length > 8)
                  StackCardMoreTechnologies(
                    count: card.technologies.length - 8,
                    label: 'Показать все технологии',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Технологии'),
                        scrollable: true,
                        content: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final technology in card.technologies)
                              StackCardTechnologyBadge(label: technology),
                          ],
                        ),
                        actions: [
                          StackCardButton(
                            label: 'Закрыть',
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: StackCardSpacing.lg),
          DeveloperCardQr(url: card.url),
          const SizedBox(height: StackCardSpacing.md),
          SelectableText(card.url.toString(), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
