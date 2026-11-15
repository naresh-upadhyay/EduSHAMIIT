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
        const val DEFAULT_SERVER_URL = "http://10.0.2.2:8000/api/v1/payment-bridge"
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
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_SERVER_URL, DEFAULT_SERVER_URL) ?: DEFAULT_SERVER_URL
    }

    fun getDeviceId(): String {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        return prefs.getString(KEY_DEVICE_ID, DEFAULT_DEVICE_ID) ?: DEFAULT_DEVICE_ID
    }

    fun triggerSync(onComplete: ((Boolean, Int) -> Unit)? = null) {
        coroutineScope.launch {
            val pending = dbHelper.getPendingEvents(limit = 50)
            if (pending.isEmpty()) {
                Log.d(TAG, "No pending notifications to sync.")
                onComplete?.invoke(true, 0)
                return@launch
            }

            try {
                val serverBase = getServerUrl().trimEnd('/')
                val url = URL("$serverBase/notifications/batch")
                val connection = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("Accept", "application/json")
                    setRequestProperty("X-Device-ID", getDeviceId())
                    connectTimeout = 8000
                    readTimeout = 8000
                    doOutput = true
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
                OutputStreamWriter(connection.outputStream).use { it.write(jsonPayload) }

                val responseCode = connection.responseCode
                if (responseCode in 200..299) {
                    val syncedUuids = pending.map { it.eventUuid }
                    dbHelper.markEventsAsSynced(syncedUuids)
                    Log.i(TAG, "Successfully synchronized ${syncedUuids.size} events to backend")
                    onComplete?.invoke(true, syncedUuids.size)
                } else {
                    Log.w(TAG, "Backend sync rejected with response code: $responseCode")
                    onComplete?.invoke(false, 0)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Network failure syncing events: ${e.message}", e)
                onComplete?.invoke(false, 0)
            }
        }
    }

    fun sendHeartbeat(batteryLevel: Int, isListenerActive: Boolean, isAccessGranted: Boolean) {
        coroutineScope.launch {
            try {
                val serverBase = getServerUrl().trimEnd('/')
                val url = URL("$serverBase/devices/heartbeat")
                val conn = (url.openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json")
                    setRequestProperty("X-Device-ID", getDeviceId())
                    connectTimeout = 5000
                    readTimeout = 5000
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
                Log.d(TAG, "Heartbeat sent, response: $code")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to send heartbeat: ${e.message}")
            }
        }
    }
}
