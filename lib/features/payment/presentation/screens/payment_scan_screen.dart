import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Lecture d'un code de paiement.
///
/// L'ecran ne fait qu'une chose : rendre un [ScannedPayment] valide. Il ne
/// contacte pas le serveur, ne debite rien, ne decide rien. C'est volontaire —
/// le scan est un geste d'appariement, et le confondre avec une autorisation
/// serait le defaut le plus grave que ce module puisse avoir.
///
/// Les codes etrangers sont ignores en silence plutot que rejetes bruyamment :
/// pendant qu'on cadre, la camera balaie des etiquettes de colis et des codes
/// Wi-Fi. Une alerte a chaque lecture non pertinente rendrait l'ecran
/// inutilisable.
class PaymentScanScreen extends StatefulWidget {
  const PaymentScanScreen({super.key});

  @override
  State<PaymentScanScreen> createState() => _PaymentScanScreenState();
}

class _PaymentScanScreenState extends State<PaymentScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    // Un seul code a la fois, et on s'arrete des qu'il est bon.
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handled = false;
  bool _sawForeignCode = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final scanned = PaymentQr.parse(barcode.rawValue);
      if (scanned == null) continue;

      _handled = true;
      Navigator.of(context).pop(scanned);
      return;
    }

    // Rien d'exploitable : on le dit une fois, discretement, pour que
    // l'utilisateur sache qu'il cadre le mauvais code plutot que de croire que
    // l'appareil ne voit rien.
    if (!_sawForeignCode && capture.barcodes.isNotEmpty && mounted) {
      setState(() => _sawForeignCode = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.payScan)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(
              message: switch (error.errorCode) {
                MobileScannerErrorCode.permissionDenied =>
                  l10n.payScanPermission,
                _ => l10n.errorUnknown,
              },
            ),
          ),

          // Gabarit de cadrage : sans repere, on approche trop pres et la mise
          // au point ne se fait jamais.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: AppRadii.componentAll,
                ),
              ),
            ),
          ),

          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.xl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Hint(text: l10n.payScanHelp, tone: Colors.black87),
                if (_sawForeignCode) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _Hint(text: l10n.payScanInvalid, tone: AppColors.warning),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: 0.85),
      borderRadius: AppRadii.componentAll,
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 15),
    ),
  );
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    ),
  );
}
