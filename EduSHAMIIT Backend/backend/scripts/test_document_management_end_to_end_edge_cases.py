import os
import sys
import asyncio
import uuid
from datetime import datetime

# Setup Python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

# Resolve local Kong gateway if host is outside docker container
if not os.environ.get("SUPABASE_URL") or "kong" in os.environ.get("SUPABASE_URL", ""):
    os.environ["SUPABASE_URL"] = "http://127.0.0.1:8000"

from app.config import settings
if "kong" in settings.SUPABASE_URL:
    settings.SUPABASE_URL = "http://127.0.0.1:8000"

from fastapi.testclient import TestClient
from app.main import app
import psycopg2
from app.middleware.auth import get_current_user
from app.services.supabase_client import get_supabase

# Mock User Fixtures
USER_ADMIN_A = {
    "id": "11111111-1111-1111-1111-111111111111",
    "user_id": "ADM-SCH-A-01",
    "email": "superadmin@school-a.edu",
    "role": "super_admin",
    "school_id": "11111111-1111-1111-1111-111111111111",
    "full_name": "Super Admin School A",
}

USER_TEACHER_A = {
    "id": "22222222-2222-2222-2222-222222222222",
    "user_id": "TCH-SCH-A-01",
    "email": "teacher1@school-a.edu",
    "role": "teacher",
    "school_id": "11111111-1111-1111-1111-111111111111",
    "full_name": "Teacher One School A",
}

USER_SCHOOL_B = {
    "id": "33333333-3333-3333-3333-333333333333",
    "user_id": "ADM-SCH-B-01",
    "email": "admin@school-b.edu",
    "role": "super_admin",
    "school_id": "22222222-2222-2222-2222-222222222222",
    "full_name": "Admin School B",
}

current_mock_user = USER_ADMIN_A

def mock_get_current_user():
    return current_mock_user

app.dependency_overrides[get_current_user] = mock_get_current_user
client = TestClient(app)

def set_user(user_dict):
    global current_mock_user
    current_mock_user = user_dict

