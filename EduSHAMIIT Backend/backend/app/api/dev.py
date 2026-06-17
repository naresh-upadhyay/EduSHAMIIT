"""
EduSHAMIIT Developer Endpoints
===============================
Protected dev-only routes for seeding data, promoting roles, and profile stat updates.
All endpoints require the X-Dev-Secret header.
"""
from fastapi import APIRouter, HTTPException, Header
from app.services.supabase_client import get_supabase
from typing import Optional

router = APIRouter()

_DEV_SECRET = "eduSHAMIIT-dev-seed-2026"


def _require_secret(secret: Optional[str]):
    if secret != _DEV_SECRET:
        raise HTTPException(status_code=403, detail="Invalid or missing dev secret")


# ─── Role Promotion ────────────────────────────────────────────────────────────

@router.post("/promote")
async def promote_user(request: dict):
    """
    Promote a user to a specific role.
    Body: { "secret": "...", "email": "user@example.com", "role": "student_admin" }
    Valid roles: student, teacher, student_admin, teacher_admin
    """
    _require_secret(request.get("secret"))

    email = request.get("email")
    role = request.get("role")
    if not email or not role:
        raise HTTPException(status_code=400, detail="email and role are required")

    valid_roles = ["student", "teacher", "student_admin", "teacher_admin"]
    if role not in valid_roles:
        raise HTTPException(status_code=400, detail=f"role must be one of: {valid_roles}")

    sb = get_supabase()
    res = await sb.table("profiles").update({"role": role}).eq("email", email).aexecute()
    if not res.data:
        raise HTTPException(status_code=404, detail=f"No profile found for email: {email}")

    return {"success": True, "data": {"email": email, "role": role}}


# ─── Profile Stats Update ──────────────────────────────────────────────────────

@router.patch("/profiles/{profile_id}/stats")
async def update_profile_stats(profile_id: str, request: dict):
    """
    Update profile stats/fields (xp, streak, roll_number, etc.).
    Body: { "secret": "...", "xp_points": 2500, "learning_streak": 18, ... }
    """
    _require_secret(request.get("secret"))

    allowed = {
        "xp_points", "learning_streak", "best_streak", "roll_number",
        "session", "admission_number", "phone", "address", "nationality",
        "religion", "gender", "date_of_birth", "bio", "specialization",
        "full_name", "class", "avatar_url",
    }
    update_data = {k: v for k, v in request.items() if k in allowed}
    if not update_data:
        raise HTTPException(status_code=400, detail="No valid fields provided")

    sb = get_supabase()
    res = await sb.table("profiles").update(update_data).eq("id", profile_id).aexecute()
    return {"success": True, "data": res.data[0] if res.data else {}}


# ─── Seed Cleanup ─────────────────────────────────────────────────────────────

@router.delete("/seed-cleanup")
async def seed_cleanup(request: dict):
    """
    Delete seeded data for given user/class sets.
    Body: {
        "secret": "...",
        "school_id": "...",
        "student_ids": [...],
        "teacher_ids": [...],
        "classes": ["10A", "10B", "11A"],
        "delete_users": [{"email": "..."}]   # optional: also delete these auth accounts
    }
    """
    _require_secret(request.get("secret"))

    sb = get_supabase()
    school_id = request.get("school_id", "")
    student_ids: list = request.get("student_ids", [])
    teacher_ids: list = request.get("teacher_ids", [])
    classes: list = request.get("classes", [])

    async def safe_delete(table, **filters):
        try:
            q = sb.table(table).delete()
            for k, v in filters.items():
                if isinstance(v, list):
                    q = q.in_(k, v)
                else:
                    q = q.eq(k, v)
            await q.aexecute()
        except Exception:
            pass

    all_user_ids = student_ids + teacher_ids

    # School-level transport cleanup
    if school_id:
        await safe_delete("student_transport", school_id=school_id)
        await safe_delete("bus_locations", school_id=school_id)
        await safe_delete("bus_stops", school_id=school_id)
        await safe_delete("bus_routes", school_id=school_id)

    # Student-linked tables
    for sid in student_ids:
        await safe_delete("results", student_id=sid)
        await safe_delete("attendance", student_id=sid)
        await safe_delete("fees", student_id=sid)
        await safe_delete("library_borrows", student_id=sid)
        await safe_delete("student_achievements", student_id=sid)
        await safe_delete("homework_submissions", student_id=sid)
        await safe_delete("student_transport", student_id=sid)

    # Teacher-linked tables
    for tid in teacher_ids:
        await safe_delete("salary", teacher_id=tid)

    # All users
    for uid in all_user_ids:
        await safe_delete("leave_applications", applicant_id=uid)
        await safe_delete("notifications", user_id=uid)

    # Class-level tables
    for cls in classes:
        await safe_delete("timetable", class_=cls)
        await safe_delete("homework", target_class=cls)
        await safe_delete("live_classes", target_class=cls)
        await safe_delete("study_materials", target_class=cls)
        await safe_delete("grading_policies", class_name=cls)
        await safe_delete("fees", target_class=cls)
        # Get subjects for class then delete their courses/exams
        subj_res = await sb.table("subjects").select("id").eq("school_id", school_id).eq("class", cls).aexecute()
        for s in (subj_res.data or []):
            sid2 = s["id"]
            await safe_delete("courses", subject_id=sid2)
            # Exams for this subject
            exam_res = await sb.table("exams").select("id").eq("subject_id", sid2).aexecute()
            for ex in (exam_res.data or []):
                await safe_delete("exam_questions", exam_id=ex["id"])
                await safe_delete("exam_submissions", exam_id=ex["id"])
                await safe_delete("exam_sessions", exam_id=ex["id"])
            await safe_delete("exams", subject_id=sid2)
        await safe_delete("subjects", class_=cls)

    # Notices/Events created by these users
    for uid in all_user_ids:
        await safe_delete("notices", created_by=uid)
        await safe_delete("events", created_by=uid)

    # Question bank
    for tid in teacher_ids:
        await safe_delete("question_bank", teacher_id=tid)

    return {"success": True, "message": "Seed data cleaned up"}
