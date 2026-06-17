import asyncio
import sys
import os
from dotenv import load_dotenv

# Load root .env
dotenv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.env"))
print("Dotenv path:", dotenv_path)
load_dotenv(dotenv_path)

# Set SUPABASE_URL if needed, but check from settings
# Add the parent directory to sys.path
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

os.environ["SUPABASE_URL"] = "http://127.0.0.1:8000"
from app.config import settings
from app.services.supabase_client import get_supabase

async def check():
    print("SUPABASE_URL:", settings.SUPABASE_URL)
    sb = get_supabase()
    
    # Check homework table columns
    hw_res = await sb.table("homework").select("*").limit(1).aexecute()
    if hw_res.data:
        print("Homework columns:", list(hw_res.data[0].keys()))
        print("Homework sample:", hw_res.data[0])
    else:
        print("No homework records found")
        
    # Check homework_submissions columns
    sub_res = await sb.table("homework_submissions").select("*").limit(1).aexecute()
    if sub_res.data:
        print("Submission columns:", list(sub_res.data[0].keys()))
        print("Submission sample:", sub_res.data[0])
    else:
        print("No submission records found")

if __name__ == "__main__":
    asyncio.run(check())
