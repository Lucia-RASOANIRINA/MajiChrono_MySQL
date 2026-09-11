import 'dart:convert';
import 'dart:math';

import 'package:majichrono/core/network/mock/mock_backend.dart';
import 'package:majichrono/features/admin/domain/entities/admin_entities.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';

/// Routes simulees de la supervision (§13).
///
/// Le module lit le registre des courses **par reference** plutot que d'en
/// tenir une copie : deux registres finiraient par diverger, et l'exploitation
/// verrait un tableau de bord qui ne correspond a aucune realite — le pire
/// defaut possible pour un ecran dont le seul role est de dire ce qui se passe.
///
/// Trois refus portent la valeur de ce simulateur :
///
///  - aucune decision sans motif suffisant (EXI-A03, EXI-A06) ;
///  - aucune reaffectation vers un livreur indisponible (EXI-A07) ;
///  - aucune reouverture d'un litige deja tranche (EXI-A05).
class AdminMockModule extends MockModule {
  AdminMockModule({required this._deliveries, Random? random})
    : _random = random ?? Random(2026);

  final Map<String, Map<String, dynamic>> Function() _deliveries;
  final Random _random;

  /// Flotte simulee. Les positions gravitent autour d'Antananarivo.
  late Map<String, Map<String, dynamic>> _fleet = _seedFleet();

  /// Dossiers KYC, **par livreur**. Le simulateur du module 4 n'en tenait
  /// qu'un seul pour toute l'application, ce qui suffisait a l'ecran du livreur
  /// mais rend une file de validation impossible a representer.
  late Map<String, Map<String, dynamic>> _kyc = _seedKyc();

  late Map<String, Map<String, dynamic>> _disputes = _seedDisputes();

  int _sequence = 0;

  @override
  void register(MockBackend backend) {
    backend.get('/admin/dashboard', _dashboard);
    backend.get('/admin/stats', _stats);
    backend.get('/admin/fleet', _fleetList);
    backend.get('/admin/kyc', _kycQueue);
    backend.post('/admin/kyc/{id}/review', _kycReview);
    backend.get('/admin/kyc/{id}/messages', _kycThreadList);
    backend.post('/admin/kyc/{id}/messages', _kycThreadReply);
    // Lecture d'une piece KYC (l'exploitant l'examine). Le simulateur ne
    // conserve pas les images : il rend une vignette de remplacement, de quoi
    // faire vivre la visionneuse en mode `mock`.
    backend.get('/accounts/{id}/kyc/{kind}', _kycDocumentImage);
    backend.post('/admin/drivers/{id}/suspension', _suspension);
    backend.get('/admin/users', _users);
    backend.post('/admin/users/{id}/suspension', _userSuspension);
    backend.post('/admin/deliveries/{id}/reassign', _reassign);
    backend.post('/disputes', _disputeOpen);
    backend.get('/disputes', _disputeList);
    backend.get('/disputes/{id}', _disputeRead);
    backend.post('/disputes/{id}/messages', _disputeMessage);
    backend.post('/disputes/{id}/decision', _disputeDecision);
  }

  @override
  Future<void> reset() async {
    _fleet = _seedFleet();
    _kyc = _seedKyc();
    _disputes = _seedDisputes();
    _kycThreads.clear();
    _suspendedUsers.clear();
    _sequence = 0;
  }

  // --- Tableau de bord (EXI-A01) ---------------------------------------

