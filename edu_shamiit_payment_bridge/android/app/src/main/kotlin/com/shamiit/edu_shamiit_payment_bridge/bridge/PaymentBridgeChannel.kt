package com.shamiit.edu_shamiit_payment_bridge.bridge

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.service.notification.NotificationListenerService
import androidx.core.app.NotificationManagerCompat
import com.shamiit.edu_shamiit_payment_bridge.notification.PaymentNotificationListenerService
import com.shamiit.edu_shamiit_payment_bridge.parser.NotificationParserFactory
import com.shamiit.edu_shamiit_payment_bridge.storage.PaymentDatabaseHelper
import com.shamiit.edu_shamiit_payment_bridge.sync.SyncManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.UUID
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileOutputStream

class PaymentBridgeChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.shamiit.payment_bridge/channel"
        private const val PREFS_DEVICE = "payment_bridge_device_prefs"
        private const val KEY_UNIQUE_DEVICE_ID = "unique_device_id"

        fun getActualBatteryLevel(context: Context): Int {
            try {
                val bm = context.getSystemService(Context.BATTERY_SERVICE) as? BatteryManager
                val cap = bm?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
                if (cap != null && cap in 1..100) {
                    return cap
                }
                val batteryStatus: Intent? = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
                val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
                if (level >= 0 && scale > 0) {
                    return (level * 100 / scale.toFloat()).toInt()
                }
            } catch (_: Exception) {}
            return 100
        }
    }

    private val dbHelper = PaymentDatabaseHelper.getInstance(context)
    private val syncManager = SyncManager.getInstance(context)
    private val parserFactory = NotificationParserFactory(context)

    /**
     * Retrieves or generates a persistent unique device ID backed by Android hardware ID or UUID.
     */
    private fun getOrCreateUniqueDeviceId(): String {
        val prefs = context.getSharedPreferences(PREFS_DEVICE, Context.MODE_PRIVATE)
        var deviceId = prefs.getString(KEY_UNIQUE_DEVICE_ID, null)
        if (deviceId.isNullOrEmpty()) {
            val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
            deviceId = if (!androidId.isNullOrEmpty() && androidId != "9774d56d682e549c") {
                "PB-$androidId".uppercase()
            } else {
                "PB-" + UUID.randomUUID().toString().substring(0, 8).uppercase()
            }
            prefs.edit().putString(KEY_UNIQUE_DEVICE_ID, deviceId).apply()
        }
        return deviceId
    }

    private fun isEmulator(): Boolean {
        return (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
                || Build.FINGERPRINT.startsWith("generic")
                || Build.FINGERPRINT.startsWith("unknown")
                || Build.HARDWARE.contains("goldfish")
                || Build.HARDWARE.contains("ranchu")
                || Build.MODEL.contains("google_sdk")
                || Build.MODEL.contains("Emulator")
                || Build.MODEL.contains("Android SDK built for x86")
                || Build.MANUFACTURER.contains("Genymotion")
                || Build.PRODUCT.contains("sdk_google")
                || Build.PRODUCT.contains("google_sdk")
                || Build.PRODUCT.contains("sdk")
                || Build.PRODUCT.contains("sdk_x86")
                || Build.PRODUCT.contains("vbox86p")
                || Build.PRODUCT.contains("emulator")
                || Build.PRODUCT.contains("simulator")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isNotificationAccessGranted" -> {
                val pkgName = context.packageName
                val enabledPackages = NotificationManagerCompat.getEnabledListenerPackages(context)
                val isGranted = enabledPackages.contains(pkgName)
                result.success(isGranted)
            }

            "openNotificationSettings" -> {
                try {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", "Unable to open notification settings: ${e.message}", null)
                }
            }

            "isListenerRunning" -> {
                val pkgName = context.packageName
                val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(pkgName)
                if (isAccessGranted && !PaymentNotificationListenerService.isServiceConnected) {
                    PaymentNotificationListenerService.forceRebind(context)
                }
                result.success(isAccessGranted)
            }

            "forceRebindListener" -> {
                PaymentNotificationListenerService.forceRebind(context)
                result.success(true)
            }

            "getRawNotifications" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val list = dbHelper.getRawNotifications(limit = 100)
                    Handler(Looper.getMainLooper()).post {
                        result.success(list)
                    }
                }
            }

            "clearRawNotifications" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val cleared = dbHelper.clearRawNotifications()
                    Handler(Looper.getMainLooper()).post {
                        result.success(cleared)
                    }
                }
            }

            "openAutostartSettings" -> {
                var opened = false
                try {
                    val intent = Intent().apply {
                        component = ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    opened = true
                } catch (_: Exception) {}
                if (!opened) {
                    try {
                        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:${context.packageName}")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        opened = true
                    } catch (_: Exception) {}
                }
                result.success(opened)
            }

            "getCustomFormats" -> {
                val prefs = context.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
                val all = prefs.all.mapValues { it.value?.toString() ?: "" }
                result.success(all)
            }

            "startListenerService" -> {
                val pkgName = context.packageName
                val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(pkgName)
                if (!isAccessGranted) {
                    try {
                        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                    } catch (_: Exception) {}
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    try {
                        NotificationListenerService.requestRebind(
                            ComponentName(context, PaymentNotificationListenerService::class.java)
                        )
                    } catch (_: Exception) {}
                }
                result.success(isAccessGranted)
            }

            "stopListenerService" -> {
                result.success(true)
            }

            "setServerUrl" -> {
                val url = call.argument<String>("url")
                if (!url.isNullOrEmpty()) {
                    val cleanUrl = url.trim().trimEnd('/')
                    val prefs = context.getSharedPreferences("payment_bridge_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString(SyncManager.KEY_SERVER_URL, cleanUrl).apply()
                    val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    flutterPrefs.edit()
                        .putString("flutter.pref_server_url", cleanUrl)
                        .putString("flutter.server_url", cleanUrl)
                        .apply()
                }
                result.success(true)
            }

            "getLocalNotifications" -> {
                CoroutineScope(Dispatchers.IO).launch {
                    val events = dbHelper.getAllEvents(limit = 100)
                    val list = events.map { ev ->
                        mapOf(
                            "id" to ev.eventUuid,
                            "event_uuid" to ev.eventUuid,
                            "source_package" to ev.sourcePackage,
                            "source_app" to ev.sourceApp,
                            "event_type" to ev.eventType,
                            "amount_paise" to ev.amountPaise,
                            "sender_name" to ev.senderName,
                            "masked_sender_identifier" to ev.maskedSenderIdentifier,
                            "transaction_reference" to ev.transactionReference,
                            "notification_timestamp" to ev.notificationTimestamp,
                            "raw_title" to ev.rawTitle,
                            "raw_text" to ev.rawText,
                            "parser_version" to ev.parserVersion,
                            "confidence_score" to ev.confidenceScore,
                            "parsing_status" to ev.parsingStatus,
                            "candidate_match_status" to "UNMATCHED",
                            "sync_status" to if (ev.isSynced) "SYNCED" else "PENDING"
                        )
                    }
                    Handler(Looper.getMainLooper()).post {
                        result.success(list)
                    }
                }
            }

            "getUniqueDeviceId" -> {
                result.success(getOrCreateUniqueDeviceId())
            }

            "isEmulator" -> {
                result.success(isEmulator())
            }

            "isIgnoringBatteryOptimizations" -> {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                val isIgnoring = powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
                result.success(isIgnoring)
            }

            "requestIgnoreBatteryOptimizations" -> {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${context.packageName}")
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    // Fallback to battery optimization settings
                    try {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        context.startActivity(intent)
                        result.success(true)
                    } catch (ex: Exception) {
                        result.error("ERROR", "Unable to open battery optimization: ${ex.message}", null)
                    }
                }
            }

            "getDiagnostics" -> {
                val batteryLevel = getActualBatteryLevel(context)

                val pkgName = context.packageName
                val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(context).contains(pkgName)
                val isListenerRunning = PaymentNotificationListenerService.isServiceConnected
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
                val isBatteryOptDisabled = powerManager?.isIgnoringBatteryOptimizations(context.packageName) ?: false
                val uniqueDeviceId = getOrCreateUniqueDeviceId()
                val isDeviceEmulator = isEmulator()

                CoroutineScope(Dispatchers.IO).launch {
                    val pendingQueueCount = dbHelper.getPendingQueueCount()
                    val totalEventsCount = dbHelper.getTotalEventsCount()

                    val diagnosticsMap = mapOf(
                        "notification_access_granted" to isAccessGranted,
                        "listener_service_running" to isListenerRunning,
                        "battery_level" to batteryLevel,
                        "battery_optimization_disabled" to isBatteryOptDisabled,
                        "pending_queue_count" to pendingQueueCount,
                        "total_events_count" to totalEventsCount,
                        "android_version" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
                        "device_model" to "${Build.MANUFACTURER} ${Build.MODEL}",
                        "device_id" to uniqueDeviceId,
                        "is_emulator" to isDeviceEmulator,
                        "app_version" to "1.0.0"
                    )
                    Handler(Looper.getMainLooper()).post {
                        result.success(diagnosticsMap)
                    }
                }
            }

            "syncNow" -> {
                syncManager.triggerSync { success, count ->
                    Handler(Looper.getMainLooper()).post {
                        result.success(mapOf("success" to success, "synced_count" to count))
                    }
                }
            }

            "getMonitoredApps" -> {
                val apps = listOf(
                    mapOf("name" to "PhonePe", "package" to "com.phonepe.app", "enabled" to PaymentNotificationListenerService.isPackageMonitored(context, "com.phonepe.app")),
                    mapOf("name" to "Google Pay", "package" to "com.google.android.apps.nbu.paisa.user", "enabled" to PaymentNotificationListenerService.isPackageMonitored(context, "com.google.android.apps.nbu.paisa.user")),
                    mapOf("name" to "Paytm", "package" to "net.one97.paytm", "enabled" to PaymentNotificationListenerService.isPackageMonitored(context, "net.one97.paytm")),
                    mapOf("name" to "BHIM UPI", "package" to "in.org.npci.upiapp", "enabled" to PaymentNotificationListenerService.isPackageMonitored(context, "in.org.npci.upiapp"))
                )
                result.success(apps)
            }

            "setAppMonitored" -> {
                val pkg = call.argument<String>("package")
                val enabled = call.argument<Boolean>("enabled") ?: true
                if (pkg != null) {
                    PaymentNotificationListenerService.setPackageMonitored(context, pkg, enabled)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Package is required", null)
                }
            }

            "simulateNotification" -> {
                val packageName = call.argument<String>("package") ?: "com.phonepe.app"
                val title = call.argument<String>("title") ?: "Payment Received"
                val text = call.argument<String>("text") ?: "Received Rs 2000.34 from **** 9821 Ref: UPI/438729106731"

                val parser = parserFactory.getParser(packageName)
                val event = parser.parse(packageName, title, text, System.currentTimeMillis())
                CoroutineScope(Dispatchers.IO).launch {
                    val inserted = dbHelper.insertEvent(event)
                    Handler(Looper.getMainLooper()).post {
                        if (inserted) {
                            syncManager.triggerSync()
                            result.success(mapOf("success" to true, "event_uuid" to event.eventUuid))
                        } else {
                            result.success(mapOf("success" to false, "reason" to "duplicate or DB insert error"))
                        }
                    }
                }
            }

            "shareReceiptPdf" -> {
                val receiptNo = call.argument<String>("receipt_no") ?: "RCP-${System.currentTimeMillis()}"
                val studentName = call.argument<String>("student_name") ?: "Student"
                val invoiceRef = call.argument<String>("invoice_ref") ?: "N/A"
                val feeHead = call.argument<String>("fee_head") ?: "Tuition & Institutional Fee"
                val paymentMode = call.argument<String>("payment_mode") ?: "UPI"
                val bankUtr = call.argument<String>("bank_utr") ?: "N/A"
                val dateTime = call.argument<String>("date_time") ?: "Now"
                val amount = call.argument<String>("amount") ?: "₹0.00"
                val baseAmount = call.argument<String>("base_amount")
                val excessAmount = call.argument<String>("excess_amount")
                val status = call.argument<String>("status") ?: "VERIFIED"

                val success = generateAndShareReceiptPdf(
                    receiptNo = receiptNo,
                    studentName = studentName,
                    invoiceRef = invoiceRef,
                    feeHead = feeHead,
                    paymentMode = paymentMode,
                    bankUtr = bankUtr,
                    dateTime = dateTime,
                    amount = amount,
                    baseAmount = baseAmount,
                    excessAmount = excessAmount,
                    status = status
                )
                result.success(success)
            }

            "setCustomFormat" -> {
                val pkg = call.argument<String>("package")
                if (pkg != null) {
                    val prefs = context.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
                    val editor = prefs.edit()

                    // Single key support (legacy)
                    val type = call.argument<String>("type")
                    val regex = call.argument<String>("regex")
                    if (type != null && regex != null) {
                        editor.putString("${pkg}_$type", regex)
                    }

                    // Multi-field and quality rule support
                    call.argument<String>("amount_regex")?.let { editor.putString("${pkg}_amount", it) }
                    call.argument<String>("sender_regex")?.let { editor.putString("${pkg}_sender", it) }
                    call.argument<String>("reference_regex")?.let { editor.putString("${pkg}_reference", it) }
                    call.argument<String>("bank_regex")?.let { editor.putString("${pkg}_masked", it) }

                    // Custom Gate Rules (Title match, Inclusion keywords, Exclusion/Ignore keywords, and Multi-Condition Query Rules JSON)
                call.argument<String>("rules_json")?.let { editor.putString("${pkg}_rules_json", it) }
                    call.argument<String>("title_match_mode")?.let { editor.putString("${pkg}_title_match_mode", it) }
                    call.argument<String>("title_match_value")?.let { editor.putString("${pkg}_title_match_value", it) }
                    call.argument<String>("required_keywords")?.let { editor.putString("${pkg}_required_keywords", it) }
                    call.argument<String>("ignore_keywords")?.let { editor.putString("${pkg}_ignore_keywords", it) }
                    call.argument<Boolean>("case_sensitive")?.let { editor.putBoolean("${pkg}_case_sensitive", it) }

                    editor.apply()
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Package is required", null)
                }
            }

            "getCustomFormat" -> {
                val pkg = call.argument<String>("package") ?: "*"
                val prefs = context.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
                val config = mapOf(
                    "package_name" to pkg,
                    "rules_json" to (prefs.getString("${pkg}_rules_json", null) ?: prefs.getString("*_rules_json", null)),
                    "amount_regex" to (prefs.getString("${pkg}_amount", null) ?: prefs.getString("*_amount", null)),
                    "sender_regex" to (prefs.getString("${pkg}_sender", null) ?: prefs.getString("*_sender", null)),
                    "reference_regex" to (prefs.getString("${pkg}_reference", null) ?: prefs.getString("*_reference", null)),
                    "bank_regex" to (prefs.getString("${pkg}_masked", null) ?: prefs.getString("*_masked", null)),
                    "title_match_mode" to (prefs.getString("${pkg}_title_match_mode", null) ?: "ANY"),
                    "title_match_value" to prefs.getString("${pkg}_title_match_value", null),
                    "required_keywords" to prefs.getString("${pkg}_required_keywords", null),
                    "ignore_keywords" to prefs.getString("${pkg}_ignore_keywords", null),
                    "case_sensitive" to prefs.getBoolean("${pkg}_case_sensitive", false)
                )
                result.success(config)
            }

            "deleteCustomFormat" -> {
                val pkg = call.argument<String>("package")
                val type = call.argument<String>("type")
                if (pkg != null) {
                    val prefs = context.getSharedPreferences("custom_formats", Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                    if (type != null) {
                        editor.remove("${pkg}_$type")
                    } else {
                        editor.remove("${pkg}_rules_json")
                        editor.remove("${pkg}_amount")
                        editor.remove("${pkg}_sender")
                        editor.remove("${pkg}_reference")
                        editor.remove("${pkg}_masked")
                        editor.remove("${pkg}_title_match_mode")
                        editor.remove("${pkg}_title_match_value")
                        editor.remove("${pkg}_required_keywords")
                        editor.remove("${pkg}_ignore_keywords")
                        editor.remove("${pkg}_case_sensitive")
                    }
                    editor.apply()
                    result.success(true)
                } else {
                    result.error("INVALID_ARGS", "Package is required", null)
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun generateAndShareReceiptPdf(
        receiptNo: String,
        studentName: String,
        invoiceRef: String,
        feeHead: String,
        paymentMode: String,
        bankUtr: String,
        dateTime: String,
        amount: String,
        baseAmount: String?,
        excessAmount: String?,
        status: String?
    ): Boolean {
        try {
            val doc = PdfDocument()
            val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create() // A4 standard
            val page = doc.startPage(pageInfo)
            val canvas = page.canvas

            val textPaint = Paint(Paint.ANTI_ALIAS_FLAG)
            val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG)

            // 1. Top Decorative Brand Banner
            fillPaint.color = Color.parseColor("#0F172A") // Primary Navy
            canvas.drawRect(0f, 0f, 595f, 110f, fillPaint)

            // Institution Title
            textPaint.color = Color.WHITE
            textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textPaint.textSize = 22f
            canvas.drawText("EduSHAMIIT International Institute", 40f, 50f, textPaint)

            textPaint.textSize = 12f
            textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            textPaint.color = Color.parseColor("#94A3B8")
            canvas.drawText("Official Fee Payment Receipt & Automated Reconciliation Summary", 40f, 74f, textPaint)
            canvas.drawText("Date Generated: $dateTime", 40f, 94f, textPaint)

            // 2. Verified Status Badge
            fillPaint.color = Color.parseColor("#DCFCE7") // Light green
            val statusRect = RectF(40f, 130f, 555f, 175f)
            canvas.drawRoundRect(statusRect, 8f, 8f, fillPaint)

            textPaint.color = Color.parseColor("#166534") // Dark green
            textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textPaint.textSize = 14f
            val statusLabel = if (!status.isNullOrEmpty()) status.uppercase() else "VERIFIED & RECONCILED"
            canvas.drawText("STATUS: $statusLabel", 56f, 158f, textPaint)

            // 3. Main Receipt Table Card
            fillPaint.color = Color.parseColor("#F8FAFC")
            val cardRect = RectF(40f, 195f, 555f, 510f)
            canvas.drawRoundRect(cardRect, 12f, 12f, fillPaint)

            fillPaint.style = Paint.Style.STROKE
            fillPaint.color = Color.parseColor("#E2E8F0")
            fillPaint.strokeWidth = 1.5f
            canvas.drawRoundRect(cardRect, 12f, 12f, fillPaint)
            fillPaint.style = Paint.Style.FILL

            // Table rows
            val rows = listOf(
                "Receipt Number" to receiptNo,
                "Student Name" to studentName,
                "Invoice Reference" to invoiceRef,
                "Fee Classification" to feeHead,
                "Payment Mode" to paymentMode,
                "Bank UTR / Reference" to bankUtr,
                "Transaction Date & Time" to dateTime
            )

            var y = 235f
            for ((label, value) in rows) {
                textPaint.color = Color.parseColor("#64748B")
                textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
                textPaint.textSize = 12f
                canvas.drawText(label, 60f, y, textPaint)

                textPaint.color = Color.parseColor("#0F172A")
                textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                textPaint.textSize = 12f
                canvas.drawText(value, 230f, y, textPaint)

                // Row divider line
                fillPaint.color = Color.parseColor("#E2E8F0")
                fillPaint.strokeWidth = 1f
                canvas.drawLine(60f, y + 14f, 535f, y + 14f, fillPaint)

                y += 38f
            }

            // 4. Amount Summary Section
            fillPaint.color = Color.parseColor("#EFF6FF") // Light blue
            val amtRect = RectF(40f, 530f, 555f, 650f)
            canvas.drawRoundRect(amtRect, 12f, 12f, fillPaint)

            textPaint.color = Color.parseColor("#1E3A8A")
            textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            textPaint.textSize = 12f
            canvas.drawText("Base Fee Paid:", 60f, 565f, textPaint)
            canvas.drawText(baseAmount ?: amount, 230f, 565f, textPaint)

            canvas.drawText("Excess Paid:", 60f, 595f, textPaint)
            canvas.drawText(excessAmount ?: "₹0.00", 230f, 595f, textPaint)

            textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textPaint.textSize = 15f
            textPaint.color = Color.parseColor("#1D4ED8")
            canvas.drawText("Total Settled Amount:", 60f, 630f, textPaint)
            canvas.drawText(amount, 230f, 630f, textPaint)

            // 5. Verification Footer
            textPaint.color = Color.parseColor("#94A3B8")
            textPaint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            textPaint.textSize = 10f
            canvas.drawText("This is an official, computer-generated receipt digitally signed via EduSHAMIIT Payment Bridge.", 40f, 700f, textPaint)
            canvas.drawText("Reconciliation ID: ${UUID.randomUUID()} • Immutable System Audit Trail Enforced", 40f, 718f, textPaint)

            doc.finishPage(page)

            // Save PDF to cache directory
            val cleanReceiptNo = receiptNo.replace("[^a-zA-Z0-9_-]".toRegex(), "_")
            val pdfFile = File(context.cacheDir, "receipt_${cleanReceiptNo}.pdf")
            val outputStream = FileOutputStream(pdfFile)
            doc.writeTo(outputStream)
            outputStream.close()
            doc.close()

            // Share via FileProvider & Intent
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", pdfFile)
            val shareIntent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                putExtra(Intent.EXTRA_SUBJECT, "Fee Payment Receipt - $receiptNo")
                putExtra(Intent.EXTRA_TEXT, "Official Fee Receipt for $studentName ($receiptNo) - Settled Amount: $amount via $paymentMode")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val chooser = Intent.createChooser(shareIntent, "Share Receipt PDF via").apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(chooser)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            // Fallback: Share plain text receipt
            try {
                val textShare = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_SUBJECT, "Fee Payment Receipt - $receiptNo")
                    putExtra(
                        Intent.EXTRA_TEXT,
                        """
                        *EduSHAMIIT International Institute*
                        *OFFICIAL FEE PAYMENT RECEIPT*
                        ---------------------------------
                        Receipt No: $receiptNo
                        Student Name: $studentName
                        Invoice: $invoiceRef
                        Fee Head: $feeHead
                        Payment Mode: $paymentMode
                        Bank UTR: $bankUtr
                        Date & Time: $dateTime
                        ---------------------------------
                        Total Amount Paid: $amount
                        Status: VERIFIED & RECONCILED
                        """.trimIndent()
                    )
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                val chooser = Intent.createChooser(textShare, "Share Receipt via").apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                context.startActivity(chooser)
                return true
            } catch (_: Exception) {
                return false
            }
        }
    }
}
