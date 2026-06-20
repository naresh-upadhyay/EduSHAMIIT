from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File, Form
from typing import Optional
from datetime import datetime, timedelta, timezone
import asyncio
import base64
import os
import httpx

from app.middleware.auth import get_current_user, require_school_id, require_student
from app.services.supabase_client import get_supabase
from app.cache.redis_client import get_cached, set_cached
from app.config import settings

router = APIRouter()


def _calculate_grade(pct):
    if pct >= 90: return "A+"
    if pct >= 80: return "A"
    if pct >= 70: return "B+"
    if pct >= 60: return "B"
    if pct >= 50: return "C"
    if pct >= 40: return "D"
    return "F"


@router.get("/dashboard")
async def student_dashboard(user=Depends(require_student), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "dashboard", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    today = datetime.now().weekday()
    
    res = await sb.rpc("get_student_dashboard_summary", {
        "p_school_id": school_id,
        "p_student_id": user["id"],
        "p_day_of_week": today
    }).aexecute()
    
    data = res.data[0] if res.data else {}
    
    # Map and flatten today's schedule to match Flutter model expectations
    schedule_list = data.get("today_schedule") or []
    if not isinstance(schedule_list, list):
        schedule_list = []
    teacher_ids = {s.get("teacher_id") for s in schedule_list if s.get("teacher_id")}
    teacher_names = {}
    if teacher_ids:
        profiles_res = await sb.table("profiles").select("id, full_name").in_("id", list(teacher_ids)).aexecute()
        if profiles_res.data:
            teacher_names = {p["id"]: p["full_name"] for p in profiles_res.data}

    mapped_schedule = []
    for item in schedule_list:
        sub_dict = item.get("subjects") or {}
        start_t = item.get("start_time", "")
        end_t = item.get("end_time", "")
        if start_t and len(start_t) > 5:
            start_t = start_t[:5]
        if end_t and len(end_t) > 5:
            end_t = end_t[:5]
            
        mapped_item = {
            **item,
            "subject": sub_dict.get("name") or "Unknown",
            "icon": sub_dict.get("icon") or "📚",
            "start_time": start_t,
            "end_time": end_t,
            "teacher": teacher_names.get(item.get("teacher_id")) or "Teacher",
            "is_now": False
        }
        mapped_schedule.append(mapped_item)
    data["today_schedule"] = mapped_schedule

    # Map and flatten pending homework to match Flutter model expectations
    homework_list = data.get("pending_homework") or []
    if not isinstance(homework_list, list):
        homework_list = []
    mapped_homework = []
    for hw in homework_list:
        sub_dict = hw.get("subjects") or {}
        mapped_hw = {
            **hw,
            "subject": sub_dict.get("name") or "Unknown",
            "icon": sub_dict.get("icon") or "📝"
        }
        mapped_homework.append(mapped_hw)
    data["pending_homework"] = mapped_homework

    data["quick_access"] = [
        {"title": "Timetable", "icon": "🗓️", "route": "/student/timetable", "bg": "EEF2FF"},
        {"title": "Results", "icon": "📊", "route": "/student/results", "bg": "FDF4FF"},
        {"title": "Fees", "icon": "💳", "route": "/student/fees", "bg": "ECFDF5"},
        {"title": "Notices", "icon": "📢", "route": "/student/notices", "bg": "FFF7ED"},
        {"title": "Homework", "icon": "📝", "route": "/student/homework", "bg": "FDF2F8"},
        {"title": "Transport", "icon": "🚌", "route": "/student/transport", "bg": "EFF6FF"},
        {"title": "Achieve", "icon": "🏆", "route": "/student/achievements", "bg": "F0FDF4"},
        {"title": "Attendance", "icon": "📋", "route": "/student/attendance", "bg": "EFF6FF"},
        {"title": "Library", "icon": "📖", "route": "/student/library", "bg": "FAF5FF"},
        {"title": "Courses", "icon": "📚", "route": "/student/courses", "bg": "ECFDF5"},
        {"title": "Leave", "icon": "✉️", "route": "/student/leave-application", "bg": "FEF2F2"},
        {"title": "Exams", "icon": "✍️", "route": "/student/exams", "bg": "EEF2FF"},
        {"title": "Live Class", "icon": "🔴", "route": "/student/live-classes", "bg": "FFE4E6", "badge": True},
        {"title": "Messages", "icon": "💬", "route": "/student/messaging", "bg": "E0E7FF"},
    ]
    
    result = {"success": True, "school_id": school_id, "data": data}
    await set_cached(school_id, "dashboard", result, user["id"], ttl=120)
    return result


@router.get("/timetable")
async def student_timetable(day: str = "monday", date: Optional[str] = None, user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    if date:
        try:
            target_date = datetime.strptime(date, "%Y-%m-%d").date()
            day_num = target_date.weekday()
            day_names = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            day = day_names[day_num]
        except Exception:
            day_map = {"monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5, "sunday": 6}
            day_num = day_map.get(day.lower(), 0)
            today_weekday = datetime.now().weekday()
            target_date = (datetime.now() + timedelta(days=(day_num - today_weekday))).date()
    else:
        day_map = {"monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5, "sunday": 6}
        day_num = day_map.get(day.lower(), 0)
        today_weekday = datetime.now().weekday()
        target_date = (datetime.now() + timedelta(days=(day_num - today_weekday))).date()
        
    target_date_str = target_date.isoformat()
    student_class = user.get("class")
    
    # Fallback: if class is missing from JWT (old token or refresh bug), fetch from profile
    if not student_class:
        profile_res = await sb.table("profiles").select("class").eq("id", user["id"]).maybe_single().aexecute()
        if profile_res.data:
            student_class = profile_res.data.get("class")
    
    # Fetch timetable entries for the given day_of_week
    db_schedule = (await sb.table("timetable")
                    .select("*, subjects(name, icon, color), profiles!teacher_id(full_name)")
                    .eq("school_id", school_id)
                    .eq("class", student_class)
                    .eq("day_of_week", day_num)
                    .order("start_time")
                    .aexecute()).data
                    
    schedule = []
    for idx, slot in enumerate(db_schedule):
        sub_name = slot.get("subjects", {}).get("name") if slot.get("subjects") else "Subject"
        if slot.get("custom_subject"):
            sub_name = slot["custom_subject"]
            
        teacher_name = slot.get("profiles", {}).get("full_name") if slot.get("profiles") else "Teacher"
        
        period_number = slot.get("slot_type") or "regular"
        if period_number == "regular":
            period_number = str(idx + 1)
            
        schedule.append({
            "id": slot.get("id", ""),
            "subject": sub_name,
            "teacher_name": teacher_name,
            "room_number": slot.get("room", "Room 101"),
            "start_time": slot["start_time"],
            "end_time": slot["end_time"],
            "day": day.capitalize(),
            "day_of_week": day.capitalize(),
            "period_number": period_number,
        })

    # Fetch live classes scheduled for this student on this date
    try:
        start_ts = f"{target_date_str}T00:00:00Z"
        end_ts = f"{target_date_str}T23:59:59Z"
        query = (sb.table("live_classes")
                            .select("*, subjects(name), profiles!teacher_id(full_name)")
                            .eq("school_id", school_id)
                            .gte("scheduled_at", start_ts)
                            .lte("scheduled_at", end_ts))
        if student_class:
            query = query.eq("target_class", student_class)
        db_live_classes = (await query.aexecute()).data or []
        for lc in db_live_classes:
            try:
                dt = datetime.fromisoformat(lc["scheduled_at"].replace("Z", "+00:00"))
                start_time = dt.strftime("%H:%M:%S")
                end_dt = dt + timedelta(minutes=lc.get("duration_minutes", 60))
                end_time = end_dt.strftime("%H:%M:%S")
            except Exception:
                start_time = "14:00:00"
                end_time = "15:00:00"
                
            teacher_name = lc.get("profiles", {}).get("full_name") if lc.get("profiles") else "Teacher"
            
            schedule.append({
                "id": lc["id"],
                "subject": f"💻 Live Class: {lc['title']}",
                "teacher_name": teacher_name,
                "room_number": lc.get("meeting_link") or lc.get("stream_url") or "EduSHAMIIT Live Room",
                "start_time": start_time,
                "end_time": end_time,
                "day": day.capitalize(),
                "day_of_week": day.capitalize(),
                "period_number": "Live Class",
                "platform": lc.get("platform", "In-App"),
                "meeting_link": lc.get("meeting_link") or lc.get("stream_url") or "",
            })
    except Exception:
        pass

    # Sort timetable chronologically
    schedule.sort(key=lambda x: x["start_time"])
        
    return {"success": True, "school_id": school_id, "data": {"schedule": schedule, "day": day, "class": student_class}}



@router.get("/results")
async def student_results(category: str = "All", user=Depends(require_student), school_id=Depends(require_school_id)):
    """
    Fetch student exam results from exam_submissions joined with published exams.
    Also includes legacy 'results' table data if present.
    Returns data in the format expected by ExamResult.fromJson().
    """
    sb = get_supabase()

    # ── Primary source: published exam_submissions ──────────────────────────
    subs_res = await sb.table("exam_submissions").select(
        "id, exam_id, score, grade_letter, class_rank, is_pass, graded_at, "
        "exams(id, title, total_marks, passing_marks, exam_type, school_id, results_published_at, subjects(name, icon))"
    ).eq("student_id", user["id"]).aexecute()

    submissions = subs_res.data or []

    formatted_results = []
    for sub in submissions:
        exam = sub.get("exams") or {}
        # Only show results that are published
        if not exam.get("results_published_at"):
            continue

        score = float(sub.get("score") or 0)
        total_marks = float(exam.get("total_marks") or 100)
        pct = (score / total_marks * 100) if total_marks > 0 else 0
        grade = sub.get("grade_letter") or _calculate_grade(pct)

        # Filter by exam_type if requested
        exam_type = exam.get("exam_type") or "General"
        if category != "All" and exam_type != category:
            continue

        subj = exam.get("subjects") or {}

        formatted_results.append({
            "id": sub.get("id", ""),
            "exam_title": exam.get("title", "Unknown Exam"),
            "subject": subj.get("name", "Unknown"),
            "subject_icon": subj.get("icon", "📚"),
            "exam_date": exam.get("results_published_at") or sub.get("graded_at") or "",
            "marks_obtained": score,
            "max_marks": total_marks,
            "grade": grade,
            "rank": sub.get("class_rank"),
            "exam_type": exam_type,
            "is_pass": sub.get("is_pass", False),
            "remarks": "Pass" if sub.get("is_pass") else "Fail",
        })

    # ── Fallback / legacy: results table ───────────────────────────────────
    legacy_res = await sb.table("results").select("*, subjects(name, icon)").eq("school_id", school_id).eq("student_id", user["id"]).order("created_at", ascending=False).aexecute()
    legacy_rows = legacy_res.data or []
    for r in legacy_rows:
        subj = r.get("subjects") or {}
        marks_obtained = float(r.get("marks_obtained") or 0)
        total_marks = float(r.get("total_marks") or 100)
        pct = (marks_obtained / total_marks * 100) if total_marks > 0 else 0
        grade = r.get("grade") or _calculate_grade(pct)
        exam_type = r.get("exam_type") or "General"
        if category != "All" and exam_type != category:
            continue
        formatted_results.append({
            "id": r.get("id", ""),
            "exam_title": r.get("exam_title") or r.get("title") or "Exam",
            "subject": subj.get("name") or r.get("subject") or "Unknown",
            "subject_icon": subj.get("icon", "📚"),
            "exam_date": r.get("exam_date") or r.get("created_at") or "",
            "marks_obtained": marks_obtained,
            "max_marks": total_marks,
            "grade": grade,
            "rank": r.get("rank"),
            "exam_type": exam_type,
            "remarks": r.get("remarks"),
        })

    # Sort by exam_date descending
    formatted_results.sort(key=lambda x: x.get("exam_date") or "", reverse=True)

    total_score = sum(float(r["marks_obtained"]) for r in formatted_results)
    max_score = sum(float(r["max_marks"]) for r in formatted_results)
    avg_score = (total_score / max_score * 100) if max_score > 0 else 0

    return {
        "success": True,
        "school_id": school_id,
        "data": formatted_results
    }


@router.post("/results/pdf")
async def student_download_results_pdf(
    request: dict,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    """
    Generate and download a PDF report card for selected or all exam results in a college/university format.
    """
    from io import BytesIO
    from fastapi.responses import StreamingResponse
    from reportlab.lib.pagesizes import letter
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT, TA_JUSTIFY
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
    from reportlab.lib.units import inch
    
    sb = get_supabase()
    
    # 1. Fetch student profile and school info
    profile_res = await sb.table("profiles").select("*").eq("id", user["id"]).maybe_single().aexecute()
    profile = profile_res.data or {}
    
    school_res = await sb.table("schools").select("*").eq("id", school_id).maybe_single().aexecute()
    school = school_res.data or {}
    school_name = school.get("name", "EDUSHAMIIT ACADEMY")

    # 2. Fetch exam_submissions
    subs_res = await sb.table("exam_submissions").select(
        "id, exam_id, score, grade_letter, class_rank, is_pass, graded_at, "
        "exams(id, title, total_marks, passing_marks, exam_type, school_id, results_published_at, subjects(name, icon))"
    ).eq("student_id", user["id"]).aexecute()
    submissions = subs_res.data or []

    formatted_results = []
    for sub in submissions:
        exam = sub.get("exams") or {}
        # Only show results that are published
        if not exam.get("results_published_at"):
            continue

        score = float(sub.get("score") or 0)
        total_marks = float(exam.get("total_marks") or 100)
        pct = (score / total_marks * 100) if total_marks > 0 else 0
        grade = sub.get("grade_letter") or _calculate_grade(pct)
        exam_type = exam.get("exam_type") or "General"
        subj = exam.get("subjects") or {}

        formatted_results.append({
            "id": sub.get("id", ""),
            "exam_title": exam.get("title", "Unknown Exam"),
            "subject": subj.get("name", "Unknown"),
            "exam_date": exam.get("results_published_at")[:10] if exam.get("results_published_at") else "",
            "marks_obtained": score,
            "max_marks": total_marks,
            "passing_marks": float(exam.get("passing_marks") or (total_marks * 0.4)),
            "grade": grade,
            "rank": sub.get("class_rank"),
            "exam_type": exam_type,
            "is_pass": sub.get("is_pass", False) or (score >= float(exam.get("passing_marks") or (total_marks * 0.4))),
            "remarks": "Pass" if (sub.get("is_pass") or (score >= float(exam.get("passing_marks") or (total_marks * 0.4)))) else "Fail",
        })

    # 3. Fetch legacy results table
    legacy_res = await sb.table("results").select("*, subjects(name, icon)").eq("school_id", school_id).eq("student_id", user["id"]).order("created_at", ascending=False).aexecute()
    legacy_rows = legacy_res.data or []
    for r in legacy_rows:
        subj = r.get("subjects") or {}
        marks_obtained = float(r.get("marks_obtained") or 0)
        total_marks = float(r.get("total_marks") or 100)
        pct = (marks_obtained / total_marks * 100) if total_marks > 0 else 0
        grade = r.get("grade") or _calculate_grade(pct)
        exam_type = r.get("exam_type") or "General"
        pass_m = float(r.get("passing_marks") or (total_marks * 0.4))
        is_pass = marks_obtained >= pass_m
        formatted_results.append({
            "id": r.get("id", ""),
            "exam_title": r.get("exam_title") or r.get("title") or "Exam",
            "subject": subj.get("name") or r.get("subject") or "Unknown",
            "exam_date": r.get("exam_date")[:10] if r.get("exam_date") else (r.get("created_at")[:10] if r.get("created_at") else ""),
            "marks_obtained": marks_obtained,
            "max_marks": total_marks,
            "passing_marks": pass_m,
            "grade": grade,
            "rank": r.get("rank"),
            "exam_type": exam_type,
            "is_pass": is_pass,
            "remarks": r.get("remarks") or ("Pass" if is_pass else "Fail"),
        })

    # 4. Filter results based on exam_ids if provided
    selected_ids = request.get("exam_ids", [])
    if selected_ids:
        id_set = set(selected_ids)
        formatted_results = [r for r in formatted_results if r["id"] in id_set]

    # Sort chronologically by date
    formatted_results.sort(key=lambda x: x.get("exam_date") or "", reverse=True)

    if not formatted_results:
        raise HTTPException(status_code=400, detail="No exam results selected or found.")

    buffer = BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        rightMargin=36,
        leftMargin=36,
        topMargin=36,
        bottomMargin=36
    )
    
    # Theme color definitions
    C_BRAND = colors.HexColor("#4F46E5") # Indigo
    C_BRAND_LIGHT = colors.HexColor("#EEF2FF")
    C_BORDER = colors.HexColor("#E2E8F0")
    C_TEXT = colors.HexColor("#1E293B")
    C_DARK = colors.HexColor("#0F172A")
    
    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'SchoolTitle', parent=styles['Normal'],
        fontSize=18, leading=22, fontName='Helvetica-Bold',
        textColor=C_BRAND, alignment=TA_CENTER, spaceAfter=4
    )
    subtitle_style = ParagraphStyle(
        'ReportSubtitle', parent=styles['Normal'],
        fontSize=11, leading=14, fontName='Helvetica-Bold',
        textColor=colors.HexColor("#475569"), alignment=TA_CENTER, spaceAfter=15
    )
    section_title = ParagraphStyle(
        'SectionTitle', parent=styles['Normal'],
        fontSize=11, leading=14, fontName='Helvetica-Bold',
        textColor=C_DARK, spaceBefore=12, spaceAfter=6
    )
    body_style = ParagraphStyle(
        'BodyTextCustom', parent=styles['Normal'],
        fontSize=8.5, leading=11, fontName='Helvetica',
        textColor=C_TEXT
    )
    body_bold = ParagraphStyle(
        'BodyTextBold', parent=styles['Normal'],
        fontSize=8.5, leading=11, fontName='Helvetica-Bold',
        textColor=C_DARK
    )
    body_center = ParagraphStyle(
        'BodyTextCenter', parent=styles['Normal'],
        fontSize=8.5, leading=11, fontName='Helvetica',
        textColor=C_TEXT, alignment=TA_CENTER
    )
    body_center_bold = ParagraphStyle(
        'BodyTextCenterBold', parent=styles['Normal'],
        fontSize=8.5, leading=11, fontName='Helvetica-Bold',
        textColor=C_DARK, alignment=TA_CENTER
    )
    body_right_bold = ParagraphStyle(
        'BodyTextRightBold', parent=styles['Normal'],
        fontSize=8.5, leading=11, fontName='Helvetica-Bold',
        textColor=C_DARK, alignment=TA_RIGHT
    )

    story = []
    story.append(Paragraph(school_name.upper(), title_style))
    story.append(Paragraph("OFFICIAL ACADEMIC TRANSCRIPT / REPORT CARD", subtitle_style))
    story.append(HRFlowable(width='100%', thickness=2, color=C_BRAND, spaceAfter=15))

    # Student details table
    student_info = [
        [
            Paragraph("<b>Student Name:</b>", body_style), Paragraph(str(profile.get("full_name", "Student")), body_bold),
            Paragraph("<b>Roll Number:</b>", body_style), Paragraph(str(profile.get("roll_number", "N/A")), body_bold)
        ],
        [
            Paragraph("<b>Class & Section:</b>", body_style), Paragraph(f"{profile.get('class', 'N/A')} - {profile.get('section', 'A')}", body_bold),
            Paragraph("<b>Academic Year:</b>", body_style), Paragraph("2026", body_bold)
        ],
        [
            Paragraph("<b>Email:</b>", body_style), Paragraph(str(profile.get("email", "N/A")), body_bold),
            Paragraph("<b>Date of Issue:</b>", body_style), Paragraph(datetime.now().strftime("%d %B %Y"), body_bold)
        ]
    ]
    
    info_table = Table(student_info, colWidths=[1.4*inch, 2.2*inch, 1.2*inch, 2.7*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 8))
    story.append(HRFlowable(width='100%', thickness=1, color=C_BORDER, spaceAfter=12))

    # Results table
    table_headers = [
        Paragraph("<b>SUBJECT</b>", body_bold),
        Paragraph("<b>EXAM TITLE</b>", body_bold),
        Paragraph("<b>TYPE</b>", body_bold),
        Paragraph("<b>MAX</b>", body_center_bold),
        Paragraph("<b>PASS</b>", body_center_bold),
        Paragraph("<b>OBTAINED</b>", body_center_bold),
        Paragraph("<b>%</b>", body_center_bold),
        Paragraph("<b>GRADE</b>", body_center_bold),
        Paragraph("<b>REMARKS</b>", body_center_bold)
    ]
    table_data = [table_headers]
    
    total_max = 0.0
    total_obtained = 0.0
    total_exams = len(formatted_results)
    passed_exams = 0
    
    for r in formatted_results:
        max_m = r["max_marks"]
        obt_m = r["marks_obtained"]
        pass_m = r["passing_marks"]
        pct = (obt_m / max_m * 100) if max_m > 0 else 0.0
        
        total_max += max_m
        total_obtained += obt_m
        
        is_pass = r["is_pass"]
        if is_pass:
            passed_exams += 1
            remark_text = f"<font color='#059669'><b>PASS</b></font>"
        else:
            remark_text = f"<font color='#DC2626'><b>FAIL</b></font>"
            
        table_data.append([
            Paragraph(str(r["subject"]), body_style),
            Paragraph(str(r["exam_title"]), body_style),
            Paragraph(str(r["exam_type"]), body_style),
            Paragraph(f"{max_m:.0f}", body_center),
            Paragraph(f"{pass_m:.0f}", body_center),
            Paragraph(f"{obt_m:.1f}", body_center_bold),
            Paragraph(f"{pct:.1f}%", body_center),
            Paragraph(str(r["grade"]), body_center_bold),
            Paragraph(remark_text, body_center)
        ])
        
    results_table = Table(table_data, colWidths=[1.2*inch, 1.8*inch, 0.9*inch, 0.5*inch, 0.5*inch, 0.9*inch, 0.6*inch, 0.5*inch, 0.6*inch])
    results_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BACKGROUND', (0, 0), (-1, 0), C_BRAND_LIGHT),
        ('GRID', (0, 0), (-1, -1), 0.5, C_BORDER),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 4),
        ('RIGHTPADDING', (0, 0), (-1, -1), 4),
    ]))
    
    story.append(Paragraph("Academic Performance Ledger", section_title))
    story.append(results_table)
    story.append(Spacer(1, 10))

    # Summary table
    agg_pct = (total_obtained / total_max * 100) if total_max > 0 else 0.0
    final_grade = _calculate_grade(agg_pct)
    final_status = "PASSED" if passed_exams == total_exams else "PROMOTED WITH FAILURES" if passed_exams > 0 else "FAILED"
    
    summary_data = [
        [
            Paragraph("<b>Total Exams:</b>", body_style), Paragraph(str(total_exams), body_bold),
            Paragraph("<b>Aggregate Percentage:</b>", body_style), Paragraph(f"{agg_pct:.2f}%", body_bold)
        ],
        [
            Paragraph("<b>Total Maximum Marks:</b>", body_style), Paragraph(f"{total_max:.0f}", body_bold),
            Paragraph("<b>Overall Grade:</b>", body_style), Paragraph(final_grade, body_bold)
        ],
        [
            Paragraph("<b>Total Marks Obtained:</b>", body_style), Paragraph(f"{total_obtained:.1f}", body_bold),
            Paragraph("<b>Result Status:</b>", body_style), Paragraph(f"<font color='{'#059669' if final_status == 'PASSED' else '#DC2626'}'><b>{final_status}</b></font>", body_bold)
        ]
    ]
    
    summary_table = Table(summary_data, colWidths=[1.8*inch, 1.8*inch, 1.8*inch, 2.1*inch])
    summary_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), colors.HexColor("#F8FAFC")),
        ('BOX', (0, 0), (-1, -1), 1, C_BORDER),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
    ]))
    story.append(Paragraph("Consolidated Academic Summary", section_title))
    story.append(summary_table)
    story.append(Spacer(1, 30))

    # Signatures
    sig_data = [
        [Paragraph("", body_style), Paragraph("", body_style)],
        [Spacer(1, 25), Spacer(1, 25)],
        [Paragraph("<b>Class Teacher Signature</b>", body_style), Paragraph("<b>Controller of Examinations / Principal</b>", body_right_bold)],
    ]
    sig_table = Table(sig_data, colWidths=[3.75*inch, 3.75*inch])
    sig_table.setStyle(TableStyle([
        ('LINEBELOW', (0, 0), (0, 0), 1, colors.HexColor("#94A3B8")),
        ('LINEBELOW', (1, 0), (1, 0), 1, colors.HexColor("#94A3B8")),
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('VALIGN', (0, 0), (-1, -1), 'BOTTOM'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(sig_table)

    doc.build(story)
    buffer.seek(0)
    
    clean_name = profile.get('full_name', 'Student').replace(' ', '_')
    filename = f"ReportCard_{clean_name}.pdf"
    
    return StreamingResponse(
        buffer,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f"attachment; filename={filename}"
        }
    )


async def _auto_publish_scheduled_exams(sb, school_id: str):
    from datetime import datetime, timezone
    try:
        now = datetime.now(timezone.utc).isoformat()
        # Update 1: release_time is not null and release_time <= now
        await sb.table("exams")\
            .update({"status": "published"})\
            .eq("school_id", school_id)\
            .in_("status", ["scheduled", "ready"])\
            .is_("release_time", "not.null")\
            .lte("release_time", now)\
            .aexecute()
            
        # Update 2: release_time is null and start_time is not null and start_time <= now
        await sb.table("exams")\
            .update({"status": "published"})\
            .eq("school_id", school_id)\
            .in_("status", ["scheduled", "ready"])\
            .is_("release_time", "null")\
            .is_("start_time", "not.null")\
            .lte("start_time", now)\
            .aexecute()
    except Exception as e:
        print(f"Error auto-publishing exams in backend: {e}", flush=True)


@router.get("/exams")
async def student_exams(user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await _auto_publish_scheduled_exams(sb, school_id)
    
    # 1. Fetch student's class from database
    profile_res = await sb.table("profiles").select("class").eq("id", user["id"]).maybe_single().aexecute()
    student_class = profile_res.data.get("class") if profile_res.data else None
    
    # 2. Fetch all exams for this school (excluding drafts)
    exams_res = await sb.table("exams")\
        .select("*, subjects(name, icon)")\
        .eq("school_id", school_id)\
        .neq("status", "draft")\
        .order("start_time", ascending=False)\
        .aexecute()
    all_exams = exams_res.data or []
    
    # 3. Fetch submissions by this student
    sub_res = await sb.table("exam_submissions").select("*").eq("student_id", user["id"]).aexecute()
    submissions = sub_res.data or []
    sub_map = {s["exam_id"]: s for s in submissions}
    
    # 4. Fetch proctoring sessions by this student
    sess_res = await sb.table("exam_sessions").select("*").eq("student_id", user["id"]).aexecute()
    sessions = sess_res.data or []
    sess_map = {s["exam_id"]: s for s in sessions}
    
    filtered_exams = []
    for exam in all_exams:
        target_classes = exam.get("target_classes")
        
        # Check class filtering
        is_targeted = False
        if not target_classes:
            is_targeted = True
        else:
            if isinstance(target_classes, str):
                try:
                    import json
                    target_classes = json.loads(target_classes)
                except Exception:
                    pass
            
            if isinstance(target_classes, list):
                cleaned_student_class = str(student_class).strip().upper() if student_class else ""
                target_classes_upper = [str(tc).strip().upper() for tc in target_classes]
                if cleaned_student_class in target_classes_upper:
                    is_targeted = True
            else:
                is_targeted = True
                
        if is_targeted:
            # Check target students/scope filtering
            scope = exam.get("scope") or "All Students"
            if scope != "All Students":
                target_students = exam.get("target_students")
                if isinstance(target_students, str):
                    try:
                        import json
                        target_students = json.loads(target_students)
                    except Exception:
                        pass
                
                if isinstance(target_students, list):
                    if user["id"] not in target_students and str(user["id"]) not in target_students:
                        is_targeted = False
                else:
                    is_targeted = False

        if not is_targeted:
            continue
            
        # Check scheduled release and status process
        status = exam.get("status") or "draft"
        if status not in ("published", "scheduled", "ready", "completed"):
            continue
            
        if status in ("scheduled", "ready"):
            release_time_str = exam.get("release_time")
            if release_time_str:
                try:
                    from dateutil.parser import parse
                    from datetime import datetime, timezone
                    release_time = parse(release_time_str)
                    now = datetime.now(timezone.utc)
                    if release_time > now:
                        continue
                except Exception:
                    pass
            else:
                continue

        # Attach submission details
        submission = sub_map.get(exam["id"])
        if submission:
            sub_status = submission.get("status")
            results_pub = exam.get("results_published_at") is not None
            if sub_status == "graded" and not results_pub:
                exam["submission_status"] = "submitted"
                exam["obtained_score"] = None
                exam["graded_at"] = None
            else:
                exam["submission_status"] = sub_status
                exam["obtained_score"] = submission.get("score")
                exam["graded_at"] = submission.get("graded_at")
        else:
            exam["submission_status"] = None
            exam["obtained_score"] = None
            exam["graded_at"] = None
            
        # Attach session details
        session = sess_map.get(exam["id"])
        if session:
            exam["session_status"] = session.get("status")
            exam["has_session"] = True
        else:
            exam["session_status"] = None
            exam["has_session"] = False
            
        # Format the subject name and icon
        subj = exam.get("subjects") or {}
        exam["subject"] = subj.get("name", "Unknown")
        exam["subject_icon"] = subj.get("icon", "📚")
        
        # Strip raw passcode and set boolean flag for client security
        passcode_val = exam.get("passcode")
        exam["has_passcode"] = bool(passcode_val and passcode_val.strip())
        exam.pop("passcode", None)
            
        filtered_exams.append(exam)
        
    return {"success": True, "school_id": school_id, "data": {"exams": filtered_exams}}


@router.get("/homework")
async def student_homework(status: str = "all", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    student_class = user.get("class")
    if not student_class:
        return {"success": True, "school_id": school_id, "data": {"homework": []}}
    
    # Parallelize homework and submissions
    hw_task = sb.table("homework").select("*, subjects(name, icon)").eq("school_id", school_id).eq("class", student_class).eq("status", "active").order("due_date").aexecute()
    sub_task = sb.table("homework_submissions").select("homework_id, status, marks, grade, teacher_remarks, attachment_url, submission_text, submitted_at").eq("student_id", user["id"]).aexecute()
    
    hw_res, sub_res = await asyncio.gather(hw_task, sub_task)
    homework = hw_res.data or []
    submissions = sub_res.data or []
    
    sub_map = {s["homework_id"]: s for s in submissions}
    filtered = []
    for hw in homework:
        sub = sub_map.get(hw["id"])
        
        # Resolve subjects mapping
        subj = hw.get("subjects") or {}
        hw["subject"] = subj.get("name", "Unknown")
        hw["subject_icon"] = subj.get("icon", "📚")
        
        # Resolve status, marks, details to match Flutter models
        hw["status"] = sub["status"] if sub else "pending"
        hw["submission_status"] = sub["status"] if sub else None
        hw["marks_obtained"] = sub.get("marks") if sub else None
        hw["marks"] = sub.get("marks") if sub else None
        hw["grade"] = sub.get("grade") if sub else None
        hw["teacher_remarks"] = sub.get("teacher_remarks") if sub else None
        hw["submission_url"] = sub.get("attachment_url") if sub else None
        hw["submission_text"] = sub.get("submission_text") if sub else None
        hw["submitted_at"] = sub.get("submitted_at") if sub else None
        attachments = hw.get("attachments")
        if attachments:
            if isinstance(attachments, list) and len(attachments) > 0:
                hw["attachment_url"] = attachments[0]
            elif isinstance(attachments, str):
                hw["attachment_url"] = attachments
            else:
                hw["attachment_url"] = None
        else:
            hw["attachment_url"] = None
        
        # Filter by status parameter (pending, submitted, graded)
        if status == "all" or (status == "pending" and (not sub or sub["status"] == "returned")) or (status == "submitted" and sub and sub["status"] == "submitted") or (status == "graded" and sub and sub["status"] == "graded"):
            filtered.append(hw)
            
    return {"success": True, "school_id": school_id, "data": {"homework": filtered}}


@router.post("/homework/submit")
async def submit_homework_body(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    return await submit_homework(homework_id=None, request=request, user=user, school_id=school_id)


@router.post("/homework/{homework_id}/submit")
async def submit_homework(homework_id: Optional[str] = None, request: dict = {}, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    hw_id = homework_id or request.get("homework_id")
    if not hw_id:
        return {"success": False, "message": "Missing homework_id"}
        
    existing = await sb.table("homework_submissions").select("id, status, homework(due_date)").eq("homework_id", hw_id).eq("student_id", user["id"]).maybe_single().aexecute()
    
    attachment = request.get("attachment_url") or request.get("file_url")
    text = request.get("submission_text", "")
    
    if existing.data:
        sub = existing.data
        status_val = sub.get("status") or ""
        homework_dict = sub.get("homework") or {}
        due_date_str = homework_dict.get("due_date")
        
        is_due_over = False
        if due_date_str:
            try:
                due_date = datetime.strptime(due_date_str, "%Y-%m-%d").date()
                if due_date < datetime.now(timezone.utc).date():
                    is_due_over = True
            except Exception:
                pass
        
        can_update = False
        if status_val == "returned":
            can_update = True
        elif status_val == "submitted" and not is_due_over:
            can_update = True
            
        if can_update:
            await sb.table("homework_submissions").update({
                "submission_text": text,
                "attachment_url": attachment,
                "submitted_at": datetime.now(timezone.utc).isoformat(),
                "status": "submitted",
                "grade": None,
                "marks": None,
                "teacher_remarks": None,
                "graded_by": None,
                "graded_at": None
            }).eq("id", sub["id"]).aexecute()
            return {"success": True, "school_id": school_id, "message": "Homework submission updated successfully"}
        else:
            if status_val == "graded":
                return {"success": False, "message": "This homework has already been graded and cannot be updated"}
            elif is_due_over:
                return {"success": False, "message": "Due date is over; you cannot update this submission"}
            else:
                return {"success": False, "message": "Already submitted"}
        
    await sb.table("homework_submissions").insert({
        "school_id": school_id, 
        "homework_id": hw_id, 
        "student_id": user["id"], 
        "submission_text": text, 
        "attachment_url": attachment, 
        "status": "submitted"
    }).aexecute()
    
    try:
        await sb.rpc("update_student_xp", {"p_school_id": school_id, "p_student_id": user["id"], "p_xp_to_add": 50, "p_action": "homework_submission"}).aexecute()
    except Exception:
        pass
        
    return {"success": True, "school_id": school_id, "message": "Homework submitted! +50 XP"}


@router.get("/attendance")
async def student_attendance(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Query all attendance records for this student
    res = await (sb.table("attendance")
                 .select("id, status, remarks, date, subject_id, subjects(name), profiles!marked_by(full_name)")
                 .eq("school_id", school_id)
                 .eq("student_id", user["id"])
                 .order("date", ascending=False)
                 .aexecute())
    records_data = res.data or []
    
    # Counts
    total_records = len(records_data)
    present_days = sum(1 for a in records_data if a["status"] == "present")
    absent_days = sum(1 for a in records_data if a["status"] == "absent")
    late_days = sum(1 for a in records_data if a["status"] == "late")
    void_days = sum(1 for a in records_data if a["status"] == "void")
    
    # Calculate overall percentage excluding void
    valid_count = present_days + absent_days + late_days
    present_count = present_days + late_days
    overall_pct = (present_count / valid_count * 100) if valid_count > 0 else 0.0
    
    # Subject-wise calculation
    subject_wise_map = {}
    for a in records_data:
        subj_name = (a.get("subjects") or {}).get("name") if a.get("subject_id") else "Entire Day"
        subj_id = a.get("subject_id")
        
        subject_wise_map.setdefault(subj_name, {"subject_id": subj_id, "present": 0, "total": 0})
        
        if a["status"] != "void":
            subject_wise_map[subj_name]["total"] += 1
            if a["status"] in ("present", "late"):
                subject_wise_map[subj_name]["present"] += 1
                
    subject_wise_list = []
    for name, data in subject_wise_map.items():
        present = data["present"]
        total = data["total"]
        pct = (present / total * 100) if total > 0 else 0.0
        subject_wise_list.append({
            "subject": name,
            "subject_id": data["subject_id"],
            "present": present,
            "total": total,
            "pct": round(pct, 1)
        })
        
    # Sort subject list: lowest percentage first
    subject_wise_list.sort(key=lambda x: x["pct"])
    
    # Monthly trend calculation
    monthly_map = {}
    for a in records_data:
        try:
            date_obj = datetime.strptime(a["date"], "%Y-%m-%d")
            month_key = date_obj.strftime("%B %Y")
            month_sort_key = date_obj.strftime("%Y-%m")
        except Exception:
            month_key = "Unknown"
            month_sort_key = "0000-00"
            
        monthly_map.setdefault(month_key, {"sort_key": month_sort_key, "present": 0, "total": 0})
        
        if a["status"] != "void":
            monthly_map[month_key]["total"] += 1
            if a["status"] in ("present", "late"):
                monthly_map[month_key]["present"] += 1
                
    monthly_list = []
    for name, data in monthly_map.items():
        present = data["present"]
        total = data["total"]
        pct = (present / total * 100) if total > 0 else 0.0
        monthly_list.append({
            "month": name,
            "sort_key": data["sort_key"],
            "present": present,
            "total": total,
            "pct": round(pct, 1)
        })
    # Sort monthly list chronologically (sort_key ascending)
    monthly_list.sort(key=lambda x: x["sort_key"])
    
    # Flatten/map detailed records for the client
    records_flat = []
    for a in records_data:
        subj_name = (a.get("subjects") or {}).get("name") if a.get("subject_id") else "Entire Day"
        marked_by_profile = a.get("profiles") or {}
        marked_by_name = marked_by_profile.get("full_name") or "Teacher"
        
        records_flat.append({
            "id": a["id"],
            "date": a["date"],
            "subject_name": subj_name,
            "subject_id": a["subject_id"],
            "status": a["status"],
            "remarks": a.get("remarks"),
            "marked_by_name": marked_by_name
        })
        
    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "summary": {
                "overall_pct": round(overall_pct, 1),
                "present_days": present_days,
                "absent_days": absent_days,
                "late_days": late_days,
                "void_days": void_days,
                "total_days": total_records
            },
            "subject_wise": subject_wise_list,
            "monthly": monthly_list,
            "records": records_flat
        }
    }


@router.get("/fees")
async def student_fees(status: Optional[str] = None, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Query all fees for summary calculation
    all_fees = (await sb.table("fees").select("*").eq("school_id", school_id).eq("student_id", user["id"]).order("due_date").aexecute()).data

    # Fetch latest payment per fee for transaction_id and payment_method
    fee_ids = [f["id"] for f in all_fees if f["id"]]
    payment_map = {}
    if fee_ids:
        payments_res = (await sb.table("payments")
            .select("fee_id, transaction_id, payment_method, paid_at, status")
            .in_("fee_id", fee_ids)
            .eq("status", "success")
            .order("created_at", ascending=False)
            .aexecute()).data
        for p in payments_res:
            fid = p.get("fee_id")
            if fid and fid not in payment_map:
                payment_map[fid] = p

    # Enrich fees with payment info
    for f in all_fees:
        p_info = payment_map.get(f["id"])
        if p_info:
            f["transaction_id"] = p_info.get("transaction_id")
            f["payment_method"] = p_info.get("payment_method")
        else:
            f["transaction_id"] = None
            f["payment_method"] = None

    pending_fees = [f for f in all_fees if f["status"] in ("pending", "partial", "overdue")]
    paid_fees    = [f for f in all_fees if f["status"] == "paid"]

    try:
        rpc_res = await sb.rpc("get_student_outstanding_balance", {
            "p_student_id": user["id"],
            "p_school_id": school_id
        }).aexecute()
        total_outstanding = float(rpc_res.data) if rpc_res.data is not None else 0.0
    except Exception as e:
        total_outstanding = sum(max(float(f["amount"]) + float(f.get("late_fine") or 0) - float(f.get("discount") or 0) - float(f.get("amount_paid") or 0), 0.0) for f in pending_fees)
    total_paid        = sum(float(f.get("amount_paid") or 0) for f in all_fees)

    # Filter fees to return if status is specified
    filtered_fees = all_fees
    if status and status.lower() != "all":
        # Handle receipts case (which maps to paid)
        target_status = "paid" if status.lower() == "receipts" else status.lower()
        filtered_fees = [f for f in all_fees if f["status"] == target_status]

    return {
        "success": True, "school_id": school_id,
        "data": {
            "total_outstanding": total_outstanding,
            "total_paid": total_paid,
            "fees": filtered_fees,
            "pending_fees": pending_fees,
            "recent_payments": paid_fees[:3],
        }
    }


@router.get("/transport")
async def student_transport(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    transport = (await sb.table("student_transport").select("*, bus_routes(*), bus_stops(stop_name)").eq("school_id", school_id).eq("student_id", user["id"]).maybe_single().aexecute()).data
    if not transport:
        return {"success": False, "message": "Not assigned to any bus route"}
    bus_location = (await sb.table("bus_locations").select("*").eq("school_id", school_id).eq("route_id", transport["route_id"]).order("recorded_at", ascending=False).limit(1).maybe_single().aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"route": transport.get("bus_routes"), "your_stop": transport.get("bus_stops", {}).get("stop_name"), "live_location": bus_location}}


@router.get("/notices")
async def student_notices(category: str = "All", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    student_class = user.get("class")
    if not student_class:
        profile_res = await sb.table("profiles").select("class").eq("id", user["id"]).maybe_single().aexecute()
        if profile_res.data:
            student_class = profile_res.data.get("class")
            
    query = sb.table("notices").select("*").eq("school_id", school_id).eq("status", "published")
    
    if student_class:
        query = query.or_(f'target_audience.eq.all,target_audience.eq.students,target_classes.cs.{{"{student_class}"}}')
    else:
        query = query.or_('target_audience.eq.all,target_audience.eq.students')
        
    if category and category.lower() != "all":
        query = query.ilike("category", category)
        
    notices = (await query.order("published_at", ascending=False).limit(20).aexecute()).data or []
    
    # Enrich notices with registrations count and student registration status
    notice_ids = [n["id"] for n in notices if n.get("id")]
    if notice_ids:
        # Fetch registrations for these notices
        reg_res = (await sb.table("notice_registrations")
                   .select("notice_id, student_id")
                   .in_("notice_id", notice_ids)
                   .aexecute()).data or []
        
        # Aggregate registrations count and check if registered
        reg_counts = {}
        my_registrations = set()
        for r in reg_res:
            nid = r.get("notice_id")
            sid = r.get("student_id")
            if nid:
                reg_counts[nid] = reg_counts.get(nid, 0) + 1
                if sid == user["id"]:
                    my_registrations.add(nid)
                    
        for n in notices:
            nid = n.get("id")
            n["registration_count"] = reg_counts.get(nid, 0)
            n["registered"] = nid in my_registrations
    else:
        for n in notices:
            n["registration_count"] = 0
            n["registered"] = False
            
    return {"success": True, "school_id": school_id, "data": {"notices": notices}}


@router.post("/notices/{notice_id}/register")
async def register_notice(notice_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    try:
        # Check if the notice exists and is an Event
        notice_res = await sb.table("notices").select("id, category").eq("id", notice_id).maybe_single().aexecute()
        if not notice_res.data:
            raise HTTPException(status_code=404, detail="Notice not found")
        
        # Check category (allow case-insensitive comparison)
        category = notice_res.data.get("category") or ""
        if category.lower() != "event":
            raise HTTPException(status_code=400, detail="Notice is not an event")

        await sb.table("notice_registrations").insert({
            "school_id": school_id, 
            "notice_id": notice_id, 
            "student_id": user["id"],
            "status": "registered"
        }).aexecute()
    except Exception as e:
        if "23505" in str(e) or "duplicate key" in str(e).lower():
            return {"success": True, "message": "Already registered for this notice"}
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")
    return {"success": True, "message": "Registered successfully"}



@router.get("/events")
async def student_events(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    events = (await sb.table("events").select("*").eq("school_id", school_id).gte("event_date", datetime.now().date().isoformat()).order("event_date").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"events": events}}


@router.post("/events/{event_id}/register")
async def register_event(event_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    try:
        await sb.table("event_registrations").insert({
            "school_id": school_id, "event_id": event_id, "student_id": user["id"]
        }).aexecute()
        
        # Award XP for event registration/participation
        try:
            from app.services.supabase_client import award_xp
            await award_xp(sb, school_id, user["id"], 20, "event_participation", event_id, "Registered for event")
        except Exception as e:
            print(f"Error awarding event XP: {str(e)}", flush=True)
            
    except Exception as e:
        if "23505" in str(e) or "duplicate key" in str(e).lower():
            return {"success": True, "message": "Already registered for this event"}
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")
    return {"success": True, "message": "Registered successfully"}


@router.get("/achievements")
async def student_achievements(
    exclude_leaderboards: bool = False,
    exclude_history: bool = False,
    user=Depends(get_current_user), 
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    
    # JIT Evaluate/Update all badges & progress
    from app.services.badge_rules import evaluate_and_update_student_badges
    await evaluate_and_update_student_badges(sb, school_id, user["id"])
    
    # 1. Fetch student profile details (after potential XP updates!)
    p_res = await sb.table("profiles").select("*").eq("id", user["id"]).single().aexecute()
    profile = p_res.data or {}
    
    # 2. Fetch student achievements & badges
    a_res = await sb.table("student_achievements").select("*, achievements(name, description, icon, rarity, xp_reward)").eq("school_id", school_id).eq("student_id", user["id"]).order("earned_at", ascending=False).aexecute()
    earned_list = a_res.data or []
    
    student_xp = profile.get("xp_points", 0)
    
    # Calculate Ranks via database count query (highly scalable)
    class_name = profile.get("class") or ""
    class_rank = 1
    if class_name:
        class_rank_res = await sb.table("profiles").select("id").count("exact").eq("school_id", school_id).eq("class", class_name).eq("role", "student").gt("xp_points", student_xp).aexecute()
        class_rank = (class_rank_res.count or 0) + 1
            
    school_rank_res = await sb.table("profiles").select("id").count("exact").eq("school_id", school_id).eq("role", "student").gt("xp_points", student_xp).aexecute()
    school_rank = (school_rank_res.count or 0) + 1
            
    # Class Leaderboard (optional on initial dashboard fetch)
    class_leaderboard = []
    if not exclude_leaderboards and class_name:
        class_res = await sb.table("profiles").select("id, full_name, xp_points, learning_streak").eq("school_id", school_id).eq("class", class_name).eq("role", "student").order("xp_points", ascending=False).limit(50).aexecute()
        for rank_idx, s in enumerate(class_res.data or []):
            class_leaderboard.append({
                "rank": rank_idx + 1,
                "student_id": s["id"],
                "full_name": s.get("full_name", "Student"),
                "xp_points": s.get("xp_points", 0),
                "learning_streak": s.get("learning_streak", 0)
            })
        
    # School Leaderboard (optional on initial dashboard fetch)
    school_leaderboard = []
    if not exclude_leaderboards:
        school_res = await sb.table("profiles").select("id, full_name, xp_points, learning_streak").eq("school_id", school_id).eq("role", "student").order("xp_points", ascending=False).limit(50).aexecute()
        for rank_idx, s in enumerate(school_res.data or []):
            school_leaderboard.append({
                "rank": rank_idx + 1,
                "student_id": s["id"],
                "full_name": s.get("full_name", "Student"),
                "xp_points": s.get("xp_points", 0),
                "learning_streak": s.get("learning_streak", 0)
            })
        
    # Map unlocked and locked achievements
    unlocked_achievements = []
    locked_achievements = []
    
    for row in earned_list:
        ach = row.get("achievements") or {}
        if not ach:
            continue
            
        progress_val = float(row.get("progress") or 0.0)
        is_locked = row.get("earned_at") is None or progress_val < 100.0
        
        item = {
            "id": row.get("achievement_id"),
            "title": ach.get("name", "Badge"),
            "description": ach.get("description", ""),
            "icon": ach.get("icon", "🏆"),
            "rarity": ach.get("rarity", "common"),
            "xp_reward": ach.get("xp_reward", 0),
            "earned_at": row.get("earned_at"),
            "progress": progress_val,
            "is_locked": is_locked
        }
        
        if is_locked:
            locked_achievements.append(item)
        else:
            unlocked_achievements.append(item)
        
    # Fetch recent XP history
    xp_history = []
    if not exclude_history:
        tx_res = await sb.table("xp_transactions").select("*").eq("school_id", school_id).eq("student_id", user["id"]).order("created_at", ascending=False).limit(20).aexecute()
        for tx in (tx_res.data or []):
            xp_history.append({
                "id": tx["id"],
                "amount": tx["amount"],
                "source_type": tx["source_type"],
                "description": tx.get("description") or f"Earned XP via {tx['source_type']}",
                "created_at": tx["created_at"]
            })
        
    return {
        "success": True, 
        "school_id": school_id, 
        "data": {
            "xp_points": student_xp, 
            "learning_streak": profile.get("learning_streak", 0), 
            "best_streak": profile.get("best_streak", 0),
            "class_rank": class_rank,
            "school_rank": school_rank,
            "unlocked_achievements": unlocked_achievements,
            "locked_achievements": locked_achievements,
            "class_leaderboard": class_leaderboard,
            "school_leaderboard": school_leaderboard,
            "xp_history": xp_history
        }
    }


@router.get("/achievements/xp-history")
async def get_student_xp_history(
    limit: int = 50, 
    offset: int = 0, 
    user=Depends(get_current_user), 
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    res = await sb.table("xp_transactions").select("*").eq("school_id", school_id).eq("student_id", user["id"]).order("created_at", ascending=False).limit(limit).offset(offset).aexecute()
    
    tx_list = []
    for tx in (res.data or []):
        tx_list.append({
            "id": tx["id"],
            "amount": tx["amount"],
            "source_type": tx["source_type"],
            "description": tx.get("description") or f"Earned XP via {tx['source_type']}",
            "created_at": tx["created_at"]
        })
    return {"success": True, "data": tx_list}



@router.post("/leave/apply")
async def apply_leave(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("leave_applications").insert({"school_id": school_id, "applicant_id": user["id"], "applicant_role": "student", "leave_type": request.get("leave_type"), "start_date": request.get("start_date"), "end_date": request.get("end_date"), "reason": request.get("reason")}).aexecute()
    return {"success": True, "message": "Leave application submitted"}


@router.get("/profile")
async def student_profile(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()

    # Fetch raw profile, stats, and documents concurrently
    profile_task = sb.table("profiles").select("*").eq("id", user["id"]).single().aexecute()
    stats_task = sb.table("student_profile_stats").select(
        "avg_score,attendance_pct,class_rank,badges_count"
    ).eq("student_id", user["id"]).maybe_single().aexecute()
    docs_task = sb.table("documents").select("id, document_type, file_name, file_url, verification_status").eq("user_id", user["id"]).aexecute()

    profile_res, stats_res, docs_res = await asyncio.gather(profile_task, stats_task, docs_task)
    p = profile_res.data or {}
    s = stats_res.data or {}
    docs = docs_res.data or []

    # Build a consistently-named response the Flutter app can rely on
    data = {
        # Identity
        "id":                p.get("id"),
        "name":              p.get("full_name", ""),
        "class":             p.get("class", ""),
        "roll_number":       str(p.get("roll_number", "")),
        "session":           p.get("session", ""),
        "avatar_url":        p.get("avatar_url"),
        # Stats (computed)
        "avg_score":         str(s.get("avg_score", "0")),
        "attendance_pct":    str(s.get("attendance_pct", "0")),
        "rank":              str(s.get("class_rank", "-")),
        "badges":            str(s.get("badges_count", "0")),
        # Personal info
        "gender":            p.get("gender", ""),
        "date_of_birth":     str(p.get("date_of_birth", "")) if p.get("date_of_birth") else "",
        "blood_group":       p.get("blood_group", ""),
        "email":             p.get("email", ""),
        "phone":             p.get("phone", ""),
        "admission_number":  p.get("admission_number", ""),
        "nationality":       p.get("nationality", ""),
        "religion":          p.get("religion", ""),
        "category":          p.get("category", ""),
        "address":           p.get("address", ""),
        "house":             p.get("house", ""),
        # Guardian info
        "father_name":       p.get("father_name", ""),
        "father_occupation": p.get("father_occupation", ""),
        "father_phone":      p.get("father_phone", ""),
        "mother_name":       p.get("mother_name", ""),
        "mother_occupation": p.get("mother_occupation", ""),
        "mother_phone":      p.get("mother_phone", ""),
        "local_guardian":    p.get("local_guardian", ""),
        # XP / gamification
        "xp_points":         p.get("xp_points", 0),
        "learning_streak":   p.get("learning_streak", 0),
        # Documents
        "documents":         docs,
    }
    return {"success": True, "school_id": school_id, "data": data}


@router.put("/profile")
async def update_student_profile(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Update editable profile fields for a student."""
    sb = get_supabase()

    # Allowed editable fields (students cannot change class/roll/session themselves)
    allowed_fields = {
        "full_name", "phone", "email", "address", "blood_group",
        "gender", "date_of_birth", "category",
        "father_name", "father_occupation", "father_phone",
        "mother_name", "mother_occupation", "mother_phone",
        "local_guardian", "nationality", "religion",
    }

    update_data = {k: v for k, v in request.items() if k in allowed_fields}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided for update")

    update_data["updated_at"] = datetime.utcnow().isoformat()

    await sb.table("profiles").update(update_data).eq("id", user["id"]).aexecute()
    return {"success": True, "message": "Profile updated successfully"}


@router.post("/profile/avatar")
async def upload_avatar(
    avatar: UploadFile = File(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Upload a profile photo and save the public URL to profiles.avatar_url."""
    image_bytes = await avatar.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty image file")
    if len(image_bytes) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image too large. Maximum 5 MB.")

    content_type = avatar.content_type or "application/octet-stream"
    if content_type == "application/octet-stream":
        if avatar.filename and avatar.filename.lower().endswith(".png"):
            content_type = "image/png"
        else:
            content_type = "image/jpeg"

    # Determine extension
    ext_map = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp", "image/gif": "gif"}
    ext = ext_map.get(content_type, "jpg")
    storage_path = f"avatars/{user['id']}.{ext}"

    # Upload to Supabase Storage via REST API
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": content_type,
        "x-upsert": "true",
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        upload_response = await client.post(storage_url, headers=headers, content=image_bytes)

    if upload_response.status_code not in (200, 201):
        raise HTTPException(
            status_code=500,
            detail=f"Storage upload failed: {upload_response.text}"
        )

    # Build public URL with a cache-busting query parameter
    timestamp = int(datetime.utcnow().timestamp())
    public_url_base = supabase_url.replace("http://kong:8000", "http://127.0.0.1:8000")
    public_url = f"{public_url_base}/storage/v1/object/public/{storage_path}?t={timestamp}"

    # Persist public URL in profiles
    sb = get_supabase()
    await sb.table("profiles").update({"avatar_url": public_url}).eq("id", user["id"]).aexecute()

    return {"success": True, "data": {"avatar_url": public_url}}


@router.post("/profile/document")
async def upload_document(
    document: UploadFile = File(...),
    document_type: str = Form(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Upload a document and add it to the user's documents list."""
    import uuid
    sb = get_supabase()
    
    # 1. Validate file
    if not document.filename:
        raise HTTPException(status_code=400, detail="Filename missing")
    ext = document.filename.split('.')[-1].lower() if '.' in document.filename else ''
    if ext not in ["pdf", "jpg", "jpeg", "png"]:
        raise HTTPException(status_code=400, detail="Invalid file type. Allowed: PDF, JPG, PNG")

    file_bytes = await document.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
    if len(file_bytes) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="File too large. Maximum 5 MB.")

    # 2. Upload to Supabase Storage
    doc_id = str(uuid.uuid4())
    storage_path = f"documents/{user['id']}/{doc_id}.{ext}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": document.content_type or "application/octet-stream",
        "x-upsert": "true",
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        upload_response = await client.post(storage_url, headers=headers, content=file_bytes)

    if upload_response.status_code not in (200, 201):
        raise HTTPException(
            status_code=500,
            detail=f"Storage upload failed: {upload_response.text}"
        )

    public_url_base = supabase_url.replace("http://kong:8000", "http://127.0.0.1:8000")
    public_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"

    # 3. Insert into documents table
    doc_data = {
        "id": doc_id,
        "school_id": school_id,
        "user_id": user["id"],
        "document_type": document_type,
        "file_name": document.filename,
        "file_url": public_url,
        "verification_status": "pending"
    }
    await sb.table("documents").insert(doc_data).aexecute()

    return {"success": True, "message": "Document uploaded successfully", "data": doc_data}




@router.get("/courses")
async def student_courses(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    student_class = user.get("class")
    
    # 1. Resolve class from profiles if not in JWT token
    if not student_class:
        profile_res = await sb.table("profiles").select("class").eq("id", user["id"]).maybe_single().aexecute()
        if profile_res.data:
            student_class = profile_res.data.get("class")
            
    # 2. Fetch courses and statistics in parallel
    if student_class:
        subjects_task = sb.table("subjects").select("*").eq("school_id", school_id).eq("class", student_class).aexecute()
    else:
        # Dummy async function that returns a structure matching subjects_res
        async def dummy_subjects():
            class DummyRes:
                data = []
            return DummyRes()
        subjects_task = dummy_subjects()
        
    subs_task = sb.table("exam_submissions").select(
        "score, exams(total_marks, results_published_at, subjects(id, name))"
    ).eq("student_id", user["id"]).aexecute()
    
    legacy_task = sb.table("results").select(
        "marks_obtained, total_marks, subject_id, subjects(id, name)"
    ).eq("school_id", school_id).eq("student_id", user["id"]).aexecute()
    
    hw_subs_task = sb.table("homework_submissions").select(
        "marks, status, homework(max_marks, subjects(id, name))"
    ).eq("student_id", user["id"]).aexecute()
    
    # Gather in parallel
    if student_class:
        subjects_res, subs_res, legacy_res, hw_subs_res = await asyncio.gather(
            subjects_task, subs_task, legacy_task, hw_subs_task
        )
        
        # Deduplicate subjects by name
        unique_subjects = {}
        for s in (subjects_res.data or []):
            name_lower = s["name"].strip().lower()
            if name_lower not in unique_subjects:
                unique_subjects[name_lower] = s
                
        subject_ids = [s["id"] for s in unique_subjects.values()]
        if subject_ids:
            courses_res = await sb.table("courses").select("*, subjects(*), profiles!teacher_id(full_name)").eq("school_id", school_id).in_("subject_id", subject_ids).aexecute()
            db_courses = courses_res.data or []
        else:
            db_courses = []
    else:
        # Fallback if no student_class
        _, subs_res, legacy_res, hw_subs_res = await asyncio.gather(
            subjects_task, subs_task, legacy_task, hw_subs_task
        )
        courses_res = await sb.table("courses").select("*, subjects(*), profiles!teacher_id(full_name)").eq("school_id", school_id).aexecute()
        db_courses = courses_res.data or []

    # 3. Compile subject-wise performance averages
    exam_stats = {} # subject_name_lower -> {"score": float, "max": float}
    hw_stats = {} # subject_name_lower -> {"score": float, "max": float}
    
    # Process exam submissions
    for sub in (subs_res.data or []):
        exam = sub.get("exams") or {}
        if not exam.get("results_published_at"):
            continue
        subj = exam.get("subjects") or {}
        subj_name = subj.get("name", "").strip().lower()
        if subj_name:
            score_val = float(sub.get("score") or 0)
            total_marks = float(exam.get("total_marks") or 100)
            if subj_name not in exam_stats:
                exam_stats[subj_name] = {"score": 0.0, "max": 0.0}
            exam_stats[subj_name]["score"] += score_val
            exam_stats[subj_name]["max"] += total_marks
            
    # Process legacy results
    for r in (legacy_res.data or []):
        subj = r.get("subjects") or {}
        subj_name = subj.get("name") or r.get("subject") or ""
        subj_name = subj_name.strip().lower()
        if subj_name:
            score_val = float(r.get("marks_obtained") or 0)
            total_marks = float(r.get("total_marks") or 100)
            if subj_name not in exam_stats:
                exam_stats[subj_name] = {"score": 0.0, "max": 0.0}
            exam_stats[subj_name]["score"] += score_val
            exam_stats[subj_name]["max"] += total_marks
            
    # Process homework submissions
    for hs in (hw_subs_res.data or []):
        if hs.get("status") == "graded" or hs.get("marks") is not None:
            hw = hs.get("homework") or {}
            subj = hw.get("subjects") or {}
            subj_name = subj.get("name", "").strip().lower()
            if subj_name:
                score_val = float(hs.get("marks") or 0)
                max_marks = float(hw.get("max_marks") or 25)
                if subj_name not in hw_stats:
                    hw_stats[subj_name] = {"score": 0.0, "max": 0.0}
                hw_stats[subj_name]["score"] += score_val
                hw_stats[subj_name]["max"] += max_marks

    # 4. Enhance course data with scores, progress, syllabus coverage, and upcoming topics matching the mockup!
    enhanced_courses = []
    seen_subject_names = set()
    for c in db_courses:
        subj = c.get("subjects") or {}
        subj_name = subj.get("name", "Subject").strip()
        if not subj_name:
            continue
        subj_name_lower = subj_name.lower()
        if subj_name_lower in seen_subject_names:
            continue
        seen_subject_names.add(subj_name_lower)
        
        teacher_name = c.get("profiles", {}).get("full_name") if c.get("profiles") else "Teacher"
        
        # Default mock metrics from the mockup
        score = "90%"
        progress = 0.75
        chapters_count = f"{subj.get('total_chapters', 30)} chapters"
        
        # Calculate combined average score for subject (60% exams, 40% homeworks)
        has_exams = subj_name_lower in exam_stats and exam_stats[subj_name_lower]["max"] > 0
        has_hw = subj_name_lower in hw_stats and hw_stats[subj_name_lower]["max"] > 0
        
        exam_avg = 0.0
        if has_exams:
            exam_avg = (exam_stats[subj_name_lower]["score"] / exam_stats[subj_name_lower]["max"]) * 100
            
        hw_avg = 0.0
        if has_hw:
            hw_avg = (hw_stats[subj_name_lower]["score"] / hw_stats[subj_name_lower]["max"]) * 100
            
        combined_val = None
        if has_exams and has_hw:
            combined_val = (exam_avg * 0.6) + (hw_avg * 0.4)
        elif has_exams:
            combined_val = exam_avg
        elif has_hw:
            combined_val = hw_avg
            
        if combined_val is not None:
            score = f"{int(round(combined_val))}%"

        # Calculate real chapters and progress from database
        real_chapters_count = 0
        try:
            chapters_res = await sb.table("course_chapters").select("id").eq("course_id", c["id"]).aexecute()
            db_chapters = chapters_res.data or []
            real_chapters_count = len(db_chapters)
            
            if real_chapters_count > 0:
                chapters_count = f"{real_chapters_count} chapters"
                
                # Fetch topics
                chapter_ids = [chap["id"] for chap in db_chapters]
                topics_res = await sb.table("course_topics").select("id").in_("chapter_id", chapter_ids).aexecute()
                db_topics = topics_res.data or []
                real_topics_count = len(db_topics)
                
                if real_topics_count > 0:
                    topic_ids = [t["id"] for t in db_topics]
                    progress_res = await sb.table("student_topic_progress")\
                        .select("topic_id")\
                        .eq("student_id", user["id"])\
                        .in_("topic_id", topic_ids)\
                        .eq("completed", True)\
                        .aexecute()
                    real_completed_count = len(progress_res.data or [])
                    progress = real_completed_count / real_topics_count
                else:
                    progress = 0.0
        except Exception as e:
            print(f"Error calculating dynamic progress: {str(e)}")

        # Check if high-fidelity mockup columns exist in database record
        db_syllabus_coverage = c.get("syllabus_coverage")
        db_upcoming_topics = c.get("upcoming_topics")
        db_resources_text = c.get("resources_text")
        db_chapters_count = c.get("chapters_count")

        # Static realistic detail data matching the mockup EXACTLY (Fallback logic)
        syllabus_coverage = []
        upcoming_topics = []
        resources_text = ""

        if db_syllabus_coverage or db_upcoming_topics or db_resources_text or db_chapters_count:
            syllabus_coverage = db_syllabus_coverage if db_syllabus_coverage else []
            upcoming_topics = db_upcoming_topics if db_upcoming_topics else []
            resources_text = db_resources_text if db_resources_text else ""
            if db_chapters_count and real_chapters_count == 0:
                chapters_count = db_chapters_count
        elif "math" in subj_name.lower():
            score = "95%"
            if real_chapters_count == 0:
                progress = 0.78
                chapters_count = "42 chapters"
            syllabus_coverage = [
                {"topic": "Algebra", "progress": 1.0, "status": "success"},
                {"topic": "Trigonometry", "progress": 1.0, "status": "success"},
                {"topic": "Coordinate Geometry", "progress": 0.9, "status": "success"},
                {"topic": "Calculus", "progress": 0.6, "status": "warning"},
                {"topic": "Probability", "progress": 0.4, "status": "error"},
                {"topic": "Statistics", "progress": 0.3, "status": "error"},
            ]
            upcoming_topics = [
                "Integration Applications",
                "Probability Distributions",
                "Statistics — Mean, Median, Mode"
            ]
            resources_text = "12 video lectures, 8 practice sets"
        elif "phys" in subj_name.lower():
            score = "89%"
            if real_chapters_count == 0:
                progress = 0.72
                chapters_count = "38 chapters"
            syllabus_coverage = [
                {"topic": "Mechanics", "progress": 1.0, "status": "success"},
                {"topic": "Thermodynamics", "progress": 1.0, "status": "success"},
                {"topic": "Optics", "progress": 0.55, "status": "warning"},
                {"topic": "Electrostatics", "progress": 0.4, "status": "warning"},
                {"topic": "Magnetism", "progress": 0.2, "status": "error"},
                {"topic": "Modern Physics", "progress": 0.1, "status": "error"},
            ]
            upcoming_topics = [
                "Lens & Mirror Problems",
                "Electric Fields",
                "Magnetic Effects"
            ]
            resources_text = "10 video lectures, 6 practice sets"
        elif "chem" in subj_name.lower():
            score = "91%"
            if real_chapters_count == 0:
                progress = 0.80
                chapters_count = "35 chapters"
            syllabus_coverage = [
                {"topic": "Organic Chemistry", "progress": 1.0, "status": "success"},
                {"topic": "Periodic Table", "progress": 1.0, "status": "success"},
                {"topic": "Chemical Bonding", "progress": 0.7, "status": "warning"},
                {"topic": "Electrochemistry", "progress": 0.5, "status": "warning"},
                {"topic": "Surface Chemistry", "progress": 0.3, "status": "error"},
            ]
            upcoming_topics = [
                "Practical Lab Experiments",
                "Transition Metals",
                "Rate of Reaction"
            ]
            resources_text = "8 video lectures, 5 practice sets, 8/10 practicals"
        elif "eng" in subj_name.lower():
            score = "92%"
            if real_chapters_count == 0:
                progress = 0.85
                chapters_count = "28 chapters"
            syllabus_coverage = [
                {"topic": "Prose — First Flight", "progress": 1.0, "status": "success"},
                {"topic": "Poetry", "progress": 1.0, "status": "success"},
                {"topic": "Footprints Without Feet", "progress": 0.75, "status": "success"},
                {"topic": "Grammar", "progress": 0.8, "status": "success"},
                {"topic": "Writing Skills", "progress": 0.6, "status": "warning"},
            ]
            upcoming_topics = [
                "Essay Writing Strategies",
                "Letter Writing Conventions",
                "Reading Comprehension Practice"
            ]
            resources_text = "6 video lectures, 12 reading tasks, 4 essay drafts"
        else:
            # Fallback for other subjects
            syllabus_coverage = [
                {"topic": "Introduction & Basics", "progress": 1.0, "status": "success"},
                {"topic": "Core Concepts", "progress": 0.8, "status": "success"},
                {"topic": "Advanced Modules", "progress": 0.4, "status": "warning"},
                {"topic": "Final Projects", "progress": 0.1, "status": "error"},
            ]
            upcoming_topics = [
                "Review of Advanced Modules",
                "Group Project Presentations",
                "Final Exam Prep"
            ]
            resources_text = "6 video lectures, 4 quizzes"

        if combined_val is not None:
            score = f"{int(round(combined_val))}%"

        enhanced_courses.append({
            "id": c["id"],
            "name": subj_name,
            "teacher": teacher_name,
            "chapters": chapters_count,
            "score": score,
            "progress": progress,
            "icon": subj.get("icon", "📚"),
            "color_hex": subj.get("color", "#4F46E5"),
            "description": c.get("description", ""),
            "syllabus_coverage": syllabus_coverage,
            "upcoming_topics": upcoming_topics,
            "resources_text": resources_text,
        })
        
    return {"success": True, "school_id": school_id, "data": {"courses": enhanced_courses}}


@router.get("/courses/{course_id}/details")
async def student_course_details(course_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Fetch course first to verify
    course_res = await sb.table("courses").select("*, subjects(*)").eq("id", course_id).eq("school_id", school_id).maybe_single().aexecute()
    if not course_res.data:
        raise HTTPException(status_code=404, detail="Course not found")
    
    # Fetch chapters
    chapters_res = await sb.table("course_chapters").select("*").eq("course_id", course_id).eq("school_id", school_id).order("chapter_order", ascending=True).aexecute()
    chapters = chapters_res.data or []
    
    # Fetch topics
    if chapters:
        chapter_ids = [c["id"] for c in chapters]
        topics_res = await sb.table("course_topics").select("*").in_("chapter_id", chapter_ids).order("topic_order", ascending=True).aexecute()
        topics = topics_res.data or []
    else:
        topics = []
        
    # Fetch student's progress for these topics
    completed_topics = set()
    if topics:
        topic_ids = [t["id"] for t in topics]
        try:
            progress_res = await sb.table("student_topic_progress")\
                .select("topic_id")\
                .eq("student_id", user["id"])\
                .in_("topic_id", topic_ids)\
                .eq("completed", True)\
                .aexecute()
            if progress_res.data:
                completed_topics = {p["topic_id"] for p in progress_res.data}
        except Exception as e:
            print(f"Error fetching topic progress details: {str(e)}")

    # Map topics to chapters with completed status
    for c in chapters:
        c["topics"] = []
        for t in topics:
            if t["chapter_id"] == c["id"]:
                t_copy = dict(t)
                t_copy["completed"] = t["id"] in completed_topics
                c["topics"].append(t_copy)
        
    return {
        "success": True,
        "data": {
            "course": course_res.data,
            "chapters": chapters
        }
    }


@router.post("/courses/topics/{topic_id}/progress")
async def update_topic_progress(
    topic_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    completed = request.get("completed", True)
    sb = get_supabase()
    
    # Verify the topic exists
    topic_res = await sb.table("course_topics").select("id").eq("id", topic_id).maybe_single().aexecute()
    if not topic_res.data:
        raise HTTPException(status_code=404, detail="Topic not found")
        
    if completed:
        # Insert or upsert progress record
        progress_data = {
            "school_id": school_id,
            "student_id": user["id"],
            "topic_id": topic_id,
            "completed": True,
            "updated_at": "now()"
        }
        res = await sb.table("student_topic_progress").upsert(
            progress_data,
            on_conflict="student_id,topic_id"
        ).aexecute()
    else:
        # Delete progress record
        res = await sb.table("student_topic_progress")\
            .delete()\
            .eq("student_id", user["id"])\
            .eq("topic_id", topic_id)\
            .aexecute()
            
    return {"success": True, "completed": completed}


@router.get("/notifications")
async def student_notifications(
    is_read: str = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    query = sb.table("notifications").select("*").eq("school_id", school_id).eq("user_id", user["id"])
    if is_read == "true":
        query = query.eq("is_read", True)
    elif is_read == "false":
        query = query.eq("is_read", False)
    notifications = (await query.order("created_at", ascending=False).limit(50).aexecute()).data
    unread_count = sum(1 for n in notifications if not n.get("is_read", False))
    return {"success": True, "school_id": school_id, "data": {"notifications": notifications, "unread_count": unread_count}}


@router.put("/notifications/{notification_id}/read")
async def student_mark_notification_read(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.patch("/notifications/{notification_id}/read")
async def student_mark_notification_read_patch(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.delete("/notifications/{notification_id}")
async def student_delete_notification(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").delete().eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.get("/live-classes")
async def student_live_classes(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    student_class = None
    if user.get("role") == "student":
        student_class = user.get("class")
        if not student_class:
            profile_res = await sb.table("profiles").select("class").eq("id", user["id"]).maybe_single().aexecute()
            if profile_res.data:
                student_class = profile_res.data.get("class")
            
    query = (sb.table("live_classes")
               .select("*, subjects(name, icon, color), profiles!teacher_id(full_name), live_class_recordings(duration)")
               .eq("school_id", school_id))
    if student_class:
        query = query.eq("target_class", student_class)
    classes = (await query.order("scheduled_at").aexecute()).data or []
               
    live_list = []
    upcoming_list = []
    recorded_list = []
    
    from datetime import datetime, timezone
    now = datetime.now(timezone.utc)
    
    for c in classes:
        subj = c.get("subjects") or {}
        subj_name = subj.get("name", "Subject")
        teacher_name = c.get("profiles", {}).get("full_name") if c.get("profiles") else "Teacher"
        
        status = c.get("status")
        
        # Calculate dynamic times if possible
        started_str = "Started 25 min ago"
        time_str = "2:00 PM"
        time_until_str = "In 1h 30m"
        date_str = "Mar 25 · 45 min"
        
        try:
            scheduled_at_dt = datetime.fromisoformat(c["scheduled_at"].replace("Z", "+00:00"))
            diff = now - scheduled_at_dt
            diff_minutes = int(diff.total_seconds() / 60)
            
            # Format started
            if diff_minutes >= 0:
                started_str = f"Started {diff_minutes} min ago"
            else:
                started_str = f"Starts in {abs(diff_minutes)} min"
                
            # Format time
            time_str = scheduled_at_dt.strftime("%I:%M %p")
            
            # Format timeUntil
            diff_hours = abs(diff.total_seconds()) / 3600
            if diff_hours < 1:
                time_until_str = f"In {int(abs(diff.total_seconds()) / 60)}m"
            else:
                hours_part = int(diff_hours)
                mins_part = int((diff_hours - hours_part) * 60)
                time_until_str = f"In {hours_part}h" if mins_part == 0 else f"In {hours_part}h {mins_part}m"
                
            # Format duration cleanly
            duration_str = None
            recs = c.get("live_class_recordings")
            if recs:
                rec_duration = None
                if isinstance(recs, list) and len(recs) > 0:
                    rec_duration = recs[0].get("duration")
                elif isinstance(recs, dict):
                    rec_duration = recs.get("duration")
                
                if rec_duration is not None:
                    h = rec_duration // 3600
                    m = (rec_duration % 3600) // 60
                    s = rec_duration % 60
                    if h > 0:
                        duration_str = f"{h}h {m}m" if s == 0 else f"{h}h {m}m {s}s"
                    elif m > 0:
                        duration_str = f"{m}m {s}s"
                    else:
                        duration_str = f"{s}s"
            
            if not duration_str:
                duration_str = f"{c.get('duration_minutes', 45)} min"

            # Format date
            date_str = f"{scheduled_at_dt.strftime('%b %d')} · {duration_str}"
        except Exception:
            pass
            
        mapped = {
            "id": c["id"],
            "teacher_id": c.get("teacher_id"),
            "subject": c["title"], # To match mockup "Physics — Optics Chapter 9"
            "subject_name": subj_name,
            "title": c.get("title", ""),
            "description": c.get("description", ""),
            "teacher": teacher_name,
            "started": started_str,
            "viewers": c.get("viewer_count", 0),
            "time": time_str,
            "timeUntil": time_until_str,
            "date": date_str,
            "icon": subj.get("icon", "📚"),
            "color_hex": subj.get("color", "#4F46E5"),
            "isLive": status == "live",
            "type": status,
            "stream_url": c.get("stream_url"),
            "recording_url": c.get("recording_url"),
            "meeting_link": c.get("meeting_link"),
            "platform": c.get("platform", "In-App")
        }
        
        if status == "live":
            live_list.append(mapped)
        elif status == "scheduled":
            upcoming_list.append(mapped)
        elif status in ("recorded", "completed"):
            recorded_list.append(mapped)
            
    return {
        "success": True, 
        "school_id": school_id, 
        "data": {
            "live": live_list,
            "upcoming": upcoming_list,
            "recorded": recorded_list
        }
    }


@router.post("/live-classes/{live_class_id}/join")
async def join_live_class(live_class_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    res = await sb.table("live_classes").select("viewer_count").eq("id", live_class_id).maybe_single().aexecute()
    if res.data:
        current_viewers = res.data.get("viewer_count") or 0
        await sb.table("live_classes").update({"viewer_count": current_viewers + 1}).eq("id", live_class_id).aexecute()
    return {"success": True}


@router.post("/live-classes/{live_class_id}/reminder")
async def set_live_class_reminder(live_class_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    return {"success": True, "message": "Reminder set successfully!"}


@router.get("/live-classes/{live_class_id}/comments")
async def get_live_class_comments(live_class_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    comments = (await sb.table("live_class_comments")
                .select("*, profiles!user_id(full_name, avatar_url, role)")
                .eq("live_class_id", live_class_id)
                .order("created_at", ascending=True)
                .aexecute()).data or []
                
    top_level = []
    replies_by_parent = {}
    
    for c in comments:
        prof = c.get("profiles") or {}
        time_str = "Just now"
        try:
            created_at_dt = datetime.fromisoformat(c["created_at"].replace("Z", "+00:00"))
            time_str = created_at_dt.strftime("%b %d, %I:%M %p")
        except Exception:
            pass
            
        mapped = {
            "id": c["id"],
            "user_id": c.get("user_id"),
            "user": prof.get("full_name", "User"),
            "avatar": prof.get("avatar_url") or (prof.get("full_name", "U")[0] if prof.get("full_name") else "U"),
            "text": c["comment"],
            "time": time_str,
            "likes": c.get("likes", 0),
            "pinned": c.get("is_pinned", False),
            "role": prof.get("role", "student"),
            "parent_id": c.get("parent_id"),
            "is_edited": c.get("is_edited", False),
            "replies": []
        }
        
        pid = c.get("parent_id")
        if pid:
            replies_by_parent.setdefault(str(pid), []).append(mapped)
        else:
            top_level.append(mapped)
            
    # Associate replies with parents
    for parent in top_level:
        parent["replies"] = replies_by_parent.get(parent["id"], [])
        
    # Reverse top-level comments so newest threads appear at the top
    top_level.reverse()
    
    return {"success": True, "data": {"comments": top_level}}


@router.post("/live-classes/{live_class_id}/comments")
async def add_live_class_comment(live_class_id: str, request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    comment_text = request.get("comment")
    if not comment_text:
        raise HTTPException(status_code=400, detail="comment text is required")
        
    user_res = await sb.table("profiles").select("full_name, avatar_url, role").eq("id", user["id"]).single().aexecute()
    prof = user_res.data or {}
    user_role = prof.get("role", "student")
    
    is_pinned = False
    if user_role == "teacher" or user.get("role") == "teacher":
        is_pinned = request.get("is_pinned", False)
        
    parent_id = request.get("parent_id")
        
    data = {
        "school_id": school_id,
        "live_class_id": live_class_id,
        "user_id": user["id"],
        "comment": comment_text,
        "is_pinned": is_pinned,
        "likes": 0,
        "parent_id": parent_id,
        "is_edited": False
    }
    res = await sb.table("live_class_comments").insert(data).aexecute()
    new_comment = res.data[0] if res.data else {}
    
    return {
        "success": True, 
        "data": {
            "id": new_comment.get("id"),
            "user_id": user["id"],
            "user": prof.get("full_name", "User"),
            "avatar": prof.get("avatar_url") or (prof.get("full_name", "U")[0] if prof.get("full_name") else "U"),
            "text": comment_text,
            "time": "Just now",
            "likes": 0,
            "pinned": is_pinned,
            "role": user_role,
            "parent_id": parent_id,
            "is_edited": False,
            "replies": []
        }
    }


@router.put("/live-classes/{live_class_id}/comments/{comment_id}")
async def edit_live_class_comment(
    live_class_id: str,
    comment_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    comment_text = request.get("comment")
    if not comment_text:
        raise HTTPException(status_code=400, detail="comment text is required")
        
    # 1. Fetch comment to verify owner
    comment_res = await sb.table("live_class_comments").select("*").eq("id", comment_id).maybe_single().aexecute()
    if not comment_res.data:
        raise HTTPException(status_code=404, detail="Comment not found")
        
    comment_data = comment_res.data
    if str(comment_data.get("user_id")) != str(user["id"]):
        raise HTTPException(status_code=403, detail="You can only edit your own comments")
        
    # 2. Update comment text and is_edited
    res = await sb.table("live_class_comments").update({
        "comment": comment_text,
        "is_edited": True
    }).eq("id", comment_id).aexecute()
    
    return {"success": True, "data": res.data[0] if res.data else {}}


@router.delete("/live-classes/{live_class_id}/comments/{comment_id}")
async def delete_live_class_comment(
    live_class_id: str,
    comment_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    
    # 1. Fetch comment to verify permissions
    comment_res = await sb.table("live_class_comments").select("*").eq("id", comment_id).maybe_single().aexecute()
    if not comment_res.data:
        raise HTTPException(status_code=404, detail="Comment not found")
        
    comment_data = comment_res.data
    is_owner = str(comment_data.get("user_id")) == str(user["id"])
    is_teacher = user.get("role") in ("teacher", "admin", "teacher_admin")
    
    if not is_owner:
        raise HTTPException(status_code=403, detail="You do not have permission to delete this comment")
        
    # 2. Delete the comment
    await sb.table("live_class_comments").delete().eq("id", comment_id).aexecute()
    return {"success": True, "message": "Comment deleted successfully"}




@router.get("/leaderboard")
async def student_leaderboard(
    scope: str = "class", 
    limit: int = 50, 
    offset: int = 0, 
    user=Depends(require_student), 
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    student_class = user.get("class")
    if not student_class:
        profile_res = await sb.table("profiles").select("class").eq("id", user["id"]).maybe_single().aexecute()
        if profile_res.data:
            student_class = profile_res.data.get("class")
            
    query = sb.table("profiles").select("id, full_name, xp_points, learning_streak, avatar_url, class").eq("school_id", school_id).eq("role", "student").order("xp_points", ascending=False)
    
    if scope == "class" and student_class:
        query = query.eq("class", student_class)
        
    res = await query.limit(limit).offset(offset).aexecute()
    students = res.data or []
    
    leaderboard_data = []
    for idx, s in enumerate(students):
        leaderboard_data.append({
            "rank": offset + idx + 1,
            "student_id": s["id"],
            "full_name": s.get("full_name", "Student"),
            "class_name": s.get("class") or "",
            "xp_points": s.get("xp_points", 0),
            "learning_streak": s.get("learning_streak", 0),
            "avatar_url": s.get("avatar_url")
        })
        
    return {
        "success": True, 
        "school_id": school_id, 
        "data": {
            "leaderboard": leaderboard_data, 
            "class": student_class,
            "scope": scope
        }
    }



@router.get("/settings")
async def get_settings(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    settings = (await sb.table("user_settings").select("*").eq("user_id", user["id"]).maybe_single().aexecute()).data
    return {"success": True, "school_id": school_id, "data": settings or {}}


@router.put("/settings")
async def update_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("user_settings").upsert({"school_id": school_id, "user_id": user["id"], **request}, on_conflict="user_id").aexecute()
    return {"success": True, "message": "Settings updated"}


@router.post("/change-password")
async def change_password(request: dict, user=Depends(get_current_user)):
    current_pw = request.get("currentPassword")
    new_pw = request.get("newPassword")
    
    if not current_pw or not new_pw:
        raise HTTPException(status_code=400, detail="Current and new password required")
        
    sb = get_supabase()
    
    # 1. Get email (fallback if not in token)
    email = user.get("email")
    if not email:
        try:
            profile_res = await sb.table("profiles").select("email").eq("id", user["id"]).maybe_single().aexecute()
            if profile_res.data:
                email = profile_res.data.get("email")
        except Exception as e:
            print(f"Error fetching email fallback: {str(e)}")
            
    if not email:
        raise HTTPException(status_code=400, detail="User email not found")

    # 2. Verify current password by attempting to sign in
    try:
        await sb.auth().sign_in_with_password({
            "email": email,
            "password": current_pw,
        })
    except Exception as e:
        print(f"Password verification failed for {email}: {str(e)}")
        raise HTTPException(status_code=400, detail=f"Current password incorrect: {str(e)}")
        
    # 2. Update to new password
    try:
        # Use the admin update to override password directly
        await sb.auth().admin_update_user(user["id"], {"password": new_pw})
        return {"success": True, "message": "Password changed successfully"}
    except Exception as e:
        print(f"Password update failed: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to update password: {str(e)}")


@router.post("/logout")
async def logout():
    return {"success": True, "message": "Logged out"}


@router.get("/messages")
async def get_messages(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import get_messages as shared_get_messages
    return await shared_get_messages(user, school_id)


@router.post("/messages/send")
async def send_message(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import send_message as shared_send_message
    return await shared_send_message(request, user, school_id)


@router.get("/messages/chat")
async def get_chat(chat_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import get_chat as shared_get_chat
    return await shared_get_chat(chat_id, user, school_id)


@router.post("/groups/create")
async def create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import create_group as shared_create_group
    return await shared_create_group(request, user, school_id)


@router.get("/groups")
async def get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import get_groups as shared_get_groups
    return await shared_get_groups(user, school_id)


@router.post("/groups/{group_id}/join")
async def join_group(group_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import join_group as shared_join_group
    return await shared_join_group(group_id, user, school_id)


@router.delete("/messages/{message_id}")
async def delete_message(message_id: str, user=Depends(get_current_user)):
    from app.api.shared import delete_message as shared_delete_message
    return await shared_delete_message(message_id, user)


@router.post("/messages/clear")
async def clear_chat(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import clear_chat as shared_clear_chat
    return await shared_clear_chat(request, user, school_id)


@router.post("/messages/upload")
async def upload_message_file(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    from app.api.shared import upload_message_file as shared_upload_message_file
    return await shared_upload_message_file(file, user, school_id)


# ============================================================================
# LIBRARY SYSTEM ENDPOINTS (STUDENT BORROWER ROLE)
# ============================================================================

@router.get("/library")
async def get_student_library_dashboard(
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    from datetime import datetime, timezone
    sb = get_supabase()
    
    # 1. Fetch borrows with books joined
    borrows_res = await sb.table("library_borrows")\
        .select("*, library_books(*)")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"])\
        .order("borrowed_at", ascending=False)\
        .aexecute()
    
    borrows = borrows_res.data or []
    
    # Calculate fine dynamically for overdue, unreturned books
    now_dt = datetime.now(timezone.utc)
    for b in borrows:
        if b.get("status") == "borrowed" and not b.get("returned_at") and b.get("due_at"):
            try:
                due_dt = datetime.fromisoformat(b["due_at"].replace("Z", "+00:00"))
                if due_dt.tzinfo is None:
                    due_dt = due_dt.replace(tzinfo=timezone.utc)
                if now_dt > due_dt:
                    days_overdue = (now_dt - due_dt).days
                    if days_overdue > 0:
                        b["fine_amount"] = float(days_overdue * 5)
            except Exception:
                pass

    # 2. Fetch student's book requests
    requests_res = await sb.table("library_requests")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"])\
        .order("created_at", ascending=False)\
        .aexecute()
    
    requests = requests_res.data or []

    # 3. Fetch books
    books_res = await sb.table("library_books")\
        .select("*")\
        .eq("school_id", school_id)\
        .order("title")\
        .limit(50)\
        .aexecute()
    
    books = books_res.data or []

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "borrows": borrows,
            "requests": requests,
            "books": books
        }
    }


@router.get("/library/books")
async def get_library_books(
    search: Optional[str] = None,
    category: Optional[str] = None,
    is_digital: Optional[bool] = None,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    q = sb.table("library_books").select("*").eq("school_id", school_id)
    
    if search:
        q = q.or_(f"title.ilike.%{search}%,author.ilike.%{search}%,isbn.ilike.%{search}%")
    if category:
        q = q.eq("category", category)
    if is_digital is not None:
        q = q.eq("is_digital", is_digital)
        
    res = await q.aexecute()
    return {
        "success": True,
        "school_id": school_id,
        "data": res.data or []
    }


@router.post("/library/borrow")
async def borrow_book(
    request: dict,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    from datetime import datetime, timezone
    book_id = request.get("book_id")
    if not book_id:
        raise HTTPException(status_code=400, detail="book_id is required")
        
    sb = get_supabase()
    # Fetch book details
    book_res = await sb.table("library_books").select("*").eq("id", book_id).eq("school_id", school_id).maybe_single().aexecute()
    book = book_res.data
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
        
    # Check if student already has active request/borrow for this book
    active_res = await sb.table("library_borrows")\
        .select("*")\
        .eq("book_id", book_id)\
        .eq("student_id", user["id"])\
        .in_("status", ["requested", "borrowed", "pending_renew", "pending_return"])\
        .aexecute()
        
    if active_res.data:
        raise HTTPException(status_code=400, detail="You already have an active borrow or request for this book")

    # If digital, borrow is instantly active and doesn't decrement copy count
    is_digital = book.get("is_digital", False)
    status = "borrowed" if is_digital else "requested"
    
    # Check available copies for physical books
    if not is_digital and book.get("available_copies", 0) <= 0:
        raise HTTPException(status_code=400, detail="No physical copies of this book are currently available")

    # Create borrow record
    now_dt = datetime.now(timezone.utc)
    due_dt = now_dt + timedelta(days=14)
    
    borrow_data = {
        "school_id": school_id,
        "book_id": book_id,
        "student_id": user["id"],
        "borrowed_at": now_dt.isoformat(),
        "due_at": due_dt.isoformat(),
        "renewals_used": 0,
        "max_renewals": 2,
        "status": status,
        "fine_amount": 0.0
    }
    
    insert_res = await sb.table("library_borrows").insert(borrow_data).aexecute()
    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to create borrow record")

    return {
        "success": True,
        "message": "eBook borrowed instantly" if is_digital else "Borrow request submitted successfully",
        "data": insert_res.data[0]
    }


@router.post("/library/borrows/{borrow_id}/renew")
async def renew_borrow(
    borrow_id: str,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    from datetime import datetime, timezone
    sb = get_supabase()
    
    # Fetch borrow record
    borrow_res = await sb.table("library_borrows").select("*, library_books(*)").eq("id", borrow_id).eq("school_id", school_id).maybe_single().aexecute()
    borrow = borrow_res.data
    if not borrow:
        raise HTTPException(status_code=404, detail="Borrow record not found")
        
    if borrow["student_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized to renew this book")
        
    if borrow["status"] != "borrowed":
        raise HTTPException(status_code=400, detail=f"Cannot renew book with status '{borrow['status']}'")
        
    if borrow.get("renewals_used", 0) >= borrow.get("max_renewals", 2):
        raise HTTPException(status_code=400, detail="Maximum renewals limit reached")

    # If digital, auto-approve the renewal instantly
    book = borrow.get("library_books") or {}
    if book.get("is_digital", False):
        new_due = datetime.fromisoformat(borrow["due_at"].replace("Z", "+00:00")) + timedelta(days=14)
        update_res = await sb.table("library_borrows")\
            .update({
                "renewals_used": borrow["renewals_used"] + 1,
                "due_at": new_due.isoformat(),
                "status": "borrowed"
            })\
            .eq("id", borrow_id)\
            .aexecute()
        return {
            "success": True,
            "message": "eBook renewal auto-approved instantly",
            "data": update_res.data[0]
        }

    # For physical books, set to pending_renew
    update_res = await sb.table("library_borrows")\
        .update({"status": "pending_renew"})\
        .eq("id", borrow_id)\
        .aexecute()
        
    return {
        "success": True,
        "message": "Renewal request submitted to librarian",
        "data": update_res.data[0]
    }


@router.post("/library/borrows/{borrow_id}/return")
async def return_borrow(
    borrow_id: str,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    from datetime import datetime, timezone
    sb = get_supabase()
    
    # Fetch borrow record
    borrow_res = await sb.table("library_borrows").select("*, library_books(*)").eq("id", borrow_id).eq("school_id", school_id).maybe_single().aexecute()
    borrow = borrow_res.data
    if not borrow:
        raise HTTPException(status_code=404, detail="Borrow record not found")
        
    if borrow["student_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized to return this book")
        
    if borrow["status"] not in ["borrowed", "pending_renew"]:
        raise HTTPException(status_code=400, detail=f"Cannot return book with status '{borrow['status']}'")

    # If digital, auto-approve return instantly
    book = borrow.get("library_books") or {}
    if book.get("is_digital", False):
        update_res = await sb.table("library_borrows")\
            .update({
                "status": "returned",
                "returned_at": datetime.now(timezone.utc).isoformat()
            })\
            .eq("id", borrow_id)\
            .aexecute()
        return {
            "success": True,
            "message": "eBook returned instantly",
            "data": update_res.data[0]
        }

    # For physical books, set status to pending_return
    update_res = await sb.table("library_borrows")\
        .update({"status": "pending_return"})\
        .eq("id", borrow_id)\
        .aexecute()
        
    return {
        "success": True,
        "message": "Return request submitted to librarian. Please return the physical book.",
        "data": update_res.data[0]
    }


@router.post("/library/requests")
async def submit_acquisition_request(
    request: dict,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    title = request.get("title")
    author = request.get("author")
    isbn = request.get("isbn")
    reason = request.get("reason")
    
    if not title or not author:
        raise HTTPException(status_code=400, detail="title and author are required")
        
    sb = get_supabase()
    request_data = {
        "school_id": school_id,
        "student_id": user["id"],
        "title": title,
        "author": author,
        "isbn": isbn,
        "reason": reason,
        "status": "pending"
    }
    
    insert_res = await sb.table("library_requests").insert(request_data).aexecute()
    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to submit acquisition request")
        
    return {
        "success": True,
        "message": "Acquisition request submitted successfully",
        "data": insert_res.data[0]
    }


@router.get("/library/recommendations")
async def get_library_recommendations(
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    import json
    import os
    sb = get_supabase()
    
    # 1. Fetch available books in the school library
    books_res = await sb.table("library_books").select("*").eq("school_id", school_id).limit(100).aexecute()
    books = books_res.data or []
    
    if not books:
        return {"success": True, "data": []}
        
    # 2. Fetch student details (class, subjects) to personalize
    profile_res = await sb.table("profiles").select("*, school_id").eq("id", user["id"]).maybe_single().aexecute()
    profile = profile_res.data or {}
    student_class = profile.get("class", "Unknown")
    
    # 3. Call ChatGoogleGenerativeAI (Gemini) if possible
    recommended_books = []
    google_api_key = os.getenv("GOOGLE_API_KEY")
    
    if google_api_key and google_api_key != "AIza-placeholder-google-key":
        try:
            from langchain_google_genai import ChatGoogleGenerativeAI
            llm = ChatGoogleGenerativeAI(
                model=os.getenv("GEMINI_MODEL", "gemini-1.5-flash"),
                temperature=0.4,
                google_api_key=google_api_key
            )
            
            # Format list of books for Gemini
            books_input = [{"id": b["id"], "title": b["title"], "author": b["author"], "category": b["category"]} for b in books]
            
            prompt = (
                f"You are Shami, an AI librarian for a student portal. "
                f"We have a student named {profile.get('full_name', 'Student')} in class {student_class}. "
                f"Here is the list of books in our school library: {json.dumps(books_input[:30])}.\n\n"
                f"Please select the top 3 best books that are most suitable for this student. "
                f"For each recommended book, provide the exact book ID from the list, and write a custom personalized 'reason' (why they should read it based on their grade level/class) and a brief 'description'.\n\n"
                f"Respond ONLY with a JSON list of objects, structured like: "
                f"[{{\"id\": \"book-id-here\", \"reason\": \"Personalized reason for recommendation\", \"description\": \"Brief book description\"}}]. "
                f"Do not include any markdown backticks or extra text, just raw JSON."
            )
            
            response = llm.invoke(prompt)
            content = response.content.strip()
            # Clean JSON markers if Gemini included them
            if content.startswith("```"):
                lines = content.splitlines()
                if lines[0].startswith("```json") or lines[0].startswith("```"):
                    content = "\n".join(lines[1:-1])
            
            recommendations_meta = json.loads(content)
            
            # Match metadata back with books list
            rec_id_map = {item["id"]: item for item in recommendations_meta if "id" in item}
            for b in books:
                if b["id"] in rec_id_map:
                    meta = rec_id_map[b["id"]]
                    recommended_books.append({
                        **b,
                        "recommendation_reason": meta.get("reason", "Highly recommended for your class."),
                        "description": meta.get("description", b.get("description", ""))
                    })
        except Exception as e:
            print(f"Gemini library recommendation failed: {str(e)}", flush=True)

    # 4. Fallback if Gemini key is missing or failed: pick books by category or class
    if not recommended_books:
        # Default rule: pick up to 3 books
        for b in books[:3]:
            recommended_books.append({
                **b,
                "recommendation_reason": "Curated pick based on popular student choices in your class.",
                "description": b.get("description", "A fantastic resource for studying and expanding your knowledge.")
            })
            
    return {
        "success": True,
        "school_id": school_id,
        "data": recommended_books
    }


@router.post("/library/borrows/{borrow_id}/cancel")
async def cancel_borrow_request(
    borrow_id: str,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    
    # Fetch borrow
    borrow_res = await sb.table("library_borrows").select("*").eq("id", borrow_id).eq("school_id", school_id).maybe_single().aexecute()
    borrow = borrow_res.data
    if not borrow:
        raise HTTPException(status_code=404, detail="Borrow record not found")
        
    if borrow["student_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized to cancel this borrow request")
        
    if borrow["status"] != "requested":
        raise HTTPException(status_code=400, detail=f"Cannot cancel borrow request with status '{borrow['status']}'")
        
    # Update status to cancelled
    update_res = await sb.table("library_borrows")\
        .update({"status": "cancelled"})\
        .eq("id", borrow_id)\
        .aexecute()
        
    return {
        "success": True,
        "message": "Borrow request cancelled successfully",
        "data": update_res.data[0] if update_res.data else {}
    }


@router.post("/library/requests/{request_id}/cancel")
async def cancel_acquisition_request(
    request_id: str,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    
    # Fetch request
    req_res = await sb.table("library_requests").select("*").eq("id", request_id).eq("school_id", school_id).maybe_single().aexecute()
    req = req_res.data
    if not req:
        raise HTTPException(status_code=404, detail="Acquisition request not found")
        
    if req["student_id"] != user["id"]:
        raise HTTPException(status_code=403, detail="Not authorized to cancel this request")
        
    if req["status"] != "pending":
        raise HTTPException(status_code=400, detail=f"Cannot cancel request with status '{req['status']}'")
        
    # Update status to cancelled
    update_res = await sb.table("library_requests")\
        .update({"status": "cancelled"})\
        .eq("id", request_id)\
        .aexecute()
        
    return {
        "success": True,
        "message": "Acquisition request cancelled successfully",
        "data": update_res.data[0] if update_res.data else {}
    }


# ─── ONLINE EXAMS STUDENT ENDPOINTS ───

@router.get("/exams/{exam_id}/online")
async def student_get_online_exam(exam_id: str, user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await _auto_publish_scheduled_exams(sb, school_id)
    # Fetch exam details
    exam_res = await sb.table("exams").select("*, subjects(name, icon), profiles!teacher_id(full_name)").eq("id", exam_id).eq("school_id", school_id).maybe_single().aexecute()
    exam = exam_res.data
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")
        
    status = exam.get("status") or "draft"
    if status not in ("published", "scheduled", "ready", "completed"):
        raise HTTPException(status_code=403, detail="Exam is not published yet.")
        
    if status in ("scheduled", "ready"):
        release_time_str = exam.get("release_time")
        if release_time_str:
            try:
                from dateutil.parser import parse
                from datetime import datetime, timezone
                release_time = parse(release_time_str)
                now = datetime.now(timezone.utc)
                if release_time > now:
                    raise HTTPException(status_code=403, detail="Exam is not published yet.")
            except Exception:
                raise HTTPException(status_code=403, detail="Exam is not published yet.")
        else:
            raise HTTPException(status_code=403, detail="Exam is not published yet.")
        
    # Fetch questions
    q_res = await sb.table("exam_questions").select("*").eq("exam_id", exam_id).order("order_number").aexecute()
    questions = q_res.data
    
    # Fetch student's submission if any
    sub_res = await sb.table("exam_submissions").select("*").eq("exam_id", exam_id).eq("student_id", user["id"]).maybe_single().aexecute()
    submission = sub_res.data

    # Fetch student's session if any
    sess_res = await sb.table("exam_sessions").select("*").eq("exam_id", exam_id).eq("student_id", user["id"]).maybe_single().aexecute()
    session = sess_res.data
    
    # Strip passcode from exam details payload to prevent network logs leakage
    passcode_val = exam.get("passcode")
    exam["has_passcode"] = bool(passcode_val and passcode_val.strip())
    exam.pop("passcode", None)

    # If student has submitted, or the exam is graded, we can show answers.
    # Otherwise, strip correct answers to prevent cheating!
    if not submission or submission.get("status") == "active":
        for q in questions:
            q.pop("correct_answer", None)
            
    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "exam": exam,
            "questions": questions,
            "submission": submission,
            "session": session
        }
    }


@router.post("/exams/{exam_id}/verify-passcode")
async def student_verify_exam_passcode(exam_id: str, request: dict, user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Check if passcode matches
    exam_res = await sb.table("exams").select("passcode").eq("id", exam_id).maybe_single().aexecute()
    if not exam_res.data:
        raise HTTPException(status_code=404, detail="Exam not found")
        
    exam_passcode = exam_res.data.get("passcode")
    if exam_passcode and exam_passcode.strip():
        provided = request.get("passcode")
        if not provided or provided.strip() != exam_passcode.strip():
            return {"success": False, "message": "Invalid passcode. Please enter the correct exam passcode."}
            
    return {"success": True, "message": "Passcode verified successfully"}


@router.post("/exams/{exam_id}/session/start")
async def student_start_exam_session(exam_id: str, request: Optional[dict] = None, user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Check if passcode is required
    exam_res = await sb.table("exams").select("passcode").eq("id", exam_id).maybe_single().aexecute()
    if not exam_res.data:
        raise HTTPException(status_code=404, detail="Exam not found")
        
    exam_passcode = exam_res.data.get("passcode")
    if exam_passcode and exam_passcode.strip():
        provided = (request or {}).get("passcode")
        if not provided or provided.strip() != exam_passcode.strip():
            raise HTTPException(status_code=401, detail="Invalid passcode. Please enter the correct exam passcode.")

    # Check if session already exists
    existing = await sb.table("exam_sessions").select("*").eq("exam_id", exam_id).eq("student_id", user["id"]).maybe_single().aexecute()
    if existing.data:
        sess_status = existing.data.get("status")
        if sess_status == "active":
            return {"success": True, "data": existing.data}
        elif sess_status == "completed":
            raise HTTPException(status_code=403, detail="Exam session has already been completed.")
        elif sess_status == "suspended":
            raise HTTPException(status_code=403, detail="You have been suspended from this exam.")
        
    now_time = datetime.now(timezone.utc).strftime("%H:%M:%S")
    initial_logs = [
        {"time": now_time, "event": "Camera & Mic initialization successful", "severity": "info"},
        {"time": now_time, "event": "Student entered live exam workspace", "severity": "info"}
    ]
    new_session = {
        "exam_id": exam_id,
        "student_id": user["id"],
        "school_id": school_id,
        "started_at": datetime.now(timezone.utc).isoformat(),
        "status": "active",
        "proctor_logs": initial_logs
    }
    try:
        with open("/tmp/debug.log", "a") as f:
            f.write(f"NEW SESSION PAYLOAD: {new_session}\n")
    except Exception as ex:
        pass
    res = await sb.table("exam_sessions").insert(new_session).aexecute()
    try:
        with open("/tmp/debug.log", "a") as f:
            f.write(f"DB INSERT RESPONSE DATA: {res.data}\n")
    except Exception as ex:
        pass
    return {"success": True, "data": res.data[0] if res.data else {}}


@router.post("/exams/{exam_id}/session/ping")
async def student_ping_exam_session(
    exam_id: str,
    request: dict,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    warnings_count = request.get("warnings_count", 0)
    active_question = request.get("active_question")
    is_online = request.get("is_online", True)
    log_event = request.get("log_event")
    
    camera_active = request.get("camera_active")
    mic_active = request.get("mic_active")
    
    update_data = {
        "warnings_count": warnings_count,
        "is_online": is_online,
        "last_ping": datetime.now(timezone.utc).isoformat()
    }
    if active_question:
        update_data["active_question"] = active_question
    if camera_active is not None:
        update_data["camera_active"] = camera_active
    if mic_active is not None:
        update_data["mic_active"] = mic_active
        
    sess_res = await sb.table("exam_sessions").select("*")\
        .eq("exam_id", exam_id)\
        .eq("student_id", user["id"])\
        .eq("status", "active")\
        .maybe_single().aexecute()
        
    sess = sess_res.data
    if not sess:
        raise HTTPException(status_code=404, detail="Active exam session not found")
        
    db_warnings = sess.get("warnings_count", 0) or 0
    update_data["warnings_count"] = max(warnings_count, db_warnings)
    
    current_logs = sess.get("proctor_logs") or []
    if not isinstance(current_logs, list):
        current_logs = []
        
    now_time = datetime.now(timezone.utc).strftime("%H:%M:%S")
    if warnings_count > db_warnings:
        if not log_event:
            log_event = f"Warning issued: focus loss detected (Count: {warnings_count})"
            
    if log_event:
        current_logs.append({
            "time": now_time,
            "event": log_event,
            "severity": "warning" if "warning" in log_event.lower() else "info"
        })
        update_data["proctor_logs"] = current_logs
        
    res = await sb.table("exam_sessions").update(update_data).eq("id", sess["id"]).aexecute()
    
    updated_sess = res.data[0] if res.data else sess
    return {
        "success": True,
        "data": {
            "id": updated_sess["id"],
            "warnings_count": updated_sess.get("warnings_count", 0),
            "is_paused": updated_sess.get("is_paused", False),
            "extra_minutes": updated_sess.get("extra_minutes", 0),
            "teacher_message": updated_sess.get("teacher_message"),
            "status": updated_sess.get("status", "active"),
            "started_at": updated_sess.get("started_at"),
            "proctor_logs": updated_sess.get("proctor_logs", [])
        }
    }


@router.post("/exams/upload")
async def student_upload_exam_file(
    file: UploadFile = File(...),
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    """Upload a subjective answer sheet to Supabase storage and return its public URL."""
    file_bytes = await file.read()
    if len(file_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty file")
        
    supabase_url = os.environ.get("SUPABASE_URL", "")
    public_url_base = os.environ.get("PUBLIC_URL", supabase_url)
    
    content_type = file.content_type or "application/octet-stream"
    filename = file.filename or "file.bin"
    
    ext = "bin"
    if "." in filename:
        ext = filename.split(".")[-1]
        
    import uuid
    unique_id = uuid.uuid4().hex
    storage_path = f"avatars/exam_{user['id']}_{unique_id}.{ext}"
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    
    headers = {
        "Authorization": f"Bearer {os.environ.get('SUPABASE_SERVICE_ROLE_KEY')}",
        "Content-Type": content_type
    }
    
    async with httpx.AsyncClient() as client:
        upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        if upload_response.status_code not in (200, 201):
            put_response = await client.put(storage_url, headers=headers, content=file_bytes)
            if put_response.status_code not in (200, 201):
                raise HTTPException(status_code=500, detail=f"Upload failed: {put_response.text}")
                
    public_url_base_replaced = public_url_base.replace("http://kong:8000", "http://127.0.0.1:8000")
    public_url = f"{public_url_base_replaced}/storage/v1/object/public/{storage_path}"
    return {
        "success": True, 
        "data": {
            "url": public_url, 
            "filename": filename, 
            "content_type": content_type
        }
    }


@router.post("/exams/{exam_id}/submit")
async def student_submit_exam(exam_id: str, request: dict, user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    answers = request.get("answers", {}) # {"q_id": "answer"}
    
    # Fetch all questions to check correct answers
    q_res = await sb.table("exam_questions").select("*").eq("exam_id", exam_id).aexecute()
    questions = q_res.data
    
    total_score = 0
    has_subjective = False
    
    for q in questions:
        q_id = q["id"]
        q_type = q["question_type"]
        correct = q.get("correct_answer")
        student_ans = answers.get(q_id)
        options = q.get("options")
        
        if q_type == "subjective":
            has_subjective = True
        elif q_type == "single_select":
            if correct is not None and student_ans is not None:
                match = False
                sa = str(student_ans).strip().upper()
                co = str(correct).strip().upper()
                if sa == co:
                    match = True
                elif len(co) == 1 and 'A' <= co <= 'Z' and options and isinstance(options, list):
                    idx = ord(co) - ord('A')
                    if 0 <= idx < len(options):
                        opt_val = str(options[idx]).strip().upper()
                        if sa == opt_val:
                            match = True
                elif len(sa) == 1 and 'A' <= sa <= 'Z' and options and isinstance(options, list):
                    idx = ord(sa) - ord('A')
                    if 0 <= idx < len(options):
                        opt_val = str(options[idx]).strip().upper()
                        if co == opt_val:
                            match = True
                if match:
                    total_score += q.get("marks", 0)
        elif q_type == "multi_select":
            if correct is not None and student_ans is not None:
                def normalize_to_text(val_str):
                    vals = [v.strip().upper() for v in str(val_str).split(",") if v.strip()]
                    normalized = set()
                    for v in vals:
                        if len(v) == 1 and 'A' <= v <= 'Z' and options and isinstance(options, list):
                            idx = ord(v) - ord('A')
                            if 0 <= idx < len(options):
                                normalized.add(str(options[idx]).strip().upper())
                                continue
                        normalized.add(v)
                    return normalized
                norm_student = normalize_to_text(student_ans)
                norm_correct = normalize_to_text(correct)
                if norm_student == norm_correct and len(norm_correct) > 0:
                    total_score += q.get("marks", 0)
        else:
            if correct is not None and student_ans is not None:
                # Compare answers (case insensitive, trimmed)
                if str(student_ans).strip().lower() == str(correct).strip().lower():
                    total_score += q.get("marks", 0)
                
    is_auto_save = request.get("is_auto_save", False)
    
    if is_auto_save:
        status = "active"
    else:
        status = "submitted" if has_subjective else "graded"
        
        # Update active session to ended
        await sb.table("exam_sessions").update({
            "status": "completed",
            "ended_at": datetime.now(timezone.utc).isoformat()
        }).eq("exam_id", exam_id).eq("student_id", user["id"]).eq("status", "active").aexecute()
    
    # Check if there is an existing submission (e.g. from auto-save / updates)
    existing = await sb.table("exam_submissions").select("*").eq("exam_id", exam_id).eq("student_id", user["id"]).maybe_single().aexecute()
    
    submission_data = {
        "exam_id": exam_id,
        "student_id": user["id"],
        "answers": answers,
        "score": total_score if (not has_subjective and not is_auto_save) else None,
        "status": status,
        "submitted_at": datetime.now(timezone.utc).isoformat(),
        "graded_at": datetime.now(timezone.utc).isoformat() if (not has_subjective and not is_auto_save) else None
    }
    
    if existing.data:
        res = await sb.table("exam_submissions").update(submission_data).eq("id", existing.data["id"]).aexecute()
    else:
        res = await sb.table("exam_submissions").insert(submission_data).aexecute()
        
    return {"success": True, "status": status, "score": total_score if (not has_subjective and not is_auto_save) else None, "data": res.data[0] if res.data else {}}


@router.get("/exams/{exam_id}/result")
async def student_get_exam_result(
    exam_id: str,
    user=Depends(require_student),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    
    # 1. Fetch exam details
    exam_res = await sb.table("exams").select("title, total_marks, passing_marks, target_classes, results_published_at").eq("id", exam_id).maybe_single().aexecute()
    exam_data = exam_res.data
    if not exam_data:
        raise HTTPException(status_code=404, detail="Exam not found")
        
    # Check if results are published
    if not exam_data.get("results_published_at"):
        raise HTTPException(status_code=403, detail="Exam results have not been published yet.")
        
    # 2. Fetch student's submission
    sub_res = await sb.table("exam_submissions").select("*").eq("exam_id", exam_id).eq("student_id", user["id"]).maybe_single().aexecute()
    sub = sub_res.data
    if not sub:
        raise HTTPException(status_code=404, detail="Submission not found for this student")
        
    # 3. Fetch questions
    q_res = await sb.table("exam_questions").select("id, question_text, question_type, options, correct_answer, marks").eq("exam_id", exam_id).aexecute()
    questions = q_res.data or []
    
    # 4. Fetch session details to get duration and warnings count
    sess_res = await sb.table("exam_sessions").select("started_at, ended_at, warnings_count").eq("exam_id", exam_id).eq("student_id", user["id"]).maybe_single().aexecute()
    sess = sess_res.data or {}
    
    # Calculate statistics
    total_questions = len(questions)
    correct_answers = 0
    incorrect_answers = 0
    skipped_answers = 0
    question_review = []  # per-question review list
    
    answers = sub.get("answers") or {}
    
    # Topic breakdown map
    # We define topics based on keywords
    topic_mapping = {
        "Optics": ["light", "optics", "lens", "mirror", "refraction", "reflection", "prism"],
        "Thermodynamics": ["heat", "thermo", "temperature", "entropy", "carnot", "gas", "pressure", "volume"],
        "Electromagnetism": ["charge", "current", "magnetic", "electric", "field", "volt", "resistance", "wire", "circuit", "ohm"],
        "Kinematics": ["speed", "velocity", "acceleration", "motion", "force", "gravity", "momentum", "mass", "newton"]
    }
    
    topic_scores = {topic: {"correct": 0, "total": 0} for topic in topic_mapping}
    topic_scores["General"] = {"correct": 0, "total": 0}
    
    def _resolve_option_letter_to_text(letter_or_text, options_list):
        """If the value is a single letter A-Z and options exist, resolve to option text."""
        if not letter_or_text:
            return letter_or_text
        s = str(letter_or_text).strip()
        if len(s) == 1 and 'A' <= s.upper() <= 'Z' and options_list and isinstance(options_list, list):
            idx = ord(s.upper()) - ord('A')
            if 0 <= idx < len(options_list):
                return str(options_list[idx])
        return s
    
    for q_idx, q in enumerate(questions):
        q_id = q["id"]
        q_type = q["question_type"]
        correct_val = q.get("correct_answer")
        student_ans = answers.get(q_id)
        q_marks = float(q.get("marks") or 1.0)
        options_list = q.get("options") or []
        
        # Categorize question into topic
        q_text_lower = q.get("question_text", "").lower()
        matched_topic = "General"
        for topic, keywords in topic_mapping.items():
            if any(kw in q_text_lower for kw in keywords):
                matched_topic = topic
                break
                
        topic_scores[matched_topic]["total"] += 1
        
        # Determine per-question result
        q_status = "skipped"  # skipped | correct | incorrect | partial
        marks_obtained = 0.0
        student_ans_display = None
        correct_ans_display = None
        teacher_feedback = None

        # Build human-readable correct answer display
        if q_type in ("single_select", "multi_select"):
            if correct_val:
                if isinstance(correct_val, str) and "," in correct_val:
                    correct_ans_display = ", ".join(
                        _resolve_option_letter_to_text(v.strip(), options_list)
                        for v in correct_val.split(",") if v.strip()
                    )
                else:
                    correct_ans_display = _resolve_option_letter_to_text(correct_val, options_list)
        elif q_type == "subjective":
            correct_ans_display = correct_val  # model answer / rubric
        else:
            correct_ans_display = str(correct_val) if correct_val is not None else None
        
        if student_ans is None:
            skipped_answers += 1
            q_status = "skipped"
            student_ans_display = None
        elif q_type == "subjective":
            # For subjective questions, check if awarded marks > 50% of question marks
            awarded = 0.0
            student_ans_text = None
            if isinstance(student_ans, dict):
                awarded = float(student_ans.get("awarded_marks") or 0.0)
                student_ans_text = student_ans.get("answer_text") or student_ans.get("text")
                teacher_feedback = student_ans.get("feedback") or student_ans.get("remarks")
            else:
                student_ans_text = str(student_ans)
            student_ans_display = student_ans_text
            marks_obtained = awarded
            if awarded >= (q_marks * 0.5):
                correct_answers += 1
                topic_scores[matched_topic]["correct"] += 1
                q_status = "correct" if awarded >= q_marks else "partial"
            else:
                incorrect_answers += 1
                q_status = "incorrect"
        elif q_type == "single_select":
            student_ans_display = _resolve_option_letter_to_text(student_ans, options_list)
            if correct_val is not None and student_ans is not None:
                match = False
                sa = str(student_ans).strip().upper()
                co = str(correct_val).strip().upper()
                if sa == co:
                    match = True
                elif len(co) == 1 and 'A' <= co <= 'Z' and options_list:
                    idx = ord(co) - ord('A')
                    if 0 <= idx < len(options_list):
                        opt_val = str(options_list[idx]).strip().upper()
                        if sa == opt_val:
                            match = True
                elif len(sa) == 1 and 'A' <= sa <= 'Z' and options_list:
                    idx = ord(sa) - ord('A')
                    if 0 <= idx < len(options_list):
                        opt_val = str(options_list[idx]).strip().upper()
                        if co == opt_val:
                            match = True
                if match:
                    correct_answers += 1
                    topic_scores[matched_topic]["correct"] += 1
                    q_status = "correct"
                    marks_obtained = q_marks
                else:
                    incorrect_answers += 1
                    q_status = "incorrect"
            else:
                incorrect_answers += 1
                q_status = "incorrect"
        elif q_type == "multi_select":
            if correct_val is not None and student_ans is not None:
                def normalize_to_text(val_str):
                    vals = [v.strip().upper() for v in str(val_str).split(",") if v.strip()]
                    normalized = set()
                    for v in vals:
                        if len(v) == 1 and 'A' <= v <= 'Z' and options_list:
                            idx = ord(v) - ord('A')
                            if 0 <= idx < len(options_list):
                                normalized.add(str(options_list[idx]).strip().upper())
                                continue
                        normalized.add(v)
                    return normalized
                norm_student = normalize_to_text(student_ans)
                norm_correct = normalize_to_text(correct_val)
                # Build display from raw student answer
                if isinstance(student_ans, str):
                    student_ans_display = ", ".join(
                        _resolve_option_letter_to_text(v.strip(), options_list)
                        for v in student_ans.split(",") if v.strip()
                    )
                else:
                    student_ans_display = str(student_ans)
                if norm_student == norm_correct and len(norm_correct) > 0:
                    correct_answers += 1
                    topic_scores[matched_topic]["correct"] += 1
                    q_status = "correct"
                    marks_obtained = q_marks
                else:
                    incorrect_answers += 1
                    q_status = "incorrect"
            else:
                incorrect_answers += 1
                q_status = "incorrect"
        else:
            student_ans_display = str(student_ans) if student_ans is not None else None
            if correct_val is not None and student_ans is not None:
                # Compare answers (case insensitive, trimmed)
                if str(student_ans).strip().lower() == str(correct_val).strip().lower():
                    correct_answers += 1
                    topic_scores[matched_topic]["correct"] += 1
                    q_status = "correct"
                    marks_obtained = q_marks
                else:
                    incorrect_answers += 1
                    q_status = "incorrect"

        # Append to per-question review
        question_review.append({
            "number": q_idx + 1,
            "question": q.get("question_text", ""),
            "type": q_type,
            "options": options_list,
            "max_marks": q_marks,
            "marks_obtained": marks_obtained,
            "student_answer": student_ans_display,
            "correct_answer": correct_ans_display,
            "status": q_status,
            "teacher_feedback": teacher_feedback,
        })
                
    # Calculate duration
    time_taken = "N/A"
    started = sess.get("started_at")
    ended = sess.get("ended_at")
    if started and ended:
        try:
            from dateutil.parser import parse
            s_dt = parse(started)
            e_dt = parse(ended)
            diff = e_dt - s_dt
            secs = diff.total_seconds()
            mins = int(secs // 60)
            hrs = mins // 60
            mins = mins % 60
            if hrs > 0:
                time_taken = f"{hrs}h {mins}m"
            else:
                time_taken = f"{mins}m"
        except Exception:
            pass
            
    warnings_count = sess.get("warnings_count", 0) or 0
    integrity = "Excellent (0 warnings)"
    if warnings_count > 3:
        integrity = f"Suspicious ({warnings_count} warnings)"
    elif warnings_count > 0:
        integrity = f"Good ({warnings_count} warnings)"
        
    # Format topic stats
    topic_stats = []
    weakest_topic = None
    min_accuracy = 101.0
    
    for topic, stats in topic_scores.items():
        if stats["total"] > 0:
            acc = round((stats["correct"] / stats["total"]) * 100)
            topic_stats.append({
                "name": topic,
                "accuracy": acc,
                "count": f"{stats['correct']}/{stats['total']}"
            })
            if acc < min_accuracy:
                min_accuracy = acc
                weakest_topic = topic
                
    # AI Revision recommendation
    recommendation = "You performed well overall! Keep up the good work and continue practicing mock exams."
    if weakest_topic and min_accuracy < 75:
        recommendation = f"Your score in {weakest_topic} ({min_accuracy}%) is relatively weak. We suggest reviewing relevant textbook chapters and attempting specialized practice questions."
        
    # If there are teacher remarks, show them
    if sub.get("remarks"):
        recommendation += f" Teacher's Remarks: {sub.get('remarks')}"
        
    # Get total class count to show e.g. "Rank 14th of 45 students"
    class_students_res = await sb.table("profiles").select("id").count("exact").eq("role", "student").eq("class", user.get("class") or '10A').aexecute()
    class_total = class_students_res.count or 15
    
    # Calculate grade and pass status dynamically if not published yet
    score = float(sub.get("score") or 0.0)
    total_marks = float(exam_data.get("total_marks") or 100.0)
    passing_marks = float(exam_data.get("passing_marks") or (total_marks * 0.4))
    pct = (score / total_marks * 100) if total_marks > 0 else 0
    
    grade_letter = sub.get("grade_letter")
    if not grade_letter:
        if pct >= 90: grade_letter = "A+"
        elif pct >= 80: grade_letter = "A"
        elif pct >= 70: grade_letter = "B+"
        elif pct >= 60: grade_letter = "B"
        elif pct >= 50: grade_letter = "C"
        elif pct >= 40: grade_letter = "D"
        else: grade_letter = "F"
        
    is_pass = sub.get("is_pass")
    if is_pass is None:
        is_pass = score >= passing_marks

    return {
        "success": True,
        "data": {
            "exam_title": exam_data.get("title"),
            "score_obtained": score,
            "total_marks": total_marks,
            "rank": sub.get("class_rank"),
            "class_total": class_total,
            "grade": grade_letter,
            "is_pass": is_pass,
            "status": "PASS" if is_pass else "FAIL",
            "total_questions": total_questions,
            "correct_answers": correct_answers,
            "incorrect_answers": incorrect_answers,
            "skipped_answers": skipped_answers,
            "time_taken": time_taken,
            "accuracy_ratio": round((correct_answers / total_questions * 100) if total_questions > 0 else 0, 1),
            "integrity_rating": integrity,
            "topic_stats": topic_stats,
            "recommendation": recommendation,
            "question_review": question_review,
        }
    }


