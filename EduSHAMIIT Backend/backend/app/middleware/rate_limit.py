from fastapi import HTTPException
import os
import time
from app.cache.redis_client import get_redis

_redis_client = None


async def rate_limit(user_id: str, limit: int = 20, window: int = 86400):
    """Rate limit AI queries per user per day."""
    try:
        rc = get_redis()
        if not rc:
            return  # Redis unavailable, allow request
        key = f"rate_limit:{user_id}"
        current = await rc.get(key)

        if current and int(current) >= limit:
            raise HTTPException(
                status_code=429,
                detail=f"Daily AI query limit reached ({limit}/day). Try again tomorrow."
            )

        pipe = rc.pipeline()
        pipe.incr(key)
        pipe.expire(key, window)
        await pipe.execute()
    except HTTPException:
        raise
    except Exception:
        # If Redis is down, allow the request
        pass


async def rate_limit_api(ip: str, limit: int = 60, window: int = 60):
    """Rate limit API requests per IP per minute."""
    try:
        rc = get_redis()
        if not rc:
            return  # Redis unavailable, allow request
        key = f"api_rate:{ip}"
        current = await rc.get(key)

        if current and int(current) >= limit:
            raise HTTPException(
                status_code=429,
                detail="Too many requests. Please slow down."
            )

        pipe = rc.pipeline()
        pipe.incr(key)
        pipe.expire(key, window)
        await pipe.execute()
    except HTTPException:
        raise
    except Exception:
        pass