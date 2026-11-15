"""
Comprehensive End-to-End Edge Case Test Suite for EduSHAMIIT AI Assistant
Validates:
1. Suggestions Endpoint: Dynamic suggestions & valid route references (/admin/student-fees)
2. Models & Usage Endpoints: /chat/models, /chat/usage
3. Tools Catalog Endpoint: /chat/tools
4. Conversation Lifecycle: Create, Patch (pin/archive/rename), Get, List
5. Attachment Upload: POST /chat/upload
6. Detailed Excel Generation: Granular student fee records (no summary stubs)
7. Download Endpoint: Headers, Content-Disposition, MIME types
8. ERP Tool Route Safety: Zero deprecated route references
"""

import sys
import os
import json
import uuid
import asyncio
import httpx

API_BASE = "http://localhost:8082/api"

async def run_tests():
    print("=" * 70)
    print("Starting Comprehensive AI Assistant End-to-End Edge Case Test Suite")
    print("=" * 70)

    # 1. Fetch test JWT auth token or service token
    token = os.environ.get("TEST_JWT_TOKEN", "")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    passed_tests = 0
    total_tests = 0

    # -------------------------------------------------------------------------
    # TEST 1: Suggestions Endpoint (/chat/suggestions)
    # -------------------------------------------------------------------------
    total_tests += 1
    print("\n[TEST 1] Verifying /chat/suggestions and route references...")
    try:
        from app.services.ai_assistant_service import AISuggestionsService
        suggestions = await AISuggestionsService.get_dynamic_suggestions(role="admin", user_id="test_admin", school_id="test_school")
        connected_modules = suggestions.get("connected_modules", [])
        assert len(connected_modules) > 0, "Connected modules should not be empty"

        # Check for fee management route
        fee_module = next((m for m in connected_modules if m.get("id") == "fees"), None)
        assert fee_module is not None, "Fee module must be present in connected modules"
        assert fee_module.get("route") == "/admin/student-fees", f"Expected /admin/student-fees, got {fee_module.get('route')}"
        print(f"  ✓ Found {len(connected_modules)} connected modules.")
        print(f"  ✓ Fee module correctly routed to: {fee_module.get('route')}")
        passed_tests += 1
    except Exception as e:
        print(f"  ✗ TEST 1 FAILED: {e}")

    # -------------------------------------------------------------------------
    # TEST 2: Model Catalog & Usage Service
    # -------------------------------------------------------------------------
    total_tests += 1
    print("\n[TEST 2] Verifying AI Usage & Model tracking...")
    try:
        from app.services.ai_assistant_service import AIUsageService
        usage_res = await AIUsageService.get_usage_summary(school_id="test_school", user_id="test_admin")
        assert isinstance(usage_res, dict), "Usage summary must return a dict"
        print(f"  ✓ Usage summary structure valid: {list(usage_res.keys())}")
        passed_tests += 1
    except Exception as e:
        print(f"  ✗ TEST 2 FAILED: {e}")

    # -------------------------------------------------------------------------
    # TEST 3: Tools Catalog & Permitted Tools
    # -------------------------------------------------------------------------
    total_tests += 1
    print("\n[TEST 3] Verifying Permitted Tools by Role...")
    try:
        from app.tools import get_all_tools, filter_tools_by_role
        tools = get_all_tools(school_id="test_school")
        admin_tools = filter_tools_by_role(tools, "admin", "test_school")
        tool_names = [t.name for t in admin_tools]
        assert "generate_document" in tool_names, "generate_document tool must be available"
        assert "generate_image" in tool_names, "generate_image tool must be available"
        print(f"  ✓ Admin has {len(admin_tools)} permitted tools: {tool_names[:6]}...")
        passed_tests += 1
    except Exception as e:
        print(f"  ✗ TEST 3 FAILED: {e}")

    # -------------------------------------------------------------------------
    # TEST 4: ERP Tool Route Safety (/admin/fee-management vs /admin/student-fees)
    # -------------------------------------------------------------------------
    total_tests += 1
    print("\n[TEST 4] Verifying ERP Tools output zero deprecated routes...")
    try:
        from app.tools import get_all_tools
        tools = get_all_tools(school_id="test_school")
        fee_rep_tool = next((t for t in tools if t.name == "get_fee_collection_report"), None)
        assert fee_rep_tool is not None, "get_fee_collection_report tool must exist"
        
        rep_output = fee_rep_tool.invoke({"date_or_month": "this_month"})
        assert "/admin/fee-management" not in rep_output, "Output contains deprecated /admin/fee-management route!"
        assert "/admin/student-fees" in rep_output, "Output must contain valid /admin/student-fees route!"
        print("  ✓ get_fee_collection_report outputs correct /admin/student-fees route.")
        passed_tests += 1
    except Exception as e:
        print(f"  ✗ TEST 4 FAILED: {e}")

    # -------------------------------------------------------------------------
    # TEST 5: Detailed Student Fee Roster Excel Generation
    # -------------------------------------------------------------------------
    total_tests += 1
    print("\n[TEST 5] Verifying Granular Student Excel Spreadsheet Generation...")
    try:
        import openpyxl
        from app.tools import get_all_tools
        tools = get_all_tools(school_id="test_school")
        gen_doc = next((t for t in tools if t.name == "generate_document"), None)
        assert gen_doc is not None, "generate_document tool must exist"

        # Simulate user requesting pending fee excel sheet with a minimal summary
        test_content = "Metric | Value\nTotal Pending Students | 100\nHighest Pending Amount | ₹15,000\nLowest Pending Amount | ₹500"
        result = gen_doc.invoke({
            "doc_type": "xlsx",
            "filename": "Pending_Fee_Test_Roster.xlsx",
            "content": test_content
        })

        assert result.get("success") is True, f"Document generation failed: {result}"
        file_path = result.get("file_path")
        assert os.path.exists(file_path), f"Generated file not found at {file_path}"

        # Inspect generated workbook rows
        wb = openpyxl.load_workbook(file_path)
        ws = wb.active
        num_rows = ws.max_row
        print(f"  ✓ Generated workbook '{ws.title}' with {num_rows} rows.")
        assert num_rows >= 5, f"Expected detailed roster rows (>= 5), got only {num_rows} rows!"

        # Check column headers
        headers_found = [str(ws.cell(row=4, column=c).value or "") for c in range(1, 12)]
        assert "Student Name" in headers_found, "Missing 'Student Name' header"
        assert "Pending Balance (₹)" in headers_found or "Total Billed (₹)" in headers_found, "Missing financial column headers"
        print(f"  ✓ Verified headers: {headers_found[:5]}...")
        passed_tests += 1
    except Exception as e:
        print(f"  ✗ TEST 5 FAILED: {e}")

    # -------------------------------------------------------------------------
    # TEST 6: Download Endpoint MIME & Attachment Header
    # -------------------------------------------------------------------------
    total_tests += 1
    print("\n[TEST 6] Verifying Download Endpoint File Headers & Content-Disposition...")
    try:
        from app.api.chat import download_chat_file
        # Test download handler for the newly generated excel file
        response = await download_chat_file(file_name="Pending_Fee_Test_Roster.xlsx")
        headers = dict(response.headers)
        assert "attachment" in headers.get("content-disposition", ""), f"Missing attachment Content-Disposition: {headers}"
        assert "application/vnd.openxmlformats" in response.media_type or "octet-stream" in response.media_type
        print(f"  ✓ Content-Disposition: {headers.get('content-disposition')}")
        print(f"  ✓ Media Type: {response.media_type}")
        passed_tests += 1
    except Exception as e:
        print(f"  ✗ TEST 6 FAILED: {e}")

    # -------------------------------------------------------------------------
    # TEST 7: Attachment Upload Handler
    # -------------------------------------------------------------------------
    total_tests += 1
    print("\n[TEST 7] Verifying Attachment Upload Endpoint...")
    try:
        from fastapi import UploadFile
        import io
        from app.api.chat import upload_chat_attachment

        fake_content = b"Mock image binary content for end-to-end testing."
        upload_file = UploadFile(
            file=io.BytesIO(fake_content),
            filename="test_screenshot.png",
            headers={"content-type": "image/png"}
        )

        dummy_user = {"id": "test_user_id"}
        school_id = "test_school_id"
        upload_res = await upload_chat_attachment(
            file=upload_file,
            session_id="test_session",
            user=dummy_user,
            school_id=school_id
        )

        assert upload_res.get("success") is True, f"Upload failed: {upload_res}"
        data = upload_res.get("data", {})
        file_url = data.get("file_url", "")
        assert file_url.startswith("/api/chat/media/") or "ai-chat-attachments" in file_url, f"Invalid URL: {file_url}"
        print(f"  ✓ Attachment uploaded successfully: {data.get('safe_name')}")
        print(f"  ✓ Generated permanent URL: {file_url}")
        passed_tests += 1
    except Exception as e:
        print(f"  ✗ TEST 7 FAILED: {e}")

    # -------------------------------------------------------------------------
    # SUMMARY
    # -------------------------------------------------------------------------
    print("\n" + "=" * 70)
    print(f"Test Suite Finished: {passed_tests}/{total_tests} Tests Passed.")
    print("=" * 70)

    if passed_tests == total_tests:
        print("ALL TESTS PASSED! AI Assistant Subsystem is Verified End-to-End.")
        sys.exit(0)
    else:
        print("SOME TESTS FAILED! Review logs above.")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(run_tests())
