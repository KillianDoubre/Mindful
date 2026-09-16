import 'package:flutter/material.dart';
import 'package:mindful/ui/common/glass_material.dart';

/// A frosted glass card (see [GlassLayer]).
///
/// Blurs by default; inside a page's [BackdropGroup] every surface shares one
/// backdrop pass.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.blur = GlassLayer.defaultBlur,
    this.groupBlur = true,
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.width,
    this.height,
    this.showShadow = true,
    this.glow,
  });

  final Widget child;
  final double blur;
  final bool groupBlur;
  final Color? color;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double? width;
  final double? height;
  final bool showShadow;
  final Color? glow;

  @override
  Widget build(BuildContext context) => GlassLayer(
        blur: blur,
        groupBlur: groupBlur,
        tint: color,
        borderRadius: borderRadius,
        padding: padding,
        margin: margin,
        width: width,
        height: height,
        showShadow: showShadow,
        glow: glow,
        child: child,
      );
}
