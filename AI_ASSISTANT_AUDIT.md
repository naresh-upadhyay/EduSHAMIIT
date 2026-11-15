# EduSHAMIIT ERP - AI Assistant Module Technical Audit

**Audit Date:** November 7, 2026  
**Audited Subsystems:** Flutter Web/Desktop/Mobile Frontend (`edu_shamiit_core`, `edu_shamiit_admin`, `edu_shamiit_academic`), Python FastAPI Backend (`EduSHAMIIT Backend`), PostgreSQL Database (`edushamiit-db` / Supabase).

---

## 1. Existing Implementation Overview

### 1.1 Frontend Architecture
- **Location:** `edu_shamiit_core/lib/screens/ai_chat/ai_chat_screen.dart` and `edu_shamiit_core/lib/providers/ai_chat_provider.dart`.
- **State Management:** Riverpod (`StateNotifier<AiChatState>`).
- **Communication:** Server-Sent Events (SSE) streaming via `SseClient` (`sendRequest`) pointing to `/api/chat/message`.
- **UI Layout:** Single full-height chat screen with a collapsible slide-over Drawer for chat history, bottom composer with attachment button, speech-to-text (STT) mic button, and quick suggestion chips above the composer.
- **Media Support:** Uploads images and documents via multipart/SSE with preview. Text-to-Speech (TTS) integration via `TtsService`.
- **Routing:** Routed in `edu_shamiit_admin` (`/admin/ai-chat`) and `edu_shamiit_academic` (`/student/ai-chat`) via `GoRoute` returning `AiChatScreen`.

### 1.2 Backend Architecture
- **Location:** `EduSHAMIIT Backend/backend/app/api/chat.py`, `app/services/langchain_agent.py`, `app/agents/router.py`, `app/agents/prompts.py`, `app/tools/*`.
- **Framework:** FastAPI with async streaming responses (`StreamingResponse(media_type="text/event-stream")`).
- **Agent Orchestrator:** LangChain with `bind_tools`, `ToolsAgentOutputParser`, and multi-tier model fallbacks (Google Gemini -> OpenRouter -> GitHub Models).
- **Authentication & Multi-Tenancy:** JWT bearer token validation in `app/middleware/auth.py`, extracting `school_id`, `user_id`, and `role`. School ID scoping enforced across all tool queries.
- **Existing Endpoints:**
  - `POST /api/chat/message`: SSE stream generating incremental agent steps and token chunks.
  - `GET /api/chat/history/{session_id}`: Paginated message history retrieval.
  - `GET /api/chat/sessions`: Lists sessions grouped from `ai_chat_history`.
  - `DELETE /api/chat/session/{session_id}`: Deletes history for a session.
  - `GET /api/chat/download/{file_name}`: Secure static asset download.
  - `GET /api/chat/image-proxy`: Image proxy bypassing CORS.

### 1.3 Database Architecture
- **Existing Tables:**
  - `public.ai_chat_history`: Stores message rows (`id`, `school_id`, `user_id`, `session_id`, `role`, `content`, `tool_calls`, `created_at`, `updated_at`).
  - `public.knowledge_base`: Stores vector embeddings (`embedding vector(1536)`) and text content for RAG queries.
  - `public.ai_insights`, `public.ai_recommendations`, `public.ai_predictions`: Pre-calculated metrics, system alerts, and operational forecasts.

---

## 2. Existing Reusable Tables

