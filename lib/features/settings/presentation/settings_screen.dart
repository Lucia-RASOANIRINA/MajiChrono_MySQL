import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/router/app_routes.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/i18n/locale_controller.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/core/settings/economy_providers.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/features/notifications/presentation/providers/notification_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Reglages : langue (EXI-T05), apparence, consommation (EXI-T07), verrou et
/// deconnexion (EXI-T04, EXI-SEC10).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.authSignOut),
        content: Text(l10n.authSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            l10n.settingsLanguage,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Bascule a chaud : aucun redemarrage, l'ecran se retraduit sous les
          // doigts de l'utilisateur (EXI-T05).
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'fr',
                label: Text(l10n.langFrench),
                icon: const Icon(Icons.translate),
              ),
              ButtonSegment(
                value: 'mg',
                label: Text(l10n.langMalagasy),
                icon: const Icon(Icons.translate),
              ),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (selection) async {
              await ref
                  .read(localeProvider.notifier)
                  .set(AppLocales.fromCode(selection.first));
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.settingsTheme,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeSystem),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeLight),
              ),
              ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ],
            selected: {themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) async {
              await ref.read(themeModeProvider.notifier).set(selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Column(
              children: [
                // EXI-T08. Le reglage vit ici et non dans un ecran a part :
                // c'est une bascule, pas un parametrage.
                Consumer(
                  builder: (context, ref, _) {
                    final economy = ref.watch(economySettingsProvider);
                    return SwitchListTile(
                      secondary: const Icon(Icons.savings_outlined),
                      title: Text(l10n.economyTitle),
                      subtitle: Text(
                        economy.enabled
                            ? l10n.economyProofNever
                            : l10n.economyHelp,
                      ),
                      isThreeLine: true,
                      value: economy.enabled,
                      onChanged: (on) => ref
                          .read(economySettingsProvider.notifier)
                          .toggle(enabled: on),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.data_usage_outlined),
                  title: Text(l10n.dataUsageTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.dataUsage),
                ),
                const Divider(height: 1),
                // EXI-S06 : le compte des elements en attente est visible ici
                // et pas seulement dans le bandeau. Un livreur qui rentre de
                // tournee veut verifier que ses constats sont partis, sans
                // avoir a deviner ou regarder.
                ListTile(
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: Text(l10n.syncPendingTitle),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Consumer(
                        builder: (context, ref, _) {
                          final count =
                              ref.watch(pendingSyncCountProvider).valueOrNull ??
                              0;
                          if (count == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(
                              right: AppSpacing.sm,
                            ),
                            child: Badge(label: Text('$count')),
                          );
                        },
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => context.push(AppRoutes.pendingSync),
                ),
                const Divider(height: 1),
                // EXI-N03 : le commercial se coupe sans toucher aux canaux
                // operationnels (courses, paiement, incidents), qui restent
                // toujours actifs.
                Consumer(
                  builder: (context, ref, _) => SwitchListTile(
                    secondary: const Icon(Icons.notifications_active_outlined),
                    title: Text(l10n.notifSettingsCommercial),
                    value: ref.watch(commercialNotificationsProvider),
                    onChanged: (on) => ref
                        .read(commercialNotificationsProvider.notifier)
                        .set(enabled: on),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.profileEdit),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.profileEdit),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bookmark_outline),
                  title: Text(l10n.addressBookManage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.addressBook),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: Text(l10n.passwordManage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.passwordChange),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(l10n.authPinTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.authPin),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.devices_outlined),
                  title: Text(l10n.sessionsManage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.sessions),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(l10n.helpCenterManage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.helpCenter),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    l10n.authSignOut,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  // Action destructrice : confirmee, et l'utilisateur est
                  // prevenu de ce qu'elle efface (§15.2.6, EXI-SEC10).
                  onTap: () => _confirmSignOut(context, ref, l10n),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
