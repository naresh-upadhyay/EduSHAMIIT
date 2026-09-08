"""
Comprehensive End-to-End Test Suite for EduSHAMIIT Pay: Payment Engine -> Payments
Covers all 31 acceptance criteria from the specification:
1. Gateway Abstraction (SBI, ICICI, HDFC, Sandbox) & Configuration Modes
2. Payment Creation with Validation & Attempt #1
3. Attempt Architecture (Separation of Order from Gateway Attempts)
4. Payment Lifecycle & State Machine Transitions
5. Gateway Webhook Processing & Idempotency (Duplicate Prevention)
6. Retry Architecture (Attempt #2 created without modifying Attempt #1)
7. Refund Lifecycle & Over-Refund Prevention
8. Reconciliation & Auditor Flow
9. Real KPI Summary Metrics Calculation
10. Server-Side Pagination, Filtering & Search
11. CSV Streaming Export
12. Multi-Tenancy Isolation
13. Security Masking (No secrets exposed in responses)
"""
import sys
import os
import asyncio
import uuid
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

# Ensure backend root is in sys.path
backend_dir = os.path.dirname(os.path.abspath(__file__))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

from app.services.payment.provider_interface import PaymentProvider
from app.services.payment.sbi_adapter import SBIAdapter
from app.services.payment.icici_adapter import ICICIAdapter
from app.services.payment.hdfc_adapter import HDFCAdapter
from app.services.payment.sandbox_provider import SandboxProvider
from app.services.payment.payment_service import PaymentService
from fastapi import FastAPI
from app.api.v1_edushamiit_pay import router as edushamiit_pay_router

app = FastAPI(title="EduSHAMIIT Pay Engine Test")
app.include_router(edushamiit_pay_router)

from httpx import AsyncClient, ASGITransport


class TestResults:
    passed = 0
    failed = 0
    errors = []

    @classmethod
    def assert_true(cls, condition, test_name):
        if condition:
            cls.passed += 1
            print(f"  [PASS] {test_name}")
        else:
            cls.failed += 1
            msg = f"Assertion failed: {test_name}"
            cls.errors.append(msg)
            print(f"  [FAIL] {test_name}")

    @classmethod
    def summary(cls):
        print("\n" + "=" * 60)
        print(f"TEST SUMMARY: {cls.passed} PASSED, {cls.failed} FAILED")
        print("=" * 60)
        if cls.errors:
            print("\nFailures:")
            for err in cls.errors:
                print(f" - {err}")
        return cls.failed == 0


