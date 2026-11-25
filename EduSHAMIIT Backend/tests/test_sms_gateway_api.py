"""
Integration tests for SHAMIIT SMS GATEWAY FastAPI endpoints & PostgreSQL persistence.
Runs against the live API gateway (http://127.0.0.1:8082/api/v1) and cleans up its own test records.
"""

import json
import unittest
import urllib.error
import urllib.request
import uuid

BASE_URL = "http://127.0.0.1:8082/api/v1"
SCHOOL_ID = "11111111-1111-1111-1111-111111111111"


def api_call(method: str, path: str, body=None, device_id: str = "SMS-TEST-001"):
    url = f"{BASE_URL}{path}"
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-School-ID": SCHOOL_ID,
            "X-Device-ID": device_id,
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as err:
        raw = err.read().decode("utf-8")
        try:
            return err.code, json.loads(raw)
        except Exception:
            return err.code, {"raw": raw}


class SmsGatewayApiTest(unittest.TestCase):
    def setUp(self):
        self.device_id = f"SMS-TEST-{uuid.uuid4().hex[:8].upper()}"

    def test_01_health_and_device_lifecycle(self):
        code, health = api_call("GET", "/sms-gateway/health", device_id=self.device_id)
        self.assertEqual(code, 200)
        self.assertEqual(health["status"], "healthy")

        code, reg = api_call(
            "POST",
            "/device/register",
            {
                "device_id": self.device_id,
                "device_name": "Test Pixel Gateway",
                "model": "Pixel 8",
                "android_version": "Android 14",
                "app_version": "1.0.0",
                "school_id": SCHOOL_ID,
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        self.assertTrue(reg["success"])
        self.assertTrue(reg["device_token"].startswith("sms_"))

        code, hb = api_call(
            "POST",
            "/device/heartbeat",
            {
                "device_id": self.device_id,
                "is_online": True,
                "battery_level": 88,
                "network_type": "4G LTE",
                "queue_size": 0,
                "uptime_seconds": 120,
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        self.assertTrue(hb["success"])

    def test_02_sim_sync_and_conflict_resolution(self):
        # Register initial dual-SIM inventory (subIds 14 and 29)
        code, res = api_call(
            "POST",
            "/device/sim-configuration",
            {
                "device_id": self.device_id,
                "preferred_sim_mode": "SIM_1",
                "preferred_subscription_id": 14,
                "preferred_sim_slot": 0,
                "auto_fallback_enabled": False,
                "sims": [
                    {
                        "subscription_id": 14,
                        "sim_slot_index": 0,
                        "carrier_name": "Jio",
                        "sim_state": "READY",
                        "is_active": True,
                        "usage_mode": "SEND_RECEIVE",
                    },
                    {
                        "subscription_id": 29,
                        "sim_slot_index": 1,
                        "carrier_name": "Airtel",
                        "sim_state": "READY",
                        "is_active": True,
                        "usage_mode": "SEND_RECEIVE",
                    },
                ],
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        self.assertEqual(len(res["sims"]), 2)
        self.assertEqual(res["configuration"]["preferred_subscription_id"], 14)

        # Simulate SIM 14 removal while fallback is disabled -> conflict cleared, no silent switch!
        code, res2 = api_call(
            "POST",
            "/device/sim-configuration",
            {
                "device_id": self.device_id,
                "sims": [
                    {
                        "subscription_id": 29,
                        "sim_slot_index": 1,
                        "carrier_name": "Airtel",
                        "sim_state": "READY",
                        "is_active": True,
                        "usage_mode": "SEND_RECEIVE",
                    }
                ],
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        self.assertTrue(len(res2["conflicts"]) > 0)
        self.assertIsNone(res2["configuration"]["preferred_subscription_id"])

    def test_03_send_lease_events_inbound_templates_and_rules(self):
        # Create template & test unresolved variable rejection
        code, tpl_res = api_call(
            "POST",
            "/templates",
            {
                "template_name": "Fee Reminder",
                "application_name": "EduSHAMIIT",
                "category": "Fees",
                "message_body": "Dear {parent_name}, fee INR {amount} due on {due_date}.",
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        tpl_id = tpl_res["template"]["id"]

        # Unresolved variable must return 400
        code, bad_send = api_call(
            "POST",
            "/sms/send",
            {
                "recipients": ["9876543210"],
                "message_body": "fallback",
                "template_id": tpl_id,
                "template_variables": {"parent_name": "Rajesh"},
                "device_id": self.device_id,
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 400)

        # Valid send
        code, send_res = api_call(
            "POST",
            "/sms/send",
            {
                "recipients": ["9876543210"],
                "message_body": "fallback",
                "template_id": tpl_id,
                "template_variables": {
                    "parent_name": "Rajesh",
                    "amount": "4500",
                    "due_date": "30 Nov 2026",
                },
                "device_id": self.device_id,
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        msg_uuid = send_res["messages"][0]["message_uuid"]
        self.assertEqual(send_res["messages"][0]["recipient_number"], "+919876543210")

        # Lease job atomically (second poll must not return same leased job!)
        code, jobs1 = api_call("GET", f"/device/jobs?device_id={self.device_id}&limit=10", device_id=self.device_id)
        self.assertEqual(code, 200)
        leased_ids = [j["message_uuid"] for j in jobs1["jobs"]]
        self.assertIn(msg_uuid, leased_ids)

        code, jobs2 = api_call("GET", f"/device/jobs?device_id={self.device_id}&limit=10", device_id=self.device_id)
        self.assertEqual(code, 200)
        self.assertNotIn(msg_uuid, [j["message_uuid"] for j in jobs2["jobs"]])

        # Report SMS_SENT (must NOT mark DELIVERED) then SMS_DELIVERED
        api_call(
            "POST",
            "/device/events",
            {
                "device_id": self.device_id,
                "events": [{"message_uuid": msg_uuid, "event_type": "SMS_SENT"}],
            },
            device_id=self.device_id,
        )
        _, detail1 = api_call("GET", f"/sms/messages/{msg_uuid}", device_id=self.device_id)
        self.assertEqual(detail1["message"]["status"], "SENT")

        api_call(
            "POST",
            "/device/events",
            {
                "device_id": self.device_id,
                "events": [{"message_uuid": msg_uuid, "event_type": "SMS_DELIVERED"}],
            },
            device_id=self.device_id,
        )
        _, detail2 = api_call("GET", f"/sms/messages/{msg_uuid}", device_id=self.device_id)
        self.assertEqual(detail2["message"]["status"], "DELIVERED")

        # Inbound SMS
        code, inb = api_call(
            "POST",
            "/device/inbound",
            {
                "device_id": self.device_id,
                "sender_number": "+918765432109",
                "message_body": "Paid fee via UPI",
                "receiving_sim_slot": 0,
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        self.assertTrue(inb["success"])

        # Automation rule CRUD + duplicate + test + delete
        code, rule_res = api_call(
            "POST",
            "/automation/rules",
            {
                "rule_name": "Absent Alert",
                "application_name": "EduSHAMIIT",
                "trigger_event": "Student absent",
                "recipient_mapping": "parent_phone",
                "message_template": "Dear {parent_name}, {student_name} is absent.",
            },
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        rule_id = rule_res["rule"]["id"]

        code, dup_res = api_call("POST", f"/automation/rules/{rule_id}/duplicate", device_id=self.device_id)
        self.assertEqual(code, 200)
        dup_id = dup_res["rule"]["id"]

        code, test_res = api_call(
            "POST",
            f"/automation/rules/{rule_id}/test",
            {"variables": {"parent_name": "Amit", "student_name": "Rohan"}},
            device_id=self.device_id,
        )
        self.assertEqual(code, 200)
        self.assertEqual(test_res["rendered_message"], "Dear Amit, Rohan is absent.")

        # Statistics & history check
        code, stats = api_call("GET", f"/sms/statistics?device_id={self.device_id}", device_id=self.device_id)
        self.assertEqual(code, 200)
        self.assertGreaterEqual(stats["sent_today"], 1)
        self.assertGreaterEqual(stats["received_today"], 1)

        # Clean up created template & rules
        api_call("DELETE", f"/automation/rules/{rule_id}", device_id=self.device_id)
        api_call("DELETE", f"/automation/rules/{dup_id}", device_id=self.device_id)
        api_call("DELETE", f"/templates/{tpl_id}", device_id=self.device_id)


if __name__ == "__main__":
    unittest.main(verbosity=2)
