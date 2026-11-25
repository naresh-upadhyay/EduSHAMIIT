"""
Universal Exams & Assessment Engine API for EduSHAMIIT ERP.
Multi-tenant, enterprise-grade examination management accessible across
Academic (Teacher Portal) and Admin (Exam Controller / Principal / Super Admin).
"""
from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File, Form, Request
from fastapi.responses import StreamingResponse
from typing import Optional, List, Dict, Any
from datetime import datetime, date, timedelta, timezone
import csv
import io
import json
import math
import os
import time
import uuid
from dateutil.parser import parse
from jose import jwt

from app.middleware.auth import get_current_user, require_school_id, require_exam_access
from app.services.supabase_client import get_supabase
from app.services.exam_monitoring_ws import exam_monitoring_ws_manager
from app.api.live_classes import resolve_browser_livekit_url
from app.api.teacher import (
    teacher_get_exams,
    teacher_get_exam_details,
    create_exam,
    teacher_update_exam,
    teacher_delete_exam,
    teacher_get_exam_questions,
    teacher_add_exam_question,
    teacher_update_exam_question,
    teacher_delete_exam_question,
    teacher_get_exam_attendance,
    teacher_save_exam_attendance,
    teacher_get_exam_sessions,
    teacher_proctor_action,
    teacher_get_exam_submissions,
    teacher_grade_exam_submission,
    teacher_download_exam_pdf,
    teacher_get_exam_analytics,
    teacher_publish_exam_results,
    generate_exam_questions,
    teacher_get_question_bank,
    teacher_add_question_bank,
    teacher_update_question_bank,
    teacher_delete_question_bank,
    teacher_duplicate_question_bank,
    teacher_approve_question_bank,
    teacher_get_question_bank_chapters,
    teacher_get_question_bank_classes,
    export_question_template,
    bulk_upload_questions,
    teacher_classes,
    teacher_subjects,
    teacher_students,
)

router = APIRouter()
question_bank_router = APIRouter()


# ============================================================================
# HELPER FORMATTERS
# ============================================================================

def _format_display_date(d_val):
    if not d_val:
        return "-"
    try:
        if isinstance(d_val, str):
            dt = datetime.fromisoformat(d_val[:10])
            return dt.strftime("%b %d, %Y")
        elif hasattr(d_val, "strftime"):
            return d_val.strftime("%b %d, %Y")
    except Exception:
        pass
    return str(d_val)


def _format_display_time(t_val):
    if not t_val:
        return "09:00 AM"
    try:
        if isinstance(t_val, str):
            if "T" in t_val:
                t_str = t_val.split("T")[1][:5]
            else:
                t_str = t_val[:5]
            dt = datetime.strptime(t_str, "%H:%M")
            return dt.strftime("%I:%M %p")
        elif hasattr(t_val, "strftime"):
            return t_val.strftime("%I:%M %p")
    except Exception:
        pass
    return str(t_val)


# ============================================================================
# DASHBOARD OVERVIEW & LOOKUP SERVICES (BEFORE /{exam_id:uuid})
# ============================================================================

@router.get("/dashboard/overview")
async def get_exams_dashboard_overview(
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Returns executive dashboard KPIs, 8-month pass/fail trends, top performers, calendar events, and recent activity."""
    sb = get_supabase()
    exams_res = await sb.table("exams").select("*").eq("school_id", school_id).aexecute()
    exams = exams_res.data or []
    
    total_exams = len(exams)

    # 1. Real total students appeared from submissions or exam counts
    subs_res = await sb.table("exam_submissions").select("id, student_id, score, is_pass, created_at, exam_id").eq("school_id", school_id).aexecute()
    submissions = subs_res.data or []

    distinct_students = {s.get("student_id") for s in submissions if s.get("student_id")}
    total_students_appeared = len(distinct_students) if distinct_students else sum(int(e.get("total_students_appeared") or 0) for e in exams)
        
    scores = [float(s.get("score")) for s in submissions if s.get("score") is not None]
    if not scores:
        scores = [float(e.get("average_score") or 0.0) for e in exams if e.get("average_score")]
    avg_score = round(sum(scores) / len(scores), 1) if scores else 0.0
        
    graded_subs = [s for s in submissions if s.get("is_pass") is not None]
    if graded_subs:
        pass_count = len([s for s in graded_subs if s.get("is_pass") is True])
        pass_pct = round((pass_count / len(graded_subs)) * 100, 1)
    else:
        pass_pcts = [float(e.get("pass_percentage") or 0.0) for e in exams if e.get("pass_percentage")]
        pass_pct = round(sum(pass_pcts) / len(pass_pcts), 1) if pass_pcts else 0.0

    # Tab counts matching status
    upcoming_count = len([e for e in exams if (e.get("status") == "scheduled" or e.get("schedule_status") == "scheduled")])
    ongoing_count = len([e for e in exams if (e.get("status") in ("ongoing", "in_progress") or e.get("schedule_status") in ("ongoing", "in_progress"))])
    completed_count = len([e for e in exams if (e.get("status") in ("completed", "published") or e.get("schedule_status") in ("completed", "published"))])

    # 2. Performance Chart: Dynamic month-by-month calculation
    from dateutil.relativedelta import relativedelta
    now_dt = datetime.now()
    months_series = []
    for i in range(7, -1, -1):
        target_m = now_dt - relativedelta(months=i)
        months_series.append(target_m.strftime("%b"))
    
    month_stats = {m: {"total": 0, "pass": 0} for m in months_series}
    for s in submissions:
        ca = s.get("created_at")
        if ca:
            try:
                m_label = datetime.fromisoformat(ca[:10]).strftime("%b")
                if m_label in month_stats:
                    month_stats[m_label]["total"] += 1
                    if s.get("is_pass") is True:
                        month_stats[m_label]["pass"] += 1
            except Exception:
                pass

    performance_chart = []
    for m in months_series:
        tot = month_stats[m]["total"]
        passed = month_stats[m]["pass"]
        pass_p = round((passed / tot) * 100) if tot > 0 else 0
        fail_p = 100 - pass_p if tot > 0 else 0
        performance_chart.append({"month": m, "pass_pct": pass_p, "fail_pct": fail_p})

    # 3. Top Performers (Dynamic from exam submissions + profiles)
    top_performers = []
    if submissions:
        student_scores: Dict[str, List[float]] = {}
        for s in submissions:
            sid = s.get("student_id")
            sc = s.get("score")
            if sid and sc is not None:
                student_scores.setdefault(sid, []).append(float(sc))
        
        if student_scores:
            sorted_students = sorted(
                student_scores.items(),
                key=lambda x: sum(x[1]) / len(x[1]),
                reverse=True
            )[:5]
            
            top_sids = [st[0] for st in sorted_students]
            p_res = await sb.table("profiles").select("id, user_id, full_name, class, avatar_url").in_("id", top_sids).aexecute()
            prof_map = {p["id"]: p for p in (p_res.data or [])}
            if len(prof_map) < len(top_sids):
                p_user_res = await sb.table("profiles").select("id, user_id, full_name, class, avatar_url").in_("user_id", top_sids).aexecute()
                for p in (p_user_res.data or []):
                    if p.get("user_id"):
                        prof_map[p["user_id"]] = p

            for rank_idx, (sid, sc_list) in enumerate(sorted_students[:3], start=1):
                prof = prof_map.get(sid, {})
                avg_val = round(sum(sc_list) / len(sc_list), 1)
                top_performers.append({
                    "name": prof.get("full_name") or f"Student {sid[:6]}",
                    "class": prof.get("class") or "General",
                    "score_pct": avg_val,
                    "rank": rank_idx,
                    "avatar": prof.get("avatar_url") or "",
                })

    # 4. Exam Calendar events (upcoming / ongoing exams)
    calendar_events = []
    for e in exams:
        if e.get("exam_date") and (e.get("status") in ("scheduled", "ongoing") or e.get("schedule_status") in ("scheduled", "ongoing")):
            c_val = e.get("target_classes") or ["Class 10"]
            c_name = c_val[0] if isinstance(c_val, list) and c_val else str(c_val)
            calendar_events.append({
                "id": str(e["id"]),
                "title": e.get("title", "Exam"),
                "date": str(e.get("exam_date")),
                "time": str(e.get("start_time"))[:5] if e.get("start_time") else "09:00",
                "class": c_name,
                "status": e.get("status", "scheduled")
            })

    # 5. Recent Activity Logs from exam_activity_logs
    act_res = await sb.table("exam_activity_logs").select("*").eq("school_id", school_id).order("created_at", ascending=False).limit(10).aexecute()
    recent_activities = act_res.data or []

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "kpis": {
                "total_exams": total_exams,
                "total_exams_change": "+8%",
                "total_students_appeared": total_students_appeared,
                "total_students_appeared_change": "+5%",
                "average_score": avg_score,
                "average_score_change": "+2%",
                "pass_percentage": pass_pct,
                "pass_percentage_change": "+1%",
            },
            "tab_counts": {
                "all": total_exams,
                "upcoming": upcoming_count,
                "ongoing": ongoing_count,
                "completed": completed_count,
            },
            "performance_chart": performance_chart,
            "top_performers": top_performers,
            "calendar_events": calendar_events,
            "recent_activities": recent_activities,
        }
    }


@router.get("/lookups/exam-management")
async def get_exam_management_lookups(
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Dynamic lookup values for categories, status, modes, attendance, grading schemes, classes, and subjects."""
    sb = get_supabase()
    keys_res = await sb.table("lookup_keys").select("id, key_code").eq("school_id", school_id).in_(
        "key_code", ["EXAM_CATEGORY", "EXAM_STATUS", "EXAM_MODE", "ATTENDANCE_STATUS", "GRADING_SCHEME", "EXAM_PURPOSE"]
    ).aexecute()
    keys_data = keys_res.data or []
    key_ids = [k["id"] for k in keys_data]
    
    values_map = {k["key_code"]: [] for k in keys_data}
    if key_ids:
        val_res = await sb.table("lookup_values").select("lookup_key_id, value_code, value_name, sort_order").in_("lookup_key_id", key_ids).order("sort_order").aexecute()
        key_id_to_code = {k["id"]: k["key_code"] for k in keys_data}
        for v in (val_res.data or []):
            code = key_id_to_code.get(v["lookup_key_id"])
            if code:
                values_map[code].append({
                    "code": v["value_code"],
                    "name": v["value_name"],
                    "sort_order": v.get("sort_order", 0)
                })

    # Fetch classes and sections directly from academic_classes & academic_sections (Class Management SSOT)
    classes_sections_res = await sb.rpc("sp_get_exam_classes_and_sections", {"p_school_id": school_id}).aexecute()
    class_mgmt_data = classes_sections_res.data if classes_sections_res else {}
    classes_with_sections = class_mgmt_data.get("classes") or []
    unique_classes = [c["name"] for c in classes_with_sections if c.get("name")]
    
    subj_res = await sb.table("subjects").select("id, name, class").eq("school_id", school_id).order("name").aexecute()
    subjects = subj_res.data or []

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "exam_categories": values_map.get("EXAM_CATEGORY", [
                {"code": "Final Exam", "name": "Final Exam"},
                {"code": "Mid Term", "name": "Mid Term"},
                {"code": "Pre Board", "name": "Pre Board"},
                {"code": "Half Yearly", "name": "Half Yearly"},
                {"code": "Unit Test", "name": "Unit Test"},
                {"code": "Practical Exam", "name": "Practical Exam"},
            ]),
            "exam_statuses": values_map.get("EXAM_STATUS", [
                {"code": "scheduled", "name": "Scheduled"},
                {"code": "ongoing", "name": "Ongoing"},
                {"code": "completed", "name": "Completed"},
                {"code": "draft", "name": "Draft"},
            ]),
            "exam_modes": values_map.get("EXAM_MODE", [
                {"code": "offline", "name": "Offline / Paper-Based"},
                {"code": "online", "name": "Online / CBT"},
                {"code": "hybrid", "name": "Hybrid"},
            ]),
            "attendance_statuses": values_map.get("ATTENDANCE_STATUS", [
                {"code": "present", "name": "Present"},
                {"code": "absent", "name": "Absent"},
                {"code": "exempted", "name": "Exempted"},
                {"code": "medical", "name": "Medical Leave"},
            ]),
            "grading_schemes": values_map.get("GRADING_SCHEME", [
                {"code": "CBSE_9_POINT", "name": "CBSE 9-Point Scale (A1 to E)"},
                {"code": "PERCENTAGE_BASED", "name": "Direct Percentage Scale"},
            ]),
            "classes": unique_classes if unique_classes else ["Class 5", "Class 6", "Class 7", "Class 8", "Class 9", "Class 10", "Class 11", "Class 12"],
            "classes_with_sections": classes_with_sections,
            "subjects": subjects,
        }
    }


# ============================================================================
# 1. CORE EXAM CRUD & LISTING
# ============================================================================

