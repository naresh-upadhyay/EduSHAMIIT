import asyncio
import asyncpg

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

async def check():
    conn = await asyncpg.connect(DB_URL)
    defn = await conn.fetchval("""
        SELECT prosrc FROM pg_proc WHERE proname = 'fn_device_management_get_overview';
    """)
    print("Full fn_device_management_get_overview source:\n")
    print(defn)
    await conn.close()

if __name__ == "__main__":
    asyncio.run(check())
