from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Optional
from datetime import datetime
import asyncio

from app.middleware.auth import get_current_user, require_school_id, require_parent
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


async def _verify_child_access(parent_id: str, student_id: str, sb) -> bool:
    """Verify that a parent has an approved relation to the student."""
    rel = await sb.table("parent_student_relations").select("id").eq("parent_id", parent_id).eq("student_id", student_id).eq("approved", True).maybe_single().aexecute()
    if not rel.data:
        raise HTTPException(status_code=403, detail="Not authorized for this student")
    return True


# ─────────────── CHILDREN ───────────────

@router.get("/children")
async def parent_children(user=Depends(require_parent), school_id=Depends(require_school_id)):
    """List all children linked to this parent."""
    sb = get_supabase()
    relations = (await sb.table("parent_student_relations").select(
        "student_id, relationship, is_primary, can_pickup, "
        "profiles!parent_student_relations_student_id_fkey(id, full_name, class, avatar_url, roll_number)"
    ).eq("parent_id", user["id"]).eq("approved", True).aexecute()).data

    children = []
    for rel in relations:
        profile = rel.get("profiles") or {}
        children.append({
            "student_id": rel["student_id"],
            "relationship": rel["relationship"],
            "is_primary": rel["is_primary"],
            "can_pickup": rel["can_pickup"],
            "full_name": profile.get("full_name", ""),
            "class": profile.get("class", ""),
            "avatar_url": profile.get("avatar_url"),
            "roll_number": profile.get("roll_number"),
        })

    return {"success": True, "school_id": school_id, "data": {"children": children}}


# ─────────────── DASHBOARD ───────────────

@router.get("/dashboard")
async def parent_dashboard(
    student_id: str = Query(..., description="Student ID to view dashboard for"),
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Dashboard overview for a specific child."""
    cached = await get_cached(school_id, "parent_dashboard", f"{user['id']}_{student_id}")
    if cached:
        return cached

    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    res = await sb.rpc("get_parent_dashboard_summary", {
        "p_school_id": school_id,
        "p_parent_id": user["id"],
        "p_student_id": student_id,
    }).aexecute()

    data = res.data[0] if res.data else {}
    result = {"success": True, "school_id": school_id, "data": data}
    await set_cached(school_id, "parent_dashboard", result, f"{user['id']}_{student_id}", ttl=120)
    return result


# ─────────────── ATTENDANCE ───────────────

@router.get("/attendance")
async def parent_attendance(
    student_id: str = Query(..., description="Student ID"),
    month: Optional[str] = Query(None, description="Filter by month (YYYY-MM)"),
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Attendance records for a specific child."""
    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    query = sb.table("attendance").select("status, date, remarks, subjects(name)").eq("school_id", school_id).eq("student_id", student_id)
    if month:
        query = query.gte("date", f"{month}-01").lt("date", f"{month}-32")

    attendance = (await query.order("date", ascending=False).aexecute()).data
    total = len(attendance)
    present = sum(1 for a in attendance if a["status"] == "present")
    absent = sum(1 for a in attendance if a["status"] == "absent")
    late = sum(1 for a in attendance if a["status"] == "late")
    pct = (present / total * 100) if total > 0 else 0

    subject_wise = {}
    for a in attendance:
        subj = a.get("subjects", {}).get("name", "Unknown") if a.get("subjects") else "Unknown"
        subject_wise.setdefault(subj, {"total": 0, "present": 0})
        subject_wise[subj]["total"] += 1
        if a["status"] == "present":
            subject_wise[subj]["present"] += 1

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "overall_pct": round(pct, 1),
            "present_days": present,
            "absent_days": absent,
            "late_days": late,
            "total_days": total,
            "records": attendance,
            "subject_wise": [
                {"subject": s, "present": d["present"], "total": d["total"],
                 "pct": round(d["present"] / d["total"] * 100, 1) if d["total"] > 0 else 0}
                for s, d in subject_wise.items()
            ],
        }
    }


# ─────────────── RESULTS ───────────────

@router.get("/results")
async def parent_results(
    student_id: str = Query(..., description="Student ID"),
    category: str = "All",
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Academic results for a specific child."""
    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    query = sb.table("results").select("*, subjects(name, icon)").eq("school_id", school_id).eq("student_id", student_id)
    if category != "All":
        query = query.eq("exam_type", category)

    results = (await query.order("created_at", ascending=False).aexecute()).data
    total = sum(float(r.get("marks_obtained", 0)) for r in results)
    max_total = sum(float(r.get("total_marks", 100)) for r in results)
    avg_score = (total / max_total * 100) if max_total > 0 else 0

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "overall": {
                "avg_score": round(avg_score, 1),
                "grade": _calculate_grade(avg_score),
                "total_exams": len(results),
            },
            "results": results,
        }
    }


# ─────────────── FEES ───────────────

@router.get("/fees")
async def parent_fees(
    student_id: str = Query(..., description="Student ID"),
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Fee details and payment history for a specific child."""
    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    fees_task = sb.table("fees").select("*").eq("school_id", school_id).eq("student_id", student_id).order("due_date").aexecute()
    payments_task = sb.table("payments").select("*").eq("student_id", student_id).order("paid_at", ascending=False).aexecute()

    fees_res, payments_res = await asyncio.gather(fees_task, payments_task)
    fees = fees_res.data
    payments = payments_res.data

    pending_fees = [f for f in fees if f["status"] in ("pending", "partial", "overdue")]
    paid_fees = [f for f in fees if f["status"] == "paid"]

    total_outstanding = sum(float(f["amount"]) for f in pending_fees)
    total_paid = sum(float(f["amount"]) for f in paid_fees)

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "total_outstanding": total_outstanding,
            "total_paid": total_paid,
            "pending_fees": pending_fees,
            "paid_fees": paid_fees,
            "recent_payments": payments[:10],
        }
    }


