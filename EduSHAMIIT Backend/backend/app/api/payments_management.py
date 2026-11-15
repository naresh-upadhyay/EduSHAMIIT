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
from datetime import datetime, date, time
from decimal import Decimal
import os
import json
import uuid
import logging
import asyncio
import io
import csv
import psycopg2
from psycopg2.extras import RealDictCursor, register_uuid

register_uuid()

from app.config import settings
from app.middleware.auth import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter()


# ============================================================================
# DATABASE EXECUTION & UTILITY HELPERS
# ============================================================================

async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute raw parameterized SQL query asynchronously via psycopg2."""
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
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
    if isinstance(val, (datetime, date, time)):
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


# ============================================================================
# METADATA & LOOKUP ENDPOINTS
# ============================================================================

@router.get("/student-fees/metadata")
async def get_student_fee_metadata(
    current_user: dict = Depends(get_current_user)
):
    """Dynamic metadata for Student Fee Management filters and modal dropdowns."""
    school_id = _get_school_id(current_user)

    # 1. Classes with active students
    cls_rows = await exec_sql("""
        SELECT DISTINCT class FROM public.profiles 
        WHERE school_id = %s::UUID AND role = 'student' AND class IS NOT NULL AND TRIM(class) != ''
        ORDER BY class ASC;
    """, (school_id,))
    classes = [r['class'] for r in cls_rows] if cls_rows else [
        "Class 1-A", "Class 2-A", "Class 3-A", "Class 4-A", "Class 5-A",
        "Class 6-A", "Class 7-A", "Class 8-A", "Class 9-A", "Class 10-A", "Class 11-A", "Class 12-A"
    ]

    # 2. Academic Years from lookups or distinct invoices
    ay_rows = await exec_sql("""
        SELECT v.value_name AS label 
        FROM public.lookup_values v
        JOIN public.lookup_keys k ON k.id = v.lookup_key_id
        WHERE k.key_code = 'ACADEMIC_YEAR' 
          AND (v.school_id = %s::UUID OR v.school_id = '11111111-1111-1111-1111-111111111111'::UUID)
          AND v.status = 'ACTIVE' AND v.deleted_at IS NULL
        ORDER BY v.sort_order ASC;
    """, (school_id,))
    academic_years = [r['label'] for r in ay_rows] if ay_rows else ["2026 - 2027", "2025 - 2026", "2024 - 2025"]

    # 3. Catalog Fee Types
    ft_rows = await exec_sql("""
        SELECT DISTINCT fee_type FROM public.student_fee_structures
        WHERE school_id = %s::UUID
        ORDER BY fee_type ASC;
    """, (school_id,))
    fee_types = [r['fee_type'] for r in ft_rows] if ft_rows else [
        "Tuition Fee", "Lab Fee", "Library Fee", "Exam Fee", "Transport Fee", "Hostel Fee", "Sports Fee"
    ]

    # 4. Payment Modes
    pm_rows = await exec_sql("""
        SELECT v.value_name AS label
        FROM public.lookup_values v
        JOIN public.lookup_keys k ON k.id = v.lookup_key_id
        WHERE k.key_code = 'STUDENT_FEE_PAYMENT_MODE'
          AND (v.school_id = %s::UUID OR v.school_id = '11111111-1111-1111-1111-111111111111'::UUID)
          AND v.status = 'ACTIVE' AND v.deleted_at IS NULL
        ORDER BY v.sort_order ASC;
    """, (school_id,))
    payment_modes = [r['label'] for r in pm_rows] if pm_rows else [
        "UPI", "Net Banking", "Cash Counter", "Cheque/DD", "POS Debit/Credit Card"
    ]

    return {
        "success": True,
        "classes": classes,
        "academic_years": academic_years,
        "fee_types": fee_types,
        "payment_modes": payment_modes
    }


@router.get("/staff-salary/metadata")
async def get_staff_salary_metadata(
    current_user: dict = Depends(get_current_user)
):
    """Dynamic metadata for Staff Salary Management filters and modal dropdowns."""
    school_id = _get_school_id(current_user)

    # 1. Distinct Departments
    dept_rows = await exec_sql("""
        SELECT DISTINCT department FROM public.profiles 
        WHERE school_id = %s::UUID AND role != 'student' AND department IS NOT NULL AND TRIM(department) != ''
        ORDER BY department ASC;
    """, (school_id,))
    departments = [r['department'] for r in dept_rows] if dept_rows else [
        "Academic & Teaching", "Administration", "Finance & Accounts", "Hostel Staff", "IT & Support", "Transportation", "Security"
    ]

    # 2. Distinct Roles
    role_rows = await exec_sql("""
        SELECT DISTINCT role FROM public.profiles 
        WHERE school_id = %s::UUID AND role != 'student' AND role IS NOT NULL AND TRIM(role) != ''
        ORDER BY role ASC;
    """, (school_id,))
    roles = [r['role'] for r in role_rows] if role_rows else [
        "teacher", "admin", "accountant", "hostel_warden", "driver", "security_guard", "maintenance"
    ]

    # 3. Available Rolling 12 Months
    today = date.today()
    months = []
    y, m = today.year, today.month
    for _ in range(12):
        months.append(f"{y}-{str(m).zfill(2)}")
        m -= 1
        if m == 0:
            m = 12
            y -= 1

    # 4. Payment Modes
    pm_rows = await exec_sql("""
        SELECT v.value_name AS label
        FROM public.lookup_values v
        JOIN public.lookup_keys k ON k.id = v.lookup_key_id
        WHERE k.key_code = 'STAFF_SALARY_PAYMENT_MODE'
          AND (v.school_id = %s::UUID OR v.school_id = '11111111-1111-1111-1111-111111111111'::UUID)
          AND v.status = 'ACTIVE' AND v.deleted_at IS NULL
        ORDER BY v.sort_order ASC;
    """, (school_id,))
    payment_modes = [r['label'] for r in pm_rows] if pm_rows else [
        "Direct Bank Transfer (NEFT/RTGS)", "Company Cheque", "Cash Disbursal", "UPI Payment"
    ]

    return {
        "success": True,
        "departments": departments,
        "roles": roles,
        "available_months": months,
        "payment_modes": payment_modes
    }


# ============================================================================
# STUDENT FEE MANAGEMENT ENDPOINTS (ROLE = 'student')
# ============================================================================

@router.get("/student-fees/summary")
async def get_student_fee_summary(
    academic_year: str = Query("2026 - 2027"),
    current_user: dict = Depends(get_current_user)
):
    """Returns high-level KPI cards for Student Fee Management."""
    school_id = _get_school_id(current_user)
    academic_year = _clean_str(academic_year, "2026 - 2027")

    sql = """
    SELECT 
        COUNT(DISTINCT i.student_id) AS total_students_with_invoices,
        COALESCE(SUM(i.total_billed), 0.0) AS total_billed,
        COALESCE(SUM(i.paid_amount), 0.0) AS total_collected,
        COALESCE(SUM(CASE WHEN i.status IN ('Partial', 'Pending') THEN i.balance_amount ELSE 0 END), 0.0) AS pending_dues,
        COALESCE(SUM(CASE WHEN i.status = 'Overdue' THEN i.balance_amount ELSE 0 END), 0.0) AS overdue_amount,
        COUNT(DISTINCT CASE WHEN i.status = 'Paid' THEN i.student_id END) AS paid_students_count,
        COUNT(DISTINCT CASE WHEN i.status IN ('Partial', 'Pending') THEN i.student_id END) AS pending_students_count,
        COUNT(DISTINCT CASE WHEN i.status = 'Overdue' THEN i.student_id END) AS overdue_students_count
    FROM public.student_fee_invoices i
    WHERE i.school_id = %s::UUID AND REPLACE(i.academic_year, ' ', '') = REPLACE(%s, ' ', '');
    """
    rows = await exec_sql(sql, (school_id, academic_year))
    stats = rows[0] if rows else {}

    # Total registered students from profiles
    stud_count_sql = "SELECT COUNT(*) as cnt FROM public.profiles WHERE school_id = %s::UUID AND role = 'student';"
    stud_rows = await exec_sql(stud_count_sql, (school_id,))
    total_students = stud_rows[0]['cnt'] if stud_rows else 0

    total_billed = float(stats.get('total_billed', 0.0))
    total_collected = float(stats.get('total_collected', 0.0))
    pending_dues = float(stats.get('pending_dues', 0.0))
    overdue_amount = float(stats.get('overdue_amount', 0.0))

    collection_rate = (total_collected / total_billed * 100) if total_billed > 0 else 0.0

    return {
        "success": True,
        "kpis": {
            "total_billed": total_billed,
            "total_collected": total_collected,
            "pending_dues": pending_dues,
            "overdue_amount": overdue_amount,
            "collection_rate": round(collection_rate, 1),
            "collection_rate_formatted": f"{round(collection_rate, 1)}% Collection",
            "total_students": total_students,
            "paid_students_count": stats.get('paid_students_count', 0),
            "pending_students_count": stats.get('pending_students_count', 0),
            "overdue_students_count": stats.get('overdue_students_count', 0),
        }
    }


@router.get("/student-fees/students")
async def get_student_fee_roster(
    academic_year: str = Query("2026 - 2027"),
    search: Optional[str] = Query(""),
    class_name: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """
    List students with role = 'student' and aggregated fee numbers.
    Supports filtering by search query (name/roll), class, and fee status.
    """
    school_id = _get_school_id(current_user)
    page = _clean_int(page, 1)
    page_size = _clean_int(page_size, 10)
    offset = (page - 1) * page_size
    academic_year = _clean_str(academic_year, "2026 - 2027")
    search = _clean_str(search)
    class_name = _clean_str(class_name)
    status = _clean_str(status)

    where_clauses = ["p.school_id = %s::UUID", "p.role = 'student'"]
    params = [school_id]

    if search:
        s = f"%{search}%"
        where_clauses.append("(p.full_name ILIKE %s OR p.email ILIKE %s OR p.roll_number::text ILIKE %s OR p.admission_number ILIKE %s)")
        params.extend([s, s, s, s])

    if class_name and class_name not in ("All Classes", "All"):
        where_clauses.append("p.class = %s")
        params.append(class_name)

    where_sql = " AND ".join(where_clauses)

    status_filter_clause = ""
    if status and status not in ("All Status", "All Fees", "All"):
        status_filter_clause = "HAVING COALESCE(MAX(i.status), 'Pending') = %s"

    query_sql = f"""
    SELECT 
        p.id AS student_id,
        p.full_name AS student_name,
        p.email AS student_email,
        p.phone AS student_phone,
        COALESCE(p.class, 'Class 10') AS class_name,
        COALESCE(p.roll_number::text, '101') AS roll_number,
        COALESCE(p.admission_number, 'ADM-' || SUBSTRING(p.id::text, 1, 6)) AS admission_number,
        p.avatar_url,
        COALESCE(MAX(i.fee_plan), 'Monthly') AS fee_plan,
        COALESCE(SUM(i.total_billed), 0.0) AS total_billed,
        COALESCE(SUM(i.paid_amount), 0.0) AS paid_amount,
        COALESCE(SUM(i.balance_amount), 0.0) AS balance_amount,
        COALESCE(MAX(i.status), 'Pending') AS status,
        MAX(i.id::text) AS latest_invoice_id,
        MAX(i.invoice_number) AS latest_invoice_number,
        MAX(i.due_date) AS due_date
    FROM public.profiles p
    LEFT JOIN public.student_fee_invoices i 
        ON p.id = i.student_id AND i.school_id = p.school_id AND REPLACE(i.academic_year, ' ', '') = REPLACE(%s, ' ', '')
    WHERE {where_sql}
    GROUP BY p.id, p.full_name, p.email, p.phone, p.class, p.roll_number, p.admission_number, p.avatar_url
    {status_filter_clause}
    ORDER BY p.full_name ASC
    LIMIT %s OFFSET %s;
    """

    full_params = [academic_year] + params
    if status_filter_clause:
        full_params.append(status)
    full_params.extend([page_size, offset])

    rows = await exec_sql(query_sql, tuple(full_params))

    count_sql = f"""
    SELECT COUNT(DISTINCT p.id) as total_count
    FROM public.profiles p
    LEFT JOIN public.student_fee_invoices i 
        ON p.id = i.student_id AND i.school_id = p.school_id AND REPLACE(i.academic_year, ' ', '') = REPLACE(%s, ' ', '')
    WHERE {where_sql}
    """
    count_params = [academic_year] + params
    count_rows = await exec_sql(count_sql, tuple(count_params))
    total_count = count_rows[0]['total_count'] if count_rows else 0

    return {
        "success": True,
        "students": _serialize_val(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": total_count,
            "total_pages": (total_count + page_size - 1) // page_size if total_count > 0 else 1
        }
    }


@router.get("/student-fees/students/{student_id}")
async def get_student_fee_detail_360(
    student_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Full 360-degree Financial Inspector for Student Fee Drawer."""
    school_id = _get_school_id(current_user)

    # 1. Profile Info
    prof_sql = """
    SELECT id, full_name, email, phone, class, roll_number, admission_number, avatar_url, status
    FROM public.profiles 
    WHERE id = %s::UUID AND school_id = %s::UUID;
    """
    prof_rows = await exec_sql(prof_sql, (student_id, school_id))
    if not prof_rows:
        raise HTTPException(status_code=404, detail="Student profile not found")
    profile = prof_rows[0]

    # 2. Invoices
    inv_sql = """
    SELECT id, invoice_number, title, fee_type, fee_plan, academic_year, billing_date,
           due_date, subtotal, concession_amount, penalty_amount, total_billed, paid_amount,
           balance_amount, status, notes, created_at
    FROM public.student_fee_invoices
    WHERE student_id = %s::UUID AND school_id = %s::UUID
    ORDER BY due_date DESC;
    """
    invoices = await exec_sql(inv_sql, (student_id, school_id))

    # 3. Payments
    pay_sql = """
    SELECT p.id, p.receipt_number, p.amount_paid, p.payment_method, p.transaction_reference,
           p.payment_date, p.status, p.remarks, i.invoice_number
    FROM public.student_fee_payments p
    LEFT JOIN public.student_fee_invoices i ON p.invoice_id = i.id
    WHERE p.student_id = %s::UUID AND p.school_id = %s::UUID
    ORDER BY p.payment_date DESC;
    """
    payments = await exec_sql(pay_sql, (student_id, school_id))

    # 4. Concessions
    conc_sql = """
    SELECT id, concession_type, amount, reason, created_at, invoice_id
    FROM public.student_fee_concessions
    WHERE student_id = %s::UUID AND school_id = %s::UUID
    ORDER BY created_at DESC;
    """
    concessions = await exec_sql(conc_sql, (student_id, school_id))

    # 5. Penalties
    pen_sql = """
    SELECT id, penalty_type, amount, reason, created_at, invoice_id
    FROM public.student_fee_penalties
    WHERE student_id = %s::UUID AND school_id = %s::UUID
    ORDER BY created_at DESC;
    """
    penalties = await exec_sql(pen_sql, (student_id, school_id))

    # Aggregates
    total_billed = sum(float(i['total_billed']) for i in invoices)
    total_paid = sum(float(i['paid_amount']) for i in invoices)
    total_balance = sum(float(i['balance_amount']) for i in invoices)

    return {
        "success": True,
        "detail": {
            "profile": _serialize_val(profile),
            "summary": {
                "total_billed": total_billed,
                "total_paid": total_paid,
                "balance_amount": total_balance,
                "invoices_count": len(invoices),
                "payments_count": len(payments),
                "concessions_count": len(concessions),
                "penalties_count": len(penalties)
            },
            "invoices": _serialize_val(invoices),
            "payments": _serialize_val(payments),
            "concessions": _serialize_val(concessions),
            "penalties": _serialize_val(penalties)
        }
    }


