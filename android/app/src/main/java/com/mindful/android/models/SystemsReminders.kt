/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */
package com.mindful.android.models

import com.mindful.android.utils.JsonUtils
import org.json.JSONObject

/**
 * A single recurring Systems reminder (time of day + active weekdays).
 *
 * [days] follows the app-wide convention: [0] = Monday ... [6] = Sunday,
 * matching [com.mindful.android.utils.DateTimeUtils.zeroIndexedDayOfWeek].
 */
data class SystemReminder(
    val isEnabled: Boolean = false,
    val minutes: Int = 0,
    val days: List<Boolean> = List(7) { true },
) {
    companion object {
        private val DEFAULT_DAYS = List(7) { true }

        fun fromJson(jsonObject: JSONObject?): SystemReminder {
            if (jsonObject == null) return SystemReminder()
            return SystemReminder(
                isEnabled = jsonObject.optBoolean("isEnabled", false),
                minutes = jsonObject.optInt("minutes", 0),
                days = JsonUtils.parseBooleanList(
                    jsonObject.optJSONArray("days")?.toString(),
                    DEFAULT_DAYS
                )
            )
        }
    }
}

/**
 * The two independent Systems reminders configured from the settings screen.
 */
data class SystemsReminders(
    val daily: SystemReminder = SystemReminder(),
    val weekly: SystemReminder = SystemReminder(),
) {
    companion object {
        fun fromJson(json: String): SystemsReminders {
            val jsonObject = JSONObject(json)
            return SystemsReminders(
                daily = SystemReminder.fromJson(jsonObject.optJSONObject("daily")),
                weekly = SystemReminder.fromJson(jsonObject.optJSONObject("weekly")),
            )
        }
    }
}
