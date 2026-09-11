import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/admin/presentation/providers/admin_providers.dart';
import 'package:majichrono/features/admin/presentation/widgets/reason_sheet.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';
import 'package:majichrono/shared/widgets/mc_empty_state.dart';
import 'package:majichrono/shared/widgets/mc_skeleton.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';

/// Gestion des utilisateurs : deux onglets (clients / livreurs), une recherche
/// par nom ou numero, et pour chaque compte la suspension ou la reactivation —
/// toujours motivee, comme toute decision d'exploitation.
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({this.initialRole, super.key});

  /// Onglet ouvert a l'arrivee, quand on vient d'une tuile du tableau de bord.
  final String? initialRole;

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  String _query = '';
  late String _role = widget.initialRole == 'driver' ? 'driver' : 'client';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final users = ref.watch(
      adminUsersProvider((role: _role, query: _query)),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminUsersTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'client',
                  label: Text(l10n.adminUsersTabClients),
                  icon: const Icon(Icons.people_outline),
                ),
                ButtonSegment(
                  value: 'driver',
                  label: Text(l10n.adminUsersTabDrivers),
                  icon: const Icon(Icons.two_wheeler_outlined),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v.trim()),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.adminUsersSearch,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: const OutlineInputBorder(
                  borderRadius: AppRadii.componentAll,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: users.when(
              loading: () => const McSkeletonList(),
              error: (_, _) => McEmptyState(
                icon: Icons.people_outline,
                title: l10n.adminUsersEmpty,
                message: l10n.errorNetwork,
              ),
              data: (items) => items.isEmpty
                  ? McEmptyState(
                      icon: Icons.people_outline,
                      title: l10n.adminUsersEmpty,
                      message: l10n.adminUsersSearch,
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(
                          adminUsersProvider((role: _role, query: _query)),
                        );
                      },
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 72),
                        itemBuilder: (context, index) => _UserTile(
                          user: items[index],
                          onChanged: () => ref.invalidate(
                            adminUsersProvider((role: _role, query: _query)),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends ConsumerStatefulWidget {
  const _UserTile({required this.user, required this.onChanged});

  final AdminUser user;
  final VoidCallback onChanged;

  @override
  ConsumerState<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends ConsumerState<_UserTile> {
  bool _busy = false;

  Future<void> _toggleSuspension() async {
    final l10n = AppLocalizations.of(context);
    final suspended = widget.user.suspended;
    final decision = await askForReason(
      context,
      action: suspended
          ? ModerationAction.reinstateAccount
          : ModerationAction.suspendAccount,
      title: suspended ? l10n.adminReinstate : l10n.adminSuspend,
      actionLabel: suspended ? l10n.adminReinstate : l10n.adminSuspend,
      help: suspended ? l10n.adminReinstateHelp : l10n.adminSuspendHelp,
      destructive: !suspended,
    );
    if (decision == null || !mounted) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminActionsProvider)
          .suspendUser(accountId: widget.user.id, decision: decision);
      messenger.showSnackBar(SnackBar(content: Text(l10n.adminActionDone)));
      widget.onChanged();
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = widget.user;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: (user.suspended ? AppColors.danger : AppColors.primary)
            .withValues(alpha: 0.12),
        child: Icon(
          user.isDriver ? Icons.two_wheeler_outlined : Icons.person_outline,
          color: user.suspended ? AppColors.danger : AppColors.primary,
        ),
      ),
      title: Text(
        user.displayName.isEmpty ? user.phone : user.displayName,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Row(
        children: [
          Text(
            user.phone,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          McStatusBadge(
            label: user.suspended ? l10n.adminUserSuspended : l10n.adminUserActive,
            icon: user.suspended ? Icons.block : Icons.check_circle_outline,
            tone: user.suspended ? McStatusTone.danger : McStatusTone.success,
          ),
        ],
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              tooltip: user.suspended ? l10n.adminReinstate : l10n.adminSuspend,
              icon: Icon(
                user.suspended ? Icons.lock_open_outlined : Icons.block_outlined,
                color: user.suspended ? AppColors.success : AppColors.danger,
              ),
              onPressed: _toggleSuspension,
            ),
    );
  }
}
