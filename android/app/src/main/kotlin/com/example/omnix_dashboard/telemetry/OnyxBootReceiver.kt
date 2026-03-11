package com.example.omnix_dashboard.telemetry

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class OnyxBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val action = intent?.action.orEmpty()
        if (action != Intent.ACTION_BOOT_COMPLETED && action != Intent.ACTION_MY_PACKAGE_REPLACED) {
            return
        }
        PttForegroundService.start(
            context = context.applicationContext,
            source = "boot_receiver:$action",
        )
        Log.i(ONYX_TELEMETRY_TAG, "ptt_boot_receiver_started action=$action")
    }
}
