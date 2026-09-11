import 'package:flutter/material.dart';

/// Frise horizontale a quelques etapes (Collecte -> En transit -> Livre).
///
/// Elle donne l'avancement d'un coup d'oeil, en haut du suivi : les etapes
/// franchies sont pleines et cochees, l'etape en cours est marquee, les
/// suivantes restent en creux. C'est le resume ; la frise verticale horodatee
/// en dessous en donne le detail.
///
/// Les libelles arrivent deja traduits.
class McStepTrail extends StatelessWidget {
  const McStepTrail({
    required this.labels,
    required this.currentIndex,
    super.key,
  });

  final List<String> labels;

  /// Index de l'etape en cours (0..labels.length-1). Les etapes d'index
  /// inferieur sont franchies.
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = labels.length - 1;

    Color line(bool reached) =>
        reached ? scheme.primary : scheme.outlineVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Container(
                              height: 2,
                              color: line(currentIndex >= i),
                            ),
                    ),
                    _Dot(
                      done: i < currentIndex,
                      current: i == currentIndex,
                      scheme: scheme,
                    ),
                    Expanded(
                      child: i == last
                          ? const SizedBox.shrink()
                          : Container(
                              height: 2,
                              color: line(currentIndex >= i + 1),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    fontWeight: i == currentIndex
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: i <= currentIndex
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.done, required this.current, required this.scheme});

  final bool done;
  final bool current;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final active = done || current;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? scheme.primary : scheme.surface,
        border: Border.all(
          color: active ? scheme.primary : scheme.outlineVariant,
          width: 2,
        ),
      ),
      child: done
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : current
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}
