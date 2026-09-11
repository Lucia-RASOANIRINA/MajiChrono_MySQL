import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery_options.dart';

/// Criteres de recherche d'un relais.
///
/// Un enregistrement plutot qu'un simple quartier : la position du point de
/// remise, quand on la connait, permet au serveur de trier du plus proche au
/// plus loin et de renvoyer une distance. L'egalite de valeur des records fait
/// que deux recherches identiques partagent le meme cache.
typedef RelayQuery = ({String? district, double? lat, double? lng});

/// Reseau de points relais partenaires (differenciant D6, §7).
///
/// Servi par quartier lorsqu'on en connait un, et trie par proximite quand la
/// position du point de remise est fournie : proposer les relais de toute
/// l'agglomeration a quelqu'un qui livre a Ambohipo lui ferait faire defiler une
/// liste dont dix-neuf entrees sur vingt sont hors sujet.
final relayPointsProvider = FutureProvider.autoDispose
    .family<List<RelayPoint>, RelayQuery>((ref, query) async {
      final json = await ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>>(
            ApiEndpoints.relayPoints,
            query: {
              'district': ?query.district,
              if (query.lat != null) 'lat': '${query.lat}',
              if (query.lng != null) 'lng': '${query.lng}',
            },
          );

      return (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(RelayPoint.fromJson)
          .whereType<RelayPoint>()
          .toList();
    });
