import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/models/task_recurrence.dart';

void main() {
  group('TaskRecurrence.fromDatabase', () {
    test('reads every stored value', () {
      for (final value in TaskRecurrence.values) {
        expect(TaskRecurrence.fromDatabase(value.databaseValue), value);
      }
    });

    test('falls back to none for unknown or missing values', () {
      expect(TaskRecurrence.fromDatabase(null), TaskRecurrence.none);
      expect(TaskRecurrence.fromDatabase('yearly'), TaskRecurrence.none);
    });

    test('only none does not repeat', () {
      expect(TaskRecurrence.none.isRepeating, isFalse);
      for (final value in TaskRecurrence.values.skip(1)) {
        expect(value.isRepeating, isTrue, reason: value.name);
      }
    });

    test('labels are French', () {
      expect(TaskRecurrence.none.label, 'Jamais');
      expect(TaskRecurrence.daily.label, 'Chaque jour');
      expect(TaskRecurrence.weekdays.label, 'En semaine');
      expect(TaskRecurrence.weekly.label, 'Chaque semaine');
      expect(TaskRecurrence.monthly.label, 'Chaque mois');
    });
  });

  group('TaskRecurrence.next', () {
    final wednesday = DateTime(2026, 9, 16, 18, 30);

    test('none keeps the date', () {
      expect(TaskRecurrence.none.next(wednesday), wednesday);
    });

    test('daily moves one day and keeps the time', () {
      expect(TaskRecurrence.daily.next(wednesday), DateTime(2026, 9, 17, 18, 30));
    });

    test('daily crosses month and year ends', () {
      expect(
        TaskRecurrence.daily.next(DateTime(2026, 12, 31, 9)),
        DateTime(2027, 1, 1, 9),
      );
    });

    test('weekly moves seven days', () {
      expect(TaskRecurrence.weekly.next(wednesday), DateTime(2026, 9, 23, 18, 30));
    });

    test('weekdays skip the weekend', () {
      // Thursday -> Friday
      expect(
        TaskRecurrence.weekdays.next(DateTime(2026, 9, 17, 8)),
        DateTime(2026, 9, 18, 8),
      );
      // Friday -> Monday
      expect(
        TaskRecurrence.weekdays.next(DateTime(2026, 9, 18, 8)),
        DateTime(2026, 9, 21, 8),
      );
      // Saturday -> Monday
      expect(
        TaskRecurrence.weekdays.next(DateTime(2026, 9, 19, 8)),
        DateTime(2026, 9, 21, 8),
      );
      // Sunday -> Monday
      expect(
        TaskRecurrence.weekdays.next(DateTime(2026, 9, 20, 8)),
        DateTime(2026, 9, 21, 8),
      );
    });

    test('weekdays always land on a weekday', () {
      var date = DateTime(2026, 1, 1, 7);
      for (var i = 0; i < 60; i++) {
        date = TaskRecurrence.weekdays.next(date);
        expect(date.weekday, lessThanOrEqualTo(DateTime.friday));
      }
    });

    test('monthly keeps the day of month', () {
      expect(
        TaskRecurrence.monthly.next(DateTime(2026, 9, 15, 10)),
        DateTime(2026, 10, 15, 10),
      );
    });

    test('monthly clamps to the last day of shorter months', () {
      expect(
        TaskRecurrence.monthly.next(DateTime(2026, 1, 31, 10)),
        DateTime(2026, 2, 28, 10),
      );
      expect(
        TaskRecurrence.monthly.next(DateTime(2028, 1, 31, 10)),
        DateTime(2028, 2, 29, 10),
      );
      expect(
        TaskRecurrence.monthly.next(DateTime(2026, 3, 31, 10)),
        DateTime(2026, 4, 30, 10),
      );
    });

    test('monthly crosses the year', () {
      expect(
        TaskRecurrence.monthly.next(DateTime(2026, 12, 15, 10)),
        DateTime(2027, 1, 15, 10),
      );
    });

    test('keeps the wall-clock time across daylight saving changes', () {
      // Europe switches to summer time on the last Sunday of March
      var date = DateTime(2026, 3, 27, 21, 15);
      for (var i = 0; i < 5; i++) {
        date = TaskRecurrence.daily.next(date);
        expect(date.hour, 21);
        expect(date.minute, 15);
      }
    });
  });

  group('TaskRecurrence.nextAfter', () {
    final now = DateTime(2026, 9, 16, 12);

    test('returns the due date for a non repeating task', () {
      final due = DateTime(2026, 9, 1);
      expect(TaskRecurrence.none.nextAfter(due, now), due);
    });

    test('moves a future due date by one occurrence', () {
      expect(
        TaskRecurrence.daily.nextAfter(DateTime(2026, 9, 20, 9), now),
        DateTime(2026, 9, 21, 9),
      );
    });

    test('skips every occurrence already in the past', () {
      final next = TaskRecurrence.daily.nextAfter(DateTime(2026, 9, 1, 9), now);
      expect(next, DateTime(2026, 9, 17, 9));
      expect(next.isAfter(now), isTrue);
    });

    test('a task due earlier today moves to tomorrow', () {
      expect(
        TaskRecurrence.daily.nextAfter(DateTime(2026, 9, 16, 8), now),
        DateTime(2026, 9, 17, 8),
      );
    });

    test('a task due later today still moves forward once', () {
      expect(
        TaskRecurrence.daily.nextAfter(DateTime(2026, 9, 16, 18), now),
        DateTime(2026, 9, 17, 18),
      );
    });

    test('weekly catches up by whole weeks', () {
      final next =
          TaskRecurrence.weekly.nextAfter(DateTime(2026, 8, 3, 9), now);
      expect(next.weekday, DateTime.monday);
      expect(next, DateTime(2026, 9, 21, 9));
    });

    test('very old dates still resolve after now', () {
      final next =
          TaskRecurrence.daily.nextAfter(DateTime(2020, 1, 1, 9), now);
      expect(next.isAfter(now), isTrue);
    });
  });
}
