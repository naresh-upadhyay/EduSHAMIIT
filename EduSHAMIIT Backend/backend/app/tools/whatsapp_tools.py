"""
WhatsApp Tools - 2 LangChain @tool functions for EduSHAMIIT communication.
Sends individual and bulk WhatsApp messages to students/parents via configured gateway.
"""
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from app.services.whatsapp_service import send_whatsapp_message as _send_whatsapp
import asyncio


def get_whatsapp_tools(school_id: str):
    """Return WhatsApp messaging tools scoped to this school."""

    @tool
    def send_whatsapp_message(phone: str, message: str) -> dict:
        """Send a WhatsApp message to a single phone number.
        Input: phone (with country code, e.g. '+919876543210'), message text.
        Use when a teacher or admin wants to send a message or alert to a specific parent/student."""
        try:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                result = loop.run_until_complete(_send_whatsapp(phone, message))
            finally:
                loop.close()
            return {
                "success": result.get("success", False),
                "phone": phone,
                "message_sent": message[:50] + "..." if len(message) > 50 else message,
                "details": result,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def send_bulk_whatsapp(class_name: str, message_template: str) -> dict:
        """Send a personalized WhatsApp message to all students in a class.
        Input: class_name (e.g. '10A'), message_template (use {student_name} as placeholder).
        Use when a teacher or admin wants to send a bulk announcement, reminder,
        or notice to an entire class via WhatsApp."""
        try:
            supabase = get_supabase()
            students_resp = supabase.table("students").select("id, name, phone").eq("school_id", school_id).eq("class_name", class_name).execute()
            students = students_resp.data or []
            if not students:
                return {"success": False, "error": f"No students found for class {class_name}"}

            phone_message_pairs = []
            skipped = []
            for student in students:
                phone = student.get("phone", "")
                name = student.get("name", "Student")
                if not phone:
                    skipped.append({"name": name, "reason": "No phone number"})
                    continue
                personalized_msg = message_template.replace("{student_name}", name)
                phone_message_pairs.append((phone, personalized_msg))

            if not phone_message_pairs:
                return {"success": False, "error": "No valid phone numbers found.", "skipped": skipped}

            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            try:
                sent = 0
                failed = 0
                failed_details = []
                for phone, msg in phone_message_pairs:
                    result = loop.run_until_complete(_send_whatsapp(phone, msg))
                    if result.get("success"):
                        sent += 1
                    else:
                        failed += 1
                        failed_details.append({"phone": phone, "error": result.get("error", "Unknown")})
            finally:
                loop.close()

            return {
                "success": True,
                "class_name": class_name,
                "total_students": len(students),
                "sent": sent,
                "failed": failed,
                "skipped": skipped,
                "failed_details": failed_details,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    return [send_whatsapp_message, send_bulk_whatsapp]