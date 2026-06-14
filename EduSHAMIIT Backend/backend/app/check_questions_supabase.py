import asyncio
import os
import sys

# Add backend directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.services.supabase_client import get_supabase

async def test():
    sb = get_supabase()
    # Fetch all exams
    exams_res = await sb.table("exams").select("id, title").limit(5).aexecute()
    exams = exams_res.data or []
    print("Exams in Supabase:")
    for e in exams:
        print(f"  ID: {e['id']} | Title: {e['title']}")
        
    exam_ids = [e["id"] for e in exams]
    print(f"Exam IDs: {exam_ids}")
    
    if exam_ids:
        q_count_res = await sb.table("exam_questions").select("exam_id").in_("exam_id", exam_ids).aexecute()
        print(f"exam_questions result: {q_count_res.data}")

if __name__ == "__main__":
    asyncio.run(test())
