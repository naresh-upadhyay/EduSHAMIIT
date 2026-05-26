import asyncio
import os
import sys

# Add E:\EduSHAMIIT\EduSHAMIIT Backend to PYTHONPATH
sys.path.append(r"E:\EduSHAMIIT\EduSHAMIIT Backend\backend")

# Set dummy environment variable values if not already present
os.environ.setdefault("SUPABASE_URL", "http://localhost:8000") # or local postgres pooler/Supabase URL
# Actually let's load from E:\EduSHAMIIT\.env
from dotenv import load_dotenv
load_dotenv(r"E:\EduSHAMIIT\.env")

# Overwrite SUPABASE_URL to point to direct DB since we are running locally on host
os.environ["SUPABASE_URL"] = "http://localhost:8000"
# Let's inspect the .env file to see what port Kong is exposed on.
# Ah, .env has the configuration. Let's see what is there.
from app.services.supabase_client import get_supabase

async def main():
    sb = get_supabase()
    res = await sb.table("ai_chat_history").select("*").order("created_at", ascending=False).limit(5).aexecute()
    with open(r"E:\EduSHAMIIT\EduSHAMIIT Backend\scratch\chat_log_output.txt", "w", encoding="utf-8") as f:
        f.write("Last 5 messages:\n")
        for row in res.data:
            f.write(f"[{row['role']}] {row['content']}\n")
            f.write(f"Tool calls: {row['tool_calls']}\n")
            f.write("-" * 50 + "\n")
    print("Log written to E:\\EduSHAMIIT\\EduSHAMIIT Backend\\scratch\\chat_log_output.txt")

if __name__ == "__main__":
    asyncio.run(main())
