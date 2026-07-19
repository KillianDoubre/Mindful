package com.mindful.android.services.accessibility

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.models.Wellbeing
import com.mindful.android.utils.DateTimeUtils
import org.json.JSONObject

/**
 * Tracks time spent on dating apps' engagement pages and blocks those pages
 * once the configured per-app daily budget is exhausted.
 *
 * Page detection still relies on accessibility view signatures, while elapsed
 * time is measured continuously with a monotonic clock as long as the detected
 * page remains in the foreground.
 */
class DatingPlatformManager(
    private val context: Context,
    private val blockedContentGoBack: () -> Unit,
    private val getForegroundRoot: (String) -> AccessibilityNodeInfo?,
    initialResetTimeMinutes: Int,
) {
    /** Package name to accumulated milliseconds spent during this daily period. */
    private val dailyMsByPackage: MutableMap<String, Long> = HashMap()
    private val timerHandler = Handler(Looper.getMainLooper())

    private var resetTimeMinutes = initialResetTimeMinutes.coerceIn(0, 24 * 60 - 1)
    private var currentPeriod = DateTimeUtils.dailyPeriodKey(resetTimeMinutes)
    private var activePackage: String? = null
    private var activeAllowedMs = 0L
    private var lastTickElapsedMs = 0L
    private var lastSaveElapsedMs = 0L
    private var lastProcessedEventTimeMs = 0L

    private val timerTick = object : Runnable {
        override fun run() {
            tickActiveSession()
        }
    }

    init {
        loadPersisted()
    }

    /**
     * Processes every relevant accessibility event, including events emitted by
     * other packages so an active dating timer is stopped as soon as the user
     * leaves the tracked app.
     */
    @Synchronized
    fun onAccessibilityEvent(
        packageName: String,
        node: AccessibilityNodeInfo,
        eventTimeMs: Long,
        wellbeing: Wellbeing,
    ) {
        if (eventTimeMs < lastProcessedEventTimeMs) return
        lastProcessedEventTimeMs = eventTimeMs

        updateResetTime(wellbeing.datingResetTimeMinutes)
        resetForNewPeriodIfNeeded()

        val config = wellbeing.datingBlocks.firstOrNull {
            it.appPackage == packageName && it.isEnabled
        }

        if (config == null || !isBlockedPageOpen(packageName, node)) {
            stopActiveSession(persistNow = true)
            return
        }

        val nowElapsedMs = SystemClock.elapsedRealtime()
        if (activePackage != packageName) {
            stopActiveSession(persistNow = true)
            activePackage = packageName
            lastTickElapsedMs = nowElapsedMs
        } else {
            accumulateUntil(nowElapsedMs)
        }

        activeAllowedMs = config.allowedMs.coerceAtLeast(MIN_ALLOWED_MS)

        if ((dailyMsByPackage[packageName] ?: 0L) >= activeAllowedMs) {
            Log.d(TAG, "onAccessibilityEvent: $packageName dating budget exhausted")
            stopActiveSession(persistNow = true)
            blockedContentGoBack.invoke()
            return
        }

        scheduleNextTick()
    }

    /** Applies a settings change immediately to a currently running counter. */
    @Synchronized
    fun updateConfig(wellbeing: Wellbeing) {
        updateResetTime(wellbeing.datingResetTimeMinutes)
        resetForNewPeriodIfNeeded()

        val packageName = activePackage ?: return
        val config = wellbeing.datingBlocks.firstOrNull {
            it.appPackage == packageName && it.isEnabled
        }

        if (config == null) {
            stopActiveSession(persistNow = true)
            return
        }

        activeAllowedMs = config.allowedMs.coerceAtLeast(MIN_ALLOWED_MS)
        if ((dailyMsByPackage[packageName] ?: 0L) >= activeAllowedMs) {
            stopActiveSession(persistNow = true)
            blockedContentGoBack.invoke()
        }
    }

    /** Persists the last active slice and releases the periodic timer. */
    @Synchronized
    fun shutdown() {
        stopActiveSession(persistNow = true)
        timerHandler.removeCallbacksAndMessages(null)
    }

    @Synchronized
    private fun tickActiveSession() {
        resetForNewPeriodIfNeeded()
        val packageName = activePackage ?: return

        val foregroundRoot = getForegroundRoot(packageName)
        if (foregroundRoot == null || !isBlockedPageOpen(packageName, foregroundRoot)) {
            stopActiveSession(persistNow = true)
            return
        }

        val nowElapsedMs = SystemClock.elapsedRealtime()
        accumulateUntil(nowElapsedMs)

        if ((dailyMsByPackage[packageName] ?: 0L) >= activeAllowedMs) {
            Log.d(TAG, "tickActiveSession: $packageName dating budget exhausted")
            stopActiveSession(persistNow = true)
            blockedContentGoBack.invoke()
            return
        }

        if (nowElapsedMs - lastSaveElapsedMs >= SAVE_INTERVAL_MS) {
            persist()
            lastSaveElapsedMs = nowElapsedMs
        }

        scheduleNextTick()
    }

    private fun accumulateUntil(nowElapsedMs: Long) {
        val packageName = activePackage ?: return
        if (lastTickElapsedMs <= 0L) {
            lastTickElapsedMs = nowElapsedMs
            return
        }

        val elapsedMs = (nowElapsedMs - lastTickElapsedMs).coerceAtLeast(0L)
        if (elapsedMs > 0L) {
            dailyMsByPackage[packageName] =
                (dailyMsByPackage[packageName] ?: 0L) + elapsedMs
        }
        lastTickElapsedMs = nowElapsedMs
    }

    private fun scheduleNextTick() {
        timerHandler.removeCallbacks(timerTick)
        if (activePackage != null) {
            timerHandler.postDelayed(timerTick, TIMER_INTERVAL_MS)
        }
    }

    private fun stopActiveSession(persistNow: Boolean) {
        val hadActiveSession = activePackage != null
        if (hadActiveSession) {
            accumulateUntil(SystemClock.elapsedRealtime())
        }
        timerHandler.removeCallbacks(timerTick)
        activePackage = null
        activeAllowedMs = 0L
        lastTickElapsedMs = 0L

        if (persistNow && hadActiveSession) persist()
    }

    private fun updateResetTime(value: Int) {
        val normalized = value.coerceIn(0, 24 * 60 - 1)
        if (normalized == resetTimeMinutes) return

        resetTimeMinutes = normalized
        resetForNewPeriodIfNeeded()
    }

    private fun resetForNewPeriodIfNeeded() {
        val period = DateTimeUtils.dailyPeriodKey(resetTimeMinutes)
        if (period == currentPeriod) return

        dailyMsByPackage.clear()
        currentPeriod = period
        lastTickElapsedMs = SystemClock.elapsedRealtime()
        persist()
    }

    private fun isBlockedPageOpen(packageName: String, node: AccessibilityNodeInfo): Boolean {
        val sig = BLOCKED_PAGES[packageName] ?: return false

        if (sig.viewIds.any { node.findAccessibilityNodeInfosByViewId(it).isNotEmpty() }) {
            return true
        }
        if (sig.texts.any { node.findAccessibilityNodeInfosByText(it).isNotEmpty() }) {
            return true
        }
        return sig.descriptions.isNotEmpty() && containsDescription(node, sig.descriptions)
    }

    private fun containsDescription(
        node: AccessibilityNodeInfo,
        targets: List<String>,
    ): Boolean {
        node.contentDescription?.toString()?.let { desc ->
            if (targets.any { desc.contains(it, ignoreCase = true) }) return true
        }
        for (i in 0 until node.childCount) {
            node.getChild(i)?.let { if (containsDescription(it, targets)) return true }
        }
        return false
    }

    private fun loadPersisted() {
        runCatching {
            val json = JSONObject(SharedPrefsHelper.getSetDatingScreenTimes(context, null))
            if (json.optInt("day", -1) == currentPeriod) {
                val times = json.optJSONObject("times") ?: JSONObject()
                times.keys().forEach { key ->
                    dailyMsByPackage[key] = times.optLong(key, 0L).coerceAtLeast(0L)
                }
            }
        }
    }

    private fun persist() {
        runCatching {
            val times = JSONObject()
            dailyMsByPackage.forEach { (packageName, timeMs) ->
                times.put(packageName, timeMs.coerceAtLeast(0L))
            }
            val json = JSONObject().put("day", currentPeriod).put("times", times)
            SharedPrefsHelper.getSetDatingScreenTimes(context, json.toString())
        }
    }

    companion object {
        private const val TAG = "Mindful.DatingPlatformManager"
        private const val TIMER_INTERVAL_MS = 1000L
        private const val SAVE_INTERVAL_MS = 5000L
        private const val MIN_ALLOWED_MS = 60 * 1000L

        /**
         * Signatures identifying each dating app's engagement pages. Chat and
         * matches pages are intentionally excluded so they remain usable.
         */
        private val BLOCKED_PAGES: Map<String, PageSignatures> = mapOf(
            "com.tinder" to PageSignatures(
                viewIds = listOf(
                    "com.tinder:id/recs_card_container",
                    "com.tinder:id/recs_card_carousel",
                    "com.tinder:id/fast_match_overlay",
                    "com.tinder:id/likes_you_background_ring",
                    "com.tinder:id/edit_profile_view_pager",
                    "com.tinder:id/edit_profile_fragment_container",
                ),
            ),
            "co.hinge.app" to PageSignatures(
                viewIds = listOf(
                    "co.hinge.app:id/boost_button_text",
                    "co.hinge.app:id/edit_prompts",
                    "co.hinge.app:id/editDateIdeasBottomSheet",
                    "co.hinge.app:id/layoutMediaGrid",
                    "co.hinge.app:id/smartPhotoToggleRow",
                ),
                texts = listOf("Standouts"),
                descriptions = listOf(
                    "Filtres pour le type de relation",
                    "Revenir sur le dernier profil ignoré",
                ),
            ),
            "com.bumble.app" to PageSignatures(
                viewIds = listOf(
                    "com.bumble.app:id/encounters_root",
                    "com.bumble.app:id/encountersProfile_voteLike",
                    "com.bumble.app:id/beeline_root",
                    "com.bumble.app:id/component_beeline_card_stack_top",
                    "com.bumble.app:id/rib_profile_editor",
                    "com.bumble.app:id/profile_editor_elements",
                ),
            ),
            "com.ftw_and_co.happn" to PageSignatures(
                viewIds = listOf(
                    "timeline_button_like",
                    "action_timeline_matching_prefs",
                    "vibes_title",
                    "likes_title",
                    "list_of_likes_nav_bar_boost_button",
                    "edit_profile_firstname_with_age",
                    "see_my_own_profile",
                    "map_position_button",
                ),
            ),
        )
    }

    private data class PageSignatures(
        val viewIds: List<String> = emptyList(),
        val texts: List<String> = emptyList(),
        val descriptions: List<String> = emptyList(),
    )
}
