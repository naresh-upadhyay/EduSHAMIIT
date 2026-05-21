from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import os

from app.api import auth, student, teacher, shared, chat, voice, image, iot, rag, payments, parent


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    print("EduSHAMIIT API starting up...")
    print("AI Assistant: Shami")
    yield
    print("EduSHAMIIT API shutting down...")


app = FastAPI(
    title="EduSHAMIIT API",
    description="Backend for EduSHAMIIT Academic App - Shami Innovation and Technologies LLP",
    version="1.0.0",
    lifespan=lifespan,
)

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
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
app.include_router(parent.router, prefix="/api/parent", tags=["Parent"])


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