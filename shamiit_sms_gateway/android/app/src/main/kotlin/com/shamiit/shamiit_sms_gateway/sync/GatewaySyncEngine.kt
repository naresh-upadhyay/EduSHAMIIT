package com.shamiit.shamiit_sms_gateway.sync

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.shamiit.shamiit_sms_gateway.security.SecureCredentialStore
import com.shamiit.shamiit_sms_gateway.storage.SmsGatewayDatabaseHelper
import com.shamiit.shamiit_sms_gateway.telephony.diagnostics.TelephonyDiagnostics
import com.shamiit.shamiit_sms_gateway.telephony.sender.SmsSender
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimManager
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

/**
 * Synchronizes local SQLite pending uploads, SIM inventory, heartbeats, and leased SMS jobs
 * with the SHAMIIT FastAPI backend.
 *
 * Guarantees:
 *  - Pending uploads are NEVER deleted until the server returns 2xx acknowledgment.
 *  - Duplicate jobs are prevented using local pending_sms_jobs state tracking.
 */
class GatewaySyncEngine(private val context: Context) {

    companion object {
        private const val TAG = "SmsGatewaySync"
        private const val DEFAULT_API_BASE = "https://eduapi.shamiit.com/api/v1"
    }

    private val db = SmsGatewayDatabaseHelper.getInstance(context)
    private val creds = SecureCredentialStore(context)
    private val gson = Gson()

    fun getApiBaseUrl(): String {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val saved = flutterPrefs.getString("flutter.sms_pref_server_url", null)
        if (!saved.isNullOrBlank()) {
            val clean = saved.trim().trimEnd('/')
            return if (clean.endsWith("/api/v1")) clean else "$clean/api/v1"
        }
        val dbUrl = (db.getSettings()["server_url"] as? String)?.trim()?.trimEnd('/')
        if (!dbUrl.isNullOrBlank()) {
            return if (dbUrl.endsWith("/api/v1")) dbUrl else "$dbUrl/api/v1"
        }
        return DEFAULT_API_BASE
    }

    fun getDeviceId(): String {
        return creds.getDeviceId() ?: TelephonyDiagnostics.getOrCreateUniqueDeviceId(context)
    }

    fun getSchoolId(): String {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return flutterPrefs.getString("flutter.sms_pref_school_id", null)
            ?: creds.getSchoolId()
            ?: "11111111-1111-1111-1111-111111111111"
    }

    fun getAuthToken(): String? {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return flutterPrefs.getString("flutter.sms_pref_user_token", null) ?: creds.getAuthToken()
    }

    fun flushPendingUploads(): Map<String, Any> {
        val pending = db.getPendingUploads(limit = 50)
        if (pending.isEmpty()) {
            return mapOf("success" to true, "uploaded" to 0, "remaining" to 0)
        }

        val apiBase = getApiBaseUrl()
        val deviceId = getDeviceId()
        var uploaded = 0
        var lastError: String? = null

        for (item in pending) {
            val uploadId = item["upload_id"] as? String ?: continue
            val uploadType = item["upload_type"] as? String ?: "EVENT"
            val payloadJson = item["payload_json"] as? String ?: continue

            val (endpoint, bodyJson) = when (uploadType) {
                "INBOUND" -> {
                    val mapType = object : TypeToken<MutableMap<String, Any?>>() {}.type
                    val m: MutableMap<String, Any?> = gson.fromJson(payloadJson, mapType)
                    m["device_id"] = deviceId
                    "$apiBase/device/inbound" to gson.toJson(m)
                }
                else -> {
                    val mapType = object : TypeToken<Map<String, Any?>>() {}.type
                    val ev: Map<String, Any?> = gson.fromJson(payloadJson, mapType)
                    "$apiBase/device/events" to gson.toJson(mapOf("device_id" to deviceId, "events" to listOf(ev)))
                }
            }

            try {
                val (code, _) = httpPost(endpoint, bodyJson)
                if (code in 200..299) {
                    // Only delete pending upload AFTER explicit server 2xx acknowledgment!
                    db.acknowledgeUpload(uploadId)
                    (item["message_uuid"] as? String)?.let { mu ->
                        db.updateMessageStatus(messageUuid = mu, status = (db.getMessage(mu)?.get("status") as? String) ?: "SENT", syncStatus = "SYNCED")
                    }
                    uploaded++
                } else {
                    lastError = "HTTP $code from $endpoint"
                    db.recordUploadFailure(uploadId, lastError)
                }
            } catch (e: Exception) {
                lastError = e.message ?: "Network error"
                db.recordUploadFailure(uploadId, lastError)
                Log.w(TAG, "Upload $uploadId failed (retained safely offline): $lastError")
            }
        }

        return mapOf(
            "success" to (lastError == null),
            "uploaded" to uploaded,
            "remaining" to db.getPendingUploadsCount(),
            "error" to (lastError ?: "")
        )
    }

