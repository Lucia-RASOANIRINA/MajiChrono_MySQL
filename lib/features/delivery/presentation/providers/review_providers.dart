import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/delivery/data/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => ReviewRepository(client: ref.watch(apiClientProvider)),
);

/// Avis deja laisse sur une course, ou `null` s'il n'y en a pas encore.
///
/// `autoDispose` : la reponse n'a de sens qu'a l'ouverture de l'ecran de suivi
/// d'une course precise. La garder entre deux visites n'apporterait rien.
final deliveryReviewProvider = FutureProvider.autoDispose
    .family<DeliveryReview?, String>(
      (ref, deliveryId) =>
          ref.watch(reviewRepositoryProvider).forDelivery(deliveryId),
    );
