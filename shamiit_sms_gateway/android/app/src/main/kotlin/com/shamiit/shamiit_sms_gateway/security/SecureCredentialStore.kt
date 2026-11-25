package com.shamiit.shamiit_sms_gateway.security

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys

/**
 * Android Keystore-backed credential store for device tokens and auth secrets.
 */
class SecureCredentialStore(context: Context) {

    companion object {
        private const val ENCRYPTED_PREFS_NAME = "shamiit_sms_gateway_secure_prefs"
        private const val FALLBACK_PREFS_NAME = "shamiit_sms_gateway_secure_fallback"
        private const val KEY_DEVICE_TOKEN = "device_token"
        private const val KEY_AUTH_TOKEN = "auth_token"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_SCHOOL_ID = "school_id"
    }

    private val prefs: SharedPreferences = try {
        val masterKeyAlias = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
        EncryptedSharedPreferences.create(
            ENCRYPTED_PREFS_NAME,
            masterKeyAlias,
            context.applicationContext,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    } catch (_: Exception) {
        context.applicationContext.getSharedPreferences(FALLBACK_PREFS_NAME, Context.MODE_PRIVATE)
    }

    fun saveDeviceToken(token: String) {
        prefs.edit().putString(KEY_DEVICE_TOKEN, token).apply()
    }

    fun getDeviceToken(): String? = prefs.getString(KEY_DEVICE_TOKEN, null)

    fun saveAuthToken(token: String) {
        prefs.edit().putString(KEY_AUTH_TOKEN, token).apply()
    }

    fun getAuthToken(): String? = prefs.getString(KEY_AUTH_TOKEN, null)

    fun saveDeviceId(deviceId: String) {
        prefs.edit().putString(KEY_DEVICE_ID, deviceId).apply()
    }

    fun getDeviceId(): String? = prefs.getString(KEY_DEVICE_ID, null)

    fun saveSchoolId(schoolId: String) {
        prefs.edit().putString(KEY_SCHOOL_ID, schoolId).apply()
    }

    fun getSchoolId(): String? = prefs.getString(KEY_SCHOOL_ID, null)

    fun clearAuth() {
        prefs.edit()
            .remove(KEY_AUTH_TOKEN)
            .remove(KEY_DEVICE_TOKEN)
            .apply()
    }

    fun isKeystoreBacked(): Boolean {
        return prefs is EncryptedSharedPreferences
    }
}
