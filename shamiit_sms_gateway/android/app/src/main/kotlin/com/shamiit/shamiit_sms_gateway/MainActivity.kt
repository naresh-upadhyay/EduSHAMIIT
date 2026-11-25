package com.shamiit.shamiit_sms_gateway

import com.shamiit.shamiit_sms_gateway.bridge.SmsEventBus
import com.shamiit.shamiit_sms_gateway.bridge.SmsGatewayChannel
import com.shamiit.shamiit_sms_gateway.telephony.diagnostics.SmsPermissionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private lateinit var gatewayChannel: SmsGatewayChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        gatewayChannel = SmsGatewayChannel(applicationContext) { this }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SmsGatewayChannel.METHOD_CHANNEL_NAME
        ).setMethodCallHandler(gatewayChannel)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SmsGatewayChannel.EVENT_CHANNEL_NAME
        ).setStreamHandler(SmsEventBus)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SmsPermissionManager.REQ_CORE_PERMISSIONS ||
            requestCode == SmsPermissionManager.REQ_CONTACTS_PERMISSION
        ) {
            if (::gatewayChannel.isInitialized) {
                gatewayChannel.onPermissionRequestCompleted()
            }
        }
    }
}
