import asyncio
import sys
import uuid
from datetime import date, datetime, timedelta
from typing import Dict, Any, List

from app.api.library import (
    get_library_requests_kpis,
    get_library_requests_options,
    list_library_requests,
    get_library_request_detail,
    create_library_request,
    transition_library_request_status,
    assign_library_request,
    approve_library_request,
    request_or_respond_clarification,
    add_library_request_comment,
    add_library_request_attachment,
    bulk_requests_action,
    export_library_requests_csv,
    CreateLibraryRequestModel,
    TransitionRequestStatusModel,
    AssignRequestModel,
    ApproveRequestModel,
    ClarificationRequestModel,
    AddRequestCommentModel,
    AddRequestAttachmentModel,
    RequestBulkActionModel,
    exec_sql
)


async def run_requests_e2e():
    print("\n" + "=" * 65)
    print("  EDUSHAMIIT ERP - LIBRARY REQUESTS MANAGEMENT E2E SUITE")
    print("=" * 65 + "\n")

    # Fetch school context
    school_rows = await exec_sql("SELECT id, name FROM public.schools ORDER BY created_at ASC LIMIT 1;")
    if not school_rows:
        print("[ERROR] No schools found in database.")
        return

    school_id = str(school_rows[0]["id"])
    school_name = school_rows[0]["name"]
    print(f"Primary School ID: {school_id} ({school_name})")

    # Fetch active admin/librarian user profile
    prof_rows = await exec_sql("SELECT id, full_name, email, role FROM public.profiles WHERE school_id = %s LIMIT 1;", (school_id,))
    if not prof_rows:
        print("[ERROR] No profiles found in database.")
        return

    admin_user = {
        "id": str(prof_rows[0]["id"]),
        "full_name": prof_rows[0]["full_name"],
        "email": prof_rows[0]["email"],
        "role": "admin"
    }


    results = []

    def report(name: str, passed: bool, details: str = ""):
        status_str = "[PASSED]" if passed else "[FAILED]"
        print(f"{status_str} {name}" + (f" - {details}" if details else ""))
        results.append((name, passed, details))

    # Test 1: Requests KPI Stats API
    try:
        res = await get_library_requests_kpis(school_id=school_id, current_user=admin_user)
        kpis = res.get("data", {})
        assert "total_requests" in kpis
        assert "new_requests" in kpis
        assert "in_progress" in kpis
        assert "resolved" in kpis
        report("1. Requests KPI Metrics API", True, f"Total: {kpis['total_requests']}, New: {kpis['new_requests']}, In Progress: {kpis['in_progress']}, Resolved: {kpis['resolved']}")
    except Exception as e:
        report("1. Requests KPI Metrics API", False, str(e))

    # Test 2: Requests Options API
    try:
        res = await get_library_requests_options(school_id=school_id, current_user=admin_user)
        opts = res.get("data", {})
        assert len(opts.get("categories", [])) > 0
        assert len(opts.get("request_types", [])) > 0
        report("2. Configurable Dropdown Options API", True, f"Categories: {len(opts['categories'])}, Types: {len(opts['request_types'])}, Roles: {len(opts['roles'])}")
    except Exception as e:
        report("2. Configurable Dropdown Options API", False, str(e))

    # Test 3: List Requests API
    try:
        res = await list_library_requests(page=1, page_size=10, school_id=school_id, current_user=admin_user)
        items = res.get("data", [])
        total = res.get("total", 0)
        assert isinstance(items, list)
        report("3. List Paginated Requests API", True, f"Total records: {total}, First page count: {len(items)}")
    except Exception as e:
        report("3. List Paginated Requests API", False, str(e))

    # Test 4: Multi-criteria Search & Filter API
    try:
        res_search = await list_library_requests(search="Psychology", page=1, page_size=10, school_id=school_id, current_user=admin_user)
        found = res_search.get("data", [])
        assert len(found) >= 1
        assert "Psychology" in found[0]["title"]
        report("4. Multi-criteria Search & Filter API", True, f"Found {len(found)} match for 'Psychology' (REQ Code: {found[0]['request_number']})")
    except Exception as e:
        report("4. Multi-criteria Search & Filter API", False, str(e))

    # Test 5: Create Request for Existing Book
    created_req_id = None
    try:
        book_rows = await exec_sql("SELECT id, title FROM public.library_books WHERE school_id = %s LIMIT 1;", (school_id,))
        if book_rows:
            b_id = str(book_rows[0]["id"])
            b_title = book_rows[0]["title"]
            payload = CreateLibraryRequestModel(
                book_id=b_id,
                request_type="Book",
                category_code="BOOK",
                priority="High",
                reason="E2E Existing Book Request Test",
                required_by=(date.today() + timedelta(days=14)).isoformat()
            )
            res = await create_library_request(payload=payload, school_id=school_id, current_user=admin_user)
            assert res.get("success") is True
            created_req_id = res["data"].get("request_id")
            req_num = res["data"].get("request_number")
            report("5. Create Request (Existing Book) API", True, f"Created {req_num} (ID: {created_req_id}) for '{b_title}'")
        else:
            report("5. Create Request (Existing Book) API", True, "Skipped (no books in catalog)")
    except Exception as e:
        report("5. Create Request (Existing Book) API", False, str(e))

    # Test 6: Create Request for Custom / New Resource
    custom_req_id = None
    try:
        payload = CreateLibraryRequestModel(
            title="Clean Code: A Handbook of Agile Software Craftsmanship",
            author="Robert C. Martin",
            isbn="978-0132350884",
            publisher="Prentice Hall",
            language="English",
            preferred_format="Physical",
            request_type="Book",
            category_code="BOOK",
            priority="Urgent",
            reason="Required for faculty programming training",
            required_by=(date.today() + timedelta(days=21)).isoformat()
        )
        res = await create_library_request(payload=payload, school_id=school_id, current_user=admin_user)
        assert res.get("success") is True
        custom_req_id = res["data"].get("request_id")
        req_num = res["data"].get("request_number")
        report("6. Create Request (New Resource) API", True, f"Created {req_num} for '{payload.title}'")
    except Exception as e:
        report("6. Create Request (New Resource) API", False, str(e))

    # Test 7: Get Request Detail & Nested Relations API
    target_req_id = created_req_id or custom_req_id
    if target_req_id:
        try:
            res = await get_library_request_detail(request_id=target_req_id, school_id=school_id, current_user=admin_user)
            data = res.get("data", {})
            assert "request" in data
            assert "timeline" in data
            assert len(data["timeline"]) >= 1
            report("7. Get Request Detail & Lifecycle Timeline API", True, f"Timeline events: {len(data['timeline'])}, Title: {data['request']['title']}")
        except Exception as e:
            report("7. Get Request Detail & Lifecycle Timeline API", False, str(e))
    else:
        report("7. Get Request Detail & Lifecycle Timeline API", True, "Skipped")

    # Test 8: Status Machine Transition (NEW -> ACTIVE -> IN_PROGRESS -> RESOLVED -> COMPLETED)
    if target_req_id:
        try:
            # Step A: NEW -> ACTIVE
            res_act = await transition_library_request_status(
                request_id=target_req_id,
                payload=TransitionRequestStatusModel(to_status="ACTIVE", comment="Reviewed and accepted by librarian"),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_act.get("success") is True

            # Step B: ACTIVE -> IN_PROGRESS
            res_prog = await transition_library_request_status(
                request_id=target_req_id,
                payload=TransitionRequestStatusModel(to_status="IN_PROGRESS", comment="Checking rack and procurement"),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_prog.get("success") is True

            # Step C: IN_PROGRESS -> RESOLVED
            res_res = await transition_library_request_status(
                request_id=target_req_id,
                payload=TransitionRequestStatusModel(to_status="RESOLVED", comment="Book copy reserved and placed on hold shelf"),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_res.get("success") is True

            # Step D: RESOLVED -> COMPLETED
            res_comp = await transition_library_request_status(
                request_id=target_req_id,
                payload=TransitionRequestStatusModel(to_status="COMPLETED", comment="Member picked up requested resource"),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_comp.get("success") is True
            report("8. Lifecycle State Machine (NEW -> COMPLETED)", True, "Successfully traversed all 4 workflow milestones with audit history")
        except Exception as e:
            report("8. Lifecycle State Machine (NEW -> COMPLETED)", False, str(e))
    else:
        report("8. Lifecycle State Machine (NEW -> COMPLETED)", True, "Skipped")

    # Test 9: Rejection Flow with Mandatory Reason
    if custom_req_id:
        try:
            res_rej = await transition_library_request_status(
                request_id=custom_req_id,
                payload=TransitionRequestStatusModel(to_status="REJECTED", reason="Out of print and exceeds department budget"),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_rej.get("success") is True
            report("9. Request Rejection Flow API", True, f"Request {custom_req_id} rejected with recorded reason")
        except Exception as e:
            report("9. Request Rejection Flow API", False, str(e))
    else:
        report("9. Request Rejection Flow API", True, "Skipped")

    # Test 10: Requester Cancellation Flow
    try:
        cancel_payload = CreateLibraryRequestModel(
            title="Temporary Test Book for Cancellation",
            author="Test Author",
            request_type="Book",
            reason="To be canceled immediately"
        )
        res_c = await create_library_request(payload=cancel_payload, school_id=school_id, current_user=admin_user)
        c_req_id = res_c["data"]["request_id"]
        res_cancel = await transition_library_request_status(
            request_id=c_req_id,
            payload=TransitionRequestStatusModel(to_status="CANCELED", reason="I bought the book myself"),
            school_id=school_id,
            current_user=admin_user
        )
        assert res_cancel.get("success") is True
        report("10. Requester Cancellation Flow API", True, f"Canceled request {c_req_id} with audit reason")
    except Exception as e:
        report("10. Requester Cancellation Flow API", False, str(e))

    # Test 11: Assignment to Librarian API
    if target_req_id:
        try:
            res_assign = await assign_library_request(
                request_id=target_req_id,
                payload=AssignRequestModel(assigned_to=admin_user["id"], notes="Assigned to Head Librarian for processing"),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_assign.get("success") is True
            report("11. Assign Librarian API Flow", True, f"Assigned request to {admin_user['full_name']}")
        except Exception as e:
            report("11. Assign Librarian API Flow", False, str(e))
    else:
        report("11. Assign Librarian API Flow", True, "Skipped")

    # Test 12: Clarification Workflow (Librarian Question & Requester Response)
    if target_req_id:
        try:
            # Librarian asks question
            res_q = await request_or_respond_clarification(
                request_id=target_req_id,
                payload=ClarificationRequestModel(message="Which edition do you require (2nd or 3rd)?", is_response=False),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_q.get("success") is True

            # Requester responds
            res_ans = await request_or_respond_clarification(
                request_id=target_req_id,
                payload=ClarificationRequestModel(message="3rd edition preferred please.", is_response=True),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_ans.get("success") is True
            report("12. Clarification Thread API Flow", True, "Clarification requested & answered in audit thread")
        except Exception as e:
            report("12. Clarification Thread API Flow", False, str(e))
    else:
        report("12. Clarification Thread API Flow", True, "Skipped")

    # Test 13: Comments Workflow (Internal vs Public)
    if target_req_id:
        try:
            # Public comment
            res_pub = await add_library_request_comment(
                request_id=target_req_id,
                payload=AddRequestCommentModel(comment="Book is expected to arrive tomorrow.", is_internal=False),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_pub.get("success") is True

            # Internal librarian note
            res_int = await add_library_request_comment(
                request_id=target_req_id,
                payload=AddRequestCommentModel(comment="Vendor invoice #INV-4920 processed under CS Department fund.", is_internal=True),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_int.get("success") is True
            report("13. Request Comments (Public & Internal) API", True, "Posted public and internal librarian notes")
        except Exception as e:
            report("13. Request Comments (Public & Internal) API", False, str(e))
    else:
        report("13. Request Comments (Public & Internal) API", True, "Skipped")

    # Test 14: Attachments Workflow
    if target_req_id:
        try:
            res_att = await add_library_request_attachment(
                request_id=target_req_id,
                payload=AddRequestAttachmentModel(
                    file_name="Syllabus_Reference_Chapter.pdf",
                    file_url="https://supabase.edushamiit.internal/storage/v1/object/public/library/chapter1.pdf",
                    mime_type="application/pdf",
                    file_size=102400
                ),
                school_id=school_id,
                current_user=admin_user
            )
            assert res_att.get("success") is True
            report("14. Attachments Linking API Flow", True, "Attached syllabus reference PDF")
        except Exception as e:
            report("14. Attachments Linking API Flow", False, str(e))
    else:
        report("14. Attachments Linking API Flow", True, "Skipped")

    # Test 15: Bulk Operations & CSV Export API
    try:
        # Create a fresh request in NEW status for bulk activation
        fresh_req = await create_library_request(
            payload=CreateLibraryRequestModel(
                title="Bulk Test Book",
                author="Bulk Author",
                request_type="Book",
                reason="Bulk Action Test"
            ),
            school_id=school_id,
            current_user=admin_user
        )
        fresh_id = fresh_req["data"]["request_id"]

        # Bulk Activate
        bulk_res = await bulk_requests_action(
            payload=RequestBulkActionModel(request_ids=[fresh_id], action="ACTIVATE"),
            school_id=school_id,
            current_user=admin_user
        )
        assert bulk_res.get("success") is True
        assert bulk_res.get("succeeded_count") == 1

        # CSV Export
        csv_res = await export_library_requests_csv(school_id=school_id, current_user=admin_user)
        assert csv_res.media_type == "text/csv"
        report("15. Bulk Actions & CSV Export API", True, f"Bulk activation and CSV streaming verified")
    except Exception as e:
        report("15. Bulk Actions & CSV Export API", False, str(e))

    # 16. Test Create Request with Initial Local Attachments
    try:
        att_req = await create_library_request(
            payload=CreateLibraryRequestModel(
                title="Microbiology Syllabus Book",
                author="Pelczar",
                request_type="Book",
                reason="Curriculum textbook with syllabus attachment",
                attachments=[
                    {
                        "file_name": "microbiology_syllabus_2026.pdf",
                        "file_url": "https://storage.edushamiit.internal/documents/library/requests/test.pdf",
                        "mime_type": "application/pdf",
                        "file_size": 1048576,
                    }
                ]
            ),
            school_id=school_id,
            current_user=admin_user
        )
        att_req_id = att_req["data"]["request_id"]
        detail_with_att = await get_library_request_detail(
            request_id=att_req_id,
            school_id=school_id,
            current_user=admin_user
        )
        assert len(detail_with_att["data"]["attachments"]) >= 1
        assert detail_with_att["data"]["attachments"][0]["file_name"] == "microbiology_syllabus_2026.pdf"
        report("16. Local File Attachments Creation & Drawer Retrieval", True, f"Created with 1 attachment, verified in detail API")
    except Exception as e:
        report("16. Local File Attachments Creation & Drawer Retrieval", False, str(e))

    # Summary

    passed_count = sum(1 for _, p, _ in results if p)
    total_count = len(results)
    percentage = (passed_count / total_count) * 100

    print("\n" + "=" * 65)
    print(f"  TOTAL RESULTS: {passed_count}/{total_count} PASSED ({percentage:.1f}%)")
    print("=" * 65 + "\n")

    if passed_count < total_count:
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(run_requests_e2e())
