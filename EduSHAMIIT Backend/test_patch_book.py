import requests
import json
import psycopg2
from psycopg2.extras import RealDictCursor

from app.config import settings
DATABASE_URL = settings.DATABASE_URL


def test_patch_book():
    conn = psycopg2.connect(DATABASE_URL)
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    # 1. Get school_id and a book id for 'New lecture test'
    cur.execute("SELECT id, school_id, title FROM public.library_books WHERE title ILIKE '%New lecture test%' LIMIT 1;")
    book = cur.fetchone()
    if not book:
        print("Book not found")
        return
    
    book_id = str(book['id'])
    school_id = str(book['school_id'])
    print(f"Testing on Book ID: {book_id}, School ID: {school_id}, Title: {book['title']}")

    # 2. Get a valid user or superadmin token
    cur.execute("SELECT id, email FROM auth.users LIMIT 1;")
    user = cur.fetchone()
    user_id = str(user['id']) if user else '00000000-0000-0000-0000-000000000000'

    jwt_secret = getattr(settings, "SUPABASE_JWT_SECRET", getattr(settings, "JWT_SECRET", "super-secret-jwt-token-with-at-least-32-characters-long"))
    from jose import jwt
    token = jwt.encode(

        {"sub": user_id, "school_id": school_id, "role": "admin", "aud": "authenticated"},
        jwt_secret,
        algorithm="HS256"
    )


    headers = {
        "Authorization": f"Bearer {token}",
        "X-School-ID": school_id,
        "Content-Type": "application/json"
    }

    # Payload matching exactly what Flutter sends on save:
    payload = {
        'title': 'New lecture test',
        'subtitle': None,
        'author': 'yash',
        'isbn13': None,
        'isbn10': None,
        'publisher': None,
        'category_name': 'Finance',
        'language_name': 'English',
        'book_type_name': 'E-Book / Digital',
        'publication_year': 2026,
        'financial_year': '2026-2027',
        'status': 'ACTIVE',
        'total_copies': 1,
        'available_copies': 1,
        'description': 'working',
        'rack_location': 'Rack A',
        'shelf_location': 'Shelf 1',
        'cover_url': 'http://127.0.0.1:8000/storage/v1/object/public/avatars/library_covers/cover_1788008128_6d79a2.png',
        'purchase_price': 299.0,
        'supplier': 'Sapna Book House',
        'condition': 'GOOD',
        'acquisition_type': 'PURCHASE',
        'is_digital': True,
        'digital_visibility': 'PUBLIC',
        'access_mode': 'ALL',
        'requires_permission': False,
        'subject': None,
        'grade_level': None,
        'difficulty_level': 'Intermediate',
        'default_access_duration_days': 30,
        'allow_notes': True,
        'allow_highlights': True,
        'allow_bookmarks': True,
        'allow_copy_text': False,
        'allow_screenshots': False,
        'digital_files': [
            {
                'file_type': 'VIDEO_HLS',
                'source_type': 'LIVE_STREAM',
                'title': 'Chapter / Live Lecture 1',
                'storage_key': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                'file_name': 'Live Stream Link',
                'mime_type': 'application/x-mpegURL',
                'file_size_bytes': 0,
                'duration_seconds': 0,
                'page_count': 0,
                'stream_url': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                'is_primary': True,
                'is_live_stream': True,
                'sort_order': 1
            },
            {
                'file_type': 'VIDEO_HLS',
                'source_type': 'LIVE_STREAM',
                'title': 'Chapter / Live Lecture 2',
                'storage_key': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                'file_name': 'Live Stream Link',
                'mime_type': 'application/x-mpegURL',
                'file_size_bytes': 0,
                'duration_seconds': 0,
                'page_count': 0,
                'stream_url': 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
                'is_primary': False,
                'is_live_stream': True,
                'sort_order': 2
            }
        ]
    }

    url = f"http://localhost:8082/api/v1/library/books/{book_id}"


    print(f"PATCH {url} ...")
    try:
        res = requests.patch(url, headers=headers, json=payload, timeout=10)
        print(f"Response Status: {res.status_code}")
        print(f"Response Body:\n{res.text}")

    except Exception as e:
        print(f"Request Exception: {e}")

if __name__ == "__main__":
    test_patch_book()
