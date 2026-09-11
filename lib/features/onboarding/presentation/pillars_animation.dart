import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/app_colors.dart';

/// Un des quatre elements montres a l'accueil.
class Pillar {
  const Pillar({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;
}

/// Ronde des quatre elements de l'accueil, sur **deux mains**.
///
/// La maquette dispose quatre elements en losange — rapidite en haut a gauche,
/// livreur a droite, expediteur a gauche, confiance en bas a droite — relies par
/// un anneau, avec un trace de suivi au centre. Deux de ces quatre positions
/// sont des mains ouvertes : une main droite qui entre par le bord droit, une
/// main gauche qui entre par le bord gauche.
///
/// L'animation fait tourner les quatre elements **de la gauche vers la droite**
/// sur cet anneau. Comme les mains restent a leur place, chaque element vient a
/// son tour se poser dans l'une puis dans l'autre : c'est le mouvement demande,
/// et c'est aussi ce que raconte l'application — le colis passe de main en main.
///
/// Le mouvement est decoupe en tours plutot que continu. Une rotation
/// permanente ne laisse lire aucun des quatre mots : l'oeil suit le mouvement au
/// lieu de lire. Chaque element avance donc d'un quart de tour en un demi-
/// seconde, puis marque une seconde d'arret — assez pour lire le mot, trop court
/// pour donner l'impression d'attendre.
///
/// Aucun moteur 3D ni animation vectorielle importee : quatre widgets places sur
/// une ellipse et un [CustomPainter] pour le decor. Le budget de 25 Mo d'APK ne
/// supporterait pas une bibliotheque d'animation, et un ecran d'accueil n'est
/// pas l'endroit ou depenser cette marge.
class PillarsAnimation extends StatefulWidget {
  const PillarsAnimation({required this.pillars, super.key});

  final List<Pillar> pillars;

  @override
  State<PillarsAnimation> createState() => _PillarsAnimationState();
}

class _PillarsAnimationState extends State<PillarsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// Glissement d'un quart de tour ; le reste du cycle est la pose.
  static const Duration _travel = Duration(milliseconds: 680);
  static const Duration _cycle = Duration(milliseconds: 2150);

  /// Les quatre positions du losange, en degres sur l'ellipse (y vers le bas).
  /// Nord-ouest, nord-est, sud-est, sud-ouest — l'ordre de la rotation horaire.
  static const List<double> _slots = [225, 315, 45, 135];

  /// Positions occupees par une main : le nord-est et le sud-ouest, en
  /// diagonale l'une de l'autre comme sur la maquette.
  static const Set<int> _handSlots = {1, 3};

  /// Cote d'une vignette. Il doit contenir la pastille agrandie (66), l'ecart
  /// (24) et deux lignes de libelle (~30) : en dessous de 124, « Confiance
  /// MajiChrono » deborde de deux pixels.
  static const double _cardSide = 128;

  /// Delai avant que la ronde ne s'ebranle.
  ///
  /// L'ecran s'affiche d'abord **fixe** : les quatre elements a leur place, les
  /// arcs, le trace, les mains. Tout est lisible avant que quoi que ce soit ne
  /// bouge. Sans ce temps d'arret, le premier mouvement se superpose au premier
  /// rendu — la page arrive et part en meme temps, ce qui se lit comme un
  /// chargement laborieux alors que c'est l'inverse.
  static const Duration _settle = Duration(milliseconds: 600);

  Timer? _start;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle);
    _start = Timer(_settle, () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _start?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Avancement du tour en cours, adouci aux deux extremites pour donner
  /// l'inertie d'un objet qu'on pose.
  double get _advance {
    final fraction = _travel.inMilliseconds / _cycle.inMilliseconds;
    final t = _controller.value;
    if (t >= fraction) return 1;
    return Curves.easeInOutCubic.transform(t / fraction);
  }

  int get _step =>
      (_controller.lastElapsedDuration ?? Duration.zero).inMilliseconds ~/
      _cycle.inMilliseconds;

  @override
  Widget build(BuildContext context) {
    final count = widget.pillars.length;
    if (count == 0) return const SizedBox.shrink();

    // Quand le systeme demande la suppression des animations, la ronde s'arrete
    // au premier tour. Les quatre elements restent lisibles ; c'est le mouvement
    // qui disparait (EXI-T09).
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final side = math.min(
          constraints.maxWidth,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 340.0,
        );

        Widget frame(BuildContext context) {
          final progress = still ? 0.0 : _step + _advance;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: const _RingPainter()),
              ),
              for (final placed in _place(count, progress, side))
                Positioned(
                  left: placed.center.dx - _cardSide / 2,
                  top: placed.center.dy - _cardSide / 2,
                  child: _PillarCard(
                    pillar: widget.pillars[placed.index],
                    onHand: placed.onHand,
                  ),
                ),
            ],
          );
        }

        return SizedBox.square(
          dimension: side,
          child: still
              ? Builder(builder: frame)
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => frame(context),
                ),
        );
      },
    );
  }

  /// Position de chaque element pour un avancement donne.
  List<_Placed> _place(int count, double progress, double side) {
    final center = Offset(side / 2, side / 2);
    final rx = side * 0.385;
    final ry = side * 0.345;

    return [
      for (var i = 0; i < count; i++) _placeOne(i, progress, center, rx, ry),
    ];
  }

  _Placed _placeOne(
    int index,
    double progress,
    Offset center,
    double rx,
    double ry,
  ) {
    // L'element `index` occupe la position `index + progress`, en tournant dans
    // le sens horaire — de la gauche vers la droite, comme demande.
    final position = index + progress;
    final from = _slots[position.floor() % _slots.length];
    final to = _slots[(position.floor() + 1) % _slots.length];

    // On interpole toujours vers l'avant : sans ce redressement, le passage de
    // 315 a 45 degres ferait reculer l'element de trois quarts de tour.
    final sweep = (to - from + 360) % 360;
    final angle = (from + sweep * (position - position.floor())) * math.pi / 180;

    final slot = position.round() % _slots.length;
    // « Pose dans la main » ne vaut que pendant la pause, pas pendant le
    // glissement : une vignette a mi-chemin n'est dans aucune main.
    final settled = (position - position.round()).abs() < 0.08;

    return _Placed(
      index: index,
      center: center + Offset(rx * math.cos(angle), ry * math.sin(angle)),
      onHand: settled && _handSlots.contains(slot),
    );
  }
}

