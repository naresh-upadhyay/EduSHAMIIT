package com.shamiit.shamiit_sms_gateway.storage

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.io.File

/**
 * Local SQLite persistence for SHAMIIT SMS GATEWAY.
 * Covers all required entities:
 *  - local_sms_messages
 *  - local_sms_events
 *  - local_device
 *  - local_sims
 *  - local_automation_rules
 *  - local_message_templates
 *  - pending_uploads
 *  - pending_sms_jobs
 *  - gateway_settings
 *
 * Guarantees idempotent synchronization and never deletes pending_uploads prior to server ACK.
 */
class SmsGatewayDatabaseHelper(private val appContext: Context) :
    SQLiteOpenHelper(appContext, DATABASE_NAME, null, DATABASE_VERSION) {

    companion object {
        const val DATABASE_NAME = "shamiit_sms_gateway.db"
        const val DATABASE_VERSION = 1

        const val TBL_MESSAGES = "local_sms_messages"
        const val TBL_EVENTS = "local_sms_events"
        const val TBL_DEVICE = "local_device"
        const val TBL_SIMS = "local_sims"
        const val TBL_RULES = "local_automation_rules"
        const val TBL_TEMPLATES = "local_message_templates"
        const val TBL_PENDING_UPLOADS = "pending_uploads"
        const val TBL_PENDING_JOBS = "pending_sms_jobs"
        const val TBL_SETTINGS = "gateway_settings"

        @Volatile
        private var instance: SmsGatewayDatabaseHelper? = null

        fun getInstance(context: Context): SmsGatewayDatabaseHelper {
            return instance ?: synchronized(this) {
                instance ?: SmsGatewayDatabaseHelper(context.applicationContext).also { instance = it }
            }
        }
    }

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_MESSAGES (
                message_uuid TEXT PRIMARY KEY,
                direction TEXT NOT NULL DEFAULT 'OUTBOUND',
                sender_number TEXT,
                recipient_number TEXT NOT NULL,
                message_body TEXT NOT NULL,
                encoding TEXT NOT NULL DEFAULT 'GSM7',
                segment_count INTEGER NOT NULL DEFAULT 1,
                sending_sim_slot INTEGER,
                sending_subscription_id INTEGER,
                receiving_sim_slot INTEGER,
                receiving_subscription_id INTEGER,
                carrier_name TEXT,
                application_source TEXT NOT NULL DEFAULT 'SMS Gateway App',
                reference_id TEXT,
                priority TEXT NOT NULL DEFAULT 'NORMAL',
                status TEXT NOT NULL DEFAULT 'QUEUED',
                delivery_report_requested INTEGER NOT NULL DEFAULT 1,
                scheduled_at TEXT,
                expires_at TEXT,
                created_at TEXT NOT NULL,
                queued_at TEXT,
                submitted_at TEXT,
                delivered_at TEXT,
                received_at TEXT,
                retry_count INTEGER NOT NULL DEFAULT 0,
                failure_reason TEXT,
                sync_status TEXT NOT NULL DEFAULT 'PENDING',
                part_statuses_json TEXT NOT NULL DEFAULT '[]'
            )
            """
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_msg_status_created ON $TBL_MESSAGES(status, created_at DESC)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_msg_dir_created ON $TBL_MESSAGES(direction, created_at DESC)")
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_msg_sync ON $TBL_MESSAGES(sync_status)")

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_EVENTS (
                event_uuid TEXT PRIMARY KEY,
                message_uuid TEXT,
                event_type TEXT NOT NULL,
                title TEXT NOT NULL,
                description TEXT,
                sim_slot INTEGER,
                subscription_id INTEGER,
                application_source TEXT,
                payload_json TEXT NOT NULL DEFAULT '{}',
                event_timestamp TEXT NOT NULL,
                is_synced INTEGER NOT NULL DEFAULT 0
            )
            """
        )
        db.execSQL("CREATE INDEX IF NOT EXISTS idx_evt_ts ON $TBL_EVENTS(event_timestamp DESC)")

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_DEVICE (
                device_id TEXT PRIMARY KEY,
                device_name TEXT NOT NULL,
                model TEXT,
                manufacturer TEXT,
                android_version TEXT,
                app_version TEXT,
                school_id TEXT,
                last_sync_at TEXT,
                last_heartbeat_at TEXT
            )
            """
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_SIMS (
                subscription_id INTEGER PRIMARY KEY,
                sim_slot_index INTEGER NOT NULL,
                carrier_name TEXT NOT NULL,
                display_name TEXT,
                country_iso TEXT,
                phone_number TEXT,
                sim_state TEXT NOT NULL,
                network_operator TEXT,
                network_type TEXT,
                signal_strength_dbm INTEGER,
                signal_level INTEGER NOT NULL DEFAULT 0,
                signal_label TEXT NOT NULL DEFAULT 'Unknown',
                is_active INTEGER NOT NULL DEFAULT 1,
                is_data_enabled INTEGER NOT NULL DEFAULT 0,
                usage_mode TEXT NOT NULL DEFAULT 'SEND_RECEIVE',
                balance_info TEXT NOT NULL DEFAULT 'Not Available',
                validity_info TEXT NOT NULL DEFAULT 'Not Available',
                sent_count INTEGER NOT NULL DEFAULT 0,
                received_count INTEGER NOT NULL DEFAULT 0,
                failed_count INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL
            )
            """
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_RULES (
                id TEXT PRIMARY KEY,
                rule_name TEXT NOT NULL,
                application_name TEXT NOT NULL,
                trigger_event TEXT NOT NULL,
                recipient_mapping TEXT NOT NULL,
                message_template TEXT NOT NULL,
                preferred_sim_slot INTEGER,
                priority TEXT NOT NULL DEFAULT 'NORMAL',
                is_active INTEGER NOT NULL DEFAULT 1,
                webhook_url TEXT,
                execution_count INTEGER NOT NULL DEFAULT 0,
                updated_at TEXT NOT NULL
            )
            """
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_TEMPLATES (
                id TEXT PRIMARY KEY,
                template_name TEXT NOT NULL,
                application_name TEXT NOT NULL,
                category TEXT NOT NULL,
                message_body TEXT NOT NULL,
                dlt_template_id TEXT,
                dlt_header TEXT,
                default_priority TEXT NOT NULL DEFAULT 'NORMAL',
                preferred_sim_slot INTEGER,
                is_active INTEGER NOT NULL DEFAULT 1,
                updated_at TEXT NOT NULL
            )
            """
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_PENDING_UPLOADS (
                upload_id TEXT PRIMARY KEY,
                upload_type TEXT NOT NULL,
                message_uuid TEXT,
                payload_json TEXT NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0,
                last_error TEXT,
                created_at INTEGER NOT NULL
            )
            """
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_PENDING_JOBS (
                message_uuid TEXT PRIMARY KEY,
                lease_token TEXT,
                recipient_number TEXT NOT NULL,
                message_body TEXT NOT NULL,
                subscription_id INTEGER,
                sim_slot INTEGER,
                priority TEXT NOT NULL DEFAULT 'NORMAL',
                delivery_report_requested INTEGER NOT NULL DEFAULT 1,
                expires_at TEXT,
                application_source TEXT,
                reference_id TEXT,
                state TEXT NOT NULL DEFAULT 'LEASED',
                leased_at INTEGER NOT NULL
            )
            """
        )

        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS $TBL_SETTINGS (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                preferred_sim_mode TEXT NOT NULL DEFAULT 'SIM_1',
                preferred_subscription_id INTEGER,
                preferred_sim_slot INTEGER DEFAULT 0,
                secondary_subscription_id INTEGER,
                secondary_sim_slot INTEGER,
                auto_fallback_enabled INTEGER NOT NULL DEFAULT 0,
                switch_on_unavailable INTEGER NOT NULL DEFAULT 1,
                switch_on_network_error INTEGER NOT NULL DEFAULT 0,
                switch_back_on_recover INTEGER NOT NULL DEFAULT 1,
                automated_messaging_enabled INTEGER NOT NULL DEFAULT 1,
                incoming_forwarding_enabled INTEGER NOT NULL DEFAULT 1,
                queue_sync_enabled INTEGER NOT NULL DEFAULT 1,
                scheduled_processing_enabled INTEGER NOT NULL DEFAULT 1,
                polling_interval_seconds INTEGER NOT NULL DEFAULT 15,
                message_expiration_seconds INTEGER NOT NULL DEFAULT 86400,
                retention_days INTEGER NOT NULL DEFAULT 90,
                emergency_disabled INTEGER NOT NULL DEFAULT 0,
                server_url TEXT NOT NULL DEFAULT 'https://eduapi.shamiit.com'
            )
            """
        )
        db.execSQL("INSERT OR IGNORE INTO $TBL_SETTINGS (id) VALUES (1)")
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        onCreate(db)
    }

    fun upsertMessage(values: ContentValues) {
        writableDatabase.insertWithOnConflict(TBL_MESSAGES, null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getMessage(messageUuid: String): Map<String, Any?>? {
        val cur = readableDatabase.rawQuery(
            "SELECT * FROM $TBL_MESSAGES WHERE message_uuid = ? LIMIT 1",
            arrayOf(messageUuid)
        )
        cur.use {
            if (!it.moveToFirst()) return null
            return cursorRowToMap(it)
        }
    }

    fun hasMessage(messageUuid: String): Boolean {
        val cur = readableDatabase.rawQuery(
            "SELECT 1 FROM $TBL_MESSAGES WHERE message_uuid = ? LIMIT 1",
            arrayOf(messageUuid)
        )
        cur.use { return it.count > 0 }
    }

    fun updateMessageStatus(
        messageUuid: String,
        status: String,
        submittedAt: String? = null,
        deliveredAt: String? = null,
        failureReason: String? = null,
        partStatusesJson: String? = null,
        retryCount: Int? = null,
        syncStatus: String? = null,
        sendingSimSlot: Int? = null,
        sendingSubId: Int? = null,
        carrierName: String? = null
    ) {
        val cv = ContentValues().apply {
            put("status", status)
            if (submittedAt != null) put("submitted_at", submittedAt)
            if (deliveredAt != null) put("delivered_at", deliveredAt)
            if (failureReason != null) put("failure_reason", failureReason)
            if (partStatusesJson != null) put("part_statuses_json", partStatusesJson)
            if (retryCount != null) put("retry_count", retryCount)
            if (syncStatus != null) put("sync_status", syncStatus)
            if (sendingSimSlot != null) put("sending_sim_slot", sendingSimSlot)
            if (sendingSubId != null) put("sending_subscription_id", sendingSubId)
            if (carrierName != null) put("carrier_name", carrierName)
        }
        writableDatabase.update(TBL_MESSAGES, cv, "message_uuid = ?", arrayOf(messageUuid))
    }

    fun queryMessages(
        status: String? = null,
        direction: String? = null,
        simSlot: Int? = null,
        search: String? = null,
        limit: Int = 100,
        offset: Int = 0
    ): List<Map<String, Any?>> {
        val where = mutableListOf<String>()
        val args = mutableListOf<String>()

        if (!status.isNullOrBlank() && status.uppercase() != "ALL") {
            where.add("UPPER(status) = ?")
            args.add(status.uppercase())
        }
        if (!direction.isNullOrBlank() && direction.uppercase() != "ALL") {
            where.add("UPPER(direction) = ?")
            args.add(direction.uppercase())
        }
        if (simSlot != null) {
            where.add("(sending_sim_slot = ? OR receiving_sim_slot = ?)")
            args.add(simSlot.toString())
            args.add(simSlot.toString())
        }
        if (!search.isNullOrBlank()) {
            val q = "%${search.trim()}%"
            where.add("(recipient_number LIKE ? OR sender_number LIKE ? OR message_body LIKE ? OR message_uuid LIKE ? OR application_source LIKE ? OR COALESCE(reference_id, '') LIKE ?)")
            repeat(6) { args.add(q) }
        }

        val whereClause = if (where.isEmpty()) "" else "WHERE ${where.joinToString(" AND ")}"
        args.add(limit.toString())
        args.add(offset.toString())

        val list = mutableListOf<Map<String, Any?>>()
        val cur = readableDatabase.rawQuery(
            "SELECT * FROM $TBL_MESSAGES $whereClause ORDER BY created_at DESC LIMIT ? OFFSET ?",
            args.toTypedArray()
        )
        cur.use {
            while (it.moveToNext()) {
                list.add(cursorRowToMap(it))
            }
        }
        return list
    }

    fun insertEvent(
        eventUuid: String,
        messageUuid: String?,
        eventType: String,
        title: String,
        description: String?,
        simSlot: Int?,
        subscriptionId: Int?,
        applicationSource: String?,
        payloadJson: String,
        eventTimestamp: String,
        isSynced: Boolean = false
    ) {
        val cv = ContentValues().apply {
            put("event_uuid", eventUuid)
            put("message_uuid", messageUuid)
            put("event_type", eventType)
            put("title", title)
            put("description", description)
            if (simSlot != null) put("sim_slot", simSlot)
            if (subscriptionId != null) put("subscription_id", subscriptionId)
            put("application_source", applicationSource)
            put("payload_json", payloadJson)
            put("event_timestamp", eventTimestamp)
            put("is_synced", if (isSynced) 1 else 0)
        }
        writableDatabase.insertWithOnConflict(TBL_EVENTS, null, cv, SQLiteDatabase.CONFLICT_IGNORE)
    }

    fun getRecentEvents(limit: Int = 25): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val cur = readableDatabase.rawQuery(
            "SELECT * FROM $TBL_EVENTS ORDER BY event_timestamp DESC LIMIT ?",
            arrayOf(limit.toString())
        )
        cur.use {
            while (it.moveToNext()) list.add(cursorRowToMap(it))
        }
        return list
    }

    fun enqueuePendingUpload(
        uploadId: String,
        uploadType: String,
        messageUuid: String?,
        payloadJson: String
    ) {
        val cv = ContentValues().apply {
            put("upload_id", uploadId)
            put("upload_type", uploadType)
            put("message_uuid", messageUuid)
            put("payload_json", payloadJson)
            put("retry_count", 0)
            put("created_at", System.currentTimeMillis())
        }
        writableDatabase.insertWithOnConflict(TBL_PENDING_UPLOADS, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun getPendingUploads(limit: Int = 50): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val cur = readableDatabase.rawQuery(
            "SELECT * FROM $TBL_PENDING_UPLOADS ORDER BY created_at ASC LIMIT ?",
            arrayOf(limit.toString())
        )
        cur.use {
            while (it.moveToNext()) list.add(cursorRowToMap(it))
        }
        return list
    }

    fun acknowledgeUpload(uploadId: String) {
        writableDatabase.delete(TBL_PENDING_UPLOADS, "upload_id = ?", arrayOf(uploadId))
    }

    fun recordUploadFailure(uploadId: String, error: String) {
        writableDatabase.execSQL(
            "UPDATE $TBL_PENDING_UPLOADS SET retry_count = retry_count + 1, last_error = ? WHERE upload_id = ?",
            arrayOf(error, uploadId)
        )
    }

    fun getPendingUploadsCount(): Int {
        val cur = readableDatabase.rawQuery("SELECT COUNT(*) FROM $TBL_PENDING_UPLOADS", null)
        cur.use { return if (it.moveToFirst()) it.getInt(0) else 0 }
    }

    fun savePendingJob(
        messageUuid: String,
        leaseToken: String?,
        recipientNumber: String,
        messageBody: String,
        subscriptionId: Int?,
        simSlot: Int?,
        priority: String,
        deliveryReportRequested: Boolean,
        expiresAt: String?,
        applicationSource: String?,
        referenceId: String?
    ): Boolean {
        val existing = readableDatabase.rawQuery(
            "SELECT state FROM $TBL_PENDING_JOBS WHERE message_uuid = ? LIMIT 1",
            arrayOf(messageUuid)
        )
        existing.use {
            if (it.moveToFirst()) {
                val st = it.getString(0)
                if (st in listOf("DISPATCHED", "SENT", "DELIVERED")) {
                    return false // Duplicate job prevention!
                }
            }
        }
        val cv = ContentValues().apply {
            put("message_uuid", messageUuid)
            put("lease_token", leaseToken)
            put("recipient_number", recipientNumber)
            put("message_body", messageBody)
            if (subscriptionId != null) put("subscription_id", subscriptionId)
            if (simSlot != null) put("sim_slot", simSlot)
            put("priority", priority)
            put("delivery_report_requested", if (deliveryReportRequested) 1 else 0)
            put("expires_at", expiresAt)
            put("application_source", applicationSource)
            put("reference_id", referenceId)
            put("state", "LEASED")
            put("leased_at", System.currentTimeMillis())
        }
        writableDatabase.insertWithOnConflict(TBL_PENDING_JOBS, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
        return true
    }

    fun updatePendingJobState(messageUuid: String, state: String) {
        val cv = ContentValues().apply { put("state", state) }
        writableDatabase.update(TBL_PENDING_JOBS, cv, "message_uuid = ?", arrayOf(messageUuid))
    }

    fun getPendingJobsCount(): Int {
        val cur = readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM $TBL_PENDING_JOBS WHERE state IN ('LEASED', 'DISPATCHING')",
            null
        )
        cur.use { return if (it.moveToFirst()) it.getInt(0) else 0 }
    }

    fun getSettings(): Map<String, Any?> {
        val cur = readableDatabase.rawQuery("SELECT * FROM $TBL_SETTINGS WHERE id = 1 LIMIT 1", null)
        cur.use {
            if (it.moveToFirst()) return cursorRowToMap(it)
        }
        return emptyMap()
    }

    fun updateSettings(values: ContentValues) {
        writableDatabase.update(TBL_SETTINGS, values, "id = 1", null)
    }

    fun upsertSims(sims: List<ContentValues>, activeSubIds: List<Int>) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            if (activeSubIds.isNotEmpty()) {
                val placeholders = activeSubIds.joinToString(",") { "?" }
                val args = activeSubIds.map { it.toString() }.toTypedArray()
                db.execSQL(
                    "UPDATE $TBL_SIMS SET is_active = 0, sim_state = 'REMOVED' WHERE subscription_id NOT IN ($placeholders)",
                    args
                )
            } else {
                db.execSQL("UPDATE $TBL_SIMS SET is_active = 0, sim_state = 'ABSENT'")
            }

            for (cv in sims) {
                val subId = cv.getAsInteger("subscription_id")
                val existingCur = db.rawQuery(
                    "SELECT usage_mode, sent_count, received_count, failed_count FROM $TBL_SIMS WHERE subscription_id = ?",
                    arrayOf(subId.toString())
                )
                existingCur.use {
                    if (it.moveToFirst()) {
                        if (!cv.containsKey("usage_mode")) cv.put("usage_mode", it.getString(0))
                        cv.put("sent_count", it.getInt(1))
                        cv.put("received_count", it.getInt(2))
                        cv.put("failed_count", it.getInt(3))
                    }
                }
                db.insertWithOnConflict(TBL_SIMS, null, cv, SQLiteDatabase.CONFLICT_REPLACE)
            }
            db.setTransactionSuccessful()
        } finally {
            db.endTransaction()
        }
    }

    fun setSimUsageMode(subscriptionId: Int, usageMode: String) {
        val cv = ContentValues().apply { put("usage_mode", usageMode) }
        writableDatabase.update(TBL_SIMS, cv, "subscription_id = ?", arrayOf(subscriptionId.toString()))
    }

    fun incrementSimStat(subscriptionId: Int, column: String) {
        if (column !in setOf("sent_count", "received_count", "failed_count")) return
        writableDatabase.execSQL(
            "UPDATE $TBL_SIMS SET $column = $column + 1 WHERE subscription_id = ?",
            arrayOf(subscriptionId.toString())
        )
    }

    fun getSims(): List<Map<String, Any?>> {
        val list = mutableListOf<Map<String, Any?>>()
        val cur = readableDatabase.rawQuery(
            "SELECT * FROM $TBL_SIMS ORDER BY sim_slot_index ASC, subscription_id ASC",
            null
        )
        cur.use {
            while (it.moveToNext()) list.add(cursorRowToMap(it))
        }
        return list
    }

    fun getTodayStats(): Map<String, Any> {
        val todayPrefix = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(java.util.Date())
        val cur = readableDatabase.rawQuery(
            """
            SELECT
                COUNT(CASE WHEN direction = 'OUTBOUND' AND status IN ('SENT', 'DELIVERED') AND created_at LIKE ? THEN 1 END) AS sent_today,
                COUNT(CASE WHEN direction = 'INBOUND' AND created_at LIKE ? THEN 1 END) AS received_today,
                COUNT(CASE WHEN direction = 'OUTBOUND' AND status = 'DELIVERED' AND created_at LIKE ? THEN 1 END) AS delivered_today,
                COUNT(CASE WHEN direction = 'OUTBOUND' AND status = 'FAILED' AND created_at LIKE ? THEN 1 END) AS failed_today,
                COUNT(CASE WHEN status IN ('QUEUED', 'LEASED', 'SENDING') THEN 1 END) AS queue_size,
                COUNT(CASE WHEN status = 'SCHEDULED' THEN 1 END) AS scheduled_count
            FROM $TBL_MESSAGES
            """,
            arrayOf("$todayPrefix%", "$todayPrefix%", "$todayPrefix%", "$todayPrefix%")
        )
        cur.use {
            if (it.moveToFirst()) {
                val sent = it.getInt(0)
                val recv = it.getInt(1)
                val deliv = it.getInt(2)
                val failed = it.getInt(3)
                val queue = it.getInt(4)
                val sched = it.getInt(5)
                val denom = deliv + failed
                val rate = if (denom > 0) (deliv * 100.0 / denom) else (if (sent > 0 && failed == 0) 100.0 else 0.0)
                return mapOf(
                    "sent_today" to sent,
                    "received_today" to recv,
                    "delivered_today" to deliv,
                    "failed_today" to failed,
                    "queue_size" to queue,
                    "scheduled_count" to sched,
                    "delivery_rate" to Math.round(rate * 10.0) / 10.0
                )
            }
        }
        return mapOf(
            "sent_today" to 0,
            "received_today" to 0,
            "delivered_today" to 0,
            "failed_today" to 0,
            "queue_size" to 0,
            "scheduled_count" to 0,
            "delivery_rate" to 0.0
        )
    }

    fun cleanupOldSyncedData(retentionDays: Int): Int {
        val cutoffMillis = System.currentTimeMillis() - retentionDays * 86400_000L
        val cutoffIso = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(java.util.Date(cutoffMillis))
        val deletedMsgs = writableDatabase.delete(
            TBL_MESSAGES,
            "sync_status = 'SYNCED' AND created_at < ?",
            arrayOf(cutoffIso)
        )
        writableDatabase.delete(TBL_EVENTS, "is_synced = 1 AND event_timestamp < ?", arrayOf(cutoffIso))
        return deletedMsgs
    }

    fun getDatabaseSizeBytes(): Long {
        val dbFile: File = appContext.getDatabasePath(DATABASE_NAME)
        return if (dbFile.exists()) dbFile.length() else 0L
    }

    private fun cursorRowToMap(cur: android.database.Cursor): Map<String, Any?> {
        val map = LinkedHashMap<String, Any?>()
        for (i in 0 until cur.columnCount) {
            val name = cur.getColumnName(i)
            when (cur.getType(i)) {
                android.database.Cursor.FIELD_TYPE_NULL -> map[name] = null
                android.database.Cursor.FIELD_TYPE_INTEGER -> map[name] = cur.getLong(i)
                android.database.Cursor.FIELD_TYPE_FLOAT -> map[name] = cur.getDouble(i)
                android.database.Cursor.FIELD_TYPE_STRING -> map[name] = cur.getString(i)
                android.database.Cursor.FIELD_TYPE_BLOB -> map[name] = cur.getBlob(i)
            }
        }
        return map
    }
}
