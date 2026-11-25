package com.shamiit.shamiit_sms_gateway.telephony.sim

enum class SimUsageMode(val value: String) {
    SEND_RECEIVE("SEND_RECEIVE"),
    SEND_ONLY("SEND_ONLY"),
    RECEIVE_ONLY("RECEIVE_ONLY");

    companion object {
        fun fromString(raw: String?): SimUsageMode {
            return entries.firstOrNull { it.value.equals(raw, ignoreCase = true) } ?: SEND_RECEIVE
        }
    }
}

enum class PreferredSimMode(val value: String) {
    SIM_1("SIM_1"),
    SIM_2("SIM_2"),
    MANUAL("MANUAL"),
    AUTO_RULE("AUTO_RULE");

    companion object {
        fun fromString(raw: String?): PreferredSimMode {
            return entries.firstOrNull { it.value.equals(raw, ignoreCase = true) } ?: SIM_1
        }
    }
}

data class SimSubscriptionInfo(
    val subscriptionId: Int,
    val simSlotIndex: Int,
    val carrierName: String,
    val displayName: String,
    val countryIso: String,
    val phoneNumber: String?,
    val simState: String,
    val networkOperator: String,
    val networkType: String,
    val signalStrengthDbm: Int?,
    val signalLevel: Int,
    val signalLabel: String,
    val isActive: Boolean,
    val isDataEnabled: Boolean,
    val usageMode: SimUsageMode = SimUsageMode.SEND_RECEIVE,
    val balanceInfo: String = "Not Available",
    val validityInfo: String = "Not Available",
    val sentCount: Int = 0,
    val receivedCount: Int = 0,
    val failedCount: Int = 0
) {
    fun canSend(): Boolean = isActive && usageMode != SimUsageMode.RECEIVE_ONLY

    fun toMap(): Map<String, Any?> = mapOf(
        "subscription_id" to subscriptionId,
        "sim_slot_index" to simSlotIndex,
        "carrier_name" to carrierName,
        "display_name" to displayName,
        "country_iso" to countryIso,
        "phone_number" to phoneNumber,
        "sim_state" to simState,
        "network_operator" to networkOperator,
        "network_type" to networkType,
        "signal_strength_dbm" to signalStrengthDbm,
        "signal_level" to signalLevel,
        "signal_label" to signalLabel,
        "is_active" to isActive,
        "is_data_enabled" to isDataEnabled,
        "usage_mode" to usageMode.value,
        "balance_info" to balanceInfo,
        "validity_info" to validityInfo,
        "sent_count" to sentCount,
        "received_count" to receivedCount,
        "failed_count" to failedCount
    )
}

data class SimSelectionResolution(
    val selectedSim: SimSubscriptionInfo?,
    val usedFallback: Boolean = false,
    val conflictMessage: String? = null,
    val errorReason: String? = null
)

/**
 * Pure Kotlin SIM selection & conflict resolver (tested on JVM without Android framework).
 */
object SimSelectionResolver {

    fun resolveForSending(
        availableSims: List<SimSubscriptionInfo>,
        explicitSubscriptionId: Int?,
        preferredMode: PreferredSimMode,
        preferredSubscriptionId: Int?,
        secondarySubscriptionId: Int?,
        autoFallbackEnabled: Boolean,
        switchWhenUnavailable: Boolean
    ): SimSelectionResolution {
        val sendable = availableSims.filter { it.canSend() }
        if (availableSims.isEmpty()) {
            return SimSelectionResolution(null, errorReason = "No active SIM cards detected on device.")
        }

        // 1. Explicit subscription ID requested (e.g. Manual Send SMS or rule-targeted sub)
        if (explicitSubscriptionId != null) {
            val match = availableSims.firstOrNull { it.subscriptionId == explicitSubscriptionId }
            if (match == null) {
                if (autoFallbackEnabled && switchWhenUnavailable && secondarySubscriptionId != null) {
                    val sec = sendable.firstOrNull { it.subscriptionId == secondarySubscriptionId }
                    if (sec != null) {
                        return SimSelectionResolution(
                            selectedSim = sec,
                            usedFallback = true,
                            conflictMessage = "Requested SIM subscription $explicitSubscriptionId unavailable; switched to fallback SIM ${sec.simSlotIndex + 1}."
                        )
                    }
                }
                return SimSelectionResolution(
                    selectedSim = null,
                    errorReason = "Requested SIM subscription $explicitSubscriptionId is not available and fallback is not permitted."
                )
            }
            if (!match.canSend()) {
                return SimSelectionResolution(
                    selectedSim = null,
                    errorReason = "SIM ${match.simSlotIndex + 1} (${match.carrierName}) cannot send (active=${match.isActive}, mode=${match.usageMode.value})."
                )
            }
            return SimSelectionResolution(selectedSim = match)
        }

        // 2. Preferred subscription ID configured
        val targetPref: SimSubscriptionInfo? = when (preferredMode) {
            PreferredSimMode.SIM_1 -> availableSims.firstOrNull { it.simSlotIndex == 0 }
                ?: availableSims.firstOrNull { it.subscriptionId == preferredSubscriptionId }
            PreferredSimMode.SIM_2 -> availableSims.firstOrNull { it.simSlotIndex == 1 }
                ?: availableSims.firstOrNull { it.subscriptionId == preferredSubscriptionId }
            PreferredSimMode.MANUAL, PreferredSimMode.AUTO_RULE ->
                availableSims.firstOrNull { it.subscriptionId == preferredSubscriptionId }
                    ?: sendable.firstOrNull()
        }

        if (targetPref != null && targetPref.canSend()) {
            return SimSelectionResolution(selectedSim = targetPref)
        }

        // 3. Preferred SIM unavailable or Receive Only: DO NOT silently switch unless fallback is explicitly enabled!
        if (autoFallbackEnabled && switchWhenUnavailable) {
            val fallback = (if (secondarySubscriptionId != null) {
                sendable.firstOrNull { it.subscriptionId == secondarySubscriptionId }
            } else null) ?: sendable.firstOrNull()

            if (fallback != null) {
                return SimSelectionResolution(
                    selectedSim = fallback,
                    usedFallback = true,
                    conflictMessage = "Preferred SIM unavailable; switched to SIM ${fallback.simSlotIndex + 1} (${fallback.carrierName})."
                )
            }
        }

        return SimSelectionResolution(
            selectedSim = null,
            errorReason = "Preferred SIM is unavailable and automatic SIM fallback is disabled."
        )
    }

    /**
     * Revalidates stored preferences against freshly observed SIM hardware (SIM removal/replacement).
     */
    fun revalidateConfiguration(
        observedSims: List<SimSubscriptionInfo>,
        preferredSubscriptionId: Int?,
        secondarySubscriptionId: Int?,
        autoFallbackEnabled: Boolean
    ): Triple<Int?, Int?, String?> {
        val activeIds = observedSims.filter { it.isActive }.map { it.subscriptionId }.toSet()
        var newPref = preferredSubscriptionId
        var newSec = secondarySubscriptionId
        var conflict: String? = null

        if (newSec != null && newSec !in activeIds) {
            newSec = null
        }

        if (newPref != null && newPref !in activeIds) {
            conflict = "Previously preferred SIM subscription ($newPref) was removed or replaced."
            if (autoFallbackEnabled && newSec != null && newSec in activeIds) {
                newPref = newSec
                conflict += " Switched to secondary SIM subscription ($newSec)."
            } else {
                newPref = null
                conflict += " Preferred SIM cleared to prevent silent routing to wrong SIM."
            }
        }
        return Triple(newPref, newSec, conflict)
    }
}
