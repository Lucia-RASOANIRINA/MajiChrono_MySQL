import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/providers/core_providers.dart';
import 'package:majichrono/features/delivery/domain/entities/delivery.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Octets de la photo d'un colis, telecharges **une seule fois**.
///
/// Les cartes du livreur se reconstruisent chaque seconde (compte a rebours
/// d'acceptation) : sans ce cache, la photo etait retelechargee a chaque
/// seconde — l'image clignotait et le forfait fondait. La photo reste en
/// memoire dix minutes apres le dernier ecran qui l'affiche.
final packagePhotoProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, mediaId) async {
      final bytes = await ref
          .watch(apiClientProvider)
          .getBytes(ApiEndpoints.mediaItem(mediaId));
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 10), link.close);
      ref.onDispose(timer.cancel);
      return Uint8List.fromList(bytes);
    });

/// Pictogramme et teinte d'une nature de colis, pour l'illustration de repli.
extension DeliveryKindVisuals on DeliveryKind {
  IconData get icon => switch (this) {
    DeliveryKind.standard => Icons.inventory_2_rounded,
    DeliveryKind.document => Icons.description_rounded,
    DeliveryKind.fragile => Icons.wine_bar_rounded,
    DeliveryKind.food => Icons.restaurant_rounded,
    DeliveryKind.shopping => Icons.shopping_basket_rounded,
  };

  List<Color> get gradient => switch (this) {
    DeliveryKind.standard => const [AppColors.primaryLight, AppColors.primary],
    DeliveryKind.document => const [Color(0xFF29B6F6), AppColors.info],
    DeliveryKind.fragile => const [Color(0xFFEF5350), AppColors.danger],
    DeliveryKind.food => const [Color(0xFF66BB6A), AppColors.success],
    DeliveryKind.shopping => const [AppColors.accent, AppColors.accentDark],
  };
}

/// Photo du colis, telle que le livreur la voit.
///
/// Elle fait reconnaitre le colis avant d'accepter et au moment du retrait.
/// Toucher la photo l'ouvre en plein ecran, zoomable. Sans photo — course
/// creee hors ligne, ancienne course —, une illustration teintee selon la
/// nature du colis prend sa place plutot qu'un carre gris : la carte reste
/// lisible d'un coup d'oeil.
class PackagePhoto extends ConsumerWidget {
  const PackagePhoto({
    required this.delivery,
    this.height = 180,
    this.width = double.infinity,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.compact = false,
    this.zoomable = true,
    super.key,
  });

  final Delivery delivery;
  final double height;
  final double width;
  final BorderRadius borderRadius;

  /// Vignette : pas de legende sous le pictogramme de repli.
  final bool compact;
  final bool zoomable;

  String? get _photoId {
    final id = delivery.package.photoId;
    return id == null || id.isEmpty ? null : id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = _photoId;
    final photo = id == null ? null : ref.watch(packagePhotoProvider(id));
    final bytes = photo?.valueOrNull;
    final heroTag = 'colis-${delivery.id}';

    final Widget content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: bytes != null
          ? Image.memory(
              bytes,
              key: const ValueKey('photo'),
              fit: BoxFit.cover,
              width: width,
              height: height,
              gaplessPlayback: true,
            )
          : _Illustration(
              key: const ValueKey('illustration'),
              kind: delivery.kind,
              loading: photo?.isLoading ?? false,
              compact: compact,
            ),
    );

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: bytes != null && zoomable
            ? GestureDetector(
                onTap: () => Navigator.of(context).push(
                  PageRouteBuilder<void>(
                    opaque: false,
                    barrierColor: Colors.black,
                    pageBuilder: (_, _, _) =>
                        _PhotoViewer(bytes: bytes, heroTag: heroTag),
                  ),
                ),
                child: Hero(tag: heroTag, child: content),
              )
            : content,
      ),
    );
  }
}

class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.kind,
    required this.loading,
    required this.compact,
    super.key,
  });

  final DeliveryKind kind;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: kind.gradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Grand pictogramme en filigrane : du relief sans image a charger.
          Positioned(
            right: -12,
            bottom: -16,
            child: Icon(
              kind.icon,
              size: compact ? 48 : 140,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Center(
            child: loading
                ? const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        kind.icon,
                        size: compact ? 26 : 44,
                        color: Colors.white,
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.pkgNoPhoto,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Photo en plein ecran, zoomable a deux doigts ; un toucher la referme.
class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.bytes, required this.heroTag});

  final Uint8List bytes;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  foregroundColor: Colors.white,
                ),
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
