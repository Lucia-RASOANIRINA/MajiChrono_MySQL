import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/custody/data/services/photo_pipeline.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/features/custody/presentation/screens/guided_camera_screen.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/features/delivery/domain/entities/price_estimate.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Liste de courses et ticket de caisse, cote livreur (EXI-C07, D5).
///
/// Le livreur avance **son propre argent**. La carte lui rappelle donc en
/// permanence son plafond, et le ticket de caisse est la piece qui justifie son
/// remboursement — sans elle, il n'a que sa parole.
///
/// La photo passe par le pipeline du module 5 : 1280 px, 200 Ko, empreinte
/// SHA-256. Une seconde chaine photo aurait diverge de la premiere au premier
/// ajustement.
class ShoppingReceiptCard extends ConsumerStatefulWidget {
  const ShoppingReceiptCard({required this.delivery, super.key});

  final Delivery delivery;

  @override
  ConsumerState<ShoppingReceiptCard> createState() =>
      _ShoppingReceiptCardState();
}

class _ShoppingReceiptCardState extends ConsumerState<ShoppingReceiptCard> {
  final TextEditingController _actual = TextEditingController();
  CustodyPhoto? _receipt;

  @override
  void dispose() {
    _actual.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final bytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => const GuidedCameraScreen(angle: PhotoAngle.top),
      ),
    );
    if (bytes == null || !mounted) return;

    final root = await getApplicationSupportDirectory();
    final directory = Directory(
      p.join(root.path, 'shopping', widget.delivery.id),
    );

    final photo = await const PhotoPipeline().process(
      raw: bytes,
      angle: PhotoAngle.top,
      directory: directory,
      fileName: 'receipt',
      takenAt: DateTime.now(),
      point: widget.delivery.dropoff.point,
    );

    if (mounted) setState(() => _receipt = photo);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final shopping = widget.delivery.shopping;
    if (shopping == null) return const SizedBox.shrink();

    final actual = int.tryParse(_actual.text.replaceAll(' ', ''));
    final withReceipt = shopping.copyWith(actualTotalAriary: actual);
    final file = _receipt == null ? null : File(_receipt!.localPath);

    return Card(
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.shoppingTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),

            // Ce qu'il faut acheter.
            for (final item in shopping.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      item.substitutable
                          ? Icons.swap_horiz
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text('${item.quantity} × ${item.label}')),
                    if (item.estimatedUnitAriary != null)
                      Text(formatAriary(item.estimatedTotalAriary)),
                  ],
                ),
              ),

            const Divider(),
            // Le plafond est rappele en permanence, et en rouge : c'est la
            // seule protection du livreur, il ne doit jamais avoir a le
            // chercher.
            Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 18,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.shoppingCap,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                Text(
                  formatAriary(shopping.capAriary),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (shopping.storeHint != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                shopping.storeHint!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _actual,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.shoppingActualTotal,
                suffixText: 'Ar',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),

            // Un depassement de plafond ne se corrige pas tout seul : il est
            // annonce, avec le montant reellement remboursable, pour que le
            // livreur sache tout de suite ce qu'il recuperera.
            if (withReceipt.exceedsCap) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_outlined,
                    size: 18,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.shoppingOverCap(
                        formatAriary(withReceipt.reimbursableAriary),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            // Le ticket : la piece qui justifie le remboursement.
            InkWell(
              onTap: _capture,
              borderRadius: AppRadii.componentAll,
              child: Container(
                padding: AppSpacing.card,
                decoration: BoxDecoration(
                  borderRadius: AppRadii.componentAll,
                  border: Border.all(
                    color: _receipt == null
                        ? AppColors.danger
                        : AppColors.success,
                    width: _receipt == null ? 1 : 2,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: file != null && file.existsSync()
                          ? ClipRRect(
                              borderRadius: AppRadii.componentAll,
                              child: Image.file(file, fit: BoxFit.cover),
                            )
                          : Icon(
                              Icons.receipt_long_outlined,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.shoppingReceipt,
                            style: theme.textTheme.bodyLarge,
                          ),
                          Text(
                            _receipt == null
                                ? l10n.shoppingReceiptMissing
                                : l10n.shoppingReceiptTaken,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _receipt == null
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_receipt != null)
                      const Icon(Icons.check_circle, color: AppColors.success),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
