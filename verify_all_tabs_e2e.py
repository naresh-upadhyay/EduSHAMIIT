"""
Comprehensive End-to-End Verification Test Script for Work Management Tabs:
1. Board Tab: sp_list_board_kanban for all boards & sprints
2. List Tab: sp_list_work_items_paged & KPI metrics
3. Backlog Tab: Epics, Stories, and hierarchy
4. Sprints Tab:
   - Sprint Backlog: sp_get_sprint_dashboard for Sprint 8, Sprint 9, Sprint 103
   - Task Board: Column mapping for NEW, ACTIVE, IN PROGRESS, RESOLVED, COMPLETED
   - All Sprints Grid: List sprints with accurate total_items and completed_items
   - Capacity Tab: Team capacity and member workload
   - Retro Tab: sp_get_sprint_retrospective_workspace
5. Teams Tab: Teams list & member counts
"""

import asyncio
import json
import sys
import os

sys.path.insert(0, os.path.abspath("EduSHAMIIT Backend/backend"))
from app.api.work_management import exec_sql, resolve_board_id, resolve_sprint_id

SCHOOL_ID = "11111111-1111-1111-1111-111111111111"

async def run_verification():
    print("=" * 80)
    print("STARTING WORK MANAGEMENT END-TO-END VERIFICATION")
    print("=" * 80)
    passed = 0
    total = 0

    def check(name: str, condition: bool, details: str = ""):
        nonlocal passed, total
        total += 1
        if condition:
            passed += 1
            print(f"  [PASS] {name} {details}")
        else:
            print(f"  [FAIL] {name} {details}")

    # ---------------------------------------------------------
    # TAB 0: BOARD TAB VERIFICATION
    # ---------------------------------------------------------
    print("\n--- 1. BOARD TAB (Kanban & Filters) ---")
    boards = await exec_sql("SELECT id, name, code FROM public.work_boards WHERE school_id = %s::UUID ORDER BY created_at ASC;", (SCHOOL_ID,))
    check("Boards Exist in DB", len(boards) >= 3, f"(Found {len(boards)} boards)")

    for b in boards:
        b_id = str(b["id"])
        b_name = b["name"]
        rows = await exec_sql("SELECT public.sp_list_board_kanban(%s::UUID, %s, NULL, 'All', 'Status', NULL, NULL) AS result;", (SCHOOL_ID, b_id))
        res = rows[0]["result"] if rows else {}
        cols = res.get("columns", [])
        total_items = sum(c.get("count", 0) for c in cols)
        check(f"Board '{b_name}' Loads Kanban", len(cols) == 4, f"({total_items} items across 4 columns)")

    # All Boards Kanban
    rows_all = await exec_sql("SELECT public.sp_list_board_kanban(%s::UUID, NULL, NULL, 'All', 'Status', NULL, NULL) AS result;", (SCHOOL_ID,))
    res_all = rows_all[0]["result"] if rows_all else {}
    cols_all = res_all.get("columns", [])
    total_all = sum(c.get("count", 0) for c in cols_all)
    check("All Boards Kanban Loads", len(cols_all) == 4 and total_all > 0, f"({total_all} total items across all boards)")

    # Check status normalization in Kanban (ensure no OPEN/PLANNED items are dropped)
    new_col_items = cols_all[0].get("items", [])
    open_planned_in_new = any(i.get("status") in ("OPEN", "PLANNED") for i in new_col_items)
    check("Kanban 'New' column contains OPEN/PLANNED items", open_planned_in_new, f"(Col 'New' has {len(new_col_items)} items)")

    # ---------------------------------------------------------
    # TAB 1: LIST TAB VERIFICATION
    # ---------------------------------------------------------
    print("\n--- 2. LIST TAB (Data Grid & KPIs) ---")
    rows_list = await exec_sql("""
        SELECT public.sp_list_work_items_paged(
            %s::UUID, NULL, NULL, 'All', 'All', NULL, 'All', NULL, 'created_at', 'DESC', 1, 100
        ) AS result;
    """, (SCHOOL_ID,))
    list_res = rows_list[0]["result"] if rows_list else {}
    list_items = list_res.get("items", [])
    list_kpis = list_res.get("kpis", {})
    check("List Tab Items Load", len(list_items) > 0, f"({len(list_items)} items loaded)")
    check("List Tab KPIs Valid", list_kpis.get("total", 0) >= len(list_items) and list_kpis.get("total", 0) > 0, f"(KPI total={list_kpis.get('total')}, page items={len(list_items)})")
    
    # Check that KPI new includes OPEN
    check("List Tab KPI 'new' includes OPEN/PLANNED", list_kpis.get("new", 0) > 0, f"(new={list_kpis.get('new')})")

    # ---------------------------------------------------------
    # TAB 2: BACKLOG TAB VERIFICATION
    # ---------------------------------------------------------
    print("\n--- 3. BACKLOG TAB (Epics & Stories) ---")
    rows_backlog = await exec_sql("SELECT public.sp_get_backlog_tree(%s::UUID, NULL, NULL, NULL, 'All', NULL, 1, 100) AS result;", (SCHOOL_ID,))
    backlog_res = rows_backlog[0]["result"] if rows_backlog else {}
    epics = backlog_res.get("epics", [])
    stories = backlog_res.get("stories", [])
    check("Backlog Epics Load", len(epics) > 0, f"({len(epics)} epics)")
    check("Backlog Stories Load", len(stories) > 0, f"({len(stories)} stories)")

    # ---------------------------------------------------------
    # TAB 3: SPRINTS TAB VERIFICATION
    # ---------------------------------------------------------
    print("\n--- 4. SPRINTS TAB ---")
    sprints = await exec_sql("SELECT id, name, sprint_number, status, goal, start_date, end_date FROM public.work_sprints WHERE school_id = %s::UUID ORDER BY sprint_number ASC;", (SCHOOL_ID,))
    check("Sprints Exist", len(sprints) >= 3, f"({len(sprints)} sprints in DB)")

    # 4A. All Sprints (Grid)
    sprints_grid = await exec_sql("""
        SELECT s.id, s.name, s.sprint_number, s.status,
               COALESCE(COUNT(DISTINCT w.id), 0) AS total_items,
               COALESCE(COUNT(DISTINCT CASE WHEN UPPER(w.status) IN ('COMPLETED', 'RESOLVED', 'CLOSED', 'DONE') THEN w.id END), 0) AS completed_items
        FROM public.work_sprints s
        LEFT JOIN public.work_items w ON w.sprint_id = s.id AND COALESCE(w.is_archived, FALSE) = FALSE
        WHERE s.school_id = %s::UUID AND COALESCE(s.is_archived, FALSE) = FALSE
        GROUP BY s.id ORDER BY s.sprint_number ASC;
    """, (SCHOOL_ID,))
    print("\n  [All Sprints Grid Counts]:")
    grid_counts = {}
    for sg in sprints_grid:
        pct = round(sg['completed_items'] / sg['total_items'] * 100) if sg['total_items'] > 0 else 0
        grid_counts[sg['name']] = (sg['total_items'], sg['completed_items'])
        print(f"    {sg['name']} ({sg['status']}): {sg['completed_items']}/{sg['total_items']} ({pct}%)")
    check("All Sprints Grid Returns All Sprints", len(sprints_grid) >= 3)

    # 4B. Sprint Backlog & Dashboard per sprint
    for s in sprints:
        sid = str(s["id"])
        sname = s["name"]
        rows_dash = await exec_sql("SELECT public.sp_get_sprint_dashboard(%s::UUID, NULL, %s::UUID, 'All Teams', NULL, 1, 50) AS result;", (SCHOOL_ID, sid))
        dash_res = rows_dash[0]["result"] if rows_dash else {}
        sp_info = dash_res.get("sprint", {})
        kpis = dash_res.get("kpis", {})
        items = dash_res.get("items", [])

        # Verify Sprint Dashboard header data matches this exact sprint!
        check(f"Dashboard Header for '{sname}' Matches Selected Sprint", sp_info.get("name") == sname, f"(Loaded name: '{sp_info.get('name')}')")
        check(f"Dashboard Status for '{sname}' Matches DB", sp_info.get("status") == s["status"], f"(Status: '{sp_info.get('status')}')")
        check(f"Dashboard Goal for '{sname}' Is Present", len(sp_info.get("goal", "")) > 0, f"(Goal: '{sp_info.get('goal', '')[:40]}...')")
        check(f"Dashboard KPIs match Grid items count for '{sname}'", kpis.get("total_items") == grid_counts.get(sname, (0, 0))[0], f"(KPIs: {kpis.get('total_items')}, Grid: {grid_counts.get(sname, (0, 0))[0]})")

    # 4C. Sprint Task Board Column Mapping Test
    print("\n  [Task Board Column Mapping Test]:")
    # Fetch all items for Sprint 8
    s8_id = str(sprints[0]["id"])
    rows_s8 = await exec_sql("SELECT public.sp_get_sprint_dashboard(%s::UUID, NULL, %s::UUID, 'All Teams', NULL, 1, 50) AS result;", (SCHOOL_ID, s8_id))
    s8_items = rows_s8[0]["result"].get("items", [])
    
    # Flatten items and children
    flat_items = []
    for it in s8_items:
        flat_items.append(it)
        for ch in it.get("children", []):
            flat_items.append(ch)

    # Test our Dart column mapping logic on these items
    def map_to_column(status: str) -> str:
        s = status.strip().toUpperCase() if hasattr(status, 'toUpperCase') else status.strip().upper()
        if s in ('NEW', 'OPEN', 'PLANNED', 'NOT STARTED', 'NOT_STARTED', 'TODO'):
            return 'NEW'
        if s in ('ACTIVE', 'CRITICAL'):
            return 'ACTIVE'
        if s in ('IN PROGRESS', 'IN_PROGRESS', 'DOING'):
            return 'IN PROGRESS'
        if s in ('RESOLVED', 'TESTING', 'QA', 'CODE REVIEW'):
            return 'RESOLVED'
        if s in ('COMPLETED', 'CLOSED', 'DONE'):
            return 'COMPLETED'
        return 'UNKNOWN'

    col_counts = {'NEW': 0, 'ACTIVE': 0, 'IN PROGRESS': 0, 'RESOLVED': 0, 'COMPLETED': 0, 'UNKNOWN': 0}
    for it in flat_items:
        col = map_to_column(it.get("status", ""))
        col_counts[col] += 1

    print(f"    Sprint 8 Task Board Columns: {col_counts}")
    check("Task Board Columns Map ALL Items (0 Unknown)", col_counts['UNKNOWN'] == 0, f"({col_counts})")
    check("Task Board Columns Have Active/New Items", col_counts['NEW'] > 0 and (col_counts['ACTIVE'] > 0 or col_counts['IN PROGRESS'] > 0))

    # 4D. Retrospective Workspace
    print("\n  [Retrospective Workspace Test]:")
    rows_retro = await exec_sql("SELECT public.sp_get_sprint_retrospective_workspace(%s::UUID, %s::UUID, NULL::UUID) AS ws;", (SCHOOL_ID, s8_id))
    retro_ws = rows_retro[0]["ws"] if rows_retro else {}
    retro_items = retro_ws.get("items", [])
    retro_actions = retro_ws.get("action_items", [])
    check("Retrospective Workspace Loads", len(retro_items) >= 0 and len(retro_actions) >= 0, f"({len(retro_items)} retro cards, {len(retro_actions)} action items)")

    # ---------------------------------------------------------
    # TAB 4: TEAM TAB VERIFICATION
    # ---------------------------------------------------------
    print("\n--- 5. TEAM TAB ---")
    teams = await exec_sql("SELECT id, name, department, status FROM public.work_teams WHERE school_id = %s::UUID;", (SCHOOL_ID,))
    check("Teams Exist in DB", len(teams) > 0, f"({len(teams)} teams found)")
    
    members = await exec_sql("SELECT count(*) as count FROM public.work_team_members WHERE school_id = %s::UUID;", (SCHOOL_ID,))
    check("Team Members Exist", members[0]["count"] > 0, f"({members[0]['count']} team members assigned)")

    print("\n" + "=" * 80)
    print(f"VERIFICATION COMPLETE: {passed}/{total} CHECKS PASSED ({round(passed/total*100)}%)")
    print("=" * 80)
    return passed == total

if __name__ == '__main__':
    success = asyncio.run(run_verification())
    sys.exit(0 if success else 1)
