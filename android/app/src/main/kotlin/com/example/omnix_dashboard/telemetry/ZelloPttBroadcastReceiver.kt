package com.example.omnix_dashboard.telemetry

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import com.example.omnix_dashboard.BuildConfig

class ZelloPttBroadcastReceiver : BroadcastReceiver() {
    companion object {
        private const val FSK_HEARTBEAT_PREFS = "onyx_guard_telemetry"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action.orEmpty()
        val extrasMap = bundleToMap(intent.extras)

        val pttState = when (action) {
            "com.zello.ptt.down" -> "ptt_down"
            "com.zello.ptt.up" -> "ptt_up"
            "com.zello.ptt.toggle" -> "ptt_toggle"
            else -> "ptt_event"
        }

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
                "zello_ptt_manifest_receiver rejected action=$action error=${validation.message}",
            )
            return
        }

        val normalizedMap = validation.normalized.toMap(
            providerId = "fsk_sdk",
            sdkStatus = if (BuildConfig.USE_LIVE_FSK_SDK) "live" else "stub",
            source = "zello_manifest_receiver",
        ).apply {
            this["payload_adapter"] = "legacy_ptt"
            this["ptt_action"] = action
            this["ptt_state"] = pttState
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
            "zello_ptt_manifest_receiver accepted action=$action state=$pttState extras=${mapPayloadKeys(extrasMap)}",
        )
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
