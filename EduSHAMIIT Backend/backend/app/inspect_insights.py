import asyncio
from app.api.attendance import exec_sql

async def run():
    rows = await exec_sql("SELECT pg_get_functiondef(oid) as fdef FROM pg_proc WHERE proname = 'fn_get_attendance_insights'")
    if rows:
        print(rows[0]['fdef'])
    else:
        print("Not found")

if __name__ == '__main__':
    asyncio.run(run())
