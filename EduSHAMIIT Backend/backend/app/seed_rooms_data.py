import os
import sys
import psycopg2
import json

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres:eduSHAMIIT2026_pg@db:5432/postgres")

school_id = "11111111-1111-1111-1111-111111111111"

rooms = [
    {
        "name": "Physics Lab",
        "code": "PHY-LAB-01",
        "type": "Laboratory",
        "building": "Science Block",
        "floor": "1st Floor",
        "capacity": 40,
        "facilities": ["Laboratory Equipment", "Projector", "AC", "Internet", "CCTV"],
        "status": "AVAILABLE",
        "description": "Equipped with advanced optics, mechanics and electronics instruments."
    },
    {
        "name": "Chemistry Lab",
        "code": "CHEM-LAB-01",
        "type": "Laboratory",
        "building": "Science Block",
        "floor": "1st Floor",
        "capacity": 40,
        "facilities": ["Laboratory Equipment", "Safety Fume Hood", "AC", "CCTV"],
        "status": "AVAILABLE",
        "description": "Standard high school chemistry lab with safety workstations."
    },
    {
        "name": "Computer Lab 1",
        "code": "COMP-LAB-01",
        "type": "Computer Lab",
        "building": "IT Block",
        "floor": "Ground Floor",
        "capacity": 30,
        "facilities": ["Computers", "AC", "Internet", "Projector", "Smart Board"],
        "status": "AVAILABLE",
        "description": "30 High-performance i7 workstations with Gigabit LAN."
    },
    {
        "name": "Computer Lab 2",
        "code": "COMP-LAB-02",
        "type": "Computer Lab",
        "building": "IT Block",
        "floor": "1st Floor",
        "capacity": 30,
        "facilities": ["Computers", "AC", "Internet", "Projector"],
        "status": "AVAILABLE",
        "description": "Multimedia and programming lab."
    },
    {
        "name": "Smart Classroom 1",
        "code": "SC-101",
        "type": "Classroom",
        "building": "Academic Block",
        "floor": "1st Floor",
        "capacity": 50,
        "facilities": ["Smart Board", "Projector", "AC", "Audio System", "CCTV"],
        "status": "AVAILABLE",
        "description": "Interactive smart teaching classroom with interactive digital board."
    },
    {
        "name": "Smart Classroom 2",
        "code": "SC-102",
        "type": "Classroom",
        "building": "Academic Block",
        "floor": "1st Floor",
        "capacity": 50,
        "facilities": ["Smart Board", "Projector", "AC", "CCTV"],
        "status": "AVAILABLE",
        "description": "Primary multimedia classroom for secondary grades."
    },
    {
        "name": "Auditorium",
        "code": "AUD-01",
        "type": "Auditorium",
        "building": "Main Building",
        "floor": "Ground Floor",
        "capacity": 500,
        "facilities": ["Audio System", "Projector", "AC", "CCTV", "Accessibility", "Lighting Rig"],
        "status": "AVAILABLE",
        "description": "Central auditorium for seminars, conferences, and annual functions."
    },
    {
        "name": "Library Reading Hall",
        "code": "LIB-RH-01",
        "type": "Library",
        "building": "Library Block",
        "floor": "Ground Floor",
        "capacity": 120,
        "facilities": ["AC", "Internet", "Quiet Study Pods", "CCTV"],
        "status": "AVAILABLE",
        "description": "Quiet study and reference reading hall."
    },
    {
        "name": "Staff Room",
        "code": "STAFF-RM-01",
        "type": "Staff Room",
        "building": "Administrative Block",
        "floor": "2nd Floor",
        "capacity": 25,
        "facilities": ["AC", "Internet", "Computers", "Coffee Station"],
        "status": "AVAILABLE",
        "description": "Faculty resource center and common lounge."
    },
    {
        "name": "Music Room",
        "code": "MUSIC-RM-01",
        "type": "Activity Room",
        "building": "Activity Block",
        "floor": "Ground Floor",
        "capacity": 30,
        "facilities": ["Acoustic Treatment", "Audio System", "Musical Instruments", "AC"],
        "status": "MAINTENANCE",
        "description": "Equipped with keyboards, drums, guitars, and Indian classical instruments."
    },
    {
        "name": "Art & Craft Studio",
        "code": "ART-01",
        "type": "Activity Room",
        "building": "Activity Block",
        "floor": "1st Floor",
        "capacity": 35,
        "facilities": ["Easels", "Pottery Wheel", "Display Boards", "AC"],
        "status": "AVAILABLE",
        "description": "Spacious studio with natural lighting for fine arts and design."
    },
    {
        "name": "Biology Lab",
        "code": "BIO-LAB-01",
        "type": "Laboratory",
        "building": "Science Block",
        "floor": "2nd Floor",
        "capacity": 40,
        "facilities": ["Microscopes", "Specimen Jars", "AC", "Projector"],
        "status": "AVAILABLE",
        "description": "Equipped with binocular compound microscopes and anatomy models."
    },
    {
        "name": "Room 101",
        "code": "RM-101",
        "type": "Classroom",
        "building": "Academic Block",
        "floor": "1st Floor",
        "capacity": 40,
        "facilities": ["Projector", "CCTV", "AC"],
        "status": "AVAILABLE",
        "description": "Standard Classroom allocated to Class 9-A."
    },
    {
        "name": "Room 102",
        "code": "RM-102",
        "type": "Classroom",
        "building": "Academic Block",
        "floor": "1st Floor",
        "capacity": 40,
        "facilities": ["Projector", "CCTV"],
        "status": "AVAILABLE",
        "description": "Standard Classroom allocated to Class 9-B."
    },
    {
        "name": "Room 103",
        "code": "RM-103",
        "type": "Classroom",
        "building": "Academic Block",
        "floor": "1st Floor",
        "capacity": 40,
        "facilities": ["Projector", "CCTV"],
        "status": "AVAILABLE",
        "description": "Standard Classroom allocated to Class 9-C."
    },
    {
        "name": "Room 201",
        "code": "RM-201",
        "type": "Classroom",
        "building": "Academic Block",
        "floor": "2nd Floor",
        "capacity": 40,
        "facilities": ["Projector", "CCTV", "AC"],
        "status": "AVAILABLE",
        "description": "Standard Classroom allocated to Class 11-A."
    },
    {
        "name": "Room 202",
        "code": "RM-202",
        "type": "Classroom",
        "building": "Academic Block",
        "floor": "2nd Floor",
        "capacity": 40,
        "facilities": ["Projector", "CCTV", "AC"],
        "status": "AVAILABLE",
        "description": "Standard Classroom allocated to Class 11-B."
    }
]

