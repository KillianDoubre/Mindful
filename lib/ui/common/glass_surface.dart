import 'dart:ui';

import 'package:flutter/material.dart';

/// A translucent surface with an optional backdrop blur.
///
/// Blur is opt-in so frequently repeated cards can keep the glass appearance
/// without creating an expensive compositing layer for every list item.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.blur = 0,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
    this.showShadow = true,
  });

  final Widget child;
  final double blur;
  final Color? color;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? width;
  final double? height;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final tint = color ?? colors.surfaceContainerHigh;
    final fill = tint.withValues(alpha: isDark ? 0.72 : 0.76);

    final surface = Container(
      width: width,
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: isDark ? 0.055 : 0.20),
              fill,
            ),
            fill,
          ],
        ),
        borderRadius: borderRadius,
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: isDark ? 0.30 : 0.38,
          ),
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: child,
    );

    final clippedSurface = ClipRRect(
      borderRadius: borderRadius,
      child: blur <= 0
          ? surface
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: surface,
            ),
    );

    return Padding(
      padding: margin,
      child:
          blur <= 0 ? clippedSurface : RepaintBoundary(child: clippedSurface),
    );
  }
}
