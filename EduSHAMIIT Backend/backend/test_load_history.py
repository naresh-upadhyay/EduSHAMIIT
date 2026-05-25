import os
import sys

from app.services.langchain_agent import load_history
from app.services.supabase_client import get_supabase

def test():
    print("Initializing Supabase Client...")
    try:
        sb = get_supabase()
        print(f"Supabase URL: {sb.url}")
        
        # Try a direct query to see if connection is ok
        print("Querying ai_chat_history to see if table is accessible...")
        res = sb.table("ai_chat_history").select("*").count("exact").limit(1).execute()
        print(f"Success! Record count in ai_chat_history: {res.count}")
        
        # Test load_history with a dummy session
        dummy_session = "bcad0959-b733-4c2a-a9b0-2d67729297a3"
        print(f"Loading history for session {dummy_session}...")
        history = load_history(dummy_session)
        print(f"History loaded: {len(history)} messages.")
        for idx, msg in enumerate(history):
            print(f"[{idx}] {msg.__class__.__name__}: {msg.content[:50]}...")
            
    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    test()
