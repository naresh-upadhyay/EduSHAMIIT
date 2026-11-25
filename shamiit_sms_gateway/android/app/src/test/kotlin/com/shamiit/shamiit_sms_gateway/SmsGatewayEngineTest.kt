package com.shamiit.shamiit_sms_gateway

import android.app.Activity
import android.telephony.SmsManager
import com.shamiit.shamiit_sms_gateway.telephony.delivery.SmsDeliveryStateMachine
import com.shamiit.shamiit_sms_gateway.telephony.receiver.ParsedSmsPart
import com.shamiit.shamiit_sms_gateway.telephony.receiver.SmsPduParser
import com.shamiit.shamiit_sms_gateway.telephony.sender.SmsValidator
import com.shamiit.shamiit_sms_gateway.telephony.sim.PreferredSimMode
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimSelectionResolver
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimSubscriptionInfo
import com.shamiit.shamiit_sms_gateway.telephony.sim.SimUsageMode
import org.junit.Assert.*
import org.junit.Test

class SmsGatewayEngineTest {

    private fun makeSim(
        subId: Int,
        slot: Int,
        carrier: String,
        active: Boolean = true,
        mode: SimUsageMode = SimUsageMode.SEND_RECEIVE
    ) = SimSubscriptionInfo(
        subscriptionId = subId,
        simSlotIndex = slot,
        carrierName = carrier,
        displayName = carrier,
        countryIso = "IN",
        phoneNumber = if (slot == 0) "+919876543210" else null,
        simState = if (active) "READY" else "ABSENT",
        networkOperator = carrier,
        networkType = "4G LTE",
        signalStrengthDbm = -75,
        signalLevel = 4,
        signalLabel = "Excellent",
        isActive = active,
        isDataEnabled = true,
        usageMode = mode
    )

    @Test
    fun `SIM selection uses real subscription IDs and respects Receive Only restriction`() {
        val sim1 = makeSim(subId = 14, slot = 0, carrier = "Jio", mode = SimUsageMode.RECEIVE_ONLY)
        val sim2 = makeSim(subId = 29, slot = 1, carrier = "Airtel", mode = SimUsageMode.SEND_RECEIVE)

        // Explicit selection of Receive Only SIM must fail
        val blocked = SimSelectionResolver.resolveForSending(
            availableSims = listOf(sim1, sim2),
            explicitSubscriptionId = 14,
            preferredMode = PreferredSimMode.SIM_1,
            preferredSubscriptionId = 14,
            secondarySubscriptionId = 29,
            autoFallbackEnabled = false,
            switchWhenUnavailable = true
        )
        assertNull(blocked.selectedSim)
        assertNotNull(blocked.errorReason)

        // Explicit selection of SIM 2 (subId = 29) succeeds with real subId
        val ok = SimSelectionResolver.resolveForSending(
            availableSims = listOf(sim1, sim2),
            explicitSubscriptionId = 29,
            preferredMode = PreferredSimMode.SIM_2,
            preferredSubscriptionId = 29,
            secondarySubscriptionId = null,
            autoFallbackEnabled = false,
            switchWhenUnavailable = true
        )
        assertEquals(29, ok.selectedSim?.subscriptionId)
        assertFalse(ok.usedFallback)
    }

    @Test
    fun `No silent SIM switch when preferred SIM unavailable and fallback disabled`() {
        val sim1Removed = makeSim(subId = 14, slot = 0, carrier = "Jio", active = false)
        val sim2 = makeSim(subId = 29, slot = 1, carrier = "Airtel", active = true)

        val noFallback = SimSelectionResolver.resolveForSending(
            availableSims = listOf(sim1Removed, sim2),
            explicitSubscriptionId = null,
            preferredMode = PreferredSimMode.SIM_1,
            preferredSubscriptionId = 14,
            secondarySubscriptionId = 29,
            autoFallbackEnabled = false,
            switchWhenUnavailable = true
        )
        assertNull(noFallback.selectedSim)
        assertTrue(noFallback.errorReason!!.contains("disabled"))

        val withFallback = SimSelectionResolver.resolveForSending(
            availableSims = listOf(sim1Removed, sim2),
            explicitSubscriptionId = null,
            preferredMode = PreferredSimMode.SIM_1,
            preferredSubscriptionId = 14,
            secondarySubscriptionId = 29,
            autoFallbackEnabled = true,
            switchWhenUnavailable = true
        )
        assertEquals(29, withFallback.selectedSim?.subscriptionId)
        assertTrue(withFallback.usedFallback)
    }

    @Test
    fun `SIM removal and replacement clears or fails over invalid subscription ID`() {
        val newSim1 = makeSim(subId = 41, slot = 0, carrier = "Vi")
        val sim2 = makeSim(subId = 29, slot = 1, carrier = "Airtel")

        // Preferred sub 14 was replaced by 41, fallback disabled -> clears preferred
        val (prefCleared, _, conflict1) = SimSelectionResolver.revalidateConfiguration(
            observedSims = listOf(newSim1, sim2),
            preferredSubscriptionId = 14,
            secondarySubscriptionId = 29,
            autoFallbackEnabled = false
        )
        assertNull(prefCleared)
        assertNotNull(conflict1)

        // Fallback enabled -> switches to secondary sub 29
        val (prefFallback, _, conflict2) = SimSelectionResolver.revalidateConfiguration(
            observedSims = listOf(newSim1, sim2),
            preferredSubscriptionId = 14,
            secondarySubscriptionId = 29,
            autoFallbackEnabled = true
        )
        assertEquals(29, prefFallback)
        assertNotNull(conflict2)
    }

