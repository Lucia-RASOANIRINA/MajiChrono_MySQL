import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/security/device_integrity.dart';
import 'package:majichrono/core/security/secure_screen.dart';
import 'package:majichrono/features/payment/domain/entities/payment.dart';
import 'package:majichrono/features/payment/presentation/providers/payment_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';

/// Presentation du code de paiement.
///
/// C'est l'ecran qu'on **tend a l'autre personne**. Il est donc dessine pour
/// etre lu de biais, a bout de bras, souvent en plein soleil : code aussi grand
/// que possible, montant en gros au-dessus, et rien d'autre a l'ecran qui
/// puisse detourner l'attention.
///
/// La luminosite n'est pas forcee : le faire exigerait une dependance de plus
/// pour un gain incertain sur les appareils d'entree de gamme vises (§4.4).
class PaymentQrScreen extends ConsumerStatefulWidget {
  const PaymentQrScreen({
    required this.intent,
    required this.onRenew,
    super.key,
  });

  final PaymentIntent intent;

  /// Regenere une intention lorsque le code a expire.
  final Future<PaymentIntent?> Function() onRenew;

  @override
  ConsumerState<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends ConsumerState<PaymentQrScreen> {
  late PaymentIntent _intent = widget.intent;
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Un battement a la seconde suffit pour le compte a rebours ; le suivi de
    // l'etat, lui, passe par le sondage plafonne (EXI-MP05).
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _renew() async {
    setState(() => _busy = true);
    final renewed = await widget.onRenew();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (renewed != null) _intent = renewed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final now = DateTime.now();
    final expired = _intent.isExpiredAt(now);
    final remaining = _intent.expiresAt.difference(now);

    // Le suivi ferme l'ecran des que le paiement aboutit : la personne qui
    // presente le code n'a pas a surveiller elle-meme.
    ref.listen(paymentStatusProvider(_intent.id), (_, next) {
      final updated = next.valueOrNull;
      if (updated != null && updated.status.isFinal && mounted) {
        Navigator.of(context).pop(updated);
      }
    });

    return SecureScreen(
      surface: SecureSurface.payment,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.payTitle)),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.payAmount,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                formatAriary(_intent.amountAriary),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Expanded(
                child: Center(
                  child: expired
                      ? _Expired(busy: _busy, onRenew: _renew)
                      : DecoratedBox(
                          decoration: const BoxDecoration(color: Colors.white),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: QrImageView(
                              data: _intent.qrPayload,
                              version: QrVersions.auto,
                              size: 260,
                              // Correction elevee : un code tendu au-dessus d'un
                              // comptoir est vite sali ou partiellement masque par
                              // un pouce.
                              errorCorrectionLevel: QrErrorCorrectLevel.H,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),
              Text(
                _intent.direction.presentedByDriver
                    ? l10n.payCollectHelp
                    : l10n.payOfferHelp,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (!expired)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const McLoader.small(),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${l10n.payWaiting}  '
                      '${l10n.payQrExpires(remaining.inMinutes + 1)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Expired extends StatelessWidget {
  const _Expired({required this.busy, required this.onRenew});

  final bool busy;
  final VoidCallback onRenew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.timer_off_outlined,
          size: 48,
          color: AppColors.warning,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.payQrExpired, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: busy ? null : onRenew,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.payQrRenew),
        ),
      ],
    );
  }
}
