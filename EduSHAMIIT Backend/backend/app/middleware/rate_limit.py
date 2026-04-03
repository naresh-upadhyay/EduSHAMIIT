from fastapi import HTTPException
import redis
import os
import time

_redis_client = None


def get_redis():
    global _redis_client
    if _redis_client is None:
        redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
        _redis_client = redis.Redis.from_url(redis_url, decode_responses=True)
    return _redis_client


async def rate_limit(user_id: str, limit: int = 20, window: int = 86400):
    """Rate limit AI queries per user per day."""
    try:
        rc = get_redis()
        key = f"rate_limit:{user_id}"
        current = rc.get(key)

        if current and int(current) >= limit:
            raise HTTPException(
                status_code=429,
                detail=f"Daily AI query limit reached ({limit}/day). Try again tomorrow."
            )

        pipe = rc.pipeline()
        pipe.incr(key)
        pipe.expire(key, window)
        pipe.execute()
    except HTTPException:
        raise
    except Exception:
        # If Redis is down, allow the request
        pass


async def rate_limit_api(ip: str, limit: int = 60, window: int = 60):
    """Rate limit API requests per IP per minute."""
    try:
        rc = get_redis()
        key = f"api_rate:{ip}"
        current = rc.get(key)

        if current and int(current) >= limit:
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please slow down."
            )

        pipe = rc.pipeline()
        pipe.incr(key)
        pipe.expire(key, window)
        pipe.execute()
    except HTTPException:
        raise
    except Exception:
        pass