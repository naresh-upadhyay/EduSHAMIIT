"""
EduSHAMIIT AI Tools - All 40+ tools for Shami AI assistant.
Role-based tool filtering ensures users only access tools they're authorized for.
"""
from app.tools.student_tools import get_student_tools
from app.tools.teacher_tools import get_teacher_tools
from app.tools.fee_tools import get_fee_tools
from app.tools.academic_tools import get_academic_tools
from app.tools.whatsapp_tools import get_whatsapp_tools
from app.tools.iot_tools import get_iot_tools
from app.tools.rag_tools import get_rag_tools


ROLE_TOOLS = {
    "student": [
        "get_timetable", "get_homework", "get_fee_status", "get_attendance",
        "get_exam_info", "get_bus_location", "get_performance",
        "generate_study_plan", "explain_concept", "get_notifications",
        "get_library_status", "get_achievements", "get_events",
        "get_leaderboard", "submit_homework", "apply_leave",
        "get_notices", "answer_general", "generate_practice", "get_live_class"
    ],
    "teacher": [
        "search_curriculum", "get_class_students", "get_class_performance",
        "get_at_risk_students", "generate_questions", "create_lesson_plan",
        "get_fee_status", "send_whatsapp_message", "send_bulk_whatsapp",
        "control_classroom_device", "get_classroom_device_status",
        "schedule_device_action", "auto_grade_homework", "get_submission_status",
        "generate_remedial_plan", "create_notice", "get_attendance_stats",
        "get_teacher_schedule", "get_pending_tasks", "generate_report",
        "explain_pedagogy", "get_leave_balance", "get_salary_info",
        "upload_material", "get_exam_analytics", "answer_general"
    ],
    "parent": [
        "get_child_attendance", "get_child_results", "get_fee_status",
        "get_notifications"
    ],
    "principal": ["*"],
    "admin": [
        "get_fee_status", "send_whatsapp_message", "control_classroom_device",
        "get_attendance_stats"
    ],
    "finance": [
        "get_fee_status", "create_razorpay_link", "send_whatsapp_message"
    ],
    "guest": [
        "search_curriculum", "get_school_info", "answer_general"
    ],
}


def get_all_tools(school_id: str) -> list:
    """Return all 40+ tools scoped to this school."""
    return [
        *get_student_tools(school_id),
        *get_teacher_tools(school_id),
        *get_fee_tools(school_id),
        *get_academic_tools(school_id),
        *get_whatsapp_tools(school_id),
        *get_iot_tools(school_id),
        *get_rag_tools(school_id),
    ]


def filter_tools_by_role(tools: list, role: str, school_id: str) -> list:
    """Filter tools based on user role."""
    allowed = ROLE_TOOLS.get(role, [])
    if "*" in allowed:
        filtered = tools
    else:
        filtered = [t for t in tools if t.name in allowed]

    # Deduplicate tools by name to prevent "Duplicate function declaration found" errors
    seen = set()
    deduped = []
    for t in filtered:
        if t.name not in seen:
            seen.add(t.name)
            deduped.append(t)
    return deduped