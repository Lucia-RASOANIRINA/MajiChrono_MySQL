import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Saisie du motif d'une decision d'exploitation (EXI-A03, EXI-A06).
///
/// Passage **oblige** de toute action de supervision. Le bouton de validation
/// reste inerte tant que le motif ne tient pas, et la feuille affiche ce qui
/// manque plutot que de rester muette — un bouton grise sans explication pousse
/// a taper n'importe quoi jusqu'a ce qu'il s'allume.
///
/// La feuille ne decide de rien elle-meme : elle rend un [ModerationDecision]
/// deja valide, ou `null` si l'utilisateur renonce. L'appelant n'a donc aucun
/// moyen d'agir sans motif, meme par erreur.
Future<ModerationDecision?> askForReason(
  BuildContext context, {
  required ModerationAction action,
  required String title,
  required String actionLabel,
  String? help,
  bool destructive = false,
}) => showModalBottomSheet<ModerationDecision>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _ReasonSheet(
    action: action,
    title: title,
    actionLabel: actionLabel,
    help: help,
    destructive: destructive,
  ),
);

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({
    required this.action,
    required this.title,
    required this.actionLabel,
    required this.destructive,
    this.help,
  });

  final ModerationAction action;
  final String title;
  final String actionLabel;
  final String? help;
  final bool destructive;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final decision = ModerationDecision.taken(
      action: widget.action,
      reason: _reason.text,
      decidedAt: DateTime.now(),
      // TODO(module 10) : l'identifiant de l'agent viendra de la session, une
      // fois les comptes d'exploitation crees cote serveur.
      decidedBy: 'ops',
    );
    if (decision != null) Navigator.of(context).pop(decision);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final typed = _reason.text.trim().length;
    final missing = ModerationAction.minReasonLength - typed;
    final ok = ModerationAction.isReasonAcceptable(_reason.text);

    return Padding(
      // Remonte au-dessus du clavier : sans cela le champ disparait derriere
      // sur un ecran de 320 dp.
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: theme.textTheme.titleLarge),
          if (widget.help != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.help!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _reason,
            autofocus: true,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.adminReasonLabel,
              // Dire combien il manque, plutot que « champ invalide » : c'est
              // la difference entre une consigne et un reproche.
              helperText: ok
                  ? l10n.adminReasonOk
                  : l10n.adminReasonMissing(missing),
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.edit_note_outlined),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.history_edu_outlined, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.adminReasonRecorded,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: ok ? _submit : null,
                  style: widget.destructive
                      ? FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        )
                      : null,
                  child: Text(widget.actionLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
