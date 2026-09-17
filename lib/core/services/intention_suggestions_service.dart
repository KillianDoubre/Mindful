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
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/core/services/productivity_repository.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/models/productivity_item.dart';

/// Keeps the conscious-opening prompt supplied with something better to do:
/// the most pressing task and the systems that can be worked on.
///
/// The native overlay cannot read the database, so the choice is pushed to it
/// whenever tasks or systems change.
class IntentionSuggestionsService {
  IntentionSuggestionsService._();

  /// The task to suggest: the pending one due soonest (overdue first), or the
  /// first pending one in the user's order when none has a due date.
  static ProductivityItem? pickTask(List<ProductivityItem> tasks) {
    final pending = tasks.where((task) => !task.isCompleted).toList();
    if (pending.isEmpty) return null;
    final dated = pending.where((task) => task.dueAt != null).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    if (dated.isNotEmpty) return dated.first;
    return pending.reduce((a, b) => a.sortOrder <= b.sortOrder ? a : b);
  }

  /// Systems worth a nudge: running ones with at least one victory.
  static List<LifeSystem> pickSystems(List<LifeSystem> systems) => systems
      .where((system) => system.isPlayable && system.victories.isNotEmpty)
      .toList();

  /// "En retard · 18:00", "Aujourd’hui · 18:00", "Demain · 09:30"…
  static String dueLabel(DateTime due, DateTime now) {
    final time = '${due.hour.toString().padLeft(2, '0')}:'
        '${due.minute.toString().padLeft(2, '0')}';
    if (due.isBefore(now)) return 'En retard · échéance $time';
    final days = DateTime(due.year, due.month, due.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return switch (days) {
      0 => 'Aujourd’hui · $time',
      1 => 'Demain · $time',
      _ => 'Dans $days jours · $time',
    };
  }

  static Map<String, Object?> buildPayload({
    required List<ProductivityItem> tasks,
    required List<LifeSystem> systems,
    required DateTime now,
  }) {
    final task = pickTask(tasks);
    return {
      'task': task == null
          ? null
          : {
              'id': task.id,
              'title': task.title,
              'isUrgent': task.dueAt != null,
              'dueLabel': task.dueAt == null ? '' : dueLabel(task.dueAt!, now),
            },
      'systems': [
        for (final system in pickSystems(systems))
          {
            'id': system.id,
            'name': system.name,
            'identity': system.identity.trim(),
          },
      ],
    };
  }

  /// Recomputes the suggestions from the database and sends them.
  static Future<void> push() async {
    try {
      final tasks =
          await ProductivityRepository.instance.load(ProductivityItemType.task);
      final systems = await SystemsRepository.instance.loadSystems();
      await MethodChannelService.instance.updateIntentionSuggestions(
        jsonEncode(
          buildPayload(tasks: tasks, systems: systems, now: DateTime.now()),
        ),
      );
    } catch (error) {
      debugPrint('IntentionSuggestionsService.push failed: $error');
    }
  }
}
