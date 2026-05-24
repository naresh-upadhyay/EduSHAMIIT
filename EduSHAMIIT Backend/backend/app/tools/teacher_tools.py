"""
Teacher Tools - 19 LangChain @tool functions for EduSHAMIIT teacher agent.
Each tool queries Supabase with school_id scoping for multi-tenant isolation.
AI-powered tools use ChatGoogleGenerativeAI (Gemini) via langchain-google-genai.
"""
import json
import os
from datetime import datetime
from typing import Optional
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from app.middleware.auth import get_current_user_id


def parse_date_to_weekday(day_str: str) -> Optional[str]:
    """Resolve relative dates, full dates, and weekdays into a standard lowercase weekday name."""
    import re
    from datetime import datetime, timedelta

    day_str = day_str.strip().lower()
    if not day_str or day_str in ("week", "full week", "all"):
        return None

    day_names = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
    for d in day_names:
        if d in day_str:
            return d

    now = datetime.now()
    if day_str == "today":
        return now.strftime("%A").lower()
    elif day_str == "tomorrow":
        return (now + timedelta(days=1)).strftime("%A").lower()
    elif day_str == "yesterday":
        return (now - timedelta(days=1)).strftime("%A").lower()

    # Try parsing as date
    # Remove ordinal suffixes: 25th -> 25
    cleaned = re.sub(r'(\d+)(st|nd|rd|th)', r'\1', day_str)
    
    # Try parsing with various formats
    formats = [
        "%d %B %Y", "%d %b %Y", "%B %d %Y", "%b %d %Y",
        "%d %B", "%d %b", "%B %d", "%b %d",
        "%d/%m/%Y", "%d-%m-%Y", "%Y-%m-%d",
        "%d/%m", "%d-%m"
    ]
    for fmt in formats:
        try:
            dt = datetime.strptime(cleaned, fmt)
            # If year is not parsed, set it to current year
            if "%Y" not in fmt and "%y" not in fmt:
                dt = dt.replace(year=now.year)
            return dt.strftime("%A").lower()
        except ValueError:
            continue

    return None


