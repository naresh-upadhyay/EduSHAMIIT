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
        if "localhost" in url:
            url = url.replace("localhost", "127.0.0.1")
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
        self._async_client = None

    async def get_async_client(self):
        """Get or create the async httpx client with connection pooling."""
        if self._async_client is None or self._async_client.is_closed:
            limits = httpx.Limits(max_keepalive_connections=20, max_connections=50)
            self._async_client = httpx.AsyncClient(timeout=10.0, limits=limits)
        return self._async_client

    async def close(self):
        """Close the async client."""
        if self._async_client and not self._async_client.is_closed:
            await self._async_client.aclose()

    def table(self, table_name: str):
        """Get a table query builder."""
        return TableQuery(self, table_name)

    def rpc(self, function_name: str, params: dict = None):
        """Call a Postgres RPC function."""
        q = TableQuery(self, "_rpc")
        q._operation = "rpc"
        q._function_name = function_name
        q._data = params or {}
        return q

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

    async def sign_in_with_password(self, credentials: dict) -> dict:
        """Sign in with email and password."""
        email = credentials.get("email")
        password = credentials.get("password")
        client = await self.client.get_async_client()

        response = await client.post(
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

    async def sign_up(self, credentials: dict) -> dict:
        """Sign up with email and password."""
        email = credentials.get("email")
        password = credentials.get("password")
        client = await self.client.get_async_client()

        response = await client.post(
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

    async def refresh_session(self, refresh_token: str) -> dict:
        """Refresh the session using a refresh token."""
        client = await self.client.get_async_client()
        response = await client.post(
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

    async def admin_delete_user(self, user_id: str):
        """Delete a user using admin privileges (service role key)."""
        client = await self.client.get_async_client()
        response = await client.delete(
            f"{self.client.auth_url}/admin/users/{user_id}",
            headers=self.client.headers,
            timeout=10.0
        )

        if response.status_code not in (200, 204):
            # Try to get error message from JSON response
            try:
                error = response.json()
            except:
                error = {"msg": response.text}
            raise Exception(self._get_error_message(error, "User deletion failed"))

        return True


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
        self._maybe_single = False
        self._count = None
        self._operation = "select"
        self._data = None

    def select(self, columns: str):
        """Select columns."""
        self._select = columns
        return self

    def count(self, count_type: str = "exact"):
        """Get the count of records."""
        self._count = count_type
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
        self._maybe_single = True
        return self

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

    def rpc(self, function_name: str, params: dict = None):
        """Call a Postgres function."""
        self._operation = "rpc"
        self._function_name = function_name
        self._data = params or {}
        return self

    def _prepare_request(self):
        if self._operation == "rpc":
            url = f"{self.client.url}/rest/v1/rpc/{self._function_name}"
        else:
            url = f"{self.client.rest_url}/{self.table_name}"

        headers = self.client.headers.copy()
        params = {}

        if self._operation == "select":
            params["select"] = self._select
        
        if self._filters:
            for f in self._filters:
                key, val = f.split("=", 1)
                params[key] = val

        if self._order:
            params["order"] = self._order
        if self._limit:
            params["limit"] = self._limit
        if self._offset:
            params["offset"] = self._offset

        if self._single:
            headers["Prefer"] = "return=representation,resolution=merge-duplicates"
            headers["Accept"] = "application/vnd.pgrst.object+json"
        elif self._maybe_single:
            params["limit"] = 1

        if self._count:
            prefer = headers.get("Prefer", "")
            if prefer:
                headers["Prefer"] = f"{prefer},count={self._count}"
            else:
                headers["Prefer"] = f"count={self._count}"

        if self._operation == "upsert":
            headers["Prefer"] = "return=representation,resolution=merge-duplicates"
            if hasattr(self, "_on_conflict") and self._on_conflict:
                params["on_conflict"] = self._on_conflict

        return url, headers, params

    def execute(self) -> dict:
        """Execute the operation synchronously."""
        url, headers, params = self._prepare_request()
        
        with httpx.Client(timeout=15.0) as client:
            if self._operation == "insert" or self._operation == "rpc":
                response = client.post(url, headers=headers, json=self._data, params=params)
            elif self._operation == "update":
                response = client.patch(url, headers=headers, json=self._data, params=params)
            elif self._operation == "upsert":
                response = client.post(url, headers=headers, json=self._data, params=params)
            elif self._operation == "delete":
                response = client.delete(url, headers=headers, params=params)
            else:
                response = client.get(url, headers=headers, params=params)

        if response.status_code not in (200, 201, 204):
            raise Exception(f"Operation failed: {response.text}")

        data = response.json() if response.status_code != 204 else []
        return QueryResult(data, response.headers, is_single=self._single, is_maybe_single=self._maybe_single)

    async def aexecute(self) -> dict:
        """Execute the operation asynchronously."""
        url, headers, params = self._prepare_request()
        client = await self.client.get_async_client()

        if self._operation == "insert" or self._operation == "rpc":
            response = await client.post(url, headers=headers, json=self._data, params=params)
        elif self._operation == "update":
            response = await client.patch(url, headers=headers, json=self._data, params=params)
        elif self._operation == "upsert":
            response = await client.post(url, headers=headers, json=self._data, params=params)
        elif self._operation == "delete":
            response = await client.delete(url, headers=headers, params=params)
        else:
            response = await client.get(url, headers=headers, params=params)

        if response.status_code not in (200, 201, 204):
            raise Exception(f"Operation failed: {response.text}")

        data = response.json() if response.status_code != 204 else []
        return QueryResult(data, response.headers, is_single=self._single, is_maybe_single=self._maybe_single)


class QueryResult:
    """Query result wrapper."""

    def __init__(self, data, headers=None, is_single=False, is_maybe_single=False):
        self.headers = headers or {}
        # Extract count if present in headers (Content-Range: 0-9/100)
        self.count = None
        content_range = self.headers.get("Content-Range")
        if content_range and "/" in content_range:
            try:
                self.count = int(content_range.split("/")[-1])
            except ValueError:
                pass

        if is_single:
            self.data = data if data else None
        elif is_maybe_single:
            if isinstance(data, list):
                self.data = data[0] if data else None
            else:
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
