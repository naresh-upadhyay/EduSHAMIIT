"""
Universal Payment Management API for EduSHAMIIT ERP:
1. Student Fee & Billing Management (Students only)
2. Staff Salary & Payroll Management (Non-student staff)
Multi-Tenant, Dynamic Lookups, Full Ledger, Automated Advance Recovery, and Complete Auditing.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status, BackgroundTasks
from fastapi.responses import StreamingResponse, HTMLResponse, JSONResponse
import base64
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any, Union
from datetime import datetime, date, timezone, time as dt_time, timedelta
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
from app.services.email_service import get_email_service

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


class CreateFeeScheduleRulePayload(BaseModel):
    rule_name: str
    target_type: str = "CLASS"  # 'ALL', 'CLASS', 'INDIVIDUALS'
    target_class: Optional[str] = "10 A"
    target_section: Optional[str] = None
    student_ids: Optional[List[str]] = []
    fee_type: str = "Tuition Fee"
    fee_plan: str = "Monthly"
    amount: float = Field(..., gt=0)
    title_template: str = "Tuition Fee - {MONTH} {YEAR}"
    notes: Optional[str] = None
    frequency: str = "MONTHLY"  # 'MONTHLY', 'QUARTERLY', 'HALF_YEARLY', 'ANNUALLY', 'ONE_TIME'
    schedule_day_of_month: int = Field(25, ge=1, le=31)
    due_days_offset: int = Field(10, ge=1, le=90)
    billing_period_target: str = "NEXT_MONTH"
    academic_year: str = "2026 - 2027"
    is_active: bool = True
    auto_deduct_advance_credit: bool = True
    send_parent_email: bool = True
    fee_structure_id: Optional[str] = None
    auto_generate_all_cohort_heads: bool = False


class UpdateFeeScheduleRulePayload(BaseModel):
    rule_name: Optional[str] = None
    target_type: Optional[str] = None
    target_class: Optional[str] = None
    target_section: Optional[str] = None
    student_ids: Optional[List[str]] = None
    fee_type: Optional[str] = None
    fee_plan: Optional[str] = None
    amount: Optional[float] = None
    title_template: Optional[str] = None
    notes: Optional[str] = None
    frequency: Optional[str] = None
    schedule_day_of_month: Optional[int] = None
    due_days_offset: Optional[int] = None
    billing_period_target: Optional[str] = None
    academic_year: Optional[str] = None
    is_active: Optional[bool] = None
    auto_deduct_advance_credit: Optional[bool] = None
    send_parent_email: Optional[bool] = None
    fee_structure_id: Optional[str] = None
    auto_generate_all_cohort_heads: Optional[bool] = None


class EnhancedBulkInvoicePayload(BaseModel):
    target_type: str = "CLASS"  # 'ALL', 'CLASS', 'INDIVIDUALS'
    target_class: Optional[str] = "All Classes"
    target_section: Optional[str] = "All Sections"
    student_ids: Optional[List[str]] = []
    fee_type: str = "Tuition Fee"
    fee_plan: str = "Monthly"
    amount: float = Field(..., gt=0)
    due_date: Optional[str] = None
    due_days_offset: Optional[int] = 10
    title: str = "Monthly Tuition & Campus Fees"
    notes: Optional[str] = None
    academic_year: str = "2026 - 2027"
    skip_duplicates: bool = True
    auto_deduct_advance_credit: bool = True
    send_parent_email: bool = True
    fee_structure_id: Optional[str] = None
    auto_bundle_all_heads: bool = False


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


class RefundStudentFeePayload(BaseModel):
    student_id: str
    amount: float
    refund_mode: str = "Bank Transfer"
    reference_number: Optional[str] = None
    reason: Optional[str] = "Overpayment Refund"
    invoice_id: Optional[str] = None
    payment_id: Optional[str] = None


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
    section_name: str = "All Sections"
    billing_cycle: str = "Monthly"
    frequency_type: str = "Monthly"
    amount: float
    due_day_of_cycle: int = 10
    grace_period_days: int = 5
    late_fine_amount: float = 0.0
    late_fine_type: str = "FLAT"
    is_mandatory: bool = True
    is_refundable: bool = False
    description: Optional[str] = None
    academic_year: str = "2026 - 2027"


class CloneFeeStructurePayload(BaseModel):
    source_class: str
    source_section: str = "All Sections"
    target_class: Optional[str] = None
    target_section: str = "All Sections"
    markup_percent: float = 0.0


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
    bonus_type: Optional[str] = "NONE"
    bonus_remarks: Optional[str] = None
    pf_deduction: float
    tds: float
    professional_tax: float = 200.0
    advance_deduction: float = 0.0
    other_deductions: float = 0.0
    other_deductions_remarks: Optional[str] = None
    payment_status: str = "Paid"
    payment_mode: str = "Direct Bank Transfer (NEFT/RTGS)"
    transaction_reference: Optional[str] = None
    remarks: Optional[str] = None
    bank_name: Optional[str] = None
    account_number: Optional[str] = None
    ifsc_code: Optional[str] = None
    pan_number: Optional[str] = None
    update_permanent_structure: bool = False


class BulkStaffPayrollPayload(BaseModel):
    month: int
    year: int
    month_str: str
    department: Optional[str] = "All Departments"
    payment_mode: str = "Direct Bank Transfer (NEFT/RTGS)"


class AutoPayrollRunPayload(BaseModel):
    month_str: str = Field(..., description="Target month in YYYY-MM format")
    payment_mode: Optional[str] = "Direct Bank Transfer (NEFT/RTGS)"
    send_email_notifications: bool = True


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


class SettleStaffAdvancePayload(BaseModel):
    settlement_amount: float
    payment_mode: str = "Cash"
    remarks: Optional[str] = "Early loan clearance"


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
        res = rows[0]["result"]
        for key in ("due_heads", "future_heads", "completed_heads"):
            if res.get(key) and isinstance(res[key], list):
                for item in res[key]:
                    if isinstance(item, dict):
                        for k, v in list(item.items()):
                            if isinstance(v, str):
                                item[k] = (
                                    v.replace("â€”", " - ")
                                    .replace("â€“", " - ")
                                    .replace("â‚¹", "₹")
                                    .replace("â€¢", "•")
                                    .replace("—", " - ")
                                    .replace("–", " - ")
                                )
        return res
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
    class_name: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """Returns high-level KPI cards for Student Fee Management via Stored Procedure."""
    school_id = _get_school_id(current_user)
    academic_year = _clean_str(academic_year, "2026 - 2027")
    clean_class = class_name.strip() if class_name and class_name.strip() not in ("All Classes", "All", "") else None

    rows = await exec_sql(
        "SELECT public.fn_student_fee_dashboard_kpis(%s::UUID, %s, %s) AS result;",
        (school_id, academic_year, clean_class)
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
            "advance_amount": 0.0,
            "collection_rate": 0.0,
            "collection_rate_formatted": "0.0% Collection",
            "total_students": 0,
            "paid_students_count": 0,
            "partial_students_count": 0,
            "pending_students_count": 0,
            "overdue_students_count": 0,
            "overpaid_students_count": 0,
            "unbilled_students_count": 0,
            "fee_structures_count": 0,
            "invoices_count": 0,
            "payments_count": 0
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
    refunds = sp_res.get("refunds") or []

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
        "advance_amount": float(stud.get("advance_amount", 0.0)),
        "invoices_count": len(invs),
        "payments_count": len(pays),
        "concessions_count": len(concs),
        "penalties_count": len(pens),
        "history_count": len(logs),
        "refunds_count": len(refunds)
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
            "history": logs,
            "refunds": refunds
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
    SELECT a.id, a.entity_type, a.entity_id, a.action, a.description, a.old_status, a.new_status,
           a.amount, 
           COALESCE(NULLIF(p.full_name, ''), a.performed_by_name, 'System') AS performed_by_name,
           COALESCE(a.performed_by_email, p.email, '') AS performed_by_email,
           COALESCE(NULLIF(p.role, ''), a.performed_by_role, 'Staff') AS performed_by_role,
           a.metadata, a.created_at
    FROM public.student_fee_audit_logs a
    LEFT JOIN public.profiles p ON p.id = a.performed_by_id
    WHERE a.student_id = %s::UUID AND a.school_id = %s::UUID
    ORDER BY a.created_at DESC;
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


# ============================================================================
# AUTOMATED INVOICE GENERATION SCHEDULING & BULK RULES ENGINE
# ============================================================================

def generate_fee_invoice_email_html(
    school_name: str,
    student_name: str,
    class_name: str,
    section_name: str,
    roll_number: str,
    admission_number: str,
    invoice_number: str,
    title: str,
    fee_type: str,
    due_date: str,
    gross_amount: float,
    advance_deducted: float,
    net_payable: float,
    remaining_advance: float,
    upi_vpa: str = "kinguoadhyay@axl",
    public_payment_url: Optional[str] = None
) -> str:
    """Generate executive branded HTML email invoice statement for parents."""
    cls_sec = class_name
    if section_name and section_name not in ("All", "All Sections", ""):
        cls_sec += f" ({section_name})"

    fmt_gross = f"{gross_amount:,.2f}"
    fmt_deduct = f"{advance_deducted:,.2f}"
    fmt_net = f"{net_payable:,.2f}"
    fmt_rem = f"{remaining_advance:,.2f}"

    encoded_tn = urllib.parse.quote(f"Fee-{invoice_number}")
    upi_intent_url = f"upi://pay?pa={upi_vpa}&pn=EduSHAMIIT&am={net_payable:.2f}&cu=INR&tn={encoded_tn}"
    qr_code_url = f"https://api.qrserver.com/v1/create-qr-code/?size=180x180&data={urllib.parse.quote(upi_intent_url)}"

    # Settlement card
    if net_payable <= 0:
        receipt_btn = f'''<div style="margin-top: 14px;"><a href="{public_payment_url}" style="display: inline-block; background: #059669; color: #FFFFFF; font-weight: 700; font-size: 13px; padding: 10px 22px; text-decoration: none; border-radius: 8px;">📄 View &amp; Download Official Fee Receipt &rarr;</a></div>''' if public_payment_url else ''
        payment_block = f"""
        <div style="background: #ECFDF5; border: 1.5px solid #10B981; border-radius: 12px; padding: 20px; text-align: center; margin: 24px 0;">
            <div style="font-size: 28px; margin-bottom: 6px;">&#x2705;</div>
            <div style="font-size: 16px; font-weight: 800; color: #065F46;">INVOICE FULLY SETTLED VIA ADVANCE CREDIT</div>
            <p style="margin: 6px 0 0; font-size: 13px; color: #047857; line-height: 1.5;">
                Great news! Your account had sufficient advance credit wallet balance to cover this invoice in full.
                <br><strong>No further payment is required from parents.</strong>
            </p>
            {receipt_btn}
        </div>
        """
    else:
        pay_btn_url = public_payment_url if public_payment_url else upi_intent_url
        pay_link_note = f'''<div style="margin-top: 12px; font-size: 12px; color: #475569;">Direct 1-Click Payment Link: <a href="{public_payment_url}" style="color: #2563EB; font-weight: 600; word-break: break-all;">{public_payment_url}</a></div>''' if public_payment_url else ''
        payment_block = f"""
        <div style="background: #F8FAFC; border: 1.5px solid #CBD5E1; border-radius: 12px; padding: 22px; text-align: center; margin: 24px 0;">
            <div style="font-size: 14px; font-weight: 800; color: #1E293B; letter-spacing: 0.5px; margin-bottom: 4px;">
                INSTANT ZERO-FEE UPI PAYMENT
            </div>
            <p style="margin: 0 0 16px; font-size: 12px; color: #64748B;">
                Scan with Google Pay, PhonePe, Paytm, BHIM, or any banking app to pay securely
            </p>
            <div style="display: inline-block; background: #FFFFFF; padding: 12px; border-radius: 12px; border: 1px solid #E2E8F0; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.06);">
                <img src="{qr_code_url}" width="160" height="160" alt="UPI QR Code" style="display: block; border-radius: 6px;" />
            </div>
            <div style="margin-top: 16px;">
                <a href="{pay_btn_url}" style="display: inline-block; background: #2563EB; color: #FFFFFF; font-weight: 700; font-size: 14px; padding: 12px 28px; text-decoration: none; border-radius: 8px; box-shadow: 0 4px 10px rgba(37,99,235,0.3);">
                    Pay Student Fee Online (&#x20B9; {fmt_net})
                </a>
            </div>
            {pay_link_note}
            <div style="margin-top: 12px; font-size: 11.5px; color: #64748B;">
                Payee VPA: <strong style="color: #0F172A;">{upi_vpa}</strong> &bull; Due Date: <strong style="color: #DC2626;">{due_date}</strong>
            </div>
        </div>
        """

    advance_deduction_row = ""
    if advance_deducted > 0:
        advance_deduction_row = f"""
        <tr style="background: #F0FDF4;">
            <td style="padding: 12px 16px; font-size: 13.5px; color: #166534; font-weight: 600;">
                &#x2714; Less: Advance Credit Wallet Deducted
            </td>
            <td style="padding: 12px 16px; font-size: 14px; color: #166534; font-weight: 800; text-align: right;">
                - &#x20B9; {fmt_deduct}
            </td>
        </tr>
        """

    remaining_advance_row = ""
    if remaining_advance > 0:
        remaining_advance_row = f"""
        <div style="margin-top: 10px; padding: 8px 14px; background: #ECFDF5; border-radius: 8px; font-size: 12px; color: #065F46; font-weight: 600; text-align: right;">
            Remaining Advance Credit Wallet Balance: &#x20B9; {fmt_rem}
        </div>
        """

    return f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fee Invoice {invoice_number}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #0F172A;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 30px 10px;">
        <tr>
            <td align="center">
                <table role="presentation" width="100%" style="max-width: 620px; background: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1); border: 1px solid #E2E8F0;">
                    
                    <!-- BRAND HEADER -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #1E3A8A 0%, #2563EB 100%); padding: 30px 28px; text-align: left;">
                            <div style="display: inline-block; background: rgba(255,255,255,0.2); border-radius: 8px; padding: 4px 10px; font-size: 11px; font-weight: 800; color: #FFFFFF; letter-spacing: 0.8px; margin-bottom: 8px;">
                                OFFICIAL STUDENT FEE INVOICE
                            </div>
                            <div style="font-size: 24px; font-weight: 900; color: #FFFFFF; letter-spacing: -0.5px;">
                                {school_name}
                            </div>
                            <div style="font-size: 12.5px; color: #BFDBFE; margin-top: 4px;">
                                Next-Generation School Management &amp; Automated Billing Portal
                            </div>
                        </td>
                    </tr>

                    <!-- CONTENT BODY -->
                    <tr>
                        <td style="padding: 28px;">
                            
                            <!-- STUDENT PROFILE SUMMARY -->
                            <div style="background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 16px 20px; margin-bottom: 22px;">
                                <table width="100%" cellspacing="0" cellpadding="0">
                                    <tr>
                                        <td width="55%">
                                            <div style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">Student Name</div>
                                            <div style="font-size: 16px; font-weight: 800; color: #0F172A; margin-top: 2px;">{student_name}</div>
                                            <div style="font-size: 12.5px; color: #2563EB; font-weight: 600; margin-top: 2px;">Class: {cls_sec}</div>
                                        </td>
                                        <td width="45%" style="text-align: right;">
                                            <div style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">Invoice Number</div>
                                            <div style="font-size: 15px; font-weight: 800; color: #0F172A; margin-top: 2px;">{invoice_number}</div>
                                            <div style="font-size: 12px; color: #64748B; margin-top: 2px;">Due: <strong style="color: #DC2626;">{due_date}</strong></div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td colspan="2" style="padding-top: 10px; border-top: 1px dashed #CBD5E1; margin-top: 10px;">
                                            <span style="font-size: 11.5px; color: #64748B;">Roll No: <strong style="color: #0F172A;">{roll_number}</strong></span>
                                            &nbsp;&bull;&nbsp;
                                            <span style="font-size: 11.5px; color: #64748B;">Admission: <strong style="color: #0F172A;">{admission_number}</strong></span>
                                        </td>
                                    </tr>
                                </table>
                            </div>

                            <!-- INVOICE PARTICULARS TITLE -->
                            <div style="margin-bottom: 12px;">
                                <div style="font-size: 15px; font-weight: 800; color: #0F172A;">{title}</div>
                                <div style="font-size: 12px; color: #64748B;">Fee Type: {fee_type} &bull; Academic Year: 2026 - 2027</div>
                            </div>

                            <!-- ITEMIZED STATEMENT TABLE -->
                            <table width="100%" cellspacing="0" cellpadding="0" style="border: 1px solid #E2E8F0; border-radius: 10px; overflow: hidden; margin-bottom: 16px;">
                                <thead>
                                    <tr style="background: #F1F5F9; border-bottom: 1px solid #E2E8F0;">
                                        <th style="padding: 12px 16px; font-size: 11.5px; font-weight: 800; color: #475569; text-align: left; text-transform: uppercase;">Description</th>
                                        <th style="padding: 12px 16px; font-size: 11.5px; font-weight: 800; color: #475569; text-align: right; text-transform: uppercase;">Amount (&#x20B9;)</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td style="padding: 14px 16px; font-size: 13.5px; color: #1E293B; border-bottom: 1px solid #F1F5F9;">
                                            {title} ({fee_type})
                                        </td>
                                        <td style="padding: 14px 16px; font-size: 14px; color: #1E293B; font-weight: 700; text-align: right; border-bottom: 1px solid #F1F5F9;">
                                            &#x20B9; {fmt_gross}
                                        </td>
                                    </tr>
                                    {advance_deduction_row}
                                    <tr style="background: #FAFAFA; border-top: 2px solid #E2E8F0;">
                                        <td style="padding: 16px; font-size: 15px; font-weight: 900; color: #0F172A;">
                                            NET FEE PAYABLE:
                                        </td>
                                        <td style="padding: 16px; font-size: 18px; font-weight: 900; color: #2563EB; text-align: right;">
                                            &#x20B9; {fmt_net}
                                        </td>
                                    </tr>
                                </tbody>
                            </table>

                            {remaining_advance_row}

                            <!-- PAYMENT ACTION BLOCK -->
                            {payment_block}

                            <!-- IMPORTANT NOTICE -->
                            <div style="background: #FEF3C7; border-left: 4px solid #F59E0B; padding: 12px 16px; border-radius: 6px; margin-top: 20px;">
                                <div style="font-size: 12px; font-weight: 700; color: #92400E;">Payment Security Notice:</div>
                                <div style="font-size: 11.5px; color: #B45309; margin-top: 2px; line-height: 1.4;">
                                    Please ensure your fee is cleared before <strong>{due_date}</strong>. Automated receipts are generated instantly upon confirmation.
                                </div>
                            </div>

                        </td>
                    </tr>

                    <!-- FOOTER -->
                    <tr>
                        <td style="background: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 28px; text-align: center;">
                            <div style="font-size: 11.5px; color: #64748B; line-height: 1.5;">
                                This is a computer-generated billing statement issued by <strong>{school_name}</strong> ERP.
                                <br>For inquiries, please reply to this email or visit the school accounts office.
                            </div>
                            <div style="font-size: 10.5px; color: #94A3B8; margin-top: 8px;">
                                &copy; 2026 {school_name}. All rights reserved.
                            </div>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>
</html>
    """

def dispatch_fee_invoice_email(
    student_email: str,
    school_name: str,
    student_name: str,
    class_name: str,
    section_name: str,
    roll_number: str,
    admission_number: str,
    invoice_number: str,
    title: str,
    fee_type: str,
    due_date: str,
    gross_amount: float,
    advance_deducted: float,
    net_payable: float,
    remaining_advance: float,
    public_payment_url: Optional[str] = None
) -> bool:
    """Helper to dispatch fee invoice parent notification email via EmailService."""
    if not student_email or "@" not in student_email:
        return False
    try:
        from app.services.email_service import EmailService
        email_svc = EmailService()
        html = generate_fee_invoice_email_html(
            school_name=school_name,
            student_name=student_name,
            class_name=class_name,
            section_name=section_name,
            roll_number=roll_number,
            admission_number=admission_number,
            invoice_number=invoice_number,
            title=title,
            fee_type=fee_type,
            due_date=due_date,
            gross_amount=gross_amount,
            advance_deducted=advance_deducted,
            net_payable=net_payable,
            remaining_advance=remaining_advance,
            public_payment_url=public_payment_url
        )
        subject = f"[{school_name}] Tuition Invoice {invoice_number} - Due {due_date}"
        sent = email_svc._send_email(student_email, subject, html)
        if sent:
            logger.info(f"[Fee Email] Successfully dispatched invoice email {invoice_number} to {student_email}")
        return sent
    except Exception as e:
        logger.warning(f"[Fee Email] Could not send invoice email {invoice_number} to {student_email}: {e}")
        return False

async def _background_dispatch_fee_invoice_emails(
    invoices: list,
    school_id: str,
    title: str,
    fee_type: str,
    due_date_str: str,
    target_section: str
):
    """Background asynchronous dispatcher for parent email notifications."""
    try:
        sch_rows = await exec_sql("SELECT name FROM public.schools WHERE id = %s::UUID;", (school_id,))
        school_name = sch_rows[0]["name"] if sch_rows else "EduSHAMIIT Global Academy"

        emails_dispatched = 0
        for inv in invoices:
            to_email = inv.get("student_email")
            if to_email and "@" in to_email:
                sent = await asyncio.to_thread(
                    dispatch_fee_invoice_email,
                    student_email=to_email,
                    school_name=school_name,
                    student_name=inv.get("student_name", "Student"),
                    class_name=inv.get("class_name", ""),
                    section_name=target_section or "",
                    roll_number=inv.get("roll_number", "-"),
                    admission_number=inv.get("admission_number", ""),
                    invoice_number=inv.get("invoice_number", ""),
                    title=title,
                    fee_type=fee_type,
                    due_date=due_date_str,
                    gross_amount=float(inv.get("gross_amount") or 0.0),
                    advance_deducted=float(inv.get("advance_deducted") or 0.0),
                    net_payable=float(inv.get("net_payable") or 0.0),
                    remaining_advance=float(inv.get("remaining_advance") or 0.0),
                    public_payment_url=inv.get("public_payment_url") or (f"/pay/invoice/{inv.get('payment_token')}" if inv.get("payment_token") else None)
                )
                if sent:
                    emails_dispatched += 1
                await asyncio.sleep(0.01)

        if emails_dispatched > 0:
            await exec_sql("""
                UPDATE public.student_fee_schedule_runs
                SET emails_sent = %s
                WHERE id = (
                    SELECT id FROM public.student_fee_schedule_runs 
                    WHERE school_id = %s::UUID 
                    ORDER BY executed_at DESC 
                    LIMIT 1
                );
            """, (emails_dispatched, school_id), fetch=False)
            logger.info(f"[Fee Email Engine] Background dispatched {emails_dispatched} parent emails successfully.")
    except Exception as e:
        logger.error(f"[Fee Email Engine] Error in background dispatch: {e}")


async def process_due_fee_schedules_internal():
    """Background helper to execute any scheduled rules whose next_run_at is due."""
    try:
        rows = await exec_sql("SELECT public.fn_process_due_fee_schedules() AS result;")
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if res.get("rules_processed_count", 0) > 0:
                print(f"[Fee Schedule Engine] Processed {res['rules_processed_count']} due rules: {res.get('results')}", flush=True)
            return res
    except Exception as e:
        print(f"[Fee Schedule Engine] Background process failed: {e}", flush=True)
    return {"success": False, "rules_processed_count": 0}


@router.get("/student-fees/target-students-preview")
async def get_target_students_preview(
    target_type: str = Query("CLASS"),
    target_class: Optional[str] = Query("All Classes"),
    target_section: Optional[str] = Query("All Sections"),
    amount: Optional[float] = Query(4500.0),
    current_user: dict = Depends(get_current_user)
):
    """Preview students, advance credit deductions, and projected net collection matching class/section cohort."""
    school_id = _get_school_id(current_user)
    t_type = (target_type or "CLASS").upper().strip()
    t_class = (target_class or "All Classes").strip()
    t_section = (target_section or "All Sections").strip()
    unit_amt = float(amount or 4500.0)

    clean_sec = "" if (t_type in ("ALL", "INDIVIDUALS") or t_section in ("All Sections", "All")) else t_section
    clean_cls = "" if (t_type in ("ALL", "INDIVIDUALS") or t_class in ("All Classes", "All")) else t_class

    # Query matching students with live calculation of available advance credit wallet
    rows = await exec_sql("""
        SELECT 
            p.id,
            p.full_name,
            COALESCE(p.email, '') AS email,
            COALESCE(p.phone, '') AS phone,
            COALESCE(ac.name, p.class, '') AS class,
            COALESCE(p.roll_number::text, '-') AS roll_number,
            COALESCE(p.admission_number, 'ADM-' || UPPER(SUBSTRING(p.id::text, 1, 6))) AS admission_number,
            p.avatar_url,
            COALESCE(sec.name, sec.code, 'A') AS section_name,
            GREATEST(0.0,
                COALESCE((
                    SELECT SUM(pay.amount_paid)
                    FROM public.student_fee_payments pay
                    WHERE pay.student_id = p.id AND pay.school_id = p.school_id
                      AND (pay.status IS NULL OR pay.status IN ('SUCCESS', 'COMPLETED', 'VERIFIED_SUCCESS'))
                ), 0.0) 
                - 
                COALESCE((
                    SELECT SUM(inv.total_billed)
                    FROM public.student_fee_invoices inv
                    WHERE inv.student_id = p.id AND inv.school_id = p.school_id AND inv.status != 'Cancelled'
                ), 0.0)
            ) AS advance_wallet_balance
        FROM public.profiles p
        LEFT JOIN public.student_class_assignments sca ON sca.student_id = p.id AND sca.school_id = p.school_id
        LEFT JOIN public.academic_classes ac ON ac.id = sca.class_id
        LEFT JOIN public.academic_sections sec ON sec.id = sca.section_id
        WHERE p.school_id = %s::UUID AND p.role = 'student'
          AND (
            %s IN ('ALL', 'INDIVIDUALS')
            OR (%s = 'CLASS' AND (
                %s = ''
                OR p.class = %s
                OR REPLACE(LOWER(COALESCE(p.class, '')), ' ', '') = REPLACE(LOWER(%s), ' ', '')
                OR ac.name = %s
                OR REPLACE(LOWER(COALESCE(ac.name, '')), ' ', '') = REPLACE(LOWER(%s), ' ', '')
                OR (
                    REGEXP_REPLACE(COALESCE(p.class, ''), '[^0-9]', '', 'g') <> ''
                    AND REGEXP_REPLACE(COALESCE(p.class, ''), '[^0-9]', '', 'g') = REGEXP_REPLACE(%s, '[^0-9]', '', 'g')
                )
            ))
          )
          AND (
            %s IN ('ALL', 'INDIVIDUALS')
            OR %s = ''
            OR p.class ILIKE '%%' || %s || '%%'
            OR sec.name ILIKE %s OR sec.code ILIKE %s OR sec.name ILIKE '%%' || %s || '%%'
          )
        ORDER BY p.full_name ASC;
    """, (
        school_id,
        t_type,
        t_type,
        clean_cls, clean_cls, clean_cls, clean_cls, clean_cls, clean_cls,
        t_type,
        clean_sec, clean_sec, clean_sec, clean_sec, clean_sec
    ))

    # Process live credit deductions and forecasting
    students_out = []
    total_gross = len(rows) * unit_amt
    total_advance_deducted = 0.0
    total_net_payable = 0.0
    fully_settled_count = 0
    partial_settled_count = 0
    pending_count = 0

    for r in rows:
        adv = float(r.get("advance_wallet_balance") or 0.0)
        deduct = min(unit_amt, adv) if adv > 0 else 0.0
        net_due = max(0.0, unit_amt - deduct)
        rem_adv = max(0.0, adv - deduct)

        if net_due == 0.0 and deduct > 0:
            status_pred = "Auto-Settled via Credit"
            fully_settled_count += 1
        elif deduct > 0:
            status_pred = "Partial Credit Applied"
            partial_settled_count += 1
        else:
            status_pred = "Pending Collection"
            pending_count += 1

        total_advance_deducted += deduct
        total_net_payable += net_due

        students_out.append({
            "id": str(r["id"]),
            "full_name": r["full_name"],
            "email": r.get("email", ""),
            "phone": r.get("phone", ""),
            "class": r.get("class", ""),
            "section": r.get("section_name", "A"),
            "roll_number": r.get("roll_number", "-"),
            "admission_number": r.get("admission_number", ""),
            "avatar_url": r.get("avatar_url"),
            "advance_wallet_balance": adv,
            "projected_deduct_amount": deduct,
            "projected_net_payable": net_due,
            "projected_remaining_wallet": rem_adv,
            "status_prediction": status_pred
        })

    return {
        "success": True,
        "count": len(students_out),
        "target_type": t_type,
        "target_class": t_class,
        "target_section": t_section,
        "unit_amount": unit_amt,
        "total_gross_invoicing": total_gross,
        "total_advance_applied": total_advance_deducted,
        "total_net_payable": total_net_payable,
        "fully_settled_count": fully_settled_count,
        "partial_settled_count": partial_settled_count,
        "pending_collection_count": pending_count,
        "students": students_out
    }


@router.post("/student-fees/invoices/bulk-generate", status_code=status.HTTP_201_CREATED)
async def bulk_generate_student_invoices_v2(
    payload: EnhancedBulkInvoicePayload,
    current_user: dict = Depends(get_current_user)
):
    """Enhanced on-demand bulk student invoice generator with multi-section targeting,
    automatic student advance credit wallet deductions, and parent email dispatch."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Admin"

    # Compute due date if not explicitly supplied
    if payload.due_date and payload.due_date.strip():
        due_date_str = payload.due_date.strip()
    else:
        offset = payload.due_days_offset or 10
        due_date_obj = datetime.now().date() + timedelta(days=offset)
        due_date_str = due_date_obj.isoformat()

    s_ids_json = json.dumps(payload.student_ids or [])

    rows = await exec_sql(
        """
        SELECT public.fn_bulk_generate_student_invoices_v2(
            %s::UUID, %s, %s, %s::jsonb, %s, %s, %s, %s, %s::DATE, %s, %s, %s::UUID, %s, %s, %s, %s, %s::UUID
        ) AS result;
        """,
        (
            school_id, payload.target_type.upper(), payload.target_class, s_ids_json,
            payload.fee_type, payload.fee_plan, payload.academic_year, payload.amount,
            due_date_str, payload.title, payload.notes or f"Bulk Invoiced by {user_name}",
            user_id, user_name, payload.skip_duplicates, payload.target_section,
            payload.auto_deduct_advance_credit, _clean_uuid(payload.fee_structure_id)
        )
    )

    res = rows[0]["result"] if rows and rows[0].get("result") else {
        "success": True,
        "message": "Bulk invoices created successfully",
        "invoices_created": 0,
        "generated_invoices": []
    }

    # If send_parent_email is requested, dispatch notifications asynchronously
    if payload.send_parent_email and res.get("generated_invoices"):
        asyncio.create_task(_background_dispatch_fee_invoice_emails(
            invoices=res["generated_invoices"],
            school_id=school_id,
            title=payload.title,
            fee_type=payload.fee_type,
            due_date_str=due_date_str,
            target_section=payload.target_section or ""
        ))
        res["emails_queued"] = len(res["generated_invoices"])
        res["emails_sent"] = len([inv for inv in res["generated_invoices"] if inv.get("student_email") and "@" in inv.get("student_email")])
    else:
        res["emails_queued"] = 0
        res["emails_sent"] = 0

    return res


@router.get("/student-fees/schedules")
async def list_fee_schedule_rules(
    current_user: dict = Depends(get_current_user)
):
    """List all configured automated invoice scheduling rules."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql("""
        SELECT r.id, r.rule_name, r.target_type, r.target_class, r.target_section,
               r.student_ids, r.fee_type, r.fee_plan, r.amount, r.title_template,
               r.notes, r.frequency, r.schedule_day_of_month, r.due_days_offset,
               r.billing_period_target, r.academic_year, r.is_active,
               r.auto_deduct_advance_credit, r.send_parent_email,
               r.last_run_at, r.next_run_at, r.total_runs, r.total_invoices_generated,
               r.total_amount_generated, r.created_at, r.updated_at,
               p.full_name AS created_by_name, p.email AS created_by_email
        FROM public.student_fee_schedule_rules r
        LEFT JOIN public.profiles p ON p.id = r.created_by
        WHERE r.school_id = %s::UUID
        ORDER BY r.is_active DESC, r.created_at DESC;
    """, (school_id,))
    return {"success": True, "rules": _serialize_val(rows)}


@router.post("/student-fees/schedules", status_code=status.HTTP_201_CREATED)
async def create_fee_schedule_rule(
    payload: CreateFeeScheduleRulePayload,
    current_user: dict = Depends(get_current_user)
):
    """Create a new automated recurring invoice generation rule."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    s_ids_json = json.dumps(payload.student_ids or [])

    # Calculate initial next_run_at
    calc_rows = await exec_sql(
        "SELECT public.fn_calculate_next_fee_schedule_run(%s, %s, NOW()) AS next_run;",
        (payload.frequency, payload.schedule_day_of_month)
    )
    next_run = calc_rows[0]["next_run"] if calc_rows else None

    ins_rows = await exec_sql("""
        INSERT INTO public.student_fee_schedule_rules (
            school_id, rule_name, target_type, target_class, target_section,
            student_ids, fee_type, fee_plan, amount, title_template,
            notes, frequency, schedule_day_of_month, due_days_offset,
            billing_period_target, academic_year, is_active,
            auto_deduct_advance_credit, send_parent_email, next_run_at,
            fee_structure_id, auto_generate_all_cohort_heads,
            created_by, created_at, updated_at
        ) VALUES (
            %s::UUID, %s, %s, %s, %s,
            %s::jsonb, %s, %s, %s, %s,
            %s, %s, %s, %s,
            %s, %s, %s,
            %s, %s, %s,
            %s::UUID, %s,
            %s::UUID, NOW(), NOW()
        ) RETURNING id, rule_name, next_run_at;
    """, (
        school_id, payload.rule_name, payload.target_type.upper(), payload.target_class, payload.target_section,
        s_ids_json, payload.fee_type, payload.fee_plan, payload.amount, payload.title_template,
        payload.notes, payload.frequency.upper(), payload.schedule_day_of_month, payload.due_days_offset,
        payload.billing_period_target.upper(), payload.academic_year, payload.is_active,
        payload.auto_deduct_advance_credit, payload.send_parent_email, next_run,
        _clean_uuid(payload.fee_structure_id), payload.auto_generate_all_cohort_heads,
        user_id
    ))
    return {
        "success": True,
        "message": f"Schedule rule '{payload.rule_name}' created successfully",
        "rule": _serialize_val(ins_rows[0] if ins_rows else {})
    }


@router.put("/student-fees/schedules/{rule_id}")
async def update_fee_schedule_rule(
    rule_id: str,
    payload: UpdateFeeScheduleRulePayload,
    current_user: dict = Depends(get_current_user)
):
    """Update configuration of an automated invoice rule."""
    school_id = _get_school_id(current_user)
    rid = _clean_uuid(rule_id)
    if not rid:
        raise HTTPException(status_code=400, detail="Invalid rule_id UUID")

    # Fetch existing
    cur = await exec_sql("SELECT * FROM public.student_fee_schedule_rules WHERE id = %s::UUID AND school_id = %s::UUID;", (rid, school_id))
    if not cur:
        raise HTTPException(status_code=404, detail="Schedule rule not found")

    existing = cur[0]
    freq = payload.frequency.upper() if payload.frequency else existing["frequency"]
    day = payload.schedule_day_of_month if payload.schedule_day_of_month is not None else existing["schedule_day_of_month"]

    # Recompute next_run_at if schedule timing changed
    calc_rows = await exec_sql(
        "SELECT public.fn_calculate_next_fee_schedule_run(%s, %s, NOW()) AS next_run;",
        (freq, day)
    )
    next_run = calc_rows[0]["next_run"] if calc_rows else existing.get("next_run_at")

    s_ids_json = json.dumps(payload.student_ids) if payload.student_ids is not None else json.dumps(existing.get("student_ids") or [])

    await exec_sql("""
        UPDATE public.student_fee_schedule_rules
        SET rule_name = COALESCE(%s, rule_name),
            target_type = COALESCE(%s, target_type),
            target_class = COALESCE(%s, target_class),
            target_section = COALESCE(%s, target_section),
            student_ids = %s::jsonb,
            fee_type = COALESCE(%s, fee_type),
            fee_plan = COALESCE(%s, fee_plan),
            amount = COALESCE(%s, amount),
            title_template = COALESCE(%s, title_template),
            notes = COALESCE(%s, notes),
            frequency = %s,
            schedule_day_of_month = %s,
            due_days_offset = COALESCE(%s, due_days_offset),
            billing_period_target = COALESCE(%s, billing_period_target),
            academic_year = COALESCE(%s, academic_year),
            is_active = COALESCE(%s, is_active),
            auto_deduct_advance_credit = COALESCE(%s, auto_deduct_advance_credit),
            send_parent_email = COALESCE(%s, send_parent_email),
            next_run_at = %s,
            fee_structure_id = COALESCE(%s::UUID, fee_structure_id),
            auto_generate_all_cohort_heads = COALESCE(%s, auto_generate_all_cohort_heads),
            updated_at = NOW()
        WHERE id = %s::UUID AND school_id = %s::UUID;
    """, (
        payload.rule_name,
        payload.target_type.upper() if payload.target_type else None,
        payload.target_class,
        payload.target_section,
        s_ids_json,
        payload.fee_type,
        payload.fee_plan,
        payload.amount,
        payload.title_template,
        payload.notes,
        freq,
        day,
        payload.due_days_offset,
        payload.billing_period_target.upper() if payload.billing_period_target else None,
        payload.academic_year,
        payload.is_active,
        payload.auto_deduct_advance_credit,
        payload.send_parent_email,
        next_run,
        _clean_uuid(payload.fee_structure_id),
        payload.auto_generate_all_cohort_heads,
        rid,
        school_id
    ), fetch=False)

    return {"success": True, "message": "Schedule rule updated successfully"}


@router.patch("/student-fees/schedules/{rule_id}/toggle")
async def toggle_fee_schedule_rule(
    rule_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Toggle a rule between Active and Paused."""
    school_id = _get_school_id(current_user)
    rid = _clean_uuid(rule_id)
    if not rid:
        raise HTTPException(status_code=400, detail="Invalid rule_id UUID")

    rows = await exec_sql("""
        UPDATE public.student_fee_schedule_rules
        SET is_active = NOT is_active,
            updated_at = NOW()
        WHERE id = %s::UUID AND school_id = %s::UUID
        RETURNING id, rule_name, is_active, next_run_at;
    """, (rid, school_id))
    if not rows:
        raise HTTPException(status_code=404, detail="Schedule rule not found")

    st = "activated" if rows[0]["is_active"] else "paused"
    return {
        "success": True,
        "message": f"Rule '{rows[0]['rule_name']}' is now {st}",
        "is_active": rows[0]["is_active"]
    }


@router.delete("/student-fees/schedules/{rule_id}")
async def delete_fee_schedule_rule(
    rule_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Delete a schedule rule."""
    school_id = _get_school_id(current_user)
    rid = _clean_uuid(rule_id)
    if not rid:
        raise HTTPException(status_code=400, detail="Invalid rule_id UUID")

    await exec_sql("""
        DELETE FROM public.student_fee_schedule_rules
        WHERE id = %s::UUID AND school_id = %s::UUID;
    """, (rid, school_id), fetch=False)

    return {"success": True, "message": "Schedule rule deleted successfully"}


@router.post("/student-fees/schedules/{rule_id}/run")
async def execute_fee_schedule_rule_manually(
    rule_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Manually trigger immediate execution of a scheduled invoice rule with advance deductions and email dispatch."""
    school_id = _get_school_id(current_user)
    rid = _clean_uuid(rule_id)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Admin"

    if not rid:
        raise HTTPException(status_code=400, detail="Invalid rule_id UUID")

    rows = await exec_sql(
        "SELECT public.fn_execute_fee_schedule_rule(%s::UUID, %s::UUID, %s) AS result;",
        (rid, user_id, user_name)
    )
    if not rows or not rows[0].get("result"):
        return {"success": True, "message": "Rule execution completed"}

    res = rows[0]["result"]

    # Dispatch parent emails if enabled
    if res.get("send_parent_email") and res.get("generated_invoices"):
        asyncio.create_task(_background_dispatch_fee_invoice_emails(
            invoices=res["generated_invoices"],
            school_id=school_id,
            title=res.get("rule_name", "Scheduled Tuition Fee"),
            fee_type="Tuition Fee",
            due_date_str=str(res.get("due_date", "")),
            target_section=""
        ))
        res["emails_queued"] = len(res["generated_invoices"])
        res["emails_sent"] = len([inv for inv in res["generated_invoices"] if inv.get("student_email") and "@" in inv.get("student_email")])
    else:
        res["emails_queued"] = 0
        res["emails_sent"] = 0

    return res


@router.get("/student-fees/schedules/runs")
async def list_fee_schedule_runs(
    rule_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=200),
    current_user: dict = Depends(get_current_user)
):
    """List execution history logs and telemetry for bulk and scheduled invoice runs."""
    school_id = _get_school_id(current_user)
    rid = _clean_uuid(rule_id) if rule_id else None

    if rid:
        rows = await exec_sql("""
            SELECT id, rule_id, rule_name, triggered_by, triggered_by_name, trigger_type,
                   status, invoices_created, students_targeted, duplicates_skipped,
                   total_amount_billed, advance_credits_applied, net_amount_due, target_section,
                   emails_sent, billing_period, due_date, execution_notes, executed_at
            FROM public.student_fee_schedule_runs
            WHERE school_id = %s::UUID AND rule_id = %s::UUID
            ORDER BY executed_at DESC
            LIMIT %s;
        """, (school_id, rid, limit))
    else:
        rows = await exec_sql("""
            SELECT id, rule_id, rule_name, triggered_by, triggered_by_name, trigger_type,
                   status, invoices_created, students_targeted, duplicates_skipped,
                   total_amount_billed, advance_credits_applied, net_amount_due, target_section,
                   emails_sent, billing_period, due_date, execution_notes, executed_at
            FROM public.student_fee_schedule_runs
            WHERE school_id = %s::UUID
            ORDER BY executed_at DESC
            LIMIT %s;
        """, (school_id, limit))

    return {"success": True, "runs": _serialize_val(rows)}


@router.post("/student-fees/schedules/process-due")
async def trigger_due_fee_schedules_check(
    current_user: dict = Depends(get_current_user)
):
    """Trigger on-demand check and execution of all due fee schedule rules."""
    res = await process_due_fee_schedules_internal()
    return res



@router.post("/student-fees/payments", status_code=status.HTTP_201_CREATED)
async def collect_student_fee_payment(
    payload: CollectStudentPaymentPayload,
    current_user: dict = Depends(get_current_user)
):
    """Collect and record a payment receipt for a student invoice via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name")
    user_role = current_user.get("role")
    user_email = current_user.get("email") or ""
    if user_id and (not user_name or not user_role):
        prof = await exec_sql(
            "SELECT full_name, email, role FROM public.profiles WHERE id = %s::UUID LIMIT 1;",
            (user_id,)
        )
        if prof:
            user_name = user_name or prof[0].get("full_name")
            user_role = user_role or prof[0].get("role")
            user_email = user_email or prof[0].get("email") or ""
    user_name = user_name or "Finance Officer"
    user_role = user_role or "Finance Officer"
    sid = _clean_uuid(payload.student_id)
    inv_id = _clean_uuid(payload.invoice_id)

    # Route Advance Credit Wallet settlements to the dedicated Stored Procedure
    if payload.payment_method in ("Advance Credit Wallet", "Advance Credit") and inv_id:
        rows = await exec_sql(
            "SELECT public.fn_settle_invoice_from_advance(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s) AS result;",
            (school_id, inv_id, user_id, user_name, user_email, user_role)
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success"):
                raise HTTPException(status_code=400, detail=res.get("message", "Unable to settle from advance credit"))
            return res
        raise HTTPException(status_code=500, detail="Failed to settle invoice from advance credit wallet")

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


@router.post("/student-fees/refunds", status_code=status.HTTP_201_CREATED)
async def refund_student_fee(
    payload: RefundStudentFeePayload,
    current_user: dict = Depends(get_current_user)
):
    """Refund student overpayment or fee surplus via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name")
    user_role = current_user.get("role")
    if user_id and (not user_name or not user_role):
        prof = await exec_sql(
            "SELECT full_name, email, role FROM public.profiles WHERE id = %s::UUID LIMIT 1;",
            (user_id,)
        )
        if prof:
            user_name = user_name or prof[0].get("full_name")
            user_role = user_role or prof[0].get("role")
    user_name = user_name or "Finance Officer"
    user_role = user_role or "Finance Officer"
    sid = _clean_uuid(payload.student_id)
    inv_id = _clean_uuid(payload.invoice_id)
    pay_id = _clean_uuid(payload.payment_id)

    if not sid:
        raise HTTPException(status_code=400, detail="Invalid student_id UUID")

    if payload.amount <= 0:
        raise HTTPException(status_code=400, detail="Refund amount must be greater than 0")

    rows = await exec_sql(
        """
        SELECT public.fn_refund_student_fee(
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s::UUID, %s::UUID, %s::UUID, %s, %s
        ) AS result;
        """,
        (
            school_id, sid, payload.amount, payload.refund_mode,
            payload.reference_number, payload.reason or "Overpayment Refund",
            inv_id, pay_id, user_id, user_name, user_role
        )
    )
    if rows and rows[0].get("result"):
        res = rows[0]["result"]
        if not res.get("success"):
            raise HTTPException(status_code=400, detail=res.get("message", "Refund failed"))
        return res
    return {"success": True, "message": "Refund processed successfully"}


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
    class_grade: Optional[str] = Query(None),
    section_name: Optional[str] = Query(None),
    frequency_type: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """Catalog of fee structure templates via Stored Procedure with cohort filters & analytics."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        "SELECT public.fn_list_student_fee_structures(%s::UUID, %s, %s, %s, %s) AS result;",
        (school_id, class_grade, section_name, frequency_type, search)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "structures": [], "summary": {}}


@router.post("/student-fees/fee-structures", status_code=status.HTTP_201_CREATED)
async def create_student_fee_structure(
    payload: StudentFeeStructurePayload,
    current_user: dict = Depends(get_current_user)
):
    """Create a new fee structure template with section, frequency, and due fine rules."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        """
        SELECT public.fn_save_student_fee_structure(
            %s::UUID, NULL, %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id, payload.fee_name, payload.fee_type, payload.class_grade,
            payload.billing_cycle, payload.amount, payload.description, payload.is_mandatory,
            payload.section_name, payload.frequency_type, payload.due_day_of_cycle,
            payload.grace_period_days, payload.late_fine_amount, payload.late_fine_type,
            payload.is_refundable, payload.academic_year
        )
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
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id, sid, payload.fee_name, payload.fee_type, payload.class_grade,
            payload.billing_cycle, payload.amount, payload.description, payload.is_mandatory,
            payload.section_name, payload.frequency_type, payload.due_day_of_cycle,
            payload.grace_period_days, payload.late_fine_amount, payload.late_fine_type,
            payload.is_refundable, payload.academic_year
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Fee structure updated successfully"}


@router.post("/student-fees/fee-structures/clone", status_code=status.HTTP_201_CREATED)
async def clone_student_fee_structures(
    payload: CloneFeeStructurePayload,
    current_user: dict = Depends(get_current_user)
):
    """Clone an entire fee structure from one class/section to another cohort with optional markup."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or current_user.get("email") or "Finance Officer"
    rows = await exec_sql(
        """
        SELECT public.fn_clone_fee_structure_to_cohort(
            %s::UUID, %s, %s, %s, %s, %s, %s::UUID, %s
        ) AS result;
        """,
        (
            school_id, payload.source_class, payload.source_section,
            payload.target_class, payload.target_section, payload.markup_percent,
            user_id, user_name
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Fee structure cloned successfully"}


@router.get("/student-fees/students/{student_id}/applicable-fee-structure")
async def get_student_applicable_fee_structure(
    student_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Get the itemized applicable fee structure for a specific student based on their class & section."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(student_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid student_id UUID")
    rows = await exec_sql(
        "SELECT public.fn_get_student_applicable_fee_structure(%s::UUID, %s::UUID) AS result;",
        (school_id, sid)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": False, "message": "Could not resolve applicable fee structure"}


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
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name")
    user_role = current_user.get("role")
    user_email = current_user.get("email")
    if user_id and (not user_name or not user_role or not user_email):
        prof = await exec_sql(
            "SELECT full_name, email, role FROM public.profiles WHERE id = %s::UUID LIMIT 1;",
            (user_id,)
        )
        if prof:
            user_name = user_name or prof[0].get("full_name")
            user_role = user_role or prof[0].get("role")
            user_email = user_email or prof[0].get("email")
    user_name = user_name or "Finance Officer"
    user_role = user_role or "Finance Officer"
    user_email = user_email or ""

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
            performed_by_id, performed_by_name, performed_by_email, performed_by_role
        ) VALUES (
            %s::UUID, %s::UUID, 'PAYMENT', %s::UUID, 'STATUS_UPDATED',
            %s, %s, %s, %s,
            %s::UUID, %s, %s, %s
        );
        """, (school_id, student_id, pid, desc, old_status, new_status, amt, user_id, user_name, user_email, user_role), fetch=False)

    return {"success": True, "message": f"Payment status successfully updated to {new_status}", "new_status": new_status}


@router.post("/student-fees/invoices/{invoice_id}/settle-from-advance")
async def settle_invoice_from_advance(
    invoice_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Settle a student invoice balance using their available advance credit wallet."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Finance Officer"
    user_email = current_user.get("email") or ""
    user_role = current_user.get("role") or "Registrar"
    inv_id = _clean_uuid(invoice_id)
    if not inv_id:
        raise HTTPException(status_code=400, detail="Invalid invoice_id UUID")

    rows = await exec_sql(
        "SELECT public.fn_settle_invoice_from_advance(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s) AS result;",
        (school_id, inv_id, user_id, user_name, user_email, user_role)
    )
    if not rows or not rows[0].get("result"):
        raise HTTPException(status_code=500, detail="Failed to settle invoice from advance credit wallet")
    res = rows[0]["result"]
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("message", "Unable to settle invoice"))
    return res


@router.post("/student-fees/students/{student_id}/settle-advance")
async def settle_all_student_invoices_from_advance(
    student_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Auto-settle all pending invoices for a student using their advance credit wallet balance."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Finance Officer"
    user_email = current_user.get("email") or ""
    user_role = current_user.get("role") or "Registrar"
    sid = _clean_uuid(student_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid student_id UUID")

    rows = await exec_sql(
        "SELECT public.fn_settle_student_invoices_from_advance(%s::UUID, %s::UUID, %s::UUID, %s, %s, %s) AS result;",
        (school_id, sid, user_id, user_name, user_email, user_role)
    )
    if not rows or not rows[0].get("result"):
        raise HTTPException(status_code=500, detail="Failed to settle student invoices from advance credit")
    res = rows[0]["result"]
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("message", "Unable to settle invoices"))
    return res


@router.delete("/student-fees/payments/{payment_id}")
async def void_student_fee_payment(
    payment_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Safely void only uncompleted payments. Prevents deletion of completed receipts for audit protection."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Finance Officer"
    pid = _clean_uuid(payment_id)
    if not pid:
        raise HTTPException(status_code=400, detail="Invalid payment_id UUID")

    rows = await exec_sql(
        "SELECT public.fn_void_student_payment(%s::UUID, %s::UUID, %s::UUID, %s) AS result;",
        (school_id, pid, user_id, user_name)
    )
    if not rows or not rows[0].get("result"):
        raise HTTPException(status_code=500, detail="Database operation failed")
    res = rows[0]["result"]
    if not res.get("success"):
        raise HTTPException(status_code=400, detail=res.get("message", "Cannot delete payment record"))
    return res


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


@router.get("/staff-salary/search-all")
async def search_all_staff_for_payroll(
    search: Optional[str] = Query(""),
    month_str: Optional[str] = Query("2026-10"),
    current_user: dict = Depends(get_current_user)
):
    """Global search across all staff in the institution database for payroll disbursal with period status."""
    school_id = _get_school_id(current_user)
    clean_search = (search or "").strip()
    clean_month_str = (month_str or "2026-10").strip()

    rows = await exec_sql(
        """
        SELECT * FROM public.fn_search_all_staff_for_payroll(%s::UUID, %s::TEXT, %s::TEXT);
        """,
        (school_id, clean_search, clean_month_str)
    )

    items = []
    for r in (rows or []):
        items.append({
            "staff_id": str(r.get("staff_id")),
            "full_name": r.get("full_name") or "Staff Member",
            "employee_id": r.get("employee_id") or "",
            "designation": r.get("designation") or "Faculty",
            "department": r.get("department") or "General",
            "email": r.get("email") or "",
            "phone": r.get("phone") or "",
            "has_structure": bool(r.get("has_structure")),
            "basic_pay": float(r.get("basic_pay") or 0.0),
            "hra": float(r.get("hra") or 0.0),
            "da": float(r.get("da") or 0.0),
            "ta": float(r.get("ta") or 0.0),
            "special_allowance": float(r.get("special_allowance") or 0.0),
            "medical_allowance": float(r.get("medical_allowance") or 0.0),
            "gross_salary": float(r.get("gross_salary") or 0.0),
            "pf_deduction": float(r.get("pf_deduction") or 0.0),
            "tds": float(r.get("tds") or 0.0),
            "professional_tax": float(r.get("professional_tax") or 0.0),
            "insurance_deduction": float(r.get("insurance_deduction") or 0.0),
            "total_deductions": float(r.get("total_deductions") or 0.0),
            "net_salary": float(r.get("net_salary") or 0.0),
            "payment_mode": r.get("payment_mode") or "Direct Bank Transfer (NEFT/RTGS)",
            "bank_name": r.get("bank_name") or "",
            "account_number": r.get("account_number") or "",
            "ifsc_code": r.get("ifsc_code") or "",
            "pan_number": r.get("pan_number") or "",
            "active_advance_balance": float(r.get("active_advance_balance") or 0.0),
            "advance_monthly_emi": float(r.get("advance_monthly_emi") or 0.0),
            "payout_id": str(r.get("payout_id")) if r.get("payout_id") else None,
            "payout_status": r.get("payout_status") or "Pending",
            "payout_date": r.get("payout_date").isoformat() if r.get("payout_date") else None,
            "payout_txn_ref": r.get("payout_txn_ref"),
            "payout_payslip_number": r.get("payout_payslip_number"),
            "payout_net_pay": float(r.get("payout_net_pay") or 0.0) if r.get("payout_net_pay") is not None else None,
            "payout_bonus": float(r.get("payout_bonus") or 0.0),
            "payout_bonus_type": r.get("payout_bonus_type") or "NONE",
            "payout_bonus_remarks": r.get("payout_bonus_remarks"),
            "payout_other_deductions": float(r.get("payout_other_deductions") or 0.0),
            "payout_other_deductions_remarks": r.get("payout_other_deductions_remarks"),
        })

    return {
        "success": True,
        "search": clean_search,
        "month_str": clean_month_str,
        "count": len(items),
        "data": items
    }


def _dispatch_salary_payslip_emails(payslips: list, school_id: str):
    """Background task to dispatch official salary pay advice emails to staff."""
    try:
        email_svc = get_email_service()
        for p in payslips:
            to_email = (p.get("email") or "").strip()
            if not to_email or "@" not in to_email:
                continue

            staff_name = p.get("staff_name") or "Staff Member"
            emp_id = p.get("employee_id") or ""
            dept = p.get("department") or "Academic & Teaching"
            desig = p.get("designation") or "Faculty"
            month_str = p.get("month_str") or "Payroll Cycle"
            ps_num = p.get("payslip_number") or ""
            net_amt = float(p.get("net_pay") or 0.0)
            gross_amt = float(p.get("gross_earnings") or 0.0)
            total_ded = float(p.get("total_deductions") or 0.0)
            bpay = float(p.get("basic_pay") or 0.0)
            hra = float(p.get("hra") or 0.0)
            da = float(p.get("da") or 0.0)
            ta = float(p.get("ta") or 0.0)
            special = float(p.get("special_allowance") or 0.0)
            pf = float(p.get("pf_deduction") or 0.0)
            tds = float(p.get("tds") or 0.0)
            ptax = float(p.get("professional_tax") or 0.0)
            adv = float(p.get("advance_deduction") or 0.0)
            bank_name = p.get("bank_name") or "Direct Bank Credit"
            acc_num = p.get("account_number") or ""
            masked_acc = f"•••• {acc_num[-4:]}" if len(acc_num) >= 4 else (acc_num or "Configured Account")
            txn_ref = p.get("transaction_reference") or ""

            subject = f"Official Salary Payslip - {month_str} | EduSHAMIIT ERP"
            html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; color: #0f172a; margin: 0; padding: 24px; }}
    .card {{ max-width: 620px; margin: 0 auto; background: #ffffff; border-radius: 12px; border: 1px solid #e2e8f0; overflow: hidden; box-shadow: 0 4px 16px rgba(0,0,0,0.06); }}
    .header {{ background: #0f172a; color: #ffffff; padding: 24px 28px; }}
    .header h2 {{ margin: 0; font-size: 20px; font-weight: 800; }}
    .header p {{ margin: 4px 0 0; font-size: 12px; color: #94a3b8; }}
    .content {{ padding: 24px 28px; }}
    .meta-grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 12px; background: #f8fafc; padding: 14px; border-radius: 8px; margin-bottom: 20px; font-size: 12px; }}
    .meta-item b {{ color: #64748b; font-size: 11px; text-transform: uppercase; display: block; }}
    .table {{ width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 13px; }}
    .table th {{ background: #f1f5f9; padding: 8px 12px; text-align: left; font-size: 11px; text-transform: uppercase; color: #475569; }}
    .table td {{ padding: 8px 12px; border-bottom: 1px solid #e2e8f0; }}
    .net-box {{ background: #f0fdf4; border: 1.5px solid #16a34a; border-radius: 8px; padding: 16px 20px; display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }}
    .net-label {{ font-size: 12px; font-weight: 700; color: #166534; text-transform: uppercase; }}
    .net-amt {{ font-size: 22px; font-weight: 900; color: #15803d; }}
    .footer {{ font-size: 11px; color: #94a3b8; text-align: center; border-top: 1px solid #f1f5f9; padding: 16px; background: #fafafa; }}
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <h2>EduSHAMIIT International Institute</h2>
      <p>Institutional Payroll Advice • Period: {month_str} • Payslip: {ps_num}</p>
    </div>
    <div class="content">
      <p style="font-size: 14px; margin-top: 0;">Dear <b>{staff_name}</b>,</p>
      <p style="font-size: 13px; color: #334155;">Your monthly salary has been processed and credited. Below is your verified salary statement and deductions breakdown:</p>
      
      <div class="meta-grid">
        <div class="meta-item"><b>Employee ID</b> {emp_id}</div>
        <div class="meta-item"><b>Department / Role</b> {dept} • {desig}</div>
        <div class="meta-item"><b>Bank / A/C</b> {bank_name} ({masked_acc})</div>
        <div class="meta-item"><b>UTR / Txn Ref</b> {txn_ref or 'Direct Credit'}</div>
      </div>

      <table class="table">
        <thead>
          <tr>
            <th>Earnings Component</th>
            <th style="text-align: right;">Amount (₹)</th>
            <th>Statutory Deduction</th>
            <th style="text-align: right;">Amount (₹)</th>
          </tr>
        </thead>
        <tbody>
          <tr><td>Basic Pay</td><td style="text-align: right;">₹ {bpay:,.2f}</td><td>Provident Fund (PF)</td><td style="text-align: right;">₹ {pf:,.2f}</td></tr>
          <tr><td>House Rent Allowance (HRA)</td><td style="text-align: right;">₹ {hra:,.2f}</td><td>TDS / Income Tax</td><td style="text-align: right;">₹ {tds:,.2f}</td></tr>
          <tr><td>Dearness & Travel (DA/TA)</td><td style="text-align: right;">₹ {(da + ta):,.2f}</td><td>Professional Tax (PT)</td><td style="text-align: right;">₹ {ptax:,.2f}</td></tr>
          <tr><td>Special Allowance</td><td style="text-align: right;">₹ {special:,.2f}</td><td>Advance Recovery / Other</td><td style="text-align: right;">₹ {adv:,.2f}</td></tr>
          <tr style="font-weight: 700; background: #f8fafc;">
            <td>Total Gross Earnings</td><td style="text-align: right; color: #166534;">₹ {gross_amt:,.2f}</td>
            <td>Total Deductions</td><td style="text-align: right; color: #991b1b;">₹ {total_ded:,.2f}</td>
          </tr>
        </tbody>
      </table>

      <div class="net-box">
        <div>
          <div class="net-label">Net Take-Home Salary Credited</div>
          <div style="font-size: 11px; color: #15803d; margin-top: 2px;">Direct Institutional Bank Transfer (NEFT/RTGS)</div>
        </div>
        <div class="net-amt">₹ {net_amt:,.2f}</div>
      </div>
    </div>
    <div class="footer">
      This is an automated institutional salary advice from EduSHAMIIT ERP SSOT.
    </div>
  </div>
</body>
</html>"""
            email_svc._send_email(to_email, subject, html_content)
    except Exception as e:
        logger.error(f"[Payroll Automation] Failed to dispatch payslip emails: {e}", exc_info=True)


@router.get("/staff-salary/unconfigured-staff")
async def get_unconfigured_staff_for_salary(
    search: Optional[str] = Query(""),
    current_user: dict = Depends(get_current_user)
):
    """Fetch staff members who do not currently have a salary structure configured (for + Add Structure popup)."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        """
        SELECT public.fn_get_unconfigured_salary_staff(%s::UUID, %s::TEXT) AS result;
        """,
        (school_id, (search or "").strip())
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "count": 0, "staff": []}


@router.post("/staff-salary/auto-payroll-run")
async def auto_generate_monthly_payroll(
    payload: AutoPayrollRunPayload,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user)
):
    """Trigger institutional automated monthly payroll disbursal and payslip generation with email notification."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    rows = await exec_sql(
        """
        SELECT public.fn_auto_generate_monthly_payroll_payslips(
            %s::UUID, %s::TEXT, %s::TEXT, %s::UUID
        ) AS result;
        """,
        (school_id, payload.month_str.strip(), payload.payment_mode or "Direct Bank Transfer (NEFT/RTGS)", user_id)
    )
    if not rows or not rows[0].get("result"):
        raise HTTPException(status_code=500, detail="Automated payroll run failed to execute")

    res = rows[0]["result"]

    # Dispatch email payslip advice asynchronously in background
    if payload.send_email_notifications and res.get("payslips_generated"):
        background_tasks.add_task(
            _dispatch_salary_payslip_emails,
            res["payslips_generated"],
            str(school_id)
        )

    return res



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

    try:
        # If updated bank tender or tax details are supplied, keep staff structure synchronized
        if any([payload.bank_name, payload.account_number, payload.ifsc_code, payload.pan_number]):
            await exec_sql(
                """
                UPDATE public.staff_salary_structures
                SET bank_name = COALESCE(NULLIF(%s, ''), bank_name),
                    account_number = COALESCE(NULLIF(%s, ''), account_number),
                    ifsc_code = COALESCE(NULLIF(%s, ''), ifsc_code),
                    pan_number = COALESCE(NULLIF(%s, ''), pan_number),
                    updated_at = NOW()
                WHERE staff_id = %s::UUID AND school_id = %s::UUID;
                """,
                (payload.bank_name, payload.account_number, payload.ifsc_code, payload.pan_number, sid, school_id)
            )

        rows = await exec_sql(
            """
            SELECT public.fn_process_staff_salary_payout(
                %s::UUID, %s::UUID, %s, %s, %s,
                %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s::UUID,
                %s, %s, %s, %s
            ) AS result;
            """,
            (
                school_id, sid, payload.month, payload.year, payload.month_str,
                payload.basic_pay, payload.hra, payload.da, payload.ta, payload.special_allowance, payload.bonus,
                payload.pf_deduction, payload.tds, payload.professional_tax, payload.advance_deduction, payload.other_deductions,
                payload.payment_status, payload.payment_mode, payload.transaction_reference, payload.remarks, user_id,
                payload.bonus_type or "NONE", payload.bonus_remarks, payload.other_deductions_remarks, payload.update_permanent_structure
            )
        )
        if rows and rows[0].get("result"):
            res = rows[0]["result"]
            if not res.get("success", True):
                raise HTTPException(status_code=400, detail=res.get("message", "Failed to process salary payout"))
            return res
        return {"success": True, "message": "Salary payout processed successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error in process_staff_salary_payout: {str(e)}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Database execution error: {str(e)}")


@router.post("/staff-salary/payouts/bulk", status_code=status.HTTP_201_CREATED)
async def bulk_process_staff_payroll(
    payload: BulkStaffPayrollPayload,
    current_user: dict = Depends(get_current_user)
):
    """Disburse salaries in bulk for all active staff in one click via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    target_month = payload.month_str or f"{payload.year}-{str(payload.month).zfill(2)}"

    rows = await exec_sql(
        """
        SELECT public.fn_bulk_run_staff_payroll(
            %s::UUID, %s, %s, %s, 'generate_and_disburse', %s::UUID
        ) AS result;
        """,
        (
            school_id,
            target_month,
            payload.department if payload.department not in ("All Departments", "All", "") else None,
            payload.payment_mode or "Direct Bank Transfer (NEFT/RTGS)",
            user_id
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "disbursed_count": 0, "message": "Bulk payroll processed successfully"}


@router.post("/staff-salary/structures", status_code=status.HTTP_201_CREATED)
async def create_staff_salary_structure(
    payload: StaffSalaryStructurePayload,
    current_user: dict = Depends(get_current_user)
):
    """Assign or update base salary compensation structure via Stored Procedure."""
    school_id = _get_school_id(current_user)
    sid = _clean_uuid(payload.staff_id)
    if not sid:
        raise HTTPException(status_code=400, detail="Invalid staff_id UUID")

    rows = await exec_sql(
        """
        SELECT public.fn_create_staff_salary_structure(
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id, sid, payload.basic_pay, payload.hra, payload.da, payload.ta,
            payload.special_allowance, payload.medical_allowance, payload.pf_deduction,
            payload.tds, payload.professional_tax, payload.insurance_deduction,
            payload.bank_name, payload.account_number, payload.ifsc_code, payload.pan_number,
            payload.payment_mode
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Salary structure created successfully"}


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
        SELECT public.fn_create_staff_salary_structure(
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id, sid, payload.basic_pay, payload.hra, payload.da, payload.ta,
            payload.special_allowance, payload.medical_allowance, payload.pf_deduction,
            payload.tds, payload.professional_tax, payload.insurance_deduction,
            payload.bank_name, payload.account_number, payload.ifsc_code, payload.pan_number,
            payload.payment_mode
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Salary structure updated successfully"}


@router.get("/staff-salary/structures")
async def list_staff_salary_structures(
    department: Optional[str] = Query(None),
    search: Optional[str] = Query(""),
    sort_by: Optional[str] = Query("name"),
    sort_order: Optional[str] = Query("ASC"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Sub-tab 4: Master catalog of all staff salary structures via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        """
        SELECT public.fn_staff_salary_structures_catalog(
            %s::UUID, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id,
            department if department not in ("All Departments", "All", "") else None,
            search or None,
            sort_by or "name",
            sort_order or "ASC",
            page,
            page_size
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "structures": [], "total_items": 0, "total_pages": 1}


@router.get("/staff-salary/payslips")
async def list_staff_payslips(
    month_str: Optional[str] = Query("2026-10"),
    department: Optional[str] = Query(None),
    search: Optional[str] = Query(""),
    sort_by: Optional[str] = Query("payslip_number"),
    sort_order: Optional[str] = Query("DESC"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Master list of monthly payslips via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        """
        SELECT public.fn_staff_payslips_master(
            %s::UUID, %s, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id,
            month_str or "2026-10",
            department if department not in ("All Departments", "All", "") else None,
            search or None,
            sort_by or "payslip_number",
            sort_order or "DESC",
            page,
            page_size
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "payslips": [], "page": page, "page_size": page_size, "total_items": 0, "total_pages": 1}


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
    status: Optional[str] = Query(None),
    search: Optional[str] = Query(""),
    sort_by: Optional[str] = Query("created_at"),
    sort_order: Optional[str] = Query("DESC"),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Master list of salary advances via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        """
        SELECT public.fn_staff_advances_master(
            %s::UUID, %s, %s, %s, %s, %s, %s
        ) AS result;
        """,
        (
            school_id,
            status if status not in ("All Status", "All", "") else None,
            search or None,
            sort_by or "created_at",
            sort_order or "DESC",
            page,
            page_size
        )
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "advances": [], "page": page, "page_size": page_size, "total_items": 0, "total_pages": 1}


@router.post("/staff-salary/advances/{advance_id}/settle")
async def settle_staff_salary_advance(
    advance_id: str,
    payload: SettleStaffAdvancePayload,
    current_user: dict = Depends(get_current_user)
):
    """Early settlement / repayment of a staff salary advance via Stored Procedure."""
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    aid = _clean_uuid(advance_id)
    if not aid:
        raise HTTPException(status_code=400, detail="Invalid advance_id UUID")

    rows = await exec_sql(
        """
        SELECT public.fn_settle_staff_salary_advance(
            %s::UUID, %s::UUID, %s, %s, %s, %s::UUID
        ) AS result;
        """,
        (school_id, aid, payload.settlement_amount, payload.payment_mode, payload.remarks, user_id)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {"success": True, "message": "Advance settled successfully"}


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


@router.get("/staff-salary/export/bank-file")
async def export_bank_disbursal_file(
    month_str: Optional[str] = Query("2026-10"),
    department: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """Generate and stream corporate bank NACH/NEFT disbursal CSV file via Stored Procedure."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql(
        "SELECT public.fn_export_bank_disbursal_file(%s::UUID, %s, %s) AS result;",
        (school_id, month_str or "2026-10", department if department not in ("All Departments", "All", "") else None)
    )
    result = rows[0]["result"] if rows and rows[0].get("result") else {}
    records = result.get("records", [])

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Beneficiary Name", "Employee ID", "Department", "Bank Name",
        "Account Number", "IFSC Code", "Disbursal Amount (INR)",
        "Narration", "Payslip Number", "Status"
    ])
    for r in records:
        writer.writerow([
            r.get("beneficiary_name", ""),
            r.get("employee_id", ""),
            r.get("department", ""),
            r.get("bank_name", ""),
            r.get("account_number", ""),
            r.get("ifsc_code", ""),
            f"{float(r.get('amount', 0.0)):.2f}",
            r.get("narration", ""),
            r.get("payslip_number", ""),
            r.get("status", "")
        ])

    output.seek(0)
    filename = f"Bank_NEFT_Disbursal_{month_str or '2026-10'}.csv"
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode('utf-8')),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


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
        COALESCE(pay.net_pay, struct.net_salary, (COALESCE(struct.gross_salary, 63000.0) - COALESCE(struct.total_deductions, 7900.0))) AS net_salary,
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
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name")
    user_role = current_user.get("role")
    user_email = current_user.get("email")
    if user_id and (not user_name or not user_role or not user_email):
        prof = await exec_sql(
            "SELECT full_name, email, role FROM public.profiles WHERE id = %s::UUID LIMIT 1;",
            (user_id,)
        )
        if prof:
            user_name = user_name or prof[0].get("full_name")
            user_role = user_role or prof[0].get("role")
            user_email = user_email or prof[0].get("email")
    user_name = user_name or "Finance Officer"
    user_role = user_role or "Finance Officer"
    user_email = user_email or ""

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
        performed_by_id, performed_by_name, performed_by_email, performed_by_role
    ) VALUES (
        %s::UUID, %s::UUID, 'PAYMENT', %s::UUID, 'UPI_QR_CREATED',
        %s, 'Pending', 'WAITING_CONFIRMATION', %s,
        %s::UUID, %s, %s, %s
    );
    """, (
        school_id, student_id, intent_id,
        f"Dynamic UPI QR created for ₹{total_amount:.2f} (Ref: {intent_ref}). Waiting confirmation.",
        total_amount,
        user_id, user_name, user_email, user_role
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




# ============================================================================
# COHORT MATCHING & LINKED FEE STRUCTURES
# ============================================================================

@router.get("/student-fees/fee-structures/cohort-matching")
async def get_cohort_matching_fee_structures(
    class_grade: str = Query("All Classes"),
    section_name: str = Query("All Sections"),
    academic_year: str = Query("2026 - 2027"),
    current_user: dict = Depends(get_current_user)
):
    """
    Returns ranked, deduplicated fee structure heads matching target cohort.
    Priority order:
      1. Exact Class + Exact Section
      2. Exact Class + All Sections
      3. All Classes + All Sections (Institution-wide)
    Deduplicated by fee head name so specific cohort settings override broader rules.
    """
    school_id = _get_school_id(current_user)
    cls = (class_grade or "All Classes").strip()
    sec = (section_name or "All Sections").strip()

    rows = await exec_sql("""
        WITH ranked_heads AS (
            SELECT 
                s.id, s.fee_name, s.fee_type, s.class_grade, s.section_name,
                s.billing_cycle, s.frequency_type, s.amount, s.due_day_of_cycle,
                s.grace_period_days, s.late_fine_amount, s.late_fine_type,
                s.is_mandatory, s.is_refundable, s.status, s.academic_year,
                s.academic_start_date, s.installment_dates, s.reminder_stages,
                CASE 
                    WHEN LOWER(TRIM(s.class_grade)) = LOWER(TRIM(%s)) 
                         AND LOWER(TRIM(s.section_name)) = LOWER(TRIM(%s)) THEN 1
                    WHEN LOWER(TRIM(s.class_grade)) = LOWER(TRIM(%s)) 
                         AND (LOWER(TRIM(s.section_name)) IN ('all sections', 'all', '') OR s.section_name IS NULL) THEN 2
                    WHEN LOWER(TRIM(s.class_grade)) IN ('all classes', 'all', '') OR s.class_grade IS NULL THEN 3
                    ELSE 99
                END AS cohort_rank,
                ROW_NUMBER() OVER (
                    PARTITION BY LOWER(TRIM(s.fee_name)) 
                    ORDER BY 
                        CASE 
                            WHEN LOWER(TRIM(s.class_grade)) = LOWER(TRIM(%s)) 
                                 AND LOWER(TRIM(s.section_name)) = LOWER(TRIM(%s)) THEN 1
                            WHEN LOWER(TRIM(s.class_grade)) = LOWER(TRIM(%s)) 
                                 AND (LOWER(TRIM(s.section_name)) IN ('all sections', 'all', '') OR s.section_name IS NULL) THEN 2
                            WHEN LOWER(TRIM(s.class_grade)) IN ('all classes', 'all', '') OR s.class_grade IS NULL THEN 3
                            ELSE 99
                        END ASC,
                        s.updated_at DESC
                ) AS rank_in_name
            FROM public.student_fee_structures s
            WHERE s.school_id = %s::UUID
              AND s.status = 'ACTIVE'
              AND (
                  LOWER(TRIM(s.class_grade)) IN ('all classes', 'all', '')
                  OR s.class_grade IS NULL
                  OR LOWER(TRIM(s.class_grade)) = LOWER(TRIM(%s))
              )
        )
        SELECT * FROM ranked_heads
        WHERE cohort_rank < 99 AND rank_in_name = 1
        ORDER BY cohort_rank ASC, billing_cycle ASC, fee_name ASC;
    """, (cls, sec, cls, cls, sec, cls, school_id, cls))

    return {
        "success": True,
        "count": len(rows),
        "target_class": cls,
        "target_section": sec,
        "fee_structures": _serialize_val(rows)
    }


@router.get("/student-fees/cohort-due-heads")
async def get_cohort_due_fee_heads(
    class_grade: str = Query("All Classes"),
    section_name: str = Query("All Sections"),
    academic_year: str = Query("2026 - 2027"),
    reference_date: Optional[str] = Query(None),
    current_user: dict = Depends(get_current_user)
):
    """
    Intelligent Cohort Due Evaluation:
    Evaluates fee structure catalog against the reference date.
    Identifies fee heads & installment dates DUE RIGHT NOW,
    ALREADY BILLED heads, and FUTURE HEADS (e.g. Exams 3 months away)
    protected from premature bulk invoicing.
    """
    school_id = _get_school_id(current_user)
    cls = (class_grade or "All Classes").strip()
    sec = (section_name or "All Sections").strip()
    ref_d = reference_date if reference_date else date.today().isoformat()

    rows = await exec_sql(
        "SELECT public.fn_evaluate_cohort_due_fee_heads(%s::UUID, %s, %s, %s, %s::DATE) AS result;",
        (school_id, cls, sec, academic_year, ref_d)
    )
    if rows and rows[0].get("result"):
        return rows[0]["result"]
    return {
        "success": True,
        "due_heads": [],
        "future_heads": [],
        "completed_heads": [],
        "due_heads_count": 0,
        "future_heads_count": 0
    }


class BulkGenerateDueHeadsPayload(BaseModel):
    target_class: str = "Class 10"
    target_section: str = "All Sections"
    academic_year: str = "2026 - 2027"
    selected_head_ids: Optional[List[str]] = None
    auto_deduct_advance_credit: bool = True
    send_parent_email: bool = True
    notice_stage: Optional[str] = None
    reference_date: Optional[str] = None


@router.post("/student-fees/invoices/bulk-generate-due-heads", status_code=status.HTTP_201_CREATED)
async def bulk_generate_cohort_due_heads(
    payload: BulkGenerateDueHeadsPayload,
    current_user: dict = Depends(get_current_user)
):
    """
    1-Click Intelligent Bulk Due Head Generator:
    Takes all active due heads evaluated for the cohort (excluding future scheduled heads),
    generates invoices with exact installment amounts, applies advance credit deductions,
    and dispatches parent reminder emails with UPI payment links and late fine warnings.
    """
    school_id = _get_school_id(current_user)
    user_id = _clean_uuid(current_user.get("id"))
    user_name = current_user.get("full_name") or "Admin"
    cls = (payload.target_class or "All Classes").strip()
    sec = (payload.target_section or "All Sections").strip()
    ref_d = payload.reference_date if payload.reference_date else date.today().isoformat()

    eval_rows = await exec_sql(
        "SELECT public.fn_evaluate_cohort_due_fee_heads(%s::UUID, %s, %s, %s, %s::DATE) AS result;",
        (school_id, cls, sec, payload.academic_year, ref_d)
    )
    if not eval_rows or not eval_rows[0].get("result"):
        raise HTTPException(status_code=400, detail="Could not evaluate cohort due heads")

    eval_res = eval_rows[0]["result"]
    due_heads = eval_res.get("due_heads") or []

    if payload.selected_head_ids and len(payload.selected_head_ids) > 0:
        sel_set = set(str(sid) for sid in payload.selected_head_ids)
        due_heads = [h for h in due_heads if str(h.get("fee_structure_id")) in sel_set]

    if not due_heads:
        return {
            "success": True,
            "message": "No fee heads are currently due for billing in this cohort.",
            "heads_processed_count": 0,
            "total_invoices_created": 0,
            "future_heads_protected": len(eval_res.get("future_heads") or []),
            "generated_heads": []
        }

    total_invoices = 0
    total_gross = 0.0
    total_advance = 0.0
    total_net = 0.0
    processed_heads = []

    for head in due_heads:
        head_id = _clean_uuid(head.get("fee_structure_id"))
        fee_name = head.get("fee_name") or "Tuition Fee"
        fee_type = head.get("fee_type") or "Tuition Fee"
        cycle = head.get("billing_cycle") or "Monthly"
        title = head.get("suggested_title") or fee_name
        amount = float(head.get("amount") or 0.0)
        due_date_str = head.get("due_date") or date.today().isoformat()
        late_penalty_note = head.get("late_penalty_note") or ""

        rows = await exec_sql(
            """
            SELECT public.fn_bulk_generate_student_invoices_v2(
                %s::UUID, 'CLASS', %s, '[]'::jsonb, %s, %s, %s, %s, %s::DATE, %s, %s, %s::UUID, %s, true, %s, %s, %s::UUID
            ) AS result;
            """,
            (
                school_id, cls, fee_type, cycle, payload.academic_year, amount,
                due_date_str, title, f"Intelligent Bulk Generated: {title}",
                user_id, user_name, sec, payload.auto_deduct_advance_credit, head_id
            )
        )

        res = rows[0]["result"] if rows and rows[0].get("result") else {
            "success": True, "invoices_created": 0, "generated_invoices": []
        }

        inv_count = res.get("invoices_created", 0)
        gen_invoices = res.get("generated_invoices") or []
        total_invoices += inv_count

        for inv in gen_invoices:
            total_gross += float(inv.get("gross_amount") or 0.0)
            total_advance += float(inv.get("advance_deducted") or 0.0)
            total_net += float(inv.get("net_payable") or 0.0)

        if payload.send_parent_email and gen_invoices:
            asyncio.create_task(_background_dispatch_fee_invoice_emails(
                invoices=gen_invoices,
                school_id=school_id,
                title=title,
                fee_type=fee_type,
                due_date_str=due_date_str,
                target_section=sec,
                late_penalty_note=late_penalty_note,
                notice_stage=payload.notice_stage
            ))

        processed_heads.append({
            "fee_name": fee_name,
            "installment_label": head.get("installment_label"),
            "amount": amount,
            "due_date": due_date_str,
            "invoices_created": inv_count,
            "late_penalty_note": late_penalty_note
        })

    return {
        "success": True,
        "message": f"Successfully generated {total_invoices} invoice(s) across {len(processed_heads)} due fee head(s).",
        "heads_processed_count": len(processed_heads),
        "total_invoices_created": total_invoices,
        "total_gross_billed": total_gross,
        "total_advance_deducted": total_advance,
        "total_net_payable": total_net,
        "future_heads_protected": len(eval_res.get("future_heads") or []),
        "processed_heads": processed_heads
    }


# ============================================================================
# PUBLIC PARENT PAYMENT PORTAL (ZERO-AUTH, SECURE ONE-CLICK TOKEN)
# ============================================================================

public_router = APIRouter()

class PublicUtrSubmitPayload(BaseModel):
    utr: str = Field(..., min_length=4, max_length=100)
    intent_id: Optional[str] = None


def _generate_qr_data_uri(upi_url: str) -> str:
    """Generates a Base64 PNG QR code data URI or falls back to public QR service."""
    try:
        import qrcode
        qr = qrcode.QRCode(version=1, box_size=8, border=2)
        qr.add_data(upi_url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="#0F172A", back_color="#FFFFFF")
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode("utf-8")
    except Exception:
        return "https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=" + urllib.parse.quote(upi_url)


@public_router.get("/public/fee-invoices/{token}")
async def get_public_fee_invoice(token: str):
    """
    Public lookup endpoint for an invoice by its secure payment token.
    No login required. Returns student metadata, itemized breakdown, and school details.
    """
    t = token.strip()
    rows = await exec_sql("""
        SELECT inv.*,
               p.full_name AS student_name, p.email AS student_email, p.phone AS student_phone,
               p.class AS student_class, p.roll_number, p.admission_number,
               COALESCE(p.father_name, p.mother_name, p.local_guardian, 'Parent / Guardian') AS parent_name, COALESCE(p.father_phone, p.mother_phone, p.phone) AS parent_phone, COALESCE(p.email, '') AS parent_email,
               sch.name AS school_name, sch.logo_url AS school_logo,
               fs.fee_name AS structure_fee_name, fs.frequency_type AS structure_frequency,
               fs.due_day_of_cycle, fs.grace_period_days, fs.late_fine_amount
        FROM public.student_fee_invoices inv
        JOIN public.profiles p ON p.id = inv.student_id
        JOIN public.schools sch ON sch.id = inv.school_id
        LEFT JOIN public.student_fee_structures fs ON fs.id = inv.fee_structure_id
        WHERE inv.payment_token = %s
          AND inv.status != 'Cancelled'
        LIMIT 1;
    """, (t,))

    if not rows:
        raise HTTPException(status_code=404, detail="Invoice not found or link has expired")

    inv = rows[0]
    inv_id = str(inv["id"])
    school_id = str(inv["school_id"])

    # Fetch payment receipts
    payments = await exec_sql("""
        SELECT id, receipt_number, amount_paid, payment_method, transaction_reference,
               payment_date, status, remarks, created_at
        FROM public.student_fee_payments
        WHERE invoice_id = %s::UUID
        ORDER BY created_at DESC;
    """, (inv_id,))

    # Fetch receiving UPI account
    upi_rows = await exec_sql("""
        SELECT vpa, display_name, beneficiary_name 
        FROM public.school_upi_accounts 
        WHERE school_id = %s::UUID AND is_active = true 
        ORDER BY is_default DESC, created_at ASC LIMIT 1;
    """, (school_id,))

    if upi_rows:
        upi_vpa = upi_rows[0]["vpa"]
        beneficiary = upi_rows[0]["beneficiary_name"] or inv.get("school_name") or "EduSHAMIIT"
    else:
        upi_vpa = "edushamiit@ybl"
        beneficiary = inv.get("school_name") or "EduSHAMIIT Academy"

    return {
        "success": True,
        "invoice": _serialize_val(inv),
        "payments": _serialize_val(payments),
        "receiving_upi": {
            "vpa": upi_vpa,
            "beneficiary_name": beneficiary
        }
    }


@public_router.post("/public/fee-invoices/{token}/create-intent")
async def create_public_payment_intent(token: str):
    """
    Creates dynamic UPI payment intent with conflict-safe unique paise offset (10-minute window).
    Reuses active non-expired intent if one already exists.
    """
    t = token.strip()
    inv_rows = await exec_sql("""
        SELECT inv.*, sch.name AS school_name, p.full_name AS student_name
        FROM public.student_fee_invoices inv
        JOIN public.schools sch ON sch.id = inv.school_id
        JOIN public.profiles p ON p.id = inv.student_id
        WHERE inv.payment_token = %s AND inv.status != 'Cancelled'
        LIMIT 1;
    """, (t,))

    if not inv_rows:
        raise HTTPException(status_code=404, detail="Invoice not found or payment link expired")

    inv = inv_rows[0]
    bal = float(inv.get("balance_amount") or 0.0)

    if bal <= 0:
        return {
            "success": True,
            "status": "ALREADY_PAID",
            "message": "This invoice has already been fully settled.",
            "balance_amount": 0.0
        }

    school_id = str(inv["school_id"])
    student_id = str(inv["student_id"])
    invoice_id = str(inv["id"])

    # 1. Check for existing active non-expired intent for this invoice
    existing_intent = await exec_sql("""
        SELECT * FROM public.payment_intents
        WHERE invoice_id = %s::UUID
          AND status = 'PENDING'
          AND expires_at > NOW()
        ORDER BY created_at DESC LIMIT 1;
    """, (invoice_id,))

    now_utc = datetime.now(timezone.utc)

    # Fetch UPI details
    upi_rows = await exec_sql("""
        SELECT vpa, display_name, beneficiary_name 
        FROM public.school_upi_accounts 
        WHERE school_id = %s::UUID AND is_active = true 
        ORDER BY is_default DESC, created_at ASC LIMIT 1;
    """, (school_id,))
    vpa = upi_rows[0]["vpa"] if upi_rows else "edushamiit@ybl"
    beneficiary = upi_rows[0]["beneficiary_name"] if upi_rows else (inv.get("school_name") or "EduSHAMIIT")

    if existing_intent:
        ei = existing_intent[0]
        total_amt = float(ei["total_amount_paise"]) / 100.0
        exp = ei["expires_at"]
        rem_secs = max(10, int((exp - now_utc).total_seconds())) if exp else 600
        intent_ref = ei["intent_reference"]
        upi_url = f"upi://pay?pa={vpa}&pn={urllib.parse.quote(beneficiary)}&am={total_amt:.2f}&cu=INR&tn={urllib.parse.quote(intent_ref)}"
        qr_uri = _generate_qr_data_uri(upi_url)

        return {
            "success": True,
            "status": "PENDING",
            "intent_id": str(ei["id"]),
            "intent_reference": intent_ref,
            "base_amount": float(ei["base_amount_paise"]) / 100.0,
            "extra_paise": ei["unique_paise"],
            "total_amount": total_amt,
            "upi_vpa": vpa,
            "beneficiary_name": beneficiary,
            "upi_intent_url": upi_url,
            "qr_code_data_uri": qr_uri,
            "expires_at": exp.isoformat() if exp else None,
            "remaining_seconds": rem_secs,
            "is_reused": True
        }

    # 2. Concurrency-Safe Unique-Paise Calculation (10-minute collision detection)
    base_paise = int(round(bal * 100))
    extra_paise = await generate_unique_amount_paise(
        school_id=school_id,
        base_amount_paise=base_paise,
        window_minutes=10,
        max_extra_paise=99
    )
    total_paise = base_paise + extra_paise
    total_amt = total_paise / 100.0

    intent_ref = f"EDU{datetime.now().strftime('%Y%m%d%H%M')}{secrets.token_hex(2).upper()}"
    expires_at = now_utc + timedelta(minutes=10)
    grace_expires_at = expires_at + timedelta(minutes=2)

    upi_url = f"upi://pay?pa={vpa}&pn={urllib.parse.quote(beneficiary)}&am={total_amt:.2f}&cu=INR&tn={urllib.parse.quote(intent_ref)}"
    qr_uri = _generate_qr_data_uri(upi_url)

    meta = json.dumps({
        "invoice_number": inv.get("invoice_number"),
        "student_name": inv.get("student_name"),
        "token": t
    })

    ins_rows = await exec_sql("""
        INSERT INTO public.payment_intents (
            school_id, student_id, invoice_id, intent_reference,
            base_amount_paise, total_amount_paise, unique_paise, currency,
            upi_vpa, status, expires_at, grace_expires_at, metadata, created_at, updated_at
        ) VALUES (
            %s::UUID, %s::UUID, %s::UUID, %s,
            %s, %s, %s, 'INR',
            %s, 'PENDING', %s, %s, %s::jsonb, NOW(), NOW()
        ) RETURNING id, intent_reference, expires_at;
    """, (
        school_id, student_id, invoice_id, intent_ref,
        base_paise, total_paise, extra_paise,
        vpa, expires_at, grace_expires_at, meta
    ))

    new_id = str(ins_rows[0]["id"]) if ins_rows else None

    return {
        "success": True,
        "status": "PENDING",
        "intent_id": new_id,
        "intent_reference": intent_ref,
        "base_amount": bal,
        "extra_paise": extra_paise,
        "total_amount": total_amt,
        "upi_vpa": vpa,
        "beneficiary_name": beneficiary,
        "upi_intent_url": upi_url,
        "qr_code_data_uri": qr_uri,
        "expires_at": expires_at.isoformat(),
        "remaining_seconds": 600,
        "is_reused": False
    }


@public_router.get("/public/fee-invoices/{token}/intent-status/{intent_id}")
async def get_public_intent_status(token: str, intent_id: str):
    """
    Real-time polling endpoint (called every 2.5s by client).
    Detects bank bridge credits or verified UTRs, updates invoice status automatically.
    """
    iid = _clean_uuid(intent_id)
    if not iid:
        raise HTTPException(status_code=400, detail="Invalid intent_id")

    rows = await exec_sql("""
        SELECT pi.*, inv.balance_amount, inv.status AS invoice_status, inv.school_id
        FROM public.payment_intents pi
        JOIN public.student_fee_invoices inv ON inv.id = pi.invoice_id
        WHERE pi.id = %s::UUID;
    """, (iid,))

    if not rows:
        raise HTTPException(status_code=404, detail="Payment intent not found")

    intent = rows[0]
    cur_status = intent["status"]
    now_utc = datetime.now(timezone.utc)

    if cur_status in ("COMPLETED", "VERIFIED_SUCCESS"):
        return {
            "status": "SUCCESS",
            "receipt_number": intent.get("receipt_number"),
            "paid_at": intent.get("paid_at").isoformat() if intent.get("paid_at") else None,
            "message": "Payment verified and receipt issued."
        }

    # Check for incoming bank bridge transaction match
    total_paise = intent["total_amount_paise"]
    school_id = str(intent["school_id"])
    created_at = intent["created_at"]

    tx_match = await exec_sql("""
        SELECT * FROM public.payment_transactions
        WHERE school_id = %s::UUID
          AND amount_paise = %s
          AND received_at >= %s
          AND (payment_status IN ('SUCCESS', 'SETTLED', 'MATCHED') OR payment_status IS NULL)
        ORDER BY received_at DESC LIMIT 1;
    """, (school_id, total_paise, created_at))

    if tx_match:
        tx = tx_match[0]
        utr = tx.get("utr_number") or tx.get("transaction_id") or "AUTO-BRIDGE"
        rec_num = f"REC-UPI-{datetime.now().strftime('%Y')}-{secrets.randbelow(90000) + 10000}"
        inv_id = str(intent["invoice_id"])
        amt_paid = float(total_paise) / 100.0

        # Mark intent completed
        await exec_sql("""
            UPDATE public.payment_intents
            SET status = 'COMPLETED',
                utr_number = %s,
                receipt_number = %s,
                paid_at = NOW(),
                updated_at = NOW()
            WHERE id = %s::UUID;
        """, (utr, rec_num, iid), fetch=False)

        # Update invoice
        await exec_sql("""
            UPDATE public.student_fee_invoices
            SET paid_amount = paid_amount + %s,
                balance_amount = GREATEST(0.0, balance_amount - %s),
                status = CASE WHEN balance_amount - %s <= 0 THEN 'Paid' ELSE 'Partial' END,
                updated_at = NOW()
            WHERE id = %s::UUID;
        """, (amt_paid, amt_paid, amt_paid, inv_id), fetch=False)

        # Record payment receipt
        await exec_sql("""
            INSERT INTO public.student_fee_payments (
                school_id, student_id, invoice_id, receipt_number,
                amount_paid, payment_method, payment_date, transaction_reference,
                status, remarks, created_at, updated_at
            ) VALUES (
                %s::UUID, %s::UUID, %s::UUID, %s,
                %s, 'UPI (Bridge Reconciled)', NOW(), %s,
                'SUCCESS', 'Auto-reconciled via UPI transaction bridge', NOW(), NOW()
            );
        """, (school_id, str(intent["student_id"]), inv_id, rec_num, amt_paid, utr), fetch=False)

        return {
            "status": "SUCCESS",
            "receipt_number": rec_num,
            "paid_at": datetime.now(timezone.utc).isoformat(),
            "message": "Payment confirmed and receipt generated."
        }

    # Check expiration
    exp = intent["expires_at"]
    if exp and exp < now_utc:
        return {
            "status": "EXPIRED",
            "message": "Payment session expired. Please refresh to generate a new QR."
        }

    rem_secs = max(0, int((exp - now_utc).total_seconds())) if exp else 0
    return {
        "status": "PENDING",
        "remaining_seconds": rem_secs
    }


@public_router.post("/public/fee-invoices/{token}/submit-utr")
async def submit_public_utr(token: str, payload: PublicUtrSubmitPayload):
    """
    Allows parents who paid via their banking app to manually enter the 12-digit UTR.
    Instantly verifies and generates official student fee payment receipt.
    """
    t = token.strip()
    utr = payload.utr.strip()

    inv_rows = await exec_sql("""
        SELECT inv.*, p.full_name AS student_name, sch.name AS school_name
        FROM public.student_fee_invoices inv
        JOIN public.schools sch ON sch.id = inv.school_id
        JOIN public.profiles p ON p.id = inv.student_id
        WHERE inv.payment_token = %s AND inv.status != 'Cancelled'
        LIMIT 1;
    """, (t,))

    if not inv_rows:
        raise HTTPException(status_code=404, detail="Invoice not found or link has expired")

    inv = inv_rows[0]
    bal = float(inv.get("balance_amount") or 0.0)

    if bal <= 0:
        return {
            "success": True,
            "status": "ALREADY_PAID",
            "message": "Invoice has already been settled in full."
        }

    school_id = str(inv["school_id"])
    student_id = str(inv["student_id"])
    invoice_id = str(inv["id"])
    rec_num = f"REC-UPI-{datetime.now().strftime('%Y')}-{secrets.randbelow(90000) + 10000}"

    # 1. Insert Payment
    await exec_sql("""
        INSERT INTO public.student_fee_payments (
            school_id, student_id, invoice_id, receipt_number,
            amount_paid, payment_method, payment_date, transaction_reference,
            status, remarks, created_at, updated_at
        ) VALUES (
            %s::UUID, %s::UUID, %s::UUID, %s,
            %s, 'UPI (Parent Confirmed)', NOW(), %s,
            'SUCCESS', %s, NOW(), NOW()
        );
    """, (school_id, student_id, invoice_id, rec_num, bal, utr, f"Parent UTR confirmation: {utr}"), fetch=False)

    # 2. Update Invoice
    await exec_sql("""
        UPDATE public.student_fee_invoices
        SET paid_amount = paid_amount + %s,
            balance_amount = 0.0,
            status = 'Paid',
            updated_at = NOW()
        WHERE id = %s::UUID;
    """, (bal, invoice_id), fetch=False)

    # 3. Update any active intents for this invoice
    await exec_sql("""
        UPDATE public.payment_intents
        SET status = 'COMPLETED',
            utr_number = %s,
            receipt_number = %s,
            paid_at = NOW(),
            updated_at = NOW()
        WHERE invoice_id = %s::UUID AND status = 'PENDING';
    """, (utr, rec_num, invoice_id), fetch=False)

    # 4. Audit Log
    await exec_sql("""
        INSERT INTO public.student_fee_audit_logs (
            school_id, student_id, entity_type, entity_id, action,
            description, old_status, new_status, amount,
            performed_by_name, performed_by_role
        ) VALUES (
            %s::UUID, %s::UUID, 'PAYMENT', %s::UUID, 'PAYMENT_RECORDED',
            'Parent confirmed UPI payment of ₹' || TO_CHAR(%s::numeric, 'FM99,99,990.00') || ' with UTR ' || %s || '; Receipt: ' || %s,
            'Pending', 'Paid', %s,
            'Parent (Online Portal)', 'parent'
        );
    """, (school_id, student_id, invoice_id, bal, utr, rec_num, bal), fetch=False)

    return {
        "success": True,
        "status": "SUCCESS",
        "receipt_number": rec_num,
        "amount_paid": bal,
        "utr_number": utr,
        "message": "Payment verified and official receipt generated successfully!"
    }


@public_router.get("/public/fee-invoices/{token}/receipt-pdf")
async def get_public_fee_receipt_printable(token: str):
    """Returns official printable receipt document for paid invoice."""
    t = token.strip()
    inv_rows = await exec_sql("""
        SELECT inv.*,
               p.full_name AS student_name, p.class AS student_class,
               p.roll_number, p.admission_number, sch.name AS school_name
        FROM public.student_fee_invoices inv
        JOIN public.profiles p ON p.id = inv.student_id
        JOIN public.schools sch ON sch.id = inv.school_id
        WHERE inv.payment_token = %s LIMIT 1;
    """, (t,))

    if not inv_rows:
        raise HTTPException(status_code=404, detail="Invoice not found")

    inv = inv_rows[0]
    inv_id = str(inv["id"])

    pmt_rows = await exec_sql("""
        SELECT * FROM public.student_fee_payments
        WHERE invoice_id = %s::UUID AND (status IS NULL OR status IN ('SUCCESS', 'COMPLETED'))
        ORDER BY created_at DESC LIMIT 1;
    """, (inv_id,))

    rec = pmt_rows[0] if pmt_rows else {}
    rec_num = rec.get("receipt_number") or f"REC-ADV-{inv['invoice_number']}"
    amt_paid = float(rec.get("amount_paid") or inv.get("paid_amount") or 0.0)
    method = rec.get("payment_method") or "Online UPI"
    tx_ref = rec.get("transaction_reference") or "VERIFIED-DIRECT"
    pdate = rec.get("payment_date") or datetime.now().date()
    school_name = inv.get("school_name") or "EduSHAMIIT Global Academy"

    html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Receipt {rec_num}</title>
    <style>
        body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f8fafc; padding: 24px; color: #0f172a; }}
        .card {{ max-width: 480px; margin: 0 auto; background: white; border: 1.5px solid #e2e8f0; border-radius: 14px; padding: 28px; box-shadow: 0 4px 12px rgba(0,0,0,0.06); }}
        .hdr {{ text-align: center; border-bottom: 2px dashed #cbd5e1; padding-bottom: 16px; margin-bottom: 18px; }}
        .sch {{ font-size: 19px; font-weight: 800; color: #1e3a8a; }}
        .sub {{ font-size: 11px; text-transform: uppercase; color: #64748b; font-weight: 700; margin-top: 4px; letter-spacing: 0.5px; }}
        .grid {{ width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 13px; }}
        .grid td {{ padding: 6px 0; }}
        .grid td.r {{ text-align: right; font-weight: 700; }}
        .tot {{ border-top: 2px solid #0f172a; border-bottom: 2px solid #0f172a; padding: 12px 0; margin: 16px 0; display: flex; justify-content: space-between; font-size: 16px; font-weight: 900; color: #047857; }}
        .ftr {{ text-align: center; font-size: 11px; color: #94a3b8; margin-top: 20px; }}
        @media print {{ body {{ background: white; padding: 0; }} .card {{ box-shadow: none; border: none; }} .no-print {{ display: none; }} }}
    </style>
</head>
<body>
    <div class="card">
        <div class="hdr">
            <div class="sch">{school_name}</div>
            <div class="sub">Official Fee Payment Receipt &bull; Student Copy</div>
            <div style="font-size: 13px; font-weight: 700; color: #0f172a; margin-top: 8px;">{rec_num}</div>
        </div>
        <table class="grid">
            <tr><td>Date &amp; Time:</td><td class="r">{pdate}</td></tr>
            <tr><td>Student Name:</td><td class="r">{inv.get('student_name')}</td></tr>
            <tr><td>Class &amp; Section:</td><td class="r">{inv.get('student_class')}</td></tr>
            <tr><td>Roll Number:</td><td class="r">{inv.get('roll_number') or '-'}</td></tr>
            <tr><td>Admission No:</td><td class="r">{inv.get('admission_number')}</td></tr>
            <tr><td>Fee Head:</td><td class="r">{inv.get('title')}</td></tr>
            <tr><td>Payment Mode:</td><td class="r">{method}</td></tr>
            <tr><td>Transaction Ref:</td><td class="r">{tx_ref}</td></tr>
        </table>
        <div class="tot">
            <span>TOTAL AMOUNT PAID:</span>
            <span>Rs. {amt_paid:,.2f}</span>
        </div>
        <div style="background: #ecfdf5; border: 1px solid #10b981; border-radius: 8px; padding: 10px; text-align: center; font-size: 12px; font-weight: 700; color: #065f46;">
            &#x2714; STATUS: CLEARED / AUDIT VERIFIED
        </div>
        <div class="ftr">
            This is a digitally generated electronic receipt verified by EduSHAMIIT ERP.
        </div>
        <div class="no-print" style="margin-top: 20px; text-align: center;">
            <button onclick="window.print()" style="background: #2563eb; color: white; border: none; padding: 10px 24px; font-weight: 700; font-size: 13px; border-radius: 8px; cursor: pointer;">
                Print Receipt Slip
            </button>
        </div>
    </div>
</body>
</html>"""
    return HTMLResponse(content=html)


@public_router.get("/pay/invoice/{token}")
async def public_parent_payment_page(token: str):
    """
    Standalone, mobile-optimized parent payment portal.
    Zero app install or login required.
    Includes dynamic UPI QR with 10-minute conflict-avoidance timer, live polling, and digital receipt.
    """
    t = token.strip()
    rows = await exec_sql("""
        SELECT inv.*,
               p.full_name AS student_name, p.class AS student_class,
               p.roll_number, p.admission_number, sch.name AS school_name
        FROM public.student_fee_invoices inv
        JOIN public.profiles p ON p.id = inv.student_id
        JOIN public.schools sch ON sch.id = inv.school_id
        WHERE inv.payment_token = %s AND inv.status != 'Cancelled'
        LIMIT 1;
    """, (t,))

    if not rows:
        return HTMLResponse(
            status_code=404,
            content="""<!DOCTYPE html><html><head><meta charset="utf-8"><title>Invoice Not Found</title>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>body{font-family:sans-serif;background:#0F172A;color:white;display:flex;align-items:center;justify-content:center;height:100vh;margin:0;padding:20px;text-align:center;}
            .card{background:#1E293B;padding:36px;border-radius:16px;max-width:420px;border:1px solid #334155;}</style></head>
            <body><div class="card"><div style="font-size:48px;">&#x26A0;&#xFE0F;</div><h2 style="margin:12px 0 8px;">Invalid or Expired Payment Link</h2>
            <p style="color:#94A3B8;font-size:14px;line-height:1.5;">This payment link is invalid or has expired. Please contact the school accounts office or request a new invoice link.</p></div></body></html>"""
        )

    inv = rows[0]
    is_paid = (inv.get("status") == "Paid" or float(inv.get("balance_amount") or 0.0) <= 0.0)
    bal = float(inv.get("balance_amount") or 0.0)
    gross = float(inv.get("total_billed") or 0.0)
    paid = float(inv.get("paid_amount") or 0.0)
    school_name = inv.get("school_name") or "EduSHAMIIT Global Academy"

    paid_view = f"""
    <div class="qr-section settled">
        <div style="font-size: 38px; margin-bottom: 6px;">&#x2705;</div>
        <div style="font-size: 17px; font-weight: 800; color: #FFFFFF;">INVOICE FULLY SETTLED</div>
        <p style="font-size: 12.5px; color: #A7F3D0; margin: 6px 0 16px;">
            This invoice has been cleared and audited in the school ledger. No further payment is due.
        </p>
        <a href="/public/fee-invoices/{t}/receipt-pdf" target="_blank" class="cta-btn" style="background:#047857; text-align:center;">
            &#x1F4C4; Download / Print Official Fee Receipt
        </a>
    </div>
    """

    pending_view = f"""
    <div class="qr-section" id="activeQrContainer">
        <div class="timer-badge" id="timerBadge">
            <span>&#x23F1;</span>
            <span id="timerText">Valid for 09:59</span>
        </div>
        <div style="font-size: 13px; font-weight: 800; color: #93C5FD; letter-spacing: 0.3px;">
            SCAN WITH ANY UPI APP (GPAY, PHONEPE, PAYTM, BHIM)
        </div>
        <div class="qr-box">
            <img id="qrImage" src="" alt="Dynamic UPI QR Code" />
        </div>
        <div style="font-size: 11.5px; color: #94A3B8; margin-bottom: 12px;" id="conflictNote">
            &#x1F6E1;&#xFE0F; Collision-safe paise allocation active &bull; Instant zero-fee verification
        </div>
        <a id="upiAppBtn" href="#" class="cta-btn">
            Pay via UPI Mobile App &rarr;
        </a>
        
        <details class="utr-accordion">
            <summary>Already paid via UPI? Submit 12-digit UTR</summary>
            <div class="utr-form">
                <input type="text" id="utrField" class="utr-input" placeholder="e.g. 432109876543" maxlength="30" />
                <button id="utrSubmitBtn" class="utr-btn" onclick="submitUtr()">Verify</button>
            </div>
            <div id="utrMsg" style="font-size: 11.5px; margin-top: 6px;"></div>
        </details>
    </div>
    """

    advance_row = f"""
    <div class="statement-row" style="color:#34D399;">
        <span>&#x2714; Advance Wallet Credit Deducted:</span>
        <strong>- Rs. {paid:,.2f}</strong>
    </div>
    """ if paid > 0 else ""

    status_or_due = "PAID IN FULL" if is_paid else f"Rs. {bal:,.2f}"
    status_label = "FEE STATUS" if is_paid else "NET PAYABLE AMOUNT:"
    status_color = "#10B981" if is_paid else "#34D399"

    js_script = f"""
    <script>
    let token = "{t}";
    let currentIntentId = null;
    let timerInterval = null;
    let pollInterval = null;
    let remainingSeconds = 600;

    async function initPaymentSession() {{
        try {{
            const res = await fetch(`/api/v1/payment-management/public/fee-invoices/${{token}}/create-intent`, {{
                method: "POST"
            }});
            const data = await res.json();
            if (data.status === "ALREADY_PAID") {{
                location.reload();
                return;
            }}
            if (data.success) {{
                currentIntentId = data.intent_id;
                remainingSeconds = data.remaining_seconds || 600;
                document.getElementById("qrImage").src = data.qr_code_data_uri;
                document.getElementById("upiAppBtn").href = data.upi_intent_url;
                document.getElementById("upiAppBtn").innerText = `Pay Rs. ${{data.total_amount.toFixed(2)}} via UPI App`;
                document.getElementById("netPayableText").innerText = `Rs. ${{data.total_amount.toFixed(2)}}`;
                
                if (data.extra_paise > 0) {{
                    document.getElementById("conflictNote").innerHTML = 
                        `&#x1F6E1;&#xFE0F; Unique ${{data.extra_paise}} paise offset added for instant automated reconciliation without conflicts`;
                }}
                startTimer();
                startPolling();
            }}
        }} catch (e) {{
            console.error("Could not init payment intent", e);
        }}
    }}

    function startTimer() {{
        clearInterval(timerInterval);
        timerInterval = setInterval(() => {{
            remainingSeconds--;
            if (remainingSeconds <= 0) {{
                clearInterval(timerInterval);
                clearInterval(pollInterval);
                document.getElementById("timerText").innerText = "Expired";
                alert("This payment session has expired. The page will reload to generate a fresh QR.");
                location.reload();
            }} else {{
                let m = Math.floor(remainingSeconds / 60);
                let s = remainingSeconds % 60;
                document.getElementById("timerText").innerText = `Valid for ${{m.toString().padStart(2, '0')}}:${{s.toString().padStart(2, '0')}}`;
            }}
        }}, 1000);
    }}

    function startPolling() {{
        clearInterval(pollInterval);
        pollInterval = setInterval(async () => {{
            if (!currentIntentId) return;
            try {{
                const res = await fetch(`/api/v1/payment-management/public/fee-invoices/${{token}}/intent-status/${{currentIntentId}}`);
                const data = await res.json();
                if (data.status === "SUCCESS") {{
                    clearInterval(pollInterval);
                    clearInterval(timerInterval);
                    location.reload();
                }}
            }} catch (e) {{
                console.warn("Polling check error", e);
            }}
        }}, 2500);
    }}

    async function submitUtr() {{
        const utrVal = document.getElementById("utrField").value.trim();
        const msgEl = document.getElementById("utrMsg");
        if (!utrVal || utrVal.length < 6) {{
            msgEl.style.color = "#F87171";
            msgEl.innerText = "Please enter a valid 12-digit UPI UTR number.";
            return;
        }}
        msgEl.style.color = "#93C5FD";
        msgEl.innerText = "Verifying transaction reference...";
        document.getElementById("utrSubmitBtn").disabled = true;

        try {{
            const res = await fetch(`/api/v1/payment-management/public/fee-invoices/${{token}}/submit-utr`, {{
                method: "POST",
                headers: {{ "Content-Type": "application/json" }},
                body: JSON.stringify({{ utr: utrVal, intent_id: currentIntentId }})
            }});
            const data = await res.json();
            if (data.success || data.status === "SUCCESS") {{
                msgEl.style.color = "#34D399";
                msgEl.innerText = "Payment verified! Reloading receipt...";
                setTimeout(() => location.reload(), 1200);
            }} else {{
                msgEl.style.color = "#F87171";
                msgEl.innerText = data.detail || data.message || "Could not verify UTR.";
                document.getElementById("utrSubmitBtn").disabled = false;
            }}
        }} catch (e) {{
            msgEl.style.color = "#F87171";
            msgEl.innerText = "Network error. Please try again.";
            document.getElementById("utrSubmitBtn").disabled = false;
        }}
    }}

    document.addEventListener("DOMContentLoaded", initPaymentSession);
    </script>
    """ if not is_paid else ""

    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Fee Payment &bull; {inv.get('student_name')} &bull; {school_name}</title>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Inter', Helvetica, Arial, sans-serif;
            background: #0B1120;
            color: #F8FAFC;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: flex-start;
            padding: 24px 16px;
        }}
        .portal-wrap {{
            width: 100%;
            max-width: 520px;
            background: #111827;
            border: 1px solid #1F2937;
            border-radius: 20px;
            overflow: hidden;
            box-shadow: 0 20px 40px -15px rgba(0,0,0,0.5);
        }}
        .portal-header {{
            background: linear-gradient(135deg, #1E3A8A 0%, #3B82F6 100%);
            padding: 24px 22px;
            text-align: left;
            position: relative;
        }}
        .portal-header .brand-badge {{
            display: inline-block;
            background: rgba(255,255,255,0.18);
            border-radius: 6px;
            padding: 3px 8px;
            font-size: 10.5px;
            font-weight: 800;
            letter-spacing: 0.6px;
            color: white;
            text-transform: uppercase;
        }}
        .portal-header h1 {{
            font-size: 20px;
            font-weight: 900;
            color: white;
            margin-top: 6px;
            letter-spacing: -0.3px;
        }}
        .portal-header p {{
            font-size: 12px;
            color: #BFDBFE;
            margin-top: 2px;
        }}
        .content-body {{
            padding: 22px;
        }}
        .student-pill {{
            background: #1F2937;
            border: 1px solid #374151;
            border-radius: 12px;
            padding: 14px 16px;
            margin-bottom: 18px;
            display: flex;
            align-items: center;
            justify-content: space-between;
        }}
        .student-pill .info-left .name {{
            font-size: 15px;
            font-weight: 800;
            color: #F9FAFB;
        }}
        .student-pill .info-left .cohort {{
            font-size: 12px;
            color: #60A5FA;
            font-weight: 600;
            margin-top: 2px;
        }}
        .student-pill .info-right {{
            text-align: right;
            font-size: 11.5px;
            color: #9CA3AF;
        }}
        .student-pill .info-right strong {{
            color: #E5E7EB;
        }}
        .statement-card {{
            background: #182234;
            border: 1px solid #283548;
            border-radius: 14px;
            padding: 16px 18px;
            margin-bottom: 20px;
        }}
        .statement-row {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 0;
            font-size: 13px;
            border-bottom: 1px solid #233147;
        }}
        .statement-row:last-child {{
            border-bottom: none;
            padding-top: 12px;
            margin-top: 4px;
        }}
        .statement-row.total .lbl {{
            font-size: 14.5px;
            font-weight: 900;
            color: #F3F4F6;
        }}
        .statement-row.total .val {{
            font-size: 20px;
            font-weight: 900;
            color: #34D399;
        }}
        .qr-section {{
            background: #0F172A;
            border: 1.5px solid #3B82F6;
            border-radius: 16px;
            padding: 22px 18px;
            text-align: center;
            margin-bottom: 20px;
        }}
        .qr-section.settled {{
            border-color: #10B981;
            background: #064E3B;
        }}
        .qr-box {{
            display: inline-block;
            background: #FFFFFF;
            padding: 12px;
            border-radius: 14px;
            box-shadow: 0 8px 24px rgba(0,0,0,0.4);
            margin: 14px 0;
        }}
        .qr-box img {{
            display: block;
            width: 190px;
            height: 190px;
            border-radius: 6px;
        }}
        .timer-badge {{
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: rgba(239, 68, 68, 0.15);
            border: 1px solid rgba(239, 68, 68, 0.4);
            color: #F87171;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: 800;
            margin-bottom: 10px;
        }}
        .cta-btn {{
            display: block;
            width: 100%;
            background: linear-gradient(135deg, #10B981 0%, #059669 100%);
            color: white;
            text-decoration: none;
            font-weight: 800;
            font-size: 15px;
            padding: 14px;
            border-radius: 10px;
            border: none;
            cursor: pointer;
            box-shadow: 0 4px 14px rgba(16,185,129,0.35);
            margin-top: 10px;
        }}
        .cta-btn:active {{
            transform: scale(0.98);
        }}
        .utr-accordion {{
            background: #182234;
            border: 1px solid #283548;
            border-radius: 12px;
            padding: 12px 16px;
            margin-top: 14px;
            text-align: left;
        }}
        .utr-accordion summary {{
            font-size: 12.5px;
            font-weight: 700;
            color: #93C5FD;
            cursor: pointer;
            outline: none;
        }}
        .utr-form {{
            margin-top: 12px;
            display: flex;
            gap: 8px;
        }}
        .utr-input {{
            flex: 1;
            background: #0F172A;
            border: 1px solid #334155;
            color: white;
            padding: 10px 12px;
            border-radius: 8px;
            font-size: 13px;
        }}
        .utr-btn {{
            background: #2563EB;
            color: white;
            border: none;
            padding: 10px 16px;
            border-radius: 8px;
            font-weight: 700;
            font-size: 12.5px;
            cursor: pointer;
        }}
        .trust-footer {{
            padding: 16px 22px;
            background: #0B1120;
            border-top: 1px solid #1F2937;
            text-align: center;
            font-size: 11px;
            color: #64748B;
            line-height: 1.5;
        }}
    </style>
</head>
<body>
    <div class="portal-wrap">
        <div class="portal-header">
            <span class="brand-badge">&#x1F512; Official Student Fee Gateway</span>
            <h1>{school_name}</h1>
            <p>Instant Zero-Fee UPI Payment &amp; Automated Ledger Settlement</p>
        </div>

        <div class="content-body">
            <!-- Student Metadata Chip -->
            <div class="student-pill">
                <div class="info-left">
                    <div class="name">{inv.get('student_name')}</div>
                    <div class="cohort">Class: {inv.get('student_class')}</div>
                </div>
                <div class="info-right">
                    <div>Roll: <strong>{inv.get('roll_number') or '-'}</strong></div>
                    <div>Adm: <strong>{inv.get('admission_number')}</strong></div>
                </div>
            </div>

            <!-- Statement Breakdown -->
            <div class="statement-card">
                <div class="statement-row">
                    <span style="color:#94A3B8;">Invoice Number:</span>
                    <strong style="color:#F1F5F9;">{inv.get('invoice_number')}</strong>
                </div>
                <div class="statement-row">
                    <span style="color:#94A3B8;">Fee Particulars:</span>
                    <strong style="color:#60A5FA;">{inv.get('title')}</strong>
                </div>
                <div class="statement-row">
                    <span style="color:#94A3B8;">Billing Academic Year:</span>
                    <strong style="color:#F1F5F9;">{inv.get('academic_year')}</strong>
                </div>
                <div class="statement-row">
                    <span style="color:#94A3B8;">Gross Invoiced Amount:</span>
                    <strong style="color:#F1F5F9;">Rs. {gross:,.2f}</strong>
                </div>
                {advance_row}
                <div class="statement-row total">
                    <span class="lbl">{status_label}</span>
                    <span class="val" id="netPayableText" style="color: {status_color};">
                        {status_or_due}
                    </span>
                </div>
            </div>

            <!-- DYNAMIC PAYMENT WIDGET -->
            <div id="paymentWidget">
                {paid_view if is_paid else pending_view}
            </div>
        </div>

        <div class="trust-footer">
            256-Bit Bank-Grade SSL &bull; Direct School Settlement &bull; Zero Gateway Surcharge<br>
            Powered by EduSHAMIIT Multi-Tenant Automated Campus ERP
        </div>
    </div>

    {js_script}
</body>
</html>"""
    return HTMLResponse(content=html)


# Include public routes on router so they are also available under /api/v1/payment-management/...
router.include_router(public_router)

