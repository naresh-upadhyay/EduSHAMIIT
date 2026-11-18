package com.shamiit.edu_shamiit_payment_bridge.parser

import android.content.Context
import com.shamiit.edu_shamiit_payment_bridge.model.PaymentNotificationEvent
import org.json.JSONArray
import org.json.JSONObject
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

    private fun evaluateClause(targetText: String, op: String, value: String, caseSensitive: Boolean): Boolean {
        if (value.isEmpty()) return true
        return when (op.uppercase()) {
            "EQUALS", "=" -> if (caseSensitive) targetText.trim() == value.trim()
                             else targetText.trim().equals(value.trim(), ignoreCase = true)
            "NOT_EQUALS", "!=" -> if (caseSensitive) targetText.trim() != value.trim()
                                 else !targetText.trim().equals(value.trim(), ignoreCase = true)
            "CONTAINS" -> if (caseSensitive) targetText.contains(value)
                          else targetText.contains(value, ignoreCase = true)
            "NOT_CONTAINS", "DOES_NOT_CONTAIN" -> if (caseSensitive) !targetText.contains(value)
                                                  else !targetText.contains(value, ignoreCase = true)
            "STARTS_WITH" -> if (caseSensitive) targetText.startsWith(value)
                             else targetText.startsWith(value, ignoreCase = true)
            "ENDS_WITH" -> if (caseSensitive) targetText.endsWith(value)
                           else targetText.endsWith(value, ignoreCase = true)
            "REGEX", "MATCHES_REGEX" -> try {
                val flags = if (caseSensitive) 0 else Pattern.CASE_INSENSITIVE
                Pattern.compile(value, flags).matcher(targetText).find()
            } catch (_: Exception) { false }
            "NOT_REGEX" -> try {
                val flags = if (caseSensitive) 0 else Pattern.CASE_INSENSITIVE
                !Pattern.compile(value, flags).matcher(targetText).find()
            } catch (_: Exception) { true }
            else -> if (caseSensitive) targetText.contains(value) else targetText.contains(value, ignoreCase = true)
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

        val appName = when {
            packageName.contains("phonepe", ignoreCase = true) || fullContent.contains("PhonePe", ignoreCase = true) -> "PhonePe"
            packageName.contains("paisa", ignoreCase = true) || packageName.contains("google", ignoreCase = true) || fullContent.contains("Google Pay", ignoreCase = true) || fullContent.contains("GPay", ignoreCase = true) -> "Google Pay"
            packageName.contains("paytm", ignoreCase = true) || fullContent.contains("Paytm", ignoreCase = true) -> "Paytm"
            packageName.contains("bhim", ignoreCase = true) || fullContent.contains("BHIM", ignoreCase = true) -> "BHIM UPI"
            packageName.contains("cred", ignoreCase = true) || fullContent.contains("CRED", ignoreCase = true) -> "CRED"
            packageName.contains("canara", ignoreCase = true) || fullContent.contains("Canara", ignoreCase = true) || (title?.contains("CANBNK", ignoreCase = true) == true) -> "Canara Bank"
            else -> "UPI App"
        }

        val prefs = context?.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
        val caseSensitive = prefs?.getBoolean("${packageName}_case_sensitive", false) ?: false

        // =========================================================================
        // QUALITY GATE 0: Azure DevOps Style Multi-Condition Rule Engine (AND / OR / NOT)
        // If user configured rich custom query conditions, evaluate them first!
        // =========================================================================
        val rulesJsonStr = prefs?.getString("${packageName}_rules_json", null)
            ?: prefs?.getString("*_rules_json", null)
        if (!rulesJsonStr.isNullOrBlank()) {
            try {
                val root = JSONObject(rulesJsonStr)
                val action = root.optString("action", "ACCEPT_AND_PARSE")
                val conditions = root.optJSONArray("conditions")
                if (conditions != null && conditions.length() > 0) {
                    var overallMatch = false
                    for (i in 0 until conditions.length()) {
                        val cond = conditions.getJSONObject(i)
                        val logicalOp = cond.optString("logical_op", "AND").uppercase()
                        val field = cond.optString("field", "title_or_body").lowercase()
                        val op = cond.optString("operator", "CONTAINS").uppercase()
                        val value = cond.optString("value", "")

                        val targetText = when (field) {
                            "title" -> title ?: ""
                            "body", "text", "description" -> text ?: ""
                            else -> fullContent
                        }

                        val clauseMatch = evaluateClause(targetText, op, value, caseSensitive)
                        if (i == 0) {
                            overallMatch = clauseMatch
                        } else {
                            if (logicalOp == "OR") {
                                overallMatch = overallMatch || clauseMatch
                            } else {
                                overallMatch = overallMatch && clauseMatch
                            }
                        }
                    }

                    // Check action against overall query match
                    val shouldAccept = if (action == "REJECT_AND_IGNORE") !overallMatch else overallMatch
                    if (!shouldAccept) {
                        return PaymentNotificationEvent(
                            eventUuid = eventUuid,
                            sourcePackage = packageName,
                            sourceApp = appName,
                            eventType = "PAYMENT_IGNORED",
                            amountPaise = 0L,
                            senderName = null,
                            maskedSenderIdentifier = null,
                            transactionReference = null,
                            notificationTimestamp = timestampStr,
                            rawTitle = title,
                            rawText = text,
                            parserVersion = version,
                            confidenceScore = "NONE",
                            parsingStatus = "IGNORED_BY_CUSTOM_QUERY_RULES"
                        )
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // =========================================================================
        // QUALITY GATE 1: Ignore Keywords (Negative Filter)
        // If message contains on-hold, loan offer, failed status -> REJECT
        // =========================================================================
        val customIgnoreStr = prefs?.getString("${packageName}_ignore_keywords", null)
            ?: prefs?.getString("*_ignore_keywords", null)
        val ignoreList = mutableListOf(
            "kept as hold", "kept on hold", "on hold", "hold in your account", "amount on hold",
            "failed", "declined", "unsuccessful", "timed out", "reversed", "rejected",
            "debited from", "withdrawn from", "spent on",
            "loan offer", "pre-approved", "eligible for loan", "cashback offer", "scratch card",
            "request received from", "mandate created", "autopay scheduled"
        )
        if (!customIgnoreStr.isNullOrBlank()) {
            val customTokens = customIgnoreStr.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            ignoreList.addAll(customTokens)
        }

        for (ignoreWord in ignoreList) {
            val containsWord = if (caseSensitive) {
                fullContent.contains(ignoreWord) || (title?.contains(ignoreWord) == true)
            } else {
                fullContent.contains(ignoreWord, ignoreCase = true) || (title?.contains(ignoreWord, ignoreCase = true) == true)
            }
            if (containsWord) {
                return PaymentNotificationEvent(
                    eventUuid = eventUuid,
                    sourcePackage = packageName,
                    sourceApp = appName,
                    eventType = "PAYMENT_IGNORED",
                    amountPaise = 0L,
                    senderName = null,
                    maskedSenderIdentifier = null,
                    transactionReference = null,
                    notificationTimestamp = timestampStr,
                    rawTitle = title,
                    rawText = text,
                    parserVersion = version,
                    confidenceScore = "NONE",
                    parsingStatus = "IGNORED_KEYWORD: '$ignoreWord'"
                )
            }
        }

        // =========================================================================
        // QUALITY GATE 2: Title Condition Matching
        // =========================================================================
        val titleMatchMode = (prefs?.getString("${packageName}_title_match_mode", null)
            ?: prefs?.getString("*_title_match_mode", null) ?: "ANY").uppercase()
        val titleMatchValue = prefs?.getString("${packageName}_title_match_value", null)
            ?: prefs?.getString("*_title_match_value", null)

        if (!titleMatchValue.isNullOrBlank() && titleMatchMode != "ANY") {
            val currentTitle = title ?: ""
            val titleMatches = when (titleMatchMode) {
                "EXACT" -> if (caseSensitive) currentTitle.trim() == titleMatchValue.trim()
                           else currentTitle.trim().equals(titleMatchValue.trim(), ignoreCase = true)
                "CONTAINS" -> if (caseSensitive) currentTitle.contains(titleMatchValue)
                             else currentTitle.contains(titleMatchValue, ignoreCase = true)
                "STARTS_WITH" -> if (caseSensitive) currentTitle.startsWith(titleMatchValue)
                                else currentTitle.startsWith(titleMatchValue, ignoreCase = true)
                "REGEX" -> try {
                    val flags = if (caseSensitive) 0 else Pattern.CASE_INSENSITIVE
                    Pattern.compile(titleMatchValue, flags).matcher(currentTitle).find()
                } catch (_: Exception) { false }
                else -> true
            }

            if (!titleMatches) {
                return PaymentNotificationEvent(
                    eventUuid = eventUuid,
                    sourcePackage = packageName,
                    sourceApp = appName,
                    eventType = "PAYMENT_IGNORED",
                    amountPaise = 0L,
                    senderName = null,
                    maskedSenderIdentifier = null,
                    transactionReference = null,
                    notificationTimestamp = timestampStr,
                    rawTitle = title,
                    rawText = text,
                    parserVersion = version,
                    confidenceScore = "NONE",
                    parsingStatus = "IGNORED_TITLE: expected $titleMatchMode '$titleMatchValue'"
                )
            }
        }

        // =========================================================================
        // QUALITY GATE 3: Required Inclusion Keywords
        // =========================================================================
        val requiredKeywordsStr = prefs?.getString("${packageName}_required_keywords", null)
            ?: prefs?.getString("*_required_keywords", null)
        if (!requiredKeywordsStr.isNullOrBlank()) {
            val reqTokens = requiredKeywordsStr.split(",").map { it.trim() }.filter { it.isNotEmpty() }
            if (reqTokens.isNotEmpty()) {
                val hasAnyRequired = reqTokens.any { reqWord ->
                    if (caseSensitive) fullContent.contains(reqWord)
                    else fullContent.contains(reqWord, ignoreCase = true)
                }
                if (!hasAnyRequired) {
                    return PaymentNotificationEvent(
                        eventUuid = eventUuid,
                        sourcePackage = packageName,
                        sourceApp = appName,
                        eventType = "PAYMENT_IGNORED",
                        amountPaise = 0L,
                        senderName = null,
                        maskedSenderIdentifier = null,
                        transactionReference = null,
                        notificationTimestamp = timestampStr,
                        rawTitle = title,
                        rawText = text,
                        parserVersion = version,
                        confidenceScore = "NONE",
                        parsingStatus = "IGNORED_MISSING_KEYWORD: requires any of ($requiredKeywordsStr)"
                    )
                }
            }
        }

        // Outgoing vs incoming check
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
