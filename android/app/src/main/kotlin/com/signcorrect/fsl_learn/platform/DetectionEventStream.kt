package com.signcorrect.fsl_learn.platform

import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.EventChannel

/**
 * Singleton EventChannel stream handler for hand detection results.
 *
 * Uses a version counter to prevent a stale [onCancel] from clearing the
 * event sink when a newer subscription is already active (race between
 * old subscription cancellation and new subscription creation on screen
 * re-open).
 *
 * Emission is throttled to [MIN_EMIT_INTERVAL_MS] so we don't marshal and
 * rebuild on every camera frame. When multiple frames arrive within one
 * interval the most recent one wins (kept in [pendingEvent] and flushed on
 * the next tick), so the overlay always reflects the latest hand pose while
 * keeping platform-channel traffic and Dart work to a fixed cadence.
 */
object DetectionEventStream : EventChannel.StreamHandler {

    // Emit at most one detection event every 50ms (~20 fps). Enough to keep
    // the overlay, feedback pill and debug readout smooth without flooding
    // the platform channel / Dart recognizer on every frame.
    private const val MIN_EMIT_INTERVAL_MS = 50L

    private var eventSink: EventChannel.EventSink? = null

    private val mainHandler = Handler(Looper.getMainLooper())

    // Version counter: incremented on every onListen, decremented on every
    // onCancel.  The sink is only cleared when the counter reaches zero,
    // meaning no active listeners remain.
    private var activeListeners = 0

    // Throttling state (only touched on the main thread via mainHandler).
    private var lastEmitMs = 0L
    private var pendingEvent: Map<String, Any?>? = null
    private var tickScheduled = false

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?
    ) {
        activeListeners++
        eventSink = events
        // Fresh subscription: reset throttle so the first frame emits
        // immediately.
        lastEmitMs = 0L
    }

    override fun onCancel(arguments: Any?) {
        activeListeners--
        if (activeListeners <= 0) {
            activeListeners = 0
            eventSink = null
            pendingEvent = null
            tickScheduled = false
        }
    }

    fun send(event: Map<String, Any?>) {

        mainHandler.post {
            val ctx = eventSink ?: return@post
            val now = SystemClock.uptimeMillis()

            if (now - lastEmitMs >= MIN_EMIT_INTERVAL_MS) {
                // Interval elapsed: emit immediately.
                lastEmitMs = now
                ctx.success(event)
            } else {
                // Too soon: stash the latest and flush it on the next tick.
                pendingEvent = event
                if (!tickScheduled) {
                    tickScheduled = true
                    mainHandler.postDelayed(::flushTick, MIN_EMIT_INTERVAL_MS)
                }
            }
        }
    }

    private fun flushTick() {
        tickScheduled = false
        if (eventSink == null) {
            pendingEvent = null
            return
        }
        val ctx = eventSink ?: return
        val pending = pendingEvent
        pendingEvent = null
        if (pending != null) {
            lastEmitMs = SystemClock.uptimeMillis()
            ctx.success(pending)
        }
    }

    fun hasListener(): Boolean {
        return eventSink != null
    }
}
