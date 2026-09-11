import 'package:majichrono/core/network/mock/mock_backend.dart';

/// Routes simulees de la notation (EXI-C40).
///
/// Le simulateur garde une note par course : renvoyer une note remplace la
/// precedente, comme le fait le serveur. De quoi eprouver le parcours — noter,
/// puis retrouver la note deja donnee — sans backend.
class ReviewsMockModule extends MockModule {
  final Map<String, Map<String, dynamic>> _byDelivery = {};

  @override
  void register(MockBackend backend) {
    backend.post('/reviews', _submit);
    backend.get('/reviews/delivery/{id}', _read);
  }

  @override
  Future<void> reset() async => _byDelivery.clear();

  Future<MockResponse> _submit(MockRequest req, Map<String, String> _) async {
    final deliveryId = '${req.json['deliveryId'] ?? ''}';
    final stars = (req.json['stars'] as num?)?.toInt() ?? 0;
    if (deliveryId.isEmpty || stars < 1 || stars > 5) {
      return MockResponse.error(422, 'invalid_review', 'Note invalide');
    }
    final review = {
      'deliveryId': deliveryId,
      'stars': stars,
      'punctuality': (req.json['punctuality'] as num?)?.toInt(),
      'service': (req.json['service'] as num?)?.toInt(),
      'comment': req.json['comment'],
    };
    _byDelivery[deliveryId] = review;
    return MockResponse.created(review);
  }

  Future<MockResponse> _read(MockRequest req, Map<String, String> params) async {
    final review = _byDelivery[params['id']];
    if (review == null) {
      return MockResponse.error(404, 'not_found', 'Aucun avis');
    }
    return MockResponse.ok(review);
  }
}
