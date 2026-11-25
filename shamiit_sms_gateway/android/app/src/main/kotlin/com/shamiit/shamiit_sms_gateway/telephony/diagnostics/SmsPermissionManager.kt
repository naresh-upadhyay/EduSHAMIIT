package com.shamiit.shamiit_sms_gateway.telephony.diagnostics

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

object SmsPermissionManager {

    const val REQ_CORE_PERMISSIONS = 4101
    const val REQ_CONTACTS_PERMISSION = 4102

    fun corePermissions(): Array<String> {
        val perms = mutableListOf(
            Manifest.permission.SEND_SMS,
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_PHONE_STATE
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            perms.add(Manifest.permission.READ_PHONE_NUMBERS)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            perms.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        return perms.toTypedArray()
    }

    fun getPermissionSnapshot(context: Context, activity: Activity? = null): Map<String, Any> {
        fun statusOf(perm: String): Map<String, Any> {
            val granted = ContextCompat.checkSelfPermission(context, perm) == PackageManager.PERMISSION_GRANTED
            val permanentlyDenied = if (!granted && activity != null) {
                !ActivityCompat.shouldShowRequestPermissionRationale(activity, perm)
            } else false
            return mapOf(
                "granted" to granted,
                "permanently_denied" to permanentlyDenied
            )
        }

        val sendSms = ContextCompat.checkSelfPermission(context, Manifest.permission.SEND_SMS) == PackageManager.PERMISSION_GRANTED
        val receiveSms = ContextCompat.checkSelfPermission(context, Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
        val readPhone = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED
        val readContacts = ContextCompat.checkSelfPermission(context, Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_GRANTED
        val postNotif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        } else true

        return mapOf(
            "send_sms" to sendSms,
            "receive_sms" to receiveSms,
            "read_phone_state" to readPhone,
            "read_contacts" to readContacts,
            "post_notifications" to postNotif,
            "all_core_granted" to (sendSms && receiveSms && readPhone && postNotif),
            "details" to mapOf(
                "SEND_SMS" to statusOf(Manifest.permission.SEND_SMS),
                "RECEIVE_SMS" to statusOf(Manifest.permission.RECEIVE_SMS),
                "READ_PHONE_STATE" to statusOf(Manifest.permission.READ_PHONE_STATE),
                "READ_CONTACTS" to statusOf(Manifest.permission.READ_CONTACTS)
            )
        )
    }
}
