package com.shamiit.edu_shamiit_payment_bridge.parser

import com.shamiit.edu_shamiit_payment_bridge.model.PaymentNotificationEvent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.regex.Pattern

class PaytmNotificationParser : NotificationParser {
    override val supportedPackage: String = "net.one97.paytm"
    override val appDisplayName: String = "Paytm"
    override val version: String = "1.0.0"

    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private val amountPattern = Pattern.compile("(?:Rs\\.?|₹)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)", Pattern.CASE_INSENSITIVE)
    private val senderPattern = Pattern.compile("(?:from|by)\\s+([*\\d\\w\\s]+?)(?:\\s+Ref|\\s*\\(|$)", Pattern.CASE_INSENSITIVE)
    private val refPattern = Pattern.compile("(?:UPI Ref(?: no)?|Txn ID|Ref:?)\\s*([A-Za-z0-9/_-]+)", Pattern.CASE_INSENSITIVE)
    private val maskedPattern = Pattern.compile("(\\*+\\s*\\d{3,4})")

    override fun parse(
        packageName: String,
        title: String?,
        text: String?,
        postTime: Long
    ): PaymentNotificationEvent {
        val fullContent = "${title ?: ""} ${text ?: ""}".trim()
        val timestampStr = isoFormat.format(if (postTime > 0) Date(postTime) else Date())
        val eventUuid = UUID.randomUUID().toString()

        val isOutgoing = fullContent.contains("paid to", ignoreCase = true) ||
                         fullContent.contains("sent to", ignoreCase = true) ||
                         fullContent.contains("debited", ignoreCase = true)

        val eventType = if (isOutgoing) "PAYMENT_SENT" else "PAYMENT_RECEIVED"

        var amountPaise = 0L
        val amountMatcher = amountPattern.matcher(fullContent)
        if (amountMatcher.find()) {
            val rawAmt = amountMatcher.group(1)?.replace(",", "") ?: "0"
            try {
                val parsedDouble = rawAmt.toDouble()
                amountPaise = Math.round(parsedDouble * 100)
            } catch (_: Exception) {}
        }

        var ref: String? = null
        val refMatcher = refPattern.matcher(fullContent)
        if (refMatcher.find()) {
            ref = refMatcher.group(1)?.trim()
        }

        var maskedSender: String? = null
        val maskedMatcher = maskedPattern.matcher(fullContent)
        if (maskedMatcher.find()) {
            maskedSender = maskedMatcher.group(1)?.trim()
        }

        var senderName: String? = null
        val senderMatcher = senderPattern.matcher(fullContent)
        if (senderMatcher.find()) {
            senderName = senderMatcher.group(1)?.trim()
        }

        val confidence = if (amountPaise > 0 && ref != null) "HIGH" else if (amountPaise > 0) "MEDIUM" else "LOW"

        return PaymentNotificationEvent(
            eventUuid = eventUuid,
            sourcePackage = packageName,
            sourceApp = appDisplayName,
            eventType = eventType,
            amountPaise = amountPaise,
            senderName = senderName,
            maskedSenderIdentifier = maskedSender,
            transactionReference = ref,
            notificationTimestamp = timestampStr,
            rawTitle = title,
            rawText = text,
            parserVersion = version,
            confidenceScore = confidence,
            parsingStatus = if (amountPaise > 0) "PARSED" else "UNPARSED"
        )
    }
}
