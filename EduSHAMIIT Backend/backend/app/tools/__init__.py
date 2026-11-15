"""
EduSHAMIIT AI Tools - Enterprise tools registry for Shami AI assistant.
Role-based tool filtering ensures users only access tools they're authorized for.
"""
from typing import Optional, List
from app.tools.student_tools import get_student_tools
from app.tools.teacher_tools import get_teacher_tools
from app.tools.fee_tools import get_fee_tools
from app.tools.academic_tools import get_academic_tools
from app.tools.whatsapp_tools import get_whatsapp_tools
from app.tools.iot_tools import get_iot_tools
from app.tools.rag_tools import get_rag_tools
from app.tools.erp_enterprise_tools import get_erp_enterprise_tools


ROLE_TOOLS = {
    "super_admin": ["*"],
    "superadmin": ["*"],
    "school_admin": ["*"],
    "schooladmin": ["*"],
    "system_admin": ["*"],
    "systemadmin": ["*"],
    "admin": ["*"],
    "director": ["*"],
    "principal": ["*"],
    "finance": [
        "get_fee_status", "get_fee_collection_report", "get_pending_fee_students",
        "create_razorpay_link", "send_whatsapp_message", "generate_report",
        "generate_document", "answer_general"
    ],
    "accountant": [
        "get_fee_status", "get_fee_collection_report", "get_pending_fee_students",
        "create_razorpay_link", "send_whatsapp_message", "generate_report",
        "generate_document", "answer_general"
    ],
    "librarian": [
        "get_library_status_summary", "get_library_status", "get_notices",
        "generate_document", "answer_general"
    ],
    "warden": [
        "get_hostel_status_summary", "get_notices", "generate_document",
        "answer_general"
    ],
    "hostel_warden": [
        "get_hostel_status_summary", "get_notices", "generate_document",
        "answer_general"
    ],
    "transport": [
        "get_transport_fleet_summary", "get_bus_location", "get_notices",
        "answer_general"
    ],
    "driver": [
        "get_transport_fleet_summary", "get_bus_location", "get_notices",
        "answer_general"
    ],
    "teacher": [
        "search_curriculum", "get_class_students", "get_class_performance",
        "get_at_risk_students", "generate_questions", "create_lesson_plan",
        "get_fee_status", "send_whatsapp_message", "send_bulk_whatsapp",
        "control_classroom_device", "get_classroom_device_status",
        "schedule_device_action", "auto_grade_homework", "get_submission_status",
        "generate_remedial_plan", "create_notice",
        "get_attendance_stats", "get_school_attendance_summary", "get_teacher_schedule", "get_pending_tasks",
        "generate_report", "explain_pedagogy", "get_leave_balance", "get_salary_info",
        "upload_material", "get_exam_analytics", "answer_general",
        "generate_image", "generate_document"
    ],
    "student": [
        "get_timetable", "get_homework", "get_fee_status", "get_attendance",
        "get_exam_info", "get_bus_location", "get_performance",
        "generate_study_plan", "explain_concept", "get_notifications",
        "get_library_status", "get_achievements", "get_events",
        "get_leaderboard", "submit_homework", "apply_leave",
        "get_notices", "answer_general", "generate_practice", "get_live_class",
        "generate_image", "generate_document"
    ],
    "parent": [
        "get_child_attendance", "get_child_results", "get_fee_status",
        "get_notifications", "get_notices", "get_bus_location",
        "answer_general"
    ],
    "guest": [
        "search_curriculum", "get_school_info", "answer_general"
    ],
}


def get_all_tools(school_id: str) -> list:
    """Return all tools scoped to this school."""
    return [
        *get_student_tools(school_id),
        *get_teacher_tools(school_id),
        *get_fee_tools(school_id),
        *get_academic_tools(school_id),
        *get_whatsapp_tools(school_id),
        *get_iot_tools(school_id),
        *get_rag_tools(school_id),
        *get_erp_enterprise_tools(school_id),
    ]


def filter_tools_by_role(tools: list, role: str, school_id: str, query: str = "") -> list:
    """Filter and intelligently prioritize tools based on user role and query context."""
    raw_role = (role or "guest").lower().strip()
    clean_role = raw_role.replace("-", "_").replace(" ", "_")
    compact_role = clean_role.replace("_", "")

    allowed = (
        ROLE_TOOLS.get(clean_role) 
        or ROLE_TOOLS.get(compact_role) 
        or ROLE_TOOLS.get("guest", [])
    )

    if "*" in allowed:
        filtered = tools
    else:
        filtered = [t for t in tools if t.name in allowed]

    # Deduplicate tools by name
    tool_map = {}
    for t in filtered:
        if t.name not in tool_map:
            tool_map[t.name] = t

    # If the user has broad permission ("*"), bound models like Groq free tier
    # will exceed ITPM token limits if 60 tools are included. Prune to the best 16-18 tools.
    if "*" in allowed and len(tool_map) > 18:
        q_lower = query.lower() if query else ""
        
        # 1. Essential Core Tools (always included)
        core_names = [
            "generate_image",
            "generate_document",
            "get_timetable",
            "get_homework",
            "get_fee_status",
            "get_attendance",
            "get_teacher_schedule",
            "get_notices",
            "generate_report",
            "answer_general"
        ]

        selected_names = set(core_names)

        # 2. Add domain-specific tools matching query keywords
        domain_keywords = {
            ("bus", "transport", "driver", "route", "vehicle"): [
                "get_bus_location", "get_transport_fleet_summary"
            ],
            ("book", "library", "issue", "fine", "return"): [
                "get_library_status", "get_library_status_summary"
            ],
            ("fee", "payment", "due", "razorpay", "collection", "receipt"): [
                "get_fee_collection_report", "get_pending_fee_students", "create_razorpay_link"
            ],
            ("hostel", "bed", "room", "warden", "outing", "gate pass"): [
                "get_hostel_status_summary"
            ],
            ("exam", "test", "marks", "rank", "result", "grade"): [
                "get_exam_info", "get_exam_analytics", "get_class_performance"
            ],
            ("leave", "absence", "holiday"): [
                "get_leave_balance", "apply_leave"
            ],
            ("iot", "device", "fan", "light", "switch", "ac", "projector"): [
                "control_classroom_device", "get_classroom_device_status", "schedule_device_action"
            ],
            ("whatsapp", "sms", "alert", "broadcast"): [
                "send_whatsapp_message", "send_bulk_whatsapp"
            ],
            ("student", "class", "section", "admission"): [
                "get_class_students", "get_at_risk_students"
            ]
        }

        for kw_tuple, t_names in domain_keywords.items():
            if any(kw in q_lower for kw in kw_tuple):
                for tn in t_names:
                    selected_names.add(tn)

        # Build final tool list (under 20 tools total)
        final_tools = []
        for name in selected_names:
            if name in tool_map:
                final_tools.append(tool_map[name])

        # Fill remaining up to 16 with top available tools
        if len(final_tools) < 16:
            for name, tool_obj in tool_map.items():
                if tool_obj not in final_tools:
                    final_tools.append(tool_obj)
                    if len(final_tools) >= 16:
                        break

        return final_tools

    return list(tool_map.values())