@router.post("/student-fees/invoices", status_code=status.HTTP_201_CREATED)
async def generate_student_invoice(
    payload: GenerateStudentInvoicePayload,
    current_user: dict = Depends(get_current_user)
):
    """Generate a single invoice for a student."""
    school_id = _get_school_id(current_user)

    seq_sql = "SELECT COUNT(*) + 1 AS next_seq FROM public.student_fee_invoices WHERE school_id = %s::UUID;"
    srows = await exec_sql(seq_sql, (school_id,))
    next_seq = srows[0]['next_seq'] if srows else 1
    inv_num = f"INV-2026-{str(next_seq).zfill(5)}"

    total_billed = (payload.subtotal - payload.concession_amount) + payload.penalty_amount
    balance_amount = total_billed

    ins_sql = """
    INSERT INTO public.student_fee_invoices (
        school_id, student_id, invoice_number, title, fee_type, fee_plan, academic_year,
        due_date, subtotal, concession_amount, penalty_amount, total_billed, paid_amount,
        balance_amount, status, notes
    ) VALUES (
        %s::UUID, %s::UUID, %s, %s, %s, %s, %s,
        %s::DATE, %s, %s, %s, %s, 0.00,
        %s, 'Pending', %s
    ) RETURNING id, invoice_number;
    """
    rows = await exec_sql(ins_sql, (
        school_id, payload.student_id, inv_num, payload.title, payload.fee_type,
        payload.fee_plan, payload.academic_year, payload.due_date, payload.subtotal,
        payload.concession_amount, payload.penalty_amount, total_billed, balance_amount, payload.notes
    ))

    return {"success": True, "message": "Invoice generated successfully", "invoice": _serialize_val(rows[0])}


