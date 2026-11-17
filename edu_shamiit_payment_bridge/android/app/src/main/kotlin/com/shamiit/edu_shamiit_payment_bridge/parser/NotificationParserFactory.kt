package com.shamiit.edu_shamiit_payment_bridge.parser

import android.content.Context

class NotificationParserFactory(private val context: Context? = null) {
    private val parsers: List<NotificationParser> = listOf(
        PhonePeNotificationParser(context),
        GooglePayNotificationParser(context),
        PaytmNotificationParser(context),
        BhimNotificationParser(context),
        GenericUpiNotificationParser(context)
    )

    fun getParser(packageName: String): NotificationParser {
        return parsers.firstOrNull { it.canHandle(packageName) } ?: parsers.last()
    }
}

