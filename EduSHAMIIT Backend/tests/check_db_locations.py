import asyncio
import json
import uuid
import asyncpg

DB_URL = "postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres"

async def check():
    conn = await asyncpg.connect(DB_URL)
    sid = uuid.UUID("11111111-1111-1111-1111-111111111111")
    
    # Check tree output for B1
    tree_raw = await conn.fetchval("SELECT sp_get_location_tree($1)", sid)
    tree = json.loads(tree_raw) if isinstance(tree_raw, str) else tree_raw
    b1_tree = next((b for b in tree["buildings"] if b["code"] == "B1"), None)
    print("Tree B1:")
    print("  id:", b1_tree["id"])
    print("  code:", b1_tree["code"])
    print("  floors:", [(f["id"], f["code"], f["name"]) for f in b1_tree.get("floors", [])])

    # Check building_floors in DB for B1
    b1_floors = await conn.fetch("SELECT id, floor_code, name, floor_level FROM building_floors WHERE building_id = $1", uuid.UUID(b1_tree["id"]))
    print("\nActual building_floors for B1:")
    for f in b1_floors:
        print("  floor:", f["id"], f["floor_code"], f["name"])

    # Check devices on each floor of B1
    for f in b1_floors:
        devs = await conn.fetch("SELECT id, device_name, floor_id FROM devices WHERE floor_id = $1", f["id"])
        print(f"  Floor {f['floor_code']} ({f['id']}): {len(devs)} devices")

    # Now let's call sp_list_devices for each floor
    for f in b1_floors:
        res = await conn.fetchval("SELECT sp_list_devices($1, '', $2, $3, NULL, 'All', 'All', 1, 10)", sid, uuid.UUID(b1_tree["id"]), f["id"])
        res_dict = json.loads(res) if isinstance(res, str) else res
        print(f"  sp_list_devices for floor {f['floor_code']}: total = {res_dict['total']}")

    await conn.close()

if __name__ == "__main__":
    asyncio.run(check())

async def check_rooms():
    conn = await asyncpg.connect(DB_URL)
    rooms = await conn.fetch("SELECT id, room_number, name FROM rooms WHERE floor_id = $1", uuid.UUID("3d6c8096-d7b4-4f98-bc3d-c41d924d4d3d"))
    print("\nGF Rooms:")
    for r in rooms:
        devs = await conn.fetch("SELECT id, device_name FROM devices WHERE room_id = $1", r["id"])
        print(f"  Room {r['room_number']} ({r['name']}): {len(devs)} devices (id: {r['id']})")
    await conn.close()

if __name__ == "__main__":
    asyncio.run(check_rooms())
