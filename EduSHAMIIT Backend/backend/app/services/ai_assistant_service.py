"""
EduSHAMIIT AI Assistant Service Layer.
Comprehensive service for:
- Conversations CRUD (Pin, Archive, Rename, Delete, Search, Export)
- Message Feedback & Regeneration
- Tool Registry, Preview, & Execution with Confirmation Workflow
- AI Usage & Token Tracking
- Role-Aware Smart Suggestions
"""
import uuid
import json
import time
from datetime import datetime
from typing import Optional, List, Dict, Any

from app.services.supabase_client import get_supabase


class AIConversationService:
    """Manages multi-tenant, user-isolated chat conversations."""

    @staticmethod
    async def list_conversations(
        user_id: str,
        school_id: str,
        search: Optional[str] = None,
        is_archived: bool = False,
        limit: int = 50,
        offset: int = 0
    ) -> List[Dict[str, Any]]:
        sb = get_supabase()
        try:
            # Auto-reconcile any historical sessions present in ai_chat_history
            await AIConversationService._reconcile_missing_conversations(user_id, school_id)

            query = sb.table("ai_conversations") \
                .select("*") \
                .eq("user_id", user_id) \
                .eq("school_id", school_id) \
                .eq("is_archived", is_archived)

            if search:
                query = query.ilike("title", f"%{search}%")

            # Order by pinned first, then latest updated
            query = query.order("is_pinned", ascending=False) \
                .order("updated_at", ascending=False) \
                .limit(limit) \
                .offset(offset)

            res = await query.aexecute()
            conversations = res.data or []

            # Enhance each conversation with snippet and message count (instant from columns, fallback if empty)
            for c in conversations:
                if not c.get("last_message"):
                    sid = c.get("id")
                    latest_msg_res = await sb.table("ai_chat_history") \
                        .select("content, created_at, role") \
                        .eq("session_id", sid) \
                        .order("created_at", ascending=False) \
                        .limit(1) \
                        .aexecute()
                    latest_msgs = latest_msg_res.data or []
                    if latest_msgs:
                        c["last_message"] = latest_msgs[0].get("content", "")[:90]
                        c["last_message_at"] = latest_msgs[0].get("created_at")
                    else:
                        c["last_message"] = "No messages yet"
                        c["last_message_at"] = c.get("updated_at")

            return conversations
        except Exception as e:
            print(f"[AIConversationService.list_conversations] Error: {e}")
            return []

    @staticmethod
    async def _reconcile_missing_conversations(user_id: str, school_id: str):
        """Auto-reconcile sessions present in ai_chat_history into ai_conversations."""
        try:
            sb = get_supabase()
            hist_res = await sb.table("ai_chat_history") \
                .select("session_id, content, role, created_at") \
                .eq("user_id", user_id) \
                .order("created_at", ascending=True) \
                .limit(200) \
                .aexecute()
            
            hist_items = hist_res.data or []
            if not hist_items:
                return

            sessions_map = {}
            for row in hist_items:
                sid = row.get("session_id")
                if sid:
                    if sid not in sessions_map:
                        sessions_map[sid] = []
                    sessions_map[sid].append(row)

            conv_res = await sb.table("ai_conversations") \
                .select("id, title") \
                .eq("user_id", user_id) \
                .aexecute()
            existing_map = {c["id"]: c.get("title", "") for c in (conv_res.data or []) if c.get("id")}

            generic_titles = {
                "new chat", "untitled", "fee collection report", 
                "new conversation", "hi", "hello", "hey", "conversation", 
                "general inquiry", "general consultation"
            }

            from app.services.langchain_agent import generate_smart_title, is_greeting_text

            for sid, msgs in sessions_map.items():
                substantive_msg = next((m["content"] for m in msgs if m.get("role") == "user" and m.get("content") and not is_greeting_text(m.get("content"))), None)
                if not substantive_msg:
                    substantive_msg = next((m["content"] for m in msgs if m.get("role") == "user" and m.get("content")), "General Consultation")
                
                smart_title = generate_smart_title(substantive_msg)
                last_created = msgs[-1].get("created_at") or datetime.utcnow().isoformat()
                first_created = msgs[0].get("created_at") or datetime.utcnow().isoformat()

                if sid not in existing_map:
                    await sb.table("ai_conversations").insert({
                        "id": sid,
                        "school_id": school_id,
                        "user_id": user_id,
                        "title": smart_title,
                        "context_module": "general",
                        "is_pinned": False,
                        "is_archived": False,
                        "created_at": first_created,
                        "updated_at": last_created
                    }).aexecute()
                    existing_map[sid] = smart_title
                else:
                    curr_title = existing_map[sid]
                    if curr_title.lower() in generic_titles and smart_title.lower() not in generic_titles:
                        await sb.table("ai_conversations").update({
                            "title": smart_title,
                            "updated_at": last_created
                        }).eq("id", sid).aexecute()
                        existing_map[sid] = smart_title
        except Exception as e:
            print(f"[_reconcile_missing_conversations] Warning: {e}")

    @staticmethod
    async def create_conversation(
        user_id: str,
        school_id: str,
        title: Optional[str] = None,
        context_module: str = "general",
        model: str = "gemini-1.5-flash"
    ) -> Dict[str, Any]:
        sb = get_supabase()
        conv_id = str(uuid.uuid4())
        data = {
            "id": conv_id,
            "school_id": school_id,
            "user_id": user_id,
            "title": title or "New Chat",
            "context_module": context_module,
            "is_pinned": False,
            "is_archived": False,
            "model": model,
            "created_at": datetime.utcnow().isoformat(),
            "updated_at": datetime.utcnow().isoformat()
        }
        await sb.table("ai_conversations").insert(data).aexecute()
        return data

    @staticmethod
    async def get_conversation(conv_id: str, user_id: str, school_id: str) -> Optional[Dict[str, Any]]:
        sb = get_supabase()
        try:
            res = await sb.table("ai_conversations") \
                .select("*") \
                .eq("id", conv_id) \
                .eq("user_id", user_id) \
                .eq("school_id", school_id) \
                .aexecute()
            if res.data and len(res.data) > 0:
                return res.data[0]
            return None
        except Exception:
            return None

    @staticmethod
    async def update_conversation(
        conv_id: str,
        user_id: str,
        school_id: str,
        title: Optional[str] = None,
        is_pinned: Optional[bool] = None,
        is_archived: Optional[bool] = None,
        context_module: Optional[str] = None
    ) -> Optional[Dict[str, Any]]:
        sb = get_supabase()
        update_data = {"updated_at": datetime.utcnow().isoformat()}
        if title is not None:
            update_data["title"] = title.strip()
        if is_pinned is not None:
            update_data["is_pinned"] = is_pinned
        if is_archived is not None:
            update_data["is_archived"] = is_archived
        if context_module is not None:
            update_data["context_module"] = context_module

        res = await sb.table("ai_conversations") \
            .update(update_data) \
            .eq("id", conv_id) \
            .eq("user_id", user_id) \
            .eq("school_id", school_id) \
            .aexecute()
        return res.data[0] if res.data else None

    @staticmethod
    async def delete_conversation(conv_id: str, user_id: str, school_id: str) -> bool:
        sb = get_supabase()
        # Delete messages first
        await sb.table("ai_chat_history") \
            .delete() \
            .eq("session_id", conv_id) \
            .eq("user_id", user_id) \
            .eq("school_id", school_id) \
            .aexecute()
        # Delete attachments
        await sb.table("ai_attachments") \
            .delete() \
            .eq("session_id", conv_id) \
            .eq("user_id", user_id) \
            .eq("school_id", school_id) \
            .aexecute()
        # Delete conversation
        res = await sb.table("ai_conversations") \
            .delete() \
            .eq("id", conv_id) \
            .eq("user_id", user_id) \
            .eq("school_id", school_id) \
            .aexecute()
        return True

    @staticmethod
    async def export_conversation(conv_id: str, user_id: str, school_id: str, format_type: str = "json") -> Dict[str, Any]:
        sb = get_supabase()
        conv = await AIConversationService.get_conversation(conv_id, user_id, school_id)
        if not conv:
            raise ValueError("Conversation not found")

        msgs_res = await sb.table("ai_chat_history") \
            .select("role, content, created_at, tool_calls") \
            .eq("session_id", conv_id) \
            .eq("user_id", user_id) \
            .eq("school_id", school_id) \
            .order("created_at", ascending=True) \
            .aexecute()
        messages = msgs_res.data or []

        if format_type == "text":
            text_lines = [f"Conversation: {conv.get('title')}", f"Exported: {datetime.utcnow().isoformat()}", "="*40, ""]
            for m in messages:
                role = "User" if m["role"] == "user" else "Shami AI Assistant"
                text_lines.append(f"[{m.get('created_at')}] {role}:")
                text_lines.append(m.get("content", ""))
                text_lines.append("-" * 30)
            return {"format": "text", "content": "\n".join(text_lines), "filename": f"chat_{conv_id}.txt"}

        return {
            "format": "json",
            "conversation": conv,
            "messages": messages,
            "exported_at": datetime.utcnow().isoformat()
        }


