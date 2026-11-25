package com.shamiit.shamiit_sms_gateway.telephony.diagnostics

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import com.shamiit.shamiit_sms_gateway.security.SecureCredentialStore
import com.shamiit.shamiit_sms_gateway.service.SmsGatewayForegroundService
import com.shamiit.shamiit_sms_gateway.storage.SmsGatewayDatabaseHelper
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimManager
import java.util.UUID

object TelephonyDiagnostics {

    private const val PREFS_DEVICE = "shamiit_sms_gateway_device_prefs"
    private const val KEY_DEVICE_ID = "unique_device_id"
    private val processStartMillis = SystemClock.elapsedRealtime()

    fun getOrCreateUniqueDeviceId(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS_DEVICE, Context.MODE_PRIVATE)
        var id = prefs.getString(KEY_DEVICE_ID, null)
        if (id.isNullOrEmpty()) {
            val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
            id = if (!androidId.isNullOrEmpty() && androidId != "9774d56d682e549c") {
                "SMS-$androidId".uppercase()
            } else {
                "SMS-${UUID.randomUUID().toString().substring(0, 8).uppercase()}"
            }
            prefs.edit().putString(KEY_DEVICE_ID, id).apply()
        }
        return id
    }

    fun isEmulator(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
            || Build.FINGERPRINT.startsWith("generic")
            || Build.FINGERPRINT.startsWith("unknown")
            || Build.HARDWARE.contains("goldfish")
            || Build.HARDWARE.contains("ranchu")
            || Build.MODEL.contains("google_sdk")
            || Build.MODEL.contains("Emulator")
            || Build.MODEL.contains("Android SDK built for x86")
            || Build.MANUFACTURER.contains("Genymotion")
            || Build.PRODUCT.contains("sdk")
            || Build.PRODUCT.contains("emulator")
            || Build.PRODUCT.contains("simulator")
    }

    fun getBatteryInfo(context: Context): Pair<Int, Boolean> {
        return try {
            val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
            val cap = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
            val statusIntent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            val level = if (cap != null && cap in 0..100) {
                cap
            } else {
                val rawLevel = statusIntent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale = statusIntent?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                if (rawLevel >= 0 && scale > 0) (rawLevel * 100 / scale.toFloat()).toInt() else 100
            }
            val plugged = statusIntent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
            val status = statusIntent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val charging = plugged > 0 || status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
            level to charging
        } catch (_: Exception) {
            100 to false
        }
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val pm = context.getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return false
        return pm.isIgnoringBatteryOptimizations(context.packageName)
    }

    fun getNetworkInfo(context: Context): Pair<Boolean, String> {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false to "OFFLINE"
        val network = cm.activeNetwork ?: return false to "OFFLINE"
        val caps = cm.getNetworkCapabilities(network) ?: return false to "OFFLINE"
        val connected = caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
        val type = when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "Wi-Fi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Cellular"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            else -> "Connected"
        }
        return connected to type
    }

    fun collectDiagnostics(context: Context): Map<String, Any?> {
        val db = SmsGatewayDatabaseHelper.getInstance(context)
        val simManager = SimManager(context)
        val sims = simManager.discoverSims()
        val (batteryLevel, isCharging) = getBatteryInfo(context)
        val (internetConnected, networkType) = getNetworkInfo(context)
        val perms = SmsPermissionManager.getPermissionSnapshot(context)
        val credStore = SecureCredentialStore(context)
        val uptimeSec = ((SystemClock.elapsedRealtime() - processStartMillis) / 1000L).coerceAtLeast(0L)

        return mapOf(
            "device_id" to getOrCreateUniqueDeviceId(context),
            "device_model" to "${Build.MANUFACTURER} ${Build.MODEL}".trim(),
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "android_version" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "sdk_int" to Build.VERSION.SDK_INT,
            "is_emulator" to isEmulator(),
            "battery_level" to batteryLevel,
            "is_charging" to isCharging,
            "battery_optimization_disabled" to isIgnoringBatteryOptimizations(context),
            "internet_connected" to internetConnected,
            "network_type" to networkType,
            "uptime_seconds" to uptimeSec,
            "service_running" to SmsGatewayForegroundService.isRunning,
            "pending_uploads_count" to db.getPendingUploadsCount(),
            "pending_jobs_count" to db.getPendingJobsCount(),
            "database_size_bytes" to db.getDatabaseSizeBytes(),
            "keystore_backed" to credStore.isKeystoreBacked(),
            "has_device_token" to !credStore.getDeviceToken().isNullOrEmpty(),
            "permissions" to perms,
            "sim_count" to sims.size,
            "sims" to sims.map { it.toMap() }
        )
    }
}
