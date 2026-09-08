from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import os
import time
import asyncio

from app.api import auth, student, teacher, shared, chat, voice, image, iot, rag, payments, v1_payments, v1_edushamiit_pay, v1_payment_gateways, students_admin, teachers_admin, documents, calls, live_classes, superadmin, audit_logs, tickets, announcements, system_config, insights, contact, alerts, transport, gis, calendar, notices, lookups, classes, attendance, finance


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    print("EduSHAMIIT API starting up...")
    print("AI Assistant: Shami")
    
    # Synchronize Supabase Vault secrets into environment variables and start scheduler
    try:
        from app.services.supabase_client import start_vault_sync_scheduler
        import asyncio
        asyncio.create_task(start_vault_sync_scheduler(15))
    except Exception as e:
        print(f"[Lifespan] Failed to start vault sync scheduler: {e}", flush=True)

    try:
        from app.services.minio_client import minio_client, cleanup_orphaned_recordings_from_storage
        minio_client.ensure_bucket_and_public_policy()
        
        # Run orphaned recordings cleanup asynchronously in background at startup
        import asyncio
        asyncio.create_task(cleanup_orphaned_recordings_from_storage())
        
        # Run expired exams auto-submit scheduler task
        from app.services.exam_cleanup import start_exam_cleanup_scheduler
        asyncio.create_task(start_exam_cleanup_scheduler(30))
    except Exception as e:
        print(f"[MinIO] Bucket initialization/cleanup/scheduler failed: {e}")
    yield
    print("EduSHAMIIT API shutting down...")


