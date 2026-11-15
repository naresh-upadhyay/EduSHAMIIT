# EduSHAMIIT Payment Bridge (Android UPI Listener & Reconciliation System)

**EduSHAMIIT Payment Bridge** is a dedicated enterprise Android application and backend reconciliation engine designed for educational institutions running the EduSHAMIIT School ERP. It runs on a dedicated school-controlled Android terminal, continuously listens to incoming UPI payment notifications (PhonePe, Google Pay, Paytm, BHIM, and other UPI applications), extracts payment metadata, safely buffers and deduplicates events in a local SQLite database, and synchronizes payment candidates with the EduSHAMIIT FastAPI backend and PostgreSQL ledger.

---

## 1. Core Financial Rule & Compliance Invariant

> [!IMPORTANT]
> **Android notifications are non-authoritative financial evidence.**
> Notifications can be delayed, dropped by battery optimizations, duplicated, spoofed, or modified.
> 
> Therefore:
> 1. A captured UPI notification creates a **Payment Candidate** (`AWAITING_VERIFICATION` or `REVIEW_REQUIRED`).
> 2. A notification **never independently confirms payment** and **never settles student invoice balances** on its own.
> 3. Student fee invoices (`student_fee_invoices`) are only settled and fee receipts (`student_fee_payments`) are only generated upon **Authoritative Bank Evidence** (e.g., approved Bank Statement CSV/XLSX import or authorized bank settlement webhook).
> 4. All financial calculations strictly use **integer paise arithmetic (`BIGINT`)**; floating-point representation is forbidden across all databases, APIs, models, and UI calculations.

---

## 2. Architecture & Components

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   DEDICATED INSTITUTION ANDROID DEVICE                           │
│                                                                                  │
│   [Installed UPI Apps]                                                           │
│   PhonePe / Google Pay / Paytm / BHIM                                            │
│            │                                                                     │
│            ▼ (Notification Access - BIND_NOTIFICATION_LISTENER_SERVICE)          │
│   ┌────────────────────────────────────────────────────────────────────────┐     │
│   │ Native Kotlin Android Service (Runs in background 24/7)                │     │
│   │  • PaymentNotificationListenerService                                  │     │
│   │  • Regex Parsers (PhonePe, Google Pay, Paytm, BHIM, Generic UPI)       │     │
│   │  • PII Masking (Sender phone/VPA -> **** 9821)                         │     │
│   │  • Local SQLite Queue (payment_bridge.db) with SHA-256 Deduplication   │     │
│   │  • SyncManager (WorkManager / Interval sync with exponential backoff)  │     │
│   │  • BootReceiver (Reboots automatically on system restart)              │     │
│   └────────────────────────────────┬───────────────────────────────────────┘     │
│                                    │ MethodChannel                               │
│   ┌────────────────────────────────▼───────────────────────────────────────┐     │
│   │ Flutter Mobile Application (Material 3 Theme)                          │     │
│   │  • Dashboard: Running status, active toggle, metrics, system status    │     │
│   │  • Notifications: Filtered list (All, Matched, Unmatched, Ignored)     │     │
│   │  • Transactions: Successful, Pending, Unmatched, Refunds               │     │
│   │  • Transaction Details: Hero status, Student, Invoice, Breakdown, UTR  │     │
│   │  • Settings: Monitored apps, backend config, sync intervals            │     │
│   │  • Diagnostics: Service health, battery optimization, queue status     │     │
│   └────────────────────────────────┬───────────────────────────────────────┘     │
└────────────────────────────────────┼─────────────────────────────────────────────┘
                                     │ HTTPS / WSS
                                     ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   EduSHAMIIT FASTAPI BACKEND (Python 3.12)                       │
│                                                                                  │
│   • /api/v1/payment-bridge/ingest/notifications (Batch ingestion & SHA-256 dedup)│
│   • /api/v1/payment-bridge/candidate-matcher (Matches payment intent / amount)   │
│   • /api/v1/payment-bridge/reconciliation (Unmatched & Review Required triage)   │
│   • /api/v1/payment-bridge/bank/import-statement (Authoritative bank evidence)   │
│   • /api/v1/payment-bridge/ws (Live WebSocket updates to terminals)              │
│   • Multi-Tenant Isolation: Enforced via institutional X-School-ID / JWT         │
└────────────────────────────────────┬─────────────────────────────────────────────┘
                                     │ PostgreSQL (Port 54322)
                                     ▼
┌──────────────────────────────────────────────────────────────────────────────────┐
│                   POSTGRESQL DATABASE (Migration 513)                            │
│                                                                                  │
│   • payment_bridge_devices: Terminal registration, tokens, heartbeat             │
│   • payment_bridge_notifications: Ingested events, raw payloads, dedup hashes    │
│   • payment_bridge_transactions: Financial ledger, paise amounts, audit trail    │
│   • payment_bridge_monitored_apps: Whitelisted UPI package names & rules         │
│   • student_fee_invoices / student_fee_payments: Authoritative ERP fee ledger    │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. UI Design System & Screens

