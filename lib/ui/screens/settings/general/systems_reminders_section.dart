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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/config/app_constants.dart';
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/enums/item_position.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/core/extensions/ext_widget.dart';
import 'package:mindful/core/utils/widget_utils.dart';
import 'package:mindful/models/systems_reminder.dart';
import 'package:mindful/providers/systems/systems_reminders_provider.dart';
import 'package:mindful/ui/common/rounded_container.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:mindful/ui/common/time_card.dart';

/// Settings section exposing the two independent Systems reminders:
/// a daily nudge to work on the systems and a weekly nudge to run the review.
class SystemsRemindersSection extends ConsumerWidget {
  const SystemsRemindersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(systemsRemindersProvider);
    final notifier = ref.read(systemsRemindersProvider.notifier);

    return Column(
      children: [
        _ReminderCard(
          title: 'Systèmes du jour',
          subtitle: 'Un rappel quotidien pour passer à l’action.',
          icon: FluentIcons.branch_20_filled,
          heroTag: 'systems-daily-reminder-time',
          reminder: config.daily,
          position: ItemPosition.top,
          onToggle: notifier.setDailyEnabled,
          onTimeChanged: notifier.setDailyTime,
          onDayToggled: notifier.toggleDailyDay,
        ),
        4.vBox,
        _ReminderCard(
          title: 'Revue hebdomadaire',
          subtitle: 'Un rappel pour faire le bilan de la semaine.',
          icon: FluentIcons.calendar_checkmark_20_filled,
          heroTag: 'systems-weekly-reminder-time',
          reminder: config.weekly,
          position: ItemPosition.bottom,
          onToggle: notifier.setWeeklyEnabled,
          onTimeChanged: notifier.setWeeklyTime,
          onDayToggled: notifier.toggleWeeklyDay,
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.heroTag,
    required this.reminder,
    required this.position,
    required this.onToggle,
    required this.onTimeChanged,
    required this.onDayToggled,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Object heroTag;
  final SystemReminder reminder;
  final ItemPosition position;
  final ValueChanged<bool> onToggle;
  final ValueChanged<TimeOfDayAdapter> onTimeChanged;
  final ValueChanged<int> onDayToggled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = reminder.isEnabled;

    return RoundedContainer(
      borderRadius: getBorderRadiusFromPosition(position),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          /// Header : icon + title + enable switch
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: enabled ? 0.11 : 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: enabled ? colors.primary : Theme.of(context).disabledColor,
                ),
              ),
              12.hBox,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StyledText(
                      title,
                      fontWeight: FontWeight.w700,
                      isSubtitle: !enabled,
                    ),
                    2.vBox,
                    StyledText(
                      subtitle,
                      fontSize: 12,
                      isSubtitle: true,
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
              ),
            ],
          ),

          /// Time + days (collapsed when the reminder is disabled)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: enabled
                ? Column(
                    children: [
                      16.vBox,

                      /// Time picker
                      TimeCard(
                        label: 'Heure du rappel',
                        heroTag: heroTag,
                        icon: getIconFromHourOfDay(reminder.time.hour),
                        iconColor:
                            getColorFromHourOfDay(context, reminder.time.hour),
                        initialTime: reminder.time,
                        onChange: (newTime) {
                          if (newTime == reminder.time) return;
                          onTimeChanged(newTime);
                        },
                      ),

                      /// Days of the week
                      16.vBox,
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          7,
                          (index) => Expanded(
                            child: RoundedContainer(
                              circularRadius: 200,
                              height: 44,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              color: reminder.days[index]
                                  ? colors.primary
                                  : Colors.transparent,
                              onPressed: () => onDayToggled(index),
                              child: StyledText(
                                AppConstants.daysShort(context)[index],
                                fontSize: 12,
                                textAlign: TextAlign.center,
                                color: reminder.days[index]
                                    ? colors.surface
                                    : null,
                              ).centered,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
