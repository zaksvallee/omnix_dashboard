package com.example.omnix_dashboard

import android.content.Intent
import android.os.Bundle
import com.example.omnix_dashboard.telemetry.GuardTelemetryChannelHandler
import com.example.omnix_dashboard.telemetry.PttForegroundService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHECKPOINT_SCAN_CHANNEL = "onyx/guard_checkpoint_scan"
    }

    private var guardTelemetryChannelHandler: GuardTelemetryChannelHandler? = null
    private var checkpointScanChannel: MethodChannel? = null
    private var pendingCheckpointScanPayload: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        guardTelemetryChannelHandler = GuardTelemetryChannelHandler(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
        checkpointScanChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHECKPOINT_SCAN_CHANNEL,
        )
        checkpointScanChannel?.setMethodCallHandler(::handleCheckpointScanMethodCall)
        cacheCheckpointScanPayload(intent)
        PttForegroundService.start(
            context = applicationContext,
            source = "main_activity_configure_engine",
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        cacheCheckpointScanPayload(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val payload = cacheCheckpointScanPayload(intent)
        if (payload != null) {
            checkpointScanChannel?.invokeMethod("checkpointScanLink", payload)
        }
    }

    override fun onDestroy() {
        checkpointScanChannel?.setMethodCallHandler(null)
        checkpointScanChannel = null
        guardTelemetryChannelHandler?.dispose()
        guardTelemetryChannelHandler = null
        super.onDestroy()
    }

    private fun handleCheckpointScanMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "consumePendingCheckpointScan" -> {
                result.success(pendingCheckpointScanPayload)
                pendingCheckpointScanPayload = null
            }
            else -> result.notImplemented()
        }
    }

    private fun cacheCheckpointScanPayload(intent: Intent?): Map<String, String>? {
        val data = intent?.data ?: return null
        if (data.scheme != "onyx" || data.host != "checkpoint") {
            return null
        }
        val segments = data.pathSegments ?: return null
        if (segments.size < 2) {
            return null
        }
        val siteId = segments[0].trim()
        val checkpointId = segments[1].trim()
        if (siteId.isEmpty() || checkpointId.isEmpty()) {
            return null
        }
        val payload = mapOf(
            "site_id" to siteId,
            "checkpoint_id" to checkpointId,
            "source" to "android_deep_link",
            "uri" to data.toString(),
        )
        pendingCheckpointScanPayload = payload
        return payload
    }
}
