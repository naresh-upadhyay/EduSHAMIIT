"""
students_admin.py — Student Admin CRUD API
==========================================
Accessible by roles: admin, student_admin

Covers:
  - Students management (list, create, update, deactivate, bulk class assign)
  - Subjects CRUD
  - Courses CRUD
  - Timetable CRUD
  - Exams CRUD
  - Results entry / update / delete
  - Attendance admin (bulk-mark, correct)
  - Fees CRUD (bulk per-student from class)
  - Events CRUD
  - Notices CRUD (with flexible targeting)
  - Transport: routes, stops, student assignments
  - Library: books + borrow management
  - Achievements: catalog + award
  - Leave management (approve / reject)
  - Notifications: broadcast with class + individual targeting
  - Content Distribution: universal distribute endpoint
"""

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from typing import Optional, List
from datetime import datetime, timedelta
import uuid
import asyncio

from app.middleware.auth import (
    get_current_user,
    require_school_id,
    require_student_admin,
)
from app.services.supabase_client import get_supabase

router = APIRouter()


# ===========================================================
# Helpers
# ===========================================================

async def _resolve_recipients(
    sb,
    school_id: str,
    target_classes: Optional[List[str]],
    target_student_ids: Optional[List[str]],
    include_parents: bool = False,
) -> List[str]:
    """
    Resolves a combined, deduplicated list of user IDs from:
      - All students in target_classes
      - Individual student IDs
    If include_parents=True, also returns parent profile IDs for those students.
    """
    user_ids: set = set()

    # --- Resolve class-based students ---
    if target_classes:
        res = await sb.table("profiles").select("id").eq(
            "school_id", school_id
        ).eq("role", "student").in_("class", target_classes).aexecute()
        for row in (res.data or []):
            user_ids.add(row["id"])

    # --- Add individually targeted students ---
    for sid in (target_student_ids or []):
        user_ids.add(sid)

    # --- Optionally include parents ---
    if include_parents and user_ids:
        # Assuming profiles has a parent_id or separate parent_profiles table.
        # Here we look for profiles where role='parent' and student_id in user_ids.
        parent_res = await sb.table("profiles").select("id").eq(
            "school_id", school_id
        ).eq("role", "parent").in_("student_id", list(user_ids)).aexecute()
        for row in (parent_res.data or []):
            user_ids.add(row["id"])

    return list(user_ids)


async def _send_notifications(
    sb,
    school_id: str,
    user_ids: List[str],
    title: str,
    body: str,
    notification_type: str,
    reference_id: Optional[str] = None,
    sender_id: Optional[str] = None,
):
    """Bulk-insert notifications for a list of user IDs."""
    if not user_ids:
        return

    records = [
        {
            "id": str(uuid.uuid4()),
            "school_id": school_id,
            "user_id": uid,
            "title": title,
            "body": body,
            "type": notification_type,
            "reference_id": reference_id,
            "is_read": False,
            "created_at": datetime.utcnow().isoformat(),
        }
        for uid in user_ids
    ]
    # Batch insert in chunks of 500
    for i in range(0, len(records), 500):
        await sb.table("notifications").insert(records[i : i + 500]).aexecute()


async def _log_distribution(
    sb,
    school_id: str,
    sender_id: str,
    content_type: str,
    content_id: Optional[str],
    target_classes: Optional[List[str]],
    target_student_ids: Optional[List[str]],
    include_parents: bool,
    recipient_count: int,
):
    """Log to content_distributions for audit trail."""
    await sb.table("content_distributions").insert({
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "content_type": content_type,
        "content_id": content_id,
        "sender_id": sender_id,
        "target_classes": target_classes or [],
        "target_student_ids": target_student_ids or [],
        "include_parents": include_parents,
        "resolved_recipient_count": recipient_count,
        "created_at": datetime.utcnow().isoformat(),
    }).aexecute()


# ===========================================================
# Students Management
# ===========================================================

