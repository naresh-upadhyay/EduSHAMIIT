package com.shamiit.shamiit_sms_gateway.telephony.diagnostics

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.provider.ContactsContract
import androidx.core.content.ContextCompat

object ContactsHelper {

    fun hasContactsPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun getContacts(context: Context, query: String? = null, limit: Int = 150): List<Map<String, String>> {
        if (!hasContactsPermission(context)) return emptyList()

        val result = mutableListOf<Map<String, String>>()
        val seen = HashSet<String>()
        val selection = if (!query.isNullOrBlank()) {
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ? OR ${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?"
        } else null
        val args = if (!query.isNullOrBlank()) {
            val q = "%${query.trim()}%"
            arrayOf(q, q)
        } else null

        val cur = context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            ),
            selection,
            args,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        ) ?: return emptyList()

        cur.use {
            val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (it.moveToNext() && result.size < limit) {
                val name = if (nameIdx >= 0) it.getString(nameIdx) ?: "Contact" else "Contact"
                val num = if (numIdx >= 0) (it.getString(numIdx) ?: "").replace(Regex("[\\s\\-()]"), "") else ""
                if (num.isNotBlank() && seen.add("$name|$num")) {
                    result.add(mapOf("name" to name, "phone" to num))
                }
            }
        }
        return result
    }
}
