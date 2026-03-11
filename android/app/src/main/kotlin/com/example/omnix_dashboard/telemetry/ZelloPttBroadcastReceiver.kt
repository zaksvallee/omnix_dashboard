package com.example.omnix_dashboard.telemetry

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ZelloPttBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val appContext = context.applicationContext
        PttForegroundService.start(
            context = appContext,
            source = "manifest_receiver",
        )
        PttTelemetryIngestor.ingestIntent(
            context = appContext,
            intent = intent,
            source = "zello_manifest_receiver",
        )
    }
}
