"""
teachers_admin.py — Teacher Admin CRUD API
==========================================
Accessible by roles: admin, teacher_admin

Covers:
  - Teachers management (list, create, update, deactivate)
  - Homework CRUD (with distribution targeting)
  - Exams CRUD (admin-level)
  - Notices CRUD (with distribution)
  - Study Materials CRUD (with distribution)
  - Live Classes CRUD (schedule, update, cancel, end)
  - Salary / Payslips CRUD
  - Timetable CRUD (teacher perspective)
  - Leave management (approve / reject)
  - Grading Policies CRUD
  - Content Distribution for teacher-generated content
"""

from fastapi import APIRouter, Depends, HTTPException
from typing import Optional, List
from datetime import datetime
import uuid
import asyncio

from app.middleware.auth import (
    get_current_user,
    require_school_id,
    require_teacher_admin,
)
from app.services.supabase_client import get_supabase

router = APIRouter()


# ===========================================================
# Shared helpers (re-declared here to keep modules independent)
# ===========================================================

async def _resolve_recipients(
    sb,
    school_id: str,
    target_classes: Optional[List[str]],
    target_student_ids: Optional[List[str]],
    include_parents: bool = False,
) -> List[str]:
    """Resolve deduplicated list of user IDs from class groups + individuals."""
    user_ids: set = set()
    if target_classes:
        res = await sb.table("profiles").select("id").eq("school_id", school_id).eq("role", "student").in_("class", target_classes).aexecute()
        for row in (res.data or []):
            user_ids.add(row["id"])
    for sid in (target_student_ids or []):
        user_ids.add(sid)
    if include_parents and user_ids:
        parent_res = await sb.table("profiles").select("id").eq("school_id", school_id).eq("role", "parent").in_("student_id", list(user_ids)).aexecute()
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
    for i in range(0, len(records), 500):
        await sb.table("notifications").insert(records[i: i + 500]).aexecute()


async def _log_distribution(sb, school_id, sender_id, content_type, content_id, target_classes, target_student_ids, include_parents, recipient_count):
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
# Teachers Management
# ===========================================================

@router.get("/list")
async def list_teachers(
    search: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """List all teacher profiles."""
    sb = get_supabase()
    query = (
        sb.table("profiles")
        .select("id, full_name, email, phone, role, avatar_url, qualification, specialization, experience_years, joining_date, bio")
        .eq("school_id", school_id)
        .eq("role", "teacher")
    )
    if search:
        query = query.ilike("full_name", f"%{search}%")
    teachers = (await query.order("full_name").limit(limit).offset(offset).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"teachers": teachers, "count": len(teachers)}}


