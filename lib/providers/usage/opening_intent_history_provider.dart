import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/models/opening_intent_record.dart';

final openingIntentHistoryProvider =
    FutureProvider<List<OpeningIntentRecord>>((ref) async {
  return MethodChannelService.instance.getOpeningIntentHistory();
});
