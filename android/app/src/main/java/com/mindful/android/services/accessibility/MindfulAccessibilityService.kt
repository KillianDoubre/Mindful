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
package com.mindful.android.services.accessibility

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.content.SharedPreferences
import android.content.SharedPreferences.OnSharedPreferenceChangeListener
import android.content.pm.PackageManager
import android.graphics.Path
import android.graphics.Rect
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
import android.view.accessibility.AccessibilityEvent.TYPE_VIEW_SCROLLED
import android.view.accessibility.AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
import android.view.accessibility.AccessibilityEvent.TYPE_WINDOWS_CHANGED
import android.view.accessibility.AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Toast
import com.mindful.android.AppConstants.FACEBOOK_PACKAGE
import com.mindful.android.AppConstants.INSTAGRAM_PACKAGE
import com.mindful.android.AppConstants.REDDIT_PACKAGE
import com.mindful.android.AppConstants.SETTINGS_PACKAGE
import com.mindful.android.AppConstants.SNAPCHAT_PACKAGE
import com.mindful.android.AppConstants.YOUTUBE_PACKAGE
import com.mindful.android.R
import com.mindful.android.enums.PlatformFeatures
import com.mindful.android.helpers.device.PermissionsHelper
import com.mindful.android.helpers.storage.SharedPrefsHelper
import com.mindful.android.models.Wellbeing
import com.mindful.android.receivers.DeviceAppsChangedReceiver
import com.mindful.android.utils.ThreadUtils
import com.mindful.android.utils.executors.Throttler
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * An AccessibilityService that monitors app usage and blocks access to specified content based on user settings.
 */
class MindfulAccessibilityService : AccessibilityService(), OnSharedPreferenceChangeListener {
    companion object {
        private const val TAG = "Mindful.MindfulAccessibilityService"
        private const val INSTAGRAM_INBOX_URI = "instagram://direct-inbox"
        // Redirect uses active polling instead of a fixed delay: it taps as soon
        // as the messages tab exists (instant when the app is already loaded) and
        // keeps re-checking every poll until the switch is confirmed or the
        // per-app deadline (maxRedirectWaitMs) is reached.
        private const val DATING_REDIRECT_POLL_MS = 300L

        /**
         * Native destinations exposed by the currently supported dating apps.
         * Resource ids are preferred because they keep the user in the running
         * app; labels cover Compose/accessibility-only navigation bars and the
         * deep link is only used when the tab is not present in the node tree.
         */
        private val DATING_MESSAGE_DESTINATIONS = mapOf(
            "com.tinder" to DatingMessageDestination(
                viewIds = listOf("com.tinder:id/action_matches"),
                labels = listOf(
                    "Conversations",
                    "Messages",
                    "Matchs",
                    "Matches",
                    "Vos matchs",
                ),
                fallbackUri = "tinder://matches",
            ),
            "co.hinge.app" to DatingMessageDestination(
                viewIds = listOf(
                    "co.hinge.app:id/matches",
                    "matches",
                ),
                labels = listOf("Matchs", "Matches", "Messages", "Vos matchs"),
                activeContentViewIds = listOf(
                    "co.hinge.app:id/messageComposition",
                    "co.hinge.app:id/messageCompositionContainer",
                    "co.hinge.app:id/sendChatButtonContainer",
                ),
                fallbackUri = "hinge://matches",
            ),
            "com.bumble.app" to DatingMessageDestination(
                viewIds = listOf("com.bumble.app:id/chat"),
                labels = listOf(
                    "Discussions",
                    "Chats",
                    "Messages",
                    "Connexions",
                    "Connections",
                ),
                // Bumble's accepted deep link remains on its launcher instead
                // of opening Chats. Target the fifth native tab directly.
                fallbackUri = null,
                navigationContainerViewId = "com.bumble.app:id/mainApp_navigationTabBar",
                navigationTabIndex = 4,
                navigationTabCount = 5,
                // Bumble's splash/app load can take ~5s before the navigation bar
                // exists and it has no deep-link fallback, so poll longer.
                maxRedirectWaitMs = 5000L,
            ),
            "com.ftw_and_co.happn" to DatingMessageDestination(
                viewIds = listOf(
                    "tab_bar_item_chat_list",
                    "com.ftw_and_co.happn:id/chat_dest",
                ),
                labels = listOf("Messages", "Conversations"),
                fallbackUri = "https://happn.com/conversations",
            ),
        )

        const val ACTION_PERFORM_HOME_PRESS = "com.mindful.android.action.performHomePress"
        const val ACTION_MIDNIGHT_ACCESSIBILITY_RESET =
            "com.mindful.android.action.midnightAccessibilityReset"
        const val ACTION_TAMPER_PROTECTION_CHANGED =
            "com.mindful.android.action.tamperProtectionChanged"

        // Set of desired events which will be processed
        private val desiredEvents = setOf(
            TYPE_WINDOWS_CHANGED,
            TYPE_WINDOW_STATE_CHANGED,
            TYPE_WINDOW_CONTENT_CHANGED,
            TYPE_VIEW_TEXT_CHANGED,
            TYPE_VIEW_SCROLLED
        )

        // Thread-safe: written from the background config executor and read
        // concurrently from the event-processing thread pool.
        private val browserPackages = ConcurrentHashMap.newKeySet<String>()
        private val shortsPlatformPackages = ConcurrentHashMap.newKeySet<String>()
        private val devicePlatformPackages = ConcurrentHashMap.newKeySet<String>()
    }


