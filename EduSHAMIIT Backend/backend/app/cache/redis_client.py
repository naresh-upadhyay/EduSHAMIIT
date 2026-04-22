import redis.asyncio as redis
import json
import os

_redis_client = None


def get_redis():
    global _redis_client
    if _redis_client is None:
        # Using 127.0.0.1 instead of localhost for faster connection on Windows
        redis_url = os.getenv("REDIS_URL", "redis://127.0.0.1:6379")
        if "localhost" in redis_url:
            redis_url = redis_url.replace("localhost", "127.0.0.1")
        _redis_client = redis.from_url(redis_url, decode_responses=True)
    return _redis_client


def cache_key(school_id: str, resource: str, resource_id: str = "") -> str:
    """Generate school-scoped cache key."""
    return f"{school_id}:{resource}:{resource_id}"


async def get_cached(school_id: str, resource: str, resource_id: str = ""):
    """Get cached data."""
    try:
        rc = get_redis()
        key = cache_key(school_id, resource, resource_id)
        data = await rc.get(key)
        return json.loads(data) if data else None
    except Exception:
        return None


async def set_cached(school_id: str, resource: str, data: dict, resource_id: str = "", ttl: int = 300):
    """Set cached data with TTL."""
    try:
        rc = get_redis()
        key = cache_key(school_id, resource, resource_id)
        await rc.setex(key, ttl, json.dumps(data, default=str))
    except Exception:
        pass


async def invalidate_cache(school_id: str, resource: str = "*"):
    """Invalidate cache for a school/resource."""
    try:
        rc = get_redis()
        pattern = f"{school_id}:{resource}:*"
        async for key in rc.scan_iter(match=pattern):
            await rc.delete(key)
    except Exception:
        pass