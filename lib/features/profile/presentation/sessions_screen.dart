import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/presentation/providers/auth_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Appareils connectes au compte : l'utilisateur voit ses sessions actives et
/// peut en revoquer une a distance — utile apres avoir prete son telephone, ou
/// en cas de doute sur un acces.
class SessionsScreen extends ConsumerStatefulWidget {
  const SessionsScreen({super.key});

  @override
  ConsumerState<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends ConsumerState<SessionsScreen> {
  late Future<List<SessionInfo>> _future = _load();
  String? _revoking;

  Future<List<SessionInfo>> _load() =>
      ref.read(authRepositoryProvider).listSessions();

  void _refresh() => setState(() => _future = _load());

  Future<void> _revoke(SessionInfo session) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _revoking = session.id);
    try {
      await ref.read(authRepositoryProvider).revokeSession(session.id);
      messenger.showSnackBar(SnackBar(content: Text(l10n.sessionRevoked)));
      _refresh();
    } on Failure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(failure.localizedMessage(l10n))),
      );
    } finally {
      if (mounted) setState(() => _revoking = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessionsTitle)),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<SessionInfo>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(l10n.errorNetwork)),
                ],
              );
            }
            final sessions = snapshot.data ?? const [];
            if (sessions.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(l10n.sessionsEmpty)),
                ],
              );
            }
            // La session courante en tete, le reste ensuite.
            final ordered = [
              ...sessions.where((s) => s.isCurrent),
              ...sessions.where((s) => !s.isCurrent),
            ];
            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: ordered.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _SessionCard(
                session: ordered[i],
                busy: _revoking == ordered[i].id,
                onRevoke: () => _revoke(ordered[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.busy,
    required this.onRevoke,
  });

  final SessionInfo session;
  final bool busy;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = session.deviceLabel ?? l10n.sessionUnknownDevice;
    final since = _formatDateTime(session.createdAt);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              session.isCurrent
                  ? Icons.smartphone
                  : Icons.devices_other_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.sessionSince(since),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (session.isCurrent)
              _CurrentChip(label: l10n.sessionCurrent)
            else if (busy)
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: onRevoke,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                child: Text(l10n.sessionRevoke),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}

class _CurrentChip extends StatelessWidget {
  const _CurrentChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.sm,
      vertical: AppSpacing.xs,
    ),
    decoration: BoxDecoration(
      color: AppColors.success.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.success,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    ),
  );
}
