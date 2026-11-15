import psycopg2
import json

import os

# Connect to Docker Supabase DB on port 54322 or 5432
DSN = os.environ.get("DATABASE_URL", "postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:54322/postgres")

def test_hostel_fee_overpaid_mathematics_e2e():
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()

    # 1. Fetch School
    cur.execute("SELECT id FROM public.schools LIMIT 1;")
    school_id = cur.fetchone()[0]
    assert school_id is not None

    # 2. Check Ananya Singh record in hostel_student_accounts
    cur.execute("""
        SELECT acc.id, p.full_name, acc.total_billed, acc.total_paid, acc.total_due, acc.advance_credit, acc.payment_status
        FROM public.hostel_student_accounts acc
        JOIN public.profiles p ON acc.student_id = p.id
        WHERE p.full_name ILIKE '%Ananya Singh%' AND acc.academic_year = '2026 - 2027';
    """)
    ananya_row = cur.fetchone()
    assert ananya_row is not None, "Ananya Singh record should exist in 2026 - 2027"
    acc_id, name, billed, paid, due, adv_credit, p_status = ananya_row
    print(f"Ananya Singh -> Billed: {billed}, Paid: {paid}, Due: {due}, Advance Credit: {adv_credit}, Status: {p_status}")
    assert paid > billed, f"Ananya Singh should have paid > billed ({paid} > {billed})"
    assert float(due) == 0.0, f"Overpaid account must have total_due == 0.00, got {due}"
    assert p_status == "OVERPAID", f"Overpaid account must have payment_status == 'OVERPAID', got {p_status}"
    assert float(adv_credit) == float(paid - billed), f"Advance credit must equal {paid - billed}, got {adv_credit}"

    # 3. Check Aditi Rao record in hostel_student_accounts
    cur.execute("""
        SELECT acc.id, p.full_name, acc.total_billed, acc.total_paid, acc.total_due, acc.advance_credit, acc.payment_status
        FROM public.hostel_student_accounts acc
        JOIN public.profiles p ON acc.student_id = p.id
        WHERE p.full_name ILIKE '%Aditi Rao%' AND acc.academic_year = '2026 - 2027';
    """)
    aditi_row = cur.fetchone()
    assert aditi_row is not None, "Aditi Rao record should exist in 2026 - 2027"
    _, aditi_name, aditi_billed, aditi_paid, aditi_due, aditi_adv, aditi_status = aditi_row
    print(f"Aditi Rao -> Billed: {aditi_billed}, Paid: {aditi_paid}, Due: {aditi_due}, Advance Credit: {aditi_adv}, Status: {aditi_status}")
    assert aditi_paid > aditi_billed
    assert float(aditi_due) == 0.0
    assert aditi_status == "OVERPAID"
    assert float(aditi_adv) == float(aditi_paid - aditi_billed)

    # 4. Test fn_hostel_get_student_fees output
    cur.execute("""
        SELECT public.fn_hostel_get_student_fees(%s::UUID, '2026 - 2027', 'Ananya');
    """, (school_id,))
    fee_list_json = cur.fetchone()[0]
    items = fee_list_json.get("data", [])
    assert len(items) >= 1
    ananya_fee_item = items[0]
    print(f"fn_hostel_get_student_fees output: {ananya_fee_item}")
    assert ananya_fee_item["name"] == "Ananya Singh"
    assert float(ananya_fee_item["paid"]) > float(ananya_fee_item["total_fee"])
    assert float(ananya_fee_item["due"]) == 0.0, f"due must be 0.00, got {ananya_fee_item['due']}"
    assert ananya_fee_item["status"] == "Over Paid", f"status must be 'Over Paid', got {ananya_fee_item['status']}"
    assert ananya_fee_item["status_raw"] == "OVERPAID"

    # 5. Test fn_hostel_get_student_fee_details_360 output
    cur.execute("""
        SELECT acc.student_id
        FROM public.hostel_student_accounts acc
        JOIN public.profiles p ON acc.student_id = p.id
        WHERE p.full_name ILIKE '%Ananya Singh%' AND acc.academic_year = '2026 - 2027';
    """)
    ananya_student_id = cur.fetchone()[0]
    cur.execute("""
        SELECT public.fn_hostel_get_student_fee_details_360(%s::UUID, %s::UUID);
    """, (school_id, ananya_student_id))
    detail_res = cur.fetchone()[0]
    detail_360 = detail_res.get("data", {}) if isinstance(detail_res, dict) else {}
    print(f"fn_hostel_get_student_fee_details_360 output status: {detail_360.get('status')}, total_due: {detail_360.get('total_due')}")
    assert float(detail_360["total_due"]) == 0.0, f"360 total_due must be 0.00, got {detail_360.get('total_due')}"
    assert detail_360["status"] == "Over Paid", f"360 status must be 'Over Paid', got {detail_360.get('status')}"
    assert detail_360["payment_status"] == "OVERPAID"
    assert float(detail_360["advance_credit"]) in (12000.0, 14000.0), f"advance_credit must be 12000.0 or 14000.0, got {detail_360.get('advance_credit')}"

    # 6. Test filtering by 'Over Paid' in fn_hostel_get_student_fees
    cur.execute("""
        SELECT public.fn_hostel_get_student_fees(
            %s::UUID, '2026 - 2027', NULL, NULL, NULL, 'Over Paid', 1, 10
        );
    """, (school_id,))
    overpaid_list = cur.fetchone()[0]
    overpaid_items = overpaid_list.get("data", [])
    assert len(overpaid_items) >= 2, f"Should return at least Ananya and Aditi, got {len(overpaid_items)}"
    for item in overpaid_items:
        assert float(item["paid"]) > float(item["total_fee"])
        assert float(item["due"]) == 0.0
        assert item["status"] == "Over Paid"

    conn.close()
    print("ALL BACKEND OVERPAID MATHEMATICS TESTS PASSED!")

if __name__ == "__main__":
    test_hostel_fee_overpaid_mathematics_e2e()
