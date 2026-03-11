package com.example.omnix_dashboard.telemetry

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent

class OnyxPttAccessibilityService : AccessibilityService() {
    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = serviceInfo ?: AccessibilityServiceInfo()
        info.flags = info.flags or AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        serviceInfo = info

        PttForegroundService.start(
            context = applicationContext,
            source = "accessibility_service_connected",
        )
        Log.i(ONYX_TELEMETRY_TAG, "ptt_accessibility_connected key_filter=true")
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val isMappedPttKey = event.keyCode == KeyEvent.KEYCODE_F1 || event.scanCode == 59
        if (!isMappedPttKey) {
            return false
        }
        val mappedAction = when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                if (event.repeatCount > 0) {
                    return false
                }
                PttIntentActions.DOWN
            }
            KeyEvent.ACTION_UP -> PttIntentActions.UP
            else -> return false
        }

        val bridgeIntent = Intent(mappedAction).apply {
            putExtra("pulse", 72)
            putExtra("movement", if (event.action == KeyEvent.ACTION_DOWN) 1.0 else 0.0)
            putExtra("state", if (event.action == KeyEvent.ACTION_DOWN) "ptt_down" else "ptt_up")
            putExtra("captured_at_utc", nowUtcIso())
            putExtra("key_code", event.keyCode)
            putExtra("key_scan_code", event.scanCode)
            putExtra("key_action", event.action)
            putExtra("key_repeat", event.repeatCount)
            putExtra("key_source", event.source)
        }

        val accepted = PttTelemetryIngestor.ingestIntent(
            context = applicationContext,
            intent = bridgeIntent,
            source = "accessibility_key_f1",
        )
        if (accepted) {
            Log.i(
                ONYX_TELEMETRY_TAG,
                "ptt_key_bridge_accepted keycode=${event.keyCode} scan=${event.scanCode} action=${event.action}",
            )
        }
        return false
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // No-op: service exists to filter hardware key events globally.
    }

    override fun onInterrupt() {
        // No-op.
    }
}