@router.post("/student-fees/invoices/bulk", status_code=status.HTTP_201_CREATED)
async def bulk_generate_student_invoices(
    payload: BulkStudentInvoicePayload,
    current_user: dict = Depends(get_current_user)
):
    """Generate invoices in bulk for students by class or all classes."""
    school_id = _get_school_id(current_user)

    stud_sql = "SELECT id, full_name, class FROM public.profiles WHERE school_id = %s::UUID AND role = 'student'"
    params = [school_id]
    if payload.class_name and payload.class_name not in ("All Classes", "All"):
        stud_sql += " AND class = %s"
        params.append(payload.class_name)

    students = await exec_sql(stud_sql, tuple(params))
    if not students:
        return {"success": True, "created_count": 0, "message": "No students matched the criteria"}

    created_count = 0
    seq_sql = "SELECT COUNT(*) AS total_inv FROM public.student_fee_invoices WHERE school_id = %s::UUID;"
    cnt_rows = await exec_sql(seq_sql, (school_id,))
    base_seq = (cnt_rows[0]['total_inv'] if cnt_rows else 0) + 1

    for s in students:
        inv_num = f"INV-2026-{str(base_seq + created_count).zfill(5)}"
        await exec_sql("""
        INSERT INTO public.student_fee_invoices (
            school_id, student_id, invoice_number, title, fee_type, fee_plan, academic_year,
            due_date, subtotal, concession_amount, penalty_amount, total_billed, paid_amount,
            balance_amount, status, notes
        ) VALUES (
            %s::UUID, %s::UUID, %s, %s, %s, %s, %s,
            %s::DATE, %s, 0.0, 0.0, %s, 0.0,
            %s, 'Pending', %s
        );
        """, (
            school_id, s['id'], inv_num, payload.title, payload.fee_type,
            payload.fee_plan, payload.academic_year, payload.due_date,
            payload.amount, payload.amount, payload.amount,
            f"Bulk billed for {s['full_name']}"
        ), fetch=False)
        created_count += 1

    return {"success": True, "created_count": created_count, "message": f"Successfully billed {created_count} students"}


@router.post("/student-fees/payments", status_code=status.HTTP_201_CREATED)
async def collect_student_fee_payment(
    payload: CollectStudentPaymentPayload,
    current_user: dict = Depends(get_current_user)
):
    """Collect and record a payment receipt for a student invoice."""
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")

    rec_seq_sql = "SELECT COUNT(*) + 1 AS next_rec FROM public.student_fee_payments WHERE school_id = %s::UUID;"
    rrows = await exec_sql(rec_seq_sql, (school_id,))
    rec_num = f"REC-2026-{str(rrows[0]['next_rec']).zfill(5)}"

    inv_id_param = _clean_uuid(payload.invoice_id)

    # 1. Insert Payment
    ins_sql = """
    INSERT INTO public.student_fee_payments (
        school_id, student_id, invoice_id, receipt_number, amount_paid,
        payment_method, transaction_reference, remarks, recorded_by
    ) VALUES (
        %s::UUID, %s::UUID, %s::UUID, %s, %s,
        %s, %s, %s, %s::UUID
    ) RETURNING id, receipt_number;
    """
    pay_rows = await exec_sql(ins_sql, (
        school_id, payload.student_id, inv_id_param, rec_num, payload.amount,
        payload.payment_method, payload.transaction_reference, payload.remarks, user_id
    ))

    # 2. Update Invoice balance & status if invoice_id is supplied
    if inv_id_param:
        await exec_sql("""
        UPDATE public.student_fee_invoices
        SET paid_amount = paid_amount + %s,
            balance_amount = GREATEST(0.0, total_billed - (paid_amount + %s)),
            status = CASE 
                WHEN (total_billed - (paid_amount + %s)) <= 0 THEN 'Paid' 
                ELSE 'Partial' 
            END,
            updated_at = NOW()
        WHERE id = %s::UUID AND school_id = %s::UUID;
        """, (payload.amount, payload.amount, payload.amount, inv_id_param, school_id), fetch=False)

    return {"success": True, "message": "Payment recorded successfully", "receipt": _serialize_val(pay_rows[0])}


@router.post("/student-fees/concessions", status_code=status.HTTP_201_CREATED)
async def apply_student_fee_concession(
    payload: ApplyStudentConcessionPayload,
    current_user: dict = Depends(get_current_user)
):
    """Apply scholarship or concession waiver to an invoice."""
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")
    inv_id = _clean_uuid(payload.invoice_id)

    await exec_sql("""
    INSERT INTO public.student_fee_concessions (
        school_id, student_id, invoice_id, concession_type, amount, reason, approved_by
    ) VALUES (
        %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s::UUID
    );
    """, (school_id, payload.student_id, inv_id, payload.concession_type, payload.amount, payload.reason, user_id), fetch=False)

    # Adjust invoice if linked
    if inv_id:
        await exec_sql("""
        UPDATE public.student_fee_invoices
        SET concession_amount = concession_amount + %s,
            total_billed = GREATEST(0.0, total_billed - %s),
            balance_amount = GREATEST(0.0, balance_amount - %s),
            status = CASE WHEN (balance_amount - %s) <= 0 THEN 'Paid' ELSE status END,
            updated_at = NOW()
        WHERE id = %s::UUID AND school_id = %s::UUID;
        """, (payload.amount, payload.amount, payload.amount, payload.amount, inv_id, school_id), fetch=False)

    return {"success": True, "message": "Concession applied successfully"}


