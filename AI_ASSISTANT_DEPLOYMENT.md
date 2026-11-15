# EduSHAMIIT ERP - AI Assistant Deployment & Operations Guide

## 1. System Requirements & Prerequisites

The EduSHAMIIT AI Assistant operates within the existing EduSHAMIIT containerized infrastructure.

| Component | Minimum Specification | Recommended Production |
|---|---|---|
| **OS** | Ubuntu 22.04 LTS / Windows Server 2022 | Ubuntu 24.04 LTS (Dockerized) |
| **CPU / RAM** | 2 vCPU / 4 GB RAM | 4 vCPU / 8 GB RAM |
| **Database** | PostgreSQL 15+ (with pgvector / Supabase engine) | Managed PostgreSQL or Supabase Cluster |
| **Backend Runtime** | Python 3.11+ (FastAPI + Uvicorn/Gunicorn) | Multi-worker Gunicorn container |
| **Frontend Runtime** | Flutter 3.24+ | Web / Android / iOS / Desktop |

---

## 2. Environment Configuration

The following environment variables must be configured in `backend/.env` or the production secret store:

```env
# Database & Supabase Gateway
SUPABASE_URL=http://kong:8000
SUPABASE_SERVICE_ROLE_KEY=<production_service_role_secret>
DATABASE_URL=postgresql://postgres:<password>@supabase-db:5432/postgres

# AI & LLM Provider API Keys
GEMINI_API_KEY=<google_gemini_api_key>
OPENAI_API_KEY=<optional_openai_fallback_key>

# JWT Authentication
JWT_SECRET=<jwt_encryption_secret>
JWT_ALGORITHM=HS256

# App Configurations
DEFAULT_AI_MODEL=gemini-1.5-flash
ENABLE_AI_VOICE=true
ENABLE_ENTERPRISE_TOOLS=true
```

---

## 3. Database Migration Procedure

The schema migration is located at:
`EduSHAMIIT Database/edushamiit-db/migrations/427_ai_assistant_enterprise_enhancements.sql`

### 3.1 Applying the Migration
Run the migration script against the primary PostgreSQL instance:

```bash
# Via Docker
docker exec -i supabase-db psql -U postgres -d postgres < "EduSHAMIIT Database/edushamiit-db/migrations/427_ai_assistant_enterprise_enhancements.sql"

# Or via PowerShell on Windows host
Get-Content "EduSHAMIIT Database\edushamiit-db\migrations\427_ai_assistant_enterprise_enhancements.sql" -Raw | docker exec -i supabase-db psql -U postgres -d postgres
```

### 3.2 Verifying Migration Success
Execute the following verification query:
```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_name IN (
    'ai_conversations', 
    'ai_chat_history', 
    'ai_attachments', 
    'ai_tool_executions', 
    'ai_usage_logs', 
    'ai_feedback', 
    'ai_provider_configs'
);
```
Expected result: **7 rows returned**.

---

## 4. Container Deployment & Startup

The backend service runs inside the `edushamiit-api` container.

### 4.1 Restarting the Backend Service
To load updated tools, routers, and services:
```bash
docker restart edushamiit-api
```

### 4.2 Verifying Container Logs & Health
```bash
docker logs --tail 50 edushamiit-api
```
Confirm:
- Uvicorn/Gunicorn worker started successfully.
- `/api/chat` and `/api/v1/ai` routers mounted with 0 import errors.
- Supabase connection established.

---

## 5. Post-Deployment Verification & Smoke Tests

### 5.1 Automated E2E Test
Execute the end-to-end verification script:
```bash
python scripts/test_ai_assistant_e2e.py
```
Expected output:
```
==================================================================
  ALL E2E SUITES PASSED SUCCESSFULLY! (0 Failures, 100% Pass Rate)
==================================================================
```

### 5.2 Unit Test Suite Execution
```bash
python -m pytest "EduSHAMIIT Backend/backend/tests/test_ai_*.py" -v
```
Expected output: **12 passed, 0 failed**.

### 5.3 Frontend Smoke Check
1. Open the EduSHAMIIT Admin dashboard (`/admin/ai-chat`).
2. Verify the 3-panel workspace renders matching `media_1794062378830_e6ceb9d4.jpg`.
3. Click **"+ New Chat"** and test sending:
   - *"Show me the fee collection report for this month."*
   - Verify that the fee report renders with INR currency (`₹ 12,84,500`) and the embedded `[View Report]` card.
4. Test clicking a Suggested Question chip (e.g., *"Show me today's attendance."*).
5. Verify Thumbs Up / Thumbs Down feedback icons record successfully.
6. Verify conversation title updates, pinning, and deletion from the Left Panel context menu.

---

## 6. Rollback & Disaster Recovery

If rollback is required:
1. Revert Git commits on frontend/backend repositories.
2. The migration `427_ai_assistant_enterprise_enhancements.sql` is non-destructive (uses `IF NOT EXISTS` and adds columns with defaults). It does NOT drop existing `ai_chat_history` columns.
3. Restart container:
   ```bash
   docker restart edushamiit-api
   ```