@router.get("")
@router.get("/")
async def get_all_exams(
    status_tab: Optional[str] = "all",
    type: Optional[str] = None,
    class_name: Optional[str] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    teacher_id: Optional[str] = None,
    search: Optional[str] = None,
    status: Optional[str] = None,
    page: int = 1,
    page_size: int = 10,
    sort_by: Optional[str] = None,
    sort_order: str = "asc",
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Retrieve exams list for teacher or admin with full aggregation metrics and UI pagination."""
    sb = get_supabase()
    query = sb.table("exams").select("*, subjects(name, class)").eq("school_id", school_id)
    if user.get("role") == "teacher":
        query = query.eq("teacher_id", user["id"])
    elif teacher_id:
        query = query.eq("teacher_id", teacher_id)
        
    exams_data = (await query.order("exam_date", ascending=False).order("created_at", ascending=False).aexecute()).data or []

    exam_ids = [e["id"] for e in exams_data]
    question_counts = {}
    if exam_ids:
        q_count_res = await sb.table("exam_questions").select("exam_id, marks").in_("exam_id", exam_ids).aexecute()
        for row in (q_count_res.data or []):
            eid = row.get("exam_id")
            if eid:
                question_counts[eid] = question_counts.get(eid, 0) + 1

    formatted_exams = []
    for e in exams_data:
        subj = e.get("subjects") or {}
        subject_name = subj.get("name") or e.get("subject") or "Mathematics"

        tc = e.get("target_classes")
        c_str = "Class 10"
        if tc:
            if isinstance(tc, str):
                try:
                    import json
                    tc = json.loads(tc)
                except Exception:
                    pass
            if isinstance(tc, list):
                c_str = ", ".join(tc)
            else:
                c_str = str(tc)
        elif subj.get("class"):
            c_str = subj.get("class")

        status_raw = e.get("status") or "draft"
        sched_status = e.get("schedule_status") or status_raw
        
        # Display status matching UI pill (Scheduled, Ongoing, Completed, Draft)
        if status_raw == "scheduled" or sched_status == "scheduled":
            status_display = "Scheduled"
        elif status_raw in ("ongoing", "in_progress") or sched_status in ("ongoing", "in_progress"):
            status_display = "Ongoing"
        elif status_raw in ("completed", "published") or sched_status in ("completed", "published"):
            status_display = "Completed"
        else:
            status_display = status_raw.capitalize()

        exam_type_val = e.get("exam_category") or e.get("paper_type") or e.get("exam_type") or "Unit Test"
        if exam_type_val.lower() == "offline":
            exam_type_val = "Unit Test"
        elif exam_type_val.lower() == "online":
            exam_type_val = "Term Exam"

        formatted_exams.append({
            "id": str(e["id"]),
            "exam_code": e.get("exam_code") or f"EXAM-{str(e['id'])[:6].upper()}",
            "title": e.get("title") or "Institutional Assessment",
            "class": c_str,
            "target_classes": tc if isinstance(tc, list) else [c_str],
            "type": exam_type_val,
            "exam_category": exam_type_val,
            "exam_type": e.get("exam_type", "offline"),
            "date": _format_display_date(e.get("exam_date")),
            "date_raw": str(e.get("exam_date") or ""),
            "time": _format_display_time(e.get("start_time")),
            "status": status_display,
            "status_raw": status_raw,
            "schedule_status": sched_status,
            "duration": f"{e.get('duration_minutes', 120)} mins",
            "duration_minutes": e.get("duration_minutes", 120),
            "total_marks": e.get("total_marks", 100),
            "passing_marks": e.get("passing_marks", 33),
            "subject": subject_name,
            "question_count": question_counts.get(e["id"], 0),
            "total_students_appeared": e.get("total_students_appeared", 0),
            "total_students_passed": e.get("total_students_passed", 0),
            "pass_percentage": float(e.get("pass_percentage") or 0.0),
            "average_score": float(e.get("average_score") or 0.0),
            "is_published": bool(e.get("is_published", False)),
            "academic_session": e.get("academic_session", "2025-26"),
            "exam_mode": e.get("exam_mode", "offline"),
        })

    # Calculate Tab counts before filtering
    tab_counts = {
        "all": len(formatted_exams),
        "upcoming": len([e for e in formatted_exams if e["status"] == "Scheduled"]),
        "ongoing": len([e for e in formatted_exams if e["status"] == "Ongoing"]),
        "completed": len([e for e in formatted_exams if e["status"] == "Completed"]),
    }

    # Order exams: Scheduled first, Ongoing second, Completed third
    formatted_exams.sort(key=lambda x: (
        0 if x["status"] == "Scheduled" else (1 if x["status"] == "Ongoing" else 2)
    ))

    # Apply status tab filter
    filtered = formatted_exams
    if status_tab and status_tab.lower() != "all":
        if status_tab.lower() in ("upcoming", "scheduled"):
            filtered = [e for e in filtered if e["status"] == "Scheduled"]
        elif status_tab.lower() in ("ongoing", "in_progress"):
            filtered = [e for e in filtered if e["status"] == "Ongoing"]
        elif status_tab.lower() in ("completed", "published"):
            filtered = [e for e in filtered if e["status"] == "Completed"]

    # Filter by class_name
    if class_name and class_name.lower() not in ("all", "all classes"):
        filtered = [e for e in filtered if class_name.lower() in e["class"].lower()]

    # Filter by type / category
    if type and type.lower() not in ("all", "all types"):
        filtered = [e for e in filtered if type.lower() in e["type"].lower()]

    # Filter by status
    if status and status.lower() not in ("all", "all status"):
        filtered = [e for e in filtered if status.lower() in e["status"].lower() or status.lower() in e["status_raw"].lower()]

    # Filter by date range
    if start_date and start_date.strip():
        sd = start_date.strip()
        filtered = [e for e in filtered if e.get("date_raw") and str(e["date_raw"]) >= sd]
    if end_date and end_date.strip():
        ed = end_date.strip()
        filtered = [e for e in filtered if e.get("date_raw") and str(e["date_raw"]) <= ed]

    # Filter by search
    if search and search.strip():
        s = search.strip().lower()
        filtered = [e for e in filtered if s in e["title"].lower() or s in e["class"].lower() or s in e["subject"].lower() or s in e["exam_code"].lower()]

    if sort_by and sort_by.strip():
        skey = sort_by.strip().lower()
        rev = (sort_order or "asc").strip().lower() == "desc"
        key_map = {
            "title": lambda x: str(x.get("title") or "").lower(),
            "class": lambda x: str(x.get("class") or "").lower(),
            "type": lambda x: str(x.get("type") or "").lower(),
            "date": lambda x: str(x.get("date_raw") or ""),
            "status": lambda x: str(x.get("status") or "").lower(),
        }
        if skey in key_map:
            filtered.sort(key=key_map[skey], reverse=rev)

    # Pagination
    total_count = len(filtered)
    total_pages = max(1, math.ceil(total_count / page_size)) if page_size > 0 else 1
    offset = (page - 1) * page_size
    paged = filtered[offset : offset + page_size] if page_size > 0 else filtered

    # KPI summary: Dynamic without hardcoded fallback numbers
    total_appeared = sum(e.get("total_students_appeared", 0) for e in formatted_exams)
    avg_score = round(sum(e.get("average_score", 0.0) for e in formatted_exams) / len(formatted_exams), 1) if formatted_exams else 0.0
    avg_pass = round(sum(e.get("pass_percentage", 0.0) for e in formatted_exams) / len(formatted_exams), 1) if formatted_exams else 0.0

    kpis = {
        "total_exams": len(formatted_exams),
        "total_exams_change": "+0%",
        "total_students_appeared": total_appeared,
        "total_students_appeared_change": "+0%",
        "average_score": avg_score,
        "average_score_change": "+0%",
        "pass_percentage": avg_pass,
        "pass_percentage_change": "+0%",
    }

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "exams": paged,
            "total_count": total_count,
            "page": page,
            "page_size": page_size,
            "total_pages": total_pages,
            "tab_counts": tab_counts,
            "kpis": kpis,
        }
    }


# ============================================================================
# BULK EXAM OPERATIONS (STATUS, PUBLISH, EXPORT)
# ============================================================================

@router.post("/bulk/status")
async def bulk_update_exam_status(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Bulk update status across multiple examinations atomically."""
    exam_ids = request.get("exam_ids") or []
    status = request.get("status") or "Scheduled"
    if not exam_ids:
        raise HTTPException(status_code=400, detail="exam_ids array cannot be empty")
    
    norm_status = status.lower()
    valid_statuses = {"scheduled", "ongoing", "completed", "cancelled"}
    if norm_status not in valid_statuses:
        raise HTTPException(status_code=400, detail=f"Invalid status '{status}'. Must be one of: {', '.join(sorted(valid_statuses))}")

    sb = get_supabase()
    res = await sb.table("exams").update({
        "status": norm_status,
        "schedule_status": norm_status,
    }).in_("id", exam_ids).eq("school_id", school_id).aexecute()

    try:
        await sb.table("exam_activity_logs").insert({
            "school_id": school_id,
            "action": "bulk_status_update",
            "title": f"Bulk Status Updated ({status})",
            "description": f"Updated status to {status} for {len(exam_ids)} examination(s)",
            "performed_by": user.get("id"),
            "performed_by_name": user.get("full_name") or "Administrator",
            "icon": "published_with_changes",
            "color": "blue",
        }).aexecute()
    except Exception:
        pass

    return {
        "success": True,
        "school_id": school_id,
        "message": f"Successfully updated status to '{status}' for {len(exam_ids)} examination(s)",
        "affected_count": len(res.data or []),
    }


@router.post("/bulk/publish")
async def bulk_publish_exams(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Bulk publish results for multiple examinations."""
    exam_ids = request.get("exam_ids") or []
    if not exam_ids:
        raise HTTPException(status_code=400, detail="exam_ids array cannot be empty")

    sb = get_supabase()
    now_iso = datetime.now(timezone.utc).isoformat()
    res = await sb.table("exams").update({
        "status": "completed",
        "schedule_status": "completed",
        "is_published": True,
        "results_published_at": now_iso,
    }).in_("id", exam_ids).eq("school_id", school_id).aexecute()

    try:
        await sb.table("exam_activity_logs").insert({
            "school_id": school_id,
            "action": "bulk_publish",
            "title": f"Bulk Published {len(exam_ids)} Exam Results",
            "description": f"Results published for {len(exam_ids)} examination(s)",
            "performed_by": user.get("id"),
            "performed_by_name": user.get("full_name") or "Administrator",
            "icon": "check_circle",
            "color": "green",
        }).aexecute()
    except Exception:
        pass

    return {
        "success": True,
        "school_id": school_id,
        "message": f"Successfully published results for {len(exam_ids)} examination(s)",
        "affected_count": len(res.data or []),
    }


@router.post("/bulk/export-schedules")
async def bulk_export_exam_schedules(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Export schedule and hall tickets metadata as CSV for selected examinations."""
    exam_ids = request.get("exam_ids") or []
    sb = get_supabase()
    query = sb.table("exams").select("*, subjects(name)").eq("school_id", school_id)
    if exam_ids:
        query = query.in_("id", exam_ids)
    res = await query.order("exam_date", ascending=True).aexecute()
    exams = res.data or []

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow([
        "Exam Code", "Exam Title", "Subject", "Class/Target", "Exam Date", 
        "Start Time", "Duration (Mins)", "Total Marks", "Passing Marks", "Mode", "Status"
    ])
    for e in exams:
        subj = (e.get("subjects") or {}).get("name") or "-"
        tc = e.get("target_classes") or []
        target_str = ", ".join(tc) if isinstance(tc, list) else str(tc or "-")
        writer.writerow([
            e.get("exam_code") or f"EXAM-{str(e['id'])[:6].upper()}",
            e.get("title") or "Exam",
            subj,
            target_str,
            e.get("exam_date") or "-",
            str(e.get("start_time") or "-")[:5],
            e.get("duration_minutes") or 120,
            e.get("total_marks") or 100,
            e.get("passing_marks") or 33,
            e.get("exam_mode") or e.get("exam_type") or "offline",
            e.get("status") or "scheduled",
        ])
    
    output.seek(0)
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode("utf-8")),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=exam_schedules_{date.today().isoformat()}.csv"}
    )


@router.post("/create")
@router.post("")
@router.post("/")
async def create_new_exam(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Create a new exam with full enterprise configuration and activity audit logging."""
    sb = get_supabase()
    target_classes = request.get("target_classes")
    if target_classes is None and request.get("class"):
        target_classes = [request.get("class")]
    if target_classes is None:
        target_classes = []

    applicable_sections = request.get("applicable_sections") or []
    target_students = request.get("target_students") or request.get("target_users") or []

    scope = request.get("scope")
    if not scope:
        if target_students and not target_classes:
            scope = "Targeted Users"
        elif target_classes:
            scope = "Target Classes"
        else:
            scope = "All Students"

    subject_id = request.get("subject_id")
    subject_name = request.get("subject")
    if not subject_id and subject_name:
        subj_res = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name).limit(1).maybe_single().aexecute()
        if subj_res.data:
            subject_id = subj_res.data["id"]

    dur_val = request.get("duration_minutes") or request.get("duration") or 120
    if isinstance(dur_val, str):
        digits = "".join([c for c in dur_val if c.isdigit()])
        duration_minutes = int(digits) if digits else 120
    else:
        duration_minutes = int(dur_val)

    exam_date = request.get("exam_date") or date.today().isoformat()
    start_time = request.get("start_time")
    if not start_time:
        start_time = f"{exam_date}T09:00:00Z"

    status_val = request.get("status", "scheduled")
    schedule_status_val = "scheduled" if status_val == "scheduled" else "draft"

    # Validate profile foreign keys
    valid_profile_id = None
    u_id = user.get("id")
    if u_id:
        p_chk = await sb.table("profiles").select("id").eq("id", u_id).aexecute()
        if p_chk.data:
            valid_profile_id = u_id
    if not valid_profile_id:
        fallback_p = await sb.table("profiles").select("id").eq("school_id", school_id).in_("role", ["teacher", "admin", "super_admin"]).limit(1).aexecute()
        if fallback_p.data:
            valid_profile_id = fallback_p.data[0]["id"]

    teacher_id = request.get("teacher_id") or valid_profile_id
    created_by = valid_profile_id
    
    exam_insert = {
        "school_id": school_id,
        "subject_id": subject_id,
        "teacher_id": teacher_id,
        "title": request.get("title", "New Examination"),
        "exam_code": request.get("exam_code") or f"EXAM-{datetime.utcnow().strftime('%Y%m%d%H%M')}",
        "academic_session": request.get("academic_session", "2025-26"),
        "exam_type": request.get("exam_type", "offline"),
        "exam_mode": request.get("exam_mode", "offline"),
        "exam_category": request.get("exam_category") or request.get("type") or "Unit Test",
        "exam_purpose": request.get("exam_purpose", "Summative Assessment"),
        "exam_date": exam_date,
        "start_time": start_time,
        "duration_minutes": duration_minutes,
        "total_marks": int(request.get("total_marks") or 100),
        "passing_marks": int(request.get("passing_marks") or 33),
        "target_classes": target_classes,
        "applicable_sections": applicable_sections,
        "target_students": target_students,
        "scope": scope,
        "status": status_val,
        "schedule_status": schedule_status_val,
        "instructions": request.get("instructions", "1. All questions are compulsory.\n2. Write clearly and legibly."),
        "created_by": created_by,
    }
    
    res = await sb.table("exams").insert(exam_insert).aexecute()
    new_exam = res.data[0] if res.data else {}

    # Audit log
    try:
        await sb.table("exam_activity_logs").insert({
            "school_id": school_id,
            "exam_id": new_exam.get("id"),
            "action": "EXAM_CREATED",
            "title": f"Exam Created: {new_exam.get('title')}",
            "description": f"{', '.join(target_classes)} • Scheduled for {_format_display_date(exam_date)}",
            "performed_by": valid_profile_id,
            "icon": "calendar_today",
            "color": "blue",
        }).aexecute()
    except Exception as e:
        logger.warning(f"Failed to log exam creation activity: {e}")

    return {"success": True, "school_id": school_id, "data": new_exam}


# ============================================================================
# EXAM SCHEDULE (DATE SHEET) & CONFLICT CHECKING
# ============================================================================

@router.put("/schedules/{schedule_id}")
async def update_exam_schedule(
    schedule_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"room_number", "invigilator_name", "start_time", "end_time", "exam_date", "status", "max_marks", "passing_marks"}
    updates = {k: v for k, v in request.items() if k in allowed}
    res = await sb.table("exam_schedules").update(updates).eq("id", schedule_id).aexecute()
    return {"success": True, "school_id": school_id, "data": res.data[0] if res.data else {}}


@router.delete("/schedules/{schedule_id}")
async def delete_exam_schedule(
    schedule_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("exam_schedules").delete().eq("id", schedule_id).aexecute()
    return {"success": True, "school_id": school_id, "message": "Schedule entry deleted"}



# ============================================================================
# PAPER BUILDER & QUESTION BANK API (MUST BE REGISTERED BEFORE /{exam_id:uuid})
# ============================================================================

@router.get("/lookups/paper-builder")
async def get_paper_builder_lookups(
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Returns dynamic lookup values and available chapters for Paper Builder."""
    sb = get_supabase()
    keys_res = await sb.table("lookup_keys").select("id, key_code").eq("school_id", school_id).in_("key_code", ["PAPER_TYPE", "PAPER_STATUS", "SECTION_TYPE", "QUESTION_TYPE", "QUESTION_DIFFICULTY"]).aexecute()
    keys_data = keys_res.data or []
    key_ids = [k["id"] for k in keys_data]
    
    values_map = {k["key_code"]: [] for k in keys_data}
    if key_ids:
        val_res = await sb.table("lookup_values").select("lookup_key_id, value_code, value_name, sort_order").in_("lookup_key_id", key_ids).order("sort_order").aexecute()
        key_id_to_code = {k["id"]: k["key_code"] for k in keys_data}
        for v in (val_res.data or []):
            code = key_id_to_code.get(v["lookup_key_id"])
            if code:
                values_map[code].append({
                    "code": v["value_code"],
                    "name": v["value_name"],
                    "sort_order": v.get("sort_order", 0)
                })
                
    chap_res = await sb.table("question_bank").select("chapter").eq("school_id", school_id).neq("chapter", None).aexecute()
    chapters = sorted(list({q["chapter"] for q in (chap_res.data or []) if q.get("chapter")}))
    
    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "paper_types": values_map.get("PAPER_TYPE", []),
            "paper_statuses": values_map.get("PAPER_STATUS", []),
            "section_types": values_map.get("SECTION_TYPE", []),
            "question_types": values_map.get("QUESTION_TYPE", []),
            "difficulties": values_map.get("QUESTION_DIFFICULTY", []),
            "chapters": chapters,
        }
    }


