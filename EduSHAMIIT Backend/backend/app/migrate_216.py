import asyncio
from app.api.transport import exec_raw_sql

async def run_migration_216():
    print("=== EXECUTING MIGRATION 216: RENAME bus_routes -> vehicles & DROP route_name ===")
    
    # 1. Rename table if bus_routes exists
    check_bus_routes = await exec_raw_sql(
        "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'bus_routes';",
        fetch=True
    )
    check_vehicles = await exec_raw_sql(
        "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'vehicles';",
        fetch=True
    )
    
    if check_bus_routes and not check_vehicles:
        print("[ACTION] Renaming table 'bus_routes' to 'vehicles'...")
        await exec_raw_sql("ALTER TABLE public.bus_routes RENAME TO vehicles;", fetch=False)
        print("[SUCCESS] Table renamed to 'vehicles'.")
    else:
        print("[INFO] Table 'bus_routes' already renamed or 'vehicles' table already exists.")

    # 2. Drop route_name column from vehicles table if present
    check_col = await exec_raw_sql(
        "SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'vehicles' AND column_name = 'route_name';",
        fetch=True
    )
    if check_col:
        print("[ACTION] Dropping 'route_name' column from 'vehicles' table...")
        await exec_raw_sql("ALTER TABLE public.vehicles DROP COLUMN route_name;", fetch=False)
        print("[SUCCESS] Column 'route_name' dropped from 'vehicles' table.")
    else:
        print("[INFO] Column 'route_name' already dropped or does not exist in 'vehicles' table.")

if __name__ == "__main__":
    asyncio.run(run_migration_216())
