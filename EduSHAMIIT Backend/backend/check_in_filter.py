import asyncio
import sys
import os
from dotenv import load_dotenv

# Load root .env
load_dotenv(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.env")))
os.environ["SUPABASE_URL"] = "http://127.0.0.1:8000"

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from app.services.supabase_client import get_supabase

async def check():
    sb = get_supabase()
    exam_ids = ["9da8b336-f9e5-46ac-982a-89cf3ba2ed86"] # Maths new exam ID
    
    # 1. Using client.in_ (which wraps in double quotes)
    res_in = await sb.table("exam_questions").select("exam_id").in_("exam_id", exam_ids).aexecute()
    print("With quotes (in_):", res_in.data)
    
    # 2. Manual filter without quotes
    q = sb.table("exam_questions").select("exam_id")
    q._filters.append("exam_id=in.(9da8b336-f9e5-46ac-982a-89cf3ba2ed86)")
    res_manual = await q.aexecute()
    print("Without quotes (manual):", res_manual.data)

if __name__ == "__main__":
    asyncio.run(check())
