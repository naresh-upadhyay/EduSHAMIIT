import os
import sys
import glob
import asyncio

from app.api.transport import exec_raw_sql

MIGRATIONS_DIR = "/app/../EduSHAMIIT Database/edushamiit-db/migrations"

async def run_all():
    print(f"=== 🚀 EDU-SHAMIIT DATABASE MIGRATION RUNNER ===")
    print(f"Directory: {MIGRATIONS_DIR}")
    
    # 1. Ensure tracking table
    await exec_raw_sql("""
        CREATE TABLE IF NOT EXISTS public.schema_migrations (
            version VARCHAR(255) PRIMARY KEY,
            applied_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        );
    """, fetch=False)
    
    # 2. Get applied migrations
    applied_rows = await exec_raw_sql("SELECT version FROM public.schema_migrations;", fetch=True)
    applied = {r["version"] for r in (applied_rows or []) if "version" in r}
    
    # 3. Find migration files
    files = sorted(glob.glob(os.path.join(MIGRATIONS_DIR, "*.sql")))
    print(f"Total Migration Files Found: {len(files)}")
    
    applied_count = 0
    skipped_count = 0
    failed_count = 0
    
    for filepath in files:
        filename = os.path.basename(filepath)
        with open(filepath, "r", encoding="utf-8") as f:
            sql_content = f.read().strip()
            
        if not sql_content:
            print(f"  [EMPTY] {filename}")
            continue
            
        try:
            print(f"  [RUNNING] {filename} ... ", end="", flush=True)
            await exec_raw_sql(sql_content, fetch=False)
            
            # Record in tracking table
            if filename not in applied:
                await exec_raw_sql("INSERT INTO public.schema_migrations (version) VALUES (%s) ON CONFLICT DO NOTHING;", (filename,), fetch=False)
            
            print("✅ SUCCESS")
            applied_count += 1
        except Exception as e:
            err_msg = str(e).split("\n")[0]
            # Ignore harmless duplicate/already exists errors
            if "already exists" in err_msg or "duplicate key" in err_msg:
                print(f"⚠️ SKIPPED ({err_msg})")
                skipped_count += 1
            else:
                print(f"❌ ERROR: {err_msg}")
                failed_count += 1

    # 4. Explicitly run Migration 216 rename & column drop
    print("\n=== EXECUTING MIGRATION 216: RENAME bus_routes -> vehicles & DROP route_name ===")
    try:
        check_bus_routes = await exec_raw_sql("SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bus_routes';", fetch=True)
        check_vehicles = await exec_raw_sql("SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicles';", fetch=True)
        
        if check_bus_routes and not check_vehicles:
            await exec_raw_sql("ALTER TABLE public.bus_routes RENAME TO vehicles;", fetch=False)
            print("  [SUCCESS] Renamed table 'bus_routes' to 'vehicles'.")
        else:
            print("  [INFO] Table 'vehicles' already exists or 'bus_routes' already renamed.")
            
        check_col = await exec_raw_sql("SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'route_name';", fetch=True)
        if check_col:
            await exec_raw_sql("ALTER TABLE public.vehicles DROP COLUMN route_name;", fetch=False)
            print("  [SUCCESS] Dropped 'route_name' column from 'vehicles' table.")
        else:
            print("  [INFO] Column 'route_name' already dropped from 'vehicles' table.")
    except Exception as e:
        print(f"  [ERROR] Migration 216 execution: {e}")

    print("\n==================================================")
    print(f"📊 SUMMARY: Applied/Processed: {applied_count} | Skipped: {skipped_count} | Errors: {failed_count}")
    print("==================================================")

if __name__ == "__main__":
    asyncio.run(run_all())
