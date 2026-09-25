# EduSHAMIIT Backend Test Suites

All automated test suites, end-to-end integration tests, and verification scripts for the FastAPI backend are consolidated in this directory.

> **Design Principle**: Working API code is kept strictly in `app/` (models, routes, services, middleware, agents). All test files and test suites reside here in `tests/` to prevent mixing testing code with production code.

---

## Directory Structure

```
EduSHAMIIT Backend/backend/
├── app/                  # Production FastAPI code ONLY
│   ├── api/              # API endpoints and route handlers
│   ├── services/         # Business logic, MinIO, email, AI
│   ├── middleware/       # Auth, role-scoping, logging
│   ├── config.py         # App configuration & settings
│   ├── models.py         # Pydantic schemas & DB models
│   └── main.py           # FastAPI entrypoint
└── tests/                # Dedicated test folder
    ├── __init__.py       # Package init & sys.path setup
    ├── conftest.py       # Pytest fixtures and environment setup
    ├── test_*.py         # Consolidated test suites
    └── README.md         # This guide
```

---

## Running Tests

### 1. Run via Pytest (Recommended)
From `EduSHAMIIT Backend/backend`:
```bash
pytest tests/
```

To run a specific module or test suite:
```bash
pytest tests/test_fastapi_routes.py
pytest tests/test_onboarding_suite.py
pytest tests/test_library_books_comprehensive_e2e.py
```

### 2. Run Directly with Python
Each test script includes universal path bootstrapping and can be executed directly from any working directory:
```bash
python tests/test_fastapi_routes.py
python tests/test_recruitment_lifecycle_e2e.py
python tests/test_attendance_management.py
```

### 3. Run Inside Docker Container
```bash
docker compose exec api pytest tests/
# Or run a specific test:
docker compose exec api python tests/test_recruitment_lifecycle_e2e.py
```