| Table Name | Schema & Purpose | Reusability Strategy |
|---|---|---|
| `ai_chat_history` | Message-level persistence with school and user scope. | **Reuse directly.** Add nullable columns for feedback rating, execution duration, tokens used, status, and metadata. |
| `knowledge_base` | RAG vector storage with `pgvector` index and FTS search. | **Reuse directly.** Expand categories for ERP policies, circulars, and FAQs. |
| `ai_insights` | System-generated insights for school performance. | **Reuse directly.** Connect AI Assistant smart insights tools to read/generate dynamic insights. |
| `ai_recommendations` | Actionable recommendations for administrative workflows. | **Reuse directly.** |
| `ai_predictions` | Predictive analytics for fees, attendance, and server loads. | **Reuse directly.** |
| `profiles` | Multi-role user accounts (Admin, Principal, Teacher, Student, Parent, Staff). | **Reuse directly** for identity, role verification, and access boundaries. |
| `schools` | Multi-school tenant definitions. | **Reuse directly** for tenant-level isolation. |
| `fees` & `payments` | Fee dues, invoice heads, and transaction records. | **Reuse directly** for AI financial tools and fee collection reports. |
| `attendance` | Daily student attendance records. | **Reuse directly** for AI attendance queries and anomaly detection. |
| `hostel_rooms`, `hostel_beds`, `hostel_complaints` | Complete hostel management records. | **Reuse directly** for hostel assistant queries. |
| `library_books`, `library_borrows` | Library catalogue and circulation records. | **Reuse directly** for book search and overdue summaries. |
| `bus_routes`, `vehicles` | Transport routes, vehicle records, and driver assignments. | **Reuse directly** for transport queries. |
| `notices` | School-wide notices and circulars. | **Reuse directly** for drafting and publishing notices. |

---

## 3. Existing Reusable APIs

| Endpoint | Method | Reusability & Enhancement Strategy |
|---|---|---|
| `/api/chat/message` | `POST` | Keep fully backwards-compatible. Stream responses with structured event schemas (text chunks, tool calls, report cards, follow-up suggestions). |
| `/api/chat/history/{session_id}` | `GET` | Keep backwards-compatible. Support message filtering and metadata returns. |
| `/api/chat/sessions` | `GET` | Enhance with metadata from the new `ai_conversations` relation (title, pinned status, archive status, active module). |
| `/api/chat/session/{session_id}` | `DELETE` | Retain for backwards compatibility while adding soft-delete and archive options. |
| `/api/chat/download/{file_name}` | `GET` | Retain with path-traversal safeguards for downloading generated PDFs and spreadsheets. |
| `/api/chat/image-proxy` | `GET` | Retain for rendering external AI-generated illustrations. |
| `/api/notices` | `GET`, `POST` | Reused by Notice Drafting AI action tool. |
| `/api/attendance` | `GET` | Reused by Attendance Intelligence AI tool. |
| `/api/v1/payment-management` | `GET` | Reused by Fee Intelligence AI tool. |
| `/api/documents` | `GET`, `POST` | Reused for AI document understanding and attachment storage. |

---

## 4. Missing Features & Gaps Identified

1. **Workspace Layout Gap:** The current screen is a single chat column with mobile drawer. The reference UI requires a sleek **3-panel workspace** (Left: Conversation history categorized by Today/Yesterday/7-days/30-days/Pinned/Archived; Center: Interactive Chat Workspace with KPI summary blocks and action cards; Right: Quick Actions, AI Tools, Connected Modules context, and Dynamic Suggestions).
2. **Conversation Metadata Management:** No dedicated table for conversation metadata (conversations are currently inferred by `DISTINCT session_id` queries). Missing pinning, archiving, renaming, search across conversations, and export.
3. **Structured Response Rendering:** Responses currently only render markdown text and image cards. Missing rich KPI summary cards (Total Collected, Total Pending, Collection Rate), Interactive Action Buttons (e.g. `[View Report]`, `[View Pending Fee List]`), data tables, and inline charts.
4. **Action Confirmation Lifecycle:** Missing a 2-step confirmation workflow for sensitive ERP actions (e.g., fee reminders, notices, grade modifications).
5. **Role-Based AI Tools:** Admins only had 4 basic tools assigned in `ROLE_TOOLS`. High-level administration tools (Finance analysis, HR leaves, Hostel queries, Library analytics, Cross-module correlation) were missing.
6. **AI Usage & Budget Controls:** No logging of token consumption, latency, or model costs. No rate-limiting or usage quotas per user/institute.
7. **Document Understanding & RAG Pipeline:** Basic document upload exists in Flutter, but document text extraction (PDF, DOCX, XLSX) and contextual indexing need robust backend pipelines.
8. **Feedback Loop:** No database storage or API endpoint for message ratings (Like/Dislike) and user comments.

---

## 5. Security & Isolation Analysis

