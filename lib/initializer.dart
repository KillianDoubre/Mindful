import 'package:flutter/material.dart';
import 'package:mindful/core/services/drift_db_service.dart';
import 'package:mindful/core/services/method_channel_service.dart';
import 'package:mindful/core/services/intention_suggestions_service.dart';
import 'package:mindful/core/services/productivity_repository.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/core/services/task_reminders_service.dart';
import 'package:mindful/models/productivity_item.dart';

/// Initializer to initialize necessary things.
class Initializer {
  /// Initializes all the required services and schedules.
  ///
  /// This method must be called after initializing `DATABASE` and `METHOD CHANNEL`.
  static Future<void> initializeServicesAndSchedules() async {
    final startTimeStamp = DateTime.now();

    final dynamicDao = DriftDbService.instance.driftDb.dynamicRecordsDao;
    final uniqueDao = DriftDbService.instance.driftDb.uniqueRecordsDao;

    /// fetch app restrictions
    var appRestrictions = await dynamicDao.fetchAppsRestrictions();
    final internetBlockedApps = appRestrictions
        .where((e) => !e.canAccessInternet)
        .map((e) => e.appPackage)
        .toList();

    /// filter out restrictions
    appRestrictions.removeWhere(
      (e) =>
          e.timerSec <= 0 &&
          e.periodDurationInMins <= 0 &&
          e.launchLimit <= 0 &&
          e.associatedGroupId == null,
    );

    /// update tracker service
    await MethodChannelService.instance.updateAppRestrictions(appRestrictions);

    /// update vpn service
    await MethodChannelService.instance
        .updateInternetBlockedApps(internetBlockedApps);

    /// Update restriction groups
    final restrictionGroups = await dynamicDao.fetchRestrictionGroups();
    await MethodChannelService.instance
        .updateRestrictionsGroups(restrictionGroups);

    /// Bedtime was removed: clear any alarm or DND it left behind
    await MethodChannelService.instance.cleanupLegacyBedtime();

    /// Fetch and update wellbeing
    final wellbeing = await uniqueDao.loadWellBeingSettings();
    await MethodChannelService.instance.updateWellBeingSettings(wellbeing);

    /// Fetch and update notification settings
    final notificationSettings = await uniqueDao.loadNotificationSettings();
    await MethodChannelService.instance
        .updateNotificationSettings(notificationSettings);

    /// Fetch and (re)schedule Systems reminders
    final systemsReminders =
        await SystemsRepository.instance.loadRemindersConfig();
    await MethodChannelService.instance
        .updateSystemsReminders(systemsReminders);

    await IntentionSuggestionsService.push();

    // Alarms are lost on reboot: schedule the task reminders again
    await TaskRemindersService.sync(
      await ProductivityRepository.instance.load(ProductivityItemType.task),
    );

    debugPrint(
      "All necessary services and schedules are initialized and it took ${DateTime.now().difference(startTimeStamp).inMilliseconds}ms.",
    );
  }
}