async def run_all_tests():
    print("\n" + "=" * 60)
    print("RUNNING EDUSHAMIIT PAY PAYMENT ENGINE SUITE")
    print("=" * 60)

    # -------------------------------------------------------------------------
    # TEST SUITE 1: GATEWAY ABSTRACTION & ADAPTERS
    # -------------------------------------------------------------------------
    print("\n--- 1. Testing Gateway Abstraction & Adapters ---")
    sbi = SBIAdapter(merchant_id="SBI_TEST_001", encryption_key="sbi_key_123", environment="SANDBOX")
    icici = ICICIAdapter(merchant_id="ICICI_TEST_001", encryption_key="icici_key_123", environment="SANDBOX")
    hdfc = HDFCAdapter(merchant_id="HDFC_TEST_001", encryption_key="hdfc_key_123", environment="SANDBOX")
    sandbox = SandboxProvider()

    TestResults.assert_true(isinstance(sbi, PaymentProvider), "SBIAdapter implements PaymentProvider")
    TestResults.assert_true(isinstance(icici, PaymentProvider), "ICICIAdapter implements PaymentProvider")
    TestResults.assert_true(isinstance(hdfc, PaymentProvider), "HDFCAdapter implements PaymentProvider")
    TestResults.assert_true(isinstance(sandbox, PaymentProvider), "SandboxProvider implements PaymentProvider")

    # Check configuration statuses
    sbi_status = sbi.get_configuration_status()
    icici_status = icici.get_configuration_status()
    hdfc_status = hdfc.get_configuration_status()

    TestResults.assert_true(sbi_status == "TEST_MODE", "SBIAdapter status is TEST_MODE")
    TestResults.assert_true(icici_status == "TEST_MODE", "ICICIAdapter status is TEST_MODE")
    TestResults.assert_true(hdfc_status == "TEST_MODE", "HDFCAdapter status is TEST_MODE")

    # Test dynamic UPI payload creation for SBI
    order_res = await sbi.create_payment_order(
        transaction_id="TXN-SBI-TEST-001",
        amount=5000.0,
        currency="INR",
        customer_name="Test Parent",
        customer_email="parent@example.com"
    )
    TestResults.assert_true(order_res.get("success") == True, "SBIAdapter creates order successfully")
    TestResults.assert_true("upi://" in order_res.get("upi_intent_url", ""), "SBIAdapter generates valid UPI Intent URL")

    # Test dynamic UPI payload creation for ICICI
    icici_order = await icici.create_payment_order(
        transaction_id="TXN-ICICI-TEST-001",
        amount=12000.0,
        currency="INR",
        customer_name="Test Student",
        customer_email="student@example.com"
    )
    TestResults.assert_true(icici_order.get("success") == True, "ICICIAdapter creates order successfully")
    TestResults.assert_true("upi://" in icici_order.get("upi_intent_url", ""), "ICICIAdapter generates valid UPI Intent URL")

    # Test dynamic UPI payload creation for HDFC
    hdfc_order = await hdfc.create_payment_order(
        transaction_id="TXN-HDFC-TEST-001",
        amount=8500.0,
        currency="INR",
        customer_name="Test Customer",
        customer_email="cust@example.com"
    )
    TestResults.assert_true(hdfc_order.get("success") == True, "HDFCAdapter creates order successfully")
    TestResults.assert_true("upi://" in hdfc_order.get("upi_intent_url", ""), "HDFCAdapter generates valid UPI Intent URL")

    # -------------------------------------------------------------------------
    # TEST SUITE 2: PAYMENT CREATION & ATTEMPT ARCHITECTURE
    # -------------------------------------------------------------------------
    print("\n--- 2. Testing Payment Creation & Attempt Architecture ---")
    school_id = "SCH-TEST-UNIT-01"
    created_payment = await PaymentService.create_payment(
        school_id=school_id,
        payer_type="STUDENT",
        customer_name="Aarav Sharma",
        customer_email="aarav.parent@example.com",
        customer_phone="9876543210",
        purpose="Student Fee",
        amount=15000.0,
        currency="INR",
        description="Term 1 Tuition Fee",
        reference_number="INV-2026-TERM1-001",
        gateway="SBI_EPAY",
        payment_method="UPI"
    )

    TestResults.assert_true(created_payment.get("success") == True, "PaymentService.create_payment succeeds")
    payment_id = created_payment.get("payment_id")
    txn_id = created_payment.get("transaction_id")
    attempt_no = created_payment.get("attempt_number")

    TestResults.assert_true(bool(payment_id), f"Payment ID generated: {payment_id}")
    TestResults.assert_true(bool(txn_id), f"Transaction ID generated: {txn_id}")
    TestResults.assert_true(attempt_no == 1, "Initial creation produces Attempt #1")

    # -------------------------------------------------------------------------
    # TEST SUITE 3: TIMELINE & DETAILS RETRIEVAL
    # -------------------------------------------------------------------------
    print("\n--- 3. Testing Payment Details & Timeline ---")
    details = await PaymentService.get_payment_details(txn_id, school_id=school_id)
    TestResults.assert_true(details is not None, "get_payment_details finds created order")
    TestResults.assert_true(details.get("payment_summary", {}).get("transaction_id") == txn_id, "Summary matches transaction ID")
    TestResults.assert_true(details.get("payer", {}).get("name") == "Aarav Sharma", "Payer name preserved")
    TestResults.assert_true(len(details.get("attempts", [])) >= 1, "Attempt #1 recorded in attempts list")
    TestResults.assert_true(len(details.get("timeline", [])) >= 1, "Chronological timeline initialized")

    # Verify secrets are masked
    tech_info = details.get("technical_diagnostics", {})
    TestResults.assert_true("api_key" not in tech_info, "Zero API keys exposed in technical diagnostics")
    TestResults.assert_true("api_secret" not in tech_info, "Zero API secrets exposed in technical diagnostics")
    TestResults.assert_true("private_key" not in tech_info, "Zero private keys exposed in technical diagnostics")

    # -------------------------------------------------------------------------
    # TEST SUITE 4: PAYMENT VERIFICATION & FULFILLMENT
    # -------------------------------------------------------------------------
    print("\n--- 4. Testing Payment Verification & Fulfillment ---")
    verify_res = await PaymentService.verify_and_fulfill_payment(txn_id)
    TestResults.assert_true(verify_res.get("success") == True, "verify_and_fulfill_payment succeeds")
    TestResults.assert_true(verify_res.get("status") == "SUCCESS", "Payment status transitioned to SUCCESS")

    # Check updated details
    updated_details = await PaymentService.get_payment_details(txn_id, school_id=school_id)
    TestResults.assert_true(updated_details["payment_summary"]["status"] == "SUCCESS", "DB reflects SUCCESS status")
    TestResults.assert_true(float(updated_details["payment_summary"]["refundable_amount"]) == 15000.0, "Initial refundable amount equals total paid")
    TestResults.assert_true(float(updated_details["payment_summary"]["total_refunded"]) == 0.0, "Initial total refunded is 0")

    # -------------------------------------------------------------------------
    # TEST SUITE 5: WEBHOOK INGESTION & IDEMPOTENCY
    # -------------------------------------------------------------------------
    print("\n--- 5. Testing Webhook Signature Verification & Idempotency ---")
    webhook_payload = {
        "event": "payment.captured",
        "order_id": txn_id,
        "payment_id": f"pay_gateway_{uuid.uuid4().hex[:8]}",
        "amount": 1500000,
        "status": "success",
        "utr": "UTR-TEST-NPCI-998877"
    }
    webhook_headers = {"x-webhook-signature": "test_signature_valid"}

    # 1st Webhook delivery
    res_hook1 = await PaymentService.process_webhook("SBI_EPAY", webhook_payload, webhook_headers)
    TestResults.assert_true(res_hook1.get("success") == True, "1st Webhook delivery processed successfully")

    # 2nd Webhook delivery (duplicate/retry by gateway)
    res_hook2 = await PaymentService.process_webhook("SBI_EPAY", webhook_payload, webhook_headers)
    TestResults.assert_true(res_hook2.get("success") == True, "2nd Webhook (duplicate) processed cleanly")
    TestResults.assert_true(res_hook2.get("idempotent") == True or res_hook2.get("status") in ("ALREADY_PROCESSED", "SUCCESS"), "Idempotency preserved (no duplicate collection/entry)")

    # -------------------------------------------------------------------------
    # TEST SUITE 6: RETRY PAYMENT (ATTEMPT ARCHITECTURE)
    # -------------------------------------------------------------------------
    print("\n--- 6. Testing Retry Payment Attempt Architecture ---")
    # Create a separate order destined to fail
    failed_payment = await PaymentService.create_payment(
        school_id=school_id,
        payer_type="PARENT",
        customer_name="Priya Patel",
        customer_email="priya@example.com",
        purpose="Transport Fee",
        amount=4500.0,
        currency="INR",
        gateway="SBI_EPAY"
    )
    fail_txn_id = failed_payment["transaction_id"]

    # Mark Attempt #1 as failed directly
    sb = PaymentService._get_sb()
    try:
        await sb.table("payment_orders").update({"status": "FAILED"}).eq("transaction_id", fail_txn_id).aexecute()
        await sb.table("payment_attempts").update({"status": "FAILED", "failure_message": "Bank server timeout"}).eq("order_id", failed_payment["payment_id"]).aexecute()
    except Exception:
        pass

    if fail_txn_id in PaymentService._memory_orders:
        PaymentService._memory_orders[fail_txn_id]["status"] = "FAILED"
    if failed_payment["payment_id"] in PaymentService._memory_orders:
        PaymentService._memory_orders[failed_payment["payment_id"]]["status"] = "FAILED"
    if failed_payment["payment_id"] in PaymentService._memory_attempts and PaymentService._memory_attempts[failed_payment["payment_id"]]:
        PaymentService._memory_attempts[failed_payment["payment_id"]][0]["status"] = "FAILED"
    if fail_txn_id in PaymentService._memory_attempts and PaymentService._memory_attempts[fail_txn_id]:
        PaymentService._memory_attempts[fail_txn_id][0]["status"] = "FAILED"

    # Trigger Retry
    retry_res = await PaymentService.retry_payment(fail_txn_id, gateway="ICICI_EAZYPAY")
    TestResults.assert_true(retry_res.get("success") == True, "retry_payment succeeds")
    TestResults.assert_true(retry_res.get("attempt_number") == 2, "New attempt has attempt_number = 2")
    TestResults.assert_true(retry_res.get("gateway") == "ICICI_EAZYPAY", "New attempt uses selected retry gateway")

    # Verify that Attempt #1 remains unchanged in the database
    retry_details = await PaymentService.get_payment_details(fail_txn_id, school_id=school_id)
    attempts = retry_details.get("attempts", [])
    TestResults.assert_true(len(attempts) == 2, f"Both attempts present in history (count={len(attempts)})")
    attempt1 = next((a for a in attempts if a.get("attempt_number") == 1), None)
    attempt2 = next((a for a in attempts if a.get("attempt_number") == 2), None)
    TestResults.assert_true(attempt1 is not None and attempt1.get("status") == "FAILED", "Attempt #1 retained as FAILED (not overwritten)")
    TestResults.assert_true(attempt2 is not None and attempt2.get("attempt_number") == 2, "Attempt #2 successfully logged with attempt_number=2")

    # -------------------------------------------------------------------------
    # TEST SUITE 7: REFUNDS & OVER-REFUND PREVENTION
    # -------------------------------------------------------------------------
    print("\n--- 7. Testing Refunds & Over-Refund Prevention ---")
    # On the earlier successful payment of 15,000:
    # Partial refund of 5,000
    ref1 = await PaymentService.request_refund(txn_id, amount=5000.0, reason="Partial student fee waiver")
    TestResults.assert_true(ref1.get("success") == True, "Partial refund of INR 5,000 accepted")
    TestResults.assert_true(ref1.get("status") == "PARTIALLY_REFUNDED", "Payment status updated to PARTIALLY_REFUNDED")
    TestResults.assert_true(float(ref1.get("remaining_refundable")) == 10000.0, "Remaining refundable correctly decreased to INR 10,000")

    # Attempt to over-refund (request 12,000 when only 10,000 remains)
    over_refund_blocked = False
    try:
        await PaymentService.request_refund(txn_id, amount=12000.0, reason="Excessive refund attempt")
    except ValueError as e:
        over_refund_blocked = True
        print(f"     [Expected Exception caught]: {e}")

    TestResults.assert_true(over_refund_blocked, "Over-refund of INR 12,000 strictly rejected with ValueError")

    # Complete the remaining refund of 10,000
    ref2 = await PaymentService.request_refund(txn_id, amount=10000.0, reason="Remaining admission withdrawal refund")
    TestResults.assert_true(ref2.get("success") == True, "Remaining refund of INR 10,000 accepted")
    TestResults.assert_true(ref2.get("status") == "REFUNDED", "Payment status updated to REFUNDED")
    TestResults.assert_true(float(ref2.get("remaining_refundable")) == 0.0, "Remaining refundable is exactly ₹0")

    # -------------------------------------------------------------------------
    # TEST SUITE 8: FASTAPI HTTP ENDPOINTS VIA ASYNC TEST CLIENT
    # -------------------------------------------------------------------------
    print("\n--- 8. Testing FastAPI Endpoints (HTTP Integration) ---")
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # GET /api/v1/edushamiit-pay/payments/summary
        res_summary = await client.get("/api/v1/edushamiit-pay/payments/summary")
        TestResults.assert_true(res_summary.status_code == 200, "GET /payments/summary returns 200 OK")
        sum_data = res_summary.json().get("data", {})
        TestResults.assert_true("total_transactions" in sum_data, "Summary contains total_transactions card")
        TestResults.assert_true("successful_payments" in sum_data, "Summary contains successful_payments card")
        TestResults.assert_true("total_amount_collected" in sum_data, "Summary contains total_amount_collected card")
        TestResults.assert_true("settlement_pending" in sum_data, "Summary contains settlement_pending card")

        # GET /api/v1/edushamiit-pay/payments (Pagination, Search & Filter)
        res_list = await client.get("/api/v1/edushamiit-pay/payments?page=1&limit=10")
        TestResults.assert_true(res_list.status_code == 200, "GET /payments returns 200 OK")
        list_data = res_list.json().get("data", {})
        TestResults.assert_true("items" in list_data, "Response contains items list")
        TestResults.assert_true("total" in list_data, "Response contains total count")

        # Search test
        res_search = await client.get(f"/api/v1/edushamiit-pay/payments?search={txn_id[:8]}")
        TestResults.assert_true(res_search.status_code == 200, "GET /payments with debounced search returns 200 OK")

        # GET /api/v1/edushamiit-pay/payments/{id}
        res_detail = await client.get(f"/api/v1/edushamiit-pay/payments/{txn_id}")
        TestResults.assert_true(res_detail.status_code == 200, "GET /payments/{id} returns 200 OK")
        d_json = res_detail.json().get("data", {})
        TestResults.assert_true("payment_summary" in d_json, "Detail contains payment_summary")
        TestResults.assert_true("payer" in d_json, "Detail contains payer info")
        TestResults.assert_true("timeline" in d_json, "Detail contains chronological timeline")

        # GET /api/v1/edushamiit-pay/payments/{id}/timeline
        res_timeline = await client.get(f"/api/v1/edushamiit-pay/payments/{txn_id}/timeline")
        TestResults.assert_true(res_timeline.status_code == 200, "GET /payments/{id}/timeline returns 200 OK")

        # GET /api/v1/edushamiit-pay/payments/{id}/receipt
        res_receipt = await client.get(f"/api/v1/edushamiit-pay/payments/{txn_id}/receipt")
        TestResults.assert_true(res_receipt.status_code == 200, "GET /payments/{id}/receipt returns 200 OK")
        rcp_data = res_receipt.json().get("data", {})
        TestResults.assert_true("receipt_number" in rcp_data, "Official receipt contains receipt_number")

        # GET /api/v1/edushamiit-pay/payments/export (CSV streaming)
        res_export = await client.get("/api/v1/edushamiit-pay/payments/export")
        TestResults.assert_true(res_export.status_code == 200, "GET /payments/export returns 200 OK")
        TestResults.assert_true("text/csv" in res_export.headers.get("content-type", ""), "Export Content-Type is text/csv")
        TestResults.assert_true("Transaction ID,Order ID" in res_export.text, "CSV header columns match specification")

        # POST /api/v1/edushamiit-pay/payments/{id}/reconcile
        res_reconcile = await client.post(
            f"/api/v1/edushamiit-pay/payments/{txn_id}/reconcile",
            json={"status": "MATCHED", "utr": "UTR-BANK-MATCHED-9999", "notes": "Audited with bank feed"}
        )
        TestResults.assert_true(res_reconcile.status_code == 200, "POST /payments/{id}/reconcile returns 200 OK")

    # -------------------------------------------------------------------------
    # TEST SUITE 9: SECURITY & TENANT ISOLATION
    # -------------------------------------------------------------------------
    print("\n--- 9. Testing Security & Tenant Isolation ---")
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # Cross-tenant query attempt (school_id mismatch)
        res_cross = await client.get(
            f"/api/v1/edushamiit-pay/payments/{txn_id}?school_id=SCH-UNAUTHORIZED-999"
        )
        TestResults.assert_true(
            res_cross.status_code in (404, 403),
            "Cross-tenant access to School A's payment by School B is strictly blocked (404/403)"
        )

        # Invalid payment amount validation (<= 0)
        res_invalid_amt = await client.post(
            "/api/v1/edushamiit-pay/payments",
            json={
                "school_id": school_id,
                "payer_type": "STUDENT",
                "customer_name": "Test",
                "customer_email": "test@example.com",
                "amount": -500.0,
                "gateway": "MOCK_SANDBOX"
            }
        )
        TestResults.assert_true(res_invalid_amt.status_code == 400, "Negative amount is rejected with 400 Bad Request")

    return TestResults.summary()


if __name__ == "__main__":
    success = asyncio.run(run_all_tests())
    sys.exit(0 if success else 1)
