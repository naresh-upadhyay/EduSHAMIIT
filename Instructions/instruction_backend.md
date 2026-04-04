# EduSHAMIIT Backend — Complete Implementation Guide (Docker, Zero External Cost)

> **PURPOSE**: SELF-CONTAINED BLUEPRINT for building the EduSHAMIIT backend from scratch. Any AI agent reading ONLY this file should be able to implement the complete FastAPI backend with all 65+ screen endpoints, 40 AI tools, custom UPI payments, IoT device control, camera attendance, RAG pipeline, and Docker deployment.

> **PRODUCT**: EduSHAMIIT
> **AI ASSISTANT**: Shami (inspired by J.A.R.V.I.S. from Iron Man)
> **BACKEND**: Python 3.11+ / FastAPI / LangChain / Supabase (PostgreSQL)
> **DEPLOYMENT**: Docker Compose (local + VPS-ready)
> **PAYMENTS**: Custom UPI (zero third-party fees)
> **MULTI-SCHOOL**: All data scoped by `school_id`
> **MARKET**: Indian school/college SaaS by Shami Innovation and Technologies LLP

> **NOTE**: Database schemas, stored procedures, and RLS policies are documented in `instruction_database.md`. Flutter frontend is documented in `instruction.md`. This file focuses on Python backend, Docker, and all AI capabilities.

---

