import 'package:flutter/foundation.dart';

/// Source des tuiles cartographiques.
///
/// Le fond de carte est le seul poste de MajiChrono qui puisse devenir payant
/// sans prevenir : il se facture au nombre de tuiles servies, et une carte
/// consultee dix fois par course sur mille courses par jour represente vite des
/// centaines de milliers de tuiles par mois. Le choix se fait donc ici, en un
/// seul endroit, et se change sans toucher un ecran.
///
/// **`tile.openstreetmap.org` n'est pas une option de production.** Le serveur
/// est offert par la fondation OSM pour l'usage occasionnel et sa politique
/// interdit explicitement les applications a fort trafic. Une application
/// commerciale qui s'en sert se fait bloquer par plage d'adresses, sans
/// avertissement et sans recours — et la carte tombe pour tous les utilisateurs
/// le meme jour. C'est pourquoi il reste cantonne au developpement.
enum TileSource {
  /// Serveur communautaire d'OpenStreetMap. **Developpement uniquement.**
  osmDev(
    url: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap',
    needsKey: false,
    productionReady: false,
  ),

  /// OpenFreeMap — source vectorielle gratuite, sans cle, sans quota.
  ///
  /// Finance par son fondateur et servi depuis des serveurs dedies, avec pour
  /// principe affiche qu'il n'y aura ni cle ni facturation. C'est le meilleur
  /// depart pour MajiChrono : rien a signer, rien a surveiller.
  ///
  /// La contrepartie est qu'aucun contrat ne garantit la disponibilite. On
  /// l'accepte parce que **la carte n'est jamais sur le chemin critique** — un
  /// livreur execute sa tournee avec des adresses et un telephone ; la carte
  /// aide, elle ne decide pas. Une panne de fond de carte degrade le confort,
  /// pas le service.
  openFreeMap(
    url: 'https://tiles.openfreemap.org/styles/liberty/{z}/{x}/{y}.pbf',
    attribution: '© OpenFreeMap © OpenStreetMap',
    needsKey: false,
    productionReady: true,
  ),

  /// CARTO Voyager — tuiles raster HTTPS, adaptees a `flutter_map`.
  ///
  /// OpenFreeMap fournit des tuiles vectorielles PBF et ne peut donc pas etre
  /// branche directement sur `TileLayer`, qui attend une image raster.
  cartoVoyager(
    url: 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
    attribution: '© CARTO © OpenStreetMap',
    needsKey: false,
    productionReady: true,
  ),

  /// MapTiler — 100 000 tuiles par mois offertes, puis payant.
  ///
  /// La voie a prendre le jour ou il faut un engagement de service : contrat,
  /// support, et statistiques d'usage. Le passage se fait en changeant cette
  /// valeur et en posant la cle.
  mapTiler(
    url: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key={key}',
    attribution: '© MapTiler © OpenStreetMap',
    needsKey: true,
    productionReady: true,
  ),

  /// Protomaps — un fichier unique, herbergeable n'importe ou.
  ///
  /// Un extrait de Madagascar tient dans quelques dizaines de megaoctets, se
  /// depose sur un stockage statique, et **fonctionne hors ligne** une fois
  /// telecharge. C'est l'aboutissement naturel pour une application qui vise
  /// des livreurs souvent sans reseau — mais il demande de produire et
  /// d'heberger l'extrait, donc du travail en amont.
  protomaps(
    url: '{host}/{z}/{x}/{y}.png',
    attribution: '© Protomaps © OpenStreetMap',
    needsKey: false,
    productionReady: true,
  );

  const TileSource({
    required this.url,
    required this.attribution,
    required this.needsKey,
    required this.productionReady,
  });

  /// Gabarit d'URL. `{key}` et `{host}` sont remplaces a la construction.
  final String url;

  /// Mention obligatoire a l'ecran. Elle n'est pas negociable : les licences
  /// d'OpenStreetMap et de ses derives l'exigent, et l'omettre expose a un
  /// retrait des tuiles.
  final String attribution;

  final bool needsKey;

  /// Faux quand la source ne tient pas la charge d'une application publiee.
  final bool productionReady;
}

/// Configuration effective du fond de carte.
class TileConfig {
  const TileConfig({required this.source, this.apiKey = '', this.host = ''});

  /// Configuration retenue.
  ///
  /// En debogage, le serveur d'OSM suffit. En release, CARTO Voyager fournit
  /// bien des images raster, contrairement aux tuiles PBF d'OpenFreeMap.
  factory TileConfig.forBuild() => TileConfig(
    source: kDebugMode ? TileSource.osmDev : TileSource.cartoVoyager,
  );

  final TileSource source;
  final String apiKey;
  final String host;

  String get urlTemplate =>
      source.url.replaceAll('{key}', apiKey).replaceAll('{host}', host);

  String get attribution => source.attribution;

  /// Vrai quand la configuration ne peut pas fonctionner telle quelle.
  ///
  /// Une source qui reclame une cle absente sert des tuiles grises sans le dire,
  /// et l'ecran ressemble alors a une panne reseau. Mieux vaut le savoir au
  /// demarrage qu'a la premiere course.
  bool get isMisconfigured => source.needsKey && apiKey.isEmpty;
}
