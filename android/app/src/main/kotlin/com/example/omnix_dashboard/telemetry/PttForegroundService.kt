package com.example.omnix_dashboard.telemetry

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.example.omnix_dashboard.MainActivity
import com.example.omnix_dashboard.R

class PttForegroundService : Service() {
    companion object {
        const val ACTION_START: String =
            "com.example.omnix_dashboard.telemetry.action.START_PTT_LISTENER"
        const val ACTION_STOP: String =
            "com.example.omnix_dashboard.telemetry.action.STOP_PTT_LISTENER"
        private const val EXTRA_SOURCE: String = "source"
        private const val CHANNEL_ID: String = "onyx_ptt_listener"
        private const val CHANNEL_NAME: String = "ONYX PTT Listener"
        private const val NOTIFICATION_ID: Int = 4307
        @Volatile
        private var running: Boolean = false

        fun start(
            context: Context,
            source: String = "manual_start",
        ) {
            if (running) return
            val intent = Intent(context, PttForegroundService::class.java).apply {
                action = ACTION_START
                putExtra(EXTRA_SOURCE, source)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, PttForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
    }

    private var receiverRegistered: Boolean = false
    private val pttReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            PttTelemetryIngestor.ingestIntent(
                context = context.applicationContext,
                intent = intent,
                source = "ptt_foreground_service",
            )
        }
    }

    override fun onCreate() {
        super.onCreate()
        running = true
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())
        registerPttReceiverIfNeeded()
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        if (intent?.action == ACTION_STOP) {
            stopForegroundCompat()
            stopSelf()
            return START_NOT_STICKY
        }

        registerPttReceiverIfNeeded()
        val source = intent?.getStringExtra(EXTRA_SOURCE)?.trim().orEmpty().ifEmpty {
            "unknown"
        }
        android.util.Log.i(
            ONYX_TELEMETRY_TAG,
            "ptt_foreground_service_active source=$source",
        )
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        unregisterPttReceiver()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun registerPttReceiverIfNeeded() {
        if (receiverRegistered) return
        val filter = IntentFilter().apply {
            for (action in PttIntentActions.all) {
                addAction(action)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(pttReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(pttReceiver, filter)
        }
        receiverRegistered = true
    }

    private fun unregisterPttReceiver() {
        if (!receiverRegistered) return
        try {
            unregisterReceiver(pttReceiver)
        } catch (_: Throwable) {
            // Keep teardown resilient.
        } finally {
            receiverRegistered = false
        }
    }

    private fun buildNotification(): android.app.Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntentFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            pendingIntentFlags,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("ONYX PTT listener active")
            .setContentText("Listening for hardware PTT broadcasts.")
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Foreground listener for ONYX hardware PTT telemetry."
            setShowBadge(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }
}
