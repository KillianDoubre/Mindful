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

/// Per-app dating blocking configuration.
///
/// When [isEnabled], the accessibility service tracks time spent on the app's
/// "engagement" pages (discovery, standout, likes-you, map, edit-profile) and
/// blocks them once [allowedMinutes] of daily usage is exhausted, until the
/// next daily reset.
@immutable
class DatingAppBlock {
  /// Package name of the dating app (e.g. com.tinder).
  final String appPackage;

  /// Allowed daily minutes on the app's engagement pages before blocking.
  final int allowedMinutes;

  /// Whether blocking is active for this app.
  final bool isEnabled;

  const DatingAppBlock({
    required this.appPackage,
    required this.allowedMinutes,
    required this.isEnabled,
  });

  DatingAppBlock copyWith({
    String? appPackage,
    int? allowedMinutes,
    bool? isEnabled,
  }) {
    return DatingAppBlock(
      appPackage: appPackage ?? this.appPackage,
      allowedMinutes: allowedMinutes ?? this.allowedMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'appPackage': appPackage,
      'allowedMinutes': allowedMinutes,
      'isEnabled': isEnabled,
    };
  }

  factory DatingAppBlock.fromMap(Map<String, dynamic> map) {
    return DatingAppBlock(
      appPackage: map['appPackage'] ?? '',
      allowedMinutes: map['allowedMinutes'] ?? 30,
      isEnabled: map['isEnabled'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DatingAppBlock &&
      other.appPackage == appPackage &&
      other.allowedMinutes == allowedMinutes &&
      other.isEnabled == isEnabled;

  @override
  int get hashCode => Object.hash(appPackage, allowedMinutes, isEnabled);

  @override
  String toString() =>
      'DatingAppBlock(appPackage: $appPackage, allowedMinutes: $allowedMinutes, isEnabled: $isEnabled)';
}
