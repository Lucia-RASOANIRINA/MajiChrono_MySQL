/// Paiement adosse aux soldes MajiPay, execute dans MajiChrono (§11.2).
///
/// Le partage des roles est le suivant : **MajiPay tient les soldes**,
/// MajiChrono conduit la transaction. Les deux telephones s'apparient par un
/// code QR, et le mouvement est arbitre par le serveur.
///
/// Une regle domine tout le reste, et elle est portee par le code plutot que
/// par la documentation : **scanner n'autorise jamais un debit**. Le scan ne
/// fait qu'apparier deux appareils. Celui qui paie confirme toujours sur son
/// propre telephone, avec son code. Sans cette regle, quiconque scanne un code
/// affiche par un tiers pourrait se servir sur son compte.
library;

/// Sens de l'appariement.
///
/// L'argent va toujours du client au livreur ; ce qui change, c'est **qui
/// presente le code et qui le scanne**. Les deux sens existent parce que les
/// deux situations existent : un livreur qui tend son telephone au comptoir, un
/// client qui prefere garder le sien en main.
enum PaymentDirection {
  /// Le livreur presente le code, le client le scanne puis confirme.
  ///
  /// C'est une **demande d'encaissement** : elle ne debite rien tant que le
  /// client n'a pas confirme chez lui.
  collect('collect'),

  /// Le client presente le code, le livreur le scanne pour encaisser.
  ///
  /// C'est une **offre de paiement** : le client a deja confirme le montant
  /// avec son code au moment de creer l'intention. Le scan du livreur ne fait
  /// que reclamer ce qui a ete autorise.
  offer('offer');

  const PaymentDirection(this.wireName);

  final String wireName;

  static PaymentDirection fromWire(String? value) =>
      PaymentDirection.values.firstWhere(
        (d) => d.wireName == value,
        orElse: () => PaymentDirection.collect,
      );

  /// Le payeur a-t-il deja donne son accord au moment de la creation ?
  ///
  /// Vrai pour l'offre — le client a saisi son code avant d'afficher le sien.
  /// Faux pour la demande : le client n'a encore rien vu.
  bool get payerPreAuthorized => this == PaymentDirection.offer;

  /// Qui presente le code.
  bool get presentedByDriver => this == PaymentDirection.collect;
}

/// Etat d'une intention de paiement (EXI-MP05).
enum PaymentStatus {
  /// Creee, en attente d'appariement.
  pending('pending'),

  /// Appariee : le code a ete scanne, les deux appareils se connaissent.
  claimed('claimed'),

  /// Confirmee par le payeur, mouvement effectue.
  captured('captured'),

  /// Refusee, expiree, ou solde insuffisant.
  failed('failed'),

  /// Basculee en especes (EXI-MP08).
  cash('cash');

  const PaymentStatus(this.wireName);

  final String wireName;

  static PaymentStatus fromWire(String? value) =>
      PaymentStatus.values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => PaymentStatus.pending,
      );

  /// Etat definitif : plus rien ne bougera, le sondage peut cesser.
  bool get isFinal =>
      this == PaymentStatus.captured ||
      this == PaymentStatus.failed ||
      this == PaymentStatus.cash;

  /// La course peut-elle etre reglee comme payee ?
  bool get settles =>
      this == PaymentStatus.captured || this == PaymentStatus.cash;
}

/// Motif d'echec, montre tel quel a l'utilisateur.
enum PaymentFailure {
  none('none'),
  insufficientFunds('insufficient_funds'),
  expired('expired'),
  declined('declined'),
  unavailable('unavailable');

  const PaymentFailure(this.wireName);

  final String wireName;

  static PaymentFailure fromWire(String? value) =>
      PaymentFailure.values.firstWhere(
        (f) => f.wireName == value,
        orElse: () => PaymentFailure.none,
      );

  /// Un repli especes est-il la suite naturelle ?
  ///
  /// Toujours, sauf quand il n'y a rien a replier. La course ne doit jamais
  /// rester bloquee sur un probleme de paiement (EXI-MP08, EXI-C43).
  bool get suggestsCash => this != PaymentFailure.none;
}

/// Solde MajiPay d'un utilisateur.
///
/// Il est **lu**, jamais calcule ni conserve : MajiPay en est la source de
/// verite. Un solde recopie dans MajiChrono divergerait au premier mouvement
/// fait ailleurs, et afficherait un montant faux au moment de payer.
class MajiPayBalance {
  const MajiPayBalance({
    required this.availableAriary,
    required this.accountRef,
    required this.fetchedAt,
  });

  final int availableAriary;

  /// Reference masquee du compte, du type `MP ** ** 4821`. Le numero complet
  /// n'a aucune raison de transiter (EXI-MP11).
  final String accountRef;

  final DateTime fetchedAt;

  bool covers(int amountAriary) => availableAriary >= amountAriary;

  static MajiPayBalance? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    return MajiPayBalance(
      availableAriary: (json['available'] as num?)?.toInt() ?? 0,
      accountRef: '${json['accountRef'] ?? ''}',
      fetchedAt:
          DateTime.tryParse('${json['fetchedAt']}')?.toLocal() ??
          DateTime.now(),
    );
  }
}

