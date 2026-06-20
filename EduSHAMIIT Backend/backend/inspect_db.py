import asyncio
import sys
import os
from dotenv import load_dotenv

# Load root .env
dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.env"))
load_dotenv(dotenv_path)

os.environ["SUPABASE_URL"] = "http://127.0.0.1:8000"

sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.services.supabase_client import get_supabase

async def check():
    sb = get_supabase()
    res = await sb.table("profiles").select("full_name, class, xp_points").eq("role", "student").order("xp_points", ascending=False).aexecute()
    students = res.data or []
    print("=== Students Ordered by XP ===")
    for idx, s in enumerate(students, 1):
        print(f"{idx}. Name: {s.get('full_name')}, Class: {s.get('class')}, XP: {s.get('xp_points')}")

if __name__ == "__main__":
    asyncio.run(check())









if __name__ == "__main__":
    asyncio.run(check())