  Future<MockResponse> _dashboard(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final all = _deliveries().values.toList();

    final byStatus = <String, int>{};
    var active = 0;
    var revenue = 0;

    for (final raw in all) {
      final status = DeliveryStatus.fromWire(raw['status'] as String?);
      byStatus[status.wireName] = (byStatus[status.wireName] ?? 0) + 1;
      if (status.isActive) active++;
      // Le chiffre du jour ne compte que ce qui est effectivement encaisse :
      // additionner les courses en cours gonflerait un resultat qui n'existe
      // pas encore.
      if (status == DeliveryStatus.paid || status == DeliveryStatus.closed) {
        revenue += (raw['priceAriary'] as num?)?.toInt() ?? 0;
      }
    }

    return MockResponse.ok({
      'activeDeliveries': active,
      'onlineDrivers': _fleet.values
          .where(
            (d) =>
                d['status'] == FleetStatus.available.wireName ||
                d['status'] == FleetStatus.busy.wireName,
          )
          .length,
      'openIncidents': all
          .where(
            (d) =>
                DeliveryStatus.fromWire(d['status'] as String?) ==
                DeliveryStatus.refused,
          )
          .length,
      'openDisputes': _disputes.values
          .where(
            (d) => !DisputeStatus.fromWire(d['status'] as String?).isClosed,
          )
          .length,
      'pendingKyc': _kyc.values
          .where(
            (k) => k['status'] == 'submitted' || k['status'] == 'under_review',
          )
          .length,
      'revenueToday': revenue,
      // Effectifs simules : la flotte donne les livreurs ; on pose un nombre de
      // clients plausible pour que la tuile ne soit pas vide en demonstration.
      'totalDrivers': _fleet.length,
      'totalClients': 128,
      'byStatus': byStatus,
    });
  }

  // --- Flotte (EXI-A02) -------------------------------------------------

  Future<MockResponse> _fleetList(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final wanted = req.query['status'];
    final items = _fleet.values
        .where((d) => wanted == null || d['status'] == wanted)
        .toList();
    return MockResponse.ok({'items': items});
  }

  // --- Validation des dossiers (EXI-A03) --------------------------------

  Future<MockResponse> _kycQueue(MockRequest req, Map<String, String> _) async {
    final wanted = req.query['status'];
    final items =
        _kyc.values
            .where((k) => wanted == null || k['status'] == wanted)
            .toList()
          // Le plus ancien depot d'abord : une file de validation qui servirait les
          // derniers arrives laisserait un dossier attendre indefiniment.
          ..sort(
            (a, b) => '${a['submittedAt']}'.compareTo('${b['submittedAt']}'),
          );

    return MockResponse.ok({'items': items});
  }

  // PNG 1x1 : la plus petite image valide, de quoi decoder la visionneuse.
  static const String _placeholderPng =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

  Future<MockResponse> _kycDocumentImage(
    MockRequest req,
    Map<String, String> _,
  ) async => MockResponse(
    200,
    base64Decode(_placeholderPng),
    headers: const {
      'content-type': ['image/png'],
    },
  );

  Future<MockResponse> _kycReview(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final application = _kyc[params['id']];
    if (application == null) {
      return MockResponse.error(404, 'not_found', 'Dossier inconnu');
    }

    final approve = req.json['approve'] == true;
    final reason = '${req.json['reason'] ?? ''}';

    // EXI-A03 : le refus est motive. Le simulateur exige le motif dans les deux
    // sens — savoir pourquoi un dossier a ete accepte compte autant, le jour ou
    // le livreur cause un incident.
    if (!ModerationAction.isReasonAcceptable(reason)) {
      return MockResponse.error(
        422,
        'reason_required',
        'Motif obligatoire',
        details: {'minLength': ModerationAction.minReasonLength},
      );
    }

    final status = DisputeStatus.fromWire(application['status'] as String?);
    if (status == DisputeStatus.resolved) {
      return MockResponse.error(409, 'already_reviewed', 'Dossier deja traite');
    }

    application['status'] = approve ? 'approved' : 'rejected';
    application['reviewedAt'] = DateTime.now().toUtc().toIso8601String();
    application['rejectionReason'] = approve ? null : reason;
    application['reviewerId'] = 'ops_1';

    // Un dossier approuve fait entrer le livreur dans la flotte, hors service
    // tant qu'il ne s'est pas mis en ligne lui-meme.
    if (approve) {
      _fleet.putIfAbsent(
        '${application['driverId']}',
        () => {
          'id': application['driverId'],
          'displayName': application['displayName'],
          'status': FleetStatus.offline.wireName,
          'position': null,
          'rating': null,
        },
      );
    }

    return MockResponse.ok(application);
  }

  // --- Suspension de compte (EXI-A06) -----------------------------------

