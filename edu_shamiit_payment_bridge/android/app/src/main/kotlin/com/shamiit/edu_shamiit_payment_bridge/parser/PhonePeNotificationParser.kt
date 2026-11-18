package com.shamiit.edu_shamiit_payment_bridge.parser

import android.content.Context
import com.shamiit.edu_shamiit_payment_bridge.model.PaymentNotificationEvent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.regex.Pattern

class PhonePeNotificationParser(private val context: Context? = null) : NotificationParser {
    override val supportedPackage: String = "com.phonepe.app"
    override val appDisplayName: String = "PhonePe"
    override val version: String = "1.1.0"

    override fun canHandle(packageName: String): Boolean {
        return packageName.contains("phonepe", ignoreCase = true)
    }

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

        // Distinguish outgoing vs incoming:
        // 'has sent' is an incoming payment ('NEHA has sent ₹1 to your account')
        val isOutgoing = fullContent.contains("paid to", ignoreCase = true) ||
                         fullContent.contains("payment sent to", ignoreCase = true) ||
                         fullContent.contains("you have sent", ignoreCase = true) ||
                         fullContent.contains("transferred to", ignoreCase = true) ||
                         fullContent.contains("debited from", ignoreCase = true) ||
                         (fullContent.contains("debited", ignoreCase = true) && !fullContent.contains("has sent", ignoreCase = true))

        val eventType = if (isOutgoing) "PAYMENT_SENT" else "PAYMENT_RECEIVED"

        // 1. Amount Extraction (supports Rs, INR, \u20B9, ₹ and comma formatting)
        var amountPaise = 0L
        val amountMatcher = getPattern("amount", "(?:Rs\\.?|INR|\\u20B9|₹)\\s*([0-9,]+(?:\\.[0-9]{1,2})?)").matcher(fullContent)
        if (amountMatcher.find()) {
            val rawAmt = amountMatcher.group(1)?.replace(",", "") ?: "0"
            try {
                val parsedDouble = rawAmt.toDouble()
                amountPaise = Math.round(parsedDouble * 100)
            } catch (_: Exception) {}
        }

        // 2. Reference / UTR
        var ref: String? = null
        val refMatcher = getPattern("reference", "(?:Ref(?:erence)?:?|UTR:?|Txn(?:Id)?:?|UPI/)\\s*([A-Za-z0-9/_-]+)").matcher(fullContent)
        if (refMatcher.find()) {
            val matched = refMatcher.group(1)
            ref = if (matched != null && !matched.startsWith("UPI/")) "UPI/$matched" else matched
        }

        // 3. Sender Name Extraction (supports 'Received from <name>', '<name> has sent', etc.)
        var senderName: String? = null
        val hasSentMatcher = Pattern.compile("(?:Money received\\s+)?([A-Za-z0-9\\s.*]+?)\\s+has sent", Pattern.CASE_INSENSITIVE).matcher(fullContent)
        if (hasSentMatcher.find()) {
            val cand = hasSentMatcher.group(1)?.trim()
            if (!cand.isNullOrEmpty() && !cand.equals("Money received", ignoreCase = true)) {
                senderName = cand
            }
        }
        if (senderName == null) {
            val senderMatcher = getPattern("sender", "(?:from|by)\\s+([*\\d\\w\\s]+?)(?:\\s+Ref|\\s+UPI|\\s+to|\\s*\\(|$)").matcher(fullContent)
            if (senderMatcher.find()) {
                senderName = senderMatcher.group(1)?.trim()
            }
        }

        // 4. Masked Sender / Bank Account Identifier
        var maskedSender: String? = null
        val maskedMatcher = getPattern("masked", "(\\*+\\s*\\d{3,4})").matcher(fullContent)
        if (maskedMatcher.find()) {
            maskedSender = maskedMatcher.group(1)?.trim()
        }
        if (maskedSender == null) {
            val bankMatcher = Pattern.compile("bank account\\s+([A-Za-z0-9\\s-]+)", Pattern.CASE_INSENSITIVE).matcher(fullContent)
            if (bankMatcher.find()) {
                maskedSender = bankMatcher.group(1)?.trim()
            }
        }

        val confidence = if (amountPaise > 0 && ref != null) "HIGH" else if (amountPaise > 0) "HIGH" else "LOW"

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
