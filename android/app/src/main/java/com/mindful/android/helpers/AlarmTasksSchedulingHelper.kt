/*
 *
 *  *
 *  *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *  *
 *  *  * This source code is licensed under the GPL-2.0 license license found in the
 *  *  * LICENSE file in the root directory of this source tree.
 *  *
 *
 */
package com.mindful.android.helpers

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.mindful.android.AppConstants
import com.mindful.android.generics.SafeServiceConnection
import com.mindful.android.models.NotificationSettings
import com.mindful.android.receivers.alarm.MidnightResetReceiver
import com.mindful.android.receivers.alarm.NotificationBatchReceiver
import com.mindful.android.receivers.alarm.NotificationBatchReceiver.Companion.EXTRA_NOTIFICATION_SETTINGS_JSON
import com.mindful.android.receivers.alarm.NotificationBatchReceiver.NotificationBatchWorker
import com.mindful.android.receivers.alarm.SystemsReminderReceiver
import com.mindful.android.receivers.alarm.TaskReminderReceiver
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.helpers.device.NotificationHelper
import com.mindful.android.enums.DndWakeLock
import org.json.JSONArray
import com.mindful.android.receivers.alarm.SystemsReminderReceiver.Companion.EXTRA_SYSTEMS_REMINDERS_JSON
import com.mindful.android.models.SystemsReminders
import com.mindful.android.services.tracking.MindfulTrackerService
import com.mindful.android.utils.DateTimeUtils.todToTodayCal
import com.mindful.android.utils.Utils
import java.util.Calendar
import java.util.Date

/**
 * Helper class for scheduling the app's alarm tasks (midnight reset, notification
 * batches, reminders).
 */
object AlarmTasksSchedulingHelper {
    private const val TAG = "Mindful.AlarmTasksSchedulingHelper"
    private const val MIDNIGHT_RESET_ALARM_ID = 101
    private const val LEGACY_BEDTIME_ALARM_ID = 102
    private val LEGACY_BEDTIME_ACTIONS = listOf(
        "com.mindful.android.action.alertBedtime",
        "com.mindful.android.action.startBedtime",
        "com.mindful.android.action.stopBedtime",
    )
    private const val NOTIFICATION_BATCH_ALARM_ID = 103
    private const val SYSTEMS_DAILY_REMINDER_ALARM_ID = 104
    private const val SYSTEMS_WEEKLY_REMINDER_ALARM_ID = 105
    private const val TASK_REMINDER_ALARM_ID_BASE = 200_000


    /**
     * Schedules the midnight reset task if it is not already scheduled.
     * Which will trigger at 12 midnight every day (with delay of 3 seconds).
     *
     * @param context               The application context.
     * @param checkBeforeScheduling Flag indicating whether to check if the task is already scheduled.
     */
    fun scheduleMidnightResetTask(context: Context, checkBeforeScheduling: Boolean) {
        if (checkBeforeScheduling) {
            val intent =
                Intent(context.applicationContext, MidnightResetReceiver::class.java).setAction(
                    MidnightResetReceiver.ACTION_START_MIDNIGHT_RESET
                )
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                MIDNIGHT_RESET_ALARM_ID,
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )

            if (pendingIntent != null) {
                Log.d(TAG, "scheduleMidnightTask: Midnight reset task is already scheduled")
                return
            }
        }

        val cal = Calendar.getInstance()
        cal[Calendar.HOUR_OF_DAY] = 0
        cal[Calendar.MINUTE] = 0
        cal[Calendar.SECOND] = 3 // For safe side
        cal.add(Calendar.DATE, 1)