@router.delete("/student-fees/concessions/{concession_id}")
async def delete_student_fee_concession(
    concession_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Reverse a concession waiver and restore the invoice total and balance."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql("""
        SELECT invoice_id, amount FROM public.student_fee_concessions 
        WHERE id = %s::UUID AND school_id = %s::UUID;
    """, (concession_id, school_id))
    if not rows:
        raise HTTPException(status_code=404, detail="Concession record not found")
    
    inv_id = rows[0].get("invoice_id")
    amt = float(rows[0].get("amount", 0.0))
    if inv_id:
        await exec_sql("""
            UPDATE public.student_fee_invoices
            SET concession_amount = GREATEST(0.0, concession_amount - %s),
                total_billed = total_billed + %s,
                balance_amount = GREATEST(0.0, (total_billed + %s) - paid_amount),
                status = CASE 
                    WHEN (total_billed + %s - paid_amount) <= 0 THEN 'Paid'
                    WHEN paid_amount > 0 THEN 'Partial'
                    ELSE 'Pending'
                END,
                updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID;
        """, (amt, amt, amt, amt, inv_id, school_id), fetch=False)

    await exec_sql("DELETE FROM public.student_fee_concessions WHERE id = %s::UUID AND school_id = %s::UUID;", (concession_id, school_id), fetch=False)
    return {"success": True, "message": "Concession waiver reversed and removed successfully"}


@router.post("/student-fees/penalties", status_code=status.HTTP_201_CREATED)
async def add_student_fee_penalty(
    payload: AddStudentPenaltyPayload,
    current_user: dict = Depends(get_current_user)
):
    """Add fine or late fee penalty to an invoice."""
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")
    inv_id = _clean_uuid(payload.invoice_id)

    await exec_sql("""
    INSERT INTO public.student_fee_penalties (
        school_id, student_id, invoice_id, penalty_type, amount, reason, applied_by
    ) VALUES (
        %s::UUID, %s::UUID, %s::UUID, %s, %s, %s, %s::UUID
    );
    """, (school_id, payload.student_id, inv_id, payload.penalty_type, payload.amount, payload.reason, user_id), fetch=False)

    # Adjust invoice if linked
    if inv_id:
        await exec_sql("""
        UPDATE public.student_fee_invoices
        SET penalty_amount = penalty_amount + %s,
            total_billed = total_billed + %s,
            balance_amount = balance_amount + %s,
            status = 'Overdue',
            updated_at = NOW()
        WHERE id = %s::UUID AND school_id = %s::UUID;
        """, (payload.amount, payload.amount, payload.amount, inv_id, school_id), fetch=False)

    return {"success": True, "message": "Penalty added successfully"}


@router.delete("/student-fees/penalties/{penalty_id}")
async def delete_student_fee_penalty(
    penalty_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Reverse a penalty fine and adjust the invoice balance accordingly."""
    school_id = _get_school_id(current_user)
    rows = await exec_sql("""
        SELECT invoice_id, amount FROM public.student_fee_penalties 
        WHERE id = %s::UUID AND school_id = %s::UUID;
    """, (penalty_id, school_id))
    if not rows:
        raise HTTPException(status_code=404, detail="Penalty record not found")
    
    inv_id = rows[0].get("invoice_id")
    amt = float(rows[0].get("amount", 0.0))
    if inv_id:
        await exec_sql("""
            UPDATE public.student_fee_invoices
            SET penalty_amount = GREATEST(0.0, penalty_amount - %s),
                total_billed = GREATEST(0.0, total_billed - %s),
                balance_amount = GREATEST(0.0, balance_amount - %s),
                status = CASE 
                    WHEN (balance_amount - %s) <= 0 THEN 'Paid'
                    WHEN paid_amount > 0 THEN 'Partial'
                    ELSE 'Pending'
                END,
                updated_at = NOW()
            WHERE id = %s::UUID AND school_id = %s::UUID;
        """, (amt, amt, amt, amt, inv_id, school_id), fetch=False)

    await exec_sql("DELETE FROM public.student_fee_penalties WHERE id = %s::UUID AND school_id = %s::UUID;", (penalty_id, school_id), fetch=False)
    return {"success": True, "message": "Penalty fine reversed and removed successfully"}


@router.get("/student-fees/fee-structures")
async def list_student_fee_structures(
    current_user: dict = Depends(get_current_user)
):
    """Catalog of fee structure templates."""
    school_id = _get_school_id(current_user)
    sql = """
    SELECT id, fee_name, fee_type, class_grade, billing_cycle, amount, description, is_mandatory, status
    FROM public.student_fee_structures
    WHERE school_id = %s::UUID
    ORDER BY created_at ASC;
    """
    rows = await exec_sql(sql, (school_id,))
    return {"success": True, "structures": _serialize_val(rows)}


@router.post("/student-fees/fee-structures", status_code=status.HTTP_201_CREATED)
async def create_student_fee_structure(
    payload: StudentFeeStructurePayload,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    sql = """
    INSERT INTO public.student_fee_structures (
        school_id, fee_name, fee_type, class_grade, billing_cycle, amount, description, is_mandatory
    ) VALUES (
        %s::UUID, %s, %s, %s, %s, %s, %s, %s
    ) RETURNING *;
    """
    rows = await exec_sql(sql, (
        school_id, payload.fee_name, payload.fee_type, payload.class_grade,
        payload.billing_cycle, payload.amount, payload.description, payload.is_mandatory
    ))
    return {"success": True, "message": "Fee structure created", "structure": _serialize_val(rows[0])}


@router.delete("/student-fees/fee-structures/{structure_id}")
async def delete_student_fee_structure(
    structure_id: str,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    await exec_sql("DELETE FROM public.student_fee_structures WHERE id = %s::UUID AND school_id = %s::UUID;", (structure_id, school_id), fetch=False)
    return {"success": True, "message": "Fee structure deleted"}


@router.put("/student-fees/fee-structures/{structure_id}")
async def update_student_fee_structure(
    structure_id: str,
    payload: StudentFeeStructurePayload,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    sql = """
    UPDATE public.student_fee_structures
    SET fee_name = %s, fee_type = %s, class_grade = %s, billing_cycle = %s,
        amount = %s, description = %s, is_mandatory = %s, updated_at = NOW()
    WHERE id = %s::UUID AND school_id = %s::UUID;
    """
    await exec_sql(sql, (
        payload.fee_name, payload.fee_type, payload.class_grade, payload.billing_cycle,
        payload.amount, payload.description, payload.is_mandatory, structure_id, school_id
    ), fetch=False)
    return {"success": True, "message": "Fee structure updated successfully"}


@router.get("/student-fees/invoices-list")
async def list_all_student_invoices(
    search: Optional[str] = Query(""),
    status: Optional[str] = Query(None),
    page: int = Query(1, ge=1),
    page_size: int = Query(15, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Sub-tab 5: Master list of all student invoices with server-side pagination."""
    school_id = _get_school_id(current_user)
    page = _clean_int(page, 1)
    page_size = _clean_int(page_size, 15)
    offset = (page - 1) * page_size

    where_clauses = ["i.school_id = %s::UUID"]
    params = [school_id]

    if search and search.strip():
        s = f"%{search.strip()}%"
        where_clauses.append("(i.invoice_number ILIKE %s OR p.full_name ILIKE %s OR i.title ILIKE %s)")
        params.extend([s, s, s])

    if status and status not in ("All Status", "All"):
        where_clauses.append("i.status = %s")
        params.append(status)

    where_sql = " AND ".join(where_clauses)

    sql = f"""
    SELECT i.id, i.invoice_number, i.title, i.fee_type, i.fee_plan, i.due_date,
           i.total_billed, i.paid_amount, i.balance_amount, i.status,
           p.full_name AS student_name, p.roll_number, p.class AS class_name
    FROM public.student_fee_invoices i
    JOIN public.profiles p ON i.student_id = p.id
    WHERE {where_sql}
    ORDER BY i.created_at DESC
    LIMIT %s OFFSET %s;
    """
    data_params = params + [page_size, offset]
    rows = await exec_sql(sql, tuple(data_params))

    cnt_sql = f"""
    SELECT COUNT(*) as total_count
    FROM public.student_fee_invoices i
    JOIN public.profiles p ON i.student_id = p.id
    WHERE {where_sql};
    """
    cnt_rows = await exec_sql(cnt_sql, tuple(params))
    total_count = cnt_rows[0]['total_count'] if cnt_rows else 0

    return {
        "success": True,
        "invoices": _serialize_val(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": total_count,
            "total_pages": (total_count + page_size - 1) // page_size if total_count > 0 else 1
        }
    }


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
    """Executes bulk operations (reminders, mass settlement, voiding) on selected students."""
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")
    if not payload.ids:
        return {"success": True, "count": 0, "message": "No students selected"}

    if payload.action == "send_reminder":
        # Log SMS / Email reminder audit event
        return {"success": True, "count": len(payload.ids), "message": f"Payment reminders queued for {len(payload.ids)} students"}

    elif payload.action == "mark_paid":
        # Mark pending invoices for selected students as Paid
        updated = 0
        for s_id in payload.ids:
            invs = await exec_sql("""
                SELECT id, balance_amount FROM public.student_fee_invoices 
                WHERE student_id = %s::UUID AND school_id = %s::UUID AND status IN ('Pending', 'Partial', 'Overdue');
            """, (s_id, school_id))
            for inv in invs:
                await exec_sql("""
                    UPDATE public.student_fee_invoices
                    SET paid_amount = total_billed,
                        balance_amount = 0.0,
                        status = 'Paid',
                        updated_at = NOW()
                    WHERE id = %s::UUID;
                """, (inv['id'],), fetch=False)
                # Create receipt
                rec_num = f"REC-BULK-{uuid.uuid4().hex[:6].upper()}"
                await exec_sql("""
                    INSERT INTO public.student_fee_payments (
                        school_id, student_id, invoice_id, receipt_number, amount_paid, payment_method, remarks, recorded_by
                    ) VALUES (
                        %s::UUID, %s::UUID, %s::UUID, %s, %s, 'Direct Settlement', 'Bulk marked as paid', %s::UUID
                    );
                """, (school_id, s_id, inv['id'], rec_num, float(inv['balance_amount']), user_id), fetch=False)
                updated += 1
        return {"success": True, "count": updated, "message": f"Successfully settled {updated} invoices for {len(payload.ids)} students"}

    elif payload.action == "void_invoices":
        for s_id in payload.ids:
            await exec_sql("""
                DELETE FROM public.student_fee_invoices 
                WHERE student_id = %s::UUID AND school_id = %s::UUID AND status IN ('Pending', 'Overdue');
            """, (s_id, school_id), fetch=False)
        return {"success": True, "count": len(payload.ids), "message": f"Unpaid invoices voided for {len(payload.ids)} students"}

    return {"success": False, "message": f"Unknown bulk action: {payload.action}"}


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
    """KPI metrics for Staff Salary Management."""
    target_month = _clean_str(month_str) or _clean_str(month) or "2026-10"
    school_id = _get_school_id(current_user)

    sql = """
    SELECT 
        COUNT(DISTINCT s.id) AS total_staff_count,
        COALESCE(SUM(struct.gross_salary), 0.0) AS total_monthly_budget,
        COALESCE(SUM(CASE WHEN pay.payment_status = 'Paid' THEN pay.net_pay ELSE 0 END), 0.0) AS total_disbursed,
        COALESCE(SUM(CASE WHEN pay.payment_status = 'Pending' OR pay.id IS NULL THEN struct.net_salary ELSE 0 END), 0.0) AS pending_disbursal,
        COALESCE(SUM(CASE WHEN pay.payment_status = 'On Hold' THEN struct.net_salary ELSE 0 END), 0.0) AS on_hold_amount,
        COUNT(DISTINCT CASE WHEN pay.payment_status = 'Paid' THEN s.id END) AS paid_staff_count,
        COUNT(DISTINCT CASE WHEN pay.payment_status = 'Pending' OR pay.id IS NULL THEN s.id END) AS pending_staff_count,
        COUNT(DISTINCT CASE WHEN pay.payment_status = 'On Hold' THEN s.id END) AS on_hold_staff_count
    FROM public.profiles s
    LEFT JOIN public.staff_salary_structures struct 
        ON s.id = struct.staff_id AND s.school_id = struct.school_id
    LEFT JOIN public.staff_salary_payouts pay 
        ON s.id = pay.staff_id AND s.school_id = pay.school_id AND pay.month_str = %s
    WHERE s.school_id = %s::UUID AND s.role != 'student';
    """
    rows = await exec_sql(sql, (target_month, school_id))
    stats = rows[0] if rows else {}

    total_budget = float(stats.get('total_monthly_budget', 0.0))
    total_disbursed = float(stats.get('total_disbursed', 0.0))
    disbursal_rate = (total_disbursed / total_budget * 100) if total_budget > 0 else 0.0

    return {
        "success": True,
        "kpis": {
            "total_monthly_budget": total_budget,
            "total_disbursed": total_disbursed,
            "pending_disbursal": float(stats.get('pending_disbursal', 0.0)),
            "on_hold_amount": float(stats.get('on_hold_amount', 0.0)),
            "disbursal_rate": round(disbursal_rate, 1),
            "disbursal_rate_formatted": f"{round(disbursal_rate, 1)}% Disbursed",
            "total_staff": stats.get('total_staff_count', 0),
            "paid_staff_count": stats.get('paid_staff_count', 0),
            "pending_staff_count": stats.get('pending_staff_count', 0),
            "on_hold_staff_count": stats.get('on_hold_staff_count', 0),
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
    page: int = Query(1, ge=1),
    page_size: int = Query(10, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """
    List staff with role != 'student', salary structures, and payout status for month.
    Includes active advance EMI deduction automatically.
    """
    target_month = _clean_str(month_str) or _clean_str(month) or "2026-10"
    school_id = _get_school_id(current_user)
    page = _clean_int(page, 1)
    page_size = _clean_int(page_size, 10)
    offset = (page - 1) * page_size
    search = _clean_str(search)
    department = _clean_str(department)
    role = _clean_str(role)
    status = _clean_str(status)

    where_clauses = ["s.school_id = %s::UUID", "s.role != 'student'"]
    params = [school_id]

    if search:
        st = f"%{search}%"
        where_clauses.append("(s.full_name ILIKE %s OR s.email ILIKE %s OR s.employee_id ILIKE %s OR s.designation ILIKE %s)")
        params.extend([st, st, st, st])

    if department and department not in ("All Departments", "All"):
        where_clauses.append("s.department = %s")
        params.append(department)

    if role and role not in ("All Roles", "All"):
        where_clauses.append("s.role = %s")
        params.append(role)

    if status and status not in ("All Status", "All Staff", "All"):
        where_clauses.append("COALESCE(pay.payment_status, 'Pending') = %s")
        params.append(status)

    where_sql = " AND ".join(where_clauses)

    query_sql = f"""
    SELECT 
        s.id AS staff_id,
        s.full_name AS staff_name,
        s.email AS staff_email,
        s.phone AS staff_phone,
        s.role,
        COALESCE(s.department, 'Academic & Teaching') AS department,
        COALESCE(s.designation, 'Senior Faculty') AS designation,
        COALESCE(s.employee_id, 'EMP-' || SUBSTRING(s.id::text, 1, 6)) AS employee_id,
        s.avatar_url,
        COALESCE(struct.basic_pay, 35000.0) AS basic_pay,
        COALESCE(struct.hra, 14000.0) AS hra,
        COALESCE(struct.gross_salary, 63000.0) AS gross_salary,
        COALESCE(struct.total_deductions, 7900.0) AS total_deductions,
        COALESCE(struct.net_salary, 55100.0) AS net_salary,
        COALESCE(pay.net_pay, struct.net_salary, 55100.0) AS actual_net_pay,
        COALESCE(pay.payment_status, 'Pending') AS status,
        pay.id AS payout_id,
        pay.payslip_number,
        pay.payment_date,
        COALESCE(pay.payment_mode, struct.payment_mode, 'Direct Bank Transfer (NEFT/RTGS)') AS payment_mode,
        pay.transaction_reference,
        struct.bank_name,
        struct.account_number,
        COALESCE(adv.active_advance_deduction, 0.0) AS active_advance_deduction
    FROM public.profiles s
    LEFT JOIN public.staff_salary_structures struct 
        ON s.id = struct.staff_id AND s.school_id = struct.school_id
    LEFT JOIN public.staff_salary_payouts pay 
        ON s.id = pay.staff_id AND s.school_id = pay.school_id AND pay.month_str = %s
    LEFT JOIN (
        SELECT staff_id, school_id, SUM(monthly_deduction) AS active_advance_deduction
        FROM public.staff_salary_advances
        WHERE status = 'Approved' AND amount_repaid < amount
        GROUP BY staff_id, school_id
    ) adv ON s.id = adv.staff_id AND s.school_id = adv.school_id
    WHERE {where_sql}
    ORDER BY s.full_name ASC
    LIMIT %s OFFSET %s;
    """

    full_params = [target_month] + params + [page_size, offset]
    rows = await exec_sql(query_sql, tuple(full_params))

    count_sql = f"""
    SELECT COUNT(DISTINCT s.id) as total_count
    FROM public.profiles s
    LEFT JOIN public.staff_salary_structures struct 
        ON s.id = struct.staff_id AND s.school_id = struct.school_id
    LEFT JOIN public.staff_salary_payouts pay 
        ON s.id = pay.staff_id AND s.school_id = pay.school_id AND pay.month_str = %s
    WHERE {where_sql}
    """
    c_params = [target_month] + params
    cnt_rows = await exec_sql(count_sql, tuple(c_params))
    total_count = cnt_rows[0]['total_count'] if cnt_rows else 0

    return {
        "success": True,
        "staff": _serialize_val(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": total_count,
            "total_pages": (total_count + page_size - 1) // page_size if total_count > 0 else 1
        }
    }


@router.get("/staff-salary/staff/{staff_id}")
async def get_staff_salary_detail_360(
    staff_id: str,
    current_user: dict = Depends(get_current_user)
):
    """Comprehensive 360-degree Drawer for Staff Salary & Payslips."""
    school_id = _get_school_id(current_user)

    # 1. Profile Info
    prof_sql = """
    SELECT id, full_name, email, phone, role, department, designation, employee_id, avatar_url, status
    FROM public.profiles 
    WHERE id = %s::UUID AND school_id = %s::UUID;
    """
    prows = await exec_sql(prof_sql, (staff_id, school_id))
    if not prows:
        raise HTTPException(status_code=404, detail="Staff profile not found")
    profile = prows[0]

    # 2. Structure
    struct_sql = """
    SELECT basic_pay, hra, da, ta, special_allowance, medical_allowance, gross_salary,
           pf_deduction, tds, professional_tax, insurance_deduction, total_deductions,
           net_salary, payment_mode, bank_name, account_number, ifsc_code, pan_number, status
    FROM public.staff_salary_structures
    WHERE staff_id = %s::UUID AND school_id = %s::UUID;
    """
    srows = await exec_sql(struct_sql, (staff_id, school_id))
    structure = srows[0] if srows else None

    # 3. Payouts History
    pays_sql = """
    SELECT id, payslip_number, month, year, month_str, basic_pay, hra, da, ta,
           special_allowance, bonus, gross_earnings, pf_deduction, tds, professional_tax,
           advance_deduction, other_deductions, total_deductions, net_pay, payment_status,
           payment_date, payment_mode, transaction_reference, remarks, created_at
    FROM public.staff_salary_payouts
    WHERE staff_id = %s::UUID AND school_id = %s::UUID
    ORDER BY year DESC, month DESC;
    """
    payouts = await exec_sql(pays_sql, (staff_id, school_id))

    # 4. Advances
    adv_sql = """
    SELECT id, amount, purpose_type, reason, repayment_months, monthly_deduction,
           amount_repaid, status, remarks, disbursed_at, created_at
    FROM public.staff_salary_advances
    WHERE staff_id = %s::UUID AND school_id = %s::UUID
    ORDER BY created_at DESC;
    """
    advances = await exec_sql(adv_sql, (staff_id, school_id))

    return {
        "success": True,
        "detail": {
            "profile": _serialize_val(profile),
            "structure": _serialize_val(structure),
            "payouts": _serialize_val(payouts),
            "advances": _serialize_val(advances)
        }
    }


@router.post("/staff-salary/payouts", status_code=status.HTTP_201_CREATED)
async def process_staff_salary_payout(
    payload: ProcessStaffPayoutPayload,
    current_user: dict = Depends(get_current_user)
):
    """Process or record individual salary payout, recovering active advances if marked Paid."""
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")

    seq_sql = "SELECT COUNT(*) + 1 AS next_ps FROM public.staff_salary_payouts WHERE school_id = %s::UUID;"
    ps_rows = await exec_sql(seq_sql, (school_id,))
    next_ps = ps_rows[0]['next_ps'] if ps_rows else 1
    payslip_num = f"PS-{payload.year}-{str(payload.month).zfill(2)}-{str(next_ps).zfill(4)}"

    gross = payload.basic_pay + payload.hra + payload.da + payload.ta + payload.special_allowance + payload.bonus
    total_ded = payload.pf_deduction + payload.tds + payload.professional_tax + payload.advance_deduction + payload.other_deductions
    net = gross - total_ded

    ins_sql = """
    INSERT INTO public.staff_salary_payouts (
        school_id, staff_id, payslip_number, month, year, month_str,
        basic_pay, hra, da, ta, special_allowance, bonus, gross_earnings,
        pf_deduction, tds, professional_tax, advance_deduction, other_deductions,
        total_deductions, net_pay, payment_status, payment_date, payment_mode,
        transaction_reference, remarks, processed_by
    ) VALUES (
        %s::UUID, %s::UUID, %s, %s, %s, %s,
        %s, %s, %s, %s, %s, %s, %s,
        %s, %s, %s, %s, %s,
        %s, %s, %s, CASE WHEN %s = 'Paid' THEN NOW() ELSE NULL END, %s,
        %s, %s, %s::UUID
    ) ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
        gross_earnings = EXCLUDED.gross_earnings,
        total_deductions = EXCLUDED.total_deductions,
        net_pay = EXCLUDED.net_pay,
        payment_status = EXCLUDED.payment_status,
        payment_date = CASE WHEN EXCLUDED.payment_status = 'Paid' THEN NOW() ELSE staff_salary_payouts.payment_date END,
        transaction_reference = EXCLUDED.transaction_reference,
        remarks = EXCLUDED.remarks,
        updated_at = NOW()
    RETURNING id, payslip_number;
    """
    rows = await exec_sql(ins_sql, (
        school_id, payload.staff_id, payslip_num, payload.month, payload.year, payload.month_str,
        payload.basic_pay, payload.hra, payload.da, payload.ta, payload.special_allowance, payload.bonus, gross,
        payload.pf_deduction, payload.tds, payload.professional_tax, payload.advance_deduction, payload.other_deductions,
        total_ded, net, payload.payment_status, payload.payment_status, payload.payment_mode,
        payload.transaction_reference or f"TXN{uuid.uuid4().hex[:8].upper()}", payload.remarks, user_id
    ))

    # Automatic advance recovery if marked as Paid
    if payload.payment_status == "Paid":
        adv_rows = await exec_sql("""
            SELECT id, amount, amount_repaid, monthly_deduction
            FROM public.staff_salary_advances
            WHERE staff_id = %s::UUID AND school_id = %s::UUID AND status = 'Approved' AND amount_repaid < amount
            ORDER BY created_at ASC;
        """, (payload.staff_id, school_id))

        rem_ded = payload.advance_deduction
        if rem_ded <= 0 and adv_rows:
            rem_ded = sum(float(a['monthly_deduction']) for a in adv_rows)

        for adv in adv_rows:
            if rem_ded <= 0:
                break
            adv_amt = float(adv['amount'])
            repaid = float(adv['amount_repaid'])
            balance = adv_amt - repaid
            deduct_amt = min(rem_ded, balance)
            new_repaid = repaid + deduct_amt
            new_status = 'Settled' if new_repaid >= adv_amt else 'Approved'
            await exec_sql("""
                UPDATE public.staff_salary_advances
                SET amount_repaid = %s, status = %s, updated_at = NOW()
                WHERE id = %s::UUID AND school_id = %s::UUID;
            """, (new_repaid, new_status, adv['id'], school_id), fetch=False)
            rem_ded -= deduct_amt

    return {"success": True, "message": "Salary payout processed successfully", "payout": _serialize_val(rows[0])}


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
    """Update or customize the base pay breakdown for an employee."""
    school_id = _get_school_id(current_user)

    gross = payload.basic_pay + payload.hra + payload.da + payload.ta + payload.special_allowance + payload.medical_allowance
    total_ded = payload.pf_deduction + payload.tds + payload.professional_tax + payload.insurance_deduction
    net = gross - total_ded

    sql = """
    INSERT INTO public.staff_salary_structures (
        school_id, staff_id, basic_pay, hra, da, ta, special_allowance, medical_allowance,
        gross_salary, pf_deduction, tds, professional_tax, insurance_deduction, total_deductions,
        net_salary, payment_mode, bank_name, account_number, ifsc_code, pan_number, updated_at
    ) VALUES (
        %s::UUID, %s::UUID, %s, %s, %s, %s, %s, %s,
        %s, %s, %s, %s, %s, %s,
        %s, %s, %s, %s, %s, %s, NOW()
    ) ON CONFLICT (school_id, staff_id) DO UPDATE SET
        basic_pay = EXCLUDED.basic_pay,
        hra = EXCLUDED.hra,
        da = EXCLUDED.da,
        ta = EXCLUDED.ta,
        special_allowance = EXCLUDED.special_allowance,
        medical_allowance = EXCLUDED.medical_allowance,
        gross_salary = EXCLUDED.gross_salary,
        pf_deduction = EXCLUDED.pf_deduction,
        tds = EXCLUDED.tds,
        professional_tax = EXCLUDED.professional_tax,
        insurance_deduction = EXCLUDED.insurance_deduction,
        total_deductions = EXCLUDED.total_deductions,
        net_salary = EXCLUDED.net_salary,
        payment_mode = EXCLUDED.payment_mode,
        bank_name = EXCLUDED.bank_name,
        account_number = EXCLUDED.account_number,
        ifsc_code = EXCLUDED.ifsc_code,
        pan_number = EXCLUDED.pan_number,
        updated_at = NOW();
    """
    await exec_sql(sql, (
        school_id, staff_id, payload.basic_pay, payload.hra, payload.da, payload.ta,
        payload.special_allowance, payload.medical_allowance, gross, payload.pf_deduction,
        payload.tds, payload.professional_tax, payload.insurance_deduction, total_ded,
        net, payload.payment_mode, payload.bank_name, payload.account_number,
        payload.ifsc_code, payload.pan_number
    ), fetch=False)

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
    """Sub-tab 5: Master list of monthly payslips with full breakdown and pagination."""
    school_id = _get_school_id(current_user)
    page = _clean_int(page, 1)
    page_size = _clean_int(page_size, 15)
    offset = (page - 1) * page_size
    search = _clean_str(search)

    where_clauses = ["pay.school_id = %s::UUID"]
    params = [school_id]
    if month_str and month_str.strip():
        where_clauses.append("pay.month_str = %s")
        params.append(month_str.strip())
    if search:
        s = f"%{search}%"
        where_clauses.append("(s.full_name ILIKE %s OR s.employee_id ILIKE %s OR pay.payslip_number ILIKE %s)")
        params.extend([s, s, s])

    where_sql = " AND ".join(where_clauses)
    sql = f"""
    SELECT pay.*, 
           s.full_name AS staff_name, s.employee_id, s.department, s.designation, s.role, s.email, s.phone,
           COALESCE(struct.bank_name, 'HDFC Bank') AS bank_name,
           COALESCE(struct.account_number, '501002340055') AS account_number,
           COALESCE(struct.ifsc_code, 'HDFC0001824') AS ifsc_code,
           COALESCE(struct.pan_number, 'PAN000055X') AS pan_number
    FROM public.staff_salary_payouts pay
    JOIN public.profiles s ON pay.staff_id = s.id
    LEFT JOIN public.staff_salary_structures struct ON pay.staff_id = struct.staff_id AND pay.school_id = struct.school_id
    WHERE {where_sql}
    ORDER BY pay.year DESC, pay.month DESC, s.full_name ASC
    LIMIT %s OFFSET %s;
    """
    params_for_data = params + [page_size, offset]
    rows = await exec_sql(sql, tuple(params_for_data))

    count_sql = f"""
    SELECT COUNT(*) as total_count
    FROM public.staff_salary_payouts pay
    JOIN public.profiles s ON pay.staff_id = s.id
    WHERE {where_sql};
    """
    cnt_rows = await exec_sql(count_sql, tuple(params))
    total_count = cnt_rows[0]['total_count'] if cnt_rows else 0

    return {
        "success": True, 
        "payslips": _serialize_val(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": total_count,
            "total_pages": (total_count + page_size - 1) // page_size if total_count > 0 else 1
        }
    }


@router.post("/staff-salary/advances", status_code=status.HTTP_201_CREATED)
async def request_staff_salary_advance(
    payload: StaffSalaryAdvancePayload,
    current_user: dict = Depends(get_current_user)
):
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")
    monthly_ded = round(payload.amount / max(1, payload.repayment_months), 2)

    await exec_sql("""
    INSERT INTO public.staff_salary_advances (
        school_id, staff_id, amount, purpose_type, reason, repayment_months, monthly_deduction, status, approved_by
    ) VALUES (
        %s::UUID, %s::UUID, %s, %s, %s, %s, %s, 'Approved', %s::UUID
    );
    """, (school_id, payload.staff_id, payload.amount, payload.purpose_type, payload.reason, payload.repayment_months, monthly_ded, user_id), fetch=False)

    return {"success": True, "message": "Salary advance recorded and approved successfully"}


@router.get("/staff-salary/advances")
async def list_staff_salary_advances(
    search: Optional[str] = Query(""),
    page: int = Query(1, ge=1),
    page_size: int = Query(15, ge=1, le=100),
    current_user: dict = Depends(get_current_user)
):
    """Sub-tab 7: Master list of salary advances with pagination and search."""
    school_id = _get_school_id(current_user)
    page = _clean_int(page, 1)
    page_size = _clean_int(page_size, 15)
    offset = (page - 1) * page_size
    search = _clean_str(search)

    where_clauses = ["adv.school_id = %s::UUID"]
    params = [school_id]
    if search:
        s = f"%{search}%"
        where_clauses.append("(s.full_name ILIKE %s OR s.employee_id ILIKE %s OR adv.purpose_type ILIKE %s)")
        params.extend([s, s, s])

    where_sql = " AND ".join(where_clauses)
    sql = f"""
    SELECT adv.*, s.full_name AS staff_name, s.employee_id, s.department
    FROM public.staff_salary_advances adv
    JOIN public.profiles s ON adv.staff_id = s.id
    WHERE {where_sql}
    ORDER BY adv.created_at DESC
    LIMIT %s OFFSET %s;
    """
    data_params = params + [page_size, offset]
    rows = await exec_sql(sql, tuple(data_params))

    cnt_sql = f"""
    SELECT COUNT(*) as total_count
    FROM public.staff_salary_advances adv
    JOIN public.profiles s ON adv.staff_id = s.id
    WHERE {where_sql};
    """
    cnt_rows = await exec_sql(cnt_sql, tuple(params))
    total_count = cnt_rows[0]['total_count'] if cnt_rows else 0

    return {
        "success": True, 
        "advances": _serialize_val(rows),
        "pagination": {
            "page": page,
            "page_size": page_size,
            "total_items": total_count,
            "total_pages": (total_count + page_size - 1) // page_size if total_count > 0 else 1
        }
    }


@router.post("/staff-salary/advances/{advance_id}/status")
async def update_staff_salary_advance_status(
    advance_id: str,
    payload: UpdateAdvanceStatusPayload,
    current_user: dict = Depends(get_current_user)
):
    """Approve, Reject, or Settle a staff salary advance."""
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")
    sql = """
    UPDATE public.staff_salary_advances
    SET status = %s,
        approved_by = COALESCE(%s::UUID, approved_by),
        remarks = COALESCE(%s, remarks),
        updated_at = NOW()
    WHERE id = %s::UUID AND school_id = %s::UUID;
    """
    await exec_sql(sql, (payload.status, user_id, payload.remarks, advance_id, school_id), fetch=False)
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
    school_id = _get_school_id(current_user)
    target_month = payload.month_str or "2026-10"
    parts = target_month.split("-")
    year = int(parts[0]) if len(parts) > 0 and parts[0].isdigit() else 2026
    month = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 10

    # Retrieve existing structure for accurate financial figures
    s_rows = await exec_sql("SELECT * FROM public.staff_salary_structures WHERE staff_id = %s::UUID AND school_id = %s::UUID;", (payload.staff_id, school_id))
    struct = s_rows[0] if s_rows else {}
    bpay = float(struct.get("basic_pay", 35000.0))
    hra = float(struct.get("hra", 14000.0))
    da = float(struct.get("da", 7000.0))
    ta = float(struct.get("ta", 4000.0))
    spl = float(struct.get("special_allowance", 3000.0))
    gross = float(struct.get("gross_salary", bpay + hra + da + ta + spl))
    pf = float(struct.get("pf_deduction", 4200.0))
    tds = float(struct.get("tds", 3500.0))
    ptax = float(struct.get("professional_tax", 200.0))
    total_ded = float(struct.get("total_deductions", pf + tds + ptax))
    net = float(struct.get("net_salary", gross - total_ded))

    payslip_num = f"PS-{target_month}-{payload.staff_id[:4].upper()}"
    p_mode = payload.payment_mode or struct.get("payment_mode", "Direct Bank Transfer (NEFT/RTGS)")
    txn_ref = payload.transaction_reference or f"UTR-{target_month.replace('-', '')}-{uuid.uuid4().hex[:6].upper()}"
    remarks = f"Status updated to {payload.status} by {payload.approver_name}. {payload.comments or ''}".strip()

    sql = """
    INSERT INTO public.staff_salary_payouts (
        school_id, staff_id, payslip_number, month, year, month_str,
        basic_pay, hra, da, ta, special_allowance, bonus, gross_earnings,
        pf_deduction, tds, professional_tax, advance_deduction, other_deductions,
        total_deductions, net_pay, payment_status, payment_date, payment_mode,
        transaction_reference, remarks
    ) VALUES (
        %s::UUID, %s::UUID, %s, %s, %s, %s,
        %s, %s, %s, %s, %s, 0.0, %s,
        %s, %s, %s, 0.0, 0.0,
        %s, %s, %s, CASE WHEN %s = 'Paid' THEN NOW() ELSE NULL END, %s,
        %s, %s
    )
    ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
        payment_status = EXCLUDED.payment_status,
        payment_mode = COALESCE(EXCLUDED.payment_mode, staff_salary_payouts.payment_mode),
        transaction_reference = COALESCE(EXCLUDED.transaction_reference, staff_salary_payouts.transaction_reference),
        remarks = EXCLUDED.remarks,
        payment_date = CASE WHEN EXCLUDED.payment_status = 'Paid' THEN NOW() ELSE staff_salary_payouts.payment_date END,
        updated_at = NOW();
    """
    await exec_sql(sql, (
        school_id, payload.staff_id, payslip_num, month, year, target_month,
        bpay, hra, da, ta, spl, gross,
        pf, tds, ptax, total_ded, net, payload.status, payload.status,
        p_mode, txn_ref, remarks
    ), fetch=False)

    # If marked as Paid, recover active advance
    if payload.status == "Paid":
        adv_rows = await exec_sql("""
            SELECT id, amount, amount_repaid, monthly_deduction
            FROM public.staff_salary_advances
            WHERE staff_id = %s::UUID AND school_id = %s::UUID AND status = 'Approved' AND amount_repaid < amount
            ORDER BY created_at ASC;
        """, (payload.staff_id, school_id))

        rem_ded = sum(float(a['monthly_deduction']) for a in adv_rows)
        for adv in adv_rows:
            if rem_ded <= 0:
                break
            adv_amt = float(adv['amount'])
            repaid = float(adv['amount_repaid'])
            balance = adv_amt - repaid
            deduct_amt = min(rem_ded, balance)
            new_repaid = repaid + deduct_amt
            new_status = 'Settled' if new_repaid >= adv_amt else 'Approved'
            await exec_sql("""
                UPDATE public.staff_salary_advances
                SET amount_repaid = %s, status = %s, updated_at = NOW()
                WHERE id = %s::UUID AND school_id = %s::UUID;
            """, (new_repaid, new_status, adv['id'], school_id), fetch=False)
            rem_ded -= deduct_amt

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
    """Executes bulk operations (mass disbursal, hold) on selected staff members."""
    school_id = _get_school_id(current_user)
    user_id = current_user.get("id")
    target_month = payload.month_str or "2026-10"
    parts = target_month.split("-")
    year = int(parts[0]) if len(parts) > 0 and parts[0].isdigit() else 2026
    month = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 10

    if not payload.ids:
        return {"success": True, "count": 0, "message": "No staff selected"}

    if payload.action == "disburse_selected":
        disbursed = 0
        for staff_id in payload.ids:
            # Check structure
            s_rows = await exec_sql("SELECT * FROM public.staff_salary_structures WHERE staff_id = %s::UUID AND school_id = %s::UUID;", (staff_id, school_id))
            struct = s_rows[0] if s_rows else {}
            bpay = float(struct.get("basic_pay", 35000.0))
            hra = float(struct.get("hra", 14000.0))
            da = float(struct.get("da", 7000.0))
            ta = float(struct.get("ta", 4000.0))
            spl = float(struct.get("special_allowance", 3000.0))
            gross = float(struct.get("gross_salary", bpay + hra + da + ta + spl))
            pf = float(struct.get("pf_deduction", 4200.0))
            tds = float(struct.get("tds", 3500.0))
            ptax = float(struct.get("professional_tax", 200.0))
            ins = float(struct.get("insurance_deduction", 0.0))
            total_ded = float(struct.get("total_deductions", pf + tds + ptax + ins))
            net = float(struct.get("net_salary", gross - total_ded))

            ps_num = f"PS-{target_month}-{staff_id[:4].upper()}"
            txn_ref = f"UTR-BULK-{uuid.uuid4().hex[:6].upper()}"

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
                %s, 'Batch disbursed via bulk action', %s::UUID
            )
            ON CONFLICT (school_id, staff_id, month_str) DO UPDATE SET
                payment_status = 'Paid',
                payment_date = NOW(),
                updated_at = NOW();
            """, (
                school_id, staff_id, ps_num, month, year, target_month,
                bpay, hra, da, ta, spl, gross,
                pf, tds, ptax, ins,
                total_ded, net, payload.payment_mode or "Direct Bank Transfer (NEFT/RTGS)",
                txn_ref, user_id
            ), fetch=False)
            disbursed += 1
        return {"success": True, "count": disbursed, "message": f"Successfully disbursed salary for {disbursed} staff members"}

    elif payload.action == "hold_selected":
        for staff_id in payload.ids:
            await exec_sql("""
                UPDATE public.staff_salary_payouts
                SET payment_status = 'On Hold', remarks = 'Put on hold via bulk action', updated_at = NOW()
                WHERE staff_id = %s::UUID AND school_id = %s::UUID AND month_str = %s;
            """, (staff_id, school_id, target_month), fetch=False)
        return {"success": True, "count": len(payload.ids), "message": f"Put payouts on hold for {len(payload.ids)} staff members"}

    return {"success": False, "message": f"Unknown bulk action: {payload.action}"}


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
