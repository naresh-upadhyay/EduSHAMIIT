"""PayU Authorization Service

Handles HMAC-SHA512 date & signature calculation for PayU v2 API.
Spec: HMAC-SHA512(body + "|" + date + "|" + merchant_secret)
"""
import hmac
import hashlib
from datetime import datetime, timezone
from email.utils import formatdate
from typing import Tuple

class PayUAuthService:
    @staticmethod
    def generate_date_header() -> str:
        """Generate current UTC date header string formatted per RFC 7231 / RFC 1123 format."""
        now = datetime.now(timezone.utc)
        return formatdate(timeval=now.timestamp(), localtime=False, usegmt=True)

    @staticmethod
    def generate_hmac_signature(body_str: str, date_str: str, merchant_secret: str) -> str:
        """
        Generate HMAC SHA512 signature for PayU v2 API.
        Signature = SHA512_HMAC(merchant_secret, body_str + "|" + date_str + "|" + merchant_secret)
        or SHA512 hash string according to PayU v2 spec.
        """
        sign_payload = f"{body_str}|{date_str}|{merchant_secret}"
        # Compute HMAC SHA512
        signature = hmac.new(
            merchant_secret.encode('utf-8'),
            sign_payload.encode('utf-8'),
            hashlib.sha512
        ).hexdigest()
        return signature

    @classmethod
    def generate_authorization_header(cls, body_str: str, date_str: str, merchant_secret: str) -> str:
        """Generate full Authorization header value for PayU v2 API."""
        sig = cls.generate_hmac_signature(body_str, date_str, merchant_secret)
        return f"HMAC-SHA512 {sig}"

    @classmethod
    def generate_headers(cls, body_str: str, merchant_secret: str) -> Tuple[dict, str]:
        """Generate HTTP headers dict including Date and Authorization for PayU API call."""
        date_str = cls.generate_date_header()
        auth_header = cls.generate_authorization_header(body_str, date_str, merchant_secret)
        headers = {
            "Content-Type": "application/json",
            "accept": "application/json",
            "date": date_str,
            "authorization": auth_header,
        }
        return headers, date_str
