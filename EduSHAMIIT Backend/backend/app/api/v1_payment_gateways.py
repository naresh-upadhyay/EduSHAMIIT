"""Payment Gateway Integration (PGI) FastAPI Router

Production-grade endpoints for:
- Gateway Dashboard (live KPIs, health, security, matrix)
- Gateway lifecycle (Create, Update, Enable, Disable, Set Default, Delete)
- Connection testing & Latency measurement
- Payment Method Matrix & Routing Rules Engine
- Transactions & Webhooks log lookup
- Webhook Ingestion & Signature Verification
"""
import os
import logging
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, HTTPException, Query, Body, Depends, Request
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field

from app.middleware.auth import get_current_user_optional
from app.services.payment.gateway_integration_service import GatewayIntegrationService
from app.services.payment.payment_service import PaymentService
from app.services.payment.payu_provider import PayUProvider
from app.services.supabase_client import get_supabase

logger = logging.getLogger("pgi_router")

router = APIRouter(tags=["Payment Gateway Integration"])


# --- Request Models ---

class TestPayUConnectionRequest(BaseModel):
    key: Optional[str] = None
    salt: Optional[str] = None
    environment: Optional[str] = "TEST"
    client_id: Optional[str] = None
    client_secret: Optional[str] = None
    success_url: Optional[str] = None
    failure_url: Optional[str] = None
    webhook_endpoint: Optional[str] = None
    school_id: Optional[str] = None


class ConfigurePayURequest(BaseModel):
    environment: str = "TEST"  # 'TEST' or 'PRODUCTION'
    key: str
    salt: str
    client_id: Optional[str] = None
    client_secret: Optional[str] = None
    success_url: Optional[str] = None
    failure_url: Optional[str] = None
    webhook_endpoint: Optional[str] = None
    school_id: Optional[str] = None


class CreateGatewayRequest(BaseModel):
    provider: str
    display_name: str
    integration_type: str = "MERCHANT_API" # 'MERCHANT_API' or 'UPI_QR'
    environment: str = "SANDBOX" # 'SANDBOX' or 'PRODUCTION'
    credentials: Dict[str, Any]
    supported_methods: Optional[List[str]] = Field(default=["UPI", "CARD", "NET_BANKING"])
    is_default: bool = False
    merchant_identifier: Optional[str] = None
    webhook_endpoint: Optional[str] = None
    school_id: Optional[str] = None


class UpdateGatewayRequest(BaseModel):
    display_name: Optional[str] = None
    integration_type: Optional[str] = None
    environment: Optional[str] = None
    status: Optional[str] = None
    is_default: Optional[bool] = None
    merchant_identifier: Optional[str] = None
    credentials: Optional[Dict[str, Any]] = None
    supported_methods: Optional[List[str]] = None
    webhook_endpoint: Optional[str] = None


class RotateCredentialsRequest(BaseModel):
    credentials: Dict[str, Any]


class CreateRoutingRuleRequest(BaseModel):
    payment_type: str = "SCHOOL_FEE"
    payment_method: str = "UPI"
    gateway_id: str
    fallback_gateway_id: Optional[str] = None
    priority: int = 1
    conditions: Optional[Dict[str, Any]] = None
    school_id: Optional[str] = None


class UpdateRoutingRuleRequest(BaseModel):
    payment_type: Optional[str] = None
    payment_method: Optional[str] = None
    gateway_id: Optional[str] = None
    fallback_gateway_id: Optional[str] = None
    priority: Optional[int] = None
    is_active: Optional[bool] = None
    conditions: Optional[Dict[str, Any]] = None


# =========================================================================
# 1. DASHBOARD & AGGREGATIONS
# =========================================================================

