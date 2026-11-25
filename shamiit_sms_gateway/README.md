# SHAMIIT SMS GATEWAY

**Company:** SHAMIIT Innovation and Technologies LLP  
**Tagline:** *Imagine Beyond Imagination*  
**Architecture:** Flutter UI + Native Android Kotlin Telephony Engine + FastAPI + PostgreSQL

## 1. Overview
`shamiit_sms_gateway` turns an authorized Android smartphone (single or dual SIM) into an enterprise SMS gateway connected to the SHAMIIT FastAPI backend. It inherits the splash screen, authentication stack (Password + Email OTP + Forgot/Reset Password), and left navigation drawer skeleton from `edu_shamiit_payment_bridge`.

## 2. Package & Module Layout
- **Flutter UI & State (`lib/`):**
  - `core/`: `constants.dart`, `theme.dart` (Light & Dark Material 3 theme), `sms_utils.dart` (GSM-7/UCS-2 estimator & E.164/Indian validator), `platform_bridge.dart`
  - `models/`: `sms_models.dart`
  - `services/`: `api_service.dart`, `websocket_service.dart`
  - `widgets/`: `common_components.dart`, `app_drawer.dart`
  - `screens/`: `splash_screen.dart`, `login_screen.dart`, `forgot_password_screen.dart`, `otp_verification_screen.dart`, `reset_password_screen.dart`, `main_navigation_shell.dart`, `dashboard_screen.dart`, `sim_config_screen.dart`, `send_sms_screen.dart`, `logs_screen.dart`, `message_details_screen.dart`, `monitoring_screen.dart`, `settings_screen.dart`, `automation_rules_screen.dart`, `message_templates_screen.dart`, `diagnostics_screen.dart`, `device_info_screen.dart`, `privacy_policy_screen.dart`
- **Native Android Kotlin Engine (`android/app/src/main/kotlin/com/shamiit/shamiit_sms_gateway/`):**
  - `telephony/sim/`: `SimModels.kt`, `SimManager.kt` (`SubscriptionManager` + `TelephonyManager` discovery, `OnSubscriptionsChangedListener`, conflict resolution)
  - `telephony/sender/`: `SmsValidator.kt`, `SmsSender.kt` (`SmsManager.createForSubscriptionId` / `getSmsManagerForSubscriptionId`, multipart splitting, unique `PendingIntent` per part)
  - `telephony/delivery/`: `SmsDeliveryTracker.kt` (`SmsSentReceiver`, `SmsDeliveredReceiver`, `SmsDeliveryStateMachine`)
  - `telephony/receiver/`: `SmsPduParser.kt`, `SmsReceiver.kt` (`SMS_RECEIVED` BroadcastReceiver persisting immediately to SQLite before WorkManager upload)
  - `telephony/diagnostics/`: `SmsPermissionManager.kt`, `TelephonyDiagnostics.kt`, `ContactsHelper.kt`
  - `storage/`: `SmsGatewayDatabaseHelper.kt` (local SQLite tables with idempotent sync & protected `pending_uploads`)
  - `security/`: `SecureCredentialStore.kt` (Android Keystore `EncryptedSharedPreferences`)
  - `sync/` & `worker/`: `GatewaySyncEngine.kt`, `SmsSyncWorker`, `IncomingSmsUploadWorker`, `GatewayHeartbeatWorker`
  - `service/` & `receiver/`: `SmsGatewayForegroundService.kt`, `BootReceiver.kt`
  - `bridge/`: `SmsEventBus.kt`, `SmsGatewayChannel.kt`, `MainActivity.kt`

## 3. FastAPI Endpoints & Database Migration
- **Database Migration:** `EduSHAMIIT Database/edushamiit-db/migrations/589_sms_gateway.sql`
- **FastAPI Router:** `EduSHAMIIT Backend/backend/app/api/sms_gateway.py` mounted at `/api/v1` in `main.py`:
  - `POST /api/v1/device/register`, `POST /api/v1/device/heartbeat`, `POST /api/v1/device/token/renew`, `POST /api/v1/device/emergency-disable`
  - `GET /api/v1/device/jobs`, `POST /api/v1/device/events`, `POST /api/v1/device/inbound`, `POST /api/v1/device/sync`
  - `GET/PUT /api/v1/device/configuration`, `GET /api/v1/sms/sim-configuration`, `POST /api/v1/device/sim-configuration`
  - `POST /api/v1/sms/send`, `GET /api/v1/sms/history`, `GET /api/v1/sms/messages/{message_uuid}`, `GET /api/v1/sms/statistics`
  - `GET/POST/PUT/DELETE /api/v1/automation/rules`, `POST /api/v1/automation/rules/{id}/duplicate`, `POST /api/v1/automation/rules/{id}/test`, `POST /api/v1/automation/trigger`, `GET /api/v1/automation/rules/{id}/executions`
  - `GET/POST/PUT/DELETE /api/v1/templates`
  - `WS /api/v1/sms-gateway/ws`

## 4. Android Permissions, Background Restrictions & Distribution Policy
- **Runtime Permissions:** `SEND_SMS`, `RECEIVE_SMS`, `READ_PHONE_STATE`, `READ_PHONE_NUMBERS`, `POST_NOTIFICATIONS`. `READ_CONTACTS` is requested **only** when the administrator opens the Contacts picker.
- **Force-Stop Limitation:** Android OS blocks BroadcastReceivers and WorkManager jobs after a user force-stops an app until the user manually opens the app again. Keep battery optimization disabled and the Foreground Service active.
- **Google Play Policy vs. Enterprise Distribution:** Google Play restricts `SEND_SMS`/`RECEIVE_SMS` to default SMS handlers or pre-approved exemptions. Distribute internally via Managed Google Play / MDM / signed enterprise APK unless Google Play SMS declaration is approved.
