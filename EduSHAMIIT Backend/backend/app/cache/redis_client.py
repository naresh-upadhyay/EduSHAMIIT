"""
Async Redis caching layer with school-scoped cache keys.
Provides singleton Redis client, TTL caching, embedding cache,
and event-driven cache invalidation.
"""
import redis.asyncio as redis
import json
import os
import hashlib

_redis_client = None
_redis_enabled = True


def get_redis():
    """Get the singleton async Redis client."""
    global _redis_client, _redis_enabled
    if not _redis_enabled:
        return None

    if _redis_client is None:
        try:
            # Using 127.0.0.1 instead of localhost for faster connection on Windows
            redis_url = os.getenv("REDIS_URL", "redis://127.0.0.1:6379")
            if "localhost" in redis_url:
                redis_url = redis_url.replace("localhost", "127.0.0.1")
            _redis_client = redis.from_url(
                redis_url,
                decode_responses=True,
                socket_timeout=0.1,
                socket_connect_timeout=0.1
            )
        except Exception:
            _redis_enabled = False
            return None
    return _redis_client


def cache_key(school_id: str, resource: str, resource_id: str = "") -> str:
    """Generate school-scoped cache key."""
    return f"{school_id}:{resource}:{resource_id}"


async def get_cached(school_id: str, resource: str, resource_id: str = ""):
    """Get cached data."""
    try:
        rc = get_redis()
        if not rc:
            return None
        key = cache_key(school_id, resource, resource_id)
        data = await rc.get(key)
        return json.loads(data) if data else None
    except Exception:
        return None


async def set_cached(school_id: str, resource: str, data: dict, resource_id: str = "", ttl: int = 300):
    """Set cached data with TTL. Default 300s (5 min)."""
    try:
        rc = get_redis()
        if not rc:
            return
        key = cache_key(school_id, resource, resource_id)
        await rc.setex(key, ttl, json.dumps(data, default=str))
    except Exception:
        pass


async def invalidate_cache(school_id: str, resource: str = "*"):
    """Invalidate cache for a school/resource pattern."""
    try:
        rc = get_redis()
        if not rc:
            return
        pattern = f"{school_id}:{resource}:*"
        async for key in rc.scan_iter(match=pattern):
            await rc.delete(key)
    except Exception:
        pass


async def invalidate_specific(school_id: str, resource: str, resource_id: str):
    """Invalidate a specific cache key."""
    try:
        rc = get_redis()
        if not rc:
            return
        key = cache_key(school_id, resource, resource_id)
        await rc.delete(key)
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Embedding Cache (RAG) — cached separately to avoid interfering with
# tool calling / internet research results
# ---------------------------------------------------------------------------

def _embedding_hash(text: str) -> str:
    """Generate a hash for embedding cache key."""
    return hashlib.md5(text.encode("utf-8")).hexdigest()


async def get_embedding_cache(school_id: str, text: str):
    """
    Get cached embedding for a text chunk.
    Returns None if not found (caller should generate embedding).
    """
    try:
        rc = get_redis()
        if not rc:
            return None
        h = _embedding_hash(text)
        key = f"{school_id}:embeddings:{h}"
        data = await rc.get(key)
        return json.loads(data) if data else None
    except Exception:
        return None


async def set_embedding_cache(school_id: str, text: str, embedding_data: dict, ttl: int = 86400):
    """
    Cache embedding data for a text chunk.
    Default TTL is 24h. Does NOT cache results from tool calls
    or internet research — those produce unique responses per call.
    Pass ttl=0 to skip caching (used for dynamic queries).
    """
    if ttl <= 0:
        return
    try:
        rc = get_redis()
        if not rc:
            return
        h = _embedding_hash(text)
        key = f"{school_id}:embeddings:{h}"
        await rc.setex(key, ttl, json.dumps(embedding_data, default=str))
    except Exception:
        pass


async def invalidate_embedding_cache(school_id: str):
    """Invalidate all embedding caches for a school."""
    await invalidate_cache(school_id, "embeddings")


# ---------------------------------------------------------------------------
# Event-driven cache invalidation helpers
# When a resource is updated (e.g. profile, homework), call these
# to clear related caches without waiting for TTL expiry.
# ---------------------------------------------------------------------------

async def on_profile_updated(school_id: str, user_id: str):
    """Called when a profile is updated — invalidate related caches."""
    await invalidate_specific(school_id, "profiles", user_id)
    await invalidate_cache(school_id, "teacher_*")
    await invalidate_cache(school_id, "student_*")


async def on_homework_changed(school_id: str):
    """Called when homework is created/updated/deleted."""
    await invalidate_cache(school_id, "homework:*")


async def on_attendance_marked(school_id: str):
    """Called when attendance is marked."""
    await invalidate_cache(school_id, "attendance:*")


async def on_results_changed(school_id: str, class_id: str = None):
    """Called when results are added/updated/deleted."""
    await invalidate_cache(school_id, "teacher_gradebook*")
    if class_id:
        await invalidate_cache(school_id, f"results:{class_id}")


async def on_fees_updated(school_id: str):
    """Called when fees/payments are updated."""
    await invalidate_cache(school_id, "fees:*")


async def on_course_progress_changed(school_id: str, student_id: str = None):
    """Called when course progress is updated."""
    await invalidate_cache(school_id, "course_progress:*")
    if student_id:
        await invalidate_specific(school_id, "course_progress", student_id)


async def on_notice_changed(school_id: str):
    """Called when notices are created/updated/deleted."""
    await invalidate_cache(school_id, "notices:*")


async def on_live_class_changed(school_id: str, teacher_id: str = None):
    """Called when live class status changes."""
    await invalidate_cache(school_id, "teacher_live_classes:*")
    if teacher_id:
        await invalidate_specific(school_id, "live_class_status", teacher_id)