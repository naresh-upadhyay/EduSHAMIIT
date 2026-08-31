import asyncio
from app.api.attendance import get_staff_attendance

async def test():
    school_id = "11111111-1111-1111-1111-111111111111"
    admin_dict = {
        "id": "10000000-0000-0000-0000-000000000003",
        "email": "admin@edushamiit.com",
        "role": "super_admin",
        "school_id": school_id
    }
    res = await get_staff_attendance(
        attendance_date="2026-08-19",
        department="ALL",
        role="ALL",
        status="ALL",
        search="",
        page=1,
        page_size=50,
        manager_id=None,
        current_user=admin_dict,
        school_id=school_id
    )
    staff = res["data"]["staff"]
    print("STAFF SAMPLE:", staff[0] if staff else "EMPTY")

asyncio.run(test())
