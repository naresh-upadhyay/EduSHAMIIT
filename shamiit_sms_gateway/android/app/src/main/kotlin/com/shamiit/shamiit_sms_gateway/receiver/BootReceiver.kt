package com.shamiit.shamiit_sms_gateway.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.shamiit.shamiit_sms_gateway.service.SmsGatewayForegroundService
import com.shamiit.shamiit_sms_gateway.worker.GatewayHeartbeatWorker
import com.shamiit.shamiit_sms_gateway.worker.SmsSyncWorker

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON"
        ) {
            SmsSyncWorker.schedulePeriodic(context)
            GatewayHeartbeatWorker.schedulePeriodic(context)
            try {
                SmsGatewayForegroundService.start(context)
            } catch (_: Exception) {
                // Android 14+ may restrict background FGS start on boot; WorkManager handles fallback sync.
            }
        }
    }
}
