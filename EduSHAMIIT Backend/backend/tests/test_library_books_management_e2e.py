import requests
from jose import jwt
import json
import uuid
import sys

BASE_URL = "http://localhost:8000/api/library"
JWT_SECRET = "super-secret-jwt-token-with-at-least-32-characters-long"

SCHOOL_A = "11111111-1111-1111-1111-111111111111"
USER_A = "38a93170-997b-4b4c-bc8e-256b93169c23"

SCHOOL_B = "22222222-2222-2222-2222-222222222222"
USER_B = str(uuid.uuid4())

def get_auth_headers(school_id, user_id, role="super_admin"):
    token = jwt.encode({
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": f"{role}@{school_id[:8]}.com",
        "exp": 9999999999
    }, JWT_SECRET, algorithm="HS256")
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

def run_tests():
    headers_a = get_auth_headers(SCHOOL_A, USER_A)
    headers_b = get_auth_headers(SCHOOL_B, USER_B)
    
    print("==================================================================")
    print("      EduSHAMIIT LIBRARY BOOKS MANAGEMENT - E2E TEST SUITE        ")
    print("==================================================================")

    passed_tests = 0
    total_tests = 0

    def test(name, condition, details=""):
        nonlocal passed_tests, total_tests
        total_tests += 1
        if condition:
            passed_tests += 1
            print(f"[PASS] Scenario {total_tests:02d}: {name}")
        else:
            print(f"[FAIL] Scenario {total_tests:02d}: {name} -> {details}")

    # 1. Book Statistics
    r1 = requests.get(f"{BASE_URL}/books/stats", headers=headers_a)
    test("Aggregated KPI Stats (Total, Available, Issued, Overdue)",
         r1.status_code == 200 and r1.json().get("data", {}).get("total_titles", 0) > 0,
         r1.text)

    # 2. Dynamic Filter Options
    r2 = requests.get(f"{BASE_URL}/books/filter-options", headers=headers_a)
    categories = r2.json().get("data", {}).get("categories", [])
    authors = r2.json().get("data", {}).get("authors", [])
    test("Dynamic Filter Options populated from Lookups & Catalogue",
         r2.status_code == 200 and len(categories) > 0 and len(authors) > 0,
         r2.text)

    # 3. Paginated Books Listing
    r3 = requests.get(f"{BASE_URL}/books?page=1&page_size=10", headers=headers_a)
    books_page = r3.json().get("data", [])
    pagination = r3.json().get("pagination", {})
    test("Paginated Books Listing with Server-Side Meta",
         r3.status_code == 200 and len(books_page) > 0 and pagination.get("total_records", 0) > 0,
         r3.text)

    # 4. Search Query Matching (Search by Title)
    r4 = requests.get(f"{BASE_URL}/books?search=Psychology", headers=headers_a)
    results4 = r4.json().get("data", [])
    test("Search Query Matching by Title ('Psychology')",
         r4.status_code == 200 and len(results4) > 0 and "Psychology" in results4[0]["title"],
         r4.text)

    # 5. Search Query Matching by Author
    r5 = requests.get(f"{BASE_URL}/books?search=James Clear", headers=headers_a)
    results5 = r5.json().get("data", [])
    test("Search Query Matching by Author ('James Clear')",
         r5.status_code == 200 and len(results5) > 0 and results5[0]["author"] == "James Clear",
         r5.text)

    # 6. Multi-Faceted Category Filter
    r6 = requests.get(f"{BASE_URL}/books?category=Finance", headers=headers_a)
    results6 = r6.json().get("data", [])
    test("Category Filtering ('Finance')",
         r6.status_code == 200 and all(b["category_name"] == "Finance" for b in results6),
         r6.text)

    # 7. Availability Filtering (AVAILABLE)
    r7 = requests.get(f"{BASE_URL}/books?availability=AVAILABLE", headers=headers_a)
    results7 = r7.json().get("data", [])
    test("Availability Filtering ('AVAILABLE')",
         r7.status_code == 200 and all(b["available_copies"] > 0 for b in results7),
         r7.text)

    # 8. Live ISBN Check - Existing ISBN
    r8 = requests.post(f"{BASE_URL}/books/check-isbn", headers=headers_a, json={"isbn13": "978-9390166268"})
    test("Live ISBN Conflict Detection (Found Existing)",
         r8.status_code == 200 and r8.json().get("exists") is True,
         r8.text)

    # 9. Live ISBN Check - New Unique ISBN
    unique_isbn = f"978-999{uuid.uuid4().hex[:7]}"
    unique_isbn10 = f"99{uuid.uuid4().hex[:8]}"
    r9 = requests.post(f"{BASE_URL}/books/check-isbn", headers=headers_a, json={"isbn13": unique_isbn})
    test("Live ISBN Check (Available / New ISBN)",
         r9.status_code == 200 and r9.json().get("exists") is False,
         r9.text)

    # 10. Create New Book Title + Initial Physical Copies
    new_book_payload = {
        "title": f"Quantum Computing Essentials {uuid.uuid4().hex[:4]}",
        "subtitle": "From Qubits to Quantum Algorithms",
        "author": "Dr. Shami Nathan",
        "isbn13": unique_isbn,
        "isbn10": unique_isbn10,
        "category_name": "Computer Science",
        "publisher": "MIT Press",
        "language_name": "English",
        "book_type_name": "Hardcover",
        "publication_year": 2026,
        "pages": 480,
        "description": "Comprehensive textbook covering quantum gates, Shor's algorithm, and quantum error correction.",
        "rack_location": "Rack Q",
        "shelf_location": "Shelf 1",
        "initial_copies_count": 3,
        "purchase_price": 799.00,
        "supplier": "Academic Books India"
    }
    r10 = requests.post(f"{BASE_URL}/books", headers=headers_a, json=new_book_payload)
    print("DEBUG r10 status:", r10.status_code, "text:", r10.text)
    created_book_id = r10.json().get("data", {}).get("id")
    test("Create Book Title + Initial Copies with Auto Accession Numbers",
         r10.status_code == 200 and created_book_id is not None and r10.json().get("data", {}).get("total_copies") == 3,
         r10.text)

    # 11. Multi-Tenant School Isolation (School B cannot see School A's new book)
    r11 = requests.get(f"{BASE_URL}/books/{created_book_id}", headers=headers_b)
    test("Strict Multi-Tenant Security Isolation (Cross-School Access Rejected with 404)",
         r11.status_code == 404,
         r11.text)

    # 12. Fetch Book Details & Physical Copies List
    r12 = requests.get(f"{BASE_URL}/books/{created_book_id}", headers=headers_a)
    book_details = r12.json().get("data", {}).get("book", {})
    copies_list = r12.json().get("data", {}).get("copies", [])
    test("Fetch Book Details & Physical Copies List",
         r12.status_code == 200 and len(copies_list) == 3 and "Quantum Computing Essentials" in book_details.get("title", ""),
         r12.text)

    # 13. Add Batch Physical Copies to Existing Book
    add_copies_payload = {
        "number_of_copies": 2,
        "condition": "NEW",
        "rack": "Rack Q",
        "shelf": "Shelf 2",
        "purchase_price": 799.00,
        "supplier": "Academic Books India",
        "notes": "Supplementary lab copies"
    }
    r13 = requests.post(f"{BASE_URL}/books/{created_book_id}/copies", headers=headers_a, json=add_copies_payload)
    test("Add Batch Physical Copies with Auto-Incremented Accession Codes",
         r13.status_code == 200 and len(r13.json().get("data", [])) == 2,
         r13.text)

    # 14. Trigger-Based Synchronization Check (Total Copies should now be 5)
    r14 = requests.get(f"{BASE_URL}/books/{created_book_id}", headers=headers_a)
    print("DEBUG r14 status:", r14.status_code, "text:", r14.text)
    data_14 = r14.json().get("data") or {}
    updated_book = data_14.get("book") or {}
    all_copies = data_14.get("copies") or []
    test("Database Trigger Synchronization (Total Copies = 5, Available = 5)",
         updated_book.get("total_copies") == 5 and updated_book.get("available_copies") == 5 and len(all_copies) == 5,
         f"status={r14.status_code}, total={updated_book.get('total_copies')}, available={updated_book.get('available_copies')}")

    # 15. Update Copy Condition, Status & Location
    first_copy_id = all_copies[0]["id"]
    r15 = requests.patch(f"{BASE_URL}/book-copies/{first_copy_id}", headers=headers_a, json={
        "condition": "FAIR",
        "rack": "Rack Q-Reserved",
        "notes": "Moved to reserve desk"
    })
    test("Update Physical Copy Attributes (Condition & Location)",
         r15.status_code == 200 and r15.json().get("data", {}).get("condition") == "FAIR",
         r15.text)

    # 16. Archive Physical Copy (Copies decrease to 4)
    r16 = requests.delete(f"{BASE_URL}/book-copies/{first_copy_id}", headers=headers_a)
    r16_check = requests.get(f"{BASE_URL}/books/{created_book_id}", headers=headers_a)
    test("Archive Physical Copy (Trigger Auto-Updates Total Copies to 4)",
         r16.status_code == 200 and r16_check.json().get("data", {}).get("book", {}).get("total_copies") == 4,
         r16.text)

    # 17. Barcode & QR Code Scan Resolution API
    sample_barcode = all_copies[1]["barcode"]
    r17 = requests.get(f"{BASE_URL}/lookup-scan?code={sample_barcode}", headers=headers_a)
    test("Barcode/QR Code Instant Scan Lookup",
         r17.status_code == 200 and r17.json().get("data", {}).get("barcode") == sample_barcode,
         r17.text)

    # 18. Barcode SVG Generation
    r18 = requests.get(f"{BASE_URL}/barcode/{sample_barcode}", headers=headers_a)
    test("Vector Code128 Barcode SVG Generation",
         r18.status_code == 200 and "<svg" in r18.text and "rect" in r18.text,
         r18.status_code)

    # 19. QR Code SVG Generation
    r19 = requests.get(f"{BASE_URL}/qr/{sample_barcode}", headers=headers_a)
    test("Vector QR Code SVG Generation",
         r19.status_code == 200 and "<svg" in r19.text,
         r19.status_code)

    # 20. Update Book Metadata
    r20 = requests.patch(f"{BASE_URL}/books/{created_book_id}", headers=headers_a, json={
        "subtitle": "2nd Edition with Quantum Machine Learning",
        "edition": "2nd Edition"
    })
    test("Update Book Catalogue Record",
         r20.status_code == 200 and r20.json().get("data", {}).get("edition") == "2nd Edition",
         r20.text)

    # 21. Bulk Operations (Change Category in Bulk)
    r21 = requests.post(f"{BASE_URL}/books/bulk", headers=headers_a, json={
        "book_ids": [created_book_id],
        "action": "CHANGE_CATEGORY",
        "category_name": "Science"
    })
    test("Bulk Operations (Bulk Category Update)",
         r21.status_code == 200 and r21.json().get("data", {}).get("modified_count") == 1,
         r21.text)

    # 22. Transactional Batch Import with Preview & Validation
    import_rows = [
        {"Title": f"Imported Book {uuid.uuid4().hex[:4]}", "Author": "Author One", "Category": "Fiction", "ISBN": f"978-{uuid.uuid4().hex[:10]}", "Copies": 2},
        {"Title": f"Imported Book {uuid.uuid4().hex[:4]}", "Author": "Author Two", "Category": "Finance", "ISBN": f"978-{uuid.uuid4().hex[:10]}", "Copies": 3}
    ]
    r22_prev = requests.post(f"{BASE_URL}/books/import", headers=headers_a, json={"rows": import_rows, "mode": "PREVIEW"})
    r22_comm = requests.post(f"{BASE_URL}/books/import", headers=headers_a, json={"rows": import_rows, "mode": "COMMIT"})
    test("Transactional CSV/Excel Batch Import with Validation Report",
         r22_prev.status_code == 200 and r22_comm.status_code == 200 and r22_comm.json().get("summary", {}).get("imported_count") == 2,
         f"prev={r22_prev.text}, comm={r22_comm.text}")

    # 23. CSV Export
    r23 = requests.get(f"{BASE_URL}/books/export?format=csv", headers=headers_a)
    test("Real-time Dynamic CSV Export",
         r23.status_code == 200 and "Title,Subtitle,Author,Publisher,Category" in r23.text,
         r23.status_code)

    # 24. Archive Book Record
    r24 = requests.delete(f"{BASE_URL}/books/{created_book_id}", headers=headers_a)
    test("Soft Archive Book Title & Related Physical Copies",
         r24.status_code == 200 and r24.json().get("data", {}).get("status") == "ARCHIVED",
         r24.text)

    # 25. Restore Archived Book Record
    r25 = requests.post(f"{BASE_URL}/books/{created_book_id}/restore", headers=headers_a)
    test("Restore Archived Book Title & Physical Copies to Active Catalogue",
         r25.status_code == 200,
         r25.text)

    print("==================================================================")
    print(f"  RESULTS: {passed_tests} / {total_tests} SCENARIOS PASSED ({int(passed_tests/total_tests*100)}%)")
    print("==================================================================")

    if passed_tests < total_tests:
        sys.exit(1)

if __name__ == "__main__":
    run_tests()
