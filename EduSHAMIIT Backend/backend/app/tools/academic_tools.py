from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from app.middleware.auth import get_current_user_id
import os


def get_academic_tools(school_id: str):
    @tool
    def generate_questions(subject: str, topic: str, difficulty: str = "medium", num_questions: int = 5, question_type: str = "mcq") -> dict:
        try:
            from langchain_openai import ChatOpenAI
            from langchain_core.messages import HumanMessage
            llm = ChatOpenAI(model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"), temperature=0.7)
            q_type = question_type.replace("_", " ")
            prompt = f"Generate {num_questions} {q_type} questions for {subject} on the topic {chr(34)}{topic}{chr(34)} at {difficulty} difficulty level. For each question provide the question text, options if MCQ with 4 choices, the correct answer, and an explanation. Format as JSON array."
            response = llm.invoke([HumanMessage(content=prompt)])
            return {"success": True, "subject": subject, "topic": topic, "difficulty": difficulty, "question_type": question_type, "questions": response.content}
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def create_lesson_plan(subject: str, topic: str, grade: str, duration_minutes: int = 40, learning_objectives: str = "") -> dict:
        try:
            from langchain_openai import ChatOpenAI
            from langchain_core.messages import HumanMessage
            llm = ChatOpenAI(model=os.getenv("OPENAI_MODEL", "gpt-4o-mini"), temperature=0.7)
            obj = f" with learning objectives: {learning_objectives}" if learning_objectives else ""
            prompt = f"Create a detailed {duration_minutes}-minute lesson plan for {subject} on the topic {chr(34)}{topic}{chr(34)} for Grade {grade}{obj}. Include Learning Objectives, Materials Needed, Lesson Structure with time allocation, Differentiation strategies, Assessment methods, and Homework activities. Format as structured JSON."
            response = llm.invoke([HumanMessage(content=prompt)])
            return {"success": True, "subject": subject, "topic": topic, "grade": grade, "duration_minutes": duration_minutes, "lesson_plan": response.content}
        except Exception as e:
            return {"success": False, "error": str(e)}

    @tool
    def get_timetable(class_name: str = "", teacher_id: str = "") -> dict:
        try:
            supabase = get_supabase()
            query = supabase.table("timetable").select("*").eq("school_id", school_id)
            if class_name:
                query = query.eq("class_name", class_name)
            if teacher_id:
                query = query.eq("teacher_id", teacher_id)
            resp = query.order("day").order("period").execute()
            entries = resp.data or []
            timetable = {}
            for entry in entries:
                day = entry.get("day", "Unknown")
                if day not in timetable:
                    timetable[day] = []
                timetable[day].append({"period": entry.get("period"), "subject": entry.get("subject"), "teacher": entry.get("teacher_name", ""), "room": entry.get("room", ""), "start_time": entry.get("start_time", ""), "end_time": entry.get("end_time", "")})
            return {"success": True, "class_name": class_name, "teacher_id": teacher_id, "timetable": timetable, "total_entries": len(entries)}
        except Exception as e:
            return {"success": False, "error": str(e)}

    return [generate_questions, create_lesson_plan, get_timetable]