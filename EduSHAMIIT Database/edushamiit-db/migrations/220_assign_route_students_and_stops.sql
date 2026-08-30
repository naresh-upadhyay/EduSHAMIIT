-- Ensure student_transport columns exist
ALTER TABLE student_transport
  ADD COLUMN IF NOT EXISTS transport_route_id UUID REFERENCES transport_routes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS transport_stop_id UUID REFERENCES transport_route_stops(id) ON DELETE SET NULL;

DO $$
DECLARE
    r RECORD;
    st_rec RECORD;
    stop_arr UUID[];
    idx INT;
    sch_id UUID;
BEGIN
    SELECT id INTO sch_id FROM schools LIMIT 1;
    IF sch_id IS NULL THEN
        sch_id := '00000000-0000-0000-0000-000000000001'::uuid;
    END IF;

    FOR r IN SELECT id, route_name FROM transport_routes LOOP
        -- 1. Ensure at least 4 stops exist for this route
        IF NOT EXISTS (SELECT 1 FROM transport_route_stops WHERE route_id = r.id) THEN
            INSERT INTO transport_route_stops (id, school_id, route_id, stop_name, stop_order, latitude, longitude, estimated_arrival) VALUES
                (gen_random_uuid(), sch_id, r.id, 'Main Depot', 1, 28.6280, 77.3780, '07:30:00'),
                (gen_random_uuid(), sch_id, r.id, 'Sector 15 Crossroad', 2, 28.6320, 77.3820, '07:45:00'),
                (gen_random_uuid(), sch_id, r.id, 'Central Park Gate', 3, 28.6360, 77.3860, '08:00:00'),
                (gen_random_uuid(), sch_id, r.id, 'School Campus Depot', 4, 28.6400, 77.3900, '08:15:00');
        END IF;

        -- Get list of stop IDs for this route
        SELECT array_agg(id ORDER BY stop_order) INTO stop_arr FROM transport_route_stops WHERE route_id = r.id;

        -- 2. Assign student profiles to this route if fewer than 5 exist
        IF (SELECT COUNT(*) FROM student_transport WHERE transport_route_id = r.id) < 5 THEN
            idx := 1;
            FOR st_rec IN (
                SELECT id FROM profiles 
                WHERE role = 'student' OR role IS NULL 
                AND id NOT IN (SELECT student_id FROM student_transport WHERE transport_route_id = r.id)
                LIMIT 10
            ) LOOP
                INSERT INTO student_transport (id, school_id, student_id, transport_route_id, transport_stop_id)
                VALUES (
                    gen_random_uuid(),
                    sch_id,
                    st_rec.id,
                    r.id,
                    stop_arr[(idx % array_length(stop_arr, 1)) + 1]
                )
                ON CONFLICT DO NOTHING;
                idx := idx + 1;
            END LOOP;
        END IF;

        -- 3. Fix any NULL transport_stop_id in student_transport for this route
        idx := 1;
        FOR st_rec IN (SELECT id FROM student_transport WHERE transport_route_id = r.id AND transport_stop_id IS NULL) LOOP
            UPDATE student_transport 
            SET transport_stop_id = stop_arr[(idx % array_length(stop_arr, 1)) + 1]
            WHERE id = st_rec.id;
            idx := idx + 1;
        END LOOP;

    END LOOP;
END $$;