  Future<MockResponse> _suspension(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final driver = _fleet[params['id']];
    if (driver == null) {
      return MockResponse.error(404, 'not_found', 'Livreur inconnu');
    }

    final suspend = req.json['suspend'] == true;
    final reason = '${req.json['reason'] ?? ''}';

    if (!ModerationAction.isReasonAcceptable(reason)) {
      return MockResponse.error(
        422,
        'reason_required',
        'Motif obligatoire',
        details: {'minLength': ModerationAction.minReasonLength},
      );
    }

    // Un livreur en course ne peut pas etre suspendu sans que la course soit
    // d'abord reaffectee : le colis serait orphelin, entre deux mains.
    if (suspend && driver['currentDeliveryId'] != null) {
      return MockResponse.error(
        409,
        'driver_busy',
        'Reaffectez la course en cours avant de suspendre',
        details: {'currentState': '${driver['currentDeliveryId']}'},
      );
    }

    driver['status'] = suspend
        ? FleetStatus.suspended.wireName
        : FleetStatus.offline.wireName;
    driver['suspensionReason'] = suspend ? reason : null;

    return MockResponse.ok(driver);
  }

  // --- Reaffectation d'une course (EXI-A07) -----------------------------

  Future<MockResponse> _reassign(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final delivery = _deliveries()[params['id']];
    if (delivery == null) {
      return MockResponse.error(404, 'not_found', 'Course inconnue');
    }

    final targetId = '${req.json['driverId'] ?? ''}';
    final reason = '${req.json['reason'] ?? ''}';
    final target = _fleet[targetId];

    if (!ModerationAction.isReasonAcceptable(reason)) {
      return MockResponse.error(422, 'reason_required', 'Motif obligatoire');
    }

    if (target == null) {
      return MockResponse.error(404, 'driver_not_found', 'Livreur inconnu');
    }

    // Reaffecter vers un livreur hors service ou suspendu reviendrait a confier
    // le colis a personne, tout en affichant qu'il est pris en charge.
    final status = FleetStatus.fromWire(target['status'] as String?);
    if (!status.canReceiveDeliveries) {
      return MockResponse.error(
        409,
        'driver_unavailable',
        'Livreur indisponible',
        details: {'currentState': status.wireName},
      );
    }

    // L'ancien livreur est libere, le nouveau prend la course.
    final previousId = delivery['driverId'] as String?;
    if (previousId != null && _fleet[previousId] != null) {
      _fleet[previousId]!
        ..['currentDeliveryId'] = null
        ..['status'] = FleetStatus.available.wireName;
    }

    delivery['driverId'] = targetId;
    delivery['driverName'] = target['displayName'];
    target
      ..['currentDeliveryId'] = params['id']
      ..['status'] = FleetStatus.busy.wireName;

    return MockResponse.ok(delivery);
  }

  // --- Litiges (EXI-A05) ------------------------------------------------

  /// Rapport d'activite simule : des chiffres plausibles pour que l'ecran de
  /// statistiques se lise vraiment en demonstration, histogrammes compris.
  Future<MockResponse> _stats(MockRequest req, Map<String, String> _) async {
    const total = 342;
    const delivered = 298;
    const cancelled = 21;
    // Heures de pointe : deux bosses (midi et soir), comme une vraie journee.
    final peakHours = [
      for (var h = 0; h < 24; h++)
        {
          'hour': h,
          'count':
              (h >= 11 && h <= 13
                  ? 30 + (13 - (h - 12).abs()) * 6
                  : h >= 17 && h <= 20
                  ? 34 + (20 - h) * 4
                  : h >= 7 && h <= 22
                  ? 8 + (h % 4) * 2
                  : 1),
        },
    ];
    return MockResponse.ok({
      'totalDeliveries': total,
      'delivered': delivered,
      'cancelled': cancelled,
      'successRate': 0.934,
      'cancellationRate': 0.061,
      'revenueAriary': 2148000,
      'driverEarningsAriary': 1825800,
      'totalClients': 128,
      'totalDrivers': _fleet.length,
      'avgDeliveryMinutes': 27,
      'incidents': 9,
      'disputes': 3,
      'topZones': const [
        {'zone': 'Analakely', 'count': 74},
        {'zone': 'Ivandry', 'count': 61},
        {'zone': 'Ambohipo', 'count': 48},
        {'zone': 'Andraharo', 'count': 39},
        {'zone': 'Ambohimanarina', 'count': 22},
      ],
      'peakHours': peakHours,
      'driverPerformance': [
        for (final d in _fleet.values.take(5))
          {
            'driverId': d['id'],
            'displayName': d['displayName'],
            'delivered': 40 + (('${d['id']}').hashCode % 30).abs(),
            'rating': d['rating'],
          },
      ],
    });
  }

