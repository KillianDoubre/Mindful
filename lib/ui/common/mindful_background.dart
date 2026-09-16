import 'package:flutter/material.dart';

/// Aurora backdrop shared by every page: large soft fields of the theme's
/// colours that give the frosted glass surfaces something to refract.
///
/// It is deliberately static: glass layers re-blur whatever moves behind them,
/// so an animated backdrop would cost a blur pass on every frame.
class MindfulBackground extends StatelessWidget {
  const MindfulBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = theme.scaffoldBackgroundColor;
    final isDark = theme.brightness == Brightness.dark;

    // AMOLED keeps a true black canvas, with only a faint glow for the glass
    final isAmoled = base == Colors.black;
    final strength = isAmoled ? 0.45 : 1.0;
    double a(double dark, double light) => (isDark ? dark : light) * strength;

    // Theme colours are pale in dark mode (and nearly grey with some dynamic
    // palettes), which turns the glows into a whitish fog. Keep their hue but
    // force a deep, saturated tone.
    final hue = _hueOf(colors.primary);
    final tertiaryHue = _hueOf(colors.tertiary, fallback: hue + 50);
    Color glow(double hueValue) => _vivid(hueValue, isDark: isDark);

    return RepaintBoundary(
      child: ColoredBox(
        color: base,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base wash so no corner is flat
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(
                      glow(hue).withValues(alpha: a(0.12, 0.08)),
                      base,
                    ),
                    base,
                    Color.alphaBlend(
                      glow(tertiaryHue).withValues(alpha: a(0.10, 0.07)),
                      base,
                    ),
                  ],
                ),
              ),
            ),
            _AuroraField(
              alignment: const Alignment(-1.1, -0.95),
              widthFactor: 1.35,
              heightFactor: 0.62,
              color: glow(hue).withValues(alpha: a(0.34, 0.30)),
            ),
            _AuroraField(
              alignment: const Alignment(1.25, -0.15),
              widthFactor: 1.05,
              heightFactor: 0.55,
              color: glow(tertiaryHue).withValues(alpha: a(0.26, 0.24)),
            ),
            _AuroraField(
              alignment: const Alignment(-1.2, 0.85),
              widthFactor: 1.2,
              heightFactor: 0.55,
              color: glow(hue - 35).withValues(alpha: a(0.24, 0.22)),
            ),
            _AuroraField(
              alignment: const Alignment(1.1, 1.15),
              widthFactor: 1.1,
              heightFactor: 0.5,
              color: glow((hue + tertiaryHue) / 2 + 20)
                  .withValues(alpha: a(0.26, 0.22)),
            ),
            // Keeps the headline area calm and legible
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    base.withValues(alpha: isDark ? 0.30 : 0.18),
                    base.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hue of [color], or [fallback] (an indigo by default) when the colour is
/// too grey for its hue to mean anything.
double _hueOf(Color color, {double fallback = 228}) {
  final hsl = HSLColor.fromColor(color);
  return hsl.saturation < 0.12 ? fallback % 360 : hsl.hue;
}

Color _vivid(double hue, {required bool isDark}) => HSLColor.fromAHSL(
      1,
      hue % 360,
      isDark ? 0.72 : 0.80,
      isDark ? 0.40 : 0.66,
    ).toColor();

/// An elliptical radial glow sized relative to the screen.
class _AuroraField extends StatelessWidget {
  const _AuroraField({
    required this.alignment,
    required this.widthFactor,
    required this.heightFactor,
    required this.color,
  });

  final Alignment alignment;
  final double widthFactor;
  final double heightFactor;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Align(
          alignment: alignment,
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            heightFactor: heightFactor,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.5,
                  stops: const [0, 0.45, 1],
                  colors: [
                    color,
                    color.withValues(alpha: color.a * 0.45),
                    color.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
