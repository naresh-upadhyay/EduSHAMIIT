"""Payments API - Full UPI/Bank payment lifecycle with all realistic fields."""
import uuid
import hashlib
import os
from datetime import datetime, timedelta
from typing import Optional, List
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, Request
from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase
from app.services.upi_service import generate_upi_link
from app.models import PaymentRequest, PaymentVerifyRequest, PaymentResponse

class DirectPaymentRequest(BaseModel):
    fee_id: str
    amount: float
    payment_method: str  # 'upi', 'card', 'netbanking'
    upi_id: Optional[str] = None
    card_number: Optional[str] = None
    card_expiry: Optional[str] = None
    card_cvv: Optional[str] = None
    bank_name: Optional[str] = None
    description: Optional[str] = "EduSHAMIIT Fee Payment"


class BulkPaymentRequest(BaseModel):
    fee_ids: List[str]
    amount: float
    payment_method: str  # 'upi', 'card', 'netbanking'
    upi_id: Optional[str] = None
    card_number: Optional[str] = None
    card_expiry: Optional[str] = None
    card_cvv: Optional[str] = None
    bank_name: Optional[str] = None
    description: Optional[str] = "EduSHAMIIT Bulk Fee Payment"


router = APIRouter()

MERCHANT_ID    = os.getenv("UPI_MERCHANT_ID",    "eduSHAMIIT@ybl")
MERCHANT_NAME  = os.getenv("UPI_MERCHANT_NAME",  "EduSHAMIIT")
WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET",      "eduSHAMIIT-webhook-secret-2026")
DEFAULT_CURRENCY = "INR"
UPI_LINK_TTL_MINS = 30   # UPI links expire in 30 minutes


def generate_transaction_id() -> str:
    """Unique transaction ID: EDU-YYYYMMDDHHMMSS-<8hex>"""
    ts     = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    unique = uuid.uuid4().hex[:8].upper()
    return f"EDU-{ts}-{unique}"


def _verify_webhook_sig(body: str, sig: str) -> bool:
    expected = hashlib.sha256(f"{body}{WEBHOOK_SECRET}".encode()).hexdigest()
    return sig == expected


