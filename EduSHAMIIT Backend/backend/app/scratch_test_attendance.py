import asyncio
import json
from app.api.attendance import exec_sql

async def test():
    # 1. Fetch school and class
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1;")
    school_id = str(schools[0]["id"])
    print("School ID:", school_id)

    classes = await exec_sql("SELECT c.id, c.name FROM public.academic_classes c WHERE c.name ILIKE '%Class 5%' LIMIT 1;")
    class_id = str(classes[0]["id"])
    print("Class:", classes[0]["name"], class_id)

    students = await exec_sql("""
        SELECT sca.student_id, p.full_name
        FROM public.student_class_assignments sca
        JOIN public.profiles p ON p.id = sca.student_id
        WHERE sca.class_id = %s AND sca.school_id = %s
        ORDER BY p.full_name ASC
        LIMIT 3;
    """, (class_id, school_id))
    print("Students found:", len(students))
    for s in students:
        print(" -", s["full_name"], s["student_id"])

    date_str = "2026-08-24"
    admin_users = await exec_sql("""
        SELECT id FROM public.profiles WHERE school_id = %s AND role = 'super_admin' LIMIT 1;
    """, (school_id,))
    user_id = str(admin_users[0]["id"]) if admin_users else str(students[0]["student_id"])

    # Test saving mixed period statuses
    records = []
    if len(students) >= 1:
        records.append({
            "student_id": str(students[0]["student_id"]),
            "status": "HALF_DAY",
            "remarks": "Aarav test",
            "periods": [
                {"period_number": 1, "status": "HALF_DAY", "remarks": ""},
                {"period_number": 2, "status": "PRESENT", "remarks": ""}
            ]
        })
    if len(students) >= 2:
        records.append({
            "student_id": str(students[1]["student_id"]),
            "status": "LATE",
            "remarks": "Ananya test",
            "periods": [
                {"period_number": 1, "status": "ABSENT", "remarks": ""},
                {"period_number": 2, "status": "LATE", "remarks": ""}
            ]
        })
    if len(students) >= 3:
        records.append({
            "student_id": str(students[2]["student_id"]),
            "status": "HALF_DAY",
            "remarks": "Naresh test",
            "periods": [
                {"period_number": 1, "status": "PRESENT", "remarks": ""},
                {"period_number": 2, "status": "HALF_DAY", "remarks": ""}
            ]
        })

    payload = {
        "attendance_date": date_str,
        "class_id": class_id,
        "section_id": None,
        "mode": "ALL_DAY",
        "records": records
    }

    print("\nCalling fn_save_daily_attendance directly with records containing individual periods...")
    res = await exec_sql(
        "SELECT public.fn_save_daily_attendance(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, user_id, json.dumps(payload))
    )
    print("Save result:", res)

    print("\nFetching roster...")
    roster_rows = await exec_sql(
        "SELECT public.fn_get_daily_attendance_roster(%s::UUID, %s::DATE, %s::UUID, NULL, %s, NULL, NULL, %s, %s, %s, %s, NULL) AS result;",
        (school_id, date_str, class_id, "ALL_DAY", "", "ALL", 1, 10)
    )
    roster_data = roster_rows[0]["result"] if isinstance(roster_rows[0]["result"], dict) else json.loads(roster_rows[0]["result"])
    print("\n--- ROSTER RESULT ---")
    for st in roster_data.get("data", {}).get("students", []):
        name = st.get("student_name") or st.get("full_name")
        status = st.get("status")
        periods = st.get("periods", [])
        period_summary = ", ".join([f"P{p.get('period_number')}: {p.get('status')}" for p in periods])
        print(f"Student: {name} | Overall Status: {status} | Periods: [{period_summary}]")

if __name__ == "__main__":
    asyncio.run(test())