/// Intention de paiement (EXI-MP02).
///
/// Elle est **creee par le serveur**. Le mobile ne detient qu'un identifiant et
/// un jeton a usage unique : aucun secret durable ne descend sur l'appareil, et
/// un telephone vole ne donne acces a aucun solde.
class PaymentIntent {
  const PaymentIntent({
    required this.id,
    required this.deliveryId,
    required this.amountAriary,
    required this.direction,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.token,
    this.payerLabel,
    this.payeeLabel,
    this.failure = PaymentFailure.none,
    this.capturedAt,
    this.receiptRef,
  });

  final String id;
  final String deliveryId;
  final int amountAriary;
  final PaymentDirection direction;
  final PaymentStatus status;
  final DateTime createdAt;

  /// Peremption courte. Un code affiche sur un comptoir et oublie ne doit pas
  /// rester encaissable une heure plus tard.
  final DateTime expiresAt;

  /// Jeton a usage unique, present uniquement chez celui qui presente le code.
  /// Il n'est jamais journalise (EXI-MP11).
  final String? token;

  final String? payerLabel;
  final String? payeeLabel;
  final PaymentFailure failure;
  final DateTime? capturedAt;

  /// Reference du recu, une fois le mouvement effectue (EXI-MP10).
  final String? receiptRef;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  /// Contenu du code QR.
  ///
  /// Il ne porte **que** l'identifiant et le jeton : ni montant, ni nom, ni
  /// numero de compte. Le scanneur interroge le serveur pour connaitre le
  /// reste, si bien qu'un code photographie a distance ne revele rien et ne
  /// vaut rien sans la confirmation du payeur.
  String get qrPayload => 'majichrono://pay?i=$id&t=${token ?? ''}';

  static PaymentIntent? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final id = json['id'] as String?;
    if (id == null) return null;

    return PaymentIntent(
      id: id,
      deliveryId: '${json['deliveryId'] ?? ''}',
      amountAriary: (json['amount'] as num?)?.toInt() ?? 0,
      direction: PaymentDirection.fromWire(json['direction'] as String?),
      status: PaymentStatus.fromWire(json['status'] as String?),
      createdAt:
          DateTime.tryParse('${json['createdAt']}')?.toLocal() ??
          DateTime.now(),
      expiresAt:
          DateTime.tryParse('${json['expiresAt']}')?.toLocal() ??
          DateTime.now().add(PaymentQr.lifetime),
      token: json['token'] as String?,
      payerLabel: json['payerLabel'] as String?,
      payeeLabel: json['payeeLabel'] as String?,
      failure: PaymentFailure.fromWire(json['failure'] as String?),
      capturedAt: DateTime.tryParse('${json['capturedAt']}')?.toLocal(),
      receiptRef: json['receiptRef'] as String?,
    );
  }
}

/// Lecture et ecriture du contenu d'un code QR de paiement.
class PaymentQr {
  const PaymentQr._();

  /// Duree de validite d'un code. Assez pour tendre un telephone et scanner,
  /// trop courte pour qu'un code oublie serve a quoi que ce soit.
  static const Duration lifetime = Duration(minutes: 5);

  static const String scheme = 'majichrono';

  /// Analyse un contenu scanne.
  ///
  /// Retourne `null` sur tout ce qui n'est pas un code de paiement MajiChrono :
  /// une etiquette de colis, un code Wi-Fi, une publicite. Un scanneur qui
  /// accepterait n'importe quoi enverrait des identifiants inconnus au serveur.
  static ScannedPayment? parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    if (uri.scheme != scheme || uri.host != 'pay') return null;

    final id = uri.queryParameters['i'];
    final token = uri.queryParameters['t'];
    if (id == null || id.isEmpty) return null;
    if (token == null || token.isEmpty) return null;

    return ScannedPayment(intentId: id, token: token);
  }
}

/// Resultat de l'analyse d'un code scanne.
class ScannedPayment {
  const ScannedPayment({required this.intentId, required this.token});

  final String intentId;
  final String token;
}

/// Recu d'un retrait MajiPay (EXI-MP09).
///
/// Il porte la reference remise par le prestataire — de quoi retrouver le
/// mouvement chez MajiPay en cas de litige — et le solde **restant**, que
/// l'ecran relit sans avoir a interroger le serveur une seconde fois.
class WithdrawReceipt {
  const WithdrawReceipt({
    required this.ref,
    required this.amountAriary,
    required this.balance,
  });

  final String ref;
  final int amountAriary;
  final MajiPayBalance balance;

  static WithdrawReceipt? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final balance = MajiPayBalance.fromJson(json);
    if (balance == null) return null;
    return WithdrawReceipt(
      ref: '${json['receiptRef'] ?? ''}',
      amountAriary: (json['amount'] as num?)?.toInt() ?? 0,
      balance: balance,
    );
  }
}

/// Entree du journal de paiements (§11, EXI-C39).
///
/// Un [PaymentIntent] enrichi de la position du compte courant dans la
/// transaction. La distinction porte l'affichage : un paiement **sortant**
/// (le compte est payeur) se lit en debit, un paiement **entrant** en credit.
/// Le serveur la calcule — le mobile n'a pas a comparer des identifiants.
class PaymentHistoryEntry {
  const PaymentHistoryEntry({required this.intent, required this.isOutgoing});

  final PaymentIntent intent;

  /// Vrai quand le compte courant est le payeur de la transaction.
  final bool isOutgoing;

  static PaymentHistoryEntry? fromJson(Map<String, dynamic>? json) {
    final intent = PaymentIntent.fromJson(json);
    if (intent == null) return null;
    return PaymentHistoryEntry(
      intent: intent,
      isOutgoing: json!['role'] != 'payee',
    );
  }
}
