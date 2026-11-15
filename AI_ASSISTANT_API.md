# EduSHAMIIT ERP - AI Assistant API Specification

## 1. Overview & Authentication

All AI Assistant endpoints are mounted on the FastAPI backend and proxied through the Supabase Kong Gateway (`http://localhost:8000` or production domain).

- **Base URL**: `/api/v1/ai` and `/api/chat`
- **Authentication**: Bearer JWT token in the `Authorization` header.
- **Tenant Context**: The `school_id` and `user_id` are automatically extracted from the verified JWT claims by FastAPI security dependencies. Cross-tenant spoofing is strictly rejected.

```http
Authorization: Bearer <access_token>
Content-Type: application/json
```

---

## 2. Core Conversation Endpoints

### 2.1 List Conversations
Retrieves conversations for the authenticated user within their school.

- **Method**: `GET`
- **Route**: `/api/v1/ai/conversations`
- **Query Parameters**:
  - `is_archived` (boolean, optional, default: `false`): Filter by archived or active.
  - `limit` (integer, optional, default: `50`): Max conversations to return.
  - `search` (string, optional): Substring filter on title.

#### Response `200 OK`
```json
{
  "success": true,
  "data": [
    {
      "id": "7b587b1c-7f5b-4394-91bc-341a99dcb76e",
      "school_id": "11111111-1111-1111-1111-111111111111",
      "user_id": "10000000-0000-0000-0000-000000000002",
      "title": "Fee Collection Report",
      "context_module": "finance",
      "is_pinned": true,
      "is_archived": false,
      "model": "gemini-1.5-flash",
      "created_at": "2026-11-07T10:24:00Z",
      "updated_at": "2026-11-07T10:24:00Z"
    }
  ]
}
```

---

### 2.2 Create Conversation
Initializes a new AI chat conversation session.

- **Method**: `POST`
- **Route**: `/api/v1/ai/conversations`
- **Request Body**:
```json
{
  "title": "Class 10 Attendance Review",
  "context_module": "attendance",
  "model": "gemini-1.5-flash"
}
```

#### Response `200 OK`
```json
{
  "success": true,
  "data": {
    "id": "c1f8876e-3677-4589-a5f1-325d7b5bf3c1",
    "school_id": "11111111-1111-1111-1111-111111111111",
    "user_id": "10000000-0000-0000-0000-000000000002",
    "title": "Class 10 Attendance Review",
    "context_module": "attendance",
    "is_pinned": false,
    "is_archived": false,
    "model": "gemini-1.5-flash",
    "created_at": "2026-11-07T10:25:00Z",
    "updated_at": "2026-11-07T10:25:00Z"
  }
}
```

---

### 2.3 Get Conversation Details & Messages
Fetches conversation metadata and full message history.

- **Method**: `GET`
- **Route**: `/api/v1/ai/conversations/{conv_id}`

#### Response `200 OK`
```json
{
  "success": true,
  "data": {
    "conversation": {
      "id": "c1f8876e-3677-4589-a5f1-325d7b5bf3c1",
      "title": "Class 10 Attendance Review",
      "is_pinned": false,
      "is_archived": false
    },
    "messages": [
      {
        "id": "d0577be1-3141-4cf1-8aa2-f94d13fa89d4",
        "role": "user",
        "content": "Show me today's attendance.",
        "created_at": "2026-11-07T10:25:05Z"
      },
      {
        "id": "f51253d8-e7a9-4458-947b-1ceb48590ef2",
        "role": "assistant",
        "content": "📊 **Attendance Summary for Today**\n\n• Total Students: 320\n• Present: 292 (91.2%)\n• Absent: 28 (8.8%)\n\n:::card type=\"attendance_summary\" title=\"Daily Attendance Overview\" subtitle=\"Class registers\" action=\"View Attendance Details\" url=\"/admin/attendance\" :::",
        "created_at": "2026-11-07T10:25:08Z",
        "feedback_rating": 1
      }
    ]
  }
}
```

---

### 2.4 Update Conversation (Rename, Pin, Archive)
Updates conversation properties.

- **Method**: `PATCH`
- **Route**: `/api/v1/ai/conversations/{conv_id}`
- **Request Body**:
```json
{
  "title": "Renamed Attendance Session",
  "is_pinned": true,
  "is_archived": false,
  "context_module": "academics"
}
```

#### Response `200 OK`
```json
{
  "success": true,
  "data": {
    "id": "c1f8876e-3677-4589-a5f1-325d7b5bf3c1",
    "title": "Renamed Attendance Session",
    "is_pinned": true,
    "is_archived": false,
    "context_module": "academics",
    "updated_at": "2026-11-07T10:26:00Z"
  }
}
```

---

