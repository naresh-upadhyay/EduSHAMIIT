import asyncio
import sys
import os
from dotenv import load_dotenv

# Load root .env
load_dotenv(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.env")))
os.environ["SUPABASE_URL"] = "http://127.0.0.1:8000"

# Add the parent directory to sys.path so we can import app
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.config import settings
from app.services.supabase_client import get_supabase

async def check():
    print("SUPABASE_URL:", settings.SUPABASE_URL)
    sb = get_supabase()
    # Fetch exams
    exams_res = await sb.table("exams").select("*").aexecute()
    print(f"Exams count: {len(exams_res.data)}")
    for e in exams_res.data:
        # Get count of questions
        q_res = await sb.table("exam_questions").select("id").eq("exam_id", e["id"]).aexecute()
        print(f"Exam: {e['title']} | ID: {e['id']} | Status: {e.get('status')} | Questions in DB: {len(q_res.data) if q_res.data else 0}")

if __name__ == "__main__":
    asyncio.run(check())
