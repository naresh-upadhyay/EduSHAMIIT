-- Migration 467: Seed Rich Automation Rules Matching Exact Design Mockup
DELETE FROM device_automation_rules WHERE school_id = '11111111-1111-1111-1111-111111111111';

INSERT INTO device_automation_rules (id, school_id, name, description, trigger_type, trigger_condition, action_payload, is_active, execution_count)
VALUES
(
    'a1111111-1111-1111-1111-111111111001',
    '11111111-1111-1111-1111-111111111111',
    'Auto Close Classroom Door (No Occupancy)',
    'Close automatic door when no one is in the room for 2 min',
    'smart',
    '{
        "combinator": "AND",
        "category": "Smart Rule",
        "location": "B1 • Classrooms",
        "conditions": [
            {"icon": "people", "attribute": "Occupancy", "operator": "is equal to", "value": "0 (No one)"},
            {"icon": "schedule", "attribute": "For a duration of", "operator": ">=", "value": "2", "unit": "Minutes"}
        ]
    }'::jsonb,
    '{
        "execution_mode": "In Sequence",
        "actions": [
            {"icon": "sensor_door", "target": "Automatic Door", "action": "Close", "parameter": ""},
            {"icon": "notifications", "target": "Send Notification", "action": "To: Facility Team", "parameter": "Room empty door auto-closed"}
        ],
        "options": {"allow_override": true, "log_activity": true, "active": true},
        "effective_for": "always"
    }'::jsonb,
    true,
    142
),
(
    'a1111111-1111-1111-1111-111111111002',
    '11111111-1111-1111-1111-111111111111',
    'Turn Off Lights (Room Empty)',
    'Turn off lights when occupancy is zero for 5 min',
    'smart',
    '{
        "combinator": "AND",
        "category": "Smart Rule",
        "location": "B1 • All Classrooms",
        "conditions": [
            {"icon": "people", "attribute": "Occupancy", "operator": "is equal to", "value": "0 (No one)"},
            {"icon": "schedule", "attribute": "For a duration of", "operator": ">=", "value": "5", "unit": "Minutes"}
        ]
    }'::jsonb,
    '{
        "execution_mode": "In Sequence",
        "actions": [
            {"icon": "lightbulb", "target": "Classroom Lights", "action": "Turn OFF", "parameter": ""}
        ],
        "options": {"allow_override": true, "log_activity": true, "active": true},
        "effective_for": "always"
    }'::jsonb,
    true,
    384
),
(
    'a1111111-1111-1111-1111-111111111003',
    '11111111-1111-1111-1111-111111111111',
    'Turn Off Fans (No Students)',
    'Turn off fans when class ends and room is empty',
    'schedule',
    '{
        "combinator": "AND",
        "category": "Schedule Rule",
        "location": "B1 • Classrooms",
        "conditions": [
            {"icon": "calendar_today", "attribute": "Class Timetable", "operator": "is equal to", "value": "Class Ended"},
            {"icon": "people", "attribute": "Occupancy", "operator": "is equal to", "value": "0 (No one)"}
        ]
    }'::jsonb,
    '{
        "execution_mode": "In Sequence",
        "actions": [
            {"icon": "mode_fan", "target": "Ceiling Fans", "action": "Turn OFF", "parameter": ""}
        ],
        "options": {"allow_override": true, "log_activity": true, "active": true},
        "effective_for": "schedule"
    }'::jsonb,
    true,
    89
),
(
    'a1111111-1111-1111-1111-111111111004',
    '11111111-1111-1111-1111-111111111111',
    'Projector Auto OFF (No Input)',
    'Turn off projector when no signal is detected for 10 min',
    'smart',
    '{
        "combinator": "AND",
        "category": "Smart Rule",
        "location": "B1 • Classrooms",
        "conditions": [
            {"icon": "videocam", "attribute": "Video Input Signal", "operator": "is equal to", "value": "No Signal"},
            {"icon": "schedule", "attribute": "For a duration of", "operator": ">=", "value": "10", "unit": "Minutes"}
        ]
    }'::jsonb,
    '{
        "execution_mode": "In Sequence",
        "actions": [
            {"icon": "tv", "target": "Projector", "action": "Standby / OFF", "parameter": ""}
        ],
        "options": {"allow_override": true, "log_activity": true, "active": true},
        "effective_for": "always"
    }'::jsonb,
    true,
    56
),
(
    'a1111111-1111-1111-1111-111111111005',
    '11111111-1111-1111-1111-111111111111',
    'AC Smart Control (Occupancy + Temp)',
    'Run AC only when room is occupied and temp > 26°C',
    'smart',
    '{
        "combinator": "AND",
        "category": "Smart Rule",
        "location": "B1 • Classrooms",
        "conditions": [
            {"icon": "people", "attribute": "Occupancy", "operator": ">", "value": "0"},
            {"icon": "thermostat", "attribute": "Room Temperature", "operator": ">", "value": "26", "unit": "°C"}
        ]
    }'::jsonb,
    '{
        "execution_mode": "In Sequence",
        "actions": [
            {"icon": "ac_unit", "target": "AC (HVAC)", "action": "Set Temperature", "parameter": "24°C Cool"}
        ],
        "options": {"allow_override": true, "log_activity": true, "active": true},
        "effective_for": "always"
    }'::jsonb,
    true,
    215
),
(
    'a1111111-1111-1111-1111-111111111006',
    '11111111-1111-1111-1111-111111111111',
    'After College Hours (Bulk OFF)',
    'Turn off non-essential devices after 08:00 PM',
    'schedule',
    '{
        "combinator": "AND",
        "category": "Schedule Rule",
        "location": "Entire Campus",
        "conditions": [
            {"icon": "schedule", "attribute": "Time of Day", "operator": ">=", "value": "20:00"}
        ]
    }'::jsonb,
    '{
        "execution_mode": "In Sequence",
        "actions": [
            {"icon": "power", "target": "Non-Essential Relays", "action": "Turn OFF", "parameter": ""}
        ],
        "options": {"allow_override": false, "log_activity": true, "active": true},
        "effective_for": "schedule"
    }'::jsonb,
    true,
    490
),
(
    'a1111111-1111-1111-1111-111111111007',
    '11111111-1111-1111-1111-111111111111',
    'Energy Saving - Weekend Mode',
    'Turn off lights, fans and AC on non-working days',
    'schedule',
    '{
        "combinator": "AND",
        "category": "Schedule Rule",
        "location": "Entire Campus",
        "conditions": [
            {"icon": "calendar_today", "attribute": "Day of Week", "operator": "in", "value": "Saturday, Sunday"}
        ]
    }'::jsonb,
    '{
        "execution_mode": "In Sequence",
        "actions": [
            {"icon": "bolt", "target": "Heavy Load Fixtures", "action": "Power Saver Mode", "parameter": ""}
        ],
        "options": {"allow_override": true, "log_activity": true, "active": true},
        "effective_for": "custom_range"
    }'::jsonb,
    true,
    104
),
(
    'a1111111-1111-1111-1111-111111111008',
    '11111111-1111-1111-1111-111111111111',
    'Main Entrance - Auto Open (Class Time)',
    'Open main entrance 30 min before first class',
    'schedule',
    '{
        "combinator": "AND",
        "category": "Schedule Rule",
        "location": "B1 • Main Entrance",
        "conditions": [
            {"icon": "schedule", "attribute": "Time of Day", "operator": "is equal to", "value": "07:30"}
        ]
    }'::jsonb,
    '{
        "execution_mode": "In Sequence",
        "actions": [
            {"icon": "door_front_door", "target": "Main Entrance Gate", "action": "Open", "parameter": ""}
        ],
        "options": {"allow_override": true, "log_activity": true, "active": false},
        "effective_for": "schedule"
    }'::jsonb,
    false,
    18
);
