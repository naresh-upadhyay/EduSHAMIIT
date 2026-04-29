from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File, Form
from typing import Optional
from datetime import datetime, timedelta
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
    data["quick_access"] = [
        {"title": "Timetable", "icon": "🗓️", "route": "/student/timetable", "bg": "EEF2FF"},
        {"title": "Results", "icon": "📊", "route": "/student/results", "bg": "FDF4FF"},
        {"title": "Fees", "icon": "💳", "route": "/student/fees", "bg": "ECFDF5"},
        {"title": "Notices", "icon": "📢", "route": "/student/notices", "bg": "FFF7ED"},
        {"title": "Homework", "icon": "📝", "route": "/student/homework", "bg": "FDF2F8"},
        {"title": "Transport", "icon": "🚌", "route": "/student/transport", "bg": "EFF6FF"},
        {"title": "Events", "icon": "📅", "route": "/student/events", "bg": "FEF3C7"},
        {"title": "Achieve", "icon": "🏆", "route": "/student/achievements", "bg": "F0FDF4"},
        {"title": "Attendance", "icon": "📋", "route": "/student/attendance", "bg": "EFF6FF"},
        {"title": "Library", "icon": "📖", "route": "/student/library", "bg": "FAF5FF"},
        {"title": "Courses", "icon": "📚", "route": "/student/courses", "bg": "ECFDF5"},
        {"title": "Leave", "icon": "✉️", "route": "/student/leave-application", "bg": "FEF2F2"},
        {"title": "Exams", "icon": "✍️", "route": "/student/exams", "bg": "EEF2FF"},
        {"title": "Live Class", "icon": "🔴", "route": "/student/live-classes", "bg": "FFE4E6", "badge": True},
        {"title": "Messages", "icon": "💬", "route": "/student/messaging", "bg": "E0E7FF"},
        {"title": "Leaderboard", "icon": "🏆", "route": "/student/leaderboard", "bg": "FEF3C7"},
    ]
    
    result = {"success": True, "school_id": school_id, "data": data}
    await set_cached(school_id, "dashboard", result, user["id"], ttl=120)
    return result


