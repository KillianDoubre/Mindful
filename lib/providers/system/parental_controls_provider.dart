/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/extensions/ext_date_time.dart';
import 'package:mindful/core/services/drift_db_service.dart';
import 'package:mindful/core/utils/default_models_utils.dart';

/// A Riverpod state notifier provider that manages [ParentalControls]
final parentalControlsProvider =
    StateNotifierProvider<ParentalControlsNotifier, ParentalControls>(
  (ref) => ParentalControlsNotifier(),
);

class ParentalControlsNotifier extends StateNotifier<ParentalControls> {
  /// Shared daily "modification window" during which the user is allowed to
  /// weaken protections (uninstall Mindful and edit invincible-mode / restriction
  /// settings). Uninstall and invincible mode now share the same start and end.
  ///
  /// To avoid a database schema migration, the two existing [TimeOfDay] columns
  /// are reused: `uninstallWindowTime` = window START, `invincibleWindowTime` =
  /// window END.
  TimeOfDayAdapter get windowStartTime => state.uninstallWindowTime;
  TimeOfDayAdapter get windowEndTime => state.invincibleWindowTime;

  /// Returns `TRUE` when the current time is inside the shared window.
  ///
  /// When start == end the window is treated as unset and always open, so the
  /// user can never lock themselves out (e.g. on the zero/zero default).
  bool get isBetweenWindow =>
      state.uninstallWindowTime.toMinutes == state.invincibleWindowTime.toMinutes
          ? true
          : DateTime.now().isBetweenTod(
              state.uninstallWindowTime,
              state.invincibleWindowTime,
            );

  /// Kept for the existing call sites that gate uninstalling / editing
  /// restrictions — both now resolve to the shared [isBetweenWindow].
  bool get isBetweenUninstallWindow => isBetweenWindow;
  bool get isBetweenInvincibleWindow => isBetweenWindow;

  ParentalControlsNotifier() : super(defaultParentalControlsModel) {
    init();
  }

  /// Initializes the settings state by loading from the database and setting up a listener for saving changes.
  Future<ParentalControls> init() async {
    final dao = DriftDbService.instance.driftDb.uniqueRecordsDao;
    state = await dao.loadParentalControls();

    /// Listen to provider and save changes to Isar database
    addListener(
      fireImmediately: false,
      (state) => dao.saveParentalControls(state),
    );

    return state;
  }

  /// Switch protected access
  void switchProtectedAccess() =>
      state = state.copyWith(protectedAccess: !state.protectedAccess);

  /// Changes the shared modification window START time.
  void changeWindowStartTime(TimeOfDayAdapter time) =>
      state = state.copyWith(uninstallWindowTime: time);

  /// Changes the shared modification window END time.
  void changeWindowEndTime(TimeOfDayAdapter time) =>
      state = state.copyWith(invincibleWindowTime: time);

  void switchInvincibleMode() =>
      state = state.copyWith(isInvincibleModeOn: !state.isInvincibleModeOn);

  void toggleIncludeAppsTimer() =>
      state = state.copyWith(includeAppsTimer: !state.includeAppsTimer);

  void toggleIncludeAppsLaunchLimit() => state =
      state.copyWith(includeAppsLaunchLimit: !state.includeAppsLaunchLimit);

  void toggleIncludeAppsActivePeriod() => state =
      state.copyWith(includeAppsActivePeriod: !state.includeAppsActivePeriod);

  void toggleIncludeGroupsTimer() =>
      state = state.copyWith(includeGroupsTimer: !state.includeGroupsTimer);

  void toggleIncludeGroupsActivePeriod() => state = state.copyWith(
      includeGroupsActivePeriod: !state.includeGroupsActivePeriod);

  void toggleIncludeShortsTimer() =>
      state = state.copyWith(includeShortsTimer: !state.includeShortsTimer);

  void toggleIncludeBedtimeSchedule() => state =
      state.copyWith(includeBedtimeSchedule: !state.includeBedtimeSchedule);
}