@router.get("/list")
async def list_students(
    class_name: Optional[str] = None,
    search: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """List all students with optional filters."""
    sb = get_supabase()
    query = (
        sb.table("profiles")
        .select("id, full_name, class, roll_number, email, phone, avatar_url, admission_number, father_name, father_phone")
        .eq("school_id", school_id)
        .eq("role", "student")
    )
    if class_name:
        query = query.eq("class", class_name)
    if search:
        query = query.ilike("full_name", f"%{search}%")
    students = (
        await query.order("class").order("roll_number").limit(limit).offset(offset).aexecute()
    ).data
    return {"success": True, "school_id": school_id, "data": {"students": students, "count": len(students)}}


@router.post("/create")
async def create_student(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Create a new student profile."""
    sb = get_supabase()
    required = ["full_name", "class", "roll_number"]
    for field in required:
        if not request.get(field):
            raise HTTPException(status_code=400, detail=f"Missing required field: {field}")

    profile_data = {
        "id": request.get("id", str(uuid.uuid4())),
        "school_id": school_id,
        "full_name": request["full_name"],
        "role": "student",
        "class": request["class"],
        "roll_number": request["roll_number"],
        "email": request.get("email"),
        "phone": request.get("phone"),
        "gender": request.get("gender"),
        "date_of_birth": request.get("date_of_birth"),
        "blood_group": request.get("blood_group"),
        "address": request.get("address"),
        "admission_number": request.get("admission_number"),
        "father_name": request.get("father_name"),
        "father_phone": request.get("father_phone"),
        "mother_name": request.get("mother_name"),
        "mother_phone": request.get("mother_phone"),
        "session": request.get("session"),
        "house": request.get("house"),
        "category": request.get("category"),
        "nationality": request.get("nationality"),
        "religion": request.get("religion"),
        "xp_points": 0,
        "learning_streak": 0,
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("profiles").insert(profile_data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else profile_data}


@router.put("/{student_id}")
async def update_student(
    student_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Update student profile (admin can change class, roll number, etc.)."""
    sb = get_supabase()
    # Admin can update all fields including class/roll
    allowed = {
        "full_name", "class", "roll_number", "email", "phone", "address",
        "gender", "date_of_birth", "blood_group", "admission_number",
        "father_name", "father_phone", "mother_name", "mother_phone",
        "local_guardian", "nationality", "religion", "category",
        "house", "session", "avatar_url",
    }
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    update_data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("profiles").update(update_data).eq("id", student_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Student profile updated"}


@router.delete("/{student_id}")
async def deactivate_student(
    student_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Soft-deactivate a student (sets is_active=false)."""
    sb = get_supabase()
    await sb.table("profiles").update({"is_active": False, "updated_at": datetime.utcnow().isoformat()}).eq(
        "id", student_id
    ).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Student deactivated"}


@router.post("/bulk-class-assign")
async def bulk_class_assign(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Move a list of students to a new class in bulk.
    Body: { student_ids: [uuid, ...], new_class: "Class XI-A" }
    """
    sb = get_supabase()
    student_ids: List[str] = request.get("student_ids", [])
    new_class: str = request.get("new_class", "")
    if not student_ids or not new_class:
        raise HTTPException(status_code=400, detail="student_ids and new_class are required")
    tasks = [
        sb.table("profiles").update({"class": new_class, "updated_at": datetime.utcnow().isoformat()}).eq(
            "id", sid
        ).eq("school_id", school_id).aexecute()
        for sid in student_ids
    ]
    await asyncio.gather(*tasks)
    return {"success": True, "message": f"Moved {len(student_ids)} students to {new_class}"}


# ===========================================================
# Subjects CRUD
# ===========================================================

@router.get("/subjects")
async def list_subjects(
    class_name: Optional[str] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("subjects").select("*").eq("school_id", school_id)
    if class_name:
        query = query.eq("class", class_name)
    subjects = (await query.order("name").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"subjects": subjects}}


@router.post("/subjects")
async def create_subject(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    if not request.get("name"):
        raise HTTPException(status_code=400, detail="name is required")
    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "name": request["name"],
        "class": request.get("class"),
        "icon": request.get("icon", "📚"),
        "color": request.get("color", "#4F46E5"),
        "teacher_id": request.get("teacher_id"),
        "created_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("subjects").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/subjects/{subject_id}")
async def update_subject(
    subject_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"name", "class", "icon", "color", "teacher_id"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("subjects").update(update_data).eq("id", subject_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Subject updated"}


@router.delete("/subjects/{subject_id}")
async def delete_subject(
    subject_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("subjects").delete().eq("id", subject_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Subject deleted"}


# ===========================================================
# Courses CRUD
# ===========================================================

@router.get("/courses")
async def list_courses(
    subject_id: Optional[str] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("courses").select("*, subjects(name, class, icon, color)").eq("school_id", school_id)
    if subject_id:
        query = query.eq("subject_id", subject_id)
    courses = (await query.order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"courses": courses}}


@router.post("/courses")
async def create_course(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Create a new course.
    Body: { subject_id, title, description, thumbnail_url, duration_weeks,
            target_classes: ['Class A', 'Class B'], is_published: true }
    """
    sb = get_supabase()
    if not request.get("title") or not request.get("subject_id"):
        raise HTTPException(status_code=400, detail="title and subject_id are required")

    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "subject_id": request["subject_id"],
        "title": request["title"],
        "description": request.get("description", ""),
        "thumbnail_url": request.get("thumbnail_url"),
        "status": "active",
        "syllabus_coverage": request.get("syllabus_coverage", []),
        "upcoming_topics": request.get("upcoming_topics", []),
        "resources_text": request.get("resources_text", ""),
        "chapters_count": request.get("chapters_count", ""),
        "created_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("courses").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/courses/{course_id}")
async def update_course(
    course_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {
        "title", "description", "thumbnail_url", "subject_id", "status",
        "syllabus_coverage", "upcoming_topics", "resources_text", "chapters_count"
    }
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("courses").update(update_data).eq("id", course_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Course updated"}


@router.delete("/courses/{course_id}")
async def delete_course(
    course_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("courses").delete().eq("id", course_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Course deleted"}


# ===========================================================
# Timetable CRUD
# ===========================================================

@router.get("/timetable")
async def list_timetable(
    class_name: Optional[str] = None,
    day_of_week: Optional[int] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("timetable").select("*, subjects(name, icon, color), profiles!teacher_id(full_name)").eq("school_id", school_id)
    if class_name:
        query = query.eq("class", class_name)
    if day_of_week is not None:
        query = query.eq("day_of_week", day_of_week)
    slots = (await query.order("day_of_week").order("start_time").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"timetable": slots}}


@router.post("/timetable")
async def create_timetable_slot(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Create timetable slot.
    Body: { class, subject_id, teacher_id, day_of_week (0-5), start_time, end_time, room }
    """
    sb = get_supabase()
    required = ["class", "subject_id", "day_of_week", "start_time", "end_time"]
    for f in required:
        if request.get(f) is None:
            raise HTTPException(status_code=400, detail=f"Missing: {f}")
    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "class": request["class"],
        "subject_id": request["subject_id"],
        "teacher_id": request.get("teacher_id"),
        "day_of_week": request["day_of_week"],
        "start_time": request["start_time"],
        "end_time": request["end_time"],
        "room": request.get("room"),
        "created_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("timetable").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/timetable/{slot_id}")
async def update_timetable_slot(
    slot_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"class", "subject_id", "teacher_id", "day_of_week", "start_time", "end_time", "room"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("timetable").update(update_data).eq("id", slot_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Timetable slot updated"}


@router.delete("/timetable/{slot_id}")
async def delete_timetable_slot(
    slot_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("timetable").delete().eq("id", slot_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Timetable slot deleted"}


# ===========================================================
# Exams CRUD (admin)
# ===========================================================

@router.get("/exams")
async def list_exams(
    exam_type: Optional[str] = None,
    class_name: Optional[str] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("exams").select("*, subjects(name, class, icon)").eq("school_id", school_id)
    if exam_type:
        query = query.eq("exam_type", exam_type)
    exams = (await query.order("start_time", ascending=False).aexecute()).data
    if class_name:
        exams = [e for e in exams if class_name in (e.get("target_classes") or [])]
    return {"success": True, "school_id": school_id, "data": {"exams": exams}}


@router.post("/exams")
async def create_exam(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Create exam with class + individual student targeting."""
    sb = get_supabase()
    required = ["subject_id", "title", "exam_date"]
    for f in required:
        if not request.get(f):
            raise HTTPException(status_code=400, detail=f"Missing: {f}")

    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "subject_id": request["subject_id"],
        "teacher_id": user["id"],
        "title": request["title"],
        "exam_type": request.get("exam_type", "offline"),
        "exam_category": request.get("exam_category"),
        "exam_date": request.get("exam_date"),
        "start_time": request.get("start_time"),
        "duration_minutes": request.get("duration_minutes", 90),
        "total_marks": request.get("total_marks", 100),
        "venue": request.get("venue"),
        "target_classes": request.get("target_classes", []),
        "status": "upcoming",
        "created_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("exams").insert(data).aexecute()
    exam_id = result.data[0]["id"] if result.data else data["id"]

    # Distribute notifications
    target_classes = request.get("target_classes", [])
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)
    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if recipients:
        await _send_notifications(
            sb, school_id, recipients,
            title=f"📝 New Exam: {data['title']}",
            body=f"Exam scheduled. Check your exam schedule for details.",
            notification_type="exam",
            reference_id=exam_id,
            sender_id=user["id"],
        )
    await _log_distribution(sb, school_id, user["id"], "exam", exam_id, target_classes, target_student_ids, include_parents, len(recipients))

    return {"success": True, "school_id": school_id, "data": {"exam_id": exam_id, "recipients_notified": len(recipients)}}


@router.put("/exams/{exam_id}")
async def update_exam(
    exam_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"title", "exam_type", "exam_category", "exam_date", "start_time", "duration_minutes", "total_marks", "venue", "target_classes", "status"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("exams").update(update_data).eq("id", exam_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Exam updated"}


@router.delete("/exams/{exam_id}")
async def delete_exam(
    exam_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("exams").delete().eq("id", exam_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Exam deleted"}


# ===========================================================
# Results CRUD
# ===========================================================

@router.get("/results")
async def list_results(
    student_id: Optional[str] = None,
    class_name: Optional[str] = None,
    subject_id: Optional[str] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("results").select("*, subjects(name, icon), profiles!student_id(full_name, class, roll_number)").eq("school_id", school_id)
    if student_id:
        query = query.eq("student_id", student_id)
    if subject_id:
        query = query.eq("subject_id", subject_id)
    results = (await query.order("created_at", ascending=False).aexecute()).data
    if class_name:
        results = [r for r in results if (r.get("profiles") or {}).get("class") == class_name]
    return {"success": True, "school_id": school_id, "data": {"results": results}}


@router.post("/results")
async def create_result(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Enter result for a student."""
    sb = get_supabase()
    required = ["student_id", "subject_id", "marks_obtained", "total_marks"]
    for f in required:
        if request.get(f) is None:
            raise HTTPException(status_code=400, detail=f"Missing: {f}")
    pct = float(request["marks_obtained"]) / float(request["total_marks"]) * 100
    grades = [(90, "A+"), (80, "A"), (70, "B+"), (60, "B"), (50, "C"), (40, "D")]
    grade = "F"
    for threshold, g in grades:
        if pct >= threshold:
            grade = g
            break
    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "student_id": request["student_id"],
        "subject_id": request["subject_id"],
        "exam_type": request.get("exam_type", "unit_test"),
        "marks_obtained": request["marks_obtained"],
        "total_marks": request["total_marks"],
        "grade": grade,
        "remarks": request.get("remarks", ""),
        "created_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("results").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.post("/results/bulk")
async def create_bulk_results(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Enter results for multiple students at once.
    Body: { exam_id, subject_id, exam_type, results: [{student_id, marks_obtained, total_marks}] }
    """
    sb = get_supabase()
    entries = request.get("results", [])
    if not entries:
        raise HTTPException(status_code=400, detail="results array is required")
    records = []
    for entry in entries:
        pct = float(entry.get("marks_obtained", 0)) / float(entry.get("total_marks", 100)) * 100
        grades = [(90, "A+"), (80, "A"), (70, "B+"), (60, "B"), (50, "C"), (40, "D")]
        grade = "F"
        for threshold, g in grades:
            if pct >= threshold:
                grade = g
                break
        records.append({
            "id": str(uuid.uuid4()),
            "school_id": school_id,
            "student_id": entry["student_id"],
            "subject_id": request.get("subject_id"),
            "exam_type": request.get("exam_type", "unit_test"),
            "marks_obtained": entry["marks_obtained"],
            "total_marks": entry.get("total_marks", 100),
            "grade": grade,
            "remarks": entry.get("remarks", ""),
            "created_at": datetime.utcnow().isoformat(),
        })
    await sb.table("results").insert(records).aexecute()
    return {"success": True, "school_id": school_id, "message": f"{len(records)} results entered"}


@router.put("/results/{result_id}")
async def update_result(
    result_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"marks_obtained", "total_marks", "grade", "remarks", "exam_type"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    await sb.table("results").update(update_data).eq("id", result_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Result updated"}


@router.delete("/results/{result_id}")
async def delete_result(
    result_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("results").delete().eq("id", result_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Result deleted"}


# ===========================================================
# Attendance Admin
# ===========================================================

@router.get("/attendance")
async def list_attendance(
    class_name: Optional[str] = None,
    student_id: Optional[str] = None,
    date: Optional[str] = None,
    subject_id: Optional[str] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("attendance").select("*, profiles!student_id(full_name, class, roll_number), subjects(name)").eq("school_id", school_id)
    if student_id:
        query = query.eq("student_id", student_id)
    if date:
        query = query.eq("date", date)
    if subject_id:
        query = query.eq("subject_id", subject_id)
    if class_name:
        query = query.eq("class", class_name)
    records = (await query.order("date", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"attendance": records}}


@router.post("/attendance/mark")
async def admin_mark_attendance(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Admin bulk-mark attendance (overrides teacher marks).
    Body: { date, subject_id, class_name, attendance_records: [{student_id, status}] }
    """
    sb = get_supabase()
    date = request.get("date", datetime.now().date().isoformat())
    records = request.get("attendance_records", [])
    if not records:
        raise HTTPException(status_code=400, detail="attendance_records is required")
    tasks = [
        sb.table("attendance").upsert({
            "school_id": school_id,
            "student_id": r["student_id"],
            "subject_id": request.get("subject_id"),
            "teacher_id": user["id"],
            "marked_by": user["id"],
            "class": request.get("class_name", ""),
            "date": date,
            "status": r["status"],
        }, on_conflict="school_id,student_id,subject_id,date").aexecute()
        for r in records
    ]
    await asyncio.gather(*tasks)
    return {"success": True, "school_id": school_id, "message": f"Marked {len(records)} students"}


@router.put("/attendance/{record_id}")
async def correct_attendance(
    record_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Correct an existing attendance record."""
    sb = get_supabase()
    if not request.get("status"):
        raise HTTPException(status_code=400, detail="status is required")
    await sb.table("attendance").update({
        "status": request["status"],
        "corrected_by": user["id"],
        "corrected_at": datetime.utcnow().isoformat(),
    }).eq("id", record_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Attendance corrected"}


# ===========================================================
# Fees CRUD
# ===========================================================

@router.get("/fees")
async def list_fees(
    student_id: Optional[str] = None,
    class_name: Optional[str] = None,
    status: Optional[str] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("fees").select("*, profiles!student_id(full_name, class, roll_number)").eq("school_id", school_id)
    if student_id:
        query = query.eq("student_id", student_id)
    if status:
        query = query.eq("status", status)
    fees = (await query.order("due_date").aexecute()).data
    if class_name:
        fees = [f for f in fees if (f.get("profiles") or {}).get("class") == class_name]
    return {"success": True, "school_id": school_id, "data": {"fees": fees}}


@router.post("/fees")
async def create_fee(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Create fee records.
    - For a single student: provide student_id
    - For a whole class: provide target_class (creates one record per student)
    Body: { fee_type, amount, due_date, description, student_id?, target_class? }
    """
    sb = get_supabase()
    required = ["fee_type", "amount", "due_date"]
    for f in required:
        if not request.get(f):
            raise HTTPException(status_code=400, detail=f"Missing: {f}")

    student_id = request.get("student_id")
    target_class = request.get("target_class")

    if not student_id and not target_class:
        raise HTTPException(status_code=400, detail="Provide either student_id or target_class")

    student_ids = []
    if target_class:
        res = await sb.table("profiles").select("id").eq("school_id", school_id).eq("role", "student").eq("class", target_class).aexecute()
        student_ids = [r["id"] for r in (res.data or [])]
    else:
        student_ids = [student_id]

    if not student_ids:
        return {"success": False, "message": "No students found for the specified target"}

    records = [
        {
            "id": str(uuid.uuid4()),
            "school_id": school_id,
            "student_id": sid,
            "fee_type": request["fee_type"],
            "amount": request["amount"],
            "due_date": request["due_date"],
            "description": request.get("description", ""),
            "status": "pending",
            "created_at": datetime.utcnow().isoformat(),
        }
        for sid in student_ids
    ]
    await sb.table("fees").insert(records).aexecute()
    return {"success": True, "school_id": school_id, "message": f"Created {len(records)} fee records", "data": {"count": len(records)}}


@router.put("/fees/{fee_id}")
async def update_fee(
    fee_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"fee_type", "amount", "due_date", "status", "description", "paid_at"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("fees").update(update_data).eq("id", fee_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Fee record updated"}


@router.delete("/fees/{fee_id}")
async def delete_fee(
    fee_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("fees").delete().eq("id", fee_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Fee record deleted"}


# ===========================================================
# Events CRUD
# ===========================================================

@router.get("/events")
async def list_events(
    upcoming_only: bool = False,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("events").select("*").eq("school_id", school_id)
    if upcoming_only:
        query = query.gte("event_date", datetime.now().date().isoformat())
    events = (await query.order("event_date").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"events": events}}


@router.post("/events")
async def create_event(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    if not request.get("title") or not request.get("event_date"):
        raise HTTPException(status_code=400, detail="title and event_date are required")
    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "title": request["title"],
        "description": request.get("description", ""),
        "event_date": request["event_date"],
        "event_time": request.get("event_time"),
        "venue": request.get("venue"),
        "category": request.get("category", "General"),
        "is_mandatory": request.get("is_mandatory", False),
        "created_by": user["id"],
        "created_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("events").insert(data).aexecute()
    event_id = result.data[0]["id"] if result.data else data["id"]

    # Notify students
    target_classes = request.get("target_classes", [])
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)
    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if recipients:
        await _send_notifications(
            sb, school_id, recipients,
            title=f"📅 New Event: {data['title']}",
            body=f"Event on {data['event_date']}. Check events section for details.",
            notification_type="event",
            reference_id=event_id,
            sender_id=user["id"],
        )
    return {"success": True, "school_id": school_id, "data": {"event_id": event_id, "recipients_notified": len(recipients)}}


@router.put("/events/{event_id}")
async def update_event(
    event_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"title", "description", "event_date", "event_time", "venue", "category", "is_mandatory", "status"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("events").update(update_data).eq("id", event_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Event updated"}


@router.delete("/events/{event_id}")
async def delete_event(
    event_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("events").delete().eq("id", event_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Event deleted"}


# ===========================================================
# Notices CRUD (student-facing, with distribution)
# ===========================================================

@router.get("/notices")
async def list_notices(
    category: Optional[str] = None,
    status: Optional[str] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("notices").select("*").eq("school_id", school_id)
    if category and category.lower() != "all":
        query = query.eq("category", category)
    if status:
        query = query.eq("status", status)
    notices = (await query.order("published_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"notices": notices}}


@router.post("/notices")
async def create_notice(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Create a notice and distribute to class groups + individual students.
    Body: {
        title, content, category, is_urgent,
        target_classes: ['Class A', 'Class B'],
        target_student_ids: ['uuid1', 'uuid2'],
        include_parents: true
    }
    """
    sb = get_supabase()
    if not request.get("title") or not request.get("content"):
        raise HTTPException(status_code=400, detail="title and content are required")

    profile = (await sb.table("profiles").select("full_name").eq("id", user["id"]).maybe_single().aexecute()).data
    author_name = (profile or {}).get("full_name", "Admin")

    target_classes = request.get("target_classes", [])
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)

    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "title": request["title"],
        "content": request["content"],
        "category": request.get("category", "General"),
        "author_id": user["id"],
        "author_name": author_name,
        "is_urgent": request.get("is_urgent", False),
        "status": request.get("status", "published"),
        "target_classes": target_classes or None,
        "target_student_ids": target_student_ids or None,
        "published_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("notices").insert(data).aexecute()
    notice_id = result.data[0]["id"] if result.data else data["id"]

    # Notify recipients
    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if recipients:
        await _send_notifications(
            sb, school_id, recipients,
            title=f"📢 {'🚨 URGENT: ' if data['is_urgent'] else ''}{data['title']}",
            body=data["content"][:200],
            notification_type="notice",
            reference_id=notice_id,
            sender_id=user["id"],
        )
    await _log_distribution(sb, school_id, user["id"], "notice", notice_id, target_classes, target_student_ids, include_parents, len(recipients))

    return {"success": True, "school_id": school_id, "data": {"notice_id": notice_id, "recipients_notified": len(recipients)}}


@router.put("/notices/{notice_id}")
async def update_notice(
    notice_id: str,
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"title", "content", "category", "is_urgent", "status"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("notices").update(update_data).eq("id", notice_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Notice updated"}


@router.delete("/notices/{notice_id}")
async def delete_notice(
    notice_id: str,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("notices").delete().eq("id", notice_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Notice deleted"}


# ===========================================================
# Transport CRUD
# ===========================================================

@router.get("/transport")
async def get_transport_overview(user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    routes = (await sb.table("bus_routes").select("*, bus_stops(*)").eq("school_id", school_id).aexecute()).data
    assignments = (await sb.table("student_transport").select("*, bus_routes(*), bus_stops(*)").eq("school_id", school_id).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"routes": routes, "assignments": assignments}}


@router.get("/transport/routes")
async def list_routes(user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    routes = (await sb.table("bus_routes").select("*, bus_stops(*)").eq("school_id", school_id).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"routes": routes}}


@router.post("/transport/routes")
async def create_route(request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    if not request.get("route_name"):
        raise HTTPException(status_code=400, detail="route_name is required")
    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "route_name": request["route_name"],
        "bus_number": request.get("bus_number") or request.get("route_number") or "",
        "driver_name": request.get("driver_name"),
        "driver_phone": request.get("driver_phone"),
        "total_capacity": request.get("total_capacity", 40),
        "status": request.get("status", "active"),
    }
    result = await sb.table("bus_routes").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/transport/routes/{route_id}")
async def update_route(route_id: str, request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    allowed = {"route_name", "bus_number", "route_number", "driver_name", "driver_phone", "total_capacity", "status"}
    update_data = {}
    for k, v in request.items():
        if k in allowed:
            if k == "route_number" or k == "bus_number":
                update_data["bus_number"] = v
            else:
                update_data[k] = v
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("bus_routes").update(update_data).eq("id", route_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Route updated"}


@router.delete("/transport/routes/{route_id}")
async def delete_route(route_id: str, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("bus_routes").delete().eq("id", route_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Route deleted"}


@router.post("/transport/assign")
async def assign_transport(request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    """Assign a student to a bus route + stop."""
    sb = get_supabase()
    if not request.get("student_id") or not request.get("route_id"):
        raise HTTPException(status_code=400, detail="student_id and route_id are required")
    data = {
        "id": str(uuid.uuid4()), "school_id": school_id,
        "student_id": request["student_id"], "route_id": request["route_id"],
        "stop_id": request.get("stop_id"),
    }
    await sb.table("student_transport").upsert(data, on_conflict="school_id,student_id").aexecute()
    return {"success": True, "message": "Transport assigned"}


@router.put("/transport/assign/{assignment_id}")
async def update_transport_assignment(assignment_id: str, request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    allowed = {"route_id", "stop_id"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    await sb.table("student_transport").update(update_data).eq("id", assignment_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Assignment updated"}


@router.delete("/transport/assign/{assignment_id}")
async def delete_transport_assignment(assignment_id: str, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("student_transport").delete().eq("id", assignment_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Transport assignment removed"}


# ===========================================================
# Library CRUD
# ===========================================================

@router.get("/library/books")
async def list_books(search: Optional[str] = None, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    query = sb.table("library_books").select("*").eq("school_id", school_id)
    if search:
        query = query.ilike("title", f"%{search}%")
    books = (await query.order("title").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"books": books}}


@router.post("/library/books")
async def add_book(request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    if not request.get("title"):
        raise HTTPException(status_code=400, detail="title is required")
    copies = request.get("total_copies", 1)
    data = {
        "id": str(uuid.uuid4()), "school_id": school_id,
        "title": request["title"], "author": request.get("author"),
        "isbn": request.get("isbn"), "category": request.get("category"),
        "total_copies": copies, "available_copies": copies,
        "cover_url": request.get("cover_url"),
        "is_digital": request.get("is_digital", False),
        "digital_url": request.get("digital_url"),
        "created_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("library_books").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/library/books/{book_id}")
async def update_book(book_id: str, request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    allowed = {"title", "author", "isbn", "category", "total_copies", "available_copies", "cover_url", "is_digital", "digital_url"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("library_books").update(update_data).eq("id", book_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Book updated"}


@router.delete("/library/books/{book_id}")
async def delete_book(book_id: str, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("library_books").delete().eq("id", book_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Book removed"}


@router.post("/library/books/{book_id}/upload")
async def upload_book_pdf(
    book_id: str,
    file: UploadFile = File(...),
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id)
):
    """
    Upload a PDF for a digital library book.
    Saves the file to Supabase storage documents bucket and updates digital_url/is_digital.
    """
    import httpx
    from app.config import settings

    if not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported for digital books")

    file_bytes = await file.read()
    file_size = len(file_bytes)

    if file_size > 20 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 20 MB)")
    if file_size == 0:
        raise HTTPException(status_code=400, detail="Empty file")

    sb = get_supabase()
    # Check if book exists
    book_res = await sb.table("library_books").select("*").eq("id", book_id).eq("school_id", school_id).maybe_single().aexecute()
    if not book_res.data:
        raise HTTPException(status_code=404, detail="Book not found")

    extension = "pdf"
    # Store in standard format under the documents bucket
    storage_path = f"documents/{school_id}/library/{book_id}.{extension}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": file.content_type or "application/pdf",
        "x-upsert": "true",
    }

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            upload_response = await client.post(storage_url, headers=headers, content=file_bytes)
        
        if upload_response.status_code not in (200, 201):
            raise HTTPException(
                status_code=500,
                detail=f"Storage upload failed: {upload_response.text}"
            )
    except Exception as e:
        if isinstance(e, HTTPException):
            raise e
        raise HTTPException(status_code=500, detail=f"Storage upload request failed: {str(e)}")

    public_url_base = supabase_url.replace("http://kong:8000", "http://127.0.0.1:8000")
    file_url = f"{public_url_base}/storage/v1/object/public/{storage_path}"

    # Update book info
    update_res = await sb.table("library_books")\
        .update({
            "is_digital": True,
            "digital_url": file_url
        })\
        .eq("id", book_id)\
        .eq("school_id", school_id)\
        .aexecute()

    return {
        "success": True,
        "message": "PDF uploaded and book updated successfully",
        "data": update_res.data[0] if update_res.data else {}
    }


@router.get("/library/borrows")
async def list_borrows(
    status: Optional[str] = None,
    student_id: Optional[str] = None,
    returned: Optional[bool] = None,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id)
):
    sb = get_supabase()
    q = sb.table("library_borrows").select("*, library_books(*), profiles!student_id(full_name, email, class)").eq("school_id", school_id)
    if status:
        q = q.eq("status", status)
    if student_id:
        q = q.eq("student_id", student_id)
    if returned is not None:
        if returned:
            q = q.eq("status", "returned")
        else:
            q = q.neq("status", "returned")
    res = await q.order("borrowed_at", ascending=False).aexecute()
    return {
        "success": True,
        "school_id": school_id,
        "data": res.data or []
    }



@router.post("/library/borrows")
async def issue_book(request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    """Issue a book to a student."""
    sb = get_supabase()
    if not request.get("student_id") or not request.get("book_id"):
        raise HTTPException(status_code=400, detail="student_id and book_id are required")
    due_date = request.get("due_date")
    if not due_date:
        due_date = (datetime.utcnow() + timedelta(days=14)).date().isoformat()
    due_at = request.get("due_at") or (due_date + "T23:59:59Z")

    data = {
        "id": str(uuid.uuid4()), "school_id": school_id,
        "student_id": request["student_id"], "book_id": request["book_id"],
        "borrowed_at": datetime.utcnow().isoformat(),
        "due_date": due_date,
        "due_at": due_at,
        "is_returned": False,
    }
    await sb.table("library_borrows").insert(data).aexecute()
    # Decrement available copies
    try:
        book = (await sb.table("library_books").select("available_copies").eq("id", request["book_id"]).maybe_single().aexecute()).data
        if book and book.get("available_copies", 0) > 0:
            await sb.table("library_books").update({"available_copies": book["available_copies"] - 1}).eq("id", request["book_id"]).aexecute()
    except Exception:
        pass
    return {"success": True, "message": "Book issued successfully", "data": data}


@router.put("/library/borrows/{borrow_id}/return")
async def return_book(borrow_id: str, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    """Mark a book as returned."""
    sb = get_supabase()
    borrow = (await sb.table("library_borrows").select("book_id").eq("id", borrow_id).maybe_single().aexecute()).data
    await sb.table("library_borrows").update({
        "is_returned": True, "return_date": datetime.now().date().isoformat(),
    }).eq("id", borrow_id).eq("school_id", school_id).aexecute()
    if borrow:
        try:
            book = (await sb.table("library_books").select("available_copies").eq("id", borrow["book_id"]).maybe_single().aexecute()).data
            if book:
                await sb.table("library_books").update({"available_copies": book["available_copies"] + 1}).eq("id", borrow["book_id"]).aexecute()
        except Exception:
            pass
    return {"success": True, "message": "Book returned"}


# ===========================================================
# Achievements CRUD + Award
# ===========================================================

@router.get("/achievements")
async def list_achievements(user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    achievements = (await sb.table("achievements").select("*").eq("school_id", school_id).order("rarity").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"achievements": achievements}}


@router.post("/achievements")
async def create_achievement(request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    if not request.get("name"):
        raise HTTPException(status_code=400, detail="name is required")
    data = {
        "id": str(uuid.uuid4()), "school_id": school_id,
        "name": request["name"], "description": request.get("description", ""),
        "icon": request.get("icon", "🏆"),
        "rarity": request.get("rarity", "common"),
        "xp_reward": request.get("xp_reward", 100),
        "created_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("achievements").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/achievements/{achievement_id}")
async def update_achievement(achievement_id: str, request: dict, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    allowed = {"name", "description", "icon", "rarity", "xp_reward"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    await sb.table("achievements").update(update_data).eq("id", achievement_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Achievement updated"}


@router.delete("/achievements/{achievement_id}")
async def delete_achievement(achievement_id: str, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("achievements").delete().eq("id", achievement_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Achievement deleted"}


@router.post("/achievements/award")
async def award_achievement(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Award an achievement to one or more students.
    Body: {
        achievement_id, student_ids: [uuid, ...],
        target_classes: ['Class A']  -- optional, awards to all students in class
    }
    """
    sb = get_supabase()
    achievement_id = request.get("achievement_id")
    if not achievement_id:
        raise HTTPException(status_code=400, detail="achievement_id is required")

    student_ids = request.get("student_ids", [])
    target_classes = request.get("target_classes", [])
    all_recipients = await _resolve_recipients(sb, school_id, target_classes, student_ids)

    records = [
        {
            "id": str(uuid.uuid4()),
            "school_id": school_id,
            "student_id": sid,
            "achievement_id": achievement_id,
            "awarded_by": user["id"],
            "earned_at": datetime.utcnow().isoformat(),
        }
        for sid in all_recipients
    ]
    if records:
        # Ignore duplicates via on_conflict (matching the unique constraint on school_id, student_id, achievement_id)
        await sb.table("student_achievements").upsert(records, on_conflict="school_id,student_id,achievement_id").aexecute()

    # Notify
    achievement = (await sb.table("achievements").select("name, xp_reward, icon").eq("id", achievement_id).maybe_single().aexecute()).data
    if achievement and all_recipients:
        await _send_notifications(
            sb, school_id, all_recipients,
            title=f"{achievement['icon']} Achievement Unlocked: {achievement['name']}",
            body=f"You earned {achievement['xp_reward']} XP! 🎉",
            notification_type="achievement",
            reference_id=achievement_id,
            sender_id=user["id"],
        )
    return {"success": True, "message": f"Achievement awarded to {len(records)} students"}


# ===========================================================
# Leave Management (Admin approve/reject)
# ===========================================================

@router.get("/leave")
async def list_leave_applications(
    status: Optional[str] = None,
    applicant_role: Optional[str] = "student",
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("leave_applications").select("*, profiles!applicant_id(full_name, class, roll_number)").eq("school_id", school_id)
    if applicant_role:
        query = query.eq("applicant_role", applicant_role)
    if status and status.lower() != "all":
        query = query.eq("status", status)
    applications = (await query.order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"applications": applications}}


@router.put("/leave/{leave_id}/approve")
async def approve_leave(leave_id: str, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("leave_applications").update({
        "status": "approved",
        "reviewed_by": user["id"],
        "reviewed_at": datetime.utcnow().isoformat(),
    }).eq("id", leave_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Leave approved"}


@router.put("/leave/{leave_id}/reject")
async def reject_leave(leave_id: str, request: dict = {}, user=Depends(require_student_admin), school_id=Depends(require_school_id)):
    sb = get_supabase()
    await sb.table("leave_applications").update({
        "status": "rejected",
        "reviewed_by": user["id"],
        "reviewed_at": datetime.utcnow().isoformat(),
        "rejection_reason": request.get("reason", ""),
    }).eq("id", leave_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Leave rejected"}


# ===========================================================
# Notifications Broadcast
# ===========================================================

@router.post("/notifications/broadcast")
async def broadcast_notification(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Send a custom notification to class groups + individual students (+ parents).
    Body: {
        title, body, type,
        target_classes: ['Class A'], target_student_ids: ['uuid'],
        include_parents: true
    }
    """
    sb = get_supabase()
    if not request.get("title") or not request.get("body"):
        raise HTTPException(status_code=400, detail="title and body are required")

    target_classes = request.get("target_classes", [])
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)

    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if not recipients:
        return {"success": False, "message": "No recipients found"}

    await _send_notifications(
        sb, school_id, recipients,
        title=request["title"],
        body=request["body"],
        notification_type=request.get("type", "general"),
        sender_id=user["id"],
    )
    return {"success": True, "school_id": school_id, "data": {"recipients_notified": len(recipients)}}


# ===========================================================
# Universal Content Distribution Endpoint
# ===========================================================

@router.post("/distribute/content")
async def distribute_content(
    request: dict,
    user=Depends(require_student_admin),
    school_id=Depends(require_school_id),
):
    """Universal distribution endpoint.
    Share any existing content to specific classes + individual students (+ parents).

    Body: {
        content_type: "notice" | "material" | "homework" | "exam" | "event",
        content_id: "uuid-of-existing-record",
        target_classes: ["Class A", "Class B"],
        target_student_ids: ["ram-uuid", "syam-uuid"],
        include_parents: false,
        custom_title: "Optional override for notification title",
        custom_body: "Optional override for notification body"
    }
    """
    sb = get_supabase()
    content_type = request.get("content_type")
    content_id = request.get("content_id")

    if not content_type or not content_id:
        raise HTTPException(status_code=400, detail="content_type and content_id are required")

    valid_types = {"notice", "material", "homework", "exam", "event", "live_class", "notification"}
    if content_type not in valid_types:
        raise HTTPException(status_code=400, detail=f"Invalid content_type. Must be one of: {', '.join(valid_types)}")

    target_classes = request.get("target_classes", [])
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)

    if not target_classes and not target_student_ids:
        raise HTTPException(status_code=400, detail="Provide at least one of target_classes or target_student_ids")

    # Fetch content title for notification
    table_map = {
        "notice": "notices",
        "material": "study_materials",
        "homework": "homework",
        "exam": "exams",
        "event": "events",
        "live_class": "live_classes",
    }
    type_icons = {
        "notice": "📢", "material": "📁", "homework": "📝",
        "exam": "✍️", "event": "📅", "live_class": "🎥",
    }
    icon = type_icons.get(content_type, "📌")
    notif_title = request.get("custom_title", f"{icon} New {content_type.replace('_', ' ').title()} shared with you")
    notif_body = request.get("custom_body", f"New {content_type} is available. Open the app to view.")

    if not request.get("custom_title") and content_type in table_map:
        try:
            record = (await sb.table(table_map[content_type]).select("title").eq("id", content_id).maybe_single().aexecute()).data
            if record and record.get("title"):
                notif_title = f"{icon} {record['title']}"
        except Exception:
            pass

    # Resolve recipients
    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if not recipients:
        return {"success": False, "message": "No recipients found for the given target"}

    # Send notifications
    await _send_notifications(
        sb, school_id, recipients,
        title=notif_title,
        body=notif_body,
        notification_type=content_type,
        reference_id=content_id,
        sender_id=user["id"],
    )

    # Log to audit table
    await _log_distribution(
        sb, school_id, user["id"], content_type, content_id,
        target_classes, target_student_ids, include_parents, len(recipients),
    )

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "content_type": content_type,
            "content_id": content_id,
            "target_classes": target_classes,
            "individual_students": target_student_ids,
            "include_parents": include_parents,
            "recipients_notified": len(recipients),
        },
    }


# ============================================================================
# LIBRARY SYSTEM ENDPOINTS (LIBRARIAN/ISSUER ADMIN ROLE)
# ============================================================================




@router.put("/library/borrows/{borrow_id}/status")
async def admin_update_borrow_status(
    borrow_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
    student_admin=Depends(require_student_admin)
):
    new_status = request.get("status")
    if not new_status:
        raise HTTPException(status_code=400, detail="status is required")
        
    sb = get_supabase()
    
    # Fetch borrow
    borrow_res = await sb.table("library_borrows").select("*, library_books(*)").eq("id", borrow_id).eq("school_id", school_id).maybe_single().aexecute()
    borrow = borrow_res.data
    if not borrow:
        raise HTTPException(status_code=404, detail="Borrow record not found")
        
    book = borrow.get("library_books") or {}
    is_digital = book.get("is_digital", False)
    
    update_data = {"status": new_status}
    old_status = borrow.get("status")
    
    if new_status == "borrowed" and old_status == "requested":
        # Approving issue
        if not is_digital:
            available = book.get("available_copies", 0)
            if available <= 0:
                raise HTTPException(status_code=400, detail="No physical copies available to issue")
            await sb.table("library_books").update({"available_copies": max(0, available - 1)}).eq("id", book["id"]).aexecute()
            
        update_data["borrowed_at"] = datetime.now().isoformat()
        update_data["due_at"] = (datetime.now() + timedelta(days=14)).isoformat()
        
    elif new_status == "borrowed" and old_status == "pending_renew":
        # Approving renewal
        update_data["renewals_used"] = borrow.get("renewals_used", 0) + 1
        if borrow.get("due_at"):
            try:
                current_due = datetime.fromisoformat(borrow["due_at"].replace("Z", "+00:00"))
                new_due = current_due + timedelta(days=14)
                update_data["due_at"] = new_due.isoformat()
            except Exception:
                update_data["due_at"] = (datetime.now() + timedelta(days=14)).isoformat()
        else:
            update_data["due_at"] = (datetime.now() + timedelta(days=14)).isoformat()
            
    elif new_status == "returned" and old_status in ["borrowed", "pending_return", "pending_renew"]:
        # Approving return
        if not is_digital:
            available = book.get("available_copies", 0)
            total = book.get("total_copies", 1)
            await sb.table("library_books").update({"available_copies": min(total, available + 1)}).eq("id", book["id"]).aexecute()
            
        update_data["returned_at"] = datetime.now().isoformat()
        
        # Calculate fine dynamically if overdue
        if borrow.get("due_at"):
            try:
                due_dt = datetime.fromisoformat(borrow["due_at"].replace("Z", "+00:00"))
                now_dt = datetime.now()
                if now_dt > due_dt:
                    days_overdue = (now_dt - due_dt).days
                    if days_overdue > 0:
                        update_data["fine_amount"] = float(days_overdue * 5)
            except Exception:
                pass
                
    elif new_status == "rejected":
        pass
        
    res = await sb.table("library_borrows").update(update_data).eq("id", borrow_id).aexecute()
    return {
        "success": True,
        "message": f"Borrow status updated to {new_status}",
        "data": res.data[0]
    }


@router.get("/library/requests")
async def admin_get_library_requests(
    status: Optional[str] = None,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
    student_admin=Depends(require_student_admin)
):
    sb = get_supabase()
    q = sb.table("library_requests").select("*, profiles!student_id(full_name, email, class)").eq("school_id", school_id)
    if status:
        q = q.eq("status", status)
    res = await q.order("created_at", ascending=False).aexecute()
    return {
        "success": True,
        "school_id": school_id,
        "data": res.data or []
    }


@router.put("/library/requests/{request_id}/status")
async def admin_update_library_request_status(
    request_id: str,
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
    student_admin=Depends(require_student_admin)
):
    new_status = request.get("status")
    if new_status not in ["approved", "rejected"]:
        raise HTTPException(status_code=400, detail="status must be 'approved' or 'rejected'")
        
    sb = get_supabase()
    
    # Fetch request
    req_res = await sb.table("library_requests").select("*").eq("id", request_id).eq("school_id", school_id).maybe_single().aexecute()
    req = req_res.data
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
        
    res = await sb.table("library_requests").update({"status": new_status}).eq("id", request_id).aexecute()
    
    # Custom premium feature: if approved, automatically insert the book into library_books!
    if new_status == "approved":
        try:
            book_data = {
                "school_id": school_id,
                "title": req["title"],
                "author": req["author"],
                "isbn": req.get("isbn") or "",
                "category": "New Acquisition",
                "shelf_location": "A-1 (Acquisition)",
                "total_copies": 1,
                "available_copies": 1,
                "is_digital": False
            }
            await sb.table("library_books").insert(book_data).aexecute()
        except Exception as e:
            print(f"Failed to auto-insert approved book: {str(e)}", flush=True)

    return {
        "success": True,
        "message": f"Request status updated to {new_status}",
        "data": res.data[0]
    }