app = FastAPI(
    title="EduSHAMIIT API",
    description="Backend for EduSHAMIIT Academic App - Shami Innovation and Technologies LLP",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def log_api_request_to_db(path: str, method: str, status_code: int, response_time_ms: float, ip_address: str, user_id: str = None):
    try:
        from app.services.supabase_client import get_supabase
        sb = get_supabase()
        await sb.table("api_request_logs").insert({
            "path": path,
            "method": method,
            "status_code": status_code,
            "response_time_ms": response_time_ms,
            "ip_address": ip_address,
            "user_id": user_id
        }).aexecute()
    except Exception as e:
        print(f"[API Gateway Logging] Failed to save log: {e}", flush=True)

@app.middleware("http")
async def api_gateway_logging_middleware(request: Request, call_next):
    path = request.url.path
    if not path.startswith("/api/"):
        return await call_next(request)
        
    if "gateway" in path:
        return await call_next(request)

    start_time = time.time()
    try:
        response = await call_next(request)
        status_code = response.status_code if hasattr(response, "status_code") else 200
        return response
    except Exception as e:
        status_code = 500
        raise e
    finally:
        process_time = (time.time() - start_time) * 1000.0
        ip_address = request.client.host if request.client else "unknown"
        user_id = None
        try:
            from app.middleware.auth import get_current_user_optional
            user = await get_current_user_optional(request)
            if user:
                user_id = user.get("id")
        except Exception:
            pass
            
        asyncio.create_task(log_api_request_to_db(
            path=path,
            method=request.method,
            status_code=status_code,
            response_time_ms=process_time,
            ip_address=ip_address,
            user_id=user_id
        ))

class AuditLoggingMiddleware:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        path = scope.get("path", "")
        if not path.startswith("/api/"):
            await self.app(scope, receive, send)
            return

        method = scope.get("method", "")
        if method == "OPTIONS":
            await self.app(scope, receive, send)
            return

        is_write = method in ("POST", "PUT", "PATCH", "DELETE")
        is_auth = any(p in path for p in ["login", "logout", "send-login-otp"])
        is_audit_action = is_write or is_auth or "export" in path or "backup" in path

        if not is_audit_action:
            await self.app(scope, receive, send)
            return

        body_bytes = b""
        async def wrapped_receive():
            nonlocal body_bytes
            message = await receive()
            if message["type"] == "http.request":
                body = message.get("body", b"")
                if body:
                    body_bytes += body
            return message

        status_code = 200
        async def wrapped_send(message):
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message.get("status", 200)
            await send(message)

        try:
            await self.app(scope, wrapped_receive, wrapped_send)
        except Exception as e:
            status_code = 500
            raise e
        finally:
            request = Request(scope, wrapped_receive)
            
            body_json = {}
            if body_bytes:
                try:
                    body_json = json.loads(body_bytes.decode("utf-8"))
                except Exception:
                    pass

            from app.api.audit_logs import sanitize_body
            sanitized_body = sanitize_body(body_json) if body_json else {}

            ip_address = request.client.host if request.client else "unknown"
            user_agent = request.headers.get("user-agent", "unknown")

            user_id = None
            school_id = None
            try:
                from app.middleware.auth import get_current_user_optional
                user = await get_current_user_optional(request)
                if user:
                    user_id = user.get("id")
                    school_id = user.get("school_id")
            except Exception:
                pass

            from app.api.audit_logs import log_audit_event_to_db
            asyncio.create_task(log_audit_event_to_db(
                school_id=school_id,
                user_id=user_id,
                ip_address=ip_address,
                user_agent=user_agent,
                path=path,
                method=method,
                status_code=status_code,
                body_json=sanitized_body
            ))

@app.middleware("http")
async def add_request_host_middleware(request: Request, call_next):
    proto = request.headers.get("X-Forwarded-Proto", request.url.scheme)
    host = request.headers.get("Host", request.url.netloc)
    host_str = f"{proto}://{host}"
    
    from app.middleware.auth import set_request_host, reset_request_host
    token = set_request_host(host_str)
    try:
        response = await call_next(request)
    finally:
        reset_request_host(token)
    return response

_MODULES_CACHE = {"data": [], "timestamp": 0}
_SCHOOL_TOGGLES_CACHE = {} # {school_id: (data, timestamp)}

@app.middleware("http")
async def enforce_modules_middleware(request: Request, call_next):
    path = request.url.path
    if not path.startswith("/api/"):
        return await call_next(request)

    # Exclude open/unauthenticated endpoints and modules config endpoints
    if any(p in path for p in ["/api/auth", "/health", "/api/admin/schools/modules/all", "/api/contact/submit"]):
        return await call_next(request)

    try:
        from app.services.supabase_client import get_supabase
        from fastapi.responses import JSONResponse
        
        now = time.time()
        global _MODULES_CACHE, _SCHOOL_TOGGLES_CACHE

        # 1. High-Speed TTL In-Memory Cache for Modules Configuration (30-second TTL)
        if now - _MODULES_CACHE["timestamp"] < 30 and _MODULES_CACHE["data"]:
            modules = _MODULES_CACHE["data"]
        else:
            sb = get_supabase()
            modules_res = await sb.table("modules").select("id, endpoints, is_enabled").aexecute()
            modules = modules_res.data or []
            _MODULES_CACHE = {"data": modules, "timestamp": now}

        # Find if global module is disabled
        disabled_endpoints = []
        for m in modules:
            if not m.get("is_enabled", True):
                endpoints = m.get("endpoints", [])
                if isinstance(endpoints, list):
                    disabled_endpoints.extend(endpoints)

        for pattern in disabled_endpoints:
            clean_pattern = pattern.rstrip("/")
            if path == clean_pattern or path.startswith(clean_pattern + "/"):
                return JSONResponse(
                    status_code=403,
                    content={"success": False, "detail": "Access Denied: This feature's module is currently disabled globally by Super Admin."}
                )

        # 2. High-Speed TTL In-Memory Cache for School Module Toggles (30-second TTL)
        from app.middleware.auth import get_current_user_optional
        user = await get_current_user_optional(request)
        if user and user.get("school_id"):
            school_id = user.get("school_id")
            if school_id in _SCHOOL_TOGGLES_CACHE and (now - _SCHOOL_TOGGLES_CACHE[school_id][1] < 30):
                module_toggles = _SCHOOL_TOGGLES_CACHE[school_id][0]
            else:
                sb = get_supabase()
                school_res = await sb.table("schools").select("module_toggles").eq("id", school_id).single().aexecute()
                school_data = school_res.data or {}
                module_toggles = school_data.get("module_toggles") or {}
                _SCHOOL_TOGGLES_CACHE[school_id] = (module_toggles, now)

            for m in modules:
                mod_id = m.get("id")
                if module_toggles.get(mod_id) is False:
                    endpoints = m.get("endpoints", [])
                    if isinstance(endpoints, list):
                        for pattern in endpoints:
                            clean_pattern = pattern.rstrip("/")
                            if path == clean_pattern or path.startswith(clean_pattern + "/"):
                                return JSONResponse(
                                    status_code=403,
                                    content={"success": False, "detail": "Access Denied: This feature is not enabled for your school."}
                                )
    except Exception as e:
        print(f"Error in enforce_modules_middleware: {e}", flush=True)

    return await call_next(request)


import traceback
from fastapi import Request, HTTPException
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"success": False, "detail": exc.detail}
    )

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    from pydantic import ValidationError as PydanticValidationError
    from fastapi.routing import APIRoute

    errors = exc.errors()

    # Detect if the error is a JSON decode / empty body error (no specific field path)
    is_json_decode = all(
        not [l for l in e.get("loc", []) if l != "body"]
        for e in errors
    ) and errors

    if is_json_decode:
        # Re-validate against the route's body model with an empty dict
        # so we can surface the actual missing required fields
        route = request.scope.get("route")
        if route and isinstance(route, APIRoute):
            for param in route.dependant.body_params:
                model_class = getattr(param.field_info, "annotation", None)
                if model_class is None:
                    model_class = param.annotation
                try:
                    if hasattr(model_class, "model_validate"):
                        model_class.model_validate({})
                    else:
                        model_class(**{})
                except PydanticValidationError as ve:
                    # Replace errors with the ones from empty-dict validation
                    errors = [
                        {
                            "type": e["type"],
                            "loc": ("body",) + tuple(e["loc"]),
                            "msg": e["msg"],
                            "input": e.get("input"),
                        }
                        for e in ve.errors()
                    ]
                break

    # Now format cleaned errors
    missing_fields = []
    other_errors = []

    for error in errors:
        loc_parts = [str(l) for l in error.get("loc", []) if l != "body"]
        field_path = ".".join(loc_parts)
        msg = error.get("msg", "")

        if not field_path:
            other_errors.append(f"Request Body: {msg}")
        elif "required" in msg.lower():
            missing_fields.append(field_path)
        else:
            other_errors.append(f"{field_path}: {msg}")

    detail_parts = []
    if missing_fields:
        detail_parts.append(f"Missing required fields: {', '.join(missing_fields)}")
    if other_errors:
        detail_parts.append("; ".join(other_errors))

    final_detail = " | ".join(detail_parts) if detail_parts else "Validation failed"

    return JSONResponse(
        status_code=422,
        content={"success": False, "detail": final_detail}
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "success": False,
            "detail": "Internal Server Error",
            "traceback": traceback.format_exc()
        }
    )

