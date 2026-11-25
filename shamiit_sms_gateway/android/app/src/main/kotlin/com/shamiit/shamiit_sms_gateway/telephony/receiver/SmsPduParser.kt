package com.shamiit.shamiit_sms_gateway.telephony.receiver

data class ParsedSmsPart(
    val sender: String,
    val body: String,
    val timestampMillis: Long
)

data class ConcatenatedSms(
    val sender: String,
    val body: String,
    val timestampMillis: Long,
    val subscriptionId: Int?,
    val simSlotIndex: Int?
)

/**
 * Pure Kotlin incoming SMS PDU/multipart concatenation & subscription metadata extractor.
 */
object SmsPduParser {

    fun mergeParts(
        parts: List<ParsedSmsPart>,
        extrasMap: Map<String, Any?>
    ): List<ConcatenatedSms> {
        if (parts.isEmpty()) return emptyList()

        val subId = extractInt(
            extrasMap,
            listOf(
                "subscription",
                "android.telephony.extra.SUBSCRIPTION_INDEX",
                "sub_id",
                "sim_sub_id"
            )
        )
        val slot = extractInt(
            extrasMap,
            listOf(
                "slot",
                "android.telephony.extra.SLOT_INDEX",
                "simId",
                "phone"
            )
        )

        val grouped = LinkedHashMap<String, MutableList<ParsedSmsPart>>()
        for (p in parts) {
            val key = p.sender.ifBlank { "UNKNOWN" }
            grouped.getOrPut(key) { mutableListOf() }.add(p)
        }

        return grouped.entries.map { (sender, senderParts) ->
            val combinedBody = senderParts.joinToString(separator = "") { it.body }
            val ts = senderParts.maxOf { it.timestampMillis }
            ConcatenatedSms(
                sender = sender,
                body = combinedBody,
                timestampMillis = ts,
                subscriptionId = subId?.takeIf { it >= 0 },
                simSlotIndex = slot?.takeIf { it >= 0 }
            )
        }
    }

    private fun extractInt(map: Map<String, Any?>, keys: List<String>): Int? {
        for (k in keys) {
            val v = map[k] ?: continue
            when (v) {
                is Number -> return v.toInt()
                is String -> v.toIntOrNull()?.let { return it }
            }
        }
        return null
    }
}
