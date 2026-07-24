-- 183_driver_timetable.sql
-- Cleanup temporary tables and enforce native schema usage for transport routes & stops.

DROP TABLE IF EXISTS public.driver_trip_stops CASCADE;
DROP TABLE IF EXISTS public.driver_timetable_trips CASCADE;
DROP TABLE IF EXISTS public.driver_schedules CASCADE;
DROP TABLE IF EXISTS public.driver_schedule_reminders CASCADE;
