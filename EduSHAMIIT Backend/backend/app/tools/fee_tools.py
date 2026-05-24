"""
Fee Tools - 2 LangChain @tool functions for EduSHAMIIT fee management.
Handles fee status queries and Razorpay payment link generation.
"""
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from app.middleware.auth import get_current_user_id
import os
import uuid


def get_fee_tools(school_id: str):
    """Return fee management tools scoped to this school."""

    @tool
    def get_fee_status(student_id: str = "") -> dict:
        """Get fee payment status, pending dues, and payment history for a student.
        Input: student_id (UUID, optional — defaults to the logged-in student).
        Use when a student, parent, or admin asks about fees, dues, pending payments,
        or fee balance."""
        try:
            supabase = get_supabase()
            sid = student_id or get_current_user_id()
            fees_resp = supabase.table("fees").select("*").eq("school_id", school_id).eq("student_id", sid).execute()
            fees = fees_resp.data or []
            payments_resp = supabase.table("payments").select("*").eq("school_id", school_id).eq("student_id", sid).execute()
            payments = payments_resp.data or []
            total_fees = sum(f.get("amount", 0) for f in fees)
            paid_amount = sum(p.get("amount", 0) for p in payments if p.get("status") == "success")
            pending_amount = total_fees - paid_amount
            return {
                "success": True,
                "student_id": sid,
                "total_fees": total_fees,
                "paid_amount": paid_amount,
                "pending_amount": pending_amount,
                "fees": fees,
                "payments": payments,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def create_razorpay_link(student_id: str, amount: float, description: str = "School Fee Payment") -> dict:
        """Generate a Razorpay payment link for a student's fee collection.
        Input: student_id (UUID), amount (in INR), optional description.
        Use when admin or finance team wants to send a payment link to a student or parent."""
        try:
            import razorpay
            razorpay_key = os.getenv("RAZORPAY_KEY_ID", "")
            razorpay_secret = os.getenv("RAZORPAY_KEY_SECRET", "")
            if not razorpay_key or not razorpay_secret:
                return {"success": False, "error": "Razorpay not configured"}
            client = razorpay.Client(auth=(razorpay_key, razorpay_secret))
            supabase = get_supabase()
            student_resp = supabase.table("students").select("name,phone,email").eq("id", student_id).eq("school_id", school_id).execute()
            student = (student_resp.data or [{}])[0]
            reference_id = f"fee_{student_id}_{uuid.uuid4().hex[:8]}"
            link_data = {
                "amount": int(amount * 100),
                "currency": "INR",
                "accept_partial": False,
                "description": description,
                "customer": {
                    "name": student.get("name", "Student"),
                    "contact": student.get("phone", ""),
                    "email": student.get("email", ""),
                },
                "notify": {"sms": True, "email": True},
                "reminder_enable": True,
                "notes": {"school_id": school_id, "student_id": student_id, "reference_id": reference_id},
            }
            resp = client.payment_link.create(link_data)
            supabase.table("payments").insert({
                "school_id": school_id,
                "student_id": student_id,
                "amount": amount,
                "status": "pending",
                "reference_id": reference_id,
                "razorpay_link_id": resp.get("id"),
            }).execute()
            return {
                "success": True,
                "payment_link": resp.get("short_url"),
                "link_id": resp.get("id"),
                "reference_id": reference_id,
                "amount": amount,
            }
        except ImportError:
            return {"success": False, "error": "razorpay not installed"}
        except Exception as e:
            return {"success": False, "error": str(e)}

    return [get_fee_status, create_razorpay_link]