app.add_middleware(AuditLoggingMiddleware)

from fastapi.middleware.gzip import GZipMiddleware

app.add_middleware(GZipMiddleware, minimum_size=1000)

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex="https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


app.include_router(auth.router, prefix="/api/auth", tags=["Authentication"])
app.include_router(student.router, prefix="/api/student", tags=["Student"])
app.include_router(teacher.router, prefix="/api/teacher", tags=["Teacher"])
app.include_router(shared.router, prefix="/api", tags=["Shared"])
app.include_router(chat.router, prefix="/api/chat", tags=["AI Chat"])
app.include_router(voice.router, prefix="/api/chat", tags=["Voice"])
app.include_router(image.router, prefix="/api/chat", tags=["Image"])
app.include_router(iot.router, prefix="/api/iot", tags=["IoT"])
app.include_router(rag.router, prefix="/api/rag", tags=["RAG"])
app.include_router(payments.router, prefix="/api/payments", tags=["Payments"])
app.include_router(v1_payments.router, prefix="/api/v1/payments", tags=["PayU v1 Payments"])
app.include_router(documents.router, prefix="/api/documents", tags=["Documents"])
app.include_router(students_admin.router, prefix="/api/admin/students", tags=["Student Admin"])
app.include_router(teachers_admin.router, prefix="/api/admin/teachers", tags=["Teacher Admin"])
app.include_router(superadmin.router, prefix="/api/admin/schools", tags=["Schools Admin"])
app.include_router(superadmin.vault_router, prefix="/api/admin", tags=["Vault Admin"])
app.include_router(audit_logs.router, prefix="/api/admin", tags=["Audit Logs"])
app.include_router(tickets.router, prefix="/api/admin", tags=["Tickets"])
app.include_router(announcements.router, prefix="/api/admin/announcements", tags=["Announcements"])
app.include_router(alerts.router, prefix="/api/admin/system-alerts", tags=["System Alerts"])
app.include_router(system_config.router, prefix="/api/admin/system-config", tags=["System Configuration"])
app.include_router(insights.router, prefix="/api/admin/insights", tags=["AI Smart Insights"])
app.include_router(calls.router, prefix="/api", tags=["Calls"])
app.include_router(live_classes.router, prefix="/api", tags=["Live Classes"])
app.include_router(contact.router, prefix="/api/contact", tags=["Contact Us"])
app.include_router(transport.router, prefix="/api/transport", tags=["Vehicle Live Dashboard"])
app.include_router(gis.router, prefix="/api", tags=["GIS & Maps Microservice"])
app.include_router(calendar.router, prefix="/api", tags=["Universal Calendar"])
app.include_router(calendar.router, prefix="/api/v1", tags=["Universal Calendar v1"])
app.include_router(notices.router, prefix="/api/notices", tags=["Universal Notices & Circulars"])
app.include_router(lookups.router, prefix="/api/lookups", tags=["Universal Lookup Management"])
app.include_router(lookups.router, prefix="/api/v1/lookups", tags=["Universal Lookup Management v1"])
app.include_router(classes.router, prefix="/api/classes", tags=["Academic Class Management"])
app.include_router(classes.router, prefix="/api/v1/classes", tags=["Academic Class Management v1"])
app.include_router(classes.router, prefix="/api", tags=["Academic Class Management Core"])
app.include_router(attendance.router, prefix="/api/attendance", tags=["Attendance Management"])
app.include_router(attendance.router, prefix="/api/v1/attendance", tags=["Attendance Management v1"])
app.include_router(attendance.router, prefix="/api", tags=["Attendance Management Core"])
app.include_router(finance.router, prefix="/api/finance", tags=["Finance Management"])
app.include_router(finance.router, prefix="/api/v1/finance", tags=["Finance Management v1"])
app.include_router(finance.router, prefix="/api", tags=["Finance Management Core"])
app.include_router(v1_edushamiit_pay.router)
app.include_router(v1_payment_gateways.router)


