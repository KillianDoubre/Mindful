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

import 'package:drift/drift.dart';
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/database/converters/active_period_list_converter.dart';
import 'package:mindful/core/database/converters/string_list_converter.dart';

@DataClassName("RestrictionGroup")
class RestrictionGroupsTable extends Table {
  /// Unique ID for each restriction group
  IntColumn get id => integer().autoIncrement()();

  /// Name of the group
  TextColumn get groupName => text().withDefault(const Constant("Social"))();

  /// The timer set for the group in SECONDS
  IntColumn get timerSec => integer().withDefault(const Constant(0))();

  /// [TimeOfDay] in minutes from where the active period will start.
  /// It is stored as total minutes.
  IntColumn get activePeriodStart => integer()
      .map(const TimeOfDayAdapterConverter())
      .withDefault(const Constant(0))();

  /// [TimeOfDay] in minutes when the active period will end
  /// It is stored as total minutes.
  IntColumn get activePeriodEnd => integer()
      .map(const TimeOfDayAdapterConverter())
      .withDefault(const Constant(0))();

  /// Total duration of active period from start to end in MINUTES
  ///
  /// Deprecated in favor of [activePeriods]. Kept for backward compatibility.
  IntColumn get periodDurationInMins =>
      integer().withDefault(const Constant(0))();

  /// List of active periods for the group. Apps in the group are allowed only
  /// when the current time falls inside one of these periods on an enabled day.
  ///
  /// Supersedes the single [activePeriodStart]/[activePeriodEnd] window.
  TextColumn get activePeriods => text()
      .map(const ActivePeriodListConverter())
      .withDefault(Constant(jsonEncode([])))();

  /// List of app's packages which are associated with the group.
  TextColumn get distractingApps => text()
      .map(const StringListConverter())
      .withDefault(Constant(jsonEncode([])))();
}
