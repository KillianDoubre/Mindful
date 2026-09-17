import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/models/weekly_review.dart';

final monday = DateTime(2026, 9, 14);

WeeklyStats stats({
  List<Map<String, int>>? usage,
  int? previous,
  List<SystemWeekVotes> systems = const [],
  List<String> tasks = const [],
}) =>
    WeeklyStats.aggregate(
      weekStart: monday,
      appsUsageByDay: usage ?? const [],
      previousScreenTime: previous,
      focusSeconds: 1800,
      notificationsCount: 12,
      systems: systems,
      completedTasks: tasks,
      overdueTasks: 2,
    );

void main() {
  group('week boundaries', () {
    test('weekStartOf returns the Monday at midnight', () {
      expect(weekStartOf(DateTime(2026, 9, 16, 15, 30)), monday);
      expect(weekStartOf(DateTime(2026, 9, 14)), monday);
      expect(weekStartOf(DateTime(2026, 9, 20, 23, 59)), monday);
    });

    test('weekStartOf handles month and year changes', () {
      expect(weekStartOf(DateTime(2026, 10, 1)), DateTime(2026, 9, 28));
      expect(weekStartOf(DateTime(2027, 1, 2)), DateTime(2026, 12, 28));
    });

    test('weekEndOf is the next Monday', () {
      expect(weekEndOf(monday), DateTime(2026, 9, 21));
      expect(weekEndOf(DateTime(2026, 12, 28)), DateTime(2027, 1, 4));
    });
  });

  group('WeeklyStats.aggregate', () {
    test('sums screen time per day and per app', () {
      final result = stats(usage: [
        {'yt': 3600, 'ig': 600},
        {'yt': 1200},
        {},
        {'ig': 300, 'wa': 60},
      ]);
      expect(result.dailyScreenTime, [4200, 1200, 0, 360, 0, 0, 0]);
      expect(result.screenTime, 5760);
      expect(result.topApps.map((a) => a.packageName), ['yt', 'ig', 'wa']);
      expect(result.topApps.first.seconds, 4800);
    });

    test('keeps only the top five apps', () {
      final result = stats(usage: [
        {for (var i = 0; i < 9; i++) 'app$i': (i + 1) * 60},
      ]);
      expect(result.topApps, hasLength(WeeklyStats.topAppsCount));
      expect(result.topApps.first.packageName, 'app8');
    });

    test('ignores zero or negative usage and extra days', () {
      final result = stats(usage: [
        {'a': 0, 'b': -30, 'c': 10},
        for (var i = 0; i < 8; i++) {'d': 100},
      ]);
      expect(result.dailyScreenTime.first, 10);
      expect(result.dailyScreenTime, hasLength(7));
      expect(result.screenTime, 10 + 6 * 100);
      expect(result.topApps.map((a) => a.packageName), isNot(contains('b')));
    });

    test('sorts systems by votes', () {
      final result = stats(systems: const [
        SystemWeekVotes(systemId: 1, name: 'A', votes: 2, activeDays: 2),
        SystemWeekVotes(systemId: 2, name: 'B', votes: 9, activeDays: 5),
      ]);
      expect(result.systems.map((s) => s.name), ['B', 'A']);
      expect(result.totalVotes, 11);
    });
  });

  group('trend and averages', () {
    test('trend is null without a comparable previous week', () {
      expect(stats(previous: null).screenTimeTrend, isNull);
      expect(stats(previous: 0).screenTimeTrend, isNull);
    });

    test('trend is the relative change', () {
      final lower = stats(usage: [{'a': 50}], previous: 100);
      expect(lower.screenTimeTrend, closeTo(-0.5, 1e-9));
      final higher = stats(usage: [{'a': 150}], previous: 100);
      expect(higher.screenTimeTrend, closeTo(0.5, 1e-9));
    });

    test('average divides by elapsed days of the week', () {
      final result = stats(usage: [
        {'a': 300},
        {'a': 300},
        {'a': 300},
      ]);
      expect(result.averageDailyScreenTime(DateTime(2026, 9, 16, 20)), 300);
      expect(result.averageDailyScreenTime(DateTime(2026, 9, 14, 1)), 900);
      expect(result.averageDailyScreenTime(DateTime(2026, 10, 1)), 900 ~/ 7);
    });
  });

  group('serialisation', () {
    test('json round trip keeps everything', () {
      final original = stats(
        usage: [
          {'yt': 100},
          {'ig': 50},
        ],
        previous: 400,
        systems: const [
          SystemWeekVotes(systemId: 3, name: 'Lecture', votes: 4, activeDays: 3),
        ],
        tasks: const ['Courses', 'Sport'],
      );
      final copy = WeeklyStats.tryDecode(original.encode())!;
      expect(copy.weekStart, original.weekStart);
      expect(copy.dailyScreenTime, original.dailyScreenTime);
      expect(copy.topApps.map((a) => a.toJson()),
          original.topApps.map((a) => a.toJson()));
      expect(copy.previousScreenTime, 400);
      expect(copy.focusSeconds, 1800);
      expect(copy.notificationsCount, 12);
      expect(copy.systems.single.name, 'Lecture');
      expect(copy.systems.single.activeDays, 3);
      expect(copy.completedTasks, ['Courses', 'Sport']);
      expect(copy.overdueTasks, 2);
    });

    test('tryDecode rejects garbage', () {
      expect(WeeklyStats.tryDecode(''), isNull);
      expect(WeeklyStats.tryDecode('not json'), isNull);
      expect(WeeklyStats.tryDecode('[1,2]'), isNull);
    });

    test('fromJson pads a short day list and tolerates missing keys', () {
      final parsed = WeeklyStats.fromJson({
        'daily': [10, 20],
      });
      expect(parsed.dailyScreenTime, [10, 20, 0, 0, 0, 0, 0]);
      expect(parsed.topApps, isEmpty);
      expect(parsed.systems, isEmpty);
      expect(parsed.previousScreenTime, isNull);
    });
  });

  group('formatting', () {
    test('formatWeekRange within a month', () {
      expect(formatWeekRange(monday), '14 – 20 sept.');
    });

    test('formatWeekRange across months', () {
      expect(formatWeekRange(DateTime(2026, 9, 28)), '28 sept. – 4 oct.');
    });

    test('formatSeconds', () {
      expect(formatSeconds(0), '0 min');
      expect(formatSeconds(59), '0 min');
      expect(formatSeconds(45 * 60), '45 min');
      expect(formatSeconds(3600), '1 h');
      expect(formatSeconds(3600 + 5 * 60), '1 h 05');
      expect(formatSeconds(13 * 3600 + 21 * 60), '13 h 21');
    });
  });
}
