"""Cashfree Payment Gateway Provider (Stub for future expansion)

Designed to plug seamlessly into PaymentProvider architecture.
"""
from typing import Dict, Any, Optional
from .provider_interface import PaymentProvider

class CashfreeProvider(PaymentProvider):
    def __init__(self, client_id: Optional[str] = None, client_secret: Optional[str] = None, environment: str = "TEST"):
        self.client_id = client_id
        self.client_secret = client_secret
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
        raise NotImplementedError("CashfreeProvider will be enabled in a future release.")

    async def verify_payment(self, transaction_id: str) -> Dict[str, Any]:
        raise NotImplementedError("CashfreeProvider will be enabled in a future release.")

    async def get_payment_status(self, transaction_id: str) -> Dict[str, Any]:
        raise NotImplementedError("CashfreeProvider will be enabled in a future release.")

    async def handle_webhook(self, payload: Dict[str, Any], headers: Dict[str, str]) -> Dict[str, Any]:
        raise NotImplementedError("CashfreeProvider will be enabled in a future release.")

    async def refund_payment(self, transaction_id: str, amount: float, reason: Optional[str] = None) -> Dict[str, Any]:
        raise NotImplementedError("CashfreeProvider will be enabled in a future release.")
