package com.shamiit.shamiit_sms_gateway.telephony.sender

import android.Manifest
import android.app.PendingIntent
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SmsManager
import androidx.core.content.ContextCompat
import com.google.gson.Gson
import com.shamiit.shamiit_sms_gateway.storage.SmsGatewayDatabaseHelper
import com.shamiit.shamiit_sms_gateway.telephony.delivery.SmsDeliveredReceiver
import com.shamiit.shamiit_sms_gateway.telephony.delivery.SmsSentReceiver
import com.shamiit.shamiit_sms_gateway.telephony.sim.PreferredSimMode
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimManager
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimSelectionResolver
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

data class SendSmsResult(
    val success: Boolean,
    val messageUuid: String,
    val status: String,
    val subscriptionId: Int? = null,
    val simSlot: Int? = null,
    val carrierName: String? = null,
    val segmentCount: Int = 1,
    val encoding: String = "GSM7",
    val error: String? = null
)

/**
 * Native Android SMS dispatch engine using SmsManager for a resolved subscriptionId.
 * Never marks a message DELIVERED on SmsManager acceptance; awaits Sent/Delivery PendingIntents.
 */
class SmsSender(private val context: Context) {

    companion object {
        const val ACTION_SMS_SENT = "com.shamiit.shamiit_sms_gateway.SMS_SENT"
        const val ACTION_SMS_DELIVERED = "com.shamiit.shamiit_sms_gateway.SMS_DELIVERED"
        const val EXTRA_MESSAGE_UUID = "extra_message_uuid"
        const val EXTRA_PART_INDEX = "extra_part_index"
        const val EXTRA_TOTAL_PARTS = "extra_total_parts"
        const val EXTRA_SUBSCRIPTION_ID = "extra_subscription_id"
        const val EXTRA_SIM_SLOT = "extra_sim_slot"
    }

    private val dbHelper = SmsGatewayDatabaseHelper.getInstance(context)
    private val simManager = SimManager(context)
    private val gson = Gson()

