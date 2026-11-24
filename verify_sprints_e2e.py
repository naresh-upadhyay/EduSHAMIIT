import urllib.request
import json

base_url = "http://localhost:8082/api/v1/work/sprints"

def check(url, label):
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        items = data.get('items', [])
        kpis = data.get('kpis', {})
        total_in_tree = len(items) + sum(len(i.get('children', [])) for i in items)
        print(f"[{label}]")
        print(f"  Total items in tree: {total_in_tree} (Parents: {len(items)})")
        print(f"  KPI Total: {kpis.get('total_items')}, Completed: {kpis.get('completed_items')}, In Progress: {kpis.get('in_progress_items')}, Not Started: {kpis.get('not_started_items')}, Blocked: {kpis.get('blocked_items')}")
        for it in items:
            ch = it.get('children', [])
            print(f"    - {it.get('item_number')} [{it.get('work_type')}] (Board: {it.get('board_name')}, Team: {it.get('team_name')}, Children: {len(ch)})")
        print()

print("================ SPRINT 9 (PLANNED) ================")
check(f"{base_url}/332ae580-759a-424f-a647-c3ad9155f6c3", "Sprint 9 - All Boards")
check(f"{base_url}/332ae580-759a-424f-a647-c3ad9155f6c3?board_id=Academic%20Board", "Sprint 9 - Academic Board")
check(f"{base_url}/332ae580-759a-424f-a647-c3ad9155f6c3?board_id=IT%20%26%20Infra%20Board", "Sprint 9 - IT & Infra Board")

print("================ SPRINT 8 (ACTIVE) ================")
check(f"{base_url}/35ad7623-f5d2-4935-a203-98a26e2b5444", "Sprint 8 - All Boards")
check(f"{base_url}/35ad7623-f5d2-4935-a203-98a26e2b5444?board_id=Institute%20Work%20Board", "Sprint 8 - Institute Work Board")

print("================ SPRINT 103 (ACTIVE) ================")
check(f"{base_url}/69680b49-1920-4f82-a7f6-88ca9ececfee", "Sprint 103 - All Boards")
