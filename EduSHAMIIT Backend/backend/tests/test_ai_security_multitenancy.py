"""
Security and Multi-Tenancy Tests for AI Assistant.
Validates:
- Role-based tool access permissions
- Tenant/School isolation
- Cross-user conversation protection
- Feedback rating boundaries
"""
import pytest
import uuid

from app.tools import get_all_tools, filter_tools_by_role
from app.services.ai_assistant_service import AIConversationService, AIMessageService


def test_role_based_tool_permissions(sample_school_id):
    school_id = sample_school_id
    all_tools = get_all_tools(school_id)

    # Student should NOT have fee collection reports, notice drafting, or device control
    student_tools = [t.name for t in filter_tools_by_role(all_tools, "student", school_id)]
    assert "get_timetable" in student_tools
    assert "get_fee_status" in student_tools
    assert "get_fee_collection_report" not in student_tools
    assert "draft_school_notice" not in student_tools

    # Admin should have enterprise reporting and administrative capabilities
    admin_tools = [t.name for t in filter_tools_by_role(all_tools, "admin", school_id)]
    assert "get_fee_collection_report" in admin_tools
    assert "get_pending_fee_students" in admin_tools
    assert "get_school_attendance_summary" in admin_tools
    assert "draft_school_notice" in admin_tools


@pytest.mark.asyncio
async def test_cross_user_and_cross_school_isolation(
    sample_school_id, sample_user_id, sample_other_user_id, sample_other_school_id
):
    school_a = sample_school_id
    school_b = sample_other_school_id
    user_a = sample_user_id
    user_b = sample_other_user_id

    # Create conversation for User A in School A
    conv_a = await AIConversationService.create_conversation(
        user_id=user_a,
        school_id=school_a,
        title="School A Private Chat"
    )
    conv_id = conv_a["id"]

    # User B in School A cannot fetch User A's conversation
    fetched_by_wrong_user = await AIConversationService.get_conversation(conv_id, user_b, school_a)
    assert fetched_by_wrong_user is None

    # User A in School B cannot access conversations across schools
    fetched_by_wrong_school = await AIConversationService.get_conversation(conv_id, user_a, school_b)
    assert fetched_by_wrong_school is None

    # Cleanup
    await AIConversationService.delete_conversation(conv_id, user_a, school_a)


from app.services.supabase_client import get_supabase

@pytest.mark.asyncio
async def test_feedback_rating_boundaries(sample_school_id, sample_user_id):
    school_id = sample_school_id
    user_id = sample_user_id
    sb = get_supabase()
    session_id = str(uuid.uuid4())
    msg_id = str(uuid.uuid4())

    # Pre-insert message so foreign key constraint in ai_feedback is satisfied
    await sb.table("ai_chat_history").insert({
        "id": msg_id,
        "school_id": school_id,
        "user_id": user_id,
        "session_id": session_id,
        "role": "assistant",
        "content": "Test fee summary breakdown"
    }).aexecute()

    # Positive feedback
    pos_res = await AIMessageService.submit_feedback(
        message_id=msg_id,
        user_id=user_id,
        school_id=school_id,
        rating=1,
        feedback_text="Very clear breakdown"
    )
    assert pos_res["success"] is True

    # Negative feedback
    neg_res = await AIMessageService.submit_feedback(
        message_id=msg_id,
        user_id=user_id,
        school_id=school_id,
        rating=-1,
        feedback_text="Need class-wise details"
    )
    assert neg_res["success"] is True
