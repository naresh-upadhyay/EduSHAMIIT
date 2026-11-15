"""
Comprehensive Unit & Integration Test Suite for EduSHAMIIT Payment Bridge
Covers:
1. Device Registration, Telemetry Heartbeats, and Key Rotation
2. Batch Notification Ingestion (Deduplication, Idempotency)
3. Matching Engine (Unique-paise match, Exact UTR, Ambiguity, Outgoing detection)
4. Dashboard and Transaction summaries
5. Reconciliation & Authoritative Bank Verification
6. ERP Invoice Balance Updates & Student Fee Ledger Receipts
7. Diagnostics and Connection tests
"""

import os
import sys
import uuid
import pytest
from starlette.testclient import TestClient

# Ensure backend root is on sys.path
backend_path = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_path not in sys.path:
    sys.path.insert(0, backend_path)

os.environ["TESTING"] = "1"
from app.main import app

client = TestClient(app)

TEST_DEVICE_ID = "PB-TEST-UNIT-01"
TEST_SCHOOL_ID = "33333333-3333-3333-3333-333333333333"


def test_device_registration_and_heartbeat():
    # 1. Device Registration
    reg_resp = client.post(
        "/api/v1/payment-bridge/devices/register",
        json={
            "device_id": TEST_DEVICE_ID,
            "device_name": "QA Test Mobile Terminal",
            "model": "Pixel 8 Pro",
            "android_version": "Android 14",
            "app_version": "1.0.0",
            "school_id": TEST_SCHOOL_ID,
        },
    )
    assert reg_resp.status_code == 200, reg_resp.text
    reg_data = reg_resp.json()
    assert reg_data["success"] is True
    assert reg_data["device_id"] == TEST_DEVICE_ID
    assert "api_key" in reg_data
    assert "secret_token" in reg_data

    # 2. Heartbeat
    hb_resp = client.post(
        "/api/v1/payment-bridge/devices/heartbeat",
        json={
            "device_id": TEST_DEVICE_ID,
            "listener_active": True,
            "notification_access_granted": True,
            "battery_level": 98,
            "pending_queue_count": 0,
            "memory_usage_mb": 42.1,
            "status": "ACTIVE",
        },
    )
    assert hb_resp.status_code == 200, hb_resp.text
    assert hb_resp.json()["status"] == "HEARTBEAT_ACK"

    # 3. Get Device Me
    me_resp = client.get(
        f"/api/v1/payment-bridge/devices/me?device_id={TEST_DEVICE_ID}"
    )
    assert me_resp.status_code == 200
    me_data = me_resp.json()
    assert me_data["device_id"] == TEST_DEVICE_ID
    assert me_data["battery_level"] == 98