print(f"Connecting to database and seeding {len(rooms)} rooms...")
conn = psycopg2.connect(DATABASE_URL)
cur = conn.cursor()

for r in rooms:
    cur.execute("""
        INSERT INTO public.academic_rooms (
            school_id, name, code, type, building, floor, capacity, facilities, status, description
        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s::JSONB, %s, %s)
        ON CONFLICT (school_id, UPPER(code)) WHERE deleted_at IS NULL
        DO UPDATE SET 
            name = EXCLUDED.name,
            type = EXCLUDED.type,
            building = EXCLUDED.building,
            floor = EXCLUDED.floor,
            capacity = EXCLUDED.capacity,
            facilities = EXCLUDED.facilities,
            status = EXCLUDED.status,
            description = EXCLUDED.description;
    """, (
        school_id, r["name"], r["code"], r["type"], r["building"], r["floor"],
        r["capacity"], json.dumps(r["facilities"]), r["status"], r["description"]
    ))

conn.commit()

# Link section default rooms to created rooms
cur.execute("""
    UPDATE public.academic_sections s
    SET room_id = r.id, room_number = r.name
    FROM public.academic_rooms r
    WHERE s.school_id = %s 
      AND r.school_id = %s
      AND ((s.name = '9-A' AND r.code = 'RM-101') OR (s.name = '9-B' AND r.code = 'RM-102') OR (s.name = '9-C' AND r.code = 'RM-103'));
""", (school_id, school_id))
conn.commit()

# Seed sample room allocations
cur.execute("""
    SELECT r.id, c.id, s.id, sub.id
    FROM public.academic_rooms r,
         public.academic_classes c,
         public.academic_sections s,
         public.academic_subjects sub
    WHERE r.code = 'PHY-LAB-01' AND r.school_id = %s
      AND c.name = 'Class 11' AND c.school_id = %s
      AND s.name = '11-A' AND s.school_id = %s
      AND sub.code = 'PHY' AND sub.school_id = %s
    LIMIT 1;
""", (school_id, school_id, school_id, school_id))
row = cur.fetchone()
if row:
    room_id, class_id, sec_id, sub_id = row
    cur.execute("""
        INSERT INTO public.room_allocations (
            school_id, room_id, academic_year, class_id, section_id, subject_id,
            day_of_week, start_time, end_time, title, allocation_type, status
        ) VALUES (
            %s, %s, '2026-27', %s, %s, %s,
            1, '09:20:00'::TIME, '13:30:00'::TIME, 'Class 11-A (Physics Practical)', 'TIMETABLE', 'ACTIVE'
        ) ON CONFLICT DO NOTHING;
    """, (school_id, room_id, class_id, sec_id, sub_id))
    conn.commit()

# Also seed for chemistry lab and computer lab
cur.execute("""
    SELECT r.id, c.id, s.id, sub.id
    FROM public.academic_rooms r,
         public.academic_classes c,
         public.academic_sections s,
         public.academic_subjects sub
    WHERE r.code = 'CHEM-LAB-01' AND r.school_id = %s
      AND c.name = 'Class 11' AND c.school_id = %s
      AND s.name = '11-B' AND s.school_id = %s
      AND sub.code = 'CHEM' AND sub.school_id = %s
    LIMIT 1;
""", (school_id, school_id, school_id, school_id))
row = cur.fetchone()
if row:
    room_id, class_id, sec_id, sub_id = row
    cur.execute("""
        INSERT INTO public.room_allocations (
            school_id, room_id, academic_year, class_id, section_id, subject_id,
            day_of_week, start_time, end_time, title, allocation_type, status
        ) VALUES (
            %s, %s, '2026-27', %s, %s, %s,
            1, '10:10:00'::TIME, '14:20:00'::TIME, 'Class 11-B (Chemistry Practical)', 'TIMETABLE', 'ACTIVE'
        ) ON CONFLICT DO NOTHING;
    """, (school_id, room_id, class_id, sec_id, sub_id))
    conn.commit()

cur.close()
conn.close()
print("✅ Academic rooms and sample allocations seeded successfully.")