The application UI strictly matches the EduSHAMIIT brand styling:
- **Palette**: Deep Navy (`#003F9E`), Bright Primary Blue (`#0B63F6`), Light Ice Blue Background (`#F4F7FC`), Success Green (`#10A352`), Warning Orange (`#E67E22`), Pending Blue (`#2980B9`), Refund Purple (`#8E44AD`).

### Screen Directory:
1. **Dashboard (`lib/screens/dashboard_screen.dart`)**:
   - Header with EduSHAMIIT brand, QR icon, and green "Running" status pill.
   - Master "Payment Listener Active" card with immediate toggle.
   - 4 Top Metric Cards: Notifications Today (42), Matched Payments (38), Unmatched Payments (2), Last Sync (10:24 AM).
   - System Status Checklist: Notification Access, Monitored UPI Apps (2 Apps), Backend Connection, Device Registration, Data Sync.
   - Today's Activity timeline with real-time updates and "Sync Now" action button.
2. **Notifications (`lib/screens/notifications_screen.dart`)**:
   - Filter chips: `All (42)`, `Matched (38)`, `Unmatched (2)`, `Ignored (2)`.
   - Date-grouped cards with UPI app icon, timestamp, masked sender (`**** 9821`), UTR reference, and candidate status badge.
3. **Transactions (`lib/screens/transactions_screen.dart`)**:
   - Filter chips: `All`, `Successful`, `Pending`, `Unmatched`, `Refunds`.
   - 4 Top Summary Counters: Successful (38), Pending (3), Unmatched (2), Refunds (1).
   - Search by student name, invoice number, or UTR reference.
4. **Transaction Details (`lib/screens/transaction_details_screen.dart`)**:
   - Hero Card with large green checkmark, "Payment Successful", amount in bold (`₹2,000.34`), and status caption.
   - Detail rows: Student (Seema >), Invoice (`INV-1042 / Annual Tuition Fee`), Payment Mode (`UPI (PhonePe)`), UTR Reference (`UPI/438729106731` with copy), Received At, Matched At, Payment Intent (`EDU202611140042` with copy).
   - Amount Breakdown Card: Base Fee (`₹2,000.00`), Reconciliation Excess (`₹0.34`), Total Received (`₹2,000.34`).
   - Action Buttons: "View Student Receipt" (opens fee receipt modal) and "Reconciliation History" (opens immutable audit trail).
5. **Settings (`lib/screens/settings_screen.dart`)**:
   - Notification Listener: Access ("Granted >"), Service ("Running >"), Auto Start on Boot toggle.
   - Monitored UPI Applications: PhonePe toggle, Google Pay toggle, "+ Add UPI App" modal.
   - Backend Configuration: Server URL, Device ID (`PB-AND-001` with copy), Institution (`Greenwood High School`), Test Connection ping button.
   - Processing Settings: Sync Interval (30s), Retry on Failure (1m), Duplicate Detection Window (5m).
6. **Diagnostics (`lib/screens/diagnostics_screen.dart`)**:
   - Real-time hardware diagnostics: Battery optimization exemption, local SQLite queue count, API ping latency, simulated notification trigger.

---

## 4. Native Kotlin Notification Listener

Located in `android/app/src/main/kotlin/com/shamiit/payment_bridge/`:
- **`notification/PaymentNotificationListenerService.kt`**:
  - Extends Android's `NotificationListenerService`.
  - Filters notifications by whitelisted packages (`com.phonepe.app`, `com.google.android.apps.nbu.paisa.user`, `net.one97.paytm`, `in.org.npci.upiapp`).
  - Ignores internal system notifications, ongoing progress bars, and zero-amount/promotional alerts.
- **`parser/`**:
  - `PhonePeNotificationParser.kt`: Extracts amount from formats like `Received ₹2,000.34 from Seema UPI Ref: 438729106731`.
  - `GooglePayNotificationParser.kt`: Extracts amount and sender from Google Pay transaction notifications.
  - `PaytmNotificationParser.kt`: Extracts Paytm UPI payments.
  - `BhimNotificationParser.kt`: Extracts NPCI BHIM transfers.
  - `GenericUpiNotificationParser.kt`: Fallback regex matcher for third-party bank UPI applications.
- **`storage/PaymentDatabaseHelper.kt`**:
  - SQLite database (`payment_bridge.db`) with tables `notification_events` and `sync_queue`.
  - Enforces local duplicate rejection based on `event_hash = SHA256(package + title + text + amount + timestamp_window)`.
- **`sync/SyncManager.kt`**:
  - Batches pending events and transmits to `/api/v1/payment-bridge/ingest/notifications`.
  - Automatically retries on network failures with exponential backoff.
- **`receiver/BootReceiver.kt`**:
  - Re-initializes background sync and listener service after Android OS reboot.

---