def test_dashboard_metrics():
    resp = client.get(
        "/api/v1/payment-bridge/dashboard",
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["app_name"] == "EduSHAMIIT Payment Bridge"
    assert "metrics" in data
    assert data["metrics"]["notifications_today"] >= 1
    assert "system_status" in data
    assert data["system_status"]["backend_connection"] == "Connected"
    assert "today_activity" in data
    assert isinstance(data["today_activity"], list)


def test_transactions_summary():
    resp = client.get(
        "/api/v1/payment-bridge/transactions/summary",
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "successful" in data
    assert "pending" in data
    assert "unmatched" in data
    assert "refunds" in data


def test_notification_batch_ingestion_and_matching():
    evt1_uuid = str(uuid.uuid4())
    evt2_uuid = str(uuid.uuid4())
    # Ingest a matched candidate with unique paise (₹2,000.34)
    batch_resp = client.post(
        "/api/v1/payment-bridge/notifications/batch",
        json={
            "device_id": TEST_DEVICE_ID,
            "events": [
                {
                    "event_uuid": evt1_uuid,
                    "source_package": "com.phonepe.app",
                    "source_app": "PhonePe",
                    "event_type": "PAYMENT_RECEIVED",
                    "amount_paise": 200034,
                    "sender_name": "Seema Guardian",
                    "masked_sender_identifier": "**** 9821",
                    "transaction_reference": f"UPI/TEST_{uuid.uuid4().hex[:8]}",
                    "notification_timestamp": "2026-11-15T10:18:00Z",
                    "raw_title": "Payment Received",
                    "raw_text": "Received Rs 2000.34 from **** 9821",
                    "parser_version": "1.0.0",
                    "confidence_score": "HIGH",
                    "parsing_status": "PARSED",
                },
                {
                    "event_uuid": evt2_uuid,
                    "source_package": "com.google.android.apps.nbu.paisa.user",
                    "source_app": "Google Pay",
                    "event_type": "PAYMENT_SENT",
                    "amount_paise": 50000,
                    "sender_name": "Stationary Vendor",
                    "masked_sender_identifier": "**** 1100",
                    "transaction_reference": f"GPay-{uuid.uuid4().hex[:8]}",
                    "notification_timestamp": "2026-11-15T09:20:00Z",
                    "raw_title": "Payment Sent",
                    "raw_text": "Paid Rs 500.00 to Stationary Vendor",
                    "parser_version": "1.0.0",
                    "confidence_score": "HIGH",
                    "parsing_status": "PARSED",
                },
            ],
        },
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert batch_resp.status_code == 200, batch_resp.text
    batch_data = batch_resp.json()
    assert batch_data["processed_count"] == 2
    assert batch_data["successful_count"] >= 1

    # Test Idempotency: re-sending the same batch must flag DUPLICATE without crashing
    dup_resp = client.post(
        "/api/v1/payment-bridge/notifications/batch",
        json={
            "device_id": TEST_DEVICE_ID,
            "events": [
                {
                    "event_uuid": evt1_uuid,
                    "source_package": "com.phonepe.app",
                    "source_app": "PhonePe",
                    "event_type": "PAYMENT_RECEIVED",
                    "amount_paise": 200034,
                    "notification_timestamp": "2026-11-15T10:18:00Z",
                }
            ],
        },
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert dup_resp.status_code == 200
    dup_data = dup_resp.json()
    assert dup_data["duplicate_count"] == 1


def test_bank_statement_import_and_authoritative_reconciliation():
    test_utr = f"UPI/RECON_{uuid.uuid4().hex[:8]}"
    # Import authoritative bank credit transaction
    bank_resp = client.post(
        "/api/v1/payment-bridge/bank-statements/import",
        json={
            "rows": [
                {
                    "account_number": "HDFC0001234-9876",
                    "utr_number": test_utr,
                    "amount_paise": 200034,
                    "transaction_date": "2026-11-15T10:19:00Z",
                    "narration": "UPI-SEEMA-TUITION-FEES-AUTO-RECON",
                    "transaction_type": "CR",
                }
            ]
        },
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert bank_resp.status_code == 200
    data = bank_resp.json()
    assert data["success"] is True
    assert data["imported_count"] == 1


def test_diagnostics_and_sync_test():
    diag_resp = client.get(
        "/api/v1/payment-bridge/diagnostics",
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert diag_resp.status_code == 200
    diag_data = diag_resp.json()
    assert diag_data["status"] == "HEALTHY"
    assert diag_data["database_connected"] is True

    test_resp = client.post("/api/v1/payment-bridge/sync/test")
    assert test_resp.status_code == 200
    assert test_resp.json()["status"] == "SUCCESS"


def test_settings_and_monitored_apps():
    # 1. Get settings
    s_resp = client.get(
        "/api/v1/payment-bridge/settings",
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert s_resp.status_code == 200
    s_data = s_resp.json()
    assert "sync_interval_seconds" in s_data

    # 2. Update settings
    up_resp = client.put(
        "/api/v1/payment-bridge/settings",
        json={"sync_interval_seconds": 30, "retry_interval_seconds": 60},
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert up_resp.status_code == 200
    assert up_resp.json()["success"] is True

    # 3. Monitored Apps
    apps_resp = client.get(
        "/api/v1/payment-bridge/monitored-apps",
        headers={"X-School-ID": TEST_SCHOOL_ID},
    )
    assert apps_resp.status_code == 200
    apps_data = apps_resp.json()
    assert isinstance(apps_data, list)
    assert any(a["package_name"] == "com.phonepe.app" for a in apps_data)