class AIMessageService:
    """Handles feedback, message history and regeneration."""

    @staticmethod
    async def submit_feedback(
        message_id: str,
        user_id: str,
        school_id: str,
        rating: int,
        feedback_text: Optional[str] = None,
        category: Optional[str] = None
    ) -> Dict[str, Any]:
        sb = get_supabase()
        # Update ai_chat_history
        await sb.table("ai_chat_history") \
            .update({"feedback_rating": rating, "feedback_text": feedback_text}) \
            .eq("id", message_id) \
            .aexecute()

        # Insert detailed feedback log
        res = await sb.table("ai_feedback").insert({
            "school_id": school_id,
            "user_id": user_id,
            "message_id": message_id,
            "rating": rating,
            "feedback_text": feedback_text,
            "category": category
        }).aexecute()

        return {"success": True, "message": "Feedback submitted successfully"}


class AIUsageService:
    """Tracks token consumption, estimated costs and quota metrics."""

    @staticmethod
    async def log_usage(
        school_id: str,
        user_id: str,
        session_id: str,
        provider: str,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
        duration_ms: int,
        status: str = "success"
    ):
        try:
            sb = get_supabase()
            total_tokens = prompt_tokens + completion_tokens
            # Rough standard blended pricing calculation: ~$0.15 / 1M tokens for Flash
            estimated_cost = (total_tokens / 1_000_000.0) * 0.15

            await sb.table("ai_usage_logs").insert({
                "school_id": school_id,
                "user_id": user_id,
                "session_id": session_id,
                "provider": provider,
                "model": model,
                "prompt_tokens": prompt_tokens,
                "completion_tokens": completion_tokens,
                "total_tokens": total_tokens,
                "estimated_cost": estimated_cost,
                "duration_ms": duration_ms,
                "status": status
            }).aexecute()
        except Exception as e:
            print(f"[AIUsageService.log_usage] Failed: {e}")

    @staticmethod
    async def get_usage_summary(school_id: str, user_id: Optional[str] = None) -> Dict[str, Any]:
        sb = get_supabase()
        try:
            q = sb.table("ai_usage_logs").select("*").eq("school_id", school_id)
            if user_id:
                q = q.eq("user_id", user_id)
            res = await q.limit(1000).aexecute()
            logs = res.data or []

            total_requests = len(logs)
            total_tokens = sum(l.get("total_tokens", 0) for l in logs)
            total_cost = sum(float(l.get("estimated_cost", 0) or 0) for l in logs)
            avg_duration = (sum(l.get("duration_ms", 0) for l in logs) / total_requests) if total_requests > 0 else 0

            return {
                "success": True,
                "total_requests": total_requests,
                "total_tokens": total_tokens,
                "estimated_cost_inr": total_cost * 86.0, # Approximate USD to INR
                "average_latency_ms": round(avg_duration, 1),
                "model_breakdown": {
                    "gemini-1.5-flash": sum(1 for l in logs if "flash" in l.get("model", "")),
                    "gemini-2.5-pro": sum(1 for l in logs if "pro" in l.get("model", "")),
                }
            }
        except Exception as e:
            return {"success": False, "error": str(e), "total_requests": 0, "total_tokens": 0}


