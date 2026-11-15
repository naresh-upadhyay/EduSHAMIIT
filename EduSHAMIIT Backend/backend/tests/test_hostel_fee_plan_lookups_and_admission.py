import psycopg2
import json

DSN = "postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:5432/postgres"

def test_hostel_fee_lookups_and_admission_e2e():
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()

    # 1. Fetch School
    cur.execute("SELECT id FROM public.schools LIMIT 1;")
    school_id = cur.fetchone()[0]
    assert school_id is not None

    # 2. Test fn_get_lookup_by_code for HOSTEL_FEE_BILLING_PLAN
    cur.execute("SELECT public.fn_get_lookup_by_code(%s, 'HOSTEL_FEE_BILLING_PLAN', false);", (school_id,))
    res_plan = cur.fetchone()[0]
    assert res_plan.get("success") is True
    values_plan = res_plan.get("values", [])
    assert len(values_plan) >= 4
    labels = [v["label"] for v in values_plan]
    assert "Monthly" in labels
    assert "Quarterly" in labels
    assert "Bi-Annual" in labels
    assert "Annual" in labels
    for lbl in labels:
        assert "₹" not in lbl, f"Plan label {lbl} should not have hardcoded amount"
        assert "(" not in lbl, f"Plan label {lbl} should not have hardcoded amount"

    # 3. Test fn_get_lookup_by_code for HOSTEL_INITIAL_FEE_PAYMENT_STATUS
    cur.execute("SELECT public.fn_get_lookup_by_code(%s, 'HOSTEL_INITIAL_FEE_PAYMENT_STATUS', false);", (school_id,))
    res_status = cur.fetchone()[0]
    assert res_status.get("success") is True
    values_status = res_status.get("values", [])
    assert len(values_status) >= 4
    status_codes = [v["code"] for v in values_status]
    assert "PAID" in status_codes
    assert "PENDING" in status_codes
    assert "PARTIAL" in status_codes
    assert "WAIVED" in status_codes

    # 4. Find an existing student profile
    cur.execute("SELECT id FROM public.profiles WHERE school_id = %s LIMIT 1;", (school_id,))
    prof_row = cur.fetchone()
    if prof_row:
        student_id = prof_row[0]
        # Check student detail
        cur.execute("SELECT public.fn_hostel_get_student_detail(%s, NULL, %s);", (school_id, student_id))
        detail_res = cur.fetchone()[0]
        # If student has admission, verify clean fee_plan
        if detail_res.get("success") and detail_res.get("data"):
            data = detail_res["data"]
            assert "(" not in data.get("fee_plan", ""), "fee_plan in student detail should not contain amount in parentheses"

    conn.close()

if __name__ == "__main__":
    test_hostel_fee_lookups_and_admission_e2e()
    print("ALL BACKEND LOOKUP AND ADMISSION TESTS PASSED!")

