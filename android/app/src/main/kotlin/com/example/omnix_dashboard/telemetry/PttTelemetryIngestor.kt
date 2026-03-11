package com.example.omnix_dashboard.telemetry

import android.content.Context
import android.content.Intent
import android.app.KeyguardManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import com.example.omnix_dashboard.BuildConfig
import java.util.TreeMap

object PttIntentActions {
    const val DOWN: String = "com.zello.ptt.down"
    const val UP: String = "com.zello.ptt.up"
    const val TOGGLE: String = "com.zello.ptt.toggle"
    const val EXTRA1_DOWN: String = "com.zello.intent.buttonExtra1.down"
    const val EXTRA1_UP: String = "com.zello.intent.buttonExtra1.up"
    const val SOS_DOWN: String = "com.zello.intent.buttonSOS.down"
    const val SOS_UP: String = "com.zello.intent.buttonSOS.up"

    val all: Set<String> = setOf(
        DOWN,
        UP,
        TOGGLE,
        EXTRA1_DOWN,
        EXTRA1_UP,
        SOS_DOWN,
        SOS_UP,
    )

    fun toState(action: String): String = when (action) {
        DOWN -> "ptt_down"
        UP -> "ptt_up"
        TOGGLE -> "ptt_toggle"
        EXTRA1_DOWN -> "ptt2_down"
        EXTRA1_UP -> "ptt2_up"
        SOS_DOWN -> "sos_down"
        SOS_UP -> "sos_up"
        else -> "ptt_event"
    }
}

object PttTelemetryIngestor {
    private const val FSK_HEARTBEAT_PREFS = "onyx_guard_telemetry"
    private const val DEDUPE_WINDOW_MS = 1200L

    private val dedupeLock = Any()
    private var lastSignature: String? = null
    private var lastProcessedAtMs: Long = 0L

    fun ingestIntent(
        context: Context,
        intent: Intent,
        source: String,
    ): Boolean {
        val action = intent.action.orEmpty()
        if (!PttIntentActions.all.contains(action)) {
            return false
        }

        val extrasMap = bundleToMap(intent.extras)
        val signature = eventSignature(action, extrasMap)
        if (isDuplicate(signature)) {
            Log.i(
                ONYX_TELEMETRY_TAG,
                "ptt_ingest_deduped action=$action source=$source extras=${mapPayloadKeys(extrasMap)}",
            )
            return false
        }

        val pttState = PttIntentActions.toState(action)
        val deviceState = resolveDeviceState(context)
        val fallbackPayload = mutableMapOf<String, Any?>(
            "pulse" to (toIntOrNull(extrasMap["pulse"]) ?: toIntOrNull(extrasMap["hr"]) ?: 72),
            "movement" to when (pttState) {
                "ptt_down" -> 1.0
                "ptt_up" -> 0.0
                else -> 0.5
            },
            "state" to pttState,
            "captured_at_utc" to (
                toTrimmedStringOrNull(extrasMap["captured_at_utc"])
                    ?: toTrimmedStringOrNull(extrasMap["timestamp"])
                    ?: toTrimmedStringOrNull(extrasMap["time_utc"])
                    ?: nowUtcIso()
            ),
        ).apply {
            toIntOrNull(extrasMap["battery"])?.let { this["battery"] = it }
            toIntOrNull(extrasMap["battery_level"])?.let { this["battery_level"] = it }
            toDoubleOrNull(extrasMap["gps_accuracy"])?.let { this["gps_accuracy"] = it }
            toDoubleOrNull(extrasMap["accuracy"])?.let { this["accuracy"] = it }
        }

        val adapterRegistry = FskPayloadAdapterRegistry()
        val (adapter, _) = adapterRegistry.resolve("legacy_ptt")
        val validation = adapter.normalize(fallbackPayload)
        if (!validation.accepted || validation.normalized == null) {
            Log.e(
                ONYX_TELEMETRY_TAG,
                "ptt_ingest_rejected action=$action source=$source error=${validation.message}",
            )
            return false
        }

        val normalizedMap = validation.normalized.toMap(
            providerId = "fsk_sdk",
            sdkStatus = if (BuildConfig.USE_LIVE_FSK_SDK) "live" else "stub",
            source = source,
        ).apply {
            this["device_locked"] = deviceState.locked
            this["device_interactive"] = deviceState.interactive
            this["device_lock_state"] = if (deviceState.locked) "locked" else "unlocked"
            this["device_state_source"] = "android_runtime"
            this["payload_adapter"] = "legacy_ptt"
            this["ptt_action"] = action
            this["ptt_state"] = pttState
            this["ingest_source"] = source
            for ((key, value) in extrasMap) {
                this["raw_${key.lowercase()}"] = value
            }
        }

        val store = FskHeartbeatStore(
            context.getSharedPreferences(FSK_HEARTBEAT_PREFS, Context.MODE_PRIVATE),
        )
        store.saveHeartbeat(normalizedMap)

        Log.i(
            ONYX_TELEMETRY_TAG,
            "ptt_ingest_accepted action=$action source=$source state=$pttState locked=${deviceState.locked} interactive=${deviceState.interactive} extras=${mapPayloadKeys(extrasMap)}",
        )
        return true
    }

    private data class DeviceState(
        val locked: Boolean,
        val interactive: Boolean,
    )

    private fun resolveDeviceState(context: Context): DeviceState {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val keyguardManager = context.getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
        val interactive = when {
            powerManager == null -> true
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT_WATCH -> powerManager.isInteractive
            else -> {
                @Suppress("DEPRECATION")
                powerManager.isScreenOn
            }
        }
        val keyguardLocked = keyguardManager?.isKeyguardLocked ?: false
        // Treat non-interactive as locked for telemetry triage.
        val locked = keyguardLocked || !interactive
        return DeviceState(locked = locked, interactive = interactive)
    }

    private fun isDuplicate(signature: String): Boolean {
        val nowMs = SystemClock.elapsedRealtime()
        synchronized(dedupeLock) {
            val duplicate =
                signature == lastSignature && (nowMs - lastProcessedAtMs) <= DEDUPE_WINDOW_MS
            if (!duplicate) {
                lastSignature = signature
                lastProcessedAtMs = nowMs
            }
            return duplicate
        }
    }

    private fun eventSignature(action: String, extrasMap: Map<String, Any?>): String {
        val sorted = TreeMap<String, Any?>()
        sorted.putAll(extrasMap)
        val payload = sorted.entries.joinToString("&") { "${it.key}=${it.value}" }
        return "$action|$payload"
    }

    private fun bundleToMap(bundle: Bundle?): Map<String, Any?> {
        if (bundle == null) return emptyMap()
        val output = mutableMapOf<String, Any?>()
        for (key in bundle.keySet()) {
            output[key] = bundle.get(key)
        }
        return output
    }
}
