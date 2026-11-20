package com.shamiit.edu_shamiit_payment_bridge.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.shamiit.edu_shamiit_payment_bridge.R
import com.shamiit.edu_shamiit_payment_bridge.bridge.PaymentBridgeChannel
import com.shamiit.edu_shamiit_payment_bridge.parser.NotificationParserFactory
import com.shamiit.edu_shamiit_payment_bridge.storage.PaymentDatabaseHelper
import com.shamiit.edu_shamiit_payment_bridge.sync.SyncManager
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class PaymentNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "PaymentListenerService"
        private const val FOREGROUND_NOTIFICATION_ID = 8801
        private const val CHANNEL_ID = "edushamiit_payment_listener_channel"

        @Volatile
        var isServiceConnected: Boolean = false
            private set

        // Configurable list of monitored package names
        val defaultMonitoredPackages = setOf(
            "com.phonepe.app",
            "com.google.android.apps.nbu.paisa.user",
            "net.one97.paytm",
            "in.org.npci.upiapp",
            "com.dreamplug.androidapp",
            "com.sbi.upi",
            "com.canarabank.mobility",
            "com.google.android.apps.messaging",
            "com.android.mms",
            "com.miui.mms",
            "com.android.shell"
        )

        private const val PREFS_APPS = "monitored_apps_prefs"
        private const val KEY_ENABLED_PREFIX = "pkg_enabled_"

        fun isPackageMonitored(context: Context, packageName: String): Boolean {
            val lower = packageName.lowercase()
            val prefs = context.getSharedPreferences(PREFS_APPS, Context.MODE_PRIVATE)
            if (prefs.getBoolean("monitor_all_apps", false)) {
                return true
            }
            val key = "$KEY_ENABLED_PREFIX$packageName"
            if (prefs.contains(key)) {
                return prefs.getBoolean(key, true)
            }
            if (defaultMonitoredPackages.contains(packageName)) return true
            // Support PhonePe, GPay, Paytm, BHIM, Cred, bank apps, and SMS variants automatically
            return lower.contains("phonepe") || lower.contains("paisa") || 
                   lower.contains("paytm") || lower.contains("upi") || 
                   lower.contains("cred") || lower.contains("dreamplug") || lower.contains("message") ||
                   lower.contains("mms") || lower.contains("sms") ||
                   lower.contains("bank")
        }

        fun setPackageMonitored(context: Context, packageName: String, enabled: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_APPS, Context.MODE_PRIVATE)
            prefs.edit().putBoolean("$KEY_ENABLED_PREFIX$packageName", enabled).apply()
        }

        /**
         * Cycles component state in PackageManager to force Android OS to reconnect
         * dead or unbound NotificationListenerService after APK install or process freeze.
         */
        fun forceRebind(context: Context) {
            try {
                val componentName = ComponentName(context, PaymentNotificationListenerService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    try {
                        NotificationListenerService.requestRebind(componentName)
                        Log.i(TAG, "requestRebind completed successfully")
                        return
                    } catch (e: Exception) {
                        Log.w(TAG, "requestRebind failed: ${e.message}, falling back to PM toggle")
                    }
                }
                val pm = context.packageManager
                pm.setComponentEnabledSetting(componentName, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                pm.setComponentEnabledSetting(componentName, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
                Log.i(TAG, "forceRebind completed successfully")
            } catch (e: Exception) {
                Log.e(TAG, "forceRebind error: ${e.message}")
            }
        }
    }

    private lateinit var parserFactory: NotificationParserFactory
    private lateinit var dbHelper: PaymentDatabaseHelper
    private lateinit var syncManager: SyncManager
    private val backgroundExecutor = Executors.newSingleThreadExecutor()
    private var heartbeatScheduler: ScheduledExecutorService? = null

    override fun onStartCommand(intent: android.content.Intent?, flags: Int, startId: Int): Int {
        return android.app.Service.START_STICKY
    }

    override fun onCreate() {
        super.onCreate()
        dbHelper = PaymentDatabaseHelper.getInstance(this)
        syncManager = SyncManager.getInstance(this)
        parserFactory = NotificationParserFactory(this)
        startForegroundNotification()
        backgroundExecutor.execute {
            try {
                dbHelper.pruneOldSyncedEvents(olderThanDays = 60)
            } catch (_: Exception) {}
        }
        Log.i(TAG, "PaymentNotificationListenerService initialized")
    }

    override fun onDestroy() {
        super.onDestroy()
        stopHeartbeatLoop()
        try {
            backgroundExecutor.shutdown()
        } catch (_: Throwable) {}
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isServiceConnected = true
        Log.i(TAG, "Notification listener connected successfully")
        startForegroundNotification()
        startHeartbeatLoop()
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isServiceConnected = false
        stopHeartbeatLoop()
        Log.w(TAG, "Notification listener disconnected - attempting auto-rebind")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(ComponentName(this, PaymentNotificationListenerService::class.java))
            } catch (_: Exception) {}
        }
    }

    private fun startForegroundNotification() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "SHAMIIT Payment Bridge",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Monitors incoming UPI and banking payment notifications in real-time"
                    setShowBadge(false)
                }
                val manager = getSystemService(NotificationManager::class.java)
                manager?.createNotificationChannel(channel)
            }

            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            val pendingIntent = if (launchIntent != null) {
                PendingIntent.getActivity(
                    this, 0, launchIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
                )
            } else null

            val builder = NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("SHAMIIT Payment Bridge Active")
                .setContentText("Listening for verified payment notifications in real-time")
                .setSmallIcon(R.mipmap.ic_launcher)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)

            if (pendingIntent != null) {
                builder.setContentIntent(pendingIntent)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(FOREGROUND_NOTIFICATION_ID, builder.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(FOREGROUND_NOTIFICATION_ID, builder.build())
            }
            Log.i(TAG, "Foreground notification started successfully")
        } catch (e: Throwable) {
            Log.w(TAG, "Could not start foreground notification: ${e.message}")
        }
    }

    private fun startHeartbeatLoop() {
        stopHeartbeatLoop()
        heartbeatScheduler = Executors.newSingleThreadScheduledExecutor()
        heartbeatScheduler?.scheduleAtFixedRate({
            try {
                if (isServiceConnected) {
                    val currentBattery = PaymentBridgeChannel.getActualBatteryLevel(this)
                    val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
                    syncManager.sendHeartbeat(
                        batteryLevel = currentBattery,
                        isListenerActive = true,
                        isAccessGranted = isAccessGranted
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Heartbeat loop error: ${e.message}")
            }
        }, 0, 30, TimeUnit.SECONDS)
    }

    private fun stopHeartbeatLoop() {
        try {
            heartbeatScheduler?.shutdownNow()
            heartbeatScheduler = null
        } catch (_: Throwable) {}
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        if (!isPackageMonitored(this, packageName)) {
            // Unrelated application notification - ignore to preserve privacy
            return
        }

        val notification = sbn.notification ?: return
        val extras = notification.extras ?: return

        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()
        val subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString()
        val infoText = extras.getCharSequence(Notification.EXTRA_INFO_TEXT)?.toString()

        val primaryText = if (!bigText.isNullOrBlank()) bigText else text
        val additionalDetails = listOfNotNull(subText, infoText).filter { it.isNotBlank() && it != primaryText }
        val effectiveText = if (additionalDetails.isNotEmpty() && !primaryText.isNullOrBlank()) {
            "$primaryText ${additionalDetails.joinToString(" ")}"
        } else {
            primaryText ?: additionalDetails.firstOrNull()
        }

        if (title.isNullOrBlank() && effectiveText.isNullOrBlank()) {
            return
        }

        val postTime = if (sbn.postTime > 0) sbn.postTime else System.currentTimeMillis()
        val rawId = UUID.randomUUID().toString()

        val appDisplayName = when {
            packageName.contains("phonepe", ignoreCase = true) -> "PhonePe"
            packageName.contains("paisa", ignoreCase = true) -> "Google Pay"
            packageName.contains("paytm", ignoreCase = true) -> "Paytm"
            packageName.contains("upiapp", ignoreCase = true) -> "BHIM UPI"
            packageName.contains("cred", ignoreCase = true) -> "CRED"
            packageName.contains("sbi", ignoreCase = true) -> "SBI UPI"
            packageName.contains("message", ignoreCase = true) || packageName.contains("mms", ignoreCase = true) -> "SMS Message"
            else -> packageName
        }

        // Immediately offload all database and sync work to backgroundExecutor
        backgroundExecutor.execute {
            try {
                Log.d(TAG, "Processing notification on background thread from: $packageName - Title: $title, Text: $effectiveText")

                // Step 1: Capture Raw Notification into local SQLite log unconditionally
                dbHelper.insertRawNotification(
                    id = rawId,
                    packageName = packageName,
                    appName = appDisplayName,
                    title = title,
                    content = effectiveText,
                    postTime = postTime,
                    parsedStatus = "PENDING"
                )

                // Step 2: Parse notification
                val parser = parserFactory.getParser(packageName)
                val event = parser.parse(packageName, title, effectiveText, postTime)

                // Privacy check: reject any notification with OTP/PIN keywords
                // Note: match word boundaries for 'pin' so words like 'Spin' or bank codes aren't falsely dropped
                val combinedLower = "$title $effectiveText".lowercase()
                val isOtpPin = combinedLower.contains("otp") || combinedLower.contains("secret code") || 
                               combinedLower.contains("password") || combinedLower.contains("passcode") || 
                               Regex("\\bpin\\b").containsMatchIn(combinedLower)
                if (isOtpPin && !combinedLower.contains("has sent") && !combinedLower.contains("received") && !combinedLower.contains("credited")) {
                    Log.w(TAG, "Notification contains authentication keywords; ignoring.")
                    dbHelper.updateRawNotificationStatus(rawId, "IGNORED_OTP", 0, null, null, null)
                    return@execute
                }

                val parsedStatus = when {
                    event.eventType == "PAYMENT_IGNORED" -> event.parsingStatus
                    event.eventType == "PAYMENT_SENT" -> "PAYMENT_SENT"
                    event.amountPaise > 0 -> "PARSED_CREDIT"
                    else -> "UNPARSED"
                }

                // Update raw record with parsed extraction results
                dbHelper.updateRawNotificationStatus(
                    id = rawId,
                    parsedStatus = parsedStatus,
                    amountPaise = event.amountPaise,
                    senderName = event.senderName,
                    reference = event.transactionReference,
                    bankName = event.maskedSenderIdentifier
                )

                if (parsedStatus == "PARSED_CREDIT") {
                    // Deduplication check: 5-minute window for identical amounts and references
                    val isDup = dbHelper.isDuplicate(event.amountPaise, event.transactionReference, windowMinutes = 5)
                    if (isDup) {
                        Log.w(TAG, "Duplicate notification detected for ref: ${event.transactionReference}, amount: ${event.amountPaise}")
                    }

                    // Store into SQLite persistent queue
                    val inserted = dbHelper.insertEvent(event)
                    if (inserted) {
                        Log.i(TAG, "Queued event ${event.eventUuid} (Amount: Rs ${event.amountPaise / 100.0})")
                        // Trigger background sync immediately
                        syncManager.triggerSync()
                    }
                } else {
                    Log.w(TAG, "Notification parsed as $parsedStatus (Amount: ${event.amountPaise})")
                }
            } catch (t: Throwable) {
                Log.e(TAG, "Error processing notification in background", t)
            }
        }
    }
}
