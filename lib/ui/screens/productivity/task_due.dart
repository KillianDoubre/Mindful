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

/// Hour used when a due date is picked without a time.
const defaultDueHour = 18;

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

/// One-tap due dates offered in the task sheet and the long-press menu.
enum DueShortcut {
  today('Aujourd’hui'),
  tomorrow('Demain'),
  weekend('Ce week-end'),
  nextWeek('Semaine pro.');

  const DueShortcut(this.label);

  final String label;

  DateTime dayFrom(DateTime now) {
    final today = _day(now);
    return switch (this) {
      DueShortcut.today => today,
      DueShortcut.tomorrow => today.add(const Duration(days: 1)),
      // Saturday; on the weekend itself, today
      DueShortcut.weekend => now.weekday >= DateTime.saturday
          ? today
          : today.add(Duration(days: DateTime.saturday - now.weekday)),
      DueShortcut.nextWeek =>
        today.add(Duration(days: 8 - now.weekday)), // next Monday
    };
  }

  /// Keeps the time already chosen, otherwise uses [defaultDueHour].
  DateTime resolve(DateTime now, DateTime? current) {
    final day = dayFrom(now);
    return DateTime(
      day.year,
      day.month,
      day.day,
      current?.hour ?? defaultDueHour,
      current?.minute ?? 0,
    );
  }

  bool matches(DateTime due) => _day(due) == dayFrom(DateTime.now());
}

/// Groups used to organise pending tasks, in display order.
enum DueGroup {
  overdue('En retard'),
  today('Aujourd’hui'),
  tomorrow('Demain'),
  later('Plus tard'),
  none('Sans échéance');

  const DueGroup(this.label);

  final String label;

  static DueGroup of(DateTime? due, DateTime now) {
    if (due == null) return DueGroup.none;
    if (due.isBefore(now)) return DueGroup.overdue;
    final days = _day(due).difference(_day(now)).inDays;
    return switch (days) {
      0 => DueGroup.today,
      1 => DueGroup.tomorrow,
      _ => DueGroup.later,
    };
  }
}

String formatDue(BuildContext context, DateTime due) {
  final localizations = MaterialLocalizations.of(context);
  final days = _day(due).difference(_day(DateTime.now())).inDays;
  final dateLabel = switch (days) {
    0 => 'Aujourd’hui',
    1 => 'Demain',
    -1 => 'Hier',
    _ => localizations.formatMediumDate(due),
  };
  final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(due));
  return '$dateLabel · $time';
}

Color dueColor(
  BuildContext context,
  DateTime due, {
  required bool isCompleted,
}) {
  final colors = Theme.of(context).colorScheme;
  if (isCompleted) return colors.onSurfaceVariant;
  return switch (DueGroup.of(due, DateTime.now())) {
    DueGroup.overdue => colors.error,
    DueGroup.today => colors.primary,
    _ => colors.tertiary,
  };
}
