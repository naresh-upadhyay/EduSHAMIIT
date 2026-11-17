import asyncio
from httpx import AsyncClient, ASGITransport
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, os.path.abspath('EduSHAMIIT Backend/backend'))
from app.main import app

async def test_api():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        # 1. KPIs
        r_kpis = await client.get("/api/v1/devices/groups/kpis?school_id=11111111-1111-1111-1111-111111111111")
        print("KPIs status:", r_kpis.status_code)
        data_kpis = r_kpis.json()
        print("KPIs data:", data_kpis)
        assert data_kpis["total_groups"] == 128
        assert data_kpis["active_groups"] == 118
        assert data_kpis["inactive_groups"] == 10

        # 2. Filter Options
        r_opts = await client.get("/api/v1/devices/groups/filter-options?school_id=11111111-1111-1111-1111-111111111111")
        print("Filter options status:", r_opts.status_code)
        data_opts = r_opts.json()
        print(f"Filter options: locations={len(data_opts.get('locations', []))}, types={len(data_opts.get('group_types', []))}, profiles={len(data_opts.get('profiles', []))}")
        assert len(data_opts["locations"]) > 0
        assert len(data_opts["group_types"]) > 0

        # 3. List with subtab 'All Groups (128)'
        r_list = await client.get("/api/v1/devices/groups?school_id=11111111-1111-1111-1111-111111111111&status=All%20Groups%20(128)&page=1&page_size=10")
        print("List status:", r_list.status_code)
        data_list = r_list.json()
        print(f"List total: {data_list.get('total')}, page groups: {len(data_list.get('groups', []))}")
        assert data_list["total"] == 128
        assert len(data_list["groups"]) == 10

        # 4. List with sort_by='name'&sort_order=ASC
        r_sorted = await client.get("/api/v1/devices/groups?school_id=11111111-1111-1111-1111-111111111111&sort_by=name&sort_order=ASC&page=1&page_size=5")
        data_sorted = r_sorted.json()
        names = [g["name"] for g in data_sorted["groups"]]
        print("Sorted names:", names)
        assert names == sorted(names, key=lambda x: x.lower())

        # 5. List with active subtab
        r_act = await client.get("/api/v1/devices/groups?school_id=11111111-1111-1111-1111-111111111111&status=Active%20(118)")
        assert r_act.json()["total"] == 118

        # 6. List with inactive subtab
        r_inact = await client.get("/api/v1/devices/groups?school_id=11111111-1111-1111-1111-111111111111&status=Inactive%20(10)")
        assert r_inact.json()["total"] == 10

        print("\n>>> FASTAPI DEVICE GROUPS ENDPOINTS TEST PASSED! <<<")

if __name__ == '__main__':
    asyncio.run(test_api())
