from datetime import datetime, timezone
import json

async def calculate_subject_average(sb, school_id: str, student_id: str, subject_name: str) -> float:
    # 1. Resolve subject IDs by name
    subs_res = await sb.table("subjects").select("id, name").eq("school_id", school_id).aexecute()
    subject_ids = [s["id"] for s in (subs_res.data or []) if s["name"].strip().lower() == subject_name.strip().lower()]
    if not subject_ids:
        return 0.0

    # 2. Fetch exam submissions
    subs_res = await sb.table("exam_submissions").select("score, exams(total_marks, subject_id)").eq("student_id", student_id).eq("status", "graded").aexecute()
    
    exam_score_sum = 0.0
    exam_max_sum = 0.0
    for sub in (subs_res.data or []):
        exam = sub.get("exams") or {}
        if exam.get("subject_id") in subject_ids:
            exam_score_sum += float(sub.get("score") or 0)
            exam_max_sum += float(exam.get("total_marks") or 100)

    # 3. Fetch legacy results
    legacy_res = await sb.table("results").select("marks_obtained, total_marks").eq("school_id", school_id).eq("student_id", student_id).in_("subject_id", subject_ids).aexecute()
    for r in (legacy_res.data or []):
        exam_score_sum += float(r.get("marks_obtained") or 0)
        exam_max_sum += float(r.get("total_marks") or 100)

    # 4. Fetch homework submissions
    hw_subs_res = await sb.table("homework_submissions").select("marks, homework(max_marks, subject_id)").eq("student_id", student_id).eq("status", "graded").aexecute()
    
    hw_score_sum = 0.0
    hw_max_sum = 0.0
    for hs in (hw_subs_res.data or []):
        hw = hs.get("homework") or {}
        if hw.get("subject_id") in subject_ids:
            hw_score_sum += float(hs.get("marks") or 0)
            hw_max_sum += float(hw.get("max_marks") or 25)

    has_exams = exam_max_sum > 0
    has_hw = hw_max_sum > 0

    exam_avg = (exam_score_sum / exam_max_sum) * 100 if has_exams else 0.0
    hw_avg = (hw_score_sum / hw_max_sum) * 100 if has_hw else 0.0

    if has_exams and has_hw:
        return (exam_avg * 0.6) + (hw_avg * 0.4)
    elif has_exams:
        return exam_avg
    elif has_hw:
        return hw_avg
    else:
        return 0.0

async def calculate_class_topper_progress(sb, school_id: str, student_id: str) -> float:
    # 1. Fetch student's profile to get class name
    prof_res = await sb.table("profiles").select("class").eq("id", student_id).maybe_single().aexecute()
    prof = prof_res.data
    if not prof or not prof.get("class"):
        return 0.0
    class_name = prof["class"]

    # 2. Fetch avg_score for all students in this class from student_profile_stats view
    stats_res = await sb.table("student_profile_stats").select("student_id, avg_score").eq("school_id", school_id).eq("class", class_name).aexecute()
    stats_list = stats_res.data or []
    if not stats_list:
        return 0.0

    # 3. Find this student's avg_score and the max avg_score in the class
    student_avg = 0.0
    topper_avg = 0.0
    for s in stats_list:
        avg = float(s.get("avg_score") or 0.0)
        if s["student_id"] == student_id:
            student_avg = avg
        topper_avg = max(topper_avg, avg)

    if topper_avg <= 0:
        return 0.0

    # If student is the topper (or tied for it), progress is 100.0%
    if student_avg >= topper_avg:
        return 100.0

    # Else, progress is relative to the topper
    return (student_avg / topper_avg) * 100.0

