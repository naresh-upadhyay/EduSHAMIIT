from fastapi import APIRouter, Depends, Query, HTTPException, UploadFile, File, Form, Request
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


@router.get("/subjects")
async def teacher_subjects(class_name: Optional[str] = None, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("subjects").select("*").eq("school_id", school_id)
    if class_name:
        query = query.eq("class", class_name)
    else:
        query = query.eq("teacher_id", user["id"])
    subjects = (await query.aexecute()).data or []
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
