package com.shamiit.edu_shamiit_payment_bridge.notification

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import com.shamiit.edu_shamiit_payment_bridge.parser.NotificationParserFactory
import com.shamiit.edu_shamiit_payment_bridge.storage.PaymentDatabaseHelper
import com.shamiit.edu_shamiit_payment_bridge.sync.SyncManager

class PaymentNotificationListenerService : NotificationListenerService() {

    companion object {
        private const val TAG = "PaymentListenerService"
        @Volatile
        var isServiceConnected: Boolean = false
            private set

        // Configurable list of monitored package names
        val defaultMonitoredPackages = setOf(
            "com.phonepe.app",
            "com.google.android.apps.nbu.paisa.user",
            "net.one97.paytm",
            "in.org.npci.upiapp"
        )

        private const val PREFS_APPS = "monitored_apps_prefs"
        private const val KEY_ENABLED_PREFIX = "pkg_enabled_"

        fun isPackageMonitored(context: Context, packageName: String): Boolean {
            val prefs = context.getSharedPreferences(PREFS_APPS, Context.MODE_PRIVATE)
            val key = "$KEY_ENABLED_PREFIX$packageName"
            return if (prefs.contains(key)) {
                prefs.getBoolean(key, true)
            } else {
                defaultMonitoredPackages.contains(packageName)
            }
        }

        fun setPackageMonitored(context: Context, packageName: String, enabled: Boolean) {
            val prefs = context.getSharedPreferences(PREFS_APPS, Context.MODE_PRIVATE)
            prefs.edit().putBoolean("$KEY_ENABLED_PREFIX$packageName", enabled).apply()
        }
    }

    private val parserFactory = NotificationParserFactory()
    private lateinit var dbHelper: PaymentDatabaseHelper
    private lateinit var syncManager: SyncManager

    override fun onCreate() {
        super.onCreate()
        dbHelper = PaymentDatabaseHelper.getInstance(this)
        syncManager = SyncManager.getInstance(this)
        Log.i(TAG, "PaymentNotificationListenerService initialized")
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        isServiceConnected = true
        Log.i(TAG, "Notification listener connected successfully")
        syncManager.sendHeartbeat(batteryLevel = 100, isListenerActive = true, isAccessGranted = true)
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        isServiceConnected = false
        Log.w(TAG, "Notification listener disconnected")
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
        val effectiveText = if (!bigText.isNullOrBlank()) bigText else text

        if (title.isNullOrBlank() && effectiveText.isNullOrBlank()) {
            return
        }

        val postTime = sbn.postTime

        Log.d(TAG, "Processing notification from: $packageName - Title: $title")

        // Parse notification
        val parser = parserFactory.getParser(packageName)
        val event = parser.parse(packageName, title, effectiveText, postTime)

        // Privacy check: reject any notification with OTP/PIN keywords
        val combined = "$title $effectiveText".lowercase()
        if (combined.contains("otp") || combined.contains("secret code") || combined.contains("pin")) {
            Log.w(TAG, "Notification contains authentication OTP/PIN keywords; ignoring.")
            return
        }

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
    }
}
