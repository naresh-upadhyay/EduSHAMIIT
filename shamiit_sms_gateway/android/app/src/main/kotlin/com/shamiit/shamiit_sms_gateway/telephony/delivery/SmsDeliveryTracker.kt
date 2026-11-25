package com.shamiit.shamiit_sms_gateway.telephony.delivery

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsManager
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.shamiit.shamiit_sms_gateway.bridge.SmsEventBus
import com.shamiit.shamiit_sms_gateway.storage.SmsGatewayDatabaseHelper
import com.shamiit.shamiit_sms_gateway.telephony.sender.SmsSender
import com.shamiit.shamiit_sms_gateway.worker.SmsSyncWorker
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * Pure Kotlin multipart SMS state transition calculator.
 */
object SmsDeliveryStateMachine {

    fun updatePartSent(
        parts: MutableList<MutableMap<String, Any>>,
        partIndex: Int,
        totalParts: Int,
        resultCode: Int
    ): Pair<String, String?> {
        ensureSize(parts, totalParts)
        val isOk = resultCode == Activity.RESULT_OK
        val errDesc = if (isOk) null else mapSmsErrorCode(resultCode)
        parts[partIndex]["sent_status"] = if (isOk) "SENT" else "FAILED"
        if (errDesc != null) {
            parts[partIndex]["error"] = errDesc
        }

        val anyFailed = parts.any { it["sent_status"] == "FAILED" }
        if (anyFailed) {
            val reasons = parts.mapNotNull { it["error"] as? String }.distinct().joinToString("; ")
            return "FAILED" to reasons.ifEmpty { "SMS transmission failed (code $resultCode)" }
        }
        val allSent = parts.all { it["sent_status"] == "SENT" }
        return if (allSent) ("SENT" to null) else ("SENDING" to null)
    }

    fun updatePartDelivered(
        parts: MutableList<MutableMap<String, Any>>,
        partIndex: Int,
        totalParts: Int,
        resultCode: Int
    ): Pair<String, String?> {
        ensureSize(parts, totalParts)
        val isOk = resultCode == Activity.RESULT_OK
        parts[partIndex]["delivery_status"] = if (isOk) "DELIVERED" else "FAILED"
        if (!isOk) {
            parts[partIndex]["delivery_error"] = "Delivery report negative (code $resultCode)"
        }
        val anyFailed = parts.any { it["delivery_status"] == "FAILED" }
        if (anyFailed) {
            return "FAILED" to "Carrier delivery report failed"
        }
        val allDelivered = parts.all { it["delivery_status"] == "DELIVERED" }
        return if (allDelivered) ("DELIVERED" to null) else ("SENT" to null)
    }

    private fun ensureSize(parts: MutableList<MutableMap<String, Any>>, totalParts: Int) {
        while (parts.size < totalParts) {
            parts.add(
                mutableMapOf(
                    "part" to (parts.size + 1),
                    "sent_status" to "PENDING",
                    "delivery_status" to "PENDING"
                )
            )
        }
    }

    fun mapSmsErrorCode(resultCode: Int): String = when (resultCode) {
        SmsManager.RESULT_ERROR_GENERIC_FAILURE -> "Generic radio/carrier failure"
        SmsManager.RESULT_ERROR_RADIO_OFF -> "Cellular radio is turned off"
        SmsManager.RESULT_ERROR_NULL_PDU -> "Null PDU encoding failure"
        SmsManager.RESULT_ERROR_NO_SERVICE -> "No cellular network service"
        SmsManager.RESULT_ERROR_LIMIT_EXCEEDED -> "Carrier SMS rate limit exceeded"
        SmsManager.RESULT_ERROR_SHORT_CODE_NOT_ALLOWED -> "Short code sending not allowed"
        SmsManager.RESULT_ERROR_SHORT_CODE_NEVER_ALLOWED -> "Short code permanently blocked"
        else -> "SMS error code $resultCode"
    }
}

class SmsSentReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val messageUuid = intent.getStringExtra(SmsSender.EXTRA_MESSAGE_UUID) ?: return
        val partIndex = intent.getIntExtra(SmsSender.EXTRA_PART_INDEX, 0)
        val totalParts = intent.getIntExtra(SmsSender.EXTRA_TOTAL_PARTS, 1)
        val subId = intent.getIntExtra(SmsSender.EXTRA_SUBSCRIPTION_ID, -1)
        val slot = intent.getIntExtra(SmsSender.EXTRA_SIM_SLOT, 0)
        val resCode = resultCode

        val db = SmsGatewayDatabaseHelper.getInstance(context)
        val gson = Gson()
        val msg = db.getMessage(messageUuid) ?: return

        val partsType = object : TypeToken<MutableList<MutableMap<String, Any>>>() {}.type
        val parts: MutableList<MutableMap<String, Any>> = try {
            gson.fromJson(msg["part_statuses_json"] as? String ?: "[]", partsType) ?: mutableListOf()
        } catch (_: Exception) {
            mutableListOf()
        }

        val (newStatus, errorReason) = SmsDeliveryStateMachine.updatePartSent(
            parts = parts,
            partIndex = partIndex,
            totalParts = totalParts,
            resultCode = resCode
        )

        val nowIso = utcNowIso()
        db.updateMessageStatus(
            messageUuid = messageUuid,
            status = newStatus,
            submittedAt = nowIso,
            failureReason = errorReason,
            partStatusesJson = gson.toJson(parts),
            syncStatus = "PENDING"
        )

        if (newStatus == "SENT") {
            if (subId > 0) db.incrementSimStat(subId, "sent_count")
            enqueueEventAndSync(context, db, gson, messageUuid, "SMS_SENT", "SMS Sent via SIM ${slot + 1}", null, slot, subId, parts, nowIso)
        } else if (newStatus == "FAILED") {
            if (subId > 0) db.incrementSimStat(subId, "failed_count")
            enqueueEventAndSync(context, db, gson, messageUuid, "SMS_FAILED", "SMS Failed on SIM ${slot + 1}", errorReason, slot, subId, parts, nowIso)
        }
    }
}

class SmsDeliveredReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val messageUuid = intent.getStringExtra(SmsSender.EXTRA_MESSAGE_UUID) ?: return
        val partIndex = intent.getIntExtra(SmsSender.EXTRA_PART_INDEX, 0)
        val totalParts = intent.getIntExtra(SmsSender.EXTRA_TOTAL_PARTS, 1)
        val subId = intent.getIntExtra(SmsSender.EXTRA_SUBSCRIPTION_ID, -1)
        val slot = intent.getIntExtra(SmsSender.EXTRA_SIM_SLOT, 0)
        val resCode = resultCode

        val db = SmsGatewayDatabaseHelper.getInstance(context)
        val gson = Gson()
        val msg = db.getMessage(messageUuid) ?: return

        val partsType = object : TypeToken<MutableList<MutableMap<String, Any>>>() {}.type
        val parts: MutableList<MutableMap<String, Any>> = try {
            gson.fromJson(msg["part_statuses_json"] as? String ?: "[]", partsType) ?: mutableListOf()
        } catch (_: Exception) {
            mutableListOf()
        }

        val (newStatus, errorReason) = SmsDeliveryStateMachine.updatePartDelivered(
            parts = parts,
            partIndex = partIndex,
            totalParts = totalParts,
            resultCode = resCode
        )

        val nowIso = utcNowIso()
        db.updateMessageStatus(
            messageUuid = messageUuid,
            status = newStatus,
            deliveredAt = if (newStatus == "DELIVERED") nowIso else null,
            failureReason = errorReason,
            partStatusesJson = gson.toJson(parts),
            syncStatus = "PENDING"
        )

        if (newStatus == "DELIVERED") {
            enqueueEventAndSync(context, db, gson, messageUuid, "SMS_DELIVERED", "SMS Delivered to recipient", null, slot, subId, parts, nowIso)
        } else if (newStatus == "FAILED") {
            enqueueEventAndSync(context, db, gson, messageUuid, "SMS_FAILED", "SMS Delivery Failed", errorReason, slot, subId, parts, nowIso)
        }
    }
}

private fun enqueueEventAndSync(
    context: Context,
    db: SmsGatewayDatabaseHelper,
    gson: Gson,
    messageUuid: String,
    eventType: String,
    title: String,
    failureReason: String?,
    slot: Int,
    subId: Int,
    parts: List<Map<String, Any>>,
    nowIso: String
) {
    val evtUuid = "evt-${UUID.randomUUID().toString().replace("-", "")}"
    val payload = gson.toJson(
        mapOf(
            "event_uuid" to evtUuid,
            "message_uuid" to messageUuid,
            "event_type" to eventType,
            "title" to title,
            "description" to failureReason,
            "failure_reason" to failureReason,
            "sim_slot" to slot,
            "subscription_id" to if (subId > 0) subId else null,
            "part_statuses" to parts,
            "event_timestamp" to nowIso
        )
    )
    db.insertEvent(
        eventUuid = evtUuid,
        messageUuid = messageUuid,
        eventType = eventType,
        title = title,
        description = failureReason,
        simSlot = slot,
        subscriptionId = if (subId > 0) subId else null,
        applicationSource = "TelephonyEngine",
        payloadJson = payload,
        eventTimestamp = nowIso
    )
    db.enqueuePendingUpload("up-$evtUuid", "EVENT", messageUuid, payload)
    SmsEventBus.emit(
        mapOf(
            "type" to eventType,
            "message_uuid" to messageUuid,
            "title" to title,
            "failure_reason" to failureReason,
            "timestamp" to nowIso
        )
    )
    SmsSyncWorker.enqueueOneShot(context)
}

private fun utcNowIso(): String =
    SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }.format(Date())
