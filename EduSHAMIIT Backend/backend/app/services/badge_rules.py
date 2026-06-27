from datetime import datetime, timezone
import json
import asyncio

async def evaluate_and_update_student_badges(sb, school_id: str, student_id: str):
    """
    Evaluates student statistics and updates achievements/XP by calling
    the stored procedure fn_evaluate_and_update_student_badges natively inside PostgreSQL.
    This resolves the N+1 query issue completely with a single database roundtrip.
    """
    try:
        # Execute natively in PostgreSQL / Supabase Database
        await sb.rpc("fn_evaluate_and_update_student_badges", {
            "p_school_id": school_id,
            "p_student_id": student_id
        }).aexecute()
        
        # Invalidate the Redis cache for this student's achievements
        from app.cache.redis_client import invalidate_student_achievements
        await invalidate_student_achievements(school_id, student_id)
        
    except Exception as e:
        print(f"Error evaluating student badges via RPC: {str(e)}", flush=True)
