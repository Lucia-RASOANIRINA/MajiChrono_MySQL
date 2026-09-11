import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/network_profile.dart';

/// Etat reseau expose a toute l'application (EXI-T06).
class NetworkStatus {
  const NetworkStatus({
    required this.reachable,
    required this.profile,
    required this.transport,
    required this.lastProbeAt,
    this.rttMs,
  });

  const NetworkStatus.unknown()
    : reachable = false,
      profile = NetworkProfile.offline,
      transport = NetworkTransport.none,
      rttMs = null,
      lastProbeAt = null;

  /// Le serveur repond reellement — et pas seulement « une interface est up ».
  final bool reachable;
  final NetworkProfile profile;
  final NetworkTransport transport;
  final int? rttMs;
  final DateTime? lastProbeAt;

  bool get isOnline => reachable;

  NetworkStatus copyWith({
    bool? reachable,
    NetworkProfile? profile,
    NetworkTransport? transport,
    int? rttMs,
    DateTime? lastProbeAt,
  }) => NetworkStatus(
    reachable: reachable ?? this.reachable,
    profile: profile ?? this.profile,
    transport: transport ?? this.transport,
    rttMs: rttMs ?? this.rttMs,
    lastProbeAt: lastProbeAt ?? this.lastProbeAt,
  );
}

enum NetworkTransport { none, mobile, wifi, ethernet, other }

/// Service d'etat reseau.
///
/// `connectivity_plus` seul ne suffit pas : a Antananarivo une interface mobile
/// peut etre « connectee » sans qu'aucun paquet ne passe. Le service croise
/// donc l'etat systeme avec une **sonde applicative** sur `/health`, et c'est
/// le temps d'aller-retour mesure qui qualifie le profil (§9.2).
class NetworkStatusService {
  NetworkStatusService({
    required this._apiClient,
    Connectivity? connectivity,
    this._probeInterval = const Duration(seconds: 30),
  }) : _connectivity = connectivity ?? Connectivity();

  final ApiClient _apiClient;
  final Connectivity _connectivity;
  final Duration _probeInterval;

  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _timer;
  NetworkStatus _current = const NetworkStatus.unknown();
  bool _probing = false;

  Stream<NetworkStatus> get stream => _controller.stream;
  NetworkStatus get current => _current;

  Future<void> start() async {
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final transport = _mapTransport(results);
      _emit(_current.copyWith(transport: transport));
      // Un changement d'interface justifie une sonde immediate.
      unawaited(refresh());
    });
    _timer = Timer.periodic(_probeInterval, (_) => unawaited(refresh()));
    await refresh();
  }

  /// Force une mesure. Sans effet si une mesure est deja en vol.
  Future<NetworkStatus> refresh() async {
    if (_probing) return _current;
    _probing = true;
    try {
      final transport = _mapTransport(await _connectivity.checkConnectivity());
      // `connectivity_plus` est indicatif et peut signaler `none` sur le Web
      // alors que le navigateur a bien acces au serveur. La sonde applicative
      // reste donc la source de verite de la joignabilite.
      final rtt = await _apiClient.probe();
      _emit(
        NetworkStatus(
          reachable: rtt != null,
          profile: NetworkProfile.fromRttMs(rtt),
          transport: transport,
          rttMs: rtt,
          lastProbeAt: DateTime.now(),
        ),
      );
      return _current;
    } finally {
      _probing = false;
    }
  }

  void _emit(NetworkStatus status) {
    _current = status;
    if (!_controller.isClosed) _controller.add(status);
  }

  NetworkTransport _mapTransport(List<ConnectivityResult> results) {
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return NetworkTransport.none;
    }
    if (results.contains(ConnectivityResult.wifi)) return NetworkTransport.wifi;
    if (results.contains(ConnectivityResult.mobile)) return NetworkTransport.mobile;
    if (results.contains(ConnectivityResult.ethernet)) {
      return NetworkTransport.ethernet;
    }
    return NetworkTransport.other;
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _connectivitySub?.cancel();
    await _controller.close();
  }
}
