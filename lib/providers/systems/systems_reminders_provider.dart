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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/systems_reminder.dart';

final systemsRemindersProvider =
    StateNotifierProvider<SystemsRemindersNotifier, SystemsRemindersConfig>(
  (ref) => SystemsRemindersNotifier(),
);

class SystemsRemindersNotifier extends StateNotifier<SystemsRemindersConfig> {
  SystemsRemindersNotifier() : super(SystemsRemindersConfig.defaults()) {
    _load();
  }

  final SystemsRepository _repository = SystemsRepository.instance;

  Future<void> _load() async {
    try {
      state = await _repository.loadRemindersConfig();
    } catch (error, stackTrace) {
      debugPrint('SystemsRepository.loadRemindersConfig failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Persists the new configuration and pushes it to the native scheduler.
  Future<void> _update(SystemsRemindersConfig config) async {
    state = config;
    await _repository.saveRemindersConfig(config);
    await MethodChannelService.instance.updateSystemsReminders(config);
  }

  Future<void> setDailyEnabled(bool value) =>
      _update(state.copyWith(daily: state.daily.copyWith(isEnabled: value)));

  Future<void> setDailyTime(TimeOfDayAdapter time) =>
      _update(state.copyWith(daily: state.daily.copyWith(time: time)));

  Future<void> toggleDailyDay(int index) =>
      _update(state.copyWith(daily: state.daily.toggleDay(index)));

  Future<void> setWeeklyEnabled(bool value) =>
      _update(state.copyWith(weekly: state.weekly.copyWith(isEnabled: value)));

  Future<void> setWeeklyTime(TimeOfDayAdapter time) =>
      _update(state.copyWith(weekly: state.weekly.copyWith(time: time)));

  Future<void> toggleWeeklyDay(int index) =>
      _update(state.copyWith(weekly: state.weekly.toggleDay(index)));
}
