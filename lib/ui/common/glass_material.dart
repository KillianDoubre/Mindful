/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'dart:ui';

import 'package:flutter/material.dart';

/// The app-wide frosted glass material.
///
/// A glass layer is a translucent tinted fill with a diagonal sheen, a light
/// rim that is brightest on the top-left edge (as if lit from above) and a
/// real backdrop blur. Inside a [BackdropGroup] the blur is shared by every
/// layer of the page, so long lists of glass tiles stay smooth.
class GlassLayer extends StatelessWidget {
  const GlassLayer({
    super.key,
    required this.child,
    required this.borderRadius,
    this.tint,
    this.blur = defaultBlur,
    this.groupBlur = true,
    this.showShadow = false,
    this.glow,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
  });

  static const defaultBlur = 18.0;

  final Widget child;
  final BorderRadius borderRadius;

  /// Base colour of the glass. Colours that are already translucent are used
  /// as given; opaque ones get the standard glass transparency.
  final Color? tint;
  final double blur;

  /// Share the page's backdrop pass. Floating chrome drawn above other glass
  /// (navigation bar) must blur on its own to see what scrolls beneath it.
  final bool groupBlur;
  final bool showShadow;

  /// Optional coloured halo, used for primary actions.
  final Color? glow;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? width;
  final double? height;

  static Color fillFor(ThemeData theme, Color? tint) {
    final isDark = theme.brightness == Brightness.dark;
    final base = tint ?? theme.colorScheme.surfaceContainerHigh;
    if (tint != null && tint.a < 1) return tint;
    return base.withValues(
      alpha: tint == null ? (isDark ? 0.40 : 0.50) : (isDark ? 0.55 : 0.62),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A fully transparent layer sits inside another glass surface: stay plain
    if (tint != null && tint!.a == 0) {
      return Padding(
        padding: margin,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            width: width,
            height: height,
            padding: padding,
            child: child,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fill = fillFor(theme, tint);
    // Square layers are always clipped by a rounded parent, which would cut a
    // square rim at the corners
    final hasRim = borderRadius != BorderRadius.zero;

    final surface = CustomPaint(
      foregroundPainter: hasRim
          ? GlassRimPainter(borderRadius: borderRadius, isDark: isDark)
          : null,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0, 0.45, 1],
            colors: [
              Color.alphaBlend(
                Colors.white.withValues(alpha: isDark ? 0.055 : 0.34),
                fill,
              ),
              fill,
              Color.alphaBlend(
                Colors.white.withValues(alpha: isDark ? 0.025 : 0.08),
                fill,
              ),
            ],
          ),
        ),
        child: child,
      ),
    );

    final filter = ImageFilter.blur(sigmaX: blur, sigmaY: blur);
    final blurred = ClipRRect(
      borderRadius: borderRadius,
      child: blur <= 0
          ? surface
          : groupBlur
              ? BackdropFilter.grouped(filter: filter, child: surface)
              : BackdropFilter(filter: filter, child: surface),
    );

    final shadows = [
      if (showShadow)
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.10),
          blurRadius: 30,
          offset: const Offset(0, 14),
        ),
      if (glow != null)
        BoxShadow(
          color: glow!.withValues(alpha: isDark ? 0.40 : 0.32),
          blurRadius: 26,
          spreadRadius: -4,
          offset: const Offset(0, 8),
        ),
    ];

    return Padding(
      padding: margin,
      child: shadows.isEmpty
          ? blurred
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: shadows,
              ),
              child: blurred,
            ),
    );
  }
}

/// Hairline rim of a glass layer: bright where light hits the top-left edge,
/// fading along the sides and catching a softer reflection bottom-right.
class GlassRimPainter extends CustomPainter {
  const GlassRimPainter({required this.borderRadius, required this.isDark});

  final BorderRadius borderRadius;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(0.5);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, 0.38, 0.72, 1],
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.34 : 0.85),
          Colors.white.withValues(alpha: isDark ? 0.07 : 0.30),
          Colors.white.withValues(alpha: isDark ? 0.03 : 0.18),
          Colors.white.withValues(alpha: isDark ? 0.16 : 0.55),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(GlassRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius || oldDelegate.isDark != isDark;
}
