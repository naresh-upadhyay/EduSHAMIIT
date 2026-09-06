import asyncio
import httpx
import uuid
from app.api.library import generate_stream_token, verify_stream_token, exec_sql

async def test_multi_assets():
    print("=" * 65)
    print("🚀 TESTING MULTI-FILE, MULTI-LINK & LIVE STREAMING CAPABILITIES")
    print("=" * 65)

    # 1. Fetch School & Admin
    print("\n--- Step 1: Database School & Admin Lookup ---")
    schools = await exec_sql("SELECT id FROM public.schools LIMIT 1")
    assert len(schools) > 0, "At least one school must exist for testing"
    school_id = str(schools[0]["id"])

    profiles = await exec_sql("SELECT id, full_name, email FROM public.profiles WHERE school_id = %s LIMIT 1", (school_id,))
    assert len(profiles) >= 1, "At least one user profile must exist"
    user_id = str(profiles[0]["id"])
    user_name = profiles[0]["full_name"] or "Librarian Admin"
    user_email = profiles[0]["email"] or "admin@edushamiit.com"
    print(f"✅ School ID: {school_id} | User: {user_name} ({user_email})")

    # 2. Fetch Books and verify multi-asset digital files
    print("\n--- Step 2: Query fn_library_list_books & Verify Multi-Asset Aggregation ---")
    books_data = await exec_sql(
        "SELECT public.fn_library_list_books(%s, 'Principles of Quantum Mechanics', NULL, NULL, NULL, NULL, NULL, NULL, 'ACTIVE', 'ALL', NULL, NULL, 'title', 'ASC', 1, 10) AS data",
        (school_id,)
    )
    items = books_data[0]["data"].get("items", [])
    print(f"✅ Found {len(items)} matching publications in library catalogue")

    quantum_book = items[0] if items else None
    assert quantum_book is not None, "Quantum Physics book not found!"

    print(f"📖 Book Title: {quantum_book['title']}")
    print(f"   Category: {quantum_book['category_name']}, Book Type: {quantum_book['book_type_name']}")
    print(f"   Digital Files Count: {len(quantum_book.get('digital_files', []))}")
    
    for idx, df in enumerate(quantum_book.get('digital_files', []), start=1):
        print(f"   [{idx}] Type: {df.get('file_type'):<12} | Source: {df.get('source_type'):<12} | Live: {df.get('is_live_stream')} | Title: {df.get('title')}")

    assert len(quantum_book.get('digital_files', [])) >= 4, "Expected at least 4 diverse digital assets attached!"
    live_stream_asset = next((f for f in quantum_book['digital_files'] if f.get('is_live_stream')), None)
    assert live_stream_asset is not None, "Live stream asset not found in digital files!"
    print(f"✅ Verified Live Stream Asset: '{live_stream_asset.get('title')}' -> {live_stream_asset.get('stream_url')}")

    # 3. Test DRM-Lite Stream Token for Specific Digital Asset (Video / Audio / PDF)
    print("\n--- Step 3: Test DRM-Lite Stream Token Generation for Specific Asset ---")
    payload = {
        "book_id": str(quantum_book["id"]),
        "file_id": str(live_stream_asset["id"]),
        "school_id": school_id,
        "user_id": user_id,
        "user_name": user_name,
        "user_email": user_email
    }
    stream_token = generate_stream_token(payload, expires_in_seconds=3600)
    assert stream_token is not None and "." in stream_token
    verified = verify_stream_token(stream_token)
    assert verified is not None
    assert verified.get("book_id") == str(quantum_book["id"])
    assert verified.get("file_id") == str(live_stream_asset["id"])
    print(f"✅ Generated HMAC DRM Stream Token: {stream_token[:28]}...")
    print(f"✅ Verified Token Payload -> book_id: {verified.get('book_id')}, file_id: {verified.get('file_id')}")

    # 4. Test In-App Multi-Asset Insertion & Playlist Ordering
    print("\n--- Step 4: Create Multi-Asset Publication with PDF, Audio, Video & Live Stream ---")
    new_book_id = str(uuid.uuid4())
    await exec_sql("""
        INSERT INTO public.library_books (
            id, school_id, title, subtitle, author, publisher, category_name, language_name,
            book_type_name, publication_year, pages, description, isbn13, total_copies,
            available_copies, is_digital, digital_visibility, access_mode, requires_permission,
            created_by, updated_by
        ) VALUES (
            %s, %s, %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s, %s,
            %s, %s, %s, %s, %s,
            %s, %s
        );
    """, (
        new_book_id, school_id,
        "Deep Learning with PyTorch & Live Interactive GPU Labs",
        "Complete Lecture Playlist with Real-Time Live Stream Broadcasts",
        "Yann LeCun & Ian Goodfellow",
        "MIT Press",
        "Computer Science",
        "English",
        "eBook (PDF/ePub/HTML)",
        2026,
        520,
        "Modern deep learning textbook containing chapter PDFs, audio explainers, video walkthroughs, and live stream classrooms.",
        f"978-0262{uuid.uuid4().hex[:6]}",
        5, 5, True, "PUBLIC", "ALL", False,
        user_id, user_id
    ), fetch=False)

    # Insert 4 distinct digital assets
    assets = [
        ("EBOOK_PDF", "FILE_UPLOAD", "Textbook Vol 1: Foundations of Neural Networks", "dl_vol1.pdf", "dl_vol1.pdf", "application/pdf", 18500000, 0, 260, "https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf", True, False, 1),
        ("AUDIO_MP3", "DIRECT_LINK", "Audio Summary: Ch 1 - Loss Functions & Backprop", "audio_ch1.mp3", "audio_ch1.mp3", "audio/mpeg", 24000000, 1800, 0, "https://actions.google.com/sounds/v1/ambiences/rain_heavy.ogg", False, False, 2),
        ("VIDEO_MP4", "DIRECT_LINK", "Video Workshop: Convolutional Networks & Vision Transformers", "video_cnn.mp4", "video_cnn.mp4", "video/mp4", 160000000, 3100, 0, "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4", False, False, 3),
        ("VIDEO_HLS", "LIVE_STREAM", "🔴 LIVE: Weekly Interactive Q&A and Code Review Stream", "live_dl_qa.m3u8", "live_dl_qa.m3u8", "application/x-mpegURL", 0, 0, 0, "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8", False, True, 4),
    ]

    for ft, st, title, sk, fn, mt, fs, dur, pg, surl, prim, live, sort_o in assets:
        await exec_sql("""
            INSERT INTO public.library_digital_files (
                book_id, school_id, file_type, source_type, title, storage_key, file_name, mime_type,
                file_size_bytes, duration_seconds, page_count, stream_url, is_primary, is_live_stream, sort_order, created_by
            ) VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
            );
        """, (
            new_book_id, school_id, ft, st, title, sk, fn, mt, fs, dur, pg, surl, prim, live, sort_o, user_id
        ), fetch=False)

    # 5. Verify retrieved created publication
    print("\n--- Step 5: Verify fn_library_list_books aggregates new publication with 4 assets ---")
    new_book_data = await exec_sql(
        "SELECT public.fn_library_list_books(%s, 'Deep Learning with PyTorch', NULL, NULL, NULL, NULL, NULL, NULL, 'ACTIVE', 'ALL', NULL, NULL, 'title', 'ASC', 1, 10) AS data",
        (school_id,)
    )
    res_items = new_book_data[0]["data"].get("items", [])
    assert len(res_items) >= 1, "Created book not returned by search!"
    retrieved = res_items[0]
    print(f"✅ Retrieved: {retrieved['title']}")
    print(f"   Attached Digital Assets ({len(retrieved.get('digital_files', []))}):")
    for a in retrieved.get("digital_files", []):
        print(f"   - {a.get('title')} [{a.get('file_type')}] (Live: {a.get('is_live_stream')})")

    assert len(retrieved.get("digital_files", [])) == 4

    print("\n" + "=" * 65)
    print("✨ ALL MULTI-FILE, MULTI-LINK & LIVE STREAMING CHECKS PASSED (100%) ✨")
    print("=" * 65)

if __name__ == "__main__":
    asyncio.run(test_multi_assets())
