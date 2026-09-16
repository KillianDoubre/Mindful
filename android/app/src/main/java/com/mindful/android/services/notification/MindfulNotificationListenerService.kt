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
package com.mindful.android.services.notification

import android.app.PendingIntent
import android.content.ComponentName
import android.content.Intent
import android.os.IBinder
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.mindful.android.generics.ServiceBinder
import com.mindful.android.generics.SmartCacheBox
import com.mindful.android.helpers.storage.DriftDbHelper
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.models.Notification
import com.mindful.android.models.NotificationSettings
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit


class MindfulNotificationListenerService : NotificationListenerService() {
    companion object {
        private const val TAG = "Mindful.MindfulNotificationService"

        /// History-only notifications are written in small groups, at most this
        /// long after they arrive. Batched ones are written right away since
        /// they have already been removed from the shade.
        private const val HISTORY_FLUSH_DELAY_SEC = 5L

        /// The connected listener, needed to read the notification shade from
        /// outside the service. Only the system may instantiate it, so this is
        /// the sole way to reach the live one.
        @Volatile
        private var connectedListener: MindfulNotificationListenerService? = null

        /**
         * Whether [packageName] currently has a notification sitting in the
         * shade, ignoring ongoing ones (sync, uploads, media players) which the
         * user never "answers".
         *
         * Used to tell a reply from a browse: opening an app that is waiting for
         * an answer must not be taxed by the conscious-opening delay.
         *
         * Returns FALSE whenever the shade cannot be read (notification access
         * revoked, listener not connected yet), so the delay stays the default.
         */
        fun hasPendingNotification(packageName: String): Boolean = runCatching {
            val listener = connectedListener ?: return false

            listener.activeNotifications?.any {
                it.packageName == packageName &&
                        (it.notification.flags and
                                android.app.Notification.FLAG_ONGOING_EVENT) == 0
            } ?: false
        }.getOrElse {
            Log.e(TAG, "hasPendingNotification: Unable to read active notifications", it)
            false
        }

        /** Applies new settings to the running listener, if any. */
        fun applySettings(settings: NotificationSettings) {
            connectedListener?.updateNotificationSettings(settings)
        }

        /** Writes every notification still held in memory, synchronously. */
        fun flushPendingNotifications() {
            connectedListener?.insertNotificationsToDb()
        }

        /** The original tap action of a batched notification, when still cached. */
        fun pendingIntentFor(key: String): PendingIntent? =
            connectedListener?.getPendingIntentForKey(key)
    }

    private val binder = ServiceBinder(this@MindfulNotificationListenerService)
    private val executorService: ExecutorService = Executors.newSingleThreadExecutor()
    private val flushScheduler = Executors.newSingleThreadScheduledExecutor()

    private val pendingLock = Any()

    /// Only one write at a time, so a batch is never inserted twice.
    private val flushLock = Any()
    private val pendingNotifications: MutableList<Notification> = mutableListOf()
    private var isFlushScheduled = false

    private val cachedPendingIntents: SmartCacheBox<String, PendingIntent> = SmartCacheBox(
        maxSize = 100,
        maxAgeMs = 24 * 60 * 60 * 1000L // 24 hours
    )

    @Volatile
    private var settings: NotificationSettings = NotificationSettings()

    @Volatile
    private var isListenerActive = false

    /**
     *  Returns the pending intent for the provided key if found, otherwise null
     */
    fun getPendingIntentForKey(key: String): PendingIntent? = cachedPendingIntents.get(key)

    override fun onCreate() {
        super.onCreate()
        // The system may restart the listener without the app: recover the
        // last settings instead of silently batching nothing.
        settings = runCatching {
            NotificationSettings.fromJson(
                SharedPrefsHelper.getSetNotificationSettingsJson(this, null)
            )
        }.getOrElse { NotificationSettings() }
    }

    override fun onListenerConnected() {
        isListenerActive = true
        connectedListener = this
        Log.d(TAG, "onListenerConnected: Notifications listener CONNECTED")
        super.onListenerConnected()
    }

