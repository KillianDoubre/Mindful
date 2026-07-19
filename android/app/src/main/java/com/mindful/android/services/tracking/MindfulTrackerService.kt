package com.mindful.android.services.tracking

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.annotation.WorkerThread
import com.mindful.android.AppConstants
import com.mindful.android.R
import com.mindful.android.generics.ServiceBinder
import com.mindful.android.helpers.device.NotificationHelper
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.enums.RestrictionType
import com.mindful.android.models.RestrictionGroup

class MindfulTrackerService : Service() {
    companion object {
        private const val TAG = "Mindful.MindfulTrackerService"
    }

    private val mBinder = ServiceBinder(this@MindfulTrackerService)

    private lateinit var overlayManager: OverlayManager
    private lateinit var reminderManager: ReminderManager

    private lateinit var restrictionManager: RestrictionManager
    val getRestrictionManager get() = restrictionManager

    private lateinit var launchTrackingManager: LaunchTrackingManager
    val getLaunchTrackingManager get() = launchTrackingManager

    override fun onCreate() {
        overlayManager = OverlayManager(this)
        reminderManager = ReminderManager(overlayManager, ::onNewAppLaunch)
        restrictionManager = RestrictionManager(this, ::stopIfNoUsage)
        launchTrackingManager = LaunchTrackingManager(
            context = this,
            onNewAppLaunched = ::onNewAppLaunch,
            dismissOverlay = { overlayManager.dismissSheetOverlay() },
            cancelReminders = { reminderManager.cancelReminders() },
        )
        super.onCreate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {

        if (intent?.action == ServiceBinder.ACTION_START_MINDFUL_SERVICE) {
            startFgService()
            return START_STICKY
        }

        stopIfNoUsage()
        return START_NOT_STICKY
    }

    private fun startFgService() {
        try {
            val notification = NotificationHelper.buildFgServiceNotification(
                this,
                getString(R.string.app_blocker_running_notification_info)
            )
            startForeground(AppConstants.TRACKER_SERVICE_NOTIFICATION_ID, notification)
            Log.d(TAG, "startFgService: TRACKER service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "startFgService: Failed to start TRACKER service", e)
            SharedPrefsHelper.insertCrashLogToPrefs(this, e)
            stopIfNoUsage()
        }
    }

    fun onMidnightReset() {
        restrictionManager.resetCache()
        overlayManager.dismissSheetOverlay()
        val reminderAwaiting = reminderManager.cancelReminders()

        // Means app is active but timer is not over and now it is reset so re-launch same event again
        if (reminderAwaiting) launchTrackingManager.reInvokeLastLaunchEvent()
    }


    @WorkerThread
    private fun onNewAppLaunch(packageName: String) {
        try {
            // Accessibility events emitted by our own overlay must never dismiss
            // or recreate it while the user is choosing an intention.
            if (overlayManager.hasSheetOverlay) return

            reminderManager.cancelReminders()

            val promptGroup = restrictionManager.getIntentPromptGroup(packageName)

            if (promptGroup != null) {
                // Resolve inexpensive restrictions first, then cover the target app
                // before querying the heavier UsageEvents history.
                val immediateState = restrictionManager.isAppRestricted(
                    packageName = packageName,
                    includeScreenTime = false,
                )
                if (immediateState != null && immediateState.timeLeftMillis <= 0L) {
                    if (immediateState.type == RestrictionType.APP_TIMER ||
                        immediateState.type == RestrictionType.GROUP_TIMER
                    ) {
                        showIntentionPrompt(packageName, promptGroup, true)
                    } else {
                        overlayManager.showSheetOverlay(packageName, immediateState)
                    }
                    return
                }

                showIntentionPrompt(
                    packageName = packageName,
                    group = promptGroup,
                    isLimitExhausted = false,
                    isLimitCheckPending = true,
                )

                val evaluatedState = restrictionManager.isAppRestricted(
                    packageName = packageName,
                    incrementLaunchCount = false,
                )
                Log.d(TAG, "onNewAppLaunch: $packageName's evaluated state => $evaluatedState")

                if (evaluatedState != null && evaluatedState.timeLeftMillis > 0L) {
                    reminderManager.scheduleReminders(packageName, evaluatedState)
                }
                val isTimerExhausted = evaluatedState != null &&
                        evaluatedState.timeLeftMillis <= 0L &&
                        (evaluatedState.type == RestrictionType.APP_TIMER ||
                                evaluatedState.type == RestrictionType.GROUP_TIMER)
                overlayManager.resolveIntentionLimit(isTimerExhausted)
                return
            }

            /// No conscious-opening prompt: evaluate restrictions normally.
            val currentOrFutureState = restrictionManager.isAppRestricted(packageName)
            Log.d(TAG, "onNewAppLaunch: $packageName's evaluated state => $currentOrFutureState")

            currentOrFutureState?.let {
                /// Already restricted
                if (it.timeLeftMillis <= 0L) {
                    overlayManager.showSheetOverlay(
                        packageName = packageName,
                        restrictionState = it,
                    )
                    return
                }
                /// Under limit but will be exhausted in some time
                else {
                    reminderManager.scheduleReminders(
                        packageName = packageName,
                        state = it,
                    )
                }
            }

        } catch (e: Exception) {
            SharedPrefsHelper.insertCrashLogToPrefs(this, e)
            Log.e(TAG, "onNewAppLaunch: Failed to process new app launch event", e)
        }
    }

    private fun showIntentionPrompt(
        packageName: String,
        group: RestrictionGroup,
        isLimitExhausted: Boolean,
        isLimitCheckPending: Boolean = false,
    ) {
        overlayManager.showIntentionOverlay(
            packageName = packageName,
            isLimitExhausted = isLimitExhausted,
            isLimitCheckPending = isLimitCheckPending,
        ) { reason, outcome ->
            reason?.let {
                SharedPrefsHelper.insertOpeningIntent(
                    context = this,
                    groupId = group.id,
                    groupName = group.groupName,
                    packageName = packageName,
                    reason = it,
                    outcome = outcome,
                )
            }
        }
    }

    private fun stopIfNoUsage() {
        if (restrictionManager.isIdle) {
            Log.d(TAG, "Service no longer needed, stopping")
            launchTrackingManager.dispose()
            reminderManager.cancelReminders()
            overlayManager.dismissSheetOverlay()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy: TRACKER service destroyed successfully")
        super.onDestroy()
    }


    override fun onBind(intent: Intent): IBinder? {
        return if (intent.action == ServiceBinder.ACTION_BIND_TO_MINDFUL) mBinder else null
    }
}
