/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';

/// A single recurring reminder for the Systems feature (time + weekdays).
///
/// [days] follows the app-wide convention used by `AppConstants.daysShort` and
/// the native `DateTimeUtils.zeroIndexedDayOfWeek()`:
/// `[0]` = Monday … `[6]` = Sunday.
@immutable
class SystemReminder {
  final bool isEnabled;
  final TimeOfDayAdapter time;
  final List<bool> days;

  const SystemReminder({
    required this.isEnabled,
    required this.time,
    required this.days,
  });

  bool get hasAnyDay => days.any((day) => day);

  SystemReminder copyWith({
    bool? isEnabled,
    TimeOfDayAdapter? time,
    List<bool>? days,
  }) {
    return SystemReminder(
      isEnabled: isEnabled ?? this.isEnabled,
      time: time ?? this.time,
      days: days ?? this.days,
    );
  }

  SystemReminder toggleDay(int index) {
    final updated = List<bool>.from(days);
    updated[index] = !updated[index];
    return copyWith(days: updated);
  }

  Map<String, dynamic> toMap() => {
        'isEnabled': isEnabled,
        'minutes': time.toMinutes,
        'days': days,
      };

  factory SystemReminder.fromMap(Map<String, dynamic> map) {
    final rawDays = (map['days'] as List?) ?? const [];
    final days = List<bool>.generate(
      7,
      (i) => i < rawDays.length ? rawDays[i] == true : true,
    );
    return SystemReminder(
      isEnabled: map['isEnabled'] == true,
      time: TimeOfDayAdapter.fromMinutes(map['minutes'] ?? 0),
      days: days,
    );
  }
}

/// Bundle of the two independent Systems reminders that can be configured from
/// the settings screen and pushed to the native alarm scheduler.
@immutable
class SystemsRemindersConfig {
  /// Reminder nudging the user to work on their daily systems.
  final SystemReminder daily;

  /// Reminder nudging the user to run the weekly systems review.
  final SystemReminder weekly;

  const SystemsRemindersConfig({
    required this.daily,
    required this.weekly,
  });

  /// Sensible defaults: both reminders are OFF until the user enables them.
  /// Daily → every day at 08:00, Weekly → Sunday at 18:00.
  factory SystemsRemindersConfig.defaults() => SystemsRemindersConfig(
        daily: const SystemReminder(
          isEnabled: false,
          time: TimeOfDayAdapter.fromMinutes(8 * 60),
          days: [true, true, true, true, true, true, true],
        ),
        weekly: const SystemReminder(
          isEnabled: false,
          time: TimeOfDayAdapter.fromMinutes(18 * 60),
          days: [false, false, false, false, false, false, true],
        ),
      );

  SystemsRemindersConfig copyWith({
    SystemReminder? daily,
    SystemReminder? weekly,
  }) {
    return SystemsRemindersConfig(
      daily: daily ?? this.daily,
      weekly: weekly ?? this.weekly,
    );
  }

  Map<String, dynamic> toMap() => {
        'daily': daily.toMap(),
        'weekly': weekly.toMap(),
      };

  factory SystemsRemindersConfig.fromMap(Map<String, dynamic> map) {
    final defaults = SystemsRemindersConfig.defaults();
    return SystemsRemindersConfig(
      daily: map['daily'] is Map
          ? SystemReminder.fromMap(
              Map<String, dynamic>.from(map['daily'] as Map),
            )
          : defaults.daily,
      weekly: map['weekly'] is Map
          ? SystemReminder.fromMap(
              Map<String, dynamic>.from(map['weekly'] as Map),
            )
          : defaults.weekly,
    );
  }

  String toJson() => json.encode(toMap());
}
