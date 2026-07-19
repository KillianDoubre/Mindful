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
import 'package:mindful/core/enums/item_position.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/core/utils/widget_utils.dart';
import 'package:mindful/ui/common/rounded_container.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:skeletonizer/skeletonizer.dart';

class UsageGlanceCard extends StatelessWidget {
  const UsageGlanceCard({
    super.key,
    required this.title,
    required this.info,
    this.icon,
    this.onTap,
    this.badge,
    this.isPrimary = false,
    this.position = ItemPosition.mid,
  });

  final IconData? icon;
  final bool isPrimary;
  final String title;
  final String info;
  final VoidCallback? onTap;
  final ItemPosition position;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final mini = icon == null;
    final colors = Theme.of(context).colorScheme;
    final foreground = isPrimary ? colors.onSecondaryContainer : null;

    return RoundedContainer(
      circularRadius: 10,
      borderRadius: getBorderRadiusFromPosition(position),
      padding: const EdgeInsets.all(17),
      color: isPrimary ? colors.secondaryContainer : null,
      onPressed: onTap,
      child: Stack(
        children: [
          /// Usage
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mini)
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        (foreground ?? colors.primary).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: foreground ?? colors.primary,
                  ),
                ),
              mini ? 0.vBox : 16.vBox,
              StyledText(
                title,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
              Skeleton.leaf(
                child: FittedBox(
                  child: StyledText(
                    info.isEmpty ? " " : info,
                    fontSize: 26,
                    maxLines: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: foreground,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),

          /// Badge
          Align(
            alignment: Alignment.topRight,
            child: badge ?? 0.hBox,
          )
        ],
      ),
    );
  }
}
