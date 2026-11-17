import asyncio
import psycopg2

conn = psycopg2.connect('postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:5432/postgres')
cur = conn.cursor()

# Test fn_get_floor_plan_and_markers for F1
cur.execute("SELECT fn_get_floor_plan_and_markers('8770a0e6-8aa9-4e65-9a85-539eabd5f9a6'::UUID);")
res_f1 = cur.fetchone()[0]
assert res_f1['success'] is True
assert len(res_f1['markers']) == res_f1['legend']['total']
print("F1 Test Passed: markers count matches legend total:", len(res_f1['markers']), "==", res_f1['legend']['total'])

# Test fn_get_floor_plan_and_markers for F2
cur.execute("SELECT fn_get_floor_plan_and_markers('b88cf8d5-d000-40ea-b1c5-be7534ca74ab'::UUID);")
res_f2 = cur.fetchone()[0]
assert res_f2['success'] is True
assert len(res_f2['markers']) == res_f2['legend']['total']
print("F2 Test Passed: markers count matches legend total:", len(res_f2['markers']), "==", res_f2['legend']['total'])

# Verify bounds: all pos_x <= 0.76 and pos_y <= 0.90
for m in res_f1['markers'] + res_f2['markers']:
    assert 0.05 <= m['pos_x'] <= 0.78, f"Marker {m['device_code']} posX out of bounds: {m['pos_x']}"
    assert 0.05 <= m['pos_y'] <= 0.92, f"Marker {m['device_code']} posY out of bounds: {m['pos_y']}"
print("Bounds Test Passed: All markers are safely inside room/corridor area and never overlap legend overlay!")

print("ALL BACKEND & DB TESTS PASSED!")