@router.get("/dashboard", summary="Get PGI Dashboard KPIs, Provider Cards, Matrix & Security")
async def get_pgi_dashboard(
    school_id: Optional[str] = Query(None),
    environment: str = Query("SANDBOX"),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    return await GatewayIntegrationService.get_dashboard_summary(
        school_id=effective_school_id,
        environment=environment
    )


@router.get("/method-matrix", summary="Get Real Dynamic Payment Method Matrix")
async def get_payment_method_matrix(
    school_id: Optional[str] = Query(None),
    environment: str = Query("SANDBOX"),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    summary = await GatewayIntegrationService.get_dashboard_summary(
        school_id=effective_school_id,
        environment=environment
    )
    return {"success": True, "data": summary.get("data", {}).get("method_matrix", [])}


# =========================================================================
# 2. GATEWAY CRUD
# =========================================================================

@router.get("", summary="List Configured Payment Gateways")
async def list_gateways(
    environment: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    items = await GatewayIntegrationService.list_gateways(
        school_id=effective_school_id,
        environment=environment,
        status=status,
        search=search
    )
    return {"success": True, "data": items}


@router.post("", summary="Add New Payment Gateway")
async def create_gateway(
    req: CreateGatewayRequest,
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = req.school_id
    user_id = None
    if user:
        user_id = user.get("id")
        if user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
            effective_school_id = user["school_id"]

    try:
        gw = await GatewayIntegrationService.create_gateway(
            provider=req.provider,
            display_name=req.display_name,
            credentials=req.credentials,
            integration_type=req.integration_type,
            environment=req.environment,
            supported_methods=req.supported_methods,
            is_default=req.is_default,
            merchant_identifier=req.merchant_identifier,
            webhook_endpoint=req.webhook_endpoint,
            school_id=effective_school_id,
            user_id=user_id
        )
        return {"success": True, "data": gw}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create gateway: {str(e)}")


# =========================================================================
# 2. PAYMENT ROUTING ENGINE CRUD
# =========================================================================

@router.get("/routing", summary="List Payment Routing Rules")
async def list_routing_rules(
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    rules = await GatewayIntegrationService.list_routing_rules(school_id=effective_school_id)
    return {"success": True, "data": rules}


@router.post("/routing", summary="Create Payment Routing Rule")
async def create_routing_rule(
    req: CreateRoutingRuleRequest,
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = req.school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        rule = await GatewayIntegrationService.create_routing_rule(
            payment_type=req.payment_type,
            payment_method=req.payment_method,
            gateway_id=req.gateway_id,
            fallback_gateway_id=req.fallback_gateway_id,
            priority=req.priority,
            conditions=req.conditions,
            school_id=effective_school_id
        )
        return {"success": True, "data": rule}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.patch("/routing/{rule_id}", summary="Update Payment Routing Rule")
async def update_routing_rule(
    rule_id: str,
    req: UpdateRoutingRuleRequest,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        rule = await GatewayIntegrationService.update_routing_rule(
            rule_id=rule_id,
            update_data=req.model_dump(exclude_unset=True),
            school_id=effective_school_id
        )
        return {"success": True, "data": rule}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/routing/{rule_id}", summary="Delete Payment Routing Rule")
async def delete_routing_rule(
    rule_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    await GatewayIntegrationService.delete_routing_rule(rule_id, school_id=effective_school_id)
    return {"success": True, "message": "Routing rule deleted"}


# =========================================================================
# 2.5 PAYU OFFICIAL HOSTED CHECKOUT & DIAGNOSTICS (STATIC ROUTES)
# Must be defined BEFORE parameterized /{gateway_id} routes in FastAPI!
# =========================================================================

@router.get("/payu/webhook-info", summary="Get PayU Webhook Diagnostic Info")
async def get_payu_webhook_info(
    request: Request,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    """
    Computes authoritative absolute webhook URL and tunnel status for PayU.
    Warns if running on localhost to prevent broken webhook delivery.
    """
    public_base = (
        os.getenv("PUBLIC_API_URL") or 
        os.getenv("PAYU_WEBHOOK_BASE_URL") or 
        os.getenv("PAYU_WEBHOOK_URL") or 
        ""
    ).strip()

    req_host = request.headers.get("X-Forwarded-Host") or request.headers.get("Host") or "localhost:8082"
    proto = request.headers.get("X-Forwarded-Proto") or ("https" if "https" in str(request.url) else "http")

    is_localhost = any(h in req_host.lower() for h in ["localhost", "127.0.0.1", "0.0.0.0"])

    if public_base:
        if public_base.endswith("/webhooks/payu") or public_base.endswith("/payu/webhook"):
            resolved_webhook_url = public_base
        else:
            resolved_webhook_url = f"{public_base.rstrip('/')}/api/v1/payment-gateways/payu/webhook"
    else:
        resolved_webhook_url = f"{proto}://{req_host}/api/v1/payment-gateways/payu/webhook"

    return {
        "success": True,
        "data": {
            "webhook_url": resolved_webhook_url,
            "is_localhost": is_localhost,
            "public_configured": bool(public_base),
            "supported_events": ["Successful", "Failed", "Refund", "Dispute"],
            "warning": "Development environment: PayU cannot reach localhost directly. Use a public HTTPS tunnel (e.g. Cloudflare Tunnel or ngrok) for webhook testing." if is_localhost else None,
            "payload_format": "application/x-www-form-urlencoded and application/json",
            "hash_algorithm": "SHA-512 reverse hash: sha512(SALT|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key)"
        }
    }


@router.post("/payu/test", summary="Test Connection with PayU API")
async def test_payu_connection(
    req: Optional[TestPayUConnectionRequest] = Body(None),
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    """
    Performs live diagnostic validation against official PayU integration.
    Tests credentials supplied in the setup wizard or loaded from database/environment.
    """
    effective_school_id = school_id or (req.school_id if req else None)
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    key = (req.key if req and req.key else "").strip()
    salt = (req.salt if req and req.salt else "").strip()
    env = (req.environment if req and req.environment else "TEST").strip().upper()

    # If credentials not provided in body, load from DB or environment
    if not key or not salt or salt == "PRESERVE_EXISTING":
        sb = GatewayIntegrationService._get_sb()
        existing_gw = None
        try:
            q = sb.table("payment_gateways").select("*").eq("provider", "PAYU")
            if effective_school_id:
                q = q.eq("school_id", effective_school_id)
            if env != "ALL":
                q = q.eq("environment", env)
            res = await q.maybe_single().aexecute()
            existing_gw = res.data
        except Exception:
            pass

        if not existing_gw and GatewayIntegrationService._memory_gateways:
            for g in GatewayIntegrationService._memory_gateways.values():
                if g.get("provider") == "PAYU" and g.get("environment") == env:
                    if not effective_school_id or g.get("school_id") == effective_school_id:
                        existing_gw = g
                        break

        if existing_gw:
            creds = existing_gw.get("credentials_encrypted") or {}
            key = key or creds.get("merchant_key") or creds.get("key") or ""
            if not salt or salt == "PRESERVE_EXISTING":
                salt = creds.get("salt") or ""

        # Fallback to environment variables
        if not key:
            key = (os.getenv("PAYU_MERCHANT_KEY") or os.getenv("PAYU_KEY") or "").strip()
        if not salt or salt == "PRESERVE_EXISTING":
            salt = (os.getenv("PAYU_SALT") or "").strip()

    provider = PayUProvider(
        merchant_key=key,
        salt=salt,
        environment=env,
        client_id=req.client_id if req else None,
        client_secret=req.client_secret if req else None,
        success_url=req.success_url if req else None,
        failure_url=req.failure_url if req else None,
        webhook_url=req.webhook_endpoint if req else None,
    )
    test_res = await provider.test_connection()
    return {"success": test_res.get("success", False), "data": test_res}


@router.post("/payu/configure", summary="Configure PayU Gateway Credentials")
async def configure_payu_gateway(
    req: ConfigurePayURequest,
    user: Optional[dict] = Depends(get_current_user_optional)
):
    """
    Secure server-side PayU configuration:
    - Encrypts credentials at rest
    - Updates local server-side environment safely
    - Sets gateway status to CONFIGURED
    - Never leaks Salt or Secret back to frontend
    """
    effective_school_id = req.school_id
    user_id = user.get("id") if user else None
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        res = await GatewayIntegrationService.configure_payu(
            environment=req.environment,
            key=req.key,
            salt=req.salt,
            client_id=req.client_id,
            client_secret=req.client_secret,
            success_url=req.success_url,
            failure_url=req.failure_url,
            webhook_endpoint=req.webhook_endpoint,
            school_id=effective_school_id,
            user_id=user_id
        )
        return {"success": True, "data": res}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error configuring PayU: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to configure PayU: {str(e)}")


# =========================================================================
# 3. GATEWAY DETAILS & ACTIONS
# =========================================================================

# NOTE: Static routes MUST be registered before parameterized /{gateway_id}
# to avoid FastAPI matching e.g. /webhooks as gateway_id='webhooks'.
@router.get("/webhooks", summary="List All Payment Gateway Webhook Events")
async def list_all_webhooks(
    provider: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=100)
):
    sb = get_supabase()
    webhooks = []
    try:
        q = sb.table("payment_gateway_webhook_events").select("*")
        if provider:
            q = q.eq("provider", provider)
        if status:
            q = q.eq("status", status)
        res = await q.order("received_at", ascending=False).limit(limit).aexecute()
        webhooks = res.data or []
    except Exception as e:
        logger.warning(f"Error querying webhook events: {e}")
    return {"success": True, "data": {"items": webhooks, "total": len(webhooks)}}

@router.get("/providers", summary="Get Supported Payment Gateway Providers")
async def get_supported_providers():
    """Returns available gateway providers and their architectural status."""
    return {
        "success": True,
        "data": [
            {
                "provider": "PAYU",
                "display_name": "PayU Hosted Checkout",
                "status": "AVAILABLE",
                "is_implemented": True,
                "supported_methods": ["UPI", "CARD", "NET_BANKING", "WALLET", "EMI"],
                "environments": ["TEST", "PRODUCTION"],
                "description": "India's premier enterprise payment gateway supporting Hosted Checkout, UPI Intent, Dynamic QR, and SHA-512 cryptographic verification."
            },
            {
                "provider": "RAZORPAY",
                "display_name": "Razorpay Standard Checkout",
                "status": "NOT_CONFIGURED",
                "is_implemented": True,
                "supported_methods": ["UPI", "CARD", "NET_BANKING"],
                "environments": ["TEST", "PRODUCTION"],
                "description": "Razorpay Standard Checkout & Payment Links."
            },
            {
                "provider": "CASHFREE",
                "display_name": "Cashfree Payments",
                "status": "NOT_CONFIGURED",
                "is_implemented": True,
                "supported_methods": ["UPI", "CARD", "NET_BANKING"],
                "environments": ["TEST", "PRODUCTION"],
                "description": "Cashfree PG order token & drop-in checkout."
            },
            {
                "provider": "SBI_EPAY",
                "display_name": "State Bank of India (SBI ePay)",
                "status": "NOT_CONFIGURED",
                "is_implemented": True,
                "supported_methods": ["UPI", "NET_BANKING", "CARD"],
                "environments": ["TEST", "PRODUCTION"],
                "description": "Institutional fee collection gateway with direct treasury settlement."
            }
        ]
    }


@router.get("/{gateway_id}", summary="Get Gateway Details (Masked Secrets)")
async def get_gateway_details(
    gateway_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    gw = await GatewayIntegrationService.get_gateway(gateway_id, school_id=effective_school_id)
    if not gw:
        raise HTTPException(status_code=404, detail="Payment gateway not found")
    return {"success": True, "data": gw}


@router.patch("/{gateway_id}", summary="Update Gateway Configuration")
async def update_gateway(
    gateway_id: str,
    req: UpdateGatewayRequest,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    user_id = None
    if user:
        user_id = user.get("id")
        if user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
            effective_school_id = user["school_id"]

    try:
        updated = await GatewayIntegrationService.update_gateway(
            gateway_id=gateway_id,
            update_data=req.model_dump(exclude_unset=True),
            school_id=effective_school_id,
            user_id=user_id
        )
        return {"success": True, "data": updated}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.delete("/{gateway_id}", summary="Safe Disable or Remove Gateway")
async def delete_gateway(
    gateway_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        await GatewayIntegrationService.disable_gateway(gateway_id, school_id=effective_school_id)
        return {"success": True, "message": "Gateway disabled successfully."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# =========================================================================
# 3. ACTIONS & TESTING
# =========================================================================

@router.post("/{gateway_id}/test", summary="Test Connection with Provider API")
async def test_single_gateway(
    gateway_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    if gateway_id.lower() in ("payu", "payu_test"):
        return await test_payu_connection(req=None, school_id=effective_school_id, user=user)

    try:
        res = await GatewayIntegrationService.test_gateway(gateway_id, school_id=effective_school_id)
        return {"success": True, "data": res}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/test-all", summary="Run Connection Tests on All Configured Gateways")
async def test_all_gateways(
    school_id: Optional[str] = Query(None),
    environment: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    results = await GatewayIntegrationService.test_all_gateways(
        school_id=effective_school_id,
        environment=environment
    )
    return {"success": True, "data": results}


@router.post("/{gateway_id}/set-default", summary="Atomically Set Gateway as Default")
async def set_default_gateway(
    gateway_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    user_id = user.get("id") if user else None
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        res = await GatewayIntegrationService.set_default_gateway(
            gateway_id=gateway_id,
            school_id=effective_school_id,
            user_id=user_id
        )
        return res
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{gateway_id}/enable", summary="Enable Gateway")
async def enable_gateway(
    gateway_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        res = await GatewayIntegrationService.enable_gateway(gateway_id, school_id=effective_school_id)
        return {"success": True, "data": res}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{gateway_id}/disable", summary="Disable Gateway")
async def disable_gateway(
    gateway_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        res = await GatewayIntegrationService.disable_gateway(gateway_id, school_id=effective_school_id)
        return {"success": True, "data": res}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.post("/{gateway_id}/health-check", summary="Trigger On-Demand Health Check")
async def run_gateway_health_check(
    gateway_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        res = await GatewayIntegrationService.test_gateway(gateway_id, school_id=effective_school_id)
        return {"success": True, "data": res}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/{gateway_id}/rotate-credentials", summary="Rotate Merchant Credentials")
async def rotate_credentials(
    gateway_id: str,
    req: RotateCredentialsRequest,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    effective_school_id = school_id
    user_id = user.get("id") if user else None
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    try:
        updated = await GatewayIntegrationService.update_gateway(
            gateway_id=gateway_id,
            update_data={"credentials": req.credentials},
            school_id=effective_school_id,
            user_id=user_id
        )
        return {"success": True, "data": updated, "message": "Credentials successfully rotated."}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# =========================================================================
# 4. TRANSACTIONS, WEBHOOKS & EVENTS LOOKUP
# =========================================================================

@router.get("/{gateway_id}/transactions", summary="List Transactions for a Gateway")
async def get_gateway_transactions(
    gateway_id: str,
    limit: int = Query(50, ge=1, le=200),
    page: int = Query(1, ge=1),
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    gw = await GatewayIntegrationService.get_gateway(gateway_id, school_id=school_id)
    if not gw:
        raise HTTPException(status_code=404, detail="Gateway not found")

    provider = gw.get("provider")
    sb = get_supabase()
    orders = []
    try:
        q = sb.table("payment_orders").select("*").ilike("provider", f"%{provider}%")
        if school_id:
            q = q.eq("school_id", school_id)
        offset = (page - 1) * limit
        res = await q.order("created_at", ascending=False).range(offset, offset + limit - 1).aexecute()
        orders = res.data or []
    except Exception as e:
        logger.warning(f"Error querying gateway transactions: {e}")

    return {
        "success": True,
        "data": {
            "items": orders,
            "total": len(orders),
            "page": page,
            "limit": limit
        }
    }


@router.get("/{gateway_id}/health", summary="Get Gateway Health Check History")
async def get_gateway_health_history(
    gateway_id: str,
    school_id: Optional[str] = Query(None)
):
    sb = get_supabase()
    history = []
    try:
        q = sb.table("payment_gateway_health_checks").select("*").eq("gateway_id", gateway_id)
        res = await q.order("checked_at", ascending=False).limit(50).aexecute()
        history = res.data or []
    except Exception:
        pass
    return {"success": True, "data": history}

# (Route moved above /{gateway_id} to avoid path parameter matching conflict)
# @router.get("/webhooks", ...) is now registered earlier in the file.


@router.get("/{gateway_id}/webhooks", summary="List Webhook Ingestions for Gateway")
async def get_gateway_webhooks(
    gateway_id: str,
    school_id: Optional[str] = Query(None)
):
    sb = get_supabase()
    webhooks = []
    try:
        q = sb.table("payment_gateway_webhooks").select("*").eq("gateway_id", gateway_id)
        res = await q.order("created_at", ascending=False).limit(50).aexecute()
        webhooks = res.data or []
    except Exception:
        pass
    return {"success": True, "data": webhooks}


@router.get("/{gateway_id}/events", summary="List Gateway Lifecycle Events")
async def get_gateway_events(
    gateway_id: str,
    school_id: Optional[str] = Query(None)
):
    sb = get_supabase()
    events = []
    try:
        q = sb.table("payment_gateway_events").select("*").eq("gateway_id", gateway_id)
        res = await q.order("created_at", ascending=False).limit(50).aexecute()
        events = res.data or []
    except Exception:
        pass
    return {"success": True, "data": events}





# =========================================================================
# 6. WEBHOOKS INGESTION
# =========================================================================

@router.post("/webhooks/{provider}", summary="Ingest Gateway Webhook Event")
async def ingest_webhook(
    provider: str,
    request: Request
):
    headers = dict(request.headers)
    try:
        payload = await request.json()
    except Exception:
        payload = {}

    res = await GatewayIntegrationService.process_webhook(provider, payload, headers)
    return {"success": True, "data": res}


# =========================================================================
# 7. PAYU SPECIFIC CONFIGURE, TEST, CALLBACKS & WEBHOOKS
# =========================================================================

# (Route moved above /{gateway_id} to avoid path parameter matching conflict)
# @router.get("/providers", ...) is now registered earlier in the file.


@router.get("/{gateway_id}/audit", summary="Get Gateway Immutable Audit Trail")
async def get_gateway_audit_trail(
    gateway_id: str,
    school_id: Optional[str] = Query(None),
    user: Optional[dict] = Depends(get_current_user_optional)
):
    """Returns immutable audit logs and lifecycle events for the gateway."""
    sb = get_supabase()
    logs = []
    try:
        q = sb.table("payment_gateway_events").select("*")
        if gateway_id != "all":
            q = q.eq("gateway_id", gateway_id)
        if school_id:
            q = q.eq("school_id", school_id)
        res = await q.order("created_at", ascending=False).limit(50).aexecute()
        logs = res.data or []
    except Exception as e:
        logger.warning(f"Error fetching gateway audit logs: {e}")

    if not logs:
        logs = [e for e in GatewayIntegrationService._memory_events if gateway_id == "all" or e.get("gateway_id") == gateway_id]

    return {"success": True, "data": logs}


@router.api_route("/payu/callback/success", methods=["GET", "POST"], summary="PayU Hosted Checkout Success Callback")
async def payu_pgi_callback_success(request: Request):
    """
    Authoritative browser redirect landing for PayU Hosted Checkout.
    Validates PayU reverse-hash: sha512(salt|status||||||udf5|udf4|udf3|udf2|udf1|email|firstname|productinfo|amount|txnid|key).
    Enforces strict amount validation.
    Fulfils payment, updates fee invoice/subscription, and renders response.
    """
    form_data = {}
    if request.method == "POST":
        try:
            form = await request.form()
            form_data = dict(form)
        except Exception:
            pass

    query_params = dict(request.query_params)
    all_params = {**query_params, **form_data}

    target_txn = all_params.get("txnid") or all_params.get("txnId")
    amount_str = all_params.get("amount", "0")
    try:
        verified_amount = float(amount_str)
    except Exception:
        verified_amount = 0.0

    # Get active PayU provider instance for reverse-hash verification
    payu_provider = PayUProvider()
    hash_valid = payu_provider.verify_response_hash(all_params)

    if not hash_valid:
        logger.error(f"[PayU Callback] Reverse hash validation FAILED for txn {target_txn}")
        await GatewayIntegrationService.log_gateway_event(
            gateway_id="PAYU",
            event_type="PAYU_RESPONSE_HASH_INVALID",
            severity="CRITICAL",
            payload={"transaction_id": target_txn, "params": {k: v for k, v in all_params.items() if k not in ("hash", "salt")}}
        )
        return HTMLResponse(content=f"""
        <!DOCTYPE html>
        <html>
        <head><title>Security Error - Invalid Payment Hash</title></head>
        <body style="font-family:sans-serif;padding:40px;background:#fef2f2;color:#991b1b;text-align:center;">
          <h2>Security Verification Failed</h2>
          <p>The payment response reverse-hash received from the gateway could not be verified.</p>
          <p>Transaction ID: <strong>{target_txn}</strong></p>
          <p>For your security, this transaction has been flagged and rejected.</p>
          <a href="/#/get-started/payment-processing?txnId={target_txn or ''}&status=failed" style="color:#b91c1c;font-weight:bold;">Return to ERP</a>
        </body>
        </html>
        """, status_code=400)

    # Reverse hash is valid! Now verify and fulfill payment atomically
    fulfillment_result = {}
    if target_txn:
        try:
            fulfillment_result = await PaymentService.verify_and_fulfill_payment(
                payment_id=target_txn,
                verified_amount=verified_amount,
                provider_txn_id=all_params.get("mihpayid"),
                hash_verified=True
            )
        except Exception as e:
            logger.error(f"[PayU Callback] Error fulfilling payment: {e}")

    # Render clean, premium confirmation HTML
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <title>Payment Successful - EduSHAMIIT</title>
      <meta http-equiv="refresh" content="2;url=/#/get-started/payment-processing?txnId={target_txn or ''}&status=success">
      <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f0fdf4; color: #166534; }}
        .card {{ background: white; padding: 40px; border-radius: 20px; box-shadow: 0 12px 30px rgba(0,0,0,0.06); text-align: center; max-width: 440px; border: 1px solid #bbf7d0; }}
        .icon {{ font-size: 52px; color: #16a34a; margin-bottom: 16px; }}
        h2 {{ margin: 0 0 10px 0; color: #14532d; }}
        p {{ margin: 6px 0; color: #475569; font-size: 14px; }}
        .btn {{ display: inline-block; margin-top: 20px; padding: 12px 24px; background: #16a34a; color: white; text-decoration: none; border-radius: 10px; font-weight: 600; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="icon">✓</div>
        <h2>Payment Verified & Confirmed!</h2>
        <p>Transaction ID: <strong>{target_txn}</strong></p>
        <p>Amount Paid: <strong>₹{verified_amount:,.2f}</strong></p>
        <p>Returning to EduSHAMIIT ERP...</p>
        <a class="btn" href="/#/get-started/payment-processing?txnId={target_txn or ''}&status=success">Continue to ERP</a>
      </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


@router.api_route("/payu/callback/failure", methods=["GET", "POST"], summary="PayU Hosted Checkout Failure Callback")
async def payu_pgi_callback_failure(request: Request):
    """Handles PayU failed or declined payment redirect."""
    form_data = {}
    if request.method == "POST":
        try:
            form = await request.form()
            form_data = dict(form)
        except Exception:
            pass

    query_params = dict(request.query_params)
    all_params = {**query_params, **form_data}

    target_txn = all_params.get("txnid") or all_params.get("txnId")
    error_msg = all_params.get("error_Message") or all_params.get("error") or "Payment was declined or cancelled at checkout"

    if target_txn:
        sb = get_supabase()
        now_iso = datetime.now(timezone.utc).isoformat()
        try:
            await sb.table("payment_orders").update({
                "status": "FAILED",
                "failure_reason": error_msg,
                "updated_at": now_iso
            }).eq("transaction_id", target_txn).aexecute()
        except Exception:
            pass

        await GatewayIntegrationService.log_gateway_event(
            gateway_id="PAYU",
            event_type="PAYMENT_FAILED",
            severity="WARNING",
            payload={"transaction_id": target_txn, "reason": error_msg}
        )

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <title>Payment Declined - EduSHAMIIT</title>
      <meta http-equiv="refresh" content="3;url=/#/get-started/payment-processing?txnId={target_txn or ''}&status=failed">
      <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #fff1f2; color: #9f1239; }}
        .card {{ background: white; padding: 40px; border-radius: 20px; box-shadow: 0 12px 30px rgba(0,0,0,0.06); text-align: center; max-width: 440px; border: 1px solid #fecdd3; }}
        .icon {{ font-size: 52px; color: #e11d48; margin-bottom: 16px; }}
        h2 {{ margin: 0 0 10px 0; color: #881337; }}
        p {{ margin: 6px 0; color: #475569; font-size: 14px; }}
        .btn {{ display: inline-block; margin-top: 20px; padding: 12px 24px; background: #e11d48; color: white; text-decoration: none; border-radius: 10px; font-weight: 600; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="icon">✕</div>
        <h2>Payment Incomplete</h2>
        <p>Transaction ID: <strong>{target_txn or 'N/A'}</strong></p>
        <p>Reason: {error_msg}</p>
        <a class="btn" href="/#/get-started/payment-processing?txnId={target_txn or ''}&status=failed">Try Again</a>
      </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


@router.post("/payu/webhook", summary="PayU Server-to-Server Webhook Handler")
@router.post("/webhooks/payu", summary="PayU Server-to-Server Webhook Handler (Legacy Path)")
async def payu_pgi_webhook(request: Request):
    """
    Authoritative server-to-server webhook ingestion for PayU.
    Handles payment, refund, and dispute events idempotently.
    """
    try:
        payload = await request.json()
    except Exception:
        payload = dict(await request.form())

    headers = dict(request.headers)
    res = await GatewayIntegrationService.process_webhook("PAYU", payload, headers)

    # If webhook contains verified transaction, trigger atomic fulfillment
    txn_id = res.get("transaction_id")
    if txn_id and res.get("verified"):
        try:
            await PaymentService.verify_and_fulfill_payment(payment_id=txn_id)
        except Exception as e:
            logger.error(f"[PayU Webhook] Fulfillment error for txn {txn_id}: {e}")

    return {"success": True, "data": res}

