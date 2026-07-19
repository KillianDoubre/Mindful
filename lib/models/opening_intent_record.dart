import 'package:flutter/foundation.dart';

@immutable
class OpeningIntentRecord {
  const OpeningIntentRecord({
    required this.timestamp,
    required this.groupId,
    required this.groupName,
    required this.packageName,
    required this.reason,
    required this.outcome,
  });

  final DateTime timestamp;
  final int groupId;
  final String groupName;
  final String packageName;
  final String reason;
  final String outcome;

  factory OpeningIntentRecord.fromMap(Map<String, dynamic> map) =>
      OpeningIntentRecord(
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as num?)?.toInt() ?? 0,
        ),
        groupId: (map['groupId'] as num?)?.toInt() ?? 0,
        groupName: map['groupName'] as String? ?? '',
        packageName: map['packageName'] as String? ?? '',
        reason: map['reason'] as String? ?? 'other',
        outcome: map['outcome'] as String? ??
            ((map['continued'] as bool? ?? true) ? 'continued' : 'cancelled'),
      );
}
