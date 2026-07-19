/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/enums/item_position.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_duration.dart';
import 'package:mindful/core/utils/date_time_utils.dart';
import 'package:mindful/providers/focus/monthly_focus_provider.dart';
import 'package:mindful/ui/common/usage_glance_card.dart';

class FocusDailyGlance extends ConsumerWidget {
  const FocusDailyGlance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayRange = DateTimeRange(start: dateToday, end: dateToday);

    final today = ref.watch(
      monthlyFocusProvider(todayRange).select(
        (v) => v.monthlyFocus[dateToday] ?? 0,
      ),
    );

    return UsageGlanceCard(
      isPrimary: true,
      compact: true,
      position: ItemPosition.topRight,
      icon: FluentIcons.target_20_filled,
      title: context.locale.focus_today_label,
      info: today.seconds.toTimeShort(context),
    );
  }
}
