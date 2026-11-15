import psycopg2
import json

DSN = "postgresql://postgres:eduSHAMIIT2026_pg@127.0.0.1:54322/postgres"

def test_sync_admissions_to_fees_and_billing():
    conn = psycopg2.connect(DSN)
    cur = conn.cursor()
    school_id = "11111111-1111-1111-1111-111111111111"
    academic_year = "2026 - 2027"

    # 1. Fetch all admitted students in 2026 - 2027 from hostel_admissions
    cur.execute("""
        SELECT a.id, a.student_id, p.full_name, a.admission_status, a.fee_status, a.monthly_fee
        FROM public.hostel_admissions a
        JOIN public.profiles p ON p.id = a.student_id
        WHERE a.school_id = %s AND a.academic_year = %s AND a.deleted_at IS NULL
        ORDER BY p.full_name;
    """, (school_id, academic_year))
    admitted = cur.fetchall()
    admitted_names = [r[2] for r in admitted]
    print(f"Admitted students ({len(admitted)}): {admitted_names}")
    assert "Deepak Chawla 101" in admitted_names, "Deepak Chawla 101 must be in admissions"

    # 2. Call fn_hostel_get_student_fees and ensure every admitted student is present
    cur.execute("""
        SELECT public.fn_hostel_get_student_fees(
            %s::UUID, %s, NULL, NULL, NULL, NULL, 1, 50, 'default', 'ASC'
        );
    """, (school_id, academic_year))
    res = cur.fetchone()[0]
    fee_items = res.get("data", [])
    fee_student_names = [item["name"] for item in fee_items]
    print(f"Fee roster students ({len(fee_items)}): {fee_student_names}")

    for name in admitted_names:
        assert name in fee_student_names, f"Student '{name}' must appear in Fees & Billing roster!"

    # 3. Verify Deepak Chawla 101 details in fee roster
    deepak_item = next(item for item in fee_items if "Deepak Chawla 101" in item["name"])
    print(f"Deepak Chawla 101 fee data: {deepak_item}")
    assert deepak_item["total_fee"] > 0
    assert deepak_item["paid"] > 0
    assert deepak_item["status"] in ("Paid", "Partial")

    # 4. Verify KPI aggregation includes all admitted students
    cur.execute("""
        SELECT public.fn_hostel_get_fee_kpis(%s::UUID, %s);
    """, (school_id, academic_year))
    kpis = cur.fetchone()[0]
    print(f"Fee KPIs: {kpis}")
    assert kpis["total_students_count"] == len(admitted), f"KPI total_students_count ({kpis['total_students_count']}) must match admitted count ({len(admitted)})"

    # 5. Verify Room A-102 bed vacancy
    cur.execute("""
        SELECT r.target_capacity, r.current_occupancy,
               COUNT(b.id) FILTER (WHERE b.status = 'AVAILABLE') AS avail_beds,
               COUNT(b.id) FILTER (WHERE b.status = 'OCCUPIED') AS occ_beds
        FROM public.hostel_rooms r
        JOIN public.hostel_beds b ON b.room_id = r.id AND b.deleted_at IS NULL
        WHERE r.room_number = 'A-102'
        GROUP BY r.target_capacity, r.current_occupancy;
    """)
    room_row = cur.fetchone()
    cap, occ, avail_beds, occ_beds = room_row
    print(f"Room A-102: cap={cap}, occ={occ}, avail_beds={avail_beds}, occ_beds={occ_beds}")
    assert cap - occ == avail_beds, f"Available beds ({avail_beds}) must equal cap - occ ({cap - occ})"

    conn.close()
    print("ALL SYNC ADMISSION TO FEES AND BED ACCURACY TESTS PASSED!")

if __name__ == "__main__":
    test_sync_admissions_to_fees_and_billing()

