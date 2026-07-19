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
import 'package:mindful/core/services/method_channel_service.dart';

/// Today's dating-page screen time in seconds, keyed by app package.
///
/// Native counters are persisted every few seconds while a tracked page is in
/// the foreground, so polling keeps the progress UI fresh without opening a
/// second native-to-Flutter event channel.
final datingScreenTimesProvider =
    StreamProvider.autoDispose<Map<String, int>>((ref) async* {
  while (true) {
    yield await MethodChannelService.instance.getDatingScreenTimesSec();
    await Future<void>.delayed(const Duration(seconds: 5));
  }
});