@router.get("/question-bank/chapters")
async def router_get_question_bank_chapters(
    subject: Optional[str] = None,
    class_name: Optional[str] = None,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_get_question_bank_chapters(subject=subject, class_name=class_name, user=user, school_id=school_id)


@router.get("/question-bank/classes")
async def router_get_question_bank_classes(
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_get_question_bank_classes(user=user, school_id=school_id)


@router.get("/question-bank/export-template")
async def router_export_question_template(type: str = "mcq", subject: Optional[str] = None):
    return await export_question_template(type=type, subject=subject)


@router.post("/question-bank/bulk-upload")
async def router_bulk_upload_questions(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await bulk_upload_questions(request=request, user=user, school_id=school_id)


@router.get("/question-bank")
async def router_get_question_bank(
    subject: Optional[str] = None,
    subject_id: Optional[str] = None,
    difficulty: Optional[str] = None,
    class_name: Optional[str] = None,
    class_id: Optional[str] = None,
    chapter: Optional[str] = None,
    question_type: Optional[str] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    tag: Optional[str] = None,
    page: int = 1,
    page_size: int = 50,
    sort_by: str = "created_at",
    sort_order: str = "desc",
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_get_question_bank(
        subject=subject,
        subject_id=subject_id,
        difficulty=difficulty,
        class_name=class_name,
        class_id=class_id,
        chapter=chapter,
        question_type=question_type,
        status=status,
        search=search,
        tag=tag,
        page=page,
        page_size=page_size,
        sort_by=sort_by,
        sort_order=sort_order,
        user=user,
        school_id=school_id,
    )


@router.post("/question-bank")
async def router_add_question_bank(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_add_question_bank(request=request, user=user, school_id=school_id)


@router.post("/question-bank/{question_id}/duplicate")
async def router_duplicate_question_bank(
    question_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_duplicate_question_bank(question_id=question_id, user=user, school_id=school_id)


@router.post("/question-bank/{question_id}/approve")
async def router_approve_question_bank(
    question_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_approve_question_bank(question_id=question_id, user=user, school_id=school_id)


@router.put("/question-bank/{question_id}")
async def router_update_question_bank(
    question_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_update_question_bank(question_id=question_id, request=request, user=user, school_id=school_id)


@router.delete("/question-bank/{question_id}")
async def router_delete_question_bank(
    question_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_delete_question_bank(question_id=question_id, user=user, school_id=school_id)


@router.post("/question-bank/bulk-action")
async def router_bulk_question_bank_action(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    from app.api.teacher import teacher_bulk_question_bank_action
    return await teacher_bulk_question_bank_action(request=request, user=user, school_id=school_id)


# ============================================================================
# 1. CORE EXAM CRUD & LISTING
# ============================================================================

@router.get("/{exam_id:uuid}")
async def get_single_exam(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Fetch complete exam configuration, question metrics, and status."""
    return await teacher_get_exam_details(exam_id=exam_id, user=user, school_id=school_id)


@router.put("/{exam_id}")
async def update_existing_exam(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Update exam parameters, duration, schedule, or status."""
    return await teacher_update_exam(exam_id=exam_id, request=request, user=user, school_id=school_id)


@router.delete("/{exam_id}")
async def delete_existing_exam(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Delete an exam and cascade delete related sessions and questions."""
    return await teacher_delete_exam(exam_id=exam_id, user=user, school_id=school_id)


# ============================================================================
# 2. EXAM QUESTIONS MANAGEMENT
# ============================================================================

@router.get("/{exam_id}/questions")
async def get_questions(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """List all questions associated with an exam."""
    return await teacher_get_exam_questions(exam_id=exam_id, user=user, school_id=school_id)


@router.post("/{exam_id}/questions")
async def add_question(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Add a question directly to an exam."""
    return await teacher_add_exam_question(exam_id=exam_id, request=request, user=user, school_id=school_id)


@router.put("/{exam_id}/questions/{question_id}")
async def update_question(
    exam_id: str,
    question_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Update an individual question within an exam."""
    return await teacher_update_exam_question(
        exam_id=exam_id,
        question_id=question_id,
        request=request,
        user=user,
        school_id=school_id,
    )


@router.delete("/{exam_id}/questions/{question_id}")
async def delete_question(
    exam_id: str,
    question_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Delete a question from an exam."""
    return await teacher_delete_exam_question(
        exam_id=exam_id,
        question_id=question_id,
        user=user,
        school_id=school_id,
    )


# ============================================================================
# 2.1 EXAM SECTIONS & ADVANCED PAPER BUILDER
# ============================================================================

@router.get("/{exam_id}/sections")
async def get_exam_sections(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Retrieve all sections and organized questions for this examination."""
    sb = get_supabase()
    sec_res = await sb.table("exam_sections").select("*").eq("exam_id", exam_id).order("sequence_number").aexecute()
    sections = sec_res.data or []
    
    q_res = await sb.table("exam_questions").select("*").eq("exam_id", exam_id).order("order_number").aexecute()
    questions = q_res.data or []
    
    sec_map = {s["id"]: {**s, "questions": []} for s in sections}
    unassigned = []
    for q in questions:
        sid = q.get("section_id")
        if sid and sid in sec_map:
            sec_map[sid]["questions"].append(q)
        else:
            unassigned.append(q)
            
    sections_list = list(sec_map.values())
    total_marks = sum(int(q.get("marks") or 1) for q in questions)
    
    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "sections": sections_list,
            "unassigned_questions": unassigned,
            "total_questions": len(questions),
            "total_marks": total_marks,
        }
    }


@router.post("/{exam_id}/sections")
async def create_exam_section(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Add a new section to the exam."""
    sb = get_supabase()
    sec_res = await sb.table("exam_sections").select("sequence_number").eq("exam_id", exam_id).aexecute()
    next_seq = max([s.get("sequence_number", 0) for s in (sec_res.data or [])] + [0]) + 1
    
    new_sec = {
        "school_id": school_id,
        "exam_id": exam_id,
        "name": request.get("name", f"Section {chr(64 + next_seq)}"),
        "section_code": request.get("section_code", chr(64 + next_seq)),
        "description": request.get("description", ""),
        "instructions": request.get("instructions", ""),
        "sequence_number": request.get("sequence_number", next_seq),
        "marks_per_question": float(request.get("marks_per_question", 1.0)),
        "max_marks": float(request.get("max_marks", 0.0)),
        "min_attempt": int(request.get("min_attempt", 0)),
        "max_attempt": int(request.get("max_attempt", 0)),
        "is_optional": bool(request.get("is_optional", False)),
    }
    res = await sb.table("exam_sections").insert(new_sec).aexecute()
    return {"success": True, "school_id": school_id, "data": res.data[0]}


@router.put("/{exam_id}/sections/{section_id}")
async def update_exam_section(
    exam_id: str,
    section_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Update section configuration."""
    sb = get_supabase()
    allowed = {"name", "section_code", "description", "instructions", "sequence_number", "marks_per_question", "max_marks", "min_attempt", "max_attempt", "is_optional"}
    updates = {k: v for k, v in request.items() if k in allowed}
    res = await sb.table("exam_sections").update(updates).eq("id", section_id).eq("exam_id", exam_id).aexecute()
    return {"success": True, "school_id": school_id, "data": res.data[0] if res.data else {}}


@router.delete("/{exam_id}/sections/{section_id}")
async def delete_exam_section(
    exam_id: str,
    section_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Delete a section and unassign questions."""
    sb = get_supabase()
    await sb.table("exam_questions").update({"section_id": None, "section_name": None}).eq("section_id", section_id).aexecute()
    await sb.table("exam_sections").delete().eq("id", section_id).eq("exam_id", exam_id).aexecute()
    return {"success": True, "school_id": school_id, "message": "Section removed successfully"}


@router.post("/{exam_id}/sections/reorder")
async def reorder_exam_sections(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Reorder sequence of sections in paper."""
    sb = get_supabase()
    section_ids = request.get("section_ids", [])
    for idx, sid in enumerate(section_ids):
        await sb.table("exam_sections").update({"sequence_number": idx + 1}).eq("id", sid).eq("exam_id", exam_id).aexecute()
    return {"success": True, "school_id": school_id, "message": "Sections reordered successfully"}


@router.post("/{exam_id}/questions/bulk-add")
async def bulk_add_questions_from_bank(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Add selected questions from Question Bank directly into the exam and section."""
    sb = get_supabase()
    question_bank_ids = request.get("question_bank_ids", [])
    section_id = request.get("section_id")
    override_marks = request.get("marks")
    
    if not question_bank_ids:
        raise HTTPException(status_code=400, detail="No questions selected to add")
        
    cur_qs = (await sb.table("exam_questions").select("order_number").eq("exam_id", exam_id).aexecute()).data or []
    next_order = max([q.get("order_number", 0) for q in cur_qs] + [0]) + 1
    
    section_name = None
    if section_id:
        sec_res = await sb.table("exam_sections").select("name, marks_per_question").eq("id", section_id).maybe_single().aexecute()
        if sec_res.data:
            section_name = sec_res.data.get("name")
            if override_marks is None and sec_res.data.get("marks_per_question"):
                override_marks = int(sec_res.data.get("marks_per_question"))

    qb_res = await sb.table("question_bank").select("*").in_("id", question_bank_ids).aexecute()
    qb_items = qb_res.data or []
    
    to_insert = []
    for item in qb_items:
        q_marks = override_marks if override_marks is not None else int(item.get("marks") or 1)
        to_insert.append({
            "exam_id": exam_id,
            "school_id": school_id,
            "section_id": section_id,
            "section_name": section_name,
            "question_bank_id": item["id"],
            "question_text": item.get("question_text", ""),
            "question_type": item.get("question_type", "mcq"),
            "options": item.get("options") or [],
            "correct_answer": item.get("correct_answer"),
            "marks": q_marks,
            "order_number": next_order,
            "difficulty": item.get("difficulty", "Easy"),
            "chapter": item.get("chapter"),
            "negative_marks": float(item.get("negative_marks") or 0.0),
            "explanation": item.get("explanation"),
            "model_answer": item.get("model_answer"),
            "is_mandatory": True,
        })
        next_order += 1
        
    if to_insert:
        await sb.table("exam_questions").insert(to_insert).aexecute()
        
    all_qs = (await sb.table("exam_questions").select("marks").eq("exam_id", exam_id).aexecute()).data or []
    total_marks = sum(int(q.get("marks") or 1) for q in all_qs)
    await sb.table("exams").update({
        "total_questions_count": len(all_qs),
        "updated_at": datetime.utcnow().isoformat(),
    }).eq("id", exam_id).aexecute()
    
    return {
        "success": True,
        "school_id": school_id,
        "added_count": len(to_insert),
        "total_questions": len(all_qs),
        "total_marks": total_marks
    }


@router.post("/{exam_id}/questions/reorder")
async def reorder_exam_questions(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Reorder and re-assign questions across sections."""
    sb = get_supabase()
    items = request.get("items", [])
    for it in items:
        qid = it.get("id")
        updates = {"order_number": it.get("order_number", 1)}
        if "section_id" in it:
            updates["section_id"] = it.get("section_id")
        await sb.table("exam_questions").update(updates).eq("id", qid).eq("exam_id", exam_id).aexecute()
        
    return {"success": True, "school_id": school_id, "message": "Questions reordered successfully"}


@router.post("/{exam_id}/randomize")
async def randomize_exam_questions(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Randomize question sequence and option orders within sections."""
    import random
    sb = get_supabase()
    shuffle_options = request.get("shuffle_options", False)
    
    q_res = await sb.table("exam_questions").select("*").eq("exam_id", exam_id).aexecute()
    questions = q_res.data or []
    
    sec_groups = {}
    for q in questions:
        sid = q.get("section_id") or "unassigned"
        sec_groups.setdefault(sid, []).append(q)
        
    global_order = 1
    for sid, group in sec_groups.items():
        random.shuffle(group)
        for q in group:
            updates = {"order_number": global_order}
            if shuffle_options and q.get("options") and isinstance(q.get("options"), list) and len(q["options"]) > 1:
                opts = list(q["options"])
                random.shuffle(opts)
                updates["options"] = opts
            await sb.table("exam_questions").update(updates).eq("id", q["id"]).aexecute()
            global_order += 1
            
    return {"success": True, "school_id": school_id, "message": "Exam questions randomized successfully"}


@router.post("/{exam_id}/clear-all")
async def clear_all_exam_questions(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Clear all questions from exam paper."""
    sb = get_supabase()
    await sb.table("exam_questions").delete().eq("exam_id", exam_id).aexecute()
    await sb.table("exams").update({
        "total_questions_count": 0,
        "status": "new",
        "updated_at": datetime.utcnow().isoformat()
    }).eq("id", exam_id).aexecute()
    return {"success": True, "school_id": school_id, "message": "All questions cleared successfully"}


@router.get("/{exam_id}/preview")
async def get_paper_preview(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Return fully formatted question paper preview (student copy and teacher marking scheme)."""
    sb = get_supabase()
    exam_res = await sb.table("exams").select("*, subjects(name)").eq("id", exam_id).maybe_single().aexecute()
    exam = exam_res.data or {}
    
    school_res = await sb.table("schools").select("name, logo_url, address, phone, board").eq("id", school_id).maybe_single().aexecute()
    school = school_res.data or {}
    
    sec_res = await sb.table("exam_sections").select("*").eq("exam_id", exam_id).order("sequence_number").aexecute()
    sections = sec_res.data or []
    
    q_res = await sb.table("exam_questions").select("*").eq("exam_id", exam_id).order("order_number").aexecute()
    questions = q_res.data or []
    
    sec_map = {s["id"]: {**s, "questions": []} for s in sections}
    unassigned = []
    for q in questions:
        sid = q.get("section_id")
        if sid and sid in sec_map:
            sec_map[sid]["questions"].append(q)
        else:
            unassigned.append(q)
            
    organized_sections = list(sec_map.values())
    if unassigned:
        organized_sections.append({
            "id": None,
            "name": "General Questions",
            "section_code": "G",
            "instructions": "",
            "sequence_number": len(organized_sections) + 1,
            "questions": unassigned
        })
        
    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "institute": {
                "name": school.get("name", "EduSHAMIIT International School"),
                "logo_url": school.get("logo_url"),
                "address": school.get("address", "Campus Academic Complex"),
            },
            "exam": {
                "id": exam.get("id"),
                "title": exam.get("title", "Question Paper"),
                "subject": exam.get("subjects", {}).get("name") if isinstance(exam.get("subjects"), dict) else (exam.get("subject") or "Mathematics"),
                "target_classes": exam.get("target_classes") or ["Class 10"],
                "paper_type": exam.get("paper_type", "Final Exam"),
                "paper_status": exam.get("paper_status", "Draft"),
                "total_marks": exam.get("total_marks", 100),
                "duration_minutes": exam.get("duration_minutes", 120),
                "exam_date": str(exam.get("exam_date") or "2026-03-15"),
                "instructions": exam.get("instructions") or "1. All questions are compulsory.\n2. Write clearly and legibly.\n3. Verify question count before beginning.",
            },
            "sections": organized_sections,
            "total_questions": len(questions),
            "calculated_total_marks": sum(int(q.get("marks") or 1) for q in questions),
        }
    }


@router.post("/{exam_id}/save-paper")
async def save_paper_configuration(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Save paper metadata, duration, instructions and take a version snapshot."""
    sb = get_supabase()
    allowed = {"title", "instructions", "duration_minutes", "total_marks", "paper_type", "paper_status", "academic_session"}
    updates = {k: v for k, v in request.items() if k in allowed}
    updates["updated_at"] = datetime.utcnow().isoformat()
    
    await sb.table("exams").update(updates).eq("id", exam_id).aexecute()
    
    cur_versions = (await sb.table("exam_paper_versions").select("version_number").eq("exam_id", exam_id).aexecute()).data or []
    next_ver = max([v.get("version_number", 0) for v in cur_versions] + [0]) + 1
    
    preview_res = await get_paper_preview(exam_id=exam_id, user=user, school_id=school_id)
    snapshot = preview_res.get("data", {})
    
    await sb.table("exam_paper_versions").insert({
        "exam_id": exam_id,
        "school_id": school_id,
        "version_number": next_ver,
        "paper_title": request.get("title") or snapshot.get("exam", {}).get("title", "Exam Paper"),
        "snapshot": snapshot,
        "saved_by": user.get("id"),
        "notes": request.get("notes", f"Saved version {next_ver}"),
    }).aexecute()
    
    return {
        "success": True,
        "school_id": school_id,
        "version": next_ver,
        "message": f"Paper saved successfully (Version {next_ver})"
    }


# ============================================================================
# 3. ATTENDANCE & PROCTORING (ONLINE / OFFLINE)
# ============================================================================

@router.get("/{exam_id}/attendance")
async def get_attendance(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Get manual attendance roster for offline exams."""
    return await teacher_get_exam_attendance(exam_id=exam_id, user=user, school_id=school_id)


@router.post("/{exam_id}/attendance")
async def save_attendance(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Save manual attendance records for offline exams."""
    return await teacher_save_exam_attendance(exam_id=exam_id, request=request, user=user, school_id=school_id)


@router.get("/{exam_id}/sessions")
async def get_sessions(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Get active student proctoring sessions for live monitoring."""
    return await teacher_get_exam_sessions(exam_id=exam_id, user=user, school_id=school_id)


@router.post("/{exam_id}/sessions/{session_id}/action")
async def send_action(
    exam_id: str,
    session_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Send proctor action command (warn, pause, extend, submit, etc.)."""
    return await teacher_proctor_action(
        exam_id=exam_id,
        session_id=session_id,
        request=request,
        user=user,
        school_id=school_id,
    )


# ============================================================================
# 4. SUBMISSIONS, GRADING & PUBLISHING
# ============================================================================

@router.get("/{exam_id}/submissions")
async def get_submissions(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Get student submissions for evaluation."""
    return await teacher_get_exam_submissions(exam_id=exam_id, user=user, school_id=school_id)


@router.post("/{exam_id}/submissions/{submission_id}/grade")
async def grade_submission(
    exam_id: str,
    submission_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Grade a student submission with score, remarks, and subjective breakdown."""
    return await teacher_grade_exam_submission(
        exam_id=exam_id,
        submission_id=submission_id,
        request=request,
        user=user,
        school_id=school_id,
    )


# ============================================================================
# EXAM SCHEDULES (DATE SHEET) & CONFLICT CHECKING
# ============================================================================

@router.get("/{exam_id}/schedules")
async def get_exam_schedules(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Retrieve date sheet / examination schedule for all subjects."""
    sb = get_supabase()
    res = await sb.table("exam_schedules").select("*, subjects(name)").eq("exam_id", exam_id).order("exam_date").order("start_time").aexecute()
    return {"success": True, "school_id": school_id, "data": res.data or []}


@router.post("/{exam_id}/schedules")
async def create_exam_schedule(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Create a date sheet schedule item with conflict checking for hall and invigilator."""
    sb = get_supabase()
    exam_date = request.get("exam_date") or date.today().isoformat()
    start_time = request.get("start_time") or "09:00:00"
    end_time = request.get("end_time") or "11:00:00"
    room = request.get("room_number") or "Hall 101"
    invigilator = request.get("invigilator_name") or "Assigned Faculty"
    class_name = request.get("class_name") or "Class 10"
    subject_name = request.get("subject_name") or "Mathematics"

    conflicts = []
    conflict_res = await sb.table("exam_schedules").select("*").eq("school_id", school_id).eq("exam_date", exam_date).aexecute()
    for row in (conflict_res.data or []):
        r_start = str(row.get("start_time"))
        r_end = str(row.get("end_time"))
        if not (end_time <= r_start or start_time >= r_end):
            if row.get("room_number") == room:
                conflicts.append(f"Room {room} is already allocated for {row.get('subject_name')} ({r_start[:5]}-{r_end[:5]})")
            if row.get("invigilator_name") == invigilator:
                conflicts.append(f"Invigilator {invigilator} is already on duty for {row.get('subject_name')}")

    if conflicts and not request.get("ignore_conflicts", False):
        return {
            "success": False,
            "has_conflict": True,
            "conflicts": conflicts,
            "message": "Schedule conflict detected: " + "; ".join(conflicts)
        }

    new_schedule = {
        "school_id": school_id,
        "exam_id": exam_id,
        "academic_session": request.get("academic_session", "2025-26"),
        "class_name": class_name,
        "section_name": request.get("section_name", "A"),
        "subject_id": request.get("subject_id"),
        "subject_name": subject_name,
        "exam_date": exam_date,
        "start_time": start_time,
        "end_time": end_time,
        "duration_minutes": int(request.get("duration_minutes") or 120),
        "max_marks": int(request.get("max_marks") or 100),
        "passing_marks": int(request.get("passing_marks") or 33),
        "room_number": room,
        "invigilator_name": invigilator,
        "status": request.get("status", "scheduled"),
    }
    res = await sb.table("exam_schedules").insert(new_schedule).aexecute()
    return {"success": True, "school_id": school_id, "data": res.data[0]}


# ============================================================================
# MARKS ENTRY & EVALUATION ROSTER
# ============================================================================

@router.get("/{exam_id}/marks")
async def get_exam_marks_entries(
    exam_id: str,
    subject_id: Optional[str] = None,
    class_name: Optional[str] = None,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Retrieve marks entry roster for this examination."""
    sb = get_supabase()
    query = sb.table("exam_marks_entries").select("*").eq("exam_id", exam_id)
    if subject_id:
        query = query.eq("subject_id", subject_id)
    entries = (await query.order("roll_number").aexecute()).data or []

    if not entries:
        exam_res = await sb.table("exams").select("target_classes, total_marks, passing_marks").eq("id", exam_id).maybe_single().aexecute()
        exam_data = exam_res.data or {}
        target_classes = exam_data.get("target_classes") or ["Class 10"]
        c_name = class_name or (target_classes[0] if isinstance(target_classes, list) and target_classes else "Class 10")

        st_query = sb.table("profiles").select("id, full_name, roll_number, class, admission_number").eq("school_id", school_id).eq("role", "student")
        if c_name:
            st_query = st_query.eq("class", c_name)
        st_res = await st_query.order("roll_number").limit(40).aexecute()
        students = st_res.data or []
        if not students:
            st_res = await sb.table("profiles").select("id, full_name, roll_number, class, admission_number").eq("school_id", school_id).eq("role", "student").limit(20).aexecute()
            students = st_res.data or []

        for idx, st in enumerate(students):
            full_name = st.get("full_name") or f"Student {idx+1}"
            entries.append({
                "student_id": st["id"],
                "student_name": full_name,
                "roll_number": st.get("roll_number") or str(idx + 1),
                "class_name": st.get("class", c_name),
                "section_name": "A",
                "attendance_status": "present",
                "max_marks": exam_data.get("total_marks", 100),
                "theory_marks": None,
                "practical_marks": None,
                "internal_marks": None,
                "total_marks_obtained": None,
                "percentage": None,
                "grade": None,
                "approval_status": "draft",
            })

    return {"success": True, "school_id": school_id, "data": entries}


@router.post("/{exam_id}/marks")
async def save_exam_marks_entries(
    exam_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Save multi-component marks entries with automated percentage and grading calculation."""
    sb = get_supabase()
    entries = request.get("entries", [])
    subject_id = request.get("subject_id")
    subject_name = request.get("subject_name", "General")

    def calc_grade(pct: float) -> str:
        if pct >= 91: return "A1"
        if pct >= 81: return "A2"
        if pct >= 71: return "B1"
        if pct >= 61: return "B2"
        if pct >= 51: return "C1"
        if pct >= 41: return "C2"
        if pct >= 33: return "D"
        return "E"

    entered_by_val = user.get("id")
    try:
        prof_chk = await sb.table("profiles").select("id").eq("id", entered_by_val).maybe_single().aexecute()
        if not prof_chk.data:
            entered_by_val = None
    except Exception:
        entered_by_val = None

    saved_count = 0
    for ent in entries:
        t_marks = float(ent.get("theory_marks") or 0.0) if ent.get("theory_marks") is not None else None
        p_marks = float(ent.get("practical_marks") or 0.0) if ent.get("practical_marks") is not None else None
        i_marks = float(ent.get("internal_marks") or 0.0) if ent.get("internal_marks") is not None else None
        
        total_obt = 0.0
        has_val = False
        if ent.get("marks_obtained") is not None and t_marks is None and p_marks is None and i_marks is None:
            t_marks = float(ent.get("marks_obtained"))
            total_obt = t_marks
            has_val = True
        else:
            if t_marks is not None: total_obt += t_marks; has_val = True
            if p_marks is not None: total_obt += p_marks; has_val = True
            if i_marks is not None: total_obt += i_marks; has_val = True

        max_m = float(ent.get("max_marks") or 100.0)
        pct = round((total_obt / max_m) * 100, 2) if (has_val and max_m > 0) else None
        grade = calc_grade(pct) if pct is not None else None

        row = {
            "school_id": school_id,
            "exam_id": exam_id,
            "student_id": ent.get("student_id"),
            "student_name": ent.get("student_name", "Student"),
            "roll_number": str(ent.get("roll_number") or ""),
            "class_name": ent.get("class_name", "Class 10"),
            "section_name": ent.get("section_name", "A"),
            "subject_id": subject_id,
            "max_marks": max_m,
            "theory_marks": t_marks,
            "practical_marks": p_marks,
            "internal_marks": i_marks,
            "total_marks_obtained": total_obt if has_val else None,
            "percentage": pct,
            "grade": grade,
            "attendance_status": ent.get("attendance_status", "present"),
            "approval_status": ent.get("approval_status", "draft"),
            "entered_by": entered_by_val,
        }
        existing = await sb.table("exam_marks_entries").select("id").eq("exam_id", exam_id).eq("student_id", ent.get("student_id")).maybe_single().aexecute()
        if existing.data:
            await sb.table("exam_marks_entries").update(row).eq("id", existing.data["id"]).aexecute()
        else:
            await sb.table("exam_marks_entries").insert(row).aexecute()
        saved_count += 1

    return {"success": True, "school_id": school_id, "saved_count": saved_count, "message": "Marks saved successfully"}


@router.post("/{exam_id}/results/calculate")
async def calculate_exam_results(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Aggregate marks, compute pass rates, average, highest, lowest scores and persist to exam."""
    sb = get_supabase()
    entries_res = await sb.table("exam_marks_entries").select("*").eq("exam_id", exam_id).aexecute()
    entries = entries_res.data or []
    
    appeared = [e for e in entries if e.get("attendance_status") == "present" and e.get("total_marks_obtained") is not None]
    total_appeared = len(appeared)
    
    exam_res = await sb.table("exams").select("total_marks, passing_marks").eq("id", exam_id).maybe_single().aexecute()
    exam = exam_res.data or {}
    passing_marks = float(exam.get("passing_marks") or 33.0)

    passed = [e for e in appeared if float(e.get("total_marks_obtained") or 0.0) >= passing_marks]
    total_passed = len(passed)
    pass_pct = round((total_passed / total_appeared) * 100, 2) if total_appeared > 0 else 0.0

    scores = [float(e.get("total_marks_obtained") or 0.0) for e in appeared]
    avg_score = round(sum(scores) / total_appeared, 2) if total_appeared > 0 else 0.0
    highest = max(scores) if scores else 0.0
    lowest = min(scores) if scores else 0.0

    updates = {
        "total_students_appeared": total_appeared,
        "total_students_passed": total_passed,
        "pass_percentage": pass_pct,
        "average_score": avg_score,
        "highest_score": highest,
        "lowest_score": lowest,
        "updated_at": datetime.utcnow().isoformat(),
    }
    await sb.table("exams").update(updates).eq("id", exam_id).aexecute()

    return {
        "success": True,
        "school_id": school_id,
        "calculated_count": total_appeared,
        "metrics": updates
    }


@router.get("/{exam_id}/results")
async def get_exam_results(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Retrieve full exam results with ranked students."""
    sb = get_supabase()
    exam_res = await sb.table("exams").select("*").eq("id", exam_id).maybe_single().aexecute()
    exam = exam_res.data or {}
    entries_res = await sb.table("exam_marks_entries").select("*").eq("exam_id", exam_id).order("total_marks_obtained", ascending=False).aexecute()
    entries = entries_res.data or []

    for idx, e in enumerate(entries):
        e["rank"] = idx + 1

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "exam": exam,
            "results": entries,
            "total_students": len(entries),
            "pass_percentage": exam.get("pass_percentage", 0.0),
            "average_score": exam.get("average_score", 0.0),
            "is_published": exam.get("is_published", False),
        }
    }


@router.post("/{exam_id}/results/publish")
async def publish_results(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Publish results to students and assign computed class ranks."""
    return await teacher_publish_exam_results(exam_id=exam_id, user=user, school_id=school_id)


@router.get("/{exam_id}/analytics")
async def get_analytics(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Retrieve full exam performance analytics and question breakdown."""
    return await teacher_get_exam_analytics(exam_id=exam_id, user=user, school_id=school_id)


@router.get("/{exam_id}/pdf")
async def download_pdf(
    exam_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Download exam paper formatted as printable PDF."""
    return await teacher_download_exam_pdf(exam_id=exam_id, user=user, school_id=school_id)


# ============================================================================
# 5. AI GENERATION & PAPER BUILDER
# ============================================================================

@router.post("/generate-questions")
async def generate_questions(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Generate exam questions via AI."""
    return await generate_exam_questions(request=request, user=user, school_id=school_id)


@router.post("/paper-builder/generate")
async def auto_generate_paper(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Auto-assemble exam paper from question bank matching distribution criteria."""
    sb = get_supabase()
    subject_name = request.get("subject", "")
    class_id = request.get("class", "")
    total_marks = int(request.get("total_marks", 100))
    distribution = request.get("question_distribution", {})

    # Fetch matching questions from question bank
    query = sb.table("question_bank").select("*, subjects(name)").eq("school_id", school_id)
    if subject_name and subject_name != "All":
        subj_res = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name).aexecute()
        if subj_res.data:
            subj_ids = [s["id"] for s in subj_res.data]
            query = query.in_("subject_id", subj_ids)
    
    q_data = (await query.order("created_at", ascending=False).aexecute()).data or []
    
    selected_questions = []
    current_marks = 0

    if distribution:
        for q_type, count in distribution.items():
            type_qs = [q for q in q_data if q.get("question_type") == q_type][:count]
            selected_questions.extend(type_qs)
    else:
        for q in q_data:
            m = int(q.get("marks") or 1)
            if current_marks + m <= total_marks:
                selected_questions.append(q)
                current_marks += m
            if current_marks >= total_marks:
                break

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "title": request.get("title", "Generated Paper"),
            "questions": selected_questions,
            "total_marks": sum(int(q.get("marks") or 1) for q in selected_questions),
            "question_count": len(selected_questions),
        }
    }


# ============================================================================
# 6. GENERIC META HELPERS FOR DROPDOWNS (CLASSES, SUBJECTS, STUDENTS)
# ============================================================================

@router.get("/meta/classes")
async def get_meta_classes(
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Returns classes available for exams (assigned classes for teacher, all classes for admin)."""
    return await teacher_classes(user=user, school_id=school_id)


@router.get("/meta/subjects")
async def get_meta_subjects(
    class_name: Optional[str] = None,
    all_subjects: Optional[bool] = False,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Returns subjects for exam creation (teacher assigned subjects or all school subjects)."""
    return await teacher_subjects(
        class_name=class_name,
        all_subjects=all_subjects,
        user=user,
        school_id=school_id,
    )


@router.get("/meta/students")
async def get_meta_students(
    class_name: str = "",
    search: str = "",
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Returns student roster for exam assignment (works for both teacher and admin)."""
    return await teacher_students(
        class_name=class_name,
        search=search,
        user=user,
        school_id=school_id,
    )


@router.get("/meta/users")
async def search_exam_target_users(
    search: str = Query("", description="Search user by name, email, employee id or roll number"),
    role: str = Query("all", description="Filter role: all, student, teacher, staff, hr, etc."),
    limit: int = Query(30, ge=1, le=100),
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Search users (students, staff, teachers, new joiners) for targeted examination scheduling."""
    sb = get_supabase()
    res = await sb.rpc("sp_search_exam_target_users", {
        "p_school_id": school_id,
        "p_search": search,
        "p_role": role,
        "p_limit": limit
    }).aexecute()
    users_data = (res.data or {}).get("users", []) if res else []
    return {"success": True, "school_id": school_id, "data": users_data, "users": users_data}


@router.post("/meta/users/batch")
async def get_exam_target_users_batch(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    """Fetch user profile details by IDs for target user chip rendering."""
    sb = get_supabase()
    raw_ids = request.get("user_ids") or []
    # filter valid uuid strings
    valid_ids = [uid for uid in raw_ids if isinstance(uid, str) and len(uid) == 36]
    res = await sb.rpc("sp_get_exam_target_users_by_ids", {
        "p_school_id": school_id,
        "p_user_ids": valid_ids
    }).aexecute()
    users_data = (res.data or {}).get("users", []) if res else []
    return {"success": True, "school_id": school_id, "data": users_data, "users": users_data}


# ============================================================================
# 5. UNIVERSAL / GENERIC TAKE EXAM ENGINE (STUDENT, TEACHER, ONBOARDING, ADMIN)
# ============================================================================

def _ensure_uuid_or_404(val: str, label: str = "Examination") -> str:
    try:
        return str(uuid.UUID(str(val)))
    except Exception:
        raise HTTPException(status_code=404, detail=f"{label} not found")


def _optional_uuid(val: Any) -> Optional[str]:
    if not val:
        return None
    try:
        return str(uuid.UUID(str(val)))
    except Exception:
        return None


def _unwrap_rpc_result(res: Any) -> Dict[str, Any]:
    data = getattr(res, "data", res)
    if isinstance(data, list):
        data = data[0] if data else {}
    return data if isinstance(data, dict) else {}


async def _execute_exam_rpc(
    sb: Any,
    fn_name: str,
    params: Dict[str, Any],
) -> Dict[str, Any]:
    try:
        res = await sb.rpc(fn_name, params).aexecute()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Database procedure {fn_name} failed: {exc}") from exc

    payload = _unwrap_rpc_result(res)
    if not payload:
        raise HTTPException(status_code=500, detail=f"Empty response from {fn_name}")
    if payload.get("success") is False:
        raise HTTPException(
            status_code=int(payload.get("status") or 400),
            detail=payload.get("error") or "Operation failed",
        )
    return payload


@router.get("/{exam_id}/prestart")
async def get_exam_prestart_info(
    exam_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Returns full examination pre-start metadata, dynamic tri-state readiness policy,
    categorized instructions, warnings, role customization permissions, and existing session state
    via PostgreSQL stored procedure `rpc_get_exam_prestart_info`.
    """
    sb = get_supabase()
    return await _execute_exam_rpc(
        sb,
        "rpc_get_exam_prestart_info",
        {
            "p_exam_id": _ensure_uuid_or_404(exam_id, "Examination"),
            "p_user_id": str(user.get("id")),
            "p_school_id": _optional_uuid(school_id),
        },
    )


@router.put("/{exam_id}/prestart/config")
async def update_prestart_config(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Allows Exam Setters / Admins to customize dynamic Pre-Start Proctoring Policies
    (Camera, Microphone, Screen Share, Device Checks: REQUIRED / OPTIONAL / DISABLED)
    via PostgreSQL stored procedure `rpc_update_exam_prestart_config`.
    """
    sb = get_supabase()
    return await _execute_exam_rpc(
        sb,
        "rpc_update_exam_prestart_config",
        {
            "p_exam_id": _ensure_uuid_or_404(exam_id, "Examination"),
            "p_user_id": str(user.get("id")),
            "p_config": request or {},
        },
    )


@router.put("/{exam_id}/prestart/instructions")
async def save_prestart_instructions(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Allows Exam Setters / Admins to save customized per-exam categorized instructions
    via PostgreSQL stored procedure `rpc_save_exam_prestart_instructions`.
    """
    sb = get_supabase()
    instructions_payload = request.get("instructions") if "instructions" in request else {}
    return await _execute_exam_rpc(
        sb,
        "rpc_save_exam_prestart_instructions",
        {
            "p_exam_id": _ensure_uuid_or_404(exam_id, "Examination"),
            "p_user_id": str(user.get("id")),
            "p_school_id": _optional_uuid(school_id),
            "p_instructions": instructions_payload,
        },
    )


@router.post("/{exam_id}/prestart/checks")
async def record_prestart_checks(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Persist device readiness and permission test results via PostgreSQL stored procedure
    `rpc_record_exam_prestart_checks`.
    """
    sb = get_supabase()
    return await _execute_exam_rpc(
        sb,
        "rpc_record_exam_prestart_checks",
        {
            "p_exam_id": _ensure_uuid_or_404(exam_id, "Examination"),
            "p_user_id": str(user.get("id")),
            "p_school_id": _optional_uuid(school_id),
            "p_payload": request or {},
        },
    )


@router.post("/{exam_id}/prestart/acknowledgment")
async def record_prestart_acknowledgment(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Persist candidate acknowledgment of examination rules and warnings via PostgreSQL stored
    procedure `rpc_record_exam_prestart_acknowledgment`.
    """
    sb = get_supabase()
    return await _execute_exam_rpc(
        sb,
        "rpc_record_exam_prestart_acknowledgment",
        {
            "p_exam_id": _ensure_uuid_or_404(exam_id, "Examination"),
            "p_user_id": str(user.get("id")),
            "p_school_id": _optional_uuid(school_id),
            "p_acknowledged": bool((request or {}).get("acknowledged", True)),
        },
    )


@router.get("/{exam_id}/take-info")
async def get_exam_take_info(
    exam_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Returns full examination information needed to render the Take Exam interface via PostgreSQL
    stored procedure `rpc_get_exam_take_info`. Sanitizes questions to strip answer keys and explanations.
    """
    sb = get_supabase()
    return await _execute_exam_rpc(
        sb,
        "rpc_get_exam_take_info",
        {
            "p_exam_id": _ensure_uuid_or_404(exam_id, "Examination"),
            "p_user_id": str(user.get("id")),
            "p_school_id": _optional_uuid(school_id),
        },
    )


@router.post("/{exam_id}/session/start")
async def start_exam_session(
    exam_id: str,
    request: Optional[dict] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Start or resume a candidate's exam session. Calculates server-authoritative timer.
    """
    sb = get_supabase()
    user_id = user.get("id")
    request = request or {}
    passcode = request.get("passcode")

    # 1. Verify exam
    exam_res = await sb.table("exams").select("*").eq("id", exam_id).maybe_single().aexecute()
    exam = exam_res.data
    if not exam:
        raise HTTPException(status_code=404, detail="Examination not found")

    if exam.get("passcode") and exam.get("passcode").strip():
        if not passcode or passcode.strip() != exam.get("passcode").strip():
            raise HTTPException(status_code=403, detail="Invalid exam access passcode")

    now_utc = datetime.now(timezone.utc)
    duration_mins = exam.get("duration_minutes") or 90

    # Check monitoring session settings
    mon_res = await sb.table("exam_monitoring_sessions").select("*").eq("exam_id", exam_id).maybe_single().aexecute()
    mon_session = mon_res.data or {}
    default_max_reentry = mon_session.get("default_max_reentry_attempts") or 2
    reentry_window_open = mon_session.get("reentry_window_open", True)

    # Check existing submission
    submission_res = await sb.table("exam_submissions").select("*").eq("exam_id", exam_id).eq("student_id", user_id).maybe_single().aexecute()
    existing_sub = submission_res.data
    if existing_sub and existing_sub.get("status") in ("submitted", "graded", "evaluated", "auto_submitted"):
        return {
            "success": True,
            "is_submitted": True,
            "message": "Examination has already been submitted",
            "submission_id": existing_sub["id"],
        }

    # Check existing session
    session_res = await sb.table("exam_sessions").select("*").eq("exam_id", exam_id).eq("student_id", user_id).order("started_at", ascending=False).limit(1).aexecute()
    existing_session = session_res.data[0] if session_res.data else None

    if existing_session:
        ex_status = (existing_session.get("status") or "").lower()
        ex_mon_status = (existing_session.get("monitoring_status") or "").upper()

        if ex_status == "terminated" or ex_mon_status == "TERMINATED":
            return {
                "success": False,
                "is_terminated": True,
                "session_id": existing_session["id"],
                "message": existing_session.get("terminated_reason") or "Your examination attempt was terminated by the invigilator.",
                "saved_answers": existing_sub.get("answers") if existing_sub else {},
            }

        if ex_mon_status in ("SUBMITTED", "AUTO_SUBMITTED") or ex_status in ("completed", "submitted"):
            return {
                "success": True,
                "is_submitted": True,
                "message": "Examination has already been completed",
                "submission_id": existing_sub["id"] if existing_sub else None,
            }

        started_at = parse(existing_session["started_at"]) if isinstance(existing_session["started_at"], str) else existing_session["started_at"]
        if started_at.tzinfo is None:
            started_at = started_at.replace(tzinfo=timezone.utc)
        extra_mins = existing_session.get("extra_minutes") or 0
        paused_total_sec = existing_session.get("paused_total_seconds") or 0
        is_paused = bool(existing_session.get("is_paused", False) or mon_session.get("status") == "PAUSED")
        pause_offset = paused_total_sec
        if is_paused and (existing_session.get("timer_pause_policy") or "freeze") == "freeze":
            p_at_raw = existing_session.get("paused_at") or mon_session.get("paused_at")
            if p_at_raw:
                p_at = parse(p_at_raw) if isinstance(p_at_raw, str) else p_at_raw
                if p_at.tzinfo is None:
                    p_at = p_at.replace(tzinfo=timezone.utc)
                pause_offset += max(0, int((now_utc - p_at).total_seconds()))

        expires_at = started_at + timedelta(minutes=duration_mins + extra_mins) + timedelta(seconds=pause_offset)
        rem_sec = max(0, int((expires_at - now_utc).total_seconds()))

        if ex_mon_status == "DISCONNECTED":
            reentry_cnt = existing_session.get("reentry_count") or 0
            max_reentry = existing_session.get("max_reentry_attempts") or default_max_reentry
            if not reentry_window_open or reentry_cnt >= max_reentry:
                return {
                    "success": False,
                    "requires_reentry_approval": True,
                    "reentry_window_closed": not reentry_window_open,
                    "session_id": existing_session["id"],
                    "remaining_seconds": rem_sec,
                    "reentry_count": reentry_cnt,
                    "max_reentry_attempts": max_reentry,
                    "message": "Re-entry approval from the invigilator is required to resume this examination.",
                    "saved_answers": existing_sub.get("answers") if existing_sub else {},
                }

        new_mon = "PAUSED" if is_paused else (
            "VIOLATION" if (existing_session.get("warnings_count") or 0) >= 3 else (
                "WARNING" if (existing_session.get("warnings_count") or 0) > 0 else "ACTIVE"
            )
        )
        upd_payload = {
            "last_ping": now_utc.isoformat(),
            "is_online": True,
            "disconnected_at": None,
            "monitoring_status": new_mon,
        }
        if ex_mon_status == "DISCONNECTED":
            upd_payload["reentry_count"] = (existing_session.get("reentry_count") or 0) + 1

        await sb.table("exam_sessions").update(upd_payload).eq("id", existing_session["id"]).aexecute()

        await exam_monitoring_ws_manager.broadcast(
            exam_id=exam_id,
            event="candidate_rejoined" if ex_mon_status == "DISCONNECTED" else "candidate_heartbeat",
            audience="invigilators",
            data={
                "candidate_id": user_id,
                "session_id": existing_session["id"],
                "monitoring_status": new_mon,
                "is_paused": is_paused,
                "remaining_seconds": rem_sec,
            },
        )

        return {
            "success": True,
            "session_id": existing_session["id"],
            "started_at": started_at.isoformat(),
            "expires_at": expires_at.isoformat(),
            "remaining_seconds": rem_sec,
            "resumed": True,
            "is_paused": is_paused,
            "paused_reason": existing_session.get("paused_reason") or mon_session.get("pause_reason"),
            "monitoring_status": new_mon,
            "warnings_count": existing_session.get("warnings_count") or 0,
            "extra_minutes": extra_mins,
            "teacher_message": existing_session.get("teacher_message"),
            "saved_answers": existing_sub.get("answers") if existing_sub else {},
        }

    # Start fresh session
    new_session_id = str(uuid.uuid4())
    started_at = now_utc
    expires_at = started_at + timedelta(minutes=duration_mins)
    q_count_res = await sb.table("exam_questions").select("id").eq("exam_id", exam_id).aexecute()
    total_q = len(q_count_res.data or [])

    await sb.table("exam_sessions").insert({
        "id": new_session_id,
        "exam_id": exam_id,
        "student_id": user_id,
        "school_id": school_id,
        "started_at": started_at.isoformat(),
        "last_ping": started_at.isoformat(),
        "created_at": started_at.isoformat(),
        "status": "in_progress",
        "monitoring_status": "PAUSED" if mon_session.get("status") == "PAUSED" else "ACTIVE",
        "is_paused": mon_session.get("status") == "PAUSED",
        "warnings_count": 0,
        "extra_minutes": mon_session.get("extended_minutes") or 0,
        "max_reentry_attempts": default_max_reentry,
        "total_questions_snapshot": total_q,
        "livekit_identity": f"candidate_{user_id}",
        "is_online": True,
        "camera_active": False,
        "mic_active": False,
        "screen_share_active": False,
        "proctor_logs": [{"time": started_at.strftime("%H:%M:%S"), "event": "Candidate started examination", "severity": "info"}],
    }).aexecute()

    # Create active submission placeholder
    if not existing_sub:
        await sb.table("exam_submissions").insert({
            "id": str(uuid.uuid4()),
            "exam_id": exam_id,
            "student_id": user_id,
            "school_id": school_id,
            "answers": {},
            "status": "active",
            "created_at": started_at.isoformat(),
        }).aexecute()

    try:
        await sb.table("exam_activity_logs").insert({
            "id": str(uuid.uuid4()),
            "school_id": school_id,
            "exam_id": exam_id,
            "action": "session_start",
            "title": "Examination Started",
            "description": f"Candidate {user.get('full_name') or user.get('email')} started examination",
            "performed_by": user_id,
            "performed_by_name": user.get("full_name") or user.get("email"),
            "icon": "play_circle",
            "color": "green",
            "created_at": started_at.isoformat(),
        }).aexecute()
    except Exception:
        pass

    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_id,
        event="candidate_started",
        audience="invigilators",
        data={
            "candidate_id": user_id,
            "session_id": new_session_id,
            "monitoring_status": "ACTIVE",
            "remaining_seconds": duration_mins * 60,
        },
    )

    return {
        "success": True,
        "session_id": new_session_id,
        "started_at": started_at.isoformat(),
        "expires_at": expires_at.isoformat(),
        "remaining_seconds": duration_mins * 60,
        "resumed": False,
        "is_paused": mon_session.get("status") == "PAUSED",
        "monitoring_status": "PAUSED" if mon_session.get("status") == "PAUSED" else "ACTIVE",
        "warnings_count": 0,
        "extra_minutes": mon_session.get("extended_minutes") or 0,
        "saved_answers": {},
    }


@router.post("/{exam_id}/session/save-answer")
async def save_exam_answer(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Persist student draft answers (autosave / debounced save) and sync monitoring progress.
    """
    sb = get_supabase()
    user_id = user.get("id")
    now_utc = datetime.now(timezone.utc)

    # Verify session is not terminated/submitted
    s_chk = (
        await sb.table("exam_sessions")
        .select("id, status, monitoring_status")
        .eq("exam_id", exam_id)
        .eq("student_id", user_id)
        .order("started_at", ascending=False)
        .limit(1)
        .aexecute()
    )
    cur_sess = s_chk.data[0] if s_chk.data else None
    if cur_sess and (
        (cur_sess.get("status") or "").lower() == "terminated"
        or (cur_sess.get("monitoring_status") or "").upper() == "TERMINATED"
    ):
        raise HTTPException(status_code=403, detail="Your examination session was terminated by the invigilator.")

    sub_res = await sb.table("exam_submissions").select("id, status, answers").eq("exam_id", exam_id).eq("student_id", user_id).maybe_single().aexecute()

    if "answers" in request and isinstance(request.get("answers"), dict):
        answers = request.get("answers") or {}
    elif request.get("question_id") is not None:
        existing_ans = (sub_res.data or {}).get("answers") if sub_res.data else {}
        answers = dict(existing_ans or {})
        answers[str(request["question_id"])] = request.get("answer")
        if request.get("current_question_id") is None:
            request["current_question_id"] = str(request["question_id"])
    else:
        answers = request.get("answers") or {}

    current_q_id = request.get("current_question_id")
    current_q_idx = request.get("current_question_index")
    marked_count = request.get("marked_count")
    answered_count = len([k for k, v in answers.items() if v is not None and v != "" and v != [] and v != {}])

    # 1. Update answers in exam_submissions
    if sub_res.data:
        if sub_res.data.get("status") not in ("submitted", "graded", "evaluated"):
            await sb.table("exam_submissions").update({
                "answers": answers,
                "updated_at": now_utc.isoformat(),
            }).eq("id", sub_res.data["id"]).aexecute()
    else:
        await sb.table("exam_submissions").insert({
            "id": str(uuid.uuid4()),
            "exam_id": exam_id,
            "student_id": user_id,
            "school_id": school_id,
            "answers": answers,
            "status": "active",
            "created_at": now_utc.isoformat(),
        }).aexecute()

    # 2. Update active_question, last_ping, last_answer_sync_at and progress counters on session
    session_update: Dict[str, Any] = {
        "last_ping": now_utc.isoformat(),
        "last_answer_sync_at": now_utc.isoformat(),
        "answered_count": answered_count,
        "is_online": True,
    }
    if current_q_id:
        session_update["active_question"] = current_q_id
    if current_q_idx is not None:
        session_update["current_question_index"] = int(current_q_idx)
    if marked_count is not None:
        session_update["marked_count"] = int(marked_count)

    await sb.table("exam_sessions").update(session_update).eq("exam_id", exam_id).eq("student_id", user_id).eq("status", "in_progress").aexecute()

    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_id,
        event="candidate_answer_synced",
        audience="invigilators",
        data={
            "candidate_id": user_id,
            "answered_count": answered_count,
            "last_answer_sync_at": now_utc.isoformat(),
        },
    )

    return {
        "success": True,
        "saved_at": now_utc.isoformat(),
        "answered_count": answered_count,
    }


@router.post("/{exam_id}/session/ping")
async def ping_exam_session(
    exam_id: str,
    request: Optional[dict] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Heartbeat ping from candidate client. Keeps session online and delegates telemetry/proctor events
    through PostgreSQL stored procedure `rpc_record_candidate_heartbeat_and_event`.
    """
    sb = get_supabase()
    user_id = user.get("id")
    request = request or {}
    # Map legacy `event` key to stored procedure `event_type`
    payload = dict(request)
    if payload.get("event") and not payload.get("event_type"):
        payload["event_type"] = str(payload.get("event")).lower().replace(" ", "_")[:60]
        payload.setdefault("title", str(payload.get("event")))

    res_data = await _execute_exam_rpc(sb, "rpc_record_candidate_heartbeat_and_event", {
        "p_school_id": school_id,
        "p_exam_id": _ensure_uuid_or_404(exam_id),
        "p_candidate_id": user_id,
        "p_payload": payload,
    })

    ev_name = "incident_recorded" if res_data.get("incident_id") else "candidate_heartbeat"
    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_id,
        event=ev_name,
        audience="invigilators",
        data={
            "candidate_id": user_id,
            "monitoring_status": res_data.get("monitoring_status"),
            "warnings_count": res_data.get("warnings_count"),
            "is_paused": res_data.get("is_paused"),
            "remaining_seconds": res_data.get("remaining_seconds"),
            "incident_id": res_data.get("incident_id"),
            "telemetry": payload,
        },
    )

    return res_data


@router.post("/{exam_id}/session/submit")
async def submit_exam(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Final submission of the exam paper.
    Auto-grades objective questions, marks subjective questions for grading,
    and syncs results into exam_submissions and exam_marks_entries.
    """
    sb = get_supabase()
    user_id = user.get("id")
    now_utc = datetime.now(timezone.utc)

    answers = request.get("answers") or {}
    is_auto_submit = bool(request.get("is_auto_submit", False))

    # 1. Fetch exam questions with correct_answer and marks
    q_res = await sb.table("exam_questions").select("*").eq("exam_id", exam_id).aexecute()
    questions = q_res.data or []

    exam_res = await sb.table("exams").select("*, subjects(name)").eq("id", exam_id).maybe_single().aexecute()
    exam = exam_res.data or {}
    passing_marks = exam.get("passing_marks") or 33
    negative_marking = bool(exam.get("negative_marking"))

    # 2. Evaluate objective questions
    has_subjective = False
    total_score = 0.0
    correct_count = 0
    incorrect_count = 0
    unanswered_count = 0
    question_results = {}

    for q in questions:
        q_id = str(q["id"])
        q_type = (q.get("question_type") or "mcq").lower()
        marks = float(q.get("marks") or 1.0)
        neg_marks = float(q.get("negative_marks") or 0.0) if negative_marking else 0.0
        correct_ans = q.get("correct_answer")
        candidate_ans = answers.get(q_id)

        # Subjective check
        if q_type in ("subjective", "long", "short", "essay", "descriptive"):
            has_subjective = True
            question_results[q_id] = {
                "status": "pending_evaluation",
                "awarded_marks": None,
                "is_correct": None,
            }
            continue

        if candidate_ans is None or candidate_ans == "":
            unanswered_count += 1
            question_results[q_id] = {
                "status": "unanswered",
                "awarded_marks": 0.0,
                "is_correct": False,
            }
            continue

        # Comparison logic for objective questions
        is_correct = False
        if q_type in ("mcq", "single_select", "true_false", "boolean"):
            is_correct = str(candidate_ans).strip().lower() == str(correct_ans).strip().lower()
        elif q_type in ("multi_select", "multiple_choice"):
            if isinstance(candidate_ans, list) and isinstance(correct_ans, (list, str)):
                c_list = [str(x).strip().lower() for x in (correct_ans if isinstance(correct_ans, list) else correct_ans.split(","))]
                u_list = [str(x).strip().lower() for x in candidate_ans]
                is_correct = set(c_list) == set(u_list)
            else:
                is_correct = str(candidate_ans).strip().lower() == str(correct_ans).strip().lower()
        elif q_type in ("fill_blank", "fill_in_the_blanks", "numerical"):
            try:
                is_correct = math.isclose(float(str(candidate_ans).strip()), float(str(correct_ans).strip()), rel_tol=1e-3)
            except Exception:
                is_correct = str(candidate_ans).strip().lower() == str(correct_ans).strip().lower()
        elif q_type in ("matching", "match_the_following"):
            if isinstance(candidate_ans, dict) and isinstance(correct_ans, dict):
                is_correct = candidate_ans == correct_ans
            else:
                is_correct = str(candidate_ans).strip().lower() == str(correct_ans).strip().lower()
        else:
            is_correct = str(candidate_ans).strip().lower() == str(correct_ans or "").strip().lower()

        if is_correct:
            correct_count += 1
            total_score += marks
            question_results[q_id] = {"status": "correct", "awarded_marks": marks, "is_correct": True}
        else:
            incorrect_count += 1
            total_score = max(0.0, total_score - neg_marks)
            question_results[q_id] = {"status": "incorrect", "awarded_marks": -neg_marks, "is_correct": False}

    submission_status = "submitted" if has_subjective else "graded"
    final_score = total_score if not has_subjective else None
    is_pass = (total_score >= passing_marks) if not has_subjective else None

    # 3. Update exam_submissions
    sub_res = await sb.table("exam_submissions").select("id").eq("exam_id", exam_id).eq("student_id", user_id).maybe_single().aexecute()
    if sub_res.data:
        sub_id = sub_res.data["id"]
        await sb.table("exam_submissions").update({
            "answers": answers,
            "score": final_score,
            "status": submission_status,
            "is_pass": is_pass,
            "submitted_at": now_utc.isoformat(),
            "graded_at": now_utc.isoformat() if not has_subjective else None,
        }).eq("id", sub_id).aexecute()
    else:
        sub_id = str(uuid.uuid4())
        await sb.table("exam_submissions").insert({
            "id": sub_id,
            "exam_id": exam_id,
            "student_id": user_id,
            "school_id": school_id,
            "answers": answers,
            "score": final_score,
            "status": submission_status,
            "is_pass": is_pass,
            "submitted_at": now_utc.isoformat(),
            "graded_at": now_utc.isoformat() if not has_subjective else None,
        }).aexecute()

    # 4. Mark session completed cleanly with monitoring_status transition
    session_res = await sb.table("exam_sessions").select("id, proctor_logs, status, monitoring_status").eq("exam_id", exam_id).eq("student_id", user_id).order("started_at", ascending=False).limit(1).aexecute()
    latest_sess = session_res.data[0] if session_res.data else None
    if latest_sess:
        if (latest_sess.get("monitoring_status") or "").upper() == "TERMINATED" and not is_auto_submit:
            raise HTTPException(status_code=403, detail="Cannot manually submit a session that was terminated by the invigilator.")
        logs = latest_sess.get("proctor_logs") or []
        if not isinstance(logs, list):
            logs = []
        logs.append({
            "time": now_utc.strftime("%H:%M:%S"),
            "event": f"Exam submitted ({'Auto-submitted on timer' if is_auto_submit else 'Submitted by candidate'})",
            "severity": "info",
        })
        await sb.table("exam_sessions").update({
            "status": "completed",
            "monitoring_status": "AUTO_SUBMITTED" if is_auto_submit else "SUBMITTED",
            "is_online": False,
            "is_paused": False,
            "ended_at": now_utc.isoformat(),
            "proctor_logs": logs,
        }).eq("id", latest_sess["id"]).aexecute()

    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_id,
        event="candidate_submitted",
        audience="invigilators",
        data={
            "candidate_id": user_id,
            "monitoring_status": "AUTO_SUBMITTED" if is_auto_submit else "SUBMITTED",
            "submitted_at": now_utc.isoformat(),
        },
    )

    # 5. Record/update exam_marks_entries so marks/results screen has it immediately
    try:
        user_name = user.get("full_name") or user.get("email") or "Candidate"
        max_marks = float(exam.get("total_marks") or (sum(float(q.get("marks") or 1) for q in questions) or 100))
        pct = round((total_score / max_marks) * 100, 2) if max_marks > 0 and not has_subjective else None

        grade_letter = "A" if pct and pct >= 85 else ("B" if pct and pct >= 70 else ("C" if pct and pct >= 50 else ("D" if pct and pct >= 33 else "F")))

        marks_res = await sb.table("exam_marks_entries").select("id").eq("exam_id", exam_id).eq("student_id", user_id).maybe_single().aexecute()
        if marks_res.data:
            await sb.table("exam_marks_entries").update({
                "total_marks_obtained": final_score,
                "theory_marks": final_score,
                "percentage": pct,
                "grade": grade_letter,
                "result_status": "Pass" if is_pass else ("Fail" if is_pass is False else "Pending"),
                "attendance_status": "Present",
                "updated_at": now_utc.isoformat(),
            }).eq("id", marks_res.data["id"]).aexecute()
        else:
            await sb.table("exam_marks_entries").insert({
                "id": str(uuid.uuid4()),
                "school_id": school_id,
                "exam_id": exam_id,
                "student_id": user_id,
                "student_name": user_name,
                "total_marks_obtained": final_score,
                "theory_marks": final_score,
                "max_marks": max_marks,
                "percentage": pct,
                "grade": grade_letter,
                "result_status": "Pass" if is_pass else ("Fail" if is_pass is False else "Pending"),
                "attendance_status": "Present",
                "approval_status": "Submitted",
                "created_at": now_utc.isoformat(),
            }).aexecute()
    except Exception as me_err:
        print(f"[TakeExam] Error updating exam_marks_entries: {me_err}")

    # 6. Log activity
    try:
        await sb.table("exam_activity_logs").insert({
            "id": str(uuid.uuid4()),
            "school_id": school_id,
            "exam_id": exam_id,
            "action": "session_submit",
            "title": "Examination Submitted",
            "description": f"Candidate {user.get('full_name') or user.get('email')} submitted examination. Score: {total_score if not has_subjective else 'Pending'}",
            "performed_by": user_id,
            "performed_by_name": user.get("full_name") or user.get("email"),
            "icon": "check_circle",
            "color": "blue",
            "created_at": now_utc.isoformat(),
        }).aexecute()
    except Exception:
        pass

    return {
        "success": True,
        "submission_id": sub_id,
        "status": submission_status,
        "score": final_score,
        "is_pass": is_pass,
        "total_questions": len(questions),
        "answered_count": len([k for k, v in answers.items() if v is not None and v != ""]),
        "correct_count": correct_count if not has_subjective else None,
        "incorrect_count": incorrect_count if not has_subjective else None,
        "unanswered_count": unanswered_count,
        "submitted_at": now_utc.isoformat(),
    }


# ============================================================================
# 6. ENTERPRISE LIVE EXAMINATION MONITORING & INVIGILATION ENGINE (RPC + LIVEKIT + WS)
# ============================================================================

def _safe_csv_cell(val: Any) -> str:
    """Prevent CSV spreadsheet formula injection when exporting reports."""
    s = "" if val is None else str(val)
    if s and s[0] in ("=", "+", "-", "@", "\t", "\r"):
        return "'" + s
    return s


@router.get("/{exam_id}/monitoring/livekit-token")
@router.post("/{exam_id}/monitoring/livekit-token")
async def get_exam_monitoring_livekit_token(
    exam_id: str,
    request: Request,
    mode: Optional[str] = Query(None, description="'invigilator' or 'candidate'"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Generate a strictly scoped LiveKit room token for live exam proctoring.
    - Invigilators/Admins: canSubscribe=True, canPublish=True, roomAdmin=True
    - Candidates: canPublish=['camera','microphone','screen_share'], canSubscribe=False
      so candidates can never watch other candidates' streams.
    """
    exam_uuid = _ensure_uuid_or_404(exam_id)
    sb = get_supabase()
    user_id = str(user.get("id") or "")
    role = str(user.get("role") or "student").lower()
    display_name = user.get("full_name") or user.get("email") or "User"

    # Determine authorization mode: explicit invigilator vs candidate
    want_invigilator = (mode or "").lower() == "invigilator" or (
        mode is None and role not in ("student", "parent", "candidate", "guest", "applicant")
    )

    is_invigilator = False
    if want_invigilator:
        # Check monitoring permission via RPC helper cleanly
        ov_res = await sb.rpc("rpc_get_exam_monitoring_overview", {
            "p_school_id": school_id,
            "p_exam_id": exam_uuid,
            "p_actor_id": user_id,
            "p_actor_role": role,
        }).aexecute()
        ov_data = _unwrap_rpc_result(ov_res)
        if ov_data.get("success") is True:
            is_invigilator = True
        elif (mode or "").lower() == "invigilator":
            raise HTTPException(
                status_code=int(ov_data.get("status") or 403),
                detail=ov_data.get("error") or "Not authorized to monitor this examination",
            )

    if not is_invigilator:
        # Verify exam exists & belongs to school for candidate
        ex_res = await sb.table("exams").select("id, school_id, status").eq("id", exam_uuid).maybe_single().aexecute()
        ex = ex_res.data
        if not ex:
            raise HTTPException(status_code=404, detail="Examination not found")
        if ex.get("school_id") and str(ex.get("school_id")) != str(school_id):
            raise HTTPException(status_code=403, detail="Tenant isolation violation")

    room_name = f"exam_{exam_uuid}"
    identity = f"invigilator_{user_id}" if is_invigilator else f"candidate_{user_id}"

    api_key = os.environ.get("LIVEKIT_API_KEY", "devkey")
    api_secret = os.environ.get("LIVEKIT_API_SECRET", "secretkey_edushamiit_livekit_2026_secure")
    now = int(time.time())

    video_grant: Dict[str, Any] = {
        "roomJoin": True,
        "room": room_name,
        "canPublish": True,
        "canPublishData": True,
        "canUpdateOwnMetadata": True,
    }
    if is_invigilator:
        video_grant.update({
            "canSubscribe": True,
            "canPublishSources": ["camera", "microphone", "screen_share"],
            "roomAdmin": True,
            "roomCreate": True,
        })
    else:
        video_grant.update({
            "canSubscribe": False,
            "canPublishSources": ["camera", "microphone", "screen_share"],
            "roomAdmin": False,
            "roomCreate": False,
        })

    claims = {
        "iss": api_key,
        "sub": identity,
        "name": display_name,
        "video": video_grant,
        "metadata": json.dumps({
            "role": "invigilator" if is_invigilator else "candidate",
            "user_id": user_id,
            "exam_id": exam_uuid,
        }),
        "nbf": now - 10,
        "exp": now + 6 * 3600,
    }
    lk_token = jwt.encode(claims, api_secret, algorithm="HS256")
    livekit_url = resolve_browser_livekit_url(request)

    return {
        "success": True,
        "token": lk_token,
        "room": room_name,
        "identity": identity,
        "name": display_name,
        "participant_role": "invigilator" if is_invigilator else "candidate",
        "can_subscribe": is_invigilator,
        "livekit_url": livekit_url,
    }


@router.get("/{exam_id}/monitoring/overview")
async def get_exam_monitoring_overview(
    exam_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch complete header context, KPIs, status breakdown, settings, and recent announcements."""
    sb = get_supabase()
    return await _execute_exam_rpc(sb, "rpc_get_exam_monitoring_overview", {
        "p_school_id": school_id,
        "p_exam_id": _ensure_uuid_or_404(exam_id),
        "p_actor_id": user.get("id"),
        "p_actor_role": user.get("role") or "",
    })


@router.get("/{exam_id}/monitoring/candidates")
async def get_exam_monitoring_candidates(
    exam_id: str,
    status: Optional[str] = None,
    violation_filter: Optional[str] = None,
    search: Optional[str] = None,
    class_filter: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(8, ge=1, le=100),
    sort_by: str = "status_priority",
    sort_dir: str = "asc",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Paginated, filtered, and sorted live monitoring roster of candidates."""
    sb = get_supabase()
    return await _execute_exam_rpc(sb, "rpc_get_exam_monitoring_candidates", {
        "p_school_id": school_id,
        "p_exam_id": _ensure_uuid_or_404(exam_id),
        "p_actor_id": user.get("id"),
        "p_actor_role": user.get("role") or "",
        "p_status": status,
        "p_violation_filter": violation_filter,
        "p_search": search,
        "p_class_filter": class_filter,
        "p_page": page,
        "p_page_size": page_size,
        "p_sort_by": sort_by,
        "p_sort_dir": sort_dir,
    })


@router.get("/{exam_id}/monitoring/candidates/{candidate_id}")
async def get_exam_monitoring_candidate_detail(
    exam_id: str,
    candidate_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Detailed monitoring snapshot, incidents, actions, time adjustments & re-entry history for one candidate."""
    sb = get_supabase()
    return await _execute_exam_rpc(sb, "rpc_get_exam_monitoring_candidate_detail", {
        "p_school_id": school_id,
        "p_exam_id": _ensure_uuid_or_404(exam_id),
        "p_candidate_id": _ensure_uuid_or_404(candidate_id, label="Candidate"),
        "p_actor_id": user.get("id"),
        "p_actor_role": user.get("role") or "",
    })


@router.post("/{exam_id}/monitoring/actions")
async def execute_exam_monitoring_action(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Execute an atomic single or bulk invigilator proctoring action:
    warn, pause, resume, extend_time, give_chance, approve_reentry, reject_reentry,
    terminate, force_submit, request_camera, request_mic, request_screen_share,
    force_mute_mic, force_disable_cam, escalate, reopen.
    """
    exam_uuid = _ensure_uuid_or_404(exam_id)
    sb = get_supabase()
    action_type = str(request.get("action_type") or request.get("action") or "").strip().lower()

    candidate_ids = request.get("candidate_ids")
    if not candidate_ids and request.get("candidate_id"):
        candidate_ids = [request.get("candidate_id")]
    # Support lookup by session_id for backward-compatibility callers
    if not candidate_ids and request.get("session_id"):
        s_res = await sb.table("exam_sessions").select("student_id").eq("id", request.get("session_id")).maybe_single().aexecute()
        if s_res.data and s_res.data.get("student_id"):
            candidate_ids = [s_res.data["student_id"]]

    payload = {
        "reason": request.get("reason") or request.get("message") or "",
        "message": request.get("message") or request.get("reason") or "",
        "minutes": request.get("minutes") or 15,
        "timer_pause_policy": request.get("timer_pause_policy") or "freeze",
        "idempotency_key": request.get("idempotency_key"),
        "override": bool(request.get("override", False)),
        "escalate_to": request.get("escalate_to"),
    }

    actor_id = user.get("id")
    actor_name = user.get("full_name") or user.get("email") or "Invigilator"
    actor_role = user.get("role") or ""

    res = await _execute_exam_rpc(sb, "rpc_execute_invigilator_action", {
        "p_school_id": school_id,
        "p_exam_id": exam_uuid,
        "p_actor_id": actor_id,
        "p_actor_name": actor_name,
        "p_actor_role": actor_role,
        "p_action_type": action_type,
        "p_candidate_ids": candidate_ids or [],
        "p_payload": payload,
    })

    affected_results = res.get("results") or []
    affected_cids = [str(r.get("candidate_id")) for r in affected_results if r.get("candidate_id")]

    if affected_cids:
        await exam_monitoring_ws_manager.broadcast(
            exam_id=exam_uuid,
            event="invigilator_action_executed",
            audience="invigilators",
            data={
                "action_type": action_type,
                "actor_name": actor_name,
                "results": affected_results,
            },
        )
        for item in affected_results:
            cid = str(item.get("candidate_id"))
            sid = str(item.get("student_id") or "")
            target_ids = [cid]
            if sid and sid != cid:
                target_ids.append(sid)

            await exam_monitoring_ws_manager.broadcast(
                exam_id=exam_uuid,
                event="invigilator_command",
                audience="candidates",
                target_candidate_ids=target_ids,
                data={
                    "command": action_type,
                    "action_type": action_type,
                    "reason": payload["reason"],
                    "message": payload["message"] or payload["reason"],
                    "minutes": payload["minutes"],
                    "monitoring_status": item.get("monitoring_status"),
                    "is_paused": item.get("is_paused"),
                    "warnings_count": item.get("warnings_count"),
                    "extra_minutes": item.get("extra_minutes"),
                    "remaining_seconds": item.get("remaining_seconds"),
                    "actor_name": actor_name,
                },
            )
            if action_type in ("warn", "terminate", "approve_reentry", "extend_time", "pause", "resume", "force_disable_cam", "enable_cam", "force_mute_mic", "unmute_mic"):
                for notify_uid in target_ids:
                    try:
                        await sb.table("notifications").insert({
                            "id": str(uuid.uuid4()),
                            "school_id": school_id,
                            "user_id": notify_uid,
                            "title": f"Exam Proctoring Notice ({action_type.replace('_', ' ').title()})",
                            "body": payload["reason"] or f"Invigilator issued {action_type.replace('_', ' ')}",
                            "type": "exam_proctoring",
                            "reference_id": exam_uuid,
                            "reference_type": "exam",
                            "priority": "high" if action_type in ("warn", "terminate") else "normal",
                            "category": "Examinations",
                            "created_by": actor_id,
                        }).aexecute()
                    except Exception:
                        pass

    return res


@router.post("/{exam_id}/monitoring/controls")
async def execute_exam_wide_monitoring_control(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Execute exam-wide control actions: pause_exam, resume_exam, extend_exam_deadline, close_reentry, open_reentry, emergency_submit_all, update_settings."""
    exam_uuid = _ensure_uuid_or_404(exam_id)
    sb = get_supabase()
    control_action = str(request.get("control_action") or request.get("action") or "").strip().lower()
    actor_name = user.get("full_name") or user.get("email") or "Invigilator"

    res = await _execute_exam_rpc(sb, "rpc_execute_exam_wide_monitoring_control", {
        "p_school_id": school_id,
        "p_exam_id": exam_uuid,
        "p_actor_id": user.get("id"),
        "p_actor_name": actor_name,
        "p_actor_role": user.get("role") or "",
        "p_control_action": control_action,
        "p_payload": request,
    })

    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_uuid,
        event="exam_control_updated",
        audience="all",
        data={
            "control_action": control_action,
            "status": res.get("status"),
            "reason": request.get("reason") or request.get("message") or "",
            "minutes": request.get("minutes"),
            "actor_name": actor_name,
        },
    )
    return res


@router.get("/{exam_id}/monitoring/incidents")
async def get_exam_monitoring_incidents(
    exam_id: str,
    severity: Optional[str] = None,
    violation_type: Optional[str] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch filtered proctoring violation reports / incident logs."""
    sb = get_supabase()
    return await _execute_exam_rpc(sb, "rpc_get_exam_monitoring_incidents", {
        "p_school_id": school_id,
        "p_exam_id": _ensure_uuid_or_404(exam_id),
        "p_actor_id": user.get("id"),
        "p_actor_role": user.get("role") or "",
        "p_severity": severity,
        "p_violation_type": violation_type,
        "p_status": status,
        "p_search": search,
        "p_page": page,
        "p_page_size": page_size,
    })


@router.post("/{exam_id}/monitoring/incidents/{incident_id}/resolve")
async def resolve_exam_monitoring_incident(
    exam_id: str,
    incident_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Acknowledge, resolve, dismiss, assign, or escalate a proctoring incident."""
    exam_uuid = _ensure_uuid_or_404(exam_id)
    inc_uuid = _ensure_uuid_or_404(incident_id, label="Incident")
    sb = get_supabase()
    res = await _execute_exam_rpc(sb, "rpc_resolve_exam_incident", {
        "p_school_id": school_id,
        "p_exam_id": exam_uuid,
        "p_incident_id": inc_uuid,
        "p_actor_id": user.get("id"),
        "p_actor_name": user.get("full_name") or user.get("email") or "Invigilator",
        "p_actor_role": user.get("role") or "",
        "p_new_status": request.get("status") or "resolved",
        "p_resolution_note": request.get("resolution_note") or request.get("note"),
        "p_assign_to": _optional_uuid(request.get("assign_to")),
    })
    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_uuid,
        event="incident_updated",
        audience="invigilators",
        data={"incident_id": inc_uuid, "status": res.get("status")},
    )
    return res


@router.post("/{exam_id}/monitoring/announcements")
async def create_exam_monitoring_announcement(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Send live announcement to all or filtered candidates and broadcast immediately via WebSocket."""
    exam_uuid = _ensure_uuid_or_404(exam_id)
    sb = get_supabase()
    actor_name = user.get("full_name") or user.get("email") or "Invigilator"
    title = request.get("title") or "Examination Announcement"
    message = request.get("message") or ""
    priority = request.get("priority") or "normal"
    target_scope = request.get("target_scope") or "all"
    target_ids = request.get("target_candidate_ids") or []
    requires_ack = bool(request.get("requires_acknowledgement", False))

    res = await _execute_exam_rpc(sb, "rpc_create_exam_announcement", {
        "p_school_id": school_id,
        "p_exam_id": exam_uuid,
        "p_actor_id": user.get("id"),
        "p_actor_name": actor_name,
        "p_actor_role": user.get("role") or "",
        "p_title": title,
        "p_message": message,
        "p_priority": priority,
        "p_target_scope": target_scope,
        "p_target_candidate_ids": target_ids,
        "p_requires_ack": requires_ack,
    })

    recipient_ids = [str(x) for x in (res.get("recipient_ids") or [])]
    ann_payload = {
        "id": res.get("announcement_id"),
        "title": title,
        "message": message,
        "priority": priority,
        "target_scope": target_scope,
        "requires_acknowledgement": requires_ack,
        "sent_by_name": actor_name,
        "recipient_count": res.get("recipient_count", 0),
    }

    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_uuid,
        event="announcement_sent",
        audience="invigilators",
        data=ann_payload,
    )
    if recipient_ids:
        await exam_monitoring_ws_manager.broadcast(
            exam_id=exam_uuid,
            event="exam_announcement",
            audience="candidates",
            target_candidate_ids=recipient_ids,
            data=ann_payload,
        )

    return res


@router.post("/{exam_id}/monitoring/announcements/{announcement_id}/ack")
async def acknowledge_exam_monitoring_announcement(
    exam_id: str,
    announcement_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Record candidate receipt/acknowledgement of an examination announcement."""
    exam_uuid = _ensure_uuid_or_404(exam_id)
    ann_uuid = _ensure_uuid_or_404(announcement_id, label="Announcement")
    sb = get_supabase()
    res = await _execute_exam_rpc(sb, "rpc_acknowledge_exam_announcement", {
        "p_school_id": school_id,
        "p_exam_id": exam_uuid,
        "p_announcement_id": ann_uuid,
        "p_candidate_id": user.get("id"),
    })
    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_uuid,
        event="announcement_acknowledged",
        audience="invigilators",
        data={"announcement_id": ann_uuid, "candidate_id": user.get("id")},
    )
    return res


@router.post("/{exam_id}/monitoring/reentry-request")
async def submit_candidate_reentry_request(
    exam_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Allow a candidate whose session was interrupted/paused to request invigilator re-entry approval."""
    exam_uuid = _ensure_uuid_or_404(exam_id)
    sb = get_supabase()
    res = await _execute_exam_rpc(sb, "rpc_request_candidate_reentry", {
        "p_school_id": school_id,
        "p_exam_id": exam_uuid,
        "p_candidate_id": user.get("id"),
        "p_reason": request.get("reason") or "Network / system interruption",
    })
    await exam_monitoring_ws_manager.broadcast(
        exam_id=exam_uuid,
        event="reentry_requested",
        audience="invigilators",
        data={
            "request_id": res.get("request_id"),
            "candidate_id": user.get("id"),
            "candidate_name": user.get("full_name") or user.get("email"),
            "reason": request.get("reason") or "Network interruption",
        },
    )
    return res


@router.post("/{exam_id}/monitoring/heartbeat")
async def candidate_monitoring_heartbeat(
    exam_id: str,
    request: Optional[dict] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Direct monitoring heartbeat / proctor event endpoint for candidate clients."""
    return await ping_exam_session(exam_id=exam_id, request=request, user=user, school_id=school_id)


@router.get("/{exam_id}/monitoring/audit-logs")
async def get_exam_monitoring_audit_logs(
    exam_id: str,
    action_type: Optional[str] = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1, le=100),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Fetch chronological invigilation intervention audit trail."""
    sb = get_supabase()
    return await _execute_exam_rpc(sb, "rpc_get_exam_monitoring_audit_logs", {
        "p_school_id": school_id,
        "p_exam_id": _ensure_uuid_or_404(exam_id),
        "p_actor_id": user.get("id"),
        "p_actor_role": user.get("role") or "",
        "p_action_type": action_type,
        "p_page": page,
        "p_page_size": page_size,
    })


@router.get("/{exam_id}/monitoring/report")
async def export_exam_monitoring_report(
    exam_id: str,
    format: str = Query("json", pattern="^(json|csv)$"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Generate full examination monitoring & incident audit report as JSON or safe CSV download."""
    exam_uuid = _ensure_uuid_or_404(exam_id)
    sb = get_supabase()
    report = await _execute_exam_rpc(sb, "rpc_get_exam_monitoring_report", {
        "p_school_id": school_id,
        "p_exam_id": exam_uuid,
        "p_actor_id": user.get("id"),
        "p_actor_role": user.get("role") or "",
    })

    if format == "json":
        return report

    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["EduSHAMIIT Live Examination Monitoring Report"])
    exam_meta = report.get("exam") or {}
    writer.writerow(["Exam Title", _safe_csv_cell(exam_meta.get("title")), "Generated At", _safe_csv_cell(report.get("generated_at"))])
    writer.writerow([])
    writer.writerow(["Roll No", "Candidate Name", "Class", "Status", "Warnings", "Incidents", "Extra Mins", "Camera", "Mic", "Screen Share", "Answered", "Total Q", "Last Ping"])
    for c in report.get("candidates") or []:
        writer.writerow([
            _safe_csv_cell(c.get("roll_number")),
            _safe_csv_cell(c.get("full_name")),
            _safe_csv_cell(c.get("class_name")),
            _safe_csv_cell(c.get("monitoring_status")),
            _safe_csv_cell(c.get("warnings_count")),
            _safe_csv_cell(c.get("incidents_count")),
            _safe_csv_cell(c.get("extra_minutes")),
            _safe_csv_cell("Active" if c.get("camera_active") else c.get("camera_permission_state")),
            _safe_csv_cell("Active" if c.get("mic_active") else c.get("mic_permission_state")),
            _safe_csv_cell("Shared" if c.get("screen_share_active") else c.get("screen_share_state")),
            _safe_csv_cell(c.get("answered_count")),
            _safe_csv_cell(c.get("total_questions")),
            _safe_csv_cell(c.get("last_ping")),
        ])
    writer.writerow([])
    writer.writerow(["Incident Log"])
    writer.writerow(["Occurred At", "Candidate", "Roll No", "Type", "Severity", "Status", "Title", "Description", "Resolution Note"])
    for inc in report.get("incidents") or []:
        writer.writerow([
            _safe_csv_cell(inc.get("occurred_at")),
            _safe_csv_cell(inc.get("candidate_name")),
            _safe_csv_cell(inc.get("roll_number")),
            _safe_csv_cell(inc.get("violation_type")),
            _safe_csv_cell(inc.get("severity")),
            _safe_csv_cell(inc.get("status")),
            _safe_csv_cell(inc.get("title")),
            _safe_csv_cell(inc.get("description")),
            _safe_csv_cell(inc.get("resolution_note")),
        ])

    csv_bytes = output.getvalue().encode("utf-8-sig")
    return StreamingResponse(
        iter([csv_bytes]),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="exam_monitoring_report_{exam_uuid[:8]}.csv"'},
    )


# ============================================================================
# STANDALONE QUESTION BANK ROUTER (FOR /api/question-bank & /api/v1/question-bank)
# ============================================================================

@question_bank_router.get("/chapters")
async def standalone_get_question_bank_chapters(
    subject: Optional[str] = None,
    class_name: Optional[str] = None,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_get_question_bank_chapters(subject=subject, class_name=class_name, user=user, school_id=school_id)


@question_bank_router.get("/classes")
async def standalone_get_question_bank_classes(
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_get_question_bank_classes(user=user, school_id=school_id)


@question_bank_router.get("/export-template")
async def standalone_export_question_template(type: str = "mcq", subject: Optional[str] = None):
    return await export_question_template(type=type, subject=subject)


@question_bank_router.post("/bulk-upload")
async def standalone_bulk_upload_questions(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await bulk_upload_questions(request=request, user=user, school_id=school_id)


@question_bank_router.get("")
@question_bank_router.get("/")
async def standalone_get_question_bank(
    subject: Optional[str] = None,
    subject_id: Optional[str] = None,
    difficulty: Optional[str] = None,
    class_name: Optional[str] = None,
    class_id: Optional[str] = None,
    chapter: Optional[str] = None,
    question_type: Optional[str] = None,
    status: Optional[str] = None,
    search: Optional[str] = None,
    tag: Optional[str] = None,
    page: int = 1,
    page_size: int = 50,
    sort_by: str = "created_at",
    sort_order: str = "desc",
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_get_question_bank(
        subject=subject,
        subject_id=subject_id,
        difficulty=difficulty,
        class_name=class_name,
        class_id=class_id,
        chapter=chapter,
        question_type=question_type,
        status=status,
        search=search,
        tag=tag,
        page=page,
        page_size=page_size,
        sort_by=sort_by,
        sort_order=sort_order,
        user=user,
        school_id=school_id,
    )


@question_bank_router.post("")
@question_bank_router.post("/")
async def standalone_add_question_bank(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_add_question_bank(request=request, user=user, school_id=school_id)


@question_bank_router.post("/{question_id}/duplicate")
async def standalone_duplicate_question_bank(
    question_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_duplicate_question_bank(question_id=question_id, user=user, school_id=school_id)


@question_bank_router.post("/{question_id}/approve")
async def standalone_approve_question_bank(
    question_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_approve_question_bank(question_id=question_id, user=user, school_id=school_id)


@question_bank_router.put("/{question_id}")
async def standalone_update_question_bank(
    question_id: str,
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_update_question_bank(question_id=question_id, request=request, user=user, school_id=school_id)


@question_bank_router.delete("/{question_id}")
async def standalone_delete_question_bank(
    question_id: str,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    return await teacher_delete_question_bank(question_id=question_id, user=user, school_id=school_id)


@question_bank_router.post("/bulk-action")
async def standalone_bulk_question_bank_action(
    request: dict,
    user=Depends(require_exam_access),
    school_id=Depends(require_school_id),
):
    from app.api.teacher import teacher_bulk_question_bank_action
    return await teacher_bulk_question_bank_action(request=request, user=user, school_id=school_id)
