package com.shamiit.shamiit_sms_gateway.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.shamiit.shamiit_sms_gateway.MainActivity
import com.shamiit.shamiit_sms_gateway.storage.SmsGatewayDatabaseHelper
import com.shamiit.shamiit_sms_gateway.sync.GatewaySyncEngine
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Foreground Service keeping the SHAMIIT SMS Gateway polling & sync loop alive
 * when backgrounded, within Android OS foreground service policies.
 */
class SmsGatewayForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "shamiit_sms_gateway_service"
        const val NOTIFICATION_ID = 7001
        const val ACTION_START = "com.shamiit.shamiit_sms_gateway.START_SERVICE"
        const val ACTION_STOP = "com.shamiit.shamiit_sms_gateway.STOP_SERVICE"

        @Volatile
        var isRunning: Boolean = false
            private set

        fun start(context: Context) {
            val intent = Intent(context, SmsGatewayForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, SmsGatewayForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var pollJob: Job? = null
    private lateinit var simManager: SimManager

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        simManager = SimManager(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            isRunning = false
            pollJob?.cancel()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = buildNotification("Gateway Active • Monitoring SIM & SMS Queue")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        isRunning = true

        simManager.registerSubscriptionListener {
            scope.launch {
                GatewaySyncEngine(this@SmsGatewayForegroundService).sendHeartbeatAndSyncSims()
            }
        }

        if (pollJob?.isActive != true) {
            pollJob = scope.launch {
                val engine = GatewaySyncEngine(this@SmsGatewayForegroundService)
                val db = SmsGatewayDatabaseHelper.getInstance(this@SmsGatewayForegroundService)
                var cycle = 0
                while (isActive && isRunning) {
                    try {
                        engine.flushPendingUploads()
                        engine.pollAndExecuteLeasedJobs()
                        if (cycle % 4 == 0) {
                            engine.sendHeartbeatAndSyncSims()
                        }
                        cycle++
                    } catch (_: Exception) {}
                    val intervalSec = ((db.getSettings()["polling_interval_seconds"] as? Number)?.toLong() ?: 15L)
                        .coerceIn(5L, 300L)
                    delay(intervalSec * 1000L)
                }
            }
        }

        return START_STICKY
    }

    override fun onDestroy() {
        isRunning = false
        pollJob?.cancel()
        if (::simManager.isInitialized) {
            simManager.unregisterSubscriptionListener()
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "SHAMIIT SMS Gateway Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps SMS queue synchronization and incoming SMS monitoring active."
            }
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(text: String): Notification {
        val launchIntent = Intent(this, MainActivity::class.java)
        val pi = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("SHAMIIT SMS Gateway")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.sym_action_chat)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
    }
}