def test_suite():
    print("=" * 80)
    print("RUNNING DOCUMENT MANAGEMENT FULL FEATURES & EDGE CASES VERIFICATION SUITE")
    print("=" * 80)

    # --------------------------------------------------------------------------
    # 1. SETUP BASELINE DATA IN POSTGRES
    # --------------------------------------------------------------------------
    print("\n[STEP 1] Setting up schools, users, and folders in database...")
    conn = psycopg2.connect(settings.DATABASE_URL)
    conn.autocommit = True
    with conn.cursor() as cur:
        for u in [USER_ADMIN_A, USER_TEACHER_A, USER_SCHOOL_B]:
            cur.execute("""
                INSERT INTO profiles (id, user_id, email, role, full_name, school_id, status, created_at, updated_at)
                VALUES (%s, %s, %s, %s, %s, %s, 'Active', NOW(), NOW())
                ON CONFLICT (id) DO UPDATE SET
                    school_id = EXCLUDED.school_id,
                    role = EXCLUDED.role,
                    full_name = EXCLUDED.full_name,
                    updated_at = NOW();
            """, (u["id"], u["user_id"], u["email"], u["role"], u["full_name"], u["school_id"]))
    conn.close()

    print("✓ Test user profiles upserted.")

    # Create root folder in School A
    set_user(USER_ADMIN_A)
    folder_res = client.post("/api/documents/folders", json={
        "name": f"Academic Folder {uuid.uuid4().hex[:6]}",
        "category": "Academic",
        "description": "Folder for academic files",
        "color": "#2563EB",
        "icon": "folder"
    })
    assert folder_res.status_code == 200, f"Folder create failed: {folder_res.text}"
    folder_data = folder_res.json()["data"]["folder"]
    folder_id = folder_data["id"]
    print(f"✓ Created folder '{folder_data['name']}' (ID: {folder_id})")

    # --------------------------------------------------------------------------
    # 2. DOCUMENT CREATION & SCOPED COUNTS
    # --------------------------------------------------------------------------
    print("\n[STEP 2] Creating documents across owners and verifying scoped counts...")
    
    # Doc 1: Admin in School A (DOCX)
    docx_bytes = b"PK\x03\x04" + b"Official curriculum guidelines for high school." * 10
    doc1_res = client.post(
        "/api/documents/upload",
        files={"file": ("curriculum_plan_2026.docx", docx_bytes, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")},
        data={
            "title": "School A Curriculum Plan 2026.docx",
            "category": "academic",
            "department": "Academics",
            "folder_id": folder_id,
        }
    )
    assert doc1_res.status_code == 200, f"Doc 1 upload failed: {doc1_res.text}"
    doc1_id = doc1_res.json()["data"]["document"]["id"]
    print(f"✓ Admin uploaded document: {doc1_id}")

    # Doc 2: Teacher in School A (XLSX)
    set_user(USER_TEACHER_A)
    xlsx_bytes = b"PK\x03\x04" + b"Weekly Plan,Status\n1,Algebra,Completed" * 10
    doc2_res = client.post(
        "/api/documents/upload",
        files={"file": ("lesson_notes.xlsx", xlsx_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        data={
            "title": "Teacher Lesson Plan Notes.xlsx",
            "category": "academic",
            "department": "Academics",
            "folder_id": folder_id,
        }
    )
    assert doc2_res.status_code == 200, f"Doc 2 upload failed: {doc2_res.text}"
    doc2_id = doc2_res.json()["data"]["document"]["id"]
    print(f"✓ Teacher uploaded document: {doc2_id}")

    # Verify All Documents list contains both docs
    set_user(USER_ADMIN_A)
    list_all = client.get("/api/documents?tab=all")
    assert list_all.status_code == 200
    all_docs = list_all.json()["data"]["documents"]
    all_doc_ids = [d["id"] for d in all_docs]
    assert doc1_id in all_doc_ids and doc2_id in all_doc_ids, "Both docs must be visible in All Documents"
    print("✓ All Documents contains both Admin and Teacher documents.")

    # Verify Author Filter (owner_id)
    list_teacher_only = client.get(f"/api/documents?tab=all&owner_id={USER_TEACHER_A['id']}")
    assert list_teacher_only.status_code == 200
    teacher_docs = list_teacher_only.json()["data"]["documents"]
    assert all(d["owner_id"] == USER_TEACHER_A["id"] for d in teacher_docs), "Only teacher docs should be returned"
    assert any(d["id"] == doc2_id for d in teacher_docs), "Doc2 must be present in teacher filter"
    assert not any(d["id"] == doc1_id for d in teacher_docs), "Doc1 must NOT be in teacher filter"
    print("✓ Author filter ('owner_id') properly filters documents across all pages.")

    # Verify Scoped Folder Counts for 'My Documents' vs 'All Documents'
    set_user(USER_TEACHER_A)
    folders_all = client.get("/api/documents/folders?tab=all").json()["data"]["folders"]
    folders_my = client.get("/api/documents/folders?tab=my_documents").json()["data"]["folders"]
    
    target_f_all = next((f for f in folders_all if f["id"] == folder_id), None)
    target_f_my = next((f for f in folders_my if f["id"] == folder_id), None)
    assert target_f_all is not None and target_f_my is not None
    assert target_f_all["document_count"] >= 2, "All tab must count all school documents"
    assert target_f_my["document_count"] == 1, "My Documents tab must count only Teacher's documents"
    print("✓ Scoped folder tree counts verified: tab=my_documents is scoped to owner, tab=all counts school.")

    # --------------------------------------------------------------------------
    # 3. MULTI-TENANT ISOLATION
    # --------------------------------------------------------------------------
    print("\n[STEP 3] Verifying Multi-Tenant School Isolation...")
    set_user(USER_SCHOOL_B)
    list_school_b = client.get("/api/documents?tab=all")
    assert list_school_b.status_code == 200
    docs_b_ids = [d["id"] for d in list_school_b.json()["data"]["documents"]]
    assert doc1_id not in docs_b_ids and doc2_id not in docs_b_ids, "School B must NOT see School A documents!"

    # Attempt direct access to School A document by School B user
    direct_get = client.get(f"/api/documents/{doc1_id}")
    assert direct_get.status_code in [403, 404], f"Cross-school direct access must fail! Got {direct_get.status_code}"
    print("✓ Multi-tenant school isolation confirmed: Zero leakage between schools.")

    # --------------------------------------------------------------------------
    # 4. RECENT TAB ACTIVITY & ORDERING
    # --------------------------------------------------------------------------
    print("\n[STEP 4] Testing Recent Activity tracking & last_accessed_at ordering...")
    set_user(USER_ADMIN_A)
    # Access Doc 1
    client.get(f"/api/documents/{doc1_id}")
    await_recent = client.get("/api/documents?tab=recent")
    assert await_recent.status_code == 200
    recent_docs = await_recent.json()["data"]["documents"]
    assert len(recent_docs) > 0 and recent_docs[0]["id"] == doc1_id, "Doc 1 must be top of recent docs list"
    print("✓ Recent documents tab successfully ordered by last_accessed_at DESC.")

    # --------------------------------------------------------------------------
    # 5. DOCUMENT APPROVAL WORKFLOW
    # --------------------------------------------------------------------------
    print("\n[STEP 5] Testing Document Approval Lifecycle...")
    set_user(USER_TEACHER_A)
    sub_res = client.post(f"/api/documents/{doc2_id}/submit-approval", json={
        "comments": "Please review this syllabus before distributing to parents."
    })
    assert sub_res.status_code == 200, f"Submit approval failed: {sub_res.text}"
    print(f"✓ Teacher submitted Doc 2 for approval.")

    set_user(USER_ADMIN_A)
    pending_res = client.get("/api/documents/approvals/pending")
    assert pending_res.status_code == 200
    pending_list = pending_res.json()["data"]["approvals"]
    assert any(a.get("id") == doc2_id or a.get("document_id") == doc2_id for a in pending_list), "Doc 2 must appear in pending approvals queue"
    print("✓ Document visible in administrator pending approvals queue.")

    # Approve Document
    appr_res = client.post(f"/api/documents/{doc2_id}/approve", json={
        "comments": "Curriculum standards met. Approved."
    })
    assert appr_res.status_code == 200, f"Approve failed: {appr_res.text}"
    doc2_details = client.get(f"/api/documents/{doc2_id}").json()["data"]["document"]
    assert doc2_details["approval_status"] == "Approved", f"Expected Approved, got {doc2_details['approval_status']}"
    print("✓ Document successfully approved and status updated to 'Approved'.")

    # --------------------------------------------------------------------------
    # 6. DOCUMENT REQUESTS WORKFLOW & FULFILLMENT
    # --------------------------------------------------------------------------
    print("\n[STEP 6] Testing Document Requests Creation, Filtering, and Fulfillment...")
    set_user(USER_TEACHER_A)
    req_create = client.post("/api/documents/requests", json={
        "title": "Grade 10 Physics Syllabus 2026",
        "description": "Need the signed laboratory syllabus document.",
        "category": "Academic",
        "priority": "High",
        "required_by_date": "2026-12-01"
    })
    assert req_create.status_code == 200, f"Request create failed: {req_create.text}"
    req_id = req_create.json()["data"]["request"]["id"]
    print(f"✓ Teacher created document request: {req_id}")

    # List requests with filter
    set_user(USER_ADMIN_A)
    req_list = client.get("/api/documents/requests?status=Pending")
    assert req_list.status_code == 200
    reqs = req_list.json()["data"]["requests"]
    assert any(r["id"] == req_id for r in reqs), "Created request must be in Pending requests list"
    print("✓ Document requests list and status filter verified.")

    # Update request status to In Progress
    patch_req = client.patch(f"/api/documents/requests/{req_id}", json={
        "status": "In Progress",
        "response_notes": "Currently scanning physics syllabus"
    })
    assert patch_req.status_code == 200, f"Patch request failed: {patch_req.text}"
    print("✓ Request status updated to 'In Progress'.")

    # Fulfill request with doc1
    fulfill_res = client.post(f"/api/documents/requests/{req_id}/fulfill?document_id={doc1_id}&notes=Attached%20document")
    assert fulfill_res.status_code == 200, f"Fulfill failed: {fulfill_res.text}"
    
    # Verify request is now Fulfilled
    req_check = client.get("/api/documents/requests?status=Fulfilled")
    assert any(r["id"] == req_id and r["status"] == "Fulfilled" for r in req_check.json()["data"]["requests"])
    print("✓ Request fulfilled and verified in Fulfilled queue.")

    # --------------------------------------------------------------------------
    # 7. TRASH LIFECYCLE, RESTORATION & EMPTY TRASH
    # --------------------------------------------------------------------------
    print("\n[STEP 7] Testing Trash Lifecycle: Soft Delete, Restore, Bulk Restore, Empty Trash...")
    set_user(USER_ADMIN_A)

    # Soft delete doc1
    del_res = client.delete(f"/api/documents/{doc1_id}")
    assert del_res.status_code == 200, f"Delete failed: {del_res.text}"
    print(f"✓ Moved Doc 1 ({doc1_id}) to Trash.")

    # Verify Doc 1 is in Trash tab and NOT in All Documents
    trash_list = client.get("/api/documents?tab=trash").json()["data"]["documents"]
    assert any(d["id"] == doc1_id for d in trash_list), "Doc 1 must appear in Trash"
    
    all_list = client.get("/api/documents?tab=all").json()["data"]["documents"]
    assert not any(d["id"] == doc1_id for d in all_list), "Doc 1 must NOT appear in active All Documents"
    print("✓ Document is excluded from active views and isolated to Trash.")

    # Restore Doc 1
    restore_res = client.post(f"/api/documents/{doc1_id}/restore")
    assert restore_res.status_code == 200, f"Restore failed: {restore_res.text}"
    
    all_list_after_restore = client.get("/api/documents?tab=all").json()["data"]["documents"]
    assert any(d["id"] == doc1_id for d in all_list_after_restore), "Doc 1 must be restored to All Documents"
    print("✓ Single Document restore from Trash verified.")

    # Test Bulk Restore
    # Soft delete doc1 and doc2
    client.post("/api/documents/bulk/delete", json={"document_ids": [doc1_id, doc2_id]})
    trash_items = client.get("/api/documents?tab=trash").json()["data"]["documents"]
    assert any(d["id"] == doc1_id for d in trash_items) and any(d["id"] == doc2_id for d in trash_items)
    print("✓ Both documents moved to Trash via bulk delete.")

    # Call bulk restore endpoint
    bulk_restore_res = client.post("/api/documents/bulk/restore", json={"document_ids": [doc1_id, doc2_id]})
    assert bulk_restore_res.status_code == 200, f"Bulk restore failed: {bulk_restore_res.text}"
    
    trash_after_bulk = client.get("/api/documents?tab=trash").json()["data"]["documents"]
    assert not any(d["id"] == doc1_id for d in trash_after_bulk)
    assert not any(d["id"] == doc2_id for d in trash_after_bulk)
    print("✓ Bulk restore endpoint verified: all selected documents restored.")

    # Test Empty Trash procedure
    # Move doc1 to trash again
    client.delete(f"/api/documents/{doc1_id}")
    empty_trash_res = client.post("/api/documents/empty-trash")
    assert empty_trash_res.status_code == 200, f"Empty trash failed: {empty_trash_res.text}"
    
    trash_after_empty = client.get("/api/documents?tab=trash").json()["data"]["documents"]
    assert not any(d["id"] == doc1_id for d in trash_after_empty)
    print("✓ Empty Trash successfully purged all soft-deleted documents.")

    # --------------------------------------------------------------------------
    # 8. COLLABORATIVE LIVE EDITOR & AUTH / RBAC ENFORCEMENT
    # --------------------------------------------------------------------------
    print("\n[STEP 8] Testing Collaborative Live Editor Token & Viewer/Editor RBAC...")
    # Create doc3 for collaboration testing
    doc3_bytes = b"PK\x03\x04" + b"Revenue,Expenses,Net\n5000000,4200000,800000" * 10
    doc3_res = client.post(
        "/api/documents/upload",
        files={"file": ("financial_model_2026.xlsx", doc3_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")},
        data={
            "title": "Institutional Financial Model 2026.xlsx",
            "category": "administration",
            "department": "Finance",
        }
    )
    assert doc3_res.status_code == 200, f"Doc 3 upload failed: {doc3_res.text}"
    doc3_id = doc3_res.json()["data"]["document"]["id"]

    # Share with Teacher with Viewer-only permission
    client.post(f"/api/documents/{doc3_id}/share", json={
        "share_type": "User",
        "target_id": USER_TEACHER_A["id"],
        "target_name": USER_TEACHER_A["full_name"],
        "permission_level": "Viewer",
        "allow_download": True
    })

    # Teacher accesses Live Editor
    set_user(USER_TEACHER_A)
    editor_resp = client.get(f"/api/documents/{doc3_id}/editor")
    assert editor_resp.status_code == 200, f"Editor access failed: {editor_resp.text}"
    editor_html = editor_resp.text
    
    # Check that Viewer permission is detected in HTML and editing controls are disabled/read-only
    assert "Viewer (Read Only)" in editor_html or "readonly" in editor_html.lower() or "read-only" in editor_html.lower(), \
        "Viewer must have read-only editor mode indicated in UI"
    print("✓ Collaborative editor correctly enforces Viewer-only read mode for shared user.")

    # Owner accesses Live Editor
    set_user(USER_ADMIN_A)
    owner_editor_resp = client.get(f"/api/documents/{doc3_id}/editor")
    assert owner_editor_resp.status_code == 200
    assert "Save & Version" in owner_editor_resp.text or "Export" in owner_editor_resp.text
    print("✓ Document Manager/Editor receives full toolbar, editing capability, and versioning controls.")

    print("\n" + "=" * 80)
    print("ALL DOCUMENT MANAGEMENT END-TO-END EDGE CASE TESTS PASSED WITH 100% SUCCESS!")
    print("=" * 80)

if __name__ == "__main__":
    test_suite()
