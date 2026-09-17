import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/enums/default_home_tab.dart';
import 'package:mindful/core/enums/recap_type.dart';
import 'package:mindful/core/enums/reminder_type.dart';
import 'package:mindful/core/enums/session_type.dart';
import 'package:mindful/config/app_constants.dart';
import 'package:mindful/models/notification_schedule.dart';

final defaultMindfulSettingsModel = MindfulSettings(
  id: 0,
  defaultHomeTab: DefaultHomeTab.dashboard,
  themeMode: AppConstants.defaultThemeMode,
  accentColor: AppConstants.defaultMaterialColor,
  username: AppConstants.defaultUsername,
  localeCode: AppConstants.defaultLocale,
  usageHistoryWeeks: 4,
  useAmoledDark: false,
  useDynamicColors: false,
  leftEmergencyPasses: 3,
  lastEmergencyUsed: DateTime(0),
  isOnboardingDone: false,
  appVersion: "",
);

const defaultSharedUniqueDataModel = SharedUniqueData(
  id: 0,
  excludedApps: [],
);

const defaultParentalControlsModel = ParentalControls(
  id: 0,
  protectedAccess: false,
  uninstallWindowTime: TimeOfDayAdapter.zero(),
  isInvincibleModeOn: false,
  invincibleWindowTime: TimeOfDayAdapter.zero(),
  includeAppsTimer: true,
  includeAppsLaunchLimit: false,
  includeAppsActivePeriod: false,
  includeGroupsTimer: false,
  includeGroupsActivePeriod: false,
  includeShortsTimer: false,
  includeBedtimeSchedule: false,
);

const defaultWellbeingModel = Wellbeing(
  id: 0,
  allowedShortsTimeSec: 30 * 60,
  blockedFeatures: [],
  blockNsfwSites: false,
  blockedWebsites: [],
  nsfwWebsites: [],
  datingBlocks: [],
  datingResetTime: TimeOfDayAdapter.zero(),
);

/// Default schedule names shipped in English by earlier versions.
const legacyScheduleLabels = {
  'Morning': 'Matin',
  'Afternoon': 'Midi',
  'Evening': 'Soir',
  'Night': 'Nuit',
};

/// Renames the English default schedules; returns the same list when there
/// is nothing to rename.
List<NotificationSchedule> frenchifyScheduleLabels(
  List<NotificationSchedule> schedules,
) {
  if (!schedules.any((s) => legacyScheduleLabels.containsKey(s.label))) {
    return schedules;
  }
  return [
    for (final schedule in schedules)
      schedule.copyWith(
        label: legacyScheduleLabels[schedule.label] ?? schedule.label,
      ),
  ];
}

NotificationSettings defaultNotificationSettingsModel = NotificationSettings(
  id: 0,
  recapType: RecapType.summeryOnly,
  storeNonBatchedToo: false,
  notificationHistoryWeeks: 2,
  batchedApps: [],
  schedules: const {
    'Matin': 480,
    'Midi': 720,
    'Soir': 960,
    'Nuit': 1260,
  }
      .entries
      .map(
        (e) => NotificationSchedule(
          label: e.key,
          time: TimeOfDayAdapter.fromMinutes(e.value),
          isActive: false,
        ),
      )
      .toList(),
);

const defaultAppRestrictionModel = AppRestriction(
  appPackage: "",
  timerSec: 0,
  launchLimit: 0,
  activePeriodStart: TimeOfDayAdapter.zero(),
  activePeriodEnd: TimeOfDayAdapter.zero(),
  periodDurationInMins: 0,
  canAccessInternet: true,
  reminderType: ReminderType.none,
);

final defaultFocusModeModel = FocusMode(
  id: 0,
  sessionType: SessionType.study,
  longestStreak: 0,
  currentStreak: 0,
  lastTimeStreakUpdated: DateTime(0),
);

const defaultFocusProfileModel = FocusProfile(
  sessionType: SessionType.study,
  sessionDuration: 30 * 60,
  shouldStartDnd: false,
  enforceSession: false,
  distractingApps: [],
);
