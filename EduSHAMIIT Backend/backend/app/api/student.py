from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Optional
from datetime import datetime, timedelta
import asyncio

from app.middleware.auth import get_current_user, require_school_id, require_student
from app.services.supabase_client import get_supabase
from app.cache.redis_client import get_cached, set_cached

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
    
    # 1. Run all independent queries in parallel
    # We use user["class"] from JWT to avoid waiting for profile fetch
    tasks = [
        # Profile fetch
        sb.table("profiles").select("*").eq("id", user["id"]).maybe_single().aexecute(),
        # Schedule
        sb.table("timetable").select("*, subjects(name, icon, color)").eq("school_id", school_id).eq("class", user["class"]).eq("day_of_week", today).order("start_time").aexecute(),
        # Homework
        sb.table("homework").select("*, subjects(name, icon)").eq("school_id", school_id).eq("class", user["class"]).eq("status", "active").lte("due_date", (datetime.now() + timedelta(days=3)).isoformat()).order("due_date").aexecute(),
        # Attendance Total
        sb.table("attendance").eq("school_id", school_id).eq("student_id", user["id"]).count().aexecute(),
        # Attendance Present
        sb.table("attendance").eq("school_id", school_id).eq("student_id", user["id"]).eq("status", "present").count().aexecute(),
        # Latest Result
        sb.table("results").select("marks_obtained, total_marks").eq("school_id", school_id).eq("student_id", user["id"]).order("created_at", ascending=False).limit(1).maybe_single().aexecute()
    ]
    
    results = await asyncio.gather(*tasks)
    
    profile = results[0].data
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    schedule = results[1].data
    homework = results[2].data
    att_total = results[3].count or 0
    att_present = results[4].count or 0
    latest_result = results[5].data
    
    # 2. Rank query depends on profile["xp_points"]
    rank_result = await sb.table("profiles").eq("school_id", school_id).eq("class", profile["class"]).eq("role", "student").gt("xp_points", profile.get("xp_points", 0)).count().aexecute()
    class_rank = (rank_result.count or 0) + 1
    
    att_pct = (att_present / att_total * 100) if att_total > 0 else 0
    avg_score = (float(latest_result["marks_obtained"]) / float(latest_result["total_marks"]) * 100) if latest_result else 0

    result = {
        "success": True, "school_id": school_id,
        "data": {
            "user": {"full_name": profile["full_name"], "class": profile.get("class"), "xp_points": profile.get("xp_points", 0), "learning_streak": profile.get("learning_streak", 0), "avatar_url": profile.get("avatar_url")},
            "stats": {"attendance_pct": round(att_pct, 1), "avg_score": round(avg_score, 1), "class_rank": class_rank, "xp_points": profile.get("xp_points", 0)},
            "today_schedule": schedule, "pending_homework": homework,
            "quick_access": [
                {"title": "Timetable", "icon": "📅", "route": "/student/timetable"}, {"title": "Results", "icon": "📊", "route": "/student/results"},
                {"title": "Fees", "icon": "💰", "route": "/student/fees"}, {"title": "Notices", "icon": "📢", "route": "/student/notices"},
                {"title": "Homework", "icon": "📝", "route": "/student/homework"}, {"title": "Transport", "icon": "🚌", "route": "/student/transport"},
                {"title": "Events", "icon": "🎉", "route": "/student/events"}, {"title": "Attendance", "icon": "📊", "route": "/student/attendance"},
                {"title": "Library", "icon": "📚", "route": "/student/library"}, {"title": "Courses", "icon": "📖", "route": "/student/courses"},
                {"title": "Exams", "icon": "📝", "route": "/student/exams"}, {"title": "Live Class", "icon": "🎥", "route": "/student/live-classes"},
                {"title": "Messages", "icon": "💬", "route": "/messaging"}, {"title": "Achievements", "icon": "🏆", "route": "/student/achievements"},
                {"title": "Leave", "icon": "🏖️", "route": "/student/leave"}, {"title": "Leaderboard", "icon": "🏆", "route": "/student/leaderboard"},
            ],
        }
    }
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
    fees_task = sb.table("fees").select("*").eq("school_id", school_id).eq("student_id", user["id"]).order("due_date").aexecute()
    payments_task = sb.table("payments").select("*").eq("school_id", school_id).eq("student_id", user["id"]).order("paid_at", ascending=False).aexecute()
    
    fees_res, payments_res = await asyncio.gather(fees_task, payments_task)
    fees = fees_res.data
    payments = payments_res.data
    
    total_outstanding = sum(float(f["amount"]) - float(f.get("amount_paid", 0)) for f in fees if f["status"] in ("pending", "partial", "overdue"))
    total_paid = sum(float(f.get("amount_paid", 0)) for f in fees)
    return {"success": True, "school_id": school_id, "data": {"total_outstanding": total_outstanding, "total_paid": total_paid, "pending_fees": [f for f in fees if f["status"] in ("pending", "partial", "overdue")], "recent_payments": payments[:3]}}


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
    await sb.table("event_registrations").insert({"school_id": school_id, "event_id": event_id, "student_id": user["id"]}).aexecute()
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
    profile = (await sb.table("profiles").select("*").eq("id", user["id"]).single().aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"profile": profile}}


@router.get("/library")
async def student_library(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    borrows = (await sb.table("library_borrows").select("*, library_books(title, author, cover_url)").eq("school_id", school_id).eq("student_id", user["id"]).order("borrowed_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"borrows": borrows}}


@router.get("/courses")
async def student_courses(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    student_class = user.get("class")
    courses = (await sb.table("courses").select("*, subjects(name, icon, color)").eq("school_id", school_id).eq("class", student_class).aexecute()).data
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


@router.get("/user/settings")
async def get_settings(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    settings = (await sb.table("user_settings").select("*").eq("user_id", user["id"]).maybe_single().aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"settings": settings or {}}}


@router.put("/user/settings")
async def update_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("user_settings").upsert({"school_id": school_id, "user_id": user["id"], **request}, on_conflict="user_id").aexecute()
    return {"success": True, "message": "Settings updated"}


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