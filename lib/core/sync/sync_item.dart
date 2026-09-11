import 'dart:convert';
import 'dart:math';

/// Vocabulaire de la file de synchronisation (§10.2, EXI-S01 a EXI-S07).
///
/// Le module 6 repose sur une idee simple, mais qui doit tenir sous la pression :
/// **rien n'est jamais tente sur le reseau avant d'avoir ete ecrit localement**.
/// L'utilisateur voit son action aboutir tout de suite ; la file se charge du
/// reste, y compris trois jours plus tard, y compris apres un redemarrage.

/// Ordre de passage des elements (EXI-S02).
///
/// L'ordre n'est pas une preference d'implementation, c'est une regle metier :
/// une preuve part avant un changement de statut, qui part avant des positions,
/// qui partent avant une notation. Sur un forfait 2G a moitie vide, ce qui passe
/// en premier est ce qui compte le plus.
enum SyncPriority {
  /// Constats de prise en charge et de remise. Ce qui ne peut pas etre refait.
  custody(0, 'custody'),

  /// Creations de course et transitions de statut.
  transition(1, 'transition'),

  /// Lots de positions du livreur.
  position(2, 'position'),

  /// Notations et signalements differables.
  rating(3, 'rating');

  const SyncPriority(this.rank, this.wireName);

  final int rank;
  final String wireName;

  static SyncPriority fromRank(int rank) => SyncPriority.values.firstWhere(
    (p) => p.rank == rank,
    orElse: () => SyncPriority.position,
  );

  /// Une preuve n'est jamais abandonnee automatiquement (EXI-S05).
  bool get neverAbandon => this == SyncPriority.custody;
}

/// Etat d'un element dans la file.
enum SyncItemStatus {
  /// En attente d'une fenetre reseau.
  pending('pending'),

  /// Envoi en cours.
  inFlight('inFlight'),

  /// Une tentative a echoue ; l'element sera rejoue apres son delai.
  failed('failed'),

  /// Le serveur a refuse definitivement, ou le plafond de tentatives est
  /// atteint. L'element ne repart plus de lui-meme : seule une relance
  /// manuelle le remet en jeu (EXI-S06).
  abandoned('abandoned');

  const SyncItemStatus(this.wireName);

  final String wireName;

  static SyncItemStatus fromWire(String? value) =>
      SyncItemStatus.values.firstWhere(
        (s) => s.wireName == value,
        orElse: () => SyncItemStatus.pending,
      );

  /// Vrai lorsque l'element compte encore comme « en attente » pour l'usager.
  bool get isOutstanding => this != SyncItemStatus.abandoned;
}

/// Cause d'echec, telle qu'elle sera montree a l'utilisateur (EXI-S06).
///
/// L'ecran des elements en attente doit dire **pourquoi** ca ne passe pas. « Une
/// erreur est survenue » laisse le livreur sans decision a prendre ; « le
/// serveur a refuse : la course a deja ete livree » lui dit qu'il n'a rien a
/// attendre du bouton de relance.
enum SyncFailureCause {
  none('none'),
  network('network'),
  server('server'),
  conflict('conflict'),
  rejected('rejected'),
  exhausted('exhausted');

  const SyncFailureCause(this.wireName);

  final String wireName;

  static SyncFailureCause fromWire(String? value) =>
      SyncFailureCause.values.firstWhere(
        (c) => c.wireName == value,
        orElse: () => SyncFailureCause.none,
      );
}

/// Un element de la file, tel que la couche metier le manipule.
class SyncItem {
  const SyncItem({
    required this.id,
    required this.idempotencyKey,
    required this.method,
    required this.path,
    required this.payload,
    required this.priority,
    required this.status,
    required this.attempts,
    required this.createdAt,
    this.nextAttemptAt,
    this.lastError,
    this.neverAbandon = false,
  });

  final String id;

  /// Cle d'idempotence stable entre reprises (EXI-S01).
  ///
  /// Elle est generee **une fois**, a la mise en file, et conservee. Sans cela,
  /// un envoi parti puis coupe avant la reponse serait rejoue sous une nouvelle
  /// cle, et le serveur creerait un doublon — deux courses, ou deux constats.
  final String idempotencyKey;

  final String method;
  final String path;

  /// Corps encode en JSON. Null pour les requetes sans corps.
  final String payload;

  final SyncPriority priority;
  final SyncItemStatus status;
  final int attempts;
  final DateTime createdAt;
  final DateTime? nextAttemptAt;
  final String? lastError;

  /// Drapeau EXI-S05, pose a la mise en file et jamais retire.
  final bool neverAbandon;

  Map<String, dynamic>? get body {
    if (payload.isEmpty) return null;
    final decoded = jsonDecode(payload);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  SyncFailureCause get cause => SyncFailureCause.fromWire(lastError);

  /// Age de l'element, affiche tel quel a l'utilisateur (EXI-S06).
  Duration ageAt(DateTime now) => now.difference(createdAt);

  /// Vrai lorsque l'element peut partir maintenant.
  bool isDueAt(DateTime now) {
    if (status == SyncItemStatus.abandoned) return false;
    if (status == SyncItemStatus.inFlight) return false;
    final due = nextAttemptAt;
    return due == null || !due.isAfter(now);
  }
}

/// Politique de reprise (§10.2).
///
/// Reprise exponentielle plafonnee, avec un bruit aleatoire : si tous les
/// telephones d'Antananarivo rejouaient leur file a la seconde exacte ou le
/// reseau revient, ils reconstruiraient la panne qu'ils viennent de subir.
class SyncBackoff {
  const SyncBackoff({this.random});

  final Random? random;

  /// Plafond de tentatives avant signalement (§10.2).
  static const int maxAttempts = 15;

  static const Duration base = Duration(seconds: 5);
  static const Duration ceiling = Duration(minutes: 30);

  /// Delai avant la tentative numero [attempts] (1 pour la premiere reprise).
  Duration delayFor(int attempts) {
    if (attempts <= 0) return Duration.zero;

    // 2^(n-1) x 5 s, plafonne a 30 minutes. Au-dela, doubler encore
    // n'apporterait rien : un livreur qui rentre en zone couverte veut que sa
    // file reparte dans la demi-heure, pas le lendemain.
    final exponent = min(attempts - 1, 20);
    final raw = base * pow(2, exponent).toDouble();
    final capped = raw > ceiling ? ceiling : raw;

    // Bruit de +/- 20 %.
    final jitter = ((random?.nextDouble() ?? 0.5) - 0.5) * 0.4;
    final millis = (capped.inMilliseconds * (1 + jitter)).round();
    return Duration(milliseconds: millis);
  }

  /// Un element a-t-il epuise ses tentatives ?
  ///
  /// Le plafond ne s'applique pas aux elements marques « jamais abandonner »
  /// (EXI-S05). C'est une contradiction assumee avec le §10.2 : abandonner une
  /// preuve parce que le reseau a ete mauvais quinze fois serait exactement le
  /// defaut que la chaine de responsabilite s'emploie a rendre impossible. Le
  /// constat cesse seulement d'etre discret — il passe en tete de l'ecran des
  /// elements en attente, pour que le livreur sache qu'il doit agir.
  static bool isExhausted({
    required int attempts,
    required bool neverAbandon,
  }) => !neverAbandon && attempts >= maxAttempts;
}
