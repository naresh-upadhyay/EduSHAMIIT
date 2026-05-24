from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File, Form
from typing import Optional
from datetime import datetime
import asyncio
import httpx
import uuid

from app.middleware.auth import get_current_user, require_school_id, require_teacher
from app.services.supabase_client import get_supabase
from app.cache.redis_client import get_cached, set_cached, invalidate_cache
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


@router.post("/attendance/mark")
async def mark_attendance(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    date = request.get("date", datetime.now().date().isoformat())
    records = request.get("attendance_records", [])
    
    tasks = []
    for record in records:
        tasks.append(sb.table("attendance").upsert({
            "school_id": school_id, "student_id": record["student_id"],
            "subject_id": request.get("subject_id"), "teacher_id": user["id"],
            "marked_by": user["id"], "class": request.get("class_name", ""),
            "date": date, "status": record["status"],
        }, on_conflict="school_id,student_id,subject_id,date").aexecute())
        
    if tasks:
        await asyncio.gather(*tasks)
        
    return {"success": True, "school_id": school_id, "message": f"Marked {len(records)} students"}


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
                
    homework = await sb.table("homework").insert({
        "school_id": school_id, "subject_id": subject_id, "teacher_id": user["id"],
        "title": request.get("title"), "description": request.get("description"),
        "due_date": request.get("due_date"), "max_marks": request.get("max_marks", 25),
        "class": target_class, "status": "active",
    }).aexecute()
    return {"success": True, "school_id": school_id, "data": {"homework_id": homework.data[0]["id"]}}


@router.patch("/homework/{homework_id}")
async def teacher_update_homework(homework_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    updates = {}
    if "title" in request: updates["title"] = request["title"]
    if "description" in request: updates["description"] = request["description"]
    if "due_date" in request: updates["due_date"] = request["due_date"]
    if "max_marks" in request: updates["max_marks"] = request["max_marks"]
    if "status" in request: updates["status"] = request["status"]
    
    await sb.table("homework").update(updates).eq("id", homework_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Homework updated successfully"}


@router.delete("/homework/{homework_id}")
async def teacher_delete_homework(homework_id: str, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("homework").delete().eq("id", homework_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Homework deleted successfully"}



@router.post("/submissions/grade")
async def grade_submission(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("homework_submissions").update({
        "status": "graded", "marks": request.get("marks"), "grade": request.get("grade"),
        "teacher_remarks": request.get("remarks"), "graded_by": user["id"],
        "graded_at": datetime.now().isoformat(),
    }).eq("id", request.get("submission_id")).eq("school_id", school_id).aexecute()
    return {"success": True, "school_id": school_id, "message": "Submission graded"}


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
    
    # 1. Fetch regular timetable periods OR date-specific periods for today
    db_schedule = (await sb.table("timetable")
                    .select("*, subjects(name, icon, color)")
                    .eq("school_id", school_id)
                    .eq("teacher_id", user["id"])
                    .or_(f"day_of_week.eq.{day_num},date.eq.{target_date_str}")
                    .order("start_time")
                    .aexecute()).data
                    
    # Map regular timetable slots to flattened format expected by Flutter models
    schedule = []
    for idx, slot in enumerate(db_schedule):
        slot_date = slot.get("date")
        if slot_date is not None and slot_date != target_date_str:
            continue
            
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
                "class": lc.get("target_class", "All"),
                "room_number": lc.get("stream_url") or "EduSHAMIIT Live Link",
                "teacher_id": lc["teacher_id"],
                "teacher_name": user.get("full_name", "Teacher")
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
        res = await sb.table("timetable").insert({
            "school_id": school_id,
            "teacher_id": user["id"],
            "class": class_name,
            "day_of_week": day_num,
            "start_time": start_time,
            "end_time": end_time,
            "room": room,
            "date": date_str,
            "slot_type": slot_type,
            "custom_subject": custom_subject
        }).aexecute()
        
        # Invalidate cache
        await invalidate_cache(school_id, "teacher_dashboard")
        
        return {"success": True, "school_id": school_id, "data": res.data[0]}



@router.post("/exams/create")
async def create_exam(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    exam = await sb.table("exams").insert({
        "school_id": school_id, "subject_id": request.get("subject_id"), "teacher_id": user["id"],
        "title": request.get("title"), "exam_type": request.get("exam_type", "offline"),
        "exam_category": request.get("exam_category"), "exam_date": request.get("exam_date"),
        "start_time": request.get("start_time"), "duration_minutes": request.get("duration_minutes", 90),
        "total_marks": request.get("total_marks", 100), "venue": request.get("venue"),
        "target_classes": request.get("target_classes"), "status": "upcoming",
    }).aexecute()
    return {"success": True, "school_id": school_id, "data": {"exam_id": exam.data[0]["id"]}}


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
async def teacher_students(class_name: str = "", user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_students", f"{user['id']}_{class_name}")
    if cached:
        return cached

    sb = get_supabase()
    query = sb.table("profiles").select("id, full_name, class, roll_number, phone, father_name, father_phone, avatar_url").eq("school_id", school_id).eq("role", "student")
    if class_name:
        query = query.eq("class", class_name)
    students = (await query.order("class").order("roll_number").aexecute()).data
    
    result = {"success": True, "school_id": school_id, "data": {"students": students}}
    await set_cached(school_id, "teacher_students", result, f"{user['id']}_{class_name}", ttl=300)
    return result


@router.post("/leave/apply")
async def teacher_apply_leave(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("leave_applications").insert({"school_id": school_id, "applicant_id": user["id"], "applicant_role": "teacher", "leave_type": request.get("leave_type"), "start_date": request.get("start_date"), "end_date": request.get("end_date"), "reason": request.get("reason")}).aexecute()
    return {"success": True, "message": "Leave application submitted"}


@router.post("/notices/create")
async def create_notice(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    profile = (await sb.table("profiles").select("full_name").eq("id", user["id"]).single().aexecute()).data
    notice = await sb.table("notices").insert({"school_id": school_id, "title": request.get("title"), "content": request.get("content"), "category": request.get("category", "General"), "author_id": user["id"], "author_name": profile["full_name"], "is_urgent": request.get("is_urgent", False), "status": "published"}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"notice_id": notice.data[0]["id"]}}


@router.get("/live-classes")
async def teacher_live_classes(user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_live_classes", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    classes = (await sb.table("live_classes").select("*, subjects(name, icon)").eq("school_id", school_id).eq("teacher_id", user["id"]).order("scheduled_at", ascending=False).aexecute()).data
    
    result = {"success": True, "school_id": school_id, "data": {"live_classes": classes}}
    await set_cached(school_id, "teacher_live_classes", result, user["id"], ttl=120)
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
        "stream_url": request.get("stream_url"),
        "recording_url": request.get("recording_url"),
        "is_live": status == "live",
        "viewer_count": 0
    }
    
    res = await sb.table("live_classes").insert(data).aexecute()
    
    # Invalidate cache
    try:
        from app.cache.redis_client import get_redis
        rc = get_redis()
        if rc:
            await rc.delete(f"{school_id}:teacher_live_classes:{user['id']}")
            await rc.delete(f"{school_id}:teacher_dashboard:{user['id']}")
    except Exception:
        pass
        
    return {"success": True, "data": res.data[0] if res.data else {}}


@router.patch("/live-classes/{live_class_id}")
async def teacher_patch_live_class(live_class_id: str, request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    
    # Verify the class belongs to this teacher and school
    existing = await sb.table("live_classes").select("id").eq("id", live_class_id).eq("school_id", school_id).eq("teacher_id", user["id"]).maybe_single().aexecute()
    if not existing.data:
        raise HTTPException(status_code=404, detail="Live class not found or access denied")
        
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
    if "title" in request:
        update_data["title"] = request["title"]
        
    if update_data:
        res = await sb.table("live_classes").update(update_data).eq("id", live_class_id).aexecute()
    else:
        res = await sb.table("live_classes").select("*").eq("id", live_class_id).aexecute()
        
    # Invalidate cache
    try:
        from app.cache.redis_client import get_redis
        rc = get_redis()
        if rc:
            await rc.delete(f"{school_id}:teacher_live_classes:{user['id']}")
            await rc.delete(f"{school_id}:teacher_dashboard:{user['id']}")
            # Clear all student live classes cache keys
            keys = await rc.keys(f"{school_id}:student_live_classes:*")
            if keys:
                await rc.delete(*keys)
    except Exception:
        pass
        
    return {"success": True, "data": res.data[0] if res.data else {}}




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
    query = sb.table("homework_submissions").select("*, profiles!student_id(full_name, roll_number), homework(title)").eq("school_id", school_id)
    if homework_id:
        query = query.eq("homework_id", homework_id)
    submissions = (await query.order("submitted_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"submissions": submissions}}


@router.get("/notifications")
async def teacher_notifications(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    notifications = (await sb.table("notifications").select("*").eq("school_id", school_id).eq("user_id", user["id"]).order("created_at", ascending=False).limit(20).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"notifications": notifications}}


@router.put("/user/settings")
async def teacher_update_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("user_settings").upsert({"school_id": school_id, "user_id": user["id"], **request}, on_conflict="user_id").aexecute()
    return {"success": True, "message": "Settings updated"}


@router.get("/messages")
async def teacher_get_messages(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    messages = (await sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url, role)").eq("school_id", school_id).or_(f"sender_id.eq.{user['id']},receiver_id.eq.{user['id']}").order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.post("/messages/send")
async def teacher_send_message(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    message = await sb.table("messages").insert({"school_id": school_id, "sender_id": user["id"], "receiver_id": request.get("receiver_id"), "content": request.get("content")}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"message_id": message.data[0]["id"]}}


@router.get("/messages/chat")
async def teacher_get_chat(chat_id: str = "", user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    if not chat_id:
        return {"success": True, "school_id": school_id, "data": {"messages": []}}
    messages = (await sb.table("messages").select("*, profiles!sender_id(full_name, avatar_url)").eq("school_id", school_id).or_(f"sender_id.eq.{chat_id},receiver_id.eq.{chat_id}").order("created_at").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}


@router.post("/groups/create")
async def teacher_create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    group = await sb.table("groups").insert({"school_id": school_id, "name": request.get("name"), "description": request.get("description"), "created_by": user["id"]}).aexecute()
    return {"success": True, "school_id": school_id, "data": {"group_id": group.data[0]["id"]}}


@router.get("/groups")
async def teacher_get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    groups = (await sb.table("groups").select("*").eq("school_id", school_id).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"groups": groups}}


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
            
    return {"success": True, "school_id": school_id, "data": {"homework": homework}}



@router.get("/exams")
async def teacher_get_exams(type: str = None, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("exams").select("*, subjects(name, class)").eq("school_id", school_id)
    exams_data = (await query.order("start_time", ascending=False).aexecute()).data
    
    for e in exams_data:
        subj = e.get("subjects") or {}
        e["subject"] = subj.get("name", "Unknown")
        if not e.get("class"):
            e["class"] = subj.get("class", "Unknown")
        if not e.get("exam_date"):
            e["exam_date"] = e.get("start_time")
        e["duration"] = str(e.get("duration_minutes", 0)) + " mins"
        
    if type and type.lower() != 'all':
        exams_data = [e for e in exams_data if (e.get("exam_type") or "").lower() == type.lower()]

    return {"success": True, "school_id": school_id, "data": {"exams": exams_data}}


@router.get("/notices")
async def teacher_get_notices(category: str = None, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("notices").select("*").eq("school_id", school_id)
    if category and category.lower() != 'all':
        query = query.eq("category", category)
    notices = (await query.order("published_at", ascending=False).aexecute()).data
    for n in notices:
        n["created_at"] = n.get("published_at")
    return {"success": True, "school_id": school_id, "data": {"notices": notices}}


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