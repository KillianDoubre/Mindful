/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

/// How a task repeats once completed.
enum TaskRecurrence {
  none('', 'Jamais'),
  daily('daily', 'Chaque jour'),
  weekdays('weekdays', 'En semaine'),
  weekly('weekly', 'Chaque semaine'),
  monthly('monthly', 'Chaque mois');

  const TaskRecurrence(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  bool get isRepeating => this != TaskRecurrence.none;

  static TaskRecurrence fromDatabase(String? value) => values.firstWhere(
        (recurrence) => recurrence.databaseValue == value,
        orElse: () => TaskRecurrence.none,
      );

  /// The occurrence right after [from], at the same time of day.
  ///
  /// Dates are built from calendar fields rather than by adding durations, so
  /// daylight saving changes never shift the time.
  DateTime next(DateTime from) {
    DateTime shift(int days) => DateTime(
          from.year,
          from.month,
          from.day + days,
          from.hour,
          from.minute,
        );

    switch (this) {
      case TaskRecurrence.none:
        return from;
      case TaskRecurrence.daily:
        return shift(1);
      case TaskRecurrence.weekdays:
        final days = switch (from.weekday) {
          DateTime.friday => 3,
          DateTime.saturday => 2,
          _ => 1,
        };
        return shift(days);
      case TaskRecurrence.weekly:
        return shift(7);
      case TaskRecurrence.monthly:
        final month = from.month + 1;
        final lastDay = DateTime(from.year, month + 1, 0).day;
        return DateTime(
          from.year,
          month,
          from.day > lastDay ? lastDay : from.day,
          from.hour,
          from.minute,
        );
    }
  }

  /// First occurrence after [due] that is also after [now], so completing a
  /// late recurring task never schedules it in the past.
  DateTime nextAfter(DateTime due, DateTime now) {
    if (!isRepeating) return due;
    var candidate = next(due);
    for (var guard = 0; guard < 5000 && !candidate.isAfter(now); guard++) {
      candidate = next(candidate);
    }
    return candidate;
  }
}