## 5. FastAPI Backend Integration

Located in `EduSHAMIIT Backend/backend/app/api/payment_bridge.py`:
- **Ingestion**:
  - `POST /api/v1/payment-bridge/ingest/notifications`: Ingests notification batches, computes SHA-256 deduplication hashes, matches candidates with open fee invoices, and broadcasts real-time events over WebSocket.
- **Reconciliation & Candidate Matching**:
  - `POST /api/v1/payment-bridge/reconciliation/match`: Manually pairs an unmatched or review-required notification with a student invoice.
  - `POST /api/v1/payment-bridge/reconciliation/ignore`: Marks false alerts or promotional messages as ignored.
- **Authoritative Settlement**:
  - `POST /api/v1/payment-bridge/bank/import-statement`: Ingests authoritative bank statement CSV data. When a bank transaction matches a candidate's UTR, it transitions status to `VERIFIED_SUCCESS`, deducts `student_fee_invoices.paid_amount_paise`, and inserts an official record into `student_fee_payments`.
- **Device Management**:
  - `POST /api/v1/payment-bridge/devices/register`
  - `POST /api/v1/payment-bridge/devices/heartbeat`
  - `GET /api/v1/payment-bridge/devices/me`
  - `POST /api/v1/payment-bridge/devices/{id}/rotate-secret`
  - `POST /api/v1/payment-bridge/devices/{id}/revoke`
- **Dashboard & Queries**:
  - `GET /api/v1/payment-bridge/dashboard`
  - `GET /api/v1/payment-bridge/transactions`
  - `GET /api/v1/payment-bridge/transactions/summary`
  - `GET /api/v1/payment-bridge/transactions/{id}`
  - `GET /api/v1/payment-bridge/settings`
  - `PUT /api/v1/payment-bridge/settings`
  - `GET /api/v1/payment-bridge/monitored-apps`
  - `GET /api/v1/payment-bridge/diagnostics`
  - `WS /api/v1/payment-bridge/ws`

---

## 6. PostgreSQL Database Migration

Located in `EduSHAMIIT Database/edushamiit-db/migrations/513_payment_bridge_system_and_reconciliation.sql`:
- Applied cleanly to PostgreSQL on port 54322.
- Creates:
  - `payment_bridge_devices`
  - `payment_bridge_monitored_apps`
  - `payment_bridge_notifications`
  - `payment_bridge_transactions`
  - `payment_bridge_reconciliation_audits`
  - `payment_bridge_settings`
- Includes Greenwood High School seed data (`33333333-3333-3333-3333-333333333333`), student profiles, sample invoices (`INV-1042`, `INV-1041`, `INV-1043`, `INV-1022`, `INV-1039`), whitelisted apps, and transactions.

---

## 7. Automated Test Suite

### Backend Test Suite (Pytest)
Located in `EduSHAMIIT Backend/backend/tests/test_payment_bridge_comprehensive.py`:
- Tests device registration, secret generation, and heartbeat.
- Tests notification batch ingestion and SHA-256 deduplication.
- Tests candidate matching with student fee invoices.
- Tests authoritative bank statement import and invoice balance settlement.
- Tests manual reconciliation and ignore workflows.
- Run via:
  ```bash
  python -m pytest "EduSHAMIIT Backend/backend/tests/test_payment_bridge_comprehensive.py" -v
  ```
  **Result:** 7 of 7 tests PASSED.

### Frontend Test Suite (Flutter Test)
Located in `edu_shamiit_payment_bridge/test/`:
- `payment_bridge_unit_test.dart`: Integer paise precision arithmetic, non-authoritative candidate invariant, metrics serialization, settings validation.
- `widget_test.dart`: Complete smoke test, dashboard layout, top 4 metrics, system status list, bottom navigation tab switching.
- Run via:
  ```bash
  flutter test -j 1
  ```
  **Result:** 6 of 6 tests PASSED.

---

## 8. Hardware & Device Setup Instructions

1. **Hardware Recommendation**:
   - Dedicated Android smartphone or tablet (Android 10+ / API 29+).
   - Insert institution SIM card associated with the bank UPI VPA.
   - Install official UPI applications (PhonePe, Google Pay, Paytm, BHIM) and register the school's merchant bank account.
2. **Application Installation**:
   - Install the EduSHAMIIT Payment Bridge APK on the terminal.
3. **Grant Android Permissions**:
   - Navigate to **Settings > Apps > Special App Access > Notification Access** and enable **EduSHAMIIT Payment Bridge**.
   - Navigate to **Battery > Battery Optimization** and select **Don't Optimize / Unrestricted** for EduSHAMIIT Payment Bridge.
4. **Pair Terminal with Institution**:
   - Open EduSHAMIIT Payment Bridge.
   - In Settings, configure Server URL and verify Device ID (`PB-AND-001`).
   - Tap "Test Connection" to establish initial handshake with the EduSHAMIIT FastAPI backend.
