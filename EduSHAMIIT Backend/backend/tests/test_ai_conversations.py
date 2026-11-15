"""
Unit and Integration Tests for AI Conversations CRUD.
"""
import pytest
import uuid

from app.services.ai_assistant_service import AIConversationService


@pytest.mark.asyncio
async def test_conversation_lifecycle(sample_school_id, sample_user_id):
    school_id = sample_school_id
    user_id = sample_user_id

    # 1. Create Conversation
    conv = await AIConversationService.create_conversation(
        user_id=user_id,
        school_id=school_id,
        title="Test Academic Consultation",
        context_module="attendance"
    )
    assert conv is not None
    conv_id = conv["id"]
    assert conv["title"] == "Test Academic Consultation"
    assert conv["is_pinned"] is False
    assert conv["is_archived"] is False

    # 2. Get Conversation
    fetched = await AIConversationService.get_conversation(conv_id, user_id, school_id)
    assert fetched is not None
    assert fetched["id"] == conv_id

    # 3. Update / Rename
    renamed = await AIConversationService.update_conversation(
        conv_id, user_id, school_id, title="Renamed Fee Consultation"
    )
    assert renamed is not None
    assert renamed["title"] == "Renamed Fee Consultation"

    # 4. Pin Conversation
    pinned = await AIConversationService.update_conversation(
        conv_id, user_id, school_id, is_pinned=True
    )
    assert pinned["is_pinned"] is True

    # 5. Archive Conversation
    archived = await AIConversationService.update_conversation(
        conv_id, user_id, school_id, is_archived=True
    )
    assert archived["is_archived"] is True

    # 6. List Conversations (Active vs. Archived)
    active_list = await AIConversationService.list_conversations(user_id, school_id, is_archived=False)
    assert not any(c["id"] == conv_id for c in active_list)

    archived_list = await AIConversationService.list_conversations(user_id, school_id, is_archived=True)
    assert any(c["id"] == conv_id for c in archived_list)

    # 7. Unarchive & Search
    unarchived = await AIConversationService.update_conversation(
        conv_id, user_id, school_id, is_archived=False
    )
    assert unarchived["is_archived"] is False

    search_res = await AIConversationService.list_conversations(user_id, school_id, search="Renamed")
    assert any(c["id"] == conv_id for c in search_res)

    # 8. Export Conversation
    export_json = await AIConversationService.export_conversation(conv_id, user_id, school_id, "json")
    assert export_json["format"] == "json"
    assert export_json["conversation"]["id"] == conv_id

    export_txt = await AIConversationService.export_conversation(conv_id, user_id, school_id, "text")
    assert export_txt["format"] == "text"
    assert "Renamed Fee Consultation" in export_txt["content"]

    # 9. Delete Conversation
    deleted = await AIConversationService.delete_conversation(conv_id, user_id, school_id)
    assert deleted is True

    post_delete = await AIConversationService.get_conversation(conv_id, user_id, school_id)
    assert post_delete is None
