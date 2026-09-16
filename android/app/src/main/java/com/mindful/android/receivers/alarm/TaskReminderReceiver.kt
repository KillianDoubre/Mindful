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
import com.mindful.android.helpers.device.NotificationHelper
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.utils.AppUtils

/** Posts the reminder of a task at one of its scheduled times. */
class TaskReminderReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "Mindful.TaskReminderReceiver"
        const val ACTION_TASK_REMINDER = "com.mindful.android.action.taskReminder"
        const val EXTRA_REMINDER_ID = "com.mindful.android.extra.reminderId"
        const val EXTRA_TASK_ID = "com.mindful.android.extra.taskId"
        const val EXTRA_TITLE = "com.mindful.android.extra.reminderTitle"
        const val EXTRA_BODY = "com.mindful.android.extra.reminderBody"

        private const val TASKS_DEEP_LINK = "com.mindful.android://open/tasks"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TASK_REMINDER) return
        try {
            val reminderId = intent.getIntExtra(EXTRA_REMINDER_ID, 0)
            val taskId = intent.getIntExtra(EXTRA_TASK_ID, 0)
            val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
            val body = intent.getStringExtra(EXTRA_BODY).orEmpty()
            if (title.isBlank()) return

            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.notify(
                // One notification per task: a later reminder replaces the earlier one
                NOTIFICATION_ID_BASE + taskId,
                NotificationCompat.Builder(context, NotificationHelper.TASKS_CHANNEL_ID)
                    .setSmallIcon(R.drawable.ic_mindful_notification)
                    .setAutoCancel(true)
                    .setCategory(NotificationCompat.CATEGORY_REMINDER)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setContentIntent(
                        AppUtils.getPendingIntentForMindfulUri(context, TASKS_DEEP_LINK)
                    )
                    .setContentTitle(title)
                    .setContentText(body)
                    .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                    .build()
            )
            Log.d(TAG, "onReceive: Posted reminder $reminderId for task $taskId")
        } catch (e: Exception) {
            Log.e(TAG, "onReceive: Unable to post task reminder", e)
            SharedPrefsHelper.insertCrashLogToPrefs(context, e)
        }
    }
}

private const val NOTIFICATION_ID_BASE = 40_000
