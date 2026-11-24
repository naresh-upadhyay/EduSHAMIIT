import asyncio
import asyncpg

async def main():
    conn = await asyncpg.connect('postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres')
    res = await conn.fetchval("SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'sp_get_sprint_dashboard';")
    with open('sp_get_sprint_dashboard.sql', 'w', encoding='utf-8') as f:
        f.write(res)
    print("Exported SQL, length:", len(res))
    await conn.close()

if __name__ == '__main__':
    asyncio.run(main())
