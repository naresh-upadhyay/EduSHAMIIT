package com.shamiit.edu_shamiit_payment_bridge.parser

import android.content.Context
import com.shamiit.edu_shamiit_payment_bridge.model.PaymentNotificationEvent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID
import java.util.regex.Pattern

class GenericUpiNotificationParser(private val context: Context? = null) : NotificationParser {
    override val supportedPackage: String = "*"
    override val appDisplayName: String = "UPI App"
    override val version: String = "1.0.0"

    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
        timeZone = TimeZone.getTimeZone("UTC")
    }

    private fun getPattern(packageName: String, type: String, defaultRegex: String): Pattern {
        val prefs = context?.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
        val customRegex = prefs?.getString("${packageName}_$type", null) ?: prefs?.getString("*_$type", null)
        return if (!customRegex.isNullOrEmpty()) {
            try { Pattern.compile(customRegex, Pattern.CASE_INSENSITIVE) } 
            catch (_: Exception) { Pattern.compile(defaultRegex, Pattern.CASE_INSENSITIVE) }
        } else {
            Pattern.compile(defaultRegex, Pattern.CASE_INSENSITIVE)
        }
    }

    override fun canHandle(packageName: String): Boolean = true

    override fun parse(
        packageName: String,
        title: String?,
        text: String?,
        postTime: Long
    ): PaymentNotificationEvent {
        val fullContent = "${title ?: ""} ${text ?: ""}".trim()
        val timestampStr = isoFormat.format(if (postTime > 0) Date(postTime) else Date())
        val eventUuid = UUID.randomUUID().toString()

        // Distinguish outgoing vs incoming payment notifications accurately:
        val isOutgoing = fullContent.contains("paid to", ignoreCase = true) ||
                         fullContent.contains("payment sent to", ignoreCase = true) ||
                         fullContent.contains("you have sent", ignoreCase = true) ||
                         fullContent.contains("you sent", ignoreCase = true) ||
                         fullContent.contains("debited from", ignoreCase = true) ||
                         (fullContent.contains("debited", ignoreCase = true) && !fullContent.contains("has sent", ignoreCase = true))

        val eventType = if (isOutgoing) "PAYMENT_SENT" else "PAYMENT_RECEIVED"

        var amountPaise = 0L
        val amountPatternStr = "(?:Rs\\.?|INR|\\u20B9|₹|amount of|credited with|received|received an amount of)\\s*[:]?\\s*(?:Rs\\.?|INR|\\u20B9|₹)?\\s*([0-9,]+(?:\\.[0-9]{1,2})?)"
        val amountMatcher = getPattern(packageName, "amount", amountPatternStr).matcher(fullContent)
        if (amountMatcher.find()) {
            val rawAmt = amountMatcher.group(1)?.replace(",", "") ?: "0"
            try {
                val parsedDouble = rawAmt.toDouble()
                amountPaise = Math.round(parsedDouble * 100)
            } catch (_: Exception) {}
        }

        var ref: String? = null
        val refPatternStr = "(?:Ref(?:erence)?|UTR|Txn(?:Id)?|UPI Ref(?: no)?|Transaction ID|UPI/)\\s*[:/]?\\s*([A-Za-z0-9/_-]+)"
        val refMatcher = getPattern(packageName, "reference", refPatternStr).matcher(fullContent)
        if (refMatcher.find()) {
            ref = refMatcher.group(1)?.trim()
        }

        var maskedSender: String? = null
        val maskedMatcher = getPattern(packageName, "masked", "(\\*+\\s*\\d{3,4})").matcher(fullContent)
        if (maskedMatcher.find()) {
            maskedSender = maskedMatcher.group(1)?.trim()
        }

        var senderName: String? = null
        val senderPatternStr = "(?:from|by|received from)\\s+([*\\d\\w\\s]+?)(?:\\s+Ref|\\s+UPI|\\s*\\(|$)"
        val senderMatcher = getPattern(packageName, "sender", senderPatternStr).matcher(fullContent)
        if (senderMatcher.find()) {
            senderName = senderMatcher.group(1)?.trim()
        }

        val appName = when {
            packageName.contains("phonepe", ignoreCase = true) || fullContent.contains("PhonePe", ignoreCase = true) -> "PhonePe"
            packageName.contains("paisa", ignoreCase = true) || packageName.contains("google", ignoreCase = true) || fullContent.contains("Google Pay", ignoreCase = true) || fullContent.contains("GPay", ignoreCase = true) -> "Google Pay"
            packageName.contains("paytm", ignoreCase = true) || fullContent.contains("Paytm", ignoreCase = true) -> "Paytm"
            packageName.contains("bhim", ignoreCase = true) || fullContent.contains("BHIM", ignoreCase = true) -> "BHIM UPI"
            else -> "UPI App"
        }

        val confidence = if (amountPaise > 0 && ref != null) "HIGH" else if (amountPaise > 0) "MEDIUM" else "LOW"

        return PaymentNotificationEvent(
            eventUuid = eventUuid,
            sourcePackage = packageName,
            sourceApp = appName,
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
