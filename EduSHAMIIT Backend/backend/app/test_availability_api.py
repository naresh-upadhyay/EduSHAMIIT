"""Availability API Unit Test Suite"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

import asyncio
from app.api.auth import check_availability

async def test_check_availability():
    # Test checking non-existent email/phone
    res = await check_availability(email="fresh_user_2026@gmail.com", phone="9876543210")
    assert res["success"] is True
    assert "email_available" in res["data"]
    assert "phone_available" in res["data"]
    print("✅ test_check_availability passed.")

if __name__ == "__main__":
    print("Running Availability API Tests...")
    asyncio.run(test_check_availability())
    print("🎉 All Availability API Tests Passed!")
