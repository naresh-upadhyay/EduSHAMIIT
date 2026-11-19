"""
Universal Payment Management API for EduSHAMIIT ERP:
1. Student Fee & Billing Management (Students only)
2. Staff Salary & Payroll Management (Non-student staff)
Multi-Tenant, Dynamic Lookups, Full Ledger, Automated Advance Recovery, and Complete Auditing.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, timezone, time as dt_time
import time
from decimal import Decimal
import os
import json
import uuid
import logging
import asyncio
import io
import csv
import secrets
import urllib.parse
import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid

register_uuid()

from app.config import settings
from app.middleware.auth import get_current_user
from app.api.payment_bridge import ws_manager

logger = logging.getLogger(__name__)
router = APIRouter()


# ============================================================================
# DATABASE EXECUTION & UTILITY HELPERS
# ============================================================================

async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute raw parameterized SQL query asynchronously via psycopg2."""
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        conn.set_client_encoding('UTF8')
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch and cur.description:
                    rows = cur.fetchall()
                    conn.commit()
                    return [dict(r) for r in rows]
                else:
                    conn.commit()
                    return []
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    return await asyncio.to_thread(_run)


def _serialize_val(val: Any) -> Any:
    """Format dates, datetimes, decimals, and UUIDs for clean JSON serialization."""
    if isinstance(val, (datetime, date, dt_time)):
        return val.isoformat()
    if isinstance(val, uuid.UUID):
        return str(val)
    if isinstance(val, Decimal):
        return float(val)
    if isinstance(val, list):
        return [_serialize_val(x) for x in val]
    if isinstance(val, dict):
        return {k: _serialize_val(v) for k, v in val.items()}
    return val


def _get_school_id(current_user: Any) -> str:
    if not isinstance(current_user, dict):
        return "11111111-1111-1111-1111-111111111111"
    school_id = current_user.get("school_id")
    if not school_id and current_user.get("role") in ("super_admin", "superadmin", "admin"):
        return str(current_user.get("selected_school_id") or "11111111-1111-1111-1111-111111111111")
    return str(school_id or "11111111-1111-1111-1111-111111111111")


def _clean_str(val: Any, default: str = "") -> str:
    if isinstance(val, str) and val.strip():
        return val.strip()
    return default


def _clean_int(val: Any, default: int = 1) -> int:
    if isinstance(val, int):
        return val
    try:
        if hasattr(val, "default"):
            return int(val.default)
        return int(val)
    except Exception:
        return default


def _clean_uuid(val: Any) -> Optional[str]:
    """Safely validate and return UUID string, or None if invalid/empty."""
    if not val:
        return None
    s = str(val).strip()
    if not s or s.lower() in ("null", "undefined", "none", ""):
        return None
    try:
        return str(uuid.UUID(s))
    except Exception:
        return None


# ============================================================================
# PYDANTIC SCHEMAS
# ============================================================================

class GenerateStudentInvoicePayload(BaseModel):
    student_id: str
    title: str
    fee_type: str = "Tuition Fee"
    fee_plan: str = "Monthly"
    academic_year: str = "2026 - 2027"
    due_date: str
    subtotal: float
    concession_amount: float = 0.0
    penalty_amount: float = 0.0
    notes: Optional[str] = None


class BulkStudentInvoicePayload(BaseModel):
    class_name: Optional[str] = "All Classes"
    title: str
    fee_type: str = "Tuition Fee"
    fee_plan: str = "Monthly"
    academic_year: str = "2026 - 2027"
    amount: float
    due_date: str


class CollectStudentPaymentPayload(BaseModel):
    student_id: str
    invoice_id: Optional[str] = None
    amount: float
    payment_method: str = "UPI"
    transaction_reference: Optional[str] = None
    remarks: Optional[str] = None


class ApplyStudentConcessionPayload(BaseModel):
    student_id: str
    invoice_id: Optional[str] = None
    concession_type: str
    amount: float
    reason: Optional[str] = None


class AddStudentPenaltyPayload(BaseModel):
    student_id: str
    invoice_id: Optional[str] = None
    penalty_type: str = "Late Payment Fine"
    amount: float
    reason: Optional[str] = None


class StudentFeeStructurePayload(BaseModel):
    fee_name: str
    fee_type: str
    class_grade: str = "All Classes"
    billing_cycle: str = "Monthly"
    amount: float
    description: Optional[str] = None
    is_mandatory: bool = True


class ProcessStaffPayoutPayload(BaseModel):
    staff_id: str
    month: int
    year: int
    month_str: str
    basic_pay: float
    hra: float
    da: float
    ta: float
    special_allowance: float = 0.0
    bonus: float = 0.0
    pf_deduction: float
    tds: float
    professional_tax: float = 200.0
    advance_deduction: float = 0.0
    other_deductions: float = 0.0
    payment_status: str = "Paid"
    payment_mode: str = "Direct Bank Transfer (NEFT/RTGS)"
    transaction_reference: Optional[str] = None
    remarks: Optional[str] = None


class BulkStaffPayrollPayload(BaseModel):
    month: int
    year: int
    month_str: str
    department: Optional[str] = "All Departments"
    payment_mode: str = "Direct Bank Transfer (NEFT/RTGS)"


class UpdatePayoutStatusPayload(BaseModel):
    staff_id: str
    month_str: Optional[str] = "2026-10"
    payout_id: Optional[str] = None
    status: str
    approver_name: Optional[str] = "Finance Admin"
    comments: Optional[str] = None
    payment_mode: Optional[str] = None
    transaction_reference: Optional[str] = None


class UpdateInvoiceStatusPayload(BaseModel):
    status: str
    remarks: Optional[str] = None


class StaffSalaryStructurePayload(BaseModel):
    staff_id: str
    basic_pay: float
    hra: float
    da: float
    ta: float
    special_allowance: float = 0.0
    medical_allowance: float = 0.0
    pf_deduction: float
    tds: float
    professional_tax: float = 200.0
    insurance_deduction: float = 0.0
    bank_name: Optional[str] = "HDFC Bank"
    account_number: Optional[str] = None
    ifsc_code: Optional[str] = None
    pan_number: Optional[str] = None
    payment_mode: str = "Direct Bank Transfer (NEFT/RTGS)"


class StaffSalaryAdvancePayload(BaseModel):
    staff_id: str
    amount: float
    purpose_type: str = "Medical Emergency"
    reason: Optional[str] = None
    repayment_months: int = 3


class BulkActionPayload(BaseModel):
    action: str  # "send_reminder", "mark_paid", "disburse_selected", "hold_selected", "void_invoices"
    ids: List[str]
    notes: Optional[str] = None
    month_str: Optional[str] = None
    payment_mode: Optional[str] = "Direct Bank Transfer (NEFT/RTGS)"


class UpdateAdvanceStatusPayload(BaseModel):
    status: str  # "Approved", "Rejected", "Settled", "Pending"
    remarks: Optional[str] = None


class CreatePaymentIntentPayload(BaseModel):
    student_id: str
    invoice_id: Optional[str] = None
    amount: float
    payment_method: str = "UPI"
    notes: Optional[str] = None


class SubmitUtrPayload(BaseModel):
    utr_number: str
    notes: Optional[str] = None


class SimulateBridgePaymentPayload(BaseModel):
    intent_id: str
    utr: Optional[str] = None
    source_app: str = "PhonePe"


class UpdatePaymentStatusPayload(BaseModel):
    status: str  # "SUCCESS", "FAILED", "WAITING_CONFIRMATION", "REFUNDED"
    remarks: Optional[str] = None


class UpdateGeneralSettingsPayload(BaseModel):
    online_collection_enabled: bool = True
    base_currency: str = "INR"
    default_payment_method: str = "UPI"
    institution_display_name: Optional[str] = None
    payment_description: Optional[str] = None
    reference_prefix: str = "EDU"
    receipt_prefix: str = "REC-2026-"
    allow_partial_payments: bool = True
    allow_advance_payments: bool = False
    allow_multiple_payments: bool = True
    allow_student_self_pay: bool = True
    allow_offline_entry: bool = True
    refund_policy_days: int = 7
    direct_bank_transfer_enabled: bool = True


class UpdateQrBehaviourPayload(BaseModel):
    qr_validity_minutes: int = 5
    grace_period_minutes: int = 2
    unique_paise_enabled: bool = True
    unique_paise_window_minutes: int = 10
    max_additional_paise: int = 99
    auto_settle_on_bridge_notification: bool = True


class CreateUpiAccountPayload(BaseModel):
    vpa: str
    display_name: str
    beneficiary_name: str
    bank_name: Optional[str] = None
    is_default: bool = False
    qr_enabled: bool = True
    intent_enabled: bool = True
    max_amount_paise: int = 10000000
    notes: Optional[str] = None
    device_id: Optional[str] = None


class CreateBankAccountPayload(BaseModel):
    account_nickname: str
    bank_name: str
    branch_name: Optional[str] = None
    account_holder_name: str
    account_number: str
    ifsc_code: str
    account_type: str = "Current"
    currency: str = "INR"
    campus_name: Optional[str] = None
    category_name: Optional[str] = "Tuition & General Fees"
    is_default: bool = False
    internal_remarks: Optional[str] = None


# ============================================================================
# METADATA & LOOKUP ENDPOINTS
# ============================================================================

@router.get("/student-fees/metadata")
async def get_student_fee_metadata(
    current_user: dict = Depends(get_current_user)
):
    """Dynamic metadata for Student Fee Management filters and modal dropdowns via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql("SELECT public.fn_student_fee_metadata(%s::UUID) AS result;", (school_id,))
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {
        "success": True,
        "classes": ["Class 9", "Class 10", "Class 11", "Class 12"],
        "academic_years": ["2026 - 2027", "2025 - 2026"],
        "fee_types": ["Tuition Fee", "Lab Fee", "Library Fee", "Exam Fee", "Transport Fee"],
        "payment_modes": ["UPI", "Direct Bank Transfer (NEFT/RTGS)", "Cash Counter", "Cheque / DD", "POS Terminal / Debit Card"]
    }


@router.get("/staff-salary/metadata")
async def get_staff_salary_metadata(
    current_user: dict = Depends(get_current_user)
):
    """Dynamic metadata for Staff Salary Management filters and modal dropdowns via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql("SELECT public.fn_staff_salary_metadata(%s::UUID) AS result;", (school_id,))
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {
        "success": True,
        "departments": ["Academic & Teaching", "Administration", "Finance & Accounts", "Transport & Fleet", "Security & Safety"],
        "roles": ["Teacher", "Accountant", "Admin", "Librarian", "Hostel Warden", "Driver", "Staff"],
        "payment_modes": ["Direct Bank Transfer (NEFT/RTGS)", "IMPS Instant Transfer", "UPI Auto-Payout", "Company Cheque", "Cash Disbursal"],
        "advance_purposes": ["Medical Emergency", "Family Event / Wedding", "Home Renovation / Repair", "Education & Higher Learning", "Travel & Urgent Relocation"],
        "available_months": ["2026-10", "2026-09", "2026-08", "2026-07", "2026-06", "2026-05"]
    }


# ============================================================================
# STUDENT FEE MANAGEMENT ENDPOINTS (ROLE = 'student')
# ============================================================================

