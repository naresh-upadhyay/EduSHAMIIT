import psycopg2

def apply_migrations():
    conn = psycopg2.connect('postgresql://postgres:eduSHAMIIT2026_pg@localhost:5432/postgres')
    conn.autocommit = True
    cur = conn.cursor()

    print("1. Creating campus_facilities table...")
    cur.execute("""
    CREATE TABLE IF NOT EXISTS public.campus_facilities (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        school_id UUID NOT NULL,
        name VARCHAR(255) NOT NULL,
        code VARCHAR(100) NOT NULL,
        category VARCHAR(100) NOT NULL DEFAULT 'Specialized Laboratory',
        building_id UUID REFERENCES public.buildings(id) ON DELETE SET NULL,
        floor_id UUID REFERENCES public.building_floors(id) ON DELETE SET NULL,
        capacity INT DEFAULT 50,
        area NUMERIC(10,2) DEFAULT 0.0,
        manager_name VARCHAR(255),
        manager_phone VARCHAR(50),
        status VARCHAR(50) DEFAULT 'Operational',
        equipment_count INT DEFAULT 0,
        description TEXT,
        created_by UUID,
        updated_by UUID,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW(),
        deleted_at TIMESTAMPTZ,
        deleted_by UUID
    );

    CREATE INDEX IF NOT EXISTS idx_campus_facilities_school ON public.campus_facilities(school_id);
    CREATE INDEX IF NOT EXISTS idx_campus_facilities_status ON public.campus_facilities(status);
    CREATE INDEX IF NOT EXISTS idx_campus_facilities_category ON public.campus_facilities(category);
    """)

    print("2. Seeding initial institutional facilities if empty...")
    cur.execute("SELECT count(*) FROM public.campus_facilities WHERE deleted_at IS NULL;")
    count = cur.fetchone()[0]
    if count == 0:
        cur.execute("""
        INSERT INTO public.campus_facilities (
            school_id, name, code, category, capacity, area, manager_name, manager_phone, status, equipment_count, description
        ) VALUES 
        ('11111111-1111-1111-1111-111111111111', 'Main Athletic Complex & Football Ground', 'SPT-FLD-01', 'Sports Complex / Ground', 1200, 65000.0, 'Coach R. K. Singh', '+91 98450 11223', 'Operational', 24, 'FIFA regulation grass turf field with 400m synthetic running track and floodlighting.'),
        ('11111111-1111-1111-1111-111111111111', 'Dr. APJ Abdul Kalam Central Auditorium', 'AUD-01', 'Auditorium & Amphitheater', 850, 9500.0, 'Deepak Malhotra', '+91 98220 44556', 'Operational', 42, 'State-of-the-art acoustic auditorium with 4K laser projection and line array audio system.'),
        ('11111111-1111-1111-1111-111111111111', 'Central Robotics & IoT Innovation FabLab', 'LAB-ROB-01', 'Robotics & Fabrication Lab', 60, 2400.0, 'Dr. S. Mukherjee', '+91 98771 99881', 'Operational', 68, 'Advanced prototyping lab with 3D printers, laser cutters, oscilloscope stations, and robotic arms.'),
        ('11111111-1111-1111-1111-111111111111', 'Central Food Court & Dining Hall', 'CAN-01', 'Dining & Cafeteria Hub', 500, 7200.0, 'Vikram Rathore', '+91 98110 33445', 'Operational', 18, 'Hygienic institutional kitchen and dining hall serving students and faculty.'),
        ('11111111-1111-1111-1111-111111111111', 'Health Center & Emergency Clinic', 'MED-01', 'Health Center & Clinic', 20, 1800.0, 'Dr. Ananya Roy', '+91 98234 55678', 'Operational', 15, '24/7 on-campus infirmary with oxygen concentrators, first aid units, and triage beds.'),
        ('11111111-1111-1111-1111-111111111111', 'Central Transport Hub & EV Charging Station', 'TRN-HUB-01', 'Transport Hub & Bus Bay', 350, 45000.0, 'Rajesh Goud', '+91 98345 67890', 'Operational', 12, 'Secure parking bays for institutional bus fleet with high-speed DC fast chargers.');
        """)
        print("   Seeded 6 institutional facilities.")

    print("3. Creating campus_utility_readings table...")
    cur.execute("""
    CREATE TABLE IF NOT EXISTS public.campus_utility_readings (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        school_id UUID NOT NULL,
        utility_name VARCHAR(150) NOT NULL,
        utility_type VARCHAR(100) NOT NULL, -- Electrical, Solar, DG, Water, RO, Internet, Gas
        reading_value VARCHAR(100) NOT NULL,
        metric_units VARCHAR(50), -- kWh, Litres, ppm, Gbps
        location VARCHAR(255) NOT NULL,
        recorded_by VARCHAR(150) NOT NULL,
        status VARCHAR(50) DEFAULT 'Normal',
        notes TEXT,
        recorded_at TIMESTAMPTZ DEFAULT NOW(),
        created_at TIMESTAMPTZ DEFAULT NOW(),
        deleted_at TIMESTAMPTZ
    );

    CREATE INDEX IF NOT EXISTS idx_campus_utility_readings_school ON public.campus_utility_readings(school_id);
    CREATE INDEX IF NOT EXISTS idx_campus_utility_readings_type ON public.campus_utility_readings(utility_type);
    """)

    print("4. Seeding initial utility readings if empty...")
    cur.execute("SELECT count(*) FROM public.campus_utility_readings WHERE deleted_at IS NULL;")
    count_util = cur.fetchone()[0]
    if count_util == 0:
        cur.execute("""
        INSERT INTO public.campus_utility_readings (
            school_id, utility_name, utility_type, reading_value, metric_units, location, recorded_by, status, notes, recorded_at
        ) VALUES 
        ('11111111-1111-1111-1111-111111111111', 'State Power Grid & Substation', 'Electrical', '45,210 kWh', 'kWh', 'Main Substation (33kV)', 'Suresh Sharma', 'Normal', 'Peak evening demand stable at 245 kW', NOW() - INTERVAL '2 hours'),
        ('11111111-1111-1111-1111-111111111111', 'Rooftop Solar PV Generation', 'Solar', '320.4 kWh', 'kWh', 'Academic Block A & B Roof', 'System Inverter Monitor', 'Optimal', 'Sunny conditions, 42% campus load offset achieved', NOW() - INTERVAL '5 hours'),
        ('11111111-1111-1111-1111-111111111111', 'Backup Diesel Generator Sets (DG)', 'DG', 'DG-01: 78% Fuel (1,560 L)', 'Litres', 'Power House Yard', 'Ramesh Kumar', 'Standby Ready', 'Weekly 15-minute test run completed without issues', NOW() - INTERVAL '8 hours'),
        ('11111111-1111-1111-1111-111111111111', 'Municipal Water & Deep Borewells', 'Water', '85,000 Litres (85%)', 'Litres', 'Central Underground Sump', 'Sunil Rao', 'Adequate', 'Overhead tanks replenished for hostel and labs', NOW() - INTERVAL '12 hours'),
        ('11111111-1111-1111-1111-111111111111', 'Central RO Water Purification Plant', 'RO', 'TDS: 68 ppm • Flow: 2,500 LPH', 'ppm', 'Amenities Block RO Plant', 'Sunil Rao', 'Certified Pure', 'UV & Osmosis filters verified clean', NOW() - INTERVAL '14 hours'),
        ('11111111-1111-1111-1111-111111111111', 'High-Speed Internet / Optical Fiber', 'Internet', 'Primary: 1.0 Gbps (99.98% Uptime)', 'Gbps', 'Server Room Core Rack', 'Kiran Verma', 'Healthy', 'Secondary backup wireless line on hot standby', NOW() - INTERVAL '16 hours');
        """)
        print("   Seeded 6 initial utility readings.")

    print("5. Enhancing space_booking functions for recurring generation...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.fn_space_booking_create_recurring(p_payload JSONB)
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_school_id UUID;
        v_user_id UUID;
        v_title VARCHAR(250);
        v_room_id UUID;
        v_building_id UUID;
        v_floor_id UUID;
        v_start_date DATE;
        v_end_date DATE;
        v_start_time TIME;
        v_end_time TIME;
        v_purpose VARCHAR(100);
        v_organizer_name VARCHAR(250);
        v_organizer_role VARCHAR(100);
        v_attendee_count INT;
        v_days_of_week INT[];
        v_series_id UUID;
        v_curr_date DATE;
        v_dow INT;
        v_created_count INT := 0;
        v_conflict_count INT := 0;
        v_booking_ref VARCHAR(50);
        v_existing_conflict INT;
    BEGIN
        v_school_id := (p_payload->>'school_id')::UUID;
        v_user_id := (p_payload->>'user_id')::UUID;
        v_title := COALESCE(p_payload->>'title', p_payload->>'series_title', 'Recurring Class/Event Series');
        v_room_id := (p_payload->>'room_id')::UUID;
        v_start_date := (p_payload->>'start_date')::DATE;
        v_end_date := COALESCE((p_payload->>'end_date')::DATE, v_start_date + INTERVAL '3 months');
        v_start_time := (p_payload->>'start_time')::TIME;
        v_end_time := (p_payload->>'end_time')::TIME;
        v_purpose := COALESCE(p_payload->>'purpose', 'Academic');
        v_organizer_name := COALESCE(p_payload->>'organizer_name', 'Faculty');
        v_organizer_role := COALESCE(p_payload->>'organizer_role', 'Faculty');
        v_attendee_count := COALESCE((p_payload->>'attendee_count')::INT, 30);
        
        -- Resolve building and floor
        SELECT building_id, floor_id INTO v_building_id, v_floor_id 
        FROM public.rooms WHERE id = v_room_id;

        -- Extract days of week array (default to 1,3,5 Mon/Wed/Fri if empty)
        IF p_payload ? 'days_of_week' AND jsonb_array_length(p_payload->'days_of_week') > 0 THEN
            SELECT ARRAY_AGG(x::INT) INTO v_days_of_week FROM jsonb_array_elements_text(p_payload->'days_of_week') AS x;
        ELSE
            v_days_of_week := ARRAY[1, 3, 5];
        END IF;

        -- Insert recurring series header
        INSERT INTO public.space_booking_recurring_series (
            school_id, title, recurrence_type, start_date, end_date, days_of_week, created_by
        ) VALUES (
            v_school_id, v_title, 'WEEKLY', v_start_date, v_end_date, v_days_of_week, v_user_id
        ) RETURNING id INTO v_series_id;

        -- Loop through dates and insert non-conflicting slots
        v_curr_date := v_start_date;
        WHILE v_curr_date <= v_end_date LOOP
            -- Extract day of week: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
            v_dow := EXTRACT(ISODOW FROM v_curr_date)::INT;
            
            IF v_dow = ANY(v_days_of_week) THEN
                -- Check for conflicts
                SELECT COUNT(*) INTO v_existing_conflict
                FROM public.space_bookings
                WHERE room_id = v_room_id
                  AND booking_date = v_curr_date
                  AND status IN ('Confirmed', 'Pending')
                  AND deleted_at IS NULL
                  AND (start_time, end_time) OVERLAPS (v_start_time, v_end_time);

                IF v_existing_conflict = 0 THEN
                    v_booking_ref := 'SB-' || TO_CHAR(v_curr_date, 'YYYYMMDD') || '-' || SUBSTRING(gen_random_uuid()::TEXT, 1, 4);

                    INSERT INTO public.space_bookings (
                        school_id, booking_ref, title, room_id, building_id, floor_id,
                        booking_date, start_time, end_time, start_datetime, end_datetime,
                        buffer_start_datetime, buffer_end_datetime,
                        purpose, status, is_approved,
                        organizer_name, organizer_role, attendee_count,
                        is_recurring, recurring_series_id, created_by
                    ) VALUES (
                        v_school_id, v_booking_ref, v_title, v_room_id, v_building_id, v_floor_id,
                        v_curr_date, v_start_time, v_end_time, (v_curr_date + v_start_time)::TIMESTAMPTZ, (v_curr_date + v_end_time)::TIMESTAMPTZ,
                        (v_curr_date + v_start_time)::TIMESTAMPTZ, (v_curr_date + v_end_time)::TIMESTAMPTZ,
                        v_purpose, 'Confirmed', TRUE,
                        v_organizer_name, v_organizer_role, v_attendee_count,
                        TRUE, v_series_id, v_user_id
                    );
                    v_created_count := v_created_count + 1;
                ELSE
                    v_conflict_count := v_conflict_count + 1;
                END IF;
            END IF;

            v_curr_date := v_curr_date + 1;
        END LOOP;

        UPDATE public.space_booking_recurring_series 
        SET total_occurrences = v_created_count 
        WHERE id = v_series_id;

        RETURN jsonb_build_object(
            'success', TRUE,
            'series_id', v_series_id,
            'created_count', v_created_count,
            'conflict_skipped_count', v_conflict_count,
            'message', 'Successfully generated ' || v_created_count || ' recurring space bookings (' || v_conflict_count || ' skipped due to conflicts).'
        );
    END;
    $$;
    """)
    print("   Created fn_space_booking_create_recurring function.")

    conn.close()
    print("Migration applied successfully!")

if __name__ == '__main__':
    apply_migrations()