  /// Annuaire simule (clients + livreurs) et l'ensemble des comptes suspendus.
  final Set<String> _suspendedUsers = {};

  static const List<Map<String, String>> _seedClients = [
    {'id': 'cli_1', 'name': 'Hery Rakoto', 'phone': '+261340000001'},
    {'id': 'cli_2', 'name': 'Vola Ranaivo', 'phone': '+261340000012'},
    {'id': 'cli_3', 'name': 'Miora Andria', 'phone': '+261340000023'},
    {'id': 'cli_4', 'name': 'Tanjona Rabe', 'phone': '+261340000034'},
  ];

  Future<MockResponse> _users(MockRequest req, Map<String, String> _) async {
    final role = req.query['role'];
    final q = (req.query['q'] ?? '').toLowerCase();

    final items = <Map<String, dynamic>>[];
    if (role != 'driver') {
      for (final c in _seedClients) {
        items.add({
          'id': c['id'],
          'displayName': c['name'],
          'phone': c['phone'],
          'role': 'client',
          'kycStatus': null,
          'rating': null,
          'suspended': _suspendedUsers.contains(c['id']),
        });
      }
    }
    if (role != 'client') {
      for (final d in _fleet.values) {
        items.add({
          'id': d['id'],
          'displayName': d['displayName'],
          'phone': '+261330000000',
          'role': 'driver',
          'kycStatus': 'approved',
          'rating': d['rating'],
          'suspended':
              d['status'] == FleetStatus.suspended.wireName ||
              _suspendedUsers.contains(d['id']),
        });
      }
    }

    final filtered = q.isEmpty
        ? items
        : items
              .where(
                (u) =>
                    '${u['displayName']}'.toLowerCase().contains(q) ||
                    '${u['phone']}'.toLowerCase().contains(q),
              )
              .toList();
    return MockResponse.ok({'items': filtered});
  }

  Future<MockResponse> _userSuspension(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final id = params['id']!;
    final reason = '${req.json['reason'] ?? ''}';
    if (!ModerationAction.isReasonAcceptable(reason)) {
      return MockResponse.error(422, 'reason_required', 'Motif obligatoire');
    }
    if (req.json['suspend'] == true) {
      _suspendedUsers.add(id);
      // Un livreur suspendu passe hors ligne dans la flotte simulee.
      final driver = _fleet[id];
      if (driver != null) {
        driver['status'] = FleetStatus.suspended.wireName;
      }
    } else {
      _suspendedUsers.remove(id);
      final driver = _fleet[id];
      if (driver != null &&
          driver['status'] == FleetStatus.suspended.wireName) {
        driver['status'] = FleetStatus.offline.wireName;
      }
    }
    return MockResponse.ok({
      'id': id,
      'suspended': _suspendedUsers.contains(id),
    });
  }

  /// Fils de suivi de dossier KYC, par livreur (cote exploitation).
  final Map<String, List<Map<String, dynamic>>> _kycThreads = {};
  int _kycThreadSeq = 0;

  Future<MockResponse> _kycThreadList(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final thread = _kycThreads[params['id']] ?? const [];
    return MockResponse.ok({'items': List<Map<String, dynamic>>.from(thread)});
  }

  Future<MockResponse> _kycThreadReply(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final body = '${req.json['body'] ?? ''}'.trim();
    if (body.isEmpty) {
      return MockResponse.error(422, 'empty_message', 'Message vide');
    }
    final message = {
      'id': 'kmsg_${++_kycThreadSeq}',
      'fromAdmin': true,
      'body': body,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    };
    (_kycThreads[params['id']!] ??= []).add(message);
    return MockResponse.ok(message);
  }

