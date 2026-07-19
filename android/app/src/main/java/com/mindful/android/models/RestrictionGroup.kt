package com.mindful.android.models

import com.mindful.android.utils.JsonUtils
import org.json.JSONObject

/**
 * Represents a group of restricted apps with shared usage settings like timers and active periods.
 */
data class RestrictionGroup(
    /**
     * Unique ID of the group.
     */
    val id: Int = 0,

    /**
     * Name of the group (e.g., "Social", "Games").
     */
    val groupName: String = "Social",

    /**
     * Time limit for all apps in the group, in seconds.
     */
    val timerSec: Int = 0,

    /**
     * Time of day (in minutes) from midnight when the app usage is allowed to start.
     */
    val activePeriodStart: Int = 0,

    /**
     * Time of day (in minutes) from midnight when the app usage is blocked.
     *
     * Deprecated in favor of [activePeriods]. Kept for backward compatibility.
     */
    val activePeriodEnd: Int = 0,

    /**
     * List of active periods for this group. Apps are allowed only when the
     * current time falls inside one of these periods on an enabled weekday.
     * Supersedes the single [activePeriodStart]/[activePeriodEnd] window.
     */
    val activePeriods: List<ActivePeriod> = emptyList(),

    /**
     * Whether an intention must be selected before opening an app in the group.
     */
    val isIntentPromptEnabled: Boolean = false,

    /**
     * Set of app package names associated with this group.
     */
    val distractingApps: Set<String> = emptySet(),
) {
    companion object {

        /**
         * Constructs a [RestrictionGroup] from a JSON string.
         */
        fun fromJson(json: String): RestrictionGroup {
            val jsonObject = JSONObject(json)

            val periodsArray = jsonObject.optJSONArray("activePeriods")
            val activePeriods = if (periodsArray != null) {
                (0 until periodsArray.length()).mapNotNull {
                    periodsArray.optJSONObject(it)?.let(ActivePeriod::fromJson)
                }
            } else {
                emptyList()
            }

            return RestrictionGroup(
                id = jsonObject.optInt("id", 0),
                groupName = jsonObject.optString("groupName", "Social"),
                timerSec = jsonObject.optInt("timerSec", 0),
                activePeriodStart = jsonObject.optInt("activePeriodStart", 0),
                activePeriodEnd = jsonObject.optInt("activePeriodEnd", 0),
                activePeriods = activePeriods,
                isIntentPromptEnabled = jsonObject.optBoolean("isIntentPromptEnabled", false),
                distractingApps = JsonUtils.parseStringSet(
                    jsonObject.optJSONArray("distractingApps")?.toString()
                )
            )
        }
    }
}
