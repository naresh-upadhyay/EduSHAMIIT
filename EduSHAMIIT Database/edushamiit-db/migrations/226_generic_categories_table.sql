-- Migration 226: Generic Categories Table
CREATE TABLE IF NOT EXISTS public.categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL DEFAULT 'schedule',
    name VARCHAR(100) NOT NULL,
    label VARCHAR(100) NOT NULL,
    color VARCHAR(20) DEFAULT '#4F46E5',
    description TEXT,
    is_system BOOLEAN DEFAULT TRUE,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Unique index to prevent duplicate category names (case-insensitive) per type and school
CREATE UNIQUE INDEX IF NOT EXISTS idx_categories_unique_type_name ON public.categories (type, LOWER(name));
CREATE INDEX IF NOT EXISTS idx_categories_school ON public.categories (school_id);

-- Clean up any legacy plural/duplicate entries
DELETE FROM public.categories WHERE type = 'schedule' AND name IN ('Meetings', 'Events', 'Reminders', 'Classes', 'Exams', 'Examinations', 'Training Sessions', 'Transport');

-- Insert seed data for Schedule Types (type = 'schedule')
INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'Meeting', 'Meeting', '#4F46E5', 'General & Team Meetings', TRUE, 1
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'meeting');

INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'Class', 'Class', '#10B981', 'Academic Classes & Lectures', TRUE, 2
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'class');

INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'Exam', 'Exam', '#EF4444', 'Examinations & Tests', TRUE, 3
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'exam');

INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'Task', 'Task', '#06B6D4', 'Tasks & Assignments', TRUE, 4
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'task');

INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'Reminder', 'Reminder', '#8B5CF6', 'Important Reminders', TRUE, 5
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'reminder');

INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'Training', 'Training', '#F59E0B', 'Staff & Student Training Sessions', TRUE, 6
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'training');

INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'Trip', 'Trip (Transport)', '#D97706', 'School Trips & Bus Transport', TRUE, 7
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'trip');

INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'School Event', 'School Event', '#EC4899', 'School Events & Functions', TRUE, 8
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'school event');

INSERT INTO public.categories (id, type, name, label, color, description, is_system, sort_order)
SELECT gen_random_uuid(), 'schedule', 'Leave', 'Leave', '#64748B', 'Staff & Student Leaves', TRUE, 9
WHERE NOT EXISTS (SELECT 1 FROM public.categories WHERE type = 'schedule' AND LOWER(name) = 'leave');