  /// Ouverture d'un litige par une partie (client ou livreur), cote §13.
  ///
  /// Le simulateur ne verifie pas l'appartenance a la course — il n'a pas de
  /// notion de session — mais reproduit la forme et l'etat initial du serveur.
  Future<MockResponse> _disputeOpen(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final deliveryId = '${req.json['deliveryId'] ?? ''}'.trim();
    final reason = '${req.json['reason'] ?? ''}'.trim();
    if (deliveryId.isEmpty) {
      return MockResponse.error(404, 'not_found', 'Course inconnue');
    }
    if (reason.isEmpty) {
      return MockResponse.error(422, 'reason_required', 'Motif obligatoire');
    }

    final id = 'dsp_${++_sequence}_${DateTime.now().millisecondsSinceEpoch}';
    final dispute = <String, dynamic>{
      'id': id,
      'deliveryId': deliveryId,
      'status': DisputeStatus.open.wireName,
      'openedAt': DateTime.now().toUtc().toIso8601String(),
      'reason': reason,
      'openedBy': 'client',
      'messages': <Map<String, dynamic>>[],
      'decision': null,
    };
    _disputes[id] = dispute;
    return MockResponse.created(dispute);
  }

  Future<MockResponse> _disputeList(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final wanted = req.query['status'];
    final items =
        _disputes.values
            .where((d) => wanted == null || d['status'] == wanted)
            .toList()
          ..sort((a, b) => '${b['openedAt']}'.compareTo('${a['openedAt']}'));
    return MockResponse.ok({'items': items});
  }

  Future<MockResponse> _disputeRead(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final dispute = _disputes[params['id']];
    if (dispute == null) {
      return MockResponse.error(404, 'not_found', 'Litige inconnu');
    }
    return MockResponse.ok(dispute);
  }

  Future<MockResponse> _disputeMessage(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final dispute = _disputes[params['id']];
    if (dispute == null) {
      return MockResponse.error(404, 'not_found', 'Litige inconnu');
    }

    if (DisputeStatus.fromWire(dispute['status'] as String?).isClosed) {
      return MockResponse.error(
        409,
        'dispute_closed',
        'Litige clos',
        details: {'currentState': '${dispute['status']}'},
      );
    }

    final body = '${req.json['body'] ?? ''}'.trim();
    if (body.isEmpty) {
      return MockResponse.error(422, 'empty_message', 'Message vide');
    }

    // Le serveur reel derive l'auteur du role authentifie ; le simulateur, qui
    // n'a pas de session, se fie a un indice du corps (`author`), sans quoi tout
    // message paraitrait venir de l'exploitation.
    final fromOps = '${req.json['author'] ?? 'ops'}' == 'ops';
    (dispute['messages'] as List<dynamic>).add({
      'id': 'msg_${++_sequence}',
      'authorLabel': fromOps ? 'Exploitation' : 'Client',
      'body': body,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'fromOperations': fromOps,
    });

    // Le premier echange fait passer le litige en instruction : l'etat suit ce
    // qui se passe, il n'attend pas qu'on pense a le changer.
    if (dispute['status'] == DisputeStatus.open.wireName) {
      dispute['status'] = DisputeStatus.investigating.wireName;
    }

    return MockResponse.ok(dispute);
  }

  Future<MockResponse> _disputeDecision(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final dispute = _disputes[params['id']];
    if (dispute == null) {
      return MockResponse.error(404, 'not_found', 'Litige inconnu');
    }

    if (DisputeStatus.fromWire(dispute['status'] as String?).isClosed) {
      return MockResponse.error(
        409,
        'already_decided',
        'Litige deja tranche',
        details: {'currentState': '${dispute['status']}'},
      );
    }

    final resolve = req.json['resolve'] == true;
    final reason = '${req.json['reason'] ?? ''}';

    if (!ModerationAction.isReasonAcceptable(reason)) {
      return MockResponse.error(422, 'reason_required', 'Motif obligatoire');
    }

    dispute['status'] = resolve
        ? DisputeStatus.resolved.wireName
        : DisputeStatus.rejected.wireName;
    dispute['decision'] = {
      'action': resolve
          ? ModerationAction.resolveDispute.wireName
          : ModerationAction.rejectDispute.wireName,
      'reason': reason.trim(),
      'decidedAt': DateTime.now().toUtc().toIso8601String(),
      'decidedBy': 'ops_1',
    };

    return MockResponse.ok(dispute);
  }

