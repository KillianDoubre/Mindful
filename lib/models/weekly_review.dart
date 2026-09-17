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

import 'package:flutter/foundation.dart';

/// Monday 00:00 of the week containing [day].
DateTime weekStartOf(DateTime day) {
  final date = DateTime(day.year, day.month, day.day);
  return DateTime(date.year, date.month, date.day - (date.weekday - 1));
}

/// Monday 00:00 of the week after the one starting at [weekStart].
DateTime weekEndOf(DateTime weekStart) =>
    DateTime(weekStart.year, weekStart.month, weekStart.day + 7);

@immutable
class AppTime {
  const AppTime(this.packageName, this.seconds);

  final String packageName;
  final int seconds;

  Map<String, Object> toJson() => {'p': packageName, 's': seconds};

  factory AppTime.fromJson(Map<String, dynamic> json) =>
      AppTime(json['p'] as String? ?? '', (json['s'] as num?)?.toInt() ?? 0);
}

@immutable
class SystemWeekVotes {
  const SystemWeekVotes({
    required this.systemId,
    required this.name,
    required this.votes,
    required this.activeDays,
  });

  final int systemId;
  final String name;
  final int votes;
  final int activeDays;

  Map<String, Object> toJson() => {
        'id': systemId,
        'n': name,
        'v': votes,
        'd': activeDays,
      };

  factory SystemWeekVotes.fromJson(Map<String, dynamic> json) =>
      SystemWeekVotes(
        systemId: (json['id'] as num?)?.toInt() ?? 0,
        name: json['n'] as String? ?? '',
        votes: (json['v'] as num?)?.toInt() ?? 0,
        activeDays: (json['d'] as num?)?.toInt() ?? 0,
      );
}

/// Everything measured about one week, frozen when the review is saved.
@immutable
class WeeklyStats {
  const WeeklyStats({
    required this.weekStart,
    required this.dailyScreenTime,
    required this.topApps,
    required this.previousScreenTime,
    required this.focusSeconds,
    required this.notificationsCount,
    required this.systems,
    required this.completedTasks,
    required this.overdueTasks,
  });

  static const topAppsCount = 5;
  static const completedTitlesCount = 8;

  final DateTime weekStart;

  /// Seconds of screen time, Monday first (7 entries).
  final List<int> dailyScreenTime;
  final List<AppTime> topApps;

  /// Total of the previous week, when known.
  final int? previousScreenTime;
  final int focusSeconds;
  final int notificationsCount;
  final List<SystemWeekVotes> systems;

  /// Titles of the tasks completed during the week, oldest first.
  final List<String> completedTasks;
  final int overdueTasks;

  int get screenTime => dailyScreenTime.fold(0, (a, b) => a + b);

  /// Average over the days that are already over or started.
  int averageDailyScreenTime(DateTime now) {
    final elapsed = now.difference(weekStart).inDays + 1;
    final days = elapsed.clamp(1, 7);
    return screenTime ~/ days;
  }

  /// Change against the previous week, as a ratio (-0.2 = 20 % less).
  double? get screenTimeTrend {
    final previous = previousScreenTime;
    if (previous == null || previous == 0) return null;
    return (screenTime - previous) / previous;
  }

  int get totalVotes => systems.fold(0, (a, b) => a + b.votes);

  /// Builds the stats from raw per-day, per-app usage.
  factory WeeklyStats.aggregate({
    required DateTime weekStart,
    required List<Map<String, int>> appsUsageByDay,
    required int? previousScreenTime,
    required int focusSeconds,
    required int notificationsCount,
    required List<SystemWeekVotes> systems,
    required List<String> completedTasks,
    required int overdueTasks,
  }) {
    final daily = List<int>.filled(7, 0);
    final perApp = <String, int>{};
    for (var day = 0; day < 7 && day < appsUsageByDay.length; day++) {
      appsUsageByDay[day].forEach((package, seconds) {
        if (seconds <= 0) return;
        daily[day] += seconds;
        perApp[package] = (perApp[package] ?? 0) + seconds;
      });
    }
    final topApps = perApp.entries
        .map((entry) => AppTime(entry.key, entry.value))
        .toList()
      ..sort((a, b) => b.seconds.compareTo(a.seconds));
    final sortedSystems = [...systems]
      ..sort((a, b) => b.votes.compareTo(a.votes));

    return WeeklyStats(
      weekStart: weekStart,
      dailyScreenTime: daily,
      topApps: topApps.take(topAppsCount).toList(),
      previousScreenTime: previousScreenTime,
      focusSeconds: focusSeconds,
      notificationsCount: notificationsCount,
      systems: sortedSystems,
      completedTasks: completedTasks,
      overdueTasks: overdueTasks,
    );
  }

  Map<String, Object?> toJson() => {
        'weekStart': weekStart.millisecondsSinceEpoch,
        'daily': dailyScreenTime,
        'topApps': topApps.map((app) => app.toJson()).toList(),
        'previous': previousScreenTime,
        'focus': focusSeconds,
        'notifications': notificationsCount,
        'systems': systems.map((system) => system.toJson()).toList(),
        'tasks': completedTasks,
        'overdue': overdueTasks,
      };

  factory WeeklyStats.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> objects(Object? value) => (value as List? ?? [])
        .whereType<Map>()
        .map((map) => map.map((key, value) => MapEntry('$key', value)))
        .toList();

    final daily = (json['daily'] as List? ?? [])
        .map((value) => (value as num?)?.toInt() ?? 0)
        .toList();
    return WeeklyStats(
      weekStart: DateTime.fromMillisecondsSinceEpoch(
        (json['weekStart'] as num?)?.toInt() ?? 0,
      ),
      dailyScreenTime: [...daily, ...List.filled(7, 0)].take(7).toList(),
      topApps: objects(json['topApps']).map(AppTime.fromJson).toList(),
      previousScreenTime: (json['previous'] as num?)?.toInt(),
      focusSeconds: (json['focus'] as num?)?.toInt() ?? 0,
      notificationsCount: (json['notifications'] as num?)?.toInt() ?? 0,
      systems: objects(json['systems']).map(SystemWeekVotes.fromJson).toList(),
      completedTasks: (json['tasks'] as List? ?? []).map((t) => '$t').toList(),
      overdueTasks: (json['overdue'] as num?)?.toInt() ?? 0,
    );
  }

  String encode() => jsonEncode(toJson());

  static WeeklyStats? tryDecode(String raw) {
    try {
      return WeeklyStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}

/// A saved Sunday review: the week's stats plus the user's reflection.
@immutable
class WeeklyReview {
  const WeeklyReview({
    required this.weekStart,
    required this.stats,
    this.rating = 0,
    this.wins = '',
    this.adjustments = '',
    this.intention = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final DateTime weekStart;
  final WeeklyStats stats;

  /// 1 to 5, 0 when not rated.
  final int rating;
  final String wins;
  final String adjustments;
  final String intention;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// "8 – 14 sept." style label for a week.
String formatWeekRange(DateTime weekStart) {
  const months = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  final endLabel = '${end.day} ${months[end.month - 1]}';
  if (end.month == weekStart.month) return '${weekStart.day} – $endLabel';
  return '${weekStart.day} ${months[weekStart.month - 1]} – $endLabel';
}

/// "2 h 05" / "45 min" for a number of seconds.
String formatSeconds(int seconds) {
  final minutes = seconds ~/ 60;
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h ${rest.toString().padLeft(2, '0')}';
}
