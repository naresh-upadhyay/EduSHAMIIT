package com.shamiit.shamiit_sms_gateway.telephony.sim

import android.Manifest
import android.annotation.SuppressLint
import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.CellSignalStrength
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.core.content.ContextCompat
import com.shamiit.shamiit_sms_gateway.storage.SmsGatewayDatabaseHelper
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * Real Android SIM discovery & subscription observer backed by SubscriptionManager & TelephonyManager.
 */
class SimManager(private val context: Context) {

    private val dbHelper = SmsGatewayDatabaseHelper.getInstance(context)
    private var changeListener: SubscriptionManager.OnSubscriptionsChangedListener? = null

    fun hasReadPhoneState(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun hasReadPhoneNumbers(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_PHONE_NUMBERS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            hasReadPhoneState()
        }
    }

    @SuppressLint("MissingPermission", "HardwareIds")
    fun discoverSims(): List<SimSubscriptionInfo> {
        if (!hasReadPhoneState()) {
            return emptyList()
        }

        val subManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            ?: return emptyList()
        val baseTelephony = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager

        val activeList: List<SubscriptionInfo> = try {
            subManager.activeSubscriptionInfoList ?: emptyList()
        } catch (_: SecurityException) {
            emptyList()
        } catch (_: Exception) {
            emptyList()
        }

        val existingUsageMap = dbHelper.getSims().associate {
            ((it["subscription_id"] as? Number)?.toInt() ?: -1) to it
        }

        val discovered = mutableListOf<SimSubscriptionInfo>()
        for (info in activeList) {
            val subId = info.subscriptionId
            val slot = info.simSlotIndex
            val tm = try {
                baseTelephony?.createForSubscriptionId(subId)
            } catch (_: Exception) {
                baseTelephony
            }

            val carrier = info.carrierName?.toString()?.takeIf { it.isNotBlank() }
                ?: tm?.networkOperatorName?.takeIf { it.isNotBlank() }
                ?: "Carrier ${slot + 1}"
            val display = info.displayName?.toString()?.takeIf { it.isNotBlank() } ?: carrier
            val countryIso = info.countryIso ?: tm?.simCountryIso ?: ""

            val phoneNumber: String? = resolvePhoneNumberSafely(subManager, info, tm)

            val simState = mapSimState(
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && tm != null) {
                    try { tm.getSimState(slot) } catch (_: Exception) { tm.simState }
                } else {
                    tm?.simState ?: TelephonyManager.SIM_STATE_UNKNOWN
                }
            )

            val networkOperator = try { tm?.networkOperatorName ?: carrier } catch (_: Exception) { carrier }
            val networkType = resolveNetworkType(tm)
            val (dbm, level, label) = resolveSignalStrength(tm)
            val isDataEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && tm != null) {
                try { tm.isDataEnabled } catch (_: Exception) { false }
            } else false

            val existing = existingUsageMap[subId]
            val usageMode = SimUsageMode.fromString(existing?.get("usage_mode") as? String)
            val sentCount = (existing?.get("sent_count") as? Number)?.toInt() ?: 0
            val receivedCount = (existing?.get("received_count") as? Number)?.toInt() ?: 0
            val failedCount = (existing?.get("failed_count") as? Number)?.toInt() ?: 0

