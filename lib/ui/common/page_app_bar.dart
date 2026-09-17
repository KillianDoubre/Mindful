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

/// Header colour once content scrolls beneath it: the page's own neutral
/// background, so the aurora never tints it in odd ways.
Color pageHeaderColor(ThemeData theme) =>
    theme.scaffoldBackgroundColor.withValues(alpha: 0.86);

/// Hairline under a header that content scrolls beneath.
Color pageHeaderDivider(ThemeData theme) =>
    theme.colorScheme.outlineVariant.withValues(alpha: 0.35);

/// App bar for secondary pages drawn over the shared background.
///
/// Transparent at rest; frosted and neutral as soon as the page content
/// scrolls under it.
class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PageAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      backgroundColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.scrolledUnder)
            ? pageHeaderColor(theme)
            : Colors.transparent,
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
