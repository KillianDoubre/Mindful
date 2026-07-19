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
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/core/extensions/ext_widget.dart';
import 'package:mindful/config/app_constants.dart';
import 'package:mindful/ui/common/rounded_container.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:sliver_tools/sliver_tools.dart';

class SliverPrimaryActionContainer extends StatelessWidget {
  /// [RoundedContainer] with primary accent and a CTA button
  const SliverPrimaryActionContainer({
    super.key,
    required this.isVisible,
    required this.title,
    required this.information,
    required this.icon,
    this.margin = EdgeInsets.zero,
    this.positiveBtn,
    this.negativeBtn,
    this.radius,
  });

  final bool isVisible;
  final String title;
  final String information;
  final EdgeInsets margin;
  final IconData icon;
  final Widget? positiveBtn;
  final Widget? negativeBtn;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    return SliverAnimatedPaintExtent(
      duration: AppConstants.defaultAnimDuration,
      curve: Curves.easeOutBack,
      child: SliverVisibility(
        visible: isVisible,
        sliver: RoundedContainer(
          borderRadius: radius ?? BorderRadius.circular(26),
          color: Theme.of(context).colorScheme.secondaryContainer,
          padding: const EdgeInsets.all(18),
          margin: margin,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSecondaryContainer
                        .withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22),
                ),

                12.vBox,

                /// title
                StyledText(
                  title,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),

                2.vBox,

                ///  info
                StyledText(
                  information,
                  fontSize: 13,
                  height: 1.3,
                ),

                16.vBox,

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    negativeBtn ?? 0.vBox,
                    const Spacer(),
                    positiveBtn ?? 0.vBox,
                  ],
                ),
              ],
            ),
          ),
        ).sliver,
      ),
    );
  }
}