        scheduleOrUpdateExactAlarmTask(
            context = context,
            receiverClass = MidnightResetReceiver::class.java,
            intentAction = MidnightResetReceiver.ACTION_START_MIDNIGHT_RESET,
            requestCode = MIDNIGHT_RESET_ALARM_ID,
            epochTimeMs = cal.timeInMillis
        )
        Log.d(
            TAG,
            "scheduleMidnightTask: Midnight reset task scheduled successfully for " + cal.time
        )
    }

    /**
     * Removes what the retired bedtime feature may have left behind: its
     * alarms (matched by component name, the receiver class no longer exists)
     * and a Do Not Disturb it had switched on.
     */
    fun cleanupLegacyBedtime(context: Context) {
        runCatching {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val component = ComponentName(
                context.packageName,
                "com.mindful.android.receivers.alarm.BedtimeRoutineReceiver",
            )
            for (action in LEGACY_BEDTIME_ACTIONS) {
                val intent = Intent(action).setComponent(component)
                PendingIntent.getBroadcast(
                    context,
                    LEGACY_BEDTIME_ALARM_ID,
                    intent,
                    PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                )?.let {
                    alarmManager.cancel(it)
                    it.cancel()
                }
            }
            if (SharedPrefsHelper.getSetDndWakeLock(context, null) == DndWakeLock.BEDTIME_MODE) {
                NotificationHelper.toggleDnd(context, DndWakeLock.BEDTIME_MODE, false)
            }
        }.onFailure { Log.e(TAG, "cleanupLegacyBedtime: Cleanup failed", it) }
    }

    /**
     * Schedules next future possible notification batch.
     *
     * @param context      The application context.
     * @param jsonNotificationSettings The json of Notification Settings.
     */
    fun scheduleNotificationBatchTask(context: Context, jsonNotificationSettings: String) {
        val settings = NotificationSettings.fromJson(jsonNotificationSettings)
        if (settings.schedules.isEmpty()) return

        val now = System.currentTimeMillis()
        var nextAlarmTimeMs: Long? = null

        // Find the first future TOD
        for (schedule in settings.schedules) {
            val currentTime = todToTodayCal(schedule.todMinutes).timeInMillis
            if (currentTime > now) {
                nextAlarmTimeMs = currentTime
                break
            }
        }

        // If no future TOD, schedule for the first TOD of the next day
        nextAlarmTimeMs = nextAlarmTimeMs
            ?: (todToTodayCal(settings.schedules[0].todMinutes).timeInMillis + AppConstants.ONE_DAY_IN_MS)


        scheduleOrUpdateExactAlarmTask(
            context = context,
            receiverClass = NotificationBatchReceiver::class.java,
            intentAction = NotificationBatchReceiver.ACTION_PUSH_BATCH,
            requestCode = NOTIFICATION_BATCH_ALARM_ID,
            epochTimeMs = nextAlarmTimeMs,
            extraMap = mapOf(
                EXTRA_NOTIFICATION_SETTINGS_JSON to jsonNotificationSettings
            ),
        )
        Log.d(
            TAG,
            "scheduleNotificationBatchTask: Notification batch task scheduled successfully for " + Date(
                nextAlarmTimeMs
            )
        )
    }

    /**
     * Cancels notification batch schedule task.
     *
     * @param context The application context.
     */
    fun cancelNotificationBatchTask(context: Context) {
        cancelExactAlarmTasks(
            context = context,
            receiverClass = NotificationBatchWorker::class.java,
            requestCode = NOTIFICATION_BATCH_ALARM_ID,
            intentActions = listOf(NotificationBatchReceiver.ACTION_PUSH_BATCH)
        )
        Log.d(TAG, "cancelNotificationBatchTask: Notification batch tasks cancelled successfully")
    }

    /**
     * Schedules (or cancels) the Systems reminders based on the provided config.
     *
     * Each enabled reminder is scheduled for its next occurrence; the receiver
     * itself decides whether to notify based on the active weekdays and then
     * reschedules for the following day. Disabled reminders are cancelled.
     *
     * @param context The application context.
     * @param jsonSystemsReminders The json string of the [SystemsReminders] config.
     */
    fun scheduleSystemsReminders(context: Context, jsonSystemsReminders: String) {
        if (jsonSystemsReminders.isBlank()) {
            cancelSystemsReminders(context)
            return
        }

        val reminders = SystemsReminders.fromJson(jsonSystemsReminders)
        val extraMap = mapOf(EXTRA_SYSTEMS_REMINDERS_JSON to jsonSystemsReminders)

        /// Daily systems reminder
        if (reminders.daily.isEnabled) {
            scheduleOrUpdateExactAlarmTask(
                context = context,
                receiverClass = SystemsReminderReceiver::class.java,
                intentAction = SystemsReminderReceiver.ACTION_DAILY_SYSTEMS,
                requestCode = SYSTEMS_DAILY_REMINDER_ALARM_ID,
                epochTimeMs = nextTimeOfDayEpochMs(reminders.daily.minutes),
                extraMap = extraMap,
            )
        } else {
            cancelExactAlarmTasks(
                context = context,
                receiverClass = SystemsReminderReceiver::class.java,
                requestCode = SYSTEMS_DAILY_REMINDER_ALARM_ID,
                intentActions = listOf(SystemsReminderReceiver.ACTION_DAILY_SYSTEMS),
            )
        }

        /// Weekly review reminder
        if (reminders.weekly.isEnabled) {
            scheduleOrUpdateExactAlarmTask(
                context = context,
                receiverClass = SystemsReminderReceiver::class.java,
                intentAction = SystemsReminderReceiver.ACTION_WEEKLY_SYSTEMS_REVIEW,
                requestCode = SYSTEMS_WEEKLY_REMINDER_ALARM_ID,
                epochTimeMs = nextTimeOfDayEpochMs(reminders.weekly.minutes),
                extraMap = extraMap,
            )
        } else {
            cancelExactAlarmTasks(
                context = context,
                receiverClass = SystemsReminderReceiver::class.java,
                requestCode = SYSTEMS_WEEKLY_REMINDER_ALARM_ID,
                intentActions = listOf(SystemsReminderReceiver.ACTION_WEEKLY_SYSTEMS_REVIEW),
            )
        }
        Log.d(TAG, "scheduleSystemsReminders: Systems reminders scheduled/updated")
    }

    /**
     * Cancels both Systems reminder alarms.
     */
    fun cancelSystemsReminders(context: Context) {
        cancelExactAlarmTasks(
            context = context,
            receiverClass = SystemsReminderReceiver::class.java,
            requestCode = SYSTEMS_DAILY_REMINDER_ALARM_ID,
            intentActions = listOf(SystemsReminderReceiver.ACTION_DAILY_SYSTEMS),
        )
        cancelExactAlarmTasks(
            context = context,
            receiverClass = SystemsReminderReceiver::class.java,
            requestCode = SYSTEMS_WEEKLY_REMINDER_ALARM_ID,
            intentActions = listOf(SystemsReminderReceiver.ACTION_WEEKLY_SYSTEMS_REVIEW),
        )
    }

    /**
     * Returns the epoch millis for the next occurrence of the given time of day.
     * If the time already passed today, it rolls over to tomorrow.
     */
    private fun nextTimeOfDayEpochMs(todMinutes: Int): Long {
        val cal = todToTodayCal(todMinutes)
        if (cal.timeInMillis <= System.currentTimeMillis()) {
            cal.add(Calendar.DATE, 1)
        }
        return cal.timeInMillis
    }

    /**
     * Schedules or updates an alarm task with the specified parameters.
     *
     * @param context       The application context.
     * @param receiverClass The receiver class for the alarm.
     * @param intentAction  The action to be set on the intent.
     * @param requestCode   A unique identifier for this alarm, used to update or cancel it later.
     * @param epochTimeMs   The time at which the alarm should go off, in milliseconds since epoch.
     * @param extraMap         An optional map of key-value pairs to be passed as extras in the `Intent`. Value should be serialized json.  Default is `null`.
     */
    /**
     * Replaces every scheduled task reminder with the ones in [json], a JSON
     * array of `{id, taskId, title, body, atMs}` objects.
     */
    fun scheduleTaskReminders(context: Context, json: String) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        fun intentFor() = Intent(context.applicationContext, TaskReminderReceiver::class.java)
            .setAction(TaskReminderReceiver.ACTION_TASK_REMINDER)

        // Cancel what was scheduled before
        for (code in SharedPrefsHelper.getSetTaskReminderCodes(context, null)) {
            PendingIntent.getBroadcast(
                context,
                code,
                intentFor(),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )?.let {
                alarmManager.cancel(it)
                it.cancel()
            }
        }

        val scheduled = mutableSetOf<Int>()
        val now = System.currentTimeMillis()
        val reminders = runCatching { JSONArray(json) }.getOrElse { JSONArray() }
        for (index in 0 until reminders.length()) {
            val item = reminders.optJSONObject(index) ?: continue
            val atMs = item.optLong("atMs")
            if (atMs <= now) continue

            val code = TASK_REMINDER_ALARM_ID_BASE + item.optInt("id")
            val intent = intentFor()
                .putExtra(TaskReminderReceiver.EXTRA_REMINDER_ID, item.optInt("id"))
                .putExtra(TaskReminderReceiver.EXTRA_TASK_ID, item.optInt("taskId"))
                .putExtra(TaskReminderReceiver.EXTRA_TITLE, item.optString("title"))
                .putExtra(TaskReminderReceiver.EXTRA_BODY, item.optString("body"))
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                code,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val canBeExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                    alarmManager.canScheduleExactAlarms()
            if (canBeExact) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    atMs,
                    pendingIntent
                )
            } else {
                // Still remind, a few minutes late at worst
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMs, pendingIntent)
            }
            scheduled.add(code)
        }

        SharedPrefsHelper.getSetTaskReminderCodes(context, scheduled)
        Log.d(TAG, "scheduleTaskReminders: ${scheduled.size} task reminders scheduled")
    }

    private fun scheduleOrUpdateExactAlarmTask(
        context: Context,
        receiverClass: Class<*>,
        intentAction: String,
        requestCode: Int,
        epochTimeMs: Long,
        extraMap: Map<String, String>? = null,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context.applicationContext, receiverClass).setAction(intentAction)
        extraMap?.let {
            it.forEach { entry ->
                intent.putExtra(entry.key, entry.value)
            }
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (alarmManager.canScheduleExactAlarms()) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    epochTimeMs,
                    pendingIntent
                )
            }
        } else {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                epochTimeMs,
                pendingIntent
            )
        }
    }

    /**
     * Cancels all the exact alarm task related to the service class and the list of actions.
     *
     * @param context       The application context.
     * @param receiverClass The receiver class for the alarm.
     * @param intentActions The list of actions to be set on the intents.
     */
    private fun cancelExactAlarmTasks(
        context: Context,
        receiverClass: Class<*>,
        requestCode: Int,
        intentActions: List<String>,
    ) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        for (action in intentActions) {
            val intent = Intent(context.applicationContext, receiverClass).setAction(action)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
        }
    }
}
