/// Achat pour compte (EXI-C07, differenciant D5).
///
/// Le livreur **avance ses propres fonds**, puis se fait rembourser a la
/// remise. Ce n'est donc pas une option de confort : c'est une prise de risque
/// personnelle, et tout ce fichier est construit autour de cette phrase.
///
/// Trois consequences en decoulent, et aucune n'est negociable :
///
///  - un **plafond** borne ce qu'on lui fait porter. Il est verifie cote
///    serveur, pas seulement affiche ;
///  - le **ticket de caisse** est la piece qui justifie le remboursement.
///    Sans lui, le livreur n'a que sa parole ;
///  - l'ecart entre l'estime et le reel est **annonce**, jamais absorbe en
///    silence.
library;

/// Un article de la liste de courses.
class ShoppingItem {
  const ShoppingItem({
    required this.label,
    required this.quantity,
    this.estimatedUnitAriary,
    this.note,
    this.substitutable = false,
  });

  final String label;
  final int quantity;

  /// Prix unitaire estime par l'expediteur. Indicatif : c'est le ticket de
  /// caisse qui fera foi.
  final int? estimatedUnitAriary;

  final String? note;

  /// L'article peut-il etre remplace si le magasin n'en a pas ?
  ///
  /// La question est posee **article par article** et non pour la liste
  /// entiere : accepter un autre riz n'engage pas a accepter un autre
  /// medicament. Sans ce grain, le livreur devrait telephoner a chaque rupture,
  /// ou decider a la place de quelqu'un d'autre.
  final bool substitutable;

  int get estimatedTotalAriary => (estimatedUnitAriary ?? 0) * quantity;

  bool get isValid => label.trim().isNotEmpty && quantity > 0;

  Map<String, dynamic> toJson() => {
    'label': label.trim(),
    'quantity': quantity,
    if (estimatedUnitAriary != null) 'estimatedUnit': estimatedUnitAriary,
    if (note != null) 'note': note,
    'substitutable': substitutable,
  };

  static ShoppingItem? fromJson(Map<String, dynamic> json) {
    final label = json['label'] as String?;
    if (label == null) return null;
    return ShoppingItem(
      label: label,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      estimatedUnitAriary: (json['estimatedUnit'] as num?)?.toInt(),
      note: json['note'] as String?,
      substitutable: json['substitutable'] == true,
    );
  }
}

/// Liste de courses confiee au livreur.
class ShoppingOrder {
  const ShoppingOrder({
    required this.items,
    required this.capAriary,
    this.storeHint,
    this.receiptPhotoId,
    this.actualTotalAriary,
  });

  final List<ShoppingItem> items;

  /// Plafond de depense (EXI-C07).
  ///
  /// C'est la seule protection du livreur : au-dela, il n'achete pas et
  /// appelle. Un plafond absent reviendrait a lui demander un cheque en blanc
  /// sur son propre argent.
  final int capAriary;

  /// Indication de magasin, jamais une obligation : le livreur connait son
  /// quartier mieux que l'expediteur.
  final String? storeHint;

  /// Photo du ticket de caisse (EXI-C07).
  ///
  /// Elle passe par le meme pipeline que les photos de constat (module 5) :
  /// 1280 px, 200 Ko, empreinte SHA-256. Une seconde chaine photo aurait
  /// diverge de la premiere au premier ajustement.
  final String? receiptPhotoId;

  /// Montant reellement paye, releve sur le ticket.
  final int? actualTotalAriary;

  /// Plancher et plafond admissibles pour le plafond lui-meme.
  ///
  /// Le maximum n'est pas une limite technique : c'est le montant au-dela
  /// duquel on ne demande plus a un livreur d'avancer de l'argent sans accord
  /// prealable de l'exploitation.
  static const int minCapAriary = 5000;
  static const int maxCapAriary = 500000;

  int get estimatedTotalAriary =>
      items.fold(0, (sum, item) => sum + item.estimatedTotalAriary);

  bool get hasItems => items.isNotEmpty && items.every((i) => i.isValid);

  bool get isCapAcceptable =>
      capAriary >= minCapAriary && capAriary <= maxCapAriary;

  /// Le plafond couvre-t-il l'estimation ?
  ///
  /// Un plafond inferieur a ce que l'expediteur a lui-meme estime est presque
  /// toujours une erreur de saisie. On le signale avant l'envoi plutot que de
  /// laisser le livreur le decouvrir devant la caisse.
  bool get capCoversEstimate =>
      estimatedTotalAriary == 0 || capAriary >= estimatedTotalAriary;

  bool get isComplete => hasItems && isCapAcceptable;

  /// Le montant reel depasse-t-il le plafond ?
  ///
  /// Le cas doit rester impossible — le livreur s'arrete au plafond — mais s'il
  /// survient, il vaut mieux qu'il soit detectable que silencieux.
  bool get exceedsCap =>
      actualTotalAriary != null && actualTotalAriary! > capAriary;

  /// Ecart entre l'estime et le reel, positif quand ca coute plus cher.
  int? get variance => actualTotalAriary == null
      ? null
      : actualTotalAriary! - estimatedTotalAriary;

  /// Somme a rembourser au livreur.
  ///
  /// Plafonnee : ce qui a ete depense au-dela du plafond n'engage pas
  /// l'expediteur, et c'est precisement ce que le plafond signifie.
  int get reimbursableAriary {
    final actual = actualTotalAriary;
    if (actual == null) return 0;
    return actual > capAriary ? capAriary : actual;
  }

  ShoppingOrder copyWith({
    List<ShoppingItem>? items,
    int? capAriary,
    String? storeHint,
    String? receiptPhotoId,
    int? actualTotalAriary,
  }) => ShoppingOrder(
    items: items ?? this.items,
    capAriary: capAriary ?? this.capAriary,
    storeHint: storeHint ?? this.storeHint,
    receiptPhotoId: receiptPhotoId ?? this.receiptPhotoId,
    actualTotalAriary: actualTotalAriary ?? this.actualTotalAriary,
  );

  Map<String, dynamic> toJson() => {
    'items': items.map((i) => i.toJson()).toList(),
    'cap': capAriary,
    if (storeHint != null) 'storeHint': storeHint,
    if (receiptPhotoId != null) 'receiptPhotoId': receiptPhotoId,
    if (actualTotalAriary != null) 'actualTotal': actualTotalAriary,
  };

  static ShoppingOrder? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return ShoppingOrder(
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ShoppingItem.fromJson)
          .whereType<ShoppingItem>()
          .toList(),
      capAriary: (json['cap'] as num?)?.toInt() ?? 0,
      storeHint: json['storeHint'] as String?,
      receiptPhotoId: json['receiptPhotoId'] as String?,
      actualTotalAriary: (json['actualTotal'] as num?)?.toInt(),
    );
  }
}
