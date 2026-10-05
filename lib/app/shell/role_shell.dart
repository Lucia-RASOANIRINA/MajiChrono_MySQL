import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:majichrono/app/theme/app_colors.dart';

/// Destination de la barre de navigation d'un profil.
class ShellDestination {
  const ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;

  /// Toujours renseigne : l'iconographie est systematiquement doublee d'un
  /// libelle (§15.1), y compris pour les utilisateurs peu a l'aise avec le
  /// numerique (§4.5).
  final String label;
}

/// Coquille commune aux trois profils.
///
/// Elle porte le bandeau reseau permanent (EXI-T06) au-dessus du contenu :
/// place ici plutot que dans chaque ecran, il ne peut pas etre oublie.
class RoleShell extends StatelessWidget {
  const RoleShell({
    required this.navigationShell,
    required this.destinations,
    this.showNavigationBar = true,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<ShellDestination> destinations;
  final bool showNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La zone sous la barre doit rester dans la surface de l'application.
      // Un fond transparent révélait le fond noir du système sur certains
      // appareils et produisait une bande visuellement incohérente.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Keep the last controls above the navigation bar. Extending the body
      // underneath the floating bar hid buttons on smaller phones.
      extendBody: false,
      // Le bandeau reseau (EXI-T06) n'est pas ici mais au-dessus du Navigator,
      // dans `MajiChronoApp.builder` : porte par la coquille, il disparaitrait
      // au premier ecran empile.
      body: navigationShell,
      bottomNavigationBar: showNavigationBar
          ? _ModernNavBar(
              currentIndex: navigationShell.currentIndex,
              destinations: destinations,
              onSelected: (index) {
                HapticFeedback.selectionClick();
                navigationShell.goBranch(
                  index,
                  // Un second appui sur l'onglet actif revient a sa racine.
                  initialLocation: index == navigationShell.currentIndex,
                );
              },
            )
          : null,
    );
  }
}

/// Barre de navigation flottante, aux couleurs de la charte.
///
/// L'onglet actif porte une pilule pleine au bleu de marque, icone blanche
/// legerement agrandie, libelle en gras et bleu ; les autres restent en gris
/// ardoise. Trois signaux concordants (forme, couleur, graisse) disent ou l'on
/// est, lisibles en plein soleil et pour les daltonismes (EXI-T09). Le libelle
/// demeure toujours visible, a 14 sp comme tout texte de l'application
/// (§15.1).
class _ModernNavBar extends StatelessWidget {
  const _ModernNavBar({
    required this.currentIndex,
    required this.destinations,
    required this.onSelected,
  });

  final int currentIndex;
  final List<ShellDestination> destinations;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.35 : 0.12,
                ),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _NavItem(
                    destination: destinations[i],
                    selected: i == currentIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  static const Duration _motion = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = isDark ? scheme.primary : AppColors.primary;
    final idle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      excludeSemantics: true,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: _motion,
                  curve: Curves.easeOutBack,
                  width: selected ? 58 : 44,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: selected
                        ? LinearGradient(
                            colors: isDark
                                ? [scheme.primary, scheme.primary]
                                : const [
                                    AppColors.primaryLight,
                                    AppColors.primary,
                                  ],
                          )
                        : null,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: active.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: AnimatedScale(
                    duration: _motion,
                    curve: Curves.easeOutBack,
                    scale: selected ? 1.12 : 1,
                    child: Icon(
                      selected ? destination.selectedIcon : destination.icon,
                      size: 22,
                      color: selected
                          ? (isDark ? scheme.onPrimary : Colors.white)
                          : idle,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: _motion,
                  // Part de la typographie du theme : meme police que le reste.
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 14,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? active : idle,
                  ),
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
