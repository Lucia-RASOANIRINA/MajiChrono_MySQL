import 'package:flutter_test/flutter_test.dart';
import 'package:majichrono/core/logging/app_logger.dart';

/// EXI-T10 et EXI-MP11 : aucune donnee personnelle ni de paiement en clair dans
/// les journaux. C'est une exigence de priorite M, donc opposable a la recette :
/// elle merite un test, pas une relecture.
void main() {
  test('un numero malgache est masque, seuls deux chiffres subsistent', () {
    final redacted = AppLogger.redact('appel vers +261 34 12 345 67');
    expect(redacted.contains('34 12 345'), isFalse);
    expect(redacted.contains('***67'), isTrue);
  });

  test('un numero au format national est masque aussi', () {
    expect(AppLogger.redact('0341234567').contains('1234'), isFalse);
  });

  test('toute suite longue de chiffres est masquee (OTP, references)', () {
    expect(AppLogger.redact('otp 483920'), 'otp ******');
  });

  test('les cles sensibles d une map sont remplacees', () {
    final redacted = AppLogger.redactMap({
      'phone': '+261341234567',
      'otp': '483920',
      'accessToken': 'ey.abc',
      'balance': 250000,
      'latitude': -18.8792,
      'deliveryId': 'dlv_42',
    });

    expect(redacted['phone'], '***');
    expect(redacted['otp'], '***');
    expect(redacted['accessToken'], '***');
    expect(redacted['balance'], '***');
    expect(redacted['latitude'], '***');
    // Ce qui n'est pas personnel reste lisible, sinon le journal ne sert a rien.
    expect(redacted['deliveryId'], 'dlv_42');
  });

  test('les maps imbriquees sont expurgees en profondeur', () {
    final redacted = AppLogger.redactMap({
      'payment': {'msisdn': '+261320000000', 'amount': 12000, 'status': 'ok'},
    });
    final payment = redacted['payment']! as Map<String, Object?>;
    expect(payment['msisdn'], '***');
    expect(payment['amount'], '***');
    expect(payment['status'], 'ok');
  });

  test('le journal local est circulaire et exportable (EXI-P10)', () {
    final logger = AppLogger.instance..clear();
    logger.info('demarrage');
    expect(logger.exportBuffer().contains('demarrage'), isTrue);
    logger.clear();
    expect(logger.exportBuffer(), isEmpty);
  });
}
