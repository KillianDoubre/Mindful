import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/ui/screens/productivity/task_due.dart';

import '../helpers/test_env.dart';

void main() {
  group('DueShortcut.dayFrom', () {
    final wednesday = DateTime(2026, 9, 16, 15);

    test('today and tomorrow', () {
      expect(DueShortcut.today.dayFrom(wednesday), DateTime(2026, 9, 16));
      expect(DueShortcut.tomorrow.dayFrom(wednesday), DateTime(2026, 9, 17));
    });

    test('weekend is the coming Saturday', () {
      expect(DueShortcut.weekend.dayFrom(wednesday), DateTime(2026, 9, 19));
      expect(
        DueShortcut.weekend.dayFrom(DateTime(2026, 9, 18)),
        DateTime(2026, 9, 19),
      );
    });

    test('during the weekend, weekend means today', () {
      expect(
        DueShortcut.weekend.dayFrom(DateTime(2026, 9, 19, 10)),
        DateTime(2026, 9, 19),
      );
      expect(
        DueShortcut.weekend.dayFrom(DateTime(2026, 9, 20, 10)),
        DateTime(2026, 9, 20),
      );
    });

    test('next week is the coming Monday', () {
      expect(DueShortcut.nextWeek.dayFrom(wednesday), DateTime(2026, 9, 21));
      expect(
        DueShortcut.nextWeek.dayFrom(DateTime(2026, 9, 20)),
        DateTime(2026, 9, 21),
      );
      expect(
        DueShortcut.nextWeek.dayFrom(DateTime(2026, 9, 21)),
        DateTime(2026, 9, 28),
      );
    });
  });

  group('DueShortcut.resolve', () {
    final now = DateTime(2026, 9, 16, 15);

    test('uses the default hour for a new due date', () {
      expect(
        DueShortcut.tomorrow.resolve(now, null),
        DateTime(2026, 9, 17, defaultDueHour),
      );
    });

    test('keeps the time already chosen', () {
      expect(
        DueShortcut.today.resolve(now, DateTime(2026, 1, 1, 7, 45)),
        DateTime(2026, 9, 16, 7, 45),
      );
    });

    test('matches only its own day', () {
      final today = DateTime.now();
      expect(DueShortcut.today.matches(today), isTrue);
      expect(DueShortcut.tomorrow.matches(today), isFalse);
      expect(
        DueShortcut.tomorrow.matches(today.add(const Duration(days: 1))),
        isTrue,
      );
    });
  });

  group('DueGroup.of', () {
    final now = DateTime(2026, 9, 16, 12);

    test('classifies due dates', () {
      expect(DueGroup.of(null, now), DueGroup.none);
      expect(DueGroup.of(DateTime(2026, 9, 16, 9), now), DueGroup.overdue);
      expect(DueGroup.of(DateTime(2026, 9, 1), now), DueGroup.overdue);
      expect(DueGroup.of(DateTime(2026, 9, 16, 18), now), DueGroup.today);
      expect(DueGroup.of(DateTime(2026, 9, 17, 8), now), DueGroup.tomorrow);
      expect(DueGroup.of(DateTime(2026, 9, 30), now), DueGroup.later);
    });

    test('groups are listed most urgent first with French labels', () {
      expect(DueGroup.values.map((g) => g.label), [
        'En retard',
        'Aujourd’hui',
        'Demain',
        'Plus tard',
        'Sans échéance',
      ]);
    });
  });

  group('display helpers', () {
    Future<BuildContext> pumpContext(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            captured = context;
            return const SizedBox();
          }),
        ),
      );
      return captured;
    }

    testWidgets('formatDue names close days', (tester) async {
      final context = await pumpContext(tester);
      final today = dayOffset(0).add(const Duration(hours: 18));
      expect(formatDue(context, today), startsWith('Aujourd’hui · '));
      expect(
        formatDue(context, today.add(const Duration(days: 1))),
        startsWith('Demain · '),
      );
      expect(
        formatDue(context, today.subtract(const Duration(days: 1))),
        startsWith('Hier · '),
      );
    });

    testWidgets('dueColor reflects urgency', (tester) async {
      final context = await pumpContext(tester);
      final colors = Theme.of(context).colorScheme;
      final past = DateTime.now().subtract(const Duration(hours: 1));
      expect(dueColor(context, past, isCompleted: false), colors.error);
      expect(dueColor(context, past, isCompleted: true),
          colors.onSurfaceVariant);
      expect(
        dueColor(context, DateTime.now().add(const Duration(days: 5)),
            isCompleted: false),
        colors.tertiary,
      );
    });
  });
}
