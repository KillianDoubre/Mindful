/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:flutter/material.dart';
import 'package:mindful/ui/common/glass_material.dart';

class RoundedContainer extends StatelessWidget {
  /// A decorated container with the provided properties
  ///
  /// If [onPressed] is not null then it build a inkwell widget, otherwise build a normal container with the decorations
  const RoundedContainer({
    super.key,
    this.height,
    this.width,
    this.color,
    this.borderRadius,
    this.child,
    this.onPressed,
    this.circularRadius = 18,
    this.margin = EdgeInsets.zero,
    this.padding = EdgeInsets.zero,
    this.alignment = Alignment.center,
  });

  final double? height;
  final double? width;
  final Color? color;
  final double circularRadius;
  final BorderRadius? borderRadius;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final Widget? child;
  final VoidCallback? onPressed;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(circularRadius);

    final content = Padding(
      padding: padding,
      child: Align(alignment: alignment, child: child),
    );

    return GlassLayer(
      width: width,
      height: height,
      margin: margin,
      tint: color,
      borderRadius: radius,
      child: onPressed == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                splashColor: colors.primary.withValues(alpha: 0.12),
                highlightColor: colors.primary.withValues(alpha: 0.06),
                child: content,
              ),
            ),
    );
  }
}
