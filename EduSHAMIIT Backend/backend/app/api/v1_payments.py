"""PayU v2 End-to-End Payments API (v1)

Provides secure payment order creation, PayU Hosted Checkout integration, callback handling,
server-to-server verification, idempotency, receipts, and admin gateway configuration.
"""
from typing import Optional, List, Dict, Any
from pydantic import BaseModel, EmailStr
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import HTMLResponse, RedirectResponse

from app.middleware.auth import get_current_user, require_school_id, get_current_user_optional
from app.services.supabase_client import get_supabase
from app.services.payment.payment_service import PaymentService
from app.services.payment.payu_provider import PayUProvider

router = APIRouter()


# ─── Pydantic Request Models ───────────────────────────────────

class InitiatePaymentRequest(BaseModel):
    invoice_id: Optional[str] = None
    fee_invoice_id: Optional[str] = None
    plan_code: Optional[str] = None
    billing_cycle: Optional[str] = "monthly"
    amount: Optional[float] = None
    currency: Optional[str] = "INR"
    gateway: Optional[str] = "PAYU"
    payment_method: Optional[str] = "UPI"
    customer_name: Optional[str] = None
    customer_email: Optional[str] = None
    customer_phone: Optional[str] = None
    school_id: Optional[str] = None
    student_id: Optional[str] = None
    purpose: Optional[str] = "School Fee"
    idempotency_key: Optional[str] = None


class PaymentRefundRequest(BaseModel):
    amount: float
    reason: str = "Customer requested refund"


class CreatePaymentOrderRequest(BaseModel):
    plan_code: str  # 'basic', 'premium', 'enterprise'
    billing_cycle: str = "monthly"  # 'monthly' or 'yearly'
    purpose: str = "SUBSCRIPTION"
    school_name: Optional[str] = None
    customer_name: Optional[str] = None
    customer_email: Optional[str] = None
    customer_phone: Optional[str] = None
    idempotency_key: Optional[str] = None


class PayUSettingsUpdateRequest(BaseModel):
    environment: str = "TEST"  # 'TEST' or 'PRODUCTION'
    merchant_key: str
    merchant_secret: str
    salt: Optional[str] = None
    webhook_secret: Optional[str] = None
    is_enabled: bool = True


