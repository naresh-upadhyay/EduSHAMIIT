import urllib.request
import json
import unittest

BASE = "http://localhost:8082/api/v1/devices"

class TestDeviceGroupsE2E(unittest.TestCase):
    def test_01_groups_kpis(self):
        req = urllib.request.Request(f"{BASE}/groups/kpis")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(data.get("total_groups"), 128)
            self.assertEqual(data.get("active_groups"), 118)
            self.assertEqual(data.get("inactive_groups"), 10)
            self.assertEqual(data.get("total_devices"), 8742)
            self.assertEqual(data.get("grouped_devices"), 8296)
            self.assertEqual(data.get("ungrouped_devices"), 446)
            print("[PASS] Groups KPIs match screenshot exactly.")

    def test_02_list_groups(self):
        req = urllib.request.Request(f"{BASE}/groups?page=1&page_size=10")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertEqual(data.get("total"), 128)
            self.assertEqual(len(data.get("groups")), 10)
            first = data["groups"][0]
            self.assertEqual(first["name"], "Classroom Lighting - Block A")
            self.assertEqual(first["group_type"], "Lighting")
            self.assertEqual(first["location_scope"], "Block A > Classrooms")
            self.assertEqual(first["profile_name"], "Default Lighting")
            self.assertEqual(first["status"], "active")
            print("[PASS] List Groups returns 10 groups with Classroom Lighting - Block A at top.")

    def test_03_group_detail(self):
        first_id = "a1111111-0001-4000-8000-000000000001"
        req = urllib.request.Request(f"{BASE}/groups/{first_id}")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            group = data["group"]
            self.assertEqual(group["name"], "Classroom Lighting - Block A")
            self.assertEqual(group["member_count"], 96)
            self.assertEqual(group["schedules_count"], 3)
            self.assertEqual(group["automations_count"], 2)
            self.assertEqual(group["scenes_count"], 4)
            adv = group.get("advanced_controls")
            self.assertTrue(len(adv) >= 2)
            self.assertEqual(adv[0]["category"], "Lighting")
            self.assertEqual(adv[0]["count"], 92)
            self.assertEqual(adv[1]["category"], "Smart Switch")
            self.assertEqual(adv[1]["count"], 4)
            print("[PASS] Group Detail returns member breakdown matching right inspector panel.")

    def test_04_execute_group_command(self):
        first_id = "a1111111-0001-4000-8000-000000000001"
        body = json.dumps({"command_type": "brightness", "parameters": {"brightness": 75}}).encode("utf-8")
        req = urllib.request.Request(f"{BASE}/groups/{first_id}/commands", data=body, headers={"Content-Type": "application/json"}, method="POST")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertTrue(data.get("success"))
            self.assertIn("OP-", data.get("operation_id"))
            print(f"[PASS] Command executed: {data.get('message')}")

    def test_05_export_groups(self):
        req = urllib.request.Request(f"{BASE}/groups/export")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertGreaterEqual(data.get("count"), 128)
            print("[PASS] Export groups returned 128 records.")

if __name__ == "__main__":
    unittest.main()
