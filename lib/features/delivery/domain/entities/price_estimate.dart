import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

/// Une ligne de l'estimation, telle qu'elle est affichee a l'utilisateur.
class PriceLine {
  const PriceLine({
    required this.kind,
    required this.amountAriary,
    this.detail,
  });

  final PriceLineKind kind;
  final int amountAriary;

  /// Precision chiffree : « 4,2 km », « 5-15 kg ».
  final String? detail;
}

enum PriceLineKind {
  base,
  distance,
  weight,
  kindSurcharge,
  schedule,
  insurance,
}

/// Estimation de prix ventilee (EXI-C10).
///
/// L'exigence impose la ventilation, pas seulement le total, et c'est ce qui
/// distingue MajiChrono d'un prix annonce au telephone : l'expediteur voit d'ou
/// vient chaque ariary avant de confirmer. C'est aussi ce qui rend une
/// contestation de prix instruisible.
class PriceEstimate {
  const PriceEstimate({
    required this.lines,
    required this.totalAriary,
    required this.distanceKm,
    required this.isProvisional,
  });

  final List<PriceLine> lines;
  final int totalAriary;
  final double distanceKm;

  /// Vrai tant que la grille appliquee est la grille provisoire locale.
  ///
  /// Le §19.2 laisse la decision DO-3 — modele de commission et grille
  /// tarifaire — ouverte. Tant qu'elle n'est pas tranchee, l'application
  /// calcule avec une grille provisoire et **le dit** : afficher un prix ferme
  /// issu d'une hypothese serait mentir a l'expediteur, et lui promettre un
  /// montant que l'exploitation ne tiendra pas.
  final bool isProvisional;
}

/// Grille tarifaire.
///
/// Les montants sont en ariary. Ils sont **provisoires** : la decision DO-3 du
/// §19.2 n'est pas arbitree. La classe est concue pour que le serveur puisse
/// livrer sa propre grille sans changer une ligne de calcul — c'est pourquoi
/// elle porte ses parametres plutot que de les coder en dur dans la formule.
class TariffGrid {
  const TariffGrid({
    required this.baseAriary,
    required this.perKmAriary,
    required this.minimumAriary,
    required this.detourFactor,
    required this.scheduledSurchargeAriary,
    required this.insuranceRate,
  });

  /// Grille publique MajiChrono : 2 000 Ar + 800 Ar/km.
  static const TariffGrid provisional = TariffGrid(
    baseAriary: 2000,
    perKmAriary: 800,
    minimumAriary: 2000,
    // Le tarif public est base sur la distance calculee, sans coefficient cache.
    detourFactor: 1,
    scheduledSurchargeAriary: 1000,
    insuranceRate: 0.02,
  );

  final int baseAriary;
  final int perKmAriary;
  final int minimumAriary;
  final double detourFactor;
  final int scheduledSurchargeAriary;
  final double insuranceRate;

  PriceEstimate estimate({
    required double straightLineKm,
    required DeliveryKind kind,
    required WeightCategory weight,
    required PickupSlot slot,
    int? insuredValueAriary,
    bool isProvisional = true,
  }) {
    final distanceKm = straightLineKm * detourFactor;

    final lines = <PriceLine>[
      PriceLine(kind: PriceLineKind.base, amountAriary: baseAriary),
      PriceLine(
        kind: PriceLineKind.distance,
        amountAriary: (distanceKm * perKmAriary).round(),
        detail: '${distanceKm.toStringAsFixed(1)} km',
      ),
    ];

    if (weight.surchargeAriary > 0) {
      lines.add(
        PriceLine(
          kind: PriceLineKind.weight,
          amountAriary: weight.surchargeAriary,
        ),
      );
    }

    var subtotal = lines.fold<int>(0, (sum, line) => sum + line.amountAriary);

    if (kind.priceMultiplier != 1) {
      final surcharge = (subtotal * (kind.priceMultiplier - 1)).round();
      lines.add(
        PriceLine(kind: PriceLineKind.kindSurcharge, amountAriary: surcharge),
      );
      subtotal += surcharge;
    }

    if (!slot.isImmediate) {
      lines.add(
        PriceLine(
          kind: PriceLineKind.schedule,
          amountAriary: scheduledSurchargeAriary,
        ),
      );
      subtotal += scheduledSurchargeAriary;
    }

    if (insuredValueAriary != null && insuredValueAriary > 0) {
      final premium = (insuredValueAriary * insuranceRate).round();
      lines.add(
        PriceLine(kind: PriceLineKind.insurance, amountAriary: premium),
      );
      subtotal += premium;
    }

    return PriceEstimate(
      lines: lines,
      // Le plancher protege les courses tres courtes, dont le cout reel pour le
      // livreur (deplacement a vide, attente) ne depend pas de la distance.
      totalAriary: subtotal < minimumAriary ? minimumAriary : subtotal,
      distanceKm: distanceKm,
      isProvisional: isProvisional,
    );
  }
}

/// Separateur de milliers : espace insecable, ecrit en echappement.
///
/// Insecable parce qu'un montant coupe en fin de ligne se lit de travers, et
/// qu'un prix mal lu se conteste. Ecrit en echappement plutot qu'en clair : un
/// espace insecable est invisible dans le code source, rien ne le distingue
/// d'une espace ordinaire a la relecture, et cette ambiguite a deja coute un
/// test qui affichait deux chaines identiques a l'ecran.
const String thousandsSeparator = '\u00A0';

/// Mise en forme des montants en ariary, sans decimale : l'ariary ne s'utilise
/// pas au centime.
String formatAriary(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(thousandsSeparator);
    }
    buffer.write(digits[i]);
  }
  return '${amount < 0 ? '-' : ''}$buffer${thousandsSeparator}Ar';
}
