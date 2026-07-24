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
    private val blockedContentOpenMessages: (
        packageName: String,
        sourceNode: AccessibilityNodeInfo?,
    ) -> Unit,
    private val getForegroundRoot: (String) -> AccessibilityNodeInfo?,
    initialResetTimeMinutes: Int,
) {
    /** Package name to accumulated milliseconds spent during this daily period. */
    private val dailyMsByPackage: MutableMap<String, Long> = HashMap()
    private val retainedBlockedSectionByPackage: MutableMap<String, Boolean> = HashMap()

    // The tick queries the accessibility tree (rootInActiveWindow, node lookups),
    // which must run on the service's main looper — the same looper the system
    // delivers accessibility events on. Using a background thread here crashes
    // the service on some devices.
    private val timerHandler = Handler(Looper.getMainLooper())

    private var resetTimeMinutes = initialResetTimeMinutes.coerceIn(0, 24 * 60 - 1)
    private var currentPeriod = DateTimeUtils.dailyPeriodKey(resetTimeMinutes)
    private var activePackage: String? = null
    private var activeAllowedMs = 0L
    private var lastTickElapsedMs = 0L
    private var lastSaveElapsedMs = 0L
    private var lastProcessedEventTimeMs = 0L
    private var lastRedirectPackage: String? = null
    private var lastRedirectElapsedMs = 0L

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

        if (config == null) {
            stopActiveSession(persistNow = true)
            return
        }

        if (!isBlockedPageOpen(packageName, node)) {
            // The messages page is intentionally unrestricted. Clearing the
            // redirect guard here lets a later return to discovery be blocked
            // immediately, even within the cooldown window.
            lastRedirectPackage = null
            lastRedirectElapsedMs = 0L
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

        // A 0-minute budget is valid and means "always redirect to messages".
        activeAllowedMs = config.allowedMs.coerceAtLeast(0L)

        if ((dailyMsByPackage[packageName] ?: 0L) >= activeAllowedMs) {
            Log.d(TAG, "onAccessibilityEvent: $packageName dating budget exhausted")
            redirectToMessages(packageName, node)
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

        // A 0-minute budget is valid and means "always redirect to messages".
        activeAllowedMs = config.allowedMs.coerceAtLeast(0L)
        if ((dailyMsByPackage[packageName] ?: 0L) >= activeAllowedMs) {
            redirectToMessages(packageName, getForegroundRoot(packageName))
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
            redirectToMessages(packageName, foregroundRoot)
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

    /**
     * Leaves discovery for the app's own messages tab. Accessibility apps can
     * emit several content-change events during a tab transition, so the short
     * cooldown prevents duplicate navigation while still allowing a retry if
     * the target app did not accept the first action.
     */
    private fun redirectToMessages(
        packageName: String,
        sourceNode: AccessibilityNodeInfo?,
    ) {
        stopActiveSession(persistNow = true)

        val nowElapsedMs = SystemClock.elapsedRealtime()
        if (lastRedirectPackage == packageName &&
            nowElapsedMs - lastRedirectElapsedMs < REDIRECT_COOLDOWN_MS
        ) {
            return
        }

        lastRedirectPackage = packageName
        lastRedirectElapsedMs = nowElapsedMs
        blockedContentOpenMessages.invoke(packageName, sourceNode)
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

        val safePageSelected = sig.safeSelectedViewIds.any { viewId ->
            findNodesByViewId(node, viewId).any(::isNodeOrParentSelected)
        }
        val safePageContentVisible = sig.safeViewIds.any {
            findNodesByViewId(node, it).isNotEmpty()
        }
        if (safePageSelected || safePageContentVisible) {
            retainedBlockedSectionByPackage.remove(packageName)
            return false
        }

        val blockedNavigationSelected = sig.selectedViewIds.any { viewId ->
            findNodesByViewId(node, viewId).any(::isNodeOrParentSelected)
        }
        val blockedContentVisible =
            sig.viewIds.any { findNodesByViewId(node, it).isNotEmpty() } ||
                    sig.texts.any { node.findAccessibilityNodeInfosByText(it).isNotEmpty() } ||
                    (sig.descriptions.isNotEmpty() && containsDescription(node, sig.descriptions))

        if (blockedNavigationSelected || blockedContentVisible) {
            if (sig.retainForNestedPages) {
                retainedBlockedSectionByPackage[packageName] = true
            }
            return true
        }

        // Hinge temporarily removes its navigation/title semantics when a
        // Standouts card opens or animates. Keep the last known blocked section
        // until Matches, a conversation, or Profile is explicitly detected.
        return sig.retainForNestedPages &&
                retainedBlockedSectionByPackage[packageName] == true
    }

    /**
     * Android Views expose qualified ids (package:id/name), while Happn's
     * Compose semantics expose raw test-tag ids (name). The platform lookup
     * does not reliably resolve the latter, so fall back to a tree traversal.
     */
    private fun findNodesByViewId(
        root: AccessibilityNodeInfo,
        targetId: String,
    ): List<AccessibilityNodeInfo> {
        val platformMatches = runCatching {
            root.findAccessibilityNodeInfosByViewId(targetId)
        }.getOrDefault(emptyList())
        if (platformMatches.isNotEmpty()) return platformMatches

        val matches = mutableListOf<AccessibilityNodeInfo>()
        collectNodesByViewId(root, targetId, matches)
        return matches
    }

    private fun collectNodesByViewId(
        node: AccessibilityNodeInfo,
        targetId: String,
        matches: MutableList<AccessibilityNodeInfo>,
    ) {
        val nodeId = node.viewIdResourceName
        if (nodeId == targetId ||
            nodeId?.substringAfterLast(":id/") == targetId.substringAfterLast(":id/")
        ) {
            matches.add(node)
        }
        for (index in 0 until node.childCount) {
            node.getChild(index)?.let { collectNodesByViewId(it, targetId, matches) }
        }
    }

    /** Main navigation items can expose their selected state on the item itself
     * or on a clickable parent, depending on whether the app uses Views or
     * Compose. Only a selected item identifies the active page. */
    private fun isNodeOrParentSelected(node: AccessibilityNodeInfo): Boolean {
        var candidate: AccessibilityNodeInfo? = node
        repeat(4) {
            val current = candidate ?: return false
            if (current.isSelected || current.isChecked) return true
            candidate = current.parent
        }
        return false
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
        private const val REDIRECT_COOLDOWN_MS = 1500L

        /**
         * Signatures identifying each dating app's engagement pages. Chat and
         * matches pages are intentionally excluded so they remain usable.
         */
        private val BLOCKED_PAGES: Map<String, PageSignatures> = mapOf(
            "com.tinder" to PageSignatures(
                safeSelectedViewIds = listOf(
                    // Conversations / Matches. This takes precedence over
                    // engagement views that can remain mounted behind the tab.
                    "com.tinder:id/action_matches",
                ),
                selectedViewIds = listOf(
                    // Explore (and its event/experience variants).
                    "com.tinder:id/action_experiences",
                    "com.tinder:id/action_events",
                    // Likes / Likes You.
                    "com.tinder:id/action_gold_home",
                ),
                viewIds = listOf(
                    // Main swipe page.
                    "com.tinder:id/recs_card_container",
                    "com.tinder:id/recs_card_carousel",
                    "com.tinder:id/main_cardstack_recs_view",
                    "com.tinder:id/recs_view_root_container",
                    // Explore and the profile cards opened from Explore.
                    "com.tinder:id/compose_discovery_view",
                    "com.tinder:id/explore_sparks_profile_card",
                    "com.tinder:id/explore_web_view",
                    // Likes / Likes You (Fast Match).
                    "com.tinder:id/fast_match_overlay",
                    "com.tinder:id/fast_match_compose_container",
                    "com.tinder:id/fast_match_recs_view",
                    "com.tinder:id/gold_home_tab_likes_you_container",
                    "com.tinder:id/likes_you_background_ring",
                    "com.tinder:id/likes_you_card",
                ),
            ),
            "co.hinge.app" to PageSignatures(
                retainForNestedPages = true,
                selectedViewIds = listOf(
                    // Main profile feed (untitled in the UI).
                    "co.hinge.app:id/discover",
                    // Curated profiles.
                    "co.hinge.app:id/standouts",
                    // "Te Like" / Likes You.
                    "co.hinge.app:id/likes_you",
                ),
                safeSelectedViewIds = listOf(
                    "co.hinge.app:id/matches",
                    "co.hinge.app:id/profile_hub",
                ),
                safeViewIds = listOf(
                    // Individual conversation views reached from Matches or
                    // directly from a notification.
                    "co.hinge.app:id/messageComposition",
                    "co.hinge.app:id/messageCompositionContainer",
                    "co.hinge.app:id/sendChatButtonContainer",
                ),
                viewIds = listOf(
                    "co.hinge.app:id/boost_button_text",
                ),
                texts = listOf("Standouts"),
                descriptions = listOf(
                    "Filtres pour le type de relation",
                    "Revenir sur le dernier profil ignoré",
                ),
            ),
            "com.bumble.app" to PageSignatures(
                safeSelectedViewIds = listOf(
                    // Chats remains usable after the discovery budget expires.
                    "com.bumble.app:id/chat",
                ),
                viewIds = listOf(
                    // "À découvrir" uses a Compose compatibility root.
                    "com.bumble.app:id/super_compatible_root",
                    // "Mon fil" uses the encounters stack.
                    "com.bumble.app:id/encounters_root",
                    "com.bumble.app:id/encountersGridProfile_list",
                    "com.bumble.app:id/encountersStackContainer",
                    "com.bumble.app:id/encountersProfile_voteLike",
                    // "Likes reçus" is Bumble's beeline screen.
                    "com.bumble.app:id/beeline_root",
                    "com.bumble.app:id/component_beeline_card_stack_top",
                ),
            ),
            "com.ftw_and_co.happn" to PageSignatures(
                safeSelectedViewIds = listOf(
                    // Compose can keep all bottom destinations in the tree, so
                    // the selected Chat item must win over blocked signatures.
                    "tab_bar_item_chat_list",
                    "com.ftw_and_co.happn:id/chat_dest",
                ),
                viewIds = listOf(
                    // Compose test-tag ids are intentionally unqualified.
                    "timeline_button_like",
                    "action_timeline_matching_prefs",
                    "vibes_title",
                    "likes_title",
                    "list_of_likes_nav_bar_boost_button",
                    "map_position_button",
                ),
            ),
        )
    }

    private data class PageSignatures(
        val retainForNestedPages: Boolean = false,
        val selectedViewIds: List<String> = emptyList(),
        val safeSelectedViewIds: List<String> = emptyList(),
        val safeViewIds: List<String> = emptyList(),
        val viewIds: List<String> = emptyList(),
        val texts: List<String> = emptyList(),
        val descriptions: List<String> = emptyList(),
    )
}
