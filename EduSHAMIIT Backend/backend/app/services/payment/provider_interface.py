"""Abstract Payment Provider Interface

Defines the universal contract for payment gateway & acquiring integrations
(Sandbox, PayU, Cashfree, Bank Direct ePay, etc.).
"""
from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List


class PaymentProvider(ABC):
    @abstractmethod
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
        """Create a payment request/order with the gateway and return checkout info."""
        pass

    @abstractmethod
    async def create_dynamic_qr(
        self,
        transaction_id: str,
        amount: float,
        payee_name: str,
        payee_vpa: str,
        note: str
    ) -> Dict[str, Any]:
        """Generate transaction-specific Dynamic NPCI UPI QR payload."""
        pass

    @abstractmethod
    async def create_upi_intent(
        self,
        transaction_id: str,
        amount: float,
        payee_name: str,
        payee_vpa: str,
        note: str
    ) -> Dict[str, Any]:
        """Generate UPI intent deep links for mobile devices (GPay, PhonePe, Paytm, BHIM)."""
        pass

    @abstractmethod
    async def verify_payment(self, transaction_id: str) -> Dict[str, Any]:
        """Verify transaction status with the provider's server-to-server API."""
        pass

    @abstractmethod
    async def get_payment_status(self, transaction_id: str) -> Dict[str, Any]:
        """Retrieve current provider status for a given transaction ID."""
        pass

    @abstractmethod
    async def handle_webhook(self, payload: Dict[str, Any], headers: Dict[str, str]) -> Dict[str, Any]:
        """Verify signature and parse incoming provider webhook notification."""
        pass

    @abstractmethod
    async def refund_payment(self, transaction_id: str, amount: float, reason: Optional[str] = None) -> Dict[str, Any]:
        """Initiate refund with provider."""
        pass

    @abstractmethod
    async def reconcile(self, start_date: str, end_date: str) -> Dict[str, Any]:
        """Retrieve settlement / transaction log batch for reconciliation."""
        pass

    def get_configuration_status(self) -> str:
        """Returns one of: CONFIGURED, NOT_CONFIGURED, TEST_MODE, LIVE_MODE."""
        return "TEST_MODE"

