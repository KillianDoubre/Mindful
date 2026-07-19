import 'package:flutter/material.dart';

/// Lightweight atmospheric background shared by all scaffold-shell screens.
class MindfulBackground extends StatelessWidget {
  const MindfulBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = theme.scaffoldBackgroundColor;

    // Preserve a truly black canvas when the AMOLED option is enabled.
    if (base == Colors.black) {
      return const ColoredBox(color: Colors.black);
    }

    final isDark = theme.brightness == Brightness.dark;
    return ColoredBox(
      color: base,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    colors.primary.withValues(alpha: isDark ? 0.07 : 0.055),
                    base,
                  ),
                  base,
                  Color.alphaBlend(
                    colors.tertiary.withValues(alpha: isDark ? 0.05 : 0.04),
                    base,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -180,
            right: -140,
            child: _AmbientOrb(
              size: 420,
              color: colors.primary.withValues(alpha: isDark ? 0.13 : 0.10),
            ),
          ),
          Positioned(
            bottom: -220,
            left: -180,
            child: _AmbientOrb(
              size: 480,
              color: colors.tertiary.withValues(alpha: isDark ? 0.10 : 0.075),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      );
}
