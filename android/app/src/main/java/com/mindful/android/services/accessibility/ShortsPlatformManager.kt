package com.mindful.android.services.accessibility

import android.content.Context
import android.content.Intent
import android.graphics.Rect
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityNodeInfo
import com.mindful.android.AppConstants.FACEBOOK_PACKAGE
import com.mindful.android.AppConstants.INSTAGRAM_PACKAGE
import com.mindful.android.AppConstants.REDDIT_PACKAGE
import com.mindful.android.AppConstants.SNAPCHAT_PACKAGE
import com.mindful.android.AppConstants.YOUTUBE_CLIENT_PACKAGE_SUFFIX
import com.mindful.android.AppConstants.YOUTUBE_PACKAGE
import com.mindful.android.enums.PlatformFeatures
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.models.Wellbeing
import org.jetbrains.annotations.Contract


class ShortsPlatformManager(
    private val context: Context,
    private val blockedContentGoBack: (targetPackage: String) -> Unit,
    private val blockedInstagramOpenInbox: () -> Unit,
) {

    private var lastTimeShortsEvent = 0L
    private var lastTimeSaved = 0L
    private var shortContentScreenTime = SharedPrefsHelper.getSetShortsScreenTimeMs(context, null)

    // -- Shared short pass ---------------------------------------------------
    // A short opened from a conversation (or a link sent from another app) may
    // be watched even when the budget is spent. The pass ends as soon as the
    // user pages to the next short or leaves the player.

    @Volatile
    private var foregroundPackage = ""

    @Volatile
    private var previousForegroundPackage = ""

    @Volatile
    private var foregroundSinceMs = 0L

    /** Package whose short player is currently open, if any. */
    private var playerPackage: String? = null

    /** First time the player was seen missing, to ignore one-off glitches. */
    private var playerMissingSinceMs = 0L

    /** Whether the last non-player screen seen was a conversation, per package. */
    private val lastScreenWasConversation = HashMap<String, Boolean>()
    private val lastScreenSeenAtMs = HashMap<String, Long>()
    private val lastComposerCheckAtMs = HashMap<String, Long>()

    private var sharedPassPackage: String? = null

    private val homePackages: Set<String> by lazy {
        context.packageManager
            .queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME), 0)
            .map { it.activityInfo.packageName }
            .toSet() + SYSTEM_UI_PACKAGE
    }

    /** Called for every app that genuinely comes to the foreground. */
    fun onForegroundPackageChanged(packageName: String) {
        // The notification shade is not the user leaving the app
        if (packageName == foregroundPackage || packageName == SYSTEM_UI_PACKAGE) return
        previousForegroundPackage = foregroundPackage
        foregroundPackage = packageName
        foregroundSinceMs = SystemClock.elapsedRealtime()
    }

    fun resetShortsScreenTime() {
        shortContentScreenTime = 0L
        SharedPrefsHelper.getSetShortsScreenTimeMs(context, 0L)
    }

    /**
     * Checks if a blocked short-form content feature is open and applies restrictions.
     *
     * @param packageName The package name of the current app in focus.
     * @param node The root `AccessibilityNodeInfo` of the current screen.
     * @param wellbeing The user's `WellBeingSettings`, including blocked features and time limits.
     */
    fun blockDistraction(
        packageName: String,
        node: AccessibilityNodeInfo,
        wellbeing: Wellbeing,
        isPagingScroll: Boolean = false,
    ) {
        // Use default youtube package for unofficial clients too
        val resolvedPackage =
            if (packageName.contains(YOUTUBE_CLIENT_PACKAGE_SUFFIX)) YOUTUBE_PACKAGE
            else packageName

        val blockedFeatures = wellbeing.blockedFeatures

        /// Check if blocking is enabled for platforms
        val isFeatureOpen = when (resolvedPackage) {
            INSTAGRAM_PACKAGE -> isInstagramFeatureOpen(node, blockedFeatures)
            SNAPCHAT_PACKAGE -> isSnapchatFeatureOpen(node, blockedFeatures)
            FACEBOOK_PACKAGE -> isFacebookFeatureOpen(node, blockedFeatures)
            REDDIT_PACKAGE -> isRedditFeatureOpen(node, blockedFeatures)
            YOUTUBE_PACKAGE -> isYoutubeFeatureOpen(node, blockedFeatures)
            else -> false
        }

        val hasSharedPass = updateSharedPass(
            resolvedPackage = resolvedPackage,
            node = node,
            isPlayerOpen = isFeatureOpen,
            isPagingScroll = isPagingScroll,
        )

        if (isFeatureOpen && !hasSharedPass) {
            maxAllowedDuration[resolvedPackage]?.let {
                updateShortsScreenTime(
                    allowedShortContentTimeMs = wellbeing.allowedShortsTimeMs,
                    maxAllowedDuration = it,
                    blockedPackageName = resolvedPackage,
                    foregroundPackage = packageName,
                )
            }
        }
    }

    /**
     * Tracks how the short player was opened and returns true while the short
     * the user was sent may keep playing regardless of the budget.
     */
    private fun updateSharedPass(
        resolvedPackage: String,
        node: AccessibilityNodeInfo,
        isPlayerOpen: Boolean,
        isPagingScroll: Boolean,
    ): Boolean {
        val now = SystemClock.elapsedRealtime()

        // Leaving the app ends everything
        if (playerPackage != null && foregroundPackage.isNotEmpty() &&
            foregroundPackage != playerPackage &&
            !foregroundPackage.contains(YOUTUBE_CLIENT_PACKAGE_SUFFIX)
        ) {
            closePlayer()
        }

        if (!isPlayerOpen) {
            // The tree walk is not free: sample the screen a few times a second
            if (now - (lastComposerCheckAtMs[resolvedPackage] ?: 0L) >= COMPOSER_CHECK_INTERVAL_MS) {
                lastComposerCheckAtMs[resolvedPackage] = now
                lastScreenWasConversation[resolvedPackage] = hasMessageComposer(node)
            }
            lastScreenSeenAtMs[resolvedPackage] = now
            if (playerPackage == resolvedPackage) {
                if (playerMissingSinceMs == 0L) {
                    playerMissingSinceMs = now
                } else if (now - playerMissingSinceMs > PLAYER_CLOSE_DEBOUNCE_MS) {
                    closePlayer()
                }
            }
            return false
        }

        playerMissingSinceMs = 0L
        if (playerPackage != resolvedPackage) {
            // The player just opened: was it from something the user was sent?
            playerPackage = resolvedPackage
            val fromConversation =
                lastScreenWasConversation[resolvedPackage] == true &&
                        now - (lastScreenSeenAtMs[resolvedPackage] ?: 0L) < CONVERSATION_WINDOW_MS
            val fromOtherApp = now - foregroundSinceMs < ENTRY_WINDOW_MS &&
                    previousForegroundPackage.isNotEmpty() &&
                    previousForegroundPackage != context.packageName &&
                    previousForegroundPackage !in homePackages
            sharedPassPackage =
                if (fromConversation || fromOtherApp) resolvedPackage else null
            if (sharedPassPackage != null) {
                Log.d(TAG, "Shared short opened in $resolvedPackage, not blocking it")
            }
        } else if (isPagingScroll && sharedPassPackage == resolvedPackage) {
            Log.d(TAG, "Moved past the shared short in $resolvedPackage")
            sharedPassPackage = null
        }

        return sharedPassPackage == resolvedPackage
    }

    private fun closePlayer() {
        playerPackage = null
        playerMissingSinceMs = 0L
        sharedPassPackage = null
    }

    /**
     * A conversation screen has a message field near the bottom of the screen
     * (search bars sit at the top).
     */
    private fun hasMessageComposer(root: AccessibilityNodeInfo): Boolean {
        val rootBounds = Rect().also(root::getBoundsInScreen)
        if (rootBounds.isEmpty) return false
        val bottomBand = rootBounds.bottom - rootBounds.height() / 3

        fun visit(node: AccessibilityNodeInfo, depth: Int): Boolean {
            if (depth > 30) return false
            if (node.className?.toString() == "android.widget.EditText" &&
                node.viewIdResourceName?.contains("search") != true
            ) {
                val bounds = Rect().also(node::getBoundsInScreen)
                if (bounds.top >= bottomBand) return true
            }
            for (index in 0 until node.childCount) {
                val child = node.getChild(index) ?: continue
                if (visit(child, depth + 1)) return true
            }
            return false
        }

        return runCatching { visit(root, 0) }.getOrDefault(false)
    }

    /**
     * Checks if a short-form content website is open in the browser based on WellBeingSettings.
     *
     * @param wellbeing The WellBeingSettings model indicating which platforms are blocked.
     * @param url      The URL text from the browser.
     * @return True if a blocked short-form content website is open, false otherwise.
     */
    fun checkAndBlockShortsOnBrowser(
        browserPackage: String,
        wellbeing: Wellbeing,
        url: String,
    ): Boolean {
        when {
            PlatformFeatures.INSTAGRAM_REELS in wellbeing.blockedFeatures
                    && doesUrlContainsAnyElement(mInstaReelUrls, url) -> true

            PlatformFeatures.INSTAGRAM_EXPLORE in wellbeing.blockedFeatures
                    && doesUrlContainsAnyElement(mInstaExploreUrls, url) -> true

            PlatformFeatures.YOUTUBE_SHORTS in wellbeing.blockedFeatures
                    && doesUrlContainsAnyElement(mYtShortUrls, url) -> true

            PlatformFeatures.FACEBOOK_REELS in wellbeing.blockedFeatures
                    && doesUrlContainsAnyElement(mFbReelUrls, url) -> true

            PlatformFeatures.SNAPCHAT_SPOTLIGHT in wellbeing.blockedFeatures
                    && doesUrlContainsAnyElement(mSnapSpotlightUrls, url) -> true

            PlatformFeatures.SNAPCHAT_DISCOVER in wellbeing.blockedFeatures
                    && doesUrlContainsAnyElement(mSnapDiscoverUrls, url) -> true

            else -> false
        }.let {
            if (it) {
                updateShortsScreenTime(
                    allowedShortContentTimeMs = wellbeing.allowedShortsTimeMs,
                    blockedPackageName = browserPackage,
                )
                return true
            }
        }

        return false
    }

    /**
     * Updates the total screen time spent on short-form content and blocks access if the allowed time is exceeded.
     *
     * @param allowedShortContentTimeMs The maximum time allowed for short-form content.
     * @param maxAllowedDuration The maximum duration considered for a single short-form content session.
     */
    private fun updateShortsScreenTime(
        allowedShortContentTimeMs: Long,
        maxAllowedDuration: Long = 30 * 1000L,
        blockedPackageName: String? = null,
        /// The app actually in front, which can differ from [blockedPackageName]
        /// for unofficial YouTube clients. Used to confirm the block still
        /// applies to what the user is looking at.
        foregroundPackage: String? = blockedPackageName,
    ) {
        // Check if limit is exhausted
        if (allowedShortContentTimeMs < 0 || shortContentScreenTime > (allowedShortContentTimeMs + SAVING_INTERVAL_MS)) {
            if (blockedPackageName == INSTAGRAM_PACKAGE) {
                blockedInstagramOpenInbox.invoke()
            } else if (foregroundPackage != null) {
                blockedContentGoBack.invoke(foregroundPackage)
            }
            return
        }

        // Calculate screen time since last check
        val currentTime = System.currentTimeMillis()
        val elapsedTime = if (lastTimeShortsEvent != 0L) currentTime - lastTimeShortsEvent else 0

        // Update only if elapsedTime is less than MAX_ALLOWED_DURATION otherwise user may have closed short content,
        shortContentScreenTime += (if (elapsedTime <= maxAllowedDuration) elapsedTime else 0)
        lastTimeShortsEvent = currentTime

        // Check if the minimum interval has passed before calling shared preferences
        if ((currentTime - lastTimeSaved) > SAVING_INTERVAL_MS) {
            SharedPrefsHelper.getSetShortsScreenTimeMs(context, shortContentScreenTime)
            lastTimeSaved = currentTime
            Log.d(
                TAG,
                "checkTimerAndBlockShortContent: shorts time saved: " + (shortContentScreenTime / 1000L) + " seconds"
            )
        }
    }


    companion object {
        private const val TAG = "Mindful.ShortsPlatformManager"

        // The minimum interval between saving short content's screen time in shared preferences
        private const val SAVING_INTERVAL_MS = (30 * 1000L)

        /// How recently the other app must have been left for the player
        /// opening to count as a shared link.
        private const val ENTRY_WINDOW_MS = 4_000L

        /// The conversation must be the screen shown right before the player.
        private const val CONVERSATION_WINDOW_MS = 60_000L

        private const val COMPOSER_CHECK_INTERVAL_MS = 300L

        /// The player must be missing this long before it counts as closed.
        private const val PLAYER_CLOSE_DEBOUNCE_MS = 1_200L

        private const val SYSTEM_UI_PACKAGE = "com.android.systemui"

        /**
         * Max allowed duration for each short content platform (based on the highest short length or duration)
         * If the interval between two short content block event is <= DURATION then it is considered that user is watching short content
         **/
        private val maxAllowedDuration = mapOf(
            INSTAGRAM_PACKAGE to (90 * 1000L),
            SNAPCHAT_PACKAGE to (60 * 1000L),
            FACEBOOK_PACKAGE to (90 * 1000L),
            REDDIT_PACKAGE to (60 * 1000L),
            YOUTUBE_PACKAGE to (3 * 60 * 1000L),
        )

        // Possible URLs of different short-form content platforms
        private val mInstaReelUrls = listOf("instagram.com/reels/", "m.instagram.com/reels/")
        private val mInstaExploreUrls = listOf("instagram.com/explore/", "m.instagram.com/explore/")

        private val mYtShortUrls = listOf("youtube.com/shorts/", "m.youtube.com/shorts/")
        private val mFbReelUrls = listOf("facebook.com/reel/", "m.facebook.com/reel/")
        private val mSnapSpotlightUrls = listOf(
            "snapchat.com/spotlight/",
            "m.snapchat.com/spotlight/",
            "web.snapchat.com/spotlight/"
        )
        private val mSnapDiscoverUrls = listOf(
            "snapchat.com/discover/",
            "m.snapchat.com/discover/",
            "web.snapchat.com/discover/"
        )

        private val mFbNodeTexts = listOf("Add a comment", "कमेंट जोड़ें…")


        /**
         * Checks if Instagram features (Reels or Search Feed) are open.
         */
        private fun isInstagramFeatureOpen(
            node: AccessibilityNodeInfo,
            blockedFeatures: Set<PlatformFeatures>,
        ): Boolean {
            return when {
                PlatformFeatures.INSTAGRAM_REELS in blockedFeatures &&
                        doesNodeByIdExists(node, "com.instagram.android:id/clips_video_container")
                -> true

                PlatformFeatures.INSTAGRAM_EXPLORE in blockedFeatures &&
                        doesNodeByIdExists(node, "com.instagram.android:id/action_bar_search_edit_text")
                -> true

                else -> false
            }
        }

        /**
         * Checks if YouTube Shorts is currently open.
         */
        private fun isYoutubeFeatureOpen(
            node: AccessibilityNodeInfo,
            blockedFeatures: Set<PlatformFeatures>,
        ): Boolean {
            return PlatformFeatures.YOUTUBE_SHORTS in blockedFeatures &&
                    doesNodeByIdExists(node, "${node.packageName}:id/reel_player_underlay")
        }

        /**
         * Checks if Snapchat Spotlight or Discover is open.
         */
        private fun isSnapchatFeatureOpen(
            node: AccessibilityNodeInfo,
            blockedFeatures: Set<PlatformFeatures>,
        ): Boolean {

            return when {
                PlatformFeatures.SNAPCHAT_SPOTLIGHT in blockedFeatures &&
                        doesNodeByIdExists(
                            node,
                            "com.snapchat.android:id/spotlight_card_static_thumbnail"
                        )
                -> true

                PlatformFeatures.SNAPCHAT_DISCOVER in blockedFeatures &&
                        doesNodeByIdExists(node, "com.snapchat.android:id/df_large_story")
                -> true

                else -> false
            }
        }

        /**
         * Checks if Facebook Reels is currently open.
         */
        private fun isFacebookFeatureOpen(
            node: AccessibilityNodeInfo,
            blockedFeatures: Set<PlatformFeatures>,
        ): Boolean {
            // TODO: Add more string translated from different languages for the node text
            //  as user may have set different language for facebook app

            if (PlatformFeatures.FACEBOOK_REELS in blockedFeatures) {
                for (text in mFbNodeTexts) {
                    if (node.findAccessibilityNodeInfosByText(text).isNotEmpty()) {
                        return true
                    }
                }
            }

            return false
        }

        /**
         * Checks if Reddit Shorts is open.
         */
        private fun isRedditFeatureOpen(
            node: AccessibilityNodeInfo,
            blockedFeatures: Set<PlatformFeatures>,
        ): Boolean {
            return PlatformFeatures.REDDIT_SHORTS in blockedFeatures && node.viewIdResourceName == "feed_vertical_pager"
        }

        /**
         * Checks if the URL contains any of the elements from the provided list of URLs.
         *
         * @param urlList The list of URL substrings to check against.
         * @param url     The URL to check.
         * @return True if the URL contains any element from the list, false otherwise.
         */
        @Contract(pure = true)
        private fun doesUrlContainsAnyElement(urlList: List<String>, url: String): Boolean {
            for (element in urlList) {
                if (url.contains(element)) return true
            }
            return false
        }

        /**
         * Checks whether an AccessibilityNodeInfo with the specified view ID exists as a descendant
         * of the given node.
         *
         * @param node   The parent AccessibilityNodeInfo to search within. This parameter must not be null.
         * @param viewId The ID of the view to look for.
         * @return `true` if a node with the specified view ID exists, `false` otherwise.
         */
        private fun doesNodeByIdExists(node: AccessibilityNodeInfo, viewId: String): Boolean {
            return node.findAccessibilityNodeInfosByViewId(viewId).isNotEmpty()
        }
    }
}
