import 'package:flutter/material.dart';
import 'package:majichrono/app/theme/design_tokens.dart';

/// Squelette de chargement (§15.2.7 : remplace l'indicateur circulaire).
///
/// Volontairement sans paquet externe (regle 9.3.6, budget de taille) : une
/// simple animation d'opacite suffit et coute zero octet d'APK.
class McSkeleton extends StatefulWidget {
  const McSkeleton({
    this.height = 16,
    this.width = double.infinity,
    this.radius = AppRadii.componentAll,
    super.key,
  });

  final double height;
  final double width;
  final BorderRadius radius;

  @override
  State<McSkeleton> createState() => _McSkeletonState();
}

class _McSkeletonState extends State<McSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    // Respect du reglage systeme de reduction des animations (§15.1).
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;

    if (reduceMotion) {
      return _box(base.withValues(alpha: 0.7));
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          _box(base.withValues(alpha: 0.45 + _controller.value * 0.35)),
    );
  }

  Widget _box(Color color) => Container(
    height: widget.height,
    width: widget.width,
    decoration: BoxDecoration(color: color, borderRadius: widget.radius),
  );
}

/// Squelette de liste, utilise partout ou une liste se charge.
///
/// [nested] est indispensable des que le squelette est place **a l'interieur**
/// d'une autre liste verticale. Sans lui, la liste interne recoit une hauteur
/// non bornee, sa mise en page echoue, et l'echec ne se manifeste pas par un
/// message : c'est **toute la liste parente qui cesse de peindre**. Le defaut
/// s'est produit sur l'ecran de suivi, ou il donnait un corps entierement vide,
/// sans exception journalisee et sans rien a l'ecran pour l'expliquer.
class McSkeletonList extends StatelessWidget {
  const McSkeletonList({this.itemCount = 5, this.nested = false, super.key});

  final int itemCount;

  /// Vrai lorsque ce squelette est imbrique dans une autre liste verticale.
  final bool nested;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      shrinkWrap: nested,
      physics: nested ? const NeverScrollableScrollPhysics() : null,
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (_, _) => const Card(
        child: Padding(
          padding: AppSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              McSkeleton(height: 18, width: 160),
              SizedBox(height: AppSpacing.sm),
              McSkeleton(height: 14),
              SizedBox(height: AppSpacing.xs),
              McSkeleton(height: 14, width: 220),
            ],
          ),
        ),
      ),
    );
  }
}