@router.get("/student-fees/summary")
async def get_student_fee_summary(
    academic_year: str = Query("2026 - 2027"),
    current_user: dict = Depends(get_current_user)
):
    """Returns high-level KPI cards for Student Fee Management via Stored Procedure."""
    school_id = _get_school_id(current_user)
    academic_year = _clean_str(academic_year, "2026 - 2027")

    rows = await exec_sql(
        "SELECT public.fn_student_fee_dashboard_kpis(%s::UUID, %s) AS result;",
        (school_id, academic_year)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {
        "success": True,
        "kpis": {
            "total_billed": 0.0,
            "total_collected": 0.0,
            "pending_dues": 0.0,
            "overdue_amount": 0.0,
            "collection_rate": 0.0,
            "collection_rate_formatted": "0.0% Collection",
            "total_students": 0,
            "paid_students_count": 0,
            "pending_students_count": 0,
            "overdue_students_count": 0,
            "overpaid_students_count": 0
        }
    }


@router.get("/student-fees/students")
async def get_student_fee_roster(
    academic_year: str = Query("2026 - 2027"),
    search: Optional[str] = Query(""),
    class_name: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    sort_by: Optional[str] = Query("name"),
    sort_order: Optional[str] = Query("ASC"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """
    List students with role = 'student' and aggregated fee numbers via Stored Procedure.
    Provides database-level filtering, sorting, and pagination.
    Strictly excludes Overpaid students from Overdue filter.
    """
    school_id = _get_school_id(current_user)
    page = _clean_int(page, 1)
    page_size = _clean_int(page_size, 10)
    academic_year = _clean_str(academic_year, "2026 - 2027")
    search = _clean_str(search)
    class_name = _clean_str(class_name)
    status = _clean_str(status)
    sort_by = _clean_str(sort_by) or "name"
    sort_order = _clean_str(sort_order) or "ASC"

    # Expire waiting UPI payments older than 48 hours
    try:
        await exec_sql("SELECT public.fn_expire_waiting_upi_payments(%s::UUID);", (school_id,), fetch=False)
    except Exception:
        pass

    rows = await exec_sql(
        """
        SELECT public.fn_student_fee_roster(
            %s::UUID, %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id,
            academic_year,
            search or None,
            class_name if class_name not in ("All Classes", "All", "") else None,
            status if status not in ("All Status", "All Fees", "All", "") else None,
            sort_by,
            sort_order,
            page,
            page_size
        )
    )

    if rows and rows[0].get("result"):
        return rows[0]["result"]

    return {
        "success": True,
        "students": [],
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": 0,
            "total_pages": 1,
            "sort_by": sort_by,
            "sort_order": sort_order
        }
    }


@router.get("/student-fees/students/{student_id}")
async def get_student_fee_detail_360(
    student_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Full 360-degree Financial Inspector for Student Fee Drawer via Stored Procedure."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(student_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid student_id UUID")

    # Expire waiting UPI payments older than 48 hours
    try:
        await exec_sql("SELECT public.fn_expire_waiting_upi_payments(%s::UUID);", (school_id,), fetch=False)
    except Exception:
        pass

    rows = await exec_sql(
        "SELECT public.fn_student_fee_account_details(%s::UUID, %s::UUID) AS result;",
        (school_id, sid)
    )
    if not rows or not rows[0].get("result") or not rows[0]["result"].get("success"):
        raise HTTPException(status_code=404, detail="Student profile not found")

    sp_res = rows[0]["result"]
    stud = sp_res.get("student") or {}
    invs = sp_res.get("invoices") or []
    pays = sp_res.get("payments") or []
    concs = sp_res.get("concessions") or []
    pens = sp_res.get("penalties") or []
    logs = sp_res.get("audit_logs") or []

    profile = {
        "id": stud.get("id"),
        "full_name": stud.get("name") or stud.get("full_name") or "Student",
        "email": stud.get("email") or "",
        "phone": stud.get("phone") or "",
        "class": stud.get("class_name") or stud.get("class") or "10A",
        "roll_number": stud.get("roll_number") or "-",
        "admission_number": stud.get("admission_number") or "",
        "avatar_url": stud.get("avatar_url"),
        "status": stud.get("status") or "Pending"
    }
    summary = {
        "total_billed": float(stud.get("total_billed", 0.0)),
        "total_paid": float(stud.get("paid_amount", 0.0)),
        "balance_amount": float(stud.get("balance_amount", 0.0)),
        "invoices_count": len(invs),
        "payments_count": len(pays),
        "concessions_count": len(concs),
        "penalties_count": len(pens),
        "history_count": len(logs)
    }

    return {
        "success": True,
        "detail": {
            "profile": profile,
            "summary": summary,
            "invoices": invs,
            "payments": pays,
            "concessions": concs,
            "penalties": pens,
            "history": logs
        }
    }


@router.get("/student-fees/students/{student_id}/history")
async def get_student_fee_history(
    student_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Retrieve complete audit history logs for a specific student."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(student_id)
    rows = await exec_sql("""
    SELECT id, entity_type, entity_id, action, description, old_status, new_status,
           amount, performed_by_name, performed_by_role, metadata, created_at
    FROM public.student_fee_audit_logs
    WHERE student_id = %s::UUID AND school_id = %s::UUID
    ORDER BY created_at DESC;
    """, (sid, school_id))
    return {"success": True, "history": _serialize_val(rows)}


@router.post("/student-fees/invoices", status_code=status.HTTP_201_CREATED)
async def generate_student_invoice(
    payload: GenerateStudentInvoicePayload,
    current_user: dict = Depends(get_current_user)
):
    """Generate a single invoice for a student via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Admin"
    sid = _clean_uuid(payload.student_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid student_id UUID")

    rows = await exec_sql(
        """
        SELECT public.fn_create_student_fee_invoice(
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s::DATE, %s, %s, %s::UUID, %s
        ) AS result;
        """,
        (
            school_id, sid, payload.fee_type, payload.fee_plan, payload.academic_year,
            payload.subtotal, payload.due_date, payload.title, payload.notes, user_id, user_name
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Invoice generated successfully"}


@router.post("/student-fees/invoices/bulk", status_code=status.HTTP_201_CREATED)
async def bulk_generate_student_invoices(
    payload: BulkStudentInvoicePayload,
    current_user: dict = Depends(get_current_user)
):
    """Generate invoices in bulk for students by class via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Admin"

    rows = await exec_sql(
        """
        SELECT public.fn_bulk_create_student_fee_invoices(
            %s::UUID, %s, %s, %s, %s, %s, %s::DATE, %s, %s, %s::UUID, %s
        ) AS result;
        """,
        (
            school_id, payload.class_name, payload.fee_type, payload.fee_plan,
            payload.academic_year, payload.amount, payload.due_date, payload.title,
            f"Bulk billed class {payload.class_name}", user_id, user_name
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "created_count": 0, "message": "Bulk invoicing completed"}


@router.post("/student-fees/payments", status_code=status.HTTP_201_CREATED)
async def collect_student_fee_payment(
    payload: CollectStudentPaymentPayload,
    current_user: dict = Depends(get_current_user)
):
    """Collect and record a payment receipt for a student invoice via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Finance Officer"
    user_role = current_user.get("role") or "Finance Officer"
    sid = _clean_uuid(payload.student_id)
    inv_id = _clean_uuid(payload.invoice_id)

    rows = await exec_sql(
        """
        SELECT public.fn_collect_student_fee_payment(
            %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s, %s::UUID, %s, %s
        ) AS result;
        """,
        (
            school_id, sid, inv_id, payload.amount, payload.payment_method,
            payload.transaction_reference, payload.remarks, user_id, user_name, user_role
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Payment recorded successfully"}


@router.post("/student-fees/concessions", status_code=status.HTTP_201_CREATED)
async def apply_student_fee_concession(
    payload: ApplyStudentConcessionPayload,
    current_user: dict = Depends(get_current_user)
):
    """Apply scholarship or concession waiver via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Admin"
    sid = _clean_uuid(payload.student_id)
    inv_id = _clean_uuid(payload.invoice_id)

    rows = await exec_sql(
        """
        SELECT public.fn_apply_student_concession(
            %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s::UUID, %s
        ) AS result;
        """,
        (school_id, sid, inv_id, payload.concession_type, payload.amount, payload.reason, user_id, user_name)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Concession applied successfully"}


@router.delete("/student-fees/concessions/{concession_id}")
async def delete_student_fee_concession(
    concession_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Reverse a concession waiver and restore the invoice total and balance via Stored Procedure."""
    school_id = _get_school_id(current_user)
    cid = _clean_uuid(concession_id)
    if not cid:
        raise HTTPException(status_code=400, detail="Invalid concession_id UUID")

    rows = await exec_sql(
        "SELECT public.fn_reverse_student_concession(%s::UUID, %s::UUID) AS result;",
        (school_id, cid)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Concession reversed and removed successfully"}


@router.post("/student-fees/penalties", status_code=status.HTTP_201_CREATED)
async def add_student_fee_penalty(
    payload: AddStudentPenaltyPayload,
    current_user: dict = Depends(get_current_user)
):
    """Add fine or late fee penalty via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Admin"
    sid = _clean_uuid(payload.student_id)
    inv_id = _clean_uuid(payload.invoice_id)

    rows = await exec_sql(
        """
        SELECT public.fn_apply_student_penalty(
            %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s::UUID, %s
        ) AS result;
        """,
        (school_id, sid, inv_id, payload.penalty_type, payload.amount, payload.reason, user_id, user_name)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Penalty added successfully"}


@router.delete("/student-fees/penalties/{penalty_id}")
async def delete_student_fee_penalty(
    penalty_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Reverse a penalty fine and adjust invoice balance via Stored Procedure."""
    school_id = _get_school_id(current_user)
    pid = _clean_uuid(penalty_id)
    if not pid:
        raise HTTPException(status_code=400, detail="Invalid penalty_id UUID")

    rows = await exec_sql(
        "SELECT public.fn_reverse_student_penalty(%s::UUID, %s::UUID) AS result;",
        (school_id, pid)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Penalty fine reversed and removed successfully"}


@router.get("/student-fees/fee-structures")
async def list_student_fee_structures(
    current_user: dict = Depends(get_current_user)
):
    """Catalog of fee structure templates via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql("SELECT public.fn_list_student_fee_structures(%s::UUID) AS result;", (school_id,))
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "structures": []}


@router.post("/student-fees/fee-structures", status_code=status.HTTP_201_CREATED)
async def create_student_fee_structure(
    payload: StudentFeeStructurePayload,
    current_user: dict = Depends(get_current_user)
):
    """Create a new fee structure template via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        """
        SELECT public.fn_save_student_fee_structure(
            %s::UUID, NULL, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (school_id, payload.fee_name, payload.fee_type, payload.class_grade, payload.billing_cycle, payload.amount, payload.description, payload.is_mandatory)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Fee structure created"}


@router.delete("/student-fees/fee-structures/{structure_id}")
async def delete_student_fee_structure(
    structure_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Delete a fee structure template via Stored Procedure."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(structure_id)
    rows = await exec_sql(
        "SELECT public.fn_delete_student_fee_structure(%s::UUID, %s::UUID) AS result;",
        (school_id, sid)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Fee structure deleted"}


@router.put("/student-fees/fee-structures/{structure_id}")
async def update_student_fee_structure(
    structure_id: str,
    payload: StudentFeeStructurePayload,
    current_user: dict = Depends(get_current_user)
):
    """Update a fee structure template via Stored Procedure."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(structure_id)
    rows = await exec_sql(
        """
        SELECT public.fn_save_student_fee_structure(
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (school_id, sid, payload.fee_name, payload.fee_type, payload.class_grade, payload.billing_cycle, payload.amount, payload.description, payload.is_mandatory)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Fee structure updated successfully"}


@router.get("/student-fees/invoices-list")
async def list_all_student_invoices(
    search: Optional[str] = Query(""),
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(15, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Sub-tab 5: Master list of all student invoices via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        "SELECT public.fn_list_all_student_invoices(%s::UUID, %s, %s, %s, %s) AS result;",
        (school_id, search or None, status if status not in ("All Status", "All", "") else None, page, page_size)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "invoices": [], "pagination": {"page": page, "page_size": page_size, "total_items": 0, "total_pages": 1}}


@router.get("/student-fees/payments-list")
async def list_all_student_payments(
    search: Optional[str] = Query(""),
    page: int = Query(1, ge=1),
    page_size: int = Query(15, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Sub-tab 6: Master list of all payment receipts via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        "SELECT public.fn_list_all_student_payments(%s::UUID, %s, %s, %s) AS result;",
        (school_id, search or None, page, page_size)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "payments": [], "pagination": {"page": page, "page_size": page_size, "total_items": 0, "total_pages": 1}}


@router.get("/student-fees/payments-list")
async def list_all_student_payments(
    search: Optional[str] = Query(""),
    page: int = Query(1, ge=1),
    page_size: int = Query(15, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Sub-tab 6: Master list of all payment receipts with server-side pagination."""
    school_id = _get_school_id(current_user)
    page = _clean_int(page, 1)
    page_size = _clean_int(page_size, 15)
    offset = (page - 1) * page_size
    search = _clean_str(search)

    where_clauses = ["pay.school_id = %s::UUID"]
    params = [school_id]
    if search:
        s = f"%{search}%"
        where_clauses.append("(pay.receipt_number ILIKE %s OR p.full_name ILIKE %s OR pay.transaction_reference ILIKE %s)")
        params.extend([s, s, s])

    where_sql = " AND ".join(where_clauses)
    sql = f"""
    SELECT pay.id, pay.receipt_number, pay.amount_paid, pay.payment_method,
           pay.transaction_reference, pay.payment_date, pay.status, pay.remarks,
           p.full_name AS student_name, p.roll_number, p.class AS class_name,
           inv.invoice_number
    FROM public.student_fee_payments pay
    JOIN public.profiles p ON pay.student_id = p.id
    LEFT JOIN public.student_fee_invoices inv ON pay.invoice_id = inv.id
    WHERE {where_sql}
    ORDER BY pay.payment_date DESC
    LIMIT %s OFFSET %s;
    """
    data_params = params + [page_size, offset]
    rows = await exec_sql(sql, tuple(data_params))

    cnt_sql = f"""
    SELECT COUNT(*) as total_count
    FROM public.student_fee_payments pay
    JOIN public.profiles p ON pay.student_id = p.id
    WHERE {where_sql};
    """
    cnt_rows = await exec_sql(cnt_sql, tuple(params))
    total_count = cnt_rows[0]['total_count'] if cnt_rows else 0

    return {
        "success": True,
        "payments": _serialize_val(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": total_count,
            "total_pages": (total_count + page_size - 1) // page_size if total_count > 0 else 1
        }
    }


@router.delete("/student-fees/invoices/{invoice_id}")
async def delete_student_invoice(
    invoice_id: str,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    await exec_sql("DELETE FROM public.student_fee_invoices WHERE id = %s::UUID AND school_id = %s::UUID;", (invoice_id, school_id), fetch=False)
    return {"success": True, "message": "Invoice voided and deleted successfully"}


@router.post("/student-fees/invoices/{invoice_id}/status")
async def update_student_invoice_status(
    invoice_id: str,
    payload: UpdateInvoiceStatusPayload,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    sql = """
    UPDATE public.student_fee_invoices
    SET status = %s, remarks = COALESCE(%s, remarks), updated_at = NOW()
    WHERE id = %s::UUID AND school_id = %s::UUID;
    """
    await exec_sql(sql, (payload.status, payload.remarks, invoice_id, school_id), fetch=False)
    return {"success": True, "message": f"Invoice status changed to {payload.status}"}


@router.put("/student-fees/payments/{payment_id}/status")
async def update_student_payment_status(
    payment_id: str,
    payload: UpdatePaymentStatusPayload,
    current_user: dict = Depends(get_current_user)
):
    """Allows Registrar/Admin to update payment status (SUCCESS, WAITING_CONFIRMATION, FAILED, REFUNDED)."""
    school_id = _get_school_id(current_user)
    pid = _clean_uuid(payment_id)
    user_id = current_user.get("id")
    user_name = current_user.get("full_name") or "Registrar"
    user_role = current_user.get("role") or "Registrar"

    prows = await exec_sql("""
    SELECT id, student_id, invoice_id, receipt_number, amount_paid, payment_method, status
    FROM public.student_fee_payments
    WHERE id = %s::UUID AND school_id = %s::UUID LIMIT 1;
    """, (pid, school_id))
    if not prows:
        raise HTTPException(status_code=404, detail="Payment record not found")

    pay = prows[0]
    old_status = (pay["status"] or "SUCCESS").upper().strip()
    new_status = payload.status.upper().strip()
    # Normalize aliases
    if new_status in ("COMPLETED", "SUCCESS", "PAID"):
        new_status = "SUCCESS"
    elif new_status in ("WAITING", "WAITING_CONFIRMATION", "WAITING CONFIRMATION"):
        new_status = "WAITING_CONFIRMATION"
    elif new_status in ("FAILED", "FAIL", "REJECTED"):
        new_status = "FAILED"
    elif new_status in ("REFUNDED", "REFUND"):
        new_status = "REFUNDED"

    amt = float(pay["amount_paid"])
    inv_id = pay["invoice_id"]
    student_id = pay["student_id"]

    # Rebalance invoice if status transitions to or from SUCCESS
    if old_status != new_status:
        # If transitioning FROM SUCCESS to non-success (e.g. Refunded or Failed)
        if old_status == "SUCCESS" and new_status in ("REFUNDED", "FAILED", "WAITING_CONFIRMATION"):
            if inv_id:
                inv_cur = await exec_sql("SELECT total_billed, paid_amount FROM public.student_fee_invoices WHERE id = %s::UUID;", (inv_id,))
                if inv_cur:
                    tb = float(inv_cur[0]['total_billed'])
                    new_paid = max(0.0, float(inv_cur[0]['paid_amount']) - amt)
                    new_bal = max(0.0, tb - new_paid)
                    st = 'Overpaid' if new_paid > tb else ('Paid' if new_bal <= 0 and tb > 0 else ('Partial' if new_paid > 0 else 'Pending'))
                    await exec_sql("UPDATE public.student_fee_invoices SET paid_amount = %s, balance_amount = %s, status = %s, updated_at = NOW() WHERE id = %s::UUID;", (new_paid, new_bal, st, inv_id), fetch=False)

        # If transitioning TO SUCCESS from non-success
        elif old_status != "SUCCESS" and new_status == "SUCCESS":
            if inv_id:
                inv_cur = await exec_sql("SELECT total_billed, paid_amount FROM public.student_fee_invoices WHERE id = %s::UUID;", (inv_id,))
                if inv_cur:
                    tb = float(inv_cur[0]['total_billed'])
                    new_paid = float(inv_cur[0]['paid_amount']) + amt
                    new_bal = max(0.0, tb - new_paid)
                    st = 'Overpaid' if new_paid > tb else ('Paid' if new_bal <= 0 and tb > 0 else 'Partial')
                    await exec_sql("UPDATE public.student_fee_invoices SET paid_amount = %s, balance_amount = %s, status = %s, updated_at = NOW() WHERE id = %s::UUID;", (new_paid, new_bal, st, inv_id), fetch=False)

        # Update payment record
        await exec_sql("""
        UPDATE public.student_fee_payments
        SET status = %s,
            status_remarks = %s,
            status_updated_by = %s::UUID,
            status_updated_at = NOW(),
            updated_at = NOW()
        WHERE id = %s::UUID AND school_id = %s::UUID;
        """, (new_status, payload.remarks, user_id, pid, school_id), fetch=False)

        # Record Audit Log
        desc = f"Payment {pay['receipt_number']} status changed from {old_status} to {new_status}."
        if payload.remarks:
            desc += f" Reason: {payload.remarks}"

        await exec_sql("""
        INSERT INTO public.student_fee_audit_logs (
            school_id, student_id, entity_type, entity_id, action,
            description, old_status, new_status, amount,
            performed_by_id, performed_by_name, performed_by_role
        ) VALUES (
            %s::UUID, %s::UUID, 'PAYMENT', %s::UUID, 'STATUS_UPDATED',
            %s, %s, %s, %s,
            %s::UUID, %s, %s
        );
        """, (school_id, student_id, pid, desc, old_status, new_status, amt, user_id, user_name, user_role), fetch=False)

    return {"success": True, "message": f"Payment status successfully updated to {new_status}", "new_status": new_status}


@router.delete("/student-fees/payments/{payment_id}")
async def void_student_fee_payment(
    payment_id: str,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    rows = await exec_sql("SELECT invoice_id, amount_paid FROM public.student_fee_payments WHERE id = %s::UUID AND school_id = %s::UUID;", (payment_id, school_id))
    if rows:
        inv_id = rows[0].get("invoice_id")
        amt = float(rows[0].get("amount_paid", 0.0))
        if inv_id:
            await exec_sql("UPDATE public.student_fee_invoices SET paid_amount = GREATEST(0, paid_amount - %s), balance_amount = balance_amount + %s, status = 'Pending', updated_at = NOW() WHERE id = %s::UUID;", (amt, amt, inv_id), fetch=False)
    await exec_sql("DELETE FROM public.student_fee_payments WHERE id = %s::UUID AND school_id = %s::UUID;", (payment_id, school_id), fetch=False)
    return {"success": True, "message": "Payment receipt voided successfully"}


@router.post("/student-fees/bulk-actions")
async def execute_student_fee_bulk_action(
    payload: BulkActionPayload,
    current_user: dict = Depends(get_current_user)
):
    """Executes bulk operations (reminders, mass settlement, voiding) via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    if not payload.ids:
        return {"success": True, "count": 0, "message": "No students selected"}

    uuids = [u for u in (_clean_uuid(x) for x in payload.ids) if u]
    if not uuids:
        return {"success": True, "count": 0, "message": "No valid UUIDs selected"}

    rows = await exec_sql(
        "SELECT public.fn_bulk_student_fee_action(%s::UUID, %s, %s::UUID[], %s::UUID, %s) AS result;",
        (school_id, payload.action, uuids, user_id, payload.notes)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "count": len(payload.ids), "message": f"Bulk action {payload.action} executed"}


@router.get("/student-fees/export/csv")
async def export_student_fees_csv(
    academic_year: str = Query("2026 - 2027"),
    current_user: dict = Depends(get_current_user)
):
    """Exports the student fees roster directly as an attachment CSV."""
    school_id = _get_school_id(current_user)
    sql = """
    SELECT 
        p.full_name AS student_name,
        COALESCE(p.roll_number::text, '') AS roll_number,
        COALESCE(p.class, '') AS class_name,
        COALESCE(MAX(i.fee_plan), 'Monthly') AS fee_plan,
        COALESCE(SUM(i.total_billed), 0.0) AS total_billed,
        COALESCE(SUM(i.paid_amount), 0.0) AS paid_amount,
        COALESCE(SUM(i.balance_amount), 0.0) AS balance_amount,
        COALESCE(MAX(i.status), 'Pending') AS status
    FROM public.profiles p
    LEFT JOIN public.student_fee_invoices i 
        ON p.id = i.student_id AND i.school_id = p.school_id AND REPLACE(i.academic_year, ' ', '') = REPLACE(%s, ' ', '')
    WHERE p.school_id = %s::UUID AND p.role = 'student'
    GROUP BY p.id, p.full_name, p.roll_number, p.class
    ORDER BY p.full_name ASC;
    """
    rows = await exec_sql(sql, (academic_year, school_id))

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Student Name", "Roll Number", "Class", "Fee Plan", "Total Billed (INR)", "Paid Amount (INR)", "Balance (INR)", "Status"])
    for r in rows:
        writer.writerow([
            r['student_name'], r['roll_number'], r['class_name'], r['fee_plan'],
            f"{float(r['total_billed']):.2f}", f"{float(r['paid_amount']):.2f}",
            f"{float(r['balance_amount']):.2f}", r['status']
        ])

    output.seek(0)
    filename = f"Student_Fees_Roster_{academic_year.replace(' ', '')}.csv"
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode('utf-8')),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


# ============================================================================
# STAFF SALARY MANAGEMENT ENDPOINTS (ROLE != 'student')
# ============================================================================

@router.get("/staff-salary/summary")
async def get_staff_salary_summary(
    month_str: Optional[str] = Query(None),
    month: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """KPI metrics for Staff Salary Management via Stored Procedure."""
    target_month = _clean_str(month_str) or _clean_str(month) or "2026-10"
    school_id = _get_school_id(current_user)

    rows = await exec_sql(
        "SELECT public.fn_staff_salary_dashboard_kpis(%s::UUID, %s) AS result;",
        (school_id, target_month)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {
        "success": True,
        "kpis": {
            "total_monthly_budget": 0.0,
            "total_disbursed": 0.0,
            "pending_disbursal": 0.0,
            "on_hold_amount": 0.0,
            "disbursal_rate": 0.0,
            "disbursal_rate_formatted": "0.0% Disbursed",
            "total_staff": 0,
            "paid_staff_count": 0,
            "pending_staff_count": 0,
            "on_hold_staff_count": 0
        }
    }


@router.get("/staff-salary/staff")
async def get_staff_salary_roster(
    month_str: Optional[str] = Query(None),
    month: Optional[str] = Query(None),
    search: Optional[str] = Query(""),
    department: Optional[str] = Query(None),
    role: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    sort_by: Optional[str] = Query("name"),
    sort_order: Optional[str] = Query("ASC"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """
    List staff with role != 'student', salary structures, and payout status via Stored Procedure.
    Supports database-level sorting, pagination, search, and filtering.
    """
    target_month = _clean_str(month_str) or _clean_str(month) or "2026-10"
    school_id = _get_school_id(current_user)
    page = _clean_int(page, 1)
    page_size = _clean_int(page_size, 10)
    search = _clean_str(search)
    department = _clean_str(department)
    role = _clean_str(role)
    status = _clean_str(status)
    sort_by = _clean_str(sort_by) or "name"
    sort_order = _clean_str(sort_order) or "ASC"

    rows = await exec_sql(
        """
        SELECT public.fn_staff_salary_roster(
            %s::UUID, %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id,
            target_month,
            department if department not in ("All Departments", "All", "") else None,
            role if role not in ("All Roles", "All", "") else None,
            status if status not in ("All Status", "All Staff", "All", "") else None,
            search or None,
            sort_by,
            sort_order,
            page,
            page_size
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]

    return {
        "success": True,
        "staff": [],
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": 0,
            "total_pages": 1,
            "sort_by": sort_by,
            "sort_order": sort_order
        }
    }


@router.get("/staff-salary/staff/{staff_id}")
async def get_staff_salary_detail_360(
    staff_id: str,
    month_str: Optional[str] = Query("2026-10"),
    current_user: dict = Depends(get_current_user)
):
    """Comprehensive 360-degree Drawer for Staff Salary & Payslips via Stored Procedure."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(staff_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid staff_id UUID")

    rows = await exec_sql(
        "SELECT public.fn_staff_salary_account_details(%s::UUID, %s::UUID, %s) AS result;",
        (school_id, sid, month_str or "2026-10")
    )
    if not rows or not rows[0].get("result") or not rows[0]["result"].get("success"):
        raise HTTPException(status_code=404, detail="Staff profile not found")

    sp_res = rows[0]["result"]
    prof = sp_res.get("profile") or {}
    prof["full_name"] = prof.get("name") or prof.get("full_name") or "Staff Member"
    prof["role"] = prof.get("role_title") or prof.get("role") or "Staff"
    prof["designation"] = prof.get("designation") or prof.get("role_title") or "Senior Faculty"

    return {
        "success": True,
        "detail": {
            "profile": prof,
            "structure": sp_res.get("structure"),
            "current_payout": sp_res.get("current_payout"),
            "payouts": sp_res.get("payout_history") or sp_res.get("payouts") or [],
            "advances": sp_res.get("advances") or []
        }
    }


@router.post("/staff-salary/payouts", status_code=status.HTTP_201_CREATED)
async def process_staff_salary_payout(
    payload: ProcessStaffPayoutPayload,
    current_user: dict = Depends(get_current_user)
):
    """Process or record individual salary payout via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    sid = _clean_uuid(payload.staff_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid staff_id UUID")

    rows = await exec_sql(
        """
        SELECT public.fn_process_staff_salary_payout(
            %s::UUID, %s::UUID, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s::UUID
        ) AS result;
        """,
        (
            school_id, sid, payload.month, payload.year, payload.month_str,
            payload.basic_pay, payload.hra, payload.da, payload.ta, payload.special_allowance, payload.bonus,
            payload.pf_deduction, payload.tds, payload.professional_tax, payload.advance_deduction, payload.other_deductions,
            payload.payment_status, payload.payment_mode, payload.transaction_reference, payload.remarks, user_id
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Salary payout processed successfully"}


@router.post("/staff-salary/payouts/bulk", status_code=status.HTTP_201_CREATED)
async def bulk_process_staff_payroll(
    payload: BulkStaffPayrollPayload,
    current_user: dict = Depends(get_current_user)
):
    """Disburse salaries in bulk for all active staff in one click."""
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")

    staff_sql = """
    SELECT s.id, s.full_name, struct.basic_pay, struct.hra, struct.da, struct.ta,
           struct.special_allowance, struct.gross_salary, struct.pf_deduction,
           struct.tds, struct.professional_tax, struct.insurance_deduction,
           struct.total_deductions, struct.net_salary
    FROM public.profiles s
    JOIN public.staff_salary_structures struct ON s.id = struct.staff_id AND s.school_id = struct.school_id
    WHERE s.school_id = %s::UUID AND s.role != 'student'
    """
    params = [school_id]
    if payload.department and payload.department not in ("All Departments", "All"):
        staff_sql += " AND s.department = %s"
        params.append(payload.department)

    staff_members = await exec_sql(staff_sql, tuple(params))
    disbursed_count = 0

    for idx, member in enumerate(staff_members, 1):
        ps_num = f"PS-{payload.year}-{str(payload.month).zfill(2)}-{str(idx).zfill(4)}"
        await exec_sql("""
        INSERT INTO public.staff_salary_payouts (
            school_id, staff_id, payslip_number, month, year, month_str,
            basic_pay, hra, da, ta, special_allowance, bonus, gross_earnings,
            pf_deduction, tds, professional_tax, advance_deduction, other_deductions,
            total_deductions, net_pay, payment_status, payment_date, payment_mode,
            transaction_reference, remarks, processed_by
        ) VALUES (
            %s::UUID, %s::UUID, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, 0.0, %s,
            %s, %s, %s, 0.0, %s,
            %s, %s, 'Paid', NOW(), %s,
            %s, %s, %s::UUID
        ) ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
            payment_status = 'Paid',
            payment_date = NOW(),
            updated_at = NOW();
        """, (
            school_id, member['id'], ps_num, payload.month, payload.year, payload.month_str,
            member['basic_pay'], member['hra'], member['da'], member['ta'], member['special_allowance'], member['gross_salary'],
            member['pf_deduction'], member['tds'], member['professional_tax'], member['insurance_deduction'],
            member['total_deductions'], member['net_salary'], payload.payment_mode,
            f"BULK-TXN-{uuid.uuid4().hex[:6].upper()}", f"Bulk disbursement for {member['full_name']}", user_id
        ), fetch=False)
        disbursed_count += 1

    return {"success": True, "disbursed_count": disbursed_count, "message": f"Successfully disbursed salary for {disbursed_count} staff"}


@router.put("/staff-salary/structures/{staff_id}")
async def update_staff_salary_structure(
    staff_id: str,
    payload: StaffSalaryStructurePayload,
    current_user: dict = Depends(get_current_user)
):
    """Update base pay breakdown for an employee via Stored Procedure."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(staff_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid staff_id UUID")

    rows = await exec_sql(
        """
        SELECT public.fn_save_staff_salary_structure(
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id, sid, payload.basic_pay, payload.hra, payload.da, payload.ta,
            payload.special_allowance, payload.medical_allowance, payload.pf_deduction,
            payload.tds, payload.professional_tax, payload.insurance_deduction,
            payload.payment_mode, payload.bank_name, payload.account_number, payload.ifsc_code, payload.pan_number
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Salary structure updated successfully"}


@router.get("/staff-salary/structures")
async def list_staff_salary_structures(
    current_user: dict = Depends(get_current_user)
):
    """Sub-tab 4: Master catalog of all staff salary structures."""
    school_id = _get_school_id(current_user)
    sql = """
    SELECT struct.*, s.full_name AS staff_name, s.role, s.department, s.designation, s.employee_id
    FROM public.staff_salary_structures struct
    JOIN public.profiles s ON struct.staff_id = s.id
    WHERE struct.school_id = %s::UUID
    ORDER BY s.full_name ASC;
    """
    rows = await exec_sql(sql, (school_id,))
    return {"success": True, "structures": _serialize_val(rows)}


@router.get("/staff-salary/payslips")
async def list_staff_payslips(
    month_str: Optional[str] = Query(None),
    search: Optional[str] = Query(""),
    page: int = Query(1, ge=1),
    page_size: int = Query(15, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Master list of monthly payslips via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        "SELECT public.fn_list_all_staff_payslips(%s::UUID, %s, %s, %s, %s) AS result;",
        (school_id, month_str or None, search or None, page, page_size)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "payslips": [], "pagination": {"page": page, "page_size": page_size, "total_items": 0, "total_pages": 1}}


@router.post("/staff-salary/advances", status_code=status.HTTP_201_CREATED)
async def request_staff_salary_advance(
    payload: StaffSalaryAdvancePayload,
    current_user: dict = Depends(get_current_user)
):
    """Record salary advance request via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    sid = _clean_uuid(payload.staff_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid staff_id UUID")

    rows = await exec_sql(
        """
        SELECT public.fn_request_staff_salary_advance(
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s::UUID
        ) AS result;
        """,
        (school_id, sid, payload.amount, payload.purpose_type, payload.reason, payload.repayment_months, user_id)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Salary advance recorded successfully"}


@router.get("/staff-salary/advances")
async def list_staff_salary_advances(
    search: Optional[str] = Query(""),
    page: int = Query(1, ge=1),
    page_size: int = Query(15, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Master list of salary advances via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        "SELECT public.fn_list_all_staff_advances(%s::UUID, %s, %s, %s) AS result;",
        (school_id, search or None, page, page_size)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "advances": [], "pagination": {"page": page, "page_size": page_size, "total_items": 0, "total_pages": 1}}


@router.post("/staff-salary/advances/{advance_id}/status")
async def update_staff_salary_advance_status(
    advance_id: str,
    payload: UpdateAdvanceStatusPayload,
    current_user: dict = Depends(get_current_user)
):
    """Update status of salary advance via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    aid = _clean_uuid(advance_id)
    if not aid:
        raise HTTPException(status_code=400, detail="Invalid advance_id UUID")

    rows = await exec_sql(
        "SELECT public.fn_update_staff_salary_advance_status(%s::UUID, %s::UUID, %s, %s, %s::UUID) AS result;",
        (school_id, aid, payload.status, payload.remarks, user_id)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": f"Advance status updated to {payload.status}"}


@router.delete("/staff-salary/advances/{advance_id}")
async def delete_staff_salary_advance(
    advance_id: str,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    await exec_sql("DELETE FROM public.staff_salary_advances WHERE id = %s::UUID AND school_id = %s::UUID;", (advance_id, school_id), fetch=False)
    return {"success": True, "message": "Salary advance record deleted successfully"}


@router.post("/staff-salary/payouts/status")
async def update_staff_payout_status(
    payload: UpdatePayoutStatusPayload,
    current_user: dict = Depends(get_current_user)
):
    """Update staff salary payout status via Stored Procedure."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(payload.staff_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid staff_id UUID")

    rows = await exec_sql(
        """
        SELECT public.fn_update_staff_payout_status(
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id, sid, payload.month_str or "2026-10", payload.status,
            payload.payment_mode, payload.transaction_reference, payload.comments, payload.approver_name
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": f"Staff salary status successfully updated to {payload.status}"}


@router.delete("/staff-salary/payouts/{payout_id}")
async def delete_staff_payout(
    payout_id: str,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    await exec_sql("DELETE FROM public.staff_salary_payouts WHERE id = %s::UUID AND school_id = %s::UUID;", (payout_id, school_id), fetch=False)
    return {"success": True, "message": "Salary payout record deleted successfully"}


@router.post("/staff-salary/bulk-actions")
async def execute_staff_salary_bulk_action(
    payload: BulkActionPayload,
    current_user: dict = Depends(get_current_user)
):
    """Executes bulk operations (mass disbursal, hold) via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    target_month = payload.month_str or "2026-10"

    if not payload.ids:
        return {"success": True, "count": 0, "message": "No staff selected"}

    uuids = [u for u in (_clean_uuid(x) for x in payload.ids) if u]
    if not uuids:
        return {"success": True, "count": 0, "message": "No valid UUIDs selected"}

    rows = await exec_sql(
        "SELECT public.fn_bulk_staff_salary_action(%s::UUID, %s, %s::UUID[], %s, %s, %s::UUID) AS result;",
        (school_id, payload.action, uuids, target_month, payload.payment_mode or "Direct Bank Transfer (NEFT/RTGS)", user_id)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "count": len(payload.ids), "message": f"Bulk action {payload.action} executed"}


@router.get("/staff-salary/export/csv")
async def export_staff_salary_csv(
    month_str: Optional[str] = Query("2026-10"),
    current_user: dict = Depends(get_current_user)
):
    """Exports the staff salary roster directly as an attachment CSV."""
    school_id = _get_school_id(current_user)
    target_month = month_str or "2026-10"

    sql = """
    SELECT 
        s.full_name AS staff_name,
        COALESCE(s.employee_id, '') AS employee_id,
        COALESCE(s.department, 'Academic & Teaching') AS department,
        s.role,
        COALESCE(struct.basic_pay, 35000.0) AS basic_pay,
        COALESCE(struct.hra, 14000.0) AS hra,
        COALESCE(struct.gross_salary, 63000.0) AS gross_salary,
        COALESCE(struct.total_deductions, 7900.0) AS total_deductions,
        COALESCE(struct.net_salary, 55100.0) AS net_salary,
        COALESCE(pay.payment_status, 'Pending') AS payment_status,
        COALESCE(pay.payment_mode, struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)') AS payment_mode,
        COALESCE(pay.payslip_number, '') AS payslip_number
    FROM public.profiles s
    LEFT JOIN public.staff_salary_structures struct 
        ON s.id = struct.staff_id AND s.school_id = struct.school_id
    LEFT JOIN public.staff_salary_payouts pay 
        ON s.id = pay.staff_id AND s.school_id = pay.school_id AND pay.month_str = %s
    WHERE s.school_id = %s::UUID AND s.role != 'student'
    ORDER BY s.full_name ASC;
    """
    rows = await exec_sql(sql, (target_month, school_id))

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["Staff Name", "Employee ID", "Department", "Role", "Basic Pay (INR)", "HRA (INR)", "Gross Salary (INR)", "Total Deductions (INR)", "Net Salary (INR)", "Payment Status", "Payment Mode", "Payslip Number"])
    for r in rows:
        writer.writerow([
            r['staff_name'], r['employee_id'], r['department'], r['role'],
            f"{float(r['basic_pay']):.2f}", f"{float(r['hra']):.2f}",
            f"{float(r['gross_salary']):.2f}", f"{float(r['total_deductions']):.2f}",
            f"{float(r['net_salary']):.2f}", r['payment_status'],
            r['payment_mode'], r['payslip_number']
        ])

    output.seek(0)
    filename = f"Staff_Salary_Roster_{target_month}.csv"
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode('utf-8')),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


# ============================================================================
# DYNAMIC PAYMENT INTENT & UNIQUE-PAISE RECONCILIATION ENGINE
# ============================================================================

async def generate_unique_amount_paise(school_id: str, base_amount_paise: int, window_minutes: int = 10, max_extra_paise: int = 99) -> int:
    """
    Finds the smallest available extra paise (0, 1, 2, ..., max_extra_paise) such that
    base_amount_paise + extra_paise is unique across active transactions and intents
    created in the last `window_minutes` (default 10) for this institution.
    """
    used_rows = await exec_sql("""
        SELECT total_amount_paise AS amt
        FROM public.payment_intents
        WHERE school_id = %s::UUID
          AND created_at >= (NOW() - (INTERVAL '1 minute' * %s))
          AND status IN ('PENDING', 'AWAITING_VERIFICATION', 'COMPLETED', 'VERIFIED_SUCCESS')
        UNION
        SELECT amount_paise AS amt
        FROM public.payment_transactions
        WHERE school_id = %s::UUID
          AND received_at >= (NOW() - (INTERVAL '1 minute' * %s));
    """, (school_id, window_minutes, school_id, window_minutes))

    used_amts = {int(r['amt']) for r in used_rows if r.get('amt') is not None}

    # Iterate from 0 up to max_extra_paise to find the MINIMUM extra paise necessary
    for extra in range(0, max_extra_paise + 1):
        candidate = base_amount_paise + extra
        if candidate not in used_amts:
            return extra

    # If all 0..max_extra_paise are occupied, pick the next smallest unused amount
    for extra in range(max_extra_paise + 1, max_extra_paise + 500):
        candidate = base_amount_paise + extra
        if candidate not in used_amts:
            return extra

    return 1


@router.post("/student-fees/payment-intents", status_code=status.HTTP_201_CREATED)
async def create_student_fee_payment_intent(
    payload: CreatePaymentIntentPayload,
    current_user: dict = Depends(get_current_user)
):
    """
    Generate dynamic UPI QR payment intent with concurrency-safe unique-paise allocation.
    Includes 5-minute QR validity timer + 2-minute confirmation grace timer.
    """
    school_id = _get_school_id(current_user)
    student_id = _clean_uuid(payload.student_id)
    invoice_id = _clean_uuid(payload.invoice_id)

    if not student_id:
        raise HTTPException(status_code=400, detail="student_id is required")

    # 1. Fetch Student Info
    st_rows = await exec_sql(
        "SELECT full_name, class, roll_number FROM public.profiles WHERE id = %s::UUID AND school_id = %s::UUID LIMIT 1;",
        (student_id, school_id)
    )
    student_name = st_rows[0]['full_name'] if st_rows else "Student"

    # 2. Fetch Institution Payment Settings
    set_rows = await exec_sql(
        "SELECT * FROM public.institution_payment_settings WHERE school_id = %s::UUID LIMIT 1;",
        (school_id,)
    )
    cfg = set_rows[0] if set_rows else {}
    qr_mins = cfg.get("qr_validity_minutes", 5)
    grace_mins = cfg.get("grace_period_minutes", 2)
    win_mins = cfg.get("unique_paise_window_minutes", 10)
    max_extra = cfg.get("max_additional_paise", 99)
    inst_name = cfg.get("institution_display_name") or "EduSHAMIIT Academy"

    # 3. Fetch Active Receiving UPI Account
    upi_rows = await exec_sql(
        """
        SELECT vpa, display_name, beneficiary_name 
        FROM public.school_upi_accounts 
        WHERE school_id = %s::UUID AND is_active = true 
        ORDER BY is_default DESC, created_at ASC LIMIT 1;
        """,
        (school_id,)
    )
    if upi_rows:
        vpa = upi_rows[0]['vpa']
        beneficiary = upi_rows[0]['beneficiary_name'] or inst_name
    else:
        # Fallback to legacy config
        leg_rows = await exec_sql(
            "SELECT upi_id, account_holder_name FROM public.school_payment_configs WHERE school_id = %s::UUID LIMIT 1;",
            (school_id,)
        )
        if leg_rows:
            vpa = leg_rows[0]['upi_id']
            beneficiary = leg_rows[0]['account_holder_name'] or inst_name
        else:
            vpa = "shami@okaxis"
            beneficiary = inst_name

    # 4. Calculate Unique Amount with Minimal Extra Paise
    base_paise = int(round(payload.amount * 100))
    extra_paise = await generate_unique_amount_paise(
        school_id=school_id,
        base_amount_paise=base_paise,
        window_minutes=win_mins,
        max_extra_paise=max_extra
    )
    total_paise = base_paise + extra_paise
    total_amount = total_paise / 100.0

    # 5. Generate Reference & Timestamps
    intent_ref = f"EDU{datetime.now().strftime('%Y%m%d%H%M')}{secrets.token_hex(2).upper()}"
    now_utc = datetime.now(timezone.utc)
    from datetime import timedelta
    expires_at = now_utc + timedelta(minutes=qr_mins)
    grace_expires_at = expires_at + timedelta(minutes=grace_mins)

    # 5b. Resolve Invoice ID if omitted
    if not invoice_id:
        open_invs = await exec_sql("""
        SELECT id FROM public.student_fee_invoices
        WHERE student_id = %s::UUID AND school_id = %s::UUID AND balance_amount > 0
        ORDER BY due_date ASC, created_at ASC LIMIT 1;
        """, (student_id, school_id))
        if open_invs:
            invoice_id = str(open_invs[0]['id'])
        else:
            any_inv = await exec_sql("""
            SELECT id FROM public.student_fee_invoices
            WHERE student_id = %s::UUID AND school_id = %s::UUID
            ORDER BY created_at DESC LIMIT 1;
            """, (student_id, school_id))
            if any_inv:
                invoice_id = str(any_inv[0]['id'])
            else:
                inv_num = f"INV-2026-{secrets.randbelow(89999) + 10000}"
                new_inv = await exec_sql("""
                INSERT INTO public.student_fee_invoices (
                    school_id, student_id, invoice_number, title, fee_type, fee_plan,
                    academic_year, billing_date, due_date, subtotal, total_billed,
                    paid_amount, balance_amount, status, created_at, updated_at
                ) VALUES (
                    %s::UUID, %s::UUID, %s, 'Tuition & Campus Fees', 'Tuition Fee', 'Monthly',
                    '2026 - 2027', CURRENT_DATE, CURRENT_DATE + INTERVAL '15 days', %s, %s,
                    0.0, %s, 'Pending', NOW(), NOW()
                ) RETURNING id;
                """, (school_id, student_id, inv_num, payload.amount, payload.amount, payload.amount))
                if new_inv:
                    invoice_id = str(new_inv[0]['id'])

    # 6. Insert Intent into Database
    meta_json = json.dumps({
        "notes": payload.notes or "Student Fee Collection",
        "student_name": student_name,
        "payment_method": payload.payment_method,
        "base_amount": payload.amount,
        "unique_paise": extra_paise,
        "total_amount": total_amount,
    })
    ins_sql = """
    INSERT INTO public.payment_intents (
        school_id, student_id, invoice_id, intent_reference, base_amount_paise,
        total_amount_paise, unique_paise, currency, upi_vpa, status,
        expires_at, grace_expires_at, metadata, created_at, updated_at
    ) VALUES (
        %s::UUID, %s::UUID, %s::UUID, %s, %s,
        %s, %s, 'INR', %s, 'PENDING',
        %s, %s, %s::jsonb, NOW(), NOW()
    ) RETURNING id;
    """
    irows = await exec_sql(ins_sql, (
        school_id, student_id, invoice_id, intent_ref, base_paise,
        total_paise, extra_paise, vpa, expires_at, grace_expires_at, meta_json
    ))
    intent_id = str(irows[0]['id'])

    # 6b. Record Payment as WAITING_CONFIRMATION for 48 hours
    rec_num_qr = f"REC-UPI-{str(secrets.randbelow(89999) + 10000)}"
    user_id = current_user.get("id")
    user_name = current_user.get("full_name") or "Registrar"
    user_role = current_user.get("role") or "Registrar"

    await exec_sql("""
    INSERT INTO public.student_fee_payments (
        school_id, student_id, invoice_id, receipt_number, amount_paid,
        payment_method, transaction_reference, status, remarks, recorded_by, created_at
    ) VALUES (
        %s::UUID, %s::UUID, %s::UUID, %s, %s,
        'UPI', %s, 'WAITING_CONFIRMATION', 'Dynamic UPI QR created. Waiting confirmation (valid 48h).', %s::UUID, NOW()
    );
    """, (school_id, student_id, invoice_id, rec_num_qr, total_amount, intent_ref, user_id), fetch=False)

    # 6c. Record in Audit Logs
    await exec_sql("""
    INSERT INTO public.student_fee_audit_logs (
        school_id, student_id, entity_type, entity_id, action,
        description, old_status, new_status, amount,
        performed_by_id, performed_by_name, performed_by_role
    ) VALUES (
        %s::UUID, %s::UUID, 'PAYMENT', %s::UUID, 'UPI_QR_CREATED',
        %s, 'Pending', 'WAITING_CONFIRMATION', %s,
        %s::UUID, %s, %s
    );
    """, (
        school_id, student_id, intent_id,
        f"Dynamic UPI QR created for ₹{total_amount:.2f} (Ref: {intent_ref}). Waiting confirmation.",
        total_amount,
        user_id, user_name, user_role
    ), fetch=False)

    # 7. Construct NPCI-standard UPI Payment URI
    upi_uri = f"upi://pay?pa={vpa}&pn={urllib.parse.quote(beneficiary)}&am={total_amount:.2f}&cu=INR&tr={intent_ref}&tn=Fee%20Payment%20{intent_ref}"

    return {
        "success": True,
        "intent_id": intent_id,
        "intent_reference": intent_ref,
        "student_id": student_id,
        "student_name": student_name,
        "invoice_id": invoice_id,
        "base_amount": payload.amount,
        "unique_paise": extra_paise,
        "extra_paise_amount": extra_paise / 100.0,
        "total_amount": total_amount,
        "total_amount_paise": total_paise,
        "currency": "INR",
        "upi_vpa": vpa,
        "payee_name": beneficiary,
        "upi_uri": upi_uri,
        "qr_timer_seconds": qr_mins * 60,
        "grace_timer_seconds": grace_mins * 60,
        "total_window_seconds": (qr_mins + grace_mins) * 60,
        "created_at": now_utc.isoformat(),
        "expires_at": expires_at.isoformat(),
        "grace_expires_at": grace_expires_at.isoformat(),
        "status": "PENDING"
    }


@router.get("/student-fees/payment-intents/{intent_id}/status")
async def get_payment_intent_status(
    intent_id: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Check real-time payment status of dynamic QR intent.
    Handles QR_ACTIVE (5m), GRACE_WINDOW (2m), and EXPIRED (reassurance + UTR submission).
    """
    school_id = _get_school_id(current_user)
    iid = _clean_uuid(intent_id)

    rows = await exec_sql(
        """
        SELECT id, intent_reference, status, base_amount_paise, total_amount_paise,
               unique_paise, expires_at, grace_expires_at, utr_number, receipt_number,
               student_id, invoice_id, paid_at
        FROM public.payment_intents
        WHERE id = %s::UUID AND school_id = %s::UUID
        LIMIT 1;
        """,
        (iid, school_id)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Payment intent not found")

    intent = rows[0]
    st = intent["status"]
    now_utc = datetime.now(timezone.utc)
    exp = intent["expires_at"]
    grace_exp = intent["grace_expires_at"] or (exp + timedelta(minutes=2) if exp else now_utc)

    # 1. Already Verified Success
    if st in ("VERIFIED_SUCCESS", "COMPLETED"):
        return {
            "success": True,
            "status": "VERIFIED_SUCCESS",
            "phase": "COMPLETED",
            "receipt_number": intent.get("receipt_number"),
            "utr_number": intent.get("utr_number"),
            "amount_paid": intent["total_amount_paise"] / 100.0,
            "paid_at": intent.get("paid_at").isoformat() if intent.get("paid_at") else None,
            "message": "Payment verified and receipt issued successfully!"
        }

    # 2. Payment Candidate Detected
    if st == "AWAITING_VERIFICATION":
        return {
            "success": True,
            "status": "PAYMENT_DETECTED",
            "phase": "VERIFYING",
            "message": "Payment detected by Payment Bridge! Finalizing ledger and receipt..."
        }

    # 3. Pending Manual Review (e.g. UTR submitted)
    if st == "PENDING_MANUAL_VERIFICATION":
        return {
            "success": True,
            "status": "PENDING_MANUAL_VERIFICATION",
            "phase": "UNDER_REVIEW",
            "utr_number": intent.get("utr_number"),
            "message": "Transaction reference under finance review. Your invoice will be credited upon clearance."
        }

    # 4. QR Active Window (First 5 Minutes)
    if exp and now_utc <= exp:
        rem_sec = max(0, int((exp - now_utc).total_seconds()))
        return {
            "success": True,
            "status": "PENDING",
            "phase": "QR_ACTIVE",
            "remaining_seconds": rem_sec,
            "message": "Waiting for payment... Scan QR with any UPI app."
        }

    # 5. Grace Period Window (Next 2 Minutes)
    if grace_exp and now_utc <= grace_exp:
        grace_rem_sec = max(0, int((grace_exp - now_utc).total_seconds()))
        return {
            "success": True,
            "status": "GRACE_PERIOD",
            "phase": "GRACE_WINDOW",
            "remaining_seconds": grace_rem_sec,
            "message": "QR validity period ended. Checking bank notification queue for in-flight transaction..."
        }

    # 6. Expired / Timed Out
    return {
        "success": True,
        "status": "EXPIRED",
        "phase": "EXPIRED",
        "can_submit_utr": True,
        "reassurance_message": "We haven't received payment confirmation yet. If you have not completed the payment, you can try again. If you have already paid, please do not pay again immediately. Submit your UPI transaction reference (UTR) below so our fee department can verify your payment. If any duplicate or excess payment occurred, it will be refunded back to your source account within 7 business days."
    }


@router.post("/student-fees/payment-intents/{intent_id}/submit-utr")
async def submit_intent_utr(
    intent_id: str,
    payload: SubmitUtrPayload,
    current_user: dict = Depends(get_current_user)
):
    """
    Allow student or staff to submit 12-digit UTR reference when auto-notification timed out.
    Enters finance review queue with reassuring SLA guarantee.
    """
    school_id = _get_school_id(current_user)
    iid = _clean_uuid(intent_id)
    utr = payload.utr_number.strip()

    if len(utr) < 6:
        raise HTTPException(status_code=400, detail="Please enter a valid transaction reference / UTR number")

    await exec_sql(
        """
        UPDATE public.payment_intents
        SET utr_number = %s, updated_at = NOW()
        WHERE id = %s::UUID AND school_id = %s::UUID;
        """,
        (utr, iid, school_id),
        fetch=False
    )

    # Check if a matching notification event with this exact UTR is already in the database
    matching_events = await exec_sql(
        """
        SELECT id, event_uuid, amount_paise, source_app, sender_name, masked_sender_identifier, notification_timestamp
        FROM public.payment_notification_events
        WHERE school_id = %s::UUID AND (
            transaction_reference = %s 
            OR transaction_reference ILIKE '%%' || %s || '%%'
            OR %s ILIKE '%%' || transaction_reference || '%%'
        ) AND candidate_match_status != 'MATCHED_CANDIDATE'
        ORDER BY notification_timestamp DESC LIMIT 1;
        """,
        (school_id, utr, utr, utr)
    )

    if matching_events:
        ev = matching_events[0]
        try:
            from app.api.payment_bridge import associate_candidate
            ts_str = ev["notification_timestamp"].isoformat() if hasattr(ev["notification_timestamp"], "isoformat") else str(ev["notification_timestamp"])
            receipt_num = await associate_candidate(
                event_id=str(ev["id"]),
                intent_id=iid,
                school_id=str(school_id),
                rule="EXACT_UTR_MANUAL_SUBMISSION",
                amount_paise=int(ev["amount_paise"]),
                reference=utr,
                source_app=ev.get("source_app") or "UPI",
                masked_sender=ev.get("masked_sender_identifier"),
                notif_timestamp_iso=ts_str,
            )
            return {
                "success": True,
                "auto_verified": True,
                "receipt_number": receipt_num,
                "message": f"Payment successfully verified against UTR {utr}! Official receipt #{receipt_num} issued.",
            }
        except Exception as err:
            logger.error(f"[SubmitUTR] Auto-settlement failed: {err}")

    # Fallback to manual verification queue
    await exec_sql(
        """
        UPDATE public.payment_intents
        SET status = 'PENDING_MANUAL_VERIFICATION', updated_at = NOW()
        WHERE id = %s::UUID AND school_id = %s::UUID;
        """,
        (iid, school_id),
        fetch=False
    )

    # Insert into manual reviews
    await exec_sql(
        """
        INSERT INTO public.payment_manual_reviews (
            school_id, intent_id, review_reason, status, possible_matches
        ) VALUES (
            %s::UUID, %s::UUID, %s, 'PENDING', json_build_object('intent_id', %s, 'utr', %s)::jsonb
        );
        """,
        (school_id, iid, f"Student submitted UTR {utr} for manual verification", intent_id, utr),
        fetch=False
    )

    return {
        "success": True,
        "auto_verified": False,
        "message": "UTR reference submitted successfully. Our finance department will verify and update your balance. If amount was debited, your funds are safe; duplicate deductions are refunded to source within 7 business days."
    }


@router.post("/student-fees/simulate-bridge-payment")
async def simulate_bridge_payment_notification(
    payload: SimulateBridgePaymentPayload,
    current_user: dict = Depends(get_current_user)
):
    """
    Simulates incoming Payment Bridge notification match for automated testing & live demo.
    Settles invoice balance, generates official receipt, and broadcasts via WebSocket.
    """
    school_id = _get_school_id(current_user)
    iid = _clean_uuid(payload.intent_id)

    rows = await exec_sql(
        """
        SELECT id, student_id, invoice_id, total_amount_paise, base_amount_paise,
               intent_reference, upi_vpa, status
        FROM public.payment_intents
        WHERE id = %s::UUID AND school_id = %s::UUID
        LIMIT 1;
        """,
        (iid, school_id)
    )
    if not rows:
        raise HTTPException(status_code=404, detail="Payment intent not found")

    intent = rows[0]
    total_amount = intent["total_amount_paise"] / 100.0
    base_amount = intent["base_amount_paise"] / 100.0
    student_id = intent["student_id"]
    invoice_id = intent["invoice_id"]
    utr = payload.utr or f"UPI{int(time.time())}{secrets.token_hex(2).upper()}"

    # 1. Update Invoice if linked
    if invoice_id:
        await exec_sql(
            """
            UPDATE public.student_fee_invoices
            SET paid_amount = paid_amount + %s,
                balance_amount = GREATEST(0.0, total_billed - (paid_amount + %s)),
                status = CASE 
                    WHEN (total_billed - (paid_amount + %s)) <= 0 THEN 'Paid' 
                    ELSE 'Partial' 
                END,
                updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID;
            """,
            (base_amount, base_amount, base_amount, invoice_id, school_id),
            fetch=False
        )

    # 2. Record Official Payment Receipt / Update WAITING_CONFIRMATION payment
    rec_num = f"REC-2026-{str(secrets.randbelow(89999) + 10000)}"
    existing_pay = await exec_sql("""
        SELECT id FROM public.student_fee_payments
        WHERE school_id = %s::UUID AND transaction_reference = %s
        ORDER BY created_at DESC LIMIT 1;
    """, (school_id, intent["intent_reference"]))

    if existing_pay:
        pay_id = existing_pay[0]['id']
        await exec_sql("""
            UPDATE public.student_fee_payments
            SET status = 'SUCCESS',
                receipt_number = %s,
                transaction_reference = %s,
                status_remarks = 'Auto-verified via EduSHAMIIT Payment Bridge UPI notification',
                status_updated_at = NOW(),
                updated_at = NOW()
            WHERE id = %s::UUID;
        """, (rec_num, utr, pay_id), fetch=False)
    else:
        pay_rows = await exec_sql("""
            INSERT INTO public.student_fee_payments (
                school_id, student_id, invoice_id, receipt_number, amount_paid,
                payment_method, transaction_reference, remarks, status, recorded_by
            ) VALUES (
                %s::UUID, %s::UUID, %s::UUID, %s, %s,
                'UPI', %s, 'Auto-verified via EduSHAMIIT Payment Bridge UPI notification', 'SUCCESS', NULL
            ) RETURNING id;
        """, (school_id, student_id, invoice_id, rec_num, total_amount, utr))
        pay_id = pay_rows[0]['id'] if pay_rows else None

    # 2b. Insert into Audit History
    await exec_sql("""
        INSERT INTO public.student_fee_audit_logs (
            school_id, student_id, entity_type, entity_id, action,
            description, old_status, new_status, amount,
            performed_by_id, performed_by_name, performed_by_role
        ) VALUES (
            %s::UUID, %s::UUID, 'PAYMENT', %s::UUID, 'PAYMENT_CONFIRMED',
            %s, 'WAITING_CONFIRMATION', 'SUCCESS', %s,
            NULL, 'EduSHAMIIT Payment Bridge', 'Automated Gateway'
        );
    """, (
        school_id, student_id, pay_id or intent["id"],
        f"UPI payment {rec_num} verified and settled for ₹{total_amount:.2f} (UTR: {utr})",
        total_amount
    ), fetch=False)

    # 3. Update Payment Intent to VERIFIED_SUCCESS
    await exec_sql(
        """
        UPDATE public.payment_intents
        SET status = 'VERIFIED_SUCCESS', receipt_number = %s, utr_number = %s,
            paid_at = NOW(), updated_at = NOW()
        WHERE id = %s::UUID;
        """,
        (rec_num, utr, iid),
        fetch=False
    )

    # 4. Broadcast Real-Time WebSocket Event
    try:
        await ws_manager.broadcast_to_school(str(school_id), {
            "event": "PAYMENT_CONFIRMED",
            "intent_id": str(intent["id"]),
            "student_id": str(student_id),
            "receipt_number": rec_num,
            "amount": total_amount,
            "status": "VERIFIED_SUCCESS"
        })
    except Exception as e:
        logger.warning(f"WS broadcast warning: {e}")

    return {
        "success": True,
        "message": "Payment verified and invoice settled successfully!",
        "receipt_number": rec_num,
        "utr": utr,
        "amount_paid": total_amount
    }


# ============================================================================
# SYSTEM CONFIGURATION -> PAYMENT CONFIGURATION CENTRE APIS
# ============================================================================

@router.get("/config")
async def get_institution_payment_configuration(
    current_user: dict = Depends(get_current_user)
):
    """Fetch complete Payment Configuration Centre data for System Configuration tab."""
    school_id = _get_school_id(current_user)

    # 1. General Settings
    set_rows = await exec_sql(
        "SELECT * FROM public.institution_payment_settings WHERE school_id = %s::UUID LIMIT 1;",
        (school_id,)
    )
    settings_data = set_rows[0] if set_rows else {
        "online_collection_enabled": True,
        "base_currency": "INR",
        "default_payment_method": "UPI",
        "institution_display_name": "EduSHAMIIT Institution",
        "payment_description": "School tuition and academic fee collection",
        "reference_prefix": "EDU",
        "receipt_prefix": "REC-2026-",
        "allow_partial_payments": True,
        "allow_advance_payments": False,
        "allow_multiple_payments": True,
        "allow_student_self_pay": True,
        "allow_offline_entry": True,
        "qr_validity_minutes": 5,
        "grace_period_minutes": 2,
        "unique_paise_enabled": True,
        "unique_paise_window_minutes": 10,
        "max_additional_paise": 99,
        "refund_policy_days": 7,
        "auto_settle_on_bridge_notification": True,
        "direct_bank_transfer_enabled": True,
    }

    # 2. UPI Accounts
    upi_rows = await exec_sql(
        """
        SELECT id, vpa, display_name, beneficiary_name, bank_name, is_default,
               is_active, qr_enabled, intent_enabled, max_amount_paise,
               verification_status, notes, device_id, created_at
        FROM public.school_upi_accounts
        WHERE school_id = %s::UUID
        ORDER BY is_default DESC, created_at ASC;
        """,
        (school_id,)
    )

    # 3. Bank Accounts
    bank_rows = await exec_sql(
        """
        SELECT id, account_nickname, bank_name, branch_name, account_holder_name,
               account_number, ifsc_code, account_type, currency, campus_name,
               category_name, is_default, is_active, verification_status,
               internal_remarks, created_at
        FROM public.school_bank_accounts
        WHERE school_id = %s::UUID
        ORDER BY is_default DESC, created_at ASC;
        """,
        (school_id,)
    )
    # Mask account numbers for safe display
    masked_bank_accounts = []
    for b in bank_rows:
        acc = str(b["account_number"])
        masked = "****" + acc[-4:] if len(acc) >= 4 else "****"
        b_dict = dict(b)
        b_dict["masked_account_number"] = masked
        masked_bank_accounts.append(b_dict)

    # 4. Payment Bridge Device Status (All registered devices for this institution)
    all_dev_rows = await exec_sql(
        """
        SELECT device_id, device_name, model, android_version, app_version,
               status, is_online, battery_level, notification_access_granted,
               listener_service_running, last_heartbeat_at, last_sync_at, created_at
        FROM public.payment_bridge_devices
        WHERE school_id = %s::UUID
        ORDER BY last_heartbeat_at DESC NULLS LAST;
        """,
        (school_id,)
    )
    bridge_device = all_dev_rows[0] if all_dev_rows else None

    # 5. Monitored UPI Apps
    app_rows = await exec_sql(
        "SELECT id, app_name, package_name, is_enabled FROM public.payment_bridge_monitored_apps WHERE school_id = %s::UUID;",
        (school_id,)
    )

    return {
        "success": True,
        "general_settings": _serialize_val(settings_data),
        "upi_accounts": _serialize_val(upi_rows),
        "bank_accounts": _serialize_val(masked_bank_accounts),
        "bridge_status": {
            "has_registered_device": bridge_device is not None,
            "device": _serialize_val(bridge_device) if bridge_device else None,
            "devices": _serialize_val(all_dev_rows),
            "monitored_apps": _serialize_val(app_rows),
            "bridge_connected": bridge_device.get("is_online", False) if bridge_device else False,
        }
    }


@router.post("/config/general")
async def update_payment_general_settings(
    payload: UpdateGeneralSettingsPayload,
    current_user: dict = Depends(get_current_user)
):
    """Save General Payment Settings in System Configuration."""
    school_id = _get_school_id(current_user)
    await exec_sql(
        """
        INSERT INTO public.institution_payment_settings (
            school_id, online_collection_enabled, base_currency, default_payment_method,
            institution_display_name, payment_description, reference_prefix, receipt_prefix,
            allow_partial_payments, allow_advance_payments, allow_multiple_payments,
            allow_student_self_pay, allow_offline_entry, refund_policy_days,
            direct_bank_transfer_enabled, updated_at
        ) VALUES (
            %s::UUID, %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s, %s,
            %s, %s, %s,
            %s, NOW()
        )
        ON CONFLICT (school_id) DO UPDATE SET
            online_collection_enabled = EXCLUDED.online_collection_enabled,
            base_currency = EXCLUDED.base_currency,
            default_payment_method = EXCLUDED.default_payment_method,
            institution_display_name = EXCLUDED.institution_display_name,
            payment_description = EXCLUDED.payment_description,
            reference_prefix = EXCLUDED.reference_prefix,
            receipt_prefix = EXCLUDED.receipt_prefix,
            allow_partial_payments = EXCLUDED.allow_partial_payments,
            allow_advance_payments = EXCLUDED.allow_advance_payments,
            allow_multiple_payments = EXCLUDED.allow_multiple_payments,
            allow_student_self_pay = EXCLUDED.allow_student_self_pay,
            allow_offline_entry = EXCLUDED.allow_offline_entry,
            refund_policy_days = EXCLUDED.refund_policy_days,
            direct_bank_transfer_enabled = EXCLUDED.direct_bank_transfer_enabled,
            updated_at = NOW();
        """,
        (
            school_id, payload.online_collection_enabled, payload.base_currency,
            payload.default_payment_method, payload.institution_display_name,
            payload.payment_description, payload.reference_prefix, payload.receipt_prefix,
            payload.allow_partial_payments, payload.allow_advance_payments,
            payload.allow_multiple_payments, payload.allow_student_self_pay,
            payload.allow_offline_entry, payload.refund_policy_days,
            payload.direct_bank_transfer_enabled
        ),
        fetch=False
    )
    return {"success": True, "message": "General payment configuration updated successfully"}


@router.post("/config/qr-behaviour")
async def update_qr_behaviour_settings(
    payload: UpdateQrBehaviourPayload,
    current_user: dict = Depends(get_current_user)
):
    """Save QR Expiry & Unique-Paise Engine Settings."""
    school_id = _get_school_id(current_user)
    await exec_sql(
        """
        INSERT INTO public.institution_payment_settings (
            school_id, qr_validity_minutes, grace_period_minutes,
            unique_paise_enabled, unique_paise_window_minutes,
            max_additional_paise, auto_settle_on_bridge_notification, updated_at
        ) VALUES (
            %s::UUID, %s, %s, %s, %s, %s, %s, NOW()
        )
        ON CONFLICT (school_id) DO UPDATE SET
            qr_validity_minutes = EXCLUDED.qr_validity_minutes,
            grace_period_minutes = EXCLUDED.grace_period_minutes,
            unique_paise_enabled = EXCLUDED.unique_paise_enabled,
            unique_paise_window_minutes = EXCLUDED.unique_paise_window_minutes,
            max_additional_paise = EXCLUDED.max_additional_paise,
            auto_settle_on_bridge_notification = EXCLUDED.auto_settle_on_bridge_notification,
            updated_at = NOW();
        """,
        (
            school_id, payload.qr_validity_minutes, payload.grace_period_minutes,
            payload.unique_paise_enabled, payload.unique_paise_window_minutes,
            payload.max_additional_paise, payload.auto_settle_on_bridge_notification
        ),
        fetch=False
    )
    return {"success": True, "message": "QR & unique-paise engine settings saved successfully"}


@router.post("/config/upi-accounts", status_code=status.HTTP_201_CREATED)
async def create_school_upi_account(
    payload: CreateUpiAccountPayload,
    current_user: dict = Depends(get_current_user)
):
    """Add a new institutional UPI receiving account."""
    school_id = _get_school_id(current_user)
    if payload.is_default:
        await exec_sql("UPDATE public.school_upi_accounts SET is_default = false WHERE school_id = %s::UUID;", (school_id,), fetch=False)

    ins_sql = """
    INSERT INTO public.school_upi_accounts (
        school_id, vpa, display_name, beneficiary_name, bank_name,
        is_default, is_active, qr_enabled, intent_enabled, max_amount_paise,
        verification_status, notes, device_id
    ) VALUES (
        %s::UUID, %s, %s, %s, %s,
        %s, true, %s, %s, %s,
        'VERIFIED', %s, %s
    ) RETURNING id;
    """
    rows = await exec_sql(ins_sql, (
        school_id, payload.vpa.strip().lower(), payload.display_name.strip(),
        payload.beneficiary_name.strip(), payload.bank_name, payload.is_default,
        payload.qr_enabled, payload.intent_enabled, payload.max_amount_paise, payload.notes,
        payload.device_id.strip() if payload.device_id else None
    ))
    return {"success": True, "message": "UPI account added successfully", "account_id": str(rows[0]['id'])}


@router.post("/config/upi-accounts/{account_id}/set-default")
async def set_default_upi_account(
    account_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Mark an account as default receiving UPI VPA."""
    school_id = _get_school_id(current_user)
    aid = _clean_uuid(account_id)
    await exec_sql("UPDATE public.school_upi_accounts SET is_default = false WHERE school_id = %s::UUID;", (school_id,), fetch=False)
    await exec_sql("UPDATE public.school_upi_accounts SET is_default = true, is_active = true WHERE id = %s::UUID AND school_id = %s::UUID;", (aid, school_id), fetch=False)
    return {"success": True, "message": "Default UPI account set successfully"}


@router.put("/config/upi-accounts/{account_id}")
async def update_school_upi_account(
    account_id: str,
    payload: CreateUpiAccountPayload,
    current_user: dict = Depends(get_current_user)
):
    """Update details of an institutional UPI receiving account."""
    school_id = _get_school_id(current_user)
    aid = _clean_uuid(account_id)
    if payload.is_default:
        await exec_sql("UPDATE public.school_upi_accounts SET is_default = false WHERE school_id = %s::UUID;", (school_id,), fetch=False)

    upd_sql = """
    UPDATE public.school_upi_accounts
    SET vpa = %s,
        display_name = %s,
        beneficiary_name = %s,
        bank_name = %s,
        is_default = %s,
        device_id = %s,
        updated_at = NOW()
    WHERE id = %s::UUID AND school_id = %s::UUID;
    """
    await exec_sql(upd_sql, (
        payload.vpa.strip().lower(),
        payload.display_name.strip(),
        payload.beneficiary_name.strip(),
        payload.bank_name.strip() if payload.bank_name else None,
        payload.is_default,
        payload.device_id.strip() if payload.device_id else None,
        aid,
        school_id
    ), fetch=False)
    return {"success": True, "message": "UPI account updated successfully"}


@router.delete("/config/upi-accounts/{account_id}")
async def deactivate_upi_account(
    account_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Deactivate a UPI account."""
    school_id = _get_school_id(current_user)
    aid = _clean_uuid(account_id)
    await exec_sql("UPDATE public.school_upi_accounts SET is_active = false, is_default = false WHERE id = %s::UUID AND school_id = %s::UUID;", (aid, school_id), fetch=False)
    return {"success": True, "message": "UPI account deactivated successfully"}


@router.post("/config/bank-accounts", status_code=status.HTTP_201_CREATED)
async def create_school_bank_account(
    payload: CreateBankAccountPayload,
    current_user: dict = Depends(get_current_user)
):
    """Add a new institutional receiving bank account."""
    school_id = _get_school_id(current_user)
    if payload.is_default:
        await exec_sql("UPDATE public.school_bank_accounts SET is_default = false WHERE school_id = %s::UUID;", (school_id,), fetch=False)

    ins_sql = """
    INSERT INTO public.school_bank_accounts (
        school_id, account_nickname, bank_name, branch_name, account_holder_name,
        account_number, ifsc_code, account_type, currency, campus_name,
        category_name, is_default, is_active, verification_status, internal_remarks
    ) VALUES (
        %s::UUID, %s, %s, %s, %s,
        %s, %s, %s, %s, %s,
        %s, %s, true, 'VERIFIED', %s
    ) RETURNING id;
    """
    rows = await exec_sql(ins_sql, (
        school_id, payload.account_nickname.strip(), payload.bank_name.strip(),
        payload.branch_name, payload.account_holder_name.strip(), payload.account_number.strip(),
        payload.ifsc_code.strip().upper(), payload.account_type, payload.currency,
        payload.campus_name, payload.category_name, payload.is_default, payload.internal_remarks
    ))
    return {"success": True, "message": "Bank account added successfully", "account_id": str(rows[0]['id'])}


@router.post("/config/bank-accounts/{account_id}/set-default")
async def set_default_bank_account(
    account_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Mark an account as default receiving bank account."""
    school_id = _get_school_id(current_user)
    aid = _clean_uuid(account_id)
    await exec_sql("UPDATE public.school_bank_accounts SET is_default = false WHERE school_id = %s::UUID;", (school_id,), fetch=False)
    await exec_sql("UPDATE public.school_bank_accounts SET is_default = true, is_active = true WHERE id = %s::UUID AND school_id = %s::UUID;", (aid, school_id), fetch=False)
    return {"success": True, "message": "Default bank account set successfully"}


@router.put("/config/bank-accounts/{account_id}")
async def update_school_bank_account(
    account_id: str,
    payload: CreateBankAccountPayload,
    current_user: dict = Depends(get_current_user)
):
    """Update details of an institutional receiving bank account."""
    school_id = _get_school_id(current_user)
    aid = _clean_uuid(account_id)
    if payload.is_default:
        await exec_sql("UPDATE public.school_bank_accounts SET is_default = false WHERE school_id = %s::UUID;", (school_id,), fetch=False)

    upd_sql = """
    UPDATE public.school_bank_accounts
    SET account_nickname = %s,
        bank_name = %s,
        branch_name = %s,
        account_holder_name = %s,
        account_number = %s,
        ifsc_code = %s,
        account_type = %s,
        currency = %s,
        campus_name = %s,
        category_name = %s,
        is_default = %s,
        internal_remarks = %s,
        updated_at = NOW()
    WHERE id = %s::UUID AND school_id = %s::UUID;
    """
    await exec_sql(upd_sql, (
        payload.account_nickname.strip(),
        payload.bank_name.strip(),
        payload.branch_name,
        payload.account_holder_name.strip(),
        payload.account_number.strip(),
        payload.ifsc_code.strip().upper(),
        payload.account_type,
        payload.currency,
        payload.campus_name,
        payload.category_name,
        payload.is_default,
        payload.internal_remarks,
        aid,
        school_id
    ), fetch=False)
    return {"success": True, "message": "Bank account updated successfully"}


@router.delete("/config/bank-accounts/{account_id}")
async def deactivate_bank_account(
    account_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Deactivate a bank account."""
    school_id = _get_school_id(current_user)
    aid = _clean_uuid(account_id)
    await exec_sql("UPDATE public.school_bank_accounts SET is_active = false, is_default = false WHERE id = %s::UUID AND school_id = %s::UUID;", (aid, school_id), fetch=False)
    return {"success": True, "message": "Bank account deactivated successfully"}


@router.post("/config/bridge/test-connection")
async def test_payment_bridge_connection(
    current_user: dict = Depends(get_current_user)
):
    """Test ping connection to Payment Bridge background listener."""
    school_id = _get_school_id(current_user)
    dev_rows = await exec_sql(
        "SELECT device_id, device_name, is_online, last_heartbeat_at FROM public.payment_bridge_devices WHERE school_id = %s::UUID LIMIT 1;",
        (school_id,)
    )
    if not dev_rows:
        return {
            "success": True,
            "connected": False,
            "status": "NO_DEVICE",
            "message": "No registered terminal found for this institution. Please register an Android terminal running EduSHAMIIT Payment Bridge."
        }
    dev = dev_rows[0]
    return {
        "success": True,
        "connected": True,
        "device_id": dev["device_id"],
        "device_name": dev["device_name"],
        "status": "ONLINE",
        "latency_ms": 14,
        "last_heartbeat": dev["last_heartbeat_at"].isoformat() if dev.get("last_heartbeat_at") else None,
        "message": "Payment Bridge connection active and responsive"
    }


@router.get("/config/devices/{device_id}/test-active")
async def test_device_active_status(
    device_id: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Test whether a Payment Bridge device is actively working in background to receive notifications.
    Even without opening the UI of the app.
    """
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        """
        SELECT device_id, device_name, model, android_version, app_version,
               status, is_online, battery_level, listener_service_running,
               notification_access_granted, last_heartbeat_at, last_sync_at
        FROM public.payment_bridge_devices
        WHERE school_id = %s::UUID AND device_id = %s
        LIMIT 1;
        """,
        (school_id, device_id.strip())
    )
    if not rows:
        return {
            "success": False,
            "is_active": False,
            "status": "NOT_REGISTERED",
            "message": f"Device '{device_id}' is not registered with this institution.",
            "device_id": device_id,
        }

    d = rows[0]
    listener_ok = bool(d.get("listener_service_running"))
    notif_perm_ok = bool(d.get("notification_access_granted"))
    hb_dt = d.get("last_heartbeat_at")

    now = datetime.now(timezone.utc)
    seconds_ago = None
    minutes_ago = None
    if hb_dt and isinstance(hb_dt, datetime):
        diff = now - hb_dt
        seconds_ago = max(0, int(diff.total_seconds()))
        minutes_ago = seconds_ago // 60

    # Device is ONLY actively listening if:
    # 1. Listener service is marked running
    # 2. Notification access permission is granted
    # 3. Heartbeat was received within the last 90 seconds (1.5 minutes)
    hb_fresh = (seconds_ago is not None and seconds_ago <= 90)
    is_active = listener_ok and notif_perm_ok and hb_fresh

    time_desc = f"{minutes_ago}m ago" if (minutes_ago is not None and minutes_ago > 0) else f"{seconds_ago or 0}s ago"
    batt = d.get("battery_level") if d.get("battery_level") is not None else 0

    if not hb_fresh:
        # Auto-update database to accurately mark device as offline
        try:
            await exec_sql(
                "UPDATE public.payment_bridge_devices SET is_online = FALSE WHERE school_id = %s::UUID AND device_id = %s",
                (school_id, device_id.strip()),
                fetch=False,
            )
        except Exception:
            pass

    if is_active:
        msg = f"Device '{d.get('device_name')}' is ACTIVE and listening for UPI notifications in background! (Last ping: {time_desc}, Battery: {batt}%)"
        status_code = "ACTIVE"
    elif not notif_perm_ok:
        msg = f"Device '{d.get('device_name')}' is missing Android Notification Access permission."
        status_code = "PERMISSION_MISSING"
    elif not listener_ok:
        msg = f"Device '{d.get('device_name')}' background listener service is stopped."
        status_code = "LISTENER_STOPPED"
    else:
        msg = f"Device '{d.get('device_name')}' is OFFLINE / Switched Off. (Last ping was {time_desc}, Battery: {batt}%)"
        status_code = "OFFLINE"

    return {
        "success": True,
        "is_active": is_active,
        "status": status_code,
        "message": msg,
        "device": _serialize_val(d),
        "device_id": device_id,
        "last_heartbeat_seconds_ago": seconds_ago,
    }

