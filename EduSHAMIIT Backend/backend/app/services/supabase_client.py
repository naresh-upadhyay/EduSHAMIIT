"""
Supabase Client - Uses direct HTTP requests to Supabase REST API.
This bypasses the supabase Python client library which has compatibility issues.
"""
import httpx
import json
import os
from app.config import settings

_client = None


class SupabaseClient:
    """Direct HTTP client for Supabase REST API."""

    def __init__(self, url: str, key: str):
        self.url = url.rstrip("/")
        self.key = key
        self.headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        }
        self.auth_url = f"{self.url}/auth/v1"
        self.rest_url = f"{self.url}/rest/v1"

    def table(self, table_name: str):
        """Get a table query builder."""
        return TableQuery(self, table_name)

    def auth(self):
        """Get auth client."""
        return AuthClient(self)


class AuthClient:
    """Supabase Auth client using direct HTTP."""

    def __init__(self, client: SupabaseClient):
        self.client = client

    def _get_error_message(self, error_data: dict, default: str) -> str:
        """Extract a readable error message from Supabase auth response."""
        # Handle specific error codes for better user experience
        if isinstance(error_data, dict):
            error_code = error_data.get("error_code") or error_data.get("error")
            if error_code == "user_already_exists" or "already registered" in str(error_data).lower():
                return "Email already exists"
                
            return (
                error_data.get("msg") or 
                error_data.get("message") or 
                error_data.get("error_description") or 
                error_data.get("error") or 
                default
            )
        return str(error_data) if error_data else default
    def sign_in_with_password(self, credentials: dict) -> dict:
        """Sign in with email and password."""
        email = credentials.get("email")
        password = credentials.get("password")

        response = httpx.post(
            f"{self.client.auth_url}/token?grant_type=password",
            headers=self.client.headers,
            json={"email": email, "password": password},
            timeout=10.0
        )

        if response.status_code != 200:
            error = response.json()
            raise Exception(self._get_error_message(error, "Login failed"))

        data = response.json()
        return AuthResponse(data)

    def sign_up(self, credentials: dict) -> dict:
        """Sign up with email and password."""
        email = credentials.get("email")
        password = credentials.get("password")

        response = httpx.post(
            f"{self.client.auth_url}/signup",
            headers=self.client.headers,
            json={"email": email, "password": password},
            timeout=10.0
        )

        if response.status_code != 200:
            error = response.json()
            raise Exception(self._get_error_message(error, "Registration failed"))

        data = response.json()
        return AuthResponse(data)

    def refresh_session(self, refresh_token: str) -> dict:
        """Refresh the session using a refresh token."""
        response = httpx.post(
            f"{self.client.auth_url}/token?grant_type=refresh_token",
            headers=self.client.headers,
            json={"refresh_token": refresh_token},
            timeout=10.0
        )

        if response.status_code != 200:
            error = response.json()
            raise Exception(self._get_error_message(error, "Token refresh failed"))

        data = response.json()
        return AuthResponse(data)


class AuthResponse:
    """Auth response wrapper."""

    def __init__(self, data: dict):
        self.data = data
        self.user = User(data.get("user", {}))
        # Session data is at the top level of the response
        self.session = Session(data)


class User:
    """User object."""

    def __init__(self, data: dict):
        self.id = data.get("id")
        self.email = data.get("email")
        self.data = data


class Session:
    """Session object."""

    def __init__(self, data: dict):
        # The refresh_token and access_token are at the top level
        self.access_token = data.get("access_token")
        self.refresh_token = data.get("refresh_token")
        self.data = data


