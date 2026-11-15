# EduSHAMIIT ERP - AI Assistant Security & Privacy Specification

## 1. Security Architecture Principles

The EduSHAMIIT AI Assistant is engineered under **defense-in-depth**, **least privilege**, and **zero-trust multi-tenancy** principles. The system enforces strict isolation between different schools, prevents unauthorized privilege escalation, and neutralizes prompt injection vulnerabilities.

---

## 2. Multi-Tenancy & Tenant Data Isolation

### 2.1 Server-Side Context Derivation
- All ERP user requests carry a cryptographic JWT issued upon login.
- FastAPI authentication dependencies (`get_current_user_id`, `get_current_school_id`, `get_user_role`) decode the verified JWT and extract the caller's `school_id` and `user_id`.
- **Zero Client-Side Trust**: Client applications are never permitted to specify the target `school_id` as an input parameter for data retrieval or message storage.
- Every database query executed by the AI service or ERP tools explicitly appends:
  ```sql
  WHERE school_id = :authenticated_school_id
  ```

### 2.2 PostgreSQL Row-Level Security (RLS)
The database migration (`427_ai_assistant_enterprise_enhancements.sql`) enforces PostgreSQL RLS across all AI tables:
- `ai_conversations`: Users can only read, update, or delete rows where `school_id = current_setting('app.current_school_id')` AND `user_id = current_setting('app.current_user_id')`.
- `ai_chat_history`: Messages are scoped to conversations owned by the user.
- `ai_tool_executions` & `ai_usage_logs`: Scoped to `school_id` for administrative audit inspection.

---

## 3. Role-Based Access Control (RBAC) Matrix

Tool access is determined dynamically before invoking the LLM agent. If a tool is not permitted for the user's role, it is completely omitted from the agent's prompt context.

| Tool Name | SuperAdmin / Admin | Director / Principal | Teacher | Student | Parent | Accountant | Librarian | Warden | Transport |
|---|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| `get_fee_collection_report` | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `get_pending_fee_students` | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ | ❌ |
| `get_fee_status` (Self) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ |
| `get_school_attendance_summary` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `get_student_enrollment_overview` | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `get_hostel_status_summary` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ |
| `get_library_status_summary` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ | ❌ | ❌ |
| `get_transport_fleet_summary` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `get_hr_staff_summary` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `draft_school_notice` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `correlate_attendance_and_fees` | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |
| `get_timetable` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `get_homework` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| `get_bus_location` | ✅ | ✅ | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |

---

## 4. Prompt Injection & Jailbreak Defense

1. **Zero SQL Rights**:
   - The LLM has **no direct access to arbitrary SQL execution**, raw table querying, or database credentials.
   - All data interactions flow through discrete, parameterized Python functions.
2. **System Prompt Perimeter**:
   - The foundational system prompt defines immutable operational boundaries:
     - Disallow revealing internal prompt directives or system configurations.
     - Enforce language alignment (English, Hindi, Hinglish) without violating institutional safety policies.
     - Prohibit fabricating student grades, fee records, or attendance logs.
3. **Structured Parameter Coercion**:
   - LangChain `@tool` arguments are validated against strict Pydantic schemas (type checks, length bounds, regex formatting).
   - Malicious prompt payloads (e.g., `"; DROP TABLE students; --"`) are treated as literal strings and cannot escape parameterized query filters.

---

## 5. Human-in-the-Loop (HITL) Action Confirmation

No destructive, state-altering, or communication-dispatching actions are executed autonomously by the AI:
- **School Notices**: The `draft_school_notice` tool returns a structured **Draft Preview**. The notice is explicitly marked:
  ```
  Status: DRAFT (Pending Human Approval)
  ⚠️ Per school policy, notices are not published automatically.
  ```
  An embedded action card (`:::card type="notice_draft" action="Review in Notices Module" url="/admin/notices" :::`) directs authorized staff to formally verify and sign off before publishing.
- **Financial Modifications**: The AI can generate fee reports or Razorpay payment links, but cannot alter fee balances, waive penalties, or modify bank accounts.

---

## 6. Audit Logging & Compliance

Every AI interaction produces persistent, immutable audit records:
- **`ai_tool_executions`**: Captures tool name, input arguments, execution duration, caller identity, and return status.
- **`ai_usage_logs`**: Logs token counts, model identifiers, and execution latencies for cost and anomaly detection.
- **`ai_feedback`**: Records explicit human feedback (+1 / -1 and text comments) for model alignment and quality monitoring.
- **Privacy Notice**: Displayed on all user workspaces:
  > *"AI uses only the information you are authorized to access. AI can make mistakes. Verify important information before taking action."*
