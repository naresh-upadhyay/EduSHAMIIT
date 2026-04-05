from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import os

from app.api import auth, student, teacher, shared, chat, voice, image, iot, rag, payments


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
from fastapi import Request
from fastapi.responses import JSONResponse
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal Server Error", "traceback": traceback.format_exc()}
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