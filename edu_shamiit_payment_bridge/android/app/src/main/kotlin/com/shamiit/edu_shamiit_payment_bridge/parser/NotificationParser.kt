package com.shamiit.edu_shamiit_payment_bridge.parser

import com.shamiit.edu_shamiit_payment_bridge.model.PaymentNotificationEvent

interface NotificationParser {
    val supportedPackage: String
    val appDisplayName: String
    val version: String

    fun canHandle(packageName: String): Boolean {
        return packageName.equals(supportedPackage, ignoreCase = true)
    }

    fun parse(
        packageName: String,
        title: String?,
        text: String?,
        postTime: Long
    ): PaymentNotificationEvent
}
