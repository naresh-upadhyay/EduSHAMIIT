"""Assign seeded DB rows to real student user."""
import httpx

STUDENT_ID = '4b23bd15-8de9-4691-8676-abbc6d2ca846'
SCHOOL_ID  = '11111111-1111-1111-1111-111111111111'

sb_url = 'http://127.0.0.1:54321/rest/v1'
sb_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.FFGoBzCoT3bR0JMmOUFOOtvvZjGhMG1jN3sWeoM8l6w'
hdr = {
    'apikey': sb_key,
    'Authorization': f'Bearer {sb_key}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

PLACEHOLDER_IDS = [
    '10000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000003',
    'bb000001-0000-0000-0000-000000000001',
    'bb000002-0000-0000-0000-000000000002',
]

def update_table(table, field, placeholder_id, limit=5):
    r = httpx.get(f'{sb_url}/{table}', headers=hdr,
                  params={'select': 'id', field: f'eq.{placeholder_id}', 'limit': str(limit)})
    rows = r.json() if isinstance(r.json(), list) else []
    print(f'  {table} {field}={placeholder_id[:8]}...: {len(rows)} rows')
    for row in rows:
        upd = httpx.patch(f'{sb_url}/{table}', headers=hdr,
                          params={'id': f'eq.{row["id"]}'},
                          json={field: STUDENT_ID})
        print(f'    Updated {row["id"]}: {upd.status_code}')
    return len(rows)

print("=== Updating ATTENDANCE ===")
for pid in PLACEHOLDER_IDS[:3]:
    update_table('attendance', 'student_id', pid, limit=8)

print("\n=== Updating RESULTS ===")
for pid in PLACEHOLDER_IDS:
    update_table('results', 'student_id', pid, limit=8)

print("\n=== Updating FEES ===")
for pid in PLACEHOLDER_IDS[:3]:
    update_table('fees', 'student_id', pid, limit=5)

print("\n=== Updating HOMEWORK_SUBMISSIONS ===")
for pid in PLACEHOLDER_IDS[:2]:
    update_table('homework_submissions', 'student_id', pid, limit=5)

print("\n=== Updating STUDENT_ACHIEVEMENTS ===")
for pid in PLACEHOLDER_IDS[:2]:
    update_table('student_achievements', 'student_id', pid, limit=5)

print("\nDone!")
