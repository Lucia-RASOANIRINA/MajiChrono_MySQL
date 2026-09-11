import 'dart:async';

import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';

/// Marque MajiChrono animee, montree pendant la relecture de la session.
///
/// Le scooter arrive par la gauche, se pose, et son sillage file derriere lui.
/// C'est la meme marque que l'icone de lanceur et que l'indicateur de
/// chargement : trois endroits, un seul symbole, donc un symbole qui devient
/// familier au lieu de trois qu'on n'apprend jamais.
///
/// Le mouvement s'arrete apres un aller : un logo qui boucle indefiniment
/// donne l'impression d'une application bloquee, ce qui est exactement le
/// contraire du message.
class McBrandMark extends StatefulWidget {
  const McBrandMark({this.size = 132, this.animate = true, super.key});

  final double size;

  /// A faux, la marque est dessinee a son etat final, sans mouvement.
  ///
  /// C'est ce qui sert d'ecran d'attente : elle prend alors exactement la place
  /// et l'aspect de l'icone que le systeme affiche juste avant, de sorte que le
  /// passage de l'un a l'autre ne se voie pas. Animer ici ferait au contraire
  /// sursauter le logo au moment ou Flutter prend la main.
  final bool animate;

  @override
  State<McBrandMark> createState() => _McBrandMarkState();
}

class _McBrandMarkState extends State<McBrandMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Deux cent soixante millisecondes : le temps d'un battement, pas d'une
    // sequence. La marque doit **apparaitre**, pas se raconter — c'est l'ecran
    // de demarrage, et tout ce qui s'y attarde se compte en attente.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still =
        !widget.animate ||
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

    // La marque est dessinee **entiere** des la premiere image ; seule sa
    // presentation s'anime. Faire apparaitre le scooter piece par piece, comme
    // le faisait la version precedente, oblige a regarder jusqu'au bout pour
    // reconnaitre le logo — l'inverse de ce qu'on veut au demarrage.
    const mark = Icon(
      Icons.delivery_dining_rounded,
      size: 96,
      color: AppColors.primaryLight,
    );
    if (still) return SizedBox.square(dimension: widget.size, child: mark);

    return SizedBox.square(
      dimension: widget.size,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: ScaleTransition(
          // `easeOutBack` depasse legerement puis revient : c'est le petit
          // ressort qui donne l'impression que la marque **se pose**, plutot
          // qu'elle ne grossit. Le depassement est faible, sinon le logo
          // rebondit et attire l'attention qu'on veut lui eviter.
          scale: Tween<double>(begin: 0.86, end: 1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
          ),
          child: mark,
        ),
      ),
    );
  }
}

/// Silhouette de Madagascar, en petit repere.
///
/// Elle dit d'ou vient l'application sans une ligne de texte. Le contour est
/// volontairement **simplifie** : a vingt pixels de haut, un trace fidele au
/// littoral se referme en tache, et le pays ne se reconnaitrait plus. Ce qui
/// doit rester lisible, c'est la forme generale — allongee nord-sud, epaulee au
/// nord-ouest, effilee au sud.
class MadagascarMark extends StatelessWidget {
  const MadagascarMark({this.height = 30, this.color, super.key});

  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    // Rapport largeur/hauteur du pays : environ 1 pour 1,8. Le respecter est ce
    // qui distingue une silhouette d'une tache allongee.
    width: height * 0.56,
    child: CustomPaint(
      painter: _MadagascarPainter(
        color: color ?? Colors.white.withValues(alpha: 0.85),
      ),
    ),
  );
}

class _MadagascarPainter extends CustomPainter {
  const _MadagascarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Contour normalise, releve sur la silhouette du pays puis reduit a une
    // vingtaine de points. Coordonnees de 0 a 1 dans les deux sens, cote ouest
    // d'abord en descendant du nord, puis remontee par la cote est.
    //
    // Des segments droits, et non des courbes : a cette taille, une bezier mal
    // placee arrondit un cap et le pays devient une patate. Vingt points
    // suffisent a garder ce qui identifie Madagascar — la pointe nord decalee a
    // l'est, le renflement au tiers superieur, et l'effilement du sud.
    const outline = <Offset>[
      Offset(0.60, 0.00), // cap d'Ambre
      Offset(0.44, 0.05),
      Offset(0.36, 0.13),
      Offset(0.26, 0.21),
      Offset(0.17, 0.32),
      Offset(0.10, 0.45),
      Offset(0.06, 0.57),
      Offset(0.09, 0.70),
      Offset(0.17, 0.82),
      Offset(0.28, 0.92),
      Offset(0.37, 1.00), // cap Sainte-Marie
      Offset(0.48, 0.95),
      Offset(0.57, 0.85),
      Offset(0.67, 0.71),
      Offset(0.76, 0.57),
      Offset(0.85, 0.42),
      Offset(0.90, 0.30),
      Offset(0.86, 0.18),
      Offset(0.75, 0.08),
    ];