# ─── GET /api/payments/history ────────────────────────────────
@router.get("/history", response_model=PaymentResponse)
async def payment_history(
    status: str = None,
    limit:  int = 20,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Return all payments for the logged-in student."""
    sb = get_supabase()
    q = (sb.table("payments")
           .select("*, fees(fee_type, amount, due_date, description)")
           .eq("school_id", school_id)
           .eq("student_id", user["id"])
           .order("created_at", ascending=False)
           .limit(limit))
    if status:
        q = q.eq("status", status)
    result = await q.aexecute()
    return PaymentResponse(
        success=True, school_id=school_id,
        data={"payments": result.data or [], "total": len(result.data or [])}
    )


# ─── POST /api/payments/create-upi-link ──────────────────────
@router.post("/create-upi-link", response_model=PaymentResponse)
async def create_upi_link(
    request: PaymentRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Create a UPI payment link for a fee and persist the transaction record."""
    sb = get_supabase()

    # Fetch & validate the fee
    fee = await (sb.table("fees")
                   .select("*")
                   .eq("id", request.fee_id)
                   .eq("school_id", school_id)
                   .maybe_single()
                   .aexecute())
    if not fee.data:
        raise HTTPException(status_code=404, detail="Fee record not found")

    fd = fee.data
    already_paid = float(fd.get("amount_paid") or 0)
    discount     = float(fd.get("discount")    or 0)
    late_fine    = float(fd.get("late_fine")   or 0)
    net_amount   = float(fd["amount"]) + late_fine - discount
    remaining    = max(net_amount - already_paid, 0)

    if remaining <= 0:
        raise HTTPException(status_code=400, detail="This fee is already fully paid")

    amount = min(float(request.amount), remaining)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid payment amount")

    tx      = generate_transaction_id()
    expires = (datetime.utcnow() + timedelta(minutes=UPI_LINK_TTL_MINS)).isoformat()
    desc    = request.description or f"{fd.get('fee_type','Fee')} - {fd.get('fee_period','')}"

    # Generate UPI deep link / QR
    upi_link = generate_upi_link(
        merchant_id=MERCHANT_ID, merchant_name=MERCHANT_NAME,
        amount=amount, transaction_id=tx, description=desc
    )

    # Persist full payment record
    payment_row = {
        "school_id":       school_id,
        "student_id":      user["id"],
        "fee_id":          request.fee_id,
        "amount":          amount,
        "currency":        DEFAULT_CURRENCY,
        "status":          "pending",
        "payment_method":  "upi",
        "payment_gateway": "upi",
        "transaction_id":  tx,
        "description":     desc,
        "remarks":         f"UPI link generated for {fd.get('fee_type','Fee')}",
        "initiated_by":    user["id"],
        "expires_at":      expires,
        "refund_amount":   0,
        "refund_status":   "none",
        "created_at":      datetime.utcnow().isoformat(),
    }
    pi = await sb.table("payments").insert(payment_row).aexecute()
    if not pi.data:
        raise HTTPException(status_code=500, detail="Failed to create payment record")

    return PaymentResponse(
        success=True, school_id=school_id,
        data={
            "payment_id":      pi.data[0]["id"],
            "transaction_id":  tx,
            "amount":          amount,
            "currency":        DEFAULT_CURRENCY,
            "upi_link":        upi_link,
            "upi_id":          MERCHANT_ID,
            "fee_type":        fd.get("fee_type", "Fee Payment"),
            "fee_period":      fd.get("fee_period"),
            "due_date":        str(fd.get("due_date", "")),
            "remaining_after": remaining - amount,
            "late_fine":       late_fine,
            "discount":        discount,
            "expires_at":      expires,
            "status":          "pending",
            "description":     desc,
        }
    )


# ─── POST /api/payments/verify ────────────────────────────────
@router.post("/verify", response_model=PaymentResponse)
async def verify_payment(
    request: PaymentVerifyRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Manually verify / update a payment status (e.g. after user confirms UPI)."""
    sb = get_supabase()

    p = await (sb.table("payments")
                 .select("*")
                 .eq("id", request.payment_id)
                 .eq("school_id", school_id)
                 .eq("student_id", user["id"])
                 .maybe_single()
                 .aexecute())
    if not p.data:
        raise HTTPException(status_code=404, detail="Payment record not found")

    pd = p.data
    if pd["status"] == "success":
        return PaymentResponse(
            success=True, school_id=school_id,
            data={
                "payment_id": pd["id"], "transaction_id": pd["transaction_id"],
                "status": "success", "message": "Payment already verified",
                "verified_at": pd.get("verified_at"),
            }
        )

    now = datetime.utcnow().isoformat()
    update_data = {
        "status":              request.status,
        "upi_transaction_id":  request.upi_transaction_id,
        "updated_at":          now,
    }
    if request.status == "success":
        update_data["paid_at"]     = now
        update_data["verified_at"] = now
    elif request.status == "failed":
        update_data["failure_reason"] = getattr(request, "failure_reason", "User reported failure")

    await sb.table("payments").update(update_data).eq("id", request.payment_id).aexecute()

    # Sync fee status if payment succeeded
    if request.status == "success":
        fee = await (sb.table("fees")
                       .select("*")
                       .eq("id", pd["fee_id"])
                       .maybe_single()
                       .aexecute())
        if fee.data:
            fd        = fee.data
            new_paid  = float(fd.get("amount_paid") or 0) + float(pd["amount"])
            net_due   = float(fd["amount"]) + float(fd.get("late_fine") or 0) - float(fd.get("discount") or 0)
            new_status = "paid" if new_paid >= net_due else "partial"
            await sb.table("fees").update({
                "amount_paid": new_paid,
                "status":      new_status,
                "paid_at":     now if new_status == "paid" else None,
                "updated_at":  now,
            }).eq("id", pd["fee_id"]).aexecute()

    return PaymentResponse(
        success=True, school_id=school_id,
        data={
            "payment_id":          pd["id"],
            "transaction_id":      pd["transaction_id"],
            "upi_transaction_id":  request.upi_transaction_id,
            "amount":              pd["amount"],
            "currency":            pd.get("currency", DEFAULT_CURRENCY),
            "status":              request.status,
            "verified_at":         now if request.status == "success" else None,
            "description":         pd.get("description"),
        }
    )


# ─── POST /api/payments/refund ────────────────────────────────
@router.post("/refund", response_model=PaymentResponse)
async def initiate_refund(
    payment_id: str,
    refund_amount: float = None,
    reason: str = None,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """Initiate a partial or full refund for a successful payment."""
    sb = get_supabase()

    p = await (sb.table("payments")
                 .select("*")
                 .eq("id", payment_id)
                 .eq("school_id", school_id)
                 .maybe_single()
                 .aexecute())
    if not p.data:
        raise HTTPException(status_code=404, detail="Payment not found")

    pd = p.data
    if pd["status"] != "success":
        raise HTTPException(status_code=400, detail="Only successful payments can be refunded")

    amount      = float(pd["amount"])
    req_refund  = float(refund_amount) if refund_amount else amount
    already_ref = float(pd.get("refund_amount") or 0)
    max_refund  = amount - already_ref

    if req_refund <= 0 or req_refund > max_refund:
        raise HTTPException(status_code=400, detail=f"Refund amount must be between 0.01 and {max_refund}")

    new_ref_total  = already_ref + req_refund
    refund_status  = "full" if new_ref_total >= amount else "partial"
    new_pay_status = "refunded" if refund_status == "full" else "success"
    now            = datetime.utcnow().isoformat()

    await sb.table("payments").update({
        "refund_amount":  new_ref_total,
        "refund_status":  refund_status,
        "refund_at":      now,
        "status":         new_pay_status,
        "remarks":        reason or "Refund initiated",
        "updated_at":     now,
    }).eq("id", payment_id).aexecute()

    # Adjust fee status back if full refund
    if refund_status == "full" and pd.get("fee_id"):
        fee = await sb.table("fees").select("*").eq("id", pd["fee_id"]).maybe_single().aexecute()
        if fee.data:
            fd          = fee.data
            new_paid    = max(float(fd.get("amount_paid") or 0) - req_refund, 0)
            fee_status  = "paid" if new_paid >= float(fd["amount"]) else ("partial" if new_paid > 0 else "pending")
            await sb.table("fees").update({
                "amount_paid": new_paid,
                "status":      fee_status,
                "updated_at":  now,
            }).eq("id", pd["fee_id"]).aexecute()

    return PaymentResponse(
        success=True, school_id=school_id,
        data={
            "payment_id":    payment_id,
            "refund_amount": req_refund,
            "refund_status": refund_status,
            "refund_at":     now,
            "new_status":    new_pay_status,
        }
    )


# ─── POST /api/payments/webhook ──────────────────────────────
@router.post("/webhook")
async def payment_webhook(request: Request):
    """
    Bank/gateway webhook handler.
    Accepts: { transaction_id, status, upi_transaction_id, bank_ref_no,
               gateway_ref_id, gateway_response, amount, currency }
    """
    try:
        body_raw  = await request.body()
        body      = await request.json()

        # Verify signature if present
        sig = request.headers.get("X-Webhook-Signature", "")
        if sig and not _verify_webhook_sig(body_raw.decode(), sig):
            return {"status": "error", "message": "Invalid signature"}

        tx   = body.get("transaction_id") or body.get("tr") or body.get("orderId")
        utx  = body.get("upi_transaction_id") or body.get("txnId") or body.get("upiTxnId")
        brf  = body.get("bank_ref_no") or body.get("refNo") or body.get("bankReference") or body.get("utr")
        gref = body.get("gateway_ref_id") or body.get("razorpay_payment_id") or body.get("paymentId")
        raw_status = body.get("status", "").lower()

        if not tx:
            return {"status": "error", "message": "Missing transaction_id"}

        STATUS_MAP = {
            "success": "success", "completed": "success", "captured": "success",
            "failure": "failed", "failed": "failed", "declined": "failed",
            "processing": "processing", "pending": "pending",
            "refunded": "refunded", "cancelled": "cancelled",
        }
        st = STATUS_MAP.get(raw_status, "pending")

        sb = get_supabase()
        p  = await (sb.table("payments")
                      .select("*")
                      .eq("transaction_id", tx)
                      .maybe_single()
                      .aexecute())
        if not p.data:
            return {"status": "received", "message": "Transaction not found", "transaction_id": tx}

        xd  = p.data
        now = datetime.utcnow().isoformat()

        if xd["status"] == "success" and st == "success":
            return {"status": "received", "message": "Already processed", "transaction_id": tx}

        update_data = {
            "status":           st,
            "gateway_response": body,
            "updated_at":       now,
        }
        if utx:   update_data["upi_transaction_id"] = utx
        if brf:   update_data["bank_ref_no"]         = brf
        if gref:  update_data["gateway_ref_id"]       = gref
        if st == "success":
            update_data["paid_at"]     = now
            update_data["verified_at"] = now
        elif st == "failed":
            update_data["failure_reason"] = body.get("failure_reason") or body.get("error_description") or "Gateway declined"

        await sb.table("payments").update(update_data).eq("id", xd["id"]).aexecute()

        # Sync fee on success
        if st == "success" and xd.get("fee_id"):
            fee = await (sb.table("fees")
                           .select("*")
                           .eq("id", xd["fee_id"])
                           .maybe_single()
                           .aexecute())
            if fee.data:
                fd        = fee.data
                new_paid  = float(fd.get("amount_paid") or 0) + float(xd["amount"])
                net_due   = float(fd["amount"]) + float(fd.get("late_fine") or 0) - float(fd.get("discount") or 0)
                fee_st    = "paid" if new_paid >= net_due else "partial"
                await sb.table("fees").update({
                    "amount_paid": new_paid,
                    "status":      fee_st,
                    "paid_at":     now if fee_st == "paid" else None,
                    "updated_at":  now,
                }).eq("id", xd["fee_id"]).aexecute()

        return {
            "status":          "received",
            "transaction_id":  tx,
            "payment_status":  st,
            "upi_txn_id":      utx,
            "bank_ref_no":     brf,
            "processed_at":    now,
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}


@router.post("/pay-direct", response_model=PaymentResponse)
async def pay_direct(
    request: DirectPaymentRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """
    Directly process a simulated payment (UPI, Card, Net Banking) for a fee.
    Fetches the school's configured payment details (UPI/bank details) as recipient.
    """
    sb = get_supabase()

    # 1. Fetch & validate the fee
    fee = await (sb.table("fees")
                   .select("*")
                   .eq("id", request.fee_id)
                   .eq("school_id", school_id)
                   .maybe_single()
                   .aexecute())
    if not fee.data:
        raise HTTPException(status_code=404, detail="Fee record not found")

    fd = fee.data
    already_paid = float(fd.get("amount_paid") or 0)
    discount     = float(fd.get("discount")    or 0)
    late_fine    = float(fd.get("late_fine")   or 0)
    net_amount   = float(fd["amount"]) + late_fine - discount
    remaining    = max(net_amount - already_paid, 0)

    if remaining <= 0:
        raise HTTPException(status_code=400, detail="This fee is already fully paid")

    amount = min(float(request.amount), remaining)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid payment amount")

    # 2. Fetch school payment details
    school_config_res = await (sb.table("school_payment_configs")
                                 .select("*")
                                 .eq("school_id", school_id)
                                 .maybe_single()
                                 .aexecute())
    school_config = school_config_res.data
    if not school_config:
        # Fallback values if no school configuration is found
        school_config = {
            "upi_id": MERCHANT_ID,
            "bank_name": "State Bank of India",
            "account_number": "39871234567",
            "ifsc_code": "SBIN0001234",
            "account_holder_name": MERCHANT_NAME
        }

    # 3. Simulate payment processing based on method
    tx = generate_transaction_id()
    now = datetime.utcnow().isoformat()
    
    # Simple validation rules for simulation
    status = "success"
    failure_reason = None
    
    if request.payment_method == "card":
        if not request.card_number or len(request.card_number.replace(" ", "")) < 12:
            status = "failed"
            failure_reason = "Invalid Card Number"
        elif not request.card_cvv or len(request.card_cvv) != 3:
            status = "failed"
            failure_reason = "Invalid CVV"
    elif request.payment_method == "upi":
        if not request.upi_id or "@" not in request.upi_id:
            status = "failed"
            failure_reason = "Invalid UPI ID Format"
    elif request.payment_method == "netbanking":
        if not request.bank_name:
            status = "failed"
            failure_reason = "Bank Name Required"
    else:
        raise HTTPException(status_code=400, detail="Unsupported payment method")

    # Save payment record
    payment_row = {
        "school_id":       school_id,
        "student_id":      user["id"],
        "fee_id":          request.fee_id,
        "amount":          amount,
        "currency":        DEFAULT_CURRENCY,
        "status":          status,
        "payment_method":  request.payment_method,
        "payment_gateway": "simulated",
        "transaction_id":  tx,
        "description":     request.description or f"{fd.get('fee_type','Fee')} - {fd.get('fee_period','')}",
        "remarks":         f"Direct payment via {request.payment_method.upper()}",
        "initiated_by":    user["id"],
        "refund_amount":   0,
        "refund_status":   "none",
        "created_at":      now,
        "updated_at":      now,
    }
    
    if status == "success":
        payment_row["paid_at"] = now
        payment_row["verified_at"] = now

    pi = await sb.table("payments").insert(payment_row).aexecute()
    if not pi.data:
        raise HTTPException(status_code=500, detail="Failed to create payment record")

    # Update fee status if payment succeeded
    if status == "success":
        new_paid = already_paid + amount
        new_status = "paid" if new_paid >= net_amount else "partial"
        await sb.table("fees").update({
            "amount_paid": new_paid,
            "status":      new_status,
            "paid_at":     now if new_status == "paid" else None,
            "updated_at":  now,
        }).eq("id", request.fee_id).aexecute()

    return PaymentResponse(
        success=(status == "success"),
        school_id=school_id,
        data={
            "payment_id":          pi.data[0]["id"],
            "transaction_id":      tx,
            "amount":              amount,
            "currency":            DEFAULT_CURRENCY,
            "status":              status,
            "failure_reason":      failure_reason,
            "fee_type":            fd.get("fee_type", "Fee Payment"),
            "fee_period":          fd.get("fee_period"),
            "due_date":            str(fd.get("due_date", "")),
            "payment_method":      request.payment_method,
            "recipient_details": {
                "upi_id":              school_config["upi_id"],
                "bank_name":           school_config["bank_name"],
                "account_number":      school_config["account_number"],
                "ifsc_code":           school_config["ifsc_code"],
                "account_holder_name": school_config["account_holder_name"]
            }
        }
    )


@router.post("/pay-bulk", response_model=PaymentResponse)
async def pay_bulk(
    request: BulkPaymentRequest,
    user: dict = Depends(get_current_user),
    school_id: str = Depends(require_school_id)
):
    """
    Simulate a bulk payment clearing multiple fees under a single transaction ID.
    """
    sb = get_supabase()
    
    if not request.fee_ids:
        raise HTTPException(status_code=400, detail="No fee IDs provided")

    # 1. Fetch & validate all fees
    fees_res = await (sb.table("fees")
                        .select("*")
                        .in_("id", request.fee_ids)
                        .eq("school_id", school_id)
                        .eq("student_id", user["id"])
                        .aexecute())
    
    if not fees_res.data:
        raise HTTPException(status_code=404, detail="No matching fee records found")

    fees_data = fees_res.data
    
    # 2. Fetch school payment details
    school_config_res = await (sb.table("school_payment_configs")
                                 .select("*")
                                 .eq("school_id", school_id)
                                 .maybe_single()
                                 .aexecute())
    school_config = school_config_res.data
    if not school_config:
        school_config = {
            "upi_id": MERCHANT_ID,
            "bank_name": "State Bank of India",
            "account_number": "39871234567",
            "ifsc_code": "SBIN0001234",
            "account_holder_name": MERCHANT_NAME
        }

    # 3. Simulate payment processing based on method
    tx = generate_transaction_id()
    now = datetime.utcnow().isoformat()
    
    status = "success"
    failure_reason = None
    
    if request.payment_method == "card":
        if not request.card_number or len(request.card_number.replace(" ", "")) < 12:
            status = "failed"
            failure_reason = "Invalid Card Number"
        elif not request.card_cvv or len(request.card_cvv) != 3:
            status = "failed"
            failure_reason = "Invalid CVV"
    elif request.payment_method == "upi":
        if not request.upi_id or "@" not in request.upi_id:
            status = "failed"
            failure_reason = "Invalid UPI ID Format"
    elif request.payment_method == "netbanking":
        if not request.bank_name:
            status = "failed"
            failure_reason = "Bank Name Required"
    else:
        raise HTTPException(status_code=400, detail="Unsupported payment method")

    inserted_payments = []
    total_processed_amount = 0.0

    if status == "success":
        # Sort fees by due date ascending (FIFO) to clear oldest dues first, with ID as tie-breaker for determinism
        sorted_fees = sorted(fees_data, key=lambda x: (x.get("due_date") or "", x.get("id") or ""))
        remaining_payment = float(request.amount)

        for fd in sorted_fees:
            if remaining_payment <= 0:
                break

            already_paid = float(fd.get("amount_paid") or 0)
            discount     = float(fd.get("discount")    or 0)
            late_fine    = float(fd.get("late_fine")   or 0)
            net_amount   = float(fd["amount"]) + late_fine - discount
            remaining_due = max(net_amount - already_paid, 0)
            
            if remaining_due <= 0:
                continue
                
            amount_for_fee = min(remaining_payment, remaining_due)
            remaining_payment -= amount_for_fee
            total_processed_amount += amount_for_fee

            payment_row = {
                "school_id":       school_id,
                "student_id":      user["id"],
                "fee_id":          fd["id"],
                "amount":          amount_for_fee,
                "currency":        DEFAULT_CURRENCY,
                "status":          status,
                "payment_method":  request.payment_method,
                "payment_gateway": "simulated",
                "transaction_id":  tx,
                "description":     request.description or f"{fd.get('fee_type','Fee')} - {fd.get('fee_period','')}",
                "remarks":         f"Bulk payment via {request.payment_method.upper()}",
                "initiated_by":    user["id"],
                "refund_amount":   0,
                "refund_status":   "none",
                "created_at":      now,
                "updated_at":      now,
                "paid_at":         now,
                "verified_at":     now,
            }
            
            pi = await sb.table("payments").insert(payment_row).aexecute()
            if pi.data:
                inserted_payments.append(pi.data[0])
                
            # Update individual fee record status and amount paid
            new_paid = already_paid + amount_for_fee
            new_status = "paid" if new_paid >= net_amount else "partial"
            await sb.table("fees").update({
                "amount_paid": new_paid,
                "status":      new_status,
                "paid_at":     now if new_status == "paid" else None,
                "updated_at":  now,
            }).eq("id", fd["id"]).aexecute()
    else:
        first_fee = fees_data[0]
        payment_row = {
            "school_id":       school_id,
            "student_id":      user["id"],
            "fee_id":          first_fee["id"],
            "amount":          request.amount,
            "currency":        DEFAULT_CURRENCY,
            "status":          "failed",
            "payment_method":  request.payment_method,
            "payment_gateway": "simulated",
            "transaction_id":  tx,
            "description":     request.description or "Bulk payment failed",
            "remarks":         f"Bulk payment failed via {request.payment_method.upper()}",
            "initiated_by":    user["id"],
            "refund_amount":   0,
            "refund_status":   "none",
            "failure_reason":  failure_reason,
            "created_at":      now,
            "updated_at":      now,
        }
        pi = await sb.table("payments").insert(payment_row).aexecute()
        if pi.data:
            inserted_payments.append(pi.data[0])

    payment_id = inserted_payments[0]["id"] if inserted_payments else str(uuid.uuid4())
    
    return PaymentResponse(
        success=(status == "success"),
        school_id=school_id,
        data={
            "payment_id":          payment_id,
            "transaction_id":      tx,
            "amount":              total_processed_amount if status == "success" else request.amount,
            "currency":            DEFAULT_CURRENCY,
            "status":              status,
            "failure_reason":      failure_reason,
            "fee_type":            "Outstanding Fees",
            "fee_period":          "Bulk Payment",
            "due_date":            "",
            "payment_method":      request.payment_method,
            "recipient_details": {
                "upi_id":              school_config["upi_id"],
                "bank_name":           school_config["bank_name"],
                "account_number":      school_config["account_number"],
                "ifsc_code":           school_config["ifsc_code"],
                "account_holder_name": school_config["account_holder_name"]
            }
        }
    )

