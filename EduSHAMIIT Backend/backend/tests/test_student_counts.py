import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import asyncio
from app.services.supabase_client import get_supabase

async def main():
    sb = get_supabase()
    res = await sb.table("schools").select("*").order("name").aexecute()
    schools = res.data or []
    
    profiles_res = await sb.table("profiles").select("school_id").aexecute()
    profiles = profiles_res.data or []
    
    student_counts = {}
    for p in profiles:
        sid = p.get("school_id")
        if sid:
            student_counts[sid] = student_counts.get(sid, 0) + 1
            
    print("--- Tenant Capacity verification ---")
    for s in schools:
        sid = s.get("id")
        name = s.get("name")
        max_stu = s.get("max_students")
        exist_stu = student_counts.get(sid, 0)
        print(f"School: {name} (ID: {sid}) -> {exist_stu} / {max_stu} Enrolled")

if __name__ == "__main__":
    asyncio.run(main())
