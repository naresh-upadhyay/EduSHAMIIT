import asyncio
import os
import json
from dotenv import load_dotenv

load_dotenv("e:/EduSHAMIIT/.env")

# Force loop policy or check if loop is running
try:
    loop = asyncio.get_event_loop()
except RuntimeError:
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)

from app.services.langchain_agent import process_message

async def run_test():
    # Setup dummy user mimicking a student login
    user = {
        "id": "073cf4b4-7678-4a9d-bca8-a186d4e3bf5e",
        "full_name": "Naresh Upadhyay",
        "role": "student",
        "class": "10A"
    }
    school_id = "11111111-1111-1111-1111-111111111111"
    session_id = "391bb577-32e5-41cb-a016-cea2ef5935c8"
    text = "Show my timetable"

    print(f"Starting E2E agent stream for prompt: '{text}'...")
    try:
        async for chunk in process_message(
            text=text,
            user=user,
            session_id=session_id,
            school_id=school_id
        ):
            print(f"Chunk: {json.dumps(chunk)}")
        print("\nSTREAM ENDED SUCCESSFULLY!")
    except Exception as e:
        print(f"\nCRITICAL AGENT ERROR: {e}")

if __name__ == "__main__":
    if loop.is_running():
        # run in current loop
        task = loop.create_task(run_test())
    else:
        loop.run_until_complete(run_test())
