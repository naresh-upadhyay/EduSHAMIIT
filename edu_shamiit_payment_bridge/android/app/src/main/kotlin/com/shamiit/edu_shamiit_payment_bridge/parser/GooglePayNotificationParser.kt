package com.shamiit.edu_shamiit_payment_bridge.parser

import android.content.Context
import com.shamiit.edu_shamiit_payment_bridge.model.PaymentNotificationEvent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.regex.Pattern

class GooglePayNotificationParser(private val context: Context? = null) : NotificationParser {
    override val supportedPackage: String = "com.google.android.apps.nbu.paisa.user"
    override val appDisplayName: String = "Google Pay"
    override val version: String = "1.0.0"

    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private fun getPattern(type: String, defaultRegex: String): Pattern {
        val prefs = context?.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
        val customRegex = prefs?.getString("${supportedPackage}_$type", null)
        return if (!customRegex.isNullOrEmpty()) {
            try { Pattern.compile(customRegex, Pattern.CASE_INSENSITIVE) } 
            catch (e: Exception) { Pattern.compile(defaultRegex, Pattern.CASE_INSENSITIVE) }
        } else {
            Pattern.compile(defaultRegex, Pattern.CASE_INSENSITIVE)
        }
    }

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
                         fullContent.contains("you paid", ignoreCase = true) ||
                         fullContent.contains("payment sent", ignoreCase = true) ||
                         fullContent.contains("debited", ignoreCase = true)

        val eventType = if (isOutgoing) "PAYMENT_SENT" else "PAYMENT_RECEIVED"

        // 1. Amount
        var amountPaise = 0L
        val amountMatcher = getPattern("amount", "(?:Rs\\.?|₹)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)").matcher(fullContent)
        if (amountMatcher.find()) {
            val rawAmt = amountMatcher.group(1)?.replace(",", "") ?: "0"
            try {
                val parsedDouble = rawAmt.toDouble()
                amountPaise = Math.round(parsedDouble * 100)
            } catch (_: Exception) {}
        }

        // 2. Reference / UTR
        var ref: String? = null
        val refMatcher = getPattern("reference", "(?:Ref|GPay-|Txn ID:?)\\s*([A-Za-z0-9/_-]+)").matcher(fullContent)
        if (refMatcher.find()) {
            val m = refMatcher.group(1)
            ref = if (m != null && !m.startsWith("GPay-") && !m.startsWith("UPI/")) "GPay-$m" else m
        }

        // 3. Masked Sender
        var maskedSender: String? = null
        val maskedMatcher = getPattern("masked", "(\\*+\\s*\\d{3,4})").matcher(fullContent)
        if (maskedMatcher.find()) {
            maskedSender = maskedMatcher.group(1)?.trim()
        }

        // 4. Sender Name
        var senderName: String? = null
        val senderMatcher = getPattern("sender", "(?:from|by)\\s+([*\\d\\w\\s]+?)(?:\\s*\\(|\\s*Ref|$)").matcher(fullContent)
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
