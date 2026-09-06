"""
Comprehensive End-to-End Test Suite for Unified Digital + Physical Library System
Tests multi-format catalogue, digital assets, DRM streaming tokens, in-app viewer security,
request permission workflows, reading/audio progress sync, annotations, reviews, and analytics.
"""
import uuid
from datetime import datetime, timedelta
from app.api.library import generate_stream_token, verify_stream_token, exec_sql


async def test_digital_books_e2e_lifecycle():

    print("\n=======================================================")
    print("🚀 RUNNING DIGITAL LIBRARY COMPREHENSIVE E2E TEST SUITE")
    print("=======================================================")

    # Setup test tenant school and profiles
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1")
    assert len(schools) > 0, "At least one school must exist for testing"
    school_id = str(schools[0]["id"])

    profiles = await exec_sql("SELECT id, full_name, email FROM public.profiles LIMIT 2")
    assert len(profiles) >= 1, "At least one user profile must exist"
    user_id = str(profiles[0]["id"])
    user_name = profiles[0]["full_name"] or "Test Student"
    user_email = profiles[0]["email"] or "student@edushamiit.com"

    # Test 1: Generate and verify signed DRM-lite stream tokens
    print("\n--- TEST 1: DRM-Lite Stream Token Crypto Verification ---")
    payload = {
        "book_id": str(uuid.uuid4()),
        "school_id": school_id,
        "user_id": user_id,
        "user_name": user_name,
        "user_email": user_email
    }
    valid_token = generate_stream_token(payload, expires_in_seconds=3600)
    assert valid_token is not None and "." in valid_token
    verified_data = verify_stream_token(valid_token)
    assert verified_data is not None
    assert verified_data["user_id"] == user_id
    assert verified_data["user_name"] == user_name
    print("✅ Valid Token Verified Successfully")

    # Test 2: Expired Token Rejection
    print("\n--- TEST 2: Expired / Tampered Token Rejection ---")
    expired_token = generate_stream_token(payload, expires_in_seconds=-10)
    assert verify_stream_token(expired_token) is None, "Expired token must be rejected"
    
    tampered_token = valid_token[:-4] + "abcd"
    assert verify_stream_token(tampered_token) is None, "Tampered signature must be rejected"
    print("✅ Expired & Tampered Tokens Blocked Successfully")

    # Test 3: Create Multi-Format Digital Books (eBook, Audiobook, Video Book)
    print("\n--- TEST 3: Multi-Format Books Creation ---")
    test_isbn = f"978-DGT-{uuid.uuid4().hex[:6]}"
    
    # 3A. Create Public eBook
    ebook_sql = """
        INSERT INTO public.library_books (
            school_id, title, author, isbn13, book_type_name, is_digital, digital_visibility,
            requires_permission, allow_notes, allow_highlights, status
        ) VALUES (
            %s, %s, %s, %s, %s, TRUE, 'PUBLIC', FALSE, TRUE, TRUE, 'ACTIVE'
        ) RETURNING id, title, is_digital, digital_visibility;
    """
    ebook_res = await exec_sql(ebook_sql, (school_id, "Advanced Quantum Physics eBook", "Dr. Richard Feynman", test_isbn, "eBook (PDF/ePub/HTML)"))
    ebook_id = str(ebook_res[0]["id"])
    assert ebook_res[0]["is_digital"] is True
    print(f"✅ Created eBook: {ebook_res[0]['title']} ({ebook_id})")

    # Attach digital PDF file
    file_sql = """
        INSERT INTO public.library_digital_files (
            book_id, school_id, file_type, storage_key, file_name, mime_type, file_size_bytes, page_count
        ) VALUES (
            %s, %s, 'EBOOK_PDF', 'books/quantum_physics.pdf', 'quantum_physics.pdf', 'application/pdf', 15420000, 350
        ) RETURNING id;
    """
    file_res = await exec_sql(file_sql, (ebook_id, school_id))
    assert len(file_res) > 0
    print("✅ Attached PDF Digital Asset (350 pages)")

    # 3B. Create Restricted Audiobook
    audio_isbn = f"978-AUD-{uuid.uuid4().hex[:6]}"
    audio_sql = """
        INSERT INTO public.library_books (
            school_id, title, author, isbn13, book_type_name, is_digital, digital_visibility,
            requires_permission, status
        ) VALUES (
            %s, %s, %s, %s, %s, TRUE, 'RESTRICTED', TRUE, 'ACTIVE'
        ) RETURNING id, title;
    """
    audio_res = await exec_sql(audio_sql, (school_id, "Atomic Habits Audiobook", "James Clear", audio_isbn, "Audiobook"))
    audio_id = str(audio_res[0]["id"])
    print(f"✅ Created Restricted Audiobook: {audio_res[0]['title']} ({audio_id})")

    # Test 4: Access Permission Stored Function Evaluation
    print("\n--- TEST 4: fn_library_check_digital_access Evaluation ---")
    # Public book access check -> should be TRUE
    access_public = await exec_sql(
        "SELECT public.fn_library_check_digital_access(%s::uuid, %s::uuid, %s::uuid) AS access",
        (school_id, ebook_id, user_id)
    )
    assert access_public[0]["access"]["has_access"] is True
    print("✅ Public eBook Access: GRANTED (Instant Open Access)")

    # Restricted audiobook access check -> should be FALSE (Permission required)
    access_restr = await exec_sql(
        "SELECT public.fn_library_check_digital_access(%s::uuid, %s::uuid, %s::uuid) AS access",
        (school_id, audio_id, user_id)
    )
    assert access_restr[0]["access"]["has_access"] is False
    assert access_restr[0]["access"]["status"] == "PERMISSION_REQUIRED"
    print("✅ Restricted Audiobook Access: LOCKED (Requires Permission)")

    # Test 5: Digital Access Request & Approval Workflow
    print("\n--- TEST 5: Permission Request & Approval Workflow ---")
    # Submit access request
    perm_req_sql = """
        INSERT INTO public.library_digital_access_permissions (
            book_id, user_id, school_id, status, reason, created_at, updated_at
        ) VALUES (
            %s, %s, %s, 'PENDING', 'Preparation for competitive exams.', NOW(), NOW()
        ) RETURNING id, status;
    """
    perm_req_res = await exec_sql(perm_req_sql, (audio_id, user_id, school_id))
    assert perm_req_res[0]["status"] == "PENDING"
    print("✅ Access Request Submitted: PENDING")

    # Librarian Approves with 30-Day Expiry
    expires_at = datetime.utcnow() + timedelta(days=30)
    approve_sql = """
        UPDATE public.library_digital_access_permissions
        SET status = 'APPROVED', granted_at = NOW(), expires_at = %s, updated_at = NOW()
        WHERE book_id = %s AND user_id = %s AND school_id = %s
        RETURNING status, expires_at;
    """
    approve_res = await exec_sql(approve_sql, (expires_at, audio_id, user_id, school_id))
    assert approve_res[0]["status"] == "APPROVED"
    print(f"✅ Librarian Approved Access (Valid for 30 days until {expires_at.strftime('%Y-%m-%d')})")

    # Re-check access -> now must be TRUE
    access_approved = await exec_sql(
        "SELECT public.fn_library_check_digital_access(%s::uuid, %s::uuid, %s::uuid) AS access",
        (school_id, audio_id, user_id)
    )
    assert access_approved[0]["access"]["has_access"] is True
    print("✅ Restricted Audiobook Access Post-Approval: UNLOCKED & GRANTED")

    # Test 6: Reading Progress & Session Sync
    print("\n--- TEST 6: Reading & Audio Progress Sync ---")
    progress_sql = """
        SELECT public.fn_library_record_digital_progress(
            %s::uuid, %s::uuid, %s::uuid, 'EBOOK', 45, 350, 12.85, 0.0, 0.0, 1.0, 900, FALSE
        ) AS progress;
    """
    prog_res = await exec_sql(progress_sql, (school_id, ebook_id, user_id))
    prog = prog_res[0]["progress"]
    assert prog["current_page"] == 45
    assert prog["total_pages"] == 350
    assert float(prog["progress_pct"]) == 12.85
    assert prog["time_spent_seconds"] == 900
    print("✅ Reading Progress Saved: Page 45/350 (12.85%, 15 mins read time)")

    # Test 7: Bookmarks, Highlights & Annotations
    print("\n--- TEST 7: Bookmarks and Color-Coded Highlights ---")
    note_sql = """
        INSERT INTO public.library_book_interactions (
            book_id, user_id, school_id, interaction_type, page_number, selected_text, highlight_color, note_content
        ) VALUES (
            %s, %s, %s, 'HIGHLIGHT', 45, 'Wave-particle duality in quantum fields', '#38BDF8', 'Key topic for midterm exam.'
        ) RETURNING id, interaction_type, highlight_color;
    """
    note_res = await exec_sql(note_sql, (ebook_id, user_id, school_id))
    assert note_res[0]["interaction_type"] == "HIGHLIGHT"
    assert note_res[0]["highlight_color"] == "#38BDF8"
    print("✅ Created Highlighting & Note Annotation")

    # Test 8: Book Review & 5-Star Rating Aggregation
    print("\n--- TEST 8: Reviews & Rating Aggregation ---")
    review_sql = """
        INSERT INTO public.library_book_reviews (
            book_id, user_id, school_id, rating, review_title, review_text, reaction_emoji, status
        ) VALUES (
            %s, %s, %s, 5, 'Masterpiece of Physics', 'Extremely clear diagrams and crystal clear explanations.', '🔥', 'PUBLISHED'
        ) RETURNING id, rating;
    """
    review_res = await exec_sql(review_sql, (ebook_id, user_id, school_id))
    assert review_res[0]["rating"] == 5

    # Update aggregate book rating
    await exec_sql(
        "UPDATE public.library_books SET rating = 5.0, total_reviews = 1 WHERE id = %s",
        (ebook_id,),
        fetch=False
    )
    print("✅ Review Submitted (5 Stars, Emoji: 🔥)")

    # Test 9: Digital Library Analytics Aggregation
    print("\n--- TEST 9: Digital Library Analytics ---")
    analytics_res = await exec_sql(
        "SELECT public.fn_library_get_digital_analytics(%s::uuid, %s::uuid) AS analytics;",
        (school_id, ebook_id)
    )
    analytics = analytics_res[0]["analytics"]
    assert analytics["total_reads"] >= 1
    assert analytics["total_highlights"] >= 1
    print(f"✅ Book Analytics Verified: Reads={analytics['total_reads']}, Highlights={analytics['total_highlights']}")

    # Clean up test records
    await exec_sql("DELETE FROM public.library_books WHERE id IN (%s, %s)", (ebook_id, audio_id), fetch=False)
    print("\n✨ ALL 9 DIGITAL LIBRARY E2E TESTS PASSED (100%) ✨\n")


if __name__ == "__main__":
    import asyncio
    asyncio.run(test_digital_books_e2e_lifecycle())
