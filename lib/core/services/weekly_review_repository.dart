/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:mindful/core/services/drift_db_service.dart';
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/core/services/productivity_repository.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/models/weekly_review.dart';

/// Sunday reviews: computes a week's stats and stores the reviews.
///
/// The table is created lazily, like the other personal modules, so existing
/// databases need no Drift migration.
class WeeklyReviewRepository {
  WeeklyReviewRepository._();

  static final WeeklyReviewRepository instance = WeeklyReviewRepository._();

  Future<void>? _initialization;

  Future<void> _ensureInitialized() => _initialization ??= _createTable();

  Future<void> _createTable() async {
    await DriftDbService.instance.driftDb.customStatement('''
      CREATE TABLE IF NOT EXISTS weekly_reviews (
        week_start INTEGER PRIMARY KEY,
        stats TEXT NOT NULL,
        rating INTEGER NOT NULL DEFAULT 0,
        wins TEXT NOT NULL DEFAULT '',
        adjustments TEXT NOT NULL DEFAULT '',
        intention TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<List<WeeklyReview>> loadAll() async {
    await _ensureInitialized();
    final rows = await DriftDbService.instance.driftDb
        .customSelect('SELECT * FROM weekly_reviews ORDER BY week_start DESC')
        .get();
    return rows.map((row) => _fromRow(row.data)).whereType<WeeklyReview>().toList();
  }

  Future<WeeklyReview?> load(DateTime weekStart) async {
    await _ensureInitialized();
    final row = await DriftDbService.instance.driftDb.customSelect(
      'SELECT * FROM weekly_reviews WHERE week_start = ?',
      variables: [Variable.withInt(weekStart.millisecondsSinceEpoch)],
    ).getSingleOrNull();
    return row == null ? null : _fromRow(row.data);
  }

  Future<void> save({
    required WeeklyStats stats,
    required int rating,
    required String wins,
    required String adjustments,
    required String intention,
  }) async {
    await _ensureInitialized();
    final now = DateTime.now().millisecondsSinceEpoch;
    await DriftDbService.instance.driftDb.customStatement(
      '''
        INSERT INTO weekly_reviews (
          week_start, stats, rating, wins, adjustments, intention,
          created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(week_start) DO UPDATE SET
          stats = excluded.stats,
          rating = excluded.rating,
          wins = excluded.wins,
          adjustments = excluded.adjustments,
          intention = excluded.intention,
          updated_at = excluded.updated_at
      ''',
      [
        stats.weekStart.millisecondsSinceEpoch,
        stats.encode(),
        rating.clamp(0, 5),
        wins.trim(),
        adjustments.trim(),
        intention.trim(),
        now,
        now,
      ],
    );
  }

  Future<void> delete(DateTime weekStart) async {
    await _ensureInitialized();
    await DriftDbService.instance.driftDb.customStatement(
      'DELETE FROM weekly_reviews WHERE week_start = ?',
      [weekStart.millisecondsSinceEpoch],
    );
  }

  WeeklyReview? _fromRow(Map<String, Object?> data) {
    final stats = WeeklyStats.tryDecode(data['stats'] as String? ?? '');
    if (stats == null) return null;
    return WeeklyReview(
      weekStart: DateTime.fromMillisecondsSinceEpoch(data['week_start'] as int),
      stats: stats,
      rating: data['rating'] as int? ?? 0,
      wins: data['wins'] as String? ?? '',
      adjustments: data['adjustments'] as String? ?? '',
      intention: data['intention'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        data['created_at'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        data['updated_at'] as int? ?? 0,
      ),
    );
  }

  /// Measures the week starting at [weekStart] from every module.
  Future<WeeklyStats> computeStats(DateTime weekStart) async {
    final now = DateTime.now();
    final weekEnd = weekEndOf(weekStart);
    final dao = DriftDbService.instance.driftDb.dynamicRecordsDao;
    final today = DateTime(now.year, now.month, now.day);

    // Screen time: stored days from the database, today live from Android
    final usageByDay = <Map<String, int>>[];
    for (var i = 0; i < 7; i++) {
      final day = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
      if (day.isAfter(today)) {
        usageByDay.add(const {});
      } else if (day == today) {
        usageByDay.add(await _liveUsage(today, now));
      } else {
        final stored = await dao.fetchDatedAppsUsage(selectedDay: day);
        usageByDay.add(
          stored.map((package, usage) => MapEntry(package, usage.screenTime)),
        );
      }
    }

    // Compare like with like: a week in progress is measured against the same
    // number of days of the previous week
    final elapsedDays = weekEnd.isAfter(now)
        ? (today.difference(weekStart).inDays + 1).clamp(1, 7)
        : 7;
    final previousStart =
        DateTime(weekStart.year, weekStart.month, weekStart.day - 7);
    var previousTotal = 0;
    var hasPrevious = false;
    for (var i = 0; i < elapsedDays; i++) {
      final day =
          DateTime(previousStart.year, previousStart.month, previousStart.day + i);
      final stored = await dao.fetchDatedAppsUsage(selectedDay: day);
      if (stored.isNotEmpty) hasPrevious = true;
      previousTotal += stored.values.fold(0, (a, b) => a + b.screenTime);
    }

    final focus = await dao.fetchSessionsDurationForInterval(weekStart, weekEnd);
    final notifications =
        await dao.fetchNotificationsCountForInterval(weekStart, weekEnd);

    final productivity = ProductivityRepository.instance;
    final completions = await productivity.loadCompletions(weekStart, weekEnd);
    final tasks = await productivity.load(ProductivityItemType.task);
    final overdue = tasks
        .where(
          (task) =>
              !task.isCompleted &&
              task.dueAt != null &&
              task.dueAt!.isBefore(now),
        )
        .length;

    final systems =
        await SystemsRepository.instance.loadWeeklyVotes(weekStart, weekEnd);

    return WeeklyStats.aggregate(
      weekStart: weekStart,
      appsUsageByDay: usageByDay,
      previousScreenTime: hasPrevious ? previousTotal : null,
      focusSeconds: focus,
      notificationsCount: notifications.values.fold(0, (a, b) => a + b),
      systems: systems,
      completedTasks: completions
          .map((completion) => completion.title)
          .toList(),
      overdueTasks: overdue,
    );
  }

  Future<Map<String, int>> _liveUsage(DateTime start, DateTime end) async {
    try {
      final usage = await MethodChannelService.instance
          .fetchAppsUsageForInterval(start: start, end: end);
      return usage.map((package, value) => MapEntry(package, value.screenTime));
    } catch (error) {
      debugPrint('WeeklyReviewRepository: live usage unavailable: $error');
      return const {};
    }
  }
}
