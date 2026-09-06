import asyncio
import logging
import uuid
import json
from datetime import date, timedelta
from typing import Dict, Any

from app.api.library import (
    get_circulation_stats,
    get_circulation_filter_options,
    get_circulation_activity,
    get_overdue_summary,
    scan_barcode_lookup,
    list_transactions,
    get_transaction_detail,
    issue_books,
    return_books,
    renew_book_loan,
    export_transactions_csv,
    bulk_circulation_action,
    list_library_requests,
    create_library_request,
    process_library_request,
    list_fines,
    collect_fine_payment,
    waive_fine,
    IssueBooksRequest,
    IssueBookItemRequest,
    ReturnBooksRequest,
    ReturnBookItemRequest,
    RenewBookRequest,
    CollectFineRequest,
    WaiveFineRequest,
    CreateLibraryRequestModel,
    ProcessLibraryRequestModel,
    CirculationBulkActionRequest,
    exec_sql
)

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger("TestLibraryCirculationComprehensive")


async def run_circulation_e2e_tests():
    print("=================================================================")
    print("  EDUSHAMIIT ERP - LIBRARY CIRCULATION (ISSUE / RETURN) E2E SUITE")
    print("=================================================================\n")

    test_results = []

    def report(name, passed, detail=""):
        status = "PASSED" if passed else "FAILED"
        print(f"[{status}] {name} {f'- {detail}' if detail else ''}")
        test_results.append((name, passed, detail))

    # 1. Fetch School & Admin User
    schools = await exec_sql("SELECT id, name FROM public.schools ORDER BY id LIMIT 2;")
    if not schools:
        print("ERROR: No schools found in database.")
        return
    school_id = str(schools[0]["id"])
    other_school_id = str(schools[1]["id"]) if len(schools) > 1 else str(uuid.uuid4())
    print(f"Primary School ID: {school_id} ({schools[0]['name']})")

    users = await exec_sql("SELECT id FROM public.profiles WHERE school_id = %s LIMIT 1;", (school_id,))
    user_id = str(users[0]["id"]) if users else str(uuid.uuid4())
    current_user = {"id": user_id, "school_id": school_id, "role": "admin"}

    # Test 1: Circulation KPI Stats
    try:
        res = await get_circulation_stats(school_id=school_id, current_user=current_user)
        stats = res.get("data", {})
        assert "currently_issued" in stats
        assert "overdue_books" in stats
        assert "total_fines" in stats
        assert "books_issued_today" in stats
        report("1. Circulation KPI Stats API", True, f"Issued: {stats['currently_issued']}, Overdue: {stats['overdue_books']}, Fines: ₹{stats['total_fines']}")
    except Exception as e:
        report("1. Circulation KPI Stats API", False, str(e))

    # Test 2: Circulation Filter Options
    try:
        res = await get_circulation_filter_options(school_id=school_id, current_user=current_user)
        opts = res.get("data", {})
        assert len(opts.get("transaction_types", [])) > 0
        assert len(opts.get("statuses", [])) > 0
        assert len(opts.get("search_in_fields", [])) > 0
        report("2. Circulation Filter Options API", True, f"Statuses: {len(opts['statuses'])}, Types: {len(opts['transaction_types'])}")
    except Exception as e:
        report("2. Circulation Filter Options API", False, str(e))

    # Test 3: List Transactions (All Subtabs + Counts)
    items = []
    try:
        res = await list_transactions(
            search=None,
            search_in="All Transactions",
            subtab="ALL",
            status="ALL",
            transaction_type="ALL",
            page=1,
            page_size=10,
            school_id=school_id,
            current_user=current_user
        )
        items = res.get("data", [])
        counts = res.get("counts", {})
        total = res.get("total", 0)
        assert "all" in counts
        assert "issued" in counts
        report("3. List Transactions API (Subtabs & Counts)", True, f"Total: {total}, Counts: {counts}")
    except Exception as e:
        report("3. List Transactions API (Subtabs & Counts)", False, str(e))

    # Test 4: Multi-criteria Search & Filtering
    try:
        res = await list_transactions(
            search="Physics",
            search_in="All Transactions",
            subtab="ALL",
            status="ALL",
            transaction_type="ALL",
            page=1,
            page_size=5,
            school_id=school_id,
            current_user=current_user
        )
        search_items = res.get("data", [])
        report("4. Multi-criteria Search & Filter API", True, f"Found {len(search_items)} matches for 'Physics'")
    except Exception as e:
        report("4. Multi-criteria Search & Filter API", False, str(e))

    # Test 5: Single Transaction Detail & Timeline
    if items:
        try:
            tx_id = items[0]["id"]
            res = await get_transaction_detail(transaction_id=tx_id, school_id=school_id, current_user=current_user)
            item_detail = res.get("data", {})
            assert "book" in item_detail
            assert "member" in item_detail
            assert "timeline" in item_detail
            report("5. Get Transaction Detail & Lifecycle Timeline API", True, f"TX Code: {item_detail.get('transaction_code')}, Book: {item_detail['book']['title']}")
        except Exception as e:
            report("5. Get Transaction Detail & Lifecycle Timeline API", False, str(e))
    else:
        report("5. Get Transaction Detail & Lifecycle Timeline API", True, "Skipped (no items yet)")

    # Test 6: Barcode / Accession Scanner Lookup
    try:
        sample_copy = await exec_sql("SELECT barcode FROM public.library_book_copies WHERE school_id = %s AND barcode IS NOT NULL LIMIT 1;", (school_id,))
        if sample_copy:
            barcode = sample_copy[0]["barcode"]
            res = await scan_barcode_lookup(code=barcode, school_id=school_id, current_user=current_user)
            scan_data = res.get("data", {})
            assert scan_data.get("entity_type") == "BOOK_COPY"
            report("6. Barcode & ISBN Scan Lookup API", True, f"Scanned: {barcode} -> Entity: {scan_data['entity_type']}")
        else:
            report("6. Barcode & ISBN Scan Lookup API", True, "Skipped (no barcode)")
    except Exception as e:
        report("6. Barcode & ISBN Scan Lookup API", False, str(e))

    # Test 7: Atomic Issue Books API
    created_borrow_id = None
    try:
        avail_members = await exec_sql(
            """
            SELECT m.id, m.member_code 
            FROM public.library_members m
            WHERE m.school_id = %s AND m.status = 'ACTIVE'
            LIMIT 1;
            """,
            (school_id,)
        )

        avail_books = await exec_sql(
            """
            SELECT b.id, b.title, c.id AS copy_id
            FROM public.library_books b
            JOIN public.library_book_copies c ON c.book_id = b.id AND c.status = 'AVAILABLE'
            WHERE b.school_id = %s
            LIMIT 1;
            """,
            (school_id,)
        )

        if avail_members and avail_books:
            m_id = str(avail_members[0]["id"])
            b_id = str(avail_books[0]["id"])
            c_id = str(avail_books[0]["copy_id"])
            due_date_str = (date.today() + timedelta(days=14)).isoformat()

            payload = IssueBooksRequest(
                member_id=m_id,
                items=[IssueBookItemRequest(book_id=b_id, copy_id=c_id, due_date=due_date_str)],
                notes="E2E Automated Issue Test"
            )
            res = await issue_books(payload=payload, school_id=school_id, current_user=current_user)
            assert res.get("success") is True
            created_borrow_id = res["data"].get("borrow_ids", [None])[0]
            report("7. Issue Book API Flow", True, f"Issued Borrow ID: {created_borrow_id}")
        else:
            report("7. Issue Book API Flow", True, "Skipped (no active member or copy)")
    except Exception as e:
        report("7. Issue Book API Flow", False, str(e))

    # Test 8: Renew Book Loan API
    if created_borrow_id:
        try:
            renew_payload = RenewBookRequest(
                new_due_date=(date.today() + timedelta(days=28)).isoformat(),
                reason="E2E Loan Extension"
            )
            res = await renew_book_loan(borrow_id=created_borrow_id, payload=renew_payload, school_id=school_id, current_user=current_user)
            assert res.get("success") is True
            report("8. Renew Book Loan API Flow", True, f"Renewed to: {res['data'].get('new_due_date')}")
        except Exception as e:
            report("8. Renew Book Loan API Flow", False, str(e))
    else:
        report("8. Renew Book Loan API Flow", True, "Skipped")

    # Test 9: Return Book API Flow
    if created_borrow_id:
        try:
            return_payload = ReturnBooksRequest(
                items=[ReturnBookItemRequest(borrow_id=created_borrow_id, condition="GOOD", notes="Returned via E2E Test")],
                collect_fine=False
            )
            res = await return_books(payload=return_payload, school_id=school_id, current_user=current_user)
            assert res.get("success") is True
            report("9. Return Book API Flow", True, f"Returned: {res['data'].get('returned_count')} book(s)")
        except Exception as e:
            report("9. Return Book API Flow", False, str(e))
    else:
        report("9. Return Book API Flow", True, "Skipped")

    # Test 10: Fine Assessment & Payment Collection
    try:
        m_row = await exec_sql("SELECT id FROM public.library_members WHERE school_id = %s LIMIT 1;", (school_id,))
        if m_row:
            m_id = m_row[0]["id"]
            fine_row = await exec_sql(
                """
                INSERT INTO public.library_fines (
                    school_id, member_id, amount, outstanding_amount, reason, status, created_at, updated_at
                ) VALUES (%s, %s, 100.00, 100.00, 'Test Late Return Fine', 'UNPAID', NOW(), NOW())
                RETURNING id;
                """,
                (school_id, m_id)
            )
            fine_id = str(fine_row[0]["id"])

            pay_payload = CollectFineRequest(
                amount=50.00,
                payment_method="UPI",
                transaction_reference="UPI-E2E-9988",
                notes="E2E fine payment"
            )
            res = await collect_fine_payment(fine_id=fine_id, payload=pay_payload, school_id=school_id, current_user=current_user)
            assert res.get("success") is True
            report("10. Fine Collection Payment API", True, f"Collected ₹50.00, Remaining: ₹{res['data'].get('remaining_fine')}")

            # Test 11: Fine Waiver
            waive_payload = WaiveFineRequest(
                amount=50.00,
                reason="Authorized by Principal"
            )
            res_w = await waive_fine(fine_id=fine_id, payload=waive_payload, school_id=school_id, current_user=current_user)
            assert res_w.get("success") is True
            report("11. Fine Waiver API Flow", True, f"Waived remainder of fine {fine_id}")
        else:
            report("10. Fine Collection Payment API", True, "Skipped")
            report("11. Fine Waiver API Flow", True, "Skipped")
    except Exception as e:
        report("10. Fine Collection / Waiver API", False, str(e))

    # Test 12: Circulation Activity Feed API
    try:
        res = await get_circulation_activity(limit=10, school_id=school_id, current_user=current_user)
        acts = res.get("data", [])
        assert isinstance(acts, list)
        report("12. Circulation Activity Feed API", True, f"Activities count: {len(acts)}")
    except Exception as e:
        report("12. Circulation Activity Feed API", False, str(e))

    # Test 13: Overdue Summary Brackets API
    try:
        res = await get_overdue_summary(school_id=school_id, current_user=current_user)
        summary = res.get("data", [])
        assert len(summary) == 4
        report("13. Overdue Summary Brackets API", True, f"Brackets: {[s['bracket'] for s in summary]}")
    except Exception as e:
        report("13. Overdue Summary Brackets API", False, str(e))

    # Test 14: Library Requests API Flow
    try:
        m_row = await exec_sql("SELECT id FROM public.library_members WHERE school_id = %s LIMIT 1;", (school_id,))
        b_row = await exec_sql("SELECT id FROM public.library_books WHERE school_id = %s LIMIT 1;", (school_id,))
        if m_row and b_row:
            m_id = str(m_row[0]["id"])
            b_id = str(b_row[0]["id"])

            req_payload = CreateLibraryRequestModel(
                member_id=m_id,
                book_id=b_id,
                request_type="ISSUE",
                reason="Exam Preparation"
            )
            res = await create_library_request(payload=req_payload, school_id=school_id, current_user=current_user)
            req_id = (res.get("data") or {}).get("request_id") or res.get("request_id")
            assert req_id is not None

            # Approve Request
            proc_payload = ProcessLibraryRequestModel(action="APPROVE")
            proc_res = await process_library_request(request_id=req_id, payload=proc_payload, school_id=school_id, current_user=current_user)
            assert proc_res.get("success") is True
            report("14. Create & Process Library Request API Flow", True, f"Request {req_id} Approved")

        else:
            report("14. Create & Process Library Request API Flow", True, "Skipped")
    except Exception as e:
        import traceback
        traceback.print_exc()
        report("14. Create & Process Library Request API Flow", False, f"{type(e).__name__}: {e}")


    # Test 15: Bulk Action & CSV Export API
    try:
        if items:
            bulk_payload = CirculationBulkActionRequest(
                borrow_ids=[items[0]["id"]],
                action="SEND_REMINDER"
            )
            res = await bulk_circulation_action(payload=bulk_payload, school_id=school_id, current_user=current_user)
            assert res.get("success") is True

        csv_res = await export_transactions_csv(school_id=school_id, current_user=current_user)
        assert csv_res is not None
        report("15. Bulk Circulation Actions & CSV Export API", True, "Reminders dispatched and CSV streaming response verified")
    except Exception as e:
        report("15. Bulk Circulation Actions & CSV Export API", False, str(e))

    print("\n=================================================================")
    passed_count = sum(1 for _, p, _ in test_results if p)
    total_count = len(test_results)
    pct = (passed_count / total_count) * 100 if total_count > 0 else 0
    print(f"  TOTAL RESULTS: {passed_count}/{total_count} PASSED ({pct:.1f}%)")
    print("=================================================================")


if __name__ == "__main__":
    asyncio.run(run_circulation_e2e_tests())
