"""
Enterprise MQTT Service for EduSHAMIIT Device Management & IoT
Handles connection, command dispatching, telemetry subscriptions, and state sync.
"""

import os
import json
import uuid
import time
import logging
import asyncio
from typing import Dict, Any, Optional, List
import paho.mqtt.client as mqtt

logger = logging.getLogger("mqtt_service")


class EnterpriseMqttService:
    _instance = None

    def __init__(self):
        self.broker_host = os.getenv("MQTT_BROKER_HOST", "mosquitto")
        self.broker_port = int(os.getenv("MQTT_BROKER_PORT", "1883"))
        self.client_id = f"edushamiit-core-backend-{uuid.uuid4().hex[:8]}"
        self.client: Optional[mqtt.Client] = None
        self.is_connected = False
        self._loop_running = False

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = EnterpriseMqttService()
        return cls._instance

    def initialize(self):
        """Initialize and connect to MQTT broker in background."""
        if self.is_connected:
            return

        try:
            self.client = mqtt.Client(client_id=self.client_id, clean_session=True)
            self.client.on_connect = self._on_connect
            self.client.on_disconnect = self._on_disconnect
            self.client.on_message = self._on_message

            logger.info(f"[MQTT] Connecting to broker at {self.broker_host}:{self.broker_port}...")
            self.client.connect_async(self.broker_host, self.broker_port, keepalive=60)
            self.client.loop_start()
            self._loop_running = True
        except Exception as e:
            logger.warning(f"[MQTT] Failed to start MQTT client: {e}")
            self.is_connected = False

    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            self.is_connected = True
            logger.info("[MQTT] Successfully connected to MQTT broker.")
            # Subscribe to telemetry, state reports, energy meters, command acknowledgments, heartbeats, diagnostics, and gateways
            client.subscribe([
                ("edu/+/+/state", 1),
                ("edu/+/+/telemetry", 1),
                ("edu/+/+/ack", 1),
                ("edu/+/+/heartbeat", 1),
                ("edu/+/+/diagnostics/response", 1),
                ("edu/+/+/health", 1),
                ("energy/+/+/telemetry", 1),
                ("energy/+/+/status", 1),
                ("gateways/+/status", 1),
                ("campus/+/gateway/+/status", 1),
                ("campus/+/gateway/+/heartbeat", 1),
                ("campus/+/gateway/+/events", 1),
                ("campus/+/integrations/+/health", 1)
            ])
        else:
            self.is_connected = False
            logger.warning(f"[MQTT] Connection failed with result code {rc}")

    def _on_disconnect(self, client, userdata, rc):
        self.is_connected = False
        logger.warning(f"[MQTT] Disconnected from broker (rc={rc})")

    def _persist_to_db(self, sql: str, params: tuple):
        """Execute database write in background thread without blocking MQTT loop."""
        def _write():
            try:
                import psycopg2
                from app.config import settings
                conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=3)
                try:
                    with conn.cursor() as cur:
                        cur.execute(sql, params)
                        conn.commit()
                finally:
                    conn.close()
            except Exception as e:
                logger.warning(f"[MQTT DB Persistence Warning]: {e}")

        import threading
        threading.Thread(target=_write, daemon=True).start()

    def _on_message(self, client, userdata, msg):
        try:
            topic = msg.topic
            raw_payload = msg.payload.decode("utf-8") if isinstance(msg.payload, (bytes, bytearray)) else str(msg.payload)
            try:
                payload = json.loads(raw_payload)
            except Exception:
                payload = {"raw": raw_payload}

            logger.debug(f"[MQTT Received] {topic}: {payload}")
            parts = topic.split("/")

            # 1. Device Telemetry & State: edu/{school_id}/{device_code}/state OR telemetry
            if len(parts) >= 4 and parts[0] == "edu":
                school_id = parts[1]
                device_code = parts[2]
                subtopic = parts[3]

                if subtopic in ("state", "telemetry"):
                    sql = """
                        UPDATE public.devices 
                        SET current_state = %s::jsonb, 
                            is_online = true, 
                            last_seen = NOW(), 
                            updated_at = NOW() 
                        WHERE (device_code = %s OR id::text = %s);
                    """
                    self._persist_to_db(sql, (json.dumps(payload), device_code, device_code))

                    tel_sql = """
                        INSERT INTO public.device_telemetry (school_id, device_id, telemetry_data, recorded_at)
                        SELECT d.school_id, d.id, %s::jsonb, NOW()
                        FROM public.devices d
                        WHERE (d.device_code = %s OR d.id::text = %s)
                        LIMIT 1;
                    """
                    self._persist_to_db(tel_sql, (json.dumps(payload), device_code, device_code))

                elif subtopic == "heartbeat":
                    hb_sql = """
                        UPDATE public.devices 
                        SET is_online = true, 
                            last_seen = NOW(), 
                            updated_at = NOW() 
                        WHERE (device_code = %s OR id::text = %s);
                    """
                    self._persist_to_db(hb_sql, (device_code, device_code))

                elif subtopic in ("diagnostics/response", "diagnostics"):
                    diag_sql = """
                        UPDATE public.devices
                        SET last_diagnostic_at = NOW(),
                            health_status = %s,
                            uptime_pct = %s,
                            response_latency_ms = %s
                        WHERE (device_code = %s OR id::text = %s);
                    """
                    status = payload.get("status", "healthy")
                    uptime = payload.get("uptime_pct", 99.5)
                    latency = payload.get("latency_ms", 35)
                    self._persist_to_db(diag_sql, (status, uptime, latency, device_code, device_code))

            # 2. Energy Meter Telemetry: energy/{school_id}/{meter_id}/telemetry
            elif parts[0] == "energy" and len(parts) >= 4:
                school_id = parts[1]
                meter_id = parts[2]
                power_w = float(payload.get("power_w", payload.get("active_power_w", 0)))
                kwh = float(payload.get("energy_kwh", payload.get("total_kwh", 0)))

                energy_sql = """
                    UPDATE public.campus_energy_meters
                    SET current_power_kw = %s,
                        total_kwh = total_kwh + %s,
                        status = 'online',
                        last_reading_at = NOW()
                    WHERE meter_code = %s;
                """
                self._persist_to_db(energy_sql, (power_w / 1000.0, kwh, meter_id))

            # 3. Gateway Status & Heartbeat: campus/{school_id}/gateway/{gateway_code}/status OR heartbeat
            elif parts[0] == "campus" and len(parts) >= 5 and parts[2] == "gateway":
                gw_code = parts[3]
                gw_sql = """
                    UPDATE public.campus_iot_gateways
                    SET is_online = true,
                        status = 'online',
                        last_heartbeat_at = NOW()
                    WHERE gateway_code = %s;
                """
                self._persist_to_db(gw_sql, (gw_code,))

        except Exception as e:
            logger.error(f"[MQTT Message Parse Error]: {e}")

    def publish_device_command(
        self,
        school_id: str,
        device_code: str,
        command_type: str,
        payload: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Publish a command envelope to a specific device."""
        msg_id = str(uuid.uuid4())
        topic = f"edu/{school_id}/{device_code}/command"
        message_body = {
            "msg_id": msg_id,
            "timestamp": time.time(),
            "command": command_type,
            "payload": payload,
            "sender": "EduSHAMIIT_Control_Console"
        }

        if not self.is_connected and not self._loop_running:
            self.initialize()

        published = False
        if self.client and self.is_connected:
            try:
                res = self.client.publish(topic, json.dumps(message_body), qos=1)
                published = (res.rc == mqtt.MQTT_ERR_SUCCESS)
            except Exception as e:
                logger.error(f"[MQTT Publish Error] Failed to publish to {topic}: {e}")

        return {
            "published": published,
            "topic": topic,
            "msg_id": msg_id,
            "payload": message_body
        }

    def publish_diagnostic_request(
        self,
        school_id: str,
        device_code: str,
        session_code: str,
        tests: List[str]
    ) -> Dict[str, Any]:
        """Publish diagnostic execution request to edge device topic."""
        msg_id = str(uuid.uuid4())
        topic = f"edu/{school_id}/{device_code}/diagnostics/request"
        message_body = {
            "schema_version": 1,
            "msg_id": msg_id,
            "session_code": session_code,
            "device_code": device_code,
            "requested_tests": tests,
            "timestamp": time.time()
        }
        published = False
        if self.client and self.is_connected:
            try:
                res = self.client.publish(topic, json.dumps(message_body), qos=1)
                published = (res.rc == mqtt.MQTT_ERR_SUCCESS)
            except Exception as e:
                logger.error(f"[MQTT Diagnostic Request Error] Failed to publish to {topic}: {e}")

        return {
            "published": published,
            "topic": topic,
            "session_code": session_code,
            "msg_id": msg_id
        }

    def publish_recovery_command(
        self,
        school_id: str,
        device_code: str,
        action_type: str,
        payload: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Publish device recovery command (restart, reconnect, reset, etc.) via MQTT."""
        return self.publish_device_command(
            school_id=school_id,
            device_code=device_code,
            command_type=f"recovery_{action_type}",
            payload=payload or {}
        )

    def publish_gateway_command(
        self,
        school_id: str,
        gateway_code: str,
        command: str,
        payload: Optional[Dict[str, Any]] = None
    ) -> Dict[str, Any]:
        """Publish a command to an edge gateway (restart, ota_update, diagnostics, scan)."""
        msg_id = str(uuid.uuid4())
        topic = f"campus/{school_id}/gateway/{gateway_code}/command"
        message_body = {
            "msg_id": msg_id,
            "timestamp": time.time(),
            "command": command,
            "payload": payload or {},
            "sender": "EduSHAMIIT_Gateway_Manager"
        }

        if not self.is_connected and not self._loop_running:
            self.initialize()

        published = False
        if self.client and self.is_connected:
            try:
                res = self.client.publish(topic, json.dumps(message_body), qos=1)
                published = (res.rc == mqtt.MQTT_ERR_SUCCESS)
            except Exception as e:
                logger.error(f"[MQTT Publish Error] Failed to publish gateway command to {topic}: {e}")

        return {
            "published": published,
            "topic": topic,
            "msg_id": msg_id,
            "payload": message_body
        }

    def shutdown(self):
        if self.client and self._loop_running:
            self.client.loop_stop()
            self.client.disconnect()
            self._loop_running = False
            self.is_connected = False


mqtt_service = EnterpriseMqttService.get_instance()
