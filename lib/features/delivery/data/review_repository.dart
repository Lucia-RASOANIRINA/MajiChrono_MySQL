import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/data_meter.dart';

/// Note deja laissee sur une course, telle que le serveur la rend.
class DeliveryReview {
  const DeliveryReview({
    required this.stars,
    this.punctuality,
    this.service,
    this.comment,
  });

  final int stars;
  final int? punctuality;
  final int? service;
  final String? comment;

  static DeliveryReview? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final stars = (json['stars'] as num?)?.toInt();
    if (stars == null) return null;
    return DeliveryReview(
      stars: stars,
      punctuality: (json['punctuality'] as num?)?.toInt(),
      service: (json['service'] as num?)?.toInt(),
      comment: json['comment'] as String?,
    );
  }
}

/// Evaluation d'une course, de l'expediteur vers le livreur (EXI-C40).
///
/// La note se corrige : renvoyer une note sur une course deja notee remplace la
/// precedente, cote serveur, plutot que d'en empiler une seconde. Le mobile n'a
/// donc rien de particulier a faire pour « modifier » un avis.
class ReviewRepository {
  ReviewRepository({required this._client});

  final ApiClient _client;

  Future<DeliveryReview> submit({
    required String deliveryId,
    required int stars,
    int? punctuality,
    int? service,
    String? comment,
  }) async {
    final body = <String, dynamic>{'deliveryId': deliveryId, 'stars': stars};
    if (punctuality != null) body['punctuality'] = punctuality;
    if (service != null) body['service'] = service;
    final trimmed = comment?.trim();
    if (trimmed != null && trimmed.isNotEmpty) body['comment'] = trimmed;

    final json = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.reviews,
      body: body,
      category: DataCategory.api,
    );
    return DeliveryReview.fromJson(json) ?? DeliveryReview(stars: stars);
  }

  /// L'avis deja donne, ou `null` si la course n'a pas encore ete notee.
  Future<DeliveryReview?> forDelivery(String deliveryId) async {
    try {
      final json = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.reviewForDelivery(deliveryId),
        category: DataCategory.api,
      );
      return DeliveryReview.fromJson(json);
    } on Object {
      // 404 : pas encore note. On ne distingue pas cette absence attendue d'une
      // panne — dans les deux cas, l'ecran proposera simplement de noter.
      return null;
    }
  }
}
