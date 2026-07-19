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
import 'package:mindful/core/extensions/ext_widget.dart';

/// Empty bottom padding sliver placed at the end of scrollable tabs and screens.
///
/// Because the app scaffold uses `extendBody: true`, scroll content extends
/// behind the bottom navigation bar and floating action buttons. This spacer
/// lets the last content item scroll clear of them.
class SliverTabsBottomPadding extends StatelessWidget {
  const SliverTabsBottomPadding({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 150).sliver;
  }
}