    // Fixed thread pool for parallel event processing
    private val executorService: ExecutorService = Executors.newFixedThreadPool(4)

    // Serializes config refreshes off the main looper. Only the heavy
    // PackageManager work runs here; the accessibility-tree call is posted back
    // to the main thread (a11y-tree APIs must not run off-main).
    private val configExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val throttler: Throttler = Throttler(500L)
    private val deviceAppsChangedReceiver: DeviceAppsChangedReceiver =
        DeviceAppsChangedReceiver(onAppsChanged = { refreshServiceConfig() })

    // Managers
    private lateinit var shortsPlatformManager: ShortsPlatformManager
    private lateinit var datingPlatformManager: DatingPlatformManager
    private lateinit var browserManager: BrowserManager
    private lateinit var deviceFeaturesManager: DeviceFeaturesManager
    private lateinit var trackingManager: TrackingManager

    private var wellbeing = Wellbeing()

    // Package whose messages-redirect poll chain is currently running. Prevents
    // overlapping chains (the manager can re-fire redirects during a long poll)
    // from tapping in a storm. A redirect for another app supersedes it.
    private var datingRedirectInFlightPackage: String? = null

    override fun onCreate() {
        super.onCreate()
        wellbeing = SharedPrefsHelper.getSetWellBeingSettings(this, null)

        trackingManager = TrackingManager(context = this)
        deviceFeaturesManager = DeviceFeaturesManager(
            context = this,
            blockedContentGoBack = this::goBackWithToast
        )
        shortsPlatformManager = ShortsPlatformManager(
            context = this,
            blockedContentGoBack = this::goBackWithToast,
            blockedInstagramOpenInbox = this::openInstagramInbox,
        )
        datingPlatformManager = DatingPlatformManager(
            context = this,
            blockedContentOpenMessages = this::openDatingMessages,
            getForegroundRoot = { packageName ->
                rootInActiveWindow?.takeIf {
                    it.packageName?.toString() == packageName
                }
            },
            initialResetTimeMinutes = wellbeing.datingResetTimeMinutes,
        )
        browserManager = BrowserManager(
            context = this,
            shortsPlatformManager = shortsPlatformManager,
            blockedContentGoBack = this::goBackWithToast
        )

        // Register shared prefs listener and load data
        SharedPrefsHelper.registerUnregisterListenerToListenablePrefs(this, true, this)

        // Register listener for install and uninstall events
        deviceAppsChangedReceiver.register(this)
    }


    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_MIDNIGHT_ACCESSIBILITY_RESET -> {
                shortsPlatformManager.resetShortsScreenTime()
                Log.d(TAG, "onStartCommand: Midnight reset completed")
            }

            ACTION_TAMPER_PROTECTION_CHANGED -> {
                Log.d(TAG, "onStartCommand: Tamper protection changed")
                refreshServiceConfig()
            }

