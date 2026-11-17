import psycopg2

conn = psycopg2.connect('postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:5432/postgres')
conn.autocommit = True
cur = conn.cursor()

with open('e:/EduSHAMIIT/EduSHAMIIT Database/edushamiit-db/migrations/520_floor_plan_stored_procedures.sql', 'r', encoding='utf-8') as f:
    sql = f.read()

cur.execute(sql)
print("Migration 520 applied successfully!")

# Verify F1
cur.execute("SELECT fn_get_floor_plan_and_markers('8770a0e6-8aa9-4e65-9a85-539eabd5f9a6'::UUID);")
f1_res = cur.fetchone()[0]
print("\n=== F1 Verification ===")
print("Success:", f1_res['success'])
print("Title:", f1_res['floor_plan']['title'])
print("Available Floors:", len(f1_res['floor_plan']['available_floors']))
print("Rooms Count:", len(f1_res['floor_plan']['rooms_layout']))
print("Markers Count:", len(f1_res['markers']))
print("Legend Counts:", f1_res['legend'])

# Verify F2
cur.execute("SELECT fn_get_floor_plan_and_markers('b88cf8d5-d000-40ea-b1c5-be7534ca74ab'::UUID);")
f2_res = cur.fetchone()[0]
print("\n=== F2 Verification ===")
print("Success:", f2_res['success'])
print("Title:", f2_res['floor_plan']['title'])
print("Rooms Count:", len(f2_res['floor_plan']['rooms_layout']))
print("Markers Count:", len(f2_res['markers']))
print("Legend Counts:", f2_res['legend'])
for m in f2_res['markers']:
    print(f"  [{m['device_type']}] {m['device_code']} - pos: ({m['pos_x']}, {m['pos_y']}), room: {m['room_number']}")