@router.post("/create")
async def create_teacher(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Create a new teacher profile."""
    sb = get_supabase()
    if not request.get("full_name"):
        raise HTTPException(status_code=400, detail="full_name is required")
    data = {
        "id": request.get("id", str(uuid.uuid4())),
        "school_id": school_id,
        "full_name": request["full_name"],
        "role": "teacher",
        "email": request.get("email"),
        "phone": request.get("phone"),
        "gender": request.get("gender"),
        "date_of_birth": request.get("date_of_birth"),
        "blood_group": request.get("blood_group"),
        "address": request.get("address"),
        "qualification": request.get("qualification"),
        "specialization": request.get("specialization"),
        "experience_years": request.get("experience_years"),
        "joining_date": request.get("joining_date"),
        "bio": request.get("bio"),
        "created_at": datetime.utcnow().isoformat(),
        "updated_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("profiles").insert(data).aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/{teacher_id}")
async def update_teacher(
    teacher_id: str,
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Update teacher profile (admin can change all fields)."""
    sb = get_supabase()
    allowed = {
        "full_name", "email", "phone", "gender", "date_of_birth", "blood_group",
        "address", "qualification", "specialization", "experience_years",
        "joining_date", "bio", "avatar_url", "role",
    }
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    update_data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("profiles").update(update_data).eq("id", teacher_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Teacher profile updated"}


@router.delete("/{teacher_id}")
async def deactivate_teacher(
    teacher_id: str,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Soft-deactivate a teacher."""
    sb = get_supabase()
    await sb.table("profiles").update({"is_active": False, "updated_at": datetime.utcnow().isoformat()}).eq(
        "id", teacher_id
    ).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Teacher deactivated"}


@router.post("/{teacher_id}/assign-classes")
async def assign_classes(
    teacher_id: str,
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Assign classes to a teacher by ensuring they have at least one timetable entry for each class."""
    sb = get_supabase()
    classes = request.get("classes", [])
    if not classes:
        raise HTTPException(status_code=400, detail="Classes list is required")
    
    # Verify teacher exists
    teacher_res = await sb.table("profiles").select("id").eq("id", teacher_id).eq("role", "teacher").eq("school_id", school_id).aexecute()
    if not teacher_res.data:
        raise HTTPException(status_code=404, detail="Teacher not found")

    assigned = []
    for cls in classes:
        # Check if already exists in timetable
        exist_res = await sb.table("timetable").select("id").eq("school_id", school_id).eq("teacher_id", teacher_id).eq("class", cls).aexecute()
        if not exist_res.data:
            # Find a subject for this class, or default to None
            sub_res = await sb.table("subjects").select("id").eq("school_id", school_id).eq("class", cls).limit(1).aexecute()
            subject_id = sub_res.data[0]["id"] if sub_res.data else None
            
            # Insert a dummy slot for Monday 9:00 - 10:00
            insert_data = {
                "school_id": school_id,
                "teacher_id": teacher_id,
                "subject_id": subject_id,
                "class": cls,
                "day_of_week": 1,
                "start_time": "09:00:00",
                "end_time": "10:00:00",
                "room": "Interactive Room"
            }
            await sb.table("timetable").insert(insert_data).aexecute()
            assigned.append(cls)
            
    return {"success": True, "message": f"Successfully assigned classes: {assigned}"}


# ===========================================================
# Homework CRUD (Admin)
# ===========================================================

@router.get("/homework")
async def list_homework(
    status: Optional[str] = None,
    class_name: Optional[str] = None,
    teacher_id: Optional[str] = None,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("homework").select("*, subjects(name, icon), profiles!teacher_id(full_name)").eq("school_id", school_id)
    if status and status.lower() != "all":
        query = query.eq("status", status)
    if class_name:
        query = query.eq("class", class_name)
    if teacher_id:
        query = query.eq("teacher_id", teacher_id)
    homework = (await query.order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"homework": homework}}


@router.post("/homework")
async def create_homework(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Create homework with flexible class + individual student distribution.
    Body: {
        subject_id, title, description, due_date, max_marks,
        target_class: "Class A"          -- primary class (stored in DB)
        target_classes: ["A", "B"],      -- for notification distribution
        target_student_ids: ["uuid"],    -- individual students (e.g. Ram, Syam)
        include_parents: true,
        teacher_id: "uuid"               -- optional override (admin assigns on behalf)
    }
    """
    sb = get_supabase()
    required = ["subject_id", "title", "due_date"]
    for f in required:
        if not request.get(f):
            raise HTTPException(status_code=400, detail=f"Missing: {f}")

    teacher_id = request.get("teacher_id", user["id"])
    target_classes = request.get("target_classes", [])
    if request.get("target_class") and request["target_class"] not in target_classes:
        target_classes = [request["target_class"]] + target_classes
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)

    hw_id = str(uuid.uuid4())
    data = {
        "id": hw_id,
        "school_id": school_id,
        "subject_id": request["subject_id"],
        "teacher_id": teacher_id,
        "title": request["title"],
        "description": request.get("description", ""),
        "due_date": request["due_date"],
        "max_marks": request.get("max_marks", 25),
        "class": request.get("target_class", target_classes[0] if target_classes else ""),
        "target_student_ids": target_student_ids or None,
        "status": "active",
        "created_at": datetime.utcnow().isoformat(),
    }
    await sb.table("homework").insert(data).aexecute()

    # Distribute notifications
    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if recipients:
        await _send_notifications(
            sb, school_id, recipients,
            title=f"📝 New Homework: {data['title']}",
            body=f"Due: {data['due_date']}. Check your homework section.",
            notification_type="homework",
            reference_id=hw_id,
            sender_id=user["id"],
        )
    await _log_distribution(sb, school_id, user["id"], "homework", hw_id, target_classes, target_student_ids, include_parents, len(recipients))

    return {
        "success": True, "school_id": school_id,
        "data": {"homework_id": hw_id, "recipients_notified": len(recipients)},
    }


@router.put("/homework/{homework_id}")
async def update_homework(
    homework_id: str,
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"title", "description", "due_date", "max_marks", "status", "class"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("homework").update(update_data).eq("id", homework_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Homework updated"}


@router.delete("/homework/{homework_id}")
async def delete_homework(
    homework_id: str,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("homework").delete().eq("id", homework_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Homework deleted"}


# ===========================================================
# Exams CRUD (Teacher-Admin)
# ===========================================================

@router.get("/exams")
async def list_exams(
    exam_type: Optional[str] = None,
    teacher_id: Optional[str] = None,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("exams").select("*, subjects(name, class, icon), profiles!teacher_id(full_name)").eq("school_id", school_id)
    if exam_type and exam_type.lower() != "all":
        query = query.eq("exam_type", exam_type)
    if teacher_id:
        query = query.eq("teacher_id", teacher_id)
    exams = (await query.order("start_time", ascending=False).aexecute()).data
    for e in exams:
        subj = e.get("subjects") or {}
        e["subject"] = subj.get("name", "Unknown")
        if not e.get("class"):
            e["class"] = subj.get("class", "Unknown")
        if not e.get("exam_date"):
            e["exam_date"] = e.get("start_time")
        e["duration"] = str(e.get("duration_minutes", 0)) + " mins"
    return {"success": True, "school_id": school_id, "data": {"exams": exams}}


@router.post("/exams")
async def create_exam(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Create exam with class + individual targeting."""
    sb = get_supabase()
    required = ["subject_id", "title"]
    for f in required:
        if not request.get(f):
            raise HTTPException(status_code=400, detail=f"Missing: {f}")

    exam_id = str(uuid.uuid4())
    teacher_id = request.get("teacher_id", user["id"])
    target_classes = request.get("target_classes", [])
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)

    data = {
        "id": exam_id,
        "school_id": school_id,
        "subject_id": request["subject_id"],
        "teacher_id": teacher_id,
        "title": request["title"],
        "exam_type": request.get("exam_type", "offline"),
        "exam_category": request.get("exam_category"),
        "exam_date": request.get("exam_date"),
        "start_time": request.get("start_time"),
        "duration_minutes": request.get("duration_minutes", 90),
        "total_marks": request.get("total_marks", 100),
        "venue": request.get("venue"),
        "target_classes": target_classes,
        "status": "upcoming",
        "created_at": datetime.utcnow().isoformat(),
    }
    await sb.table("exams").insert(data).aexecute()

    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if recipients:
        await _send_notifications(
            sb, school_id, recipients,
            title=f"📝 Exam Scheduled: {data['title']}",
            body=f"Exam date: {data.get('exam_date', 'TBD')}. Check your exam section.",
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
    user=Depends(require_teacher_admin),
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
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("exams").delete().eq("id", exam_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Exam deleted"}


# ===========================================================
# Notices CRUD (Teacher-Admin, with distribution)
# ===========================================================

@router.get("/notices")
async def list_notices(
    category: Optional[str] = None,
    status: Optional[str] = None,
    user=Depends(require_teacher_admin),
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
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Create a notice and distribute to class groups + individual students + parents.
    Body: {
        title, content, category, is_urgent,
        target_classes: ["Class A", "Class B"],
        target_student_ids: ["uuid1", "uuid2"],
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

    notice_id = str(uuid.uuid4())
    data = {
        "id": notice_id,
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
    await sb.table("notices").insert(data).aexecute()

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
    user=Depends(require_teacher_admin),
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
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("notices").delete().eq("id", notice_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Notice deleted"}


# ===========================================================
# Study Materials CRUD (with distribution)
# ===========================================================

@router.get("/materials")
async def list_materials(
    material_type: Optional[str] = None,
    teacher_id: Optional[str] = None,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("study_materials").select("*, profiles!teacher_id(full_name)").eq("school_id", school_id)
    if material_type and material_type.lower() != "all":
        query = query.eq("material_type", material_type)
    if teacher_id:
        query = query.eq("teacher_id", teacher_id)
    materials = (await query.order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"materials": materials}}


@router.post("/materials")
async def create_material(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Upload/create study material and distribute to class groups + individual students + parents.
    Body: {
        title, description, material_type, attachment_urls,
        teacher_id: "uuid",               -- optional override
        target_class: "Class A",          -- primary class
        target_classes: ["A", "B"],       -- for multi-class notification
        target_student_ids: ["uuid"],     -- e.g. Ram, Syam outside these classes
        include_parents: true
    }
    """
    sb = get_supabase()
    if not request.get("title") or not request.get("material_type"):
        raise HTTPException(status_code=400, detail="title and material_type are required")

    teacher_id = request.get("teacher_id", user["id"])
    target_classes = request.get("target_classes", [])
    if request.get("target_class") and request["target_class"] not in target_classes:
        target_classes = [request["target_class"]] + target_classes
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)

    material_id = str(uuid.uuid4())
    data = {
        "id": material_id,
        "school_id": school_id,
        "teacher_id": teacher_id,
        "title": request["title"],
        "description": request.get("description", ""),
        "material_type": request["material_type"],
        "target_class": request.get("target_class", target_classes[0] if target_classes else ""),
        "target_classes": target_classes or None,
        "target_student_ids": target_student_ids or None,
        "attachment_urls": request.get("attachment_urls"),
        "created_at": datetime.utcnow().isoformat(),
    }
    await sb.table("study_materials").insert(data).aexecute()

    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if recipients:
        await _send_notifications(
            sb, school_id, recipients,
            title=f"📁 New Material: {data['title']}",
            body=f"New {data['material_type']} material shared. Open the app to access it.",
            notification_type="material",
            reference_id=material_id,
            sender_id=user["id"],
        )
    await _log_distribution(sb, school_id, user["id"], "material", material_id, target_classes, target_student_ids, include_parents, len(recipients))

    return {
        "success": True, "school_id": school_id,
        "data": {"material_id": material_id, "recipients_notified": len(recipients)},
    }


@router.put("/materials/{material_id}")
async def update_material(
    material_id: str,
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"title", "description", "material_type", "attachment_urls", "target_class"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("study_materials").update(update_data).eq("id", material_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Material updated"}


@router.delete("/materials/{material_id}")
async def delete_material(
    material_id: str,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("study_materials").delete().eq("id", material_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Material deleted"}


# ===========================================================
# Live Classes CRUD
# ===========================================================

@router.get("/live-classes")
async def list_live_classes(
    status: Optional[str] = None,
    teacher_id: Optional[str] = None,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("live_classes").select("*, subjects(name, icon), profiles!teacher_id(full_name)").eq("school_id", school_id)
    if status:
        query = query.eq("status", status)
    if teacher_id:
        query = query.eq("teacher_id", teacher_id)
    classes = (await query.order("scheduled_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"live_classes": classes}}


@router.post("/live-classes")
async def schedule_live_class(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Schedule a live class with distribution.
    Body: {
        subject_id, title, scheduled_at, duration_minutes, teacher_id,
        target_class, target_classes, target_student_ids, include_parents,
        meeting_url
    }
    """
    sb = get_supabase()
    if not request.get("title") or not request.get("subject_id"):
        raise HTTPException(status_code=400, detail="title and subject_id are required")

    teacher_id = request.get("teacher_id", user["id"])
    target_classes = request.get("target_classes", [])
    if request.get("target_class") and request["target_class"] not in target_classes:
        target_classes = [request["target_class"]] + target_classes
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)

    lc_id = str(uuid.uuid4())
    data = {
        "id": lc_id,
        "school_id": school_id,
        "teacher_id": teacher_id,
        "subject_id": request["subject_id"],
        "title": request["title"],
        "scheduled_at": request.get("scheduled_at", datetime.utcnow().isoformat()),
        "duration_minutes": request.get("duration_minutes", 60),
        "target_class": request.get("target_class", target_classes[0] if target_classes else ""),
        "meeting_link": request.get("meeting_url") or request.get("meeting_link"),
        "status": request.get("status", "scheduled"),
        "is_live": request.get("status") == "live",
        "created_at": datetime.utcnow().isoformat(),
    }
    await sb.table("live_classes").insert(data).aexecute()

    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if recipients:
        await _send_notifications(
            sb, school_id, recipients,
            title=f"🎥 Live Class: {data['title']}",
            body=f"Scheduled at {data['scheduled_at'][:16].replace('T', ' ')}. Don't miss it!",
            notification_type="live_class",
            reference_id=lc_id,
            sender_id=user["id"],
        )
    await _log_distribution(sb, school_id, user["id"], "live_class", lc_id, target_classes, target_student_ids, include_parents, len(recipients))

    return {"success": True, "school_id": school_id, "data": {"live_class_id": lc_id, "recipients_notified": len(recipients)}}


@router.put("/live-classes/{live_class_id}")
async def update_live_class(
    live_class_id: str,
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"title", "scheduled_at", "duration_minutes", "meeting_url", "meeting_link", "status", "is_live", "target_class"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if "meeting_url" in update_data:
        update_data["meeting_link"] = update_data.pop("meeting_url")
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    await sb.table("live_classes").update(update_data).eq("id", live_class_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Live class updated"}


@router.put("/live-classes/{live_class_id}/end")
async def end_live_class(
    live_class_id: str,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """End an ongoing live class."""
    sb = get_supabase()
    await sb.table("live_classes").update({
        "status": "ended", "is_live": False,
        "ended_at": datetime.utcnow().isoformat(),
    }).eq("id", live_class_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Live class ended"}


@router.delete("/live-classes/{live_class_id}")
async def delete_live_class(
    live_class_id: str,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    
    # 1. Clean up physical recording files from MinIO
    try:
        from app.services.minio_client import delete_live_class_recordings_from_storage
        await delete_live_class_recordings_from_storage(sb, live_class_id)
    except Exception as e:
        print(f"[Cleanup] Error in admin delete_live_class recordings cleanup: {e}")
        
    # 2. Delete class from database
    await sb.table("live_classes").delete().eq("id", live_class_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Live class cancelled"}


# ===========================================================
# Salary / Payslips CRUD
# ===========================================================

@router.get("/salary")
async def list_salary(
    teacher_id: Optional[str] = None,
    month: Optional[str] = None,
    status: Optional[str] = None,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("salary").select("*, profiles!teacher_id(full_name, email)").eq("school_id", school_id)
    if teacher_id:
        query = query.eq("teacher_id", teacher_id)
    if month:
        query = query.eq("month", month)
    if status:
        query = query.eq("status", status)
    salary = (await query.order("month", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"salary": salary}}


@router.post("/salary")
async def create_salary(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Create salary payslip for one or more teachers.
    Body: {
        teacher_id?: "uuid",           -- single teacher
        teacher_ids?: ["uuid", ...],   -- bulk (all must be provided)
        month: "2026-05",
        basic_pay, allowances, deductions, net_pay, status, remarks
    }
    """
    sb = get_supabase()
    if not request.get("month"):
        raise HTTPException(status_code=400, detail="month is required (format: YYYY-MM)")

    teacher_ids = request.get("teacher_ids", [])
    if request.get("teacher_id"):
        teacher_ids = [request["teacher_id"]] + teacher_ids
    if not teacher_ids:
        raise HTTPException(status_code=400, detail="Provide teacher_id or teacher_ids")

    month_val = int(request["month"].split("-")[1])
    year_val = int(request["month"].split("-")[0])
    amount_val = float(request.get("net_pay", 0))
    if amount_val == 0:
        amount_val = float(request.get("basic_pay", 0)) + float(request.get("allowances", 0)) - float(request.get("deductions", 0))

    # Fetch existing payslips to retrieve their IDs for a clean single-key upsert
    existing_res = await sb.table("salary").select("id, teacher_id").eq("school_id", school_id).eq("month_str", request["month"]).in_("teacher_id", teacher_ids).aexecute()
    existing_map = {row["teacher_id"]: row["id"] for row in (existing_res.data or [])}

    records = []
    for tid in teacher_ids:
        rec_id = existing_map.get(tid) or str(uuid.uuid4())
        records.append({
            "id": rec_id,
            "school_id": school_id,
            "teacher_id": tid,
            "month": month_val,
            "year": year_val,
            "month_str": request["month"],
            "amount": amount_val,
            "basic_pay": request.get("basic_pay", 0),
            "allowances": request.get("allowances", 0),
            "deductions": request.get("deductions", 0),
            "net_pay": request.get("net_pay", amount_val),
            "status": request.get("status", "unpaid"),
            "remarks": request.get("remarks", ""),
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat(),
        })

    await sb.table("salary").upsert(records).aexecute()

    # Notify teachers
    await _send_notifications(
        sb, school_id, teacher_ids,
        title=f"💰 Salary Slip: {request['month']}",
        body=f"Your salary slip for {request['month']} is now available.",
        notification_type="salary",
        sender_id=user["id"],
    )
    return {"success": True, "school_id": school_id, "message": f"Created {len(records)} payslips", "data": {"count": len(records), "id": records[0]["id"]}}


@router.put("/salary/{salary_id}")
async def update_salary(
    salary_id: str,
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"basic_pay", "allowances", "deductions", "net_pay", "status", "remarks", "paid_at"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")
    if "net_pay" in update_data:
        update_data["amount"] = update_data["net_pay"]
    update_data["updated_at"] = datetime.utcnow().isoformat()
    if update_data.get("status") == "paid" and not update_data.get("paid_at"):
        update_data["paid_at"] = datetime.utcnow().isoformat()
    await sb.table("salary").update(update_data).eq("id", salary_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Salary record updated"}


@router.delete("/salary/{salary_id}")
async def delete_salary(
    salary_id: str,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("salary").delete().eq("id", salary_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Salary record deleted"}


# ===========================================================
# Timetable CRUD (Teacher-Admin)
# ===========================================================

@router.get("/timetable")
async def list_timetable(
    teacher_id: Optional[str] = None,
    class_name: Optional[str] = None,
    day_of_week: Optional[int] = None,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("timetable").select("*, subjects(name, icon, color), profiles!teacher_id(full_name)").eq("school_id", school_id)
    if teacher_id:
        query = query.eq("teacher_id", teacher_id)
    if class_name:
        query = query.eq("class", class_name)
    if day_of_week is not None:
        query = query.eq("day_of_week", day_of_week)
    slots = (await query.order("day_of_week").order("start_time").aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"timetable": slots}}


@router.post("/timetable")
async def create_timetable_slot(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    required = ["class", "subject_id", "teacher_id", "day_of_week", "start_time", "end_time"]
    for f in required:
        if request.get(f) is None:
            raise HTTPException(status_code=400, detail=f"Missing: {f}")
    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "class": request["class"],
        "subject_id": request["subject_id"],
        "teacher_id": request["teacher_id"],
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
    user=Depends(require_teacher_admin),
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
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("timetable").delete().eq("id", slot_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Timetable slot deleted"}


# ===========================================================
# Leave Management (Admin approve/reject for teachers)
# ===========================================================

@router.get("/leave")
async def list_leave_applications(
    status: Optional[str] = None,
    teacher_id: Optional[str] = None,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("leave_applications").select("*, profiles!applicant_id(full_name, email)").eq("school_id", school_id).eq("applicant_role", "teacher")
    if teacher_id:
        query = query.eq("applicant_id", teacher_id)
    if status and status.lower() != "all":
        query = query.eq("status", status)
    applications = (await query.order("created_at", ascending=False).aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"applications": applications}}


@router.put("/leave/{leave_id}/approve")
async def approve_leave(
    leave_id: str,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("leave_applications").update({
        "status": "approved",
        "reviewed_by": user["id"],
        "reviewed_at": datetime.utcnow().isoformat(),
    }).eq("id", leave_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Leave approved"}


@router.put("/leave/{leave_id}/reject")
async def reject_leave(
    leave_id: str,
    request: dict = {},
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    await sb.table("leave_applications").update({
        "status": "rejected",
        "reviewed_by": user["id"],
        "reviewed_at": datetime.utcnow().isoformat(),
        "rejection_reason": request.get("reason", ""),
    }).eq("id", leave_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Leave rejected"}


# ===========================================================
# Grading Policies CRUD
# ===========================================================

@router.get("/grading-config")
async def list_grading_config(
    class_name: Optional[str] = None,
    subject_id: Optional[str] = None,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("grading_policies").select("*, subjects(name), profiles!teacher_id(full_name)").eq("school_id", school_id)
    if class_name:
        query = query.eq("class", class_name)
    if subject_id:
        query = query.eq("subject_id", subject_id)
    configs = (await query.aexecute()).data
    return {"success": True, "school_id": school_id, "data": {"configs": configs}}


@router.post("/grading-config")
async def create_grading_config(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    data = {
        "id": str(uuid.uuid4()),
        "school_id": school_id,
        "teacher_id": request.get("teacher_id", user["id"]),
        "class": request.get("class_name"),
        "subject_id": request.get("subject_id"),
        "mid_term_weight": request.get("mid_term_weight", 30),
        "final_term_weight": request.get("final_term_weight", 40),
        "attendance_weight": request.get("attendance_weight", 5),
        "assignment_weight": request.get("assignment_weight", 10),
        "class_test_weight": request.get("class_test_weight", 10),
        "lab_weight": request.get("lab_weight", 5),
        "updated_at": datetime.utcnow().isoformat(),
    }
    result = await sb.table("grading_policies").upsert(data, on_conflict="school_id,class,subject_id").aexecute()
    return {"success": True, "school_id": school_id, "data": result.data[0] if result.data else data}


@router.put("/grading-config/{config_id}")
async def update_grading_config(
    config_id: str,
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    allowed = {"mid_term_weight", "final_term_weight", "attendance_weight", "assignment_weight", "class_test_weight", "lab_weight"}
    update_data = {k: v for k, v in request.items() if k in allowed}
    update_data["updated_at"] = datetime.utcnow().isoformat()
    await sb.table("grading_policies").update(update_data).eq("id", config_id).eq("school_id", school_id).aexecute()
    return {"success": True, "message": "Grading config updated"}


# ===========================================================
# Content Distribution (Teacher-Admin version)
# ===========================================================

@router.post("/distribute/content")
async def distribute_content(
    request: dict,
    user=Depends(require_teacher_admin),
    school_id=Depends(require_school_id),
):
    """Distribute existing teacher-generated content to class groups + individuals + parents.
    Same interface as students_admin distribute endpoint.

    Body: {
        content_type: "notice" | "material" | "homework" | "exam" | "live_class",
        content_id: "uuid",
        target_classes: ["Class A", "Class B"],
        target_student_ids: ["ram-uuid", "syam-uuid"],
        include_parents: true,
        custom_title: "...",
        custom_body: "..."
    }
    """
    sb = get_supabase()
    content_type = request.get("content_type")
    content_id = request.get("content_id")

    if not content_type or not content_id:
        raise HTTPException(status_code=400, detail="content_type and content_id are required")

    valid_types = {"notice", "material", "homework", "exam", "live_class", "event", "notification"}
    if content_type not in valid_types:
        raise HTTPException(status_code=400, detail=f"Invalid content_type. Must be one of: {', '.join(valid_types)}")

    target_classes = request.get("target_classes", [])
    target_student_ids = request.get("target_student_ids", [])
    include_parents = request.get("include_parents", False)

    if not target_classes and not target_student_ids:
        raise HTTPException(status_code=400, detail="Provide at least one of target_classes or target_student_ids")

    # Fetch content record title
    table_map = {
        "notice": "notices", "material": "study_materials", "homework": "homework",
        "exam": "exams", "event": "events", "live_class": "live_classes",
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

    recipients = await _resolve_recipients(sb, school_id, target_classes, target_student_ids, include_parents)
    if not recipients:
        return {"success": False, "message": "No recipients found for the given target"}

    await _send_notifications(
        sb, school_id, recipients,
        title=notif_title, body=notif_body,
        notification_type=content_type,
        reference_id=content_id, sender_id=user["id"],
    )
    await _log_distribution(
        sb, school_id, user["id"], content_type, content_id,
        target_classes, target_student_ids, include_parents, len(recipients),
    )

    return {
        "success": True, "school_id": school_id,
        "data": {
            "content_type": content_type, "content_id": content_id,
            "target_classes": target_classes, "individual_students": target_student_ids,
            "include_parents": include_parents, "recipients_notified": len(recipients),
        },
    }