            discovered.add(
                SimSubscriptionInfo(
                    subscriptionId = subId,
                    simSlotIndex = slot,
                    carrierName = carrier,
                    displayName = display,
                    countryIso = countryIso.uppercase(Locale.US),
                    phoneNumber = phoneNumber,
                    simState = simState,
                    networkOperator = networkOperator,
                    networkType = networkType,
                    signalStrengthDbm = dbm,
                    signalLevel = level,
                    signalLabel = label,
                    isActive = simState == "READY" || simState == "LOADED",
                    isDataEnabled = isDataEnabled,
                    usageMode = usageMode,
                    balanceInfo = "Not Available",
                    validityInfo = "Not Available",
                    sentCount = sentCount,
                    receivedCount = receivedCount,
                    failedCount = failedCount
                )
            )
        }

        persistAndRevalidate(discovered)
        return discovered.sortedBy { it.simSlotIndex }
    }

    @SuppressLint("MissingPermission", "HardwareIds")
    private fun resolvePhoneNumberSafely(
        subManager: SubscriptionManager,
        info: SubscriptionInfo,
        tm: TelephonyManager?
    ): String? {
        if (!hasReadPhoneNumbers() && !hasReadPhoneState()) return null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val n = subManager.getPhoneNumber(info.subscriptionId)
                if (!n.isNullOrBlank()) return n
            }
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        }
        try {
            @Suppress("DEPRECATION")
            val n = info.number
            if (!n.isNullOrBlank()) return n
        } catch (_: Exception) {
        }
        try {
            @Suppress("DEPRECATION")
            val n = tm?.line1Number
            if (!n.isNullOrBlank()) return n
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        }
        return null
    }

    private fun mapSimState(state: Int): String = when (state) {
        TelephonyManager.SIM_STATE_READY -> "READY"
        TelephonyManager.SIM_STATE_ABSENT -> "ABSENT"
        TelephonyManager.SIM_STATE_PIN_REQUIRED -> "PIN_REQUIRED"
        TelephonyManager.SIM_STATE_PUK_REQUIRED -> "PUK_REQUIRED"
        TelephonyManager.SIM_STATE_NETWORK_LOCKED -> "NETWORK_LOCKED"
        TelephonyManager.SIM_STATE_NOT_READY -> "NOT_READY"
        TelephonyManager.SIM_STATE_PERM_DISABLED -> "PERM_DISABLED"
        TelephonyManager.SIM_STATE_CARD_IO_ERROR -> "CARD_IO_ERROR"
        else -> "UNKNOWN"
    }

    @SuppressLint("MissingPermission")
    private fun resolveNetworkType(tm: TelephonyManager?): String {
        if (tm == null || !hasReadPhoneState()) return "Unknown"
        val type = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) tm.dataNetworkType else @Suppress("DEPRECATION") tm.networkType
        } catch (_: Exception) {
            TelephonyManager.NETWORK_TYPE_UNKNOWN
        }
        return when (type) {
            TelephonyManager.NETWORK_TYPE_NR -> "5G NR"
            TelephonyManager.NETWORK_TYPE_LTE -> "4G LTE"
            TelephonyManager.NETWORK_TYPE_HSPAP,
            TelephonyManager.NETWORK_TYPE_HSPA,
            TelephonyManager.NETWORK_TYPE_HSDPA,
            TelephonyManager.NETWORK_TYPE_HSUPA,
            TelephonyManager.NETWORK_TYPE_UMTS -> "3G"
            TelephonyManager.NETWORK_TYPE_EDGE,
            TelephonyManager.NETWORK_TYPE_GPRS,
            TelephonyManager.NETWORK_TYPE_GSM -> "2G"
            else -> "Mobile Network"
        }
    }

    private fun resolveSignalStrength(tm: TelephonyManager?): Triple<Int?, Int, String> {
        if (tm == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return Triple(null, 3, "Good")
        }
        return try {
            val ss = tm.signalStrength ?: return Triple(null, 0, "Unavailable")
            val level = ss.level.coerceIn(0, 4)
            var dbm: Int? = null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val cellStrengths: List<CellSignalStrength> = ss.cellSignalStrengths
                if (cellStrengths.isNotEmpty()) {
                    dbm = cellStrengths.first().dbm
                }
            }
            val label = when (level) {
                4 -> "Excellent"
                3 -> "Good"
                2 -> "Fair"
                1 -> "Poor"
                else -> "No Signal"
            }
            Triple(dbm, level, label)
        } catch (_: Exception) {
            Triple(null, 0, "Unknown")
        }
    }

    private fun persistAndRevalidate(sims: List<SimSubscriptionInfo>) {
        val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }.format(Date())

        val cvs = sims.map { sim ->
            ContentValues().apply {
                put("subscription_id", sim.subscriptionId)
                put("sim_slot_index", sim.simSlotIndex)
                put("carrier_name", sim.carrierName)
                put("display_name", sim.displayName)
                put("country_iso", sim.countryIso)
                put("phone_number", sim.phoneNumber)
                put("sim_state", sim.simState)
                put("network_operator", sim.networkOperator)
                put("network_type", sim.networkType)
                if (sim.signalStrengthDbm != null) put("signal_strength_dbm", sim.signalStrengthDbm)
                put("signal_level", sim.signalLevel)
                put("signal_label", sim.signalLabel)
                put("is_active", if (sim.isActive) 1 else 0)
                put("is_data_enabled", if (sim.isDataEnabled) 1 else 0)
                put("balance_info", sim.balanceInfo)
                put("validity_info", sim.validityInfo)
                put("updated_at", nowIso)
            }
        }
        dbHelper.upsertSims(cvs, sims.map { it.subscriptionId })

        val settings = dbHelper.getSettings()
        val prefSub = (settings["preferred_subscription_id"] as? Number)?.toInt()
        val secSub = (settings["secondary_subscription_id"] as? Number)?.toInt()
        val autoFallback = ((settings["auto_fallback_enabled"] as? Number)?.toInt() ?: 0) == 1

        val (newPref, newSec, conflict) = SimSelectionResolver.revalidateConfiguration(
            observedSims = sims,
            preferredSubscriptionId = prefSub,
            secondarySubscriptionId = secSub,
            autoFallbackEnabled = autoFallback
        )
        if (conflict != null) {
            val upd = ContentValues().apply {
                if (newPref != null) put("preferred_subscription_id", newPref) else putNull("preferred_subscription_id")
                if (newSec != null) put("secondary_subscription_id", newSec) else putNull("secondary_subscription_id")
            }
            dbHelper.updateSettings(upd)
            dbHelper.insertEvent(
                eventUuid = "sim-chg-${System.currentTimeMillis()}",
                messageUuid = null,
                eventType = "SIM_CHANGED",
                title = "SIM Hardware Changed",
                description = conflict,
                simSlot = null,
                subscriptionId = newPref,
                applicationSource = "TelephonyEngine",
                payloadJson = "{}",
                eventTimestamp = nowIso
            )
        }
    }

    fun registerSubscriptionListener(onChanged: (List<SimSubscriptionInfo>) -> Unit) {
        if (!hasReadPhoneState()) return
        val subManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager ?: return
        unregisterSubscriptionListener()
        val listener = object : SubscriptionManager.OnSubscriptionsChangedListener() {
            override fun onSubscriptionsChanged() {
                val updated = discoverSims()
                onChanged(updated)
            }
        }
        changeListener = listener
        try {
            subManager.addOnSubscriptionsChangedListener(listener)
        } catch (_: Exception) {}
    }

    fun unregisterSubscriptionListener() {
        val subManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager ?: return
        changeListener?.let {
            try {
                subManager.removeOnSubscriptionsChangedListener(it)
            } catch (_: Exception) {}
        }
        changeListener = null
    }
}
