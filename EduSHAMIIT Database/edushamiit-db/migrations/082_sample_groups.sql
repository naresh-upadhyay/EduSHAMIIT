-- ============================================================
-- Migration 082: Sample Groups data
-- ============================================================

INSERT INTO groups (school_id, name, description, created_by)
SELECT
  s.id,
  g.name,
  g.description,
  p.id
FROM
  schools s,
  profiles p,
  (VALUES
    ('Study Group 10A',  'Group for Class 10A students'),
    ('Science Club',     'Science enthusiasts group'),
    ('Math Olympiad',    'Olympiad preparation group'),
    ('Debate Team',      'School debate team')
  ) AS g(name, description)
WHERE s.id = '11111111-1111-1111-1111-111111111111'
  AND p.school_id = s.id
  AND p.role = 'teacher'
LIMIT 4
ON CONFLICT DO NOTHING;
