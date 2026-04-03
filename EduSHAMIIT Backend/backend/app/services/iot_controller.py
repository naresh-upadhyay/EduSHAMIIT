import paho.mqtt.client as mqtt
import httpx
import json
import os
from app.services.supabase_client import get_supabase


class IoTController:
    def __init__(self):
        self._mqtt = None
        self._connected = False

    def _ensure_mqtt(self):
        if self._mqtt is None:
            try:
                broker_host = os.getenv("MQTT_BROKER_HOST", "localhost")
                broker_port = int(os.getenv("MQTT_BROKER_PORT", "1883"))
                self._mqtt = mqtt.Client(client_id="edushamiit-python")
                self._mqtt.on_message = self._on_status_update
                self._mqtt.connect(broker_host, broker_port)
                self._mqtt.subscribe("school/+/status")
                self._mqtt.loop_start()
                self._connected = True
            except Exception as e:
                print(f"MQTT connection failed: {e}")
                self._connected = False

    def control_device(self, room: str, device: str, action: str) -> dict:
        """Control a device via MQTT. Falls back to HTTP if MQTT fails."""
        self._ensure_mqtt()
        payload = json.dumps({"device": device, "action": action})
        topic = f"school/{room}/control"

        if self._connected:
            try:
                result = self._mqtt.publish(topic, payload, qos=1)
                if result.rc == 0:
                    self._log(room, device, action)
                    return {"ok": True, "method": "mqtt"}
            except Exception:
                pass

        return self._http_fallback(room, device, action)

    def _http_fallback(self, room, device, action) -> dict:
        """Fallback to direct HTTP if MQTT fails."""
        ip = self._get_device_ip(room)
        if not ip:
            return {"ok": False, "error": "device unreachable"}
        try:
            r = httpx.post(
                f"http://{ip}/control",
                json={"device": device, "action": action},
                timeout=3
            )
            return {"ok": r.status_code == 200, "method": "http"}
        except Exception:
            return {"ok": False, "error": "http timeout"}

    def get_room_status(self, room: str) -> dict:
        """Get current device status from a room."""
        ip = self._get_device_ip(room)
        if not ip:
            return {}
        try:
            r = httpx.get(f"http://{ip}/status", timeout=3)
            return r.json()
        except Exception:
            return {}

    def _get_device_ip(self, room: str) -> str | None:
        """Look up device IP from database."""
        try:
            result = get_supabase().table("iot_devices") \
                .select("ip_address") \
                .eq("room_id", room) \
                .single().execute()
            return result.data.get("ip_address") if result.data else None
        except Exception:
            return None

    def _on_status_update(self, client, userdata, message):
        """Handle status updates from devices."""
        try:
            data = json.loads(message.payload)
            get_supabase().table("iot_device_states").upsert(data).execute()
        except Exception as e:
            print(f"Status update error: {e}")

    def _log(self, room, device, action):
        """Log control action to database."""
        try:
            get_supabase().table("iot_control_log").insert({
                "room_id": room,
                "device": device,
                "action": action,
                "triggered_by": "ai_assistant",
            }).execute()
        except Exception:
            pass


# Singleton
iot = IoTController()