1. **Multi-Tenant Data Isolation:** Ensure `school_id` is strictly extracted from the authenticated JWT token and never accepted as an unverified user-supplied input.
2. **RBAC Enforcement on Tools:** Tool executions must independently verify the user's role against permissions on the backend before executing any database query or mutative action.
3. **No Arbitrary SQL:** The LLM must never execute unparameterized or dynamic SQL. All ERP queries must go through validated, parameter-bound Python service functions and Supabase query builders.
4. **Prompt Injection Defense:** File contents, external inputs, and OCR transcripts must be treated strictly as untrusted data inputs, demarcated with boundary tags, and stripped of system override instructions.
5. **Safe File Handling:** Path traversal validation is present in `/download`, but mime-type verification and virus/malware inspection safeguards should be standardized for uploads.

---

## 6. Performance & Scalability Bottlenecks

1. **Session Listing Aggregation:** Querying `ai_chat_history` with descending ordering and manual Python deduplication causes linear degradation as chat history grows. Dedicated `ai_conversations` table with indexing solves this.
2. **Context Window Saturation:** Loading up to 40 previous messages into the LLM prompt without token budgeting can lead to context-length errors or excessive token expenditure. Message pruning and summarization are required.
3. **Blocking Synchronous Operations:** Report generation and document OCR must run asynchronously without stalling the SSE event stream.

---

## 7. UI/UX Inconsistencies & Target Alignment

1. **Target Design Aesthetics:**
   - Soft enterprise blue palette (`#4F46E5` / `#2563EB` accents, clean `#F8FAFC` background in light mode, `#0F172A` in dark mode).
   - Robot icon in rounded container with "AI Assistant Beta" header pill.
   - 3-column layout matching the provided screenshot (`media_1794062378830_e6ceb9d4.jpg`).
   - Quick action grid: "Generate Report", "Student Search", "Attendance Query", "Fee Report", "Timetable", "Send Notice".
   - Contextual suggested questions with navigation arrow buttons.
   - Clean, rounded message bubbles with initials badge for users and robot avatar for AI.
   - Embedded interactive action cards (`[View Report]`, `[View Pending Fee List]`) inside responses.

---

## 8. Database Migration Plan (`427_ai_assistant_enterprise_enhancements.sql`)

1. **Create `public.ai_conversations`**:
   - Stores `id (UUID PRIMARY KEY)`, `school_id`, `user_id`, `title`, `context_module`, `is_pinned`, `is_archived`, `model`, `created_at`, `updated_at`.
   - Backfill existing distinct `session_id`s from `ai_chat_history`.
2. **Enhance `public.ai_chat_history`**:
   - Add `feedback_rating INT`, `feedback_text TEXT`, `status TEXT`, `tokens_used INT`, `duration_ms INT`, `metadata JSONB`.
3. **Create `public.ai_attachments`**:
   - Stores uploaded document references, extracted text snippets, and metadata.
4. **Create `public.ai_tool_executions`**:
   - Records tool name, input parameters, execution status, preview data, and audit tracking.
5. **Create `public.ai_usage_logs`**:
   - Records tokens, latency, provider, model, and estimated cost per request.
6. **Create `public.ai_feedback`**:
   - Stores detailed feedback submissions.
7. **Create `public.ai_provider_configs`**:
   - Allows configurable LLM providers and models per school or globally.
8. **Add Indexes & RLS Policies**:
   - Ensure tenant isolation on all newly created tables.

---

## 9. Implementation Execution Roadmap

- **Phase 2:** Execute safe database migration `427_ai_assistant_enterprise_enhancements.sql`.
- **Phase 3:** Implement FastAPI services:
  - `AIConversationService`, `AIMessageService`, `AIToolRegistryService`, `AIReportService`, `AIUsageService`, `AIFeedbackService`.
  - Add comprehensive routers under `/api/v1/ai` and enhance `/api/chat`.
- **Phase 4:** Expand tool registry with full ERP cross-module intelligence (Finance, HR, Transport, Hostel, Library, Students, Attendance, Notices).
- **Phase 5:** Upgrade Flutter UI to the full 3-Panel workspace matching the reference screenshot:
  - Left panel: Searchable, categorized conversation history.
  - Center panel: Rich chat stream with KPI summaries, interactive report cards, follow-up chips, and professional composer.
  - Right panel: AI Tools, Quick Actions grid, Suggested Questions, and Context selector.
- **Phase 6:** Automated testing suite and E2E verification script `scripts/test_ai_assistant_e2e.py`.
- **Phase 7:** Final documentation deliverables.
