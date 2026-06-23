"""
JWT Token Cache Middleware
Caches decoded JWT payloads in Redis to avoid repeated python-jose decode overhead.
Each token is cached for its remaining TTL (exp - current_time).
Key format: jwt:{sha256(token)}
"""
import hashlib
import json
import time
from app.cache.redis_client import get_redis

# Cache TTL buffer (seconds) — re-fetch 5 minutes before actual expiry
# so we never serve a stale token that's about to expire
CACHE_TTL_BUFFER = 300


def _token_hash(token: str) -> str:
    """Generate a deterministic hash for the JWT token."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()[:32]


async def get_cached_payload(token: str):
    """
    Get cached JWT payload from Redis.
    Returns the decoded dict if found, or None if not cached.
    """
    try:
        rc = get_redis()
        if not rc:
            return None
        key = f"jwt:{_token_hash(token)}"
        data = await rc.get(key)
        if data:
            return json.loads(data)
        return None
    except Exception:
        return None


async def set_cached_payload(token: str, payload: dict, exp_timestamp: int):
    """
    Cache a decoded JWT payload in Redis.
    TTL is calculated from the token's exp claim minus current time,
    minus a buffer so we re-fetch before actual expiry.
    """
    try:
        rc = get_redis()
        if not rc:
            return
        now = int(time.time())
        ttl = max(60, exp_timestamp - now - CACHE_TTL_BUFFER)
        key = f"jwt:{_token_hash(token)}"
        await rc.setex(key, ttl, json.dumps(payload, default=str))
    except Exception:
        pass


async def invalidate_cached_token(token: str):
    """Invalidate a cached JWT token (e.g. on logout)."""
    try:
        rc = get_redis()
        if not rc:
            return
        key = f"jwt:{_token_hash(token)}"
        await rc.delete(key)
    except Exception:
        pass