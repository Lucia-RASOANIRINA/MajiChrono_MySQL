import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/notifications/domain/entities/app_notification.dart';
import 'package:majichrono/features/notifications/domain/entities/center_notification.dart';
import 'package:majichrono/features/notifications/presentation/providers/notification_center_provider.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';

/// Centre de notifications (EXI-N06) : l'historique de ce que l'application a
/// affiche, avec son etat de lecture et le lien profond de chaque ligne.
///
/// La notification systeme est ephemere ; ici, elle reste. Une ligne non lue se
/// distingue par une pastille et un fond legerement teinte ; la toucher la
/// marque lue et ouvre son ecran, s'il y en a un.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(notificationCenterProvider);
    final controller = ref.read(notificationCenterProvider.notifier);
    final hasUnread = items.any((n) => !n.read);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.notifCenterTitle),
        actions: [
          if (hasUnread)
            IconButton(
              tooltip: l10n.notifCenterMarkAllRead,
              icon: const Icon(Icons.done_all),
              onPressed: controller.markAllRead,
            ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: l10n.notifCenterClear,
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: controller.clear,
            ),
        ],
      ),
      body: items.isEmpty
          ? McEmptyState(
              icon: Icons.notifications_none_outlined,
              title: l10n.notifCenterTitle,
              message: l10n.notifCenterEmpty,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: _NotificationTile(
                    item: item,
                    onTap: () {
                      controller.markRead(index);
                      final route = item.route;
                      if (route != null && route.isNotEmpty) {
                        context.go(route);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final CenterNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _channelStyle(item.channel, theme);

    return ListTile(
      onTap: onTap,
      // Une ligne non lue prend un fond legerement teinte : le repere est visuel
      // avant d'etre textuel.
      tileColor: item.read
          ? null
          : theme.colorScheme.primary.withValues(alpha: 0.06),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        foregroundColor: color,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
        ),
      ),
      subtitle: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _stamp(item.receivedAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!item.read) ...[
            const SizedBox(height: 6),
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Horodatage numerique, neutre vis-a-vis de la langue : jour/mois puis heure.
  String _stamp(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final time = '${two(at.hour)}:${two(at.minute)}';
    if (at.year == now.year && at.month == now.month && at.day == now.day) {
      return time;
    }
    return '${two(at.day)}/${two(at.month)} $time';
  }

  (IconData, Color) _channelStyle(McNotificationChannel channel, ThemeData t) =>
      switch (channel) {
        McNotificationChannel.courses => (
          Icons.local_shipping_outlined,
          t.colorScheme.primary,
        ),
        McNotificationChannel.payment => (
          Icons.payments_outlined,
          AppColors.success,
        ),
        McNotificationChannel.incidents => (
          Icons.warning_amber_outlined,
          AppColors.accent,
        ),
        McNotificationChannel.commercial => (
          Icons.campaign_outlined,
          t.colorScheme.onSurfaceVariant,
        ),
      };
}
