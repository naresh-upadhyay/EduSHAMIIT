# Parent Portal Feature — Architecture Plan

## 1. Overview

The Parent Portal enables parents/guardians to log into EduSHAMIIT and monitor their children's academic progress, attendance, fee payments, and school communications. The system already has a `parent` role defined in the database and Flutter `UserRole` enum, but no dedicated backend API or frontend screens exist yet.

---

## 2. Key Architecture Decisions

### 2.1 Parent-Student Relationship

A **many-to-many** relationship between parents and students is needed because:

- A parent can have **multiple children** in the same school
- A child may have **multiple guardians** (father, mother, local guardian)

### 2.2 Child Switcher Pattern

Parents with multiple children will use a **child switcher dropdown** in the app bar. The selected child's ID is stored in a Riverpod `StateProvider` and passed to all API calls. This avoids duplicating screens per child.

### 2.3 Read-Only with Limited Write Access

Parents are primarily **readers** of student data, but can:

- Apply for leave on behalf of a student
- Send messages to teachers
- Pay fees online
- Update their own profile/settings

---

## 3. Database Changes

### 3.1 New Migration: `parent_student_relations`

```sql
CREATE TABLE IF NOT EXISTS parent_student_relations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  parent_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  student_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  relationship TEXT NOT NULL CHECK (relationship IN ('father','mother','guardian','other')),
  is_primary BOOLEAN DEFAULT FALSE,
  can_pickup BOOLEAN DEFAULT FALSE,
  approved BOOLEAN DEFAULT FALSE,
  approved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(parent_id, student_id)
);
```

### 3.2 New Migration: `parent_notifications`

Leverage the existing `notifications` table — no new table needed. Parents will receive notifications with `user_id` pointing to the parent profile.

### 3.3 RLS Policies for Parent Role

Add Row Level Security policies so parents can only read data belonging to their linked students:

```sql
-- Parent can read attendance for their children
CREATE POLICY parent_read_attendance ON attendance
  FOR SELECT USING (
    school_id = (SELECT school_id FROM profiles WHERE id = auth.uid())
    AND student_id IN (
      SELECT student_id FROM parent_student_relations
      WHERE parent_id = auth.uid() AND approved = TRUE
    )
  );

-- Similar policies for: results, fees, payments, homework_submissions,
-- leave_applications, student_achievements, student_transport
```

### 3.4 Database Function: `get_parent_dashboard_summary`

```sql
CREATE OR REPLACE FUNCTION get_parent_dashboard_summary(
  p_school_id UUID, p_parent_id UUID, p_student_id UUID
) RETURNS JSONB AS $$
DECLARE
  v_student RECORD;
  v_attendance JSONB;
  v_results JSONB;
  v_fees JSONB;
  v_upcoming JSONB;
BEGIN
  -- Verify parent-child relationship
  IF NOT EXISTS (
    SELECT 1 FROM parent_student_relations
    WHERE parent_id = p_parent_id AND student_id = p_student_id AND approved = TRUE
  ) THEN
    RAISE EXCEPTION 'Not authorized for this student';
  END IF;

  SELECT full_name, class, avatar_url INTO v_student
    FROM profiles WHERE id = p_student_id;

  SELECT jsonb_agg(row_to_json(a.*)) INTO v_attendance
    FROM attendance a WHERE a.student_id = p_student_id
    ORDER BY a.date DESC LIMIT 30;

  SELECT jsonb_agg(row_to_json(r.*)) INTO v_results
    FROM results r WHERE r.student_id = p_student_id
    ORDER BY r.created_at DESC LIMIT 10;

  SELECT jsonb_agg(row_to_json(f.*)) INTO v_fees
    FROM fees f WHERE f.student_id = p_student_id AND f.status = 'pending';

  SELECT jsonb_build(
    'exams', (SELECT jsonb_agg(row_to_json(e.*)) FROM exams e
      WHERE e.school_id = p_school_id AND e.start_time >= NOW()
      ORDER BY e.start_time LIMIT 5),
    'events', (SELECT jsonb_agg(row_to_json(ev.*)) FROM events ev
      WHERE ev.school_id = p_school_id AND ev.start_date >= NOW()
      ORDER BY ev.start_date LIMIT 5)
  ) INTO v_upcoming;

  RETURN jsonb_build(
    'student', row_to_json(v_student),
    'attendance', v_attendance,
    'recent_results', v_results,
    'pending_fees', v_fees,
    'upcoming', v_upcoming
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 4. Backend API Changes

### 4.1 New File: `backend/app/api/parent.py`

All endpoints use `require_parent` auth dependency.

| Method | Endpoint                                | Description                             |
| ------ | --------------------------------------- | --------------------------------------- |
| GET    | `/parent/dashboard?student_id=`         | Dashboard overview for a specific child |
| GET    | `/parent/children`                      | List all linked children                |
| GET    | `/parent/attendance?student_id=&month=` | Attendance records                      |
| GET    | `/parent/results?student_id=`           | Academic results                        |
| GET    | `/parent/fees?student_id=`              | Fee details and payment history         |
| GET    | `/parent/homework?student_id=`          | Homework assignments and submissions    |
| GET    | `/parent/transport?student_id=`         | Bus route and stop info                 |
| GET    | `/parent/leave?student_id=`             | Leave applications                      |
| POST   | `/parent/leave/apply`                   | Apply for leave on behalf of student    |
| GET    | `/parent/notifications`                 | Parent notifications                    |
| GET    | `/parent/messages`                      | Messages with teachers                  |
| POST   | `/parent/messages/send`                 | Send message to teacher                 |
| GET    | `/parent/timetable?student_id=`         | Student timetable                       |
| GET    | `/parent/achievements?student_id=`      | Student achievements                    |
| GET    | `/parent/events`                        | School events                           |
| GET    | `/parent/notices`                       | School notices                          |

### 4.2 Auth Middleware: Add `require_parent`

In [`auth.py`](EduSHAMIIT Backend/backend/app/middleware/auth.py:91), add alongside existing `require_student` and `require_teacher`:

```python
async def require_parent(user: dict = Depends(get_current_user)) -> dict:
    """Dependency to require parent role."""
    if user.get("role") != "parent":
        raise HTTPException(status_code=403, detail="Access denied. Parent role required.")
    return user
