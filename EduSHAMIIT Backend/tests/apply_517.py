import asyncio
import asyncpg

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

async def apply_migration():
    print("Connecting to DB to apply 517...")
    conn = await asyncpg.connect(DB_URL)
    with open(r"e:/EduSHAMIIT/EduSHAMIIT Database/edushamiit-db/migrations/517_device_registry_stored_procedures_and_isolation.sql", "r", encoding="utf-8") as f:
        sql = f.read()
    await conn.execute(sql)
    print("Migration 517 applied successfully!")
    await conn.close()

if __name__ == "__main__":
    asyncio.run(apply_migration())
