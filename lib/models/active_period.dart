/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:flutter/foundation.dart';

import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';

/// A single active period for a restriction group.
///
/// Apps in the group are allowed only when the current time falls inside one of
/// the group's [ActivePeriod]s AND the current weekday is enabled in [days].
///
/// [days] is a list of exactly 7 booleans ordered Monday → Sunday, matching
/// `DateTime.weekday - 1` (Monday = index 0, Sunday = index 6).
@immutable
class ActivePeriod {
  /// [TimeOfDay] from where the active period starts (stored as total minutes).
  final TimeOfDayAdapter start;

  /// [TimeOfDay] when the active period ends (stored as total minutes).
  final TimeOfDayAdapter end;

  /// Weekdays on which this period is enabled, ordered Monday → Sunday.
  final List<bool> days;

  const ActivePeriod({
    required this.start,
    required this.end,
    required this.days,
  });

  /// A sensible default window (09:00 → 17:00, every day) for a newly added
  /// period, so it is immediately meaningful (start != end enforces it).
  factory ActivePeriod.defaultWindow() => ActivePeriod(
        start: const TimeOfDayAdapter(hour: 9, minute: 0),
        end: const TimeOfDayAdapter(hour: 17, minute: 0),
        days: List<bool>.filled(7, true),
      );

  /// Total duration from [start] to [end] (wraps past midnight).
  Duration get totalDuration => end.difference(start);

  /// Whether at least one weekday is enabled.
  bool get hasAnyDay => days.any((d) => d);

  ActivePeriod copyWith({
    TimeOfDayAdapter? start,
    TimeOfDayAdapter? end,
    List<bool>? days,
  }) {
    return ActivePeriod(
      start: start ?? this.start,
      end: end ?? this.end,
      days: days ?? this.days,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'start': start.toMinutes,
      'end': end.toMinutes,
      'days': days,
    };
  }

  factory ActivePeriod.fromMap(Map<String, dynamic> map) {
    final rawDays = (map['days'] as List?) ?? const [];
    final days = List<bool>.generate(
      7,
      (i) => i < rawDays.length ? (rawDays[i] as bool? ?? true) : true,
    );

    return ActivePeriod(
      start: TimeOfDayAdapter.fromMinutes(map['start'] ?? 0),
      end: TimeOfDayAdapter.fromMinutes(map['end'] ?? 0),
      days: days,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ActivePeriod &&
      other.start == start &&
      other.end == end &&
      listEquals(other.days, days);

  @override
  int get hashCode => Object.hash(start, end, Object.hashAll(days));

  @override
  String toString() => 'ActivePeriod(start: $start, end: $end, days: $days)';
}