    final path = Path()..moveTo(w * outline.first.dx, h * outline.first.dy);
    for (final point in outline.skip(1)) {
      path.lineTo(w * point.dx, h * point.dy);
    }
    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MadagascarPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Bande de defilement : un scooter qui traverse l'ecran, en boucle.
///
/// Elle occupe le bas de l'accueil, qui restait vide sous le schema. Ce vide
/// n'etait pas neutre : il faisait paraitre l'ecran inacheve, et l'oeil y
/// cherchait quelque chose. Un mouvement horizontal lent l'occupe sans
/// concurrencer la ronde du dessus — celle-ci tourne, celle-ci file, les deux
/// ne se disputent pas l'attention.
class McScooterStrip extends StatefulWidget {
  const McScooterStrip({this.height = 56, super.key});

  final double height;

  @override
  State<McScooterStrip> createState() => _McScooterStripState();
}

class _McScooterStripState extends State<McScooterStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _start;

  @override
  void initState() {
    super.initState();
    // Le scooter est d'abord pose au tiers du parcours, immobile, puis part.
    // Meme raison que la ronde : la page se lit avant de bouger.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..value = 0.33;
    _start = Timer(const Duration(milliseconds: 600), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ScooterStripPainter(
            progress: still ? 0.5 : _controller.value,
          ),
        ),
      ),
    );
  }
}

class _ScooterStripPainter extends CustomPainter {
  const _ScooterStripPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final roadY = h * 0.78;

    // La route : un trait pointille, plus dense au centre. Il donne au scooter
    // un sol, sans quoi il flotte.
    const dash = 16.0;
    for (var x = 0.0; x < size.width; x += dash * 2) {
      final middle = 1 - (x / size.width - 0.5).abs() * 2;
      canvas.drawLine(
        Offset(x, roadY),
        Offset(x + dash, roadY),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.06 + middle * 0.16),
      );
    }

    // Le scooter traverse de gauche a droite, puis reapparait a gauche. Il sort
    // franchement du cadre aux deux bouts : une reapparition au bord se lirait
    // comme un saut.
    final span = size.width + h * 2.4;
    final x = -h * 1.2 + span * progress;

    canvas.save();
    canvas.translate(x, 0);

    final unit = h * 0.62;
    final stroke = unit * 0.10;
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.92);

    final wheelR = unit * 0.20;
    final wheelY = roadY - wheelR;
    final rearX = unit * 0.22;
    final frontX = unit * 0.86;

    for (final wx in [rearX, frontX]) {
      canvas.drawCircle(Offset(wx, wheelY), wheelR, mark);
    }
    canvas.drawLine(Offset(rearX, wheelY), Offset(frontX, wheelY), mark);
    canvas.drawLine(
      Offset(frontX, wheelY),
      Offset(frontX, wheelY - unit * 0.42),
      mark,
    );
    canvas.drawLine(
      Offset(frontX - unit * 0.16, wheelY - unit * 0.42),
      Offset(frontX + unit * 0.10, wheelY - unit * 0.42),
      mark,
    );
    // Le colis a l'arriere : c'est lui qui fait lire « livraison ».
    final boxSide = unit * 0.30;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rearX - boxSide * 0.4,
          wheelY - wheelR - boxSide - unit * 0.04,
          boxSide,
          boxSide,
        ),
        Radius.circular(unit * 0.04),
      ),
      mark,
    );

    // Sillage, derriere lui.
    for (var i = 0; i < 3; i++) {
      final y = wheelY - unit * (0.18 + i * 0.22);
      canvas.drawLine(
        Offset(-unit * (0.35 + i * 0.18), y),
        Offset(-unit * 0.06, y),
        Paint()
          ..strokeWidth = stroke * 0.9
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primaryLight.withValues(alpha: 0.75 - i * 0.18),
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScooterStripPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
