from fastapi.testclient import TestClient
from app.main import app
from app.middleware.auth import get_current_user, require_school_id

# Override dependencies for local testing
app.dependency_overrides[require_school_id] = lambda: "11111111-1111-1111-1111-111111111111"
app.dependency_overrides[get_current_user] = lambda: {
    "id": "38a93170-997b-4b4c-bc8e-256b93169c23",
    "email": "mathematicsking888@gmail.com",
    "role": "super_admin",
    "school_id": "11111111-1111-1111-1111-111111111111"
}

client = TestClient(app)
resp = client.get("/api/library/books/filter-options")
print("STATUS:", resp.status_code)
print("RESPONSE:", resp.json())
