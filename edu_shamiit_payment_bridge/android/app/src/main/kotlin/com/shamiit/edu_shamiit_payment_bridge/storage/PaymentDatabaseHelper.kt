package com.shamiit.edu_shamiit_payment_bridge.storage

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.shamiit.edu_shamiit_payment_bridge.model.PaymentNotificationEvent

class PaymentDatabaseHelper(context: Context) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME = "edushamiit_payment_bridge.db"
        const val DATABASE_VERSION = 1
        const val TABLE_EVENTS = "payment_events"
        const val TABLE_RAW_NOTIFICATIONS = "raw_notifications"

        const val COL_UUID = "event_uuid"
        const val COL_PACKAGE = "source_package"
        const val COL_APP = "source_app"
        const val COL_EVENT_TYPE = "event_type"
        const val COL_AMOUNT_PAISE = "amount_paise"
        const val COL_SENDER_NAME = "sender_name"
        const val COL_MASKED_SENDER = "masked_sender_identifier"
        const val COL_REF = "transaction_reference"
        const val COL_TIMESTAMP = "notification_timestamp"
        const val COL_RAW_TITLE = "raw_title"
        const val COL_RAW_TEXT = "raw_text"
        const val COL_PARSER_VERSION = "parser_version"
        const val COL_CONFIDENCE = "confidence_score"
        const val COL_STATUS = "parsing_status"
        const val COL_IS_SYNCED = "is_synced"
        const val COL_RETRY_COUNT = "retry_count"
        const val COL_CREATED_AT = "created_at"

        // Raw notification table columns
        const val COL_RAW_ID = "id"
        const val COL_RAW_PKG = "package_name"
        const val COL_RAW_APP_NAME = "app_name"
        const val COL_NOTIF_TITLE = "title"
        const val COL_NOTIF_CONTENT = "content"
        const val COL_RAW_POST_TIME = "post_time"
        const val COL_RAW_PARSED_STATUS = "parsed_status"
        const val COL_RAW_AMOUNT_PAISE = "amount_paise"
        const val COL_RAW_SENDER = "sender_name"
        const val COL_RAW_REF = "reference"
        const val COL_RAW_BANK = "bank_name"
        const val COL_RAW_CREATED_AT = "created_at"

        @Volatile
        private var instance: PaymentDatabaseHelper? = null

        fun getInstance(context: Context): PaymentDatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: PaymentDatabaseHelper(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE_EVENTS (
                $COL_UUID TEXT PRIMARY KEY,
                $COL_PACKAGE TEXT NOT NULL,
                $COL_APP TEXT NOT NULL,
                $COL_EVENT_TYPE TEXT NOT NULL,
                $COL_AMOUNT_PAISE INTEGER NOT NULL,
                $COL_SENDER_NAME TEXT,
                $COL_MASKED_SENDER TEXT,
                $COL_REF TEXT,
                $COL_TIMESTAMP TEXT NOT NULL,
                $COL_RAW_TITLE TEXT,
                $COL_RAW_TEXT TEXT,
                $COL_PARSER_VERSION TEXT,
                $COL_CONFIDENCE TEXT,
                $COL_STATUS TEXT,
                $COL_IS_SYNCED INTEGER DEFAULT 0,
                $COL_RETRY_COUNT INTEGER DEFAULT 0,
                $COL_CREATED_AT INTEGER DEFAULT (strftime('%s', 'now'))
            )
            """
        )
        db.execSQL("CREATE INDEX idx_events_synced ON $TABLE_EVENTS ($COL_IS_SYNCED)")
        db.execSQL("CREATE INDEX idx_events_ref ON $TABLE_EVENTS ($COL_REF)")

        createRawTable(db)
    }

    private fun createRawTable(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TABLE_RAW_NOTIFICATIONS (
                $COL_RAW_ID TEXT PRIMARY KEY,
                $COL_RAW_PKG TEXT NOT NULL,
                $COL_RAW_APP_NAME TEXT NOT NULL,
                $COL_NOTIF_TITLE TEXT,
                $COL_NOTIF_CONTENT TEXT,
                $COL_RAW_POST_TIME INTEGER NOT NULL,
                $COL_RAW_PARSED_STATUS TEXT NOT NULL,
                $COL_RAW_AMOUNT_PAISE INTEGER DEFAULT 0,
                $COL_RAW_SENDER TEXT,
                $COL_RAW_REF TEXT,
                $COL_RAW_BANK TEXT,
                $COL_RAW_CREATED_AT INTEGER DEFAULT (strftime('%s', 'now'))
            )
            """
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_raw_notif_time ON $TABLE_RAW_NOTIFICATIONS ($COL_RAW_CREATED_AT DESC)")
    }

    override fun onOpen(db: SQLiteDatabase) {
        super.onOpen(db)
        createRawTable(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        createRawTable(db)
    }

    fun insertEvent(event: PaymentNotificationEvent): Boolean {
        val db = writableDatabase
        val cv = ContentValues().apply {
            put(COL_UUID, event.eventUuid)
            put(COL_PACKAGE, event.sourcePackage)
            put(COL_APP, event.sourceApp)
            put(COL_EVENT_TYPE, event.eventType)
            put(COL_AMOUNT_PAISE, event.amountPaise)
            put(COL_SENDER_NAME, event.senderName)
            put(COL_MASKED_SENDER, event.maskedSenderIdentifier)
            put(COL_REF, event.transactionReference)
            put(COL_TIMESTAMP, event.notificationTimestamp)
            put(COL_RAW_TITLE, event.rawTitle)
            put(COL_RAW_TEXT, event.rawText)
            put(COL_PARSER_VERSION, event.parserVersion)
            put(COL_CONFIDENCE, event.confidenceScore)
            put(COL_STATUS, event.parsingStatus)
            put(COL_IS_SYNCED, if (event.isSynced) 1 else 0)
            put(COL_RETRY_COUNT, event.retryCount)
        }
        val result = db.insertWithOnConflict(TABLE_EVENTS, null, cv, SQLiteDatabase.CONFLICT_IGNORE)
        return result != -1L
    }

    fun isDuplicate(amountPaise: Long, reference: String?, windowMinutes: Int): Boolean {
        if (amountPaise <= 0) return false
        val db = readableDatabase
        val timeThreshold = (System.currentTimeMillis() / 1000) - (windowMinutes * 60)

        val cursor = if (!reference.isNullOrBlank()) {
            db.rawQuery(
                "SELECT 1 FROM $TABLE_EVENTS WHERE $COL_REF = ? AND $COL_AMOUNT_PAISE = ? AND $COL_CREATED_AT >= ?",
                arrayOf(reference, amountPaise.toString(), timeThreshold.toString())
            )
        } else {
            // When reference is not yet parsed, use a strict 30-second window to prevent
            // blocking distinct students paying the same tuition fee simultaneously at the counter!
            val shortThreshold = (System.currentTimeMillis() / 1000) - 30
            db.rawQuery(
                "SELECT 1 FROM $TABLE_EVENTS WHERE $COL_AMOUNT_PAISE = ? AND $COL_CREATED_AT >= ?",
                arrayOf(amountPaise.toString(), shortThreshold.toString())
            )
        }

        val hasDup = cursor.count > 0
        cursor.close()
        return hasDup
    }

    /**
     * Periodically prunes synced events older than [olderThanDays] days to keep local SQLite storage lean.
     */
    fun pruneOldSyncedEvents(olderThanDays: Int = 60) {
        try {
            val db = writableDatabase
            val threshold = (System.currentTimeMillis() / 1000) - (olderThanDays * 86400L)
            db.delete(TABLE_EVENTS, "$COL_IS_SYNCED = 1 AND $COL_CREATED_AT < ?", arrayOf(threshold.toString()))
        } catch (_: Exception) {}
    }

    fun getPendingEvents(limit: Int = 50): List<PaymentNotificationEvent> {
        val db = readableDatabase
        val list = mutableListOf<PaymentNotificationEvent>()
        val cursor = db.rawQuery(
            "SELECT * FROM $TABLE_EVENTS WHERE $COL_IS_SYNCED = 0 ORDER BY $COL_CREATED_AT ASC LIMIT ?",
            arrayOf(limit.toString())
        )
        while (cursor.moveToNext()) {
            list.add(
                PaymentNotificationEvent(
                    eventUuid = cursor.getString(cursor.getColumnIndexOrThrow(COL_UUID)),
                    sourcePackage = cursor.getString(cursor.getColumnIndexOrThrow(COL_PACKAGE)),
                    sourceApp = cursor.getString(cursor.getColumnIndexOrThrow(COL_APP)),
                    eventType = cursor.getString(cursor.getColumnIndexOrThrow(COL_EVENT_TYPE)),
                    amountPaise = cursor.getLong(cursor.getColumnIndexOrThrow(COL_AMOUNT_PAISE)),
                    senderName = cursor.getString(cursor.getColumnIndexOrThrow(COL_SENDER_NAME)),
                    maskedSenderIdentifier = cursor.getString(cursor.getColumnIndexOrThrow(COL_MASKED_SENDER)),
                    transactionReference = cursor.getString(cursor.getColumnIndexOrThrow(COL_REF)),
                    notificationTimestamp = cursor.getString(cursor.getColumnIndexOrThrow(COL_TIMESTAMP)),
                    rawTitle = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_TITLE)),
                    rawText = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_TEXT)),
                    parserVersion = cursor.getString(cursor.getColumnIndexOrThrow(COL_PARSER_VERSION)),
                    confidenceScore = cursor.getString(cursor.getColumnIndexOrThrow(COL_CONFIDENCE)),
                    parsingStatus = cursor.getString(cursor.getColumnIndexOrThrow(COL_STATUS)),
                    isSynced = cursor.getInt(cursor.getColumnIndexOrThrow(COL_IS_SYNCED)) == 1,
                    retryCount = cursor.getInt(cursor.getColumnIndexOrThrow(COL_RETRY_COUNT))
                )
            )
        }
        cursor.close()
        return list
    }

    fun getAllEvents(limit: Int = 100): List<PaymentNotificationEvent> {
        val db = readableDatabase
        val list = mutableListOf<PaymentNotificationEvent>()
        val cursor = db.rawQuery(
            "SELECT * FROM $TABLE_EVENTS ORDER BY $COL_CREATED_AT DESC LIMIT ?",
            arrayOf(limit.toString())
        )
        while (cursor.moveToNext()) {
            list.add(
                PaymentNotificationEvent(
                    eventUuid = cursor.getString(cursor.getColumnIndexOrThrow(COL_UUID)),
                    sourcePackage = cursor.getString(cursor.getColumnIndexOrThrow(COL_PACKAGE)),
                    sourceApp = cursor.getString(cursor.getColumnIndexOrThrow(COL_APP)),
                    eventType = cursor.getString(cursor.getColumnIndexOrThrow(COL_EVENT_TYPE)),
                    amountPaise = cursor.getLong(cursor.getColumnIndexOrThrow(COL_AMOUNT_PAISE)),
                    senderName = cursor.getString(cursor.getColumnIndexOrThrow(COL_SENDER_NAME)),
                    maskedSenderIdentifier = cursor.getString(cursor.getColumnIndexOrThrow(COL_MASKED_SENDER)),
                    transactionReference = cursor.getString(cursor.getColumnIndexOrThrow(COL_REF)),
                    notificationTimestamp = cursor.getString(cursor.getColumnIndexOrThrow(COL_TIMESTAMP)),
                    rawTitle = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_TITLE)),
                    rawText = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_TEXT)),
                    parserVersion = cursor.getString(cursor.getColumnIndexOrThrow(COL_PARSER_VERSION)),
                    confidenceScore = cursor.getString(cursor.getColumnIndexOrThrow(COL_CONFIDENCE)),
                    parsingStatus = cursor.getString(cursor.getColumnIndexOrThrow(COL_STATUS)),
                    isSynced = cursor.getInt(cursor.getColumnIndexOrThrow(COL_IS_SYNCED)) == 1,
                    retryCount = cursor.getInt(cursor.getColumnIndexOrThrow(COL_RETRY_COUNT))
                )
            )
        }
        cursor.close()
        return list
    }

    fun markEventsAsSynced(uuids: List<String>) {
        if (uuids.isEmpty()) return
        val db = writableDatabase
        db.beginTransaction()
        try {
            val cv = ContentValues().apply { put(COL_IS_SYNCED, 1) }
            for (uuid in uuids) {
                db.update(TABLE_EVENTS, cv, "$COL_UUID = ?", arrayOf(uuid))
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun getPendingQueueCount(): Int {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT count(*) FROM $TABLE_EVENTS WHERE $COL_IS_SYNCED = 0", null)
        var count = 0
        if (cursor.moveToFirst()) {
            count = cursor.getInt(0)
        }
        cursor.close()
        return count
    }

    fun getTotalEventsCount(): Int {
        val db = readableDatabase
        val cursor = db.rawQuery("SELECT count(*) FROM $TABLE_EVENTS", null)
        var count = 0
        if (cursor.moveToFirst()) {
            count = cursor.getInt(0)
        }
        cursor.close()
        return count
    }

    // ==========================================
    // RAW NOTIFICATIONS LOGGING & QUERYING
    // ==========================================

    fun insertRawNotification(
        id: String,
        packageName: String,
        appName: String,
        title: String?,
        content: String?,
        postTime: Long,
        parsedStatus: String,
        amountPaise: Long = 0,
        senderName: String? = null,
        reference: String? = null,
        bankName: String? = null
    ): Boolean {
        return try {
            val db = writableDatabase
            createRawTable(db)
            val cv = ContentValues().apply {
                put(COL_RAW_ID, id)
                put(COL_RAW_PKG, packageName)
                put(COL_RAW_APP_NAME, appName)
                put(COL_NOTIF_TITLE, title)
                put(COL_NOTIF_CONTENT, content)
                put(COL_RAW_POST_TIME, postTime)
                put(COL_RAW_PARSED_STATUS, parsedStatus)
                put(COL_RAW_AMOUNT_PAISE, amountPaise)
                put(COL_RAW_SENDER, senderName)
                put(COL_RAW_REF, reference)
                put(COL_RAW_BANK, bankName)
            }
            db.insertWithOnConflict(TABLE_RAW_NOTIFICATIONS, null, cv, SQLiteDatabase.CONFLICT_REPLACE) != -1L
        } catch (e: Exception) {
            false
        }
    }

    fun updateRawNotificationStatus(
        id: String,
        parsedStatus: String,
        amountPaise: Long,
        senderName: String?,
        reference: String?,
        bankName: String?
    ): Boolean {
        return try {
            val db = writableDatabase
            val cv = ContentValues().apply {
                put(COL_RAW_PARSED_STATUS, parsedStatus)
                put(COL_RAW_AMOUNT_PAISE, amountPaise)
                put(COL_RAW_SENDER, senderName)
                put(COL_RAW_REF, reference)
                put(COL_RAW_BANK, bankName)
            }
            db.update(TABLE_RAW_NOTIFICATIONS, cv, "$COL_RAW_ID = ?", arrayOf(id)) > 0
        } catch (e: Exception) {
            false
        }
    }

    fun getRawNotifications(limit: Int = 100): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        try {
            val db = readableDatabase
            createRawTable(db)
            val cursor = db.rawQuery(
                "SELECT * FROM $TABLE_RAW_NOTIFICATIONS ORDER BY $COL_RAW_CREATED_AT DESC, $COL_RAW_POST_TIME DESC LIMIT ?",
                arrayOf(limit.toString())
            )
            while (cursor.moveToNext()) {
                val map = mutableMapOf<String, Any?>()
                val id = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_ID))
                val pkg = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_PKG))
                val app = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_APP_NAME))
                val notifTitle = cursor.getString(cursor.getColumnIndexOrThrow(COL_NOTIF_TITLE)) ?: ""
                val notifContent = cursor.getString(cursor.getColumnIndexOrThrow(COL_NOTIF_CONTENT)) ?: ""
                val postTime = cursor.getLong(cursor.getColumnIndexOrThrow(COL_RAW_POST_TIME))
                val parsedStatus = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_PARSED_STATUS))
                val amountPaise = cursor.getLong(cursor.getColumnIndexOrThrow(COL_RAW_AMOUNT_PAISE))
                val senderName = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_SENDER))
                val ref = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_REF))
                val bank = cursor.getString(cursor.getColumnIndexOrThrow(COL_RAW_BANK))
                val createdAt = cursor.getLong(cursor.getColumnIndexOrThrow(COL_RAW_CREATED_AT))

                map["id"] = id
                map["package_name"] = pkg
                map["app_name"] = app
                map["title"] = notifTitle
                map["content"] = notifContent
                map["text"] = notifContent
                map["body"] = notifContent
                map["raw_text"] = notifContent
                map["post_time"] = postTime
                map["parsed_status"] = parsedStatus
                map["amount_paise"] = amountPaise
                map["sender_name"] = senderName
                map["reference"] = ref
                map["bank_name"] = bank
                map["created_at"] = createdAt
                list.add(map)
            }
            cursor.close()
        } catch (e: Exception) {}
        return list
    }

    fun clearRawNotifications(): Boolean {
        return try {
            val db = writableDatabase
            db.delete(TABLE_RAW_NOTIFICATIONS, null, null) >= 0
        } catch (e: Exception) {
            false
        }
    }
}
