"""Assign timetable + homework rows to the real teacher."""
import httpx

TEACHER_ID = '625e7620-801a-4e29-ae28-f66358e75952'
sb_url = 'http://127.0.0.1:54321/rest/v1'
sb_key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoic2VydmljZV9yb2xlIiwiaXNzIjoic3VwYWJhc2UiLCJpYXQiOjE2MDAwMDAwMDAsImV4cCI6MjAwMDAwMDAwMH0.FFGoBzCoT3bR0JMmOUFOOtvvZjGhMG1jN3sWeoM8l6w'
hdr = {
    'apikey': sb_key,
    'Authorization': f'Bearer {sb_key}',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
}

# Assign timetable rows from aa000002 to real teacher
r = httpx.get(f'{sb_url}/timetable', headers=hdr,
              params={'select': 'id', 'teacher_id': 'eq.aa000002-0000-0000-0000-000000000002', 'limit': '5'})
rows = r.json()
print(f'Timetable aa000002 rows: {len(rows)}')
for row in rows:
    upd = httpx.patch(f'{sb_url}/timetable', headers=hdr,
                      params={'id': f'eq.{row["id"]}'},
                      json={'teacher_id': TEACHER_ID})
    print(f'  timetable {row["id"]}: {upd.status_code}')

# Assign homework rows from aa000001 to real teacher
r2 = httpx.get(f'{sb_url}/homework', headers=hdr,
               params={'select': 'id', 'teacher_id': 'eq.aa000001-0000-0000-0000-000000000001', 'limit': '5'})
hw_rows = r2.json()
print(f'Homework aa000001 rows: {len(hw_rows)}')
for row in hw_rows:
    upd = httpx.patch(f'{sb_url}/homework', headers=hdr,
                      params={'id': f'eq.{row["id"]}'},
                      json={'teacher_id': TEACHER_ID})
    print(f'  homework {row["id"]}: {upd.status_code}')

# Also check salary rows
r3 = httpx.get(f'{sb_url}/salary', headers=hdr,
               params={'select': 'id', 'teacher_id': 'eq.aa000001-0000-0000-0000-000000000001', 'limit': '5'})
sal_rows = r3.json()
print(f'Salary aa000001 rows: {len(sal_rows)}')
for row in sal_rows:
    upd = httpx.patch(f'{sb_url}/salary', headers=hdr,
                      params={'id': f'eq.{row["id"]}'},
                      json={'teacher_id': TEACHER_ID})
    print(f'  salary {row["id"]}: {upd.status_code}')

print('Done!')
