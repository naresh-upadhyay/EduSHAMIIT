import asyncio
import os
import sys
import json
import uuid

# Ensure backend root is on sys.path
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.dirname(CURRENT_DIR)
sys.path.insert(0, BACKEND_DIR)

from app.api.hostel import exec_sql

async def run_test():
    school_id = "11111111-1111-1111-1111-111111111111"
    student_id = "b1000001-0000-0000-0000-000000000101" # Deepak Chawla 101
    admin_id = "5198c4b0-f1cb-45db-9649-41688d0438ba"

    print("=== Testing Penalty Assessment and Ledger Synchronization E2E ===")

    # 1. Assess a Penalty (e.g., late payment fine of 100)
    penalty_payload = json.dumps({
        "student_id": student_id,
        "charge_type": "LATE_FEE",
        "penalty_type": "LATE_FEE",
        "amount": 100.0,
        "description": "Fee dues overdue beyond grace period",
        "reason": "Fee dues overdue beyond grace period"
    })

    rows = await exec_sql(
        "SELECT public.fn_hostel_add_penalty(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, admin_id, penalty_payload)
    )
    assert rows and rows[0]["result"]["success"], f"Failed to assess penalty: {rows}"
    penalty_id = rows[0]["result"]["penalty_id"]
    print(f"[OK] Penalty assessed successfully! Penalty ID: {penalty_id}")

    # 2. Verify Penalty in public.hostel_penalties
    rows = await exec_sql(
        "SELECT * FROM public.hostel_penalties WHERE id = %s::UUID;",
        (penalty_id,)
    )
    assert rows and rows[0]["amount"] == 100.0
    print(f"[OK] Penalty verified in hostel_penalties: Amount ₹{rows[0]['amount']}, Status: {rows[0]['status']}")

    # 3. Verify entry in public.hostel_fee_ledger
    rows = await exec_sql(
        "SELECT * FROM public.hostel_fee_ledger WHERE student_id = %s::UUID ORDER BY transaction_date DESC, created_at DESC LIMIT 5;",
        (student_id,)
    )
    assert rows and len(rows) > 0, "No ledger entries found!"
    latest_entry = rows[0]
    print(f"[OK] Latest Ledger Entry: Type: {latest_entry['entry_type']}, Debit: ₹{latest_entry['debit']}, Credit: ₹{latest_entry['credit']}, Balance: ₹{latest_entry['running_balance']}")
    assert latest_entry["running_balance"] is not None, "running_balance must not be None!"

    # 4. Verify 360 financial profile
    rows = await exec_sql(
        "SELECT public.fn_hostel_get_student_fee_details_360(%s::UUID, %s::UUID) AS result;",
        (school_id, student_id)
    )
    assert rows and rows[0]["result"]["success"]
    data = rows[0]["result"]["data"]
    print(f"[OK] 360 Profile: Name: {data['full_name']}")
    print(f"     Total Billed: ₹{data['total_fee']}, Total Paid: ₹{data['total_paid']}, Total Due: ₹{data['total_due']}")
    print(f"     Ledger entries count: {len(data['ledger'])}")
    print(f"     Penalties count: {len(data.get('penalties', []))}")
    assert len(data["ledger"]) >= 1, "Expected at least 1 ledger entry in 360 profile!"
    assert len(data.get("penalties", [])) >= 1, "Expected at least 1 penalty in 360 profile!"

    print("\nALL PENALTY AND LEDGER TESTS PASSED WITH 100% SUCCESS!")

if __name__ == "__main__":
    asyncio.run(run_test())

