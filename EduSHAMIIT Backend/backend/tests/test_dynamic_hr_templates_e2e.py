import os
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import asyncio
import os
import sys
import uuid
import json
from jose import jwt
from httpx import AsyncClient, ASGITransport

from app.main import app
from app.api.recruitment import exec_sql

SCHOOL_ID = "11111111-1111-1111-1111-111111111111"
ADMIN_USER_ID = "38a93170-997b-4b4c-bc8e-256b93169c23"

def make_token(user_id: str, role: str, email: str, school_id: str = SCHOOL_ID) -> str:
    payload = {
        "sub": user_id,
        "school_id": school_id,
        "role": role,
        "email": email,
        "exp": 9999999999
    }
    from app.config import settings
    jwt_secret = settings.SUPABASE_JWT_SECRET or settings.JWT_SECRET or os.getenv("JWT_SECRET", "super-secret-jwt-key-for-local-testing-only-12345")
    return jwt.encode(payload, jwt_secret, algorithm="HS256")


async def run_tests():
    print("=" * 80)
    print(" [E2E TEST SUITE] Dynamic Database-Driven HR Templates & Lookups Verification")
    print("=" * 80)

    admin_token = make_token(ADMIN_USER_ID, "super_admin", "admin@edushamiit.com")
    headers = {"Authorization": f"Bearer {admin_token}", "X-School-Id": SCHOOL_ID}

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://testserver") as client:
        # TEST 1: GET /api/hr/templates/presets
        print("\n[TEST 1] Verifying GET /api/hr/templates/presets returns dynamic DB presets...")
        r = await client.get("/api/hr/templates/presets", headers=headers)
        assert r.status_code == 200, f"Failed presets: {r.status_code} {r.text}"
        data = r.json()
        assert data.get("success") is True
        presets = data.get("data", [])
        assert len(presets) >= 8, f"Expected at least 8 presets from DB, got {len(presets)}"
        
        preset_types = {p["template_type"] for p in presets}
        print(f" -> Found {len(presets)} dynamic presets in DB spanning types: {preset_types}")
        assert "Warning Letter" in preset_types, "Warning Letter preset missing from DB"
        assert "Offer Letter" in preset_types, "Offer Letter preset missing from DB"
        assert "Appointment Letter" in preset_types, "Appointment Letter preset missing from DB"
        assert "Experience Letter" in preset_types, "Experience Letter preset missing from DB"
        assert "Relieving Letter" in preset_types, "Relieving Letter preset missing from DB"
        print(" -> PASSED: Dynamic presets successfully retrieved from PostgreSQL!")

        # TEST 2: GET /api/hr/templates/lookups
        print("\n[TEST 2] Verifying GET /api/hr/templates/lookups loads types & categories from lookup tables...")
        r = await client.get("/api/hr/templates/lookups", headers=headers)
        assert r.status_code == 200
        lookups = r.json().get("data", {})
        types = lookups.get("types", [])
        categories = lookups.get("categories", [])
        print(f" -> Found {len(types)} template types from lookup table: {types}")
        print(f" -> Found {len(categories)} template categories from lookup table: {categories}")
        assert "Warning Letter" in types
        assert "Offer Letter" in types
        assert "Administration" in categories
        assert "Employee Policies" in categories
        print(" -> PASSED: Dynamic dropdown lookups wired to DB tables!")

        # TEST 3: Verify Warning Letter Content in DB
        print("\n[TEST 3] Verifying Warning Letter preset in DB has authentic disciplinary clauses...")
        warn_tmpl = next((p for p in presets if p["template_type"] == "Warning Letter"), None)
        assert warn_tmpl is not None, "Warning letter preset not found in DB"
        html = warn_tmpl.get("content_html", "")
        assert "FORMAL WRITTEN WARNING" in html or "Corrective Action Plan" in html
        assert "policy_violated" in str(warn_tmpl.get("variables", []))
        print(" -> PASSED: Warning Letter contains authentic disciplinary clauses & variables in DB!")

        # TEST 4: Filter Templates by Type
        print("\n[TEST 4] Testing filtering GET /api/hr/templates?template_type=Warning Letter...")
        r = await client.get("/api/hr/templates?template_type=Warning Letter", headers=headers)
        assert r.status_code == 200
        filtered = r.json().get("data", [])
        for item in filtered:
            assert item["template_type"] == "Warning Letter", f"Found non-warning template {item['template_type']}"
        print(f" -> PASSED: Successfully filtered {len(filtered)} Warning Letter templates from DB!")

        # TEST 5: Filter Templates by Search
        print("\n[TEST 5] Testing search filter GET /api/hr/templates?search=Offer...")
        r = await client.get("/api/hr/templates?search=Offer", headers=headers)
        assert r.status_code == 200
        search_res = r.json().get("data", [])
        assert len(search_res) > 0
        for item in search_res:
            combined = (item["template_name"] + item["template_code"] + (item.get("description") or "")).lower()
            assert "offer" in combined
        print(f" -> PASSED: Search query matched {len(search_res)} offer templates!")

        # TEST 6: Create New Custom Template with Dynamic Lookups
        print("\n[TEST 6] Testing POST /api/hr/templates to create custom template...")
        custom_code = f"TMPL-TEST-{uuid.uuid4().hex[:6].upper()}"
        payload = {
            "template_code": custom_code,
            "template_name": "Test Dynamic Letter of Commendation",
            "template_type": "Custom",
            "category_name": "Employee Policies",
            "description": "Commendation letter for academic excellence.",
            "content_html": "<p>Congratulations {{employee_name}} for your exceptional contribution.</p>",
            "variables": ["employee_name", "department", "institution_name"],
            "is_preset": False
        }
        r = await client.post("/api/hr/templates", json=payload, headers=headers)
        assert r.status_code == 200, f"Create failed: {r.status_code} {r.text}"
        created = r.json().get("data")
        created_id = created["id"]
        assert created["template_code"] == custom_code
        print(f" -> PASSED: Successfully created template {custom_code} (ID: {created_id}) in DB!")

        # TEST 7: Single Template Fetch by ID
        print("\n[TEST 7] Testing GET /api/hr/templates/{id}...")
        r = await client.get(f"/api/hr/templates/{created_id}", headers=headers)
        assert r.status_code == 200
        fetched = r.json().get("data")
        assert fetched["id"] == created_id
        assert fetched["template_name"] == "Test Dynamic Letter of Commendation"
        print(" -> PASSED: Template fetched correctly by ID!")

        # TEST 8: Update Template
        print("\n[TEST 8] Testing PATCH /api/hr/templates/{id} to update type & content...")
        update_payload = {
            "template_name": "Updated Dynamic Commendation Order",
            "template_type": "Warning Letter",
            "content_html": "<p>Updated content for {{employee_name}}.</p>",
            "category_name": "Administration"
        }
        r = await client.patch(f"/api/hr/templates/{created_id}", json=update_payload, headers=headers)
        assert r.status_code == 200
        updated = r.json().get("data")
        assert updated["template_name"] == "Updated Dynamic Commendation Order"
        assert updated["template_type"] == "Warning Letter"
        assert updated["category_name"] == "Administration"
        print(" -> PASSED: Template updated dynamically!")

        # TEST 9: Duplicate Code Rejection
        print("\n[TEST 9] Testing duplicate template_code returns 400...")
        dup_payload = {
            "template_code": custom_code,
            "template_name": "Duplicate template",
            "template_type": "Custom",
            "content_html": "<p>Test</p>"
        }
        r = await client.post("/api/hr/templates", json=dup_payload, headers=headers)
        assert r.status_code == 400
        print(" -> PASSED: Duplicate code properly rejected with 400 status!")

        # TEST 10: Non-Existent Template returns 404
        print("\n[TEST 10] Testing non-existent template ID returns 404...")
        fake_id = str(uuid.uuid4())
        r = await client.get(f"/api/hr/templates/{fake_id}", headers=headers)
        assert r.status_code == 404
        print(" -> PASSED: 404 returned for non-existent template!")

        # TEST 11: Clean Up Test Template
        print("\n[TEST 11] Cleaning up created test template...")
        r = await client.delete(f"/api/hr/templates/{created_id}", headers=headers)
        assert r.status_code == 200
        print(" -> PASSED: Test template deleted cleanly!")

    print("\n" + "=" * 80)
    print(" ALL 11 E2E TESTS PASSED WITH 100% SUCCESS!")
    print("=" * 80)

if __name__ == "__main__":
    asyncio.run(run_tests())
