import asyncio
from datetime import datetime, timezone, timedelta
from dateutil.parser import parse
from app.services.supabase_client import get_supabase

async def auto_submit_expired_exams():
    try:
        sb = get_supabase()
        
        # 1. Fetch all exams that are not drafts
        exams_res = await sb.table("exams").select("*").neq("status", "draft").aexecute()
        exams = exams_res.data or []
        
        now = datetime.now(timezone.utc)
        expired_exam_ids = []
        exam_details_map = {}
        
        for exam in exams:
            exam_id = exam.get("id")
            start_time_str = exam.get("start_time")
            duration_mins = exam.get("duration_minutes") or 90
            
            if start_time_str and exam_id:
                try:
                    start_time = parse(start_time_str)
                    if start_time.tzinfo is None:
                        start_time = start_time.replace(tzinfo=timezone.utc)
                    end_time = start_time + timedelta(minutes=duration_mins)
                    if now >= end_time:
                        expired_exam_ids.append(exam_id)
                        exam_details_map[exam_id] = exam
                except Exception as e:
                    print(f"[ExamCleanup] Error parsing time for exam {exam_id}: {e}")
                    
        if not expired_exam_ids:
            return
            
        for exam_id in expired_exam_ids:
            exam = exam_details_map[exam_id]
            
            # Fetch all questions for this exam
            q_res = await sb.table("exam_questions").select("id, question_type, correct_answer, marks").eq("exam_id", exam_id).aexecute()
            questions = q_res.data or []
            has_subjective = any(q.get("question_type") == "subjective" for q in questions)
            
            # A. Process all incomplete proctoring sessions
            sessions_res = await sb.table("exam_sessions").select("*").eq("exam_id", exam_id).neq("status", "completed").aexecute()
            sessions = sessions_res.data or []
            
            # Fetch all submissions for this exam
            submissions_res = await sb.table("exam_submissions").select("*").eq("exam_id", exam_id).aexecute()
            submissions = submissions_res.data or []
            submission_map = {sub.get("student_id"): sub for sub in submissions}
            
            for session in sessions:
                student_id = session.get("student_id")
                session_id = session.get("id")
                
                if not student_id or not session_id:
                    continue
                    
                submission = submission_map.get(student_id)
                now_iso = datetime.now(timezone.utc).isoformat()
                now_time = datetime.now(timezone.utc).strftime("%H:%M:%S")
                
                submission_status = "submitted" if has_subjective else "graded"
                
                if submission:
                    if submission.get("status") == "active":
                        # Calculate objective score
                        answers = submission.get("answers") or {}
                        total_score = 0
                        for q in questions:
                            q_id = q["id"]
                            q_type = q.get("question_type")
                            correct = q.get("correct_answer")
                            student_ans = answers.get(str(q_id)) or answers.get(q_id)
                            if q_type != "subjective" and correct is not None and student_ans is not None:
                                if str(student_ans).strip().lower() == str(correct).strip().lower():
                                    total_score += q.get("marks", 0)
                                    
                        await sb.table("exam_submissions").update({
                            "status": submission_status,
                            "score": total_score if not has_subjective else None,
                            "submitted_at": now_iso,
                            "graded_at": now_iso if not has_subjective else None
                        }).eq("id", submission["id"]).aexecute()
                        print(f"[ExamCleanup] Auto-submitted active submission {submission['id']} for student {student_id}")
                else:
                    # Create empty submission
                    await sb.table("exam_submissions").insert({
                        "exam_id": exam_id,
                        "student_id": student_id,
                        "answers": {},
                        "score": 0 if not has_subjective else None,
                        "status": submission_status,
                        "submitted_at": now_iso,
                        "graded_at": now_iso if not has_subjective else None
                    }).aexecute()
                    print(f"[ExamCleanup] Created empty submission for student {student_id}")
                    
                # Mark session completed
                logs = session.get("proctor_logs") or []
                if not isinstance(logs, list):
                    logs = []
                logs.append({"time": now_time, "event": "Exam duration expired. Session auto-submitted by backend.", "severity": "info"})
                
                await sb.table("exam_sessions").update({
                    "status": "completed",
                    "ended_at": now_iso,
                    "proctor_logs": logs
                }).eq("id", session_id).aexecute()
                print(f"[ExamCleanup] Completed session {session_id} for student {student_id}")
                
            # B. Clean up any orphaned active submissions
            for submission in submissions:
                student_id = submission.get("student_id")
                if submission.get("status") == "active" and student_id:
                    # Calculate objective score
                    answers = submission.get("answers") or {}
                    total_score = 0
                    for q in questions:
                        q_id = q["id"]
                        q_type = q.get("question_type")
                        correct = q.get("correct_answer")
                        student_ans = answers.get(str(q_id)) or answers.get(q_id)
                        if q_type != "subjective" and correct is not None and student_ans is not None:
                            if str(student_ans).strip().lower() == str(correct).strip().lower():
                                total_score += q.get("marks", 0)
                                
                    now_iso = datetime.now(timezone.utc).isoformat()
                    submission_status = "submitted" if has_subjective else "graded"
                    await sb.table("exam_submissions").update({
                        "status": submission_status,
                        "score": total_score if not has_subjective else None,
                        "submitted_at": now_iso,
                        "graded_at": now_iso if not has_subjective else None
                    }).eq("id", submission["id"]).aexecute()
                    print(f"[ExamCleanup] Auto-submitted orphaned active submission {submission['id']} for student {student_id}")
                    
    except Exception as e:
        print(f"[ExamCleanup] Error in auto_submit_expired_exams: {e}")

async def start_exam_cleanup_scheduler(interval_seconds: int = 30):
    print(f"[ExamCleanup] Starting background auto-submit cleanup scheduler (interval: {interval_seconds}s)")
    while True:
        await auto_submit_expired_exams()
        await asyncio.sleep(interval_seconds)
