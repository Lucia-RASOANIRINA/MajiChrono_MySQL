/// Profils reseau du marche malgache (§4.1 du cahier des charges).
///
/// Sert a deux choses :
///  1. qualifier le reseau reel mesure par la sonde applicative, afin d'adapter
///     les cadences (EXI-C20 : 10 s en 4G, 45 s en 2G ; EXI-L11) ;
///  2. simuler un reseau degrade en developpement et en recette (§16.2).
enum NetworkProfile {
  offline(label: 'Hors ligne', minLatencyMs: 0, maxLatencyMs: 0, kbps: 0),
  twoG(label: '2G', minLatencyMs: 900, maxLatencyMs: 2500, kbps: 40),
  threeG(label: '3G', minLatencyMs: 220, maxLatencyMs: 700, kbps: 400),
  fourG(label: '4G', minLatencyMs: 40, maxLatencyMs: 180, kbps: 4000);

  const NetworkProfile({
    required this.label,
    required this.minLatencyMs,
    required this.maxLatencyMs,
    required this.kbps,
  });

  final String label;
  final int minLatencyMs;
  final int maxLatencyMs;

  /// Debit indicatif, utilise pour simuler le temps de transfert d'un corps.
  final int kbps;

  bool get isOnline => this != NetworkProfile.offline;

  /// Reseau juge trop faible pour du temps reel confortable.
  bool get isDegraded => this == NetworkProfile.twoG;

  /// Cadence de rafraichissement du suivi client (EXI-C20).
  Duration get trackingRefreshInterval => switch (this) {
    NetworkProfile.fourG => const Duration(seconds: 10),
    NetworkProfile.threeG => const Duration(seconds: 20),
    NetworkProfile.twoG => const Duration(seconds: 45),
    NetworkProfile.offline => const Duration(seconds: 60),
  };

  /// Qualification a partir d'un temps d'aller-retour mesure.
  static NetworkProfile fromRttMs(int? rttMs) {
    if (rttMs == null) return NetworkProfile.offline;
    if (rttMs > 800) return NetworkProfile.twoG;
    if (rttMs > 250) return NetworkProfile.threeG;
    return NetworkProfile.fourG;
  }
}
