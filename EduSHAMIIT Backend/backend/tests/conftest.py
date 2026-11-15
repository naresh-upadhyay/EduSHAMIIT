"""
Pytest configuration for EduSHAMIIT Backend
Provides universal test fixtures, path initialization, and mock settings.
"""
import os
import sys

# Ensure backend root is always on sys.path
backend_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_dir not in sys.path:
    sys.path.insert(0, backend_dir)

# Ensure local test runs can connect to Supabase Kong on localhost
if "kong" in os.environ.get("SUPABASE_URL", "") or not os.environ.get("SUPABASE_URL"):
    os.environ["SUPABASE_URL"] = "http://localhost:8000"

import pytest

@pytest.fixture
def sample_school_id():
    return "11111111-1111-1111-1111-111111111111"

@pytest.fixture
def sample_user_id():
    return "10000000-0000-0000-0000-000000000002"

@pytest.fixture
def sample_other_user_id():
    return "10000000-0000-0000-0000-000000000003"

@pytest.fixture
def sample_other_school_id():
    return "22222222-2222-2222-2222-222222222222"
