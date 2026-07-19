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
import 'package:mindful/models/active_period.dart';

/// Stores a list of [ActivePeriod] as a JSON string in SQL.
///
/// Implements [JsonTypeConverter2] so Drift's generated `toJson()` emits a real
/// JSON array of period objects (not a doubly-encoded string). This is what the
/// native side receives via the method channel and parses.
class ActivePeriodListConverter
    extends TypeConverter<List<ActivePeriod>, String>
    with JsonTypeConverter2<List<ActivePeriod>, String, List<dynamic>> {
  const ActivePeriodListConverter();

  @override
  List<ActivePeriod> fromSql(String fromDb) => (json.decode(fromDb) as List)
      .map((e) => ActivePeriod.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  @override
  String toSql(List<ActivePeriod> value) =>
      jsonEncode(value.map((e) => e.toMap()).toList());

  @override
  List<ActivePeriod> fromJson(List<dynamic> json) => json
      .map((e) => ActivePeriod.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  @override
  List<dynamic> toJson(List<ActivePeriod> value) =>
      value.map((e) => e.toMap()).toList();
}
