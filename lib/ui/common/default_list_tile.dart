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

/// Global list tile used throughout the app
///
/// Alternative to [ListTile] as the list tile widget have some artifact when scrolling while in focus state
class DefaultListTile extends StatelessWidget {
  const DefaultListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.leadingIcon,
    this.titleText,
    this.subtitleText,
    this.color,
    this.accent,
    this.onPressed,
    this.switchValue,
    this.isSelected,
    this.position,
    this.margin,
    this.enabled = true,
    this.isPrimary = false,
  });

  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final IconData? leadingIcon;
  final String? titleText;
  final String? subtitleText;
  final Color? color;
  final Color? accent;
  final bool? switchValue;
  final bool? isSelected;
  final ItemPosition? position;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isPrimary;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = enabled
        ? accent ?? (isPrimary ? colors.onSecondaryContainer : null)
        : theme.disabledColor;

    return RoundedContainer(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      margin: margin ?? const EdgeInsets.only(top: 4),
      borderRadius: getBorderRadiusFromPosition(position ?? ItemPosition.none),
      color: isPrimary ? colors.secondaryContainer : color,
      onPressed: enabled ? onPressed : null,
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          /// Leading widget
          leadingIcon != null
              ? Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (foreground ?? colors.primary).withValues(
                      alpha: enabled ? 0.11 : 0.06,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    leadingIcon,
                    size: 21,
                    color: foreground ?? colors.primary,
                  ),
                )
              : leading ?? 0.hBox,

          /// leading space
          if (leading != null || leadingIcon != null) const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Title widget
                titleText != null
                    ? StyledText(
                        titleText!,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        color: foreground,
                      )
                    : title ?? 0.vBox,

                /// Subtitle widget
                subtitleText != null
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: StyledText(
                          subtitleText!,
                          fontSize: 13,
                          height: 1.28,
                          isSubtitle: true,
                          color: enabled ? null : theme.disabledColor,
                        ),
                      )
                    : subtitle ?? 0.vBox,
              ],
            ),
          ),

          if (switchValue != null || isSelected != null || trailing != null)
            4.hBox,

          /// Trailing widget
          switchValue != null
              ? IgnorePointer(
                  child: Switch(
                    value: switchValue ?? false,
                    splashRadius: 0,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: enabled ? (_) {} : null,
                  ),
                )
              : isSelected != null
                  ? IgnorePointer(
                      child: Checkbox(
                        value: isSelected,
                        splashRadius: 0,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: enabled ? (_) {} : null,
                      ),
                    )
                  : trailing ?? 0.hBox,
        ],
      ),
    );
  }
}
