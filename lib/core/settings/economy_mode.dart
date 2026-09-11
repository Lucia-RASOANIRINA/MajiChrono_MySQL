/// Mode economie de donnees (EXI-T08).
///
/// Le mode ne coupe rien d'essentiel. Il decale ce qui peut l'etre — les
/// photos — et empeche ce qui coute cher sans etre necessaire tout de suite —
/// le telechargement de tuiles a la volee.
///
/// La distinction est la regle de conception de ce fichier : **une preuve ne se
/// degrade jamais**. Un constat part avec ses quatre photos en pleine
/// definition, mode economie ou non, parce qu'une preuve amoindrie pour
/// economiser deux cents kilo-octets ne serait plus une preuve. Ce qui se
/// differe, c'est l'envoi ; jamais le contenu.
library;

/// Ce que le mode economie change, exigence par exigence.
class EconomySettings {
  const EconomySettings({
    this.enabled = false,
    this.deferPhotosToWifi = true,
    this.blockOnDemandTiles = true,
    this.reduceTrackingCadence = true,
  });

  final bool enabled;

  /// Les photos attendent une connexion non facturee.
  ///
  /// Elles restent capturees, chiffrees et conservees : c'est l'**envoi** qui
  /// attend, pas la prise de vue. Un livreur en mode economie fait ses constats
  /// exactement comme les autres.
  final bool deferPhotosToWifi;

  /// Aucune tuile de carte n'est telechargee a la demande.
  ///
  /// Le cache pre-telecharge continue de servir : la carte se degrade sur les
  /// quartiers jamais visites, elle ne disparait pas. Une carte partielle avec
  /// les points corrects reste utilisable ; un ecran vide ne l'est pas.
  final bool blockOnDemandTiles;

  /// La cadence d'emission des positions passe au palier superieur.
  final bool reduceTrackingCadence;

  EconomySettings copyWith({
    bool? enabled,
    bool? deferPhotosToWifi,
    bool? blockOnDemandTiles,
    bool? reduceTrackingCadence,
  }) => EconomySettings(
    enabled: enabled ?? this.enabled,
    deferPhotosToWifi: deferPhotosToWifi ?? this.deferPhotosToWifi,
    blockOnDemandTiles: blockOnDemandTiles ?? this.blockOnDemandTiles,
    reduceTrackingCadence: reduceTrackingCadence ?? this.reduceTrackingCadence,
  );

  /// Un envoi peut-il partir maintenant ?
  ///
  /// [isProof] est la porte de sortie : une preuve part toujours. Le parametre
  /// est **requis** a l'appel plutot que par defaut, pour qu'aucun appelant ne
  /// puisse differer une preuve par inadvertance.
  bool allowsUpload({
    required bool isProof,
    required bool isMetered,
    required int sizeBytes,
  }) {
    if (!enabled) return true;
    if (isProof) return true;
    if (!isMetered) return true;
    if (!deferPhotosToWifi) return true;

    // Sous ce seuil, differer coute plus en complexite qu'en forfait : une
    // vignette de quelques kilo-octets ne vaut pas une file d'attente.
    return sizeBytes <= smallPayloadBytes;
  }

  /// Charge en dessous de laquelle on n'attend pas.
  static const int smallPayloadBytes = 20 * 1024;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'deferPhotos': deferPhotosToWifi,
    'blockTiles': blockOnDemandTiles,
    'reduceCadence': reduceTrackingCadence,
  };

  static EconomySettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EconomySettings();
    return EconomySettings(
      enabled: json['enabled'] == true,
      deferPhotosToWifi: json['deferPhotos'] != false,
      blockOnDemandTiles: json['blockTiles'] != false,
      reduceTrackingCadence: json['reduceCadence'] != false,
    );
  }
}
