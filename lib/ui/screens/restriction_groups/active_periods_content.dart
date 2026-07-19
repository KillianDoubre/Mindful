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
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_duration.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/models/active_period.dart';
import 'package:mindful/ui/common/rounded_container.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:mindful/ui/common/time_period_start_end_cards.dart';
import 'package:mindful/ui/common/weekdays_selector.dart';

/// Editable list of a restriction group's [ActivePeriod]s.
///
/// Renders one card per period (start/end pickers + weekday bubbles + remove)
/// and an "add" button while the count is below [maxPeriods]. It is stateless —
/// every mutation produces a new list emitted through [onChanged].
class ActivePeriodsContent extends StatelessWidget {
  const ActivePeriodsContent({
    super.key,
    required this.periods,
    required this.canModify,
    required this.onChanged,
    required this.onLockedTap,
    this.maxPeriods = 3,
  });

  final List<ActivePeriod> periods;
  final bool canModify;
  final int maxPeriods;
  final ValueChanged<List<ActivePeriod>> onChanged;

  /// Called when the user attempts to edit while editing is locked
  /// (e.g. invincible mode). Typically shows a snack alert.
  final VoidCallback onLockedTap;

  /// Returns whether editing is allowed, otherwise notifies via [onLockedTap].
  bool _guard() {
    if (!canModify) onLockedTap();
    return canModify;
  }

  void _updateAt(int index, ActivePeriod period) {
    final updated = [...periods];
    updated[index] = period;
    onChanged(updated);
  }

  void _removeAt(int index) {
    if (!_guard()) return;
    onChanged([...periods]..removeAt(index));
  }

  void _addPeriod() {
    if (!_guard()) return;
    if (periods.length >= maxPeriods) return;
    onChanged([...periods, ActivePeriod.defaultWindow()]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /// Info
        StyledText(
          context.locale.active_period_info,
          color: Theme.of(context).hintColor,
        ),
        12.vBox,

        /// Period cards
        ...List.generate(
          periods.length,
          (index) => _buildPeriodCard(context, index, periods[index]),
        ),

        /// Add period button
        if (periods.length < maxPeriods)
          Align(
            child: TextButton.icon(
              icon: const Icon(FluentIcons.add_circle_20_filled),
              label: Text(context.locale.active_period_add_button),
              onPressed: _addPeriod,
            ),
          ),
      ],
    );
  }

  Widget _buildPeriodCard(
      BuildContext context, int index, ActivePeriod period) {
    return RoundedContainer(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      circularRadius: 16,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Column(
        children: [
          /// Header: duration + remove
          Row(
            children: [
              StyledText(
                period.totalDuration.toTimeFull(context),
                fontWeight: FontWeight.bold,
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  FluentIcons.delete_20_regular,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _removeAt(index),
              ),
            ],
          ),
          8.vBox,

          /// Start / end time
          TimePeriodStartEndCards(
            startTime: period.start,
            endTime: period.end,
            bgColor: Theme.of(context).colorScheme.surface,
            startHeroTag: "activePeriod.$index.start",
            endHeroTag: "activePeriod.$index.end",
            isModifiable: _guard,
            onStartTimeChanged: (start) =>
                _updateAt(index, period.copyWith(start: start)),
            onEndTimeChanged: (end) =>
                _updateAt(index, period.copyWith(end: end)),
          ),
          16.vBox,

          /// Active weekdays
          WeekdaysSelector(
            selectedDays: period.days,
            enabled: canModify,
            onDayToggled: (dayIndex) {
              final days = [...period.days];
              days[dayIndex] = !days[dayIndex];
              _updateAt(index, period.copyWith(days: days));
            },
          ),
        ],
      ),
    );
  }
}
