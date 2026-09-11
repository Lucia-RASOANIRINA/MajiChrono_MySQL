import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Lecture du numero de scelle (EXI-CC14).
///
/// Un scelle porte un code-barres lineaire, pas un QR : c'est une etiquette
/// industrielle, imprimee par lots. Le scanneur accepte donc les formats
/// lineaires courants **et** le QR, parce que rien ne garantit que le
/// fournisseur ne changera pas d'etiquette entre deux commandes.
///
/// Le code lu est **rendu, jamais applique directement**. Le livreur le voit
/// arriver dans le champ et peut le corriger : une etiquette sale se lit
/// parfois de travers, et un numero de scelle faux vaut moins qu'un numero
/// saisi a la main.
class SealScanScreen extends StatefulWidget {
  const SealScanScreen({super.key});

  @override
  State<SealScanScreen> createState() => _SealScanScreenState();
}

class _SealScanScreenState extends State<SealScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.qrCode,
    ],
  );

  bool _handled = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;

      _handled = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.custodySealScan)),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? l10n.payScanPermission
                        : l10n.errorUnknown,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ),
          ),

          // Gabarit large et bas : un code-barres lineaire se cadre en largeur,
          // pas dans un carre.
          IgnorePointer(
            child: Center(
              child: Container(
                width: 280,
                height: 120,
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
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.90),
                borderRadius: AppRadii.componentAll,
              ),
              child: Text(
                l10n.custodySealScanHelp,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