class AISuggestionsService:
    """Generates dynamic role-specific smart suggestion chips and quick action definitions."""

    @staticmethod
    def get_role_context(role: str) -> Dict[str, Any]:
        clean_role = (role or "admin").lower()

        quick_actions = [
            {"id": "gen_report", "label": "Generate Report", "icon": "bar_chart", "prompt": "Generate a comprehensive fee and attendance report for this month."},
            {"id": "student_search", "label": "Student Search", "icon": "person_search", "prompt": "Search student details by name or roll number."},
            {"id": "att_query", "label": "Attendance Query", "icon": "event_available", "prompt": "Show me today's attendance summary for all classes."},
            {"id": "fee_report", "label": "Fee Report", "icon": "currency_rupee", "prompt": "Show me the fee collection report for this month for all classes."},
            {"id": "timetable", "label": "Timetable", "icon": "schedule", "prompt": "Show me the timetable for Class 10."},
            {"id": "send_notice", "label": "Send Notice", "icon": "campaign", "prompt": "Draft a notice for parents regarding the upcoming school event."},
        ]

        suggested_questions = [
            "Show me today's attendance.",
            "Generate class 10 timetable.",
            "List all pending fees.",
            "How many students are in Class 9?",
            "Show recent notices.",
        ]

        if clean_role in ("student",):
            quick_actions = [
                {"id": "my_timetable", "label": "My Timetable", "icon": "schedule", "prompt": "Show my timetable for today."},
                {"id": "my_homework", "label": "Pending Homework", "icon": "assignment", "prompt": "What homework assignments are pending for me?"},
                {"id": "my_fees", "label": "Fee Status", "icon": "currency_rupee", "prompt": "Check my fee payment balance and pending dues."},
                {"id": "my_bus", "label": "Bus Location", "icon": "directions_bus", "prompt": "Where is my school bus right now?"},
                {"id": "my_exams", "label": "Exam Schedule", "icon": "quiz", "prompt": "Show my upcoming exam schedule and dates."},
                {"id": "study_plan", "label": "Study Plan", "icon": "auto_stories", "prompt": "Create a personalized study revision plan for me."},
            ]
            suggested_questions = [
                "Show my timetable for today.",
                "What homework is due tomorrow?",
                "Where is my school bus?",
                "Show my attendance percentage.",
                "Explain the concept of Photosynthesis.",
            ]
        elif clean_role in ("teacher",):
            quick_actions = [
                {"id": "class_students", "label": "Class Students", "icon": "group", "prompt": "Get student roster for Class 10-A."},
                {"id": "attendance_stats", "label": "Attendance Stats", "icon": "fact_check", "prompt": "Show attendance stats for my class today."},
                {"id": "lesson_plan", "label": "Create Lesson Plan", "icon": "menu_book", "prompt": "Create a 45-minute lesson plan for Class 9 Physics."},
                {"id": "gen_questions", "label": "Question Paper", "icon": "quiz", "prompt": "Generate 10 mixed questions on Quadratic Equations for Class 10."},
                {"id": "my_schedule", "label": "Teacher Schedule", "icon": "calendar_month", "prompt": "Show my teaching schedule for this week."},
                {"id": "draft_notice", "label": "Draft Notice", "icon": "campaign", "prompt": "Draft a homework reminder notice for Class 10."},
            ]
            suggested_questions = [
                "Show attendance stats for Class 10-A.",
                "Identify at-risk students with low scores in Class 9.",
                "Create a 45-minute lesson plan on Thermodynamics.",
                "Generate 5 multiple choice questions on Chemical Reactions.",
                "Show my pending homework evaluation tasks.",
            ]

        connected_modules = [
            {"id": "students", "name": "Student Management", "icon": "people", "route": "/admin/students", "is_accessible": True},
            {"id": "academics", "name": "Academic Management", "icon": "school", "route": "/admin/classes", "is_accessible": True},
            {"id": "attendance", "name": "Attendance Hub", "icon": "fact_check", "route": "/admin/attendance", "is_accessible": True},
            {"id": "fees", "name": "Fee Management", "icon": "payments", "route": "/admin/student-fees", "is_accessible": True},
            {"id": "hr", "name": "HR & Staff", "icon": "badge", "route": "/admin/recruit/overview", "is_accessible": True},
            {"id": "transport", "name": "Transport Fleet", "icon": "directions_bus", "route": "/admin/transport", "is_accessible": True},
            {"id": "library", "name": "Library Circulation", "icon": "menu_book", "route": "/admin/library", "is_accessible": True},
            {"id": "hostel", "name": "Hostel Management", "icon": "apartment", "route": "/admin/hostel", "is_accessible": True},
            {"id": "notices", "name": "Notices & Circulars", "icon": "campaign", "route": "/admin/notices", "is_accessible": True},
            {"id": "timetable", "name": "Timetable Assistant", "icon": "calendar_month", "route": "/admin/timetable", "is_accessible": True},
        ]

        return {
            "role": clean_role,
            "quick_actions": quick_actions,
            "suggested_questions": suggested_questions,
            "connected_modules": connected_modules
        }

    @staticmethod
    async def get_dynamic_suggestions(role: str, user_id: str, school_id: str) -> Dict[str, Any]:
        """Generate smart suggestions merging role-based capabilities with user's recent chat activity."""
        base = AISuggestionsService.get_role_context(role)
        if not user_id or not school_id:
            return base

        try:
            sb = get_supabase()
            # Fetch recent user messages
            res = await sb.table("ai_chat_history") \
                .select("content, created_at") \
                .eq("user_id", user_id) \
                .eq("school_id", school_id) \
                .eq("role", "user") \
                .order("created_at", ascending=False) \
                .limit(10) \
                .aexecute()

            messages = res.data or []
            if not messages:
                return base

            joined_history = " ".join([m.get("content", "").lower() for m in messages])
            history_questions = []

            # Fee topic detection
            if any(k in joined_history for k in ["fee", "dues", "collection", "payment"]):
                history_questions.append("Compare this month's fee collection with last month.")
                history_questions.append("List students with pending fees > ₹ 10,000.")

            # Attendance topic detection
            if any(k in joined_history for k in ["attendance", "absent", "present"]):
                history_questions.append("Which classes had the lowest attendance this week?")
                history_questions.append("Summarize staff attendance for today.")

            # Timetable / Exams detection
            if any(k in joined_history for k in ["timetable", "schedule", "exam", "period"]):
                history_questions.append("Generate schedule for upcoming terminal exams.")
                history_questions.append("Show Class 10 timetable changes.")

            # Notices detection
            if any(k in joined_history for k in ["notice", "circular", "announcement"]):
                history_questions.append("Draft an urgent circular for tomorrow's holiday.")

            # Bus / Transport detection
            if any(k in joined_history for k in ["bus", "transport", "driver", "route"]):
                history_questions.append("Show vehicles with pending fitness certificates.")

            if history_questions:
                # Merge history questions at the top of suggested questions (deduped)
                merged_questions = []
                for q in history_questions + base["suggested_questions"]:
                    if q not in merged_questions:
                        merged_questions.append(q)
                base["suggested_questions"] = merged_questions[:8]
                base["has_past_activity"] = True
                base["recent_topics"] = [
                    t for t in ["Fees", "Attendance", "Timetable", "Notices", "Transport"]
                    if t.lower() in joined_history
                ]
        except Exception as e:
            print(f"[AISuggestionsService] History analysis exception: {e}")

        return base
