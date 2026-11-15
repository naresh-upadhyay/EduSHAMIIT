import asyncio
import jwt
import httpx
from datetime import datetime, timezone, timedelta

SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"
ALGORITHM = "HS256"

def get_auth_token():
    payload = {
        "sub": "5198c4b0-f1cb-45db-9649-41688d0438ba",
        "id": "5198c4b0-f1cb-45db-9649-41688d0438ba",
        "email": "admin@edushamiit.com",
        "role": "SUPER_ADMIN",
        "school_id": "11111111-1111-1111-1111-111111111111",
        "exp": datetime.now(timezone.utc) + timedelta(hours=2)
    }
    return jwt.encode(payload, SECRET, algorithm=ALGORITHM)

async def test_all():
    token = get_auth_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    async with httpx.AsyncClient(base_url="http://localhost:8082", timeout=20.0) as client:
        print("\n--- TEST 1: EXPORT FEES CSV (2026 - 2027) ---")
        res_export = await client.get("/api/hostel/fees/export", headers=headers, params={"academic_year": "2026 - 2027"})
        assert res_export.status_code == 200, f"Export failed: {res_export.text}"
        csv_text = res_export.text
        lines = [l for l in csv_text.strip().split("\n") if l.strip()]
        print(f"Export CSV lines count: {len(lines)}")
        print("CSV Header:", lines[0])
        for line in lines[1:]:
            print("Row:", line)
        assert len(lines) == 6, f"Expected 1 header + 5 students = 6 lines, got {len(lines)}"
        assert "Deepak Chawla 101" in csv_text
        assert "Aman Khan" in csv_text
        assert "Ananya Singh" in csv_text
        assert "Aarav Sharma" in csv_text
        assert "Aditi Rao" in csv_text
        print("[PASS] Test 1: Export Fees CSV verified with exact 5 visible students!")

        print("\n--- TEST 2: EXPORT FEES CSV WITH FILTER (SELECTED STUDENT) ---")
        deepak_id = "b1000001-0000-0000-0000-000000000101"
        res_export_filtered = await client.get(
            "/api/hostel/fees/export", 
            headers=headers, 
            params={"academic_year": "2026 - 2027", "student_ids": deepak_id}
        )
        assert res_export_filtered.status_code == 200
        filtered_lines = [l for l in res_export_filtered.text.strip().split("\n") if l.strip()]
        print(f"Filtered lines count: {len(filtered_lines)}")
        assert len(filtered_lines) == 2, f"Expected 1 header + 1 student = 2 lines, got {len(filtered_lines)}"
        assert "Deepak Chawla 101" in filtered_lines[1]
        print("[PASS] Test 2: Filtered export verified!")

        print("\n--- TEST 3: SEND DUE REMINDERS (SCOPED TO VISIBLE STUDENTS WITH DUES) ---")
        remind_res = await client.post(
            "/api/hostel/fees/reminders",
            headers=headers,
            json={
                "academic_year": "2026 - 2027",
                "reminder_type": "OVERDUE",
                "channel": "ALL"
            }
        )
        assert remind_res.status_code == 200, f"Reminders failed: {remind_res.text}"
        remind_data = remind_res.json()
        print("Reminders response:", remind_data)
        assert remind_data["success"] is True
        # Only Deepak Chawla has dues (₹1,000). The other 4 students are Over Paid (₹0 due)
        assert remind_data["sent_count"] == 1, f"Expected 1 student with dues, got {remind_data['sent_count']}"
        assert remind_data["reminded_students"][0]["student_name"] == "Deepak Chawla 101"
        assert remind_data["reminded_students"][0]["email"] == "student.101@edushamiit.com"
        assert remind_data["reminded_students"][0]["due_amount"] == 1000.0
        print("[PASS] Test 3: Due reminders sent ONLY to visible student with dues on registered email!")

        print("\n--- TEST 4: BULK GENERATE INVOICES SCOPED TO 2026 - 2027 ---")
        bulk_res = await client.post(
            "/api/hostel/fees/invoices/bulk",
            headers=headers,
            json={
                "academic_year": "2026 - 2027",
                "billing_period": f"Test Term {datetime.now().strftime('%Y%m%d%H%M%S')}",
                "student_ids": [deepak_id]
            }
        )
        assert bulk_res.status_code == 200, f"Bulk invoices failed: {bulk_res.text}"
        bulk_data = bulk_res.json()
        print("Bulk invoice response:", bulk_data)
        assert bulk_data["success"] is True
        assert bulk_data["created_count"] == 1
        print("[PASS] Test 4: Bulk invoice generation successfully scoped!")

if __name__ == "__main__":
    asyncio.run(test_all())