    fun sendHeartbeatAndSyncSims(): Boolean {
        return try {
            val apiBase = getApiBaseUrl()
            val deviceId = getDeviceId()
            val simManager = SimManager(context)
            val sims = simManager.discoverSims()
            val (battery, charging) = TelephonyDiagnostics.getBatteryInfo(context)
            val (connected, netType) = TelephonyDiagnostics.getNetworkInfo(context)
            val activeSim = sims.firstOrNull { it.isActive }

            val hbBody = gson.toJson(
                mapOf(
                    "device_id" to deviceId,
                    "is_online" to connected,
                    "battery_level" to battery,
                    "is_charging" to charging,
                    "battery_optimization_disabled" to TelephonyDiagnostics.isIgnoringBatteryOptimizations(context),
                    "network_type" to netType,
                    "internet_connected" to connected,
                    "queue_size" to db.getPendingUploadsCount() + db.getPendingJobsCount(),
                    "active_sim_slot" to activeSim?.simSlotIndex,
                    "active_subscription_id" to activeSim?.subscriptionId
                )
            )
            val (hbCode, _) = httpPost("$apiBase/device/heartbeat", hbBody)

            val simBody = gson.toJson(
                mapOf(
                    "device_id" to deviceId,
                    "sims" to sims.map { it.toMap() }
                )
            )
            httpPost("$apiBase/device/sim-configuration", simBody)
            hbCode in 200..299
        } catch (e: Exception) {
            Log.w(TAG, "Heartbeat failed: ${e.message}")
            false
        }
    }

    fun pollAndExecuteLeasedJobs(): Int {
        val settings = db.getSettings()
        if (((settings["emergency_disabled"] as? Number)?.toInt() ?: 0) == 1) return 0
        if (((settings["automated_messaging_enabled"] as? Number)?.toInt() ?: 1) == 0) return 0

        return try {
            val apiBase = getApiBaseUrl()
            val deviceId = getDeviceId()
            val (code, body) = httpGet("$apiBase/device/jobs?device_id=$deviceId&limit=10")
            if (code !in 200..299 || body.isNullOrBlank()) return 0

            val mapType = object : TypeToken<Map<String, Any?>>() {}.type
            val parsed: Map<String, Any?> = gson.fromJson(body, mapType)
            @Suppress("UNCHECKED_CAST")
            val jobs = parsed["jobs"] as? List<Map<String, Any?>> ?: return 0
            val leaseToken = parsed["lease_token"] as? String
            val sender = SmsSender(context)
            var dispatched = 0

            for (job in jobs) {
                val msgUuid = job["message_uuid"] as? String ?: continue
                val recipient = job["recipient_number"] as? String ?: continue
                val text = job["message_body"] as? String ?: continue
                val subId = (job["sending_subscription_id"] as? Number)?.toInt()
                val simSlot = (job["sending_sim_slot"] as? Number)?.toInt()
                val priority = job["priority"] as? String ?: "NORMAL"
                val deliveryReq = (job["delivery_report_requested"] as? Boolean) ?: true
                val expiresAt = job["expires_at"] as? String
                val appSource = job["application_source"] as? String ?: "Backend Automation"
                val refId = job["reference_id"] as? String

                val accepted = db.savePendingJob(
                    messageUuid = msgUuid,
                    leaseToken = leaseToken,
                    recipientNumber = recipient,
                    messageBody = text,
                    subscriptionId = subId,
                    simSlot = simSlot,
                    priority = priority,
                    deliveryReportRequested = deliveryReq,
                    expiresAt = expiresAt,
                    applicationSource = appSource,
                    referenceId = refId
                )
                if (!accepted) continue

                val res = sender.sendSms(
                    messageUuid = msgUuid,
                    rawRecipient = recipient,
                    messageBody = text,
                    explicitSubscriptionId = subId,
                    requestDeliveryReport = deliveryReq,
                    applicationSource = appSource,
                    referenceId = refId,
                    priority = priority
                )
                if (res.success) dispatched++
            }
            flushPendingUploads()
            dispatched
        } catch (e: Exception) {
            Log.w(TAG, "Job poll error: ${e.message}")
            0
        }
    }

    private fun httpGet(urlStr: String): Pair<Int, String?> {
        val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            setRequestProperty("Accept", "application/json")
            setRequestProperty("X-Device-ID", getDeviceId())
            setRequestProperty("X-School-ID", getSchoolId())
            getAuthToken()?.takeIf { it.isNotEmpty() }?.let {
                setRequestProperty("Authorization", "Bearer $it")
            }
            connectTimeout = 5000
            readTimeout = 5000
        }
        val code = conn.responseCode
        val stream = if (code in 200..399) conn.inputStream else conn.errorStream
        val text = stream?.let { BufferedReader(InputStreamReader(it)).use { br -> br.readText() } }
        return code to text
    }

    private fun httpPost(urlStr: String, bodyJson: String): Pair<Int, String?> {
        val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "application/json")
            setRequestProperty("X-Device-ID", getDeviceId())
            setRequestProperty("X-School-ID", getSchoolId())
            getAuthToken()?.takeIf { it.isNotEmpty() }?.let {
                setRequestProperty("Authorization", "Bearer $it")
            }
            connectTimeout = 5000
            readTimeout = 5000
            doOutput = true
        }
        OutputStreamWriter(conn.outputStream).use { it.write(bodyJson) }
        val code = conn.responseCode
        val stream = if (code in 200..399) conn.inputStream else conn.errorStream
        val text = stream?.let { BufferedReader(InputStreamReader(it)).use { br -> br.readText() } }
        return code to text
    }
}