def get_teacher_tools(school_id: str) -> list:
    """Return all 19 teacher tools scoped to this school."""

    def _llm():
        from app.agents.router import get_llm, get_fallback_llms
        base = get_llm("qa")
        fallbacks = get_fallback_llms()
        if fallbacks:
            return base.with_fallbacks(fallbacks)
        return base

    @tool
    def get_class_students(class_name: str) -> str:
        """Get the list of students in a class.
        Input: class name like 'X-A', 'X-B'.
        Use when teacher asks about students in a class or needs the student list."""
        sb = get_supabase()
        students = sb.table("profiles").select("id, full_name, roll_number, xp_points, learning_streak, avatar_url").eq("school_id", school_id).eq("class", class_name).eq("role", "student").order("roll_number").execute().data

        if not students:
            return f"No students found in class {class_name}."

        buf = [f"👥 Class {class_name} Students ({len(students)} total):"]
        for s in students:
            buf.append(f"  {s.get('roll_number', '?')}. {s.get('full_name', '')} (XP: {s.get('xp_points', 0)}, Streak: {s.get('learning_streak', 0)})")

        return "\n".join(buf)

    @tool
    def get_class_performance(class_name: str) -> str:
        """Get academic performance summary for a class including averages, top performers, and at-risk students.
        Input: class name like 'X-A'.
        Use when teacher asks about class performance, results, or how students are doing."""
        sb = get_supabase()
        students = sb.table("profiles").select("id, full_name").eq("school_id", school_id).eq("class", class_name).eq("role", "student").execute().data

        results = sb.table("results").select("student_id, marks_obtained, max_marks").eq("school_id", school_id).in_("student_id", [s["id"] for s in students]).execute().data
        attendance = sb.table("attendance").select("student_id, status").eq("school_id", school_id).in_("student_id", [s["id"] for s in students]).execute().data

        student_stats = {}
        for s in students:
            sid = s["id"]
            s_results = [r for r in results if r["student_id"] == sid]
            s_att = [a for a in attendance if a["student_id"] == sid]

            avg_score = 0
            if s_results:
                total = sum(float(r["marks_obtained"]) for r in s_results)
                max_total = sum(float(r["max_marks"]) for r in s_results)
                avg_score = (total / max_total * 100) if max_total > 0 else 0

            att_pct = 0
            if s_att:
                present = sum(1 for a in s_att if a["status"] == "present")
                att_pct = (present / len(s_att) * 100)

            student_stats[sid] = {"name": s["full_name"], "avg_score": avg_score, "att_pct": att_pct}

        sorted_students = sorted(student_stats.values(), key=lambda x: x["avg_score"], reverse=True)
        top5 = sorted_students[:5]
        at_risk = [s for s in sorted_students if s["avg_score"] < 50 or s["att_pct"] < 75]
        class_avg = sum(s["avg_score"] for s in sorted_students) / len(sorted_students) if sorted_students else 0

        buf = [f"📊 Class {class_name} Performance:"]
        buf.append(f"  Total Students: {len(students)}")
        buf.append(f"  Class Average: {class_avg:.1f}%")
        buf.append("")
        buf.append("🏆 Top 5 Performers:")
        for i, s in enumerate(top5):
            buf.append(f"  #{i + 1} {s['name']}: {s['avg_score']:.1f}%")

        if at_risk:
            buf.append("")
            buf.append("⚠️ At-Risk Students (Score < 50% or Attendance < 75%):")
            for s in at_risk:
                buf.append(f"  ❌ {s['name']}: Score {s['avg_score']:.1f}%, Attendance {s['att_pct']:.1f}%")

        return "\n".join(buf)

    @tool
    def get_at_risk_students(class_name: str) -> str:
        """Identify students who are at risk due to low scores or poor attendance.
        Input: class name like 'X-A'.
        Use when teacher asks about struggling students or who needs extra help."""
        sb = get_supabase()
        students = sb.table("profiles").select("id, full_name").eq("school_id", school_id).eq("class", class_name).eq("role", "student").execute().data

        student_ids = [s["id"] for s in students]
        results = sb.table("results").select("student_id, marks_obtained, max_marks").eq("school_id", school_id).in_("student_id", student_ids).execute().data
        attendance = sb.table("attendance").select("student_id, status").eq("school_id", school_id).in_("student_id", student_ids).execute().data

        at_risk = []
        for s in students:
            sid = s["id"]
            s_results = [r for r in results if r["student_id"] == sid]
            s_att = [a for a in attendance if a["student_id"] == sid]

            avg_score = 0
            if s_results:
                total = sum(float(r["marks_obtained"]) for r in s_results)
                max_total = sum(float(r["max_marks"]) for r in s_results)
                avg_score = (total / max_total * 100) if max_total > 0 else 0

            att_pct = 0
            if s_att:
                present = sum(1 for a in s_att if a["status"] == "present")
                att_pct = (present / len(s_att) * 100)

            issues = []
            if avg_score < 50:
                issues.append(f"Low score: {avg_score:.1f}%")
            if att_pct < 75:
                issues.append(f"Low attendance: {att_pct:.1f}%")

            if issues:
                at_risk.append({"name": s["full_name"], "issues": issues})

        if not at_risk:
            return f"No at-risk students in {class_name}. Great job! 🎉"

        buf = [f"⚠️ At-Risk Students in {class_name}:"]
        for s in at_risk:
            buf.append(f"  ❌ {s['name']}:")
            for issue in s["issues"]:
                buf.append(f"     • {issue}")

        return "\n".join(buf)

    @tool
    def generate_questions(subject: str, topic: str, grade: str, question_type: str = "mixed", count: int = 10, difficulty: str = "medium") -> str:
        """Generate exam or practice questions.
        Input: subject, topic, grade (e.g. 'Class 10'), question_type ('mcq'|'short_answer'|'long_answer'|'mixed'), count, difficulty ('easy'|'medium'|'hard').
        Use when teacher asks to generate questions, create question paper, or make quiz."""
        llm = _llm()
        prompt = f"Generate {count} {difficulty} {question_type} questions for {grade} {subject} on topic: {topic}.\n\nFormat each question with:\n- Question number\n- Question text\n- For MCQ: 4 options (A, B, C, D) and mark the correct answer\n- For subjective: mention marks and expected answer length\n- NCERT aligned where applicable\n\nOutput as clean numbered list."
        response = llm.invoke(prompt)
        return response.content

    @tool
    def create_lesson_plan(subject: str, topic: str, grade: str, duration_minutes: int = 45) -> str:
        """Generate a structured lesson plan for a class.
        Input: subject, topic, grade, duration in minutes.
        Use when teacher asks for lesson plan or teaching plan."""
        llm = _llm()
        prompt = f"Create a {duration_minutes}-minute lesson plan for:\nSubject: {subject}\nTopic: {topic}\nGrade: {grade}\n\nInclude:\n- Learning objectives\n- Teaching materials needed\n- Step-by-step activities with time allocations\n- Q&A section\n- Assessment questions\n- Homework assignment\n- NCERT curriculum aligned\n\nMake it practical and easy to follow."
        response = llm.invoke(prompt)
        return response.content

    @tool
    def auto_grade_homework(submission_id: str, marks: float, grade: str, remarks: str = "") -> str:
        """Grade a homework submission.
        Input: submission_id, marks awarded, grade (A+/A/B+/B/C/D/F), optional remarks.
        Use when teacher wants to grade a submission."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        sb.table("homework_submissions").update({
            "status": "graded",
            "marks": marks,
            "grade": grade,
            "teacher_remarks": remarks,
            "graded_by": teacher_id,
            "graded_at": datetime.now().isoformat(),
        }).eq("id", submission_id).eq("school_id", school_id).execute()

        return f"Submission graded! ✅\nMarks: {marks} | Grade: {grade}\nRemarks: {remarks}"

    @tool
    def get_submission_status(homework_id: str) -> str:
        """Get submission statistics for a homework assignment.
        Input: homework_id.
        Use when teacher asks who submitted, submission count, or grading status."""
        sb = get_supabase()
        homework = sb.table("homework").select("title, target_class, max_marks").eq("id", homework_id).single().execute().data
        submissions = sb.table("homework_submissions").select("*, profiles(full_name)").eq("homework_id", homework_id).eq("school_id", school_id).execute().data

        total_submitted = len(submissions)
        graded = sum(1 for s in submissions if s.get("status") == "graded")
        pending = total_submitted - graded

        buf = [f"📝 Homework: {homework.get('title', '')} ({homework.get('target_class', '')})"]
        buf.append(f"  Total Submitted: {total_submitted}")
        buf.append(f"  ✅ Graded: {graded}")
        buf.append(f"  ⏳ Pending: {pending}")

        if pending > 0:
            buf.append("\n📋 Pending Submissions:")
            for s in submissions:
                if s.get("status") != "graded":
                    student_name = s.get("profiles", {}).get("full_name", "Unknown")
                    buf.append(f"  • {student_name} (submitted {s.get('submitted_at', '')[:10]})")

        return "\n".join(buf)

    @tool
    def generate_remedial_plan(student_name: str, weak_subjects: str) -> str:
        """Generate a remedial teaching plan for a struggling student.
        Input: student name, comma-separated weak subjects.
        Use when teacher asks for remedial plan for a weak student."""
        llm = _llm()
        prompt = f"Create a remedial teaching plan for student: {student_name}\nWeak subjects: {weak_subjects}\n\nInclude:\n- Root cause analysis (common misconceptions)\n- Step-by-step remediation strategy\n- Practice exercises (easy to hard)\n- Timeline (2-4 weeks)\n- Progress checkpoints\n- Parent communication tips\n\nMake it practical for a teacher to implement."
        response = llm.invoke(prompt)
        return response.content

    @tool
    def create_notice(title: str, content: str, category: str = "General", is_urgent: bool = False) -> str:
        """Create a school notice or announcement.
        Input: title, content, category ('Urgent'|'General'|'Event'|'Academic'), is_urgent (true/false).
        Use when teacher wants to create a notice or announcement."""
        sb = get_supabase()
        teacher_id = get_current_user_id()
        profile = sb.table("profiles").select("full_name").eq("id", teacher_id).single().execute().data

        sb.table("notices").insert({
            "school_id": school_id,
            "title": title,
            "content": content,
            "category": category,
            "author_id": teacher_id,
            "author_name": profile.get("full_name", ""),
            "is_urgent": is_urgent,
            "status": "published",
        }).execute()

        return f"Notice published! 📢\nTitle: {title}\nCategory: {category}\n{'🚨 Urgent' if is_urgent else ''}"

    @tool
    def get_attendance_stats(class_name: str, date: str = "today") -> str:
        """Get attendance statistics for a class on a specific date.
        Input: class name, date (DD/MM/YYYY or 'today').
        Use when teacher asks about attendance, who's absent, or attendance report."""
        sb = get_supabase()
        if date == "today":
            query_date = datetime.now().strftime("%Y-%m-%d")
        else:
            try:
                query_date = datetime.strptime(date, "%d/%m/%Y").strftime("%Y-%m-%d")
            except ValueError:
                query_date = datetime.now().strftime("%Y-%m-%d")

        attendance = sb.table("attendance").select("status, profiles(full_name, roll_number)").eq("school_id", school_id).eq("date", query_date).execute().data
        students = sb.table("profiles").select("id, full_name, roll_number").eq("school_id", school_id).eq("class", class_name).eq("role", "student").execute().data

        student_ids = {s["id"]: s for s in students}
        class_attendance = [a for a in attendance if a.get("student_id") in student_ids]

        present = [a for a in class_attendance if a["status"] == "present"]
        absent = [a for a in class_attendance if a["status"] == "absent"]
        late = [a for a in class_attendance if a["status"] == "late"]

        buf = [f"📊 Attendance for {class_name} on {query_date}:"]
        buf.append(f"  ✅ Present: {len(present)}")
        buf.append(f"  ❌ Absent: {len(absent)}")
        buf.append(f"  ⏰ Late: {len(late)}")
        buf.append(f"  📈 Percentage: {(len(present) / len(class_attendance) * 100) if class_attendance else 0:.1f}%")

        if absent:
            buf.append("\n❌ Absent Students:")
            for a in absent:
                student = student_ids.get(a["student_id"], {})
                buf.append(f"  • {student.get('full_name', 'Unknown')} (Roll: {student.get('roll_number', '?')})")

        return "\n".join(buf)

    @tool
    def get_teacher_schedule(day: str = "week") -> str:
        """Get the teacher's own schedule.
        Input: a day name like 'monday', a date like '25 May', 'today', 'tomorrow', or 'week' for the full week schedule.
        Use when teacher asks about their schedule, classes, or timetable on a specific day/date."""
        sb = get_supabase()
        teacher_id = get_current_user_id()
        day_map = {"monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5}
        
        # Resolve day string to a weekday name
        resolved_day = parse_date_to_weekday(day)
        
        if resolved_day == "sunday":
            return "No classes scheduled for Sunday. Free day! Enjoy! 🎉"

        query = sb.table("timetable").select("*, subjects(name, icon)").eq("school_id", school_id).eq("teacher_id", teacher_id).order("start_time")

        if resolved_day in day_map:
            query = query.eq("day_of_week", day_map[resolved_day])

        schedule = query.execute().data
        if not schedule:
            day_display = resolved_day if resolved_day else day
            return f"No classes scheduled for {day_display}. Free day! 🎉"

        day_title = resolved_day.title() if resolved_day else "Full Week"
        buf = [f"📅 Your Schedule ({day_title}):"]
        for item in schedule:
            subj = item.get("subjects", {})
            buf.append(f"  {subj.get('icon', '📚')} {subj.get('name', 'Unknown')} — {item.get('start_time', '')} to {item.get('end_time', '')}")
            buf.append(f"     Class: {item.get('class', '?')} | Room: {item.get('room', 'TBD')}")

        return "\n".join(buf)

    @tool
    def get_pending_tasks() -> str:
        """Get all pending tasks for the teacher including ungraded submissions and leave approvals.
        Use when teacher asks about pending work, tasks, or what needs attention."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        homework = sb.table("homework").select("id, title").eq("teacher_id", teacher_id).eq("status", "active").execute().data
        ungraded = 0
        for hw in homework:
            subs = sb.table("homework_submissions").select("id").eq("homework_id", hw["id"]).eq("status", "submitted").execute().data
            ungraded += len(subs)

        pending_leaves = sb.table("leave_applications").select("id").eq("school_id", school_id).eq("status", "pending").execute().data

        buf = ["📋 Your Pending Tasks:"]
        buf.append(f"  📝 Ungraded Submissions: {ungraded}")
        buf.append(f"  🏖️ Leave Approvals Pending: {len(pending_leaves)}")

        return "\n".join(buf)

    @tool
    def generate_report(class_name: str) -> str:
        """Generate a comprehensive performance report for a class.
        Input: class name.
        Use when teacher asks for class report or performance summary."""
        llm = _llm()
        sb = get_supabase()
        students = sb.table("profiles").select("id, full_name").eq("school_id", school_id).eq("class", class_name).eq("role", "student").execute().data
        results = sb.table("results").select("student_id, marks_obtained, max_marks").eq("school_id", school_id).in_("student_id", [s["id"] for s in students]).execute().data

        student_data = []
        for s in students:
            s_results = [r for r in results if r["student_id"] == s["id"]]
            total = sum(float(r["marks_obtained"]) for r in s_results)
            max_total = sum(float(r["max_marks"]) for r in s_results)
            avg = (total / max_total * 100) if max_total > 0 else 0
            student_data.append({"name": s["full_name"], "avg": round(avg, 1)})

        class_avg = sum(s["avg"] for s in student_data) / len(student_data) if student_data else 0

        prompt = f"Generate a professional class performance report for {class_name}.\nClass average: {class_avg:.1f}%\nTotal students: {len(students)}\nStudent averages: {json.dumps(student_data[:10])}\n\nInclude: Executive summary, key metrics, top performers, students needing attention, recommendations, action items."
        response = llm.invoke(prompt)
        return response.content

    @tool
    def explain_pedagogy(topic: str) -> str:
        """Get teaching strategies and pedagogical advice for a topic.
        Input: topic or concept to teach.
        Use when teacher asks for teaching strategies or how to teach something."""
        llm = _llm()
        prompt = f"Provide teaching strategies for: {topic}\n\nInclude:\n- Differentiated instruction approaches\n- Engagement techniques\n- Assessment methods\n- Common misconceptions and how to address them\n- Real-world connections\n- Technology integration ideas\n\nKeep it practical for Indian school context."
        response = llm.invoke(prompt)
        return response.content

    @tool
    def get_leave_balance() -> str:
        """Get the teacher's leave balance and history.
        Use when teacher asks about leave balance, remaining leaves, or leave history."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        leaves = sb.table("leave_applications").select("*").eq("school_id", school_id).eq("applicant_id", teacher_id).order("created_at", ascending=False).limit(10).execute().data

        approved = sum(1 for l in leaves if l.get("status") == "approved")
        pending = sum(1 for l in leaves if l.get("status") == "pending")
        rejected = sum(1 for l in leaves if l.get("status") == "rejected")

        buf = ["🏖️ Leave Summary:"]
        buf.append(f"  ✅ Approved: {approved}")
        buf.append(f"  ⏳ Pending: {pending}")
        buf.append(f"  ❌ Rejected: {rejected}")
        buf.append(f"  📊 Total Applied: {len(leaves)}")

        if leaves:
            buf.append("\n📋 Recent Applications:")
            for l in leaves[:5]:
                status = {"approved": "✅", "pending": "⏳", "rejected": "❌"}.get(l.get("status"), "?")
                buf.append(f"  {status} {l.get('leave_type', '')}: {l.get('start_date', '')} to {l.get('end_date', '')}")

        return "\n".join(buf)

    @tool
    def get_salary_info(month: str = "") -> str:
        """Get salary information for the teacher.
        Input: month in 'YYYY-MM' format or empty for latest.
        Use when teacher asks about salary, pay, or compensation."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        query = sb.table("salary").select("*").eq("school_id", school_id).eq("teacher_id", teacher_id).order("month", ascending=False)
        if month:
            query = query.eq("month", month)
        salary = query.limit(1).maybe_single().execute().data

        if not salary:
            return "No salary records found."

        buf = [f"💰 Salary for {salary.get('month', '')}:"]
        buf.append(f"  Gross Salary: ₹{float(salary.get('gross_salary', 0)):,.2f}")
        buf.append(f"  Basic Pay: ₹{float(salary.get('basic_pay', 0)):,.2f}")
        buf.append(f"  HRA: ₹{float(salary.get('hra', 0)):,.2f}")
        buf.append(f"  DA: ₹{float(salary.get('da', 0)):,.2f}")
        buf.append(f"  Special Allowance: ₹{float(salary.get('special_allowance', 0)):,.2f}")
        buf.append(f"  --- Deductions ---")
        buf.append(f"  PF: ₹{float(salary.get('pf_deduction', 0)):,.2f}")
        buf.append(f"  TDS: ₹{float(salary.get('tds_deduction', 0)):,.2f}")
        buf.append(f"  Professional Tax: ₹{float(salary.get('professional_tax', 0)):,.2f}")
        buf.append(f"  ---")
        buf.append(f"  💵 Net Salary: ₹{float(salary.get('net_salary', 0)):,.2f}")
        buf.append(f"  Status: {salary.get('status', 'pending').title()}")

        return "\n".join(buf)

    @tool
    def upload_material(title: str, material_type: str, target_class: str, description: str = "") -> str:
        """Create a study material entry.
        Input: title, material_type ('Notes'|'PPTs'|'Videos'|'Worksheets'), target_class, description.
        Use when teacher wants to upload or share study materials."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        sb.table("study_materials").insert({
            "school_id": school_id,
            "teacher_id": teacher_id,
            "title": title,
            "description": description,
            "material_type": material_type,
            "target_class": target_class,
        }).execute()

        return f"Material created! 📚\nTitle: {title}\nType: {material_type}\nClass: {target_class}\n\nYou can now upload files through the app."

    @tool
    def get_exam_analytics(exam_id: str) -> str:
        """Get analytics for a completed exam including score distribution and statistics.
        Input: exam_id.
        Use when teacher asks about exam results, analytics, or performance."""
        sb = get_supabase()
        sessions = sb.table("exam_sessions").select("*, profiles(full_name)").eq("exam_id", exam_id).eq("school_id", school_id).order("total_marks", ascending=False).execute().data

        if not sessions:
            return "No exam sessions found for this exam."

        scores = [float(s.get("total_marks", 0)) for s in sessions]
        avg = sum(scores) / len(scores) if scores else 0
        highest = max(scores) if scores else 0
        lowest = min(scores) if scores else 0

        buf = [f"📊 Exam Analytics:"]
        buf.append(f"  Total Students: {len(sessions)}")
        buf.append(f"  Average Score: {avg:.1f}")
        buf.append(f"  Highest: {highest:.1f}")
        buf.append(f"  Lowest: {lowest:.1f}")
        buf.append("")
        buf.append("🏆 Top 5:")
        for i, s in enumerate(sessions[:5]):
            name = s.get("profiles", {}).get("full_name", "Unknown")
            buf.append(f"  #{i + 1} {name}: {s.get('total_marks', 0):.1f} ({s.get('total_correct', 0)} correct)")

        return "\n".join(buf)

    @tool
    def answer_general(question: str) -> str:
        """Answer general questions not related to school data.
        Use for general knowledge, teaching tips, or off-topic questions."""
        llm = _llm()
        response = llm.invoke(f"Answer this question concisely: {question}")
        return response.content

    return [
        get_class_students, get_class_performance, get_at_risk_students,
        generate_questions, create_lesson_plan, auto_grade_homework,
        get_submission_status, generate_remedial_plan, create_notice,
        get_attendance_stats, get_teacher_schedule, get_pending_tasks,
        generate_report, explain_pedagogy, get_leave_balance,
        get_salary_info, upload_material, get_exam_analytics, answer_general
    ]