    override fun onListenerDisconnected() {
        isListenerActive = false
        if (connectedListener === this) connectedListener = null
        Log.d(TAG, "onListenerConnected: Notifications listener DIS-CONNECTED")

        super.onListenerDisconnected()
        // Try to rebind again
        runCatching {
            val listener = ComponentName(this, MindfulNotificationListenerService::class.java)
            requestRebind(listener)
        }
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (!isListenerActive) return
        val packageName = sbn.packageName
        try {
            // If from mindful or not clearable or group summery
            val isGroupSummary =
                sbn.notification.flags and android.app.Notification.FLAG_GROUP_SUMMARY != 0
            if (packageName == this.packageName || !sbn.isClearable || isGroupSummary || sbn.isOngoing) return

            val current = settings
            val isFromBatchedApp = current.batchedApps.contains(packageName)

            // Process only if keeping history or it is from batched app
            if (current.storeNonBatchedToo || isFromBatchedApp) {
                // Read everything before the notification is cancelled
                val notification = Notification.fromSbn(sbn)
                val contentIntent = sbn.notification.contentIntent
                executorService.submit {
                    processNotificationInBg(
                        notification,
                        contentIntent,
                        isFromBatchedApp,
                    )
                }
            }

            // Dismiss notification if it is from distracting apps
            if (isFromBatchedApp) {
                cancelNotification(sbn.key)
                Log.d(TAG, "onNotificationPosted: Distracting notification dismissed")
            }
        } catch (e: Exception) {
            SharedPrefsHelper.insertCrashLogToPrefs(this, e)
            Log.e(TAG, "onNotificationPosted: Something went wrong for package: $packageName", e)
        }
        super.onNotificationPosted(sbn)
    }


    fun updateNotificationSettings(settings: NotificationSettings) {
        this.settings = settings
        Log.d(
            TAG,
            "updateNotificationSettings: Notification settings updated successfully: $settings"
        )
    }

    private fun processNotificationInBg(
        parsed: Notification,
        contentIntent: PendingIntent?,
        isFromBatchedApp: Boolean,
    ) {
        try {
            var notification = parsed.copy(isRead = !isFromBatchedApp)
            if (notification.title.isEmpty() || notification.content.isEmpty()) {
                // A batched notification is already gone from the shade: never
                // drop it, give it a readable fallback instead
                if (!isFromBatchedApp) return
                notification = notification.copy(
                    title = notification.title.ifEmpty { appLabel(notification.packageName) },
                    content = notification.content.ifEmpty { "Nouvelle notification" },
                )
            }

            contentIntent?.let { cachedPendingIntents.put(notification.key, it) }
            synchronized(pendingLock) { pendingNotifications.add(notification) }

            if (isFromBatchedApp) insertNotificationsToDb() else scheduleHistoryFlush()
        } catch (e: Exception) {
            SharedPrefsHelper.insertCrashLogToPrefs(this, e)
            Log.e(TAG, "processNotificationInBg: Failed to process notification", e)
        }
    }

    private fun appLabel(packageName: String): String = runCatching {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(packageName, 0)
        ).toString()
    }.getOrDefault(packageName)

    private fun scheduleHistoryFlush() {
        synchronized(pendingLock) {
            if (isFlushScheduled) return
            isFlushScheduled = true
        }
        runCatching {
            flushScheduler.schedule(
                { executorService.submit { insertNotificationsToDb() } },
                HISTORY_FLUSH_DELAY_SEC,
                TimeUnit.SECONDS,
            )
        }
    }

    /**
     * Writes the notifications held in memory. Only the ones actually written
     * are removed, so anything arriving meanwhile waits for the next write.
     */
    fun insertNotificationsToDb() = synchronized(flushLock) {
        val batch = synchronized(pendingLock) {
            isFlushScheduled = false
            pendingNotifications.toList()
        }
        if (batch.isEmpty()) return@synchronized

        val isSuccess = DriftDbHelper.insertNotifications(this, batch)
        if (isSuccess) {
            synchronized(pendingLock) { pendingNotifications.removeAll(batch) }
        } else {
            scheduleHistoryFlush()
        }
    }


    override fun onBind(intent: Intent): IBinder? {
        return if (intent.action == ServiceBinder.ACTION_BIND_TO_MINDFUL) binder
        else super.onBind(intent)
    }

    override fun onDestroy() {
        if (connectedListener === this) connectedListener = null
        insertNotificationsToDb()
        flushScheduler.shutdownNow()
        executorService.shutdown()
        Log.d(TAG, "onDestroy: Notifications listener DESTROYED")
        super.onDestroy()
    }
}
