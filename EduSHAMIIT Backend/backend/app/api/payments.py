"Payments API - UPI payment link generation, verification, and bank webhook handler."
import uuid
import hashlib
import os
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, Request
from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase
from app.services.upi_service import generate_upi_link
from app.models import PaymentRequest, PaymentVerifyRequest, PaymentResponse

router = APIRouter()

MERCHANT_ID = os.getenv("UPI_MERCHANT_ID", "eduSHAMIIT@ybl")
MERCHANT_NAME = os.getenv("UPI_MERCHANT_NAME", "EduSHAMIIT")
WEBHOOK_SECRET = os.getenv("WEBHOOK_SECRET", "eduSHAMIIT-webhook-secret-2026")


def generate_transaction_id() -> str:
    "Generate a unique transaction ID with EDU prefix."
    timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
    unique = uuid.uuid4().hex[:8].upper()
    return f"EDU-{timestamp}-{unique}"


@router.post("/create-upi-link", response_model=PaymentResponse)
async def create_upi_link(request: PaymentRequest, user: dict = Depends(get_current_user), school_id: str = Depends(require_school_id)):
    sb = get_supabase()
    fee = await sb.table("fees").select("*").eq("id", request.fee_id).eq("school_id", school_id).maybe_single().aexecute()
    if not fee.data:
        raise HTTPException(status_code=404, detail="Fee record not found")
    fd = fee.data
    remaining = float(fd["amount"]) - float(fd.get("amount_paid", 0))
    if remaining <= 0:
        raise HTTPException(status_code=400, detail="This fee is already fully paid")
    amount = min(float(request.amount), remaining)
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Invalid payment amount")
    tx = generate_transaction_id()
    pr = {"school_id": school_id, "student_id": user["id"], "fee_id": request.fee_id, "transaction_id": tx, "amount": amount, "currency": "INR", "status": "pending", "payment_method": "upi", "description": request.description or "EduSHAMIIT Fee Payment"}
    pi = await sb.table("payments").insert(pr).aexecute()
    if not pi.data:
        raise HTTPException(status_code=500, detail="Failed to create payment record")
    ul = generate_upi_link(merchant_id=MERCHANT_ID, merchant_name=MERCHANT_NAME, amount=amount, transaction_id=tx, description=request.description or "EduSHAMIIT Fee")
    return PaymentResponse(success=True, school_id=school_id, data={"payment_id": pi.data[0]["id"], "transaction_id": tx, "amount": amount, "currency": "INR", "upi_link": ul, "upi_id": MERCHANT_ID, "fee_type": fd.get("fee_type", "Fee Payment"), "due_date": fd.get("due_date"), "remaining_amount": remaining, "status": "pending"})


@router.post("/verify", response_model=PaymentResponse)
async def verify_payment(request: PaymentVerifyRequest, user: dict = Depends(get_current_user), school_id: str = Depends(require_school_id)):
    sb = get_supabase()
    p = await sb.table("payments").select("*").eq("id", request.payment_id).eq("school_id", school_id).maybe_single().aexecute()
    if not p.data:
        raise HTTPException(status_code=404, detail="Payment record not found")
    pd = p.data
    if pd["status"] == "success":
        return PaymentResponse(success=True, school_id=school_id, data={"payment_id": pd["id"], "transaction_id": pd["transaction_id"], "status": "success", "message": "Payment was already verified"})
    ud = {"status": request.status, "verified_at": datetime.utcnow().isoformat()}
    if request.upi_transaction_id:
        ud["upi_transaction_id"] = request.upi_transaction_id
    await sb.table("payments").update(ud).eq("id", request.payment_id).aexecute()
    if request.status == "success":
        fee = await sb.table("fees").select("*").eq("id", pd["fee_id"]).maybe_single().aexecute()
        if fee.data:
            fd = fee.data
            np = float(fd.get("amount_paid", 0)) + float(pd["amount"])
            ns = "paid" if np >= float(fd["amount"]) else "partial"
            await sb.table("fees").update({"amount_paid": np, "status": ns, "paid_at": datetime.utcnow().isoformat() if ns == "paid" else None}).eq("id", pd["fee_id"]).aexecute()
    return PaymentResponse(success=True, school_id=school_id, data={"payment_id": pd["id"], "transaction_id": pd["transaction_id"], "amount": pd["amount"], "status": request.status, "upi_transaction_id": request.upi_transaction_id, "verified_at": ud["verified_at"]})


@router.post("/webhook")
async def payment_webhook(request: Request):
    try:
        body = await request.json()
        sig = request.headers.get("X-Webhook-Signature", "")
        if sig:
            exp = hashlib.sha256((str(body) + WEBHOOK_SECRET).encode()).hexdigest()
        tx = body.get("transaction_id") or body.get("tr")
        utx = body.get("upi_transaction_id") or body.get("txnId")
        sr = body.get("status", "").lower()
        brf = body.get("bank_ref_no") or body.get("refNo") or body.get("bankReference")
        if not tx:
            return {"status": "error", "message": "Missing transaction_id"}
        sm = {"success": "success", "completed": "success", "failure": "failed", "failed": "failed", "pending": "pending"}
        st = sm.get(sr, "pending")
        sb = get_supabase()
        p = await sb.table("payments").select("*").eq("transaction_id", tx).maybe_single().aexecute()
        if not p.data:
            return {"status": "received", "message": "Transaction not found"}
        xd = p.data
        if xd["status"] == "success" and st == "success":
            return {"status": "received", "message": "Already processed"}
        ud = {"status": st, "upi_transaction_id": utx or xd.get("upi_transaction_id"), "bank_ref_no": brf, "webhook_payload": body, "verified_at": datetime.utcnow().isoformat()}
        await sb.table("payments").update(ud).eq("id", xd["id"]).aexecute()
        if st == "success":
            fee = await sb.table("fees").select("*").eq("id", xd["fee_id"]).maybe_single().aexecute()
            if fee.data:
                fd = fee.data
                np = float(fd.get("amount_paid", 0)) + float(xd["amount"])
                ns = "paid" if np >= float(fd["amount"]) else "partial"
                await sb.table("fees").update({"amount_paid": np, "status": ns, "paid_at": datetime.utcnow().isoformat() if ns == "paid" else None}).eq("id", xd["fee_id"]).aexecute()
        return {"status": "received", "transaction_id": tx, "payment_status": st}
    except Exception as e:
        return {"status": "error", "message": str(e)}

