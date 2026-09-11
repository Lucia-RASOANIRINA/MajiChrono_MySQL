/// Coordonnees du support MajiChrono.
///
/// Regroupees ici — une seule source — pour que le centre d'aide, un e-mail de
/// signalement ou un futur appel d'urgence pointent tous vers le meme numero et
/// la meme adresse. A ajuster le jour ou l'assistance a sa propre ligne.
class SupportContact {
  const SupportContact._();

  /// Ligne d'assistance. Numero malgache au format canonique.
  static const String phone = '+261320000000';

  static const String email = 'support@majichrono.mg';
}
