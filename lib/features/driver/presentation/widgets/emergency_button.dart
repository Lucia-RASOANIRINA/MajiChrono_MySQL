import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/driver/domain/entities/emergency.dart';
import 'package:majichrono/features/driver/presentation/providers/emergency_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Bouton d'urgence du livreur (EXI-L13, differenciant D10).
///
/// **Deux appuis, et rien entre les deux.** Un appui ouvre la feuille, un appui
/// envoie. Pas de menu deroulant, pas de champ a remplir, pas de dialogue de
/// confirmation supplementaire : chaque etape ajoutee est une seconde de plus
/// pour quelqu'un qui vient de se faire arreter au bord d'une route.
///
/// Le second appui n'est pas une politesse — c'est ce qui empeche le
/// declenchement dans une poche.
///
/// La qualification de l'urgence est **facultative** et posee apres coup : les
/// quatre natures sont proposees sous le bouton d'envoi, jamais avant. Une
/// alerte sans nature part quand meme, et c'est deja l'essentiel.
class EmergencyButton extends ConsumerWidget {
  const EmergencyButton({this.deliveryId, super.key});

  final String? deliveryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: AppSizes.minTouchTarget,
      child: OutlinedButton.icon(
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.sos_outlined, color: AppColors.danger),
        label: Text(
          l10n.emergencyButton,
          style: const TextStyle(
            color: AppColors.danger,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.danger, width: 2),
        ),
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) => showModalBottomSheet<void>(
    context: context,
    isDismissible: true,
    builder: (_) => _EmergencySheet(deliveryId: deliveryId),
  );
}

class _EmergencySheet extends ConsumerStatefulWidget {
  const _EmergencySheet({this.deliveryId});

  final String? deliveryId;

  @override
  ConsumerState<_EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends ConsumerState<_EmergencySheet> {
  EmergencyKind _kind = EmergencyKind.unspecified;
  EmergencyAlert? _sent;
  bool _busy = false;

  Future<void> _send() async {
    if (_busy) return;
    setState(() => _busy = true);

    // L'envoi ne peut pas echouer du point de vue du livreur : hors ligne,
    // l'alerte est conservee localement et part au retour du reseau. Lui
    // afficher un echec le laisserait croire que personne ne sait.
    final alert = await ref
        .read(emergencyActionsProvider)
        .raise(kind: _kind, deliveryId: widget.deliveryId);

    if (mounted) {
      setState(() {
        _busy = false;
        _sent = alert;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sent = _sent;

    String kindLabel(EmergencyKind kind) => switch (kind) {
      EmergencyKind.accident => l10n.emergencyAccident,
      EmergencyKind.aggression => l10n.emergencyAggression,
      EmergencyKind.breakdown => l10n.emergencyBreakdown,
      EmergencyKind.medical => l10n.emergencyMedical,
      EmergencyKind.unspecified => l10n.emergencyUnspecified,
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sent == null) ...[
              Text(
                l10n.emergencyTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.emergencyHelp, style: theme.textTheme.bodyLarge),
              const SizedBox(height: AppSpacing.lg),

              // Le deuxieme appui. Grand, rouge, seul : rien d'autre ne doit
              // pouvoir etre touche par erreur a sa place.
              SizedBox(
                height: AppSizes.driverActionHeight,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: _busy
                      ? const McLoader.small(color: Colors.white)
                      : const Icon(Icons.campaign),
                  label: Text(l10n.emergencySend),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              // La qualification vient **apres** le bouton, jamais avant : elle
              // precise l'alerte, elle ne conditionne pas son depart.
              Text(
                l10n.emergencyKindOptional,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final kind in EmergencyKind.values)
                    if (kind != EmergencyKind.unspecified)
                      ChoiceChip(
                        label: Text(kindLabel(kind)),
                        selected: _kind == kind,
                        onSelected: (on) => setState(
                          () => _kind = on ? kind : EmergencyKind.unspecified,
                        ),
                      ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 32,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.emergencySent,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                sent.kind.needsImmediateCallback
                    ? l10n.emergencyCallbackSoon
                    : l10n.emergencyAcknowledgePending,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.commonClose),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
