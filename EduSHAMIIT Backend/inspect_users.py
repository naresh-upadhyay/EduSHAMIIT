import asyncio
from backend.app.services.supabase_client import get_supabase

async def main():
    sb = get_supabase()
    res1 = await sb.table("profiles").select("*").eq("email", "naresh.king88898@gmail.com").maybe_single().aexecute()
    print("Student Profile:")
    print(res1.data)
    
    res2 = await sb.table("profiles").select("*").eq("email", "nehaupadhyay9119@gmail.com").maybe_single().aexecute()
    print("\nTeacher Profile:")
    print(res2.data)

if __name__ == "__main__":
    asyncio.run(main())
