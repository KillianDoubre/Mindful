/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */
package com.mindful.android.utils

import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.util.Log
import androidx.annotation.WorkerThread

/**
 * Tells which app truly owns the foreground, according to the system's usage
 * events.
 *
 * A launch event on its own does not prove an app came to the front:
 * accessibility emits TYPE_WINDOW_STATE_CHANGED for windows that never do
 * (heads-up notifications, toasts, dialogs, picture-in-picture players), and a
 * stale launch is replayed on unlock, at midnight and when an emergency pass
 * ends. Both used to interrupt the user for an app they never opened.
 */
object ForegroundAppResolver {
    private const val TAG = "Mindful.ForegroundAppResolver"

    /// Window of usage events inspected on every check
    private const val LOOKBACK_MS: Long = 5000

    /// Usage events lag a few hundred ms behind accessibility events, so a
    /// genuine launch is re-checked a couple of times before being rejected.
    private const val CHECK_ATTEMPTS = 3
    private const val CHECK_DELAY_MS: Long = 250

    /**
     * Returns TRUE once the usage events show [packageName] in the foreground.
     *
     * Blocks for up to [CHECK_ATTEMPTS] x [CHECK_DELAY_MS] while the evidence is
     * missing, so the launch is only rejected when another app is confirmed to
     * be in front.
     */
    @WorkerThread
    fun isForegroundConfirmed(context: Context, packageName: String): Boolean {
        repeat(CHECK_ATTEMPTS) { attempt ->
            if (queryForegroundPackage(context) == packageName) return true

            if (attempt < CHECK_ATTEMPTS - 1) {
                try {
                    Thread.sleep(CHECK_DELAY_MS)
                } catch (e: InterruptedException) {
                    Thread.currentThread().interrupt()
                    return false
                }
            }
        }

        Log.d(TAG, "isForegroundConfirmed: $packageName is not in the foreground")
        return false
    }

    /**
     * Resolves the package currently holding the foreground, or NULL when the
     * recent events carry no evidence either way.
     */
    @WorkerThread
    private fun queryForegroundPackage(context: Context): String? {
        val usageStatsManager = runCatching {
            context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        }.getOrNull() ?: return null

        val timeNow = System.currentTimeMillis()
        val events = runCatching {
            usageStatsManager.queryEvents(timeNow - LOOKBACK_MS, timeNow)
        }.getOrNull() ?: return null

        val currentEvent = UsageEvents.Event()
        var foregroundPackage: String? = null

        while (events.hasNextEvent()) {
            events.getNextEvent(currentEvent)

            when (currentEvent.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED,
                    -> foregroundPackage = currentEvent.packageName

                UsageEvents.Event.ACTIVITY_PAUSED,
                UsageEvents.Event.ACTIVITY_STOPPED,
                    -> if (foregroundPackage == currentEvent.packageName) {
                    foregroundPackage = null
                }

                else -> {}
            }
        }

        return foregroundPackage
    }
}
