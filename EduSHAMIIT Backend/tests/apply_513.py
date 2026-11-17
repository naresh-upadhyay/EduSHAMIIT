import asyncio
import asyncpg
import pathlib

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

async def run_migration():
    sql_path = pathlib.Path(r"e:\EduSHAMIIT\EduSHAMIIT Database\edushamiit-db\migrations\513_control_dashboard_crud_and_stored_procedures.sql")
    print(f"Reading migration from {sql_path}...")
    sql = sql_path.read_text(encoding="utf-8")
    
    print("Connecting to PostgreSQL at localhost:54322...")
    conn = await asyncpg.connect(DB_URL)
    try:
        print("Executing migration 513...")
        await conn.execute(sql)
        print("[SUCCESS] Migration 513 executed successfully!")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(run_migration())
