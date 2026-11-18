package com.shamiit.edu_shamiit_payment_bridge

import android.os.Bundle
import androidx.core.app.NotificationManagerCompat
import com.shamiit.edu_shamiit_payment_bridge.bridge.PaymentBridgeChannel
import com.shamiit.edu_shamiit_payment_bridge.notification.PaymentNotificationListenerService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PaymentBridgeChannel.CHANNEL_NAME)
        channel.setMethodCallHandler(PaymentBridgeChannel(this))
        checkAndRebindListener()
    }

    override fun onResume() {
        super.onResume()
        checkAndRebindListener()
    }

    private fun checkAndRebindListener() {
        try {
            val isAccessGranted = NotificationManagerCompat.getEnabledListenerPackages(this).contains(packageName)
            if (isAccessGranted && !PaymentNotificationListenerService.isServiceConnected) {
                PaymentNotificationListenerService.forceRebind(this)
            }
        } catch (_: Exception) {}
    }
}
