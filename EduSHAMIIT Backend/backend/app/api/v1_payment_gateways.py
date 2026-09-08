"""Payment Gateway Integration (PGI) FastAPI Router

Production-grade endpoints for:
- Gateway Dashboard (live KPIs, health, security, matrix)
- Gateway lifecycle (Create, Update, Enable, Disable, Set Default, Delete)
- Connection testing & Latency measurement
- Payment Method Matrix & Routing Rules Engine
- Transactions & Webhooks log lookup
- Webhook Ingestion & Signature Verification
"""
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, HTTPException, Query, Body, Depends, Request
from pydantic import BaseModel, Field

from app.middleware.auth import get_current_user_optional
from app.services.payment.gateway_integration_service import GatewayIntegrationService
from app.services.supabase_client import get_supabase

router = APIRouter(prefix="/api/v1/payment-gateways", tags=["Payment Gateway Integration"])


# --- Request Models ---

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
# 3. GATEWAY DETAILS & ACTIONS
# =========================================================================

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
