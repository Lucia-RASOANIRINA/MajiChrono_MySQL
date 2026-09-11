import 'dart:io';

import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/shared/widgets/mc_card.dart';
import 'package:majichrono/shared/widgets/mc_status_badge.dart';

/// Un fait court accompagnant une course : une icone et sa valeur (distance,
/// heure estimee, prix). Le libelle arrive deja formate et traduit.
class McDeliveryFact {
  const McDeliveryFact(this.icon, this.text);

  final IconData icon;
  final String text;
}

/// Carte de course : le composant qui liste les livraisons, actives comme
/// terminees, cote client, livreur et admin.
///
/// Une seule carte pour tous ces ecrans — c'est ce qui fait qu'une course se
/// reconnait partout de la meme facon. Elle montre, de haut en bas : le statut
/// (pastille icone + libelle), le trajet (depart et arrivee relies par un petit
/// trace), une ligne de faits (distance, heure, prix), puis un pied facultatif
/// (mini-fiche livreur, bouton de detail...).
///
/// Tout le texte arrive traduit ; la carte ne fait que le disposer.
class McDeliveryCard extends StatelessWidget {
  const McDeliveryCard({
    required this.statusLabel,
    required this.statusIcon,
    required this.origin,
    required this.destination,
    this.statusTone = McStatusTone.neutral,
    this.facts = const [],
    this.leading,
    this.trailing,
    this.footer,
    this.onTap,
    this.accent,
    super.key,
  });

  final String statusLabel;
  final IconData statusIcon;
  final McStatusTone statusTone;
  final String origin;
  final String destination;
  final List<McDeliveryFact> facts;

  /// Vignette a gauche : la photo du colis ou de la facade quand elle existe,
  /// sinon une pastille thematique (voir [McDeliveryThumb]).
  final Widget? leading;

  /// Coin haut-droit de la carte, en regard du statut : typiquement le prix.
  final Widget? trailing;

  /// Pied facultatif : un bouton d'action, une mini-fiche livreur, etc.
  final Widget? footer;
  final VoidCallback? onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            McStatusBadge(
              label: statusLabel,
              icon: statusIcon,
              tone: statusTone,
            ),
            const Spacer(),
            ?trailing,
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Route(origin: origin, destination: destination),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              for (final fact in facts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      fact.icon,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      fact.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        if (footer != null) ...[
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          footer!,
        ],
      ],
    );

    return McCard(
      onTap: onTap,
      accent: accent,
      child: leading == null
          ? content
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading!,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: content),
              ],
            ),
    );
  }
}

/// Vignette d'une course : la photo du colis ou de la facade si un fichier
/// local existe, sinon une pastille thematique (icone sur fond teinte).
///
/// C'est l'emplacement photo demande sur chaque course. Il montre la vraie
/// photo des qu'elle est capturee par la chaine photo (EXI-C09), et reste
/// lisible en attendant — un carre vide se lirait comme un chargement bloque.
class McDeliveryThumb extends StatelessWidget {
  const McDeliveryThumb({
    required this.icon,
    this.imagePath,
    this.tint,
    this.size = 56,
    super.key,
  });

  final IconData icon;

  /// Chemin d'un fichier image local. Absent ou introuvable, on affiche la
  /// pastille thematique.
  final String? imagePath;
  final Color? tint;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tint ?? scheme.primary;
    final file = imagePath == null ? null : File(imagePath!);
    final hasPhoto = file != null && file.existsSync();

    return ClipRRect(
      borderRadius: AppRadii.componentAll,
      child: SizedBox(
        width: size,
        height: size,
        child: hasPhoto
            ? Image.file(file, fit: BoxFit.cover)
            : ColoredBox(
                color: color.withValues(alpha: 0.14),
                child: Icon(icon, color: color, size: size * 0.42),
              ),
      ),
    );
  }
}

/// Le petit trace depart -> arrivee : un point plein, un trait, un fanion.
class _Route extends StatelessWidget {
  const _Route({required this.origin, required this.destination});

  final String origin;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // La colonne de reperes, calee sur les deux lignes de texte.
        Column(
          children: [
            const SizedBox(height: 4),
            Icon(Icons.circle, size: 12, color: scheme.primary),
            Container(
              width: 2,
              height: 22,
              margin: const EdgeInsets.symmetric(vertical: 2),
              color: scheme.outlineVariant,
            ),
            Icon(Icons.location_on, size: 14, color: scheme.secondary),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                origin,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