## 📋 TABLE OF CONTENTS

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Docker Setup](#2-docker-setup)
3. [FastAPI Project Structure](#3-fastapi-project-structure)
4. [Roles & Permissions](#4-roles--permissions)
5. [LLM Selection & Routing Strategy](#5-llm-selection--routing-strategy)
6. [LangChain Agent Architecture](#6-langchain-agent-architecture)
7. [All AI Tool Definitions (40 Tools)](#7-all-ai-tool-definitions-40-tools)
8. [Multimodal Input/Output](#8-multimodal-inputoutput)
9. [RAG Pipeline](#9-rag-pipeline)
10. [IoT Device Control (ESP32 + MQTT)](#10-iot-device-control-esp32--mqtt)
11. [Camera Attendance (Computer Vision)](#11-camera-attendance-computer-vision)
12. [Custom UPI Payment System](#12-custom-upi-payment-system)
13. [Authentication Endpoints](#13-authentication-endpoints)
14. [Student Screen Endpoints (29 Screens)](#14-student-screen-endpoints-29-screens)
15. [Teacher Screen Endpoints (29 Screens)](#15-teacher-screen-endpoints-29-screens)
16. [Shared Screen Endpoints (7 Screens)](#16-shared-screen-endpoints-7-screens)
17. [AI Chat Endpoints](#17-ai-chat-endpoints)
18. [IoT Control Endpoints](#18-iot-control-endpoints)
19. [RAG Pipeline Endpoints](#19-rag-pipeline-endpoints)
20. [Complete Python Implementation](#20-complete-python-implementation)
21. [Security & Auth](#21-security--auth)
22. [Environment Variables](#22-environment-variables)
23. [Cost Optimisation](#23-cost-optimisation)
24. [Build Order](#24-build-order)

---

## 1. SYSTEM ARCHITECTURE OVERVIEW

### 1.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              EduSHAMIIT Ecosystem                               │
│                        Shami Innovation and Technologies LLP                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │   Flutter    │  │   Flutter    │  │   Flutter    │  │   Web        │       │
│  │  Academic    │  │   Family     │  │  Admin Suite │  │  Dashboard   │       │
│  │  (Student/  │  │  (Parent)    │  │  (Principal/ │  │  (Reports)   │       │
│  │   Teacher)  │  │              │  │   Admin)     │  │              │       │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘       │
│         │                 │                 │                 │                │
│         └─────────────────┴─────────────────┴─────────────────┘                │
│                                    │ HTTPS                                     │
│                                    ▼                                           │
│                    ┌───────────────────────────────────┐                       │
│                    │       Nginx Load Balancer         │                       │
│                    │    (SSL, Rate Limiting, SSE)      │                       │
│                    └───────────────┬───────────────────┘                       │
│                                    │                                           │
│              ┌─────────────────────┼─────────────────────┐                     │
│              │                     │                     │                     │
│         ┌────┴────┐          ┌────┴────┐          ┌────┴────┐                │
│         │FastAPI 1│          │FastAPI 2│          │FastAPI N│                │
│         │ :8000   │          │ :8000   │          │ :8000   │                │
│         └────┬────┘          └────┬────┘          └────┬────┘                │
│              │                    │                     │                     │
│  ┌───────────┴────────────────────┴─────────────────────┴───────────┐        │
│  │                      Service Layer (Python)                       │        │
│  │                                                                   │        │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │        │
│  │  │   Shami AI  │  │   Payment   │  │    IoT      │              │        │
│  │  │   Agent     │  │   Service   │  │  Controller │              │        │
│  │  │ (LangChain) │  │  (UPI/RZP)  │  │   (MQTT)    │              │        │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │        │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │        │
│  │  │   Camera    │  │   RAG       │  │  WhatsApp   │              │        │
│  │  │ Attendance  │  │  Pipeline   │  │   Service   │              │        │
│  │  │ (YOLO+Face) │  │ (pgvector)  │  │ (Gupshup)   │              │        │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │        │
│  └──────────────────────────────────────────────────────────────────┘        │
│                                    │                                           │
│  ┌─────────────────────────────────┴─────────────────────────────────┐        │
│  │                      Data Layer                                    │        │
│  │                                                                    │        │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │        │
│  │  │  Supabase    │  │    Redis     │  │   RabbitMQ   │            │        │
│  │  │ (PostgreSQL) │  │   (Cache)    │  │   (Queue)    │            │        │
│  │  │  + pgvector  │  │              │  │              │            │        │
│  │  └──────────────┘  └──────────────┘  └──────────────┘            │        │
│  │                                                                    │        │
│  └────────────────────────────────────────────────────────────────────┘        │
│                                                                                 │
│  ┌──────────────────────────────────────────────────────────────────┐          │
│  │                    IoT Layer (On-Premise)                         │          │
│  │                                                                    │          │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │          │
│  │  │   Mosquitto  │  │   ESP32 x N  │  │   Camera     │            │          │
│  │  │  MQTT Broker │  │  Relay Boards│  │   (RTSP)     │            │          │
│  │  │   :1883      │  │  (Per Room)  │  │              │            │          │
│  │  └──────────────┘  └──────────────┘  └──────────────┘            │          │
│  └──────────────────────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Shami AI — The EduSHAMIIT Intelligence

Shami is the AI assistant for EduSHAMIIT, inspired by J.A.R.V.I.S. from Iron Man:
- **Proactive**: Surfaces insights users didn't ask for ("Sir, 3 teachers are absent today — shall I arrange substitutes?")
- **Multimodal**: Handles text, voice (Hindi + English), and images
- **Tool-powered**: 40 tools for students and teachers to access real school data
- **Context-aware**: Knows the user's role, class, school, and history
- **India-specific**: INR formatting (₹1,23,456), DD/MM/YYYY dates, Hinglish support

### 1.3 Microservices Responsibility

| Service | Responsibility | Port |
|---|---|---|
| `api-gateway` (nginx) | Load balancing, SSL, rate limiting, SSE proxy | 443/80 |
| `fastapi-app` | REST API, JWT auth, all business logic | 8000 |
| `shami-ai-agent` | LangChain agent, 40 tools, LLM routing | Integrated |
| `whisper-service` | Voice STT (Hindi + English) | 8009 |
| `camera-service` | YOLOv8 + DeepFace attendance | 8010 |
| `mosquitto` | MQTT broker for IoT devices | 1883 |
| `postgres` | Primary database + pgvector | 5432 |
| `redis` | Response caching, device state | 6379 |
| `rabbitmq` | Async task queue | 5672 |

### 1.4 Multi-School Data Flow

Every API request flows through this chain:
```
Flutter → JWT (contains school_id) → FastAPI extracts school_id → 
All DB queries filtered by school_id → Redis keys prefixed with school_id →
Response includes school_id for client-side scoping
```

---

## 2. DOCKER SETUP

### 2.1 docker-compose.yml

```yaml
version: '3.8'

services:
  # ============================================
  # DATABASE
  # ============================================
  postgres:
    image: supabase/postgres:15.1.0
    container_name: eduSHAMIIT-db
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: eduSHAMIIT
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: ${DB_PASSWORD:-eduSHAMIIT2026}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./sql/init.sql:/docker-entrypoint-initdb.d/init.sql
    command: >
      postgres
        -c wal_level=replica
        -c max_wal_senders=3
        -c shared_preload_libraries=vector
    networks:
      - eduSHAMIIT-net

  # ============================================
  # CACHE
  # ============================================
  redis:
    image: redis:7-alpine
    container_name: eduSHAMIIT-redis
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru
    networks:
      - eduSHAMIIT-net

  # ============================================
  # MESSAGE QUEUE
  # ============================================
  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: eduSHAMIIT-rabbitmq
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: eduSHAMIIT
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASSWORD:-eduSHAMIIT2026}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    networks:
      - eduSHAMIIT-net

  # ============================================
  # MQTT BROKER (IoT)
  # ============================================
  mosquitto:
    image: eclipse-mosquitto:2
    container_name: eduSHAMIIT-mqtt
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - mosquitto_data:/mosquitto/data
    networks:
      - eduSHAMIIT-net

  # ============================================
  # BACKEND API (3 replicas for scaling)
  # ============================================
  api-1:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: eduSHAMIIT-api-1
    environment:
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD:-eduSHAMIIT2026}@postgres:5432/eduSHAMIIT
      - REDIS_URL=redis://redis:6379
      - RABBITMQ_URL=amqp://eduSHAMIIT:${RABBITMQ_PASSWORD:-eduSHAMIIT2026}@rabbitmq:5672
      - SUPABASE_URL=http://postgres:5432
      - SUPABASE_JWT_SECRET=${JWT_SECRET:-eduSHAMIIT-jwt-secret-2026}
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
      - GOOGLE_API_KEY=${GOOGLE_API_KEY}
      - RAZORPAY_KEY_ID=${RAZORPAY_KEY_ID}
      - RAZORPAY_SECRET=${RAZORPAY_SECRET}
      - WHATSAPP_API_KEY=${WHATSAPP_API_KEY}
      - WHATSAPP_NUMBER=${WHATSAPP_NUMBER}
      - MQTT_BROKER_HOST=mosquitto
      - MQTT_BROKER_PORT=1883
      - UPI_MERCHANT_ID=${UPI_MERCHANT_ID:-eduSHAMIIT-school@upi}
      - UPI_MERCHANT_NAME=${UPI_MERCHANT_NAME:-EduSHAMIIT Academy}
    depends_on:
      - postgres
      - redis
      - rabbitmq
      - mosquitto
    networks:
      - eduSHAMIIT-net

  api-2:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: eduSHAMIIT-api-2
    environment:
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD:-eduSHAMIIT2026}@postgres:5432/eduSHAMIIT
      - REDIS_URL=redis://redis:6379
      - RABBITMQ_URL=amqp://eduSHAMIIT:${RABBITMQ_PASSWORD:-eduSHAMIIT2026}@rabbitmq:5672
      - SUPABASE_JWT_SECRET=${JWT_SECRET:-eduSHAMIIT-jwt-secret-2026}
      - MQTT_BROKER_HOST=mosquitto
      - MQTT_BROKER_PORT=1883
    depends_on:
      - postgres
      - redis
      - rabbitmq
      - mosquitto
    networks:
      - eduSHAMIIT-net

  api-3:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: eduSHAMIIT-api-3
    environment:
      - DATABASE_URL=postgresql://postgres:${DB_PASSWORD:-eduSHAMIIT2026}@postgres:5432/eduSHAMIIT
      - REDIS_URL=redis://redis:6379
      - RABBITMQ_URL=amqp://eduSHAMIIT:${RABBITMQ_PASSWORD:-eduSHAMIIT2026}@rabbitmq:5672
      - SUPABASE_JWT_SECRET=${JWT_SECRET:-eduSHAMIIT-jwt-secret-2026}
      - MQTT_BROKER_HOST=mosquitto
      - MQTT_BROKER_PORT=1883
    depends_on:
      - postgres
      - redis
      - rabbitmq
      - mosquitto
    networks:
      - eduSHAMIIT-net

  # ============================================
  # LOAD BALANCER
  # ============================================
  nginx:
    image: nginx:alpine
    container_name: eduSHAMIIT-gateway
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - api-1
      - api-2
      - api-3
    networks:
      - eduSHAMIIT-net

  # ============================================
  # AI SERVICES
  # ============================================
  whisper:
    build:
      context: ./services/whisper
      dockerfile: Dockerfile
    container_name: eduSHAMIIT-whisper
    ports:
      - "8009:8009"
    networks:
      - eduSHAMIIT-net

  camera:
    build:
      context: ./services/camera
      dockerfile: Dockerfile
    container_name: eduSHAMIIT-camera
    ports:
      - "8010:8010"
    networks:
      - eduSHAMIIT-net

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
  mosquitto_data:

networks:
  eduSHAMIIT-net:
    driver: bridge
```

### 2.2 Backend Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
```

### 2.3 requirements.txt

```
fastapi==0.109.0
uvicorn[standard]==0.27.0
supabase==2.3.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
httpx==0.26.0
redis==5.0.1
paho-mqtt==1.6.1
langchain==0.3.0
langchain-core==0.3.0
langchain-google-genai==2.0.0
langchain-anthropic==0.2.0
langchain-openai==0.2.0
langchain-community==0.3.0
openai==1.12.0
razorpay==1.4.1
PyPDF2==3.0.1
opencv-python-headless==4.9.0.80
deepface==0.0.80
ultralytics==8.1.0
python-dotenv==1.0.0
aiofiles==23.2.1
websockets==12.0
```

### 2.4 Nginx Configuration

```nginx
upstream eduSHAMIIT_api {
    least_conn;
    server api-1:8000;
    server api-2:8000;
    server api-3:8000;
}

# Rate limiting zones
limit_req_zone $binary_remote_addr zone=api:10m rate=30r/m;
limit_req_zone $binary_remote_addr zone=chat:10m rate=10r/m;

server {
    listen 80;
    server_name api.eduSHAMIIT.local;

    # Standard API endpoints
    location / {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://eduSHAMIIT_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
        proxy_cache off;
    }

    # AI Chat SSE endpoints (long-lived connections)
    location /api/chat/message {
        limit_req zone=chat burst=10 nodelay;
        proxy_pass http://eduSHAMIIT_api;
        proxy_buffering off;
        proxy_cache off;
        proxy_read_timeout 300s;
        proxy_set_header Connection '';
        proxy_http_version 1.1;
        chunked_transfer_encoding off;
    }

    # Voice upload endpoint (larger payloads)
    location /api/chat/voice {
        limit_req zone=chat burst=5 nodelay;
        client_max_body_size 25M;
        proxy_pass http://eduSHAMIIT_api;
        proxy_read_timeout 120s;
    }

    # Image upload endpoint
    location /api/chat/image {
        limit_req zone=chat burst=5 nodelay;
        client_max_body_size 15M;
        proxy_pass http://eduSHAMIIT_api;
        proxy_read_timeout 60s;
    }

    # RAG document ingestion (larger files)
    location /api/rag/ingest {
        limit_req zone=api burst=3 nodelay;
        client_max_body_size 50M;
        proxy_pass http://eduSHAMIIT_api;
        proxy_read_timeout 300s;
    }

    # IoT control (low latency)
    location /api/iot/ {
        limit_req zone=api burst=50 nodelay;
        proxy_pass http://eduSHAMIIT_api;
        proxy_read_timeout 10s;
    }
}
```

### 2.5 .env File

```bash
# ============================================
# DATABASE
# ============================================
DB_PASSWORD=eduSHAMIIT2026

# ============================================
# MESSAGE QUEUE
# ============================================
RABBITMQ_PASSWORD=eduSHAMIIT2026

# ============================================
# JWT
# ============================================
JWT_SECRET=eduSHAMIIT-jwt-secret-2026

# ============================================
# AI MODELS
# ============================================
OPENAI_API_KEY=sk-...                    # Whisper STT + Embeddings
ANTHROPIC_API_KEY=sk-ant-...             # Claude Haiku (tool calls)
GOOGLE_API_KEY=AIza...                   # Gemini Flash (Q&A, vision, generation)

# ============================================
# PAYMENTS
# ============================================
UPI_MERCHANT_ID=eduSHAMIIT-school@upi    # Your school's UPI ID
UPI_MERCHANT_NAME=EduSHAMIIT Academy
RAZORPAY_KEY_ID=rzp_live_...             # Optional: Razorpay integration
RAZORPAY_SECRET=...

# ============================================
# WHATSAPP
# ============================================
WHATSAPP_API_KEY=...                     # Gupshup API key
WHATSAPP_NUMBER=917XXXXXXXXX             # WhatsApp Business number

# ============================================
# IoT
# ============================================
MQTT_BROKER_HOST=mosquitto
MQTT_BROKER_PORT=1883

# ============================================
# TTS (Optional)
# ============================================
GOOGLE_TTS_API_KEY=...
ELEVENLABS_API_KEY=...

# ============================================
# APP
# ============================================
APP_ENV=production
```

### 2.6 Start Everything

```bash
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f api-1

# View AI agent logs
docker-compose logs -f api-1 | grep "Shami"

# Stop everything
docker-compose down
```

### 2.7 Push to VPS

```bash
# On your VPS
git clone https://github.com/your-repo/eduSHAMIIT-backend.git
cd eduSHAMIIT-backend
cp .env.example .env  # Edit with production values
docker-compose up -d
```

---

## 3. FASTAPI PROJECT STRUCTURE

```
backend/
├── app/
│   ├── main.py                    # FastAPI app + CORS + routers
│   ├── config.py                  # Environment config
│   ├── models.py                  # Pydantic schemas
│   │
│   ├── api/                       # REST API endpoints
│   │   ├── __init__.py
│   │   ├── auth.py                # Login, register, refresh
│   │   ├── student.py             # 29 student screen endpoints
│   │   ├── teacher.py             # 29 teacher screen endpoints
│   │   ├── shared.py              # Messages, notifications, settings
│   │   ├── chat.py                # AI chat (SSE streaming)
│   │   ├── voice.py               # Voice upload + transcription
│   │   ├── image.py               # Image analysis
│   │   ├── iot.py                 # Device control
│   │   ├── rag.py                 # Document ingestion
│   │   └── payments.py            # Custom UPI payments
│   │
│   ├── agents/                    # LangChain AI agent
│   │   ├── __init__.py
│   │   ├── shami_agent.py         # Main agent builder
│   │   ├── router.py              # Task detection → LLM routing
│   │   └── prompts.py             # Role-specific system prompts
│   │
│   ├── middleware/
│   │   ├── __init__.py
│   │   ├── auth.py                # JWT validation + school_id extraction
│   │   └── rate_limit.py          # Rate limiting
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── supabase_client.py     # Supabase singleton
│   │   ├── redis_client.py        # Cache layer
│   │   ├── rabbitmq_client.py     # Message queue
│   │   ├── langchain_agent.py     # AI agent orchestrator
│   │   ├── whisper_service.py     # Voice STT
│   │   ├── tts_service.py         # Text-to-speech
│   │   ├── vision_service.py      # Image analysis
│   │   ├── camera_service.py      # Face detection (on-premise)
│   │   ├── iot_controller.py      # MQTT device control
│   │   ├── upi_service.py         # Custom UPI payments
│   │   ├── whatsapp_service.py    # WhatsApp messaging
│   │   └── rag_service.py         # Document ingestion + search
│   │
│   ├── tools/                     # LangChain tools (40 total)
│   │   ├── __init__.py            # ALL_TOOLS assembly + filter
│   │   ├── student_tools.py       # 20 student AI tools
│   │   ├── teacher_tools.py       # 20 teacher AI tools
│   │   ├── fee_tools.py           # Fee + payment tools
│   │   ├── academic_tools.py      # Questions, lesson plans, timetable
│   │   ├── whatsapp_tools.py      # WhatsApp parent messaging
│   │   ├── iot_tools.py           # IoT control tools
│   │   └── rag_tools.py           # Curriculum search
│   │
│   └── cache/
│       └── redis_client.py        # Redis wrapper
│
├── esp32/
│   └── relay_controller/
│       └── relay_controller.ino   # ESP32 Arduino firmware
│
├── requirements.txt
├── Dockerfile
└── .env
```

### 3.1 main.py

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import auth, student, teacher, shared, chat, voice, image, iot, rag, payments

app = FastAPI(
    title="EduSHAMIIT API",
    description="Backend for EduSHAMIIT Academic App — Shami Innovation and Technologies LLP",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/auth")
app.include_router(student.router, prefix="/api/student")
app.include_router(teacher.router, prefix="/api/teacher")
app.include_router(shared.router, prefix="/api")
app.include_router(chat.router, prefix="/api/chat")
app.include_router(voice.router, prefix="/api/chat")
app.include_router(image.router, prefix="/api/chat")
app.include_router(iot.router, prefix="/api/iot")
app.include_router(rag.router, prefix="/api/rag")
app.include_router(payments.router, prefix="/api/payments")

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "EduSHAMIIT API", "ai": "Shami"}
```

---

## 4. ROLES & PERMISSIONS

EduSHAMIIT has 17 roles across 7 tiers. Shami's tool access is gated by role.

### 4.1 Role Hierarchy

| Tier | Role | App | Shami Capabilities |
|---|---|---|---|
| 0 — Platform | Super Admin | Admin Suite | Full access, all schools |
| 1 — Institution | Director | Admin Suite | Multi-school analytics, executive briefing |
| 2 — School Head | Principal | Admin Suite | School-wide reports, staff management |
| 3 — Academic | Teacher / HOD | Academic | Lesson plans, question paper, student insights |
| 3 — Academic | Student | Academic | Q&A, homework help, syllabus search (RAG) |
| 4 — Operations | Admin Manager | Admin Suite | Admissions, timetable, fee ops |
| 4 — Operations | Finance Officer | Admin Suite | Fee collection, Razorpay, defaulter list |
| 4 — Operations | HR Manager | Admin Suite | Staff attendance, payroll queries |
| 4 — Operations | Transport Coordinator | Admin Suite | Bus routes, driver management |
| 4 — Operations | Librarian | Admin Suite | Book catalog, issue/return |
| 4 — Operations | Sports Coordinator | Admin Suite | Events, student club management |
| 5 — Family | Parent | Family App | Child attendance, fees, results, WhatsApp alerts |
| 5 — Family | Admission Applicant | Family App | Application status, document queries |
| 5 — Family | Guest / Enquiry | Family App | School info chatbot (no auth required) |
| 6 — Support | Security Guard | Admin Suite | Gate QR, visitor log (no AI) |
| 6 — Support | Support Staff | Admin Suite | Task checklist (no AI) |
| 6 — Support | Bus Driver | Admin Suite | Route view, boarding log (no AI) |

### 4.2 Tool Permission Matrix

```python
# app/tools/__init__.py

ROLE_TOOLS = {
    "student": [
        "get_timetable", "get_homework", "get_fee_status", "get_attendance",
        "get_exam_info", "get_bus_location", "get_performance",
        "generate_study_plan", "explain_concept", "get_notifications",
        "get_library_status", "get_achievements", "get_events",
        "get_leaderboard", "submit_homework", "apply_leave",
        "get_notices", "answer_general", "generate_practice", "get_live_class"
    ],
    "teacher": [
        "search_curriculum", "get_student_profile", "get_attendance_report",
        "get_results", "generate_questions", "create_lesson_plan",
        "get_fee_status", "send_whatsapp", "send_bulk_whatsapp",
        "control_classroom_device", "get_classroom_device_status",
        "schedule_device_action", "get_class_students", "get_class_performance",
        "get_at_risk_students", "auto_grade_homework", "get_submission_status",
        "generate_remedial_plan", "create_notice", "get_attendance_stats",
        "get_teacher_schedule", "get_pending_tasks", "generate_report",
        "explain_pedagogy", "get_leave_balance", "get_salary_info",
        "upload_material", "get_exam_analytics", "answer_general"
    ],
    "parent": [
        "get_child_attendance", "get_child_results", "get_fee_status",
        "create_razorpay_link", "get_notifications"
    ],
    "principal": ["*"],  # All tools
    "admin": [
        "get_student_profile", "get_fee_status", "create_razorpay_link",
        "send_whatsapp", "control_classroom_device", "get_attendance_report"
    ],
    "finance": [
        "get_fee_status", "create_razorpay_link", "send_whatsapp"
    ],
    "guest": [
        "get_school_info", "search_curriculum"
    ],
}

def filter_tools_by_role(tools: list, role: str, school_id: str) -> list:
    """Filter tools based on user role."""
    allowed = ROLE_TOOLS.get(role, [])
    if "*" in allowed:
        return tools
    return [t for t in tools if t.name in allowed]
```

---

## 5. LLM SELECTION & ROUTING STRATEGY

**Core principle:** Never use one model for everything. Route each task to the cheapest capable model.

### 5.1 Models

| Model | Provider | Cost (input/output per 1M) | Use for |
|---|---|---|---|
| `gemini-1.5-flash-latest` | Google | $0.075 / $0.30 | Text Q&A, RAG, vision, question generation |
| `claude-haiku-4-5-20251001` | Anthropic | $0.80 / $4.00 | Tool calls, IoT JSON commands, DB operations |
| `whisper-1` | OpenAI | $0.006/min | Voice STT (Hindi + English) |
| Google TTS / ElevenLabs | Google / ElevenLabs | $0.000015/char | Voice TTS output |
| `text-embedding-3-small` | OpenAI | $0.02/1M | RAG embeddings (one-time per document) |

### 5.2 Routing Logic

```python
# app/agents/router.py
from enum import Enum
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_anthropic import ChatAnthropic

class TaskType(Enum):
    QA          = "qa"           # student Q&A, explanations
    GENERATION  = "generation"   # question papers, lesson plans
    TOOL_CALL   = "tool_call"    # DB ops, fee, attendance fetch
    IOT_CONTROL = "iot_control"  # device commands (fan, light, camera)
    VISION      = "vision"       # image analysis (diagrams, exam sheets)
    RAG         = "rag"          # curriculum document retrieval + answer

IOT_KEYWORDS = [
    "fan", "light", "lights", "camera", "turn on", "turn off",
    "switch", "projector", "ac", "bulb", "switch off", "band karo",
    "on karo", "off karo", "chalao", "bund karo"
]

TOOL_KEYWORDS = [
    "fee", "fees", "attendance", "marks", "result", "schedule",
    "timetable", "leave", "salary", "payment", "dues", "absent",
    "homework", "exam", "library", "bus", "transport", "notice"
]

def detect_task(message: str, has_image: bool = False) -> TaskType:
    """Detect the type of task from user message."""
    if has_image:
        return TaskType.VISION

    msg = message.lower()

    if any(k in msg for k in IOT_KEYWORDS):
        return TaskType.IOT_CONTROL

    if any(k in msg for k in TOOL_KEYWORDS):
        return TaskType.TOOL_CALL

    if any(k in msg for k in ["explain", "solve", "what is", "how does", "help me", "define"]):
        return TaskType.RAG

    return TaskType.QA

def get_llm(task: TaskType):
    """Return the appropriate LLM for this task type."""
    if task in (TaskType.TOOL_CALL, TaskType.IOT_CONTROL):
        # Claude Haiku for structured JSON tool calls
        return ChatAnthropic(
            model="claude-haiku-4-5-20251001",
            temperature=0.0,
            max_tokens=1024
        )
    # Gemini Flash for everything else (cheaper)
    return ChatGoogleGenerativeAI(
        model="gemini-1.5-flash-latest",
        temperature=0.3,
        max_tokens=2048
    )
```

---

## 6. LANGCHAIN AGENT ARCHITECTURE

### 6.1 Main Agent Builder

```python
# app/agents/shami_agent.py
from langchain.agents import create_tool_calling_agent, AgentExecutor
from langchain_core.prompts import ChatPromptTemplate, MessagesPlaceholder
from app.agents.router import detect_task, get_llm
from app.tools import get_all_tools, filter_tools_by_role
from app.agents.prompts import get_system_prompt

def build_agent(role: str, school_id: str, task_type: str = "qa") -> AgentExecutor:
    """
    Build a role-scoped, task-appropriate LangChain agent.

    Args:
        role:      User role string (e.g. 'teacher', 'student')
        school_id: UUID of the school — all queries scoped to this
        task_type: Detected task type for LLM selection
    """
    llm = get_llm(task_type)
    all_tools = get_all_tools(school_id)
    tools = filter_tools_by_role(all_tools, role, school_id)

    prompt = ChatPromptTemplate.from_messages([
        ("system", get_system_prompt(role, school_id)),
        MessagesPlaceholder("chat_history"),
        ("human", "{input}"),
        MessagesPlaceholder("agent_scratchpad"),
    ])

    agent = create_tool_calling_agent(llm, tools, prompt)
    return AgentExecutor(
        agent=agent,
        tools=tools,
        return_intermediate_steps=True,
        max_iterations=5,
        verbose=True,
    )

async def process_message(
    text: str = "",
    image_b64: str = None,
    audio_path: str = None,
    user=None,
    session_id: str = "",
) -> dict:
    """Single entry point for all message types."""

    # Step 1: Transcribe voice if provided
    if audio_path:
        from app.services.whisper_service import transcribe_file
        text = await transcribe_file(audio_path)

    # Step 2: Handle image directly (skip agent for pure vision tasks)
    if image_b64:
        from app.services.vision_service import analyze_image
        result = await analyze_image(image_b64, text)
        return {"type": "vision", "output": result, "tool_result": None}

    # Step 3: Detect task type and build agent
    task = detect_task(text)
    agent = build_agent(user.role, user.school_id, task.value)
    history = load_history(session_id)

    # Step 4: Run agent
    result = await agent.ainvoke({
        "input": text,
        "chat_history": history,
    })

    # Step 5: Save conversation
    await save_message(session_id, user.id, "user", text)
    await save_message(session_id, user.id, "assistant", result["output"],
                       tool_data=extract_tool_results(result))

    return {
        "type": "text",
        "output": result["output"],
        "tool_result": extract_tool_results(result),
        "intermediate_steps": result.get("intermediate_steps", []),
    }
```

### 6.2 System Prompts

```python
# app/agents/prompts.py

BASE_PROMPT = """You are Shami, the AI assistant for EduSHAMIIT — a school & college management platform by Shami Innovation and Technologies LLP.

IDENTITY:
- Name: Shami
- Tone: Warm, professional, concise
- Language: Match the user's language (Hindi or English). Hinglish is fine.
- Never invent student data. Always use tools to fetch real information.
- Format numbers in Indian style: ₹1,23,456 not ₹123456
- Dates in DD/MM/YYYY format

SCHOOL CONTEXT:
- School ID: {school_id}
- All data queries are automatically scoped to this school

TOOL USAGE RULES:
- Always call tools to fetch live data before answering factual questions
- For device control (fans/lights): confirm the action with the user if ambiguous
- For fee payment: always generate a UPI/Razorpay link, never ask for card details
- For WhatsApp: confirm message content with the user before sending

When you cannot help, say so clearly and suggest who can help instead.
"""

ROLE_CONTEXT = {
    "student": """You are talking to a student. Be encouraging and supportive.
Help them understand concepts, solve problems, and track their academic progress.
Suggest study strategies. Never give direct answers to exam questions — guide instead.""",

    "teacher": """You are talking to a teacher. Be efficient and professional.
Help generate lesson plans, question papers, analyze student performance, and automate admin tasks.
You can control classroom devices (fans, lights, projectors) on their behalf.""",

    "parent": """You are talking to a parent. Be reassuring and transparent.
Help them track their child's attendance, results, and fees.
You can generate payment links and send WhatsApp notifications.""",

    "principal": """You are talking to the school principal. Provide strategic insights.
Give school-wide analytics, staff summaries, and actionable recommendations.
You have access to all school data.""",

    "admin": """You are talking to an admin staff member. Be precise and task-oriented.
Help with admissions, fee collection, timetables, and parent communication.""",

    "finance": """You are talking to a finance officer.
Help with fee collection, pending dues, payment links, and payment reports.""",

    "guest": """You are talking to a prospective parent exploring the school.
Provide school information, admission process details, and answer FAQs.
Do not share private student data. Encourage them to apply.""",
}

def get_system_prompt(role: str, school_id: str) -> str:
    context = ROLE_CONTEXT.get(role, "You are a helpful school assistant.")
    return BASE_PROMPT.format(school_id=school_id) + "\n\n" + context
```

---

## 7. ALL AI TOOL DEFINITIONS (40 TOOLS)

### 7.1 Student Tools (20 tools)

```python
# app/tools/student_tools.py
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from app.cache.redis_client import get_cached, set_cached
from datetime import datetime, timedelta
import json

def get_student_tools(school_id: str) -> list:
    """Return all 20 student tools scoped to this school."""

    @tool
    def get_timetable(day: str = "today") -> str:
        """Get the student's class timetable for a specific day.
        Input: day name like 'monday', 'tuesday', etc., or 'today', or 'week' for full week.
        Use when student asks about their schedule, classes, or what they have today."""
        sb = get_supabase()
        profile = sb.table("profiles").select("class").eq("id", get_current_user_id()).single().execute().data
        student_class = profile["class"]

        day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5}
        query = sb.table("timetable")\
            .select("*, subjects(name, icon, color)")\
            .eq("school_id", school_id)\
            .eq("class", student_class)\
            .order("start_time")

        if day.lower() in day_map:
            query = query.eq("day_of_week", day_map[day.lower()])

        data = query.execute().data

        if not data:
            return f"No classes scheduled for {day}. Enjoy! 🎉"

        days_names = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday']
        buf = []
        current_day = None
        for item in data:
            dow = item['day_of_week']
            if current_day != dow:
                current_day = dow
                buf.append(f"\n📅 {days_names[dow]}:")
            if item.get('is_break'):
                buf.append(f"  ☕ {item.get('break_name','Break')} ({item['start_time']} - {item['end_time']})")
            elif item.get('is_free_period'):
                buf.append(f"  🆓 Free Period ({item['start_time']} - {item['end_time']})")
            else:
                subj = item.get('subjects',{})
                buf.append(f"  {subj.get('icon','📚')} {subj.get('name','Unknown')} - {item['start_time']} to {item['end_time']} (Room {item.get('room','TBD')})")

        return "\n".join(buf)

    @tool
    def get_homework(status: str = "pending") -> str:
        """Get homework assignments for the student.
        Input: 'pending', 'submitted', 'graded', or 'all'.
        Use when student asks about homework, assignments, or tasks."""
        sb = get_supabase()
        profile = sb.table("profiles").select("class").eq("id", get_current_user_id()).single().execute().data

        homework = sb.table("homework")\
            .select("*, subjects(name, icon)")\
            .eq("school_id", school_id)\
            .eq("target_class", profile["class"])\
            .eq("status", "active")\
            .order("due_date").execute().data

        submissions = sb.table("homework_submissions")\
            .select("homework_id, status, marks, grade, teacher_remarks")\
            .eq("student_id", get_current_user_id()).execute().data

        sub_map = {s["homework_id"]: s for s in submissions}

        filtered = []
        for hw in homework:
            sub = sub_map.get(hw["id"])
            hw_status = sub["status"] if sub else "pending"

            if status == "all" or (status == "pending" and not sub) or \
               (status == "submitted" and hw_status == "submitted") or \
               (status == "graded" and hw_status == "graded"):
                filtered.append({
                    "title": hw["title"],
                    "subject": hw.get("subjects",{}).get("name","Unknown"),
                    "icon": hw.get("subjects",{}).get("icon","📝"),
                    "due_date": hw["due_date"][:10],
                    "max_marks": hw.get("max_marks"),
                    "status": hw_status,
                    "marks": sub.get("marks") if sub else None,
                    "grade": sub.get("grade") if sub else None,
                })

        if not filtered:
            return f"No {status} homework found. 🎉"

        buf = [f"📝 Homework ({status.title()}):"]
        for hw in filtered:
            buf.append(f"  {hw['icon']} {hw['title']} ({hw['subject']})")
            buf.append(f"     Due: {hw['due_date']} | Max Marks: {hw['max_marks']}")
            if hw['status'] == 'graded':
                buf.append(f"     ✅ Graded: {hw['marks']}/{hw['max_marks']} ({hw['grade']})")
            elif hw['status'] == 'submitted':
                buf.append(f"     ⏳ Submitted, awaiting grading")

        return "\n".join(buf)

    @tool
    def get_fee_status() -> str:
        """Check fee balance, pending dues, and payment history for the student.
        Use when student or parent asks about fees, payment, dues, or outstanding amount."""
        sb = get_supabase()
        user_id = get_current_user_id()

        fees = sb.table("fees")\
            .select("*")\
            .eq("school_id", school_id)\
            .eq("student_id", user_id)\
            .order("due_date").execute().data

        payments = sb.table("payments")\
            .select("*")\
            .eq("school_id", school_id)\
            .eq("student_id", user_id)\
            .order("paid_at", ascending=False)\
            .limit(3).execute().data

        total_outstanding = sum(float(f["amount"]) - float(f.get("amount_paid",0)) for f in fees if f["status"] in ("pending","partial","overdue"))
        total_paid = sum(float(f.get("amount_paid",0)) for f in fees)

        buf = [f"💰 Fee Status:"]
        buf.append(f"  Total Outstanding: ₹{total_outstanding:,.2f}")
        buf.append(f"  Total Paid: ₹{total_paid:,.2f}")
        buf.append("")

        pending = [f for f in fees if f["status"] in ("pending","partial","overdue")]
        if pending:
            buf.append("📋 Pending Fees:")
            for f in pending:
                due = f.get("due_date","N/A")[:10]
                buf.append(f"  • {f.get('fee_type','Fee')}: ₹{float(f['amount']):,.2f} (Due: {due})")

        if payments:
            buf.append("\n✅ Recent Payments:")
            for p in payments:
                buf.append(f"  • ₹{float(p['amount']):,.2f} via {p.get('payment_method','N/A')} on {p.get('paid_at','N/A')[:10]}")

        return "\n".join(buf)

    @tool
    def get_attendance() -> str:
        """Get the student's attendance statistics including overall and subject-wise breakdown.
        Use when student asks about attendance, how many classes they've attended, or attendance percentage."""
        sb = get_supabase()
        user_id = get_current_user_id()

        attendance = sb.table("attendance")\
            .select("status, subjects(name)")\
            .eq("school_id", school_id)\
            .eq("student_id", user_id).execute().data

        if not attendance:
            return "No attendance records found yet."

        total = len(attendance)
        present = sum(1 for a in attendance if a["status"] == "present")
        absent = sum(1 for a in attendance if a["status"] == "absent")
        late = sum(1 for a in attendance if a["status"] == "late")
        pct = (present / total * 100) if total > 0 else 0

        # Subject-wise
        subject_wise = {}
        for a in attendance:
            subj = a.get("subjects",{}).get("name","Unknown")
            subject_wise.setdefault(subj, {"total":0,"present":0})
            subject_wise[subj]["total"] += 1
            if a["status"] == "present":
                subject_wise[subj]["present"] += 1

        buf = [f"📊 Attendance Report:"]
        buf.append(f"  Overall: {pct:.1f}% ({present} present, {absent} absent, {late} late out of {total} days)")
        buf.append("")
        buf.append("📚 Subject-wise:")
        for subj, data in subject_wise.items():
            subj_pct = (data["present"]/data["total"]*100) if data["total"]>0 else 0
            emoji = "✅" if subj_pct >= 75 else "⚠️" if subj_pct >= 50 else "❌"
            buf.append(f"  {emoji} {subj}: {subj_pct:.1f}% ({data['present']}/{data['total']})")

        return "\n".join(buf)

    @tool
    def get_exam_info() -> str:
        """Get upcoming exams for the student's class.
        Use when student asks about exams, test dates, exam schedule, or when exams are."""
        sb = get_supabase()
        profile = sb.table("profiles").select("class").eq("id", get_current_user_id()).single().execute().data

        exams = sb.table("exams")\
            .select("*, subjects(name, icon)")\
            .eq("school_id", school_id)\
            .contains("target_classes", f'["{profile["class"]}"]')\
            .gte("exam_date", datetime.now().date().isoformat())\
            .order("exam_date").execute().data

        if not exams:
            return "No upcoming exams scheduled. Use this time to prepare! 📚"

        buf = ["📝 Upcoming Exams:"]
        for ex in exams:
            subj = ex.get("subjects",{})
            buf.append(f"  {subj.get('icon','📝')} {ex['title']} ({subj.get('name','Unknown')})")
            buf.append(f"     📅 {ex['exam_date']} | ⏰ {ex.get('start_time','TBD')} | ⏱️ {ex.get('duration_minutes',90)} min")
            buf.append(f"     📍 {ex.get('venue','TBD')} | 📊 Total Marks: {ex.get('total_marks',100)}")

        return "\n".join(buf)

    @tool
    def get_bus_location() -> str:
        """Get the live location of the student's school bus.
        Use when student or parent asks about bus location, ETA, or when the bus will arrive."""
        sb = get_supabase()
        user_id = get_current_user_id()

        transport = sb.table("student_transport")\
            .select("*, bus_routes(*), bus_stops(stop_name)")\
            .eq("school_id", school_id)\
            .eq("student_id", user_id).maybe_single().execute().data

        if not transport:
            return "You are not assigned to any bus route. Contact the transport office."

        bus_location = sb.table("bus_locations")\
            .select("*")\
            .eq("school_id", school_id)\
            .eq("route_id", transport["route_id"])\
            .order("recorded_at", ascending=False)\
            .limit(1).maybe_single().execute().data

        route = transport.get("bus_routes",{})
        stop = transport.get("bus_stops",{})

        buf = [f"🚌 Bus Tracking:"]
        buf.append(f"  Route: {route.get('route_name','N/A')}")
        buf.append(f"  Bus: {route.get('bus_number','N/A')}")
        buf.append(f"  Your Stop: {stop.get('stop_name','N/A')}")

        if bus_location:
            eta = bus_location.get("eta_minutes","N/A")
            buf.append(f"  📍 Live Location: {bus_location['lat']:.4f}, {bus_location['lng']:.4f}")
            buf.append(f"  ⏱️ ETA: {eta} minutes")
            buf.append(f"  🚀 Speed: {bus_location.get('speed',0):.1f} km/h")
        else:
            buf.append("  ⚠️ Live location unavailable (bus may not have started)")

        return "\n".join(buf)

    @tool
    def get_performance() -> str:
        """Get the student's academic performance summary including scores, grades, and trends.
        Use when student asks about their overall performance, how they're doing, or their scores."""
        sb = get_supabase()
        user_id = get_current_user_id()

        results = sb.table("results")\
            .select("*, subjects(name, icon)")\
            .eq("school_id", school_id)\
            .eq("student_id", user_id)\
            .order("created_at", ascending=False)\
            .limit(20).execute().data

        if not results:
            return "No exam results available yet."

        total = sum(float(r.get("marks_obtained",0)) for r in results)
        max_total = sum(float(r.get("max_marks",100)) for r in results)
        avg = (total/max_total*100) if max_total > 0 else 0

        # Subject-wise averages
        subj_scores = {}
        for r in results:
            subj = r.get("subjects",{}).get("name","Unknown")
            icon = r.get("subjects",{}).get("icon","📚")
            subj_scores.setdefault(subj, {"total":0,"max":0,"icon":icon,"count":0})
            subj_scores[subj]["total"] += float(r.get("marks_obtained",0))
            subj_scores[subj]["max"] += float(r.get("max_marks",100))
            subj_scores[subj]["count"] += 1

        buf = [f"📊 Academic Performance:"]
        buf.append(f"  Overall Average: {avg:.1f}% ({_calculate_grade(avg)})")
        buf.append(f"  Total Exams: {len(results)}")
        buf.append("")
        buf.append("📚 Subject-wise Averages:")
        for subj, data in subj_scores.items():
            subj_avg = (data["total"]/data["max"]*100) if data["max"]>0 else 0
            buf.append(f"  {data['icon']} {subj}: {subj_avg:.1f}% ({_calculate_grade(subj_avg)})")

        return "\n".join(buf)

    @tool
    def generate_study_plan(weak_subjects: str = "") -> str:
        """Generate a personalized study plan for the student based on upcoming exams and weak areas.
        Input: comma-separated weak subjects (e.g. 'Physics, Chemistry') or empty for auto-detect.
        Use when student asks for study plan, how to prepare, or study tips."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.4)

        # Get upcoming exams
        sb = get_supabase()
        profile = sb.table("profiles").select("class").eq("id", get_current_user_id()).single().execute().data
        exams = sb.table("exams")\
            .select("title, exam_date, subjects(name)")\
            .eq("school_id", school_id)\
            .contains("target_classes", f'["{profile["class"]}"]')\
            .gte("exam_date", datetime.now().date().isoformat())\
            .order("exam_date").limit(5).execute().data

        exam_info = "\n".join([f"- {e['title']} ({e.get('subjects',{}).get('name','')}) on {e['exam_date']}" for e in exams])

        prompt = f"""Create a practical study plan for a Class {profile['class']} student.

Upcoming exams:
{exam_info}

Weak subjects: {weak_subjects if weak_subjects else 'Auto-detect from exam dates'}

Include:
- Daily schedule with specific time blocks
- Subject prioritization based on exam dates
- Break times and revision strategies
- Quick tips for each subject
- NCERT-aligned study materials to focus on

Keep it concise and actionable."""

        response = llm.invoke(prompt)
        return response.content

    @tool
    def explain_concept(concept: str, subject: str = "") -> str:
        """Explain an academic concept in simple terms with examples.
        Input: concept to explain, optionally with subject.
        Use when student asks 'what is', 'explain', 'how does', 'define' something."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.3)

        prompt = f"""Explain the concept: {concept}
Subject: {subject if subject else 'General'}

Requirements:
- Simple language suitable for school students
- Use analogies and real-life examples
- Include a quick memory trick
- Mention if it's important for exams
- Keep it under 200 words"""

        response = llm.invoke(prompt)
        return response.content

    @tool
    def get_notifications() -> str:
        """Get recent notifications for the student.
        Use when student asks about notifications, alerts, or updates."""
        sb = get_supabase()
        user_id = get_current_user_id()

        notifications = sb.table("notifications")\
            .select("*")\
            .eq("school_id", school_id)\
            .eq("user_id", user_id)\
            .order("created_at", ascending=False)\
            .limit(10).execute().data

        if not notifications:
            return "No new notifications. 🔔"

        buf = ["🔔 Recent Notifications:"]
        for n in notifications:
            read = "✅" if n.get("is_read") else "🔵"
            buf.append(f"  {read} {n['title']}")
            buf.append(f"     {n['body'][:80]}...")

        return "\n".join(buf)

    @tool
    def get_library_status() -> str:
        """Get the student's library book borrowing status.
        Use when student asks about library books, borrowed books, or due dates."""
        sb = get_supabase()
        user_id = get_current_user_id()

        borrows = sb.table("library_borrows")\
            .select("*, library_books(title, author)")\
            .eq("school_id", school_id)\
            .eq("student_id", user_id)\
            .in_("status", ["borrowed","overdue"])\
            .execute().data

        if not borrows:
            return "No books currently borrowed. Visit the library! 📚"

        buf = ["📚 Library Books:"]
        for b in borrows:
            book = b.get("library_books",{})
            status = "⚠️ OVERDUE" if b["status"] == "overdue" else "📖 Borrowed"
            buf.append(f"  {status}: {book.get('title','Unknown')} by {book.get('author','Unknown')}")
            buf.append(f"     Due: {b['due_at'][:10]} | Fine: ₹{b.get('fine_amount',0)}")

        return "\n".join(buf)

    @tool
    def get_achievements() -> str:
        """Get the student's earned achievements and badges.
        Use when student asks about achievements, badges, rewards, or progress."""
        sb = get_supabase()
        user_id = get_current_user_id()

        profile = sb.table("profiles").select("xp_points, learning_streak, best_streak").eq("id", user_id).single().execute().data
        achievements = sb.table("student_achievements")\
            .select("*, achievements(name, description, icon, rarity, xp_reward)")\
            .eq("school_id", school_id)\
            .eq("student_id", user_id)\
            .order("earned_at", ascending=False).execute().data

        buf = [f"🏆 Achievements:"]
        buf.append(f"  ⭐ XP Points: {profile.get('xp_points',0)}")
        buf.append(f"  🔥 Current Streak: {profile.get('learning_streak',0)} days")
        buf.append(f"  🏅 Best Streak: {profile.get('best_streak',0)} days")
        buf.append("")

        if achievements:
            buf.append("🎖️ Badges Earned:")
            for a in achievements:
                ach = a.get("achievements",{})
                buf.append(f"  {ach.get('icon','🏆')} {ach.get('name','Unknown')} ({ach.get('rarity','common')})")
                buf.append(f"     +{ach.get('xp_reward',0)} XP | {ach.get('description','')}")
        else:
            buf.append("No badges earned yet. Keep working! 💪")

        return "\n".join(buf)

    @tool
    def get_events() -> str:
        """Get upcoming school events.
        Use when student asks about events, competitions, functions, or activities."""
        sb = get_supabase()

        events = sb.table("events")\
            .select("*")\
            .eq("school_id", school_id)\
            .gte("event_date", datetime.now().date().isoformat())\
            .order("event_date").limit(10).execute().data

        if not events:
            return "No upcoming events. Stay tuned! 🎉"

        buf = ["🎉 Upcoming Events:"]
        for e in events:
            buf.append(f"  🎊 {e['title']}")
            buf.append(f"     📅 {e.get('event_date','TBD')} | ⏰ {e.get('event_time','TBD')}")
            buf.append(f"     📍 {e.get('venue','TBD')}")
            if e.get("max_participants"):
                buf.append(f"     👥 {e.get('current_participants',0)}/{e['max_participants']} registered")

        return "\n".join(buf)

    @tool
    def get_leaderboard() -> str:
        """Get the class leaderboard based on XP points.
        Use when student asks about leaderboard, ranking, or who has the most XP."""
        sb = get_supabase()
        profile = sb.table("profiles").select("class").eq("id", get_current_user_id()).single().execute().data

        students = sb.table("profiles")\
            .select("full_name, xp_points, learning_streak")\
            .eq("school_id", school_id)\
            .eq("class", profile["class"])\
            .eq("role", "student")\
            .order("xp_points", ascending=False)\
            .limit(10).execute().data

        buf = [f"🏆 Class {profile['class']} Leaderboard:"]
        medals = ["🥇","🥈","🥉"]
        for i, s in enumerate(students):
            medal = medals[i] if i < 3 else f"#{i+1}"
            buf.append(f"  {medal} {s['full_name']} — {s['xp_points']} XP (🔥 {s['learning_streak']} day streak)")

        return "\n".join(buf)

    @tool
    def submit_homework(homework_id: str, submission_text: str = "") -> str:
        """Submit homework assignment.
        Input: homework_id (from get_homework), submission_text (optional).
        Use when student wants to submit their homework."""
        sb = get_supabase()
        user_id = get_current_user_id()

        # Check if already submitted
        existing = sb.table("homework_submissions")\
            .select("id")\
            .eq("homework_id", homework_id)\
            .eq("student_id", user_id).maybe_single().execute()

        if existing.data:
            return "You've already submitted this homework! ✅"

        # Create submission
        sb.table("homework_submissions").insert({
            "school_id": school_id,
            "homework_id": homework_id,
            "student_id": user_id,
            "submission_text": submission_text,
            "status": "submitted",
        }).execute()

        return "Homework submitted successfully! 🎉 You earned +50 XP!"

    @tool
    def apply_leave(leave_type: str, start_date: str, end_date: str, reason: str) -> str:
        """Apply for leave.
        Input: leave_type ('sick','casual','other'), start_date (DD/MM/YYYY), end_date (DD/MM/YYYY), reason.
        Use when student wants to apply for leave or is absent."""
        sb = get_supabase()
        user_id = get_current_user_id()

        # Parse dates
        from datetime import datetime
        start = datetime.strptime(start_date, "%d/%m/%Y").date()
        end = datetime.strptime(end_date, "%d/%m/%Y").date()

        sb.table("leave_applications").insert({
            "school_id": school_id,
            "applicant_id": user_id,
            "applicant_role": "student",
            "leave_type": leave_type,
            "start_date": str(start),
            "end_date": str(end),
            "reason": reason,
            "status": "pending",
        }).execute()

        return f"Leave application submitted! 📝\nType: {leave_type}\nFrom: {start_date} To: {end_date}\nStatus: Pending approval"

    @tool
    def get_notices() -> str:
        """Get recent school notices and announcements.
        Use when student asks about notices, announcements, circulars, or updates."""
        sb = get_supabase()

        notices = sb.table("notices")\
            .select("*")\
            .eq("school_id", school_id)\
            .eq("status", "published")\
            .order("published_at", ascending=False)\
            .limit(10).execute().data

        if not notices:
            return "No notices at the moment. 📢"

        buf = ["📢 Recent Notices:"]
        for n in notices:
            urgent = "🚨 " if n.get("is_urgent") else ""
            buf.append(f"  {urgent}{n['title']}")
            buf.append(f"     {n['content'][:100]}...")
            buf.append(f"     📅 {n.get('published_at','')[:10]} | Category: {n.get('category','General')}")

        return "\n".join(buf)

    @tool
    def answer_general(question: str) -> str:
        """Answer general questions not related to school data.
        Use for general knowledge, fun facts, motivation, or off-topic questions."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.5)
        response = llm.invoke(f"Answer this question concisely: {question}")
        return response.content

    @tool
    def generate_practice(subject: str, topic: str, count: int = 5) -> str:
        """Generate practice questions for a subject and topic.
        Input: subject name, topic, number of questions (default 5).
        Use when student wants practice questions or revision material."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.7)
        prompt = f"""Generate {count} practice questions for {subject} on topic: {topic}.
Mix of MCQ and short answer. Include answers. NCERT aligned."""
        response = llm.invoke(prompt)
        return response.content

    @tool
    def get_live_class() -> str:
        """Get currently live or upcoming live classes.
        Use when student asks about live classes, online classes, or video sessions."""
        sb = get_supabase()
        profile = sb.table("profiles").select("class").eq("id", get_current_user_id()).single().execute().data

        classes = sb.table("live_classes")\
            .select("*, subjects(name, icon)")\
            .eq("school_id", school_id)\
            .eq("target_class", profile["class"])\
            .in_("status", ["live","scheduled"])\
            .order("scheduled_at").limit(5).execute().data

        if not classes:
            return "No live classes scheduled. 🎥"

        buf = ["🎥 Live Classes:"]
        for lc in classes:
            subj = lc.get("subjects",{})
            status = "🔴 LIVE NOW" if lc.get("is_live") else "📅 Scheduled"
            buf.append(f"  {status}: {subj.get('icon','🎥')} {lc['title']}")
            buf.append(f"     ⏰ {lc['scheduled_at'][:16]} | ⏱️ {lc.get('duration_minutes',60)} min")

        return "\n".join(buf)

    return [
        get_timetable, get_homework, get_fee_status, get_attendance,
        get_exam_info, get_bus_location, get_performance,
        generate_study_plan, explain_concept, get_notifications,
        get_library_status, get_achievements, get_events,
        get_leaderboard, submit_homework, apply_leave,
        get_notices, answer_general, generate_practice, get_live_class
    ]
```

### 7.2 Teacher Tools (20 tools)

```python
# app/tools/teacher_tools.py
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
from datetime import datetime
import json

def get_teacher_tools(school_id: str) -> list:
    """Return all 20 teacher tools scoped to this school."""

    @tool
    def get_class_students(class_name: str) -> str:
        """Get the list of students in a class.
        Input: class name like 'X-A', 'X-B'.
        Use when teacher asks about students in a class or needs the student list."""
        sb = get_supabase()

        students = sb.table("profiles")\
            .select("id, full_name, roll_number, xp_points, learning_streak")\
            .eq("school_id", school_id)\
            .eq("class", class_name)\
            .eq("role", "student")\
            .order("roll_number").execute().data

        if not students:
            return f"No students found in class {class_name}."

        buf = [f"👥 Class {class_name} Students ({len(students)} total):"]
        for s in students:
            buf.append(f"  {s.get('roll_number','?')}. {s['full_name']} (XP: {s.get('xp_points',0)}, Streak: {s.get('learning_streak',0)})")

        return "\n".join(buf)

    @tool
    def get_class_performance(class_name: str) -> str:
        """Get academic performance summary for a class including averages, top performers, and at-risk students.
        Input: class name like 'X-A'.
        Use when teacher asks about class performance, results, or how students are doing."""
        sb = get_supabase()

        # Get students
        students = sb.table("profiles")\
            .select("id, full_name")\
            .eq("school_id", school_id)\
            .eq("class", class_name)\
            .eq("role", "student").execute().data

        # Get results
        results = sb.table("results")\
            .select("student_id, marks_obtained, max_marks")\
            .eq("school_id", school_id)\
            .in_("student_id", [s["id"] for s in students]).execute().data

        # Get attendance
        attendance = sb.table("attendance")\
            .select("student_id, status")\
            .eq("school_id", school_id)\
            .in_("student_id", [s["id"] for s in students]).execute().data

        # Calculate per-student stats
        student_stats = {}
        for s in students:
            sid = s["id"]
            s_results = [r for r in results if r["student_id"] == sid]
            s_attendance = [a for a in attendance if a["student_id"] == sid]

            avg_score = 0
            if s_results:
                total = sum(float(r["marks_obtained"]) for r in s_results)
                max_total = sum(float(r["max_marks"]) for r in s_results)
                avg_score = (total/max_total*100) if max_total > 0 else 0

            att_pct = 0
            if s_attendance:
                present = sum(1 for a in s_attendance if a["status"] == "present")
                att_pct = (present/len(s_attendance)*100)

            student_stats[sid] = {"name": s["full_name"], "avg_score": avg_score, "att_pct": att_pct}

        # Sort by score
        sorted_students = sorted(student_stats.values(), key=lambda x: x["avg_score"], reverse=True)

        # Top 5 and at-risk
        top5 = sorted_students[:5]
        at_risk = [s for s in sorted_students if s["avg_score"] < 50 or s["att_pct"] < 75]

        class_avg = sum(s["avg_score"] for s in sorted_students) / len(sorted_students) if sorted_students else 0

        buf = [f"📊 Class {class_name} Performance:"]
        buf.append(f"  Total Students: {len(students)}")
        buf.append(f"  Class Average: {class_avg:.1f}%")
        buf.append("")
        buf.append("🏆 Top 5 Performers:")
        for i, s in enumerate(top5):
            buf.append(f"  #{i+1} {s['name']}: {s['avg_score']:.1f}%")

        if at_risk:
            buf.append("")
            buf.append("⚠️ At-Risk Students (Score < 50% or Attendance < 75%):")
            for s in at_risk:
                buf.append(f"  ❌ {s['name']}: Score {s['avg_score']:.1f}%, Attendance {s['att_pct']:.1f}%")

        return "\n".join(buf)

    @tool
    def get_at_risk_students(class_name: str) -> str:
        """Identify students who are at risk due to low scores or poor attendance.
        Input: class name like 'X-A'.
        Use when teacher asks about struggling students or who needs extra help."""
        sb = get_supabase()

        students = sb.table("profiles")\
            .select("id, full_name")\
            .eq("school_id", school_id)\
            .eq("class", class_name)\
            .eq("role", "student").execute().data

        student_ids = [s["id"] for s in students]

        results = sb.table("results")\
            .select("student_id, marks_obtained, max_marks")\
            .eq("school_id", school_id)\
            .in_("student_id", student_ids).execute().data

        attendance = sb.table("attendance")\
            .select("student_id, status")\
            .eq("school_id", school_id)\
            .in_("student_id", student_ids).execute().data

        at_risk = []
        for s in students:
            sid = s["id"]
            s_results = [r for r in results if r["student_id"] == sid]
            s_att = [a for a in attendance if a["student_id"] == sid]

            avg_score = 0
            if s_results:
                total = sum(float(r["marks_obtained"]) for r in s_results)
                max_total = sum(float(r["max_marks"]) for r in s_results)
                avg_score = (total/max_total*100) if max_total > 0 else 0

            att_pct = 0
            if s_att:
                present = sum(1 for a in s_att if a["status"] == "present")
                att_pct = (present/len(s_att)*100)

            issues = []
            if avg_score < 50:
                issues.append(f"Low score: {avg_score:.1f}%")
            if att_pct < 75:
                issues.append(f"Low attendance: {att_pct:.1f}%")

            if issues:
                at_risk.append({"name": s["full_name"], "issues": issues})

        if not at_risk:
            return f"No at-risk students in {class_name}. Great job! 🎉"

        buf = [f"⚠️ At-Risk Students in {class_name}:"]
        for s in at_risk:
            buf.append(f"  ❌ {s['name']}:")
            for issue in s["issues"]:
                buf.append(f"     • {issue}")

        return "\n".join(buf)

    @tool
    def generate_questions(subject: str, topic: str, grade: str, question_type: str = "mixed", count: int = 10, difficulty: str = "medium") -> str:
        """Generate exam or practice questions.
        Input: subject, topic, grade (e.g. 'Class 10'), question_type ('mcq'|'short_answer'|'long_answer'|'mixed'), count, difficulty ('easy'|'medium'|'hard').
        Use when teacher asks to generate questions, create question paper, or make quiz."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.7)
        prompt = f"""Generate {count} {difficulty} {question_type} questions for {grade} {subject} on topic: {topic}.

Format each question with:
- Question number
- Question text
- For MCQ: 4 options (A, B, C, D) and mark the correct answer
- For subjective: mention marks and expected answer length
- NCERT aligned where applicable

Output as clean numbered list."""
        response = llm.invoke(prompt)
        return response.content

    @tool
    def create_lesson_plan(subject: str, topic: str, grade: str, duration_minutes: int = 45) -> str:
        """Generate a structured lesson plan for a class.
        Input: subject, topic, grade, duration in minutes.
        Use when teacher asks for lesson plan or teaching plan."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.4)
        prompt = f"""Create a {duration_minutes}-minute lesson plan for:
Subject: {subject}
Topic: {topic}
Grade: {grade}

Include:
- Learning objectives
- Teaching materials needed
- Step-by-step activities with time allocations
- Q&A section
- Assessment questions
- Homework assignment
- NCERT curriculum aligned

Make it practical and easy to follow."""
        response = llm.invoke(prompt)
        return response.content

    @tool
    def auto_grade_homework(submission_id: str, marks: float, grade: str, remarks: str = "") -> str:
        """Grade a homework submission.
        Input: submission_id, marks awarded, grade (A+/A/B+/B/C/D/F), optional remarks.
        Use when teacher wants to grade a submission."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        sb.table("homework_submissions").update({
            "status": "graded",
            "marks": marks,
            "grade": grade,
            "teacher_remarks": remarks,
            "graded_by": teacher_id,
            "graded_at": datetime.now().isoformat(),
        }).eq("id", submission_id).eq("school_id", school_id).execute()

        return f"Submission graded! ✅\nMarks: {marks} | Grade: {grade}\nRemarks: {remarks}"

    @tool
    def get_submission_status(homework_id: str) -> str:
        """Get submission statistics for a homework assignment.
        Input: homework_id.
        Use when teacher asks who submitted, submission count, or grading status."""
        sb = get_supabase()

        homework = sb.table("homework").select("title, target_class, max_marks").eq("id", homework_id).single().execute().data
        submissions = sb.table("homework_submissions")\
            .select("*, profiles(full_name)")\
            .eq("homework_id", homework_id)\
            .eq("school_id", school_id).execute().data

        total_submitted = len(submissions)
        graded = sum(1 for s in submissions if s["status"] == "graded")
        pending = total_submitted - graded

        buf = [f"📝 Homework: {homework['title']} ({homework['target_class']})"]
        buf.append(f"  Total Submitted: {total_submitted}")
        buf.append(f"  ✅ Graded: {graded}")
        buf.append(f"  ⏳ Pending: {pending}")

        if pending > 0:
            buf.append("\n📋 Pending Submissions:")
            for s in submissions:
                if s["status"] != "graded":
                    student_name = s.get("profiles",{}).get("full_name","Unknown")
                    buf.append(f"  • {student_name} (submitted {s['submitted_at'][:10]})")

        return "\n".join(buf)

    @tool
    def generate_remedial_plan(student_name: str, weak_subjects: str) -> str:
        """Generate a remedial teaching plan for a struggling student.
        Input: student name, comma-separated weak subjects.
        Use when teacher asks for remedial plan for a weak student."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.4)
        prompt = f"""Create a remedial teaching plan for student: {student_name}
Weak subjects: {weak_subjects}

Include:
- Root cause analysis (common misconceptions)
- Step-by-step remediation strategy
- Practice exercises (easy to hard)
- Timeline (2-4 weeks)
- Progress checkpoints
- Parent communication tips

Make it practical for a teacher to implement."""
        response = llm.invoke(prompt)
        return response.content

    @tool
    def create_notice(title: str, content: str, category: str = "General", is_urgent: bool = False) -> str:
        """Create a school notice or announcement.
        Input: title, content, category ('Urgent'|'General'|'Event'|'Academic'), is_urgent (true/false).
        Use when teacher wants to create a notice or announcement."""
        sb = get_supabase()
        teacher_id = get_current_user_id()
        profile = sb.table("profiles").select("full_name").eq("id", teacher_id).single().execute().data

        sb.table("notices").insert({
            "school_id": school_id,
            "title": title,
            "content": content,
            "category": category,
            "author_id": teacher_id,
            "author_name": profile["full_name"],
            "is_urgent": is_urgent,
            "status": "published",
        }).execute()

        return f"Notice published! 📢\nTitle: {title}\nCategory: {category}\n{'🚨 Urgent' if is_urgent else ''}"

    @tool
    def get_attendance_stats(class_name: str, date: str = "today") -> str:
        """Get attendance statistics for a class on a specific date.
        Input: class name, date (DD/MM/YYYY or 'today').
        Use when teacher asks about attendance, who's absent, or attendance report."""
        sb = get_supabase()

        if date == "today":
            query_date = datetime.now().strftime("%Y-%m-%d")
        else:
            query_date = datetime.strptime(date, "%d/%m/%Y").strftime("%Y-%m-%d")

        attendance = sb.table("attendance")\
            .select("status, profiles(full_name, roll_number)")\
            .eq("school_id", school_id)\
            .eq("date", query_date)\
            .execute().data

        # Filter by class (need to join with profiles)
        students = sb.table("profiles")\
            .select("id, full_name, roll_number")\
            .eq("school_id", school_id)\
            .eq("class", class_name)\
            .eq("role", "student").execute().data

        student_ids = {s["id"]: s for s in students}
        class_attendance = [a for a in attendance if a.get("student_id") in student_ids]

        present = [a for a in class_attendance if a["status"] == "present"]
        absent = [a for a in class_attendance if a["status"] == "absent"]
        late = [a for a in class_attendance if a["status"] == "late"]

        buf = [f"📊 Attendance for {class_name} on {query_date}:"]
        buf.append(f"  ✅ Present: {len(present)}")
        buf.append(f"  ❌ Absent: {len(absent)}")
        buf.append(f"  ⏰ Late: {len(late)}")
        buf.append(f"  📈 Percentage: {(len(present)/len(class_attendance)*100) if class_attendance else 0:.1f}%")

        if absent:
            buf.append("\n❌ Absent Students:")
            for a in absent:
                student = student_ids.get(a["student_id"],{})
                buf.append(f"  • {student.get('full_name','Unknown')} (Roll: {student.get('roll_number','?')})")

        return "\n".join(buf)

    @tool
    def get_teacher_schedule(day: str = "today") -> str:
        """Get the teacher's own schedule for a day.
        Input: day name or 'today'.
        Use when teacher asks about their schedule, classes, or what they have today."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5}
        query = sb.table("timetable")\
            .select("*, subjects(name, icon)")\
            .eq("school_id", school_id)\
            .eq("teacher_id", teacher_id)\
            .order("start_time")

        if day.lower() in day_map:
            query = query.eq("day_of_week", day_map[day.lower()])

        schedule = query.execute().data

        if not schedule:
            return f"No classes scheduled for {day}. Free day! 🎉"

        buf = [f"📅 Your Schedule ({day.title()}):"]
        for item in schedule:
            subj = item.get("subjects",{})
            buf.append(f"  {subj.get('icon','📚')} {subj.get('name','Unknown')} — {item['start_time']} to {item['end_time']}")
            buf.append(f"     Class: {item.get('class','?')} | Room: {item.get('room','TBD')}")

        return "\n".join(buf)

    @tool
    def get_pending_tasks() -> str:
        """Get all pending tasks for the teacher including ungraded submissions and leave approvals.
        Use when teacher asks about pending work, tasks, or what needs attention."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        # Ungraded submissions
        homework = sb.table("homework").select("id, title").eq("teacher_id", teacher_id).eq("status", "active").execute().data
        ungraded = 0
        for hw in homework:
            subs = sb.table("homework_submissions").select("id").eq("homework_id", hw["id"]).eq("status", "submitted").execute().data
            ungraded += len(subs)

        # Pending leave approvals
        pending_leaves = sb.table("leave_applications").select("id").eq("school_id", school_id).eq("status", "pending").execute().data

        buf = ["📋 Your Pending Tasks:"]
        buf.append(f"  📝 Ungraded Submissions: {ungraded}")
        buf.append(f"  🏖️ Leave Approvals Pending: {len(pending_leaves)}")

        return "\n".join(buf)

    @tool
    def generate_report(class_name: str) -> str:
        """Generate a comprehensive performance report for a class.
        Input: class name.
        Use when teacher asks for class report or performance summary."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        # Get performance data
        perf = get_class_performance(class_name)

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.4)
        prompt = f"""Generate a professional class performance report based on this data:

{perf}

Include:
- Executive summary
- Key metrics
- Top performers
- Students needing attention
- Recommendations
- Action items for teachers

Format as a formal report."""
        response = llm.invoke(prompt)
        return response.content

    @tool
    def explain_pedagogy(topic: str) -> str:
        """Get teaching strategies and pedagogical advice for a topic.
        Input: topic or concept to teach.
        Use when teacher asks for teaching strategies or how to teach something."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.4)
        prompt = f"""Provide teaching strategies for: {topic}

Include:
- Differentiated instruction approaches
- Engagement techniques
- Assessment methods
- Common misconceptions and how to address them
- Real-world connections
- Technology integration ideas

Keep it practical for Indian school context."""
        response = llm.invoke(prompt)
        return response.content

    @tool
    def get_leave_balance() -> str:
        """Get the teacher's leave balance and history.
        Use when teacher asks about leave balance, remaining leaves, or leave history."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        leaves = sb.table("leave_applications")\
            .select("*")\
            .eq("school_id", school_id)\
            .eq("applicant_id", teacher_id)\
            .order("created_at", ascending=False)\
            .limit(10).execute().data

        approved = sum(1 for l in leaves if l["status"] == "approved")
        pending = sum(1 for l in leaves if l["status"] == "pending")
        rejected = sum(1 for l in leaves if l["status"] == "rejected")

        buf = ["🏖️ Leave Summary:"]
        buf.append(f"  ✅ Approved: {approved}")
        buf.append(f"  ⏳ Pending: {pending}")
        buf.append(f"  ❌ Rejected: {rejected}")
        buf.append(f"  📊 Total Applied: {len(leaves)}")

        if leaves:
            buf.append("\n📋 Recent Applications:")
            for l in leaves[:5]:
                status = {"approved":"✅","pending":"⏳","rejected":"❌"}.get(l["status"],"?")
                buf.append(f"  {status} {l['leave_type']}: {l['start_date']} to {l['end_date']}")

        return "\n".join(buf)

    @tool
    def get_salary_info(month: str = "") -> str:
        """Get salary information for the teacher.
        Input: month in 'YYYY-MM' format or empty for latest.
        Use when teacher asks about salary, pay, or compensation."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        query = sb.table("salary")\
            .select("*")\
            .eq("school_id", school_id)\
            .eq("teacher_id", teacher_id)\
            .order("month", ascending=False)

        if month:
            query = query.eq("month", month)

        salary = query.limit(1).maybe_single().execute().data

        if not salary:
            return "No salary records found."

        buf = [f"💰 Salary for {salary['month']}:"]
        buf.append(f"  Gross Salary: ₹{float(salary.get('gross_salary',0)):,.2f}")
        buf.append(f"  Basic Pay: ₹{float(salary.get('basic_pay',0)):,.2f}")
        buf.append(f"  HRA: ₹{float(salary.get('hra',0)):,.2f}")
        buf.append(f"  DA: ₹{float(salary.get('da',0)):,.2f}")
        buf.append(f"  Special Allowance: ₹{float(salary.get('special_allowance',0)):,.2f}")
        buf.append(f"  --- Deductions ---")
        buf.append(f"  PF: ₹{float(salary.get('pf_deduction',0)):,.2f}")
        buf.append(f"  TDS: ₹{float(salary.get('tds_deduction',0)):,.2f}")
        buf.append(f"  Professional Tax: ₹{float(salary.get('professional_tax',0)):,.2f}")
        buf.append(f"  ---")
        buf.append(f"  💵 Net Salary: ₹{float(salary.get('net_salary',0)):,.2f}")
        buf.append(f"  Status: {salary.get('status','pending').title()}")

        return "\n".join(buf)

    @tool
    def upload_material(title: str, material_type: str, target_class: str, description: str = "") -> str:
        """Create a study material entry.
        Input: title, material_type ('Notes'|'PPTs'|'Videos'|'Worksheets'), target_class, description.
        Use when teacher wants to upload or share study materials."""
        sb = get_supabase()
        teacher_id = get_current_user_id()

        sb.table("study_materials").insert({
            "school_id": school_id,
            "teacher_id": teacher_id,
            "title": title,
            "description": description,
            "material_type": material_type,
            "target_class": target_class,
        }).execute()

        return f"Material created! 📚\nTitle: {title}\nType: {material_type}\nClass: {target_class}\n\nYou can now upload files through the app."

    @tool
    def get_exam_analytics(exam_id: str) -> str:
        """Get analytics for a completed exam including score distribution and statistics.
        Input: exam_id.
        Use when teacher asks about exam results, analytics, or performance."""
        sb = get_supabase()

        sessions = sb.table("exam_sessions")\
            .select("*, profiles(full_name)")\
            .eq("exam_id", exam_id)\
            .eq("school_id", school_id)\
            .order("total_marks", ascending=False).execute().data

        if not sessions:
            return "No exam sessions found for this exam."

        scores = [float(s["total_marks"]) for s in sessions]
        avg = sum(scores)/len(scores) if scores else 0
        highest = max(scores) if scores else 0
        lowest = min(scores) if scores else 0

        buf = [f"📊 Exam Analytics:"]
        buf.append(f"  Total Students: {len(sessions)}")
        buf.append(f"  Average Score: {avg:.1f}")
        buf.append(f"  Highest: {highest:.1f}")
        buf.append(f"  Lowest: {lowest:.1f}")
        buf.append("")
        buf.append("🏆 Top 5:")
        for i, s in enumerate(sessions[:5]):
            name = s.get("profiles",{}).get("full_name","Unknown")
            buf.append(f"  #{i+1} {name}: {s['total_marks']:.1f} ({s.get('total_correct',0)} correct)")

        return "\n".join(buf)

    @tool
    def answer_general(question: str) -> str:
        """Answer general questions not related to school data.
        Use for general knowledge, teaching tips, or off-topic questions."""
        from langchain_google_genai import ChatGoogleGenerativeAI

        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.5)
        response = llm.invoke(f"Answer this question concisely: {question}")
        return response.content

    return [
        get_class_students, get_class_performance, get_at_risk_students,
        generate_questions, create_lesson_plan, auto_grade_homework,
        get_submission_status, generate_remedial_plan, create_notice,
        get_attendance_stats, get_teacher_schedule, get_pending_tasks,
        generate_report, explain_pedagogy, get_leave_balance,
        get_salary_info, upload_material, get_exam_analytics, answer_general
    ]
```

### 7.3 Fee Tools

```python
# app/tools/fee_tools.py
from langchain_core.tools import tool
from app.services.supabase_client import get_supabase
import os

def get_fee_tools(school_id: str) -> list:

    @tool
    def get_fee_status(student_id: str = "") -> str:
        """Get pending fee dues and payment history for a student.
        Input: student_id (optional, defaults to current user).
        Use when asking about fees, dues, or payment status."""
        sb = get_supabase()
        sid = student_id or get_current_user_id()

        result = sb.table("fees")\
            .select("amount, amount_paid, due_date, fee_type, status, academic_year")\
            .eq("school_id", school_id)\
            .eq("student_id", sid)\
            .order("due_date").execute().data

        if not result:
            return "No fee records found."

        total_due = sum(float(f["amount"]) - float(f.get("amount_paid",0)) for f in result if f["status"] in ("pending","partial","overdue"))

        buf = [f"💰 Fee Status:"]
        buf.append(f"  Total Outstanding: ₹{total_due:,.2f}")
        for f in result:
            if f["status"] in ("pending","partial","overdue"):
                buf.append(f"  • {f.get('fee_type','Fee')}: ₹{float(f['amount']):,.2f} (Due: {f.get('due_date','N/A')[:10]})")

        return "\n".join(buf)

    @tool
    def create_razorpay_link(student_id: str, amount: float, description: str = "") -> str:
        """Create a Razorpay payment link for fee collection.
        Input: student_id, amount in INR, description.
        Returns a short URL the parent can use to pay immediately."""
        import razorpay

        client = razorpay.Client(auth=(os.getenv("RAZORPAY_KEY_ID"), os.getenv("RAZORPAY_SECRET")))
        student = get_supabase().table("profiles")\
            .select("full_name, father_phone, email")\
            .eq("id", student_id).single().execute()

        s = student.data
        link = client.payment_link.create({
            "amount": int(amount * 100),
            "currency": "INR",
            "description": description or f"School fee — {s['full_name']}",
            "customer": {
                "name": s["full_name"],
                "contact": s.get("father_phone",""),
                "email": s.get("email",""),
            },
            "notify": {"sms": True, "email": True},
            "reminder_enable": True,
        })

        return f"Payment link created! 🔗\nAmount: ₹{amount:,.2f}\nURL: {link['short_url']}\nStudent: {s['full_name']}"

    return [get_fee_status, create_razorpay_link]
```

### 7.4 Academic Tools

```python
# app/tools/academic_tools.py
from langchain_core.tools import tool
from langchain_google_genai import ChatGoogleGenerativeAI
from app.services.supabase_client import get_supabase
from datetime import datetime

def get_academic_tools(school_id: str) -> list:

    @tool
    def generate_questions(subject: str, topic: str, grade: str, question_type: str = "mixed", count: int = 10, difficulty: str = "medium") -> str:
        """Generate exam/practice questions.
        subject: 'Mathematics' | 'Physics' | 'Hindi' | etc.
        topic: specific topic within subject
        grade: 'Class 10' | 'Class 12' etc.
        question_type: 'mcq' | 'short_answer' | 'long_answer' | 'mixed'
        difficulty: 'easy' | 'medium' | 'hard'"""
        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.7)
        prompt = f"""Generate {count} {difficulty} {question_type} questions for {grade} {subject} on topic: {topic}.

Format each question with:
- Question number
- Question text
- For MCQ: 4 options (A, B, C, D) and mark the correct answer
- For subjective: mention marks and expected answer length
- NCERT aligned where applicable

Output as clean numbered list."""
        response = llm.invoke(prompt)
        return response.content

    @tool
    def create_lesson_plan(subject: str, topic: str, grade: str, duration_minutes: int = 45) -> str:
        """Generate a structured lesson plan for a teacher.
        Returns a detailed plan with objectives, activities, and assessment."""
        llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.4)
        prompt = f"""Create a {duration_minutes}-minute lesson plan for:
Subject: {subject}
Topic: {topic}
Grade: {grade}

Include: Learning objectives, teaching materials, step-by-step activities,
Q&A section, assessment questions, homework assignment.
NCERT curriculum aligned. Practical and easy to follow."""
        response = llm.invoke(prompt)
        return response.content

    @tool
    def get_timetable(class_name: str, day: str = "today") -> str:
        """Get the class timetable for a specific day."""
        sb = get_supabase()
        if day == "today":
            day = datetime.now().strftime("%A")

        day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5}
        day_num = day_map.get(day.lower())

        query = sb.table("timetable")\
            .select("*, subjects(name, icon), profiles!teacher_id(full_name)")\
            .eq("school_id", school_id)\
            .eq("class", class_name)\
            .order("start_time")

        if day_num is not None:
            query = query.eq("day_of_week", day_num)

        result = query.execute().data

        if not result:
            return f"No classes scheduled for {class_name} on {day}."

        buf = [f"📅 {class_name} Timetable ({day}):"]
        for item in result:
            subj = item.get("subjects",{})
            teacher = item.get("profiles",{})
            buf.append(f"  {subj.get('icon','📚')} {subj.get('name','Unknown')} — {item['start_time']} to {item['end_time']}")
            buf.append(f"     Room: {item.get('room','TBD')} | Teacher: {teacher.get('full_name','TBD')}")

        return "\n".join(buf)

    return [generate_questions, create_lesson_plan, get_timetable]
```

### 7.5 WhatsApp Tools

```python
# app/tools/whatsapp_tools.py
from langchain_core.tools import tool
import requests
import os

def get_whatsapp_tools(school_id: str) -> list:

    @tool
    def send_whatsapp_message(phone: str, message: str) -> str:
        """Send a WhatsApp message to a parent.
        phone: Indian format without spaces (e.g. 919876543210)
        message: plain text message (max 1000 chars)"""
        response = requests.post(
            "https://api.gupshup.io/wa/api/v1/msg",
            headers={"apikey": os.getenv("WHATSAPP_API_KEY")},
            data={
                "channel": "whatsapp",
                "source": os.getenv("WHATSAPP_NUMBER"),
                "destination": phone,
                "message": message,
                "src.name": "EduSHAMIIT"
            }
        )
        return "Message sent successfully! ✅" if response.ok else f"Failed: {response.text}"

    @tool
    def send_bulk_whatsapp(class_name: str, message: str, filter_status: str = "all") -> str:
        """Send a WhatsApp message to all parents in a class.
        filter_status: 'all' | 'fee_pending' | 'absent_today'
        Replaces {student_name} in message with actual student name."""
        sb = get_supabase()
        students = sb.table("profiles")\
            .select("full_name, father_phone")\
            .eq("school_id", school_id)\
            .eq("class", class_name)\
            .eq("role", "student").execute().data

        sent_count = 0
        for s in students:
            phone = s.get("father_phone")
            if phone:
                personalized = message.replace("{student_name}", s["full_name"])
                resp = requests.post(
                    "https://api.gupshup.io/wa/api/v1/msg",
                    headers={"apikey": os.getenv("WHATSAPP_API_KEY")},
                    data={
                        "channel": "whatsapp",
                        "source": os.getenv("WHATSAPP_NUMBER"),
                        "destination": phone,
                        "message": personalized,
                        "src.name": "EduSHAMIIT"
                    }
                )
                if resp.ok:
                    sent_count += 1

        return f"WhatsApp sent to {sent_count}/{len(students)} parents in {class_name} 📱"

    return [send_whatsapp_message, send_bulk_whatsapp]
```

### 7.6 IoT Tools

```python
# app/tools/iot_tools.py
from langchain_core.tools import tool
from app.services.iot_controller import iot
from app.services.supabase_client import get_supabase
from datetime import datetime

def get_iot_tools(school_id: str) -> list:

    @tool
    def control_classroom_device(room: str, device: str, action: str) -> str:
        """Control an electrical device in a classroom over WiFi.
        room: classroom ID — e.g. 'class_10a', 'staff_room', 'library', 'principal_office'
        device: 'fan' | 'light1' | 'light2' | 'projector' | 'ac' | 'all' | 'all_lights'
        action: 'on' | 'off' | 'toggle'

        Examples:
          User: "Turn off the fan in 10A" → room='class_10a', device='fan', action='off'
          User: "Switch on lights in staffroom" → room='staff_room', device='all_lights', action='on'
          User: "Band karo sab lights class 9B mein" → room='class_9b', device='all_lights', action='off'"""
        result = iot.control_device(room, device, action)
        if result["ok"]:
            return f"Done! ✅ {device} in {room} has been turned {action}."
        return f"❌ Could not reach {room}. The device board may be offline."

    @tool
    def get_classroom_device_status(room: str) -> str:
        """Get current on/off status of all devices in a classroom."""
        status = iot.get_room_status(room)
        if not status:
            return f"Cannot fetch status for {room}. Device may be offline. ⚠️"

        buf = [f"🔌 Device Status in {room}:"]
        for device, state in status.items():
            emoji = "🟢" if state == "on" else "🔴"
            buf.append(f"  {emoji} {device}: {state}")

        return "\n".join(buf)

    @tool
    def schedule_device_action(room: str, device: str, action: str, time_str: str) -> str:
        """Schedule a device to turn on/off at a specific time.
        time_str: '14:30' (24h format) or 'HH:MM'
        Example: Schedule all lights in class 10A to turn off at 17:00"""
        sb = get_supabase()

        # Parse time
        scheduled_time = datetime.strptime(time_str, "%H:%M").replace(
            year=datetime.now().year,
            month=datetime.now().month,
            day=datetime.now().day
        )

        sb.table("iot_scheduled_actions").insert({
            "school_id": school_id,
            "room_id": room,
            "device": device,
            "action": action,
            "scheduled_time": scheduled_time.isoformat(),
            "status": "pending",
        }).execute()

        return f"⏰ Scheduled: {device} in {room} will {action} at {time_str}"

    return [control_classroom_device, get_classroom_device_status, schedule_device_action]
```

### 7.7 RAG Tools

```python
# app/tools/rag_tools.py
from langchain_core.tools import tool
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import SupabaseVectorStore
from app.services.supabase_client import get_supabase

def get_rag_tools(school_id: str) -> list:
    embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
    vector_store = SupabaseVectorStore(
        client=get_supabase(),
        embedding=embeddings,
        table_name="knowledge_base",
        query_name="match_documents",
    )

    @tool
    def search_curriculum(query: str, subject: str = "", grade: str = "") -> str:
        """
        Search the school's curriculum, textbooks, past papers, and study materials
        to find relevant content for answering academic questions.

        Use this tool FIRST for any academic question before generating an answer.
        query: the student's question in natural language
        subject: optional filter (e.g. 'Mathematics', 'Physics')
        grade: optional filter (e.g. 'Class 10', 'Class 12')
        """
        filter_dict = {"school_id": school_id}
        if subject:
            filter_dict["subject"] = subject
        if grade:
            filter_dict["grade"] = grade

        docs = vector_store.similarity_search(query, k=5, filter=filter_dict)
        if not docs:
            return "No relevant curriculum content found. Answering from general knowledge."

        context = "\n\n---\n\n".join([
            f"[Source: {d.metadata.get('source', 'Unknown')}]\n{d.page_content}"
            for d in docs
        ])
        return context

    return [search_curriculum]
```

### 7.8 ALL_TOOLS Assembly

```python
# app/tools/__init__.py
from app.tools.student_tools import get_student_tools
from app.tools.teacher_tools import get_teacher_tools
from app.tools.fee_tools import get_fee_tools
from app.tools.academic_tools import get_academic_tools
from app.tools.whatsapp_tools import get_whatsapp_tools
from app.tools.iot_tools import get_iot_tools
from app.tools.rag_tools import get_rag_tools

def get_all_tools(school_id: str) -> list:
    """Return all 40+ tools scoped to this school."""
    return [
        *get_student_tools(school_id),
        *get_teacher_tools(school_id),
        *get_fee_tools(school_id),
        *get_academic_tools(school_id),
        *get_whatsapp_tools(school_id),
        *get_iot_tools(school_id),
        *get_rag_tools(school_id),
    ]

# Role-based tool filtering (see Section 4.2)
ROLE_TOOLS = {
    "student": [
        "get_timetable", "get_homework", "get_fee_status", "get_attendance",
        "get_exam_info", "get_bus_location", "get_performance",
        "generate_study_plan", "explain_concept", "get_notifications",
        "get_library_status", "get_achievements", "get_events",
        "get_leaderboard", "submit_homework", "apply_leave",
        "get_notices", "answer_general", "generate_practice", "get_live_class"
    ],
    "teacher": [
        "search_curriculum", "get_student_profile", "get_attendance_report",
        "get_results", "generate_questions", "create_lesson_plan",
        "get_fee_status", "send_whatsapp", "send_bulk_whatsapp",
        "control_classroom_device", "get_classroom_device_status",
        "schedule_device_action", "get_class_students", "get_class_performance",
        "get_at_risk_students", "auto_grade_homework", "get_submission_status",
        "generate_remedial_plan", "create_notice", "get_attendance_stats",
        "get_teacher_schedule", "get_pending_tasks", "generate_report",
        "explain_pedagogy", "get_leave_balance", "get_salary_info",
        "upload_material", "get_exam_analytics", "answer_general"
    ],
    "parent": ["get_child_attendance", "get_child_results", "get_fee_status", "create_razorpay_link", "get_notifications"],
    "principal": ["*"],
    "admin": ["get_student_profile", "get_fee_status", "create_razorpay_link", "send_whatsapp", "control_classroom_device", "get_attendance_report"],
    "finance": ["get_fee_status", "create_razorpay_link", "send_whatsapp"],
    "guest": ["get_school_info", "search_curriculum"],
}

def filter_tools_by_role(tools: list, role: str, school_id: str) -> list:
    allowed = ROLE_TOOLS.get(role, [])
    if "*" in allowed:
        return tools
    return [t for t in tools if t.name in allowed]
```

---

## 8. MULTIMODAL INPUT/OUTPUT

### 8.1 Voice Input (Whisper STT)

```python
# app/services/whisper_service.py
from openai import AsyncOpenAI

oai = AsyncOpenAI()

async def transcribe(audio_bytes: bytes, filename: str, content_type: str) -> str:
    """Transcribe audio to text using OpenAI Whisper.
    Supports Hindi + English (auto-detected)."""
    transcript = await oai.audio.transcriptions.create(
        model="whisper-1",
        file=(filename, audio_bytes, content_type),
        language="hi",
        response_format="text"
    )
    return transcript

async def transcribe_file(file_path: str) -> str:
    """Transcribe audio file to text."""
    with open(file_path, "rb") as f:
        audio_bytes = f.read()
    return await transcribe(audio_bytes, "audio.m4a", "audio/m4a")
```

### 8.2 Image Input (Gemini Vision)

```python
# app/services/vision_service.py
import base64
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.messages import HumanMessage

async def analyze_image(image_b64: str, question: str = "Describe this image") -> str:
    """Analyze an image using Gemini Flash Vision.
    Supports: handwritten answers, diagrams, whiteboard photos, ID cards."""
    llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.3)
    msg = HumanMessage(content=[
        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
        {"type": "text", "text": question or "Describe and analyze this image in detail."}
    ])
    response = await llm.ainvoke([msg])
    return response.content
```

### 8.3 Text-to-Speech (Optional)

```python
# app/services/tts_service.py
from google.cloud import texttospeech
import os

async def synthesize_speech(text: str, language_code: str = "hi-IN") -> str:
    """Convert text to speech audio URL.
    Returns URL to the generated audio file."""
    client = texttospeech.TextToSpeechClient()

    input_text = texttospeech.SynthesisInput(text=text)
    voice = texttospeech.VoiceSelectionParams(
        language_code=language_code,
        ssml_gender=texttospeech.SsmlVoiceGender.NEUTRAL
    )
    audio_config = texttospeech.AudioConfig(
        audio_encoding=texttospeech.AudioEncoding.MP3
    )

    response = client.synthesize_speech(
        input=input_text, voice=voice, audio_config=audio_config
    )

    # Save to Supabase Storage and return URL
    filename = f"tts/{uuid.uuid4()}.mp3"
    # Upload to Supabase Storage
    # Return public URL
    return audio_url
```

---

## 9. RAG PIPELINE

### 9.1 Document Ingestion Service

```python
# app/services/rag_service.py
from langchain_community.document_loaders import PyPDFLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_openai import OpenAIEmbeddings
from langchain_community.vectorstores import SupabaseVectorStore
from app.services.supabase_client import get_supabase

embeddings = OpenAIEmbeddings(model="text-embedding-3-small")

async def ingest_document(
    pdf_bytes: bytes,
    school_id: str,
    subject: str,
    grade: str,
    source: str,
) -> int:
    """Load a PDF, chunk it, embed it, and store in Supabase pgvector."""
    import tempfile
    import os

    # Save bytes to temp file
    with tempfile.NamedTemporaryFile(delete=False, suffix=".pdf") as tmp:
        tmp.write(pdf_bytes)
        tmp_path = tmp.name

    try:
        loader = PyPDFLoader(tmp_path)
        docs = loader.load()

        splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
        chunks = splitter.split_documents(docs)

        for chunk in chunks:
            chunk.metadata.update({
                "school_id": school_id,
                "subject": subject,
                "grade": grade,
                "source": source,
            })

        vector_store = SupabaseVectorStore(
            client=get_supabase(),
            embedding=embeddings,
            table_name="knowledge_base",
            query_name="match_documents",
        )
        await vector_store.aadd_documents(chunks)

        return len(chunks)
    finally:
        os.unlink(tmp_path)
```

### 9.2 Similarity Search

```python
async def search_knowledge_base(
    query: str,
    school_id: str,
    subject: str = "",
    grade: str = "",
    k: int = 5,
) -> list:
    """Search the knowledge base for relevant content."""
    filter_dict = {"school_id": school_id}
    if subject:
        filter_dict["subject"] = subject
    if grade:
        filter_dict["grade"] = grade

    vector_store = SupabaseVectorStore(
        client=get_supabase(),
        embedding=embeddings,
        table_name="knowledge_base",
        query_name="match_documents",
    )

    docs = vector_store.similarity_search(query, k=k, filter=filter_dict)
    return docs
```

---

## 10. IoT DEVICE CONTROL (ESP32 + MQTT)

### 10.1 Hardware Specifications

- **Board:** ESP32 WROOM-32E + 4CH relay (220V AC powered, opto-isolated)
- **Cost:** ₹500–700 per room
- **Size:** ~85mm × 60mm (fits in standard switchboard gang box)
- **Channels:** 4 relays × 10A / 250V AC each
- **Relay logic:** Active LOW (GPIO LOW = relay ON, HIGH = relay OFF)
- **Available on:** Flipkart, Robu.in, etstore.in

**Channel mapping per room:**
```
CH1 → GPIO23 → Ceiling Fan
CH2 → GPIO22 → Tube Light Row 1 (front)
CH3 → GPIO21 → Tube Light Row 2 (back)
CH4 → GPIO19 → Projector / Smart TV
```

### 10.2 ESP32 Firmware (Arduino IDE)

Flash with Arduino IDE. Board: `ESP32 Dev Module`.

```cpp
// esp32/relay_controller/relay_controller.ino
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <WebServer.h>
#include <Preferences.h>

// ── Config — edit per device ────────────────────────────────
const char* WIFI_SSID   = "School_WiFi";
const char* WIFI_PASS   = "schoolwifipass";
const char* MQTT_SERVER = "192.168.1.100";   // Python server LAN IP
const char* DEVICE_ID   = "room_10a_board1"; // unique per room
const char* DEVICE_ROOM = "class_10a";

// ── Relay GPIO pins (active LOW) ─────────────────────────────
const int  RELAY_PINS[]   = {23, 22, 21, 19};
const char* RELAY_NAMES[] = {"fan", "light1", "light2", "projector"};
const int  NUM_RELAYS     = 4;

WiFiClient   espClient;
PubSubClient mqtt(espClient);
WebServer    http(80);
Preferences  prefs;

String buildStatusJson() {
  StaticJsonDocument<256> doc;
  doc["device_id"] = DEVICE_ID;
  doc["room_id"]   = DEVICE_ROOM;
  for (int i = 0; i < NUM_RELAYS; i++) {
    doc[RELAY_NAMES[i]] = digitalRead(RELAY_PINS[i]) == LOW ? "on" : "off";
  }
  String json;
  serializeJson(doc, json);
  return json;
}

void handleCommand(String device, String action) {
  for (int i = 0; i < NUM_RELAYS; i++) {
    if (device == RELAY_NAMES[i] || device == "all" ||
        (device == "all_lights" && i >= 1 && i <= 2)) {
      bool state = (action == "on");
      if (action == "toggle") state = digitalRead(RELAY_PINS[i]) == HIGH;
      digitalWrite(RELAY_PINS[i], state ? LOW : HIGH);  // active LOW!
      prefs.putBool(RELAY_NAMES[i], state);              // persist
    }
  }
  publishStatus();
}

void publishStatus() {
  String json = buildStatusJson();
  String topic = String("school/") + DEVICE_ROOM + "/status";
  mqtt.publish(topic.c_str(), json.c_str(), true);  // retained
}

void onMqttMessage(char* topic, byte* payload, unsigned int len) {
  StaticJsonDocument<128> doc;
  deserializeJson(doc, payload, len);
  String action = doc["action"].as<String>();
  String device = doc["device"].as<String>();
  handleCommand(device, action);
}

void setupHttpServer() {
  http.on("/status", HTTP_GET, []() {
    http.send(200, "application/json", buildStatusJson());
  });
  http.on("/control", HTTP_POST, []() {
    StaticJsonDocument<128> doc;
    deserializeJson(doc, http.arg("plain"));
    handleCommand(doc["device"], doc["action"]);
    http.send(200, "application/json", "{\"ok\":true}");
  });
  http.begin();
}

void setup() {
  for (int i = 0; i < NUM_RELAYS; i++) {
    pinMode(RELAY_PINS[i], OUTPUT);
    bool saved = prefs.getBool(RELAY_NAMES[i], false);
    digitalWrite(RELAY_PINS[i], saved ? LOW : HIGH);
  }
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  mqtt.setServer(MQTT_SERVER, 1883);
  mqtt.setCallback(onMqttMessage);
  setupHttpServer();
}

void loop() {
  if (!mqtt.connected()) reconnectMqtt();
  mqtt.loop();
  http.handleClient();
}

void reconnectMqtt() {
  if (mqtt.connect(DEVICE_ID)) {
    String topic = String("school/") + DEVICE_ROOM + "/control";
    mqtt.subscribe(topic.c_str());
    publishStatus();
  }
}
```

### 10.3 Python IoT Controller Service

```python
# app/services/iot_controller.py
import paho.mqtt.client as mqtt
import httpx
import json
from app.services.supabase_client import get_supabase

class IoTController:
    def __init__(self):
        self._mqtt = mqtt.Client(client_id="edushamiit-python")
        self._mqtt.on_message = self._on_status_update
        self._mqtt.connect("mosquitto", 1883)
        self._mqtt.subscribe("school/+/status")
        self._mqtt.loop_start()

    def control_device(self, room: str, device: str, action: str) -> dict:
        """Control a device via MQTT. Falls back to HTTP if MQTT fails."""
        payload = json.dumps({"device": device, "action": action})
        topic = f"school/{room}/control"
        result = self._mqtt.publish(topic, payload, qos=1)

        if result.rc == 0:
            self._log(room, device, action)
            return {"ok": True, "method": "mqtt"}
        return self._http_fallback(room, device, action)

    def _http_fallback(self, room, device, action) -> dict:
        """Fallback to direct HTTP if MQTT fails."""
        ip = self._get_device_ip(room)
        if not ip:
            return {"ok": False, "error": "device unreachable"}
        try:
            r = httpx.post(
                f"http://{ip}/control",
                json={"device": device, "action": action},
                timeout=3
            )
            return {"ok": r.status_code == 200, "method": "http"}
        except Exception:
            return {"ok": False, "error": "http timeout"}

    def get_room_status(self, room: str) -> dict:
        """Get current device status from a room."""
        ip = self._get_device_ip(room)
        if not ip:
            return {}
        try:
            r = httpx.get(f"http://{ip}/status", timeout=3)
            return r.json()
        except Exception:
            return {}

    def _get_device_ip(self, room: str) -> str | None:
        """Look up device IP from database."""
        result = get_supabase().table("iot_devices")\
            .select("ip_address")\
            .eq("room_id", room)\
            .single().execute()
        return result.data.get("ip_address") if result.data else None

    def _on_status_update(self, client, userdata, message):
        """Handle status updates from devices."""
        data = json.loads(message.payload)
        get_supabase().table("iot_device_states").upsert(data).execute()

    def _log(self, room, device, action):
        """Log control action to database."""
        get_supabase().table("iot_control_log").insert({
            "room_id": room,
            "device": device,
            "action": action,
            "triggered_by": "ai_assistant",
        }).execute()

# Singleton
iot = IoTController()
```

### 10.4 MQTT Broker Setup

```bash
# Docker (included in docker-compose.yml)
docker-compose up -d mosquitto

# Manual install on Ubuntu
sudo apt install mosquitto mosquitto-clients
sudo systemctl enable --now mosquitto

# Test
mosquitto_sub -t "school/class_10a/status"
mosquitto_pub -t "school/class_10a/control" -m '{"device":"fan","action":"on"}'
```

---

## 11. CAMERA ATTENDANCE (COMPUTER VISION)

**Privacy rule:** All face processing runs on a local Python server inside the school. No student face images are sent to any cloud API.

### 11.1 Hardware Requirements

- IP camera with RTSP support (₹2,000–5,000 each, 1 per classroom)
- Local mini-PC / NUC or spare laptop with NVIDIA GPU (RTX 3060 or better)
- Runs YOLOv8 + DeepFace locally

### 11.2 Camera Attendance Service

```python
# app/services/camera_attendance.py
import cv2
from deepface import DeepFace
from ultralytics import YOLO
from app.services.supabase_client import get_supabase
from datetime import datetime

yolo = YOLO("yolov8n.pt")  # nano model — fast, runs on CPU too

class ClassroomCamera:
    def __init__(self, rtsp_url: str, class_id: str, school_id: str):
        self.cap = cv2.VideoCapture(rtsp_url)
        self.class_id = class_id
        self.school_id = school_id
        self.face_db = f"/faces/{school_id}/{class_id}"

    async def take_attendance(self) -> dict:
        """Capture frame, detect faces, identify students, write attendance."""
        ret, frame = self.cap.read()
        if not ret:
            return {"error": "camera feed unavailable"}

        # Step 1: Count people with YOLO (fast)
        results = yolo.predict(frame, classes=[0], verbose=False)  # 0 = person
        headcount = len(results[0].boxes)

        # Step 2: Identify faces with DeepFace (slower but accurate)
        present_ids = []
        for box in results[0].boxes:
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            face_crop = frame[y1:y2, x1:x2]
            try:
                matches = DeepFace.find(
                    img_path=face_crop,
                    db_path=self.face_db,
                    model_name="ArcFace",
                    enforce_detection=False,
                    silent=True,
                )
                if matches and not matches[0].empty:
                    student_id = matches[0].iloc[0]["identity"].split("/")[-2]
                    present_ids.append(student_id)
            except Exception:
                pass

        # Step 3: Write to Supabase
        today = datetime.now().strftime("%Y-%m-%d")
        all_students = get_supabase().table("profiles")\
            .select("id").eq("class", self.class_id).eq("role", "student").execute()
        all_ids = [s["id"] for s in all_students.data]

        records = []
        for sid in all_ids:
            records.append({
                "student_id": sid,
                "school_id": self.school_id,
                "date": today,
                "status": "present" if sid in present_ids else "absent",
                "method": "camera_ai",
            })

        if records:
            get_supabase().table("attendance").upsert(records).execute()

        return {
            "headcount": headcount,
            "identified": len(present_ids),
            "present_ids": present_ids,
            "date": today,
        }
```

### 11.3 Enroll Student Faces

```python
# scripts/enroll_faces.py
import os
import shutil

def enroll_student(student_id: str, class_id: str, school_id: str, photo_path: str):
    """Save student face photo to local face database (one-time setup)."""
    face_dir = f"/faces/{school_id}/{class_id}/{student_id}"
    os.makedirs(face_dir, exist_ok=True)
    shutil.copy(photo_path, f"{face_dir}/face_01.jpg")
    print(f"Enrolled: {student_id} → {face_dir}")
```

---

## 12. CUSTOM UPI PAYMENT SYSTEM

### 12.1 How It Works

```
Student clicks "Pay Now" in Flutter
       ↓
Flutter calls POST /api/payments/create-upi-link
       ↓
Backend generates UPI deep link:
  upi://pay?pa=school@upi&pn=EduSHAMIIT&am=12500&tn=FEE-X-A-2026&tr=TXN-123456
       ↓
Flutter opens UPI app (GPay/PhonePe/Paytm)
       ↓
Student completes payment in UPI app
       ↓
UPI app sends callback to Flutter
       ↓
Flutter calls POST /api/payments/verify
       ↓
Backend verifies and updates payment status to 'success'
       ↓
Student sees "Payment Successful!" ✅
```

### 12.2 Create UPI Payment Link

```python
# app/api/payments.py
from fastapi import APIRouter, Depends, HTTPException
from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase
from app.services.upi_service import generate_upi_link
from datetime import datetime
import uuid

router = APIRouter()

@router.post("/create-upi-link")
async def create_upi_payment(
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Create a UPI payment link for fee payment.

    Request:
    {
        "fee_id": "uuid-fee-1",
        "amount": 12500.00,
        "description": "Tuition Fee Q2 2026"
    }
    """
    sb = get_supabase()

    fee_id = request.get("fee_id")
    amount = request.get("amount")
    description = request.get("description", "EduSHAMIIT Fee Payment")

    # Generate unique transaction ID
    transaction_id = f"EDU-{uuid.uuid4().hex[:12].upper()}"

    # Create payment record
    payment = sb.table("payments").insert({
        "school_id": school_id,
        "fee_id": fee_id,
        "student_id": user["id"],
        "amount": amount,
        "transaction_id": transaction_id,
        "status": "pending",
        "payment_method": "upi",
    }).execute()

    # Generate UPI deep link
    upi_link = generate_upi_link(
        merchant_id="eduSHAMIIT-school@upi",
        merchant_name="EduSHAMIIT Academy",
        amount=amount,
        transaction_id=transaction_id,
        description=description,
    )

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "payment_id": payment.data[0]["id"],
            "upi_link": upi_link,
            "amount": amount,
            "expires_at": "2026-04-15T23:59:59Z",
        }
    }
```

### 12.3 UPI Link Generator

```python
# app/services/upi_service.py
from urllib.parse import urlencode

def generate_upi_link(
    merchant_id: str,
    merchant_name: str,
    amount: float,
    transaction_id: str,
    description: str = "EduSHAMIIT Payment",
) -> str:
    """Generate UPI deep link for payment.
    Opens UPI app (GPay, PhonePe, Paytm, etc.) directly.
    Zero external fees — direct bank-to-bank transfer."""
    params = {
        "pa": merchant_id,
        "pn": merchant_name,
        "am": str(amount),
        "tn": description,
        "tr": transaction_id,
        "cu": "INR",
        "mc": "8220",  # Education MCC
    }
    return f"upi://pay?{urlencode(params)}"

def generate_upi_qr_data(
    merchant_id: str,
    merchant_name: str,
    amount: float,
    transaction_id: str,
) -> str:
    """Generate UPI QR code data string for scanning."""
    return generate_upi_link(merchant_id, merchant_name, amount, transaction_id, "EduSHAMIIT Fee")
```

### 12.4 Payment Verification

```python
# app/api/payments.py (continued)
@router.post("/verify")
async def verify_payment(
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Verify UPI payment after student completes payment in UPI app."""
    sb = get_supabase()

    payment_id = request.get("payment_id")
    upi_transaction_id = request.get("upi_transaction_id")
    status = request.get("status", "success")

    # Update payment status
    sb.table("payments").update({
        "status": status,
        "transaction_id": upi_transaction_id,
        "paid_at": datetime.now().isoformat(),
    }).eq("id", payment_id).eq("school_id", school_id).execute()

    # Update fee status
    payment = sb.table("payments").select("fee_id, amount").eq("id", payment_id).single().execute()
    if payment.data:
        fee = sb.table("fees").select("amount, amount_paid").eq("id", payment.data["fee_id"]).single().execute()
        if fee.data:
            new_paid = float(fee.data["amount_paid"]) + float(payment.data["amount"])
            new_status = "paid" if new_paid >= float(fee.data["amount"]) else "partial"
            sb.table("fees").update({
                "amount_paid": new_paid,
                "status": new_status,
            }).eq("id", payment.data["fee_id"]).execute()

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "payment_id": payment_id,
            "status": status,
            "message": "Payment verified successfully",
        }
    }

@router.post("/webhook")
async def bank_webhook(request: dict):
    """Handle bank payment webhook for production."""
    sb = get_supabase()

    transaction_id = request.get("transaction_id")
    upi_transaction_id = request.get("upi_transaction_id")
    status = request.get("status", "success")

    payment = sb.table("payments").select("*").eq("transaction_id", transaction_id).single().execute()

    if not payment.data:
        return {"success": False, "error": "Transaction not found"}

    if float(request.get("amount", 0)) != float(payment.data["amount"]):
        return {"success": False, "error": "Amount mismatch"}

    sb.table("payments").update({
        "status": status,
        "transaction_id": upi_transaction_id,
        "paid_at": request.get("timestamp", datetime.now().isoformat()),
    }).eq("id", payment.data["id"]).execute()

    if status == "success":
        fee = sb.table("fees").select("amount, amount_paid").eq("id", payment.data["fee_id"]).single().execute()
        if fee.data:
            new_paid = float(fee.data["amount_paid"]) + float(payment.data["amount"])
            new_status = "paid" if new_paid >= float(fee.data["amount"]) else "partial"
            sb.table("fees").update({
                "amount_paid": new_paid,
                "status": new_status,
            }).eq("id", payment.data["fee_id"]).execute()

    return {"success": True, "message": "Payment processed"}
```

---

## 13. AUTHENTICATION ENDPOINTS

### 13.0 POST /api/auth/reset-password (Generate OTP / Verify & Reset)

```python
# app/api/auth.py
from fastapi import APIRouter, HTTPException
from app.services.supabase_client import get_supabase
import uuid
from datetime import datetime, timedelta

router = APIRouter()

@router.post("/send-otp")
async def send_otp(request: dict):
    sb = get_supabase()
    identifier = request.get("identifier") # email or user_id

    # Logic to look up user and generate OTP
    # Save to password_resets table
    return {"message": "OTP sent successfully"}

@router.post("/reset-password")
async def reset_password(request: dict):
    sb = get_supabase()
    otp = request.get("otp")
    new_password = request.get("new_password")

    # Logic to verify OTP from password_resets table
    # Call Supabase Admin API to update password
    return {"message": "Password reset successfully"}
```

### 13.1 POST /api/auth/login

```python
# app/api/auth.py
from fastapi import APIRouter, HTTPException
from app.services.supabase_client import get_supabase
from jose import jwt
from datetime import datetime, timedelta
import os
import uuid

router = APIRouter()

@router.post("/login")
async def login(request: dict):
    """Authenticate user and return JWT token.

    Request:
    {
        "email": "rohan@school.com",
        "password": "password123",
        "role": "student"
    }
    """
    sb = get_supabase()

    email = request.get("email")
    password = request.get("password")

    auth_response = sb.auth.sign_in_with_password({
        "email": email,
        "password": password,
    })

    user_id = auth_response.user.id
    profile = sb.table("profiles").select("*").eq("id", user_id).single().execute()

    if not profile.data:
        raise HTTPException(status_code=404, detail="Profile not found")

    token = jwt.encode(
        {
            "sub": user_id,
            "school_id": profile.data["school_id"],
            "role": profile.data["role"],
            "class": profile.data.get("class"),
            "exp": datetime.now() + timedelta(days=7),
        },
        os.getenv("SUPABASE_JWT_SECRET"),
        algorithm="HS256",
    )

    return {
        "success": True,
        "school_id": profile.data["school_id"],
        "data": {
            "token": token,
            "refresh_token": auth_response.session.refresh_token,
            "user": {
                "id": user_id,
                "full_name": profile.data["full_name"],
                "role": profile.data["role"],
                "class": profile.data.get("class"),
                "school_id": profile.data["school_id"],
                "avatar_url": profile.data.get("avatar_url"),
            }
        }
    }

@router.post("/register")
async def register(request: dict):
    """Register new user (student/teacher)."""
    sb = get_supabase()

    auth_response = sb.auth.sign_up({
        "email": request["email"],
        "password": request["password"],
    })

    sb.table("profiles").insert({
        "id": auth_response.user.id,
        "school_id": request["school_id"],
        "user_id": f"STU-{uuid.uuid4().hex[:6].upper()}",
        "full_name": request["full_name"],
        "role": request["role"],
        "class": request.get("class"),
    }).execute()

    return {"success": True, "message": "Registration successful"}

@router.post("/refresh")
async def refresh_token(request: dict):
    """Refresh JWT token."""
    sb = get_supabase()
    refresh_token = request.get("refresh_token")

    auth_response = sb.auth.refresh_session(refresh_token)
    profile = sb.table("profiles").select("*").eq("id", auth_response.user.id).single().execute()

    token = jwt.encode(
        {
            "sub": auth_response.user.id,
            "school_id": profile.data["school_id"],
            "role": profile.data["role"],
            "exp": datetime.now() + timedelta(days=7),
        },
        os.getenv("SUPABASE_JWT_SECRET"),
        algorithm="HS256",
    )

    return {"success": True, "data": {"token": token}}
```

---

## 14. STUDENT SCREEN ENDPOINTS (29 SCREENS)

### 14.1 Dashboard — GET /api/student/dashboard

```python
# app/api/student.py
from fastapi import APIRouter, Depends
from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase
from app.services.redis_client import get_cached, set_cached
from datetime import datetime, timedelta

router = APIRouter()

@router.get("/dashboard")
async def student_dashboard(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Student dashboard with stats, schedule, homework, and quick access."""
    cached = await get_cached(school_id, "dashboard", user["id"])
    if cached:
        return cached

    sb = get_supabase()
    profile = sb.table("profiles").select("*").eq("id", user["id"]).single().execute().data

    today = datetime.now().weekday()
    schedule = sb.table("timetable")\
        .select("*, subjects(name, icon, color)")\
        .eq("school_id", school_id)\
        .eq("class", profile["class"])\
        .eq("day_of_week", today)\
        .order("start_time").execute().data

    homework = sb.table("homework")\
        .select("*, subjects(name, icon)")\
        .eq("school_id", school_id)\
        .eq("target_class", profile["class"])\
        .eq("status", "active")\
        .lte("due_date", (datetime.now() + timedelta(days=3)).isoformat())\
        .order("due_date").execute().data

    attendance = sb.table("attendance")\
        .select("status")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"]).execute().data

    att_pct = (sum(1 for a in attendance if a["status"] == "present") / len(attendance) * 100) if attendance else 0

    # Calculate class rank
    all_students = sb.table("profiles")\
        .select("id, xp_points")\
        .eq("school_id", school_id)\
        .eq("class", profile["class"])\
        .eq("role", "student")\
        .order("xp_points", ascending=False).execute().data

    class_rank = next((i+1 for i, s in enumerate(all_students) if s["id"] == user["id"]), 0)

    # Latest score
    latest_result = sb.table("results")\
        .select("marks_obtained, max_marks")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"])\
        .order("created_at", ascending=False)\
        .limit(1).maybe_single().execute().data

    avg_score = 0
    if latest_result:
        avg_score = (float(latest_result["marks_obtained"]) / float(latest_result["max_marks"]) * 100)

    result = {
        "success": True,
        "school_id": school_id,
        "data": {
            "user": {
                "full_name": profile["full_name"],
                "class": profile.get("class"),
                "xp_points": profile.get("xp_points", 0),
                "learning_streak": profile.get("learning_streak", 0),
                "avatar_url": profile.get("avatar_url"),
            },
            "stats": {
                "attendance_pct": round(att_pct, 1),
                "avg_score": round(avg_score, 1),
                "class_rank": class_rank,
                "xp_points": profile.get("xp_points", 0),
            },
            "today_schedule": schedule,
            "pending_homework": homework,
            "quick_access": [
                {"title": "Timetable", "icon": "📅", "route": "/student/timetable"},
                {"title": "Results", "icon": "📊", "route": "/student/results"},
                {"title": "Fees", "icon": "💰", "route": "/student/fees"},
                {"title": "Notices", "icon": "📢", "route": "/student/notices"},
                {"title": "Homework", "icon": "📝", "route": "/student/homework"},
                {"title": "Transport", "icon": "🚌", "route": "/student/transport"},
                {"title": "Events", "icon": "🎉", "route": "/student/events"},
                {"title": "Attendance", "icon": "📊", "route": "/student/attendance"},
                {"title": "Library", "icon": "📚", "route": "/student/library"},
                {"title": "Courses", "icon": "📖", "route": "/student/courses"},
                {"title": "Exams", "icon": "📝", "route": "/student/exams"},
                {"title": "Live Class", "icon": "🎥", "route": "/student/live-classes"},
                {"title": "Messages", "icon": "💬", "route": "/messaging"},
                {"title": "Achievements", "icon": "🏆", "route": "/student/achievements"},
                {"title": "Leave", "icon": "🏖️", "route": "/student/leave"},
                {"title": "Leaderboard", "icon": "🏆", "route": "/student/leaderboard"},
            ],
        }
    }

    await set_cached(school_id, "dashboard", result, user["id"], ttl=120)
    return result
```

### 14.2 Timetable — GET /api/student/timetable

```python
@router.get("/timetable")
async def student_timetable(
    day: str = "monday",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get student's class timetable for a specific day."""
    sb = get_supabase()
    profile = sb.table("profiles").select("class").eq("id", user["id"]).single().execute().data

    day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5}
    day_num = day_map.get(day.lower(), datetime.now().weekday())

    schedule = sb.table("timetable")\
        .select("*, subjects(name, icon, color), profiles!teacher_id(full_name)")\
        .eq("school_id", school_id)\
        .eq("class", profile["class"])\
        .eq("day_of_week", day_num)\
        .order("start_time").execute().data

    return {"success": True, "school_id": school_id, "data": {"schedule": schedule, "day": day, "class": profile["class"]}}
```

### 14.3 Results — GET /api/student/results

```python
@router.get("/results")
async def student_results(
    category: str = "All",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get student's exam results with optional category filter."""
    sb = get_supabase()

    query = sb.table("results")\
        .select("*, subjects(name, icon)")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"])

    if category != "All":
        query = query.eq("exam_category", category)

    results = query.order("created_at", ascending=False).execute().data

    total = sum(float(r.get("marks_obtained", 0)) for r in results)
    max_total = sum(float(r.get("max_marks", 100)) for r in results)
    avg_score = (total / max_total * 100) if max_total > 0 else 0

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "overall": {"avg_score": round(avg_score, 1), "grade": _calculate_grade(avg_score), "total_exams": len(results)},
            "results": results,
        }
    }

def _calculate_grade(pct):
    if pct >= 90: return "A+"
    if pct >= 80: return "A"
    if pct >= 70: return "B+"
    if pct >= 60: return "B"
    if pct >= 50: return "C"
    if pct >= 40: return "D"
    return "F"
```

### 14.4 Exams — GET /api/student/exams

```python
@router.get("/exams")
async def student_exams(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get upcoming exams for student's class."""
    sb = get_supabase()
    profile = sb.table("profiles").select("class").eq("id", user["id"]).single().execute().data

    exams = sb.table("exams")\
        .select("*, subjects(name, icon)")\
        .eq("school_id", school_id)\
        .contains("target_classes", f'["{profile["class"]}"]')\
        .gte("exam_date", datetime.now().date().isoformat())\
        .order("exam_date").execute().data

    return {"success": True, "school_id": school_id, "data": {"exams": exams}}
```

### 14.5 Homework — GET /api/student/homework

```python
@router.get("/homework")
async def student_homework(
    status: str = "all",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get homework assignments with status filter."""
    sb = get_supabase()
    profile = sb.table("profiles").select("class").eq("id", user["id"]).single().execute().data

    homework = sb.table("homework")\
        .select("*, subjects(name, icon)")\
        .eq("school_id", school_id)\
        .eq("target_class", profile["class"])\
        .eq("status", "active")\
        .order("due_date").execute().data

    submissions = sb.table("homework_submissions")\
        .select("homework_id, status, marks, grade")\
        .eq("student_id", user["id"]).execute().data

    sub_map = {s["homework_id"]: s for s in submissions}

    filtered = []
    for hw in homework:
        sub = sub_map.get(hw["id"])
        hw["submission_status"] = sub["status"] if sub else None
        hw["marks"] = sub.get("marks") if sub else None
        hw["grade"] = sub.get("grade") if sub else None

        if status == "all" or (status == "pending" and not sub) or \
           (status == "submitted" and sub and sub["status"] == "submitted") or \
           (status == "graded" and sub and sub["status"] == "graded"):
            filtered.append(hw)

    return {"success": True, "school_id": school_id, "data": {"homework": filtered}}
```

### 14.6 Homework Submit — POST /api/student/homework/submit

```python
@router.post("/homework/submit")
async def submit_homework(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Submit homework assignment."""
    sb = get_supabase()

    homework_id = request.get("homework_id")
    submission_text = request.get("submission_text", "")
    attachment_url = request.get("attachment_url")

    existing = sb.table("homework_submissions")\
        .select("id")\
        .eq("homework_id", homework_id)\
        .eq("student_id", user["id"]).maybe_single().execute()

    if existing.data:
        return {"success": False, "message": "Already submitted"}

    submission = sb.table("homework_submissions").insert({
        "school_id": school_id,
        "homework_id": homework_id,
        "student_id": user["id"],
        "submission_text": submission_text,
        "attachment_url": attachment_url,
        "status": "submitted",
    }).execute()

    # Award XP via database function
    sb.rpc("update_student_xp", {
        "p_school_id": school_id,
        "p_student_id": user["id"],
        "p_xp_to_add": 50,
        "p_action": "homework_submission"
    }).execute()

    return {"success": True, "school_id": school_id, "data": {"submission_id": submission.data[0]["id"]}}
```

### 14.7 Attendance — GET /api/student/attendance

```python
@router.get("/attendance")
async def student_attendance(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get student's attendance statistics."""
    sb = get_supabase()

    attendance = sb.table("attendance")\
        .select("status, subjects(name)")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"]).execute().data

    total = len(attendance)
    present = sum(1 for a in attendance if a["status"] == "present")
    absent = sum(1 for a in attendance if a["status"] == "absent")
    late = sum(1 for a in attendance if a["status"] == "late")
    pct = (present / total * 100) if total > 0 else 0

    subject_wise = {}
    for a in attendance:
        subj = a.get("subjects", {}).get("name", "Unknown")
        subject_wise.setdefault(subj, {"total": 0, "present": 0})
        subject_wise[subj]["total"] += 1
        if a["status"] == "present":
            subject_wise[subj]["present"] += 1

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "overall_pct": round(pct, 1),
            "present_days": present,
            "absent_days": absent,
            "late_days": late,
            "total_days": total,
            "subject_wise": [
                {"subject": s, "present": d["present"], "total": d["total"],
                 "pct": round(d["present"]/d["total"]*100, 1) if d["total"] > 0 else 0}
                for s, d in subject_wise.items()
            ],
        }
    }
```

### 14.8 Fees — GET /api/student/fees

```python
@router.get("/fees")
async def student_fees(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get student's fee status and payment history."""
    sb = get_supabase()

    fees = sb.table("fees")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"])\
        .order("due_date").execute().data

    payments = sb.table("payments")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"])\
        .order("paid_at", ascending=False).execute().data

    total_outstanding = sum(float(f["amount"]) - float(f.get("amount_paid", 0)) for f in fees if f["status"] in ("pending", "partial", "overdue"))
    total_paid = sum(float(f.get("amount_paid", 0)) for f in fees)

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "total_outstanding": total_outstanding,
            "total_paid": total_paid,
            "pending_fees": [f for f in fees if f["status"] in ("pending", "partial", "overdue")],
            "recent_payments": payments[:3],
        }
    }
```

### 14.9 Transport — GET /api/student/transport

```python
@router.get("/transport")
async def student_transport(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get student's bus route and live location."""
    sb = get_supabase()

    transport = sb.table("student_transport")\
        .select("*, bus_routes(*), bus_stops(stop_name)")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"]).maybe_single().execute().data

    if not transport:
        return {"success": False, "message": "Not assigned to any bus route"}

    bus_location = sb.table("bus_locations")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("route_id", transport["route_id"])\
        .order("recorded_at", ascending=False)\
        .limit(1).maybe_single().execute().data

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "route": transport.get("bus_routes"),
            "your_stop": transport.get("bus_stops", {}).get("stop_name"),
            "live_location": bus_location,
        }
    }
```

### 14.10 Notices — GET /api/student/notices

```python
@router.get("/notices")
async def student_notices(
    category: str = "All",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get school notices and announcements."""
    sb = get_supabase()

    query = sb.table("notices")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("status", "published")

    if category != "All":
        query = query.eq("category", category)

    notices = query.order("published_at", ascending=False).limit(20).execute().data

    return {"success": True, "school_id": school_id, "data": {"notices": notices}}
```

### 14.11 Events — GET /api/student/events

```python
@router.get("/events")
async def student_events(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get upcoming school events."""
    sb = get_supabase()

    events = sb.table("events")\
        .select("*")\
        .eq("school_id", school_id)\
        .gte("event_date", datetime.now().date().isoformat())\
        .order("event_date").execute().data

    return {"success": True, "school_id": school_id, "data": {"events": events}}

@router.post("/events/{event_id}/register")
async def register_event(event_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Register for a school event."""
    sb = get_supabase()

    sb.table("event_registrations").insert({
        "school_id": school_id,
        "event_id": event_id,
        "student_id": user["id"],
    }).execute()

    # Increment participant count
    event = sb.table("events").select("current_participants").eq("id", event_id).single().execute().data
    sb.table("events").update({
        "current_participants": event["current_participants"] + 1
    }).eq("id", event_id).execute()

    return {"success": True, "message": "Registered successfully"}
```

### 14.12 Achievements — GET /api/student/achievements

```python
@router.get("/achievements")
async def student_achievements(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get student's achievements and XP stats."""
    sb = get_supabase()

    profile = sb.table("profiles").select("xp_points, learning_streak, best_streak").eq("id", user["id"]).single().execute().data
    achievements = sb.table("student_achievements")\
        .select("*, achievements(name, description, icon, rarity, xp_reward)")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"])\
        .order("earned_at", ascending=False).execute().data

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "xp_points": profile.get("xp_points", 0),
            "learning_streak": profile.get("learning_streak", 0),
            "best_streak": profile.get("best_streak", 0),
            "achievements": achievements,
        }
    }
```

### 14.13 Leave — POST /api/student/leave/apply

```python
@router.post("/leave/apply")
async def apply_leave(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Apply for leave."""
    sb = get_supabase()

    sb.table("leave_applications").insert({
        "school_id": school_id,
        "applicant_id": user["id"],
        "applicant_role": "student",
        "leave_type": request.get("leave_type"),
        "start_date": request.get("start_date"),
        "end_date": request.get("end_date"),
        "reason": request.get("reason"),
    }).execute()

    return {"success": True, "message": "Leave application submitted"}
```

### 14.14 Profile — GET /api/student/profile

```python
@router.get("/profile")
async def student_profile(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get student's full profile."""
    sb = get_supabase()
    profile = sb.table("profiles").select("*").eq("id", user["id"]).single().execute().data
    return {"success": True, "school_id": school_id, "data": {"profile": profile}}
```

### 14.15 Library — GET /api/student/library

```python
@router.get("/library")
async def student_library(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get student's library borrowing status."""
    sb = get_supabase()

    borrows = sb.table("library_borrows")\
        .select("*, library_books(title, author, cover_url)")\
        .eq("school_id", school_id)\
        .eq("student_id", user["id"])\
        .order("borrowed_at", ascending=False).execute().data

    return {"success": True, "school_id": school_id, "data": {"borrows": borrows}}
```

### 14.16 Courses — GET /api/student/courses

```python
@router.get("/courses")
async def student_courses(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get courses for student's class."""
    sb = get_supabase()
    profile = sb.table("profiles").select("class").eq("id", user["id"]).single().execute().data

    courses = sb.table("courses")\
        .select("*, subjects(name, icon, color)")\
        .eq("school_id", school_id)\
        .eq("class", profile["class"]).execute().data

    return {"success": True, "school_id": school_id, "data": {"courses": courses}}
```

### 14.17 Notifications — GET /api/student/notifications

```python
@router.get("/notifications")
async def student_notifications(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get student's notifications."""
    sb = get_supabase()

    notifications = sb.table("notifications")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("user_id", user["id"])\
        .order("created_at", ascending=False)\
        .limit(20).execute().data

    return {"success": True, "school_id": school_id, "data": {"notifications": notifications}}

@router.put("/notifications/{notification_id}/read")
async def mark_notification_read(notification_id: str, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Mark a notification as read."""
    sb = get_supabase()
    sb.table("notifications").update({"is_read": True}).eq("id", notification_id).execute()
    return {"success": True}
```

### 14.18 Live Classes — GET /api/student/live-classes

```python
@router.get("/live-classes")
async def student_live_classes(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get live and upcoming classes."""
    sb = get_supabase()
    profile = sb.table("profiles").select("class").eq("id", user["id"]).single().execute().data

    classes = sb.table("live_classes")\
        .select("*, subjects(name, icon), profiles!teacher_id(full_name)")\
        .eq("school_id", school_id)\
        .eq("target_class", profile["class"])\
        .in_("status", ["live", "scheduled"])\
        .order("scheduled_at").execute().data

    return {"success": True, "school_id": school_id, "data": {"live_classes": classes}}
```

### 14.19 Leaderboard — GET /api/student/leaderboard

```python
@router.get("/leaderboard")
async def student_leaderboard(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get class leaderboard by XP points."""
    sb = get_supabase()
    profile = sb.table("profiles").select("class").eq("id", user["id"]).single().execute().data

    students = sb.table("profiles")\
        .select("id, full_name, xp_points, learning_streak, avatar_url")\
        .eq("school_id", school_id)\
        .eq("class", profile["class"])\
        .eq("role", "student")\
        .order("xp_points", ascending=False)\
        .limit(20).execute().data

    return {"success": True, "school_id": school_id, "data": {"leaderboard": students, "class": profile["class"]}}
```

### 14.20-14.29 Remaining Student Endpoints

```python
# Settings — GET /api/user/settings
@router.get("/user/settings")
async def get_settings(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    settings = sb.table("user_settings").select("*").eq("user_id", user["id"]).maybe_single().execute().data
    return {"success": True, "school_id": school_id, "data": {"settings": settings or {}}}

# Messaging — GET /api/messages
@router.get("/messages")
async def get_messages(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    messages = sb.table("messages")\
        .select("*, profiles!sender_id(full_name, avatar_url, role)")\
        .eq("school_id", school_id)\
        .or_(f"sender_id.eq.{user['id']},receiver_id.eq.{user['id']}")\
        .order("created_at", ascending=False).execute().data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}

# Send Message — POST /api/messages/send
@router.post("/messages/send")
async def send_message(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    message = sb.table("messages").insert({
        "school_id": school_id,
        "sender_id": user["id"],
        "receiver_id": request.get("receiver_id"),
        "content": request.get("content"),
    }).execute()
    return {"success": True, "school_id": school_id, "data": {"message_id": message.data[0]["id"]}}

# Create Group — POST /api/groups/create
@router.post("/groups/create")
async def create_group(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    group = sb.table("groups").insert({
        "school_id": school_id,
        "name": request.get("name"),
        "description": request.get("description"),
        "created_by": user["id"],
    }).execute()
    return {"success": True, "school_id": school_id, "data": {"group_id": group.data[0]["id"]}}
```

---

## 15. TEACHER SCREEN ENDPOINTS (29 SCREENS)

### 15.1 Dashboard — GET /api/teacher/dashboard

```python
# app/api/teacher.py
from fastapi import APIRouter, Depends
from app.middleware.auth import get_current_user, require_school_id
from app.services.supabase_client import get_supabase
from datetime import datetime

router = APIRouter()

@router.get("/dashboard")
async def teacher_dashboard(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Teacher dashboard with stats, schedule, and pending tasks."""
    sb = get_supabase()

    classes = sb.table("timetable")\
        .select("class")\
        .eq("school_id", school_id)\
        .eq("teacher_id", user["id"]).execute().data

    unique_classes = list(set(c["class"] for c in classes))

    students = sb.table("profiles")\
        .select("id")\
        .eq("school_id", school_id)\
        .in_("class", unique_classes)\
        .eq("role", "student").execute().data

    # Today's schedule
    today = datetime.now().weekday()
    schedule = sb.table("timetable")\
        .select("*, subjects(name, icon)")\
        .eq("school_id", school_id)\
        .eq("teacher_id", user["id"])\
        .eq("day_of_week", today)\
        .order("start_time").execute().data

    # Pending submissions
    homework = sb.table("homework")\
        .select("id")\
        .eq("school_id", school_id)\
        .eq("teacher_id", user["id"])\
        .eq("status", "active").execute().data

    pending_subs = 0
    for hw in homework:
        subs = sb.table("homework_submissions")\
            .select("id")\
            .eq("homework_id", hw["id"])\
            .eq("status", "submitted").execute().data
        pending_subs += len(subs)

    return {
        "success": True,
        "school_id": school_id,
        "data": {
            "teacher": sb.table("profiles").select("*").eq("id", user["id"]).single().execute().data,
            "stats": {
                "total_students": len(students),
                "total_classes": len(unique_classes),
                "pending_tasks": pending_subs,
            },
            "today_schedule": schedule,
        }
    }
```

### 15.2 My Classes — GET /api/teacher/classes

```python
@router.get("/classes")
async def teacher_classes(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get classes taught by this teacher."""
    sb = get_supabase()

    classes = sb.table("timetable")\
        .select("class")\
        .eq("school_id", school_id)\
        .eq("teacher_id", user["id"]).execute().data

    unique_classes = list(set(c["class"] for c in classes))

    class_details = []
    for cls in unique_classes:
        students = sb.table("profiles")\
            .select("id")\
            .eq("school_id", school_id)\
            .eq("class", cls)\
            .eq("role", "student").execute().data

        class_details.append({"class": cls, "student_count": len(students)})

    return {"success": True, "school_id": school_id, "data": {"classes": class_details}}
```

### 15.3 Mark Attendance — POST /api/teacher/attendance/mark

```python
@router.post("/attendance/mark")
async def mark_attendance(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Mark attendance for students in a class."""
    sb = get_supabase()

    date = request.get("date", datetime.now().date().isoformat())
    records = request.get("attendance_records", [])

    for record in records:
        sb.table("attendance").upsert({
            "school_id": school_id,
            "student_id": record["student_id"],
            "subject_id": request.get("subject_id"),
            "teacher_id": user["id"],
            "date": date,
            "status": record["status"],
        }, on_conflict="school_id,student_id,subject_id,date").execute()

    return {"success": True, "school_id": school_id, "message": f"Marked {len(records)} students"}
```

### 15.4 Create Homework — POST /api/teacher/homework/create

```python
@router.post("/homework/create")
async def create_homework(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Create a new homework assignment."""
    sb = get_supabase()

    homework = sb.table("homework").insert({
        "school_id": school_id,
        "subject_id": request.get("subject_id"),
        "teacher_id": user["id"],
        "title": request.get("title"),
        "description": request.get("description"),
        "due_date": request.get("due_date"),
        "max_marks": request.get("max_marks", 25),
        "target_class": request.get("target_class"),
        "status": "active",
    }).execute()

    return {"success": True, "school_id": school_id, "data": {"homework_id": homework.data[0]["id"]}}
```

### 15.5 Grade Submission — POST /api/teacher/submissions/grade

```python
@router.post("/submissions/grade")
async def grade_submission(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Grade a homework submission."""
    sb = get_supabase()

    sb.table("homework_submissions").update({
        "status": "graded",
        "marks": request.get("marks"),
        "grade": request.get("grade"),
        "teacher_remarks": request.get("remarks"),
        "graded_by": user["id"],
        "graded_at": datetime.now().isoformat(),
    }).eq("id", request.get("submission_id")).eq("school_id", school_id).execute()

    return {"success": True, "school_id": school_id, "message": "Submission graded"}
```

### 15.6 Class Detail — GET /api/teacher/class-detail

```python
@router.get("/class-detail")
async def teacher_class_detail(
    class_name: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get detailed information about a class including students and performance."""
    sb = get_supabase()

    students = sb.table("profiles")\
        .select("id, full_name, roll_number, xp_points, learning_streak, avatar_url")\
        .eq("school_id", school_id)\
        .eq("class", class_name)\
        .eq("role", "student")\
        .order("roll_number").execute().data

    return {"success": True, "school_id": school_id, "data": {"class": class_name, "students": students}}
```

### 15.7 Timetable — GET /api/teacher/timetable

```python
@router.get("/timetable")
async def teacher_timetable(
    day: str = "monday",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get teacher's timetable for a specific day."""
    sb = get_supabase()

    day_map = {"monday":0,"tuesday":1,"wednesday":2,"thursday":3,"friday":4,"saturday":5}
    day_num = day_map.get(day.lower(), datetime.now().weekday())

    schedule = sb.table("timetable")\
        .select("*, subjects(name, icon, color)")\
        .eq("school_id", school_id)\
        .eq("teacher_id", user["id"])\
        .eq("day_of_week", day_num)\
        .order("start_time").execute().data

    return {"success": True, "school_id": school_id, "data": {"schedule": schedule, "day": day}}
```

### 15.8 Create Exam — POST /api/teacher/exams/create

```python
@router.post("/exams/create")
async def create_exam(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Create a new exam."""
    sb = get_supabase()

    exam = sb.table("exams").insert({
        "school_id": school_id,
        "subject_id": request.get("subject_id"),
        "teacher_id": user["id"],
        "title": request.get("title"),
        "exam_type": request.get("exam_type", "offline"),
        "exam_category": request.get("exam_category"),
        "exam_date": request.get("exam_date"),
        "start_time": request.get("start_time"),
        "duration_minutes": request.get("duration_minutes", 90),
        "total_marks": request.get("total_marks", 100),
        "venue": request.get("venue"),
        "target_classes": request.get("target_classes"),
        "status": "upcoming",
    }).execute()

    return {"success": True, "school_id": school_id, "data": {"exam_id": exam.data[0]["id"]}}
```

### 15.9 Generate Questions — POST /api/teacher/exams/generate-questions

```python
@router.post("/exams/generate-questions")
async def generate_exam_questions(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """AI-generate exam questions."""
    from langchain_google_genai import ChatGoogleGenerativeAI

    llm = ChatGoogleGenerativeAI(model="gemini-1.5-flash-latest", temperature=0.7)
    prompt = f"""Generate exam questions:
Subject: {request.get('subject')}
Topic: {request.get('topic')}
MCQ: {request.get('num_mcq', 10)} questions
Subjective: {request.get('num_subjective', 5)} questions
Difficulty: {request.get('difficulty', 'medium')}
Total Marks: {request.get('total_marks', 100)}

Format as JSON array with question_number, section, type, text, options, correct_answer, marks."""

    response = llm.invoke(prompt)
    return {"success": True, "school_id": school_id, "data": {"questions": response.content}}
```

### 15.10 Gradebook — GET /api/teacher/gradebook

```python
@router.get("/gradebook")
async def teacher_gradebook(
    class_name: str,
    subject_id: str = "",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get gradebook for a class and subject."""
    sb = get_supabase()

    students = sb.table("profiles")\
        .select("id, full_name, roll_number")\
        .eq("school_id", school_id)\
        .eq("class", class_name)\
        .eq("role", "student")\
        .order("roll_number").execute().data

    query = sb.table("results")\
        .select("student_id, marks_obtained, max_marks, grade, exam_category")\
        .eq("school_id", school_id)\
        .in_("student_id", [s["id"] for s in students])

    if subject_id:
        query = query.eq("subject_id", subject_id)

    results = query.execute().data

    # Build gradebook
    gradebook = []
    for s in students:
        s_results = [r for r in results if r["student_id"] == s["id"]]
        total = sum(float(r["marks_obtained"]) for r in s_results)
        max_total = sum(float(r["max_marks"]) for r in s_results)
        avg = (total/max_total*100) if max_total > 0 else 0

        gradebook.append({
            "student_id": s["id"],
            "name": s["full_name"],
            "roll_number": s.get("roll_number"),
            "results": s_results,
            "average": round(avg, 1),
            "grade": _calculate_grade(avg),
        })

    return {"success": True, "school_id": school_id, "data": {"gradebook": gradebook}}
```

### 15.11 Grading Config — PUT /api/teacher/grading-config

```python
@router.put("/grading-config")
async def update_grading_config(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Update grading weightage configuration."""
    sb = get_supabase()

    sb.table("grading_policies").upsert({
        "school_id": school_id,
        "teacher_id": user["id"],
        "class": request.get("class"),
        "subject_id": request.get("subject_id"),
        "mid_term_weight": request.get("mid_term_weight", 30),
        "final_term_weight": request.get("final_term_weight", 40),
        "attendance_weight": request.get("attendance_weight", 5),
        "assignment_weight": request.get("assignment_weight", 10),
        "class_test_weight": request.get("class_test_weight", 10),
        "lab_weight": request.get("lab_weight", 5),
    }).execute()

    return {"success": True, "message": "Grading config updated"}
```

### 15.12 Student Directory — GET /api/teacher/students

```python
@router.get("/students")
async def teacher_students(
    class_name: str = "",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get student directory, optionally filtered by class."""
    sb = get_supabase()

    query = sb.table("profiles")\
        .select("id, full_name, class, roll_number, phone, father_name, father_phone, avatar_url")\
        .eq("school_id", school_id)\
        .eq("role", "student")

    if class_name:
        query = query.eq("class", class_name)

    students = query.order("class").order("roll_number").execute().data

    return {"success": True, "school_id": school_id, "data": {"students": students}}
```

### 15.13 Leave — POST /api/teacher/leave/apply

```python
@router.post("/leave/apply")
async def teacher_apply_leave(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Apply for leave."""
    sb = get_supabase()

    sb.table("leave_applications").insert({
        "school_id": school_id,
        "applicant_id": user["id"],
        "applicant_role": "teacher",
        "leave_type": request.get("leave_type"),
        "start_date": request.get("start_date"),
        "end_date": request.get("end_date"),
        "reason": request.get("reason"),
    }).execute()

    return {"success": True, "message": "Leave application submitted"}
```

### 15.14 Create Notice — POST /api/teacher/notices/create

```python
@router.post("/notices/create")
async def create_notice(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Create a school notice."""
    sb = get_supabase()
    profile = sb.table("profiles").select("full_name").eq("id", user["id"]).single().execute().data

    notice = sb.table("notices").insert({
        "school_id": school_id,
        "title": request.get("title"),
        "content": request.get("content"),
        "category": request.get("category", "General"),
        "author_id": user["id"],
        "author_name": profile["full_name"],
        "is_urgent": request.get("is_urgent", False),
        "status": "published",
    }).execute()

    return {"success": True, "school_id": school_id, "data": {"notice_id": notice.data[0]["id"]}}
```

### 15.15 Live Classes — GET /api/teacher/live-classes

```python
@router.get("/live-classes")
async def teacher_live_classes(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get teacher's live classes."""
    sb = get_supabase()

    classes = sb.table("live_classes")\
        .select("*, subjects(name, icon)")\
        .eq("school_id", school_id)\
        .eq("teacher_id", user["id"])\
        .order("scheduled_at", ascending=False).execute().data

    return {"success": True, "school_id": school_id, "data": {"live_classes": classes}}

@router.post("/live-classes/start")
async def start_live_class(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Start a live class session."""
    sb = get_supabase()

    live_class = sb.table("live_classes").insert({
        "school_id": school_id,
        "teacher_id": user["id"],
        "subject_id": request.get("subject_id"),
        "title": request.get("title"),
        "scheduled_at": request.get("scheduled_at"),
        "duration_minutes": request.get("duration_minutes", 60),
        "target_class": request.get("target_class"),
        "status": "live",
        "is_live": True,
    }).execute()

    return {"success": True, "school_id": school_id, "data": {"live_class_id": live_class.data[0]["id"]}}
```

### 15.16 Upload Materials — POST /api/teacher/materials/upload

```python
@router.post("/materials/upload")
async def upload_material(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Upload study material."""
    sb = get_supabase()

    material = sb.table("study_materials").insert({
        "school_id": school_id,
        "teacher_id": user["id"],
        "title": request.get("title"),
        "description": request.get("description"),
        "material_type": request.get("material_type"),
        "target_class": request.get("target_class"),
        "attachment_urls": request.get("attachment_urls"),
    }).execute()

    return {"success": True, "school_id": school_id, "data": {"material_id": material.data[0]["id"]}}
```

### 15.17 Salary — GET /api/teacher/salary

```python
@router.get("/salary")
async def teacher_salary(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get teacher's salary information."""
    sb = get_supabase()

    salary = sb.table("salary")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("teacher_id", user["id"])\
        .order("month", ascending=False)\
        .limit(6).execute().data

    return {"success": True, "school_id": school_id, "data": {"salary_history": salary}}
```

### 15.18 Profile — GET /api/teacher/profile

```python
@router.get("/profile")
async def teacher_profile(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Get teacher's full profile."""
    sb = get_supabase()
    profile = sb.table("profiles").select("*").eq("id", user["id"]).single().execute().data
    return {"success": True, "school_id": school_id, "data": {"profile": profile}}
```

### 15.19-15.29 Remaining Teacher Endpoints

```python
# Submissions — GET /api/teacher/submissions
@router.get("/submissions")
async def teacher_submissions(
    homework_id: str = "",
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    query = sb.table("homework_submissions")\
        .select("*, profiles!student_id(full_name, roll_number), homework(title)")\
        .eq("school_id", school_id)

    if homework_id:
        query = query.eq("homework_id", homework_id)

    submissions = query.order("submitted_at", ascending=False).execute().data
    return {"success": True, "school_id": school_id, "data": {"submissions": submissions}}

# Notifications — GET /api/notifications
@router.get("/notifications")
async def teacher_notifications(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    notifications = sb.table("notifications")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("user_id", user["id"])\
        .order("created_at", ascending=False)\
        .limit(20).execute().data
    return {"success": True, "school_id": school_id, "data": {"notifications": notifications}}

# Settings — PUT /api/user/settings
@router.put("/user/settings")
async def update_settings(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    sb.table("user_settings").upsert({
        "school_id": school_id,
        "user_id": user["id"],
        **request,
    }).execute()
    return {"success": True, "message": "Settings updated"}
```

---

## 16. SHARED SCREEN ENDPOINTS (7 SCREENS)

### 16.1 Messaging

```python
# GET /api/messages — handled in student.py
# POST /api/messages/send — handled in student.py
# GET /api/messages/chat — get chat history
@router.get("/messages/chat")
async def get_chat(
    chat_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    sb = get_supabase()
    messages = sb.table("messages")\
        .select("*, profiles!sender_id(full_name, avatar_url)")\
        .eq("school_id", school_id)\
        .or_(f"sender_id.eq.{chat_id},receiver_id.eq.{chat_id}")\
        .order("created_at").execute().data
    return {"success": True, "school_id": school_id, "data": {"messages": messages}}
```

### 16.2 Notifications

```python
# GET /api/notifications — handled in student.py and teacher.py
# PUT /api/notifications/{id}/read — handled in student.py
```

### 16.3 Settings

```python
# GET /api/user/settings — handled in student.py
# PUT /api/user/settings — handled in teacher.py
```

### 16.4 Groups

```python
# POST /api/groups/create — handled in student.py
@router.get("/groups")
async def get_groups(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    sb = get_supabase()
    groups = sb.table("groups")\
        .select("*")\
        .eq("school_id", school_id)\
        .or_(f"created_by.eq.{user['id']},members.cs.[\"{user['id']}\"]")\
        .execute().data
    return {"success": True, "school_id": school_id, "data": {"groups": groups}}
```

---

## 17. AI CHAT ENDPOINTS

### 17.1 POST /api/chat/message (SSE Streaming)

```python
# app/api/chat.py
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from app.middleware.auth import get_current_user, require_school_id
from app.services.langchain_agent import process_message
import json

router = APIRouter()

@router.post("/message")
async def chat_message(
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """
    Send message to Shami AI and stream response via SSE.

    Request:
    {
        "message": "What classes do I have today?",
        "session_id": "uuid-session-1"
    }

    SSE Response:
    data: {"type":"text","content":"📅 Your Monday Schedule:\n"}
    data: {"type":"text","content":"  📐 Mathematics - 08:00 to 08:45\n"}
    data: {"type":"tool_result","tool":"get_timetable","data":{...}}
    data: {"type":"done"}
    """
    message = request.get("message")
    session_id = request.get("session_id")

    async def generate():
        async for chunk in process_message(
            text=message,
            user=user,
            school_id=school_id,
            session_id=session_id,
        ):
            yield f"data: {json.dumps(chunk)}\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
```

### 17.2 POST /api/chat/voice

```python
# app/api/voice.py
from fastapi import APIRouter, UploadFile, Form, Depends
from fastapi.responses import StreamingResponse
from app.middleware.auth import get_current_user, require_school_id
from app.services.whisper_service import transcribe
from app.services.langchain_agent import process_message
import json

router = APIRouter()

@router.post("/voice")
async def chat_voice(
    audio: UploadFile,
    session_id: str = Form(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Transcribe voice audio and process with Shami AI."""
    audio_bytes = await audio.read()
    text = await transcribe(audio_bytes, audio.filename, audio.content_type)

    async def generate():
        async for chunk in process_message(text=text, user=user, school_id=school_id, session_id=session_id):
            yield f"data: {json.dumps(chunk)}\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
```

### 17.3 POST /api/chat/image

```python
# app/api/image.py
from fastapi import APIRouter, UploadFile, Form, Depends
from app.middleware.auth import get_current_user, require_school_id
from app.services.vision_service import analyze_image

router = APIRouter()

@router.post("/image")
async def chat_image(
    image: UploadFile,
    question: str = Form("Describe this image"),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Analyze an image with Shami AI vision."""
    import base64
    image_bytes = await image.read()
    b64 = base64.b64encode(image_bytes).decode()

    result = await analyze_image(b64, question)
    return {"success": True, "school_id": school_id, "data": {"output": result}}
```

### 17.4 GET /api/chat/history/{session_id}

```python
@router.get("/history/{session_id}")
async def get_chat_history(
    session_id: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get chat history for a session."""
    sb = get_supabase()

    messages = sb.table("ai_chat_history")\
        .select("*")\
        .eq("school_id", school_id)\
        .eq("user_id", user["id"])\
        .eq("session_id", session_id)\
        .order("created_at").execute().data

    return {"success": True, "school_id": school_id, "data": {"messages": messages}}
```

---

## 18. IoT CONTROL ENDPOINTS

### 18.1 POST /api/iot/control

```python
# app/api/iot.py
from fastapi import APIRouter, Depends
from app.middleware.auth import get_current_user, require_school_id
from app.services.iot_controller import iot

router = APIRouter()

@router.post("/control")
async def control_device(
    request: dict,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Control classroom device via MQTT.

    Request:
    {
        "room": "class_10a",
        "device": "fan",
        "action": "on"
    }
    """
    room = request.get("room")
    device = request.get("device")
    action = request.get("action")

    result = iot.control_device(room, device, action)

    return {
        "success": result["ok"],
        "school_id": school_id,
        "data": {"room": room, "device": device, "action": action, "method": result.get("method")}
    }

@router.get("/status/{room}")
async def get_device_status(
    room: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Get device status for a room."""
    status = iot.get_room_status(room)
    return {"success": True, "school_id": school_id, "data": {"room": room, "devices": status}}

@router.post("/schedule")
async def schedule_device(request: dict, user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """Schedule a device action."""
    sb = get_supabase()
    from datetime import datetime

    scheduled_time = datetime.strptime(request.get("time"), "%H:%M").replace(
        year=datetime.now().year, month=datetime.now().month, day=datetime.now().day
    )

    sb.table("iot_scheduled_actions").insert({
        "school_id": school_id,
        "room_id": request.get("room"),
        "device": request.get("device"),
        "action": request.get("action"),
        "scheduled_time": scheduled_time.isoformat(),
        "status": "pending",
    }).execute()

    return {"success": True, "message": "Device action scheduled"}

@router.get("/devices")
async def list_devices(user=Depends(get_current_user), school_id=Depends(require_school_id)):
    """List all registered IoT devices."""
    sb = get_supabase()
    devices = sb.table("iot_devices").select("*").eq("school_id", school_id).execute().data
    return {"success": True, "school_id": school_id, "data": {"devices": devices}}
```

---

## 19. RAG PIPELINE ENDPOINTS

### 19.1 POST /api/rag/ingest

```python
# app/api/rag.py
from fastapi import APIRouter, UploadFile, Form, Depends
from app.middleware.auth import get_current_user, require_school_id
from app.services.rag_service import ingest_document

router = APIRouter()

@router.post("/ingest")
async def ingest_document_endpoint(
    file: UploadFile,
    subject: str = Form(...),
    grade: str = Form(...),
    source: str = Form(...),
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Ingest PDF document into RAG knowledge base."""
    pdf_bytes = await file.read()
    chunks = await ingest_document(
        pdf_bytes=pdf_bytes,
        school_id=school_id,
        subject=subject,
        grade=grade,
        source=source,
    )

    return {"success": True, "school_id": school_id, "data": {"chunks_ingested": chunks}}
```

### 19.2 GET /api/rag/documents

```python
@router.get("/documents")
async def list_documents(
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """List ingested documents for this school."""
    sb = get_supabase()

    docs = sb.table("knowledge_base")\
        .select("source, subject, grade, created_at")\
        .eq("school_id", school_id)\
        .order("created_at", ascending=False).execute().data

    # Deduplicate by source
    seen = set()
    unique_docs = []
    for d in docs:
        if d["source"] not in seen:
            seen.add(d["source"])
            unique_docs.append(d)

    return {"success": True, "school_id": school_id, "data": {"documents": unique_docs}}
```

### 19.3 DELETE /api/rag/documents/{source}

```python
@router.delete("/documents/{source}")
async def delete_document(
    source: str,
    user=Depends(get_current_user),
    school_id=Depends(require_school_id),
):
    """Remove a document from knowledge base."""
    sb = get_supabase()
    sb.table("knowledge_base").delete().eq("school_id", school_id).eq("source", source).execute()
    return {"success": True, "message": f"Document '{source}' removed"}
```

---

## 20. COMPLETE PYTHON IMPLEMENTATION

### 20.1 Redis Cache Client

```python
# app/cache/redis_client.py
import redis
import json
import os

redis_client = redis.Redis.from_url(os.getenv("REDIS_URL", "redis://localhost:6379"), decode_responses=True)

def cache_key(school_id: str, resource: str, resource_id: str = "") -> str:
    """Generate school-scoped cache key."""
    return f"{school_id}:{resource}:{resource_id}"

async def get_cached(school_id: str, resource: str, resource_id: str = ""):
    key = cache_key(school_id, resource, resource_id)
    data = redis_client.get(key)
    return json.loads(data) if data else None

async def set_cached(school_id: str, resource: str, data: dict, resource_id: str = "", ttl: int = 300):
    key = cache_key(school_id, resource, resource_id)
    redis_client.setex(key, ttl, json.dumps(data, default=str))

async def invalidate_cache(school_id: str, resource: str = "*"):
    pattern = f"{school_id}:{resource}:*"
    for key in redis_client.scan_iter(match=pattern):
        redis_client.delete(key)
```

### 20.2 Supabase Client

```python
# app/services/supabase_client.py
from supabase import create_client
import os

_client = None

def get_supabase():
    global _client
    if _client is None:
        _client = create_client(
            os.getenv("SUPABASE_URL", "http://localhost:54321"),
            os.getenv("SUPABASE_SERVICE_ROLE_KEY", ""),
        )
    return _client
```

### 20.3 JWT Middleware

```python
# app/middleware/auth.py
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer
from jose import jwt, JWTError
import os

security = HTTPBearer()

async def get_current_user(token=Depends(security)):
    """Extract user context from JWT token."""
    try:
        payload = jwt.decode(
            token.credentials,
            os.getenv("SUPABASE_JWT_SECRET"),
            algorithms=["HS256"],
            options={"verify_aud": False}
        )
        return {
            "id": payload["sub"],
            "school_id": payload["school_id"],
            "role": payload["role"],
            "class": payload.get("class"),
        }
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")

async def require_school_id(user=Depends(get_current_user)):
    """Dependency to extract and validate school_id from JWT."""
    if not user.get("school_id"):
        raise HTTPException(status_code=400, detail="school_id required")
    return user["school_id"]

# Helper used by tools
_current_user_context = {}

def set_current_user_context(user: dict):
    global _current_user_context
    _current_user_context = user

def get_current_user_id() -> str:
    return _current_user_context.get("id", "")
```

### 20.4 Rate Limiting

```python
# app/middleware/rate_limit.py
from fastapi import HTTPException
import redis
import os
import time

redis_client = redis.Redis.from_url(os.getenv("REDIS_URL"), decode_responses=True)

async def rate_limit(user_id: str, limit: int = 20, window: int = 86400):
    """Rate limit AI queries per user per day."""
    key = f"rate_limit:{user_id}"
    current = redis_client.get(key)

    if current and int(current) >= limit:
        raise HTTPException(status_code=429, detail="Daily AI query limit reached")

    pipe = redis_client.pipeline()
    pipe.incr(key)
    pipe.expire(key, window)
    pipe.execute()
```

---

## 21. SECURITY & AUTH

### 21.1 Security Rules

- Python backend uses `SUPABASE_SERVICE_ROLE_KEY` (bypasses RLS — server-side only)
- Flutter uses only `SUPABASE_ANON_KEY` + user JWT (RLS enforced)
- API keys (Anthropic, Google, OpenAI, Razorpay) live only in backend `.env`
- Never put any API key inside the Flutter app
- IoT MQTT broker runs on LAN only — not exposed to internet
- Face image data never leaves the school premises
- All API requests include `school_id` from JWT for data isolation
- Rate limiting per school_id and per user_id

### 21.2 CORS Configuration

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_methods=["*"],
    allow_headers=["*"],
    allow_credentials=True,
)
```

---

## 22. ENVIRONMENT VARIABLES

```bash
# .env (complete)

# Database
DB_PASSWORD=eduSHAMIIT2026

# Message Queue
RABBITMQ_PASSWORD=eduSHAMIIT2026

# JWT
JWT_SECRET=eduSHAMIIT-jwt-secret-2026

# AI Models
OPENAI_API_KEY=sk-...                    # Whisper + Embeddings
ANTHROPIC_API_KEY=sk-ant-...             # Claude Haiku (tool calls)
GOOGLE_API_KEY=AIza...                   # Gemini Flash (Q&A, vision)

# Payments
UPI_MERCHANT_ID=eduSHAMIIT-school@upi
UPI_MERCHANT_NAME=EduSHAMIIT Academy
RAZORPAY_KEY_ID=rzp_live_...
RAZORPAY_SECRET=...

# WhatsApp
WHATSAPP_API_KEY=...                     # Gupshup API key
WHATSAPP_NUMBER=917XXXXXXXXX

# TTS
GOOGLE_TTS_API_KEY=...
ELEVENLABS_API_KEY=...

# IoT
MQTT_BROKER_HOST=mosquitto
MQTT_BROKER_PORT=1883

# Redis
REDIS_URL=redis://redis:6379

# App
APP_ENV=production
```

---

## 23. COST OPTIMISATION

### 23.1 Monthly Estimate (500 students, 50 teachers)

| Service | Est. Cost/Month |
|---|---|
| Gemini 1.5 Flash (2M tokens/day) | ~$18 |
| Whisper STT (200 min/day) | ~$36 |
| Claude Haiku (500 tool calls/day) | ~$12 |
| text-embedding-3-small (5K queries/day) | ~$1 |
| Google TTS (50K chars/day) | ~$22 |
| Camera AI (on-premise) | $0 |
| Docker hosting (VPS) | ~$25 |
| **Total** | **~$114 (~₹9,500/month)** |

### 23.2 Cost Reduction Strategies

1. **Cache repeat answers** — Redis caches common Q&A. Same question from 100 students = 1 LLM call
2. **Per-user daily limits** — Free tier: 20 AI queries/day. Premium: unlimited
3. **Batch embedding** — Run PDF ingestion at night using batch API (50% discount)
4. **Local LLM fallback** — Run Llama 3.2 on school server for simple one-word answers
5. **Response deduplication** — Hash the question; return cached response if identical within 1 hour
6. **Smart routing** — Use cheapest model for each task (see Section 5)

---

## 24. BUILD ORDER

Follow this sequence. Each step depends on the previous.

```
PHASE 1 — Foundation (Week 1)
  [ ] 1. Docker Compose setup (postgres, redis, rabbitmq, mosquitto)
  [ ] 2. FastAPI project scaffolded (main.py, config.py, models.py)
  [ ] 3. Supabase client singleton
  [ ] 4. JWT auth middleware (with school_id extraction)
  [ ] 5. Redis cache client
  [ ] 6. Health check endpoint

PHASE 2 — Authentication (Week 1)
  [ ] 7. POST /api/auth/login
  [ ] 8. POST /api/auth/register
  [ ] 9. POST /api/auth/refresh

PHASE 3 — Student Endpoints (Week 2)
  [ ] 10. GET /api/student/dashboard
  [ ] 11. GET /api/student/timetable
  [ ] 12. GET /api/student/results
  [ ] 13. GET /api/student/exams
  [ ] 14. GET /api/student/homework
  [ ] 15. POST /api/student/homework/submit
  [ ] 16. GET /api/student/attendance
  [ ] 17. GET /api/student/fees
  [ ] 18. GET /api/student/transport
  [ ] 19. GET /api/student/notices
  [ ] 20. GET /api/student/events
  [ ] 21. GET /api/student/achievements
  [ ] 22. POST /api/student/leave/apply
  [ ] 23. GET /api/student/profile
  [ ] 24. GET /api/student/library
  [ ] 25. GET /api/student/courses
  [ ] 26. GET /api/student/notifications
  [ ] 27. GET /api/student/live-classes
  [ ] 28. GET /api/student/leaderboard

PHASE 4 — Teacher Endpoints (Week 3)
  [ ] 29. GET /api/teacher/dashboard
  [ ] 30. GET /api/teacher/classes
  [ ] 31. POST /api/teacher/attendance/mark
  [ ] 32. POST /api/teacher/homework/create
  [ ] 33. POST /api/teacher/submissions/grade
  [ ] 34. GET /api/teacher/class-detail
  [ ] 35. GET /api/teacher/timetable
  [ ] 36. POST /api/teacher/exams/create
  [ ] 37. POST /api/teacher/exams/generate-questions
  [ ] 38. GET /api/teacher/gradebook
  [ ] 39. PUT /api/teacher/grading-config
  [ ] 40. GET /api/teacher/students
  [ ] 41. POST /api/teacher/leave/apply
  [ ] 42. POST /api/teacher/notices/create
  [ ] 43. GET /api/teacher/live-classes
  [ ] 44. POST /api/teacher/materials/upload
  [ ] 45. GET /api/teacher/salary
  [ ] 46. GET /api/teacher/profile

PHASE 5 — Shared Endpoints (Week 3)
  [ ] 47. GET /api/messages
  [ ] 48. POST /api/messages/send
  [ ] 49. GET /api/notifications
  [ ] 50. GET /api/user/settings
  [ ] 51. PUT /api/user/settings
  [ ] 52. POST /api/groups/create

PHASE 6 — Payments (Week 4)
  [ ] 53. POST /api/payments/create-upi-link
  [ ] 54. POST /api/payments/verify
  [ ] 55. POST /api/payments/webhook

PHASE 7 — AI Agent (Week 4-5)
  [ ] 56. Gemini Flash LLM connected
  [ ] 57. Claude Haiku connected
  [ ] 58. Router (detect_task → get_llm) working
  [ ] 59. System prompts for all roles
  [ ] 60. build_agent() function
  [ ] 61. process_message() orchestrator
  [ ] 62. All 20 student tools
  [ ] 63. All 20 teacher tools
  [ ] 64. Tool permission filtering by role
  [ ] 65. Chat history save/load
  [ ] 66. POST /api/chat/message (SSE streaming)

PHASE 8 — Multimodal (Week 5)
  [ ] 67. POST /api/chat/voice (Whisper STT)
  [ ] 68. POST /api/chat/image (Gemini Vision)
  [ ] 69. TTS service (optional)

PHASE 9 — RAG Pipeline (Week 6)
  [ ] 70. POST /api/rag/ingest
  [ ] 71. GET /api/rag/documents
  [ ] 72. search_curriculum tool
  [ ] 73. RAG tested with NCERT sample PDF

PHASE 10 — IoT (Week 6)
  [ ] 74. Mosquitto MQTT broker running
  [ ] 75. ESP32 firmware flashed
  [ ] 76. iot_controller.py working
  [ ] 77. IoT tools connected
  [ ] 78. POST /api/iot/control
  [ ] 79. GET /api/iot/status/{room}
  [ ] 80. POST /api/iot/schedule
  [ ] 81. GET /api/iot/devices

PHASE 11 — Camera (Week 7-8)
  [ ] 82. YOLOv8 + DeepFace installed
  [ ] 83. Student face enrollment
  [ ] 84. camera_attendance.py working
  [ ] 85. Attendance auto-written to Supabase

PHASE 12 — Production Hardening
  [ ] 86. Rate limiting per user per day
  [ ] 87. Redis response caching
  [ ] 88. Error handling + fallback messages
  [ ] 89. Nginx SSE proxy configuration
  [ ] 90. Docker deployment to VPS
  [ ] 91. Health checks and monitoring
```

---

*This document is the single source of truth for building the EduSHAMIIT Python backend — by Shami Innovation and Technologies LLP.*

*Every AI agent, code generator, or developer working on this project should start here.*

---
**Last updated:** April 2026
**Maintainer:** Naresh — EduSHAMIIT