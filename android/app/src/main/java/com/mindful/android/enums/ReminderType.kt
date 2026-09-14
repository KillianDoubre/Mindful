package com.mindful.android.enums

enum class ReminderType {
    NONE,
    NOTIFICATION,
    MODAL_SHEET;

    companion object {
        fun fromName(name: String): ReminderType {
            return when (name) {
                "none" -> NONE
                // Legacy value: the toast reminder was removed, it now shows nothing
                "toast" -> NONE
                "notification" -> NOTIFICATION
                "modalSheet" -> MODAL_SHEET
                else -> NONE
            }
        }
    }
}