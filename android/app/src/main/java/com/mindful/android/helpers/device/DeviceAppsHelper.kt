package com.mindful.android.helpers.device

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.SystemClock
import android.util.Log
import com.mindful.android.AppConstants
import com.mindful.android.AppConstants.REMOVED_APP_NAME
import com.mindful.android.AppConstants.REMOVED_PACKAGE
import com.mindful.android.AppConstants.TETHERING_APP_NAME
import com.mindful.android.AppConstants.TETHERING_PACKAGE
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Callable
import java.util.concurrent.Executors

object DeviceAppsHelper {
    private const val TAG = "Mindful.DeviceAppsHelper"

    /// Icons are displayed at most ~40dp, so a 128px bitmap is plenty and far
    /// cheaper to render, compress and ship over the channel than full-size ones.
    private const val ICON_SIZE_PX = 128

    /// Cached icons are regenerated after this age so theme/icon-pack changes
    /// eventually show up even without an app update.
    private const val ICON_CACHE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000L
    private const val ICON_CACHE_DIR = "app_icons"

    /**
     * Retrieves a list of installed device apps with their infos.
     *
     * @param context       The context to use for fetching app information.
     * @param onSuccess Callback which will be invoke after fetching infos.
     */
    fun getDeviceAppInfos(
        context: Context,
        onSuccess: (data: Any) -> Unit,
    ) {
        Thread {
            val startedAt = SystemClock.elapsedRealtime()
            val packageManager = context.packageManager
            val cacheDir = File(context.cacheDir, ICON_CACHE_DIR).apply { mkdirs() }

            // Fetch set of important apps like Dialer, Launcher etc.
            val impSystemApps = ImpSystemAppsHelper.fetchImpApps(packageManager)
            impSystemApps.add(context.packageName)
            impSystemApps.add(AppConstants.SETTINGS_PACKAGE)

            // Fetch set of all launchable apps
            val launchableApps = packageManager.queryIntentActivities(
                Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER),
                0
            ).distinctBy { it.activityInfo.packageName }

            // Labels and icons are loaded independently per app, so spread the work
            val threads = Runtime.getRuntime().availableProcessors().coerceIn(2, 6)
            val executor = Executors.newFixedThreadPool(threads)
            val deviceAppsMapList: MutableList<Map<String, Any>> = try {
                executor.invokeAll(
                    launchableApps.map { resolveInfo ->
                        Callable {
                            val appInfo = resolveInfo.activityInfo.applicationInfo
                            val packageName = resolveInfo.activityInfo.packageName
                            getAppInfoMap(
                                name = resolveInfo.loadLabel(packageManager).toString(),
                                packageName = packageName,
                                isImpSysApp = impSystemApps.contains(packageName),
                                appIcon = getCachedAppIcon(
                                    packageManager,
                                    cacheDir,
                                    packageName,
                                    appInfo
                                ),
                            )
                        }
                    }
                ).map { it.get() }.toMutableList()
            } finally {
                executor.shutdown()
            }

            // Get placeholder icon
            val placeholderIcon = encodeIcon(packageManager.getApplicationIcon(ApplicationInfo()))

            // Add additional apps for network usage
            deviceAppsMapList.add(
                getAppInfoMap(
                    name = TETHERING_APP_NAME,
                    packageName = TETHERING_PACKAGE,
                    isImpSysApp = true,
                    appIcon = placeholderIcon,
                )
            )

            // removed apps
            deviceAppsMapList.add(
                getAppInfoMap(
                    name = REMOVED_APP_NAME,
                    packageName = REMOVED_PACKAGE,
                    isImpSysApp = true,
                    appIcon = placeholderIcon,
                )
            )

            Log.d(
                TAG,
                "getDeviceAppInfos: ${launchableApps.size} apps in " +
                        "${SystemClock.elapsedRealtime() - startedAt}ms"
            )
            onSuccess(deviceAppsMapList)
        }.start()
    }

    /**
     * Returns the PNG bytes of the app icon, reusing the on-disk copy made for the
     * same installed version of the app when available.
     */
    private fun getCachedAppIcon(
        packageManager: PackageManager,
        cacheDir: File,
        packageName: String,
        appInfo: ApplicationInfo,
    ): ByteArray {
        val versionStamp = runCatching {
            packageManager.getPackageInfo(packageName, 0).lastUpdateTime
        }.getOrDefault(0L)
        val cacheFile = File(cacheDir, "${packageName}_$versionStamp.png")

        if (cacheFile.exists() &&
            System.currentTimeMillis() - cacheFile.lastModified() < ICON_CACHE_MAX_AGE_MS
        ) {
            runCatching { return cacheFile.readBytes() }
        }

        val bytes = encodeIcon(packageManager.getApplicationIcon(appInfo))
        if (bytes.isNotEmpty()) {
            runCatching {
                // Drop copies made for older versions of this app
                cacheDir.listFiles { f -> f.name.startsWith("${packageName}_") }
                    ?.forEach { it.delete() }
                cacheFile.writeBytes(bytes)
            }
        }
        return bytes
    }

    /**
     * Renders the drawable into a [ICON_SIZE_PX] square bitmap and encodes it as PNG.
     * Returns an empty array on failure, which Flutter shows as a fallback icon.
     */
    private fun encodeIcon(icon: Drawable): ByteArray = runCatching {
        val bitmap = Bitmap.createBitmap(ICON_SIZE_PX, ICON_SIZE_PX, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        icon.setBounds(0, 0, ICON_SIZE_PX, ICON_SIZE_PX)
        icon.draw(canvas)

        val output = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
        bitmap.recycle()
        output.toByteArray()
    }.getOrElse {
        Log.e(TAG, "encodeIcon: Cannot render app icon", it)
        ByteArray(0)
    }

    private fun getAppInfoMap(
        name: String,
        packageName: String,
        isImpSysApp: Boolean,
        appIcon: ByteArray,
    ): Map<String, Any> {
        return mapOf(
            "appName" to name,
            "packageName" to packageName,
            "isImpSysApp" to isImpSysApp,
            "appIcon" to appIcon,
        )
    }
}
