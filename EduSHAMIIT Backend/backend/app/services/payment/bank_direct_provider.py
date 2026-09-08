"""Bank-Direct Acquiring Provider Adapter Interface

Supports Bank Direct acquiring integrations (SBI ePay, ICICI Eazypay, HDFC SmartHub, Axis Bank).
Requires official bank merchant credentials and API specifications to operate in production.
Falls back safely to sandbox simulation in development.
"""
import urllib.parse
from typing import Dict, Any, Optional
from .provider_interface import PaymentProvider
from .sandbox_provider import SandboxProvider


class BankDirectProvider(PaymentProvider):
    """
    Standard interface adapter for Bank Direct acquiring APIs.
    Disallows unauthenticated fake production execution.
    """
    def __init__(
        self,
        bank_code: str = "SBI_EPAY", # 'SBI_EPAY', 'ICICI_EAZYPAY', 'HDFC_SMARTHUB', 'AXIS_BANK'
        merchant_id: Optional[str] = None,
        encryption_key: Optional[str] = None,
        upi_vpa: Optional[str] = None,
        environment: str = "SANDBOX"
    ):
        self.bank_code = bank_code.upper()
        self.merchant_id = merchant_id
        self.encryption_key = encryption_key
        self.upi_vpa = upi_vpa
        self.environment = environment
        self._fallback_sandbox = SandboxProvider(
            merchant_id=merchant_id or f"{self.bank_code}-MOCK",
            upi_vpa=upi_vpa or f"school@{self.bank_code.lower()}",
            environment="SANDBOX"
        )

    def is_configured_for_production(self) -> bool:
        """Check if production merchant credentials have been officially supplied."""
        return bool(self.merchant_id and self.encryption_key and self.environment == "PRODUCTION")

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
        if not self.is_configured_for_production():
            # In development or until official bank credentials are submitted, use sandbox simulation
            return await self._fallback_sandbox.create_payment_order(
                transaction_id, amount, currency, customer_name, customer_email, customer_phone, product_info, callback_urls, user_defined_fields
            )
        raise NotImplementedError(
            f"Production direct acquiring API for {self.bank_code} requires merchant onboarding approval from {self.bank_code}."
        )

    async def create_dynamic_qr(
        self,
        transaction_id: str,
        amount: float,
        payee_name: str,
        payee_vpa: str,
        note: str
    ) -> Dict[str, Any]:
        # NPCI UPI Dynamic QR URI works universally with any verified bank VPA
        vpa = payee_vpa or self.upi_vpa or f"school@{self.bank_code.lower()}"
        encoded_pn = urllib.parse.quote(payee_name)
        encoded_tn = urllib.parse.quote(note)
        
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
            "provider": self.bank_code,
            "transaction_id": transaction_id,
            "qr_payload": upi_uri,
            "vpa": vpa,
            "payee_name": payee_name,
            "amount": amount,
            "currency": "INR",
            "mode": "PRODUCTION" if self.is_configured_for_production() else "SANDBOX"
        }

    async def create_upi_intent(
        self,
        transaction_id: str,
        amount: float,
        payee_name: str,
        payee_vpa: str,
        note: str
    ) -> Dict[str, Any]:
        return await self._fallback_sandbox.create_upi_intent(
            transaction_id, amount, payee_name, payee_vpa, note
        )

    async def verify_payment(self, transaction_id: str) -> Dict[str, Any]:
        if not self.is_configured_for_production():
            return await self._fallback_sandbox.verify_payment(transaction_id)
        raise NotImplementedError(f"Direct bank query API for {self.bank_code} requires bank authorization.")

    async def get_payment_status(self, transaction_id: str) -> Dict[str, Any]:
        return await self.verify_payment(transaction_id)

    async def handle_webhook(self, payload: Dict[str, Any], headers: Dict[str, str]) -> Dict[str, Any]:
        return await self._fallback_sandbox.handle_webhook(payload, headers)

    async def refund_payment(self, transaction_id: str, amount: float, reason: Optional[str] = None) -> Dict[str, Any]:
        if not self.is_configured_for_production():
            return await self._fallback_sandbox.refund_payment(transaction_id, amount, reason)
        raise NotImplementedError(f"Direct refund API for {self.bank_code} requires bank authorization.")

    async def reconcile(self, start_date: str, end_date: str) -> Dict[str, Any]:
        return await self._fallback_sandbox.reconcile(start_date, end_date)
