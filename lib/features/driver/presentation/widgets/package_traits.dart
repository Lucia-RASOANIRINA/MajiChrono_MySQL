import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Caracteristiques d'un colis, montrees au livreur avant acceptation.
///
/// Le livreur decide en **trente secondes** (EXI-L04), souvent moto a l'arret.
/// Un prix et deux adresses ne suffisent pas a savoir s'il peut prendre la
/// course : un colis fragile impose une conduite lente, un colis lourd ne tient
/// pas dans tous les top-cases, un colis de valeur engage sa responsabilite.
///
/// Ces trois informations existaient deja dans la declaration (EXI-C08) mais
/// n'etaient montrees nulle part. Les afficher ne change rien au modele — cela
/// rend seulement visible ce qui l'etait deja, au moment ou la decision se
/// prend.
enum PackageTrait {
  fragile,
  heavy,
  valuable,
  food,
  document,
  shopping;

  /// Traits deduits d'une course.
  ///
  /// Deduits, pas saisis : demander a l'expediteur de cocher « fragile » en
  /// plus de choisir « fragile » comme type de course serait lui faire dire deux
  /// fois la meme chose.
  static List<PackageTrait> of(Delivery delivery) {
    final traits = <PackageTrait>[];

    switch (delivery.kind) {
      case DeliveryKind.fragile:
        traits.add(PackageTrait.fragile);
      case DeliveryKind.food:
        traits.add(PackageTrait.food);
      case DeliveryKind.document:
        traits.add(PackageTrait.document);
      case DeliveryKind.shopping:
        traits.add(PackageTrait.shopping);
      case DeliveryKind.standard:
        break;
    }

    // Au-dela de cinq kilos, le colis ne tient plus dans un top-case ordinaire.
    if (delivery.package.weight == WeightCategory.from5to15 ||
        delivery.package.weight == WeightCategory.over15) {
      traits.add(PackageTrait.heavy);
    }

    // Le seuil de valeur declaree au-dela duquel la course engage vraiment le
    // livreur. En dessous, l'afficher ajouterait du bruit sur presque toutes
    // les courses.
    const valuableThresholdAriary = 200000;
    final declared = delivery.package.declaredValueAriary ?? 0;
    if (declared >= valuableThresholdAriary) traits.add(PackageTrait.valuable);

    return traits;
  }
}

/// Bandeau de pastilles, a placer sous le prix d'une offre.
class PackageTraits extends StatelessWidget {
  const PackageTraits({required this.delivery, super.key});

  final Delivery delivery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final traits = PackageTrait.of(delivery);
    if (traits.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        for (final trait in traits) _TraitChip(trait: trait, l10n: l10n),
      ],
    );
  }
}

class _TraitChip extends StatelessWidget {
  const _TraitChip({required this.trait, required this.l10n});

  final PackageTrait trait;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Icone **et** libelle. Une pastille muette obligerait a apprendre un code
    // couleur, et personne n'apprend un code couleur en trente secondes
    // (EXI-T09).
    final (icon, tone, label) = switch (trait) {
      PackageTrait.fragile => (
        Icons.warning_amber_rounded,
        AppColors.danger,
        l10n.traitFragile,
      ),
      PackageTrait.heavy => (
        Icons.fitness_center,
        AppColors.warning,
        l10n.traitHeavy,
      ),
      PackageTrait.valuable => (
        Icons.diamond_outlined,
        AppColors.accentDark,
        l10n.traitValuable,
      ),
      PackageTrait.food => (
        Icons.restaurant,
        AppColors.success,
        l10n.traitFood,
      ),
      PackageTrait.document => (
        Icons.description_outlined,
        AppColors.info,
        l10n.traitDocument,
      ),
      PackageTrait.shopping => (
        Icons.shopping_basket_outlined,
        AppColors.primary,
        l10n.traitShopping,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: AppRadii.componentAll,
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
