from fastapi import APIRouter, Depends, Query, HTTPException
from typing import Optional
from datetime import datetime
import asyncio

from app.middleware.auth import get_current_user, require_school_id, require_teacher
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
async def teacher_dashboard(user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_dashboard", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    today = datetime.now().weekday()
    
    tasks = [
        sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute(),
        sb.table("timetable").select("*, subjects(name, icon)").eq("school_id", school_id).eq("teacher_id", user["id"]).eq("day_of_week", today).order("start_time").aexecute(),
        sb.table("homework").select("id").eq("school_id", school_id).eq("teacher_id", user["id"]).eq("status", "active").aexecute(),
        sb.table("profiles").select("*").eq("id", user["id"]).single().aexecute()
    ]
    
    results = await asyncio.gather(*tasks)
    classes = results[0].data
    schedule = results[1].data
    homework = results[2].data
    profile = results[3].data

    unique_classes = list(set(c["class"] for c in classes))
    homework_ids = [hw["id"] for hw in homework]

    async def fetch_students():
        if not unique_classes: return []
        res = await sb.table("profiles").select("id").eq("school_id", school_id).in_("class", unique_classes).eq("role", "student").aexecute()
        return res.data
        
    async def fetch_pending_subs():
        if not homework_ids: return []
        res = await sb.table("homework_submissions").select("id").in_("homework_id", homework_ids).eq("status", "submitted").aexecute()
        return res.data

    students, pending_subs_data = await asyncio.gather(fetch_students(), fetch_pending_subs())
    pending_subs = len(pending_subs_data)

    result = {"success": True, "school_id": school_id, "data": {"teacher": profile, "stats": {"total_students": len(students), "total_classes": len(unique_classes), "pending_tasks": pending_subs}, "today_schedule": schedule}}
    await set_cached(school_id, "teacher_dashboard", result, user["id"], ttl=120)
    return result


@router.get("/classes")
async def teacher_classes(user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_classes", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    classes_res = await sb.table("timetable").select("class").eq("school_id", school_id).eq("teacher_id", user["id"]).aexecute()
    classes = classes_res.data
    unique_classes = list(set(c["class"] for c in classes))
    
    tasks = []
    for cls in unique_classes:
        tasks.append(sb.table("profiles").select("id").eq("school_id", school_id).eq("class", cls).eq("role", "student").aexecute())
        
    results = await asyncio.gather(*tasks) if tasks else []
    
    class_details = []
    for i, cls in enumerate(unique_classes):
        students = results[i].data if results else []
        class_details.append({"class": cls, "student_count": len(students)})
        
    result = {"success": True, "school_id": school_id, "data": {"classes": class_details}}
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
            "date": date, "status": record["status"],
        }, on_conflict="school_id,student_id,subject_id,date").aexecute())
        
    if tasks:
        await asyncio.gather(*tasks)
        
    return {"success": True, "school_id": school_id, "message": f"Marked {len(records)} students"}


@router.post("/homework/create")
async def create_homework(request: dict, user=Depends(require_teacher), school_id=Depends(require_school_id)):
    sb = get_supabase()
    homework = await sb.table("homework").insert({
        "school_id": school_id, "subject_id": request.get("subject_id"), "teacher_id": user["id"],
        "title": request.get("title"), "description": request.get("description"),
        "due_date": request.get("due_date"), "max_marks": request.get("max_marks", 25),
        "target_class": request.get("target_class"), "status": "active",
    }).aexecute()
    return {"success": True, "school_id": school_id, "data": {"homework_id": homework.data[0]["id"]}}


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
async def teacher_timetable(day: str = "monday", user=Depends(require_teacher), school_id=Depends(require_school_id)):
    cached = await get_cached(school_id, "teacher_timetable", f"{user['id']}_{day}")
    if cached:
        return cached

    sb = get_supabase()
    day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5}
    day_num = day_map.get(day.lower(), datetime.now().weekday())
    schedule = (await sb.table("timetable").select("*, subjects(name, icon, color)").eq("school_id", school_id).eq("teacher_id", user["id"]).eq("day_of_week", day_num).order("start_time").aexecute()).data
    
    result = {"success": True, "school_id": school_id, "data": {"schedule": schedule, "day": day}}
    await set_cached(school_id, "teacher_timetable", result, f"{user['id']}_{day}", ttl=300)
    return result


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
        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.7, google_api_key=os.getenv("GOOGLE_API_KEY", "AIza-placeholder"))
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
        query = sb.table("results").select("student_id, marks_obtained, max_marks, grade, exam_category").eq("school_id", school_id).in_("student_id", [s["id"] for s in students])
        if subject_id:
            query = query.eq("subject_id", subject_id)
        results = (await query.aexecute()).data
        
    gradebook = []
    for s in students:
        s_results = [r for r in results if r["student_id"] == s["id"]]
        total = sum(float(r["marks_obtained"]) for r in s_results)
        max_total = sum(float(r["max_marks"]) for r in s_results)
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
    profile = (await sb.table("profiles").select("*").eq("id", user["id"]).single().aexecute()).data
    
    result = {"success": True, "school_id": school_id, "data": {"profile": profile}}
    await set_cached(school_id, "teacher_profile", result, user["id"], ttl=300)
    return result


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