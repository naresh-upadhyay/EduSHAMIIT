import requests
import json

# Test through backend FastAPI endpoints on port 8000 or internal app
BASE_URL = "http://localhost:8000/api/v1"

# We will test using testclient
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

# Helper auth headers
headers = {
    "X-School-ID": "11111111-1111-1111-1111-111111111111",
    "Authorization": "Bearer mock_or_admin"
}

print("Testing FastAPI app initialization and route registration...")
routes = [route.path for route in app.routes]
circulation_routes = [r for r in routes if "circulation" in r or "transactions" in r]
print("Registered Circulation Routes:", circulation_routes)

assert "/api/v1/library/circulation/stats" in routes
assert "/api/v1/library/transactions" in routes
assert "/api/v1/library/transactions/raise-issue-request" in routes
assert "/api/v1/library/transactions/{borrow_id}/process-request" in routes
assert "/api/v1/library/transactions/{borrow_id}/request-renew" in routes

print("\nALL FASTAPI ROUTE REGISTRATIONS CONFIRMED!")
