/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */
package com.mindful.android.utils

import java.util.concurrent.atomic.AtomicBoolean

/**
 * Whether a blocking sheet overlay is currently covering the screen.
 *
 * Published by the tracker's overlay manager and read by the accessibility
 * service, which share the same process. The overlay does not pause the app
 * underneath: it keeps running and keeps emitting accessibility events, so the
 * content blockers used to keep acting on an app that is already blocked —
 * sending Back or re-opening it every throttle window, which made the app flip
 * between closed and reopened. An app behind the overlay is already handled,
 * there is nothing left to police inside it.
 */
object BlockingOverlayState {
    private val visible = AtomicBoolean(false)

    val isVisible: Boolean get() = visible.get()

    fun setVisible(value: Boolean) = visible.set(value)
}