    fun hasSendPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.SEND_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    @Synchronized
    fun sendSms(
        messageUuid: String = "msg-${UUID.randomUUID().toString().replace("-", "")}",
        rawRecipient: String,
        messageBody: String,
        explicitSubscriptionId: Int? = null,
        requestDeliveryReport: Boolean = true,
        applicationSource: String = "SMS Gateway App",
        referenceId: String? = null,
        priority: String = "NORMAL"
    ): SendSmsResult {
        val nowIso = utcNowIso()

        if (!hasSendPermission()) {
            return SendSmsResult(
                success = false,
                messageUuid = messageUuid,
                status = "FAILED",
                error = "SEND_SMS runtime permission is not granted."
            )
        }

        // Duplicate submission guard
        val existing = dbHelper.getMessage(messageUuid)
        if (existing != null) {
            val st = existing["status"] as? String
            if (st in listOf("SENDING", "SENT", "DELIVERED")) {
                return SendSmsResult(
                    success = false,
                    messageUuid = messageUuid,
                    status = st ?: "SENDING",
                    error = "Duplicate message submission prevented ($messageUuid already $st)."
                )
            }
        }

        val normalizedRecipient = try {
            SmsValidator.normalizePhoneNumber(rawRecipient)
        } catch (e: IllegalArgumentException) {
            return SendSmsResult(
                success = false,
                messageUuid = messageUuid,
                status = "FAILED",
                error = e.message
            )
        }

        if (messageBody.isBlank()) {
            return SendSmsResult(
                success = false,
                messageUuid = messageUuid,
                status = "FAILED",
                error = "Message body cannot be empty."
            )
        }

        val settings = dbHelper.getSettings()
        if (((settings["emergency_disabled"] as? Number)?.toInt() ?: 0) == 1) {
            return SendSmsResult(
                success = false,
                messageUuid = messageUuid,
                status = "FAILED",
                error = "Emergency gateway disable is active."
            )
        }

        val sims = simManager.discoverSims()
        val prefMode = PreferredSimMode.fromString(settings["preferred_sim_mode"] as? String)
        val prefSub = (settings["preferred_subscription_id"] as? Number)?.toInt()
        val secSub = (settings["secondary_subscription_id"] as? Number)?.toInt()
        val autoFallback = ((settings["auto_fallback_enabled"] as? Number)?.toInt() ?: 0) == 1
        val switchUnavail = ((settings["switch_on_unavailable"] as? Number)?.toInt() ?: 1) == 1

        val resolution = SimSelectionResolver.resolveForSending(
            availableSims = sims,
            explicitSubscriptionId = explicitSubscriptionId,
            preferredMode = prefMode,
            preferredSubscriptionId = prefSub,
            secondarySubscriptionId = secSub,
            autoFallbackEnabled = autoFallback,
            switchWhenUnavailable = switchUnavail
        )

        val chosenSim = resolution.selectedSim
        if (chosenSim == null) {
            persistFailedAttempt(
                messageUuid = messageUuid,
                recipient = normalizedRecipient,
                body = messageBody,
                applicationSource = applicationSource,
                referenceId = referenceId,
                priority = priority,
                reason = resolution.errorReason ?: "No eligible SIM available",
                nowIso = nowIso
            )
            return SendSmsResult(
                success = false,
                messageUuid = messageUuid,
                status = "FAILED",
                error = resolution.errorReason
            )
        }

        val encodingEstimate = SmsValidator.analyzeEncoding(messageBody)
        val smsManager = getSmsManagerForSub(chosenSim.subscriptionId)
        val parts = smsManager.divideMessage(messageBody) ?: arrayListOf(messageBody)
        val totalParts = parts.size.coerceAtLeast(1)

        val initialParts = (0 until totalParts).map { idx ->
            mapOf("part" to (idx + 1), "sent_status" to "PENDING", "delivery_status" to "PENDING")
        }

        val msgValues = ContentValues().apply {
            put("message_uuid", messageUuid)
            put("direction", "OUTBOUND")
            put("recipient_number", normalizedRecipient)
            put("message_body", messageBody)
            put("encoding", encodingEstimate.encoding)
            put("segment_count", totalParts)
            put("sending_sim_slot", chosenSim.simSlotIndex)
            put("sending_subscription_id", chosenSim.subscriptionId)
            put("carrier_name", chosenSim.carrierName)
            put("application_source", applicationSource)
            put("reference_id", referenceId)
            put("priority", priority)
            put("status", "SENDING")
            put("delivery_report_requested", if (requestDeliveryReport) 1 else 0)
            put("created_at", nowIso)
            put("queued_at", nowIso)
            put("submitted_at", nowIso)
            put("sync_status", "PENDING")
            put("part_statuses_json", gson.toJson(initialParts))
        }
        dbHelper.upsertMessage(msgValues)
        dbHelper.updatePendingJobState(messageUuid, "DISPATCHED")

        val sentIntents = ArrayList<PendingIntent>(totalParts)
        val deliveredIntents = if (requestDeliveryReport) ArrayList<PendingIntent>(totalParts) else null
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        for (i in 0 until totalParts) {
            val reqCodeBase = (messageUuid.hashCode() and 0x00FFFFFF) * 32 + i
            val sentIntent = Intent(context, SmsSentReceiver::class.java).apply {
                action = ACTION_SMS_SENT
                putExtra(EXTRA_MESSAGE_UUID, messageUuid)
                putExtra(EXTRA_PART_INDEX, i)
                putExtra(EXTRA_TOTAL_PARTS, totalParts)
                putExtra(EXTRA_SUBSCRIPTION_ID, chosenSim.subscriptionId)
                putExtra(EXTRA_SIM_SLOT, chosenSim.simSlotIndex)
            }
            sentIntents.add(PendingIntent.getBroadcast(context, reqCodeBase, sentIntent, flags))

            if (requestDeliveryReport && deliveredIntents != null) {
                val delivIntent = Intent(context, SmsDeliveredReceiver::class.java).apply {
                    action = ACTION_SMS_DELIVERED
                    putExtra(EXTRA_MESSAGE_UUID, messageUuid)
                    putExtra(EXTRA_PART_INDEX, i)
                    putExtra(EXTRA_TOTAL_PARTS, totalParts)
                    putExtra(EXTRA_SUBSCRIPTION_ID, chosenSim.subscriptionId)
                    putExtra(EXTRA_SIM_SLOT, chosenSim.simSlotIndex)
                }
                deliveredIntents.add(PendingIntent.getBroadcast(context, reqCodeBase + 100000, delivIntent, flags))
            }
        }

        return try {
            if (totalParts == 1) {
                smsManager.sendTextMessage(
                    normalizedRecipient,
                    null,
                    parts[0],
                    sentIntents[0],
                    deliveredIntents?.get(0)
                )
            } else {
                smsManager.sendMultipartTextMessage(
                    normalizedRecipient,
                    null,
                    parts,
                    sentIntents,
                    deliveredIntents
                )
            }

            // Enqueue SMS_SUBMITTED event for backend sync (not SENT or DELIVERED!)
            val evtId = "evt-sub-${UUID.randomUUID().toString().replace("-", "")}"
            val evtPayload = gson.toJson(
                mapOf(
                    "event_uuid" to evtId,
                    "message_uuid" to messageUuid,
                    "event_type" to "SMS_SUBMITTED",
                    "title" to "SMS Submitted via SIM ${chosenSim.simSlotIndex + 1}",
                    "description" to "Submitted $totalParts part(s) to $normalizedRecipient",
                    "sim_slot" to chosenSim.simSlotIndex,
                    "subscription_id" to chosenSim.subscriptionId,
                    "carrier_name" to chosenSim.carrierName,
                    "part_statuses" to initialParts,
                    "event_timestamp" to nowIso
                )
            )
            dbHelper.insertEvent(
                eventUuid = evtId,
                messageUuid = messageUuid,
                eventType = "SMS_SUBMITTED",
                title = "SMS Submitted to $normalizedRecipient",
                description = "SIM ${chosenSim.simSlotIndex + 1} (${chosenSim.carrierName})",
                simSlot = chosenSim.simSlotIndex,
                subscriptionId = chosenSim.subscriptionId,
                applicationSource = applicationSource,
                payloadJson = evtPayload,
                eventTimestamp = nowIso
            )
            dbHelper.enqueuePendingUpload("up-$evtId", "EVENT", messageUuid, evtPayload)

            SendSmsResult(
                success = true,
                messageUuid = messageUuid,
                status = "SENDING",
                subscriptionId = chosenSim.subscriptionId,
                simSlot = chosenSim.simSlotIndex,
                carrierName = chosenSim.carrierName,
                segmentCount = totalParts,
                encoding = encodingEstimate.encoding
            )
        } catch (e: Exception) {
            val reason = "SmsManager exception: ${e.message ?: e.javaClass.simpleName}"
            dbHelper.updateMessageStatus(
                messageUuid = messageUuid,
                status = "FAILED",
                failureReason = reason,
                syncStatus = "PENDING"
            )
            SendSmsResult(
                success = false,
                messageUuid = messageUuid,
                status = "FAILED",
                subscriptionId = chosenSim.subscriptionId,
                simSlot = chosenSim.simSlotIndex,
                carrierName = chosenSim.carrierName,
                error = reason
            )
        }
    }

    @Suppress("DEPRECATION")
    private fun getSmsManagerForSub(subscriptionId: Int): SmsManager {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            context.getSystemService(SmsManager::class.java).createForSubscriptionId(subscriptionId)
        } else {
            SmsManager.getSmsManagerForSubscriptionId(subscriptionId)
        }
    }

    private fun persistFailedAttempt(
        messageUuid: String,
        recipient: String,
        body: String,
        applicationSource: String,
        referenceId: String?,
        priority: String,
        reason: String,
        nowIso: String
    ) {
        val enc = SmsValidator.analyzeEncoding(body)
        val cv = ContentValues().apply {
            put("message_uuid", messageUuid)
            put("direction", "OUTBOUND")
            put("recipient_number", recipient)
            put("message_body", body)
            put("encoding", enc.encoding)
            put("segment_count", enc.segmentCount)
            put("application_source", applicationSource)
            put("reference_id", referenceId)
            put("priority", priority)
            put("status", "FAILED")
            put("created_at", nowIso)
            put("failure_reason", reason)
            put("sync_status", "PENDING")
        }
        dbHelper.upsertMessage(cv)
    }

    private fun utcNowIso(): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date())
}
