import 'package:flutter/material.dart';

import 'package:majichrono/app/theme/design_tokens.dart';

/// Surface de base de MajiChrono : une carte au rayon des feuilles (16 dp),
/// posee sur le fond, qui porte cartes de course, fiches et blocs
/// d'information.
///
/// Un seul composant pour toutes les cartes : sans lui, chaque ecran redessine
/// sa propre boite, les rayons divergent, les elevations aussi, et l'ensemble
/// cesse de se lire comme une meme application. Ici le rayon, la couleur de
/// surface et l'elevation viennent des jetons (§15.1) ; l'ecran n'a plus qu'a
/// remplir [child].
///
/// [accent] ajoute un liseré vertical de couleur au bord gauche — la facon la
/// plus discrete de marquer un statut sans teinter toute la carte, et qui
/// reste lisible en niveaux de gris (le liseré est une position, pas seulement
/// une couleur).
class McCard extends StatelessWidget {
  const McCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.accent,
    this.selected = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Liseré de statut au bord gauche. Absent, la carte est neutre.
  final Color? accent;

  /// Etat choisi : la carte prend une bordure a la couleur primaire.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cardColor = theme.cardTheme.color ?? scheme.surface;

    Widget content = Padding(padding: padding, child: child);

    if (accent != null) {
      // Le lisere de statut longe tout le bord gauche. On le pose en
      // `Positioned` (top et bottom a 0) dans un `Stack` qui se dimensionne sur
      // le contenu : il epouse ainsi la hauteur de la carte sans imposer la
      // moindre contrainte de hauteur au contenu.
      //
      // Un `Row(CrossAxisAlignment.stretch)` le faisait aussi, mais sous une
      // hauteur **non bornee** — cas d'une carte dans une liste defilante — le
      // stretch exige une hauteur infinie et fait planter le layout du viewport
      // (« BoxConstraints forces an infinite height »). Tout le corps de
      // l'ecran devenait alors blanc : c'etait le bug de l'accueil livreur des
      // qu'une course active (carte a lisere) etait affichee.
      content = Stack(
        children: [
          Padding(padding: const EdgeInsets.only(left: 4), child: content),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 4,
            child: ColoredBox(color: accent!),
          ),
        ],
      );
    }

    return Material(
      color: cardColor,
      elevation: AppElevation.raised,
      shadowColor: scheme.shadow,
      clipBehavior: Clip.antiAlias,
      // `shape` et `borderRadius` s'excluent sur Material : on ne fournit le
      // premier qu'en etat choisi (pour la bordure), le second sinon.
      borderRadius: selected ? null : AppRadii.sheetAll,
      shape: selected
          ? RoundedRectangleBorder(
              borderRadius: AppRadii.sheetAll,
              side: BorderSide(color: scheme.primary, width: 2),
            )
          : null,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}
