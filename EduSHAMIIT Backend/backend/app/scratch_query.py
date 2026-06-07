import asyncio
from app.services.supabase_client import get_supabase

async def main():
    sb = get_supabase()
    res = await sb.table("live_class_recordings").select("*").aexecute()
    print("LIVE CLASS RECORDINGS:")
    for row in res.data or []:
        print(row)
        
    lc_res = await sb.table("live_classes").select("id, status, is_live, recording_url").eq("id", "73000000-0000-0000-0000-000000000001").aexecute()
    print("LIVE CLASSES:")
    for row in lc_res.data or []:
        print(row)

if __name__ == "__main__":
    asyncio.run(main())
