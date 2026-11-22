-- Migration 567: Backfill and Synchronize Room Assignments for Campus Management
-- Ensures full consistency between room occupancy KPIs and the Space Allocations grid.

DO $$
BEGIN
    -- 1. Align assignment_status for rooms that have active occupancy
    UPDATE public.rooms
    SET assignment_status = 'Assigned'
    WHERE deleted_at IS NULL
      AND current_occupancy > 0
      AND assignment_status = 'Unassigned';

    -- 2. Backfill room_assignments for all currently assigned / occupied rooms
    INSERT INTO public.room_assignments (
        id,
        school_id,
        room_id,
        reference_module,
        reference_name,
        assignment_purpose,
        start_date,
        end_date,
        assigned_to_name,
        status,
        notes,
        created_at,
        updated_at
    )
    SELECT 
        gen_random_uuid(),
        r.school_id,
        r.id,
        CASE 
            WHEN r.name ILIKE '%grade%' OR r.name ILIKE '%section%' OR r.name ILIKE '%class%' THEN 'Academics'
            WHEN r.room_type ILIKE '%lab%' THEN 'Academics'
            WHEN r.room_type ILIKE '%office%' OR r.room_type ILIKE '%staff%' OR r.room_type ILIKE '%reception%' OR r.room_type ILIKE '%meeting%' THEN 'Administration'
            WHEN r.room_type ILIKE '%library%' THEN 'Library'
            WHEN r.room_type ILIKE '%hostel%' THEN 'Hostel'
            ELSE 'General'
        END,
        COALESCE(NULLIF(r.name, ''), 'Room ' || r.room_number),
        CASE 
            WHEN r.name ILIKE '%grade%' OR r.name ILIKE '%section%' OR r.name ILIKE '%class%' THEN 'Classroom & Lecture Instruction'
            WHEN r.room_type ILIKE '%lab%' THEN 'Laboratory & Practical Sessions'
            WHEN r.room_type ILIKE '%office%' OR r.room_type ILIKE '%staff%' THEN 'Staff & Administrative Workstations'
            WHEN r.room_type ILIKE '%library%' THEN 'Reading & Reference Learning'
            WHEN r.room_type ILIKE '%hostel%' THEN 'Student Boarding & Residence'
            WHEN r.room_type ILIKE '%gym%' OR r.room_type ILIKE '%sport%' THEN 'Sports & Physical Education'
            WHEN r.room_type ILIKE '%auditorium%' THEN 'Seminars, Conferences & Events'
            ELSE COALESCE(NULLIF(r.purpose, ''), r.room_type || ' Allocation')
        END,
        CURRENT_DATE,
        NULL,
        COALESCE(
            NULLIF(r.responsible_person_name, ''),
            CASE 
                WHEN r.name ILIKE '%grade%' OR r.name ILIKE '%section%' OR r.name ILIKE '%class%' THEN 'Academic Coordinator'
                WHEN r.room_type ILIKE '%lab%' THEN 'Lab Incharge'
                WHEN r.room_type ILIKE '%office%' OR r.room_type ILIKE '%staff%' THEN 'Department Head'
                WHEN r.room_type ILIKE '%library%' THEN 'Chief Librarian'
                WHEN r.room_type ILIKE '%hostel%' THEN 'Hostel Warden'
                ELSE 'Facility Manager'
            END
        ),
        'Active',
        'Institutional space allocation',
        NOW(),
        NOW()
    FROM public.rooms r
    WHERE r.deleted_at IS NULL
      AND (r.assignment_status = 'Assigned' OR r.current_occupancy > 0)
      AND NOT EXISTS (
          SELECT 1 FROM public.room_assignments ra 
          WHERE ra.room_id = r.id AND ra.deleted_at IS NULL AND ra.status = 'Active'
      );

END $$;

