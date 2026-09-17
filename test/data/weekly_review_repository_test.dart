import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/enums/session_state.dart';
import 'package:mindful/core/enums/session_type.dart';
import 'package:mindful/core/services/productivity_repository.dart';
import 'package:mindful/core/services/weekly_review_repository.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/models/weekly_review.dart';

import '../helpers/test_env.dart';

WeeklyStats emptyStats(DateTime weekStart, {int focus = 0}) =>
    WeeklyStats.aggregate(
      weekStart: weekStart,
      appsUsageByDay: const [],
      previousScreenTime: null,
      focusSeconds: focus,
      notificationsCount: 0,
      systems: const [],
      completedTasks: const [],
      overdueTasks: 0,
    );

void main() {
  late AppDatabase db;
  final repository = WeeklyReviewRepository.instance;

  setUpAll(() {
    mockNativeChannel({
      'getAppsUsageForInterval': (_) => [
            {
              'packageName': 'com.live.app',
              'screenTime': 600,
              'mobileData': 0,
              'wifiData': 0,
            },
          ],
    });
    db = useInMemoryDatabase();
  });

  setUp(() async {
    await repository.loadAll();
    await ProductivityRepository.instance.load(ProductivityItemType.task);
    await clearTables(db, [
      'weekly_reviews',
      'productivity_items',
      'task_completions',
      'app_usage_table',
      'focus_sessions_table',
    ]);
  });

  tearDownAll(() => db.close());

  group('saved reviews', () {
    final week = DateTime(2026, 9, 7);

    test('save then load', () async {
      await repository.save(
        stats: emptyStats(week, focus: 900),
        rating: 4,
        wins: ' Lu tous les jours ',
        adjustments: 'Moins de YouTube',
        intention: 'Courir deux fois',
      );
      final review = (await repository.load(week))!;
      expect(review.weekStart, week);
      expect(review.rating, 4);
      expect(review.wins, 'Lu tous les jours');
      expect(review.adjustments, 'Moins de YouTube');
      expect(review.intention, 'Courir deux fois');
      expect(review.stats.focusSeconds, 900);
    });

    test('saving again updates the same week', () async {
      await repository.save(
        stats: emptyStats(week),
        rating: 2,
        wins: '',
        adjustments: '',
        intention: 'A',
      );
      final first = (await repository.load(week))!;
      await repository.save(
        stats: emptyStats(week, focus: 60),
        rating: 5,
        wins: '',
        adjustments: '',
        intention: 'B',
      );
      final reviews = await repository.loadAll();
      expect(reviews, hasLength(1));
      expect(reviews.single.intention, 'B');
      expect(reviews.single.rating, 5);
      expect(reviews.single.stats.focusSeconds, 60);
      expect(reviews.single.createdAt, first.createdAt);
    });

    test('rating is kept between 0 and 5', () async {
      await repository.save(
        stats: emptyStats(week),
        rating: 12,
        wins: '',
        adjustments: '',
        intention: '',
      );
      expect((await repository.load(week))!.rating, 5);
    });

    test('history is newest first', () async {
      for (final start in [
        DateTime(2026, 8, 24),
        DateTime(2026, 9, 7),
        DateTime(2026, 8, 31),
      ]) {
        await repository.save(
          stats: emptyStats(start),
          rating: 0,
          wins: '',
          adjustments: '',
          intention: '',
        );
      }
      expect((await repository.loadAll()).map((r) => r.weekStart), [
        DateTime(2026, 9, 7),
        DateTime(2026, 8, 31),
        DateTime(2026, 8, 24),
      ]);
    });

    test('delete and missing weeks', () async {
      await repository.save(
        stats: emptyStats(week),
        rating: 0,
        wins: '',
        adjustments: '',
        intention: '',
      );
      await repository.delete(week);
      expect(await repository.load(week), isNull);
      expect(await repository.loadAll(), isEmpty);
    });

    test('a corrupted snapshot is skipped', () async {
      await db.customStatement(
        '''INSERT INTO weekly_reviews
           (week_start, stats, created_at, updated_at) VALUES (?, ?, ?, ?)''',
        [week.millisecondsSinceEpoch, 'oops', 0, 0],
      );
      expect(await repository.load(week), isNull);
      expect(await repository.loadAll(), isEmpty);
    });
  });

  group('computeStats', () {
    Future<void> usage(DateTime day, String package, int seconds) =>
        db.dynamicRecordsDao.insertBatchAppUsages([
          AppUsageTableCompanion.insert(
            packageName: package,
            date: Value(day),
            screenTime: Value(seconds),
          ),
        ]);

    test('gathers a past week from every module', () async {
      final week = weekStartOf(DateTime.now().subtract(const Duration(days: 14)));
      final previous = DateTime(week.year, week.month, week.day - 7);

      await usage(week, 'yt', 3600);
      await usage(DateTime(week.year, week.month, week.day + 2), 'ig', 1200);
      await usage(DateTime(week.year, week.month, week.day + 2), 'yt', 600);
      await usage(previous, 'yt', 9000);

      final session = await db.dynamicRecordsDao.insertFocusSession(
        type: SessionType.study,
        durationSecs: 1500,
      );
      await db.dynamicRecordsDao.updateFocusSessionById(
        session.copyWith(
          state: SessionState.successful,
          startDateTime: DateTime(week.year, week.month, week.day + 1, 9),
        ),
      );

      final tasks = ProductivityRepository.instance;
      final taskId = await tasks.save(
        type: ProductivityItemType.task,
        draft: ProductivityItemDraft(
          title: 'En retard',
          dueAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );
      final task = (await tasks.load(ProductivityItemType.task))
          .singleWhere((t) => t.id == taskId);
      await tasks.logCompletion(
        task,
        at: DateTime(week.year, week.month, week.day + 3, 10),
      );
      await tasks.logCompletion(task, at: DateTime.now());

      final stats = await repository.computeStats(week);

      expect(stats.weekStart, week);
      expect(stats.dailyScreenTime[0], 3600);
      expect(stats.dailyScreenTime[2], 1800);
      expect(stats.screenTime, 5400);
      expect(stats.topApps.map((a) => a.packageName), ['yt', 'ig']);
      expect(stats.previousScreenTime, 9000);
      expect(stats.screenTimeTrend, closeTo(-0.4, 1e-9));
      expect(stats.focusSeconds, 1500);
      expect(stats.completedTasks, ['En retard']);
      expect(stats.overdueTasks, 1);
    });

    test('no previous data means no comparison', () async {
      final week = weekStartOf(DateTime.now().subtract(const Duration(days: 21)));
      await usage(week, 'yt', 60);
      final stats = await repository.computeStats(week);
      expect(stats.previousScreenTime, isNull);
      expect(stats.screenTimeTrend, isNull);
    });

    test('the current week reads today live from Android', () async {
      final week = weekStartOf(DateTime.now());
      final stats = await repository.computeStats(week);
      final todayIndex = DateTime.now().difference(week).inDays;
      expect(stats.dailyScreenTime[todayIndex], 600);
      expect(stats.topApps.single.packageName, 'com.live.app');
      expect(callsTo('getAppsUsageForInterval'), isNotEmpty);
    });
  });
}
