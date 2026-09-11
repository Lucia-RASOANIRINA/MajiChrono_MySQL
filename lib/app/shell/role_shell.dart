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
      // Le fond suit la charte du home (ardoise clair / bleu nuit) pour que la
      // barre flottante se detache du contenu.
      backgroundColor: Colors.transparent,
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

/// Barre de navigation flottante, arrondie, dans le langage visuel du home.
///
/// Un rail unique porte les destinations ; sous l'onglet actif glisse une
/// pilule teintee de la couleur de marque. L'icone se remplit et le libelle
/// passe en gras : trois signaux concordants pour dire ou l'on est, ce qui
/// reste lisible en plein soleil et pour les daltonismes (EXI-T09). Le libelle
/// demeure toujours visible sous chaque icone (§15.1).
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.28 : 0.10,
                ),
                blurRadius: 20,
                offset: const Offset(0, 6),
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
                    isDark: isDark,
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
    required this.isDark,
    required this.onTap,
  });

  final ShellDestination destination;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? const Color(0xFF93C5FD) : AppColors.primary;
    final idleColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final color = selected ? activeColor : idleColor;

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Tooltip(
        message: destination.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 22,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: color,
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