-- 3. Trigger Function: Sync room assignment state when rooms change
CREATE OR REPLACE FUNCTION public.fn_sync_rooms_occupancy_assignments()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    -- If room was deleted or freed (Unassigned & 0 occupancy)
    IF NEW.deleted_at IS NOT NULL OR (NEW.assignment_status = 'Unassigned' AND COALESCE(NEW.current_occupancy, 0) = 0) THEN
        UPDATE public.room_assignments
        SET status = 'Released', deleted_at = NOW(), updated_at = NOW()
        WHERE room_id = NEW.id AND deleted_at IS NULL AND status = 'Active';

    -- If room was assigned or occupied
    ELSIF NEW.deleted_at IS NULL AND (NEW.assignment_status = 'Assigned' OR COALESCE(NEW.current_occupancy, 0) > 0) THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.room_assignments 
            WHERE room_id = NEW.id AND deleted_at IS NULL AND status = 'Active'
        ) THEN
            INSERT INTO public.room_assignments (
                id, school_id, room_id, reference_module, reference_name,
                assignment_purpose, start_date, assigned_to_name, status, notes,
                created_at, updated_at
            ) VALUES (
                gen_random_uuid(),
                NEW.school_id,
                NEW.id,
                CASE 
                    WHEN NEW.name ILIKE '%grade%' OR NEW.name ILIKE '%section%' OR NEW.name ILIKE '%class%' THEN 'Academics'
                    WHEN NEW.room_type ILIKE '%lab%' THEN 'Academics'
                    WHEN NEW.room_type ILIKE '%office%' OR NEW.room_type ILIKE '%staff%' OR NEW.room_type ILIKE '%reception%' OR NEW.room_type ILIKE '%meeting%' THEN 'Administration'
                    WHEN NEW.room_type ILIKE '%library%' THEN 'Library'
                    WHEN NEW.room_type ILIKE '%hostel%' THEN 'Hostel'
                    ELSE 'General'
                END,
                COALESCE(NULLIF(NEW.name, ''), 'Room ' || NEW.room_number),
                CASE 
                    WHEN NEW.name ILIKE '%grade%' OR NEW.name ILIKE '%section%' OR NEW.name ILIKE '%class%' THEN 'Classroom & Lecture Instruction'
                    WHEN NEW.room_type ILIKE '%lab%' THEN 'Laboratory & Practical Sessions'
                    WHEN NEW.room_type ILIKE '%office%' OR NEW.room_type ILIKE '%staff%' THEN 'Staff & Administrative Workstations'
                    WHEN NEW.room_type ILIKE '%library%' THEN 'Reading & Reference Learning'
                    WHEN NEW.room_type ILIKE '%hostel%' THEN 'Student Boarding & Residence'
                    WHEN NEW.room_type ILIKE '%gym%' OR NEW.room_type ILIKE '%sport%' THEN 'Sports & Physical Education'
                    WHEN NEW.room_type ILIKE '%auditorium%' THEN 'Seminars, Conferences & Events'
                    ELSE COALESCE(NULLIF(NEW.purpose, ''), NEW.room_type || ' Allocation')
                END,
                CURRENT_DATE,
                COALESCE(
                    NULLIF(NEW.responsible_person_name, ''),
                    CASE 
                        WHEN NEW.name ILIKE '%grade%' OR NEW.name ILIKE '%section%' OR NEW.name ILIKE '%class%' THEN 'Academic Coordinator'
                        WHEN NEW.room_type ILIKE '%lab%' THEN 'Lab Incharge'
                        WHEN NEW.room_type ILIKE '%office%' OR NEW.room_type ILIKE '%staff%' THEN 'Department Head'
                        WHEN NEW.room_type ILIKE '%library%' THEN 'Chief Librarian'
                        WHEN NEW.room_type ILIKE '%hostel%' THEN 'Hostel Warden'
                        ELSE 'Facility Manager'
                    END
                ),
                'Active',
                'Institutional space allocation',
                NOW(),
                NOW()
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_rooms_occupancy_assignments ON public.rooms;
CREATE TRIGGER trg_sync_rooms_occupancy_assignments
AFTER INSERT OR UPDATE OF assignment_status, current_occupancy, deleted_at, name, room_type, responsible_person_name
ON public.rooms
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_rooms_occupancy_assignments();

-- 4. Trigger Function: Sync room assignment changes back to rooms table
CREATE OR REPLACE FUNCTION public.fn_sync_assignments_to_room()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    IF NEW.deleted_at IS NOT NULL OR NEW.status = 'Released' THEN
        -- If no more active assignments exist for this room, free the room
        IF NOT EXISTS (
            SELECT 1 FROM public.room_assignments
            WHERE room_id = NEW.room_id AND deleted_at IS NULL AND status = 'Active' AND id <> NEW.id
        ) THEN
            UPDATE public.rooms
            SET assignment_status = 'Unassigned', current_occupancy = 0
            WHERE id = NEW.room_id AND deleted_at IS NULL;
        END IF;
    ELSIF NEW.status = 'Active' AND NEW.deleted_at IS NULL THEN
        UPDATE public.rooms
        SET assignment_status = 'Assigned',
            current_occupancy = CASE WHEN current_occupancy = 0 THEN max_capacity ELSE current_occupancy END
        WHERE id = NEW.room_id AND deleted_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_assignments_to_room ON public.room_assignments;
CREATE TRIGGER trg_sync_assignments_to_room
AFTER INSERT OR UPDATE OF status, deleted_at
ON public.room_assignments
FOR EACH ROW
EXECUTE FUNCTION public.fn_sync_assignments_to_room();
