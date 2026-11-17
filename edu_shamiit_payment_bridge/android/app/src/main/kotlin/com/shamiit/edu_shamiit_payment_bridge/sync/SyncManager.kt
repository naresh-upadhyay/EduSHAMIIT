package com.shamiit.edu_shamiit_payment_bridge.sync

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.shamiit.edu_shamiit_payment_bridge.model.PaymentNotificationEvent
import com.shamiit.edu_shamiit_payment_bridge.storage.PaymentDatabaseHelper
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class SyncManager(private val context: Context) {

    companion object {
        private const val TAG = "PaymentBridgeSync"
        const val PREFS_NAME = "edu_shamiit_payment_bridge_prefs"
        const val KEY_SERVER_URL = "server_url"
        const val KEY_DEVICE_ID = "device_id"
        const val KEY_API_KEY = "api_key"
        const val DEFAULT_SERVER_URL = "http://10.0.2.2:8082/api/v1/payment-bridge"
        const val DEFAULT_DEVICE_ID = "PB-AND-001"

        @Volatile
        private var instance: SyncManager? = null

        fun getInstance(context: Context): SyncManager {
            return instance ?: synchronized(this) {
                instance ?: SyncManager(context.applicationContext).also { instance = it }
            }
        }
    }

    private val dbHelper = PaymentDatabaseHelper.getInstance(context)
    private val gson = Gson()
    private val coroutineScope = CoroutineScope(Dispatchers.IO)

    fun getServerUrl(): String {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val flutterUrl = flutterPrefs.getString("flutter.pref_server_url", null)
            ?: flutterPrefs.getString("flutter.server_url", null)
        if (!flutterUrl.isNullOrEmpty()) {
            return flutterUrl.replace(":8000", ":8082")
        }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL
        return raw.replace(":8000", ":8082")
    }

    fun getDeviceId(): String {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val flutterDevice = flutterPrefs.getString("flutter.pref_device_id", null)
        if (!flutterDevice.isNullOrEmpty()) {
            return flutterDevice
        }
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_DEVICE_ID, DEFAULT_DEVICE_ID) ?: DEFAULT_DEVICE_ID
    }

    fun getSchoolId(): String {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return flutterPrefs.getString("flutter.pref_school_id", null) ?: "33333333-3333-3333-3333-333333333333"
    }

    fun getAuthToken(): String? {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return flutterPrefs.getString("flutter.pref_user_token", null)
    }

    fun triggerSync(onComplete: ((Boolean, Int) -> Unit)? = null) {
        coroutineScope.launch {
            val pending = dbHelper.getPendingEvents(limit = 50)
            if (pending.isEmpty()) {
                Log.d(TAG, "No pending notifications to sync.")
                onComplete?.invoke(true, 0)
                return@launch
            }

            val payloadMap = mapOf(
                "device_id" to getDeviceId(),
                "events" to pending.map { ev ->
                    mapOf(
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
                        "parsing_status" to ev.parsingStatus
                    )
                }
            )
            val jsonPayload = gson.toJson(payloadMap)

            val primaryBase = getServerUrl().trimEnd('/')
            val candidateUrls = if (primaryBase.contains("10.0.2.2") || primaryBase.contains("127.0.0.1")) {
                listOf(
                    primaryBase.replace("10.0.2.2", "127.0.0.1"),
                    primaryBase.replace("127.0.0.1", "10.0.2.2")
                )
            } else {
                listOf(primaryBase)
            }
            var syncSuccess = false
            var syncedCount = 0

            for (serverBase in candidateUrls) {
                try {
                    val url = URL("$serverBase/notifications/batch")
                    val connection = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("Accept", "application/json")
                        setRequestProperty("X-Device-ID", getDeviceId())
                        setRequestProperty("X-School-ID", getSchoolId())
                        getAuthToken()?.let { token ->
                            if (token.isNotEmpty()) {
                                setRequestProperty("Authorization", "Bearer $token")
                            }
                        }
                        connectTimeout = 4000
                        readTimeout = 4000
                        doOutput = true
                    }

                    OutputStreamWriter(connection.outputStream).use { it.write(jsonPayload) }
                    val responseCode = connection.responseCode
                    if (responseCode in 200..299) {
                        val syncedUuids = pending.map { it.eventUuid }
                        dbHelper.markEventsAsSynced(syncedUuids)
                        Log.i(TAG, "Successfully synchronized ${syncedUuids.size} events to $serverBase")
                        syncSuccess = true
                        syncedCount = syncedUuids.size
                        break
                    } else {
                        Log.w(TAG, "Sync rejected at $serverBase with code: $responseCode")
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed syncing to $serverBase: ${e.message}")
                }
            }

            onComplete?.invoke(syncSuccess, syncedCount)
        }
    }

    fun sendHeartbeat(batteryLevel: Int, isListenerActive: Boolean, isAccessGranted: Boolean) {
        coroutineScope.launch {
            val serverBase = getServerUrl().trimEnd('/')
            val candidateUrls = if (serverBase.contains("10.0.2.2") || serverBase.contains("127.0.0.1")) {
                listOf(
                    serverBase.replace("10.0.2.2", "127.0.0.1"),
                    serverBase.replace("127.0.0.1", "10.0.2.2")
                )
            } else {
                listOf(serverBase)
            }
            for (base in candidateUrls) {
                try {
                    val url = URL("$base/devices/heartbeat")
                    val conn = (url.openConnection() as HttpURLConnection).apply {
                        requestMethod = "POST"
                        setRequestProperty("Content-Type", "application/json")
                        setRequestProperty("X-Device-ID", getDeviceId())
                        setRequestProperty("X-School-ID", getSchoolId())
                        getAuthToken()?.let { token ->
                            if (token.isNotEmpty()) {
                                setRequestProperty("Authorization", "Bearer $token")
                            }
                        }
                        connectTimeout = 3000
                        readTimeout = 3000
                        doOutput = true
                    }
                    val payload = mapOf(
                        "device_id" to getDeviceId(),
                        "listener_active" to isListenerActive,
                        "notification_access_granted" to isAccessGranted,
                        "battery_level" to batteryLevel,
                        "pending_queue_count" to dbHelper.getPendingQueueCount(),
                        "status" to "ACTIVE"
                    )
                    OutputStreamWriter(conn.outputStream).use { it.write(gson.toJson(payload)) }
                    val code = conn.responseCode
                    Log.d(TAG, "Heartbeat sent to $base, response: $code")
                    if (code in 200..299) break
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to send heartbeat to $base: ${e.message}")
                }
            }
        }
    }
}
