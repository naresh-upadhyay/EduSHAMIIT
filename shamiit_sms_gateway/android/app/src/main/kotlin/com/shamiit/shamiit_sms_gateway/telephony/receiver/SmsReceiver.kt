package com.shamiit.shamiit_sms_gateway.telephony.receiver

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import com.google.gson.Gson
import com.shamiit.shamiit_sms_gateway.bridge.SmsEventBus
import com.shamiit.shamiit_sms_gateway.storage.SmsGatewayDatabaseHelper
import com.shamiit.shamiit_sms_gateway.telephony.sender.SmsValidator
import com.shamiit.shamiit_sms_gateway.worker.IncomingSmsUploadWorker
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

/**
 * BroadcastReceiver for incoming network SMS (android.provider.Telephony.SMS_RECEIVED).
 * Persists locally to SQLite BEFORE scheduling WorkManager upload (no long network calls here).
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        val pendingResult = goAsync()
        Thread {
            try {
                val parts = messages.map { sms ->
                    ParsedSmsPart(
                        sender = sms.displayOriginatingAddress ?: sms.originatingAddress ?: "Unknown",
                        body = sms.displayMessageBody ?: sms.messageBody ?: "",
                        timestampMillis = sms.timestampMillis
                    )
                }

                val extrasMap = mutableMapOf<String, Any?>()
                intent.extras?.let { bundle ->
                    for (k in bundle.keySet()) {
                        @Suppress("DEPRECATION")
                        extrasMap[k] = bundle.get(k)
                    }
                }

                val merged = SmsPduParser.mergeParts(parts, extrasMap)
                val db = SmsGatewayDatabaseHelper.getInstance(context)
                val gson = Gson()
                val sims = db.getSims()

                for (item in merged) {
                    val msgUuid = "in-${UUID.randomUUID().toString().replace("-", "")}"
                    val tsIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                        timeZone = TimeZone.getTimeZone("UTC")
                    }.format(Date(if (item.timestampMillis > 0) item.timestampMillis else System.currentTimeMillis()))

                    val matchedSim = when {
                        item.subscriptionId != null -> sims.firstOrNull { (it["subscription_id"] as? Number)?.toInt() == item.subscriptionId }
                        item.simSlotIndex != null -> sims.firstOrNull { (it["sim_slot_index"] as? Number)?.toInt() == item.simSlotIndex }
                        else -> null
                    }
                    val resolvedSlot = item.simSlotIndex ?: (matchedSim?.get("sim_slot_index") as? Number)?.toInt()
                    val resolvedSubId = item.subscriptionId ?: (matchedSim?.get("subscription_id") as? Number)?.toInt()
                    val carrierName = matchedSim?.get("carrier_name") as? String
                    val enc = SmsValidator.analyzeEncoding(item.body)

                    val cv = ContentValues().apply {
                        put("message_uuid", msgUuid)
                        put("direction", "INBOUND")
                        put("sender_number", item.sender)
                        put("recipient_number", matchedSim?.get("phone_number") as? String ?: "Device SIM")
                        put("message_body", item.body)
                        put("encoding", enc.encoding)
                        put("segment_count", enc.segmentCount)
                        if (resolvedSlot != null) put("receiving_sim_slot", resolvedSlot)
                        if (resolvedSubId != null) put("receiving_subscription_id", resolvedSubId)
                        put("carrier_name", carrierName)
                        put("application_source", "Incoming Network SMS")
                        put("status", "RECEIVED")
                        put("created_at", tsIso)
                        put("received_at", tsIso)
                        put("sync_status", "PENDING")
                    }
                    db.upsertMessage(cv)

                    if (resolvedSubId != null) {
                        db.incrementSimStat(resolvedSubId, "received_count")
                    }

                    val uploadPayload = gson.toJson(
                        mapOf(
                            "message_uuid" to msgUuid,
                            "sender_number" to item.sender,
                            "recipient_number" to (matchedSim?.get("phone_number") as? String ?: "Device SIM"),
                            "message_body" to item.body,
                            "receiving_sim_slot" to resolvedSlot,
                            "receiving_subscription_id" to resolvedSubId,
                            "carrier_name" to carrierName,
                            "received_at" to tsIso
                        )
                    )
                    db.enqueuePendingUpload("up-$msgUuid", "INBOUND", msgUuid, uploadPayload)

                    val evtId = "evt-$msgUuid"
                    db.insertEvent(
                        eventUuid = evtId,
                        messageUuid = msgUuid,
                        eventType = "SMS_RECEIVED",
                        title = "SMS Received from ${item.sender}",
                        description = item.body.take(120),
                        simSlot = resolvedSlot,
                        subscriptionId = resolvedSubId,
                        applicationSource = "Incoming Network SMS",
                        payloadJson = uploadPayload,
                        eventTimestamp = tsIso
                    )

                    SmsEventBus.emit(
                        mapOf(
                            "type" to "SMS_RECEIVED",
                            "message_uuid" to msgUuid,
                            "sender_number" to item.sender,
                            "message_body" to item.body,
                            "sim_slot" to resolvedSlot,
                            "timestamp" to tsIso
                        )
                    )
                }

                IncomingSmsUploadWorker.enqueue(context)
            } finally {
                pendingResult.finish()
            }
        }.start()
    }
}
