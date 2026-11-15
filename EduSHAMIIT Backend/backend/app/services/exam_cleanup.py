import asyncio
from datetime import datetime, timezone, timedelta
from dateutil.parser import parse
from app.services.supabase_client import get_supabase


async def auto_submit_expired_exams():
    try:
        sb = get_supabase()

        exams_res = await sb.table("exams").select("*").neq("status", "draft").aexecute()
        exams = exams_res.data or []
        if not exams:
            return

        now = datetime.now(timezone.utc)
        mon_res = await sb.table("exam_monitoring_sessions").select("*").aexecute()
        mon_map = {m.get("exam_id"): m for m in (mon_res.data or []) if m.get("exam_id")}

        for exam in exams:
            exam_id = exam.get("id")
            start_time_str = exam.get("start_time")
            duration_mins = exam.get("duration_minutes") or 90
            if not exam_id:
                continue

            mon = mon_map.get(exam_id) or {}
            # Skip paused exams while frozen
            if mon.get("status") == "PAUSED":
                continue

            exam_extended_mins = mon.get("extended_minutes") or 0
            exam_paused_sec = mon.get("paused_total_seconds") or 0

            # Check global schedule end_time window if set
            exam_window_expired = False
            if start_time_str:
                try:
                    start_time = parse(start_time_str)
                    if start_time.tzinfo is None:
                        start_time = start_time.replace(tzinfo=timezone.utc)
                    window_end = (
                        start_time
                        + timedelta(minutes=duration_mins + exam_extended_mins)
                        + timedelta(seconds=exam_paused_sec)
                    )
                    exam_window_expired = now >= window_end
                except Exception as e:
                    print(f"[ExamCleanup] Error parsing time for exam {exam_id}: {e}")

            sessions_res = (
                await sb.table("exam_sessions")
                .select("*")
                .eq("exam_id", exam_id)
                .in_("status", ["in_progress", "active", "paused"])
                .aexecute()
            )
            sessions = sessions_res.data or []
            if not sessions and not exam_window_expired:
                continue

            q_res = (
                await sb.table("exam_questions")
                .select("id, question_type, correct_answer, marks")
                .eq("exam_id", exam_id)
                .aexecute()
            )
            questions = q_res.data or []
            has_subjective = any(
                (q.get("question_type") or "").lower() in ("subjective", "long", "short", "essay", "descriptive")
                for q in questions
            )

            submissions_res = await sb.table("exam_submissions").select("*").eq("exam_id", exam_id).aexecute()
            submissions = submissions_res.data or []
            submission_map = {sub.get("student_id"): sub for sub in submissions}

            for session in sessions:
                student_id = session.get("student_id")
                session_id = session.get("id")
                if not student_id or not session_id:
                    continue

                mon_status = (session.get("monitoring_status") or "").upper()
                if mon_status in ("SUBMITTED", "AUTO_SUBMITTED", "TERMINATED"):
                    continue
                if session.get("is_paused") and (session.get("timer_pause_policy") or "freeze") == "freeze":
                    continue

                # Check per-session expiration respecting extra_minutes & paused_total_seconds
                s_start_raw = session.get("started_at")
                session_expired = False
                if s_start_raw:
                    try:
                        s_start = parse(s_start_raw) if isinstance(s_start_raw, str) else s_start_raw
                        if s_start.tzinfo is None:
                            s_start = s_start.replace(tzinfo=timezone.utc)
                        s_extra = max(session.get("extra_minutes") or 0, exam_extended_mins)
                        s_paused = session.get("paused_total_seconds") or 0
                        s_end = s_start + timedelta(minutes=duration_mins + s_extra) + timedelta(seconds=s_paused)
                        session_expired = now >= s_end
                    except Exception:
                        session_expired = exam_window_expired
                else:
                    session_expired = exam_window_expired

                if not session_expired:
                    continue

                submission = submission_map.get(student_id)
                now_iso = datetime.now(timezone.utc).isoformat()
                now_time = datetime.now(timezone.utc).strftime("%H:%M:%S")
                submission_status = "submitted" if has_subjective else "graded"

                if submission:
                    if submission.get("status") == "active":
                        answers = submission.get("answers") or {}
                        total_score = 0
                        for q in questions:
                            q_id = q["id"]
                            q_type = (q.get("question_type") or "").lower()
                            correct = q.get("correct_answer")
                            student_ans = answers.get(str(q_id)) or answers.get(q_id)
                            if q_type not in ("subjective", "long", "short", "essay", "descriptive") and correct is not None and student_ans is not None:
                                if str(student_ans).strip().lower() == str(correct).strip().lower():
                                    total_score += q.get("marks", 0)

                        await sb.table("exam_submissions").update({
                            "status": submission_status,
                            "score": total_score if not has_subjective else None,
                            "submitted_at": now_iso,
                            "graded_at": now_iso if not has_subjective else None,
                        }).eq("id", submission["id"]).aexecute()
                else:
                    await sb.table("exam_submissions").insert({
                        "exam_id": exam_id,
                        "student_id": student_id,
                        "school_id": exam.get("school_id"),
                        "answers": {},
                        "score": 0 if not has_subjective else None,
                        "status": submission_status,
                        "submitted_at": now_iso,
                        "graded_at": now_iso if not has_subjective else None,
                    }).aexecute()

                logs = session.get("proctor_logs") or []
                if not isinstance(logs, list):
                    logs = []
                logs.append({
                    "time": now_time,
                    "event": "Exam duration expired. Session auto-submitted by backend.",
                    "severity": "info",
                })

                await sb.table("exam_sessions").update({
                    "status": "completed",
                    "monitoring_status": "AUTO_SUBMITTED",
                    "ended_at": now_iso,
                    "is_online": False,
                    "is_paused": False,
                    "proctor_logs": logs,
                }).eq("id", session_id).aexecute()

    except Exception as e:
        print(f"[ExamCleanup] Error in auto_submit_expired_exams: {e}")


async def start_exam_cleanup_scheduler(interval_seconds: int = 30):
    print(f"[ExamCleanup] Starting background auto-submit cleanup scheduler (interval: {interval_seconds}s)")
    while True:
        await auto_submit_expired_exams()
        await asyncio.sleep(interval_seconds)