  // --- Jeux d'essai -----------------------------------------------------

  Map<String, Map<String, dynamic>> _seedFleet() {
    const names = [
      ('drv_1', 'Rakoto Andrianina', '1234 TBA', FleetStatus.busy),
      ('drv_2', 'Hery Rasoanaivo', '5678 TBB', FleetStatus.available),
      ('drv_3', 'Naina Ratsimba', '9012 TBC', FleetStatus.available),
      ('drv_4', 'Fanja Randria', '3456 TBD', FleetStatus.offline),
      ('drv_5', 'Tiana Rakotomalala', '7890 TBE', FleetStatus.suspended),
    ];

    final now = DateTime.now();
    return {
      for (final (id, name, plate, status) in names)
        id: {
          'id': id,
          'displayName': name,
          'plate': plate,
          'status': status.wireName,
          'rating': 4.2 + _random.nextDouble() * 0.7,
          'position': status == FleetStatus.offline
              ? null
              : {
                  'lat': -18.90 + (_random.nextDouble() - 0.5) * 0.08,
                  'lng': 47.52 + (_random.nextDouble() - 0.5) * 0.08,
                },
          'lastSeenAt': status == FleetStatus.offline
              ? null
              : now
                    .subtract(Duration(minutes: _random.nextInt(14)))
                    .toUtc()
                    .toIso8601String(),
          // Un livreur « occupe » porte la course qui l'occupe : sans cela le
          // jeu d'essai se contredirait lui-meme, et la regle qui interdit de
          // suspendre un livreur en course ne serait jamais exercee.
          'currentDeliveryId': status == FleetStatus.busy ? 'dlv_1' : null,
          'suspensionReason': status == FleetStatus.suspended
              ? 'Trois colis remis sans constat de remise complet'
              : null,
        },
    };
  }

  Map<String, Map<String, dynamic>> _seedKyc() {
    const documents = [
      'cin_front',
      'cin_back',
      'licence',
      'selfie',
      'registration',
      'vehicle',
      'plate',
    ];

    final now = DateTime.now();
    // Un dossier complet, un incomplet : la file doit montrer les deux, parce
    // que la decision n'est pas la meme.
    return {
      'drv_6': {
        'driverId': 'drv_6',
        'displayName': 'Miora Andrianasolo',
        'status': 'submitted',
        'submittedAt': now
            .subtract(const Duration(hours: 30))
            .toUtc()
            .toIso8601String(),
        'documents': [
          for (final code in documents)
            {
              'code': code,
              'provided': true,
              'uploadId': 'up_$code',
              'url': '/accounts/drv_6/kyc/$code',
            },
        ],
        'rejectionReason': null,
      },
      'drv_7': {
        'driverId': 'drv_7',
        'displayName': 'Toky Rabemananjara',
        'status': 'submitted',
        'submittedAt': now
            .subtract(const Duration(hours: 5))
            .toUtc()
            .toIso8601String(),
        'documents': [
          for (final code in documents)
            {
              'code': code,
              'provided': code != 'registration' && code != 'vehicle',
              'uploadId': null,
              'url': (code != 'registration' && code != 'vehicle')
                  ? '/accounts/drv_7/kyc/$code'
                  : null,
            },
        ],
        'rejectionReason': null,
      },
    };
  }

  Map<String, Map<String, dynamic>> _seedDisputes() {
    final now = DateTime.now();
    return {
      'dsp_1': {
        'id': 'dsp_1',
        'deliveryId': 'dlv_1',
        'status': DisputeStatus.open.wireName,
        'openedAt': now
            .subtract(const Duration(hours: 6))
            .toUtc()
            .toIso8601String(),
        // Un litige ne dit jamais « probleme » : il reprend le motif du constat,
        // mot pour mot, parce que c'est ce motif qui sera relu en cas de
        // contestation.
        'reason': 'Coin du carton enfonce a l ouverture',
        'openedBy': 'client',
        'messages': <Map<String, dynamic>>[],
        'decision': null,
      },
    };
  }
}