async def evaluate_progress(sb, school_id: str, student_id: str, rule_type: str, rule_params: dict) -> float:
    rule_params = rule_params or {}
    
    if rule_type == 'subject_average':
        subject_name = rule_params.get("subject_name")
        min_average = float(rule_params.get("min_average") or 90.0)
        
        if subject_name:
            avg = await calculate_subject_average(sb, school_id, student_id, subject_name)
            progress = (avg / min_average) * 100.0
        else:
            # Any exam score >= 90%
            max_exam_pct = 0.0
            subs_res = await sb.table("exam_submissions").select("score, exams(total_marks)").eq("student_id", student_id).eq("status", "graded").aexecute()
            for s in (subs_res.data or []):
                score = float(s.get("score") or 0)
                total = float(s.get("exams", {}).get("total_marks") or 100)
                if total > 0:
                    max_exam_pct = max(max_exam_pct, (score / total) * 100.0)

            legacy_res = await sb.table("results").select("marks_obtained, total_marks").eq("school_id", school_id).eq("student_id", student_id).aexecute()
            for r in (legacy_res.data or []):
                score = float(r.get("marks_obtained") or 0)
                total = float(r.get("total_marks") or 100)
                if total > 0:
                    max_exam_pct = max(max_exam_pct, (score / total) * 100.0)
            
            progress = (max_exam_pct / min_average) * 100.0
            
        return min(100.0, max(0.0, progress))
        
    elif rule_type == 'class_topper':
        progress = await calculate_class_topper_progress(sb, school_id, student_id)
        return min(100.0, max(0.0, progress))
        
    elif rule_type == 'attendance_pct':
        min_pct = float(rule_params.get("min_percentage") or 100.0)
        stats_res = await sb.table("student_profile_stats").select("attendance_pct").eq("student_id", student_id).maybe_single().aexecute()
        stats = stats_res.data
        att_pct = float((stats or {}).get("attendance_pct") or 0.0)
        
        progress = (att_pct / min_pct) * 100.0
        return min(100.0, max(0.0, progress))
        
    elif rule_type == 'homework_submissions':
        target_count = int(rule_params.get("count") or 5)
        hw_cnt_res = await sb.table("homework_submissions").select("id").count("exact").eq("student_id", student_id).eq("status", "graded").aexecute()
        hw_count = hw_cnt_res.count or 0
        
        progress = (hw_count / target_count) * 100.0
        return min(100.0, max(0.0, progress))
        
    elif rule_type == 'streak_days':
        min_days = int(rule_params.get("min_days") or 18)
        prof_res = await sb.table("profiles").select("learning_streak").eq("id", student_id).maybe_single().aexecute()
        prof = prof_res.data
        streak = int((prof or {}).get("learning_streak") or 0)
        
        progress = (streak / min_days) * 100.0
        return min(100.0, max(0.0, progress))

    elif rule_type == 'library_borrows':
        target_count = int(rule_params.get("count") or 10)
        borrows_res = await sb.table("library_borrows").select("id").count("exact").eq("student_id", student_id).aexecute()
        borrows_count = borrows_res.count or 0
        
        progress = (borrows_count / target_count) * 100.0
        return min(100.0, max(0.0, progress))
        
    elif rule_type == 'science_prodigy':
        min_average = float(rule_params.get("min_average") or 90.0)
        min_subjects = int(rule_params.get("min_subjects") or 2)
        
        stem_names = {'mathematics', 'physics', 'chemistry', 'biology', 'computer science'}
        subs_res = await sb.table("subjects").select("id, name").eq("school_id", school_id).aexecute()
        stem_subs = [s for s in (subs_res.data or []) if s["name"].strip().lower() in stem_names]
        
        count_above_threshold = 0
        for sub in stem_subs:
            avg = await calculate_subject_average(sb, school_id, student_id, sub["name"])
            if avg >= min_average:
                count_above_threshold += 1
                
        progress = (count_above_threshold / min_subjects) * 100.0
        return min(100.0, max(0.0, progress))
        
    return 0.0

async def evaluate_and_update_student_badges(sb, school_id: str, student_id: str):
    try:
        # 1. Fetch already earned/progress record IDs from student_achievements
        sa_res = await sb.table("student_achievements").select("id, achievement_id, progress, earned_at").eq("school_id", school_id).eq("student_id", student_id).aexecute()
        sa_map = {row["achievement_id"]: row for row in (sa_res.data or [])}
        
        # 2. Fetch all achievement templates
        templates_res = await sb.table("achievements").select("*").eq("school_id", school_id).aexecute()
        templates = templates_res.data or []
        
        for t in templates:
            t_id = t["id"]
            rule_type = t.get("rule_type")
            rule_params = t.get("rule_params")
            
            if not rule_type:
                continue
                
            existing_sa = sa_map.get(t_id)
            if existing_sa and float(existing_sa.get("progress") or 0) >= 100.0:
                continue
                
            calculated_progress = await evaluate_progress(sb, school_id, student_id, rule_type, rule_params)
            calculated_progress = round(calculated_progress, 1)
            
            if calculated_progress >= 100.0:
                # Award badge!
                sa_data = {
                    "school_id": school_id,
                    "student_id": student_id,
                    "achievement_id": t_id,
                    "progress": 100.0,
                    "earned_at": datetime.now(timezone.utc).isoformat()
                }
                if existing_sa:
                    await sb.table("student_achievements").update(sa_data).eq("id", existing_sa["id"]).aexecute()
                else:
                    await sb.table("student_achievements").insert(sa_data).aexecute()
                    
                # Credit the XP
                await sb.table("xp_transactions").insert({
                    "school_id": school_id,
                    "student_id": student_id,
                    "amount": t["xp_reward"],
                    "source_type": "achievement",
                    "source_id": t_id,
                    "description": f"Achievement unlocked: {t['name']}"
                }).aexecute()
                
                prof_res = await sb.table("profiles").select("xp_points").eq("id", student_id).maybe_single().aexecute()
                current_xp = 0
                if prof_res.data:
                    current_xp = prof_res.data.get("xp_points") or 0
                    
                await sb.table("profiles").update({"xp_points": current_xp + t["xp_reward"]}).eq("id", student_id).aexecute()
                
                # Send notification
                await sb.table("notifications").insert({
                    "school_id": school_id,
                    "user_id": student_id,
                    "title": f"🏆 Achievement Unlocked: {t['name']}",
                    "body": f"You earned {t['xp_reward']} XP! Keep it up! 🎉",
                    "type": "achievement",
                    "reference_id": t_id
                }).aexecute()
            else:
                # Save progress < 100% and set earned_at to NULL
                sa_data = {
                    "school_id": school_id,
                    "student_id": student_id,
                    "achievement_id": t_id,
                    "progress": calculated_progress,
                    "earned_at": None
                }
                if existing_sa:
                    await sb.table("student_achievements").update(sa_data).eq("id", existing_sa["id"]).aexecute()
                else:
                    await sb.table("student_achievements").insert(sa_data).aexecute()
                    
    except Exception as e:
        print(f"Error evaluating student badges: {str(e)}", flush=True)