    @Test
    fun `Phone number validation handles Indian and international E164 formats`() {
        assertEquals("+919876543210", SmsValidator.normalizePhoneNumber("9876543210"))
        assertEquals("+919876543210", SmsValidator.normalizePhoneNumber("09876543210"))
        assertEquals("+919876543210", SmsValidator.normalizePhoneNumber("+91 98765-43210"))
        assertEquals("+14155552671", SmsValidator.normalizePhoneNumber("+14155552671"))
        assertFalse(SmsValidator.isValidPhoneNumber("12345"))
        assertFalse(SmsValidator.isValidPhoneNumber("abc"))
    }

    @Test
    fun `GSM7 and Unicode UCS2 segment estimation calculates limits accurately`() {
        val gsmSingle = SmsValidator.analyzeEncoding("A".repeat(160))
        assertEquals("GSM7", gsmSingle.encoding)
        assertEquals(1, gsmSingle.segmentCount)
        assertEquals(160, gsmSingle.perSegmentLimit)

        val gsmMulti = SmsValidator.analyzeEncoding("A".repeat(161))
        assertEquals("GSM7", gsmMulti.encoding)
        assertEquals(2, gsmMulti.segmentCount)
        assertEquals(153, gsmMulti.perSegmentLimit)

        // Extended GSM-7 char (€) counts as 2 septets
        val gsmEuro = SmsValidator.analyzeEncoding("€".repeat(81))
        assertEquals("GSM7", gsmEuro.encoding)
        assertEquals(162, gsmEuro.characterCount)
        assertEquals(2, gsmEuro.segmentCount)

        // Hindi / emoji triggers UNICODE (70 / 67)
        val uniSingle = SmsValidator.analyzeEncoding("नमस्ते छात्र")
        assertEquals("UNICODE", uniSingle.encoding)
        assertEquals(1, uniSingle.segmentCount)
        assertEquals(70, uniSingle.perSegmentLimit)

        val uniMulti = SmsValidator.analyzeEncoding("नमस्ते ".repeat(15))
        assertEquals("UNICODE", uniMulti.encoding)
        assertTrue(uniMulti.segmentCount >= 2)
        assertEquals(67, uniMulti.perSegmentLimit)
    }

    @Test
    fun `Template variable substitution rejects unresolved required variables`() {
        val body = "Dear {parent_name}, fee of {amount} is due on {due_date}."
        val rendered = SmsValidator.renderTemplateStrict(
            body,
            mapOf("parent_name" to "Rajesh", "amount" to "5000", "due_date" to "30 Nov 2026")
        )
        assertEquals("Dear Rajesh, fee of 5000 is due on 30 Nov 2026.", rendered)

        try {
            SmsValidator.renderTemplateStrict(body, mapOf("parent_name" to "Rajesh"))
            fail("Expected IllegalArgumentException for missing variables")
        } catch (e: IllegalArgumentException) {
            assertTrue(e.message!!.contains("amount"))
        }
    }

    @Test
    fun `Incoming SMS multi-PDU parser concatenates body and extracts subscription metadata`() {
        val merged = SmsPduParser.mergeParts(
            parts = listOf(
                ParsedSmsPart("+919876543210", "Hello ", 1700000001000L),
                ParsedSmsPart("+919876543210", "World!", 1700000002000L)
            ),
            extrasMap = mapOf("subscription" to 14, "slot" to 0)
        )
        assertEquals(1, merged.size)
        assertEquals("Hello World!", merged[0].body)
        assertEquals(14, merged[0].subscriptionId)
        assertEquals(0, merged[0].simSlotIndex)
        assertEquals(1700000002000L, merged[0].timestampMillis)
    }

    @Test
    fun `Multipart SMS state machine distinguishes SENDING, SENT, DELIVERED and FAILED`() {
        val parts = mutableListOf<MutableMap<String, Any>>()
        val (s1, _) = SmsDeliveryStateMachine.updatePartSent(parts, 0, 2, Activity.RESULT_OK)
        assertEquals("SENDING", s1) // Part 2 still pending

        val (s2, _) = SmsDeliveryStateMachine.updatePartSent(parts, 1, 2, Activity.RESULT_OK)
        assertEquals("SENT", s2) // Sent != Delivered!

        val (d1, _) = SmsDeliveryStateMachine.updatePartDelivered(parts, 0, 2, Activity.RESULT_OK)
        assertEquals("SENT", d1) // Part 2 delivery pending

        val (d2, _) = SmsDeliveryStateMachine.updatePartDelivered(parts, 1, 2, Activity.RESULT_OK)
        assertEquals("DELIVERED", d2)

        // Failure case
        val failParts = mutableListOf<MutableMap<String, Any>>()
        val (fStatus, fReason) = SmsDeliveryStateMachine.updatePartSent(
            failParts, 0, 1, SmsManager.RESULT_ERROR_NO_SERVICE
        )
        assertEquals("FAILED", fStatus)
        assertTrue(fReason!!.contains("No cellular network service"))
    }
}