class _Placed {
  const _Placed({
    required this.index,
    required this.center,
    required this.onHand,
  });

  final int index;
  final Offset center;
  final bool onHand;
}

/// Vignette d'un element : icone dans une pastille claire, libelle dessous.
class _PillarCard extends StatelessWidget {
  const _PillarCard({required this.pillar, required this.onHand});

  final Pillar pillar;

  /// Vrai quand l'element repose dans une main : la pastille se detache alors
  /// legerement, pour qu'on voie qu'elle est portee et non simplement posee.
  final bool onHand;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _PillarsAnimationState._cardSide,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: onHand ? 66 : 58,
            height: onHand ? 66 : 58,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                // Ombre portee, qui detache la pastille du fond.
                BoxShadow(
                  color: Colors.black.withValues(alpha: onHand ? 0.32 : 0.16),
                  blurRadius: onHand ? 20 : 9,
                  offset: Offset(0, onHand ? 9 : 3),
                ),
                // Halo clair, uniquement sur l'element porte : il dit lequel des
                // quatre est en train d'etre remis, sans un mot de plus.
                if (onHand)
                  BoxShadow(
                    color: AppColors.primaryLight.withValues(alpha: 0.55),
                    blurRadius: 22,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Icon(pillar.icon, size: onHand ? 32 : 28, color: pillar.color),
          ),
          // L'ecart laisse passer la paume dessinee sous la pastille : sans lui,
          // la main barre le libelle.
          const SizedBox(height: 24),
          Text(
            pillar.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.15,
              fontWeight: FontWeight.w600,
              // Une ombre portee, parce que le libelle peut passer devant
              // l'anneau ou le trace : sans elle, deux traits blancs se
              // superposent et le mot devient illisible pendant le glissement.
              shadows: [
                Shadow(color: AppColors.primary, blurRadius: 6),
                Shadow(color: AppColors.primary, blurRadius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Decor fixe : l'anneau de liaison, le trace de suivi et les deux mains.
class _RingPainter extends CustomPainter {
  const _RingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final rx = side * 0.385;
    final ry = side * 0.345;

    // Quatre arcs plutot qu'un ovale continu.
    //
    // La maquette relie les elements par des traits qui **s'interrompent** a
    // leur approche : le lien se lit comme un chemin d'un element a l'autre, et
    // non comme un cerceau qui les enferme. Chaque arc s'affine aussi vers ses
    // extremites, ce qu'un trait d'epaisseur constante ne sait pas faire — d'ou
    // le decoupage en segments dont l'opacite suit une courbe.
    final ring = Rect.fromCenter(
      center: center,
      width: rx * 2,
      height: ry * 2,
    );
    const gap = 0.32; // radians laisses libres de part et d'autre d'un sommet.
    for (var quarter = 0; quarter < 4; quarter++) {
      final start = (45 + quarter * 90) * math.pi / 180 + gap;
      final sweep = math.pi / 2 - gap * 2;
      const segments = 14;

      for (var i = 0; i < segments; i++) {
        // Opacite en cloche : forte au milieu de l'arc, nulle aux extremites.
        final t = (i + 0.5) / segments;
        final fade = math.sin(t * math.pi);
        canvas.drawArc(
          ring,
          start + sweep * i / segments,
          sweep / segments + 0.004,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 + fade * 0.9
            ..color = Colors.white.withValues(alpha: 0.10 + fade * 0.34),
        );
      }
    }

    // Quatre points sur l'anneau, aux positions ou les elements se posent. Ils
    // rendent la ronde lisible a l'arret : sans eux, l'anneau est un trait
    // continu et rien ne dit ou les vignettes vont s'arreter.
    for (final degrees in [225.0, 315.0, 45.0, 135.0]) {
      final angle = degrees * math.pi / 180;
      canvas.drawCircle(
        center + Offset(rx * math.cos(angle), ry * math.sin(angle)),
        2.4,
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }

    _paintPulse(canvas, center, side);

    // Main droite au nord-est, main gauche au sud-ouest : les deux positions ou
    // les elements viennent se poser a tour de role.
    final ne = center + Offset(rx * math.cos(-math.pi / 4), ry * math.sin(-math.pi / 4));
    final sw = center + Offset(rx * math.cos(3 * math.pi / 4), ry * math.sin(3 * math.pi / 4));
    _paintHand(canvas, ne, side * 0.13, fromRight: true);
    _paintHand(canvas, sw, side * 0.13, fromRight: false);
  }

  /// Le trace de suivi qui traverse l'anneau sur la maquette. Il dit en une
  /// ligne ce que fait l'application : un colis suivi, battement par battement.
  void _paintPulse(Canvas canvas, Offset center, double side) {
    final w = side * 0.34;
    final h = side * 0.09;
    final path = Path()..moveTo(center.dx - w, center.dy);
    for (final point in [
      Offset(center.dx - w * 0.45, center.dy),
      Offset(center.dx - w * 0.26, center.dy - h),
      Offset(center.dx - w * 0.06, center.dy + h * 1.1),
      Offset(center.dx + w * 0.14, center.dy - h * 0.7),
      Offset(center.dx + w * 0.34, center.dy),
      Offset(center.dx + w, center.dy),
    ]) {
      path.lineTo(point.dx, point.dy);
    }

    // Deux passes : un halo large et transparent, puis le trait net par-dessus.
    // C'est ce qui donne au trace l'aspect lumineux de la maquette, sans image
    // ni effet couteux — un flou gaussien sur un ecran d'accueil se paierait a
    // chaque image, sur des telephones qui n'en ont pas les moyens.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primaryLight.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primaryLight,
    );
  }

  /// Une main ouverte, paume vers le haut, manche entrant par le bord.
  ///
  /// La paume est un **arc epais** — la moitie basse d'une ellipse — et non un
  /// contour ferme. C'est ce qui la fait lire comme un creux qui porte quelque
  /// chose : une forme pleine, a cette taille, devient une tache.
  void _paintHand(
    Canvas canvas,
    Offset at,
    double s, {
    required bool fromRight,
  }) {
    final dir = fromRight ? 1.0 : -1.0;
    final thickness = s * 0.26;

    final skin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;

    // Le creux se place sous la pastille, pas sur elle : la vignette porte son
    // libelle sous l'icone, et une paume centree sur la vignette le barrerait.
    final cup = Rect.fromCenter(
      center: at.translate(0, -s * 0.12),
      width: s * 2.05,
      height: s * 1.30,
    );
    canvas.drawArc(cup, 0.10, math.pi - 0.20, false, skin);

    // Quatre doigts, releves du cote oppose au manche.
    final tipsAt = Offset(at.dx - dir * s * 1.00, at.dy - s * 0.12);
    for (var i = 0; i < 4; i++) {
      final lift = s * (0.30 + i * 0.07);
      final from = tipsAt.translate(dir * s * 0.07 * i, -s * 0.02 * i);
      canvas.drawLine(
        from,
        from.translate(-dir * s * 0.10, -lift),
        Paint()
          ..strokeWidth = thickness * 0.62
          ..strokeCap = StrokeCap.round
          ..color = Colors.white,
      );
    }

    // Manche, attache au poignet et filant vers le bord de l'ecran. Attache :
    // un rectangle pose plus loin flotterait, comme deux objets sans rapport.
    final wrist = Offset(at.dx + dir * s * 1.00, at.dy - s * 0.12);
    canvas.drawLine(
      wrist,
      wrist.translate(dir * s * 1.30, s * 0.30),
      Paint()
        ..strokeWidth = thickness * 1.25
        ..strokeCap = StrokeCap.round
        ..color = AppColors.primaryLight,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => false;
}
