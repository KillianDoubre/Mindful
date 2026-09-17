import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/services/intention_suggestions_service.dart';
import 'package:mindful/models/life_system.dart';

import '../models/life_system_test.dart' show system, victory;
import '../models/productivity_item_test.dart' show makeTask;

void main() {
  final now = DateTime(2026, 9, 16, 12);

  group('pickTask', () {
    test('nothing to suggest without pending tasks', () {
      expect(IntentionSuggestionsService.pickTask([]), isNull);
      expect(
        IntentionSuggestionsService.pickTask([makeTask(isCompleted: true)]),
        isNull,
      );
    });

    test('prefers the task due soonest, overdue included', () {
      final picked = IntentionSuggestionsService.pickTask([
        makeTask(id: 1, dueAt: DateTime(2026, 9, 20)),
        makeTask(id: 2, dueAt: DateTime(2026, 9, 10)),
        makeTask(id: 3),
        makeTask(id: 4, dueAt: DateTime(2026, 9, 1), isCompleted: true),
      ]);
      expect(picked?.id, 2);
    });

    test('falls back to the first task in the user order', () {
      final picked = IntentionSuggestionsService.pickTask([
        makeTask(id: 1, sortOrder: 5),
        makeTask(id: 2, sortOrder: 1),
        makeTask(id: 3, sortOrder: 3),
      ]);
      expect(picked?.id, 2);
    });
  });

  group('pickSystems', () {
    test('keeps running systems that have victories', () {
      final withVictory = [victory()];
      final picked = IntentionSuggestionsService.pickSystems([
        system(victories: withVictory),
        system(victories: withVictory, status: LifeSystemStatus.maintenance),
        system(victories: withVictory, status: LifeSystemStatus.paused),
        system(victories: withVictory, status: LifeSystemStatus.archived),
        system(),
      ]);
      expect(picked, hasLength(2));
    });
  });

  group('dueLabel', () {
    test('overdue', () {
      expect(
        IntentionSuggestionsService.dueLabel(DateTime(2026, 9, 16, 9), now),
        'En retard · échéance 09:00',
      );
    });

    test('later today, tomorrow and later', () {
      expect(
        IntentionSuggestionsService.dueLabel(DateTime(2026, 9, 16, 18), now),
        'Aujourd’hui · 18:00',
      );
      expect(
        IntentionSuggestionsService.dueLabel(DateTime(2026, 9, 17, 7, 5), now),
        'Demain · 07:05',
      );
      expect(
        IntentionSuggestionsService.dueLabel(DateTime(2026, 9, 20, 10), now),
        'Dans 4 jours · 10:00',
      );
    });
  });

  group('buildPayload', () {
    test('describes the task and every playable system', () {
      final payload = IntentionSuggestionsService.buildPayload(
        tasks: [makeTask(id: 9, title: 'Appeler', dueAt: DateTime(2026, 9, 16, 18))],
        systems: [system(victories: [victory()])],
        now: now,
      );
      final task = payload['task'] as Map<String, Object?>;
      expect(task['id'], 9);
      expect(task['title'], 'Appeler');
      expect(task['isUrgent'], isTrue);
      expect(task['dueLabel'], 'Aujourd’hui · 18:00');
      final systems = payload['systems'] as List;
      expect(systems.single, {
        'id': 1,
        'name': 'Lecture',
        'identity': 'lit chaque jour',
      });
    });

    test('an undated task is not urgent and has no label', () {
      final payload = IntentionSuggestionsService.buildPayload(
        tasks: [makeTask()],
        systems: const [],
        now: now,
      );
      final task = payload['task'] as Map<String, Object?>;
      expect(task['isUrgent'], isFalse);
      expect(task['dueLabel'], '');
      expect(payload['systems'], isEmpty);
    });

    test('no task gives a null entry', () {
      final payload = IntentionSuggestionsService.buildPayload(
        tasks: const [],
        systems: const [],
        now: now,
      );
      expect(payload['task'], isNull);
    });
  });
}