# ─────────────── HOMEWORK ───────────────

@router.get("/homework")
async def parent_homework(
    student_id: str = Query(..., description="Student ID"),
    status: str = "all",
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Homework assignments and submissions for a specific child."""
    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    # Get student's class
    student = (await sb.table("profiles").select("class").eq("id", student_id).single().aexecute()).data
    student_class = student.get("class", "")

    hw_task = sb.table("homework").select("*, subjects(name, icon)").eq("school_id", school_id).eq("class", student_class).eq("status", "active").order("due_date").aexecute()
    sub_task = sb.table("homework_submissions").select("homework_id, status, marks, grade").eq("student_id", student_id).aexecute()

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


# ─────────────── TIMETABLE ───────────────

@router.get("/timetable")
async def parent_timetable(
    student_id: str = Query(..., description="Student ID"),
    day: str = "monday",
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Student timetable for a specific child."""
    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    student = (await sb.table("profiles").select("class").eq("id", student_id).single().aexecute()).data
    student_class = student.get("class", "")

    day_map = {"monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5}
    day_num = day_map.get(day.lower(), datetime.now().weekday())

    schedule = (await sb.table("timetable").select("*, subjects(name, icon, color), profiles!teacher_id(full_name)").eq("school_id", school_id).eq("class", student_class).eq("day_of_week", day_num).order("start_time").aexecute()).data

    return {"success": True, "school_id": school_id, "data": {"schedule": schedule, "day": day, "class": student_class}}


# ─────────────── TRANSPORT ───────────────

@router.get("/transport")
async def parent_transport(
    student_id: str = Query(..., description="Student ID"),
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Bus route and stop info for a specific child."""
    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    transport = (await sb.table("student_transport").select("*, bus_routes(*), bus_stops(stop_name)").eq("school_id", school_id).eq("student_id", student_id).maybe_single().aexecute()).data
    if not transport:
        return {"success": False, "message": "Not assigned to any bus route"}

    bus_location = (await sb.table("bus_locations").select("*").eq("school_id", school_id).eq("route_id", transport["route_id"]).order("recorded_at", ascending=False).limit(1).maybe_single().aexecute()).data

    return {"success": True, "school_id": school_id, "data": {"route": transport.get("bus_routes"), "your_stop": transport.get("bus_stops", {}).get("stop_name"), "live_location": bus_location}}


# ─────────────── LEAVE ───────────────

@router.get("/leave")
async def parent_leave(
    student_id: str = Query(..., description="Student ID"),
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Leave applications for a specific child."""
    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    leaves = (await sb.table("leave_applications").select("*").eq("school_id", school_id).eq("applicant_id", student_id).eq("applicant_role", "student").order("created_at", ascending=False).aexecute()).data

    return {"success": True, "school_id": school_id, "data": {"leaves": leaves}}


@router.post("/leave/apply")
async def parent_apply_leave(request: dict, user=Depends(require_parent), school_id=Depends(require_school_id)):
    """Apply for leave on behalf of a student."""
    sb = get_supabase()
    student_id = request.get("student_id")
    if not student_id:
        raise HTTPException(status_code=400, detail="student_id is required")

    await _verify_child_access(user["id"], student_id, sb)

    await sb.table("leave_applications").insert({
        "school_id": school_id,
        "applicant_id": student_id,
        "applicant_role": "student",
        "leave_type": request.get("leave_type"),
        "start_date": request.get("start_date"),
        "end_date": request.get("end_date"),
        "reason": request.get("reason"),
        "remarks": f"Applied by parent ({user.get('email', '')})",
    }).aexecute()

    return {"success": True, "message": "Leave application submitted on behalf of student"}


# ─────────────── ACHIEVEMENTS ───────────────

@router.get("/achievements")
async def parent_achievements(
    student_id: str = Query(..., description="Student ID"),
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Student achievements for a specific child."""
    sb = get_supabase()
    await _verify_child_access(user["id"], student_id, sb)

    p_task = sb.table("profiles").select("xp_points, learning_streak, best_streak").eq("id", student_id).single().aexecute()
    a_task = sb.table("student_achievements").select("*, achievements(name, description, icon, rarity, xp_reward)").eq("school_id", school_id).eq("student_id", student_id).order("earned_at", ascending=False).aexecute()

    p_res, a_res = await asyncio.gather(p_task, a_task)
    profile = p_res.data
    achievements = a_res.data

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "xp_points": profile.get("xp_points", 0),
            "learning_streak": profile.get("learning_streak", 0),
            "best_streak": profile.get("best_streak", 0),
            "achievements": achievements,
        }
    }


# ─────────────── NOTIFICATIONS ───────────────

@router.get("/notifications")
async def parent_notifications(user=Depends(require_parent), school_id=Depends(require_school_id)):
    """Parent notifications."""
    sb = get_supabase()
    notifications = (await sb.table("notifications").select("*").eq("school_id", school_id).eq("user_id", user["id"]).order("created_at", ascending=False).limit(30).aexecute()).data
    unread = sum(1 for n in notifications if not n.get("is_read"))
    return {"success": True, "school_id": school_id, "data": {"notifications": notifications, "unread_count": unread}}


# ─────────────── MESSAGES ───────────────

@router.get("/messages")
async def parent_messages(
    teacher_id: Optional[str] = None,
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """Messages with teachers."""
    sb = get_supabase()
    query = sb.table("messages").select("*").eq("school_id", school_id)
    if teacher_id:
        query = query.or_(f"sender_id.eq.{user['id']},receiver_id.eq.{user['id']}").or_(f"sender_id.eq.{teacher_id},receiver_id.eq.{teacher_id}")
    else:
        query = query.or_(f"sender_id.eq.{user['id']},receiver_id.eq.{user['id']}")

    messages = (await query.order("created_at", ascending=False).limit(50).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.post("/messages/send")
async def parent_send_message(request: dict, user=Depends(require_parent), school_id=Depends(require_school_id)):
    """Send message to a teacher."""
    sb = get_supabase()
    teacher_id = request.get("teacher_id")
    content = request.get("content")
    if not teacher_id or not content:
        raise HTTPException(status_code=400, detail="teacher_id and content are required")

    await sb.table("messages").insert({
        "school_id": school_id,
        "sender_id": user["id"],
        "receiver_id": teacher_id,
        "content": content,
    }).aexecute()

    return {"success": True, "message": "Message sent"}


# ─────────────── NOTICES ───────────────

@router.get("/notices")
async def parent_notices(
    category: str = "All",
    user=Depends(require_parent),
    school_id=Depends(require_school_id)
):
    """School notices."""
    sb = get_supabase()
    query = sb.table("notices").select("*").eq("school_id", school_id).eq("status", "published")
    if category != "All":
        query = query.eq("category", category)
    notices = (await query.order("published_at", ascending=False).limit(20).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"notices": notices}}


# ─────────────── EVENTS ───────────────

@router.get("/events")
async def parent_events(user=Depends(require_parent), school_id=Depends(require_school_id)):
    """School events."""
    sb = get_supabase()
    events = (await sb.table("events").select("*").eq("school_id", school_id).gte("start_date", datetime.now().date().isoformat()).order("start_date").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"events": events}}


# ─────────────── PROFILE ───────────────

@router.get("/profile")
async def parent_profile(user=Depends(require_parent), school_id=Depends(require_school_id)):
    """Parent profile information."""
    sb = get_supabase()
    profile = (await sb.table("profiles").select("*").eq("id", user["id"]).single().aexecute()).data

    # Get children count
    children = (await sb.table("parent_student_relations").select("student_id, profiles!parent_student_relations_student_id_fkey(full_name, class)").eq("parent_id", user["id"]).eq("approved", True).aexecute()).data

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "id": profile.get("id"),
            "full_name": profile.get("full_name", ""),
            "email": profile.get("email", ""),
            "phone": profile.get("phone", ""),
            "gender": profile.get("gender", ""),
            "address": profile.get("address", ""),
            "avatar_url": profile.get("avatar_url"),
            "children": [
                {
                    "student_id": c["student_id"],
                    "full_name": c.get("profiles", {}).get("full_name", ""),
                    "class": c.get("profiles", {}).get("class", ""),
                }
                for c in children
            ],
        }
    }


@router.put("/profile")
async def update_parent_profile(request: dict, user=Depends(require_parent), school_id=Depends(require_school_id)):
    """Update parent profile."""
    sb = get_supabase()
    allowed_fields = {"full_name", "phone", "address", "avatar_url", "gender"}
    updates = {k: v for k, v in request.items() if k in allowed_fields}
    if not updates:
        raise HTTPException(status_code=400, detail="No valid fields to update")

    updates["updated_at"] = datetime.now().isoformat()
    await sb.table("profiles").update(updates).eq("id", user["id"]).aexecute()

    return {"success": True, "message": "Profile updated"}