### 2.5 Delete Conversation
Soft-deletes or purges a conversation and its message tree.

- **Method**: `DELETE`
- **Route**: `/api/v1/ai/conversations/{conv_id}`

#### Response `200 OK`
```json
{
  "success": true,
  "message": "Conversation deleted successfully."
}
```

---

### 2.6 Export Conversation
Exports conversation transcripts into JSON or human-readable Plain Text format.

- **Method**: `GET`
- **Route**: `/api/v1/ai/conversations/{conv_id}/export`
- **Query Parameters**:
  - `format`: `"json"` or `"text"` (default: `"json"`)

#### Response `200 OK` (Format: `json`)
```json
{
  "format": "json",
  "conversation": { "id": "c1f8876e-3677-4589-a5f1-325d7b5bf3c1", "title": "Class 10 Attendance Review" },
  "messages": [ ... ],
  "exported_at": "2026-11-07T10:27:00Z"
}
```

---

## 3. Feedback & Telemetry Endpoints

### 3.1 Submit User Feedback
Records user ratings on assistant responses.

- **Method**: `POST`
- **Route**: `/api/v1/ai/feedback`
- **Request Body**:
```json
{
  "message_id": "f51253d8-e7a9-4458-947b-1ceb48590ef2",
  "rating": 1,
  "feedback_text": "Accurate figures and quick response."
}
```

#### Response `200 OK`
```json
{
  "success": true,
  "data": {
    "feedback_id": "9d27f8aa-4623-4412-87ce-802ba98e1f02",
    "status": "recorded"
  }
}
```

---

### 3.2 Dynamic Role Suggestions
Returns contextual Quick Actions and Suggested Questions according to the caller's role.

- **Method**: `GET`
- **Route**: `/api/v1/ai/suggestions`

#### Response `200 OK` (Admin Role)
```json
{
  "success": true,
  "data": {
    "quick_actions": [
      { "id": "gen_report", "label": "Generate Report", "icon": "bar_chart", "prompt": "Generate a comprehensive fee and attendance report for this month." },
      { "id": "student_search", "label": "Student Search", "icon": "person_search", "prompt": "Search student details by name or roll number." },
      { "id": "att_query", "label": "Attendance Query", "icon": "event_available", "prompt": "Show me today's attendance summary for all classes." },
      { "id": "fee_report", "label": "Fee Report", "icon": "currency_rupee", "prompt": "Show me the fee collection report for this month for all classes." },
      { "id": "timetable", "label": "Timetable", "icon": "schedule", "prompt": "Show me the timetable for Class 10." },
      { "id": "send_notice", "label": "Send Notice", "icon": "campaign", "prompt": "Draft a notice for parents regarding the upcoming school event." }
    ],
    "suggested_questions": [
      "Show me today's attendance.",
      "Generate class 10 timetable.",
      "List all pending fees.",
      "How many students are in Class 9?",
      "Show recent notices."
    ]
  }
}
```

---

### 3.3 List Available Tools
Lists all ERP tools accessible to the logged-in role.

- **Method**: `GET`
- **Route**: `/api/v1/ai/tools`

#### Response `200 OK`
```json
{
  "success": true,
  "role": "admin",
  "tools": [
    {
      "name": "get_fee_collection_report",
      "description": "Generate institute fee collection report with total dues, collected, pending, and collection rate."
    },
    {
      "name": "draft_school_notice",
      "description": "Draft a formal institute notice or circular for parents, students, or staff."
    }
  ]
}
```

---

### 3.4 Usage & Cost Analytics
Returns token consumption, latency benchmarks, and cost estimates.

- **Method**: `GET`
- **Route**: `/api/v1/ai/usage`

#### Response `200 OK`
```json
{
  "success": true,
  "data": {
    "total_requests": 142,
    "total_tokens": 85400,
    "estimated_cost_inr": 1.10,
    "average_latency_ms": 780.4,
    "model_breakdown": {
      "gemini-1.5-flash": 138,
      "gemini-2.5-pro": 4
    }
  }
}
```

---

## 4. HTTP Status Codes & Error Handling

| Code | Meaning | Example Scenario |
|---|---|---|
| `200 OK` | Success | Normal operation completed. |
| `400 Bad Request` | Invalid Input | Rating value outside `[-1, 1]` or malformed JSON. |
| `401 Unauthorized` | Missing / Invalid Token | Expired or absent Bearer token. |
| `403 Forbidden` | RBAC / Tenant Boundary | Student trying to fetch fee collection report or user attempting to query a different `school_id`. |
| `404 Not Found` | Resource Missing | Conversation ID not found for current user. |
| `500 Server Error` | Backend Exception | Database connectivity timeout or upstream LLM outage. |
