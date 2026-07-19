package com.mindful.android.models

import org.json.JSONObject

/**
 * A single active period for a [RestrictionGroup].
 *
 * Apps in the group are allowed only when the current time is inside one of the
 * group's active periods AND the current weekday is enabled in [days].
 *
 * [days] holds exactly 7 booleans ordered Monday → Sunday, matching
 * [com.mindful.android.utils.DateTimeUtils.zeroIndexedDayOfWeek].
 */
data class ActivePeriod(
    /** Time of day (minutes from midnight) when the period starts. */
    val startMins: Int = 0,

    /** Time of day (minutes from midnight) when the period ends. */
    val endMins: Int = 0,

    /** Enabled weekdays, ordered Monday → Sunday. */
    val days: List<Boolean> = List(7) { true },
) {
    companion object {

        /**
         * Constructs an [ActivePeriod] from a JSON object of the shape
         * `{ "start": Int, "end": Int, "days": [Bool x7] }`.
         */
        fun fromJson(obj: JSONObject): ActivePeriod {
            val daysArray = obj.optJSONArray("days")
            val days = List(7) { i ->
                if (daysArray != null && i < daysArray.length()) {
                    daysArray.optBoolean(i, true)
                } else {
                    true
                }
            }

            return ActivePeriod(
                startMins = obj.optInt("start", 0),
                endMins = obj.optInt("end", 0),
                days = days,
            )
        }
    }
}
