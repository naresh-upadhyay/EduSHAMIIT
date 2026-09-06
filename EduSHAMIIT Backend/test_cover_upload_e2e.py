import asyncio
import io
import httpx
from app.config import settings
import psycopg2
from psycopg2.extras import RealDictCursor

def test_cover_upload_e2e():
    conn = psycopg2.connect(settings.DATABASE_URL)
    cur = conn.cursor(cursor_factory=RealDictCursor)
    
    # 1. Create a dummy 100x100 PNG image bytes
    from PIL import Image
    img = Image.new('RGB', (200, 300), color=(99, 102, 241))
    buf = io.BytesIO()
    img.save(buf, format='PNG')
    image_bytes = buf.getvalue()

    # 2. Test upload directly via backend helper
    from app.middleware.auth import get_public_supabase_url
    import uuid
    from datetime import datetime

    filename = f"test_cover_{int(datetime.utcnow().timestamp())}_{uuid.uuid4().hex[:6]}.png"
    storage_path = f"library_covers/{filename}"
    supabase_url = settings.SUPABASE_URL.rstrip("/")
    storage_url = f"{supabase_url}/storage/v1/object/avatars/{storage_path}"
    headers = {
        "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
        "Content-Type": "image/png",
        "x-upsert": "true",
    }

    import requests
    upload_res = requests.post(storage_url, headers=headers, data=image_bytes)
    print(f"Storage Upload Status: {upload_res.status_code}")
    assert upload_res.status_code in (200, 201), f"Storage upload failed: {upload_res.text}"

    public_url_base = get_public_supabase_url(settings.SUPABASE_URL)
    public_url = f"{public_url_base}/storage/v1/object/public/avatars/{storage_path}"
    print(f"Generated Public URL: {public_url}")

    # 3. Test that public URL is directly fetchable
    fetch_res = requests.get(public_url)
    print(f"Fetch Public URL Status: {fetch_res.status_code} (length: {len(fetch_res.content)} bytes)")
    assert fetch_res.status_code == 200, f"Public fetch failed: {fetch_res.text}"

    # 4. Attach cover to 'New lecture test' in database
    cur.execute("UPDATE public.library_books SET cover_url = %s WHERE title ILIKE '%%New lecture test%%' RETURNING id, title, cover_url;", (public_url,))
    conn.commit()
    updated_book = cur.fetchone()
    print(f"\nUpdated Book in DB:")
    print(f"ID: {updated_book['id']}")
    print(f"Title: {updated_book['title']}")
    print(f"Cover URL: {updated_book['cover_url']}")

    print("\nCOVER UPLOAD & URL RESOLUTION END-TO-END TEST PASSED!")

if __name__ == "__main__":
    test_cover_upload_e2e()
