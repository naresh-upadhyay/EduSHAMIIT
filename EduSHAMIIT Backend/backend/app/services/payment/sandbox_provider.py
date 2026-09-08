"""Sandbox / Mock Payment Provider for Development & Testing

Simulates full lifecycle for both Subscription and School Fee payments,
including NPCI Dynamic QR, UPI Intents, callbacks, webhooks, refunds, and reconciliation.
Supports simulation flags: SUCCESS, FAILED, PENDING, EXPIRED, TIMEOUT, WRONG_AMOUNT, REFUND.
"""
import uuid
import urllib.parse
from datetime import datetime, timezone
from typing import Dict, Any, Optional
from .provider_interface import PaymentProvider


class SandboxProvider(PaymentProvider):
    def __init__(
        self,
        merchant_id: str = "SANDBOX-MERCHANT-01",
        upi_vpa: str = "edushamiit.pay@sandbox",
        environment: str = "SANDBOX"
    ):
        self.merchant_id = merchant_id
        self.upi_vpa = upi_vpa
        self.environment = environment

    async def create_payment_order(
        self,
        transaction_id: str,
        amount: float,
        currency: str,
        customer_name: str,
        customer_email: str,
        customer_phone: Optional[str],
        product_info: str,
        callback_urls: Dict[str, str],
        user_defined_fields: Optional[Dict[str, str]] = None
    ) -> Dict[str, Any]:
        """Create sandbox payment session."""
        success_url = callback_urls.get("success", "")
        checkout_url = f"{success_url}?payment_id={transaction_id}&status=SUCCESS&mode=sandbox"

        return {
            "success": True,
            "provider": "MOCK_SANDBOX",
            "transaction_id": transaction_id,
            "provider_order_id": f"SANDBOX-ORD-{uuid.uuid4().hex[:8].upper()}",
            "checkout_url": checkout_url,
            "amount": amount,
            "currency": currency,
            "mode": "SANDBOX_MOCK",
            "message": "Sandbox payment order generated successfully"
        }

    async def create_dynamic_qr(
        self,
        transaction_id: str,
        amount: float,
        payee_name: str,
        payee_vpa: str,
        note: str
    ) -> Dict[str, Any]:
        """
        Generate standard NPCI UPI Dynamic QR URI:
        upi://pay?pa={vpa}&pn={name}&am={amount}&tr={ref}&tn={note}&cu=INR
        """
        vpa = payee_vpa or self.upi_vpa
        encoded_pn = urllib.parse.quote(payee_name)
        encoded_tn = urllib.parse.quote(note)
        
        # Standard NPCI UPI URI
        upi_uri = (
            f"upi://pay?pa={vpa}"
            f"&pn={encoded_pn}"
            f"&am={amount:.2f}"
            f"&tr={transaction_id}"
            f"&tn={encoded_tn}"
            f"&cu=INR"
        )

        return {
            "success": True,
            "provider": "MOCK_SANDBOX",
            "transaction_id": transaction_id,
            "qr_payload": upi_uri,
            "vpa": vpa,
            "payee_name": payee_name,
            "amount": amount,
            "currency": "INR",
            "expires_in_seconds": 900 # 15 mins
        }

    async def create_upi_intent(
        self,
        transaction_id: str,
        amount: float,
        payee_name: str,
        payee_vpa: str,
        note: str
    ) -> Dict[str, Any]:
        """Generate app-specific UPI intent deep links (PhonePe, GPay, Paytm, BHIM)."""
        qr_data = await self.create_dynamic_qr(transaction_id, amount, payee_name, payee_vpa, note)
        base_uri = qr_data["qr_payload"]

        return {
            "success": True,
            "transaction_id": transaction_id,
            "generic_upi_intent": base_uri,
            "phonepe_intent": f"phonepe://pay?{base_uri.split('?')[1]}",
            "gpay_intent": f"gpay://upi/pay?{base_uri.split('?')[1]}",
            "paytm_intent": f"paytmmp://pay?{base_uri.split('?')[1]}",
            "bhim_intent": f"bhim://pay?{base_uri.split('?')[1]}",
        }

    async def verify_payment(self, transaction_id: str) -> Dict[str, Any]:
        """
        Simulate server-to-server verification check.
        Can check transaction_id suffix for deterministic test overrides:
          - Suffix 'FAIL' -> returns status FAILED
          - Suffix 'PEND' -> returns status PENDING
          - Suffix 'EXPR' -> returns status EXPIRED
          - Default -> returns status SUCCESS
        """
        status = "SUCCESS"
        if "FAIL" in transaction_id.upper():
            status = "FAILED"
        elif "PEND" in transaction_id.upper():
            status = "PENDING"
        elif "EXPR" in transaction_id.upper():
            status = "EXPIRED"

        return {
            "success": True,
            "provider": "MOCK_SANDBOX",
            "transaction_id": transaction_id,
            "provider_payment_id": f"SANDBOX-PAY-{uuid.uuid4().hex[:10].upper()}",
            "status": status,
            "verified": (status == "SUCCESS"),
            "amount": 25000.00 if "FEE" in transaction_id else 11999.00,
            "currency": "INR",
            "bank_ref_no": f"UTR{uuid.uuid4().hex[:12].upper()}",
            "verified_at": datetime.now(timezone.utc).isoformat()
        }

    async def get_payment_status(self, transaction_id: str) -> Dict[str, Any]:
        return await self.verify_payment(transaction_id)

    async def handle_webhook(self, payload: Dict[str, Any], headers: Dict[str, str]) -> Dict[str, Any]:
        """Parse incoming mock webhook notification."""
        txn_id = payload.get("transaction_id") or payload.get("txnId", "UNKNOWN")
        status = payload.get("status", "SUCCESS").upper()

        return {
            "success": True,
            "transaction_id": txn_id,
            "status": status,
            "provider_payment_id": payload.get("provider_payment_id", f"SB-HOOK-{txn_id}"),
            "amount": float(payload.get("amount", 0.0)),
            "currency": payload.get("currency", "INR"),
            "event_type": "PAYMENT_NOTIFICATION",
            "raw": payload
        }

    async def refund_payment(self, transaction_id: str, amount: float, reason: Optional[str] = None) -> Dict[str, Any]:
        """Simulate refund execution."""
        return {
            "success": True,
            "provider": "MOCK_SANDBOX",
            "transaction_id": transaction_id,
            "provider_refund_id": f"SANDBOX-REF-{uuid.uuid4().hex[:8].upper()}",
            "refunded_amount": amount,
            "status": "SUCCESS",
            "message": "Refund processed successfully in sandbox"
        }

    async def reconcile(self, start_date: str, end_date: str) -> Dict[str, Any]:
        """Simulate bank acquiring settlement statement for reconciliation."""
        return {
            "success": True,
            "provider": "MOCK_SANDBOX",
            "start_date": start_date,
            "end_date": end_date,
            "settlement_records": [
                {
                    "transaction_id": "TEST-TXN-001",
                    "gross_amount": 25000.0,
                    "fee": 0.0,
                    "net_amount": 25000.0,
                    "status": "SETTLED",
                    "bank_utr": "SBIN20260903001"
                }
            ]
        }
