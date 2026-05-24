"""
Student Tools - 20 LangChain @tool functions for EduSHAMIIT student agent.
Each tool queries Supabase with school_id scoping for multi-tenant isolation.
AI-powered tools use ChatGoogleGenerativeAI (Gemini) via langchain-google-genai.
"""
import json
import os
from datetime import datetime, timedelta
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


def get_student_tools(school_id: str) -> list:
    """Return all 20 student tools scoped to this school."""

    def _llm():
        from app.agents.router import get_llm, get_fallback_llms
        base = get_llm("qa")
        fallbacks = get_fallback_llms()
        if fallbacks:
            return base.with_fallbacks(fallbacks)
        return base

    @tool
    def get_timetable(day: str = "week") -> str:
        """Get the student's class timetable.
        Input: a day name like 'monday', a date like '25 May', 'today', 'tomorrow', or 'week' for the full week timetable.
        Use when student asks about their schedule, timetable, classes, or what they have on a specific day/date."""
        sb = get_supabase()
        user_id = get_current_user_id()
        profile = sb.table("profiles").select("class").eq("id", user_id).single().execute().data
        if not profile:
            return "Could not find your class. Please contact admin."

        student_class = profile["class"]
        day_map = {"monday": 0, "tuesday": 1, "wednesday": 2, "thursday": 3, "friday": 4, "saturday": 5}
        
        # Resolve day string to a weekday name
        resolved_day = parse_date_to_weekday(day)
        
        if resolved_day == "sunday":
            return "No classes scheduled for Sunday. Enjoy! 🎉"

        query = sb.table("timetable").select("*, subjects(name, icon, color)").eq("school_id", school_id).eq("class", student_class).order("start_time")

        if resolved_day in day_map:
            query = query.eq("day_of_week", day_map[resolved_day])

        data = query.execute().data
        if not data:
            day_display = resolved_day if resolved_day else day
            return f"No classes scheduled for {day_display}. Enjoy! 🎉"

        days_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        buf = []
        current_day = None
        for item in data:
            dow = item.get('day_of_week', 0)
            if current_day != dow:
                current_day = dow
                buf.append(f"\n📅 {days_names[dow]}:")
            if item.get('is_break'):
                buf.append(f"  ☕ {item.get('break_name', 'Break')} ({item.get('start_time', '')} - {item.get('end_time', '')})")
            elif item.get('is_free_period'):
                buf.append(f"  🆓 Free Period ({item.get('start_time', '')} - {item.get('end_time', '')})")
            else:
                subj = item.get('subjects', {})
                buf.append(f"  {subj.get('icon', '📚')} {subj.get('name', 'Unknown')} - {item.get('start_time', '')} to {item.get('end_time', '')} (Room {item.get('room', 'TBD')})")

        return "\n".join(buf)

    @tool
    def get_homework(status: str = "pending") -> str:
        """Get homework assignments for the student.
        Input: 'pending', 'submitted', 'graded', or 'all'.
        Use when student asks about homework, assignments, or tasks."""
        sb = get_supabase()
        user_id = get_current_user_id()
        profile = sb.table("profiles").select("class").eq("id", user_id).single().execute().data
        if not profile:
            return "Could not find your class."

        homework = sb.table("homework").select("*, subjects(name, icon)").eq("school_id", school_id).eq("target_class", profile["class"]).eq("status", "active").order("due_date").execute().data
        submissions = sb.table("homework_submissions").select("homework_id, status, marks, grade").eq("student_id", user_id).execute().data
        sub_map = {s["homework_id"]: s for s in submissions}

        filtered = []
        for hw in homework:
            sub = sub_map.get(hw["id"])
            hw_status = sub["status"] if sub else "pending"
            if status == "all" or (status == "pending" and not sub) or (status == "submitted" and hw_status == "submitted") or (status == "graded" and hw_status == "graded"):
                filtered.append({
                    "title": hw.get("title", ""),
                    "subject": hw.get("subjects", {}).get("name", "Unknown"),
                    "icon": hw.get("subjects", {}).get("icon", "📝"),
                    "due_date": hw.get("due_date", "")[:10],
                    "max_marks": hw.get("max_marks"),
                    "status": hw_status,
                    "marks": sub.get("marks") if sub else None,
                    "grade": sub.get("grade") if sub else None,
                })

        if not filtered:
            return f"No {status} homework found. 🎉"

        buf = [f"📝 Homework ({status.title()}):"]
        for hw in filtered:
            buf.append(f"  {hw['icon']} {hw['title']} ({hw['subject']})")
            buf.append(f"     Due: {hw['due_date']} | Max Marks: {hw['max_marks']}")
            if hw['status'] == 'graded':
                buf.append(f"     ✅ Graded: {hw['marks']}/{hw['max_marks']} ({hw['grade']})")
            elif hw['status'] == 'submitted':
                buf.append(f"     ⏳ Submitted, awaiting grading")

        return "\n".join(buf)

    @tool
    def get_fee_status() -> str:
        """Check fee balance, pending dues, and payment history for the student.
        Use when student or parent asks about fees, payment, dues, or outstanding amount."""
        sb = get_supabase()
        user_id = get_current_user_id()

        fees = sb.table("fees").select("*").eq("school_id", school_id).eq("student_id", user_id).order("due_date").execute().data
        payments = sb.table("payments").select("*").eq("school_id", school_id).eq("student_id", user_id).order("paid_at", ascending=False).limit(3).execute().data

        total_outstanding = sum(float(f["amount"]) - float(f.get("amount_paid", 0)) for f in fees if f.get("status") in ("pending", "partial", "overdue"))
        total_paid = sum(float(f.get("amount_paid", 0)) for f in fees)

        buf = [f"💰 Fee Status:"]
        buf.append(f"  Total Outstanding: ₹{total_outstanding:,.2f}")
        buf.append(f"  Total Paid: ₹{total_paid:,.2f}")
        buf.append("")

        pending = [f for f in fees if f.get("status") in ("pending", "partial", "overdue")]
        if pending:
            buf.append("📋 Pending Fees:")
            for f in pending:
                due = f.get("due_date", "N/A")[:10]
                buf.append(f"  • {f.get('fee_type', 'Fee')}: ₹{float(f.get('amount', 0)):,.2f} (Due: {due})")

        if payments:
            buf.append("\n✅ Recent Payments:")
            for p in payments:
                buf.append(f"  • ₹{float(p.get('amount', 0)):,.2f} via {p.get('payment_method', 'N/A')} on {p.get('paid_at', 'N/A')[:10]}")

        return "\n".join(buf)

    @tool
    def get_attendance() -> str:
        """Get the student's attendance statistics including overall and subject-wise breakdown.
        Use when student asks about attendance, how many classes they've attended, or attendance percentage."""
        sb = get_supabase()
        user_id = get_current_user_id()

        attendance = sb.table("attendance").select("status, subjects(name)").eq("school_id", school_id).eq("student_id", user_id).execute().data

        if not attendance:
            return "No attendance records found yet."

        total = len(attendance)
        present = sum(1 for a in attendance if a["status"] == "present")
        absent = sum(1 for a in attendance if a["status"] == "absent")
        late = sum(1 for a in attendance if a["status"] == "late")
        pct = (present / total * 100) if total > 0 else 0

        subject_wise = {}
        for a in attendance:
            subj = a.get("subjects", {}).get("name", "Unknown")
            subject_wise.setdefault(subj, {"total": 0, "present": 0})
            subject_wise[subj]["total"] += 1
            if a["status"] == "present":
                subject_wise[subj]["present"] += 1

        buf = [f"📊 Attendance Report:"]
        buf.append(f"  Overall: {pct:.1f}% ({present} present, {absent} absent, {late} late out of {total} days)")
        buf.append("")
        buf.append("📚 Subject-wise:")
        for subj, data in subject_wise.items():
            subj_pct = (data["present"] / data["total"] * 100) if data["total"] > 0 else 0
            emoji = "✅" if subj_pct >= 75 else "⚠️" if subj_pct >= 50 else "❌"
            buf.append(f"  {emoji} {subj}: {subj_pct:.1f}% ({data['present']}/{data['total']})")

        return "\n".join(buf)

    @tool
    def get_exam_info() -> str:
        """Get upcoming exams for the student's class.
        Use when student asks about exams, test dates, exam schedule, or when exams are."""
        sb = get_supabase()
        user_id = get_current_user_id()
        profile = sb.table("profiles").select("class").eq("id", user_id).single().execute().data
        if not profile:
            return "Could not find your class."

        exams = sb.table("exams").select("*, subjects(name, icon)").eq("school_id", school_id).contains("target_classes", f'["{profile["class"]}"]').gte("exam_date", datetime.now().date().isoformat()).order("exam_date").execute().data

        if not exams:
            return "No upcoming exams scheduled. Use this time to prepare! 📚"

        buf = ["📝 Upcoming Exams:"]
        for ex in exams:
            subj = ex.get("subjects", {})
            buf.append(f"  {subj.get('icon', '📝')} {ex.get('title', 'Exam')} ({subj.get('name', 'Unknown')})")
            buf.append(f"     📅 {ex.get('exam_date', '')} | ⏰ {ex.get('start_time', 'TBD')} | ⏱️ {ex.get('duration_minutes', 90)} min")
            buf.append(f"     📍 {ex.get('venue', 'TBD')} | 📊 Total Marks: {ex.get('total_marks', 100)}")

        return "\n".join(buf)

    @tool
    def get_bus_location() -> str:
        """Get the live location of the student's school bus.
        Use when student or parent asks about bus location, ETA, or when the bus will arrive."""
        sb = get_supabase()
        user_id = get_current_user_id()

        transport = sb.table("student_transport").select("*, bus_routes(*), bus_stops(stop_name)").eq("school_id", school_id).eq("student_id", user_id).maybe_single().execute().data

        if not transport:
            return "You are not assigned to any bus route. Contact the transport office."

        bus_location = sb.table("bus_locations").select("*").eq("school_id", school_id).eq("route_id", transport.get("route_id")).order("recorded_at", ascending=False).limit(1).maybe_single().execute().data

        route = transport.get("bus_routes", {})
        stop = transport.get("bus_stops", {})

        buf = [f"🚌 Bus Tracking:"]
        buf.append(f"  Route: {route.get('route_name', 'N/A')}")
        buf.append(f"  Bus: {route.get('bus_number', 'N/A')}")
        buf.append(f"  Your Stop: {stop.get('stop_name', 'N/A')}")

        if bus_location:
            eta = bus_location.get("eta_minutes", "N/A")
            buf.append(f"  📍 Live Location: {bus_location.get('lat', 0):.4f}, {bus_location.get('lng', 0):.4f}")
            buf.append(f"  ⏱️ ETA: {eta} minutes")
            buf.append(f"  🚀 Speed: {bus_location.get('speed', 0):.1f} km/h")
        else:
            buf.append("  ⚠️ Live location unavailable (bus may not have started)")

        return "\n".join(buf)

    @tool
    def get_performance() -> str:
        """Get the student's academic performance summary including scores, grades, and trends.
        Use when student asks about their overall performance, how they're doing, or their scores."""
        sb = get_supabase()
        user_id = get_current_user_id()

        results = sb.table("results").select("*, subjects(name, icon)").eq("school_id", school_id).eq("student_id", user_id).order("created_at", ascending=False).limit(20).execute().data

        if not results:
            return "No exam results available yet."

        total = sum(float(r.get("marks_obtained", 0)) for r in results)
        max_total = sum(float(r.get("max_marks", 100)) for r in results)
        avg = (total / max_total * 100) if max_total > 0 else 0

        def _grade(pct):
            if pct >= 90: return "A+"
            if pct >= 80: return "A"
            if pct >= 70: return "B+"
            if pct >= 60: return "B"
            if pct >= 50: return "C"
            if pct >= 40: return "D"
            return "F"

        subj_scores = {}
        for r in results:
            subj = r.get("subjects", {}).get("name", "Unknown")
            icon = r.get("subjects", {}).get("icon", "📚")
            subj_scores.setdefault(subj, {"total": 0, "max": 0, "icon": icon, "count": 0})
            subj_scores[subj]["total"] += float(r.get("marks_obtained", 0))
            subj_scores[subj]["max"] += float(r.get("max_marks", 100))
            subj_scores[subj]["count"] += 1

        buf = [f"📊 Academic Performance:"]
        buf.append(f"  Overall Average: {avg:.1f}% ({_grade(avg)})")
        buf.append(f"  Total Exams: {len(results)}")
        buf.append("")
        buf.append("📚 Subject-wise Averages:")
        for subj, data in subj_scores.items():
            subj_avg = (data["total"] / data["max"] * 100) if data["max"] > 0 else 0
            buf.append(f"  {data['icon']} {subj}: {subj_avg:.1f}% ({_grade(subj_avg)})")

        return "\n".join(buf)

    @tool
    def generate_study_plan(weak_subjects: str = "") -> str:
        """Generate a personalized study plan for the student based on upcoming exams and weak areas.
        Input: comma-separated weak subjects (e.g. 'Physics, Chemistry') or empty for auto-detect.
        Use when student asks for study plan, how to prepare, or study tips."""
        llm = _llm()
        sb = get_supabase()
        user_id = get_current_user_id()
        profile = sb.table("profiles").select("class").eq("id", user_id).single().execute().data

        exams = sb.table("exams").select("title, exam_date, subjects(name)").eq("school_id", school_id).contains("target_classes", f'["{profile.get("class", "")}"]').gte("exam_date", datetime.now().date().isoformat()).order("exam_date").limit(5).execute().data

        exam_info = "\n".join([f"- {e.get('title', '')} ({e.get('subjects', {}).get('name', '')}) on {e.get('exam_date', '')}" for e in exams]) if exams else "No upcoming exams found"

        prompt = f"Create a practical study plan for a Class {profile.get('class', '')} student.\n\nUpcoming exams:\n{exam_info}\n\nWeak subjects: {weak_subjects if weak_subjects else 'Auto-detect from exam dates'}\n\nInclude: Daily schedule, subject prioritization, break times, revision strategies, quick tips. Keep it concise and actionable."

        response = llm.invoke(prompt)
        return response.content

    @tool
    def explain_concept(concept: str, subject: str = "") -> str:
        """Explain an academic concept in simple terms with examples.
        Input: concept to explain, optionally with subject.
        Use when student asks 'what is', 'explain', 'how does', 'define' something."""
        llm = _llm()
        prompt = f"Explain the concept: {concept}\nSubject: {subject if subject else 'General'}\n\nRequirements:\n- Simple language suitable for school students\n- Use analogies and real-life examples\n- Include a quick memory trick\n- Mention if it's important for exams\n- Keep it under 200 words"

        response = llm.invoke(prompt)
        return response.content

    @tool
    def get_notifications() -> str:
        """Get recent notifications for the student.
        Use when student asks about notifications, alerts, or updates."""
        sb = get_supabase()
        user_id = get_current_user_id()

        notifications = sb.table("notifications").select("*").eq("school_id", school_id).eq("user_id", user_id).order("created_at", ascending=False).limit(10).execute().data

        if not notifications:
            return "No new notifications. 🔔"

        buf = ["🔔 Recent Notifications:"]
        for n in notifications:
            read = "✅" if n.get("is_read") else "🔵"
            buf.append(f"  {read} {n.get('title', '')}")
            buf.append(f"     {n.get('body', '')[:80]}...")

        return "\n".join(buf)

    @tool
    def get_library_status() -> str:
        """Get the student's library book borrowing status.
        Use when student asks about library books, borrowed books, or due dates."""
        sb = get_supabase()
        user_id = get_current_user_id()

        borrows = sb.table("library_borrows").select("*, library_books(title, author)").eq("school_id", school_id).eq("student_id", user_id).in_("status", ["borrowed", "overdue"]).execute().data

        if not borrows:
            return "No books currently borrowed. Visit the library! 📚"

        buf = ["📚 Library Books:"]
        for b in borrows:
            book = b.get("library_books", {})
            status = "⚠️ OVERDUE" if b.get("status") == "overdue" else "📖 Borrowed"
            buf.append(f"  {status}: {book.get('title', 'Unknown')} by {book.get('author', 'Unknown')}")
            buf.append(f"     Due: {b.get('due_at', '')[:10]} | Fine: ₹{b.get('fine_amount', 0)}")

        return "\n".join(buf)

    @tool
    def get_achievements() -> str:
        """Get the student's earned achievements and badges.
        Use when student asks about achievements, badges, rewards, or progress."""
        sb = get_supabase()
        user_id = get_current_user_id()

        profile = sb.table("profiles").select("xp_points, learning_streak, best_streak").eq("id", user_id).single().execute().data
        achievements = sb.table("student_achievements").select("*, achievements(name, description, icon, rarity, xp_reward)").eq("school_id", school_id).eq("student_id", user_id).order("earned_at", ascending=False).execute().data

        buf = [f"🏆 Achievements:"]
        buf.append(f"  ⭐ XP Points: {profile.get('xp_points', 0)}")
        buf.append(f"  🔥 Current Streak: {profile.get('learning_streak', 0)} days")
        buf.append(f"  🏅 Best Streak: {profile.get('best_streak', 0)} days")
        buf.append("")

        if achievements:
            buf.append("🎖️ Badges Earned:")
            for a in achievements:
                ach = a.get("achievements", {})
                buf.append(f"  {ach.get('icon', '🏆')} {ach.get('name', 'Unknown')} ({ach.get('rarity', 'common')})")
                buf.append(f"     +{ach.get('xp_reward', 0)} XP | {ach.get('description', '')}")
        else:
            buf.append("No badges earned yet. Keep working! 💪")

        return "\n".join(buf)

    @tool
    def get_events() -> str:
        """Get upcoming school events.
        Use when student asks about events, competitions, functions, or activities."""
        sb = get_supabase()

        events = sb.table("events").select("*").eq("school_id", school_id).gte("event_date", datetime.now().date().isoformat()).order("event_date").limit(10).execute().data

        if not events:
            return "No upcoming events. Stay tuned! 🎉"

        buf = ["🎉 Upcoming Events:"]
        for e in events:
            buf.append(f"  🎊 {e.get('title', '')}")
            buf.append(f"     📅 {e.get('event_date', 'TBD')} | ⏰ {e.get('event_time', 'TBD')}")
            buf.append(f"     📍 {e.get('venue', 'TBD')}")
            if e.get("max_participants"):
                buf.append(f"     👥 {e.get('current_participants', 0)}/{e.get('max_participants', 0)} registered")

        return "\n".join(buf)

    @tool
    def get_leaderboard() -> str:
        """Get the class leaderboard based on XP points.
        Use when student asks about leaderboard, ranking, or who has the most XP."""
        sb = get_supabase()
        user_id = get_current_user_id()
        profile = sb.table("profiles").select("class").eq("id", user_id).single().execute().data

        students = sb.table("profiles").select("id, full_name, xp_points, learning_streak").eq("school_id", school_id).eq("class", profile.get("class", "")).eq("role", "student").order("xp_points", ascending=False).limit(10).execute().data

        buf = [f"🏆 Class {profile.get('class', '')} Leaderboard:"]
        medals = ["🥇", "🥈", "🥉"]
        for i, s in enumerate(students):
            medal = medals[i] if i < 3 else f"#{i + 1}"
            buf.append(f"  {medal} {s.get('full_name', '')} — {s.get('xp_points', 0)} XP (🔥 {s.get('learning_streak', 0)} day streak)")

        return "\n".join(buf)

    @tool
    def submit_homework(homework_id: str, submission_text: str = "") -> str:
        """Submit homework assignment.
        Input: homework_id (from get_homework), submission_text (optional).
        Use when student wants to submit their homework."""
        sb = get_supabase()
        user_id = get_current_user_id()

        existing = sb.table("homework_submissions").select("id").eq("homework_id", homework_id).eq("student_id", user_id).maybe_single().execute()
        if existing.data:
            return "You've already submitted this homework! ✅"

        sb.table("homework_submissions").insert({
            "school_id": school_id,
            "homework_id": homework_id,
            "student_id": user_id,
            "submission_text": submission_text,
            "status": "submitted",
        }).execute()

        try:
            sb.rpc("update_student_xp", {"p_school_id": school_id, "p_student_id": user_id, "p_xp_to_add": 50, "p_action": "homework_submission"}).execute()
        except Exception:
            pass

        return "Homework submitted successfully! 🎉 You earned +50 XP!"

    @tool
    def apply_leave(leave_type: str, start_date: str, end_date: str, reason: str) -> str:
        """Apply for leave.
        Input: leave_type ('sick','casual','other'), start_date (DD/MM/YYYY), end_date (DD/MM/YYYY), reason.
        Use when student wants to apply for leave or is absent."""
        sb = get_supabase()
        user_id = get_current_user_id()

        try:
            start = datetime.strptime(start_date, "%d/%m/%Y").date()
            end = datetime.strptime(end_date, "%d/%m/%Y").date()
        except ValueError:
            return "Invalid date format. Please use DD/MM/YYYY."

        sb.table("leave_applications").insert({
            "school_id": school_id,
            "applicant_id": user_id,
            "applicant_role": "student",
            "leave_type": leave_type,
            "start_date": str(start),
            "end_date": str(end),
            "reason": reason,
            "status": "pending",
        }).execute()

        return f"Leave application submitted! 📝\nType: {leave_type}\nFrom: {start_date} To: {end_date}\nStatus: Pending approval"

    @tool
    def get_notices() -> str:
        """Get recent school notices and announcements.
        Use when student asks about notices, announcements, circulars, or updates."""
        sb = get_supabase()

        notices = sb.table("notices").select("*").eq("school_id", school_id).eq("status", "published").order("published_at", ascending=False).limit(10).execute().data

        if not notices:
            return "No notices at the moment. 📢"

        buf = ["📢 Recent Notices:"]
        for n in notices:
            urgent = "🚨 " if n.get("is_urgent") else ""
            buf.append(f"  {urgent}{n.get('title', '')}")
            buf.append(f"     {n.get('content', '')[:100]}...")
            buf.append(f"     📅 {n.get('published_at', '')[:10]} | Category: {n.get('category', 'General')}")

        return "\n".join(buf)

    @tool
    def answer_general(question: str) -> str:
        """Answer general questions not related to school data.
        Use for general knowledge, fun facts, motivation, or off-topic questions."""
        llm = _llm()
        response = llm.invoke(f"Answer this question concisely: {question}")
        return response.content

    @tool
    def generate_practice(subject: str, topic: str = "", count: int = 5) -> str:
        """Generate practice questions for a subject and topic.
        Input: subject name, topic (optional), number of questions (default 5).
        Use when student wants practice questions or revision material."""
        llm = _llm()
        topic_str = f"on topic: {topic}" if topic else "general concepts"
        prompt = f"Generate {count} practice questions for {subject} {topic_str}.\nMix of MCQ and short answer. Include answers. NCERT aligned."
        response = llm.invoke(prompt)
        return response.content

    @tool
    def get_live_class() -> str:
        """Get currently live or upcoming live classes.
        Use when student asks about live classes, online classes, or video sessions."""
        sb = get_supabase()
        user_id = get_current_user_id()
        profile = sb.table("profiles").select("class").eq("id", user_id).single().execute().data

        classes = sb.table("live_classes").select("*, subjects(name, icon)").eq("school_id", school_id).eq("target_class", profile.get("class", "")).in_("status", ["live", "scheduled"]).order("scheduled_at").limit(5).execute().data

        if not classes:
            return "No live classes scheduled. 🎥"

        buf = ["🎥 Live Classes:"]
        for lc in classes:
            subj = lc.get("subjects", {})
            status = "🔴 LIVE NOW" if lc.get("is_live") else "📅 Scheduled"
            buf.append(f"  {status}: {subj.get('icon', '🎥')} {lc.get('title', '')}")
            buf.append(f"     ⏰ {lc.get('scheduled_at', '')[:16]} | ⏱️ {lc.get('duration_minutes', 60)} min")

        return "\n".join(buf)

    @tool
    def get_child_attendance(child_id: str) -> str:
        """Get attendance statistics for a parent's child.
        Input: child_id (student UUID).
        Use when parent asks about their child's attendance."""
        sb = get_supabase()
        child = sb.table("profiles").select("full_name, class").eq("id", child_id).eq("school_id", school_id).single().execute().data
        if not child:
            return "Child not found."

        attendance = sb.table("attendance").select("status, subjects(name)").eq("school_id", school_id).eq("student_id", child_id).execute().data

        if not attendance:
            return f"No attendance records found for {child['full_name']}."

        total = len(attendance)
        present = sum(1 for a in attendance if a["status"] == "present")
        absent = sum(1 for a in attendance if a["status"] == "absent")
        late = sum(1 for a in attendance if a["status"] == "late")
        pct = (present / total * 100) if total > 0 else 0

        subject_wise = {}
        for a in attendance:
            subj = a.get("subjects", {}).get("name", "Unknown")
            subject_wise.setdefault(subj, {"total": 0, "present": 0})
            subject_wise[subj]["total"] += 1
            if a["status"] == "present":
                subject_wise[subj]["present"] += 1

        buf = [f"📊 Attendance for {child['full_name']} ({child.get('class', '')}):"]
        buf.append(f"  Overall: {pct:.1f}% ({present} present, {absent} absent, {late} late out of {total} days)")
        buf.append("")
        buf.append("📚 Subject-wise:")
        for subj, data in subject_wise.items():
            subj_pct = (data["present"] / data["total"] * 100) if data["total"] > 0 else 0
            emoji = "✅" if subj_pct >= 75 else "⚠️" if subj_pct >= 50 else "❌"
            buf.append(f"  {emoji} {subj}: {subj_pct:.1f}% ({data['present']}/{data['total']})")

        return "\n".join(buf)

    @tool
    def get_child_results(child_id: str) -> str:
        """Get academic results for a parent's child.
        Input: child_id (student UUID).
        Use when parent asks about their child's exam results or performance."""
        sb = get_supabase()
        child = sb.table("profiles").select("full_name, class").eq("id", child_id).eq("school_id", school_id).single().execute().data
        if not child:
            return "Child not found."

        results = sb.table("results").select("*, subjects(name, icon)").eq("school_id", school_id).eq("student_id", child_id).order("created_at", ascending=False).limit(10).execute().data

        if not results:
            return f"No exam results available for {child['full_name']}."

        total = sum(float(r.get("marks_obtained", 0)) for r in results)
        max_total = sum(float(r.get("max_marks", 100)) for r in results)
        avg = (total / max_total * 100) if max_total > 0 else 0

        def _grade(pct):
            if pct >= 90: return "A+"
            if pct >= 80: return "A"
            if pct >= 70: return "B+"
            if pct >= 60: return "B"
            if pct >= 50: return "C"
            if pct >= 40: return "D"
            return "F"

        buf = [f"📊 Results for {child['full_name']} ({child.get('class', '')}):"]
        buf.append(f"  Overall Average: {avg:.1f}% ({_grade(avg)})")
        buf.append("")
        buf.append("📝 Recent Exams:")
        for r in results:
            subj = r.get("subjects", {})
            marks = float(r.get("marks_obtained", 0))
            max_marks = float(r.get("max_marks", 100))
            pct = (marks / max_marks * 100) if max_marks > 0 else 0
            buf.append(f"  {subj.get('icon', '📝')} {r.get('exam_title', 'Exam')} ({subj.get('name', '')}): {marks:.0f}/{max_marks:.0f} ({_grade(pct)})")

        return "\n".join(buf)

    return [
        get_timetable, get_homework, get_fee_status, get_attendance,
        get_exam_info, get_bus_location, get_performance,
        generate_study_plan, explain_concept, get_notifications,
        get_library_status, get_achievements, get_events,
        get_leaderboard, submit_homework, apply_leave,
        get_notices, answer_general, generate_practice, get_live_class,
        get_child_attendance, get_child_results
    ]
