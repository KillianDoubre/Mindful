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
import 'package:mindful/ui/common/styled_text.dart';

class ContentSectionHeader extends StatelessWidget {
  /// Global title text with primary accent mainly used as a header for different sections in a list of widgets
  const ContentSectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.only(top: 26, bottom: 10),
    this.alignment = Alignment.centerLeft,
  });

  final String title;
  final EdgeInsets padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 9),
          StyledText(
            title,
            fontSize: 14,
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ],
      ),
    );
  }
}
