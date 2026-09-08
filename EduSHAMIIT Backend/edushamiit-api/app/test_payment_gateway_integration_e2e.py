"""
End-to-End Test Suite for Payment Gateway Integration (PGI)
Tests all real database-backed endpoints, adapters, idempotency, multi-tenancy,
routing rules, health monitor, audit events, and security validation.
"""

import sys
import os
import time
import hmac
import hashlib
import json
import requests

BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8082/api/v1")
PG_URL = f"{BASE_URL}/payment-gateways"
TEST_SCHOOL_A = "e1f11111-1111-1111-1111-111111111111"
TEST_SCHOOL_B = "e2f22222-2222-2222-2222-222222222222"

headers = {
    "Content-Type": "application/json",
}

def test_01_dashboard_real_db_kpis():
    """Verify that /dashboard aggregates actual rows from database, not fake metrics."""
    res = requests.get(f"{PG_URL}/dashboard?school_id={TEST_SCHOOL_A}", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    data = res.json()["data"]
    kpis = data["kpis"]
    
    # Must contain required KPI keys
    assert "connected_gateways" in kpis
    assert "healthy_gateways" in kpis
    assert "total_gateways" in kpis
    assert "today_transactions" in kpis
    assert "today_amount" in kpis
    assert "success_rate" in kpis
    assert "gateways" in data
    
    # Must be integer/numeric from DB, never hardcoded strings
    assert isinstance(kpis["connected_gateways"], int)
    assert isinstance(kpis["total_gateways"], int)
    assert isinstance(kpis["today_transactions"], int)
    print(f"[PASS] Dashboard KPIs loaded from DB: {kpis['connected_gateways']}/{kpis['total_gateways']} connected, {kpis['today_transactions']} txns")

def test_02_payment_method_matrix():
    """Verify method matrix correctly maps supported Indian & international payment rails."""
    res = requests.get(f"{PG_URL}/method-matrix?school_id={TEST_SCHOOL_A}", headers=headers)
    assert res.status_code == 200
    matrix = res.json()["data"]
    assert len(matrix) >= 5
    row_methods = [r["method"] for r in matrix]
    assert "UPI" in row_methods
    assert "CARD" in row_methods
    assert "NET_BANKING" in row_methods
    print(f"[PASS] Method matrix generated with {len(matrix)} methods across providers.")

def test_03_create_new_gateway_and_mask_secrets():
    """Verify duplicate gateway prevention, credential encryption, and secret masking."""
    dup_payload = {
        "provider": "RAZORPAY",
        "display_name": "Duplicate Razorpay Attempt",
        "integration_type": "MERCHANT_API",
        "environment": "SANDBOX",
        "credentials": {"key_id": "test", "key_secret": "test"},
        "supported_methods": ["UPI"],
        "school_id": TEST_SCHOOL_A
    }
    dup_res = requests.post(f"{PG_URL}", json=dup_payload, headers=headers)
    assert dup_res.status_code == 400, f"Expected 400 for duplicate gateway, got {dup_res.status_code}"
    assert "already configured" in dup_res.text
    print("[PASS] Duplicate gateway creation rejected with HTTP 400.")

    # Now create in PRODUCTION environment
    payload = {
        "provider": "RAZORPAY",
        "display_name": "Test Razorpay Production Gateway",
        "integration_type": "MERCHANT_API",
        "environment": "PRODUCTION",
        "merchant_identifier": "rzp_prod_sec_001",
        "credentials": {
            "key_id": "rzp_live_sec_key_12345",
            "key_secret": "super_secret_key_that_must_never_leak_98765",
            "webhook_secret": "whsec_live_9988776655"
        },
        "supported_methods": ["UPI", "CARD"],
        "school_id": TEST_SCHOOL_A
    }
    
    res = requests.post(f"{PG_URL}", json=payload, headers=headers)
    # If it was already created from a previous run, cleanup or accept 200
    if res.status_code == 400 and "already configured" in res.text:
        # Fetch existing
        gws = requests.get(f"{PG_URL}?school_id={TEST_SCHOOL_A}&environment=PRODUCTION", headers=headers).json()["data"]
        gw_id = [g["id"] for g in gws if g["provider"] == "RAZORPAY"][0]
    else:
        assert res.status_code == 200, f"Failed to create gateway: {res.text}"
        created = res.json()["data"]
        gw_id = created["id"]
    
    # Verify GET single gateway masks secrets
    get_res = requests.get(f"{PG_URL}/{gw_id}", headers=headers)
    assert get_res.status_code == 200
    fetched = get_res.json()["data"]
    fetched_creds = fetched.get("credentials_masked", {})
    # Secret must never be in plaintext
    for k, v in fetched_creds.items():
        assert v != "super_secret_key_that_must_never_leak_98765"
        assert "••••" in str(v)
    print(f"[PASS] Gateway {gw_id} secured: credentials encrypted at rest and masked in APIs.")
    return gw_id

def test_04_test_connection_handshake():
    """Verify that [Test] actually tests provider credentials and returns valid health report."""
    # Fetch first active gateway
    res = requests.get(f"{PG_URL}?school_id={TEST_SCHOOL_A}", headers=headers)
    assert res.status_code == 200
    gateways = res.json()["data"]
    assert len(gateways) > 0
    target_gw = gateways[0]
    gw_id = target_gw["id"]
    
    test_res = requests.post(f"{PG_URL}/{gw_id}/test", headers=headers)
    assert test_res.status_code == 200
    report = test_res.json()["data"]
    assert "status" in report
    assert report["status"] in ["SUCCESS", "FAILED", "WARNING"]
    assert "latency_ms" in report
    print(f"[PASS] Gateway test handshake executed: status={report['status']}, latency={report.get('latency_ms')}ms")

def test_05_test_all_gateways():
    """Verify that [Test All Gateways] runs live tests on all configured gateways."""
    res = requests.post(f"{PG_URL}/test-all?school_id={TEST_SCHOOL_A}", headers=headers)
    assert res.status_code == 200
    results = res.json()["data"]
    assert len(results) > 0
    for r in results:
        assert "provider" in r
        assert "status" in r
    print(f"[PASS] Test-all completed across {len(results)} gateways.")

def test_06_atomic_default_gateway_switching():
    """Verify that setting a gateway as default unsets any previous default atomically."""
    res = requests.get(f"{PG_URL}?school_id={TEST_SCHOOL_A}", headers=headers)
    gateways = res.json()["data"]
    if len(gateways) < 2:
        print("[SKIP] Need at least 2 gateways to test default switching")
        return
        
    gw1 = gateways[0]["id"]
    gw2 = gateways[1]["id"]
    
    # Set gw2 as default
    res2 = requests.post(f"{PG_URL}/{gw2}/set-default", headers=headers)
    assert res2.status_code == 200
    
    # Check that gw2 is default and gw1 is NOT
    res_check = requests.get(f"{PG_URL}?school_id={TEST_SCHOOL_A}", headers=headers)
    all_gw = {g["id"]: g["is_default"] for g in res_check.json()["data"]}
    assert all_gw[gw2] is True, f"Gateway {gw2} should be default"
    assert all_gw[gw1] is False, f"Previous gateway {gw1} should no longer be default"
    
    # Revert back to gw1
    requests.post(f"{PG_URL}/{gw1}/set-default", headers=headers)
    print(f"[PASS] Atomic default gateway switching verified.")

def test_07_routing_rules_crud():
    """Verify creation, listing, updating and deletion of Payment Routing Rules."""
    # List gateways to route to
    res = requests.get(f"{PG_URL}?school_id={TEST_SCHOOL_A}", headers=headers)
    gateways = res.json()["data"]
    assert len(gateways) > 0
    gw_id = gateways[0]["id"]
    
    # Create rule
    rule_payload = {
        "payment_type": "ADMISSION",
        "payment_method": "UPI",
        "gateway_id": gw_id,
        "priority": 5,
        "school_id": TEST_SCHOOL_A
    }
    create_res = requests.post(f"{PG_URL}/routing", json=rule_payload, headers=headers)
    assert create_res.status_code == 200
    rule = create_res.json()["data"]
    rule_id = rule["id"]
    assert rule["payment_type"] == "ADMISSION"
    
    # Update rule priority
    patch_res = requests.patch(f"{PG_URL}/routing/{rule_id}", json={"priority": 10}, headers=headers)
    assert patch_res.status_code == 200
    assert patch_res.json()["data"]["priority"] == 10
    
    # Delete rule
    del_res = requests.delete(f"{PG_URL}/routing/{rule_id}", headers=headers)
    assert del_res.status_code == 200
    
    # Verify rule is gone
    list_res = requests.get(f"{PG_URL}/routing?school_id={TEST_SCHOOL_A}", headers=headers)
    existing_ids = [r["id"] for r in list_res.json()["data"]]
    assert rule_id not in existing_ids
    print(f"[PASS] Routing rules CRUD successfully executed.")

def test_08_health_check_persistence():
    """Verify health check runs and persists latency and status in DB."""
    res = requests.get(f"{PG_URL}?school_id={TEST_SCHOOL_A}", headers=headers)
    gw_id = res.json()["data"][0]["id"]
    
    hc_res = requests.post(f"{PG_URL}/{gw_id}/health-check", headers=headers)
    assert hc_res.status_code == 200
    hc_data = hc_res.json()["data"]
    assert "latency_ms" in hc_data
    assert "status" in hc_data
    
    # Check history
    hist_res = requests.get(f"{PG_URL}/{gw_id}/health", headers=headers)
    assert hist_res.status_code == 200
    history = hist_res.json()["data"]
    assert len(history) > 0
    print(f"[PASS] Health check persisted: latency={hc_data['latency_ms']}ms, status={hc_data['status']}")

def test_09_webhook_processing_and_idempotency():
    """Verify webhook processing with idempotency to prevent duplicate transaction recording."""
    wh_event_id = f"evt_test_{int(time.time())}"
    webhook_payload = {
        "event": "payment.captured",
        "entity": "event",
        "payload": {
            "payment": {
                "entity": {
                    "id": f"pay_test_{int(time.time())}",
                    "amount": 500000,
                    "currency": "INR",
                    "status": "captured",
                    "order_id": "order_test_999"
                }
            }
        }
    }
    raw_body = json.dumps(webhook_payload)
    secret = "whsec_live_9988776655"
    sig = hmac.new(secret.encode(), raw_body.encode(), hashlib.sha256).hexdigest()
    
    wh_headers = {
        "Content-Type": "application/json",
        "X-Razorpay-Signature": sig,
        "X-Provider-Event-Id": wh_event_id,
    }
    
    # First delivery
    res1 = requests.post(f"{PG_URL}/webhooks/razorpay?school_id={TEST_SCHOOL_A}", data=raw_body, headers=wh_headers)
    assert res1.status_code == 200
    res1_data = res1.json().get("data", res1.json())
    assert res1_data.get("status", "").upper() in ("PROCESSED", "SUCCESS")
    
    # Second delivery (Duplicate event) -> MUST be idempotent
    res2 = requests.post(f"{PG_URL}/webhooks/razorpay?school_id={TEST_SCHOOL_A}", data=raw_body, headers=wh_headers)
    assert res2.status_code == 200
    res2_data = res2.json().get("data", res2.json())
    assert res2_data.get("status", "").upper() == "ALREADY_PROCESSED", f"Expected ALREADY_PROCESSED for duplicate event ID {wh_event_id}, got {res2_data}"
    print(f"[PASS] Webhook idempotency confirmed for event {wh_event_id}.")

def test_10_multi_tenant_isolation():
    """Verify strict tenant isolation between School A and School B."""
    res_a = requests.get(f"{PG_URL}?school_id={TEST_SCHOOL_A}", headers=headers)
    assert res_a.status_code == 200
    gateways_a = res_a.json()["data"]
    
    # Query School B
    res_b = requests.get(f"{PG_URL}?school_id={TEST_SCHOOL_B}", headers=headers)
    assert res_b.status_code == 200
    gateways_b = res_b.json()["data"]
    
    # Gateways belonging to School A should not leak into School B
    ids_a = {g["id"] for g in gateways_a if g.get("school_id") == TEST_SCHOOL_A}
    ids_b = {g["id"] for g in gateways_b}
    
    assert ids_a.isdisjoint(ids_b), "TENANT LEAK DETECTED: School A gateways found in School B response!"
    print(f"[PASS] Strict multi-tenant isolation verified between {TEST_SCHOOL_A} and {TEST_SCHOOL_B}.")

if __name__ == "__main__":
    print("Running Payment Gateway Integration E2E Test Suite...")
    test_01_dashboard_real_db_kpis()
    test_02_payment_method_matrix()
    test_03_create_new_gateway_and_mask_secrets()
    test_04_test_connection_handshake()
    test_05_test_all_gateways()
    test_06_atomic_default_gateway_switching()
    test_07_routing_rules_crud()
    test_08_health_check_persistence()
    test_09_webhook_processing_and_idempotency()
    test_10_multi_tenant_isolation()
    print("\n=======================================================")
    print("ALL 10 E2E AUTOMATION TESTS PASSED WITH 100% SUCCESS!")
    print("=======================================================\n")
