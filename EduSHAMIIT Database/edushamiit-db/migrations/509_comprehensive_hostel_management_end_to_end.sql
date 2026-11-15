-- ============================================================================
-- Migration: 509_comprehensive_hostel_management_end_to_end.sql
-- Description: Comprehensive Hostel Management Enhancements
-- 1. Night Curfew & Roll-Call Bed-by-Bed Attendance Subsystem
-- 2. Mess & Dining Hall Management (Menu schedules, Dietary preferences, Meal Attendance, Automated Rebate Calculations)
-- 3. Room & Bed Asset Inventory Handover Check-in/Check-out Audit
-- 4. Visitor Logbook & Guest Room Management
-- 5. Stored Procedures and Analytics Aggregators for Zero-Hardcoding
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. NIGHT CURFEW & ROLL-CALL ATTENDANCE
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hostel_night_attendance_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID REFERENCES public.hostel_buildings(id) ON DELETE SET NULL,
    floor_id UUID REFERENCES public.hostel_floors(id) ON DELETE SET NULL,
    academic_year VARCHAR(20) NOT NULL DEFAULT '2026 - 2027',
    attendance_date DATE NOT NULL DEFAULT CURRENT_DATE,
    session_time TIME NOT NULL DEFAULT '22:00:00',
    taken_by_staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'COMPLETED', -- DRAFT, COMPLETED, AUDITED
    total_students INT NOT NULL DEFAULT 0,
    present_count INT NOT NULL DEFAULT 0,
    absent_count INT NOT NULL DEFAULT 0,
    on_leave_count INT NOT NULL DEFAULT 0,
    infirmary_count INT NOT NULL DEFAULT 0,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hostel_night_att_sess_school_date 
    ON public.hostel_night_attendance_sessions(school_id, attendance_date);

CREATE TABLE IF NOT EXISTS public.hostel_night_attendance_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.hostel_night_attendance_sessions(id) ON DELETE CASCADE,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    admission_id UUID REFERENCES public.hostel_admissions(id) ON DELETE SET NULL,
    room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE SET NULL,
    bed_id UUID REFERENCES public.hostel_beds(id) ON DELETE SET NULL,
    status VARCHAR(30) NOT NULL DEFAULT 'PRESENT', -- PRESENT, ABSENT, APPROVED_LEAVE, INFIRMARY
    remarks TEXT,
    parent_alert_sent BOOLEAN NOT NULL DEFAULT FALSE,
    parent_alert_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hostel_night_att_rec_student 
    ON public.hostel_night_attendance_records(student_id, status);

-- ----------------------------------------------------------------------------
-- 2. MESS & DINING HALL MANAGEMENT
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hostel_mess_menus (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID REFERENCES public.hostel_buildings(id) ON DELETE CASCADE,
    day_of_week VARCHAR(15) NOT NULL, -- MONDAY, TUESDAY, WEDNESDAY, etc.
    meal_type VARCHAR(20) NOT NULL, -- BREAKFAST, LUNCH, SNACKS, DINNER
    timing_start TIME NOT NULL,
    timing_end TIME NOT NULL,
    items JSONB NOT NULL DEFAULT '[]'::jsonb, -- e.g. ["Idli", "Sambar", "Chutney", "Coffee"]
    calories_estimate INT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.hostel_mess_dietary_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    admission_id UUID REFERENCES public.hostel_admissions(id) ON DELETE CASCADE,
    diet_type VARCHAR(30) NOT NULL DEFAULT 'VEGETARIAN', -- VEGETARIAN, NON_VEG, JAIN, VEGAN
    allergies TEXT,
    special_instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_hostel_dietary_student UNIQUE(student_id)
);

CREATE TABLE IF NOT EXISTS public.hostel_mess_attendance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    meal_date DATE NOT NULL DEFAULT CURRENT_DATE,
    meal_type VARCHAR(20) NOT NULL, -- BREAKFAST, LUNCH, SNACKS, DINNER
    scanned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    scanned_by_staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'CONSUMED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hostel_mess_att_date 
    ON public.hostel_mess_attendance(school_id, meal_date, meal_type);

