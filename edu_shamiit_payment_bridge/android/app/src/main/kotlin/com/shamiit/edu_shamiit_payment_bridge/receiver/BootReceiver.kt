package com.shamiit.edu_shamiit_payment_bridge.receiver

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.util.Log
import com.shamiit.edu_shamiit_payment_bridge.notification.PaymentNotificationListenerService
import com.shamiit.edu_shamiit_payment_bridge.sync.SyncManager

class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PaymentBridgeBoot"
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        val action = intent.action
        Log.i(TAG, "Received broadcast action: $action")

        if (Intent.ACTION_BOOT_COMPLETED == action || "android.intent.action.QUICKBOOT_POWERON" == action) {
            // Auto-recovery of NotificationListenerService on device boot
            try {
                val componentName = ComponentName(context, PaymentNotificationListenerService::class.java)
                val pm = context.packageManager
                pm.setComponentEnabledSetting(
                    componentName,
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                    PackageManager.DONT_KILL_APP
                )
                Log.i(TAG, "Re-enabled NotificationListenerService after boot")

                // Trigger background sync to send any pending stored notifications
                SyncManager.getInstance(context).triggerSync()
            } catch (e: Exception) {
                Log.e(TAG, "Error handling boot broadcast: ${e.message}", e)
            }
        }
    }
}
