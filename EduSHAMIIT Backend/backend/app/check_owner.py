import asyncio
from app.api.transport import exec_raw_sql

async def check_owner():
    owner = await exec_raw_sql("SELECT tableowner FROM pg_tables WHERE tablename='bus_routes';", fetch=True)
    curr = await exec_raw_sql("SELECT current_user, session_user;", fetch=True)
    print("Table owner:", owner)
    print("Current user:", curr)

if __name__ == "__main__":
    asyncio.run(check_owner())