class TableQuery:
    """Table query builder using direct HTTP."""

    def __init__(self, client: SupabaseClient, table_name: str):
        self.client = client
        self.table_name = table_name
        self._select = "*"
        self._filters = []
        self._order = None
        self._limit = None
        self._offset = None
        self._single = False

    def select(self, columns: str):
        """Select columns."""
        self._select = columns
        return self

    def eq(self, column: str, value):
        """Filter by equality."""
        self._filters.append(f"{column}=eq.{value}")
        return self

    def neq(self, column: str, value):
        """Filter by not equal."""
        self._filters.append(f"{column}=neq.{value}")
        return self

    def gt(self, column: str, value):
        """Filter by greater than."""
        self._filters.append(f"{column}=gt.{value}")
        return self

    def gte(self, column: str, value):
        """Filter by greater than or equal."""
        self._filters.append(f"{column}=gte.{value}")
        return self

    def lt(self, column: str, value):
        """Filter by less than."""
        self._filters.append(f"{column}=lt.{value}")
        return self

    def lte(self, column: str, value):
        """Filter by less than or equal."""
        self._filters.append(f"{column}=lte.{value}")
        return self

    def like(self, column: str, pattern: str):
        """Filter by like pattern."""
        self._filters.append(f"{column}=like.{pattern}")
        return self

    def ilike(self, column: str, pattern: str):
        """Filter by case-insensitive like."""
        self._filters.append(f"{column}=ilike.{pattern}")
        return self

    def is_(self, column: str, value: str):
        """Filter by is (null, not null, etc)."""
        self._filters.append(f"{column}=is.{value}")
        return self

    def in_(self, column: str, values: list):
        """Filter by in list."""
        formatted_values = ",".join([f'"{v}"' if isinstance(v, str) else str(v) for v in values])
        self._filters.append(f"{column}=in.({formatted_values})")
        return self

    def contains(self, column: str, value):
        """Filter by contains (for JSONB)."""
        self._filters.append(f"{column}=cs.{value}")
        return self

    def or_(self, condition: str):
        """Add an OR condition."""
        self._filters.append(f"or=({condition})")
        return self

    def order(self, column: str, ascending: bool = True):
        """Order results."""
        direction = "asc" if ascending else "desc"
        self._order = f"{column}.{direction}"
        return self

    def limit(self, count: int):
        """Limit results."""
        self._limit = count
        return self

    def offset(self, count: int):
        """Offset results."""
        self._offset = count
        return self

    def single(self):
        """Expect single result."""
        self._single = True
        return self

    def maybe_single(self):
        """Expect single result or null."""
        self._single = True
        return self

    def execute(self) -> dict:
        """Execute the query."""
        url = f"{self.client.rest_url}/{self.table_name}"

        # Build query parameters
        params = {"select": self._select}
        if self._filters:
            # Add filters as query params
            for f in self._filters:
                key, val = f.split("=", 1)
                params[key] = val

        if self._order:
            params["order"] = self._order
        if self._limit:
            params["limit"] = self._limit
        if self._offset:
            params["offset"] = self._offset

        # Add prefer header for single result
        headers = self.client.headers.copy()
        if self._single:
            headers["Prefer"] = "return=representation,resolution=merge-duplicates"
            headers["Accept"] = "application/vnd.pgrst.object+json"

        response = httpx.get(url, headers=headers, params=params, timeout=10.0)

        if response.status_code not in (200, 201):
            error = response.text
            raise Exception(f"Query failed: {error}")

        data = response.json()
        return QueryResult(data, is_single=self._single)

    def insert(self, data: dict):
        """Insert a row."""
        self._operation = "insert"
        self._data = data
        return self

    def update(self, data: dict):
        """Update rows."""
        self._operation = "update"
        self._data = data
        return self

    def upsert(self, data: dict, on_conflict: str = None):
        """Upsert a row."""
        self._operation = "upsert"
        self._data = data
        self._on_conflict = on_conflict
        return self

    def delete(self):
        """Delete rows."""
        self._operation = "delete"
        return self

    def execute(self) -> dict:
        """Execute the operation."""
        url = f"{self.client.rest_url}/{self.table_name}"

        headers = self.client.headers.copy()
        params = {}

        # Add filters
        if self._filters:
            for f in self._filters:
                key, val = f.split("=", 1)
                params[key] = val

        if self._single:
            headers["Prefer"] = "return=representation,resolution=merge-duplicates"
            headers["Accept"] = "application/vnd.pgrst.object+json"

        if hasattr(self, '_operation'):
            if self._operation == "insert":
                response = httpx.post(url, headers=headers, json=self._data, params=params, timeout=10.0)
            elif self._operation == "update":
                response = httpx.patch(url, headers=headers, json=self._data, params=params, timeout=10.0)
            elif self._operation == "upsert":
                headers["Prefer"] = "return=representation,resolution=merge-duplicates"
                if hasattr(self, '_on_conflict') and self._on_conflict:
                    params["on_conflict"] = self._on_conflict
                response = httpx.post(url, headers=headers, json=self._data, params=params, timeout=10.0)
            elif self._operation == "delete":
                response = httpx.delete(url, headers=headers, params=params, timeout=10.0)
            else:
                # Default to select
                if self._select:
                    params["select"] = self._select
                response = httpx.get(url, headers=headers, params=params, timeout=10.0)
        else:
            # Select operation
            if self._select:
                params["select"] = self._select
            response = httpx.get(url, headers=headers, params=params, timeout=10.0)

        if response.status_code not in (200, 201, 204):
            error = response.text
            raise Exception(f"Operation failed: {error}")

        if response.status_code == 204:
            return QueryResult([], is_single=self._single)

        data = response.json()
        return QueryResult(data, is_single=self._single)


class QueryResult:
    """Query result wrapper."""

    def __init__(self, data, is_single=False):
        if is_single:
            self.data = data if data else None
        else:
            if isinstance(data, list):
                self.data = data
            else:
                self.data = [data] if data else []


def get_supabase() -> SupabaseClient:
    """Get Supabase client singleton."""
    global _client
    if _client is None:
        _client = SupabaseClient(settings.SUPABASE_URL, settings.SUPABASE_SERVICE_ROLE_KEY)
    return _client
