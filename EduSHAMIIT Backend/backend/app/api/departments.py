"""
Standardized Departments Management API for EduSHAMIIT ERP.
Provides a unified Single Source of Truth (SSOT) endpoint for department lookups,
integrating with public.lookup_values and public.fn_get_standard_departments.
"""
from fastapi import APIRouter, HTTPException, Query, Request
from typing import Optional, List, Dict, Any
import logging
import asyncio
import psycopg2
from psycopg2.extras import RealDictCursor

from app.config import settings

logger = logging.getLogger(__name__)
router = APIRouter()


async def exec_sql(sql: str, params: tuple = (), fetch: bool = True) -> List[Dict[str, Any]]:
    """Execute raw parameterized SQL query asynchronously via psycopg2."""
    def _run():
        conn = psycopg2.connect(settings.DATABASE_URL, connect_timeout=5)
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(sql, params)
                if fetch:
                    rows = cur.fetchall()
                    conn.commit()
                    return [dict(r) for r in rows]
                else:
                    conn.commit()
                    return []
        except Exception as e:
            conn.rollback()
            raise e
        finally:
            conn.close()

    return await asyncio.to_thread(_run)


@router.get("", summary="Get Standardized Departments")
@router.get("/", summary="Get Standardized Departments")
async def get_standard_departments(
    request: Request,
    school_id: Optional[str] = Query(None),
):
    """
    Unified Single Source of Truth (SSOT) endpoint for institution departments.
    Resolves official departments backed by public.fn_get_standard_departments.
    Guarantees consistent, deduplicated department names across all ERP modules.
    Supports authenticated sessions, X-School-Id headers, and query parameters.
    """
    effective_school_id = school_id or request.headers.get("X-School-Id")
    if not effective_school_id:
        auth_header = request.headers.get("Authorization")
        if auth_header and auth_header.startswith("Bearer "):
            try:
                from app.middleware.auth import decode_token
                payload = await decode_token(auth_header.split(" ")[1])
                if payload:
                    effective_school_id = payload.get("school_id")
            except Exception:
                pass

    try:
        sql = "SELECT public.fn_get_standard_departments(%s::UUID) AS result;"
        rows = await exec_sql(sql, (effective_school_id,))
        if rows and rows[0].get("result"):
            return rows[0]["result"]
        raise HTTPException(status_code=500, detail="Failed to retrieve departments")
    except Exception as e:
        logger.error(f"[Departments] Failed to retrieve departments: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))
