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
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/config/hero_tags.dart';
import 'package:mindful/ui/common/time_card.dart';

class TimePeriodStartEndCards extends StatelessWidget {
  const TimePeriodStartEndCards({
    super.key,
    this.bgColor,
    this.isModifiable,
    this.enabled = true,
    this.startHeroTag = HeroTags.scheduleStartTimePickerTag,
    this.endHeroTag = HeroTags.scheduleEndTimePickerTag,
    required this.startTime,
    required this.endTime,
    required this.onStartTimeChanged,
    required this.onEndTimeChanged,
  });

  final Color? bgColor;
  final bool Function()? isModifiable;
  final bool enabled;

  /// Hero tags for the start/end time cards. Must be unique per instance when
  /// several [TimePeriodStartEndCards] are shown on the same screen.
  final Object startHeroTag;
  final Object endHeroTag;

  final TimeOfDayAdapter startTime;
  final TimeOfDayAdapter endTime;
  final Function(TimeOfDayAdapter timeTod) onStartTimeChanged;
  final Function(TimeOfDayAdapter timeTod) onEndTimeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        /// Schedule start time
        Expanded(
          child: TimeCard(
            enabled: enabled,
            isModifiable: isModifiable,
            label: context.locale.schedule_start_label,
            heroTag: startHeroTag,
            initialTime: startTime,
            bgColor: bgColor,
            onChange: onStartTimeChanged,
          ),
        ),

        12.hBox,

        /// Schedule end time
        Expanded(
          child: TimeCard(
            enabled: enabled,
            isModifiable: isModifiable,
            label: context.locale.schedule_end_label,
            heroTag: endHeroTag,
            initialTime: endTime,
            bgColor: bgColor,
            onChange: onEndTimeChanged,
          ),
        ),
      ],
    );
  }
}
