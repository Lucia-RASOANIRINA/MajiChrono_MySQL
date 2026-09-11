import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:majichrono/shared/widgets/mc_loader.dart';
import 'package:majichrono/app/theme/app_colors.dart';
import 'package:majichrono/app/theme/design_tokens.dart';
import 'package:majichrono/features/custody/domain/entities/custody_report.dart';
import 'package:majichrono/l10n/app_localizations.dart';

/// Prise de vue guidee par gabarit (EXI-CC10, EXI-CC11).
///
/// Deux exigences se rejoignent ici.
///
/// **Le gabarit** : les quatre angles doivent etre cadres de la meme facon a la
/// prise en charge et a la remise, sans quoi le vis-a-vis du comparateur ne
/// comparerait rien. Le cadre affiche en surimpression n'est donc pas un
/// ornement, c'est ce qui rend les deux photos superposables.
///
/// **L'import galerie est impossible** : l'appareil est ouvert dans
/// l'application, et rien ne permet de choisir un fichier existant. C'est une
/// mesure anti-fraude — une photo importee pourrait dater d'hier, ou montrer un
/// autre colis. Elle a un cout d'ergonomie assume : si l'appareil photo est
/// indisponible, le constat ne peut pas se faire, et l'ecran le dit.
class GuidedCameraScreen extends StatefulWidget {
  const GuidedCameraScreen({required this.angle, super.key});

  final PhotoAngle angle;

  @override
  State<GuidedCameraScreen> createState() => _GuidedCameraScreenState();
}

class _GuidedCameraScreenState extends State<GuidedCameraScreen> {
  CameraController? _controller;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'no_camera');
        return;
      }
      final controller = CameraController(
        cameras.first,
        // Resolution moyenne : la photo sera de toute facon ramenee a 1280 px
        // (EXI-CC41). Capturer en pleine resolution ne ferait qu'allonger le
        // temps de traitement sur un appareil a 2 Go de RAM (§4.4).
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } on CameraException {
      if (mounted) setState(() => _error = 'camera_error');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _busy) return;

    setState(() => _busy = true);
    try {
      final shot = await controller.takePicture();
      final bytes = await File(shot.path).readAsBytes();
      if (!mounted) return;
      Navigator.of(context).pop(bytes);
    } on CameraException {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final label = switch (widget.angle) {
      PhotoAngle.top => l10n.custodyPhotoTop,
      PhotoAngle.bottom => l10n.custodyPhotoBottom,
      PhotoAngle.side1 => l10n.custodyPhotoSide1,
      PhotoAngle.side2 => l10n.custodyPhotoSide2,
    };

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(label),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  l10n.custodyPhotoInAppOnly,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            )
          : _controller == null
          ? const Center(child: McLoader())
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                // Gabarit d'angle : le cadre que l'utilisateur doit remplir.
                IgnorePointer(
                  child: CustomPaint(painter: const _TemplatePainter()),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.custodyPhotoGuide,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // Declencheur large et central : le livreur tient le
                          // colis d'une main (§15.2.2).
                          SizedBox(
                            height: AppSizes.driverActionHeight,
                            width: AppSizes.driverActionHeight,
                            child: FilledButton(
                              onPressed: _busy ? null : _capture,
                              style: FilledButton.styleFrom(
                                shape: const CircleBorder(),
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                              ),
                              child: const Icon(Icons.camera_alt, size: 28),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Cadre de cadrage affiche en surimpression.
class _TemplatePainter extends CustomPainter {
  const _TemplatePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.width * 0.82;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.42),
      width: side,
      height: side,
    );

    // Voile sombre hors du cadre : l'oeil va au cadre, pas au decor.
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = const Color(0x88000000));

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_TemplatePainter oldDelegate) => false;
}
