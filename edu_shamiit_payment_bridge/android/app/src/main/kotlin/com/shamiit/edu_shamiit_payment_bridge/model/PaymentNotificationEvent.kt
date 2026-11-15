package com.shamiit.edu_shamiit_payment_bridge.model

/**
 * Normalized payment notification event model.
 * Financial quantities are stored as integer paise (e.g. 200034 = Rs 2000.34).
 */
data class PaymentNotificationEvent(
    val eventUuid: String,
    val sourcePackage: String,
    val sourceApp: String,
    val eventType: String, // PAYMENT_RECEIVED, PAYMENT_SENT, UNKNOWN
    val amountPaise: Long,
    val senderName: String?,
    val maskedSenderIdentifier: String?,
    val transactionReference: String?,
    val notificationTimestamp: String,
    val rawTitle: String?,
    val rawText: String?,
    val parserVersion: String = "1.0.0",
    val confidenceScore: String = "HIGH", // HIGH, MEDIUM, LOW, UNPARSED
    val parsingStatus: String = "PARSED",
    val isSynced: Boolean = false,
    val retryCount: Int = 0
)
