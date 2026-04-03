from urllib.parse import urlencode


def generate_upi_link(
    merchant_id: str,
    merchant_name: str,
    amount: float,
    transaction_id: str,
    description: str = "EduSHAMIIT Payment",
) -> str:
    """Generate UPI deep link for payment. Opens UPI app (GPay, PhonePe, Paytm, etc.) directly.
    Zero external fees - direct bank-to-bank transfer."""
    params = {
        "pa": merchant_id,
        "pn": merchant_name,
        "am": str(amount),
        "tn": description,
        "tr": transaction_id,
        "cu": "INR",
        "mc": "8220",  # Education MCC
    }
    return f"upi://pay?{urlencode(params)}"


def generate_upi_qr_data(
    merchant_id: str,
    merchant_name: str,
    amount: float,
    transaction_id: str,
) -> str:
    """Generate UPI QR code data string for scanning."""
    return generate_upi_link(merchant_id, merchant_name, amount, transaction_id, "EduSHAMIIT Fee")