CREATE TABLE IF NOT EXISTS public.hostel_mess_rebates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    admission_id UUID REFERENCES public.hostel_admissions(id) ON DELETE SET NULL,
    leave_request_id UUID REFERENCES public.hostel_leave_outing_requests(id) ON DELETE SET NULL,
    academic_year VARCHAR(20) NOT NULL DEFAULT '2026 - 2027',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_days INT NOT NULL,
    rebate_rate_per_day NUMERIC(10,2) NOT NULL DEFAULT 120.00,
    total_rebate_amount NUMERIC(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'APPROVED', -- PENDING, APPROVED, CREDITED, REJECTED
    credit_note_invoice_id UUID,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 3. ROOM & BED ASSET INVENTORY HANDOVER AUDIT
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hostel_asset_audits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    admission_id UUID REFERENCES public.hostel_admissions(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE SET NULL,
    bed_id UUID REFERENCES public.hostel_beds(id) ON DELETE SET NULL,
    audit_type VARCHAR(30) NOT NULL DEFAULT 'CHECK_IN', -- CHECK_IN, CHECK_OUT, PERIODIC, DAMAGE_REPORT
    audit_date DATE NOT NULL DEFAULT CURRENT_DATE,
    conducted_by_staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    items_checklist JSONB NOT NULL DEFAULT '[]'::jsonb, 
    -- e.g. [{"item": "Mattress", "condition": "GOOD", "is_present": true, "damage_cost": 0}]
    total_damages_cost NUMERIC(10,2) NOT NULL DEFAULT 0.00,
    deposit_deduction_applied BOOLEAN NOT NULL DEFAULT FALSE,
    student_signature_acknowledged BOOLEAN NOT NULL DEFAULT TRUE,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hostel_asset_audits_student 
    ON public.hostel_asset_audits(student_id, audit_type);

-- ----------------------------------------------------------------------------
-- 4. VISITOR LOGBOOK & GUEST ROOM MANAGEMENT
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.hostel_visitors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    admission_id UUID REFERENCES public.hostel_admissions(id) ON DELETE SET NULL,
    visitor_name VARCHAR(150) NOT NULL,
    visitor_phone VARCHAR(30) NOT NULL,
    relationship VARCHAR(50) NOT NULL DEFAULT 'Parent',
    id_proof_type VARCHAR(50) DEFAULT 'Aadhar Card',
    id_proof_number VARCHAR(100),
    check_in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    check_out_time TIMESTAMPTZ,
    purpose TEXT NOT NULL DEFAULT 'Family Visit',
    vehicle_number VARCHAR(50),
    allowed_by_staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    badge_number VARCHAR(30),
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE, CHECKED_OUT, DENIED
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_hostel_visitors_school_status 
    ON public.hostel_visitors(school_id, status);

CREATE TABLE IF NOT EXISTS public.hostel_guest_room_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    building_id UUID REFERENCES public.hostel_buildings(id) ON DELETE SET NULL,
    room_id UUID REFERENCES public.hostel_rooms(id) ON DELETE SET NULL,
    visitor_id UUID REFERENCES public.hostel_visitors(id) ON DELETE SET NULL,
    guest_name VARCHAR(150) NOT NULL,
    contact_number VARCHAR(30) NOT NULL,
    check_in_date DATE NOT NULL,
    check_out_date DATE NOT NULL,
    daily_charge NUMERIC(10,2) NOT NULL DEFAULT 800.00,
    total_charge NUMERIC(10,2) NOT NULL DEFAULT 800.00,
    payment_status VARCHAR(30) NOT NULL DEFAULT 'PAID', -- PAID, PENDING, WAIVED
    status VARCHAR(30) NOT NULL DEFAULT 'CONFIRMED', -- CONFIRMED, CHECKED_IN, CHECKED_OUT, CANCELLED
    booked_by_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 5. SEED STANDARD MESS MENUS AND LOOKUPS
-- ----------------------------------------------------------------------------
INSERT INTO public.hostel_mess_menus (school_id, building_id, day_of_week, meal_type, timing_start, timing_end, items, calories_estimate)
SELECT 
    b.school_id,
    b.id,
    d.day,
    m.meal,
    m.t_start::TIME,
    m.t_end::TIME,
    m.items::jsonb,
    m.calories
FROM public.hostel_buildings b
CROSS JOIN (
    VALUES ('MONDAY'), ('TUESDAY'), ('WEDNESDAY'), ('THURSDAY'), ('FRIDAY'), ('SATURDAY'), ('SUNDAY')
) AS d(day)
CROSS JOIN (
    VALUES 
    ('BREAKFAST', '07:30', '09:00', '["Idli / Poha / Bread Toast", "Sambar & Chutney", "Boiled Egg / Banana", "Tea / Milk"]', 450),
    ('LUNCH', '12:30', '14:30', '["Chapati / Roti", "Steamed Basmati Rice", "Dal Tadka", "Seasonal Vegetable Paneer / Curry", "Curd / Raita", "Salad"]', 750),
    ('SNACKS', '17:00', '18:00', '["Samosa / Veg Cutlet / Biscuits", "Tea / Coffee"]', 280),
    ('DINNER', '20:00', '21:45', '["Phulka / Roti", "Jeera Rice", "Dal Makhani / Sambar", "Special Veg / Non-Veg Korma", "Gulab Jamun / Sweet"]', 700)
) AS m(meal, t_start, t_end, items, calories)
WHERE NOT EXISTS (
    SELECT 1 FROM public.hostel_mess_menus mm 
    WHERE mm.building_id = b.id AND mm.day_of_week = d.day AND mm.meal_type = m.meal
);

-- Seed dietary profiles for existing hostel admissions
INSERT INTO public.hostel_mess_dietary_profiles (school_id, student_id, admission_id, diet_type, allergies)
SELECT 
    ha.school_id,
    ha.student_id,
    ha.id,
    'VEGETARIAN',
    'None reported'
FROM public.hostel_admissions ha
WHERE NOT EXISTS (
    SELECT 1 FROM public.hostel_mess_dietary_profiles dp WHERE dp.student_id = ha.student_id
)
ON CONFLICT (student_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 6. STORED PROCEDURES & WORKFLOW AUTOMATIONS
-- ----------------------------------------------------------------------------

-- A. Submit Night Roll-Call Attendance
CREATE OR REPLACE FUNCTION public.fn_hostel_submit_night_attendance(
    p_school_id UUID,
    p_building_id UUID,
    p_floor_id UUID,
    p_staff_id UUID,
    p_attendance_date DATE,
    p_academic_year TEXT,
    p_records JSONB, -- Array of {student_id, admission_id, room_id, bed_id, status, remarks}
    p_remarks TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_session_id UUID;
    v_rec JSONB;
    v_total INT := 0;
    v_present INT := 0;
    v_absent INT := 0;
    v_leave INT := 0;
    v_infirmary INT := 0;
    v_status TEXT;
BEGIN
    -- Create attendance session
    INSERT INTO public.hostel_night_attendance_sessions (
        school_id, building_id, floor_id, academic_year, attendance_date,
        session_time, taken_by_staff_id, status, remarks
    ) VALUES (
        p_school_id, p_building_id, p_floor_id, COALESCE(p_academic_year, '2026 - 2027'),
        COALESCE(p_attendance_date, CURRENT_DATE), CURRENT_TIME, p_staff_id, 'COMPLETED', p_remarks
    )
    RETURNING id INTO v_session_id;

    -- Iterate and insert records
    FOR v_rec IN SELECT * FROM jsonb_array_elements(p_records)
    LOOP
        v_total := v_total + 1;
        v_status := COALESCE(v_rec->>'status', 'PRESENT');

        IF v_status = 'PRESENT' THEN
            v_present := v_present + 1;
        ELSIF v_status = 'ABSENT' THEN
            v_absent := v_absent + 1;
        ELSIF v_status = 'APPROVED_LEAVE' THEN
            v_leave := v_leave + 1;
        ELSIF v_status = 'INFIRMARY' THEN
            v_infirmary := v_infirmary + 1;
        END IF;

        INSERT INTO public.hostel_night_attendance_records (
            session_id, school_id, student_id, admission_id, room_id, bed_id,
            status, remarks, parent_alert_sent, parent_alert_time
        ) VALUES (
            v_session_id,
            p_school_id,
            (v_rec->>'student_id')::UUID,
            (v_rec->>'admission_id')::UUID,
            (v_rec->>'room_id')::UUID,
            (v_rec->>'bed_id')::UUID,
            v_status,
            v_rec->>'remarks',
            (v_status = 'ABSENT'), -- Trigger parent alert flag if absent
            CASE WHEN v_status = 'ABSENT' THEN NOW() ELSE NULL END
        );
    END LOOP;

    -- Update session counts
    UPDATE public.hostel_night_attendance_sessions
    SET total_students = v_total,
        present_count = v_present,
        absent_count = v_absent,
        on_leave_count = v_leave,
        infirmary_count = v_infirmary,
        updated_at = NOW()
    WHERE id = v_session_id;

    RETURN jsonb_build_object(
        'success', true,
        'session_id', v_session_id,
        'total_students', v_total,
        'present_count', v_present,
        'absent_count', v_absent,
        'on_leave_count', v_leave,
        'infirmary_count', v_infirmary
    );
END;
$$;

-- B. Calculate & Apply Mess Rebate for Approved Leave
CREATE OR REPLACE FUNCTION public.fn_hostel_process_leave_mess_rebate(
    p_school_id UUID,
    p_leave_request_id UUID,
    p_daily_rebate_rate NUMERIC DEFAULT 120.00
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_leave RECORD;
    v_days INT;
    v_rebate_amt NUMERIC(10,2);
    v_rebate_id UUID;
BEGIN
    SELECT * INTO v_leave 
    FROM public.hostel_leave_outing_requests
    WHERE id = p_leave_request_id AND school_id = p_school_id;

    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave request not found');
    END IF;

    -- Only calculate rebate for multi-day leaves (> 2 days)
    v_days := (v_leave.expected_return_at::DATE - v_leave.start_at::DATE);
    IF v_days < 2 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Leave duration is less than minimum 2 days for mess rebate');
    END IF;

    v_rebate_amt := v_days * p_daily_rebate_rate;

    INSERT INTO public.hostel_mess_rebates (
        school_id, student_id, leave_request_id, academic_year,
        start_date, end_date, total_days, rebate_rate_per_day,
        total_rebate_amount, status, remarks
    ) VALUES (
        p_school_id, v_leave.student_id, p_leave_request_id, COALESCE(v_leave.academic_year, '2026 - 2027'),
        v_leave.start_at::DATE, v_leave.expected_return_at::DATE, v_days, p_daily_rebate_rate,
        v_rebate_amt, 'APPROVED', 'Automatic mess rebate for approved leave: ' || v_leave.request_number
    )
    RETURNING id INTO v_rebate_id;

    RETURN jsonb_build_object(
        'success', true,
        'rebate_id', v_rebate_id,
        'days', v_days,
        'rebate_amount', v_rebate_amt
    );
END;
$$;

-- C. Record Asset Audit (Check-in / Check-out)
CREATE OR REPLACE FUNCTION public.fn_hostel_record_asset_audit(
    p_school_id UUID,
    p_student_id UUID,
    p_admission_id UUID,
    p_room_id UUID,
    p_bed_id UUID,
    p_audit_type VARCHAR,
    p_staff_id UUID,
    p_checklist JSONB,
    p_total_damages NUMERIC DEFAULT 0.00,
    p_apply_deposit_deduction BOOLEAN DEFAULT FALSE,
    p_remarks TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_audit_id UUID;
BEGIN
    INSERT INTO public.hostel_asset_audits (
        school_id, admission_id, student_id, room_id, bed_id,
        audit_type, audit_date, conducted_by_staff_id, items_checklist,
        total_damages_cost, deposit_deduction_applied, student_signature_acknowledged, remarks
    ) VALUES (
        p_school_id, p_admission_id, p_student_id, p_room_id, p_bed_id,
        p_audit_type, CURRENT_DATE, p_staff_id, p_checklist,
        p_total_damages, p_apply_deposit_deduction, true, p_remarks
    )
    RETURNING id INTO v_audit_id;

    -- If deposit deduction is applied on checkout and damage cost > 0, record penalty in fees
    IF p_apply_deposit_deduction AND p_total_damages > 0 THEN
        INSERT INTO public.hostel_penalties (
            school_id, student_id, charge_type, amount, description, status
        ) VALUES (
            p_school_id, p_student_id, 'ROOM_DAMAGE', p_total_damages,
            'Checkout damage deduction from asset audit ID: ' || v_audit_id::TEXT, 'APPLIED'
        );
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'audit_id', v_audit_id,
        'total_damages', p_total_damages
    );
END;
$$;

-- D. Collision-Resilient Room Creation & Bulk Generator
CREATE OR REPLACE FUNCTION public.fn_hostel_create_or_update_room(
    p_school_id UUID,
    p_user_id UUID,
    p_data JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_id UUID;
    v_building_id UUID;
    v_floor_id UUID;
    v_room_number VARCHAR(50);
    v_room_code VARCHAR(100);
    v_room_name VARCHAR(150);
    v_room_type VARCHAR(100);
    v_is_residential BOOLEAN;
    v_capacity INT;
    v_size NUMERIC(8,2);
    v_fee NUMERIC(10,2);
    v_gender VARCHAR(20);
    v_status VARCHAR(30);
    v_photos JSONB;
    v_amenities JSONB;
    v_record RECORD;
BEGIN
    v_id := (p_data->>'id')::UUID;
    v_building_id := (p_data->>'building_id')::UUID;
    v_floor_id := (p_data->>'floor_id')::UUID;
    v_room_number := TRIM(p_data->>'room_number');
    v_room_code := COALESCE(TRIM(p_data->>'room_code'), v_room_number);
    v_room_name := p_data->>'room_name';
    v_room_type := COALESCE(TRIM(p_data->>'room_type'), 'Standard');
    v_is_residential := COALESCE((p_data->>'is_residential')::BOOLEAN, 
                                 CASE WHEN v_room_type IN ('Toilet/Washroom', 'Pantry', 'Laundry', 'Storage', 'Electrical Room', 'Pump Room') THEN FALSE ELSE TRUE END);
    v_capacity := COALESCE((p_data->>'capacity')::INT, CASE WHEN v_is_residential THEN 3 ELSE 0 END);
    v_size := COALESCE((p_data->>'room_size_sqm')::NUMERIC, 18.0);
    v_fee := COALESCE((p_data->>'monthly_fee')::NUMERIC, 6000.0);
    v_gender := COALESCE(p_data->>'gender_restriction', 'ALL');
    v_status := COALESCE(p_data->>'operational_status', 'AVAILABLE');
    v_photos := COALESCE(p_data->'photos', '[]'::JSONB);
    v_amenities := COALESCE(p_data->'amenities', '[]'::JSONB);

    IF v_building_id IS NULL OR v_floor_id IS NULL OR v_room_number IS NULL OR v_room_number = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Building, floor, and room number are required');
    END IF;

    -- Pre-empt unique constraint collisions on (building_id, floor_id, upper(room_number))
    IF v_id IS NULL THEN
        SELECT id INTO v_id 
        FROM public.hostel_rooms
        WHERE building_id = v_building_id 
          AND floor_id = v_floor_id 
          AND UPPER(room_number) = UPPER(v_room_number) 
          AND deleted_at IS NULL;
    END IF;

    IF v_id IS NOT NULL THEN
        UPDATE public.hostel_rooms
        SET room_number = v_room_number,
            room_code = v_room_code,
            room_name = v_room_name,
            room_type = v_room_type,
            is_residential = v_is_residential,
            target_capacity = v_capacity,
            room_size_sqm = v_size,
            monthly_fee = v_fee,
            gender_restriction = v_gender,
            operational_status = v_status,
            photos = v_photos,
            amenities = v_amenities,
            updated_by = p_user_id,
            updated_at = NOW()
        WHERE id = v_id AND school_id = p_school_id AND deleted_at IS NULL
        RETURNING * INTO v_record;
    ELSE
        INSERT INTO public.hostel_rooms (
            school_id, building_id, floor_id, room_number, room_code, room_name, room_type,
            is_residential, target_capacity, room_size_sqm, monthly_fee, gender_restriction,
            operational_status, photos, amenities, created_by, updated_by
        ) VALUES (
            p_school_id, v_building_id, v_floor_id, v_room_number, v_room_code, v_room_name, v_room_type,
            v_is_residential, v_capacity, v_size, v_fee, v_gender,
            v_status, v_photos, v_amenities, p_user_id, p_user_id
        )
        RETURNING * INTO v_record;
    END IF;

    PERFORM public.fn_hostel_recalculate_room(v_record.id);

    RETURN jsonb_build_object('success', true, 'data', to_jsonb(v_record));
END;
$$;
