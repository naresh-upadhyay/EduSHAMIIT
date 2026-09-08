"""Seed baseline Payment Gateway Integration fixtures into live PostgreSQL."""
import uuid
from datetime import datetime, timezone, timedelta
from app.services.supabase_client import get_supabase

async def seed_gateways():
    sb = get_supabase()
    school_id = "e1f11111-1111-1111-1111-111111111111" # Greenfield Public School
    admin_id = "ac2cd910-f889-4856-a3e8-affa1cb9fc91"
    now = datetime.now(timezone.utc)

    # Clean existing
    try:
        await sb.table("payment_gateway_routing_rules").delete().neq("id", "00000000-0000-0000-0000-000000000000").aexecute()
        await sb.table("payment_gateway_health_checks").delete().neq("id", "00000000-0000-0000-0000-000000000000").aexecute()
        await sb.table("payment_gateway_events").delete().neq("id", "00000000-0000-0000-0000-000000000000").aexecute()
        await sb.table("payment_gateways").delete().neq("id", "00000000-0000-0000-0000-000000000000").aexecute()
    except Exception as e:
        print(f"Cleanup note: {e}")

    # 1. Razorpay
    rzp_id = str(uuid.uuid4())
    await sb.table("payment_gateways").insert({
        "id": rzp_id,
        "school_id": school_id,
        "provider": "RAZORPAY",
        "display_name": "Razorpay Standard",
        "integration_type": "MERCHANT_API",
        "environment": "SANDBOX",
        "status": "CONNECTED",
        "is_default": True,
        "merchant_identifier": "rzp_test_greenfield01",
        "credentials_encrypted": {"key_id_masked": "rzp_test•••••••01", "has_secret": True},
        "supported_methods": ["UPI", "CARD", "NET_BANKING", "WALLET", "QR"],
        "webhook_endpoint": "/api/v1/payment-gateways/webhooks/razorpay",
        "last_health_check_at": (now - timedelta(minutes=4)).isoformat(),
        "last_health_status": "SUCCESS",
        "last_health_latency_ms": 64,
        "created_by": admin_id,
        "created_at": (now - timedelta(days=30)).isoformat(),
        "updated_at": (now - timedelta(minutes=4)).isoformat()
    }).aexecute()

    # 2. SBI
    sbi_id = str(uuid.uuid4())
    await sb.table("payment_gateways").insert({
        "id": sbi_id,
        "school_id": school_id,
        "provider": "SBI",
        "display_name": "SBI UPI Collection",
        "integration_type": "UPI_QR", # Distinct UPI/QR mode
        "environment": "SANDBOX",
        "status": "CONNECTED",
        "is_default": False,
        "merchant_identifier": "greenfield@sbi",
        "credentials_encrypted": {"vpa": "greenfield@sbi", "merchant_name": "Greenfield Public School"},
        "supported_methods": ["UPI", "QR"],
        "webhook_endpoint": "/api/v1/payment-gateways/webhooks/sbi",
        "last_health_check_at": (now - timedelta(minutes=12)).isoformat(),
        "last_health_status": "SUCCESS",
        "last_health_latency_ms": 138,
        "created_by": admin_id,
        "created_at": (now - timedelta(days=25)).isoformat(),
        "updated_at": (now - timedelta(minutes=12)).isoformat()
    }).aexecute()

    # 3. PayU
    payu_id = str(uuid.uuid4())
    await sb.table("payment_gateways").insert({
        "id": payu_id,
        "school_id": school_id,
        "provider": "PAYU",
        "display_name": "PayU Hosted Checkout",
        "integration_type": "MERCHANT_API",
        "environment": "SANDBOX",
        "status": "ACTIVE",
        "is_default": False,
        "merchant_identifier": "PAYU_TEST_GREENFIELD",
        "credentials_encrypted": {"key_masked": "PAYU•••••KEY", "has_secret": True},
        "supported_methods": ["UPI", "CARD", "NET_BANKING"],
        "webhook_endpoint": "/api/v1/payment-gateways/webhooks/payu",
        "last_health_check_at": (now - timedelta(minutes=18)).isoformat(),
        "last_health_status": "SUCCESS",
        "last_health_latency_ms": 115,
        "created_by": admin_id,
        "created_at": (now - timedelta(days=20)).isoformat(),
        "updated_at": (now - timedelta(minutes=18)).isoformat()
    }).aexecute()

    # 4. Cashfree
    cashfree_id = str(uuid.uuid4())
    await sb.table("payment_gateways").insert({
        "id": cashfree_id,
        "school_id": school_id,
        "provider": "CASHFREE",
        "display_name": "Cashfree Payments",
        "integration_type": "MERCHANT_API",
        "environment": "SANDBOX",
        "status": "NOT_CONFIGURED",
        "is_default": False,
        "supported_methods": ["UPI", "CARD", "NET_BANKING", "WALLET"],
        "created_by": admin_id,
        "created_at": (now - timedelta(days=15)).isoformat(),
        "updated_at": (now - timedelta(days=15)).isoformat()
    }).aexecute()

    # 5. PayPal
    paypal_id = str(uuid.uuid4())
    await sb.table("payment_gateways").insert({
        "id": paypal_id,
        "school_id": school_id,
        "provider": "PAYPAL",
        "display_name": "PayPal International",
        "integration_type": "MERCHANT_API",
        "environment": "SANDBOX",
        "status": "DISABLED",
        "is_default": False,
        "merchant_identifier": "paypal_sb_greenfield",
        "credentials_encrypted": {"client_id_masked": "sb-••••••••12", "has_secret": True},
        "supported_methods": ["CARD", "INTERNATIONAL"],
        "last_health_check_at": (now - timedelta(hours=2)).isoformat(),
        "last_health_status": "WARNING",
        "last_health_latency_ms": 310,
        "last_health_error": "Multi-currency processing pending merchant verification",
        "created_by": admin_id,
        "created_at": (now - timedelta(days=10)).isoformat(),
        "updated_at": (now - timedelta(hours=2)).isoformat()
    }).aexecute()

    # Routing Rules
    await sb.table("payment_gateway_routing_rules").insert([
        {
            "school_id": school_id,
            "payment_type": "SCHOOL_FEE",
            "payment_method": "UPI",
            "gateway_id": rzp_id,
            "fallback_gateway_id": sbi_id,
            "priority": 1,
            "is_active": True,
            "conditions": {"max_amount": 100000}
        },
        {
            "school_id": school_id,
            "payment_type": "SCHOOL_FEE",
            "payment_method": "CARD",
            "gateway_id": payu_id,
            "fallback_gateway_id": rzp_id,
            "priority": 2,
            "is_active": True,
            "conditions": {}
        },
        {
            "school_id": school_id,
            "payment_type": "SUBSCRIPTION",
            "payment_method": "ALL",
            "gateway_id": rzp_id,
            "fallback_gateway_id": None,
            "priority": 1,
            "is_active": True,
            "conditions": {}
        }
    ]).aexecute()

    # Health Checks History
    await sb.table("payment_gateway_health_checks").insert([
        {
            "gateway_id": rzp_id,
            "school_id": school_id,
            "status": "SUCCESS",
            "latency_ms": 64,
            "metadata": {"endpoint": "https://api.razorpay.com/v1/orders", "http_status": 200},
            "checked_at": (now - timedelta(minutes=4)).isoformat()
        },
        {
            "gateway_id": sbi_id,
            "school_id": school_id,
            "status": "SUCCESS",
            "latency_ms": 138,
            "metadata": {"vpa": "greenfield@sbi", "validation": "VPA_ACTIVE"},
            "checked_at": (now - timedelta(minutes=12)).isoformat()
        },
        {
            "gateway_id": payu_id,
            "school_id": school_id,
            "status": "SUCCESS",
            "latency_ms": 115,
            "metadata": {"endpoint": "https://apitest.payu.in/v2/payments", "http_status": 200},
            "checked_at": (now - timedelta(minutes=18)).isoformat()
        }
    ]).aexecute()

    # Events Log
    await sb.table("payment_gateway_events").insert([
        {
            "gateway_id": rzp_id,
            "school_id": school_id,
            "event_type": "GATEWAY_ENABLED",
            "event_source": "ADMIN_ACTION",
            "severity": "INFO",
            "payload": {"gateway": "Razorpay Standard", "environment": "SANDBOX"},
            "created_at": (now - timedelta(days=2)).isoformat()
        },
        {
            "gateway_id": rzp_id,
            "school_id": school_id,
            "event_type": "SET_DEFAULT",
            "event_source": "ADMIN_ACTION",
            "severity": "INFO",
            "payload": {"gateway": "Razorpay Standard"},
            "created_at": (now - timedelta(days=1)).isoformat()
        },
        {
            "gateway_id": rzp_id,
            "school_id": school_id,
            "event_type": "HEALTH_CHECK",
            "event_source": "MONITOR",
            "severity": "INFO",
            "payload": {"latency_ms": 64, "status": "SUCCESS"},
            "created_at": (now - timedelta(minutes=4)).isoformat()
        },
        {
            "gateway_id": sbi_id,
            "school_id": school_id,
            "event_type": "HEALTH_CHECK",
            "event_source": "MONITOR",
            "severity": "INFO",
            "payload": {"latency_ms": 138, "status": "SUCCESS"},
            "created_at": (now - timedelta(minutes=12)).isoformat()
        }
    ]).aexecute()

    print("Baseline Payment Gateway fixtures successfully seeded.")

if __name__ == "__main__":
    import asyncio
    asyncio.run(seed_gateways())
