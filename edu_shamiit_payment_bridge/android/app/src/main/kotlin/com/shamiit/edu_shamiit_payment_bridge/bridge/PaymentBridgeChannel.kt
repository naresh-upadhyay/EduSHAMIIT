package com.shamiit.edu_shamiit_payment_bridge.bridge

import android.content.Context
import android.content.Intent
import android.os.BatteryManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.shamiit.edu_shamiit_payment_bridge.notification.PaymentNotificationListenerService
import com.shamiit.edu_shamiit_payment_bridge.parser.NotificationParserFactory
import com.shamiit.edu_shamiit_payment_bridge.storage.PaymentDatabaseHelper
import com.shamiit.edu_shamiit_payment_bridge.sync.SyncManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class PaymentBridgeChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.shamiit.payment_bridge/channel"
    }

    private val dbHelper = PaymentDatabaseHelper.getInstance(context)
    private val syncManager = SyncManager.getInstance(context)
    private val parserFactory = NotificationParserFactory()

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isNotificationAccessGranted" -> {
                val pkgName = context.packageName
                val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(context)
                val isGranted = enabledPackages.contains(pkgName)
                result.success(isGranted)
            }

            "openNotificationSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", "Unable to open notification settings: ${e.message}", null)
                }
            }

            "isListenerRunning" -> {
                result.success(PaymentNotificationListenerService.isServiceConnected)
            }

            "getDiagnostics" -> {
                val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                val batteryLevel = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) ?: 95

                val pkgName = context.packageName
                val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(pkgName)
                val isListenerRunning = PaymentNotificationListenerService.isServiceConnected
                val pendingQueueCount = dbHelper.getPendingQueueCount()
                val totalEventsCount = dbHelper.getTotalEventsCount()

                val diagnosticsMap = mapOf(
                    "notification_access_granted" to isAccessGranted,
                    "listener_service_running" to isListenerRunning,
                    "battery_level" to batteryLevel,
                    "battery_optimization_disabled" to true,
                    "pending_queue_count" to pendingQueueCount,
                    "total_events_count" to totalEventsCount,
                    "android_version" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
                    "device_model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                    "app_version" to "1.0.0"
                )
                result.success(diagnosticsMap)
            }

            "syncNow" -> {
                syncManager.triggerSync { success, count ->
                    result.success(mapOf("success" to success, "synced_count" to count))
                }
            }

            "getMonitoredApps" -> {
                val apps = listOf(
                    mapOf("name" to "PhonePe", "package" to "com.phonepe.app", "enabled" to PaymentNotificationListenerService.isPackageMonitored(context, "com.phonepe.app")),
                    mapOf("name" to "Google Pay", "package" to "com.google.android.apps.nbu.paisa.user", "enabled" to PaymentNotificationListenerService.isPackageMonitored(context, "com.google.android.apps.nbu.paisa.user")),
                    mapOf("name" to "Paytm", "package" to "net.one97.paytm", "enabled" to PaymentNotificationListenerService.isPackageMonitored(context, "net.one97.paytm")),
                    mapOf("name" to "BHIM UPI", "package" to "in.org.npci.upiapp", "enabled" to PaymentNotificationListenerService.isPackageMonitored(context, "in.org.npci.upiapp"))
                )
                result.success(apps)
            }

            "setAppMonitored" -> {
                val pkg = call.argument<String>("package")
                val enabled = call.argument<Boolean>("enabled") ?: true
                if (pkg != null) {
                    PaymentNotificationListenerService.setPackageMonitored(context, pkg, enabled)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Package is required", null)
                }
            }

            "simulateNotification" -> {
                val packageName = call.argument<String>("package") ?: "com.phonepe.app"
                val title = call.argument<String>("title") ?: "Payment Received"
                val text = call.argument<String>("text") ?: "Received Rs 2000.34 from **** 9821 Ref: UPI/438729106731"

                val parser = parserFactory.getParser(packageName)
                val event = parser.parse(packageName, title, text, System.currentTimeMillis())
                val inserted = dbHelper.insertEvent(event)
                if (inserted) {
                    syncManager.triggerSync()
                    result.success(mapOf("success" to true, "event_uuid" to event.eventUuid))
                } else {
                    result.success(mapOf("success" to false, "reason" to "duplicate or DB insert error"))
                }
            }

            else -> result.notImplemented()
        }
    }
}