```

### 4.3 Register Router in [`main.py`](EduSHAMIIT Backend/backend/app/main.py:6)

```python
from app.api import auth, student, teacher, shared, chat, voice, image, iot, rag, payments, parent

app.include_router(parent.router, prefix="/api/parent", tags=["Parent"])
```

### 4.4 Pydantic Models

Add to [`models.py`](EduSHAMIIT Backend/backend/app/models.py):

```python
class ParentLeaveRequest(BaseModel):
    student_id: str
    leave_type: str
    start_date: str
    end_date: str
    reason: str

class ParentMessageRequest(BaseModel):
    teacher_id: str
    content: str
    student_id: Optional[str] = None
```

---

## 5. Flutter Frontend Changes

### 5.1 New Feature Directory Structure

```
lib/features/parent/
├── dashboard/
│   └── screens/
│       └── parent_dashboard.dart
├── attendance/
│   └── screens/
│       └── parent_attendance.dart
├── results/
│   └── screens/
│       └── parent_results.dart
├── fees/
│   └── screens/
│       └── parent_fees.dart
├── homework/
│   └── screens/
│       └── parent_homework.dart
├── leave/
│   └── screens/
│       └── parent_leave.dart
├── transport/
│   └── screens/
│       └── parent_transport.dart
├── messaging/
│   └── screens/
│       └── parent_messaging.dart
├── notifications/
│   └── screens/
│       └── parent_notifications.dart
├── profile/
│   └── screens/
│       └── parent_profile.dart
├── settings/
│   └── screens/
│       └── parent_settings.dart
├── timetable/
│   └── screens/
│       └── parent_timetable.dart
└── achievements/
    └── screens/
        └── parent_achievements.dart
```

### 5.2 New Shell Scaffold

Create `lib/shared/widgets/parent_shell_scaffold.dart` following the same pattern as [`student_shell_scaffold.dart`](edu_shamiit_ai/lib/shared/widgets/student_shell_scaffold.dart:12).

**Bottom Nav Items (mobile):**

1. 🏠 Dashboard
2. 📊 Progress
3. 💳 Fees
4. 💬 Messages
5. 👤 Profile

**Sidebar Items (desktop):**
All of the above plus: Attendance, Timetable, Homework, Leave, Transport, Achievements, Notifications, Settings

### 5.3 Parent Theme

Create `lib/core/theme/parent_theme.dart` and `lib/core/constants/parent_colors.dart`:

- Primary color: Deep teal/green (#0D9488) — distinct from student blue and teacher purple
- Accent: Warm amber (#F59E0B)

### 5.4 Child Switcher Widget

Create `lib/shared/widgets/child_switcher.dart`:

- Dropdown in the app bar showing the selected child's name and class
- Uses a `StateProvider<String?>` for the selected child ID
- When switched, all parent screens refresh with the new child's data

### 5.5 Router Changes in [`app_router.dart`](edu_shamiit_ai/lib/app_router.dart:69)

Add a new `ShellRoute` for parent:

```dart
final _parentShellKey = GlobalKey<NavigatorState>(debugLabel: 'parentShell');

