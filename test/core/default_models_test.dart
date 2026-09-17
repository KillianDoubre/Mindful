import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/utils/default_models_utils.dart';
import 'package:mindful/models/notification_schedule.dart';

NotificationSchedule schedule(String label, int minutes) => NotificationSchedule(
      label: label,
      time: TimeOfDayAdapter.fromMinutes(minutes),
      isActive: true,
    );

void main() {
  group('frenchifyScheduleLabels', () {
    test('renames the old English defaults', () {
      final result = frenchifyScheduleLabels([
        schedule('Morning', 480),
        schedule('Afternoon', 720),
        schedule('Evening', 960),
        schedule('Night', 1260),
      ]);
      expect(result.map((s) => s.label), ['Matin', 'Midi', 'Soir', 'Nuit']);
      expect(result.map((s) => s.time.toMinutes), [480, 720, 960, 1260]);
      expect(result.every((s) => s.isActive), isTrue);
    });

    test('keeps custom names', () {
      final result = frenchifyScheduleLabels([
        schedule('Morning', 480),
        schedule('Pause café', 600),
      ]);
      expect(result.map((s) => s.label), ['Matin', 'Pause café']);
    });

    test('returns the very same list when nothing changes', () {
      final schedules = [schedule('Matin', 480)];
      expect(identical(frenchifyScheduleLabels(schedules), schedules), isTrue);
      final empty = <NotificationSchedule>[];
      expect(identical(frenchifyScheduleLabels(empty), empty), isTrue);
    });
  });

  test('new installs get French schedule names', () {
    final labels =
        defaultNotificationSettingsModel.schedules.map((s) => s.label).toList();
    expect(labels, isNotEmpty);
    for (final label in labels) {
      expect(legacyScheduleLabels.containsKey(label), isFalse, reason: label);
    }
  });
}
