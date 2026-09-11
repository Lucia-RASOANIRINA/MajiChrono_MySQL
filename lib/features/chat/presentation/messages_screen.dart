import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/auth/presentation/controllers/auth_state.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/chat/presentation/chat_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';

/// Espace « Messages » : la boite de reception des conversations.
///
/// Une conversation par course, la plus recente en tete, avec le dernier
/// message et une pastille de non-lus. On relit la liste a chaque ouverture —
/// une discussion avance vite pendant une course, une liste figee mentirait.
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final conversations = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.messagesTitle)),
      body: conversations.when(
        loading: () => const McSkeletonList(),
        error: (_, _) => McEmptyState(
          icon: Icons.forum_outlined,
          title: l10n.messagesEmpty,
          message: l10n.errorNetwork,
        ),
        data: (items) => items.isEmpty
            ? McEmptyState(
                icon: Icons.forum_outlined,
                title: l10n.messagesEmpty,
                message: l10n.messagesEmptyHelp,
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(conversationsProvider);
                  await ref.read(conversationsProvider.future);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.xxl,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) => Card(
                    child: _ConversationTile(conversation: items[index]),
                  ),
                ),
              ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final Conversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final myId = _currentAccountId(ref);
    final fromMe =
        conversation.lastSenderId != null && conversation.lastSenderId == myId;
    final preview = fromMe
        ? l10n.messagesYouPrefix(conversation.lastMessage)
        : conversation.lastMessage;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: const Icon(Icons.person_outline, color: AppColors.primary),
      ),
      title: Text(
        conversation.counterpartyName,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: conversation.hasUnread
              ? FontWeight.w700
              : FontWeight.w600,
        ),
      ),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: conversation.hasUnread
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: conversation.hasUnread
              ? FontWeight.w600
              : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(conversation.lastAt),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (conversation.hasUnread)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              child: Text(
                conversation.unread > 99 ? '99+' : '${conversation.unread}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            const SizedBox(height: 18),
        ],
      ),
      onTap: () => context.push(
        AppRoutes.chat(conversation.deliveryId),
        extra: conversation.counterpartyName,
      ),
    );
  }

  String? _currentAccountId(WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).valueOrNull;
    return switch (auth) {
      AuthAuthenticated(:final account) => account.id,
      AuthLocked(:final account) => account.id,
      _ => null,
    };
  }

  /// Heure du jour pour aujourd'hui, sinon la date : le repere utile change avec
  /// l'anciennete du message.
  String _formatTime(DateTime at) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final sameDay =
        at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return '${two(at.hour)}:${two(at.minute)}';
    return '${two(at.day)}/${two(at.month)}';
  }
}