// Inside routes list:
ShellRoute(
  navigatorKey: _parentShellKey,
  builder: (context, state, child) => ParentShellScaffold(child: child),
  routes: [
    GoRoute(path: '/parent/dashboard', ...),
    GoRoute(path: '/parent/attendance', ...),
    GoRoute(path: '/parent/results', ...),
    GoRoute(path: '/parent/fees', ...),
    GoRoute(path: '/parent/homework', ...),
    GoRoute(path: '/parent/leave', ...),
    GoRoute(path: '/parent/transport', ...),
    GoRoute(path: '/parent/messaging', ...),
    GoRoute(path: '/parent/notifications', ...),
    GoRoute(path: '/parent/profile', ...),
    GoRoute(path: '/parent/settings', ...),
    GoRoute(path: '/parent/timetable', ...),
    GoRoute(path: '/parent/achievements', ...),
    GoRoute(path: '/parent/ai-chat', ...),
  ],
),
```

Update redirect logic to handle parent role:

```dart
if (role.value == 'parent') {
  return '/parent/dashboard';
}
```

### 5.6 Auth Provider Updates

In [`auth_provider.dart`](edu_shamiit_ai/lib/core/providers/auth_provider.dart:12), the `signIn` method already handles role from the backend response. The `UserRole.parent` enum value already exists in [`role_provider.dart`](edu_shamiit_ai/lib/core/providers/role_provider.dart:8). No changes needed here — the backend login response just needs to return `role: "parent"`.

### 5.7 New Providers

Create `lib/core/providers/parent_provider.dart`:

- `childrenProvider` — fetches list of linked children
- `selectedChildProvider` — `StateProvider<String?>` for currently selected child
- `parentDashboardProvider` — fetches dashboard data for selected child

---

## 6. Data Flow Diagram

```mermaid
flowchart TB
    subgraph Flutter App
        A[Login Screen] -->|role=parent| B[Parent Shell Scaffold]
        B --> C[Child Switcher]
        C -->|selected_child_id| D[Parent Dashboard]
        C -->|selected_child_id| E[Attendance Screen]
        C -->|selected_child_id| F[Results Screen]
        C -->|selected_child_id| G[Fees Screen]
        C -->|selected_child_id| H[Other Screens...]
    end

    subgraph FastAPI Backend
        I[/api/parent/children]
        J[/api/parent/dashboard?student_id=]
        K[/api/parent/attendance?student_id=]
        L[/api/parent/results?student_id=]
        M[/api/parent/fees?student_id=]
        N[/api/parent/leave/apply]
    end

    subgraph PostgreSQL Database
        O[parent_student_relations]
        P[profiles]
        Q[attendance]
        R[results]
        S[fees + payments]
        T[homework + submissions]
    end

    D --> J
    E --> K
    F --> L
    G --> M
    I --> O
    J --> O
    J --> Q
    J --> R
    J --> S
    K --> Q
    L --> R
    M --> S
    O --> P
```

---

## 7. Security Considerations

1. **Parent-Student Link Verification**: Every parent API endpoint must verify the `parent_student_relations` record exists and is `approved = TRUE` before returning data
2. **RLS Policies**: Database-level Row Level Security ensures parents cannot query data for students they are not linked to
3. **JWT Role**: The `role: parent` claim in JWT ensures the auth middleware gates access correctly
4. **Approval Workflow**: New parent-student links require admin/teacher approval before data access is granted
5. **Read-Only Enforcement**: Parents cannot modify attendance, results, or homework — only read

---

## 8. Implementation Order

The work is broken into phases that can be implemented incrementally:

### Phase 1: Foundation (Database + Auth)

1. Create migration for `parent_student_relations` table
2. Create migration for RLS policies for parent role
3. Create migration for `get_parent_dashboard_summary` function
4. Add `require_parent` to auth middleware
5. Add sample data migration for parent-student relations

### Phase 2: Backend API

6. Create `backend/app/api/parent.py` with all endpoints
7. Add Pydantic models for parent requests
8. Register parent router in `main.py`
9. Test all parent endpoints

### Phase 3: Flutter Frontend — Core

10. Create `parent_colors.dart` and `parent_theme.dart`
11. Create `parent_shell_scaffold.dart` with bottom nav and sidebar
12. Create `child_switcher.dart` widget
13. Create `parent_provider.dart` with Riverpod providers
14. Update `app_router.dart` with parent shell route and redirect
15. Update `app.dart` to select parent theme

### Phase 4: Flutter Frontend — Screens

16. Create `parent_dashboard.dart` screen
17. Create `parent_attendance.dart` screen
18. Create `parent_results.dart` screen
19. Create `parent_fees.dart` screen
20. Create `parent_homework.dart` screen
21. Create `parent_leave.dart` screen
22. Create `parent_transport.dart` screen
23. Create `parent_messaging.dart` screen
24. Create `parent_notifications.dart` screen
25. Create `parent_profile.dart` screen
26. Create `parent_settings.dart` screen
27. Create `parent_timetable.dart` screen
28. Create `parent_achievements.dart` screen

### Phase 5: Integration & Polish

29. Integration testing of full parent flow
30. Add AI chat access for parents
31. Add push notification support for parent role
32. Update login screen to show parent role option
