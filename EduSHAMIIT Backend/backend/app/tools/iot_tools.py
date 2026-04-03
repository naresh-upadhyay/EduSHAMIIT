"""
IoT Tools - 3 LangChain @tool functions for EduSHAMIIT IoT device control.
Uses MQTT controller for device communication with HTTP fallback.
"""
import json
from datetime import datetime
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from app.services.iot_controller import iot as iot_controller


def get_iot_tools(school_id: str) -> list:
    """Return all 3 IoT tools scoped to this school."""

    @tool
    def control_classroom_device(room: str, device: str, action: str) -> str:
        """
        Control an electrical device in a classroom over WiFi.
        room: classroom ID like 'class_10a', 'staff_room', 'library', 'principal_office'
        device: 'fan' | 'light1' | 'light2' | 'projector' | 'ac' | 'all' | 'all_lights'
        action: 'on' | 'off' | 'toggle'

        Examples:
          User: "Turn off the fan in 10A" -> room='class_10a', device='fan', action='off'
          User: "Switch on lights in staffroom" -> room='staff_room', device='all_lights', action='on'
          User: "Band karo sab lights class 9B mein" -> room='class_9b', device='all_lights', action='off'
        """
        result = iot_controller.control_device(room, device, action)
        if result.get("ok"):
            return f"Done! ✅ {device} in {room} has been turned {action}."
        return f"❌ Could not reach {room}. The device board may be offline."

    @tool
    def get_classroom_device_status(room: str) -> str:
        """
        Get current on/off status of all devices in a classroom.
        room: classroom ID like 'class_10a', 'staff_room'
        Returns formatted status of fan, lights, projector, AC in the room.
        """
        status = iot_controller.get_room_status(room)
        if not status:
            return f"Cannot fetch status for {room}. Device may be offline. ⚠️"

        buf = [f"🔌 Device Status in {room}:"]
        for device, state in status.items():
            emoji = "🟢" if state == "on" else "🔴"
            buf.append(f"  {emoji} {device}: {state}")

        return "\n".join(buf)

    @tool
    def schedule_device_action(room: str, device: str, action: str, time_str: str) -> str:
        """
        Schedule a device to turn on/off at a specific time.
        room: classroom ID like 'class_10a'
        device: 'fan' | 'light1' | 'light2' | 'projector' | 'ac' | 'all' | 'all_lights'
        action: 'on' | 'off' | 'toggle'
        time_str: '14:30' (24h format) or 'HH:MM'

        Example: Schedule all lights in class 10A to turn off at 17:00
        """
        sb = get_supabase()
        try:
            scheduled_time = datetime.strptime(time_str, "%H:%M").replace(
                year=datetime.now().year,
                month=datetime.now().month,
                day=datetime.now().day
            )

            sb.table("iot_scheduled_actions").insert({
                "school_id": school_id,
                "room_id": room,
                "device": device,
                "action": action,
                "scheduled_time": scheduled_time.isoformat(),
                "status": "pending",
            }).execute()

            return f"⏰ Scheduled: {device} in {room} will {action} at {time_str}"
        except ValueError:
            return "❌ Invalid time format. Please use HH:MM (e.g., 14:30)"
        except Exception as e:
            return f"❌ Error scheduling action: {str(e)}"

    return [control_classroom_device, get_classroom_device_status, schedule_device_action]