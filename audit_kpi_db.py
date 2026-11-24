import psycopg2, json

conn = psycopg2.connect('postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres')
cur = conn.cursor()

# 1. Check Boards & Work Items counts in DB
cur.execute('''
    SELECT b.id, b.name, COUNT(w.id) as item_count
    FROM public.work_boards b
    LEFT JOIN public.work_items w ON w.board_id = b.id AND w.is_archived = false
    GROUP BY b.id, b.name
    ORDER BY b.created_at;
''')
boards = cur.fetchall()
print("=== BOARDS & WORK ITEMS IN DB ===")
total_board_items = 0
for b in boards:
    print(f"Board '{b[1]}' (id={b[0]}): {b[2]} items")
    total_board_items += b[2]
print(f"Total across boards: {total_board_items}")

cur.execute("SELECT COUNT(*) FROM public.work_items WHERE is_archived = false;")
total_all = cur.fetchone()[0]
print(f"Total unarchived work items in DB: {total_all}")

cur.execute('''
    SELECT 
        COUNT(*) as total,
        COUNT(*) FILTER (WHERE UPPER(status) IN ('NEW', 'OPEN', 'PLANNED', 'NOT STARTED', 'NOT_STARTED', 'TODO')) as new,
        COUNT(*) FILTER (WHERE UPPER(status) IN ('ACTIVE', 'IN_PROGRESS', 'IN PROGRESS', 'DOING', 'CRITICAL')) as active,
        COUNT(*) FILTER (WHERE UPPER(status) IN ('RESOLVED', 'TESTING', 'QA', 'CODE REVIEW')) as resolved,
        COUNT(*) FILTER (WHERE UPPER(status) IN ('COMPLETED', 'CLOSED', 'DONE')) as completed,
        COUNT(*) FILTER (WHERE due_date < CURRENT_DATE AND UPPER(status) NOT IN ('COMPLETED', 'CLOSED', 'DONE')) as overdue
    FROM public.work_items
    WHERE is_archived = false;
''')
kpi_all = cur.fetchone()
print(f"\n=== OVERALL DB KPIS ===")
print(f"Total: {kpi_all[0]}, New: {kpi_all[1]}, Active: {kpi_all[2]}, Resolved: {kpi_all[3]}, Completed: {kpi_all[4]}, Overdue: {kpi_all[5]}")

# Test sp_list_work_items_paged for NULL (All Boards)
cur.execute('''
    SELECT public.sp_list_work_items_paged(
        '11111111-1111-1111-1111-111111111111'::UUID, NULL, NULL, 'All', 'All', NULL, 'All', NULL, 'created_at', 'DESC', 1, 100
    );
''')
res_paged = cur.fetchone()[0]
print("\n=== sp_list_work_items_paged (All Boards) ===")
print("Total returned:", res_paged.get('total'))
print("KPIs returned:", res_paged.get('kpis'))
print("Items in page 1:", len(res_paged.get('items', [])))

# Test per board
for b in boards:
    cur.execute('''
        SELECT public.sp_list_work_items_paged(
            '11111111-1111-1111-1111-111111111111'::UUID, %s::UUID, NULL, 'All', 'All', NULL, 'All', NULL, 'created_at', 'DESC', 1, 100
        );
    ''', (b[0],))
    res_b = cur.fetchone()[0]
    print(f"Board '{b[1]}': total={res_b.get('total')}, kpis={res_b.get('kpis')}, items_len={len(res_b.get('items', []))}")

conn.close()
