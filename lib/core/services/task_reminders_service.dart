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
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/models/productivity_item.dart';

/// Turns task reminder offsets into concrete alarms on the native side.
class TaskRemindersService {
  TaskRemindersService._();

  /// Alarms beyond this count are scheduled on a later sync.
  static const _maxScheduled = 60;

  /// Reschedules every upcoming reminder of [tasks].
  static Future<void> sync(List<ProductivityItem> tasks) async {
    try {
      final now = DateTime.now();
      final reminders = <(DateTime, Map<String, Object>)>[];
      for (final task in tasks) {
        final due = task.dueAt;
        if (task.isCompleted || due == null) continue;
        for (final offset in task.reminderOffsets) {
          final at = due.subtract(Duration(minutes: offset));
          if (!at.isAfter(now)) continue;
          reminders.add((
            at,
            {
              // Stable per task and offset slot
              'id': task.id * 100 + task.reminderOffsets.indexOf(offset),
              'taskId': task.id,
              'title': task.title,
              'body': _body(offset, due),
              'atMs': at.millisecondsSinceEpoch,
            },
          ));
        }
      }
      reminders.sort((a, b) => a.$1.compareTo(b.$1));
      await MethodChannelService.instance.updateTaskReminders(
        reminders.take(_maxScheduled).map((entry) => entry.$2).toList(),
      );
    } catch (error) {
      debugPrint('TaskRemindersService.sync failed: $error');
    }
  }

  static String _body(int offset, DateTime due) {
    final time = '${due.hour.toString().padLeft(2, '0')}:'
        '${due.minute.toString().padLeft(2, '0')}';
    if (offset == 0) return 'C’est l’heure · échéance à $time';
    return 'Échéance ${formatReminderDelay(offset, withBefore: false)} · à $time';
  }
}

/// "15 min avant", "2 h avant", "1 jour avant"… (0 = at the due time).
String formatReminderOffset(int minutes) =>
    minutes == 0 ? 'À l’échéance' : formatReminderDelay(minutes);

String formatReminderDelay(int minutes, {bool withBefore = true}) {
  final suffix = withBefore ? ' avant' : '';
  final prefix = withBefore ? '' : 'dans ';
  if (minutes % 1440 == 0) {
    final days = minutes ~/ 1440;
    return '$prefix$days jour${days > 1 ? 's' : ''}$suffix';
  }
  if (minutes % 60 == 0) return '$prefix${minutes ~/ 60} h$suffix';
  if (minutes > 60) {
    return '$prefix${minutes ~/ 60} h ${(minutes % 60).toString().padLeft(2, '0')}$suffix';
  }
  return '$prefix$minutes min$suffix';
}
