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
import 'package:mindful/models/dating_app_block.dart';

/// Stores a list of [DatingAppBlock] as a JSON string in SQL.
///
/// Implements [JsonTypeConverter2] so Drift's generated `toJson()` emits a real
/// JSON array of objects (not a doubly-encoded string), which is what the native
/// side receives through the method channel and parses.
class DatingAppBlockListConverter
    extends TypeConverter<List<DatingAppBlock>, String>
    with JsonTypeConverter2<List<DatingAppBlock>, String, List<dynamic>> {
  const DatingAppBlockListConverter();

  @override
  List<DatingAppBlock> fromSql(String fromDb) => (json.decode(fromDb) as List)
      .map((e) => DatingAppBlock.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  @override
  String toSql(List<DatingAppBlock> value) =>
      jsonEncode(value.map((e) => e.toMap()).toList());

  @override
  List<DatingAppBlock> fromJson(List<dynamic> json) => json
      .map((e) => DatingAppBlock.fromMap(Map<String, dynamic>.from(e)))
      .toList();

  @override
  List<dynamic> toJson(List<DatingAppBlock> value) =>
      value.map((e) => e.toMap()).toList();
}
