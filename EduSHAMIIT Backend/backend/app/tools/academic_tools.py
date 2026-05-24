"""
Academic Tools - 3 LangChain @tool functions for EduSHAMIIT teacher agent.
Uses Gemini 1.5 Flash for AI-powered question and lesson plan generation.
"""
import os
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from app.middleware.auth import get_current_user_id


def get_academic_tools(school_id: str):
    """Return academic AI tools scoped to this school."""

    def _llm():
        from langchain_google_genai import ChatGoogleGenerativeAI
        return ChatGoogleGenerativeAI(
            model=os.getenv("GEMINI_MODEL", "gemini-1.5-flash"),
            temperature=0.7,
            google_api_key=os.getenv("GOOGLE_API_KEY", ""),
        )

    @tool
    def generate_questions(
        subject: str,
        topic: str,
        difficulty: str = "medium",
        num_questions: int = 5,
        question_type: str = "mcq",
    ) -> dict:
        """Generate exam or practice questions for a subject and topic using AI.
        Input: subject name, topic, difficulty (easy/medium/hard),
        number of questions (default 5), question type (mcq/short_answer/long_answer).
        Use when a teacher asks to create questions, make a quiz, or generate test paper."""
        try:
            llm = _llm()
            from langchain_core.messages import HumanMessage
            q_type = question_type.replace("_", " ")
            prompt = (
                f"Generate {num_questions} {q_type} questions for {subject} "
                f"on the topic \"{topic}\" at {difficulty} difficulty level. "
                "For each question provide: question text, options (if MCQ, 4 choices), "
                "the correct answer, and a brief explanation. "
                "Format as a clean numbered list. NCERT-aligned."
            )
            response = llm.invoke([HumanMessage(content=prompt)])
            return {
                "success": True,
                "subject": subject,
                "topic": topic,
                "difficulty": difficulty,
                "question_type": question_type,
                "questions": response.content,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def create_lesson_plan(
        subject: str,
        topic: str,
        grade: str,
        duration_minutes: int = 40,
        learning_objectives: str = "",
    ) -> dict:
        """Create a detailed lesson plan for a teacher using AI.
        Input: subject, topic, grade/class, duration in minutes (default 40),
        optional learning objectives.
        Use when a teacher asks for a lesson plan, teaching plan, or class preparation."""
        try:
            llm = _llm()
            from langchain_core.messages import HumanMessage
            obj = f" with learning objectives: {learning_objectives}" if learning_objectives else ""
            prompt = (
                f"Create a detailed {duration_minutes}-minute lesson plan for {subject} "
                f"on the topic \"{topic}\" for Grade {grade}{obj}. "
                "Include: Learning Objectives, Materials Needed, Lesson Structure "
                "with time allocation, Activities, Differentiation strategies, "
                "Assessment methods, and Homework. "
                "Make it practical and NCERT-aligned."
            )
            response = llm.invoke([HumanMessage(content=prompt)])
            return {
                "success": True,
                "subject": subject,
                "topic": topic,
                "grade": grade,
                "duration_minutes": duration_minutes,
                "lesson_plan": response.content,
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def get_timetable(class_name: str = "", teacher_id: str = "") -> dict:
        """Get the school timetable for a class or teacher.
        Input: class_name (e.g. '10A') or teacher_id (UUID), or both.
        Use when a teacher or admin asks about the class schedule or teacher timetable."""
        try:
            supabase = get_supabase()
            query = supabase.table("timetable").select("*").eq("school_id", school_id)
            if class_name:
                query = query.eq("class_name", class_name)
            if teacher_id:
                query = query.eq("teacher_id", teacher_id)
            resp = query.order("day").order("period").execute()
            entries = resp.data or []
            timetable: dict = {}
            for entry in entries:
                day = entry.get("day", "Unknown")
                if day not in timetable:
                    timetable[day] = []
                timetable[day].append({
                    "period": entry.get("period"),
                    "subject": entry.get("subject"),
                    "teacher": entry.get("teacher_name", ""),
                    "room": entry.get("room", ""),
                    "start_time": entry.get("start_time", ""),
                    "end_time": entry.get("end_time", ""),
                })
            return {
                "success": True,
                "class_name": class_name,
                "teacher_id": teacher_id,
                "timetable": timetable,
                "total_entries": len(entries),
            }
        except Exception as e:
            return {"success": False, "error": str(e)}

    return [generate_questions, create_lesson_plan, get_timetable]