@router.get("/timetable")
async def student_timetable(day: str = "monday", user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    day_map = {"monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5}
    day_num = day_map.get(day.lower(), datetime.now().weekday())
    # Use class from JWT
    student_class = user.get("class")
    schedule = (await sb.table("timetable").select("*, subjects(name, icon, color), profiles!teacher_id(full_name)").eq("school_id", school_id).eq("class", student_class).eq("day_of_week", day_num).order("start_time").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"schedule": schedule, "day": day, "class": student_class}}


@router.get("/results")
async def student_results(category: str = "All", user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("results").select("*, subjects(name, icon)").eq("school_id", school_id).eq("student_id", user["id"])
    if category != "All":
        # Use exam_type instead of exam_category
        query = query.eq("exam_type", category)
    results = (await query.order("created_at", ascending=False).aexecute()).data
    total = sum(float(r.get("marks_obtained", 0)) for r in results)
    max_total = sum(float(r.get("total_marks", 100)) for r in results)
    avg_score = (total / max_total * 100) if max_total > 0 else 0
    return {"success": True, "school_id": school_id, "data": {"overall": {"avg_score": round(avg_score, 1), "grade": _calculate_grade(avg_score), "total_exams": len(results)}, "results": results}}


@router.get("/exams")
async def student_exams(user=Depends(require_student), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Table 'exams' doesn't have 'target_classes' or 'exam_date' columns. 
    # Using 'start_time' for date filtering.
    exams = (await sb.table("exams").select("*, subjects(name, icon)").eq("school_id", school_id).gte("start_time", datetime.now().isoformat()).order("start_time").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"exams": exams}}


@router.get("/homework")
async def student_homework(status: str = "all", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    student_class = user.get("class")
    
    # Parallelize homework and submissions
    hw_task = sb.table("homework").select("*, subjects(name, icon)").eq("school_id", school_id).eq("class", student_class).eq("status", "active").order("due_date").aexecute()
    sub_task = sb.table("homework_submissions").select("homework_id, status, marks, grade").eq("student_id", user["id"]).aexecute()
    
    hw_res, sub_res = await asyncio.gather(hw_task, sub_task)
    homework = hw_res.data
    submissions = sub_res.data
    
    sub_map = {s["homework_id"]: s for s in submissions}
    filtered = []
    for hw in homework:
        sub = sub_map.get(hw["id"])
        hw["submission_status"] = sub["status"] if sub else None
        hw["marks"] = sub.get("marks") if sub else None
        hw["grade"] = sub.get("grade") if sub else None
        if status == "all" or (status == "pending" and not sub) or (status == "submitted" and sub and sub["status"] == "submitted") or (status == "graded" and sub and sub["status"] == "graded"):
            filtered.append(hw)
    return {"success": True, "school_id": school_id, "data": {"homework": filtered}}


@router.post("/homework/submit")
async def submit_homework(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    homework_id = request.get("homework_id")
    existing = await sb.table("homework_submissions").select("id").eq("homework_id", homework_id).eq("student_id", user["id"]).maybe_single().aexecute()
    if existing.data:
        return {"success": False, "message": "Already submitted"}
    await sb.table("homework_submissions").insert({"school_id": school_id, "homework_id": homework_id, "student_id": user["id"], "submission_text": request.get("submission_text", ""), "attachment_url": request.get("attachment_url"), "status": "submitted"}).aexecute()
    try:
        await sb.rpc("update_student_xp", {"p_school_id": school_id, "p_student_id": user["id"], "p_xp_to_add": 50, "p_action": "homework_submission"}).aexecute()
    except Exception:
        pass
    return {"success": True, "school_id": school_id, "message": "Homework submitted! +50 XP"}


@router.get("/attendance")
async def student_attendance(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    attendance = (await sb.table("attendance").select("status, subjects(name)").eq("school_id", school_id).eq("student_id", user["id"]).aexecute()).data
    total = len(attendance)
    present = sum(1 for a in attendance if a["status"] == "present")
    absent = sum(1 for a in attendance if a["status"] == "absent")
    late = sum(1 for a in attendance if a["status"] == "late")
    pct = (present / total * 100) if total > 0 else 0
    subject_wise = {}
    for a in attendance:
        subj = a.get("subjects", {}).get("name", "Unknown")
        subject_wise.setdefault(subj, {"total": 0, "present": 0})
        subject_wise[subj]["total"] += 1
        if a["status"] == "present":
            subject_wise[subj]["present"] += 1
    return {"success": True, "school_id": school_id, "data": {"overall_pct": round(pct, 1), "present_days": present, "absent_days": absent, "late_days": late, "total_days": total, "subject_wise": [{"subject": s, "present": d["present"], "total": d["total"], "pct": round(d["present"]/d["total"]*100, 1) if d["total"] > 0 else 0} for s, d in subject_wise.items()]}}


@router.get("/fees")
async def student_fees(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # payments table has no school_id/student_id columns — query fees table only
    fees = (await sb.table("fees").select("*").eq("school_id", school_id).eq("student_id", user["id"]).order("due_date").aexecute()).data

    pending_fees = [f for f in fees if f["status"] in ("pending", "partial", "overdue")]
    paid_fees    = [f for f in fees if f["status"] == "paid"]

    total_outstanding = sum(float(f["amount"]) for f in pending_fees)
    total_paid        = sum(float(f["amount"]) for f in paid_fees)
    return {
        "success": True, "school_id": school_id,
        "data": {
            "total_outstanding": total_outstanding,
            "total_paid": total_paid,
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
    query = sb.table("notices").select("*").eq("school_id", school_id).eq("status", "published")
    if category != "All":
        query = query.eq("category", category)
    notices = (await query.order("published_at", ascending=False).limit(20).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"notices": notices}}


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
    except Exception as e:
        if "23505" in str(e) or "duplicate key" in str(e).lower():
            return {"success": True, "message": "Already registered for this event"}
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")
    return {"success": True, "message": "Registered successfully"}


@router.get("/achievements")
async def student_achievements(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Parallelize profile and achievements
    p_task = sb.table("profiles").select("xp_points, learning_streak, best_streak").eq("id", user["id"]).single().aexecute()
    a_task = sb.table("student_achievements").select("*, achievements(name, description, icon, rarity, xp_reward)").eq("school_id", school_id).eq("student_id", user["id"]).order("earned_at", ascending=False).aexecute()
    
    p_res, a_res = await asyncio.gather(p_task, a_task)
    profile = p_res.data
    achievements = a_res.data
    
    return {"success": True, "school_id": school_id, "data": {"xp_points": profile.get("xp_points", 0), "learning_streak": profile.get("learning_streak", 0), "best_streak": profile.get("best_streak", 0), "achievements": achievements}}


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


@router.get("/library")
async def student_library(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    borrows = (await sb.table("library_borrows").select("*, library_books(title, author, cover_url)").eq("school_id", school_id).eq("student_id", user["id"]).order("borrowed_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"borrows": borrows}}


@router.get("/courses")
async def student_courses(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    student_class = user.get("class")
    # courses table has no 'class' column — resolve via subjects.class first
    if student_class:
        subjects_res = await sb.table("subjects").select("id").eq("school_id", school_id).eq("class", student_class).aexecute()
        subject_ids = [s["id"] for s in (subjects_res.data or [])]
        if subject_ids:
            courses = (await sb.table("courses").select("*, subjects(name, icon, color)").eq("school_id", school_id).in_("subject_id", subject_ids).aexecute()).data
        else:
            courses = []
    else:
        # Fallback: return all courses for the school
        courses = (await sb.table("courses").select("*, subjects(name, icon, color)").eq("school_id", school_id).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"courses": courses}}


@router.get("/notifications")
async def student_notifications(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    notifications = (await sb.table("notifications").select("*").eq("school_id", school_id).eq("user_id", user["id"]).order("created_at", ascending=False).limit(20).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"notifications": notifications}}


@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("id", notification_id).aexecute()
    return {"success": True}


@router.get("/live-classes")
async def student_live_classes(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    student_class = user.get("class")
    classes = (await sb.table("live_classes").select("*, subjects(name, icon), profiles!teacher_id(full_name)").eq("school_id", school_id).eq("target_class", student_class).in_("status", ["live", "scheduled"]).order("scheduled_at").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"live_classes": classes}}


@router.get("/leaderboard")
async def student_leaderboard(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    student_class = user.get("class")
    students = (await sb.table("profiles").select("id, full_name, xp_points, learning_streak, avatar_url").eq("school_id", school_id).eq("class", student_class).eq("role", "student").order("xp_points", ascending=False).limit(20).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"leaderboard": students, "class": student_class}}


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
    sb = get_supabase()
    messages = (await sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url, role)").eq("school_id", school_id).or_(f"sender_id.eq.{user['id']},receiver_id.eq.{user['id']}").order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.post("/messages/send")
async def send_message(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    message = await sb.table("messages").insert({"school_id": school_id, "sender_id": user["id"], "receiver_id": request.get("receiver_id"), "content": request.get("content")}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"message_id": message.data[0]["id"]}}


@router.get("/messages/chat")
async def get_chat(chat_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    if not chat_id:
        return {"success": True, "school_id": school_id, "data": {"messages": []}}
    messages = (await sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url)").eq("school_id", school_id).or_(f"sender_id.eq.{chat_id},receiver_id.eq.{chat_id}").order("created_at").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.post("/groups/create")
async def create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    group = await sb.table("groups").insert({"school_id": school_id, "name": request.get("name"), "description": request.get("description"), "created_by": user["id"]}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"group_id": group.data[0]["id"]}}


@router.get("/groups")
async def get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    groups = (await sb.table("groups").select("*").eq("school_id", school_id).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"groups": groups}}