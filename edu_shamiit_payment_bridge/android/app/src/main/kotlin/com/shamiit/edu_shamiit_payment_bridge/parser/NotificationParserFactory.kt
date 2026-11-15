package com.shamiit.edu_shamiit_payment_bridge.parser

class NotificationParserFactory {
    private val parsers: List<NotificationParser> = listOf(
        PhonePeNotificationParser(),
        GooglePayNotificationParser(),
        PaytmNotificationParser(),
        BhimNotificationParser(),
        GenericUpiNotificationParser()
    )

    fun getParser(packageName: String): NotificationParser {
        return parsers.firstOrNull { it.canHandle(packageName) } ?: parsers.last()
    }
}
