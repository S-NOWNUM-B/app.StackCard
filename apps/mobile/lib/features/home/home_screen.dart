import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/stackcard_colors.dart';
import '../../core/theme/stackcard_tokens.dart';
import '../../shared/widgets/stackcard_dialog_actions.dart';
import '../../shared/widgets/stackcard_button.dart';
import '../auth/auth.dart';
import '../media/media.dart';
import '../portfolio_draft/portfolio_draft.dart';

/// Главная читает только durable snapshot; буфер редактора не участвует в outputs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(portfolioDraftRepositoryProvider);
    final account = ref.watch(accountAuthRepositoryProvider);
    final session = account == null ? null : ref.watch(accountSessionProvider);
    final ready =
        session == null ||
        (session.hasValue && !session.isLoading && !session.hasError);
    final guest = account == null || ref.watch(guestAccessProvider);
    // Shell сохраняет ветку; незавершённая операция прежнего UID не блокирует новый.
    return _HomeBody(
      key: ValueKey((repository, account, session?.value?.uid, guest, ready)),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  const _HomeBody({super.key});
  @override
  ConsumerState<_HomeBody> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<_HomeBody> {
  bool _downloading = false;
  bool _sharing = false;

  bool _active(PortfolioDraftRepository repository, String? uid) =>
      mounted &&
      identical(ref.read(portfolioDraftRepositoryProvider), repository) &&
      ref.read(accountSessionProvider).value?.uid == uid;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _download(PortfolioContent saved) async {
    final repository = ref.read(portfolioDraftRepositoryProvider);
    final uid = ref.read(accountSessionProvider).value?.uid;
    final actions = ref.read(portfolioPdfFileActionsProvider);
    if (actions == null) {
      _message('Сохранение PDF недоступно на этом устройстве.');
      return;
    }
    setState(() => _downloading = true);
    try {
      Uint8List? avatar;
      final showsProfile = saved.blocks.any(
        (block) => block.kind == PortfolioBlockKind.profile && block.visible,
      );
      if (showsProfile && saved.profile.avatarPath.isNotEmpty) {
        final media = ref.read(portfolioMediaRepositoryProvider);
        if (media == null || media.ownerUid != uid) {
          throw const PortfolioPdfFailure(PortfolioPdfFailureKind.unavailable);
        }
        avatar = await media.read(saved.profile.avatarPath);
      } else if (showsProfile && saved.profile.avatarUrl.isNotEmpty) {
        avatar = await ref
            .read(portfolioLegacyAvatarReaderProvider)
            .read(saved.profile.avatarUrl);
      }
      if (!_active(repository, uid)) return;
      final bytes = await ref
          .read(portfolioPdfGeneratorProvider)
          .generate(saved, avatarBytes: avatar);
      if (!_active(repository, uid)) return;
      final success = await actions.savePdf(bytes);
      if (_active(repository, uid) && success) {
        _message('Портфолио сохранено в PDF.');
      }
    } catch (_) {
      if (_active(repository, uid)) {
        _message(
          'Не удалось сохранить PDF. Проверьте доступ к фото и повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<String?> _choice(
    String title,
    String message,
    List<({String value, String label})> choices,
  ) => showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        StackCardDialogActions(
          onCancel: () => Navigator.pop(context),
          onConfirm: () => Navigator.pop(context, choice.value),
        ),
      ],
    ),
  );

  Future<void> _share(String documentId) async {
    final repository = ref.read(portfolioDraftRepositoryProvider);
    final uid = ref.read(accountSessionProvider).value?.uid;
    if (uid == null ||
        ref.read(documentPublicationRepositoryProvider) == null) {
      _message(
        'Публикация недоступна: нужен аккаунт и настроенный сервер публикации.',
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      final controller = ref.read(
        documentPublicationControllerProvider.notifier,
      );
      await controller.load();
      if (!_active(repository, uid)) return;
      var state = ref.read(documentPublicationControllerProvider);
      if (state.pending != null) {
        final choice = await _choice(
          'Результат публикации ещё не подтверждён',
          'Проверьте прежний запрос или повторите его. Новый запрос пока не отправляется.',
          [
            (value: 'check', label: 'Проверить'),
            (value: 'retry', label: 'Повторить'),
          ],
        );
        if (!_active(repository, uid) || choice == null) return;
        final success = choice == 'check'
            ? await controller.checkOperation()
            : await controller.retryOperation();
        if (!_active(repository, uid)) return;
        if (!success) {
          _message(
            'Не удалось подтвердить публикацию. Повторите проверку позже.',
          );
          return;
        }
        state = ref.read(documentPublicationControllerProvider);
      }
      if (state.inventory == null || state.loading || state.busy) {
        _message(
          'Не удалось загрузить публикацию. Проверьте соединение и повторите.',
        );
        return;
      }
      var publication = state.forDocument(documentId);
      var publish = publication?.shareableUrl == null;
      if (publish) {
        final choice = await _choice(
          'Опубликовать портфолио?',
          'Сохранённое портфолио станет доступно по публичной ссылке. Изменения в редакторе не включаются.',
          [(value: 'publish', label: 'Опубликовать и поделиться')],
        );
        if (!_active(repository, uid) || choice != 'publish') return;
      } else {
        final draft = ref.read(portfolioDraftControllerProvider).draft;
        final mutation = ref
            .read(portfolioSyncStateProvider)
            .confirmedMutationId;
        final newer =
            draft?.pendingSync == true ||
            (mutation != null && mutation != publication!.sourceMutationId);
        if (newer) {
          final choice = await _choice(
            'Есть новая сохранённая версия',
            'Обновить публичное портфолио перед отправкой ссылки?',
            [
              (value: 'existing', label: 'Поделиться текущей'),
              (value: 'update', label: 'Обновить и поделиться'),
            ],
          );
          if (!_active(repository, uid) || choice == null) return;
          publish = choice == 'update';
        }
      }
      if (publish) {
        if (ref.read(documentPublicationSavedMutationProvider) == null) {
          _message(
            'Сохранённая версия ещё не синхронизирована. Дождитесь соединения и повторите.',
          );
          return;
        }
        final success = await controller.perform(
          action: DocumentPublicationAction.publish,
          documentId: documentId,
          savedVersion: true,
        );
        if (!_active(repository, uid)) return;
        if (!success) {
          _message(
            'Публикация не подтверждена. Повторное нажатие позволит проверить результат.',
          );
          return;
        }
        publication = ref
            .read(documentPublicationControllerProvider)
            .forDocument(documentId);
      }
      final url = publication?.shareableUrl;
      if (url == null || !_active(repository, uid)) {
        _message('Публичная ссылка пока недоступна.');
        return;
      }
      final actions = ref.read(documentLinkActionsProvider);
      if (actions != null) {
        try {
          await actions.share(url);
          return;
        } catch (_) {
          if (!_active(repository, uid)) return;
        }
      }
      await Clipboard.setData(ClipboardData(text: url.toString()));
      if (_active(repository, uid)) _message('Ссылка скопирована.');
    } catch (_) {
      if (_active(repository, uid)) {
        _message('Не удалось поделиться портфолио. Повторите позже.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => WorkspaceReadGate(
    data: (_) {
      final workspace = ref
          .watch(portfolioDraftControllerProvider)
          .draft
          ?.content;
      final saved = workspace == null
          ? null
          : resolvedMainPortfolioContent(workspace);
      final document = workspace == null
          ? null
          : mainPortfolioDocument(workspace);
      final nonempty = saved != null && portfolioHasDisplayContent(saved);
      final busy = _downloading || _sharing;
      final download = StackCardButton(
        key: const Key('home.download'),
        label: 'Скачать портфолио',
        onPressed: nonempty && !busy ? () => _download(saved) : null,
      );
      final share = StackCardButton(
        key: const Key('home.share'),
        label: 'Поделиться',
        primary: true,
        loading: _sharing,
        onPressed: nonempty && !busy && document != null
            ? () => _share(document.id)
            : null,
      );
      return ListView(
        key: const Key('home.savedPortfolio'),
        padding: const EdgeInsets.all(StackCardSpacing.lg),
        children: [
          LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= 360 &&
                    MediaQuery.textScalerOf(context).scale(1) <= 1.3
                ? Row(
                    children: [
                      Expanded(child: download),
                      const SizedBox(width: 8),
                      Expanded(child: share),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [download, const SizedBox(height: 8), share],
                  ),
          ),
          const SizedBox(height: StackCardSpacing.xl),
          if (nonempty)
            MainPortfolioContentView(content: saved)
          else
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: StackCardSpacing.xl,
              ),
              child: Column(
                children: [
                  Text(
                    'Портфолио пока пустое',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: StackCardSpacing.sm),
                  Text(
                    workspace?.documents.isNotEmpty == true && document == null
                        ? 'Откройте Редактор и выберите основу из прежних документов.'
                        : 'Заполните портфолио в Редакторе и нажмите «Сохранить».',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
