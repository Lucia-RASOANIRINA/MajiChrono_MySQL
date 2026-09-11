import 'package:flutter/material.dart';

/// Comportement de defilement de l'application.
///
/// Deux ecarts volontaires par rapport au defaut Flutter :
///
///  - **aucun effet de sur-defilement.** Android applique par defaut un
///    etirement elastique en bout de liste. Sur le parcours livreur, ou chaque
///    etape se valide en trois gestes (§15.2.2), un contenu qui rebondit sous
///    le pouce donne l'impression d'un appui rate et invite a re-appuyer. Un
///    ecran qui ne bouge pas est un ecran sur lequel on vise juste.
///
///  - **physique de defilement uniforme.** La meme physique sur Android et iOS
///    evite qu'un ecran se comporte differemment selon la plateforme, ce qui
///    compte pour une application dont le parcours livreur sera recette au
///    geste pres sur appareils reels (§16.2-8).
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const ClampingScrollPhysics();
}
