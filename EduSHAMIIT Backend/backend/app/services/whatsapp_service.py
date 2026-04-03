import httpx
import os


async def send_whatsapp_message(phone: str, message: str) -> dict:
    """Send a WhatsApp message via Gupshup API."""
    try:
        api_key = os.getenv("WHATSAPP_API_KEY", "placeholder_whatsapp_key")
        source_number = os.getenv("WHATSAPP_NUMBER", "917000000000")

        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://api.gupshup.io/wa/api/v1/msg",
                headers={"apikey": api_key},
                data={
                    "channel": "whatsapp",
                    "source": source_number,
                    "destination": phone,
                    "message": message,
                    "src.name": "EduSHAMIIT"
                },
                timeout=10.0
            )

        if response.status_code == 200:
            return {"success": True, "message": "Message sent"}
        return {"success": False, "error": response.text}
    except Exception as e:
        return {"success": False, "error": str(e)}


async def send_bulk_whatsapp(phones: list, message: str) -> dict:
    """Send WhatsApp messages to multiple numbers."""
    sent = 0
    failed = 0
    for phone in phones:
        result = await send_whatsapp_message(phone, message)
        if result["success"]:
            sent += 1
        else:
            failed += 1
    return {"success": True, "sent": sent, "failed": failed}