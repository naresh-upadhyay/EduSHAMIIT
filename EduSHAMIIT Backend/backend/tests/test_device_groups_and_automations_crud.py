import pytest
import uuid
from httpx import AsyncClient
from app.main import app

@pytest.mark.asyncio
async def test_device_groups_crud(auth_headers):
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # 1. List groups
        res = await ac.get("/api/v1/devices/groups", headers=auth_headers)
        assert res.status_code == 200
        groups = res.json().get("groups", [])
        initial_count = len(groups)

        # 2. Create group
        new_code = f"GRP-TEST-{uuid.uuid4().hex[:6].upper()}"
        create_payload = {
            "name": "Science Block Fans",
            "code": new_code,
            "description": "Ceiling fans across physics and chem labs",
            "group_type": "custom",
            "icon": "mode_fan",
            "color": "#06B6D4",
            "device_ids": []
        }
        res_create = await ac.post("/api/v1/devices/groups", json=create_payload, headers=auth_headers)
        assert res_create.status_code == 200
        data = res_create.json()
        assert data["success"] is True
        created_group = data["group"]
        group_id = created_group["id"]
        assert created_group["name"] == "Science Block Fans"

        # 3. Update group
        update_payload = {
            "name": "Science Block Smart Fans (Updated)",
            "description": "Updated description for physics labs"
        }
        res_update = await ac.put(f"/api/v1/devices/groups/{group_id}", json=update_payload, headers=auth_headers)
        assert res_update.status_code == 200
        assert res_update.json()["group"]["name"] == "Science Block Smart Fans (Updated)"

        # 4. Group Action
        action_payload = {"action": "all_on"}
        res_action = await ac.post(f"/api/v1/devices/groups/{group_id}/action", json=action_payload, headers=auth_headers)
        assert res_action.status_code == 200
        assert res_action.json()["success"] is True

        # 5. Delete group
        res_del = await ac.delete(f"/api/v1/devices/groups/{group_id}", headers=auth_headers)
        assert res_del.status_code == 200
        assert res_del.json()["success"] is True


@pytest.mark.asyncio
async def test_automations_crud_and_simulation(auth_headers):
    async with AsyncClient(app=app, base_url="http://test") as ac:
        # 1. List automations
        res = await ac.get("/api/v1/devices/automations", headers=auth_headers)
        assert res.status_code == 200
        automations = res.json().get("automations", [])
        assert len(automations) >= 8

        # 2. Create rule
        rule_payload = {
            "name": "HVAC Auto Setpoint 22C",
            "description": "Optimize temperature during library hours",
            "trigger_type": "smart",
            "trigger_condition": {
                "combinator": "AND",
                "conditions": [
                    {"attribute": "Occupancy", "operator": ">", "value": "10"}
                ]
            },
            "action_payload": {
                "execution_mode": "In Sequence",
                "actions": [
                    {"target": "Library AC", "action": "Set Temperature", "parameter": "22C"}
                ]
            },
            "is_active": True
        }
        res_create = await ac.post("/api/v1/devices/automations", json=rule_payload, headers=auth_headers)
        assert res_create.status_code == 200
        created_rule = res_create.json()["automation"]
        rule_id = created_rule["id"]
        assert created_rule["name"] == "HVAC Auto Setpoint 22C"

        # 3. Test rule simulation
        test_payload = {
            "rule_id": rule_id,
            "trigger_condition": created_rule["trigger_condition"],
            "action_payload": created_rule["action_payload"]
        }
        res_test = await ac.post("/api/v1/devices/automations/test", json=test_payload, headers=auth_headers)
        assert res_test.status_code == 200
        assert res_test.json()["condition_met"] is True

        # 4. Duplicate rule
        res_dup = await ac.post(f"/api/v1/devices/automations/{rule_id}/duplicate", headers=auth_headers)
        assert res_dup.status_code == 200
        dup_rule = res_dup.json()["automation"]
        assert "Copy of HVAC Auto Setpoint 22C" in dup_rule["name"]

        # 5. Delete rules
        await ac.delete(f"/api/v1/devices/automations/{rule_id}", headers=auth_headers)
        await ac.delete(f"/api/v1/devices/automations/{dup_rule['id']}", headers=auth_headers)