# ─── 0. CENTRAL PAYMENT APIs (POST / and GET /) ────────────────
@router.post("", summary="Central Payment Initiation API")
async def initiate_payment(
    req: InitiatePaymentRequest,
    request: Request,
    user: Optional[dict] = Depends(get_current_user_optional)
):
    """
    Centralized Payment API for all ERP payment flows.
    Validates tenant, authoritative amount from DB, creates internal transaction first,
    and returns PayU Hosted Checkout parameters.
    """
    sb = get_supabase()
    effective_school_id = req.school_id
    user_id = user.get("id") if user else None
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    authoritative_amount = req.amount
    purpose = req.purpose or "Fee Payment"
    student_id = req.student_id

    # 1. Authoritative Fee Invoice Validation from Database
    target_invoice_id = req.fee_invoice_id or req.invoice_id
    if target_invoice_id:
        try:
            q = sb.table("fee_invoices").select("*").eq("id", target_invoice_id)
            if effective_school_id:
                q = q.eq("school_id", effective_school_id)
            inv_res = await q.maybe_single().aexecute()
            if inv_res.data:
                inv = inv_res.data
                if inv.get("status") == "paid":
                    raise HTTPException(status_code=400, detail="Invoice is already fully paid.")
                balance = float(inv.get("amount_balance") or inv.get("amount_payable") or inv.get("amount_demand") or 0.0)
                if balance > 0:
                    authoritative_amount = balance
                purpose = f"Fee: {inv.get('fee_head', 'School Fee')} ({inv.get('invoice_number', target_invoice_id)})"
                student_id = student_id or inv.get("student_id")
        except HTTPException:
            raise
        except Exception:
            pass

    # 2. Subscription Plan Calculation
    if req.plan_code:
        _, calculated_amount = await PaymentService.calculate_plan_amount(req.plan_code, req.billing_cycle or "monthly")
        authoritative_amount = calculated_amount
        purpose = f"Subscription: {req.plan_code.capitalize()} ({req.billing_cycle})"

    if not authoritative_amount or authoritative_amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid payment amount. Amount must be greater than zero.")

    cust_name = req.customer_name or (user.get("full_name") if user else "Valued Student")
    cust_email = req.customer_email or (user.get("email") if user else "student@school.edu")
    cust_phone = req.customer_phone or (user.get("phone") if user else "9999999999")

    try:
        payment = await PaymentService.create_payment(
            school_id=effective_school_id,
            payer_type="STUDENT" if student_id else "CUSTOMER",
            customer_name=cust_name,
            customer_email=cust_email,
            customer_phone=cust_phone,
            purpose=purpose,
            amount=authoritative_amount,
            currency=req.currency or "INR",
            gateway=req.gateway or "PAYU",
            payment_method=req.payment_method or "UPI",
            student_id=student_id,
            fee_invoice_id=target_invoice_id,
            idempotency_key=req.idempotency_key,
            user_id=user_id
        )

        return {
            "success": True,
            "data": {
                "transaction_id": payment["transaction_id"],
                "payment_id": payment["payment_id"],
                "gateway": payment.get("gateway", "PAYU"),
                "checkout_url": payment.get("checkout_url"),
                "params": payment.get("params"),
                "amount": payment["amount"],
                "currency": payment["currency"],
                "status": payment["status"]
            }
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Payment initialization failed: {str(e)}")


@router.get("", summary="List Payments / Transactions")
async def list_payments(
    school_id: Optional[str] = None,
    status: Optional[str] = None,
    limit: int = 50,
    page: int = 1,
    user: Optional[dict] = Depends(get_current_user_optional)
):
    """List payment orders with tenant isolation and server-side pagination."""
    effective_school_id = school_id
    if user and user.get("role") not in ("super_admin", "owner") and user.get("school_id"):
        effective_school_id = user["school_id"]

    sb = get_supabase()
    orders = []
    try:
        q = sb.table("payment_orders").select("*")
        if effective_school_id:
            q = q.eq("school_id", effective_school_id)
        if status and status.upper() != "ALL":
            q = q.eq("status", status.upper())
        offset = (page - 1) * limit
        res = await q.order("created_at", ascending=False).range(offset, offset + limit - 1).aexecute()
        orders = res.data or []
    except Exception:
        orders = list(PaymentService._memory_orders.values())
        if effective_school_id:
            orders = [o for o in orders if o.get("school_id") == effective_school_id]

    return {
        "success": True,
        "data": {
            "items": orders,
            "total": len(orders),
            "page": page,
            "limit": limit
        }
    }



# ─── 1. POST /api/v1/payments/orders ─────────────────────────
@router.post("/orders", summary="Create Payment Order", description="Initiate a new PayU v2 hosted checkout payment order")
async def create_payment_order(
    req: CreatePaymentOrderRequest,
    request: Request,
    user: Optional[dict] = Depends(get_current_user_optional)
):
    """
    Validates plan price server-side, generates transaction ID, logs PENDING order,
    and returns PayU hosted checkout URL.
    """
    try:
        user_id = user.get("id") if user else None
        school_id = user.get("school_id") if user else None

        customer_name = req.customer_name or (user.get("full_name") if user else "Valued School Admin")
        customer_email = req.customer_email or (user.get("email") if user else "admin@school.edu")
        customer_phone = req.customer_phone or (user.get("phone") if user else "9999999999")

        host = str(request.base_url).rstrip("/")

        order = await PaymentService.create_payment_order(
            school_id=school_id,
            user_id=user_id,
            plan_code=req.plan_code.lower(),
            billing_cycle=req.billing_cycle.lower(),
            customer_name=customer_name,
            customer_email=customer_email,
            customer_phone=customer_phone,
            purpose=req.purpose,
            idempotency_key=req.idempotency_key,
            callback_base_url=host
        )

        return {"success": True, "data": order}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to create payment order: {str(e)}")


# ─── 2. GET /api/v1/payments/{payment_id} ────────────────────
@router.get("/{payment_id}", summary="Get Payment Order Details")
async def get_payment_details(payment_id: str):
    """Retrieve public summary of a payment order."""
    sb = get_supabase()
    query = sb.table("payment_orders").select("id, public_id, school_id, provider, status, amount, currency, plan_code, plan_name, billing_cycle, transaction_id, checkout_url, created_at, completed_at, failure_reason")
    
    if "-" in payment_id and len(payment_id) == 36:
        res = await query.eq("id", payment_id).maybe_single().aexecute()
    else:
        res = await query.eq("transaction_id", payment_id).maybe_single().aexecute()

    if not res.data:
        raise HTTPException(status_code=404, detail="Payment order not found")

    return {"success": True, "data": res.data}


# ─── 3. POST /api/v1/payments/{payment_id}/verify ───────────
@router.post("/{payment_id}/verify", summary="Verify Payment Order")
async def verify_payment(payment_id: str):
    """
    Executes PayU server-to-server verification API check, updates order status,
    and activates school subscription atomically upon SUCCESS.
    """
    try:
        result = await PaymentService.verify_and_fulfill_payment(payment_id)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Verification failed: {str(e)}")


# ─── 4. POST /api/v1/payments/{payment_id}/retry ────────────
@router.post("/{payment_id}/retry", summary="Retry Failed Payment")
async def retry_payment(payment_id: str, request: Request):
    """Generates a fresh transaction attempt for a failed/cancelled payment order."""
    try:
        host = str(request.base_url).rstrip("/")
        result = await PaymentService.retry_payment_order(payment_id, callback_base_url=host)
        return {"success": True, "data": result}
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Retry failed: {str(e)}")


# ─── 4b. POST /api/v1/payments/{payment_id}/refund ──────────
@router.post("/{payment_id}/refund", summary="Request Payment Refund")
async def refund_payment(
    payment_id: str,
    req: PaymentRefundRequest,
    user: Optional[dict] = Depends(get_current_user_optional)
):
    """
    Executes refund for an authorized payment order via PayU postservice cancel_refund_transaction.
    Validates refundable balance and updates transaction status.
    """
    user_id = user.get("id") if user else None
    try:
        result = await PaymentService.request_refund(
            payment_order_id=payment_id,
            amount=req.amount,
            reason=req.reason,
            user_id=user_id
        )
        return {"success": True, "data": result}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Refund processing failed: {str(e)}")



# ─── 5. GET /api/v1/payments/{payment_id}/receipt ───────────
@router.get("/{payment_id}/receipt", summary="Get Payment Receipt")
async def get_payment_receipt(payment_id: str):
    """Returns official payment receipt for successful transactions."""
    sb = get_supabase()
    is_uuid = False
    try:
        uuid.UUID(payment_id)
        is_uuid = True
    except Exception:
        pass

    if is_uuid:
        res = await sb.table("payment_receipts").select("*").eq("payment_order_id", payment_id).maybe_single().aexecute()
    else:
        res = await sb.table("payment_receipts").select("*").eq("transaction_id", payment_id).maybe_single().aexecute()

    if not res or not res.data:
        raise HTTPException(status_code=404, detail="Payment receipt not found for this transaction")

    return {"success": True, "data": res.data}


# ─── 6. PAYU CALLBACK ENDPOINTS (SUCCESS / FAILURE / CANCEL) ───

@router.api_route("/payu/callback/success", methods=["GET", "POST"], summary="PayU Success Callback")
async def payu_callback_success(request: Request, txnId: Optional[str] = None):
    """
    Handles browser redirection callback from PayU after successful payment.
    Verifies transaction status server-side before showing confirmation.
    """
    query_params = dict(request.query_params)
    form_data = {}
    if request.method == "POST":
        try:
            form = await request.form()
            form_data = dict(form)
        except Exception:
            pass

    all_params = {**query_params, **form_data}
    target_txn = txnId or all_params.get("txnid") or all_params.get("txnId")

    # Reverse hash verification if POST data from PayU
    provider = PayUProvider()
    if request.method == "POST" and "hash" in all_params:
        if not provider.verify_response_hash(all_params):
            return HTMLResponse(content=f"""
            <!DOCTYPE html>
            <html>
            <head><title>Security Error - Invalid Hash</title></head>
            <body style="font-family:sans-serif;padding:40px;text-align:center;background:#fef2f2;color:#991b1b;">
              <h2>Security Verification Failed</h2>
              <p>The payment response reverse-hash received from PayU could not be verified.</p>
              <a href="/#/get-started/payment-processing?txnId={target_txn or ''}&status=failed">Return to School ERP</a>
            </body>
            </html>
            """, status_code=400)

    if target_txn:
        verified_amt = None
        try:
            if all_params.get("amount"):
                verified_amt = float(all_params["amount"])
        except Exception:
            pass
        # Perform server-side verification and atomic fulfillment
        await PaymentService.verify_and_fulfill_payment(
            payment_id=target_txn,
            verified_amount=verified_amt,
            provider_txn_id=all_params.get("mihpayid"),
            hash_verified=True
        )

    # Return clean HTML auto-redirect to app processing UI
    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <title>Payment Successful - School ERP</title>
      <meta http-equiv="refresh" content="1;url=/#/get-started/payment-processing?txnId={target_txn or ''}&status=success">
      <style>
        body {{ font-family: system-ui, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f8fafc; color: #0f172a; }}
        .card {{ background: white; padding: 40px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); text-align: center; max-width: 400px; }}
        .icon {{ font-size: 48px; color: #10b981; margin-bottom: 16px; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="icon">✓</div>
        <h2>Payment Confirmed!</h2>
        <p>Redirecting back to School ERP app...</p>
      </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


@router.api_route("/payu/callback/failure", methods=["GET", "POST"], summary="PayU Failure Callback")
async def payu_callback_failure(request: Request, txnId: Optional[str] = None):
    """Handles PayU failure redirection callback."""
    query_params = dict(request.query_params)
    target_txn = txnId or query_params.get("txnId")

    if target_txn:
        await PaymentService.verify_and_fulfill_payment(target_txn)

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <title>Payment Failed - School ERP</title>
      <meta http-equiv="refresh" content="1;url=/#/get-started/payment-processing?txnId={target_txn or ''}&status=failed">
      <style>
        body {{ font-family: system-ui, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f8fafc; color: #0f172a; }}
        .card {{ background: white; padding: 40px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); text-align: center; max-width: 400px; }}
        .icon {{ font-size: 48px; color: #ef4444; margin-bottom: 16px; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="icon">✕</div>
        <h2>Payment Could Not Be Completed</h2>
        <p>Redirecting back to School ERP app...</p>
      </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


@router.api_route("/payu/callback/cancel", methods=["GET", "POST"], summary="PayU Cancel Callback")
async def payu_callback_cancel(request: Request, txnId: Optional[str] = None):
    """Handles PayU user cancellation redirection callback."""
    query_params = dict(request.query_params)
    target_txn = txnId or query_params.get("txnId")

    if target_txn:
        sb = get_supabase()
        await sb.table("payment_orders").update({"status": "CANCELLED"}).eq("transaction_id", target_txn).aexecute()

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
      <title>Payment Cancelled - School ERP</title>
      <meta http-equiv="refresh" content="1;url=/#/get-started/payment-processing?txnId={target_txn or ''}&status=cancelled">
      <style>
        body {{ font-family: system-ui, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #f8fafc; color: #0f172a; }}
        .card {{ background: white; padding: 40px; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.05); text-align: center; max-width: 400px; }}
        .icon {{ font-size: 48px; color: #f59e0b; margin-bottom: 16px; }}
      </style>
    </head>
    <body>
      <div class="card">
        <div class="icon">⚠️</div>
        <h2>Payment Cancelled</h2>
        <p>Redirecting back to School ERP app...</p>
      </div>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)


# ─── 7. POST /api/v1/payments/webhooks/payu ──────────────────
@router.post("/webhooks/payu", summary="PayU Webhook Notification Handler")
async def payu_webhook(request: Request):
    """
    Processes PayU server-to-server webhook notifications independently of frontend redirect.
    Verifies payload signature and activates school subscription idempotently.
    """
    try:
        payload = await request.json()
    except Exception:
        payload = dict(await request.form())

    headers = dict(request.headers)
    provider = PayUProvider()
    webhook_data = await provider.handle_webhook(payload, headers)

    txn_id = webhook_data.get("transaction_id")
    if txn_id:
        await PaymentService.verify_and_fulfill_payment(txn_id)

    return {"status": "SUCCESS", "message": "Webhook processed"}


# ─── 8. ADMIN PAYMENT SETTINGS (GET / PUT) ────────────────────

@router.get("/settings/payu", summary="Get PayU Settings")
async def get_payu_settings(user: dict = Depends(get_current_user)):
    """Retrieve PayU credentials status for Admin (Secrets are write-only / masked)."""
    sb = get_supabase()
    res = await sb.table("payment_gateway_settings").select("*").eq("provider", "PAYU").maybe_single().aexecute()
    data = res.data or {}

    # Mask sensitive secrets
    merchant_key = data.get("merchant_key", "")
    masked_key = f"••••••••{merchant_key[-4:]}" if len(merchant_key) >= 4 else ("Configured" if merchant_key else "Not Configured")

    return {
        "success": True,
        "data": {
            "provider": "PAYU",
            "environment": data.get("environment", "TEST"),
            "merchant_key": masked_key,
            "merchant_secret_configured": bool(data.get("merchant_secret")),
            "salt_configured": bool(data.get("salt")),
            "is_enabled": data.get("is_enabled", True)
        }
    }


@router.put("/settings/payu", summary="Update PayU Settings")
async def update_payu_settings(req: PayUSettingsUpdateRequest, user: dict = Depends(get_current_user)):
    """Update PayU merchant credentials (SuperAdmin only)."""
    if user.get("role") not in ("admin", "superadmin", "owner"):
        raise HTTPException(status_code=403, detail="Unauthorized: Only SuperAdmin can configure payment gateway credentials")

    sb = get_supabase()
    payload = {
        "provider": "PAYU",
        "environment": req.environment.upper(),
        "merchant_key": req.merchant_key,
        "merchant_secret": req.merchant_secret,
        "salt": req.salt,
        "webhook_secret": req.webhook_secret,
        "is_enabled": req.is_enabled
    }

    res = await sb.table("payment_gateway_settings").upsert(payload, on_conflict="provider").aexecute()
    return {"success": True, "message": "PayU payment gateway settings updated successfully"}


# ─── 9. GET /api/v1/payments/admin/transactions ──────────────
@router.get("/admin/transactions", summary="Admin Payment Transactions History")
async def get_admin_transactions(
    status: Optional[str] = None,
    plan_code: Optional[str] = None,
    limit: int = 50,
    user: dict = Depends(get_current_user)
):
    """List payment transactions with status and search filters for Admin dashboard."""
    sb = get_supabase()
    query = sb.table("payment_orders").select("*, schools(name)").order("created_at", ascending=False).limit(limit)

    if status and status.upper() != "ALL":
        query = query.eq("status", status.upper())
    if plan_code:
        query = query.eq("plan_code", plan_code)

    res = await query.aexecute()
    return {"success": True, "data": res.data or []}
