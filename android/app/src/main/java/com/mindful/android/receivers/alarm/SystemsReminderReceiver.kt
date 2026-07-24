/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */
package com.mindful.android.receivers.alarm

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import com.mindful.android.R
import com.mindful.android.helpers.AlarmTasksSchedulingHelper
import com.mindful.android.helpers.device.NotificationHelper
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.models.SystemReminder
import com.mindful.android.models.SystemsReminders
import com.mindful.android.utils.AppUtils
import com.mindful.android.utils.DateTimeUtils

/**
 * Fires the Systems reminders (daily systems nudge & weekly review nudge).
 *
 * The alarm is scheduled for every day at the configured time; this receiver
 * decides whether to actually post the notification based on the active
 * weekdays, then reschedules both reminders for their next occurrence.
 */
class SystemsReminderReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "Mindful.SystemsReminderReceiver"
        const val ACTION_DAILY_SYSTEMS: String =
            "com.mindful.android.action.dailySystemsReminder"
        const val ACTION_WEEKLY_SYSTEMS_REVIEW: String =
            "com.mindful.android.action.weeklySystemsReviewReminder"
        const val EXTRA_SYSTEMS_REMINDERS_JSON: String =
            "com.mindful.android.extra.systemsRemindersJson"

        private const val DAILY_NOTIFICATION_ID = 311
        private const val WEEKLY_NOTIFICATION_ID = 312

        /// Deep link opening the Systems tab (index 1 on the home screen).
        private const val SYSTEMS_DEEP_LINK = "com.mindful.android://open/home?tab=1"
    }

    override fun onReceive(context: Context, intent: Intent) {
        try {
            val json = intent.extras?.getString(EXTRA_SYSTEMS_REMINDERS_JSON) ?: ""
            if (json.isBlank()) return

            val reminders = SystemsReminders.fromJson(json)
            val today = DateTimeUtils.zeroIndexedDayOfWeek()

            when (intent.action) {
                ACTION_DAILY_SYSTEMS -> maybePush(
                    context,
                    reminders.daily,
                    today,
                    DAILY_NOTIFICATION_ID,
                    context.getString(R.string.systems_daily_reminder_notification_info),
                )

                ACTION_WEEKLY_SYSTEMS_REVIEW -> maybePush(
                    context,
                    reminders.weekly,
                    today,
                    WEEKLY_NOTIFICATION_ID,
                    context.getString(R.string.systems_weekly_reminder_notification_info),
                )
            }

            /// Reschedule both reminders for their next occurrence.
            AlarmTasksSchedulingHelper.scheduleSystemsReminders(context, json)
        } catch (e: Exception) {
            Log.e(TAG, "onReceive: Error while handling systems reminder", e)
            SharedPrefsHelper.insertCrashLogToPrefs(context, e)
        }
    }

    private fun maybePush(
        context: Context,
        reminder: SystemReminder,
        todayIndex: Int,
        notificationId: Int,
        text: String,
    ) {
        if (!reminder.isEnabled) return
        if (!reminder.days.getOrElse(todayIndex) { false }) return

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(
            notificationId,
            NotificationCompat.Builder(context, NotificationHelper.SYSTEMS_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_mindful_notification)
                .setOngoing(false)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(
                    AppUtils.getPendingIntentForMindfulUri(context, SYSTEMS_DEEP_LINK)
                )
                .setContentTitle(context.getString(R.string.app_name))
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .build()
        )
    }
}