            ACTION_PERFORM_HOME_PRESS -> {
                Log.d(TAG, "onStartCommand: Pressing home button")
                goBackWithToast(GLOBAL_ACTION_HOME)
            }
        }
        return super.onStartCommand(intent, flags, startId)
    }

    override fun onServiceConnected() {
        refreshServiceConfig()
        trackingManager.stopManualTracking()
        Log.d(TAG, "onCreate: Accessibility service started successfully")
        super.onServiceConnected()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        try {
            // If not desired event or executor is shutdown, then just return
            if (!desiredEvents.contains(event.eventType) || executorService.isShutdown) return

            // App-launch tracking must not wait for the accessibility tree to be ready.
            // On complex apps, rootInActiveWindow can remain null while their first
            // frames load, which used to leave a short permissive window.
            val eventPackageName = event.packageName?.toString().orEmpty()
            val isMindfulActivity = eventPackageName == packageName &&
                    event.className?.toString() == "com.mindful.android.MainActivity"
            val isRealActivityChange = event.eventType == TYPE_WINDOW_STATE_CHANGED &&
                    (eventPackageName != packageName || isMindfulActivity)
            if (eventPackageName.isNotBlank() && isRealActivityChange &&
                isForegroundWindowEvent(eventPackageName)
            ) {
                trackingManager.onNewEvent(eventPackageName)
            }

            executorService.submit {
                // Determine package and event source node
                val node = if (eventPackageName == REDDIT_PACKAGE) event.source
                else rootInActiveWindow ?: event.source

                node?.let {
                    // Dating timers also receive events from other packages so
                    // active counters stop immediately when the user leaves.
                    datingPlatformManager.onAccessibilityEvent(
                        packageName = eventPackageName,
                        node = it,
                        eventTimeMs = event.eventTime,
                        wellbeing = wellbeing.copy(),
                    )

                    // Only process if any of the content is blocked
                    if (shouldBlockContent()) {
                        processEventInBackground(
                            packageName = eventPackageName,
                            node = it,
                            wellBeing = wellbeing.copy()
                        )
                    }
                }
            }

        } catch (ignored: Exception) {
        }
    }

    /**
     * Guards app-launch tracking against false positives.
     *
     * A [TYPE_WINDOW_STATE_CHANGED] event does not guarantee the app moved to
     * the foreground: background apps emit these for notifications, toasts,
     * picture-in-picture mini-players and other non-focused windows. Treating
     * those as launches used to pop the conscious-opening prompt for apps the
     * user never opened.
     *
     * The event is accepted only when it belongs to the currently active
     * window. A null root means the foreground app is still loading (a genuine
     * fresh launch that must not be missed), so it stays permitted.
     */
    private fun isForegroundWindowEvent(eventPackageName: String): Boolean {
        val activePackage = rootInActiveWindow?.packageName?.toString() ?: return true
        return activePackage == eventPackageName
    }

    /**
     * Processes accessibility event in background thread instead of main thread.
     *
     * @param packageName The package name of the app generating the event.
     * @param node        The accessibility node representing the UI element currently in focus.
     */
    private fun processEventInBackground(
        packageName: String,
        node: AccessibilityNodeInfo,
        wellBeing: Wellbeing,
    ) {
        try {
            when (packageName) {
                in devicePlatformPackages ->
                    deviceFeaturesManager.blockFeatures(packageName, node, wellBeing)

                in shortsPlatformPackages ->
                    shortsPlatformManager.blockDistraction(packageName, node, wellBeing)

                in browserPackages ->
                    browserManager.blockDistraction(packageName, node, wellBeing)
            }

        } catch (e: Exception) {
            Log.e(
                TAG,
                "processEventInBackground: Failed to process accessibility event in background",
                e
            )
            SharedPrefsHelper.insertCrashLogToPrefs(this, e)
        }
    }


    /**
     * Determines whether content should be blocked based on the current settings.
     *
     * @return `true` if content should be blocked based on the current settings,
     * `false` otherwise.
     */
    private fun shouldBlockContent(): Boolean {
        // Tamper protection: when device admin is granted, the system settings
        // package is added to devicePlatformPackages. It must be able to trigger
        // processing on its own, otherwise the admin/accessibility settings page
        // is only blocked as a side effect of some other active content block.
        return devicePlatformPackages.isNotEmpty() ||
                wellbeing.blockedFeatures.isNotEmpty() ||
                wellbeing.blockedWebsites.isNotEmpty() ||
                wellbeing.nsfwWebsites.isNotEmpty() ||
                wellbeing.blockNsfwSites ||
                wellbeing.datingBlocks.any { it.isEnabled }
    }


    /**
     * Performs the back action and shows a toast message indicating that the content is blocked.
     */
    private fun goBackWithToast(customAction: Int? = null) {
        throttler.submit {
            ThreadUtils.runOnMainThread {
                // Perform the back action (can be done on background thread)
                performGlobalAction(customAction ?: GLOBAL_ACTION_BACK)

                // Post Toast to main thread
                Toast.makeText(
                    this@MindfulAccessibilityService,
                    getString(R.string.toast_blocked_content),
                    Toast.LENGTH_LONG
                ).show()
            }
        }
    }

    /** Opens Instagram's messaging page when its Shorts budget is exhausted. */
    private fun openInstagramInbox() {
        throttler.submit {
            ThreadUtils.runOnMainThread {
                runCatching {
                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(INSTAGRAM_INBOX_URI))
                            .setPackage(INSTAGRAM_PACKAGE)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    )
                }.onFailure {
                    Log.e(TAG, "openInstagramInbox: Unable to open Instagram inbox", it)
                    performGlobalAction(GLOBAL_ACTION_BACK)
                }
            }
        }
    }

    /**
     * Redirects an exhausted dating discovery page to the app's own messages
     * tab instead of issuing a global Back/Home action.
     */
    private fun openDatingMessages(
        packageName: String,
        sourceNode: AccessibilityNodeInfo?,
    ) {
        // Runs on the main thread so datingRedirectInFlightPackage is only ever
        // touched there (this can be invoked from a background executor).
        ThreadUtils.runOnMainThread {
            // Ignore a duplicate redirect for the same app while its poll runs; a
            // redirect for a different app takes over.
            if (datingRedirectInFlightPackage == packageName) return@runOnMainThread
            datingRedirectInFlightPackage = packageName
            tryOpenDatingMessages(
                packageName = packageName,
                startElapsedMs = SystemClock.elapsedRealtime(),
                hasClicked = false,
            )
        }
    }

    /**
     * Actively polls for the app's messages tab: taps it the instant it exists
     * (immediate when the app is already loaded) and keeps re-checking until the
     * switch is confirmed or the per-app deadline is reached. This avoids both a
     * fixed pre-delay (lag when already loaded) and trusting a single tap that
     * Compose reports as handled without actually switching tabs.
     */
    private fun tryOpenDatingMessages(
        packageName: String,
        startElapsedMs: Long,
        hasClicked: Boolean,
    ) {
        ThreadUtils.runOnMainThread {
            runCatching {
                // Superseded by a redirect for another app.
                if (datingRedirectInFlightPackage != packageName) return@runCatching

                val destination = DATING_MESSAGE_DESTINATIONS[packageName] ?: run {
                    datingRedirectInFlightPackage = null
                    return@runCatching
                }

                // Foreground guard: if the user has left or closed the dating app,
                // abort the whole chain. We must never chase the messages page — nor
                // deep-link back into it — once the app is no longer in front. A null
                // package means the accessibility tree is not ready yet (e.g. during
                // the splash), so we keep waiting rather than aborting in that case.
                val root = rootInActiveWindow
                val activePackage = root?.packageName?.toString()
                if (activePackage != null && activePackage != packageName) {
                    datingRedirectInFlightPackage = null
                    Log.d(
                        TAG,
                        "openDatingMessages: $packageName left for $activePackage, aborting redirect"
                    )
                    return@runCatching
                }
                val currentRoot = root?.takeIf { activePackage == packageName }

                // Confirmed on the messages tab → done (toast only if we caused it).
                if (currentRoot != null &&
                    isDatingMessageDestinationActive(currentRoot, destination)
                ) {
                    datingRedirectInFlightPackage = null
                    if (hasClicked) showDatingRedirectToast()
                    Log.d(TAG, "openDatingMessages: $packageName on messages")
                    return@runCatching
                }

                // Tap only when the tab is actually present (nothing is tapped
                // during the splash, since the click helpers require a target).
                val clickedNow = currentRoot != null &&
                        clickDatingMessageDestination(currentRoot, destination)
                val clicked = hasClicked || clickedNow

                val waitedMs = SystemClock.elapsedRealtime() - startElapsedMs
                if (waitedMs < destination.maxRedirectWaitMs) {
                    ThreadUtils.runOnMainThread(DATING_REDIRECT_POLL_MS) {
                        tryOpenDatingMessages(packageName, startElapsedMs, clicked)
                    }
                    return@runCatching
                }

                // Deadline reached without confirming the switch: deep-link
                // fallback when the app has a reliable one — but only while the app
                // is still confirmed in the foreground, so a closed app is never
                // relaunched by the fallback.
                datingRedirectInFlightPackage = null
                if (destination.fallbackUri != null && activePackage == packageName) {
                    startActivity(
                        Intent(Intent.ACTION_VIEW, Uri.parse(destination.fallbackUri))
                            .setPackage(packageName)
                            .addFlags(
                                Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                            )
                    )
                    showDatingRedirectToast()
                } else {
                    Log.w(TAG, "openDatingMessages: Messages tab unavailable for $packageName")
                }
            }.onFailure {
                if (datingRedirectInFlightPackage == packageName) {
                    datingRedirectInFlightPackage = null
                }
                // Do not fall back to Back/Home: that would close the dating
                // app, which is precisely what this feature must avoid.
                Log.e(TAG, "openDatingMessages: Unable to open messages for $packageName", it)
            }
        }
    }

    private fun showDatingRedirectToast() {
        Toast.makeText(
            this@MindfulAccessibilityService,
            getString(R.string.toast_dating_redirect_messages),
            Toast.LENGTH_LONG,
        ).show()
    }

    private fun clickDatingMessageDestination(
        root: AccessibilityNodeInfo,
        destination: DatingMessageDestination,
    ): Boolean {
        destination.viewIds.forEach { viewId ->
            findNodesByViewId(root, viewId).forEach { node ->
                // A real tap at the tab node's centre is far more reliable than
                // ACTION_CLICK, which Compose (Bumble) reports as handled without
                // actually switching tabs. Fall back to ACTION_CLICK otherwise.
                if (tapClickableNodeCenter(node) || clickNodeOrClickableParent(node)) return true
            }
        }

        return findNodeWithExactLabel(root, destination.labels)?.let { node ->
            // Bumble's Compose navigation reports ACTION_CLICK as handled but
            // sometimes does not change tabs. A real tap at the tab's centre
            // reliably activates Chats and also works for the other supported
            // navigation bars.
            tapClickableNodeCenter(node) || clickNodeOrClickableParent(node)
        } == true || tapNavigationDestination(root, destination)
    }

    private fun isDatingMessageDestinationActive(
        root: AccessibilityNodeInfo,
        destination: DatingMessageDestination,
    ): Boolean {
        if (destination.activeContentViewIds.any { findNodesByViewId(root, it).isNotEmpty() }) {
            return true
        }

        val selectedById = destination.viewIds.any { viewId ->
            findNodesByViewId(root, viewId).any(::isNodeOrParentSelected)
        }
        return selectedById || containsSelectedExactLabel(root, destination.labels)
    }

    private fun containsSelectedExactLabel(
        node: AccessibilityNodeInfo,
        labels: List<String>,
    ): Boolean {
        val nodeLabels = listOfNotNull(node.text, node.contentDescription)
            .map { it.toString().trim() }
        if (nodeLabels.any { value -> labels.any { it.equals(value, ignoreCase = true) } } &&
            isNodeOrParentSelected(node)
        ) {
            return true
        }

        for (index in 0 until node.childCount) {
            node.getChild(index)?.let { child ->
                if (containsSelectedExactLabel(child, labels)) return true
            }
        }
        return false
    }

    private fun isNodeOrParentSelected(node: AccessibilityNodeInfo): Boolean {
        var candidate: AccessibilityNodeInfo? = node
        repeat(5) {
            val current = candidate ?: return false
            if (current.isSelected || current.isChecked) return true
            candidate = current.parent
        }
        return false
    }

    private fun findNodeWithExactLabel(
        node: AccessibilityNodeInfo,
        labels: List<String>,
    ): AccessibilityNodeInfo? {
        val nodeLabels = listOfNotNull(node.text, node.contentDescription)
            .map { it.toString().trim() }
        if (nodeLabels.any { value -> labels.any { it.equals(value, ignoreCase = true) } }) {
            return node
        }

        for (index in 0 until node.childCount) {
            node.getChild(index)?.let { child ->
                findNodeWithExactLabel(child, labels)?.let { return it }
            }
        }
        return null
    }

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

    private fun clickNodeOrClickableParent(node: AccessibilityNodeInfo): Boolean {
        var candidate: AccessibilityNodeInfo? = node
        repeat(5) {
            val current = candidate ?: return false
            if (current.isClickable && current.performAction(AccessibilityNodeInfo.ACTION_CLICK)) {
                return true
            }
            candidate = current.parent
        }
        return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
    }

    private fun tapNodeCenter(node: AccessibilityNodeInfo): Boolean {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        if (bounds.isEmpty) return false

        return dispatchTap(bounds.exactCenterX(), bounds.exactCenterY())
    }

    /**
     * Taps the centre of the node's nearest clickable ancestor (or the node
     * itself). The view-id/label match can be a small inner icon or text, so
     * targeting the whole tab hit-area lands the gesture far more reliably.
     */
    private fun tapClickableNodeCenter(node: AccessibilityNodeInfo): Boolean {
        var candidate: AccessibilityNodeInfo? = node
        var depth = 0
        while (candidate != null && depth < 5) {
            if (candidate.isClickable) return tapNodeCenter(candidate)
            candidate = candidate.parent
            depth++
        }
        return tapNodeCenter(node)
    }

    private fun tapNavigationDestination(
        root: AccessibilityNodeInfo,
        destination: DatingMessageDestination,
    ): Boolean {
        val containerId = destination.navigationContainerViewId ?: return false
        val tabIndex = destination.navigationTabIndex ?: return false
        val tabCount = destination.navigationTabCount ?: return false
        if (tabCount <= 0 || tabIndex !in 0 until tabCount) return false

        val container = findNodesByViewId(root, containerId).firstOrNull()
            ?: return false

        // Prefer the real tab node's centre when the bar exposes one child per
        // tab — more precise than assuming equal-width tabs (Bumble's bar is not
        // evenly divided). Fall back to geometry only if the layout differs.
        if (container.childCount == tabCount) {
            container.getChild(tabIndex)?.let { tab ->
                val tabBounds = Rect()
                tab.getBoundsInScreen(tabBounds)
                if (!tabBounds.isEmpty) {
                    return dispatchTap(tabBounds.exactCenterX(), tabBounds.exactCenterY())
                }
            }
        }

        val bounds = Rect()
        container.getBoundsInScreen(bounds)
        if (bounds.isEmpty) return false

        val tabWidth = bounds.width().toFloat() / tabCount
        val x = bounds.left + tabWidth * (tabIndex + 0.5f)
        return dispatchTap(x, bounds.exactCenterY())
    }

    private fun dispatchTap(x: Float, y: Float): Boolean {
        val tapPath = Path().apply {
            moveTo(x, y)
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(tapPath, 0L, 80L))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    /**
     * Updates the service info with the latest settings and registered packages.
     */
    private fun refreshServiceConfig() {
        // The PackageManager queries below are the expensive part and used to
        // block the main looper (shared with the Flutter UI) on every settings
        // change — the "Définir" freeze. Run them on a background thread, but
        // marshal the accessibility-tree call (updateConfig -> rootInActiveWindow)
        // back to the main thread, since a11y-tree APIs must run on main.
        configExecutor.execute { refreshServiceConfigInternal() }
    }

    private fun refreshServiceConfigInternal() {
        try {
            // Using hashset to avoid duplicates
            browserPackages.clear()
            devicePlatformPackages.clear()
            shortsPlatformPackages.clear()
            val pm = packageManager

            // Check admin and add settings to blocked packages
            if (PermissionsHelper.getAndAskAdminPermission(this, false)) {
                devicePlatformPackages.add(SETTINGS_PACKAGE)
            }

            // Fetch installed browser packages
            val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("http://www.google.com"))
            pm.queryIntentActivities(browserIntent, PackageManager.MATCH_ALL).forEach {
                browserPackages.add(it.activityInfo.packageName)
            }

            wellbeing.blockedFeatures.forEach { feature ->
                when (feature) {
                    /// Instagram
                    PlatformFeatures.INSTAGRAM_REELS,
                    PlatformFeatures.INSTAGRAM_EXPLORE,
                        -> shortsPlatformPackages.add(INSTAGRAM_PACKAGE)

                    // Snapchat
                    PlatformFeatures.SNAPCHAT_SPOTLIGHT,
                    PlatformFeatures.SNAPCHAT_DISCOVER,
                        -> shortsPlatformPackages.add(SNAPCHAT_PACKAGE)

                    // Facebook
                    PlatformFeatures.FACEBOOK_REELS ->
                        shortsPlatformPackages.add(FACEBOOK_PACKAGE)

                    // Reddit
                    PlatformFeatures.REDDIT_SHORTS ->
                        shortsPlatformPackages.add(REDDIT_PACKAGE)

                    // Youtube
                    PlatformFeatures.YOUTUBE_SHORTS -> {
                        // Add official package
                        shortsPlatformPackages.add(YOUTUBE_PACKAGE)

                        // Now add other unofficial clients
                        val ytIntent =
                            Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com"))
                        pm.queryIntentActivities(ytIntent, PackageManager.MATCH_ALL)
                            .filterNot { browserPackages.contains(it.activityInfo.packageName) }
                            .forEach {
                                shortsPlatformPackages.add(it.activityInfo.packageName)
                            }
                    }
                }
            }


            // Accessibility-tree access must run on the main looper.
            mainHandler.post { datingPlatformManager.updateConfig(wellbeing) }

            // Load nsfw website domains if needed
            if (wellbeing.blockNsfwSites) BrowserManager.initializeNsfwDomains()
            else BrowserManager.clearNsfwDomains()

            Log.d(
                TAG, "refreshServiceConfig: Accessibility service config updated successfully: " +
                        "\n settings: $wellbeing" +
                        "\n device platforms: $devicePlatformPackages" +
                        "\n short platforms: $shortsPlatformPackages" +
                        "\n browsers: $browserPackages"
            )
        } catch (e: Exception) {
            Log.e(TAG, "refreshServiceInfo: Failed to refresh service info", e)
            SharedPrefsHelper.insertCrashLogToPrefs(this, e)
        }
    }

    override fun onSharedPreferenceChanged(prefs: SharedPreferences, changedKey: String?) {
        changedKey?.let { key ->
            if (key == SharedPrefsHelper.PREF_KEY_WELLBEING_SETTINGS) {
                Log.d(TAG, "OnSharedPrefsChanged: Key changed = $changedKey")
                wellbeing = SharedPrefsHelper.getSetWellBeingSettings(this, null)
                refreshServiceConfig()
            }
        }
    }

    override fun onInterrupt() {
    }

    override fun onDestroy() {
        try {
            executorService.shutdownNow()
            configExecutor.shutdownNow()
            datingPlatformManager.shutdown()
            trackingManager.startManualTracking()

            // Unregister prefs listener and receiver
            deviceAppsChangedReceiver.unRegister(this)
            SharedPrefsHelper.registerUnregisterListenerToListenablePrefs(this, false, this)
        } catch (e: Exception) {
            // ignored
        }

        Log.d(TAG, "onDestroy: Accessibility service destroyed")
        super.onDestroy()
    }

    private data class DatingMessageDestination(
        val viewIds: List<String>,
        val labels: List<String>,
        val activeContentViewIds: List<String> = emptyList(),
        val fallbackUri: String?,
        val navigationContainerViewId: String? = null,
        val navigationTabIndex: Int? = null,
        val navigationTabCount: Int? = null,
        /// How long to keep polling/tapping for the messages tab before giving up
        /// (and using the deep-link fallback if any). Instant when the tab already
        /// exists; only matters while the app is still loading.
        val maxRedirectWaitMs: Long = 1500L,
    )
}
