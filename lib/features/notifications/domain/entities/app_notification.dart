/// Les quatre canaux de notification d'Android, paramietrables separement par
/// l'utilisateur (EXI-N02).
///
/// Le systeme Android range les notifications par canal : l'utilisateur peut
/// couper le commercial sans perdre les courses. C'est pour cela qu'ils sont
/// distincts et nommes — un canal unique retirerait ce reglage fin.
enum McNotificationChannel {
  /// Cycle de la course : acceptee, livreur arrive, colis remis. Prioritaire et
  /// sonore (EXI-N03).
  courses('mc_courses'),

  /// Resultat d'un paiement.
  payment('mc_payment'),

  /// Incident sur une course.
  incidents('mc_incidents'),

  /// Annonces commerciales — le seul canal desactivable sans consequence
  /// operationnelle (EXI-N03).
  commercial('mc_commercial');

  const McNotificationChannel(this.id);

  /// Identifiant stable du canal cote Android. Ne doit jamais changer une fois
  /// livre : le systeme lie les preferences de l'utilisateur a cet identifiant.
  final String id;
}

/// Une notification prete a etre affichee.
///
/// Les textes arrivent **deja traduits** dans la langue du compte (EXI-N05) :
/// le service d'affichage ne connait pas les langues, il pose ce qu'on lui
/// donne. La [route] est le lien profond ouvert au toucher (EXI-N04).
class AppNotification {
  const AppNotification({
    required this.channel,
    required this.title,
    required this.body,
    this.route,
    this.id,
  });

  final McNotificationChannel channel;
  final String title;
  final String body;

  /// Chemin go_router ouvert quand l'utilisateur touche la notification. Absent,
  /// le toucher ouvre simplement l'application.
  final String? route;

  /// Identifiant d'affichage. Deux notifications de meme id se remplacent —
  /// utile pour mettre a jour l'etat d'une course sans empiler les messages.
  final int? id;
}
