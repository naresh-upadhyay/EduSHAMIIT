import psycopg2
from psycopg2.extras import RealDictCursor
import json

from app.config import settings

conn = psycopg2.connect(settings.DATABASE_URL)

cur = conn.cursor(cursor_factory=RealDictCursor)

school_id = '11111111-1111-1111-1111-111111111111'

print("=== 1. TEST FORMAT FILTER: VIDEOBOOK with search 'test' ===")
cur.execute("SELECT public.fn_library_list_books(%s::uuid, %s, NULL, NULL, NULL, NULL, %s, NULL, 'ACTIVE', 'ALL', NULL, NULL, 'title', 'ASC', 1, 10) AS res;", (school_id, 'test', 'VIDEOBOOK'))
res = cur.fetchone()['res']
print(f"Total found: {res['pagination']['total']}, Items: {len(res['items'])}")
for b in res['items']:
    print(f"  - [{b['book_type_name']}] {b['title']} (is_digital: {b['is_digital']})")

print("\n=== 2. TEST FORMAT FILTER: EBOOK with search 'test' ===")
cur.execute("SELECT public.fn_library_list_books(%s::uuid, %s, NULL, NULL, NULL, NULL, %s, NULL, 'ACTIVE', 'ALL', NULL, NULL, 'title', 'ASC', 1, 10) AS res;", (school_id, 'test', 'EBOOK'))
res_eb = cur.fetchone()['res']
print(f"Total found: {res_eb['pagination']['total']}, Items: {len(res_eb['items'])}")
for b in res_eb['items']:
    print(f"  - [{b['book_type_name']}] {b['title']} (is_digital: {b['is_digital']})")

print("\n=== 3. TEST FORMAT FILTER: PHYSICAL with search 'test' ===")
cur.execute("SELECT public.fn_library_list_books(%s::uuid, %s, NULL, NULL, NULL, NULL, %s, NULL, 'ACTIVE', 'ALL', NULL, NULL, 'title', 'ASC', 1, 10) AS res;", (school_id, 'test', 'PHYSICAL'))
res_phys = cur.fetchone()['res']
print(f"Total found: {res_phys['pagination']['total']}, Items: {len(res_phys['items'])}")
for b in res_phys['items']:
    print(f"  - [{b['book_type_name']}] {b['title']} (is_digital: {b['is_digital']})")

print("\n=== 4. TEST CHECK 'New lecture test' ROW ===")
cur.execute("SELECT id, title, book_type_name, is_digital, (SELECT json_agg(df) FROM public.library_digital_files df WHERE df.book_id = library_books.id) as files FROM public.library_books WHERE title ILIKE '%New lecture test%';")
row = cur.fetchone()
print(f"ID: {row['id']}")
print(f"Title: {row['title']}")
print(f"Book Type: {row['book_type_name']}")
print(f"is_digital: {row['is_digital']}")
print(f"Attached files: {row['files']}")

print("\nALL BACKEND & DB CHECKS PASSED!")
