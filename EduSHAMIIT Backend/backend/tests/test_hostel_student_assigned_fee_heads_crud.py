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

    print("=== Testing Student Assigned Fee Structure CRUD End-to-End ===")

    # 1. Test 360 profile
    rows = await exec_sql(
        "SELECT public.fn_hostel_get_student_fee_details_360(%s::UUID, %s::UUID) AS result;",
        (school_id, student_id)
    )
    assert rows and rows[0]["result"]["success"], "fn_hostel_get_student_fee_details_360 failed!"
    data = rows[0]["result"]["data"]
    print(f"[OK] 360 profile loaded for: {data['full_name']}")
    print(f"     Total Fee: {data['total_fee']}, Total Paid: {data['total_paid']}, Total Due: {data['total_due']}, Status: {data['status']}")
    
    breakdown = data.get("breakdown") or data.get("fee_breakdown") or []
    print(f"     Breakdown count: {len(breakdown)}")
    for head in breakdown:
        print(f"       - {head['head_name']}: ₹{head['amount']} (Mandatory: {head['is_mandatory']}, Refundable: {head.get('is_refundable')})")
    
    assert len(breakdown) >= 2, f"Expected at least 2 fee heads for Deepak Chawla 101, got {len(breakdown)}"
    baseline_fee = sum(float(h["amount"]) for h in breakdown)
    print(f"     Total assigned breakdown sum: ₹{baseline_fee}")
    assert baseline_fee > 0, "Expected non-zero fee sum"
    assert baseline_fee != 82000.0, "Hardcoded 82,000 fee structure was detected!"

    # 2. Test Get Heads function directly
    rows = await exec_sql(
        "SELECT public.fn_hostel_get_student_fee_heads(%s::UUID, %s::UUID) AS result;",
        (school_id, student_id)
    )
    assert rows and rows[0]["result"]["success"]
    heads = rows[0]["result"]["data"]
    print(f"[OK] fn_hostel_get_student_fee_heads returned {len(heads)} heads")

    # 3. Test Add Fee Head
    new_head_payload = json.dumps({
        "head_name": "Gym & Sports Fee",
        "amount": 500.0,
        "is_mandatory": False,
        "frequency": "MONTHLY"
    })
    rows = await exec_sql(
        "SELECT public.fn_hostel_add_student_fee_head(%s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, student_id, new_head_payload)
    )
    assert rows and rows[0]["result"]["success"]
    added_head = rows[0]["result"]["data"]
    added_id = added_head["id"]
    print(f"[OK] Added fee head: {added_head['head_name']} (ID: {added_id}) - ₹{added_head['amount']}")

    # Verify updated 360 profile totals
    rows = await exec_sql(
        "SELECT public.fn_hostel_get_student_fee_details_360(%s::UUID, %s::UUID) AS result;",
        (school_id, student_id)
    )
    data = rows[0]["result"]["data"]
    print(f"     After Add: Total Fee: {data['total_fee']}, Total Paid: {data['total_paid']}, Total Due: {data['total_due']}, Status: {data['status']}")
    assert float(data["total_fee"]) == baseline_fee + 500.0, f"Expected total fee {baseline_fee + 500.0}, got {data['total_fee']}"

    # 4. Test Update Fee Head
    update_payload = json.dumps({
        "head_name": "Premium Gym & Fitness",
        "amount": 750.0,
        "is_mandatory": True
    })
    rows = await exec_sql(
        "SELECT public.fn_hostel_update_student_fee_head(%s::UUID, %s::UUID, %s::UUID, %s::JSONB) AS result;",
        (school_id, student_id, added_id, update_payload)
    )
    assert rows and rows[0]["result"]["success"]
    updated_head = rows[0]["result"]["data"]
    print(f"[OK] Updated fee head: {updated_head['head_name']} - ₹{updated_head['amount']}")

    # Verify updated 360 profile totals
    rows = await exec_sql(
        "SELECT public.fn_hostel_get_student_fee_details_360(%s::UUID, %s::UUID) AS result;",
        (school_id, student_id)
    )
    data = rows[0]["result"]["data"]
    print(f"     After Update: Total Fee: {data['total_fee']}, Total Due: {data['total_due']}")
    assert float(data["total_fee"]) == baseline_fee + 750.0, f"Expected total fee {baseline_fee + 750.0}, got {data['total_fee']}"

    # 5. Test Delete Fee Head
    rows = await exec_sql(
        "SELECT public.fn_hostel_delete_student_fee_head(%s::UUID, %s::UUID, %s::UUID) AS result;",
        (school_id, student_id, added_id)
    )
    assert rows and rows[0]["result"]["success"]
    print(f"[OK] Deleted fee head ID: {added_id}")

    # Verify totals restored
    rows = await exec_sql(
        "SELECT public.fn_hostel_get_student_fee_details_360(%s::UUID, %s::UUID) AS result;",
        (school_id, student_id)
    )
    data = rows[0]["result"]["data"]
    print(f"     After Delete: Total Fee: {data['total_fee']}, Total Paid: {data['total_paid']}, Total Due: {data['total_due']}, Status: {data['status']}")
    assert float(data["total_fee"]) == baseline_fee, f"Expected total fee restored to {baseline_fee}, got {data['total_fee']}"
    assert float(data["total_due"]) == 0.0, f"Expected total due 0.0, got {data['total_due']}"
    assert data["status"] == "Paid", f"Expected Paid status, got {data['status']}"

    print("\nALL STUDENT ASSIGNED FEE STRUCTURE CRUD TESTS PASSED SUCCESSFULLY! 100% VERIFIED.")

if __name__ == "__main__":
    asyncio.run(run_test())