@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "EduSHAMIIT API", "ai": "Shami"}


@app.get("/")
async def root():
    return {
        "message": "Welcome to EduSHAMIIT API",
        "ai_assistant": "Shami",
        "version": "1.0.0",
        "docs": "/docs",
    }


@app.on_event("startup")
async def start_automated_archiving_loop():
    """Automated background tasks for nightly log archiving (24h) and weekly database optimization (7 days)."""
    async def archive_scheduler():
        while True:
            try:
                from app.services.supabase_client import get_supabase
                sb = get_supabase()
                await sb.rpc("archive_old_audit_logs", {"p_retention_days": 90}).aexecute()
                print("[Auto Archive] Nightly audit log cleanup completed successfully.", flush=True)
            except Exception as e:
                print(f"[Auto Archive] Log cleanup background task skipped: {e}", flush=True)
            await asyncio.sleep(86400)

    async def optimization_scheduler():
        while True:
            try:
                from app.services.supabase_client import get_supabase
                sb = get_supabase()
                await sb.rpc("optimize_database_bloat_and_stats").aexecute()
                print("[Auto Optimization] Weekly database statistics optimization completed.", flush=True)
            except Exception as e:
                print(f"[Auto Optimization] Weekly optimization task skipped: {e}", flush=True)
            await asyncio.sleep(604800)

    asyncio.create_task(archive_scheduler())
    asyncio.create_task(optimization_scheduler())
