from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File, Form, Request
from typing import Optional
from datetime import datetime, timezone
import asyncio
import httpx
import uuid

from app.middleware.auth import get_current_user, require_school_id, require_teacher
from app.services.supabase_client import get_supabase
from app.cache.redis_client import get_cached, set_cached, invalidate_cache
from app.config import settings
from app.models import QuestionType

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
async def teacher_dashboard(user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_dashboard", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    today = datetime.now().weekday()
    
    res = await sb.rpc("get_teacher_dashboard_summary", {
        "p_school_id": school_id,
        "p_teacher_id": user["id"],
        "p_day_of_week": today
    }).aexecute()
    
    data = res.data[0] if res.data else {}
    result = {"success": True, "school_id": school_id, "data": data}
    await set_cached(school_id, "teacher_dashboard", result, user["id"], ttl=120)
    return result


@router.get("/classes")
async def teacher_classes(user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_classes", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    res = await sb.rpc("get_teacher_classes_with_counts", {
        "p_school_id": school_id,
        "p_teacher_id": user["id"]
    }).aexecute()
    
    result = {"success": True, "school_id": school_id, "data": {"classes": res.data}}
    await set_cached(school_id, "teacher_classes", result, user["id"], ttl=300)
    return result


@router.get("/subjects")
async def teacher_subjects(
    class_name: Optional[str] = None,
    all_subjects: Optional[bool] = False,
    user=Depends(require_teacher),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    query = sb.table("subjects").select("*").eq("school_id", school_id)
    if class_name:
        query = query.eq("class", class_name)
    elif not all_subjects:
        classes_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute()
        teacher_classes = list({row["class"] for row in classes_res.data if row.get("class")})
        if teacher_classes:
            query = query.in_("class", teacher_classes)
        else:
            query = query.eq("teacher_id", user["id"])
    subjects = (await query.order("name").aexecute()).data or []
    return {"success": True, "school_id": school_id, "data": {"subjects": subjects}}


@router.get("/attendance/fetch")
async def fetch_attendance(
    class_name: str,
    date: str,
    subject_id: Optional[str] = None,
    user=Depends(require_teacher),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    # 1. Fetch students for the class
    students = (await sb.table("profiles")
                .select("id, full_name, roll_number, avatar_url")
                .eq("school_id", school_id)
                .eq("class", class_name)
                .eq("role", "student")
                .order("roll_number")
                .aexecute()).data or []
                
    if not students:
        return {"success": True, "school_id": school_id, "data": {"students": []}}
    
    # 2. Fetch existing attendance records by student_id list (avoids class reserved-word issues)
    student_ids = [s["id"] for s in students]
    query = (sb.table("attendance")
               .select("student_id, status, remarks")
               .eq("school_id", school_id)
               .in_("student_id", student_ids)
               .eq("date", date))
    if subject_id:
        query = query.eq("subject_id", subject_id)
    else:
        query = query.is_("subject_id", "null")
        
    records = (await query.aexecute()).data or []
    
    # 3. Merge: student data + attendance status
    record_map = {r["student_id"]: r for r in records}
    
    merged = []
    for s in students:
        r_info = record_map.get(s["id"])
        merged.append({
            "student_id": s["id"],
            "name": s["full_name"],
            "roll_no": str(s.get("roll_number") or ""),
            "avatar_url": s.get("avatar_url"),
            "status": r_info["status"] if r_info else None,
            "remarks": r_info["remarks"] if r_info else None
        })
        
    return {"success": True, "school_id": school_id, "data": {"students": merged}}


@router.post("/attendance/mark")
async def mark_attendance(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    date = request.get("date", datetime.now().date().isoformat())
    class_name = request.get("class_name") or request.get("class_id") or ""
    subject_id = request.get("subject_id")
    records = request.get("attendance_records") or request.get("records") or []
    
    db_records = []
    for r in records:
        db_records.append({
            "school_id": school_id,
            "student_id": r["student_id"],
            "subject_id": subject_id,
            "teacher_id": user["id"],
            "marked_by": user["id"],
            "class_name": class_name,   # Use class_name key (not "class" which is a reserved SQL keyword)
            "date": date,
            "status": r["status"],
            "remarks": r.get("remarks")
        })
        
    if db_records:
        await sb.rpc("batch_upsert_attendance", {"p_records": db_records}).aexecute()
        
        # Award XP for attending classes
        try:
            from app.services.supabase_client import award_xp
            for r in records:
                if r.get("status") == "present":
                    await award_xp(sb, school_id, r["student_id"], 10, "attendance", None, f"Attended class on {date}")
        except Exception as e:
            print(f"Error awarding attendance XP: {str(e)}", flush=True)
        
    return {"success": True, "school_id": school_id, "message": f"Successfully marked attendance for {len(records)} students"}


@router.post("/homework/create")
async def create_homework(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    subject_id = request.get("subject_id")
    subject_name = request.get("subject")
    target_class = request.get("class") or request.get("target_class")
    
    if not subject_id and subject_name:
        # Resolve subject name to subject_id
        query = sb.table("subjects").select("id").eq("school_id", school_id).ilike("name", subject_name)
        if target_class:
            query = query.eq("class", target_class)
        subj_res = await query.maybe_single().aexecute()
        if subj_res.data:
            subject_id = subj_res.data["id"]
        else:
            # Fallback to any subject matching the name
            subj_res_any = await sb.table("subjects").select("id").eq("school_id", school_id).ilike("name", subject_name).limit(1).aexecute()
            if subj_res_any.data:
                subject_id = subj_res_any.data[0]["id"]
                
    attachment_url = request.get("attachment_url")
    attachments = [attachment_url] if attachment_url else None

    homework = await sb.table("homework").insert({
        "school_id": school_id, "subject_id": subject_id, "teacher_id": user["id"],
        "title": request.get("title"), "description": request.get("description"),
        "due_date": request.get("due_date"), "max_marks": request.get("max_marks", 25),
        "class": target_class, "status": "active",
        "attachments": attachments,
    }).aexecute()
    
    homework_id = homework.data[0]["id"]
    
    # Notify all students in this class
    if target_class:
        students_res = await sb.table("profiles").select("id").eq("school_id", school_id).eq("class", target_class).eq("role", "student").aexecute()
        student_ids = [s["id"] for s in (students_res.data or [])]
        if student_ids:
            notification_title = "📝 New Homework Assigned"
            notification_body = f"New assignment: '{request.get('title')}' in {subject_name or 'homework'}"
            notification_type = "homework"
            
            records = [
                {
                    "id": str(uuid.uuid4()),
                    "school_id": school_id,
                    "user_id": uid,
                    "title": notification_title,
                    "body": notification_body,
                    "type": notification_type,
                    "reference_id": homework_id,
                    "is_read": False,
                    "created_at": datetime.utcnow().isoformat(),
                }
                for uid in student_ids
            ]
            for i in range(0, len(records), 500):
                await sb.table("notifications").insert(records[i: i + 500]).aexecute()
                
    return {"success": True, "school_id": school_id, "data": {"homework_id": homework_id}}


@router.patch("/homework/{homework_id}")
async def teacher_update_homework(homework_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    updates = {}
    if "title" in request: updates["title"] = request["title"]
    if "description" in request: updates["description"] = request["description"]
    if "due_date" in request: updates["due_date"] = request["due_date"]
    if "max_marks" in request: updates["max_marks"] = request["max_marks"]
    if "status" in request: updates["status"] = request["status"]
    if "attachment_url" in request: updates["attachments"] = [request["attachment_url"]] if request["attachment_url"] else None
    
    await sb.table("homework").update(updates).eq("id", homework_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Homework updated successfully"}


@router.delete("/homework/{homework_id}")
async def teacher_delete_homework(homework_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("homework").delete().eq("id", homework_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Homework deleted successfully"}


@router.post("/homework/{homework_id}/remind")
async def send_homework_reminder(
    homework_id: str,
    user=Depends(require_teacher),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    
    # 1. Fetch homework details
    hw_res = await sb.table("homework").select("*").eq("id", homework_id).eq("school_id", school_id).maybe_single().aexecute()
    if not hw_res.data:
        raise HTTPException(status_code=404, detail="Homework not found")
        
    homework = hw_res.data
    target_class = homework.get("class")
    title = homework.get("title")
    
    if not target_class:
        raise HTTPException(status_code=400, detail="Homework does not have a target class")
        
    # 2. Fetch all student profiles in this class
    students_res = await sb.table("profiles").select("id").eq("school_id", school_id).eq("class", target_class).eq("role", "student").aexecute()
    student_ids = [s["id"] for s in (students_res.data or [])]
    
    if not student_ids:
        return {"success": True, "sent_count": 0, "message": "No students in this class"}
        
    # 3. Fetch student_ids who have already submitted the homework
    submitted_res = await sb.table("homework_submissions").select("student_id").eq("homework_id", homework_id).eq("school_id", school_id).aexecute()
    submitted_ids = {sub["student_id"] for sub in (submitted_res.data or [])}
    
    # 4. Filter to students who haven't submitted yet
    pending_student_ids = [uid for uid in student_ids if uid not in submitted_ids]
    
    if not pending_student_ids:
        return {"success": True, "sent_count": 0, "message": "All students have already submitted"}
        
    # 5. Send notification to pending students
    notification_title = "📚 Homework Reminder"
    notification_body = f"Please submit your homework: '{title}'"
    notification_type = "homework"
    
    import uuid
    records = [
        {
            "id": str(uuid.uuid4()),
            "school_id": school_id,
            "user_id": uid,
            "title": notification_title,
            "body": notification_body,
            "type": notification_type,
            "reference_id": homework_id,
            "is_read": False,
            "created_at": datetime.utcnow().isoformat(),
        }
        for uid in pending_student_ids
    ]
    for i in range(0, len(records), 500):
        await sb.table("notifications").insert(records[i: i + 500]).aexecute()
        
    return {"success": True, "sent_count": len(pending_student_ids), "message": f"Reminders sent to {len(pending_student_ids)} students"}




@router.post("/submissions/grade")
async def grade_submission(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    sub_id = request.get("submission_id")
    if not sub_id:
        raise HTTPException(status_code=400, detail="submission_id is required")
        
    # 1. Fetch submission details to get homework max marks
    sub_res = await sb.table("homework_submissions").select("*, homework(max_marks)").eq("id", sub_id).eq("school_id", school_id).maybe_single().aexecute()
    if not sub_res.data:
        raise HTTPException(status_code=404, detail="Submission not found")
        
    submission = sub_res.data
    homework = submission.get("homework") or {}
    max_marks = homework.get("max_marks") or 25
    
    # 2. Validate marks
    marks = request.get("marks")
    if marks is not None:
        try:
            marks_float = float(marks)
            if marks_float > max_marks:
                raise HTTPException(status_code=400, detail=f"Score cannot exceed maximum marks ({max_marks})")
            if marks_float < 0:
                raise HTTPException(status_code=400, detail="Score cannot be negative")
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid marks format")
            
    # 3. Update submission
    feedback = request.get("remarks") or request.get("feedback")
    await sb.table("homework_submissions").update({
        "status": "graded", "marks": marks, "grade": request.get("grade"),
        "teacher_remarks": feedback, "graded_by": user["id"],
        "graded_at": datetime.now().isoformat(),
    }).eq("id", sub_id).eq("school_id", school_id).aexecute()

    # Award XP dynamically based on homework grade
    if marks is not None:
        try:
            from app.services.supabase_client import award_xp
            xp_to_add = int((float(marks) / (float(max_marks) or 25.0)) * 50)
            if xp_to_add > 0:
                await award_xp(sb, school_id, submission["student_id"], xp_to_add, "homework", sub_id, f"Homework graded: {marks}/{max_marks} marks")
        except Exception as e:
            print(f"Error awarding homework XP: {str(e)}", flush=True)

    return {"success": True, "school_id": school_id, "message": "Submission graded"}


@router.post("/submissions/return")
async def return_submission(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    sub_id = request.get("submission_id")
    if not sub_id:
        raise HTTPException(status_code=400, detail="submission_id is required")
        
    # 1. Fetch submission details
    sub_res = await sb.table("homework_submissions").select("*, homework(title)").eq("id", sub_id).eq("school_id", school_id).maybe_single().aexecute()
    if not sub_res.data:
        raise HTTPException(status_code=404, detail="Submission not found")
        
    submission = sub_res.data
    feedback = request.get("remarks") or request.get("feedback")
    
    # 2. Update status to "returned" and clear grade/marks
    await sb.table("homework_submissions").update({
        "status": "returned",
        "marks": None,
        "grade": None,
        "teacher_remarks": feedback,
        "graded_by": user["id"],
        "graded_at": datetime.now(timezone.utc).isoformat(),
    }).eq("id", sub_id).eq("school_id", school_id).aexecute()
    
    # 3. Insert notification for student
    try:
        hw_title = (submission.get("homework") or {}).get("title") or "Homework"
        await sb.table("notifications").insert({
            "id": str(uuid.uuid4()),
            "school_id": school_id,
            "user_id": submission["student_id"],
            "title": "↩️ Homework Returned",
            "body": f"Your homework '{hw_title}' has been returned by teacher for correction.",
            "type": "homework",
            "reference_id": submission["homework_id"],
            "is_read": False,
            "created_at": datetime.utcnow().isoformat(),
        }).aexecute()
    except Exception as e:
        print("Failed to send return notification:", e)
        
    # 4. Fetch updated submission
    updated = await sb.table("homework_submissions").select("*, homework(max_marks)").eq("id", sub_id).maybe_single().aexecute()
    return {"success": True, "school_id": school_id, "data": updated.data}



@router.get("/class-detail")
async def teacher_class_detail(class_name: str = "", user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_class_detail", f"{user['id']}_{class_name}")
    if cached:
        return cached

    sb = get_supabase()
    students = (await sb.table("profiles").select("id, full_name, roll_number, xp_points, learning_streak, avatar_url").eq("school_id", school_id).eq("class", class_name).eq("role", "student").order("roll_number").aexecute()).data
    
    result = {"success": True, "school_id": school_id, "data": {"class": class_name, "students": students}}
    await set_cached(school_id, "teacher_class_detail", result, f"{user['id']}_{class_name}", ttl=300)
    return result


@router.get("/timetable")
async def teacher_timetable(day: str = "monday", date: Optional[str] = None, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    from datetime import timedelta
    sb = get_supabase()
    
    if date:
        try:
            target_date = datetime.strptime(date, "%Y-%m-%d").date()
            day_num = target_date.weekday()
            day_names = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
            day = day_names[day_num]
        except Exception:
            day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5,"sunday":6}
            day_num = day_map.get(day.lower(), 0)
            today_weekday = datetime.now().weekday()
            target_date = (datetime.now() + timedelta(days=(day_num - today_weekday))).date()
    else:
        day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5,"sunday":6}
        day_num = day_map.get(day.lower(), 0)
        today_weekday = datetime.now().weekday()  # Monday = 0, Sunday = 6
        target_date = (datetime.now() + timedelta(days=(day_num - today_weekday))).date()
        
    target_date_str = target_date.isoformat()
    
    # 1. Fetch regular timetable periods for this day_of_week
    db_schedule = (await sb.table("timetable")
                    .select("*, subjects(name, icon, color)")
                    .eq("school_id", school_id)
                    .eq("teacher_id", user["id"])
                    .eq("day_of_week", day_num)
                    .order("start_time")
                    .aexecute()).data
                    
    # Map regular timetable slots to flattened format expected by Flutter models
    schedule = []
    for idx, slot in enumerate(db_schedule):
            
        sub_name = slot.get("subjects", {}).get("name") if slot.get("subjects") else "Subject"
        if slot.get("custom_subject"):
            sub_name = slot["custom_subject"]
            
        period_number = slot.get("slot_type") or "regular"
        if period_number == "regular":
            period_number = str(idx + 1)
            
        schedule.append({
            "id": slot["id"],
            "day_of_week": day.capitalize(),
            "period_number": period_number,
            "start_time": slot["start_time"],
            "end_time": slot["end_time"],
            "subject": sub_name,
            "subject_id": slot.get("subject_id"),
            "class": slot["class"],
            "room_number": slot.get("room", "Room 101"),
            "teacher_id": slot["teacher_id"],
            "teacher_name": user.get("full_name", "Teacher")
        })
        
    # 2. Fetch live classes (scheduled online meetings) for this date
    try:
        start_ts = f"{target_date_str}T00:00:00Z"
        end_ts = f"{target_date_str}T23:59:59Z"
        db_live_classes = (await sb.table("live_classes")
                            .select("*")
                            .eq("school_id", school_id)
                            .eq("teacher_id", user["id"])
                            .gte("scheduled_at", start_ts)
                            .lte("scheduled_at", end_ts)
                            .aexecute()).data
        for lc in db_live_classes:
            try:
                dt = datetime.fromisoformat(lc["scheduled_at"].replace("Z", "+00:00"))
                start_time = dt.strftime("%H:%M:%S")
                end_dt = dt + timedelta(minutes=lc.get("duration_minutes", 60))
                end_time = end_dt.strftime("%H:%M:%S")
            except Exception:
                start_time = "14:00:00"
                end_time = "15:00:00"
                
            schedule.append({
                "id": lc["id"],
                "day_of_week": day.capitalize(),
                "period_number": "Live Class",
                "start_time": start_time,
                "end_time": end_time,
                "subject": f"💻 Live Class: {lc['title']}",
                "subject_id": lc.get("subject_id"),  # Required for per-lecture attendance marking
                "class": lc.get("target_class", "All"),
                "room_number": lc.get("stream_url") or "EduSHAMIIT Live Link",
                "teacher_id": lc["teacher_id"],
                "teacher_name": user.get("full_name", "Teacher"),
                "platform": lc.get("platform", "In-App"),
                "meeting_link": lc.get("meeting_link") or lc.get("stream_url") or "",
                "status": lc.get("status", "scheduled")
            })
    except Exception:
        pass
        
    # 3. Fetch academic events for this date
    try:
        db_events = (await sb.table("events")
                      .select("*")
                      .eq("school_id", school_id)
                      .eq("event_date", target_date_str)
                      .aexecute()).data
        for ev in db_events:
            ev_time = ev.get("event_time") or "09:00:00"
            try:
                start_dt = datetime.strptime(ev_time, "%H:%M:%S")
                start_time = start_dt.strftime("%H:%M:%S")
                end_time = (start_dt + timedelta(hours=2)).strftime("%H:%M:%S")
            except Exception:
                start_time = ev_time
                end_time = "17:00:00"
                
            schedule.append({
                "id": ev["id"],
                "day_of_week": day.capitalize(),
                "period_number": "Event",
                "start_time": start_time,
                "end_time": end_time,
                "subject": f"🔔 Event: {ev['title']}",
                "class": "All Classes",
                "room_number": ev.get("venue") or "School Grounds",
                "teacher_id": user["id"],
                "teacher_name": user.get("full_name", "Teacher")
            })
    except Exception:
        pass
        
    # Chronologically sort the consolidated timeline
    schedule.sort(key=lambda x: x["start_time"])
    
    result = {"success": True, "school_id": school_id, "data": {"schedule": schedule, "day": day}}
    return result


@router.post("/timetable")
async def schedule_timetable_slot(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    date_str = request.get("date")
    slot_type = request.get("slot_type")
    custom_subject = request.get("custom_subject")
    class_name = request.get("class") or request.get("class_name")
    start_time = request.get("start_time")
    end_time = request.get("end_time")
    room = request.get("room") or request.get("room_number") or "Room 101"
    
    if not date_str or not slot_type or not custom_subject or not class_name or not start_time or not end_time:
        raise HTTPException(status_code=400, detail="Missing required fields")

    # Verify teacher is assigned to the class they are scheduling
    tt_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute()
    assigned_classes = {row["class"].strip().upper() for row in (tt_res.data or []) if row.get("class")}
    # Fallback: also allow the class from the teacher's own profile (for teachers with no timetable rows yet)
    profile_class = user.get("class", "")
    if profile_class:
        assigned_classes.add(profile_class.strip().upper())
    if class_name.strip().upper() not in assigned_classes:
        raise HTTPException(
            status_code=403,
            detail=f"You are not authorized to schedule slots for class '{class_name}'. You are only assigned to: {', '.join(assigned_classes)}"
        )
        
    try:
        target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        day_num = target_date.weekday()
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid date format. Expected YYYY-MM-DD")
        
    if slot_type == "Live Class":
        try:
            t1 = datetime.strptime(start_time, "%H:%M:%S")
            t2 = datetime.strptime(end_time, "%H:%M:%S")
            duration_minutes = int((t2 - t1).total_seconds() / 60)
            if duration_minutes <= 0:
                duration_minutes = 60
        except Exception:
            duration_minutes = 60
            
        scheduled_at = f"{date_str}T{start_time}Z"
        
        res = await sb.table("live_classes").insert({
            "school_id": school_id,
            "teacher_id": user["id"],
            "title": custom_subject,
            "scheduled_at": scheduled_at,
            "duration_minutes": duration_minutes,
            "target_class": class_name,
            "status": "scheduled",
            "stream_url": room,
            "is_live": False
        }).aexecute()
        
        # Invalidate cache
        await invalidate_cache(school_id, "teacher_dashboard")
        await invalidate_cache(school_id, "teacher_live_classes")
        
        return {"success": True, "school_id": school_id, "data": res.data[0]}
    else:
        # Try to resolve a subject_id from the subject name if not provided
        subject_id = request.get("subject_id")
        if not subject_id and custom_subject:
            subj_res = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", custom_subject).limit(1).maybe_single().aexecute()
            if subj_res.data:
                subject_id = subj_res.data["id"]

        insert_data = {
            "school_id": school_id,
            "teacher_id": user["id"],
            "class": class_name,
            "day_of_week": day_num,
            "start_time": start_time,
            "end_time": end_time,
            "room": room,
        }
        if subject_id:
            insert_data["subject_id"] = subject_id

        res = await sb.table("timetable").insert(insert_data).aexecute()

        # Invalidate cache
        await invalidate_cache(school_id, "teacher_dashboard")

        return {"success": True, "school_id": school_id, "data": res.data[0]}



@router.post("/exams/create")
async def create_exam(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    print("Incoming create_exam payload:", request)
    sb = get_supabase()
    
    # 2. Map class / class_id to target_classes
    target_classes = request.get("target_classes")
    if not target_classes:
        class_val = request.get("class") or request.get("class_id")
        if class_val:
            target_classes = [class_val]

    # 1. Map subject name to subject_id if needed
    subject_id = request.get("subject_id")
    subject_name = request.get("subject")
    if not subject_id and subject_name:
        class_val = target_classes[0] if (target_classes and len(target_classes) > 0) else None
        subj_query = sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name)
        if class_val:
            subj_query = subj_query.eq("class", class_val)
        subj_res = await subj_query.limit(1).maybe_single().aexecute()
        if subj_res.data:
            subject_id = subj_res.data["id"]
        else:
            subj_res_fallback = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name).limit(1).maybe_single().aexecute()
            if subj_res_fallback.data:
                subject_id = subj_res_fallback.data["id"]

    # Verify teacher is assigned to these target classes
    if target_classes:
        tt_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute()
        assigned_classes = {row["class"].strip().upper() for row in (tt_res.data or []) if row.get("class")}
        for tc in target_classes:
            if tc.strip().upper() not in assigned_classes:
                raise HTTPException(
                    status_code=403,
                    detail=f"You are not authorized to create exams for class '{tc}'. You are only assigned to: {', '.join(assigned_classes)}"
                )
            
    # 3. Ensure start_time and end_time are set
    exam_date = request.get("exam_date")
    start_time = request.get("start_time")
    
    # extract duration digits from string if it comes as "90 mins"
    dur_val = request.get("duration_minutes") or request.get("duration") or 90
    if isinstance(dur_val, str):
        # find digits in string
        digits = "".join([c for c in dur_val if c.isdigit()])
        duration_minutes = int(digits) if digits else 90
    else:
        duration_minutes = int(dur_val)
    
    if not start_time and exam_date:
        start_time = f"{exam_date}T09:00:00"
        
    if start_time:
        try:
            from datetime import timedelta, timezone
            def parse_to_utc_dt(s: str) -> datetime:
                if not s:
                    return None
                if s.endswith("Z"):
                    s = s[:-1] + "+00:00"
                try:
                    dt = datetime.fromisoformat(s)
                except ValueError:
                    from dateutil.parser import parse
                    dt = parse(s)
                if dt.tzinfo is None:
                    # Naive datetime. Assume Indian Standard Time (+5:30)
                    dt = dt.replace(tzinfo=timezone(timedelta(hours=5, minutes=30)))
                return dt.astimezone(timezone.utc)

            start_dt = parse_to_utc_dt(start_time)
            start_time = start_dt.isoformat()
            end_time = (start_dt + timedelta(minutes=duration_minutes)).isoformat()
        except Exception as e:
            print("Error parsing start_time in backend:", e)
            end_time = None
    else:
        end_time = None
        
    venue = request.get("venue")
    if not venue:
        venue = "Online Portal" if request.get("exam_type") == "online" else "Classroom"
        
    status_val = request.get("status") or "new"
    if status_val in ("published", "scheduled", "ready"):
        raise HTTPException(
            status_code=400,
            detail="Cannot schedule or publish an exam with 0 questions. Please add questions using the Paper Builder first."
        )

    exam = await sb.table("exams").insert({
        "school_id": school_id,
        "subject_id": subject_id,
        "teacher_id": user["id"],
        "title": request.get("title"),
        "exam_type": request.get("exam_type", "offline"),
        "exam_category": request.get("exam_category") or request.get("exam_type", "Unit Test"),
        "exam_date": exam_date,
        "start_time": start_time,
        "end_time": end_time,
        "duration_minutes": duration_minutes,
        "total_marks": int(request.get("total_marks") or 100),
        "venue": venue,
        "target_classes": target_classes,
        "status": status_val,
        "instructions": request.get("instructions"),
        "syllabus": request.get("syllabus"),
        "negative_marking": request.get("negative_marking", False),
        "shuffle_questions": request.get("shuffle_questions", True),
        "shuffle_options": request.get("shuffle_options", True),
        "allow_calculator": request.get("allow_calculator", False),
        "camera_required": request.get("camera_required", True),
        "mic_required": request.get("mic_required", True),
        "auto_submit_on_timer": request.get("auto_submit_on_timer", True),
        "passcode": request.get("passcode"),
        "target_students": request.get("target_students"),
        "scope": request.get("scope", "All Students")
    }).aexecute()
    
    return {"success": True, "school_id": school_id, "data": {"exam_id": exam.data[0]["id"] if exam.data else None}}


@router.post("/exams/generate-questions")
async def generate_exam_questions(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    try:
        from langchain_google_genai import ChatGoogleGenerativeAI
        import os
        llm = ChatGoogleGenerativeAI(model=os.getenv("GEMINI_MODEL", "gemini-1.5-flash"), temperature=0.7, google_api_key=os.getenv("GOOGLE_API_KEY", "AIza-placeholder"))
        prompt = f"Generate exam questions:\nSubject: {request.get('subject')}\nTopic: {request.get('topic')}\nMCQ: {request.get('num_mcq', 10)} questions\nSubjective: {request.get('num_subjective', 5)} questions\nDifficulty: {request.get('difficulty', 'medium')}\nFormat as numbered list with answers."
        response = llm.invoke(prompt)
        return {"success": True, "school_id": school_id, "data": {"questions": response.content}}
    except Exception as e:
        return {"success": False, "school_id": school_id, "data": {"questions": f"Question generation error: {str(e)}"}}


@router.get("/gradebook")
async def teacher_gradebook(class_name: str = "", subject_id: str = "", user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_gradebook", f"{user['id']}_{class_name}_{subject_id}")
    if cached:
        return cached

    sb = get_supabase()
    students = (await sb.table("profiles").select("id, full_name, roll_number").eq("school_id", school_id).eq("class", class_name).eq("role", "student").order("roll_number").aexecute()).data
    
    results = []
    if students:
        query = sb.table("results").select("student_id, marks_obtained, total_marks, grade, exam_type").eq("school_id", school_id).in_("student_id", [s["id"] for s in students])
        if subject_id:
            query = query.eq("subject_id", subject_id)
        results = (await query.aexecute()).data
        
    gradebook = []
    for s in students:
        s_results = [r for r in results if r["student_id"] == s["id"]]
        total = sum(float(r["marks_obtained"]) for r in s_results)
        max_total = sum(float(r["total_marks"]) for r in s_results)
        avg = (total/max_total*100) if max_total > 0 else 0
        gradebook.append({"student_id": s["id"], "name": s["full_name"], "roll_number": s.get("roll_number"), "results": s_results, "average": round(avg, 1), "grade": _calculate_grade(avg)})
        
    result = {"success": True, "school_id": school_id, "data": {"gradebook": gradebook}}
    await set_cached(school_id, "teacher_gradebook", result, f"{user['id']}_{class_name}_{subject_id}", ttl=300)
    return result


@router.put("/grading-config")
async def update_grading_config(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("grading_policies").upsert({
        "school_id": school_id, "teacher_id": user["id"], "class": request.get("class_name"),
        "subject_id": request.get("subject_id"), "mid_term_weight": request.get("mid_term_weight", 30),
        "final_term_weight": request.get("final_term_weight", 40), "attendance_weight": request.get("attendance_weight", 5),
        "assignment_weight": request.get("assignment_weight", 10), "class_test_weight": request.get("class_test_weight", 10),
        "lab_weight": request.get("lab_weight", 5),
    }).aexecute()
    return {"success": True, "message": "Grading config updated"}


@router.get("/students")
async def teacher_students(class_name: str = "", search: str = "", user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_students", f"{user['id']}_{class_name}_{search}")
    if cached:
        return cached

    sb = get_supabase()
    
    # Fetch classes assigned to this teacher from timetable
    tt_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute()
    teacher_classes = list(dict.fromkeys(
        row["class"] for row in (tt_res.data or []) if row.get("class")
    ))
    
    if not teacher_classes:
        # If teacher has no assigned classes, return empty student list
        return {"success": True, "school_id": school_id, "data": {"students": []}}
        
    query = sb.table("profiles").select("id, full_name, class, roll_number, phone, email, date_of_birth, father_name, father_phone, avatar_url").eq("school_id", school_id).eq("role", "student")
    
    if class_name:
        if class_name in teacher_classes:
            query = query.eq("class", class_name)
        else:
            return {"success": True, "school_id": school_id, "data": {"students": []}}
    else:
        query = query.in_("class", teacher_classes)
        
    students = (await query.order("class").order("roll_number").aexecute()).data
    
    # Python-based search filtering (case-insensitive name and roll_number search)
    if search:
        search_lower = search.strip().lower()
        students = [
            s for s in students
            if search_lower in s["full_name"].lower() or (s.get("roll_number") and search_lower in str(s["roll_number"]))
        ]
    
    # Fetch performance stats
    stats_query = sb.table("student_profile_stats").select("student_id, avg_score, attendance_pct, class_rank").eq("school_id", school_id)
    if class_name:
        stats_query = stats_query.eq("class", class_name)
    else:
        stats_query = stats_query.in_("class", teacher_classes)
        
    stats_res = await stats_query.aexecute()
    stats_map = {item["student_id"]: item for item in stats_res.data}
    
    # Fetch total students per class for class_total
    totals_query = sb.table("profiles").select("class").eq("school_id", school_id).eq("role", "student").in_("class", teacher_classes)
    totals_res = await totals_query.aexecute()
    class_totals = {}
    for p in totals_res.data:
        c = p.get("class")
        if c:
            class_totals[c] = class_totals.get(c, 0) + 1
            
    # Merge stats and counts
    for s in students:
        s_id = s["id"]
        s_stats = stats_map.get(s_id, {})
        s["avg_marks"] = s_stats.get("avg_score", 0.0)
        s["attendance_pct"] = s_stats.get("attendance_pct", 100.0)
        s["class_rank"] = s_stats.get("class_rank", 1)
        s["class_total"] = class_totals.get(s["class"], 0)

    result = {"success": True, "school_id": school_id, "data": {"students": students}}
    await set_cached(school_id, "teacher_students", result, f"{user['id']}_{class_name}_{search}", ttl=300)
    return result


@router.get("/students/{student_id}")
async def teacher_student_detail(student_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Get student profile
    student = (await sb.table("profiles").select("id, full_name, class, roll_number, phone, email, date_of_birth, avatar_url, father_name, father_phone").eq("id", student_id).eq("school_id", school_id).eq("role", "student").maybe_single().aexecute()).data
    if not student:
        raise HTTPException(status_code=404, detail="Student not found")
        
    # Fetch performance stats
    stats = (await sb.table("student_profile_stats").select("avg_score, attendance_pct, class_rank").eq("student_id", student_id).maybe_single().aexecute()).data or {}
    
    # Fetch class total count
    class_total_res = await sb.table("profiles").select("id").eq("school_id", school_id).eq("class", student["class"]).eq("role", "student").aexecute()
    class_total = len(class_total_res.data) if class_total_res.data else 0
    
    student["avg_marks"] = stats.get("avg_score", 0.0)
    student["attendance_pct"] = stats.get("attendance_pct", 100.0)
    student["class_rank"] = stats.get("class_rank", 1)
    student["class_total"] = class_total
    
    return {"success": True, "school_id": school_id, "data": student}


@router.post("/leave/apply")
async def teacher_apply_leave(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("leave_applications").insert({"school_id": school_id, "applicant_id": user["id"], "applicant_role": "teacher", "leave_type": request.get("leave_type"), "start_date": request.get("start_date"), "end_date": request.get("end_date"), "reason": request.get("reason")}).aexecute()
    return {"success": True, "message": "Leave application submitted"}


@router.post("/notices/create")
async def create_notice(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    profile_res = await sb.table("profiles").select("full_name").eq("id", user["id"]).maybe_single().aexecute()
    profile = profile_res.data or {}
    author_name = profile.get("full_name", "Teacher")
    
    status = request.get("status", "published")
    scheduled_at = request.get("scheduled_at")
    published_at = datetime.utcnow().isoformat() if status == "published" else None
    
    insert_data = {
        "school_id": school_id,
        "title": request.get("title"),
        "content": request.get("content"),
        "category": request.get("category", "General"),
        "author_id": user["id"],
        "author_name": author_name,
        "is_urgent": request.get("is_urgent", False),
        "status": status,
        "scheduled_at": scheduled_at,
        "published_at": published_at,
        "target_audience": request.get("target_audience", "all"),
        "attachment_url": request.get("attachment_url"),
        "target_classes": request.get("target_classes"),
    }
    
    notice = await sb.table("notices").insert(insert_data).aexecute()
    if not notice.data:
        raise HTTPException(status_code=500, detail="Failed to create notice")
    return {"success": True, "school_id": school_id, "data": {"notice_id": notice.data[0]["id"]}}


@router.put("/notices/{notice_id}")
async def teacher_update_notice(notice_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Verify notice exists and teacher is the author
    existing = await sb.table("notices").select("*").eq("id", notice_id).eq("school_id", school_id).maybe_single().aexecute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Notice not found")
        
    if existing.data.get("author_id") != user["id"]:
        raise HTTPException(status_code=403, detail="You are not authorized to update this notice")
        
    allowed_fields = {"title", "content", "category", "is_urgent", "status", "scheduled_at", "target_audience", "attachment_url", "target_classes"}
    update_data = {k: v for k, v in request.items() if k in allowed_fields}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields to update")
        
    # If publishing a draft or scheduled notice
    if update_data.get("status") == "published" and existing.data.get("status") != "published":
        update_data["published_at"] = datetime.utcnow().isoformat()
        
    await sb.table("notices").update(update_data).eq("id", notice_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Notice updated successfully"}


@router.delete("/notices/{notice_id}")
async def teacher_delete_notice(notice_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Verify notice exists and teacher is the author
    existing = await sb.table("notices").select("*").eq("id", notice_id).eq("school_id", school_id).maybe_single().aexecute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Notice not found")
        
    if existing.data.get("author_id") != user["id"]:
        raise HTTPException(status_code=403, detail="You are not authorized to delete this notice")
        
    await sb.table("notices").delete().eq("id", notice_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Notice deleted successfully"}


@router.get("/live-classes")
async def teacher_live_classes(
    status: Optional[str] = Query(None),
    user=Depends(require_teacher),
    school_id=Depends(require_school_id)
):
    cache_id = f"{user['id']}:{status or 'all'}"
    cached = await get_cached(school_id, "teacher_live_classes", cache_id)
    if cached:
        return cached

    sb = get_supabase()
    query = sb.table("live_classes").select("*, subjects(name, icon)").eq("school_id", school_id).eq("teacher_id", user["id"])
    if status:
        if status == "ongoing":
            query = query.in_("status", ["live", "ongoing"])
        elif status == "completed":
            query = query.in_("status", ["recorded", "completed"])
        else:
            query = query.eq("status", status)
    classes = (await query.order("scheduled_at", ascending=False).aexecute()).data or []
    
    # Populate subject name for front-end compatibility
    for c in classes:
        if "subjects" in c and c["subjects"]:
            c["subject"] = c["subjects"].get("name", "")
            
    result = {"success": True, "school_id": school_id, "data": {"live_classes": classes}}
    await set_cached(school_id, "teacher_live_classes", result, cache_id, ttl=120)
    return result


@router.post("/live-classes")
async def teacher_create_live_class(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    subject_name = request.get("subject")
    subject_id = request.get("subject_id")
    target_class = request.get("target_class") or request.get("class")
    status = request.get("status", "scheduled")
    
    if not subject_id and subject_name:
        query = sb.table("subjects").select("id").eq("school_id", school_id).ilike("name", subject_name)
        if target_class:
            query = query.eq("class", target_class)
        subj_res = await query.maybe_single().aexecute()
        if subj_res.data:
            subject_id = subj_res.data["id"]
        else:
            subj_res_any = await sb.table("subjects").select("id").eq("school_id", school_id).ilike("name", subject_name).limit(1).aexecute()
            if subj_res_any.data:
                subject_id = subj_res_any.data[0]["id"]
                
    scheduled_at = request.get("scheduled_at") or datetime.utcnow().isoformat()
    duration_minutes = request.get("duration_minutes", 60)
    
    data = {
        "school_id": school_id,
        "teacher_id": user["id"],
        "subject_id": subject_id,
        "title": request.get("title"),
        "scheduled_at": scheduled_at,
        "duration_minutes": duration_minutes,
        "target_class": target_class,
        "status": status,
        "platform": request.get("platform", "In-App"),
        "stream_url": request.get("stream_url"),
        "recording_url": request.get("recording_url"),
        "meeting_link": request.get("meeting_link"),
        "is_live": status == "live",
        "viewer_count": 0
    }
    
    res = await sb.table("live_classes").insert(data).aexecute()
    
    # Invalidate cache
    try:
        await invalidate_cache(school_id, f"teacher_live_classes:{user['id']}")
        from app.cache.redis_client import get_redis
        rc = get_redis()
        if rc:
            await rc.delete(f"{school_id}:teacher_dashboard:{user['id']}")
    except Exception:
        pass
        
    return {"success": True, "data": res.data[0] if res.data else {}}


@router.patch("/live-classes/{live_class_id}")
async def teacher_patch_live_class(live_class_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Verify the class belongs to this teacher and school
    existing = await sb.table("live_classes").select("*").eq("id", live_class_id).eq("school_id", school_id).eq("teacher_id", user["id"]).maybe_single().aexecute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Live class not found or access denied")
        
    existing_data = existing.data
    update_data = {}
    
    if "status" in request:
        status = request["status"]
        update_data["status"] = status
        update_data["is_live"] = status == "live"
    if "viewer_count" in request:
        update_data["viewer_count"] = request["viewer_count"]
    if "stream_url" in request:
        update_data["stream_url"] = request["stream_url"]
    if "recording_url" in request:
        update_data["recording_url"] = request["recording_url"]
    if "meeting_link" in request:
        update_data["meeting_link"] = request["meeting_link"]
    if "platform" in request:
        update_data["platform"] = request["platform"]
    if "title" in request:
        update_data["title"] = request["title"]
    if "duration_minutes" in request:
        duration_val = request["duration_minutes"]
        if isinstance(duration_val, (int, float)) and duration_val > 0:
            update_data["duration_minutes"] = int(duration_val)
    if "scheduled_at" in request:
        update_data["scheduled_at"] = request["scheduled_at"]
    if "target_class" in request or "class" in request:
        update_data["target_class"] = request.get("target_class") or request.get("class")
        
    if "subject_id" in request:
        update_data["subject_id"] = request["subject_id"]
    elif "subject" in request:
        subject_name = request["subject"]
        if subject_name:
            t_class = request.get("target_class") or request.get("class") or existing_data.get("target_class")
            query = sb.table("subjects").select("id").eq("school_id", school_id).ilike("name", subject_name)
            if t_class:
                query = query.eq("class", t_class)
            subj_res = await query.maybe_single().aexecute()
            if subj_res.data:
                update_data["subject_id"] = subj_res.data["id"]
            else:
                subj_res_any = await sb.table("subjects").select("id").eq("school_id", school_id).ilike("name", subject_name).limit(1).aexecute()
                if subj_res_any.data:
                    update_data["subject_id"] = subj_res_any.data[0]["id"]
        
    if update_data:
        res = await sb.table("live_classes").update(update_data).eq("id", live_class_id).aexecute()
    else:
        res = await sb.table("live_classes").select("*").eq("id", live_class_id).aexecute()
        
    # Invalidate cache
    try:
        await invalidate_cache(school_id, f"teacher_live_classes:{user['id']}")
        from app.cache.redis_client import get_redis
        rc = get_redis()
        if rc:
            await rc.delete(f"{school_id}:teacher_dashboard:{user['id']}")
            # Clear all student live classes cache keys
            keys = await rc.keys(f"{school_id}:student_live_classes:*")
            if keys:
                await rc.delete(*keys)
    except Exception:
        pass
        
    return {"success": True, "data": res.data[0] if res.data else {}}


@router.delete("/live-classes/{live_class_id}")
async def teacher_delete_live_class(
    live_class_id: str,
    user=Depends(require_teacher),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    
    # Verify the class belongs to this teacher and school
    existing = await sb.table("live_classes").select("id").eq("id", live_class_id).eq("school_id", school_id).eq("teacher_id", user["id"]).maybe_single().aexecute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Live class not found or access denied")
        
    # 1. Clean up physical recording files from MinIO
    try:
        from app.services.minio_client import delete_live_class_recordings_from_storage
        await delete_live_class_recordings_from_storage(sb, live_class_id)
    except Exception as e:
        print(f"[Cleanup] Error in teacher_delete_live_class recordings cleanup: {e}")
        
    # 2. Delete class from database (cascade deletes live_class_recordings)
    await sb.table("live_classes").delete().eq("id", live_class_id).aexecute()
    
    # Invalidate cache
    try:
        await invalidate_cache(school_id, f"teacher_live_classes:{user['id']}")
        from app.cache.redis_client import get_redis
        rc = get_redis()
        if rc:
            await rc.delete(f"{school_id}:teacher_dashboard:{user['id']}")
            # Clear all student live classes cache keys
            keys = await rc.keys(f"{school_id}:student_live_classes:*")
            if keys:
                await rc.delete(*keys)
    except Exception:
        pass
        
    return {"success": True, "message": "Live class deleted successfully"}


@router.post("/live-classes/start")
async def start_live_class(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    live_class = await sb.table("live_classes").insert({"school_id": school_id, "teacher_id": user["id"], "subject_id": request.get("subject_id"), "title": request.get("title"), "scheduled_at": request.get("scheduled_at"), "duration_minutes": request.get("duration_minutes", 60), "target_class": request.get("target_class"), "status": "live", "is_live": True}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"live_class_id": live_class.data[0]["id"]}}


@router.post("/materials/upload")
async def upload_material(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    material = await sb.table("study_materials").insert({"school_id": school_id, "teacher_id": user["id"], "title": request.get("title"), "description": request.get("description"), "material_type": request.get("material_type"), "target_class": request.get("target_class"), "attachment_urls": request.get("attachment_urls")}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"material_id": material.data[0]["id"]}}


@router.get("/salary")
async def teacher_salary(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_salary", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    salary = (await sb.table("salary").select("*").eq("school_id", school_id).eq("teacher_id", user["id"]).order("month", ascending=False).limit(6).aexecute()).data
    
    result = {"success": True, "school_id": school_id, "data": {"salary_history": salary}}
    await set_cached(school_id, "teacher_salary", result, user["id"], ttl=3600)
    return result


@router.get("/profile")
async def teacher_profile(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_profile", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    profile_task = sb.table("profiles").select("*").eq("id", user["id"]).single().aexecute()
    docs_task = sb.table("documents").select("id, document_type, file_name, file_url, verification_status").eq("user_id", user["id"]).aexecute()
    # Fetch distinct classes from timetable assigned to this teacher
    timetable_task = sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute()
    
    profile_res, docs_res, tt_res = await asyncio.gather(profile_task, docs_task, timetable_task)
    profile = profile_res.data or {}
    profile["documents"] = docs_res.data or []
    
    # Build sorted unique classes list from timetable
    tt_classes = list(dict.fromkeys(
        row["class"] for row in (tt_res.data or []) if row.get("class")
    ))
    tt_classes.sort()
    # Also include the single class from profile if present and not already in list
    profile_class = profile.get("class", "")
    if profile_class and profile_class not in tt_classes:
        tt_classes.insert(0, profile_class)
    profile["classes"] = tt_classes
    
    result = {"success": True, "school_id": school_id, "data": {"profile": profile}}
    await set_cached(school_id, "teacher_profile", result, user["id"], ttl=300)
    return result



@router.patch("/profile")
async def update_teacher_profile(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    allowed_fields = {
        "full_name", "phone", "email", "address", "blood_group",
        "gender", "date_of_birth", "category",
        "father_name", "father_occupation", "father_phone",
        "mother_name", "mother_occupation", "mother_phone",
        "local_guardian", "nationality", "religion", "qualification",
        "experience_years", "bio", "joining_date", "specialization"
    }
    update_data = {k: v for k, v in request.items() if k in allowed_fields}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided for update")
    
    update_data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("profiles").update(update_data).eq("id", user["id"]).aexecute()
    
    # Clear Redis Cache
    try:
        from app.cache.redis_client import get_redis
        rc = get_redis()
        if rc:
            await rc.delete(f"{school_id}:teacher_profile:{user['id']}")
    except Exception:
        pass
        
    # Fetch updated profile to return
    profile_task = sb.table("profiles").select("*").eq("id", user["id"]).single().aexecute()
    docs_task = sb.table("documents").select("id, document_type, file_name, file_url, verification_status").eq("user_id", user["id"]).aexecute()
    profile_res, docs_res = await asyncio.gather(profile_task, docs_task)
    profile = profile_res.data or {}
    profile["documents"] = docs_res.data or []
    
    return {
        "success": True, 
        "message": "Profile updated successfully", 
        "data": {**profile, "profile": profile}
    }


@router.post("/profile/avatar")
async def upload_avatar(
    avatar: UploadFile = File(...),
    user=Depends(require_teacher),
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

    # Clear Redis Cache
    try:
        from app.cache.redis_client import get_redis
        rc = get_redis()
        if rc:
            await rc.delete(f"{school_id}:teacher_profile:{user['id']}")
    except Exception:
        pass

    return {"success": True, "data": {"avatar_url": public_url}}


@router.post("/profile/document")
async def upload_document(
    document: UploadFile = File(...),
    document_type: str = Form(...),
    user=Depends(require_teacher),
    school_id=Depends(require_school_id),
):
    """Upload a document and add it to the teacher's documents list."""
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

    # Clear Redis Cache
    try:
        from app.cache.redis_client import get_redis
        rc = get_redis()
        if rc:
            await rc.delete(f"{school_id}:teacher_profile:{user['id']}")
    except Exception:
        pass

    return {"success": True, "message": "Document uploaded successfully", "data": doc_data}


@router.get("/submissions")
async def teacher_submissions(homework_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("homework_submissions").select("*, profiles!student_id(full_name, roll_number), homework(title, max_marks)").eq("school_id", school_id)
    if homework_id:
        query = query.eq("homework_id", homework_id)
    submissions = (await query.order("submitted_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"submissions": submissions}}


@router.get("/notifications")
async def teacher_notifications(
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
async def teacher_mark_notification_read(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.patch("/notifications/{notification_id}/read")
async def teacher_mark_notification_read_patch(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").update({"is_read": True}).eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.delete("/notifications/{notification_id}")
async def teacher_delete_notification(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("notifications").delete().eq("id", notification_id).eq("user_id", user["id"]).aexecute()
    return {"success": True}


@router.put("/user/settings")
async def teacher_update_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("user_settings").upsert({"school_id": school_id, "user_id": user["id"], **request}, on_conflict="user_id").aexecute()
    return {"success": True, "message": "Settings updated"}


@router.get("/messages")
async def teacher_get_messages(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import get_messages as shared_get_messages
    return await shared_get_messages(user, school_id)


@router.post("/messages/send")
async def teacher_send_message(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import send_message as shared_send_message
    return await shared_send_message(request, user, school_id)


@router.get("/messages/chat")
async def teacher_get_chat(chat_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import get_chat as shared_get_chat
    return await shared_get_chat(chat_id, user, school_id)


@router.post("/groups/create")
async def teacher_create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import create_group as shared_create_group
    return await shared_create_group(request, user, school_id)


@router.get("/groups")
async def teacher_get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import get_groups as shared_get_groups
    return await shared_get_groups(user, school_id)


@router.post("/groups/{group_id}/join")
async def teacher_join_group(group_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    from app.api.shared import join_group as shared_join_group
    return await shared_join_group(group_id, user, school_id)


@router.post("/messages/upload")
async def upload_message_file(
    file: UploadFile = File(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    from app.api.shared import upload_message_file as shared_upload_message_file
    return await shared_upload_message_file(file, user, school_id)


@router.get("/homework")
async def teacher_get_homework(status: str = None, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("homework").select("*, subjects(name, icon)").eq("school_id", school_id).eq("teacher_id", user["id"])
    if status and status.lower() != 'all':
        query = query.eq("status", status.lower())
    homework = (await query.order("created_at", ascending=False).aexecute()).data
    
    if homework:
        # Get all unique classes for these homeworks
        classes = list(set(hw["class"] for hw in homework if hw.get("class")))
        
        # Query total student count in each class
        students_res = await sb.table("profiles").select("id, class").eq("school_id", school_id).eq("role", "student").in_("class", classes).aexecute()
        students_data = students_res.data or []
        
        class_student_count = {}
        for s in students_data:
            c = s.get("class")
            if c:
                class_student_count[c] = class_student_count.get(c, 0) + 1
                
        # Query submissions count grouped by homework_id
        hw_ids = [hw["id"] for hw in homework]
        submissions_res = await sb.table("homework_submissions").select("homework_id, id").eq("school_id", school_id).in_("homework_id", hw_ids).aexecute()
        submissions_data = submissions_res.data or []
        
        hw_submission_count = {}
        for sub in submissions_data:
            h_id = sub.get("homework_id")
            if h_id:
                hw_submission_count[h_id] = hw_submission_count.get(h_id, 0) + 1
                
        for hw in homework:
            hw["total_count"] = class_student_count.get(hw["class"], 0)
            hw["submitted_count"] = hw_submission_count.get(hw["id"], 0)
            subj = hw.get("subjects") or {}
            hw["subject"] = subj.get("name", "Unknown")
            hw["subject_icon"] = subj.get("icon", "📚")
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
            
    return {"success": True, "school_id": school_id, "data": {"homework": homework}}



@router.get("/exams")
async def teacher_get_exams(type: str = None, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("exams").select("*, subjects(name, class)").eq("school_id", school_id).eq("teacher_id", user["id"])
    exams_data = (await query.order("created_at", ascending=False).aexecute()).data
    
    exam_ids = [e["id"] for e in exams_data]
    question_counts = {}
    joined_counts = {}
    completed_counts = {}
    
    if exam_ids:
        # Get count of questions grouped by exam_id
        q_count_res = await sb.table("exam_questions").select("exam_id").in_("exam_id", exam_ids).aexecute()
        for row in (q_count_res.data or []):
            eid = row.get("exam_id")
            if eid:
                question_counts[eid] = question_counts.get(eid, 0) + 1
                
        # Get count of sessions (joined) grouped by exam_id
        sessions_res = await sb.table("exam_sessions").select("exam_id, student_id").in_("exam_id", exam_ids).aexecute()
        joined_sets = {}
        for row in (sessions_res.data or []):
            eid = row.get("exam_id")
            sid = row.get("student_id")
            if eid and sid:
                joined_sets.setdefault(eid, set()).add(sid)
        for eid, sids in joined_sets.items():
            joined_counts[eid] = len(sids)
            
        # Get count of submissions (completed) grouped by exam_id
        submissions_res = await sb.table("exam_submissions").select("exam_id, student_id").in_("exam_id", exam_ids).aexecute()
        completed_sets = {}
        for row in (submissions_res.data or []):
            eid = row.get("exam_id")
            sid = row.get("student_id")
            if eid and sid:
                completed_sets.setdefault(eid, set()).add(sid)
        for eid, sids in completed_sets.items():
            completed_counts[eid] = len(sids)

    for e in exams_data:
        subj = e.get("subjects") or {}
        e["subject"] = subj.get("name", "Unknown")
        
        tc = e.get("target_classes")
        if tc:
            if isinstance(tc, str):
                try:
                    import json
                    tc = json.loads(tc)
                except Exception:
                    pass
            if isinstance(tc, list):
                e["class"] = ", ".join(tc)
            else:
                e["class"] = str(tc)
        else:
            e["class"] = subj.get("class", "Unknown")
            
        if not e.get("exam_date"):
            e["exam_date"] = e.get("start_time")[:10] if e.get("start_time") else None
            
        e["duration"] = str(e.get("duration_minutes", 0)) + " mins"
        e["question_count"] = question_counts.get(e["id"], 0)
        e["joined_count"] = joined_counts.get(e["id"], 0)
        e["completed_count"] = completed_counts.get(e["id"], 0)
        
    if type and type.lower() != 'all':
        exams_data = [
            e for e in exams_data 
            if (e.get("exam_type") or "").lower() == type.lower() 
            or (e.get("exam_category") or "").lower() == type.lower()
            or (type.lower() == 'term' and (e.get("exam_category") or "").lower() == 'mid term')
            or (type.lower() == 'unit' and (e.get("exam_category") or "").lower() == 'unit test')
            or (type.lower() == 'quiz' and (e.get("exam_category") or "").lower() == 'practice test')
            or (type.lower() == 'final' and (e.get("exam_category") or "").lower() == 'final exam')
        ]

    return {"success": True, "school_id": school_id, "data": {"exams": exams_data}}


@router.get("/exams/{exam_id}")
async def teacher_get_exam_details(exam_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    exam_res = await sb.table("exams").select("*, subjects(name, class)").eq("id", exam_id).eq("school_id", school_id).maybe_single().aexecute()
    exam = exam_res.data
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")
        
    # Get question count
    q_count_res = await sb.table("exam_questions").select("id").eq("exam_id", exam_id).aexecute()
    exam["question_count"] = len(q_count_res.data or [])
    
    # Get joined count
    sessions_res = await sb.table("exam_sessions").select("student_id").eq("exam_id", exam_id).aexecute()
    joined_students = {row["student_id"] for row in (sessions_res.data or []) if row.get("student_id")}
    exam["joined_count"] = len(joined_students)
    
    # Get completed/submitted count
    submissions_res = await sb.table("exam_submissions").select("student_id").eq("exam_id", exam_id).aexecute()
    completed_students = {row["student_id"] for row in (submissions_res.data or []) if row.get("student_id")}
    exam["completed_count"] = len(completed_students)
    
    # Format target classes
    tc = exam.get("target_classes")
    if tc:
        if isinstance(tc, str):
            try:
                import json
                tc = json.loads(tc)
            except Exception:
                pass
        if isinstance(tc, list):
            exam["class"] = ", ".join(tc)
        else:
            exam["class"] = str(tc)
    else:
        subj = exam.get("subjects") or {}
        exam["class"] = subj.get("class", "Unknown")
        
    if not exam.get("exam_date"):
        exam["exam_date"] = exam.get("start_time")[:10] if exam.get("start_time") else None
        
    exam["duration"] = str(exam.get("duration_minutes", 0)) + " mins"
    subj = exam.get("subjects") or {}
    exam["subject"] = subj.get("name", "Unknown")
    
    return {"success": True, "school_id": school_id, "data": exam}


@router.get("/exams/{exam_id}/attendance")
async def teacher_get_exam_attendance(exam_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Fetch exam details
    exam_res = await sb.table("exams").select("*").eq("id", exam_id).eq("school_id", school_id).maybe_single().aexecute()
    exam = exam_res.data
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")
        
    # Parse target classes
    classes = []
    tc = exam.get("target_classes")
    if tc:
        if isinstance(tc, str):
            try:
                import json
                tc_parsed = json.loads(tc)
                if isinstance(tc_parsed, list):
                    classes = tc_parsed
                else:
                    classes = [str(tc_parsed)]
            except Exception:
                classes = [tc]
        elif isinstance(tc, list):
            classes = tc

    # Fetch students in target classes
    students_query = sb.table("profiles").select("id, full_name, roll_number, class").eq("school_id", school_id).eq("role", "student")
    if classes:
        students_query = students_query.in_("class", classes)
    students_res = await students_query.aexecute()
    students = students_res.data or []

    # Filter by specific students if scope is Specific Students
    scope = exam.get("scope", "All Students")
    target_students = exam.get("target_students")
    if scope == "Specific Students" and target_students:
        if isinstance(target_students, str):
            try:
                import json
                target_students = json.loads(target_students)
            except Exception:
                pass
        if isinstance(target_students, list):
            target_ids = set(target_students)
            students = [s for s in students if s["id"] in target_ids]

    # Fetch submissions
    submissions_res = await sb.table("exam_submissions").select("id, student_id, status").eq("exam_id", exam_id).aexecute()
    submissions = submissions_res.data or []
    attended_student_ids = {sub["student_id"] for sub in submissions}
    sub_map = {sub["student_id"]: sub for sub in submissions}

    data = []
    for s in students:
        s_id = s["id"]
        sub = sub_map.get(s_id)
        data.append({
            "id": s_id,
            "full_name": s["full_name"],
            "roll_number": s["roll_number"],
            "class": s["class"],
            "present": s_id in attended_student_ids,
            "submission_id": sub["id"] if sub else None,
            "status": sub["status"] if sub else None
        })

    return {"success": True, "school_id": school_id, "data": {"students": data}}


@router.post("/exams/{exam_id}/attendance")
async def teacher_save_exam_attendance(exam_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Fetch exam details
    exam_res = await sb.table("exams").select("*").eq("id", exam_id).eq("school_id", school_id).maybe_single().aexecute()
    exam = exam_res.data
    if not exam:
        raise HTTPException(status_code=404, detail="Exam not found")

    student_ids = request.get("student_ids", [])
    present_set = set(student_ids)

    # Fetch current submissions
    curr_subs_res = await sb.table("exam_submissions").select("id, student_id, status").eq("exam_id", exam_id).aexecute()
    curr_subs = {sub["student_id"]: sub for sub in (curr_subs_res.data or [])}

    to_insert = []
    to_delete = []

    # Find new present students to insert
    for s_id in present_set:
        if s_id not in curr_subs:
            to_insert.append({
                "exam_id": exam_id,
                "student_id": s_id,
                "status": "submitted",
                "answers": {},
                "score": None,
                "submitted_at": datetime.utcnow().isoformat()
            })

    # Find marked-absent students to delete
    for s_id, sub in curr_subs.items():
        if s_id not in present_set:
            if sub["status"] == "graded":
                raise HTTPException(status_code=400, detail=f"Cannot mark student absent because their exam is already graded.")
            to_delete.append(sub["id"])

    if to_insert:
        await sb.table("exam_submissions").insert(to_insert).aexecute()
    if to_delete:
        await sb.table("exam_submissions").delete().in_("id", to_delete).aexecute()

    # Award XP for attending offline exam
    try:
        from app.services.supabase_client import award_xp
        for s_id in present_set:
            await award_xp(sb, school_id, s_id, 15, "attendance", exam_id, f"Attended offline exam: {exam.get('title')}")
    except Exception as e:
        print(f"Error awarding exam attendance XP: {str(e)}", flush=True)

    return {"success": True, "school_id": school_id, "message": "Attendance saved successfully"}


@router.get("/notices")
async def teacher_get_notices(
    category: str = None,
    tab: str = "all",
    search: str = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    query = sb.table("notices").select("*").eq("school_id", school_id)
    
    # We fetch the notices first and then apply filters in Python for reliable combinations
    notices_data = (await query.order("published_at", ascending=False).aexecute()).data or []
    
    user_id = user["id"]
    filtered_notices = []
    
    for n in notices_data:
        # Check tab filter
        is_author = n.get("author_id") == user_id
        status = n.get("status", "published")
        
        if tab == "draft":
            if status != "draft" or not is_author:
                continue
        elif tab == "my":
            if is_author and status in ["published", "scheduled"]:
                pass
            else:
                continue
        elif tab == "school":
            if not is_author and status in ["published", "scheduled"]:
                pass
            else:
                continue
        else: # tab == 'all'
            if status in ["published", "scheduled"]:
                pass
            else:
                continue
                
        # Category filter (case-insensitive)
        if category and category.lower() != 'all':
            notice_cat = (n.get("category") or "").lower()
            if notice_cat != category.lower() and category.lower() not in notice_cat:
                continue
                
        # Search filter
        if search:
            search_lower = search.lower()
            title = (n.get("title") or "").lower()
            content = (n.get("content") or "").lower()
            if search_lower not in title and search_lower not in content:
                continue
                
        filtered_notices.append(n)
        
    for n in filtered_notices:
        n["created_at"] = n.get("published_at") or n.get("created_at")
        
    # Enrich notices with registrations count
    notice_ids = [n["id"] for n in filtered_notices if n.get("id")]
    if notice_ids:
        reg_res = (await sb.table("notice_registrations")
                   .select("notice_id")
                   .in_("notice_id", notice_ids)
                   .aexecute()).data or []
        
        reg_counts = {}
        for r in reg_res:
            nid = r.get("notice_id")
            if nid:
                reg_counts[nid] = reg_counts.get(nid, 0) + 1
                
        for n in filtered_notices:
            nid = n.get("id")
            n["registration_count"] = reg_counts.get(nid, 0)
    else:
        for n in filtered_notices:
            n["registration_count"] = 0
            
    return {"success": True, "school_id": school_id, "data": {"notices": filtered_notices}}


@router.get("/notices/{notice_id}/registrations")
async def get_notice_registrations(notice_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Query notice registrations and select details of students
    res = await (sb.table("notice_registrations")
                 .select("student_id, profiles!student_id(id, full_name, avatar_url, roll_number, email)")
                 .eq("school_id", school_id)
                 .eq("notice_id", notice_id)
                 .aexecute())
    
    registrations = res.data or []
    students = []
    for r in registrations:
        prof = r.get("profiles")
        if prof:
            students.append({
                "id": prof.get("id"),
                "full_name": prof.get("full_name"),
                "avatar_url": prof.get("avatar_url"),
                "roll_number": prof.get("roll_number"),
                "email": prof.get("email")
            })
            
    return {"success": True, "school_id": school_id, "data": {"registrations": students}}



@router.get("/leave")
async def teacher_get_leave(status: str = None, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("leave_applications").select("*").eq("school_id", school_id).eq("applicant_id", user["id"])
    if status and status.lower() != 'all':
        query = query.eq("status", status.lower())
    applications = (await query.order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"applications": applications}}


@router.get("/materials")
async def teacher_get_materials(type: str = None, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("study_materials").select("*").eq("school_id", school_id).eq("teacher_id", user["id"])
    if type and type.lower() != 'all':
        query = query.eq("material_type", type.lower())
    materials = (await query.order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"materials": materials}}


@router.get("/salary/{salary_id}/download")
async def download_salary_slip(
    salary_id: str,
    request: Request,
    token: Optional[str] = Query(None)
):
    # Authenticate token from query parameter or Authorization header
    token_str = token
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token_str = auth_header.split(" ")[1]
        
    if not token_str:
        raise HTTPException(status_code=401, detail="Authentication token required")
        
    import os
    from jose import jwt, JWTError
    try:
        jwt_secret = os.getenv("SUPABASE_JWT_SECRET", os.getenv("JWT_SECRET", "eduSHAMIIT-jwt-secret-2026"))
        payload = jwt.decode(
            token_str,
            jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False}
        )
        user = {
            "id": payload.get("sub"),
            "school_id": payload.get("school_id"),
            "role": payload.get("role"),
            "class": payload.get("class"),
            "email": payload.get("email"),
        }
        if not user["id"]:
            raise HTTPException(status_code=401, detail="Invalid token: missing user ID")
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")
        
    school_id = user.get("school_id")
    if not school_id:
        raise HTTPException(status_code=400, detail="school_id required")

    sb = get_supabase()
    # Fetch the salary record and verify ownership
    salary_res = await sb.table("salary").select("*").eq("id", salary_id).eq("school_id", school_id).eq("teacher_id", user["id"]).maybe_single().aexecute()
    salary = salary_res.data
    if not salary:
        raise HTTPException(status_code=404, detail="Salary slip not found or access denied")
    
    # Fetch school name
    school_res = await sb.table("schools").select("name").eq("id", school_id).maybe_single().aexecute()
    school_name = (school_res.data or {}).get("name", "EduSHAMIIT Academy")
    
    # Fetch profile details (for full name, email, subject/specialization)
    profile_res = await sb.table("profiles").select("*").eq("id", user["id"]).maybe_single().aexecute()
    profile = profile_res.data or {}
    
    # Generate PDF bytes using ReportLab
    import io
    from reportlab.lib.pagesizes import letter
    from reportlab.lib import colors
    from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_RIGHT
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
    from reportlab.lib.units import inch
    from fastapi.responses import StreamingResponse
    
    buffer = io.BytesIO()
    
    # Setup document
    doc = SimpleDocTemplate(
        buffer,
        pagesize=letter,
        leftMargin=0.75*inch,
        rightMargin=0.75*inch,
        topMargin=0.75*inch,
        bottomMargin=0.75*inch
    )
    
    story = []
    
    # Colors
    C_BRAND = colors.HexColor("#059669")  # Emerald/Green matching mockup
    C_BRAND_LIGHT = colors.HexColor("#ECFDF5")
    C_DARK = colors.HexColor("#0F172A")
    C_TEXT = colors.HexColor("#475569")
    C_BORDER = colors.HexColor("#E2E8F0")
    C_RED = colors.HexColor("#EF4444")
    
    # Styles
    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'DocTitle', parent=styles['Normal'],
        fontSize=20, leading=26, fontName='Helvetica-Bold',
        textColor=C_BRAND, alignment=TA_CENTER
    )
    subtitle_style = ParagraphStyle(
        'DocSubTitle', parent=styles['Normal'],
        fontSize=10, leading=14, fontName='Helvetica-Bold',
        textColor=C_TEXT, alignment=TA_CENTER,
        spaceAfter=15
    )
    section_title = ParagraphStyle(
        'SectionTitle', parent=styles['Normal'],
        fontSize=12, leading=16, fontName='Helvetica-Bold',
        textColor=C_DARK, spaceBefore=10, spaceAfter=6
    )
    body_style = ParagraphStyle(
        'BodyText', parent=styles['Normal'],
        fontSize=9, leading=13, fontName='Helvetica',
        textColor=C_TEXT
    )
    body_bold = ParagraphStyle(
        'BodyTextBold', parent=styles['Normal'],
        fontSize=9, leading=13, fontName='Helvetica-Bold',
        textColor=C_DARK
    )
    body_right = ParagraphStyle(
        'BodyTextRight', parent=styles['Normal'],
        fontSize=9, leading=13, fontName='Helvetica',
        textColor=C_TEXT, alignment=TA_RIGHT
    )
    body_bold_right = ParagraphStyle(
        'BodyTextBoldRight', parent=styles['Normal'],
        fontSize=9, leading=13, fontName='Helvetica-Bold',
        textColor=C_DARK, alignment=TA_RIGHT
    )
    
    # Title
    story.append(Paragraph(school_name.upper(), title_style))
    month_names = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    month_name = month_names[salary.get("month", 1)]
    year = salary.get("year", 2026)
    story.append(Paragraph(f"SALARY PAYSLIP — {month_name.upper()} {year}", subtitle_style))
    story.append(HRFlowable(width='100%', thickness=1.5, color=C_BRAND, spaceAfter=15))
    
    # Employee & Pay Summary Info Table
    emp_info = [
        [Paragraph("<b>Employee Name:</b>", body_style), Paragraph(profile.get("full_name", "Teacher"), body_bold),
         Paragraph("<b>Payslip ID:</b>", body_style), Paragraph(str(salary.get("id"))[:8] + "...", body_style)],
        [Paragraph("<b>Email:</b>", body_style), Paragraph(profile.get("email", ""), body_style),
         Paragraph("<b>Payment Mode:</b>", body_style), Paragraph(salary.get("payment_mode", "bank_transfer").replace("_", " ").title(), body_style)],
        [Paragraph("<b>Role:</b>", body_style), Paragraph(user.get("role", "Teacher").title(), body_style),
         Paragraph("<b>Status:</b>", body_style), Paragraph(f"<font color='#059669'><b>{salary.get('status', 'paid').upper()}</b></font>", body_style)],
    ]
    
    info_table = Table(emp_info, colWidths=[1.5*inch, 2*inch, 1.25*inch, 2.25*inch])
    info_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 4),
        ('TOPPADDING', (0, 0), (-1, -1), 4),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(info_table)
    story.append(Spacer(1, 15))
    story.append(HRFlowable(width='100%', thickness=1, color=C_BORDER, spaceAfter=15))
    
    # Calculate Breakup values
    basic = float(salary.get("basic_pay", 0) or 0)
    hra = float(salary.get("hra", 0) or 0)
    da = float(salary.get("da", 0) or 0)
    special_allowance = float(salary.get("special_allowance", 0) or 0)
    pf = float(salary.get("pf_deduction", 0) or 0)
    tds = float(salary.get("tds", 0) or 0)
    prof_tax = float(salary.get("professional_tax", 0) or 0)
    misc = float(salary.get("miscellaneous", 0) or 0)
    advance_deduction = float(salary.get("advance_deduction", 0) or 0)
    
    # Split miscellaneous into earning or deduction
    misc_earning = misc if misc > 0 else 0.0
    misc_deduction = abs(misc) if misc < 0 else 0.0
    
    gross = basic + hra + da + special_allowance + misc_earning
    deductions = pf + tds + prof_tax + misc_deduction + advance_deduction
    net = gross - deductions
    
    # Breakup Table: Earnings vs Deductions
    breakup_data = [
        [Paragraph("<b>EARNINGS</b>", body_bold), Paragraph("<b>AMOUNT (Rs.)</b>", body_bold_right),
         Paragraph("<b>DEDUCTIONS</b>", body_bold), Paragraph("<b>AMOUNT (Rs.)</b>", body_bold_right)],
        
        [Paragraph("Basic Pay", body_style), Paragraph(f"Rs. {basic:,.2f}", body_right),
         Paragraph("PF Deduction", body_style), Paragraph(f"Rs. {pf:,.2f}", body_right)],
        
        [Paragraph("HRA", body_style), Paragraph(f"Rs. {hra:,.2f}", body_right),
         Paragraph("TDS", body_style), Paragraph(f"Rs. {tds:,.2f}", body_right)],
         
        [Paragraph("DA", body_style), Paragraph(f"Rs. {da:,.2f}", body_right),
         Paragraph("Professional Tax", body_style), Paragraph(f"Rs. {prof_tax:,.2f}", body_right)],
         
        [Paragraph("Special Allowance", body_style), Paragraph(f"Rs. {special_allowance:,.2f}", body_right),
         Paragraph("Salary Advance", body_style) if advance_deduction > 0 else Paragraph("", body_style), Paragraph(f"Rs. {advance_deduction:,.2f}" if advance_deduction > 0 else "", body_right)],
         
        [Paragraph("Miscellaneous", body_style) if misc_earning > 0 else Paragraph("", body_style), Paragraph(f"Rs. {misc_earning:,.2f}" if misc_earning > 0 else "", body_right),
         Paragraph("Miscellaneous", body_style) if misc_deduction > 0 else Paragraph("", body_style), Paragraph(f"Rs. {misc_deduction:,.2f}" if misc_deduction > 0 else "", body_right)],
         
        [Paragraph("<b>Gross Earnings</b>", body_bold), Paragraph(f"<b>Rs. {gross:,.2f}</b>", body_bold_right),
         Paragraph("<b>Total Deductions</b>", body_bold), Paragraph(f"<b>Rs. {deductions:,.2f}</b>", body_bold_right)],
    ]
    
    breakup_table = Table(breakup_data, colWidths=[1.8*inch, 1.6*inch, 1.8*inch, 1.8*inch])
    breakup_table.setStyle(TableStyle([
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BACKGROUND', (0, 0), (1, 0), C_BRAND_LIGHT),
        ('BACKGROUND', (2, 0), (3, 0), colors.HexColor("#FEF2F2")),
        ('GRID', (0, 0), (-1, -1), 0.5, C_BORDER),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 6),
        ('TOPPADDING', (0, 0), (-1, -1), 6),
        ('LEFTPADDING', (0, 0), (-1, -1), 8),
        ('RIGHTPADDING', (0, 0), (-1, -1), 8),
        ('BACKGROUND', (0, -1), (1, -1), C_BRAND_LIGHT),
        ('BACKGROUND', (2, -1), (3, -1), colors.HexColor("#FEF2F2")),
    ]))
    
    story.append(Paragraph("Salary Breakup Details", section_title))
    story.append(breakup_table)
    story.append(Spacer(1, 20))
    
    # Net Salary Highlight Card
    net_data = [
        [Paragraph(f"<font size='14'><b>Net Salary: Rs. {net:,.2f}</b></font><br/><font size='8' color='#64748B'>({month_name} {year})</font>", body_bold),
         Paragraph(f"<font color='#059669'><b>✔ Credited successfully</b></font><br/><font size='8' color='#64748B'>Paid on: {salary.get('paid_at', '')[:10] if salary.get('paid_at') else 'N/A'}</font>", body_bold_right)]
    ]
    net_table = Table(net_data, colWidths=[3.5*inch, 3.5*inch])
    net_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, -1), C_BRAND_LIGHT),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('BOX', (0, 0), (-1, -1), 1.5, C_BRAND),
        ('TOPPADDING', (0, 0), (-1, -1), 10),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 10),
        ('LEFTPADDING', (0, 0), (-1, -1), 15),
        ('RIGHTPADDING', (0, 0), (-1, -1), 15),
    ]))
    story.append(net_table)
    story.append(Spacer(1, 40))
    
    # Signature Section
    sig_data = [
        [Paragraph("", body_style), Paragraph("For " + school_name, body_bold_right)],
        [Spacer(1, 40), Spacer(1, 40)],
        [Paragraph("Employee Signature", body_style), Paragraph("Authorized Signatory", body_bold_right)],
    ]
    sig_table = Table(sig_data, colWidths=[3.5*inch, 3.5*inch])
    sig_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (0, -1), 'LEFT'),
        ('ALIGN', (1, 0), (1, -1), 'RIGHT'),
        ('VALIGN', (0, 0), (-1, -1), 'BOTTOM'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
    ]))
    story.append(sig_table)
    
    # Build PDF
    doc.build(story)
    
    buffer.seek(0)
    filename = f"Payslip_{year}_{month_name}.pdf"
    
    return StreamingResponse(
        buffer,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f"attachment; filename={filename}"
        }
    )


@router.get("/salary/advance")
async def get_salary_advances(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    advances = (await sb.table("salary_advances")
                .select("*")
                .eq("school_id", school_id)
                .eq("teacher_id", user["id"])
                .order("created_at", ascending=False)
                .aexecute()).data
    return {"success": True, "data": {"salary_advances": advances}}


@router.post("/salary/advance")
async def request_salary_advance(
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    amount = float(request.get("amount", 0))
    purpose_type = request.get("purpose_type")
    reason = request.get("reason")
    month = int(request.get("month", datetime.utcnow().month))
    year = int(request.get("year", datetime.utcnow().year))
    
    if amount <= 0:
        raise HTTPException(status_code=400, detail="Advance amount must be greater than zero")
    if not purpose_type:
        raise HTTPException(status_code=400, detail="Purpose type is required")
        
    sb = get_supabase()
    
    # Check limit: amount must be <= min(basic_pay, net_salary)
    # Find salary record for this month/year. If none, get latest record.
    salary_res = await sb.table("salary").select("*").eq("school_id", school_id).eq("teacher_id", user["id"]).eq("month", month).eq("year", year).maybe_single().aexecute()
    salary = salary_res.data
    
    if not salary:
        # Fall back to latest historical salary record
        latest_res = await sb.table("salary").select("*").eq("school_id", school_id).eq("teacher_id", user["id"]).order("year", ascending=False).order("month", ascending=False).limit(1).aexecute()
        if latest_res.data:
            salary = latest_res.data[0]
            
    if not salary:
        # Defaults if no history exists at all (safety fallback)
        basic_pay = 50000.0
        net_salary = 50000.0
    else:
        basic_pay = float(salary.get("basic_pay", 0) or 0)
        net_salary = float(salary.get("net_pay") or salary.get("amount", 0) or 0)
        
    limit = min(basic_pay, net_salary)
    if amount > limit:
        raise HTTPException(
            status_code=400, 
            detail=f"Requested advance amount (Rs. {amount:,.2f}) exceeds the limit. Your limit is Rs. {limit:,.2f} (minimum of basic salary Rs. {basic_pay:,.2f} and net salary Rs. {net_salary:,.2f})."
        )
        
    # Insert advance request
    advance_data = {
        "school_id": school_id,
        "teacher_id": user["id"],
        "amount": amount,
        "purpose_type": purpose_type,
        "reason": reason,
        "status": "pending",
        "month": month,
        "year": year
    }
    
    insert_res = await sb.table("salary_advances").insert(advance_data).aexecute()
    return {"success": True, "message": "Salary advance requested successfully", "data": {"advance": insert_res.data[0]}}


@router.post("/salary/advance/{advance_id}/approve-debug")
async def approve_salary_advance_debug(
    advance_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    
    # 1. Fetch advance request
    advance_res = await sb.table("salary_advances").select("*").eq("id", advance_id).eq("school_id", school_id).maybe_single().aexecute()
    advance = advance_res.data
    if not advance:
        raise HTTPException(status_code=404, detail="Salary advance request not found")
        
    if advance.get("status") != "pending":
        raise HTTPException(status_code=400, detail=f"Request is already {advance.get('status')}")
        
    # 2. Update request status to approved
    await sb.table("salary_advances").update({"status": "approved", "updated_at": datetime.utcnow().isoformat()}).eq("id", advance_id).aexecute()
    
    amount = float(advance["amount"])
    month = advance["month"]
    year = advance["year"]
    teacher_id = advance["teacher_id"]
    
    # 3. Apply deduction to the corresponding month's salary record
    salary_res = await sb.table("salary").select("*").eq("school_id", school_id).eq("teacher_id", teacher_id).eq("month", month).eq("year", year).maybe_single().aexecute()
    salary = salary_res.data
    
    if salary:
        # Update existing salary record
        current_deduction = float(salary.get("advance_deduction", 0) or 0)
        new_deduction = current_deduction + amount
        
        # Calculate new totals
        basic = float(salary.get("basic_pay", 0) or 0)
        hra = float(salary.get("hra", 0) or 0)
        da = float(salary.get("da", 0) or 0)
        sa = float(salary.get("special_allowance", 0) or 0)
        pf = float(salary.get("pf_deduction", 0) or 0)
        tds = float(salary.get("tds", 0) or 0)
        pt = float(salary.get("professional_tax", 0) or 0)
        misc = float(salary.get("miscellaneous", 0) or 0)
        misc_earning = misc if misc > 0 else 0.0
        misc_deduction = abs(misc) if misc < 0 else 0.0
        
        gross = basic + hra + da + sa + misc_earning
        total_deductions = pf + tds + pt + misc_deduction + new_deduction
        net = gross - total_deductions
        
        update_data = {
            "advance_deduction": new_deduction,
            "deductions": total_deductions,
            "net_pay": net,
            "amount": net,
            "updated_at": datetime.utcnow().isoformat()
        }
        await sb.table("salary").update(update_data).eq("id", salary["id"]).aexecute()
    else:
        # Create a new salary record using the latest record as template
        latest_res = await sb.table("salary").select("*").eq("school_id", school_id).eq("teacher_id", teacher_id).order("year", ascending=False).order("month", ascending=False).limit(1).aexecute()
        
        if latest_res.data:
            template = latest_res.data[0]
            basic = float(template.get("basic_pay", 0) or 0)
            hra = float(template.get("hra", 0) or 0)
            da = float(template.get("da", 0) or 0)
            sa = float(template.get("special_allowance", 0) or 0)
            pf = float(template.get("pf_deduction", 0) or 0)
            tds = float(template.get("tds", 0) or 0)
            pt = float(template.get("professional_tax", 0) or 0)
            misc = float(template.get("miscellaneous", 0) or 0)
        else:
            # Fallbacks if no salary record exists
            basic, hra, da, sa, pf, tds, pt, misc = 45000.0, 18000.0, 7000.0, 5000.0, 3600.0, 2500.0, 450.0, 0.0
            
        misc_earning = misc if misc > 0 else 0.0
        misc_deduction = abs(misc) if misc < 0 else 0.0
        
        gross = basic + hra + da + sa + misc_earning
        total_deductions = pf + tds + pt + misc_deduction + amount
        net = gross - total_deductions
        
        month_str = f"{year}-{month:02d}"
        
        new_salary = {
            "school_id": school_id,
            "teacher_id": teacher_id,
            "month": month,
            "year": year,
            "month_str": month_str,
            "basic_pay": basic,
            "hra": hra,
            "da": da,
            "special_allowance": sa,
            "pf_deduction": pf,
            "tds": tds,
            "professional_tax": pt,
            "miscellaneous": misc,
            "advance_deduction": amount,
            "deductions": total_deductions,
            "net_pay": net,
            "amount": net,
            "status": "pending",
            "payment_mode": "bank_transfer"
        }
        await sb.table("salary").insert(new_salary).aexecute()
        
    await invalidate_cache(school_id, "teacher_salary")
    return {"success": True, "message": "Salary advance approved and deduction applied successfully"}


@router.delete("/salary/advance/{advance_id}")
async def cancel_salary_advance(
    advance_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    # Fetch request first to verify it belongs to user and is pending
    advance_res = await sb.table("salary_advances").select("*").eq("id", advance_id).eq("school_id", school_id).eq("teacher_id", user["id"]).maybe_single().aexecute()
    advance = advance_res.data
    if not advance:
        raise HTTPException(status_code=404, detail="Salary advance request not found")
        
    if advance.get("status") != "pending":
        raise HTTPException(status_code=400, detail="Only pending advance requests can be cancelled")
        
    # Delete from database
    await sb.table("salary_advances").delete().eq("id", advance_id).aexecute()
    return {"success": True, "message": "Salary advance request cancelled successfully"}


# ─── ONLINE EXAMS CRUD ENDPOINTS FOR TEACHERS ───

async def _update_exam_questions_status(sb, exam_id: str):
    # Count the questions
    q_res = await sb.table("exam_questions").select("id").eq("exam_id", exam_id).aexecute()
    q_count = len(q_res.data) if q_res.data else 0
    
    # Get current exam status
    exam_res = await sb.table("exams").select("status").eq("id", exam_id).maybe_single().aexecute()
    if exam_res.data:
        current_status = exam_res.data.get("status")
        # Only transition between 'new', 'draft' and 'in_progress'
        if q_count > 0 and current_status in ('new', 'draft'):
            await sb.table("exams").update({"status": "in_progress"}).eq("id", exam_id).aexecute()
        elif q_count == 0 and current_status == 'in_progress':
            await sb.table("exams").update({"status": "new"}).eq("id", exam_id).aexecute()

@router.get("/exams/{exam_id}/questions")
async def teacher_get_exam_questions(exam_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    res = await sb.table("exam_questions").select("*").eq("exam_id", exam_id).order("order_number").aexecute()
    return {"success": True, "school_id": school_id, "data": {"questions": res.data}}


@router.post("/exams/{exam_id}/questions")
async def teacher_add_exam_question(exam_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Fetch current max order_number
    questions = (await sb.table("exam_questions").select("order_number").eq("exam_id", exam_id).aexecute()).data
    next_order = max([q.get("order_number", 0) for q in questions] + [0]) + 1
    
    new_q = {
        "exam_id": exam_id,
        "question_text": request.get("question_text"),
        "question_type": request.get("question_type", "mcq"),
        "options": request.get("options"),
        "correct_answer": request.get("correct_answer"),
        "marks": request.get("marks", 1),
        "order_number": request.get("order_number", next_order),
    }
    res = await sb.table("exam_questions").insert(new_q).aexecute()
    await _update_exam_questions_status(sb, exam_id)
    return {"success": True, "school_id": school_id, "data": res.data[0]}


@router.put("/exams/{exam_id}/questions/{question_id}")
async def teacher_update_exam_question(exam_id: str, question_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    allowed = {"question_text", "question_type", "options", "correct_answer", "marks", "order_number"}
    updates = {k: v for k, v in request.items() if k in allowed}
    res = await sb.table("exam_questions").update(updates).eq("id", question_id).eq("exam_id", exam_id).aexecute()
    return {"success": True, "school_id": school_id, "data": res.data[0]}


@router.delete("/exams/{exam_id}/questions/{question_id}")
async def teacher_delete_exam_question(exam_id: str, question_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("exam_questions").delete().eq("id", question_id).eq("exam_id", exam_id).aexecute()
    await _update_exam_questions_status(sb, exam_id)
    return {"success": True, "school_id": school_id, "message": "Question deleted"}


@router.get("/exams/{exam_id}/submissions")
async def teacher_get_exam_submissions(exam_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    res = await sb.table("exam_submissions").select("*, profiles!student_id(full_name, roll_number, class)").eq("exam_id", exam_id).order("score", ascending=False).aexecute()
    return {"success": True, "school_id": school_id, "data": {"submissions": res.data}}


@router.post("/exams/{exam_id}/submissions/{submission_id}/grade")
async def teacher_grade_exam_submission(exam_id: str, submission_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    score = request.get("score")
    remarks = request.get("remarks", "")
    answers = request.get("answers")
    
    # Fetch exam to get total_marks and passing_marks for grade calculation
    exam_res = await sb.table("exams").select("total_marks, passing_marks").eq("id", exam_id).maybe_single().aexecute()
    exam_data = exam_res.data or {}
    total_marks = float(exam_data.get("total_marks") or 100)
    passing_marks = float(exam_data.get("passing_marks") or (total_marks * 0.4))

    # Validate overall score
    if score is not None:
        score_val = float(score)
        if score_val > total_marks:
            raise HTTPException(status_code=400, detail=f"Total score ({score_val}) cannot exceed exam total marks ({total_marks})")
        if score_val < 0:
            raise HTTPException(status_code=400, detail="Total score cannot be negative")

    # Fetch exam questions to validate individual question marks limits
    questions_res = await sb.table("exam_questions").select("id, marks").eq("exam_id", exam_id).aexecute()
    questions = questions_res.data or []
    question_max_marks = {q["id"]: float(q.get("marks") or 0.0) for q in questions}

    # Validate individual subjective question marks if answers is provided
    if answers:
        for q_id, q_ans in answers.items():
            if isinstance(q_ans, dict) and "awarded_marks" in q_ans:
                awarded = float(q_ans["awarded_marks"])
                max_marks = question_max_marks.get(q_id)
                if max_marks is not None and awarded > max_marks:
                    raise HTTPException(
                        status_code=400, 
                        detail=f"Awarded marks ({awarded}) exceed maximum allowed marks ({max_marks}) for question {q_id}"
                    )
                if awarded < 0:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Awarded marks ({awarded}) cannot be negative for question {q_id}"
                    )

    is_pass = (score is not None and float(score) >= passing_marks)
    pct = (float(score) / total_marks * 100) if score is not None else 0
    if pct >= 90: grade_letter = "A+"
    elif pct >= 80: grade_letter = "A"
    elif pct >= 70: grade_letter = "B+"
    elif pct >= 60: grade_letter = "B"
    elif pct >= 50: grade_letter = "C"
    elif pct >= 40: grade_letter = "D"
    else: grade_letter = "F"
    
    update_data = {
        "score": score,
        "remarks": remarks,
        "status": "graded",
        "graded_at": datetime.utcnow().isoformat(),
        "grade_letter": grade_letter,
        "is_pass": is_pass,
    }
    if answers is not None:
        update_data["answers"] = answers

    res = await sb.table("exam_submissions").update(update_data).eq("id", submission_id).eq("exam_id", exam_id).aexecute()

    # Award XP dynamically based on exam score
    if score is not None:
        try:
            sub_res = await sb.table("exam_submissions").select("student_id").eq("id", submission_id).maybe_single().aexecute()
            sub_data = sub_res.data or {}
            student_id = sub_data.get("student_id")
            if student_id:
                from app.services.supabase_client import award_xp
                xp_to_add = int((float(score) / (total_marks or 100.0)) * 150)
                if xp_to_add > 0:
                    await award_xp(sb, school_id, student_id, xp_to_add, "exam", submission_id, f"Exam graded: {score}/{total_marks} marks")
        except Exception as e:
            print(f"Error awarding exam XP: {str(e)}", flush=True)

    return {"success": True, "school_id": school_id, "data": res.data[0] if res.data else {}}


@router.get("/exams/{exam_id}/analytics")
async def teacher_get_exam_analytics(exam_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """
    Returns real analytics for a completed/graded exam:
    - Participation stats (assigned, submitted, graded)
    - Score distribution (bins of 10%)
    - Per-question accuracy (% of students who got it right)
    - Top 5 performers, bottom 5 performers
    - Grade distribution (A+, A, B+, B, C, D, F)
    - Average, highest, lowest scores
    - Pass rate
    """
    sb = get_supabase()

    # Fetch exam details
    exam_res = await sb.table("exams").select("title, total_marks, passing_marks, target_classes, results_published_at").eq("id", exam_id).maybe_single().aexecute()
    exam_data = exam_res.data or {}
    total_marks = exam_data.get("total_marks") or 100
    passing_marks = float(exam_data.get("passing_marks") or (total_marks * 0.4))

    # Fetch all graded submissions
    subs_res = await sb.table("exam_submissions").select(
        "id, student_id, score, status, grade_letter, is_pass, answers, profiles!student_id(full_name, roll_number)"
    ).eq("exam_id", exam_id).aexecute()
    all_submissions = subs_res.data or []
    graded = [s for s in all_submissions if s.get("status") == "graded" or s.get("score") is not None]
    submitted = [s for s in all_submissions if s.get("status") in ("submitted", "graded")]

    # Fetch questions for per-question accuracy
    q_res = await sb.table("exam_questions").select("id, question_text, question_type, options, correct_answer, marks, order_number").eq("exam_id", exam_id).order("order_number").aexecute()
    questions = q_res.data or []

    # Score stats
    scores = [float(s["score"]) for s in graded if s.get("score") is not None]
    avg_score = round(sum(scores) / len(scores), 2) if scores else 0
    highest_score = round(max(scores), 2) if scores else 0
    lowest_score = round(min(scores), 2) if scores else 0
    pass_count = sum(1 for s in graded if s.get("is_pass") or (s.get("score") is not None and float(s["score"]) >= passing_marks))
    pass_rate = round(pass_count / len(graded) * 100, 1) if graded else 0

    # Score distribution (bins: 0-10, 10-20, ..., 90-100)
    bins = {f"{i*10}-{(i+1)*10}%": 0 for i in range(10)}
    for score in scores:
        pct = (score / total_marks) * 100
        bin_idx = min(int(pct // 10), 9)
        key = f"{bin_idx*10}-{(bin_idx+1)*10}%"
        bins[key] = bins.get(key, 0) + 1

    # Grade distribution
    grade_dist = {"A+": 0, "A": 0, "B+": 0, "B": 0, "C": 0, "D": 0, "F": 0}
    for s in graded:
        pct = (float(s["score"]) / total_marks * 100) if s.get("score") is not None else 0
        if pct >= 90: grade_dist["A+"] += 1
        elif pct >= 80: grade_dist["A"] += 1
        elif pct >= 70: grade_dist["B+"] += 1
        elif pct >= 60: grade_dist["B"] += 1
        elif pct >= 50: grade_dist["C"] += 1
        elif pct >= 40: grade_dist["D"] += 1
        else: grade_dist["F"] += 1

    # Per-question accuracy (for MCQ, numerical, fill_in_the_blank, assertion_reason)
    question_stats = []
    for q in questions:
        q_id = q["id"]
        correct_answer = q.get("correct_answer")
        q_type = q.get("question_type", "mcq")
        if q_type == "subjective":
            question_stats.append({
                "id": q_id,
                "text": q["question_text"][:80] + "..." if len(q.get("question_text", "")) > 80 else q.get("question_text", ""),
                "type": q_type,
                "marks": q.get("marks", 0),
                "accuracy": None,
                "attempts": len(submitted),
            })
            continue
        attempts = 0
        correct = 0
        for s in submitted:
            answers = s.get("answers") or {}
            student_ans = answers.get(q_id) or answers.get(str(q_id))
            if student_ans is not None:
                attempts += 1
                if correct_answer:
                    if q_type == "single_select" or q_type == "mcq":
                        match = False
                        sa = str(student_ans).strip().upper()
                        co = str(correct_answer).strip().upper()
                        if sa == co:
                            match = True
                        elif len(co) == 1 and 'A' <= co <= 'Z' and q.get("options") and isinstance(q["options"], list):
                            idx = ord(co) - ord('A')
                            if 0 <= idx < len(q["options"]):
                                opt_val = str(q["options"][idx]).strip().upper()
                                if sa == opt_val:
                                    match = True
                        elif len(sa) == 1 and 'A' <= sa <= 'Z' and q.get("options") and isinstance(q["options"], list):
                            idx = ord(sa) - ord('A')
                            if 0 <= idx < len(q["options"]):
                                opt_val = str(q["options"][idx]).strip().upper()
                                if co == opt_val:
                                    match = True
                        if match:
                            correct += 1
                    elif q_type == "multi_select" or q_type == "multi_correct":
                        def normalize_to_text(val_str):
                            vals = [v.strip().upper() for v in str(val_str).split(",") if v.strip()]
                            normalized = set()
                            for v in vals:
                                if len(v) == 1 and 'A' <= v <= 'Z' and q.get("options") and isinstance(q["options"], list):
                                    idx = ord(v) - ord('A')
                                    if 0 <= idx < len(q["options"]):
                                        normalized.add(str(q["options"][idx]).strip().upper())
                                        continue
                                normalized.add(v)
                            return normalized
                        norm_student = normalize_to_text(student_ans)
                        norm_correct = normalize_to_text(correct_answer)
                        if norm_student == norm_correct and len(norm_correct) > 0:
                            correct += 1
                    else:
                        if str(student_ans).strip().lower() == str(correct_answer).strip().lower():
                            correct += 1
        accuracy = round(correct / attempts * 100, 1) if attempts > 0 else 0
        question_stats.append({
            "id": q_id,
            "text": q["question_text"][:80] + "..." if len(q.get("question_text", "")) > 80 else q.get("question_text", ""),
            "type": q_type,
            "marks": q.get("marks", 0),
            "accuracy": accuracy,
            "attempts": attempts,
            "correct": correct,
        })

    # Top 5 and bottom 5 performers
    sorted_graded = sorted(graded, key=lambda s: float(s.get("score") or 0), reverse=True)
    def fmt_student(s):
        prof = s.get("profiles") or {}
        return {
            "name": prof.get("full_name", "Student"),
            "roll": prof.get("roll_number", ""),
            "score": float(s.get("score") or 0),
            "percentage": round(float(s.get("score") or 0) / total_marks * 100, 1),
            "grade": s.get("grade_letter", ""),
            "is_pass": s.get("is_pass", False),
        }
    top_performers = [fmt_student(s) for s in sorted_graded[:5]]
    bottom_performers = [fmt_student(s) for s in sorted_graded[-5:] if sorted_graded] if len(sorted_graded) > 5 else []

    return {
        "success": True,
        "data": {
            "exam": exam_data,
            "total_marks": total_marks,
            "passing_marks": passing_marks,
            "results_published": exam_data.get("results_published_at") is not None,
            "stats": {
                "total_submissions": len(all_submissions),
                "submitted": len(submitted),
                "graded": len(graded),
                "avg_score": avg_score,
                "highest_score": highest_score,
                "lowest_score": lowest_score,
                "pass_count": pass_count,
                "pass_rate": pass_rate,
            },
            "score_distribution": bins,
            "grade_distribution": grade_dist,
            "question_stats": question_stats,
            "top_performers": top_performers,
            "bottom_performers": bottom_performers,
        }
    }


@router.post("/exams/{exam_id}/results/publish")
async def teacher_publish_exam_results(exam_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """
    Publish exam results:
    1. Compute and store class_rank for all graded submissions
    2. Update exam with results_published_at timestamp
    3. Update exam status to 'completed'
    """
    sb = get_supabase()

    # Fetch all graded submissions ordered by score desc
    subs_res = await sb.table("exam_submissions").select(
        "id, student_id, score, grade_letter, is_pass"
    ).eq("exam_id", exam_id).in_("status", ["graded", "submitted"]).aexecute()
    submissions = subs_res.data or []

    # Get exam info for grade calculations
    exam_res = await sb.table("exams").select("total_marks, passing_marks").eq("id", exam_id).maybe_single().aexecute()
    exam_data = exam_res.data or {}
    total_marks = float(exam_data.get("total_marks") or 100)
    passing_marks = float(exam_data.get("passing_marks") or (total_marks * 0.4))

    # Sort by score descending and assign class ranks
    graded = sorted(
        [s for s in submissions if s.get("score") is not None],
        key=lambda s: float(s["score"]),
        reverse=True
    )

    for rank, sub in enumerate(graded, start=1):
        score = float(sub["score"])
        pct = (score / total_marks) * 100
        is_pass = score >= passing_marks
        if pct >= 90: grade_letter = "A+"
        elif pct >= 80: grade_letter = "A"
        elif pct >= 70: grade_letter = "B+"
        elif pct >= 60: grade_letter = "B"
        elif pct >= 50: grade_letter = "C"
        elif pct >= 40: grade_letter = "D"
        else: grade_letter = "F"

        await sb.table("exam_submissions").update({
            "class_rank": rank,
            "is_pass": is_pass,
            "grade_letter": grade_letter,
            "status": "graded",
        }).eq("id", sub["id"]).aexecute()

    # Mark exam as results published and status completed
    now_ts = datetime.utcnow().isoformat()
    await sb.table("exams").update({
        "results_published_at": now_ts,
        "status": "completed",
    }).eq("id", exam_id).aexecute()

    return {
        "success": True,
        "message": f"Results published for {len(graded)} students",
        "published_at": now_ts,
    }


@router.get("/exams/{exam_id}/sessions")
async def teacher_get_exam_sessions(exam_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    res = await sb.table("exam_sessions").select("*, profiles!student_id(full_name, roll_number)").eq("exam_id", exam_id).aexecute()
    return {"success": True, "school_id": school_id, "data": {"sessions": res.data}}


@router.post("/exams/{exam_id}/sessions/{session_id}/action")
async def teacher_proctor_action(
    exam_id: str,
    session_id: str,
    request: dict,
    user=Depends(require_teacher),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    action = request.get("action") # warn, pause, resume, extend, submit, suspend
    extra_minutes = request.get("extra_minutes", 0)
    message = request.get("message", "")
    
    sess_res = await sb.table("exam_sessions").select("*").eq("id", session_id).eq("exam_id", exam_id).maybe_single().aexecute()
    sess = sess_res.data
    if not sess:
        raise HTTPException(status_code=404, detail="Proctor session not found")
        
    update_data = {}
    current_logs = sess.get("proctor_logs") or []
    if not isinstance(current_logs, list):
        current_logs = []
    
    now_time = datetime.now(timezone.utc).strftime("%H:%M:%S")

    if action == "warn":
        current_warnings = sess.get("warnings_count", 0) or 0
        update_data["warnings_count"] = current_warnings + 1
        msg = message or f"Warning issued by proctor (Count: {current_warnings + 1})"
        update_data["teacher_message"] = msg
        current_logs.append({"time": now_time, "event": f"Teacher Warning: {msg}", "severity": "warning"})
    elif action == "pause":
        update_data["is_paused"] = True
        msg = message or "Your exam has been paused by the proctor."
        update_data["teacher_message"] = msg
        current_logs.append({
            "time": now_time,
            "event": "Exam session paused by proctor",
            "severity": "info",
            "paused_at_iso": datetime.now(timezone.utc).isoformat()
        })
    elif action == "resume":
        update_data["is_paused"] = False
        update_data["teacher_message"] = None
        
        # Shift started_at forward by pause duration
        paused_at_iso = None
        for log in reversed(current_logs):
            if log.get("event") == "Exam session paused by proctor" and "paused_at_iso" in log:
                paused_at_iso = log["paused_at_iso"]
                break
        if paused_at_iso:
            try:
                from dateutil.parser import parse
                paused_at = parse(paused_at_iso)
                pause_duration = datetime.now(timezone.utc) - paused_at
                started_at_str = sess.get("started_at")
                if started_at_str:
                    started_at = parse(started_at_str)
                    new_started_at = started_at + pause_duration
                    update_data["started_at"] = new_started_at.isoformat()
            except Exception:
                pass
                
        current_logs.append({
            "time": now_time,
            "event": "Exam session resumed by proctor",
            "severity": "info",
            "resumed_at_iso": datetime.now(timezone.utc).isoformat()
        })
    elif action == "extend":
        current_extra = sess.get("extra_minutes", 0) or 0
        update_data["extra_minutes"] = current_extra + extra_minutes
        current_logs.append({"time": now_time, "event": f"Extra {extra_minutes} minutes added by proctor", "severity": "info"})
    elif action == "submit":
        update_data["status"] = "completed"
        update_data["ended_at"] = datetime.now(timezone.utc).isoformat()
        current_logs.append({"time": now_time, "event": "Exam force-submitted by proctor", "severity": "info"})
    elif action == "suspend":
        update_data["status"] = "suspended"
        update_data["ended_at"] = datetime.now(timezone.utc).isoformat()
        current_logs.append({"time": now_time, "event": "Student suspended from exam by proctor", "severity": "error"})
    elif action == "force_camera":
        camera_active = request.get("camera_active", True)
        update_data["camera_active"] = camera_active
        current_logs.append({
            "time": now_time,
            "event": f"Proctor forced camera {'ON' if camera_active else 'OFF'}",
            "severity": "info"
        })
    elif action == "force_mic":
        mic_active = request.get("mic_active", True)
        update_data["mic_active"] = mic_active
        current_logs.append({
            "time": now_time,
            "event": f"Proctor forced microphone {'ON' if mic_active else 'OFF'}",
            "severity": "info"
        })
    elif action == "reopen":
        update_data["status"] = "active"
        update_data["warnings_count"] = 0
        update_data["ended_at"] = None
        update_data["teacher_message"] = None
        
        # Adjust started_at to preserve the student's active exam duration spent so far
        started_at_str = sess.get("started_at")
        ended_at_str = sess.get("ended_at")
        if started_at_str and ended_at_str:
            try:
                from dateutil.parser import parse
                started_at = parse(started_at_str)
                ended_at = parse(ended_at_str)
                duration_spent = ended_at - started_at
                new_started_at = datetime.now(timezone.utc) - duration_spent
                update_data["started_at"] = new_started_at.isoformat()
            except Exception:
                update_data["started_at"] = datetime.now(timezone.utc).isoformat()
        else:
            update_data["started_at"] = datetime.now(timezone.utc).isoformat()

        current_logs.append({"time": now_time, "event": "Exam session reopened by proctor. Warning count reset.", "severity": "info"})
        # Update submission status to active so student can rejoin and resume saving answers
        await sb.table("exam_submissions").update({"status": "active"}).eq("exam_id", exam_id).eq("student_id", sess["student_id"]).aexecute()
    else:
        raise HTTPException(status_code=400, detail=f"Unsupported action: {action}")
        
    update_data["proctor_logs"] = current_logs
    
    res = await sb.table("exam_sessions").update(update_data).eq("id", session_id).aexecute()
    return {"success": True, "data": res.data[0] if res.data else {}}


@router.put("/exams/{exam_id}")
async def teacher_update_exam(
    exam_id: str,
    request: dict,
    user=Depends(require_teacher),
    school_id=Depends(require_school_id),
):
    print("Incoming update_exam payload:", request)
    sb = get_supabase()
    # verify teacher owns this exam or it is in the same school
    check_exam = await sb.table("exams").select("*").eq("id", exam_id).eq("school_id", school_id).maybe_single().aexecute()
    if not check_exam.data:
        raise HTTPException(status_code=404, detail="Exam not found")
    if check_exam.data.get("teacher_id") != user["id"]:
        raise HTTPException(status_code=403, detail="You do not have permission to modify this exam")

    allowed = {
        "title", "exam_type", "exam_category", "exam_date", "start_time", "end_time", 
        "duration_minutes", "total_marks", "venue", "target_classes", "status", 
        "instructions", "syllabus", "subject_id",
        "negative_marking", "shuffle_questions", "shuffle_options", "allow_calculator", 
        "camera_required", "mic_required", "auto_submit_on_timer",
        "passcode", "target_students", "scope", "release_time"
    }
    update_data = {k: v for k, v in request.items() if k in allowed}

    status_val = update_data.get("status")
    if status_val in ("published", "scheduled", "ready"):
        q_res = await sb.table("exam_questions").select("id").eq("exam_id", exam_id).aexecute()
        if not q_res.data or len(q_res.data) == 0:
            raise HTTPException(
                status_code=400,
                detail="Cannot schedule or publish an exam with 0 questions. Please add questions using the Paper Builder first."
            )
    
    # translate class to target_classes
    class_val = request.get("class") or request.get("class_id")
    if class_val and not update_data.get("target_classes"):
        update_data["target_classes"] = [class_val]

    # translate subject name to subject_id
    subject_name = request.get("subject")
    if subject_name and not update_data.get("subject_id"):
        target_classes = update_data.get("target_classes") or check_exam.data.get("target_classes")
        class_val = target_classes[0] if (target_classes and len(target_classes) > 0) else None
        
        subj_query = sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name)
        if class_val:
            subj_query = subj_query.eq("class", class_val)
        subj_res = await subj_query.limit(1).maybe_single().aexecute()
        if subj_res.data:
            update_data["subject_id"] = subj_res.data["id"]
        else:
            subj_res_fallback = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name).limit(1).maybe_single().aexecute()
            if subj_res_fallback.data:
                update_data["subject_id"] = subj_res_fallback.data["id"]

    # Verify teacher is assigned to these target classes on update
    if "target_classes" in update_data and update_data["target_classes"]:
        tt_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute()
        assigned_classes = {row["class"].strip().upper() for row in (tt_res.data or []) if row.get("class")}
        for tc in update_data["target_classes"]:
            if tc.strip().upper() not in assigned_classes:
                raise HTTPException(
                    status_code=403,
                    detail=f"You are not authorized to assign exams to class '{tc}'. You are only assigned to: {', '.join(assigned_classes)}"
                )
        
    # extract duration digits from string if it comes as "90 mins"
    dur_val = request.get("duration_minutes") or request.get("duration")
    if dur_val is not None:
        if isinstance(dur_val, str):
            digits = "".join([c for c in dur_val if c.isdigit()])
            duration_minutes = int(digits) if digits else 90
        else:
            duration_minutes = int(dur_val)
        update_data["duration_minutes"] = duration_minutes
        
    # ensure start_time is translated or formatted
    from datetime import timezone, timedelta
    def parse_to_utc_dt(s: str) -> datetime:
        if not s:
            return None
        if s.endswith("Z"):
            s = s[:-1] + "+00:00"
        try:
            dt = datetime.fromisoformat(s)
        except ValueError:
            from dateutil.parser import parse
            dt = parse(s)
        if dt.tzinfo is None:
            # Naive datetime. Assume Indian Standard Time (+5:30)
            dt = dt.replace(tzinfo=timezone(timedelta(hours=5, minutes=30)))
        return dt.astimezone(timezone.utc)

    start_time_raw = request.get("start_time")
    if not start_time_raw and not check_exam.data.get("start_time"):
        exam_date = request.get("exam_date") or check_exam.data.get("exam_date")
        if exam_date:
            start_time_raw = f"{exam_date}T09:00:00"
            
    if start_time_raw:
        try:
            start_dt = parse_to_utc_dt(start_time_raw)
            update_data["start_time"] = start_dt.isoformat()
            
            # Recalculate end_time if start_time or duration_minutes is changed
            dur_val = update_data.get("duration_minutes") or check_exam.data.get("duration_minutes") or 90
            update_data["end_time"] = (start_dt + timedelta(minutes=dur_val)).isoformat()
        except Exception as e:
            print("Error parsing start_time on update in backend:", e)
    elif "duration_minutes" in update_data:
        existing_start = check_exam.data.get("start_time")
        if existing_start:
            try:
                start_dt = parse_to_utc_dt(existing_start)
                dur_val = update_data["duration_minutes"]
                update_data["end_time"] = (start_dt + timedelta(minutes=dur_val)).isoformat()
            except Exception as e:
                print("Error recalculating end_time on duration update:", e)

    # Normalize release_time to UTC if provided
    release_time_raw = update_data.get("release_time")
    if release_time_raw:
        try:
            release_dt = parse_to_utc_dt(release_time_raw)
            update_data["release_time"] = release_dt.isoformat()
        except Exception as e:
            print("Error parsing release_time in backend:", e)

    # Validate release_time is before start_time
    final_start_time = update_data.get("start_time") or check_exam.data.get("start_time")
    final_release_time = update_data.get("release_time") or check_exam.data.get("release_time")
    if final_release_time and final_start_time:
        try:
            start_dt = parse_to_utc_dt(final_start_time)
            release_dt = parse_to_utc_dt(final_release_time)
            if release_dt >= start_dt:
                raise HTTPException(
                    status_code=400,
                    detail="Publish (release) date/time must be earlier than the exam start date/time."
                )
        except HTTPException:
            raise
        except Exception as e:
            print("Error validating release_time:", e)
        
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
        
    res = await sb.table("exams").update(update_data).eq("id", exam_id).aexecute()
    return {"success": True, "message": "Exam updated", "data": res.data[0] if res.data else {}}


@router.delete("/exams/{exam_id}")
async def teacher_delete_exam(
    exam_id: str,
    user=Depends(require_teacher),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    # verify teacher owns this exam
    check_exam = await sb.table("exams").select("*").eq("id", exam_id).eq("school_id", school_id).maybe_single().aexecute()
    if not check_exam.data:
        raise HTTPException(status_code=404, detail="Exam not found")
    if check_exam.data.get("teacher_id") != user["id"]:
        raise HTTPException(status_code=403, detail="You do not have permission to delete this exam")
        
    # delete associated sessions, submissions, questions to prevent foreign key errors
    await sb.table("exam_sessions").delete().eq("exam_id", exam_id).aexecute()
    await sb.table("exam_submissions").delete().eq("exam_id", exam_id).aexecute()
    await sb.table("exam_questions").delete().eq("exam_id", exam_id).aexecute()
    
    await sb.table("exams").delete().eq("id", exam_id).aexecute()
    return {"success": True, "message": "Exam deleted"}


@router.get("/question-bank")
async def teacher_get_question_bank(
    subject: str = None, 
    difficulty: str = None, 
    user=Depends(require_teacher), 
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    query = sb.table("question_bank").select("*, subjects(name)").eq("school_id", school_id)
    if subject and subject != "All":
        subj_res = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject).aexecute()
        if subj_res.data:
            subj_ids = [s["id"] for s in subj_res.data]
            query = query.in_("subject_id", subj_ids)
        else:
            query = query.eq("subject_id", "00000000-0000-0000-0000-000000000000")
    if difficulty and difficulty != "All":
        query = query.eq("difficulty", difficulty)
    
    res = await query.order("created_at", ascending=False).aexecute()
    return {"success": True, "school_id": school_id, "data": {"questions": res.data or []}}


@router.post("/question-bank")
async def teacher_add_question_bank(
    request: dict, 
    user=Depends(require_teacher), 
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    subject_name = request.get("subject")
    subject_id = request.get("subject_id")
    class_name = request.get("class") or request.get("class_id")
    if not subject_id and subject_name:
        subj_query = sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name)
        if class_name:
            subj_query = subj_query.eq("class", class_name)
        subj_res = await subj_query.limit(1).maybe_single().aexecute()
        if subj_res.data:
            subject_id = subj_res.data["id"]
        else:
            # Fallback to match by name and current teacher
            subj_res_t = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name).eq("teacher_id", user["id"]).limit(1).maybe_single().aexecute()
            if subj_res_t.data:
                subject_id = subj_res_t.data["id"]
            else:
                subj_res_fallback = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name).limit(1).maybe_single().aexecute()
                if subj_res_fallback.data:
                    subject_id = subj_res_fallback.data["id"]
            
    if not subject_id:
        subj_res = await sb.table("subjects").select("id").eq("school_id", school_id).limit(1).maybe_single().aexecute()
        if subj_res.data:
            subject_id = subj_res.data["id"]
            
    new_q = {
        "school_id": school_id,
        "teacher_id": user["id"],
        "subject_id": subject_id,
        "chapter": request.get("chapter", ""),
        "question_text": request.get("question_text"),
        "question_type": request.get("question_type", "mcq"),
        "options": request.get("options"),
        "correct_answer": request.get("correct_answer"),
        "difficulty": request.get("difficulty", "Medium"),
        "marks": int(request.get("marks", 1) or 1)
    }
    res = await sb.table("question_bank").insert(new_q).aexecute()
    return {"success": True, "school_id": school_id, "data": res.data[0]}


@router.put("/question-bank/{question_id}")
async def teacher_update_question_bank(
    question_id: str, 
    request: dict, 
    user=Depends(require_teacher), 
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    check_q = await sb.table("question_bank").select("*").eq("id", question_id).eq("school_id", school_id).maybe_single().aexecute()
    if not check_q.data:
        raise HTTPException(status_code=404, detail="Question not found")
        
    allowed = {"question_text", "question_type", "options", "correct_answer", "difficulty", "marks", "chapter"}
    updates = {k: v for k, v in request.items() if k in allowed}
    
    subject_name = request.get("subject")
    class_name = request.get("class") or request.get("class_id")
    if subject_name:
        subj_query = sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name)
        if class_name:
            subj_query = subj_query.eq("class", class_name)
        subj_res = await subj_query.limit(1).maybe_single().aexecute()
        if subj_res.data:
            updates["subject_id"] = subj_res.data["id"]
        else:
            subj_res_t = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name).eq("teacher_id", user["id"]).limit(1).maybe_single().aexecute()
            if subj_res_t.data:
                updates["subject_id"] = subj_res_t.data["id"]
            else:
                subj_res_fallback = await sb.table("subjects").select("id").eq("school_id", school_id).eq("name", subject_name).limit(1).maybe_single().aexecute()
                if subj_res_fallback.data:
                    updates["subject_id"] = subj_res_fallback.data["id"]
            
    res = await sb.table("question_bank").update(updates).eq("id", question_id).aexecute()
    return {"success": True, "school_id": school_id, "data": res.data[0]}


@router.delete("/question-bank/{question_id}")
async def teacher_delete_question_bank(
    question_id: str, 
    user=Depends(require_teacher), 
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    await sb.table("question_bank").delete().eq("id", question_id).eq("school_id", school_id).aexecute()
    return {"success": True, "school_id": school_id, "message": "Question deleted"}


@router.get("/question-bank/export-template")
async def export_question_template(type: str = "mcq", subject: str = None):
    subj_name = subject.strip() if (subject and subject.strip()) else None
    active_sub = subj_name or "Physics"
    
    import csv
    import io
    from fastapi.responses import StreamingResponse
    
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["subject", "question_text", "question_type", "options", "correct_answer", "difficulty", "marks", "chapter"])
    
    t = type.lower()
    if t == "all":
        writer.writerow([
            active_sub,
            "What is the SI unit of force?",
            QuestionType.single_select.value,
            "Newton|Joule|Pascal|Watt",
            "A",
            "Easy",
            "1",
            "Mechanics"
        ])
        writer.writerow([
            active_sub,
            "Which of the following are Newton's laws of motion?",
            QuestionType.multi_select.value,
            "Law of Inertia|Law of Acceleration|Law of Action-Reaction|Law of Gravity",
            "A,B,C",
            "Medium",
            "2",
            "Mechanics"
        ])
        writer.writerow([
            active_sub,
            "Explain the function of mitochondria.",
            QuestionType.subjective.value,
            "",
            "Mitochondria generate chemical energy in the form of ATP to power cell activities.",
            "Medium",
            "3",
            "Cell Biology"
        ])
    elif t in ("single_select", "mcq", "true_false"):
        writer.writerow([
            active_sub,
            "What is the SI unit of force?",
            QuestionType.single_select.value,
            "Newton|Joule|Pascal|Watt",
            "A",
            "Easy",
            "1",
            "Mechanics"
        ])
    elif t in ("multi_select", "multi_correct"):
        writer.writerow([
            active_sub,
            "Which of the following are Newton's laws of motion?",
            QuestionType.multi_select.value,
            "Law of Inertia|Law of Acceleration|Law of Action-Reaction|Law of Gravity",
            "A,B,C",
            "Medium",
            "2",
            "Mechanics"
        ])
    elif t in ("subjective", "short_answer", "long_answer"):
        writer.writerow([
            active_sub,
            "Explain the function of mitochondria.",
            QuestionType.subjective.value,
            "",
            "Mitochondria generate chemical energy in the form of ATP to power cell activities.",
            "Medium",
            "3",
            "Cell Biology"
        ])
    else:
        writer.writerow([
            active_sub,
            "What is the SI unit of force?",
            QuestionType.single_select.value,
            "Newton|Joule|Pascal|Watt",
            "A",
            "Easy",
            "1",
            "Mechanics"
        ])
        
    content = output.getvalue()
    return StreamingResponse(
        io.BytesIO(content.encode("utf-8")), 
        media_type="text/csv", 
        headers={"Content-Disposition": f"attachment; filename=template_{type}.csv"}
    )


@router.post("/question-bank/bulk-upload")
async def bulk_upload_questions(
    request: dict,
    user=Depends(require_teacher),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    csv_content = request.get("csv_content", "")
    subject_name = request.get("subject", "Physics")
    question_type = request.get("question_type", "mcq")
    
    # Retrieve all subjects for the school to resolve names dynamically
    subj_res_all = await sb.table("subjects").select("id, name").eq("school_id", school_id).aexecute()
    subjects_map = {s["name"].lower().strip(): s["id"] for s in subj_res_all.data} if subj_res_all.data else {}
    
    # Get a fallback subject ID matching subject_name from payload or fallback to first subject
    default_subject_id = None
    if subjects_map:
        default_subject_id = subjects_map.get(subject_name.lower().strip())
        if not default_subject_id:
            default_subject_id = list(subjects_map.values())[0]
            
    if not default_subject_id:
        raise HTTPException(status_code=400, detail="No subjects configured in the database. Please create a subject first.")

    import csv
    import io
    
    # Strip UTF-8 BOM if present
    cleaned_csv = csv_content.strip().lstrip("\ufeff")
    f = io.StringIO(cleaned_csv)
    reader = csv.DictReader(f)
    inserted = []
    
    def map_question_type(val: str) -> str:
        v = val.lower().strip()
        if v in ("single_select", "mcq", "true_false"):
            return "single_select"
        elif v in ("multi_select", "multi_correct"):
            return "multi_select"
        elif v in ("subjective", "short_answer", "long_answer"):
            return "subjective"
        else:
            raise HTTPException(status_code=400, detail=f"Invalid or unsupported question type: '{val}'")

    for row in reader:
        # Normalize keys: lowercase, stripped of spaces, check for None key/values
        cleaned_row = {
            (k.lower().strip() if k is not None else ""): (v.strip() if v is not None else "")
            for k, v in row.items()
        }
        
        q_text = cleaned_row.get("question_text")
        if not q_text:
            continue
        
        # Resolve subject name per row if available, else use default_subject_id
        row_subject_name = cleaned_row.get("subject") or ""
        row_subject_id = default_subject_id
        if row_subject_name:
            matched_id = subjects_map.get(row_subject_name.lower().strip())
            if matched_id:
                row_subject_id = matched_id
        
        row_q_type = cleaned_row.get("question_type") or question_type
        mapped_type = map_question_type(row_q_type)
        
        options = None
        correct = ""
        
        if mapped_type in ("single_select", "multi_select"):
            opts_str = cleaned_row.get("options", "")
            if opts_str:
                options = [o.strip() for o in opts_str.split("|") if o.strip()]
            else:
                options = []
            if len(options) < 2:
                raise HTTPException(status_code=400, detail=f"Select question must have at least 2 options. Found: '{opts_str}'")
                
            correct_ans = cleaned_row.get("correct_answer") or cleaned_row.get("correct_answers") or cleaned_row.get("model_answer") or ""
            correct_ans = correct_ans.strip()
            
            if mapped_type == "single_select":
                if len(correct_ans) != 1 or not correct_ans.isalpha():
                    raise HTTPException(status_code=400, detail=f"Correct answer for single_select must be a single letter (A-Z). Found: '{correct_ans}'")
                letter = correct_ans.upper()
                idx = ord(letter) - ord('A')
                if idx < 0 or idx >= len(options):
                    raise HTTPException(status_code=400, detail=f"Correct answer letter '{letter}' is out of range for the {len(options)} options provided.")
                correct = letter
            else:  # multi_select
                letters = [l.strip().upper() for l in correct_ans.split(",") if l.strip()]
                if not letters:
                    raise HTTPException(status_code=400, detail=f"Correct answer for multi_select must contain comma-separated letters. Found: '{correct_ans}'")
                for letter in letters:
                    if len(letter) != 1 or not letter.isalpha():
                        raise HTTPException(status_code=400, detail=f"Invalid letter in correct_answer for multi_select: '{letter}'")
                    idx = ord(letter) - ord('A')
                    if idx < 0 or idx >= len(options):
                        raise HTTPException(status_code=400, detail=f"Correct answer letter '{letter}' is out of range for the {len(options)} options provided.")
                sorted_letters = sorted(list(set(letters)))
                correct = ",".join(sorted_letters)
        else:  # subjective
            options = None
            correct = cleaned_row.get("correct_answer") or cleaned_row.get("model_answer") or ""
                
        diff = cleaned_row.get("difficulty", "Medium")
        
        try:
            marks = int(cleaned_row.get("marks", "1") or "1")
        except ValueError:
            marks = 1
            
        chap = cleaned_row.get("chapter", "")
        
        new_q = {
            "school_id": school_id,
            "teacher_id": user["id"],
            "subject_id": row_subject_id,
            "question_text": q_text,
            "question_type": mapped_type,
            "options": options,
            "correct_answer": correct,
            "difficulty": diff,
            "marks": marks,
            "chapter": chap
        }
        res = await sb.table("question_bank").insert(new_q).aexecute()
        if res.data:
            inserted.append(res.data[0])
            
    return {"success": True, "count": len(inserted), "questions": inserted}


@router.get("/courses/{course_id}/details")
async def teacher_course_details(course_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # Fetch course first
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
        
    # Map topics to chapters
    for c in chapters:
        c["topics"] = [t for t in topics if t["chapter_id"] == c["id"]]
        
    return {
        "success": True,
        "data": {
            "course": course_res.data,
            "chapters": chapters
        }
    }


@router.post("/courses/{course_id}/chapters")
async def teacher_create_chapter(course_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    title = request.get("title")
    if not title:
        raise HTTPException(status_code=400, detail="Title is required")
        
    chapter_order = request.get("chapter_order")
    if chapter_order is None:
        chapters = (await sb.table("course_chapters").select("chapter_order").eq("course_id", course_id).aexecute()).data or []
        chapter_order = max([c.get("chapter_order", 0) for c in chapters] + [0]) + 1
        
    new_chapter = {
        "school_id": school_id,
        "course_id": course_id,
        "title": title,
        "description": request.get("description", ""),
        "chapter_order": chapter_order
    }
    
    res = await sb.table("course_chapters").insert(new_chapter).aexecute()
    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to create chapter")
    return {"success": True, "data": res.data[0]}


@router.put("/courses/chapters/{chapter_id}")
async def teacher_update_chapter(chapter_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    allowed = {"title", "description", "chapter_order"}
    updates = {k: v for k, v in request.items() if k in allowed}
    if not updates:
        raise HTTPException(status_code=400, detail="No updates provided")
        
    res = await sb.table("course_chapters").update(updates).eq("id", chapter_id).eq("school_id", school_id).aexecute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Chapter not found")
    return {"success": True, "data": res.data[0]}


@router.delete("/courses/chapters/{chapter_id}")
async def teacher_delete_chapter(chapter_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    res = await sb.table("course_chapters").delete().eq("id", chapter_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Chapter deleted"}


@router.post("/courses/chapters/{chapter_id}/topics")
async def teacher_create_topic(chapter_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    title = request.get("title")
    if not title:
        raise HTTPException(status_code=400, detail="Title is required")
        
    topic_order = request.get("topic_order")
    if topic_order is None:
        topics = (await sb.table("course_topics").select("topic_order").eq("chapter_id", chapter_id).aexecute()).data or []
        topic_order = max([t.get("topic_order", 0) for t in topics] + [0]) + 1
        
    new_topic = {
        "school_id": school_id,
        "chapter_id": chapter_id,
        "title": title,
        "content": request.get("content", ""),
        "topic_order": topic_order
    }
    
    res = await sb.table("course_topics").insert(new_topic).aexecute()
    if not res.data:
        raise HTTPException(status_code=500, detail="Failed to create topic")
    return {"success": True, "data": res.data[0]}


@router.put("/courses/topics/{topic_id}")
async def teacher_update_topic(topic_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    allowed = {"title", "content", "topic_order"}
    updates = {k: v for k, v in request.items() if k in allowed}
    if not updates:
        raise HTTPException(status_code=400, detail="No updates provided")
        
    res = await sb.table("course_topics").update(updates).eq("id", topic_id).eq("school_id", school_id).aexecute()
    if not res.data:
        raise HTTPException(status_code=404, detail="Topic not found")
    return {"success": True, "data": res.data[0]}


@router.delete("/courses/topics/{topic_id}")
async def teacher_delete_topic(topic_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    res = await sb.table("course_topics").delete().eq("id", topic_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Topic deleted"}


@router.get("/classes/{class_name}/courses")
async def teacher_class_courses(class_name: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    # 1. Fetch all subjects for this class
    subjects_res = await sb.table("subjects").select("*").eq("school_id", school_id).eq("class", class_name).aexecute()
    db_subjects = subjects_res.data or []
    
    if not db_subjects:
        return {"success": True, "data": []}
        
    # Deduplicate subjects by name
    unique_subjects = {}
    for s in db_subjects:
        name_lower = s["name"].strip().lower()
        if name_lower not in unique_subjects:
            unique_subjects[name_lower] = s
            
    subjects = list(unique_subjects.values())
    subject_ids = [s["id"] for s in subjects]
    
    # 2. Fetch existing courses for these subjects
    courses_res = await sb.table("courses").select("*").eq("school_id", school_id).in_("subject_id", subject_ids).aexecute()
    courses = courses_res.data or []
    
    # Map subject_id to course
    course_by_subject = {c["subject_id"]: c for c in courses}
    
    # 3. For any subject that doesn't have a course, create one dynamically!
    result_courses = []
    seen_subject_names = set()
    for s in subjects:
        subj_name_lower = s["name"].strip().lower()
        if subj_name_lower in seen_subject_names:
            continue
        seen_subject_names.add(subj_name_lower)
        
        course = course_by_subject.get(s["id"])
        if not course:
            # Create a course row dynamically!
            new_c = {
                "school_id": school_id,
                "subject_id": s["id"],
                "teacher_id": user["id"],
                "title": f"{s['name']} - {class_name}",
                "description": f"Course material for {s['name']} class {class_name}",
                "status": "active"
            }
            ins_res = await sb.table("courses").insert(new_c).aexecute()
            if ins_res.data:
                course = ins_res.data[0]
                
        if course:
            course["subject"] = s
            result_courses.append(course)
            
    return {"success": True, "data": result_courses}


# ===========================================================
# Teacher Achievements & Tasks CRUD + Progress Tracking
# ===========================================================

@router.get("/achievements/tasks")
async def teacher_get_tasks(user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """List all achievement/task templates."""
    sb = get_supabase()
    res = await sb.table("achievements").select("*").eq("school_id", school_id).order("created_at", ascending=False).aexecute()
    return {"success": True, "school_id": school_id, "data": {"tasks": res.data or []}}


@router.post("/achievements/tasks")
async def teacher_create_task(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """Create a new task template."""
    sb = get_supabase()
    name = request.get("name")
    if not name:
        raise HTTPException(status_code=400, detail="name is required")
        
    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "name": name,
        "description": request.get("description", ""),
        "icon": request.get("icon", "🏆"),
        "xp_reward": int(request.get("xp_reward", 100)),
        "rarity": request.get("rarity", "common"),
        "criteria": request.get("criteria", ""),
        "target_class": request.get("target_class"),
        "created_at": datetime.utcnow().isoformat()
    }
    result = await sb.table("achievements").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/achievements/tasks/{task_id}")
async def teacher_update_task(task_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """Edit a task template."""
    sb = get_supabase()
    allowed = {"name", "description", "icon", "xp_reward", "rarity", "criteria", "target_class"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if "xp_reward" in update_data:
        update_data["xp_reward"] = int(update_data["xp_reward"])
        
    await sb.table("achievements").update(update_data).eq("id", task_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Task updated successfully"}


@router.delete("/achievements/tasks/{task_id}")
async def teacher_delete_task(task_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """Delete a task template."""
    sb = get_supabase()
    await sb.table("achievements").delete().eq("id", task_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Task deleted successfully"}


@router.get("/achievements/student-progress")
async def teacher_get_student_progress(class_name: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """Returns student list with their total XP, streaks, and list of earned achievements."""
    sb = get_supabase()
    
    # 1. Fetch students in target class
    students_res = await sb.table("profiles").select("id, full_name, roll_number, class, xp_points, learning_streak").eq("school_id", school_id).eq("class", class_name).eq("role", "student").order("xp_points", ascending=False).aexecute()
    students = students_res.data or []
    
    # 2. Fetch all student achievements earned for this school
    sa_res = await sb.table("student_achievements").select("student_id, achievement_id").eq("school_id", school_id).aexecute()
    sa_data = sa_res.data or []
    
    # Group achievements by student
    student_badges = {}
    for row in sa_data:
        s_id = row["student_id"]
        ach_id = row["achievement_id"]
        if s_id not in student_badges:
            student_badges[s_id] = []
        student_badges[s_id].append(ach_id)
        
    progress_list = []
    for s in students:
        s_id = s["id"]
        progress_list.append({
            "id": s_id,
            "name": s["full_name"],
            "roll_number": s["roll_number"],
            "class": s["class"],
            "xp_points": s.get("xp_points") or 0,
            "learning_streak": s.get("learning_streak") or 0,
            "earned_badges": student_badges.get(s_id, [])
        })
        
    return {"success": True, "school_id": school_id, "data": {"students": progress_list}}


@router.post("/achievements/unlock")
async def teacher_unlock_task(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """Manually unlock a task (achievement) for a student."""
    sb = get_supabase()
    student_id = request.get("student_id")
    task_id = request.get("task_id")
    if not student_id or not task_id:
        raise HTTPException(status_code=400, detail="student_id and task_id are required")
        
    # 1. Check if achievement exists
    ach_res = await sb.table("achievements").select("*").eq("id", task_id).eq("school_id", school_id).maybe_single().aexecute()
    achievement = ach_res.data
    if not achievement:
        raise HTTPException(status_code=404, detail="Task template not found")
        
    # 2. Check if already earned
    sa_check = await sb.table("student_achievements").select("id").eq("school_id", school_id).eq("student_id", student_id).eq("achievement_id", task_id).maybe_single().aexecute()
    if sa_check.data:
        return {"success": True, "message": "Task already completed by student"}
        
    # 3. Award the achievement
    await sb.table("student_achievements").insert({
        "school_id": school_id,
        "student_id": student_id,
        "achievement_id": task_id,
        "progress": 100.0
    }).aexecute()
    
    # 4. Credit XP
    from app.services.supabase_client import award_xp
    await award_xp(sb, school_id, student_id, achievement["xp_reward"], "teacher_task", task_id, f"Completed Task: {achievement['name']} (unlocked by instructor)")
    
    return {"success": True, "message": f"Task '{achievement['name']}' unlocked and {achievement['xp_reward']} XP credited."}


@router.post("/achievements/penalty")
async def teacher_apply_penalty(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    """Apply an XP penalty deduction to a student."""
    sb = get_supabase()
    student_id = request.get("student_id")
    amount = request.get("amount") # should be positive, we will negate it
    reason = request.get("reason") or "Behavioral deduction"
    if not student_id or not amount:
        raise HTTPException(status_code=400, detail="student_id and amount are required")
        
    try:
        val = int(amount)
        if abs(val) > 50:
            raise HTTPException(status_code=400, detail="Deduction amount cannot be greater than 50 XP")
        penalty_amount = -abs(val)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid penalty amount format")
        
    from app.services.supabase_client import award_xp
    await award_xp(sb, school_id, student_id, penalty_amount, "manual_penalty", None, f"Penalty: {reason}")
    
    return {"success": True, "message": f"Deducted {abs(penalty_amount)} XP penalty successfully."}





