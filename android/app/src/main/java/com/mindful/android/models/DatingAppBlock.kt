package com.mindful.android.models

import org.json.JSONObject

/**
 * Per-app dating blocking configuration.
 *
 * When [isEnabled], the accessibility service tracks time spent on the app's
 * engagement pages (discovery, standout, likes-you, map, edit-profile) and blocks
 * them once [allowedMinutes] of daily usage is exhausted, until the daily reset.
 */
data class DatingAppBlock(
    val appPackage: String = "",
    val allowedMinutes: Int = 30,
    val isEnabled: Boolean = false,
) {
    /** Allowed daily budget in milliseconds. */
    val allowedMs: Long get() = allowedMinutes * 60 * 1000L

    companion object {
        fun fromJson(obj: JSONObject): DatingAppBlock = DatingAppBlock(
            appPackage = obj.optString("appPackage", ""),
            allowedMinutes = obj.optInt("allowedMinutes", 30),
            isEnabled = obj.optBoolean("isEnabled", false),
        )
    }
}
