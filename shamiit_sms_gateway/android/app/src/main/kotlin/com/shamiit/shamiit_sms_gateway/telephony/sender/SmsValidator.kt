package com.shamiit.shamiit_sms_gateway.telephony.sender

data class SmsEncodingEstimate(
    val encoding: String, // GSM7 or UNICODE
    val characterCount: Int,
    val segmentCount: Int,
    val perSegmentLimit: Int,
    val remainingInCurrentSegment: Int
)

/**
 * Pure Kotlin SMS validation, GSM-7/UCS-2 encoding estimation, and template variable engine.
 */
object SmsValidator {

    private val GSM7_BASIC: Set<Char> = (
        "@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞ\u001BÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?" +
            "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà"
        ).toSet()

    private val GSM7_EXTENDED: Set<Char> = "^{}\\[~]|€".toSet()

    private val PHONE_REGEX = Regex("^(\\+[1-9]\\d{6,14}|[6-9]\\d{9}|0[6-9]\\d{9})$")
    private val VAR_REGEX = Regex("\\{([a-zA-Z0-9_]+)\\}")

    fun normalizePhoneNumber(raw: String): String {
        val cleaned = raw.trim().replace(Regex("[\\s\\-().]"), "")
        require(PHONE_REGEX.matches(cleaned)) {
            "Invalid phone number: '$raw'. Expected Indian 10-digit or international E.164 format."
        }
        return when {
            cleaned.matches(Regex("^[6-9]\\d{9}$")) -> "+91$cleaned"
            cleaned.matches(Regex("^0[6-9]\\d{9}$")) -> "+91${cleaned.substring(1)}"
            else -> cleaned
        }
    }

    fun isValidPhoneNumber(raw: String): Boolean {
        return try {
            normalizePhoneNumber(raw)
            true
        } catch (_: IllegalArgumentException) {
            false
        }
    }

    fun analyzeEncoding(body: String): SmsEncodingEstimate {
        if (body.isEmpty()) {
            return SmsEncodingEstimate(
                encoding = "GSM7",
                characterCount = 0,
                segmentCount = 1,
                perSegmentLimit = 160,
                remainingInCurrentSegment = 160
            )
        }

        var septets = 0
        var isGsm7 = true
        for (ch in body) {
            when {
                ch in GSM7_BASIC -> septets += 1
                ch in GSM7_EXTENDED -> septets += 2
                else -> {
                    isGsm7 = false
                    break
                }
            }
        }

        return if (isGsm7) {
            if (septets <= 160) {
                SmsEncodingEstimate("GSM7", septets, 1, 160, 160 - septets)
            } else {
                val segments = (septets + 152) / 153
                val rem = segments * 153 - septets
                SmsEncodingEstimate("GSM7", septets, segments, 153, rem)
            }
        } else {
            val units = body.length // UTF-16 code units
            if (units <= 70) {
                SmsEncodingEstimate("UNICODE", units, 1, 70, 70 - units)
            } else {
                val segments = (units + 66) / 67
                val rem = segments * 67 - units
                SmsEncodingEstimate("UNICODE", units, segments, 67, rem)
            }
        }
    }

    fun renderTemplateStrict(
        templateBody: String,
        variables: Map<String, String>,
        requiredVars: Set<String>? = null
    ): String {
        val detected = VAR_REGEX.findAll(templateBody).map { it.groupValues[1] }.toSet()
        val req = requiredVars ?: detected
        val missing = req.filter { variables[it].isNullOrBlank() }.sorted()
        require(missing.isEmpty()) {
            "Unresolved required template variables: ${missing.joinToString(", ")}"
        }
        var rendered = templateBody
        for (key in detected) {
            val v = variables[key]
            if (v != null) {
                rendered = rendered.replace("{$key}", v)
            }
        }
        val remaining = VAR_REGEX.findAll(rendered).map { it.groupValues[1] }.toSet()
        require(remaining.isEmpty()) {
            "Unresolved template placeholders: ${remaining.sorted().joinToString(", ")}"
        }
        return rendered
    }
}
