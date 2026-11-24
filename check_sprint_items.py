import asyncio
import asyncpg

async def check_items():
    conn = await asyncpg.connect('postgresql://postgres:eduSHAMIIT2026_pg@localhost:54322/postgres')
    rows = await conn.fetch('''
        SELECT w.item_number, w.title, w.work_type, w.status, b.name as board, COALESCE(w.team_name, wt.name, 'No Team') as team, s.name as sprint
        FROM public.work_items w
        LEFT JOIN public.work_boards b ON b.id = w.board_id
        LEFT JOIN public.work_teams wt ON wt.id = w.team_id
        LEFT JOIN public.work_sprints s ON s.id = w.sprint_id
        WHERE w.sprint_id IS NOT NULL AND w.is_archived = FALSE
        ORDER BY s.name, w.item_number;
    ''')
    for r in rows:
        print(f"[{r['sprint']}] {r['item_number']} ({r['work_type']}) - {r['title'][:35]} | Board: {r['board']} | Team: {r['team']}")
    await conn.close()

if __name__ == '__main__':
    asyncio.run(check_items())
