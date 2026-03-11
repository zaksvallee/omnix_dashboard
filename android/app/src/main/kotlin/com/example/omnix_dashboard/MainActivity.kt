package com.example.omnix_dashboard

import com.example.omnix_dashboard.telemetry.GuardTelemetryChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var guardTelemetryChannelHandler: GuardTelemetryChannelHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        guardTelemetryChannelHandler = GuardTelemetryChannelHandler(
            context = applicationContext,
            messenger = flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onDestroy() {
        guardTelemetryChannelHandler?.dispose()
        guardTelemetryChannelHandler = null
        super.onDestroy()
    }
}
