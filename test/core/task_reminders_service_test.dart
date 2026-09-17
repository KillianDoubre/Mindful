import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/services/task_reminders_service.dart';

import '../helpers/test_env.dart';
import '../models/productivity_item_test.dart' show makeTask;

List<Map<String, dynamic>> lastScheduled() {
  final calls = callsTo('updateTaskReminders');
  expect(calls, isNotEmpty);
  return (jsonDecode(calls.last.arguments as String) as List)
      .cast<Map<String, dynamic>>();
}

void main() {
  group('formatReminderOffset', () {
    test('zero is the due time', () {
      expect(formatReminderOffset(0), 'À l’échéance');
    });

    test('minutes, hours and days', () {
      expect(formatReminderOffset(5), '5 min avant');
      expect(formatReminderOffset(60), '1 h avant');
      expect(formatReminderOffset(90), '1 h 30 avant');
      expect(formatReminderOffset(125), '2 h 05 avant');
      expect(formatReminderOffset(1440), '1 jour avant');
      expect(formatReminderOffset(2880), '2 jours avant');
      expect(formatReminderOffset(10080), '7 jours avant');
    });

    test('delay without "before" reads as a countdown', () {
      expect(formatReminderDelay(15, withBefore: false), 'dans 15 min');
      expect(formatReminderDelay(120, withBefore: false), 'dans 2 h');
      expect(formatReminderDelay(1440, withBefore: false), 'dans 1 jour');
    });
  });

  group('TaskRemindersService.sync', () {
    setUp(mockNativeChannel);

    test('schedules one alarm per upcoming reminder', () async {
      final due = DateTime.now().add(const Duration(days: 2));
      await TaskRemindersService.sync([
        makeTask(id: 3, title: 'Sport', dueAt: due, reminders: [0, 60]),
      ]);
      final scheduled = lastScheduled();
      expect(scheduled, hasLength(2));
      expect(scheduled.map((r) => r['taskId']), [3, 3]);
      expect(scheduled.map((r) => r['title']), ['Sport', 'Sport']);
      // Soonest first: one hour before, then at the due time
      expect(scheduled.first['atMs'],
          due.subtract(const Duration(minutes: 60)).millisecondsSinceEpoch);
      expect(scheduled.last['atMs'], due.millisecondsSinceEpoch);
    });

    test('ids are stable per task and slot', () async {
      final due = DateTime.now().add(const Duration(days: 1));
      await TaskRemindersService.sync([
        makeTask(id: 4, dueAt: due, reminders: [0, 30]),
      ]);
      expect(lastScheduled().map((r) => r['id']).toSet(), {400, 401});
    });

    test('skips completed tasks, tasks without date and past reminders',
        () async {
      final now = DateTime.now();
      await TaskRemindersService.sync([
        makeTask(
          id: 1,
          dueAt: now.add(const Duration(days: 1)),
          reminders: [0],
          isCompleted: true,
        ),
        makeTask(id: 2, reminders: [0]),
        makeTask(
          id: 3,
          dueAt: now.add(const Duration(minutes: 30)),
          reminders: [60, 10],
        ),
      ]);
      final scheduled = lastScheduled();
      expect(scheduled, hasLength(1));
      expect(scheduled.single['taskId'], 3);
    });

    test('sends an empty list when nothing is due', () async {
      await TaskRemindersService.sync([makeTask()]);
      expect(lastScheduled(), isEmpty);
    });

    test('caps the number of alarms', () async {
      final due = DateTime.now().add(const Duration(days: 3));
      await TaskRemindersService.sync([
        for (var i = 1; i <= 40; i++)
          makeTask(id: i, dueAt: due, reminders: [0, 10, 20]),
      ]);
      expect(lastScheduled(), hasLength(60));
    });

    test('body mentions the due time', () async {
      final due = DateTime.now().add(const Duration(days: 1));
      final time = '${due.hour.toString().padLeft(2, '0')}:'
          '${due.minute.toString().padLeft(2, '0')}';
      await TaskRemindersService.sync([
        makeTask(dueAt: due, reminders: [0, 60]),
      ]);
      final bodies = lastScheduled().map((r) => r['body'] as String).toList();
      expect(bodies.first, 'Échéance dans 1 h · à $time');
      expect(bodies.last, 'C’est l’heure · échéance à $time');
    });

    test('never throws when the native side fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(fgChannel, (_) async => throw Exception());
      await TaskRemindersService.sync([
        makeTask(
          dueAt: DateTime.now().add(const Duration(days: 1)),
          reminders: [0],
        ),
      ]);
    });
  });
}
