import sys
import os
import uuid
import httpx

BASE_URL = "http://127.0.0.1:8000"
client = httpx.Client(base_url=BASE_URL, timeout=30.0)

def get_auth_token(role="student"):
    """Register and get an auth token for testing"""
    email = f"test_docs_{role}_{uuid.uuid4().hex[:6]}@example.com"
    data = {
        "email": email,
        "password": "Password123!",
        "full_name": f"Test {role.capitalize()} Docs",
        "role": role,
        "school_id": "11111111-1111-1111-1111-111111111111",
        "class_name": "10A" if role == "student" else None
    }
    
    # Register
    print(f"Registering test {role} user: {email}")
    res = client.post("/api/auth/register", json=data)
    if res.status_code != 200:
        print(f"Failed to register {role}: {res.text}")
        return None
        
    # Login
    print(f"Logging in {role} user...")
    res = client.post("/api/auth/login", json={"email": email, "password": "Password123!", "role": role})
    if res.status_code == 200:
        return res.json().get("data", {}).get("token")
    else:
        print(f"Failed to login {role}: {res.text}")
        return None

def run_tests():
    print("="*60)
    print("STARTING DOCUMENTS HUB INTEGRATION TESTS (WITH PDF AUTO-SAVE)")
    print("="*60)
    
    token = get_auth_token("student")
    if not token:
        print("Could not obtain auth token. Exiting.")
        sys.exit(1)
        
    headers = {
        "Authorization": f"Bearer {token}"
    }

    # ── Preparation: Create a dummy local generated PDF file on the server ──────
    assets_dir = os.path.join(os.getcwd(), "assets")
    os.makedirs(assets_dir, exist_ok=True)
    pdf_filename = "algebra_quiz.pdf"
    pdf_path = os.path.join(assets_dir, pdf_filename)
    dummy_pdf_data = b"%PDF-1.4 ... Test Generated PDF Content ... %EOF"
    with open(pdf_path, "wb") as f:
        f.write(dummy_pdf_data)
    print(f"Prepared test generated PDF at local path: {pdf_path}")

    # 1. Test GET /api/documents (List initially)
    print("\n1. Testing GET /api/documents (initial fetch)...")
    res = client.get("/api/documents", headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    body = res.json()
    assert body.get("success") is True
    documents = body.get("data", {}).get("documents", [])
    category_counts = body.get("data", {}).get("category_counts", {})
    print(f"Success! Found {len(documents)} documents.")
    print(f"Category counts: {category_counts}")

    # 2. Test POST /api/documents/save-ai (Save text-only AI Document)
    print("\n2. Testing POST /api/documents/save-ai (plain text fallback)...")
    ai_doc_data = {
        "title": "Quantum Mechanics Intro",
        "content": "# Quantum Mechanics\n\nQuantum mechanics is a fundamental theory in physics...",
        "description": "AI-generated study material on quantum mechanics.",
        "session_id": "test-ai-session-123"
    }
    res = client.post("/api/documents/save-ai", json=ai_doc_data, headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    body = res.json()
    assert body.get("success") is True
    saved_doc = body.get("data", {}).get("document", {})
    assert saved_doc.get("title") == "Quantum Mechanics Intro"
    assert saved_doc.get("category") == "ai_generated"
    assert saved_doc.get("file_url") is None
    ai_doc_id = saved_doc.get("id")
    print(f"Success! AI text document saved with ID: {ai_doc_id}")

    # 3. Test POST /api/documents/save-ai (Save AI Document with generated PDF detection)
    print("\n3. Testing POST /api/documents/save-ai (with PDF detection & Storage upload)...")
    ai_pdf_data = {
        "title": "Algebra Practice Quiz",
        "content": f"I have generated your document: [Download {pdf_filename}](/api/chat/download/{pdf_filename})",
        "description": "Auto-saved PDF quiz.",
        "session_id": "test-ai-session-123"
    }
    res = client.post("/api/documents/save-ai", json=ai_pdf_data, headers=headers)
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    body = res.json()
    assert body.get("success") is True
    saved_pdf_doc = body.get("data", {}).get("document", {})
    assert saved_pdf_doc.get("title") == "Algebra Practice Quiz"
    assert saved_pdf_doc.get("category") == "ai_generated"
    assert saved_pdf_doc.get("file_url") is not None
    assert saved_pdf_doc.get("file_name") == pdf_filename
    assert saved_pdf_doc.get("file_size") == len(dummy_pdf_data)
    assert saved_pdf_doc.get("mime_type") == "application/pdf"
    ai_pdf_doc_id = saved_pdf_doc.get("id")
    print(f"Success! Detected generated PDF, uploaded to Storage, and saved document ID: {ai_pdf_doc_id}")
    print(f"Supabase Public URL: {saved_pdf_doc.get('file_url')}")

    # 4. Test GET /api/documents/{id}/download (Download AI Text Document)
    print(f"\n4. Testing GET /api/documents/{ai_doc_id}/download (text streaming)...")
    res = client.get(f"/api/documents/{ai_doc_id}/download", headers=headers)
    assert res.status_code == 200
    assert "text/plain" in res.headers.get("Content-Type", "")
    assert "Quantum Mechanics" in res.text
    print("Success! AI document downloaded as text.")

    # 5. Test GET /api/documents/{id}/download (Download AI PDF Document via Redirect)
    print(f"\n5. Testing GET /api/documents/{ai_pdf_doc_id}/download (redirect to Storage)...")
    res = client.get(f"/api/documents/{ai_pdf_doc_id}/download", headers=headers, follow_redirects=False)
    assert res.status_code in (302, 307), f"Expected redirect, got {res.status_code}"
    print(f"Success! Redirected to storage URL: {res.headers.get('Location')}")

    # 6. Test POST /api/documents/upload (Manual Multipart File upload)
    print("\n6. Testing POST /api/documents/upload...")
    dummy_file_content = b"%PDF-1.4 ... Test PDF Content ... %EOF"
    upload_data = {
        "title": "My Algebra Notes",
        "description": "PDF notes for Algebra Chapter 1",
        "category": "my_uploads"
    }
    files = {
        "file": ("algebra_notes.pdf", dummy_file_content, "application/pdf")
    }
    res = client.post(
        "/api/documents/upload", 
        data=upload_data,
        files=files,
        headers=headers
    )
    assert res.status_code == 200, f"Expected 200, got {res.status_code}: {res.text}"
    body = res.json()
    assert body.get("success") is True
    uploaded_doc = body.get("data", {}).get("document", {})
    assert uploaded_doc.get("title") == "My Algebra Notes"
    assert uploaded_doc.get("file_name") == "algebra_notes.pdf"
    assert uploaded_doc.get("category") == "my_uploads"
    file_doc_id = uploaded_doc.get("id")
    print(f"Success! PDF File uploaded manually. ID: {file_doc_id}")

    # 7. Test GET /api/documents (Verify all documents returned)
    print("\n7. Testing GET /api/documents?category=ai_generated...")
    res = client.get("/api/documents?category=ai_generated", headers=headers)
    assert res.status_code == 200
    documents = res.json().get("data", {}).get("documents", [])
    assert any(doc.get("id") == ai_pdf_doc_id for doc in documents)
    print("Success! Uploaded/saved documents found in list.")

    # 8. Test DELETE /api/documents/{id} (Delete manual uploaded file)
    print(f"\n8. Testing DELETE /api/documents/{file_doc_id}...")
    res = client.delete(f"/api/documents/{file_doc_id}", headers=headers)
    assert res.status_code == 200
    print("Success! File document deleted.")

    # 9. Test DELETE /api/documents/{id} (Delete auto-saved PDF document)
    print(f"\n9. Testing DELETE /api/documents/{ai_pdf_doc_id}...")
    res = client.delete(f"/api/documents/{ai_pdf_doc_id}", headers=headers)
    assert res.status_code == 200
    print("Success! Auto-saved PDF document deleted.")

    # 10. Clean up AI text document
    print(f"\n10. Cleaning up AI text document {ai_doc_id}...")
    res = client.delete(f"/api/documents/{ai_doc_id}", headers=headers)
    assert res.status_code == 200
    print("Success! Cleaned up AI text document.")

    # Clean up local generated assets file
    try:
        os.remove(pdf_path)
    except Exception:
        pass

    print("\n" + "="*60)
    print("ALL API ENDPOINTS TESTED SUCCESSFULLY — 100% GREEN!")
    print("="*60)

if __name__ == "__main__":
    run_tests()
