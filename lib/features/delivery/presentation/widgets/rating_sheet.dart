import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/features/delivery/presentation/providers/review_providers.dart';
import 'package:majichrono/l10n/app_localizations.dart';
import 'package:majichrono/shared/l10n/failure_messages.dart';

/// Ouvre la feuille de notation d'une course remise (EXI-C40).
Future<void> showRatingSheet(
  BuildContext context, {
  required String deliveryId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RatingSheet(deliveryId: deliveryId),
  );
}

class _RatingSheet extends ConsumerStatefulWidget {
  const _RatingSheet({required this.deliveryId});

  final String deliveryId;

  @override
  ConsumerState<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends ConsumerState<_RatingSheet> {
  int _stars = 0;
  int _punctuality = 0;
  int _service = 0;
  final _comment = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(reviewRepositoryProvider)
          .submit(
            deliveryId: widget.deliveryId,
            stars: _stars,
            punctuality: _punctuality == 0 ? null : _punctuality,
            service: _service == 0 ? null : _service,
            comment: _comment.text.trim(),
          );
      if (!mounted) return;
      ref.invalidate(deliveryReviewProvider(widget.deliveryId));
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.rateThanks)));
    } on Failure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.localizedMessage(l10n);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.errorNetwork;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.rateTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.lg),

          // La note globale, en grand : c'est la seule obligatoire.
          Center(
            child: _StarRow(
              value: _stars,
              size: 40,
              onChanged: (v) => setState(() {
                _stars = v;
                _error = null;
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _AxisRow(
            label: l10n.ratePunctuality,
            value: _punctuality,
            onChanged: (v) => setState(() => _punctuality = v),
          ),
          const SizedBox(height: AppSpacing.md),
          _AxisRow(
            label: l10n.rateService,
            value: _service,
            onChanged: (v) => setState(() => _service = v),
          ),
          const SizedBox(height: AppSpacing.lg),

          TextField(
            controller: _comment,
            enabled: !_busy,
            maxLines: 3,
            maxLength: 400,
            decoration: InputDecoration(
              labelText: l10n.rateComment,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _stars == 0 || _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.rateSubmit),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un axe secondaire (ponctualite, service) : un libelle a gauche, ses etoiles
/// a droite. Facultatif — zero etoile veut dire « non renseigne ».
class _AxisRow extends StatelessWidget {
  const _AxisRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        _StarRow(value: value, size: 26, onChanged: onChanged),
      ],
    );
  }
}

/// Cinq etoiles tappables. Toucher une etoile deja seule la remet a zero, de
/// sorte qu'un axe facultatif reste effacable.
class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.value,
    required this.onChanged,
    this.size = 30,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final position = i + 1;
        final filled = position <= value;
        return IconButton(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          constraints: const BoxConstraints(),
          onPressed: () => onChanged(value == position ? 0 : position),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: filled ? AppColors.accent : Colors.grey,
          ),
        );
      }),
    );
  }
}
