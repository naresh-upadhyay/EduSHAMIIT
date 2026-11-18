package com.shamiit.edu_shamiit_payment_bridge.bridge

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.core.app.NotificationManagerCompat
import com.shamiit.edu_shamiit_payment_bridge.notification.PaymentNotificationListenerService
import com.shamiit.edu_shamiit_payment_bridge.parser.NotificationParserFactory
import com.shamiit.edu_shamiit_payment_bridge.storage.PaymentDatabaseHelper
import com.shamiit.edu_shamiit_payment_bridge.sync.SyncManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.UUID

class PaymentBridgeChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.shamiit.payment_bridge/channel"
        private const val PREFS_DEVICE = "payment_bridge_device_prefs"
        private const val KEY_UNIQUE_DEVICE_ID = "unique_device_id"

        fun getActualBatteryLevel(context: Context): Int {
            try {
                val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                val cap = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (cap != null && cap in 1..100) {
                    return cap
                }
                val batteryStatus: Intent? = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                if (level >= 0 && scale > 0) {
                    return (level * 100 / scale.toFloat()).toInt()
                }
            } catch (_: Exception) {}
            return 100
        }
    }

    private val dbHelper = PaymentDatabaseHelper.getInstance(context)
    private val syncManager = SyncManager.getInstance(context)
    private val parserFactory = NotificationParserFactory(context)

    /**
     * Retrieves or generates a persistent unique device ID backed by Android hardware ID or UUID.
     */
    private fun getOrCreateUniqueDeviceId(): String {
        val prefs = context.getSharedPreferences(PREFS_DEVICE, Context.MODE_PRIVATE)
        var deviceId = prefs.getString(KEY_UNIQUE_DEVICE_ID, null)
        if (deviceId.isNullOrEmpty()) {
            val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
            deviceId = if (!androidId.isNullOrEmpty() && androidId != "9774d56d682e549c") {
                "PB-$androidId".uppercase()
            } else {
                "PB-" + UUID.randomUUID().toString().substring(0, 8).uppercase()
            }
            prefs.edit().putString(KEY_UNIQUE_DEVICE_ID, deviceId).apply()
        }
        return deviceId
    }

    private fun isEmulator(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.PRODUCT.contains("sdk_google")
                || Build.PRODUCT.contains("google_sdk")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("sdk_x86")
                || Build.PRODUCT.contains("vbox86p")
                || Build.PRODUCT.contains("emulator")
                || Build.PRODUCT.contains("simulator")
    }

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
                val pkgName = context.packageName
                val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(pkgName)
                if (isAccessGranted && !PaymentNotificationListenerService.isServiceConnected) {
                    PaymentNotificationListenerService.forceRebind(context)
                }
                result.success(isAccessGranted)
            }

            "forceRebindListener" -> {
                PaymentNotificationListenerService.forceRebind(context)
                result.success(true)
            }

            "getRawNotifications" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val list = dbHelper.getRawNotifications(limit = 100)
                    Handler(Looper.getMainLooper()).post {
                        result.success(list)
                    }
                }
            }

            "clearRawNotifications" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val cleared = dbHelper.clearRawNotifications()
                    Handler(Looper.getMainLooper()).post {
                        result.success(cleared)
                    }
                }
            }

            "openAutostartSettings" -> {
                var opened = false
                try {
                    val intent = Intent().apply {
                        component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    opened = true
                } catch (_: Exception) {}
                if (!opened) {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        opened = true
                    } catch (_: Exception) {}
                }
                result.success(opened)
            }

            "getCustomFormats" -> {
                val prefs = context.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
                val all = prefs.all.mapValues { it.value?.toString() ?: "" }
                result.success(all)
            }

            "startListenerService" -> {
                val pkgName = context.packageName
                val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(pkgName)
                if (!isAccessGranted) {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                    } catch (_: Exception) {}
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    try {
                        NotificationListenerService.requestRebind(
                            ComponentName(context, PaymentNotificationListenerService::class.java)
                        )
                    } catch (_: Exception) {}
                }
                result.success(isAccessGranted)
            }

            "stopListenerService" -> {
                result.success(true)
            }

            "getLocalNotifications" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val events = dbHelper.getAllEvents(limit = 100)
                    val list = events.map { ev ->
                        mapOf(
                            "id" to ev.eventUuid,
                            "event_uuid" to ev.eventUuid,
                            "source_package" to ev.sourcePackage,
                            "source_app" to ev.sourceApp,
                            "event_type" to ev.eventType,
                            "amount_paise" to ev.amountPaise,
                            "sender_name" to ev.senderName,
                            "masked_sender_identifier" to ev.maskedSenderIdentifier,
                            "transaction_reference" to ev.transactionReference,
                            "notification_timestamp" to ev.notificationTimestamp,
                            "raw_title" to ev.rawTitle,
                            "raw_text" to ev.rawText,
                            "parser_version" to ev.parserVersion,
                            "confidence_score" to ev.confidenceScore,
                            "parsing_status" to ev.parsingStatus,
                            "candidate_match_status" to if (ev.isSynced) "MATCHED_CANDIDATE" else "UNMATCHED",
                            "sync_status" to if (ev.isSynced) "SYNCED" else "PENDING"
                        )
                    }
                    Handler(Looper.getMainLooper()).post {
                        result.success(list)
                    }
                }
            }

            "getUniqueDeviceId" -> {
                result.success(getOrCreateUniqueDeviceId())
            }

            "isEmulator" -> {
                result.success(isEmulator())
            }

            "isIgnoringBatteryOptimizations" -> {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                val isIgnoring = powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
                result.success(isIgnoring)
            }

            "requestIgnoreBatteryOptimizations" -> {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    // Fallback to battery optimization settings
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (ex: Exception) {
                        result.error("ERROR", "Unable to open battery optimization: ${ex.message}", null)
                    }
                }
            }

            "getDiagnostics" -> {
                val batteryLevel = getActualBatteryLevel(context)

                val pkgName = context.packageName
                val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(pkgName)
                val isListenerRunning = PaymentNotificationListenerService.isServiceConnected
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                val isBatteryOptDisabled = powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
                val uniqueDeviceId = getOrCreateUniqueDeviceId()
                val isDeviceEmulator = isEmulator()

                CoroutineScope(Dispatchers.IO).launch {
                    val pendingQueueCount = dbHelper.getPendingQueueCount()
                    val totalEventsCount = dbHelper.getTotalEventsCount()

                    val diagnosticsMap = mapOf(
                        "notification_access_granted" to isAccessGranted,
                        "listener_service_running" to isListenerRunning,
                        "battery_level" to batteryLevel,
                        "battery_optimization_disabled" to isBatteryOptDisabled,
                        "pending_queue_count" to pendingQueueCount,
                        "total_events_count" to totalEventsCount,
                        "android_version" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
                        "device_model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                        "device_id" to uniqueDeviceId,
                        "is_emulator" to isDeviceEmulator,
                        "app_version" to "1.0.0"
                    )
                    Handler(Looper.getMainLooper()).post {
                        result.success(diagnosticsMap)
                    }
                }
            }

            "syncNow" -> {
                syncManager.triggerSync { success, count ->
                    Handler(Looper.getMainLooper()).post {
                        result.success(mapOf("success" to success, "synced_count" to count))
                    }
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
                CoroutineScope(Dispatchers.IO).launch {
                    val inserted = dbHelper.insertEvent(event)
                    Handler(Looper.getMainLooper()).post {
                        if (inserted) {
                            syncManager.triggerSync()
                            result.success(mapOf("success" to true, "event_uuid" to event.eventUuid))
                        } else {
                            result.success(mapOf("success" to false, "reason" to "duplicate or DB insert error"))
                        }
                    }
                }
            }

            "setCustomFormat" -> {
                val pkg = call.argument<String>("package")
                val type = call.argument<String>("type")
                val regex = call.argument<String>("regex")
                if (pkg != null && type != null && regex != null) {
                    val prefs = context.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
                    prefs.edit().putString("${pkg}_$type", regex).apply()
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Package, type, and regex are required", null)
                }
            }

            else -> result.notImplemented()
        }
    }
}
