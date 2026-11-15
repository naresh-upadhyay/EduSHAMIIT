"""
Unit and Integration Tests for AI Usage Tracking and Smart Suggestions.
"""
import pytest
import uuid
from app.services.ai_assistant_service import AIUsageService, AISuggestionsService


@pytest.mark.asyncio
async def test_ai_usage_logging_and_summary(sample_school_id, sample_user_id):
    school_id = sample_school_id
    user_id = sample_user_id
    session_id = str(uuid.uuid4())

    # Log two distinct AI usage sessions
    await AIUsageService.log_usage(
        school_id=school_id,
        user_id=user_id,
        session_id=session_id,
        provider="google",
        model="gemini-1.5-flash",
        prompt_tokens=150,
        completion_tokens=350,
        duration_ms=850,
        status="success"
    )

    await AIUsageService.log_usage(
        school_id=school_id,
        user_id=user_id,
        session_id=session_id,
        provider="google",
        model="gemini-1.5-flash",
        prompt_tokens=200,
        completion_tokens=400,
        duration_ms=920,
        status="success"
    )

    summary = await AIUsageService.get_usage_summary(school_id, user_id)
    assert summary["success"] is True
    assert summary["total_requests"] >= 2
    assert summary["total_tokens"] >= 1100
    assert summary["average_latency_ms"] > 0


def test_smart_suggestions_role_context():
    # Admin context
    admin_ctx = AISuggestionsService.get_role_context("admin")
    assert admin_ctx["role"] == "admin"
    assert len(admin_ctx["quick_actions"]) == 6
    assert any("Fee Report" in a["label"] for a in admin_ctx["quick_actions"])
    assert any("Generate class 10 timetable" in q for q in admin_ctx["suggested_questions"])

    # Student context
    student_ctx = AISuggestionsService.get_role_context("student")
    assert student_ctx["role"] == "student"
    assert any("My Timetable" in a["label"] for a in student_ctx["quick_actions"])
    assert any("homework" in q.lower() for q in student_ctx["suggested_questions"])

    # Teacher context
    teacher_ctx = AISuggestionsService.get_role_context("teacher")
    assert teacher_ctx["role"] == "teacher"
    assert any("Class Students" in a["label"] for a in teacher_ctx["quick_actions"])
