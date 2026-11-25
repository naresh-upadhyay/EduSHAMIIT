package com.shamiit.shamiit_sms_gateway.bridge

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import com.shamiit.shamiit_sms_gateway.security.SecureCredentialStore
import com.shamiit.shamiit_sms_gateway.service.SmsGatewayForegroundService
import com.shamiit.shamiit_sms_gateway.storage.SmsGatewayDatabaseHelper
import com.shamiit.shamiit_sms_gateway.sync.GatewaySyncEngine
import com.shamiit.shamiit_sms_gateway.telephony.diagnostics.ContactsHelper
import com.shamiit.shamiit_sms_gateway.telephony.diagnostics.SmsPermissionManager
import com.shamiit.shamiit_sms_gateway.telephony.diagnostics.TelephonyDiagnostics
import com.shamiit.shamiit_sms_gateway.telephony.sender.SmsSender
import com.shamiit.shamiit_sms_gateway.telephony.sender.SmsValidator
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimManager
import com.shamiit.shamiit_sms_gateway.worker.GatewayHeartbeatWorker
import com.shamiit.shamiit_sms_gateway.worker.SmsSyncWorker
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class SmsGatewayChannel(
    private val context: Context,
    private val activityProvider: () -> Activity?
) : MethodChannel.MethodCallHandler {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.shamiit.sms_gateway/channel"
        const val EVENT_CHANNEL_NAME = "com.shamiit.sms_gateway/events"
    }

    private val db = SmsGatewayDatabaseHelper.getInstance(context)
    private val simManager = SimManager(context)
    private val smsSender = SmsSender(context)
    private val creds = SecureCredentialStore(context)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingPermissionResult: MethodChannel.Result? = null

    fun onPermissionRequestCompleted() {
        val res = pendingPermissionResult ?: return
        pendingPermissionResult = null
        res.success(SmsPermissionManager.getPermissionSnapshot(context, activityProvider()))
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getUniqueDeviceId" -> {
                result.success(TelephonyDiagnostics.getOrCreateUniqueDeviceId(context))
            }

            "isEmulator" -> {
                result.success(TelephonyDiagnostics.isEmulator())
            }

            "getPermissionSnapshot" -> {
                result.success(SmsPermissionManager.getPermissionSnapshot(context, activityProvider()))
            }

            "requestCorePermissions" -> {
                val act = activityProvider()
                if (act == null) {
                    result.success(SmsPermissionManager.getPermissionSnapshot(context))
                    return
                }
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(
                    act,
                    SmsPermissionManager.corePermissions(),
                    SmsPermissionManager.REQ_CORE_PERMISSIONS
                )
            }

            "requestContactsPermission" -> {
                val act = activityProvider()
                if (act == null) {
                    result.success(ContactsHelper.hasContactsPermission(context))
                    return
                }
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(
                    act,
                    arrayOf(android.Manifest.permission.READ_CONTACTS),
                    SmsPermissionManager.REQ_CONTACTS_PERMISSION
                )
            }

            "openAppSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "isIgnoringBatteryOptimizations" -> {
                result.success(TelephonyDiagnostics.isIgnoringBatteryOptimizations(context))
            }

            "requestIgnoreBatteryOptimizations" -> {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (_: Exception) {
                    result.success(false)
                }
            }

            "startGatewayService" -> {
                SmsSyncWorker.schedulePeriodic(context)
                GatewayHeartbeatWorker.schedulePeriodic(context)
                SmsGatewayForegroundService.start(context)
                result.success(true)
            }

            "stopGatewayService" -> {
                SmsGatewayForegroundService.stop(context)
                result.success(true)
            }

            "isGatewayServiceRunning" -> {
                result.success(SmsGatewayForegroundService.isRunning)
            }

            "discoverSims" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val sims = simManager.discoverSims().map { it.toMap() }
                    mainHandler.post { result.success(sims) }
                }
            }

            "setSimUsageMode" -> {
                val subId = call.argument<Int>("subscription_id")
                val mode = call.argument<String>("usage_mode") ?: "SEND_RECEIVE"
                if (subId != null) {
                    db.setSimUsageMode(subId, mode)
                }
                result.success(true)
            }

            "getLocalSettings" -> {
                result.success(db.getSettings())
            }

            "saveLocalSettings" -> {
                val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any>()
                val cv = ContentValues().apply {
                    (args["preferred_sim_mode"] as? String)?.let { put("preferred_sim_mode", it) }
                    if (args.containsKey("preferred_subscription_id")) {
                        val v = (args["preferred_subscription_id"] as? Number)?.toInt()
                        if (v != null) put("preferred_subscription_id", v) else putNull("preferred_subscription_id")
                    }
                    if (args.containsKey("preferred_sim_slot")) {
                        val v = (args["preferred_sim_slot"] as? Number)?.toInt()
                        if (v != null) put("preferred_sim_slot", v) else putNull("preferred_sim_slot")
                    }
                    if (args.containsKey("secondary_subscription_id")) {
                        val v = (args["secondary_subscription_id"] as? Number)?.toInt()
                        if (v != null) put("secondary_subscription_id", v) else putNull("secondary_subscription_id")
                    }
                    if (args.containsKey("secondary_sim_slot")) {
                        val v = (args["secondary_sim_slot"] as? Number)?.toInt()
                        if (v != null) put("secondary_sim_slot", v) else putNull("secondary_sim_slot")
                    }
                    (args["auto_fallback_enabled"] as? Boolean)?.let { put("auto_fallback_enabled", if (it) 1 else 0) }
                    (args["switch_on_unavailable"] as? Boolean)?.let { put("switch_on_unavailable", if (it) 1 else 0) }
                    (args["switch_on_network_error"] as? Boolean)?.let { put("switch_on_network_error", if (it) 1 else 0) }
                    (args["switch_back_on_recover"] as? Boolean)?.let { put("switch_back_on_recover", if (it) 1 else 0) }
                    (args["automated_messaging_enabled"] as? Boolean)?.let { put("automated_messaging_enabled", if (it) 1 else 0) }
                    (args["incoming_forwarding_enabled"] as? Boolean)?.let { put("incoming_forwarding_enabled", if (it) 1 else 0) }
                    (args["queue_sync_enabled"] as? Boolean)?.let { put("queue_sync_enabled", if (it) 1 else 0) }
                    (args["scheduled_processing_enabled"] as? Boolean)?.let { put("scheduled_processing_enabled", if (it) 1 else 0) }
                    (args["polling_interval_seconds"] as? Number)?.let { put("polling_interval_seconds", it.toInt()) }
                    (args["message_expiration_seconds"] as? Number)?.let { put("message_expiration_seconds", it.toInt()) }
                    (args["retention_days"] as? Number)?.let { put("retention_days", it.toInt()) }
                    (args["emergency_disabled"] as? Boolean)?.let { put("emergency_disabled", if (it) 1 else 0) }
                    (args["server_url"] as? String)?.let { put("server_url", it.trim().trimEnd('/')) }
                }
                if (cv.size() > 0) db.updateSettings(cv)
                result.success(true)
            }

            "sendNativeSms" -> {
                val recipient = call.argument<String>("recipient") ?: ""
                val messageBody = call.argument<String>("message_body") ?: ""
                val subId = call.argument<Int>("subscription_id")
                val deliveryReq = call.argument<Boolean>("delivery_report_requested") ?: true
                val appSource = call.argument<String>("application_source") ?: "SMS Gateway App"
                val refId = call.argument<String>("reference_id")
                val priority = call.argument<String>("priority") ?: "NORMAL"
                val msgUuid = call.argument<String>("message_uuid")

                CoroutineScope(Dispatchers.IO).launch {
                    val res = if (msgUuid != null) {
                        smsSender.sendSms(
                            messageUuid = msgUuid,
                            rawRecipient = recipient,
                            messageBody = messageBody,
                            explicitSubscriptionId = subId,
                            requestDeliveryReport = deliveryReq,
                            applicationSource = appSource,
                            referenceId = refId,
                            priority = priority
                        )
                    } else {
                        smsSender.sendSms(
                            rawRecipient = recipient,
                            messageBody = messageBody,
                            explicitSubscriptionId = subId,
                            requestDeliveryReport = deliveryReq,
                            applicationSource = appSource,
                            referenceId = refId,
                            priority = priority
                        )
                    }
                    if (res.success) {
                        GatewaySyncEngine(context).flushPendingUploads()
                    }
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "success" to res.success,
                                "message_uuid" to res.messageUuid,
                                "status" to res.status,
                                "subscription_id" to res.subscriptionId,
                                "sim_slot" to res.simSlot,
                                "carrier_name" to res.carrierName,
                                "segment_count" to res.segmentCount,
                                "encoding" to res.encoding,
                                "error" to res.error
                            )
                        )
                    }
                }
            }

            "analyzeSmsText" -> {
                val text = call.argument<String>("text") ?: ""
                val est = SmsValidator.analyzeEncoding(text)
                result.success(
                    mapOf(
                        "encoding" to est.encoding,
                        "character_count" to est.characterCount,
                        "segment_count" to est.segmentCount,
                        "per_segment_limit" to est.perSegmentLimit,
                        "remaining" to est.remainingInCurrentSegment
                    )
                )
            }

            "getLocalMessages" -> {
                val status = call.argument<String>("status")
                val direction = call.argument<String>("direction")
                val simSlot = call.argument<Int>("sim_slot")
                val search = call.argument<String>("search")
                val limit = call.argument<Int>("limit") ?: 100
                val offset = call.argument<Int>("offset") ?: 0
                CoroutineScope(Dispatchers.IO).launch {
                    val list = db.queryMessages(status, direction, simSlot, search, limit, offset)
                    mainHandler.post { result.success(list) }
                }
            }

            "getLocalStats" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val stats = db.getTodayStats()
                    mainHandler.post { result.success(stats) }
                }
            }

            "getLocalEvents" -> {
                val limit = call.argument<Int>("limit") ?: 25
                CoroutineScope(Dispatchers.IO).launch {
                    val list = db.getRecentEvents(limit)
                    mainHandler.post { result.success(list) }
                }
            }

            "getContacts" -> {
                val query = call.argument<String>("query")
                CoroutineScope(Dispatchers.IO).launch {
                    val list = ContactsHelper.getContacts(context, query)
                    mainHandler.post { result.success(list) }
                }
            }

            "getDiagnostics" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val diag = TelephonyDiagnostics.collectDiagnostics(context)
                    mainHandler.post { result.success(diag) }
                }
            }

            "syncNow" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val engine = GatewaySyncEngine(context)
                    val flushRes = engine.flushPendingUploads()
                    val dispatched = engine.pollAndExecuteLeasedJobs()
                    val hbOk = engine.sendHeartbeatAndSyncSims()
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "success" to (flushRes["success"] == true || hbOk),
                                "uploaded" to (flushRes["uploaded"] ?: 0),
                                "remaining_uploads" to (flushRes["remaining"] ?: 0),
                                "dispatched_jobs" to dispatched,
                                "heartbeat_ok" to hbOk
                            )
                        )
                    }
                }
            }

            "cleanupLocalStorage" -> {
                val days = call.argument<Int>("retention_days") ?: 90
                CoroutineScope(Dispatchers.IO).launch {
                    val deleted = db.cleanupOldSyncedData(days)
                    mainHandler.post {
                        result.success(
                            mapOf(
                                "deleted_count" to deleted,
                                "database_size_bytes" to db.getDatabaseSizeBytes()
                            )
                        )
                    }
                }
            }

            "saveCredentials" -> {
                call.argument<String>("auth_token")?.let { creds.saveAuthToken(it) }
                call.argument<String>("device_token")?.let { creds.saveDeviceToken(it) }
                call.argument<String>("device_id")?.let { creds.saveDeviceId(it) }
                call.argument<String>("school_id")?.let { creds.saveSchoolId(it) }
                result.success(true)
            }

            "clearCredentials" -> {
                creds.clearAuth()
                result.success(true)
            }

            else -> result.notImplemented()
        }
    }
}
