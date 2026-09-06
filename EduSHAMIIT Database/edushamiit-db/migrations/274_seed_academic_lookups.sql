-- ============================================================================
-- Migration 274: Seed Dynamic Academic Lookups (Room Types, Stages, Buildings, Floors, Facilities, Subject Types, Statuses, Academic Years, Time Slots)
-- Ensures enterprise key-value management for all ERP academic popups
-- ============================================================================

DO $$
DECLARE
    s RECORD;
    admin_id UUID;
    v_key_id UUID;
BEGIN
    FOR s IN SELECT id FROM public.schools LOOP
        SELECT id INTO admin_id FROM public.profiles WHERE school_id = s.id LIMIT 1;
        IF admin_id IS NULL THEN
            SELECT id INTO admin_id FROM public.profiles LIMIT 1;
        END IF;

        IF admin_id IS NOT NULL THEN
            -- 1. ROOM_TYPE
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Room Type', 'ROOM_TYPE', 'Classification of academic, administrative and activity spaces across campus.', 'SYSTEM', 'meeting_room_outlined', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Classroom', 'CLASSROOM', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Laboratory', 'LABORATORY', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Computer Lab', 'COMPUTER_LAB', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Auditorium', 'AUDITORIUM', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Library', 'LIBRARY', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Staff Room', 'STAFF_ROOM', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Activity Room', 'ACTIVITY_ROOM', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Art & Craft Studio', 'ART_CRAFT_STUDIO', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Music & Dance Studio', 'MUSIC_DANCE_STUDIO', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Sports Complex / Gym', 'SPORTS_COMPLEX', 'ACTIVE', 10, admin_id),
                    (v_key_id, s.id, 'Infirmary / Medical Room', 'INFIRMARY', 'ACTIVE', 11, admin_id),
                    (v_key_id, s.id, 'Conference Hall', 'CONFERENCE_HALL', 'ACTIVE', 12, admin_id),
                    (v_key_id, s.id, 'Other', 'OTHER', 'ACTIVE', 13, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 2. ROOM_STATUS / OPERATIONAL_STATUS
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Room Operational Status', 'ROOM_STATUS', 'Real-time operational and maintenance status of rooms.', 'SYSTEM', 'sync_alt_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Available / In Service', 'AVAILABLE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Maintenance / Out of Service', 'MAINTENANCE', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'In Use / Occupied', 'IN_USE', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Reserved', 'RESERVED', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Decommissioned', 'DECOMMISSIONED', 'INACTIVE', 5, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 3. CAMPUS_BUILDING
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Campus Building', 'CAMPUS_BUILDING', 'Campus buildings, blocks, and physical facilities.', 'SYSTEM', 'apartment_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Academic Block A', 'BLOCK_A', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Academic Block B', 'BLOCK_B', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Academic Block C', 'BLOCK_C', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Activity Block', 'ACTIVITY_BLOCK', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Science Block', 'SCIENCE_BLOCK', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Administrative Block', 'ADMIN_BLOCK', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'New Building', 'NEW_BUILDING', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Sports Arena', 'SPORTS_ARENA', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Old Annex (Demolished)', 'OLD_ANNEX', 'INACTIVE', 9, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 4. BUILDING_FLOOR
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Building Floor', 'BUILDING_FLOOR', 'Floors and vertical level tiers in institutional buildings.', 'SYSTEM', 'stairs_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Ground Floor', 'GROUND_FLOOR', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, '1st Floor', '1ST_FLOOR', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, '2nd Floor', '2ND_FLOOR', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, '3rd Floor', '3RD_FLOOR', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, '4th Floor', '4TH_FLOOR', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Basement', 'BASEMENT', 'ACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 5. ROOM_FACILITY
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Room Facility & Features', 'ROOM_FACILITY', 'Equipment and smart features equipped in rooms.', 'SYSTEM', 'devices_other_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Projector', 'PROJECTOR', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Smart Board', 'SMART_BOARD', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'AC', 'AC', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'CCTV', 'CCTV', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Laboratory Equipment', 'LAB_EQUIPMENT', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Computers', 'COMPUTERS', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Internet', 'INTERNET', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Audio System', 'AUDIO_SYSTEM', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Accessibility', 'ACCESSIBILITY', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Safety Fume Hood', 'SAFETY_FUME_HOOD', 'ACTIVE', 10, admin_id),
                    (v_key_id, s.id, 'Quiet Study Pods', 'QUIET_STUDY_PODS', 'ACTIVE', 11, admin_id),
                    (v_key_id, s.id, 'Whiteboard', 'WHITEBOARD', 'ACTIVE', 12, admin_id),
                    (v_key_id, s.id, 'Natural Lighting', 'NATURAL_LIGHTING', 'ACTIVE', 13, admin_id),
                    (v_key_id, s.id, 'Easels', 'EASELS', 'ACTIVE', 14, admin_id),
                    (v_key_id, s.id, 'Pottery Wheel', 'POTTERY_WHEEL', 'ACTIVE', 15, admin_id),
                    (v_key_id, s.id, 'Display Boards', 'DISPLAY_BOARDS', 'ACTIVE', 16, admin_id),
                    (v_key_id, s.id, 'Microscopes', 'MICROSCOPES', 'ACTIVE', 17, admin_id),
                    (v_key_id, s.id, 'Specimen Jars', 'SPECIMEN_JARS', 'ACTIVE', 18, admin_id),
                    (v_key_id, s.id, 'Musical Instruments', 'MUSICAL_INSTRUMENTS', 'ACTIVE', 19, admin_id),
                    (v_key_id, s.id, 'Acoustic Treatment', 'ACOUSTIC_TREATMENT', 'ACTIVE', 20, admin_id),
                    (v_key_id, s.id, 'Lighting Rig', 'LIGHTING_RIG', 'ACTIVE', 21, admin_id),
                    (v_key_id, s.id, 'Coffee Station', 'COFFEE_STATION', 'ACTIVE', 22, admin_id),
                    (v_key_id, s.id, 'Obsolete Equipment', 'OBSOLETE_EQ', 'INACTIVE', 23, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 6. CLASS_STAGE
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Academic Stage', 'CLASS_STAGE', 'Educational grade levels and academic stages.', 'SYSTEM', 'school_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Pre-Primary', 'PRE_PRIMARY', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Primary', 'PRIMARY', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Middle School', 'MIDDLE_SCHOOL', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Secondary', 'SECONDARY', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Senior Secondary', 'SENIOR_SECONDARY', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Vocational Diploma', 'VOCATIONAL_DIPLOMA', 'INACTIVE', 6, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 7. SUBJECT_TYPE
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Subject Type', 'SUBJECT_TYPE', 'Academic subject nature and curriculum categories.', 'SYSTEM', 'auto_stories_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Core', 'CORE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Optional / Elective', 'OPTIONAL', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Language', 'LANGUAGE', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Practical / Lab', 'PRACTICAL', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Activity / Skill', 'ACTIVITY', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Vocational', 'VOCATIONAL', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Co-Curricular', 'CO_CURRICULAR', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Other', 'OTHER', 'ACTIVE', 8, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 8. ACADEMIC_STATUS
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Academic Status', 'ACADEMIC_STATUS', 'Lifecycle and operational status for academic entities.', 'SYSTEM', 'toggle_on_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Active', 'ACTIVE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Inactive', 'INACTIVE', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Archived', 'ARCHIVED', 'ACTIVE', 3, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 9. ALLOCATION_TYPE
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Room Allocation Type', 'ALLOCATION_TYPE', 'Intent and booking category for room scheduling.', 'SYSTEM', 'calendar_month_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Timetable / Regular Class', 'TIMETABLE', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Exam / Assessment', 'EXAM', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Event / Seminar', 'EVENT', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Maintenance', 'MAINTENANCE', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Temporary Booking', 'TEMPORARY', 'ACTIVE', 5, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 10. FINANCIAL_YEAR
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Financial Year', 'FINANCIAL_YEAR', 'Fiscal budgeting and institutional procurement years.', 'SYSTEM', 'calendar_today_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, '2026-27', 'FY_2026_27', '2026-04-01 to 2027-03-31', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, '2025-26', 'FY_2025_26', '2025-04-01 to 2026-03-31', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, '2024-25', 'FY_2024_25', '2024-04-01 to 2025-03-31', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, '2023-24', 'FY_2023_24', '2023-04-01 to 2024-03-31', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, '2022-23', 'FY_2022_23', '2022-04-01 to 2023-03-31', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, '2021-22', 'FY_2021_22', '2021-04-01 to 2022-03-31', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, '2020-21', 'FY_2020_21', '2020-04-01 to 2021-03-31', 'ACTIVE', 7, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

            -- 11. ACADEMIC_TIME_SLOT
            INSERT INTO public.lookup_keys (school_id, key_name, key_code, description, key_type, icon, status, created_by)
            VALUES (s.id, 'Academic Time Slot', 'ACADEMIC_TIME_SLOT', 'Standard daily timetable periods and break slots with start/end times.', 'SYSTEM', 'schedule_rounded', 'ACTIVE', admin_id)
            ON CONFLICT (school_id, key_code) WHERE deleted_at IS NULL DO UPDATE SET key_name = EXCLUDED.key_name
            RETURNING id INTO v_key_id;

            IF v_key_id IS NOT NULL THEN
                INSERT INTO public.lookup_values (lookup_key_id, school_id, value_name, value_code, description, status, sort_order, created_by) VALUES
                    (v_key_id, s.id, 'Period 1 (08:00 - 08:45)', 'PERIOD_1', '08:00:00 to 08:45:00', 'ACTIVE', 1, admin_id),
                    (v_key_id, s.id, 'Period 2 (08:50 - 09:35)', 'PERIOD_2', '08:50:00 to 09:35:00', 'ACTIVE', 2, admin_id),
                    (v_key_id, s.id, 'Period 3 (09:40 - 10:25)', 'PERIOD_3', '09:40:00 to 10:25:00', 'ACTIVE', 3, admin_id),
                    (v_key_id, s.id, 'Short Break (10:25 - 10:45)', 'BREAK_SHORT', '10:25:00 to 10:45:00', 'ACTIVE', 4, admin_id),
                    (v_key_id, s.id, 'Period 4 (10:45 - 11:30)', 'PERIOD_4', '10:45:00 to 11:30:00', 'ACTIVE', 5, admin_id),
                    (v_key_id, s.id, 'Period 5 (11:35 - 12:20)', 'PERIOD_5', '11:35:00 to 12:20:00', 'ACTIVE', 6, admin_id),
                    (v_key_id, s.id, 'Lunch Break (12:20 - 01:00)', 'BREAK_LUNCH', '12:20:00 to 13:00:00', 'ACTIVE', 7, admin_id),
                    (v_key_id, s.id, 'Period 6 (01:00 - 01:45)', 'PERIOD_6', '13:00:00 to 13:45:00', 'ACTIVE', 8, admin_id),
                    (v_key_id, s.id, 'Period 7 (01:50 - 02:35)', 'PERIOD_7', '13:50:00 to 14:35:00', 'ACTIVE', 9, admin_id),
                    (v_key_id, s.id, 'Period 8 (02:40 - 03:25)', 'PERIOD_8', '14:40:00 to 15:25:00', 'ACTIVE', 10, admin_id)
                ON CONFLICT (lookup_key_id, value_code) WHERE deleted_at IS NULL DO NOTHING;
            END IF;

        END IF;
    END LOOP;
END $$;
